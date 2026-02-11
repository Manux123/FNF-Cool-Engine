package funkin.gameplay.notes;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import funkin.gameplay.notes.Note;
import funkin.gameplay.notes.NoteSplash;
import funkin.gameplay.notes.NoteBatcher;

/**
 * NoteRenderer SUPER OPTIMIZADO
 * 
 * NUEVAS CARACTERÍSTICAS:
 * - Batching de notas para reducir draw calls
 * - Splashes para hold notes (inicio, continuo, fin)
 * - Object pooling mejorado
 * - Gestión automática de splashes continuos
 */
class NoteRenderer
{
    // Referencias
    private var playerStrums:FlxTypedGroup<FlxSprite>;
    private var cpuStrums:FlxTypedGroup<FlxSprite>;
    
    // NUEVO: Batcher para notas
    public var noteBatcher:NoteBatcher;
    private var useBatching:Bool = true;
    
    // Config
    public var downscroll:Bool = false;
    public var strumLineY:Float = 50;
    public var noteSpeed:Float = 1.0;
    
    // OPTIMIZATION: Object Pooling para notas
    private var notePool:Array<Note> = [];
    private var maxPoolSize:Int = 50;
    
    // OPTIMIZATION: Object Pooling para splashes
    private var splashPool:Array<NoteSplash> = [];
    private var maxSplashPoolSize:Int = 32;
    
    // NUEVO: Tracking de hold notes activas para splashes continuos
    private var activeHoldSplashes:Map<Note, NoteSplash> = new Map();
    
    // Stats de pooling
    public var pooledNotes:Int = 0;
    public var pooledSplashes:Int = 0;
    public var createdNotes:Int = 0;
    public var createdSplashes:Int = 0;
    
    // NUEVO: Configuración de splashes para holds
    public var holdSplashesEnabled:Bool = true;
    public var holdSplashInterval:Float = 0.2; // Intervalo entre splashes de hold
    
    // Constructor
    public function new(notes:FlxTypedGroup<Note>, playerStrums:FlxTypedGroup<FlxSprite>, cpuStrums:FlxTypedGroup<FlxSprite>)
    {
        this.playerStrums = playerStrums;
        this.cpuStrums = cpuStrums;
        
        // NUEVO: Inicializar batcher
        if (useBatching)
        {
            noteBatcher = new NoteBatcher();
        }
        
        trace('[NoteRenderer] Inicializado - Pool: $maxPoolSize notas, $maxSplashPoolSize splashes');
        trace('[NoteRenderer] Batching: $useBatching | Hold Splashes: $holdSplashesEnabled');
    }
    
    /**
     * Obtener nota del pool o crear una nueva
     */
    public function getNote(strumTime:Float, noteData:Int, ?prevNote:Note, ?sustainNote:Bool = false, ?mustHitNote:Bool = false):Note
    {
        var note:Note = null;
        
        if (notePool.length > 0)
        {
            note = notePool.pop();
            note.recycle(strumTime, noteData, prevNote, sustainNote, mustHitNote);
            pooledNotes++;
        }
        else
        {
            note = new Note(strumTime, noteData, prevNote, sustainNote, mustHitNote);
            createdNotes++;
        }
        
        // NUEVO: Agregar al batcher si está habilitado
        if (useBatching && noteBatcher != null)
        {
            noteBatcher.addNoteToBatch(note);
        }
        
        return note;
    }
    
    /**
     * Reciclar nota - Devolverla al pool
     */
    public function recycleNote(note:Note):Void
    {
        if (note == null) return;
        
        // NUEVO: Detener splash continuo si existe
        if (activeHoldSplashes.exists(note))
        {
            var holdSplash = activeHoldSplashes.get(note);
            if (holdSplash != null)
            {
                holdSplash.stopContinuousSplash();
                recycleSplash(holdSplash);
            }
            activeHoldSplashes.remove(note);
        }
        
        // NUEVO: Remover del batcher si está habilitado
        if (useBatching && noteBatcher != null)
        {
            noteBatcher.removeNoteFromBatch(note);
        }
        
        try
        {
            if (notePool.length < maxPoolSize)
            {
                note.kill();
                note.visible = false;
                note.active = false;
                notePool.push(note);
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
    
    /**
     * Obtener splash del pool o crear uno nuevo
     */
    public function getSplash(x:Float, y:Float, noteData:Int = 0, ?splashName:String = null, ?type:SplashType = NORMAL):NoteSplash
    {
        var splash:NoteSplash = null;
        
        // Buscar splash disponible en el pool
        for (s in splashPool)
        {
            if (!s.inUse)
            {
                splash = s;
                splash.setup(x, y, noteData, splashName, type);
                pooledSplashes++;
                return splash;
            }
        }
        
        // Si no hay splashes disponibles, crear uno nuevo o reusar el más viejo
        if (splashPool.length < maxSplashPoolSize)
        {
            splash = new NoteSplash(x, y, noteData, splashName);
            splash.splashType = type;
            splashPool.push(splash);
            createdSplashes++;
        }
        else
        {
            // Reusar el primer splash (más viejo)
            splash = splashPool[0];
            splash.setup(x, y, noteData, splashName, type);
            pooledSplashes++;
        }
        
        return splash;
    }
    
    /**
     * NUEVO: Crear splash para inicio de hold note
     */
    public function createHoldStartSplash(note:Note, strumX:Float, strumY:Float):NoteSplash
    {
        if (!holdSplashesEnabled) return null;
        
        var splash = getSplash(strumX, strumY, note.noteData, null, HOLD_START);
        return splash;
    }
    
    /**
     * NUEVO: Iniciar splash continuo para hold note
     */
    public function startHoldContinuousSplash(note:Note, strumX:Float, strumY:Float):NoteSplash
    {
        if (!holdSplashesEnabled) return null;
        
        // Si ya existe, no crear otro
        if (activeHoldSplashes.exists(note))
            return activeHoldSplashes.get(note);
        
        var splash = getSplash(strumX, strumY, note.noteData, null, HOLD_CONTINUOUS);
        splash.startContinuousSplash(strumX, strumY, note.noteData);
        
        activeHoldSplashes.set(note, splash);
        
        return splash;
    }
    
    /**
     * NUEVO: Detener splash continuo y crear splash de release
     */
    public function stopHoldSplash(note:Note, strumX:Float, strumY:Float):Void
    {
        if (!holdSplashesEnabled) return;
        
        // Detener splash continuo si existe
        if (activeHoldSplashes.exists(note))
        {
            var holdSplash = activeHoldSplashes.get(note);
            if (holdSplash != null)
            {
                holdSplash.stopContinuousSplash();
                recycleSplash(holdSplash);
            }
            activeHoldSplashes.remove(note);
        }
        
        // Crear splash de release (final)
        var releaseSplash = getSplash(strumX, strumY, note.noteData, null, HOLD_END);
    }
    
    /**
     * NUEVO: Update para gestionar splashes continuos
     */
    public function updateHoldSplashes():Void
    {
        // Limpiar splashes de notas que ya no existen
        var notesToRemove:Array<Note> = [];
        
        for (note in activeHoldSplashes.keys())
        {
            if (!note.exists || note.wasGoodHit || !note.alive)
            {
                notesToRemove.push(note);
            }
        }
        
        for (note in notesToRemove)
        {
            var splash = activeHoldSplashes.get(note);
            if (splash != null)
            {
                splash.stopContinuousSplash();
                recycleSplash(splash);
            }
            activeHoldSplashes.remove(note);
        }
    }
    
    /**
     * Reciclar splash
     */
    public function recycleSplash(splash:NoteSplash):Void
    {
        if (splash == null) return;
        
        try
        {
            splash.recycleSplash();
        }
        catch (e:Dynamic)
        {
            trace('[NoteRenderer] Error reciclando splash: ' + e);
        }
    }
    
    /**
     * NUEVO: Actualizar batcher
     */
    public function updateBatcher():Void
    {
        if (useBatching && noteBatcher != null)
        {
            noteBatcher.update(FlxG.elapsed);
        }
    }
    
    /**
     * Limpiar pools
     */
    public function clearPools():Void
    {
        // Limpiar hold splashes activos
        for (note in activeHoldSplashes.keys())
        {
            var splash = activeHoldSplashes.get(note);
            if (splash != null)
            {
                splash.stopContinuousSplash();
                splash.destroy();
            }
        }
        activeHoldSplashes.clear();
        
        // Limpiar note pool
        for (note in notePool)
        {
            if (note != null)
                note.destroy();
        }
        notePool = [];
        
        // Limpiar splash pool
        for (splash in splashPool)
        {
            if (splash != null)
                splash.destroy();
        }
        splashPool = [];
        
        // Limpiar batcher
        if (noteBatcher != null)
        {
            noteBatcher.clearBatches();
        }
        
        pooledNotes = 0;
        pooledSplashes = 0;
        createdNotes = 0;
        createdSplashes = 0;
        
        trace('[NoteRenderer] Pools limpiados');
    }
    
    /**
     * Obtener estadísticas completas
     */
    public function getPoolStats():String
    {
        var stats = 'Notes: ${notePool.length}/$maxPoolSize (pooled: $pooledNotes, created: $createdNotes)\n';
        stats += 'Splashes: ${splashPool.length}/$maxSplashPoolSize (pooled: $pooledSplashes, created: $createdSplashes)\n';
        stats += 'Active Hold Splashes: ${Lambda.count(activeHoldSplashes)}\n';
        
        if (useBatching && noteBatcher != null)
        {
            stats += '\n' + noteBatcher.getBatchStats();
        }
        
        return stats;
    }
    
    /**
     * NUEVO: Toggle batching
     */
    public function toggleBatching():Void
    {
        useBatching = !useBatching;
        
        if (useBatching && noteBatcher == null)
        {
            noteBatcher = new NoteBatcher();
        }
        
        trace('[NoteRenderer] Batching: $useBatching');
    }
    
    /**
     * NUEVO: Toggle hold splashes
     */
    public function toggleHoldSplashes():Void
    {
        holdSplashesEnabled = !holdSplashesEnabled;
        trace('[NoteRenderer] Hold Splashes: $holdSplashesEnabled');
    }
    
    /**
     * Destruir
     */
    public function destroy():Void
    {
        clearPools();
        
        if (noteBatcher != null)
        {
            noteBatcher.destroy();
            noteBatcher = null;
        }
        
        playerStrums = null;
        cpuStrums = null;
    }
}
