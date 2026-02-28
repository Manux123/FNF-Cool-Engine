package funkin.gameplay.notes;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import funkin.gameplay.notes.Note;
import funkin.gameplay.notes.NoteSplash;
import funkin.gameplay.notes.NoteHoldCover;
import funkin.gameplay.notes.NoteBatcher;

/**
 * NoteRenderer SUPER OPTIMIZADO
 *
 * ARQUITECTURA (patrón v-slice):
 * - NoteSplash    → solo splashes de hit en notas normales
 * - NoteHoldCover → covers visuales para hold notes (start → loop → end)
 * - Object pooling separado para cada tipo
 * - Cero allocs en los paths calientes (buffers preallocados)
 *
 * API pública usada por NoteManager:
 * - getNote / recycleNote
 * - spawnSplash        (notas normales)
 * - recycleSplash
 * - startHoldCover     (inicio de hold note)
 * - stopHoldCover      (release o miss)
 * - updateHoldCovers   (limpiar covers huérfanos, llamar 1×/frame)
 * - updateBatcher
 * - clearPools / destroy
 */
class NoteRenderer
{
    // Referencias
    private var playerStrums:FlxTypedGroup<FlxSprite>;
    private var cpuStrums:FlxTypedGroup<FlxSprite>;

    // BUGFIX: El batcher interno de NoteRenderer NUNCA se añade al FlxState
    // via add(), por lo que nunca se dibuja. Las notas se renderizan desde el
    // FlxTypedGroup<Note> que PlayState sí añade a la escena.
    public var noteBatcher:NoteBatcher = null;
    private var useBatching:Bool = false;

    // Config
    public var downscroll:Bool = false;
    public var strumLineY:Float = 50;
    public var noteSpeed:Float = 1.0;

    // OPTIMIZATION: pools separados para sustain vs normal.
    // BUGFIX: mezclarlos causaba que note.recycle() cambiara isSustainNote sin
    // recargar animaciones → WARNING "No animation called 'purpleScroll'" etc.
    // 24 + 24 = 48 objetos poolados — suficiente para canciones densas.
    // El valor anterior (50+50=100) mantenía demasiados FlxSprites vivos con
    // sus texturas, contribuyendo a la presión de RAM durante gameplay.
    private var notePool:Array<Note>    = [];   // notas normales (cabeza)
    private var sustainPool:Array<Note> = [];   // hold pieces + tails
    private var maxPoolSize:Int = 24;

    // OPTIMIZATION: pool de splashes de hit normales
    private var splashPool:Array<NoteSplash> = [];
    private var maxSplashPoolSize:Int = 16;

    // NUEVO (v-slice): pool de NoteHoldCover
    public var holdCoverPool:Array<NoteHoldCover> = [];
    private var maxHoldCoverPoolSize:Int = 8;

    // Tracking de hold notes activas → cover asociado (keyed por dirección 0-3)
    private var activeHoldCovers:Map<Int, NoteHoldCover> = new Map();

    // Stats de pooling
    public var pooledNotes:Int = 0;
    public var pooledSplashes:Int = 0;
    public var createdNotes:Int = 0;
    public var createdSplashes:Int = 0;
    public var pooledHoldCovers:Int = 0;
    public var createdHoldCovers:Int = 0;

    // Constructor
    public function new(notes:FlxTypedGroup<Note>, playerStrums:FlxTypedGroup<FlxSprite>, cpuStrums:FlxTypedGroup<FlxSprite>)
    {
        this.playerStrums = playerStrums;
        this.cpuStrums = cpuStrums;

        trace('[NoteRenderer] Inicializado - Pool: $maxPoolSize notas, $maxSplashPoolSize splashes, $maxHoldCoverPoolSize holdCovers');
    }

    // ─────────────────────────── NOTE POOL ───────────────────────────────────

    /**
     * Obtener nota del pool o crear una nueva.
     */
    public function getNote(strumTime:Float, noteData:Int, ?prevNote:Note, ?sustainNote:Bool = false, ?mustHitNote:Bool = false):Note
    {
        var note:Note = null;
        final pool = sustainNote ? sustainPool : notePool;

        if (pool.length > 0)
        {
            note = pool.pop();
            note.recycle(strumTime, noteData, prevNote, sustainNote, mustHitNote);
            pooledNotes++;
        }
        else
        {
            note = new Note(strumTime, noteData, prevNote, sustainNote, mustHitNote);
            createdNotes++;
        }

        if (useBatching && noteBatcher != null)
            noteBatcher.addNoteToBatch(note);

        return note;
    }

    /**
     * Reciclar nota — devolverla al pool.
     */
    public function recycleNote(note:Note):Void
    {
        if (note == null) return;

        // Hold cover lifecycle is managed by direction in NoteManager.releaseHoldNote()

        if (useBatching && noteBatcher != null)
            noteBatcher.removeNoteFromBatch(note);

        try
        {
            final pool = note.isSustainNote ? sustainPool : notePool;
            if (pool.length < maxPoolSize)
            {
                note.kill();
                note.visible = false;
                note.active = false;
                pool.push(note);
            }
            else
            {
                note.kill();
                note.destroy();
            }
        }
        catch (e:Dynamic)
        {
            trace('[NoteRenderer] Error reciclando nota: ' + e);
        }
    }

    // ────────────────────────── SPLASH POOL ──────────────────────────────────

    /**
     * Crear y devolver un splash de hit para una nota normal.
     * El caller (NoteManager) es quien añade el resultado al FlxGroup de la escena.
     */
    public function spawnSplash(x:Float, y:Float, noteData:Int = 0, ?splashName:String):NoteSplash
    {
        // Buscar splash disponible en el pool
        for (s in splashPool)
        {
            if (!s.inUse)
            {
                s.setup(x, y, noteData, splashName);
                pooledSplashes++;
                return s;
            }
        }

        // Crear nuevo, o reusar el más viejo si el pool está lleno
        var splash:NoteSplash;
        if (splashPool.length < maxSplashPoolSize)
        {
            splash = new NoteSplash();
            splashPool.push(splash);
            createdSplashes++;
        }
        else
        {
            splash = splashPool[0];
        }

        splash.setup(x, y, noteData, splashName);
        return splash;
    }

    /**
     * Reciclar splash de hit.
     */
    public function recycleSplash(splash:NoteSplash):Void
    {
        if (splash == null) return;
        try { splash.kill(); }
        catch (e:Dynamic) { trace('[NoteRenderer] Error reciclando splash: ' + e); }
    }

    // ─────────────────────── HOLD COVER POOL (v-slice) ───────────────────────

    private function _getHoldCover(x:Float, y:Float, noteData:Int, ?splashName:String):NoteHoldCover
    {
        // Buscar uno libre en el pool
        for (c in holdCoverPool)
        {
            if (!c.inUse)
            {
                c.setup(x, y, noteData, splashName);
                pooledHoldCovers++;
                return c;
            }
        }

        // Ninguno libre → crear siempre uno nuevo (nunca robar uno activo)
        // maxHoldCoverPoolSize es un techo suave — 4 dirs × 2 lados = 8 max simultáneos
        var cover = new NoteHoldCover();
        holdCoverPool.push(cover);
        createdHoldCovers++;
        cover.setup(x, y, noteData, splashName);
        return cover;
    }

    // ─────────────────────── API DE HOLD COVERS ──────────────────────────────

    /**
     * Registrar un cover pre-creado en el pool (usado para prewarm desde PlayState).
     * El cover debe estar muerto (kill() ya llamado) antes de registrar.
     */
    public function registerHoldCoverInPool(cover:NoteHoldCover):Void
    {
        if (holdCoverPool.indexOf(cover) < 0)
            holdCoverPool.push(cover);
    }

    /**
     * Iniciar cover visual para una hold note.
     * Reproduce start → loop (automático) → end (cuando se llama stopHoldCover).
     *
     * Solo llamar si FlxG.save.data.notesplashes == true (el check lo hace NoteManager).
     * El caller debe añadir el resultado al FlxGroup de la escena.
     *
     * @return El NoteHoldCover asignado, o null si ya había uno para esta nota.
     */
    public function startHoldCover(direction:Int, strumX:Float, strumY:Float, isPlayer:Bool = true):NoteHoldCover
    {
        // Player usa claves 0-3, CPU usa 4-7 para evitar colisiones
        var key:Int = isPlayer ? direction : direction + 4;
        if (activeHoldCovers.exists(key))
            return activeHoldCovers.get(key);

        var cover = _getHoldCover(strumX, strumY, direction);
        cover.playStart();
        activeHoldCovers.set(key, cover);
        return cover;
    }

    /**
     * Detener el cover de una hold note (release o miss).
     * Reproduce la animación de fin; NoteHoldCover se mata solo al terminar.
     */
    public function stopHoldCover(direction:Int, isPlayer:Bool = true):Void
    {
        var key:Int = isPlayer ? direction : direction + 4;
        if (activeHoldCovers.exists(key))
        {
            var cover = activeHoldCovers.get(key);
            // Si playEnd() devuelve false → cover en estado "end_pending" (start aún no acabó)
            // Se eliminará del map igualmente; el cover se autodestruirá al terminar su start
            if (cover != null) cover.playEnd();
            activeHoldCovers.remove(key);
        }
    }

    /**
     * Ya no necesario: el ciclo de vida se gestiona explícitamente
     * por dirección en NoteManager (startHoldCover / stopHoldCover).
     * Se mantiene por compatibilidad con llamadas existentes.
     */
    public function updateHoldCovers():Void {}

    // ─────────────────────── TOGGLE / STATS / BATCHER ────────────────────────

    public function updateBatcher():Void
    {
        if (useBatching && noteBatcher != null)
            noteBatcher.update(FlxG.elapsed);
    }

    public function toggleBatching():Void
    {
        useBatching = !useBatching;
        if (useBatching && noteBatcher == null)
            noteBatcher = new NoteBatcher();
        trace('[NoteRenderer] Batching: $useBatching');
    }

    /**
     * Alias mantenido para que NoteManager.toggleHoldSplashes() compile sin cambios.
     * Los hold covers se habilitan/deshabilitan mediante FlxG.save.data.notesplashes
     * en NoteManager.handleSustainNoteHit().
     */
    public function toggleHoldSplashes():Void
    {
        trace('[NoteRenderer] Hold covers controlados via FlxG.save.data.notesplashes en NoteManager');
    }

    public function getPoolStats():String
    {
        var stats = 'Notes: ${notePool.length + sustainPool.length}/$maxPoolSize';
        stats += ' (normal: ${notePool.length} sustain: ${sustainPool.length}';
        stats += ' pooled: $pooledNotes created: $createdNotes)\n';
        stats += 'Splashes: ${splashPool.length}/$maxSplashPoolSize';
        stats += ' (pooled: $pooledSplashes created: $createdSplashes)\n';
        stats += 'HoldCovers: ${holdCoverPool.length}/$maxHoldCoverPoolSize';
        stats += ' (active: ${Lambda.count(activeHoldCovers)}';
        stats += ' pooled: $pooledHoldCovers created: $createdHoldCovers)\n';
        return stats;
    }

    // ──────────────────────────── LIMPIEZA ───────────────────────────────────

    public function clearPools():Void
    {
        // Hold covers activos — solo kill, NO destroy
        // (están en grpHoldCovers que PlayState destruirá correctamente)
        for (dir in activeHoldCovers.keys())
        {
            var cover = activeHoldCovers.get(dir);
            if (cover != null) cover.kill();
        }
        activeHoldCovers.clear();

        // Note pool — estas notas NO están en ningún FlxGroup → destruir
        for (note in notePool)
            if (note != null) note.destroy();
        notePool = [];

        for (note in sustainPool)
            if (note != null) note.destroy();
        sustainPool = [];

        // Splash pool — están en grpNoteSplashes → solo kill, NO destroy
        for (splash in splashPool)
            if (splash != null) splash.kill();
        splashPool = [];

        // HoldCover pool — están en grpHoldCovers → solo kill, NO destroy
        for (cover in holdCoverPool)
            if (cover != null) cover.kill();
        holdCoverPool = [];

        if (noteBatcher != null)
            noteBatcher.clearBatches();

        pooledNotes = 0;
        pooledSplashes = 0;
        createdNotes = 0;
        createdSplashes = 0;
        pooledHoldCovers = 0;
        createdHoldCovers = 0;

        trace('[NoteRenderer] Pools limpiados');
    }

    public function destroy():Void
    {
        clearPools();

        if (noteBatcher != null)
        {
            noteBatcher.clearBatches();
            noteBatcher.destroy();
            noteBatcher = null;
        }

        playerStrums = null;
        cpuStrums = null;
    }
}
