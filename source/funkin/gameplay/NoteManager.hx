package funkin.gameplay;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import funkin.gameplay.notes.Note;
import funkin.gameplay.notes.NoteRenderer;
import funkin.gameplay.notes.NoteSplash;
import funkin.gameplay.notes.StrumNote;
import funkin.gameplay.objects.StrumsGroup;
import funkin.data.Song.SwagSong;
import funkin.data.Conductor;
import funkin.gameplay.notes.NoteSkinSystem;

using StringTools;

/**
 * Datos crudos de una nota — sin FlxSprite, sin texturas, sin DisplayObject.
 * Solo primitivas (~50 bytes/nota). Los FlxSprite se crean on-demand en spawnNotes().
 */
typedef NoteRawData = {
    var strumTime:Float;
    var noteData:Int;
    var isSustainNote:Bool;
    var mustHitNote:Bool;
    var strumsGroupIndex:Int;
    var noteType:String;
    var sustainLength:Float;
}

class NoteManager
{
    // === GROUPS ===
    public var notes:FlxTypedGroup<Note>;
    public var splashes:FlxTypedGroup<NoteSplash>;

    // Datos crudos — solo primitivas, cero FlxSprites hasta spawnNotes()
    private var unspawnNotes:Array<NoteRawData> = [];
    private var _unspawnIdx:Int = 0;
    private var _prevSpawnedNote:Note = null;

    // === STRUMS ===
    private var playerStrums:FlxTypedGroup<FlxSprite>;
    private var cpuStrums:FlxTypedGroup<FlxSprite>;
    private var playerStrumsGroup:StrumsGroup;
    private var cpuStrumsGroup:StrumsGroup;
    private var allStrumsGroups:Array<StrumsGroup>;

    // OPTIMIZACIÓN: Caché de strums por dirección — evita forEach O(n) por nota por frame.
    // Antes: 20 notas × 1 forEach × 4 iteraciones = 80 iteraciones+closures/frame.
    // Ahora: lookup O(1) directo en el Map.
    private var _playerStrumCache:Map<Int, FlxSprite> = [];
    private var _cpuStrumCache:Map<Int, FlxSprite>    = [];
    private var _strumGroupCache:Map<Int, Map<Int, FlxSprite>> = [];

    // === RENDERER ===
    private var renderer:NoteRenderer;

    // === CONFIG ===
    public var strumLineY:Float = 50;
    public var downscroll:Bool  = false;
    public var middlescroll:Bool = false;
    private var songSpeed:Float  = 1.0;
    private static inline var CULL_DISTANCE:Float = 2000;
    private var _scrollSpeed:Float = 0.45;
    var downscrollOff:Float = 0;

    // === CALLBACKS ===
    public var onNoteMiss:Note->Void  = null;
    public var onCPUNoteHit:Note->Void = null;
    public var onNoteHit:Note->Void   = null;

    // Hold note tracking
    private var heldNotes:Map<Int, Note>     = new Map();
    private var holdStartTimes:Map<Int, Float> = new Map();

    public function new(notes:FlxTypedGroup<Note>, playerStrums:FlxTypedGroup<FlxSprite>,
            cpuStrums:FlxTypedGroup<FlxSprite>, splashes:FlxTypedGroup<NoteSplash>,
            ?playerStrumsGroup:StrumsGroup, ?cpuStrumsGroup:StrumsGroup,
            ?allStrumsGroups:Array<StrumsGroup>)
    {
        this.notes            = notes;
        this.playerStrums     = playerStrums;
        this.cpuStrums        = cpuStrums;
        this.splashes         = splashes;
        this.playerStrumsGroup = playerStrumsGroup;
        this.cpuStrumsGroup   = cpuStrumsGroup;
        this.allStrumsGroups  = allStrumsGroups;
        renderer = new NoteRenderer(notes, playerStrums, cpuStrums);

        _rebuildStrumCache();
    }

    /**
     * Reconstruye el caché de strums por dirección.
     * Llamar después de cualquier cambio en los grupos de strums.
     */
    public function _rebuildStrumCache():Void
    {
        _playerStrumCache = [];
        _cpuStrumCache    = [];
        _strumGroupCache  = [];

        if (playerStrums != null)
            playerStrums.forEach(function(s:FlxSprite) { _playerStrumCache.set(s.ID, s); });
        if (cpuStrums != null)
            cpuStrums.forEach(function(s:FlxSprite) { _cpuStrumCache.set(s.ID, s); });

        if (allStrumsGroups != null)
        {
            for (i in 0...allStrumsGroups.length)
            {
                var grp = allStrumsGroups[i];
                if (grp == null) continue;
                var map:Map<Int, FlxSprite> = [];
                // StrumsGroup tiene getStrum(dir) — iteramos las 4 direcciones estándar
                for (dir in 0...4)
                {
                    var s = grp.getStrum(dir);
                    if (s != null) map.set(dir, s);
                }
                _strumGroupCache.set(i, map);
            }
        }
    }

    /**
     * Genera SOLO datos crudos desde SONG data — cero FlxSprites instanciados.
     */
    public function generateNotes(SONG:SwagSong):Void
    {
        unspawnNotes     = [];
        _unspawnIdx      = 0;
        _prevSpawnedNote = null;
        songSpeed        = SONG.speed;
        _scrollSpeed     = 0.45 * FlxMath.roundDecimal(songSpeed, 2);

        for (section in SONG.notes)
        {
            for (songNotes in section.sectionNotes)
            {
                var daStrumTime:Float = songNotes[0];
                var rawNoteData:Int   = Std.int(songNotes[1]);
                var daNoteData:Int    = rawNoteData % 4;
                var groupIdx:Int      = Math.floor(rawNoteData / 4);

                var gottaHitNote:Bool;
                if (allStrumsGroups != null && groupIdx < allStrumsGroups.length && groupIdx >= 2)
                    gottaHitNote = !allStrumsGroups[groupIdx].isCPU;
                else
                {
                    gottaHitNote = section.mustHitSection;
                    if (groupIdx == 1) gottaHitNote = !section.mustHitSection;
                }

                var noteType:String = (songNotes.length > 3 && songNotes[3] != null) ? Std.string(songNotes[3]) : '';
                var susLength:Float = songNotes[2];

                unspawnNotes.push({
                    strumTime: daStrumTime, noteData: daNoteData,
                    isSustainNote: false, mustHitNote: gottaHitNote,
                    strumsGroupIndex: groupIdx, noteType: noteType,
                    sustainLength: susLength
                });

                if (susLength > 0)
                {
                    var floorSus:Int = Math.floor(susLength / Conductor.stepCrochet);
                    for (susNote in 0...floorSus)
                    {
                        unspawnNotes.push({
                            strumTime: daStrumTime + (Conductor.stepCrochet * susNote) + Conductor.stepCrochet,
                            noteData: daNoteData, isSustainNote: true,
                            mustHitNote: gottaHitNote, strumsGroupIndex: groupIdx,
                            noteType: noteType, sustainLength: 0
                        });
                    }
                }
            }
        }

        unspawnNotes.sort((a, b) -> Std.int(a.strumTime - b.strumTime));
        trace('[NoteManager] ${unspawnNotes.length} notas en cola (datos crudos)');
    }

    public function update(songPosition:Float):Void
    {
        spawnNotes(songPosition);
        updateActiveNotes(songPosition);
        updateStrumAnimations();
        if (renderer != null) { renderer.updateBatcher(); renderer.updateHoldSplashes(); }
    }

    private function spawnNotes(songPosition:Float):Void
    {
        final spawnTime:Float = 1800 / songSpeed;
        while (_unspawnIdx < unspawnNotes.length &&
               unspawnNotes[_unspawnIdx].strumTime - songPosition < spawnTime)
        {
            final raw = unspawnNotes[_unspawnIdx++];

            final note = renderer.getNote(raw.strumTime, raw.noteData, _prevSpawnedNote,
                                          raw.isSustainNote, raw.mustHitNote);
            note.strumsGroupIndex = raw.strumsGroupIndex;
            note.noteType         = raw.noteType;
            note.sustainLength    = raw.sustainLength;
            note.visible = true;
            note.active  = true;
            note.alpha   = raw.isSustainNote ? 0.6 : 1.0;

            _prevSpawnedNote = note;
            notes.add(note);

            // OPTIMIZACIÓN: compactar solo cuando el array sea grande Y el puntero
            // supere el 75% — evita el splice O(n) frecuente de antes (era al 50%).
            if (_unspawnIdx > 1024 && _unspawnIdx >= (unspawnNotes.length >> 1) + (unspawnNotes.length >> 2))
            {
                unspawnNotes.splice(0, _unspawnIdx);
                _unspawnIdx = 0;
            }
        }
    }

    private function updateActiveNotes(songPosition:Float):Void
    {
        final members = notes.members;
        final len     = members.length;
        // Precalcular hitWindow una vez por frame, no una vez por nota
        final hitWindow:Float = Conductor.safeZoneOffset;

        for (i in 0...len)
        {
            final note = members[i];
            if (note == null || !note.alive) continue;

            updateNotePosition(note, songPosition);

            // ── CPU notes ──────────────────────────────────────────────────
            if (!note.mustPress && note.strumTime <= songPosition)
            {
                handleCPUNote(note);
                continue;
            }

            // ── MISS: nota del jugador que pasó la ventana ─────────────────
            // BUG ANTERIOR: tooLate se marcaba pero nunca se llamaba missNote().
            // La nota simplemente desaparecía al salirse de pantalla via
            // shouldRemoveNote → removeNote, sin disparar onNoteMiss.
            //
            // FIX (inspirado en Codename): detectar tooLate inmediatamente
            // y llamar missNote(), que dispara onNoteMiss, aplica penalización
            // y recicla la nota al pool. Sin esperar a que salga de pantalla.
            if (note.mustPress && !note.wasGoodHit)
            {
                // note.tooLate puede ser true por Note.update() (hitWindowCache)
                // o por la comprobación de aquí abajo con safeZoneOffset
                if (note.tooLate || songPosition > note.strumTime + hitWindow)
                {
                    note.tooLate = true; // asegurar que quede marcada
                    missNote(note);
                    continue;
                }
            }

            // ── Visibilidad y culling ──────────────────────────────────────
            if (note.y < -CULL_DISTANCE || note.y > FlxG.height + CULL_DISTANCE)
                note.visible = false;
            else
            {
                note.visible = true;
                if (!note.mustPress && middlescroll) note.alpha = 0;
            }
        }
    }

    private function handleCPUNote(note:Note):Void
    {
        note.wasGoodHit = true;
        if (onCPUNoteHit != null) onCPUNoteHit(note);
        handleStrumAnimation(note.noteData, note.strumsGroupIndex, false);
        if (!note.isSustainNote && !FlxG.save.data.middlescroll && FlxG.save.data.notesplashes)
            createNormalSplash(note, false);
        removeNote(note);
    }

    private function updateStrumAnimations():Void
    {
        _resetStrumsGroup(cpuStrums);
        _resetStrumsGroup(playerStrums);
    }

    private static inline function _resetStrumsGroup(group:FlxTypedGroup<FlxSprite>):Void
    {
        if (group == null) return;
        final members = group.members;
        final len     = members.length;
        for (i in 0...len)
        {
            final strum = members[i];
            if (strum == null || !strum.alive) continue;
            final strumNote = cast(strum, funkin.gameplay.notes.StrumNote);
            if (strumNote != null
                && strumNote.animation.curAnim != null
                && strumNote.animation.curAnim.name.startsWith('confirm')
                && strumNote.animation.curAnim.finished)
                strumNote.playAnim('static');
        }
    }

    private function handleStrumAnimation(noteData:Int, groupIndex:Int, isPlayer:Bool):Void
    {
        var strum = getStrumForDirection(noteData, groupIndex, isPlayer);
        if (strum != null)
        {
            var strumNote = cast(strum, funkin.gameplay.notes.StrumNote);
            if (strumNote != null) strumNote.playAnim('confirm', true);
        }
    }

    private function updateNotePosition(note:Note, songPosition:Float):Void
    {
        var noteY:Float;
        if (downscroll)
            noteY = strumLineY + (songPosition - note.strumTime) * _scrollSpeed;
        else
            noteY = strumLineY - (songPosition - note.strumTime) * _scrollSpeed;
        note.y = noteY;

        var strum = getStrumForDirection(note.noteData, note.strumsGroupIndex, note.mustPress);
        if (strum != null)
        {
            note.angle   = strum.angle;
            note.scale.x = strum.scale.x;
            if (!note.isSustainNote) note.scale.y = strum.scale.y;
            note.updateHitbox();
            if (!note.isSustainNote)
                note.alpha = FlxMath.bound(strum.alpha, 0.05, 1.0);
            else
                note.alpha = FlxMath.bound(strum.alpha, 0.05, 0.7);
            note.x = strum.x + (strum.width - note.width) / 2;
        }

        if (note.isSustainNote && downscroll && !note.mustPress)
        {
            var strumLineThreshold = (strumLineY + Note.swagWidth / 2);
            var noteEndPos = note.y - note.offset.y * note.scale.y + note.height;
            if (noteEndPos >= strumLineThreshold)
            {
                var clipRect = note.clipRect;
                if (clipRect == null) clipRect = new flixel.math.FlxRect();
                clipRect.width  = note.frameWidth * 2;
                clipRect.height = (strumLineThreshold - note.y) / note.scale.y;
                if (FlxG.save.data.downscroll) downscrollOff = 10;
                clipRect.y = note.frameHeight - clipRect.height + downscrollOff;
                note.clipRect = clipRect;
            }
        }
    }

    private function removeNote(note:Note):Void
    {
        note.kill();
        notes.remove(note, true);
        if (renderer != null) renderer.recycleNote(note);
    }

    public function hitNote(note:Note, rating:String):Void
    {
        if (note.wasGoodHit) return;
        note.wasGoodHit = true;
        handleStrumAnimation(note.noteData, note.strumsGroupIndex, true);
        if (rating == "sick")
        {
            if (note.isSustainNote) handleSustainNoteHit(note);
            else createNormalSplash(note, true);
        }
        removeNote(note);
        if (onNoteHit != null) onNoteHit(note);
    }

    private function handleSustainNoteHit(note:Note):Void
    {
        var direction = note.noteData;
        if (!heldNotes.exists(direction))
        {
            heldNotes.set(direction, note);
            holdStartTimes.set(direction, Conductor.songPosition);
            var strum = getStrumForDirection(direction, note.strumsGroupIndex, true);
            if (strum != null && renderer != null)
            {
                var splash = renderer.createHoldStartSplash(note, strum.x, strum.y);
                if (splash != null) splashes.add(splash);
                var cont = renderer.startHoldContinuousSplash(note, strum.x, strum.y);
                if (cont != null) splashes.add(cont);
            }
        }
        // No llamar removeNote aquí — hitNote() ya lo hace después
    }

    public function releaseHoldNote(direction:Int):Void
    {
        if (!heldNotes.exists(direction)) return;
        var note  = heldNotes.get(direction);
        var strum = getStrumForDirection(direction, note.strumsGroupIndex, true);
        if (strum != null && renderer != null) renderer.stopHoldSplash(note, strum.x, strum.y);
        heldNotes.remove(direction);
        holdStartTimes.remove(direction);
    }

    private function createNormalSplash(note:Note, isPlayer:Bool):Void
    {
        if (renderer == null) return;
        var strum = getStrumForDirection(note.noteData, note.strumsGroupIndex, isPlayer);
        if (strum != null)
        {
            var splash = renderer.getSplash(strum.x, strum.y, note.noteData);
            if (splash != null) splashes.add(splash);
        }
    }

    /**
     * Obtiene el strum para una dirección dada.
     * OPTIMIZADO: usa caché Map<Int, FlxSprite> para O(1) en vez de forEach O(n).
     * El forEach anterior creaba una closure nueva cada llamada — ahora es solo
     * un Map lookup. Con 20 notas en pantalla esto elimina ~80 closures por frame.
     */
    private function getStrumForDirection(direction:Int, strumsGroupIndex:Int, isPlayer:Bool):FlxSprite
    {
        // Grupos adicionales (strumsGroupIndex >= 2) — caché por grupo
        if (allStrumsGroups != null && allStrumsGroups.length > 0 && strumsGroupIndex >= 2)
        {
            var groupMap = _strumGroupCache.get(strumsGroupIndex);
            if (groupMap != null) return groupMap.get(direction);
        }

        // Grupos 0 y 1 — caché por dirección
        return isPlayer ? _playerStrumCache.get(direction) : _cpuStrumCache.get(direction);
    }

    public function missNote(note:Note):Void
    {
        if (note == null || note.wasGoodHit) return;
        if (heldNotes.exists(note.noteData)) releaseHoldNote(note.noteData);
        if (onNoteMiss != null) onNoteMiss(note);
        removeNote(note);
    }

    public function destroy():Void
    {
        unspawnNotes     = [];
        _unspawnIdx      = 0;
        _prevSpawnedNote = null;
        heldNotes.clear();
        holdStartTimes.clear();
        _playerStrumCache = [];
        _cpuStrumCache    = [];
        _strumGroupCache  = [];
        if (renderer != null) { renderer.clearPools(); renderer.destroy(); }
    }

    public function getPoolStats():String
        return renderer != null ? renderer.getPoolStats() : "No renderer";

    public function toggleBatching():Void
        if (renderer != null) renderer.toggleBatching();

    public function toggleHoldSplashes():Void
        if (renderer != null) renderer.toggleHoldSplashes();
}
