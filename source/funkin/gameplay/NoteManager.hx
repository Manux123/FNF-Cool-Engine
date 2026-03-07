package funkin.gameplay;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import funkin.gameplay.notes.Note;
import funkin.gameplay.notes.NoteRenderer;
import funkin.gameplay.notes.NoteSplash;
import funkin.gameplay.notes.NoteHoldCover;
import funkin.gameplay.notes.StrumNote;
import funkin.gameplay.objects.StrumsGroup;
import funkin.data.Song.SwagSong;
import funkin.data.Conductor;
import funkin.gameplay.notes.NoteSkinSystem;
import funkin.gameplay.modchart.ModChartManager;
import funkin.gameplay.modchart.ModChartEvent;

using StringTools;

/**
 * Datos crudos de una nota — sin FlxSprite, sin texturas, sin DisplayObject.
 * Solo primitivas (~50 bytes/nota). Los FlxSprite se crean on-demand en spawnNotes().
 */
typedef NoteRawData =
{
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
	/** Grupo separado para notas sustain — se dibuja DEBAJO de notes para que
	 *  las notas normales siempre aparezcan por encima de los holds. */
	public var sustainNotes:FlxTypedGroup<Note>;
	public var splashes:FlxTypedGroup<NoteSplash>;
	public var holdCovers:FlxTypedGroup<NoteHoldCover>;

	// Datos crudos — solo primitivas, cero FlxSprites hasta spawnNotes()
	private var unspawnNotes:Array<NoteRawData> = [];
	private var _unspawnIdx:Int = 0;
	// BUGFIX: trackeado por dirección para evitar cross-chain en holds simultáneos
	private var _prevSpawnedNote:Map<Int, Note> = new Map();

	/** Calcula la clave del mapa _prevSpawnedNote combinando dirección y grupo de strums.
	 *  noteData 0-3, strumsGroupIndex 0-N → clave única por grupo de strums.
	 *  Necesario para que notas de distintos personajes/grupos en la misma
	 *  dirección no compartan entrada y corrompan la cadena prevNote de los sustains. */
	private inline function _prevNoteKey(noteData:Int, strumsGroupIndex:Int):Int
		return noteData + strumsGroupIndex * 4;

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
	private var _cpuStrumCache:Map<Int, FlxSprite> = [];
	private var _strumGroupCache:Map<Int, Map<Int, FlxSprite>> = [];

	// === RENDERER ===
	public var renderer:NoteRenderer;

	// === CONFIG ===
	public var strumLineY:Float = 50;
	public var downscroll:Bool = false;
	public var middlescroll:Bool = false;

	private var songSpeed:Float = 1.0;

	/**
	 * Referencia al ModChartManager activo (si hay modchart cargado).
	 * PlayState la asigna en create() después de crear el ModChartManager.
	 * NoteManager la usa en updateNotePosition() para aplicar modificadores per-nota.
	 */
	public var modManager:Null<ModChartManager> = null;

	private static inline var CULL_DISTANCE:Float = 2000;

	private var _scrollSpeed:Float = 0.45;
	var downscrollOff:Float = 0;

	// === SAVE.DATA CACHE (evita acceso Dynamic en hot loop) ===
	// Se actualizan en generateNotes() y cuando cambia la configuración.
	private var _cachedNoteSplashes:Bool = false;
	private var _cachedDownscroll:Bool = false;
	private var _cachedMiddlescroll:Bool = false;

	/** Actualiza el caché de opciones del jugador. Llamar si el jugador cambia config. */
	public function refreshSaveDataCache():Void {
		_cachedNoteSplashes  = FlxG.save.data.notesplashes == true;
		_cachedDownscroll    = FlxG.save.data.downscroll   == true;
		_cachedMiddlescroll  = FlxG.save.data.middlescroll == true;
	}

	// === CALLBACKS ===
	public var onNoteMiss:Note->Void = null;
	public var onCPUNoteHit:Note->Void = null;
	public var onNoteHit:Note->Void = null;

	// Hold note tracking
	private var heldNotes:Map<Int, Note> = new Map();
	private var holdStartTimes:Map<Int, Float> = new Map();
	/**
	 * Tiempo exacto en que termina cada hold por dirección.
	 * Calculado al golpear el head note: headNote.strumTime + headNote.sustainLength.
	 * Comparar con songPosition cada frame para disparar playEnd() puntualmente.
	 */
	private var holdEndTimes:Map<Int, Float> = new Map();
	/** Mismo para CPU (por dirección 0-3). */
	private var cpuHoldEndTimes:Array<Float> = [-1, -1, -1, -1];

	/**
	 * Estado de teclas presionadas — actualizado desde PlayState cada frame
	 * (inputHandler.held[0..3]).  Usado para distinguir si un sustain está
	 * siendo mantenido o fue soltado antes de tiempo.
	 */
	public var playerHeld:Array<Bool> = [false, false, false, false];

	/**
	 * Direcciones (0-3) cuyos sustains ya contaron un miss este ciclo.
	 * OPTIMIZADO: Bool[4] en lugar de Map<Int,Bool> — elimina allocs de Map.clear()
	 * que ocurrían 60 veces/seg. Map.clear() en Haxe/C++ resetea el hashmap interno
	 * y puede hacer pequeñas allocations. Array fijo es O(1) set y O(1) clear.
	 */
	private var _missedHoldDir:Array<Bool> = [false, false, false, false];

	/** Buffer preallocado para autoReleaseFinishedHolds — cero allocs por frame */
	private var _autoReleaseBuffer:Array<Int> = [];

	/**
	 * Tracking de qué direcciones está "manteniendo" el CPU (para hold covers).
	 * OPTIMIZADO: Bool[4] en lugar de Map<Int,Bool> — mismo razonamiento que _missedHoldDir.
	 */
	private var _cpuHeldDirs:Array<Bool> = [false, false, false, false];

	/**
	 * Set de NoteHoldCovers ya añadidos al grupo holdCovers.
	 * OPTIMIZADO: reemplaza holdCovers.members.indexOf(cover) O(n) con lookup O(1).
	 * indexOf se llamaba en cada nota de hold activa (cada frame CPU hit) — con
	 * canciones densas esto se suma rápidamente.
	 */
	private var _holdCoverSet:haxe.ds.ObjectMap<NoteHoldCover, Bool> = new haxe.ds.ObjectMap();

	/** ClipRect reutilizable para sustains en downscroll — elimina `new FlxRect()` por frame */
	private var _sustainClipRect:flixel.math.FlxRect = new flixel.math.FlxRect();

	public function new(notes:FlxTypedGroup<Note>, playerStrums:FlxTypedGroup<FlxSprite>, cpuStrums:FlxTypedGroup<FlxSprite>,
			splashes:FlxTypedGroup<NoteSplash>, holdCovers:FlxTypedGroup<NoteHoldCover>, ?playerStrumsGroup:StrumsGroup, ?cpuStrumsGroup:StrumsGroup, ?allStrumsGroups:Array<StrumsGroup>,
			?sustainNotes:FlxTypedGroup<Note>)
	{
		this.notes = notes;
		this.sustainNotes = sustainNotes != null ? sustainNotes : notes; // fallback: usar mismo grupo si no se pasa
		this.playerStrums = playerStrums;
		this.cpuStrums = cpuStrums;
		this.splashes = splashes;
		this.holdCovers = holdCovers;
		this.playerStrumsGroup = playerStrumsGroup;
		this.cpuStrumsGroup = cpuStrumsGroup;
		this.allStrumsGroups = allStrumsGroups;
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
		_cpuStrumCache = [];
		_strumGroupCache = [];

		if (playerStrums != null)
			playerStrums.forEach(function(s:FlxSprite)
			{
				_playerStrumCache.set(s.ID, s);
			});
		if (cpuStrums != null)
			cpuStrums.forEach(function(s:FlxSprite)
			{
				_cpuStrumCache.set(s.ID, s);
			});

		if (allStrumsGroups != null)
		{
			for (i in 0...allStrumsGroups.length)
			{
				var grp = allStrumsGroups[i];
				if (grp == null)
					continue;
				var map:Map<Int, FlxSprite> = [];
				// StrumsGroup tiene getStrum(dir) — iteramos las 4 direcciones estándar
				for (dir in 0...4)
				{
					var s = grp.getStrum(dir);
					if (s != null)
						map.set(dir, s);
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
		_unspawnIdx = 0;
		_prevSpawnedNote.clear();
		songSpeed = SONG.speed;
		_scrollSpeed = 0.45 * FlxMath.roundDecimal(songSpeed, 2);

		// Cachear opciones del jugador ahora — se usan en el hot loop de notas
		refreshSaveDataCache();

		// ── v2: pre-calcular capacidad total para evitar resizes del array ────
		// Cada push() que supera la capacidad interna copia el array completo.
		// En canciones con 800+ notas esto causaba ~12 copias durante la generación.
		var noteCount:Int = 0;
		for (section in SONG.notes)
			for (songNotes in section.sectionNotes)
			{
				noteCount++;
				var susLength:Float = songNotes[2];
				if (susLength > 0)
					noteCount += Math.floor(susLength / Conductor.stepCrochet);
			}

		// Pre-reservar: llenar con nulls tipados para reservar memoria interna,
		// luego truncar a 0 sin liberar. Los push() posteriores no reasignan.
		var _preAlloc:Array<Null<NoteRawData>> = [for (_ in 0...noteCount) null];
		unspawnNotes = cast _preAlloc;
		#if (cpp || hl)
		unspawnNotes.resize(0);
		#else
		unspawnNotes = [];
		#end

		for (section in SONG.notes)
		{
			for (songNotes in section.sectionNotes)
			{
				var daStrumTime:Float = songNotes[0];
				var rawNoteData:Int = Std.int(songNotes[1]);
				var daNoteData:Int = rawNoteData % 4;
				var groupIdx:Int = Math.floor(rawNoteData / 4);

				var gottaHitNote:Bool;
				if (allStrumsGroups != null && groupIdx < allStrumsGroups.length && groupIdx >= 2)
					gottaHitNote = !allStrumsGroups[groupIdx].isCPU;
				else
				{
					gottaHitNote = section.mustHitSection;
					if (groupIdx == 1)
						gottaHitNote = !section.mustHitSection;
				}

				var noteType:String = (songNotes.length > 3 && songNotes[3] != null) ? Std.string(songNotes[3]) : '';
				var susLength:Float = songNotes[2];

				unspawnNotes.push({
					strumTime: daStrumTime,
					noteData: daNoteData,
					isSustainNote: false,
					mustHitNote: gottaHitNote,
					strumsGroupIndex: groupIdx,
					noteType: noteType,
					sustainLength: susLength
				});

				if (susLength > 0)
				{
					var floorSus:Int = Math.floor(susLength / Conductor.stepCrochet);
					for (susNote in 0...floorSus)
					{
						unspawnNotes.push({
							strumTime: daStrumTime + (Conductor.stepCrochet * susNote) + Conductor.stepCrochet,
							noteData: daNoteData,
							isSustainNote: true,
							mustHitNote: gottaHitNote,
							strumsGroupIndex: groupIdx,
							noteType: noteType,
							sustainLength: 0
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
		autoReleaseFinishedHolds();
		if (renderer != null)
		{
			renderer.updateBatcher();
			renderer.updateHoldCovers();
		}
	}

	/**
	 * Libera holds cuyas piezas de sustain ya se consumieron.
	 * IMPORTANTE: revisa tanto notes.members (spawneadas) como unspawnNotes
	 * (futuras). Sin el check de unspawnNotes, holds largos se liberaban
	 * prematuramente porque las piezas futuras aún no estaban en el grupo.
	 */
	/**
	 * Libera holds cuyo tiempo de fin (strumTime + sustainLength del head note)
	 * ya fue alcanzado por songPosition.
	 *
	 * FIX: antes usaba _hasPendingSustain que esperaba a que las notas salieran
	 * de pantalla. Ahora usamos el tiempo exacto de fin, que es conocido desde
	 * que golpeamos el head note. Esto dispara playEnd() en el momento correcto.
	 */
	private function autoReleaseFinishedHolds():Void
	{
		final songPos = Conductor.songPosition;

		// ── Jugador ──────────────────────────────────────────────────────────
		if (heldNotes.keys().hasNext())
		{
			_autoReleaseBuffer.resize(0);
			for (dir in heldNotes.keys())
			{
				// Usar holdEndTime si está disponible; fallback a _hasPendingSustain
				var shouldRelease:Bool;
				if (holdEndTimes.exists(dir))
					shouldRelease = songPos >= holdEndTimes.get(dir);
				else
					shouldRelease = !_hasPendingSustain(dir, true, sustainNotes.members, sustainNotes.members.length);
				if (shouldRelease)
					_autoReleaseBuffer.push(dir);
			}
			for (dir in _autoReleaseBuffer)
				releaseHoldNote(dir);
		}

		// ── CPU ──────────────────────────────────────────────────────────────
		var _anyCpuHeld = false;
		for (d in 0...4) if (_cpuHeldDirs[d]) { _anyCpuHeld = true; break; }
		if (_anyCpuHeld)
		{
			_autoReleaseBuffer.resize(0);
			for (dir in 0...4)
			{
				if (!_cpuHeldDirs[dir]) continue;
				var shouldRelease:Bool;
				if (cpuHoldEndTimes[dir] >= 0)
					shouldRelease = songPos >= cpuHoldEndTimes[dir];
				else
					shouldRelease = !_hasPendingSustain(dir, false, sustainNotes.members, sustainNotes.members.length);
				if (shouldRelease) _autoReleaseBuffer.push(dir);
			}
			for (dir in _autoReleaseBuffer)
			{
				if (renderer != null) renderer.stopHoldCover(dir, false);
				_cpuHeldDirs[dir] = false;
				cpuHoldEndTimes[dir] = -1;
			}
		}
	}

	/**
	 * Devuelve true si quedan piezas de sustain pendientes para una dirección,
	 * buscando tanto en las notas ya spawneadas como en las futuras (unspawnNotes).
	 * Sin revisar unspawnNotes, los holds largos se liberaban prematuramente.
	 */
	/**
	 * Devuelve true si quedan piezas de sustain AÚN NO COMPLETADAS para esta dirección.
	 *
	 * FIX: antes comprobaba `n.alive` y esperaba a que los sustains se salieran de pantalla.
	 * Ahora comprueba `!n.wasGoodHit && !n.tooLate` — la hold termina en cuanto la última
	 * pieza de sustain cruza la ventana de hit (wasGoodHit=true), no cuando sale de pantalla.
	 * Esto dispara la animación de fin del hold cover en el momento correcto.
	 */
	private function _hasPendingSustain(dir:Int, isPlayer:Bool, members:Array<Note>, len:Int):Bool
	{
		// 1. Notas spawneadas: pendientes = vivas, aún no golpeadas y no perdidas
		for (i in 0...len)
		{
			final n = members[i];
			if (n != null && n.alive && n.isSustainNote && n.noteData == dir
				&& n.mustPress == isPlayer && !n.wasGoodHit && !n.tooLate)
				return true;
		}
		// 2. Notas futuras aún no spawneadas — CRÍTICO para holds largos
		for (i in _unspawnIdx...unspawnNotes.length)
		{
			final raw = unspawnNotes[i];
			if (raw.isSustainNote && raw.noteData == dir && raw.mustHitNote == isPlayer)
				return true;
		}
		return false;
	}

	private function spawnNotes(songPosition:Float):Void
	{
		final spawnTime:Float = 1800 / songSpeed;
		while (_unspawnIdx < unspawnNotes.length && unspawnNotes[_unspawnIdx].strumTime - songPosition < spawnTime)
		{
			final raw = unspawnNotes[_unspawnIdx++];

			final _pnKey = _prevNoteKey(raw.noteData, raw.strumsGroupIndex);
			final note = renderer.getNote(raw.strumTime, raw.noteData, _prevSpawnedNote.get(_pnKey), raw.isSustainNote, raw.mustHitNote);
			note.strumsGroupIndex = raw.strumsGroupIndex;
			note.noteType = raw.noteType;
			note.sustainLength = raw.sustainLength;
			note.visible = true;
			note.active = true;
			note.alpha = raw.isSustainNote ? 0.6 : 1.0;

			_prevSpawnedNote.set(_pnKey, note);
			// Sustain notes van al grupo separado (se dibuja ANTES que notes →
			// las notas normales siempre quedan por encima visualmente).
			if (raw.isSustainNote)
				sustainNotes.add(note);
			else
				notes.add(note);
			// Sin splice: el array NoteRawData es ~50 bytes/nota (trivial en RAM).
			// El splice O(n) causaba un hiccup visible al 75% de la canción.
		}
	}

	private function updateActiveNotes(songPosition:Float):Void
	{
		final hitWindow:Float = Conductor.safeZoneOffset;

		// Limpiar el set de miss-por-hold al inicio de cada frame
		// OPTIMIZADO: asignación directa × 4 vs Map.clear() que rehashea internamente
		_missedHoldDir[0] = false;
		_missedHoldDir[1] = false;
		_missedHoldDir[2] = false;
		_missedHoldDir[3] = false;

		// Iterar ambos grupos: primero sustains, luego notas normales
		_updateNoteGroup(sustainNotes.members, sustainNotes.members.length, songPosition, hitWindow);
		// Evitar doble-iteración si sustainNotes apunta al mismo objeto que notes (fallback)
		if (sustainNotes != notes)
			_updateNoteGroup(notes.members, notes.members.length, songPosition, hitWindow);
	}

	private inline function _updateNoteGroup(members:Array<Note>, len:Int, songPosition:Float, hitWindow:Float):Void
	{
		for (i in 0...len)
		{
			final note = members[i];
			if (note == null || !note.alive)
				continue;

			updateNotePosition(note, songPosition);

			// ── CPU notes ──────────────────────────────────────────────────
			if (!note.mustPress && note.strumTime <= songPosition)
			{
				handleCPUNote(note);
				continue;
			}

			// ── Notas del jugador ──────────────────────────────────────────
			if (note.mustPress && !note.wasGoodHit)
			{
				// ── SUSTAIN NOTES: lógica especial ─────────────────────────
				// Los sustains NO se eliminan por ventana de tiempo como las
				// notas normales.  Solo se eliminan si:
				//   a) La tecla está mantenida  → se procesan como hit en processSustains()
				//   b) La tecla NO está mantenida Y el strumTime ya pasó → miss (fade)
				//
				// FIX del bug "notas largas se rompen al final":
				//   El bug ocurría porque los sustains del jugador entraban en el
				//   mismo bloque de miss que las notas normales y se eliminaban
				//   pieza a pieza cuando el strumTime superaba hitWindow.
				if (note.isSustainNote)
				{
					if (songPosition > note.strumTime + hitWindow)
					{
						var dir = note.noteData;
						if (playerHeld[dir])
						{
							// Tecla mantenida: marcar como golpeada pero NO eliminar todavía.
							// Dejamos que el clipRect oculte la pieza suavemente mientras scrollea
							// más allá del strum, evitando el efecto de trozos que desaparecen.
							// Se eliminará en culling cuando salga completamente de pantalla.
							note.wasGoodHit = true;
							// Arrancar hold cover si todavía no se hizo (esta pieza pasó
							// el hitWindow sin pasar por processSustains/hitNote).
							handleSustainNoteHit(note);
						}
						else
						{
							// Tecla soltada: fallar el sustain
							// Desvanecer la nota en lugar de eliminarla (feedback visual)
							note.alpha = 0.2;
							note.tooLate = true;

							// Contar UN miss por grupo de hold, no uno por pieza
							if (!_missedHoldDir[dir])
							{
								_missedHoldDir[dir] = true;
								if (onNoteMiss != null)
									onNoteMiss(note);
							}
							// Eliminar la pieza desvanecida después de que pasa de pantalla
							removeNote(note);
						}
					}
					// Si strumTime todavía no pasó, no hacer nada — processSustains() lo maneja
					continue;
				}

				// ── NOTAS NORMALES: miss si pasan la ventana ───────────────
				if (note.tooLate || songPosition > note.strumTime + hitWindow)
				{
					note.tooLate = true;
					missNote(note);
					continue;
				}
			}

			// ── Visibilidad y culling ──────────────────────────────────────
			if (note.y < -CULL_DISTANCE || note.y > FlxG.height + CULL_DISTANCE)
			{
				note.visible = false;
				// Eliminar sustains consumidas que ya salieron de pantalla
				if (note.isSustainNote && note.wasGoodHit)
					removeNote(note);
			}
			else
			{
				// No sobrescribir visible=false de sustains consumidas ocultas por clipRect
				if (!(note.isSustainNote && note.wasGoodHit))
					note.visible = true;
				if (!note.mustPress && middlescroll)
					note.alpha = 0;
			}
		}
	}

	private function handleCPUNote(note:Note):Void
	{
		note.wasGoodHit = true;
		if (onCPUNoteHit != null)
			onCPUNoteHit(note);
		// Solo animar el strum en la nota cabeza, NO en las piezas de sustain.
		handleStrumAnimation(note.noteData, note.strumsGroupIndex, false);
		// Guardar tiempo de fin del hold para la CPU al golpear el HEAD note
		if (!note.isSustainNote && note.sustainLength > 0)
			cpuHoldEndTimes[note.noteData] = note.strumTime + note.sustainLength;/*
		if (!note.isSustainNote && !_cachedMiddlescroll && _cachedNoteSplashes && renderer != null)
			createNormalSplash(note, false);*/
		// Hold covers para CPU: solo en la primera pieza de sustain
		if (note.isSustainNote && !_cachedMiddlescroll && _cachedNoteSplashes && renderer != null)
		{
			var dir = note.noteData;
			if (!_cpuHeldDirs[dir])
			{
				_cpuHeldDirs[dir] = true;
				var strum = getStrumForDirection(dir, note.strumsGroupIndex, false);
				if (strum != null)
				{
					var cover = renderer.startHoldCover(dir, strum.x - strum.offset.x + strum.frameWidth * 0.5, strum.y - strum.offset.y + strum.frameHeight * 0.5, false);
					if (cover != null && !_holdCoverSet.exists(cover) && holdCovers.members.indexOf(cover) < 0) {
						_holdCoverSet.set(cover, true);
						holdCovers.add(cover);
					}
				}
			}
		}

		removeNote(note);
	}

	private function updateStrumAnimations():Void
	{
		_resetStrumsGroup(cpuStrums);
		_resetStrumsGroup(playerStrums);
	}

	private static inline function _resetStrumsGroup(group:FlxTypedGroup<FlxSprite>):Void
	{
		if (group == null)
			return;
		final members = group.members;
		final len = members.length;
		for (i in 0...len)
		{
			final strum = members[i];
			if (strum == null || !strum.alive)
				continue;
			final strumNote = cast(strum, funkin.gameplay.notes.StrumNote);
			if (strumNote == null) continue;
			final anim = strumNote.animation.curAnim;
			// OPT: comparar primer char 'c' antes de llamar startsWith (evita scan completo)
			// En la mayoria de frames el anim es 'static', que falla en el primer char.
			if (anim != null && anim.finished
				&& anim.name.length >= 7
				&& anim.name.charCodeAt(0) == 99 // 'c' de 'confirm'
				&& anim.name.startsWith('confirm'))
				strumNote.playAnim('static');
		}
	}

	private function handleStrumAnimation(noteData:Int, groupIndex:Int, isPlayer:Bool):Void
	{
		var strum = getStrumForDirection(noteData, groupIndex, isPlayer);
		if (strum != null)
		{
			var strumNote = cast(strum, funkin.gameplay.notes.StrumNote);
			if (strumNote != null)
				strumNote.playAnim('confirm', true);
		}
	}

	private function updateNotePosition(note:Note, songPosition:Float):Void
	{
		// ── Leer modificadores per-nota del ModChartManager (si existe) ────────
		var _modState:funkin.gameplay.modchart.StrumState = null;
		if (modManager != null && modManager.enabled)
		{
			// Resolver el groupId a partir del strumsGroupIndex de la nota
			var _groupId:String = null;
			if (allStrumsGroups != null && note.strumsGroupIndex < allStrumsGroups.length)
				_groupId = allStrumsGroups[note.strumsGroupIndex].id;
			if (_groupId == null)
				_groupId = note.mustPress ? "player" : "cpu";
			_modState = modManager.getState(_groupId, note.noteData);
		}

		// ── Scroll speed con multiplicador per-strum ────────────────────────────
		final _scrollMult:Float = (_modState != null) ? _modState.scrollMult : 1.0;
		final _effectiveSpeed:Float = _scrollSpeed * _scrollMult;

		var noteY:Float;
		if (downscroll)
			noteY = strumLineY + (songPosition - note.strumTime) * _effectiveSpeed;
		else
			noteY = strumLineY - (songPosition - note.strumTime) * _effectiveSpeed;

		// Para notas normales, Y es directo
		if (!note.isSustainNote)
			note.y = noteY;

		var strum = getStrumForDirection(note.noteData, note.strumsGroupIndex, note.mustPress);
		if (strum != null)
		{
			// ── Ángulo base del strum ─────────────────────────────────────────
			var _finalAngle:Float = strum.angle;

			if (_modState != null)
			{
				// CONFUSION: rotación plana extra en cada nota
				_finalAngle += _modState.confusion;

				// TORNADO: cada nota rota según su strumTime (efecto carrusel).
				// La onda usa drunkFreq como frecuencia compartida con drunk.
				if (_modState.tornado != 0)
					_finalAngle += _modState.tornado * Math.sin(note.strumTime * 0.001 * _modState.drunkFreq);
			}

			note.angle = _finalAngle;

			// ── Escala / alpha ────────────────────────────────────────────────
			final newSX = strum.scale.x;
			final newSY = note.isSustainNote ? note.scale.y : strum.scale.y;
			final scaleChanged = note.scale.x != newSX || note.scale.y != newSY;
			note.scale.x = newSX;
			if (!note.isSustainNote)
				note.scale.y = newSY;
			if (scaleChanged)
				note.updateHitbox();
			note.alpha = FlxMath.bound(strum.alpha, 0.05, 1.0);

			// ── Posición X base ───────────────────────────────────────────────
			var _noteX:Float = strum.x + (strum.width - note.width) / 2;

			if (_modState != null)
			{
				// NOTE_OFFSET_X: offset plano en X
				_noteX += _modState.noteOffsetX;

				// DRUNK_X: onda senoidal en X usando strumTime de la nota.
				// El segundo término (songPosition) hace que la onda se desplace
				// en el tiempo incluso cuando no llegan notas nuevas.
				if (_modState.drunkX != 0)
					_noteX += _modState.drunkX * Math.sin(
						note.strumTime * 0.001 * _modState.drunkFreq
						+ songPosition * 0.0008
					);

				// FLIP_X: espejo horizontal alrededor del centro del strum.
				// Con flipX=1 las notas aparecen en el lado opuesto del strum.
				if (_modState.flipX > 0.5)
				{
					final _strumCenter = strum.x + strum.width / 2;
					_noteX = _strumCenter - (_noteX - _strumCenter + note.width / 2) - note.width / 2;
				}
			}

			note.x = _noteX;
		}

		// ── V-Slice style fade: desvanecer notas que pasan el strum ─────────
		// Solo aplica a notas del jugador que no fueron golpeadas
		if (note.mustPress && !note.wasGoodHit && !note.isSustainNote)
		{
			// Distancia desde el centro del strum hacia la dirección "pasada"
			// En upscroll: las notas vienen de abajo, pasan el strum hacia arriba (Y decrece)
			// En downscroll: las notas vienen de arriba, pasan el strum hacia abajo (Y crece)
			var distPast:Float;
			if (downscroll)
				distPast = note.y - strumLineY;   // positivo = debajo del strum (pasó)
			else
				distPast = strumLineY - note.y;    // positivo = encima del strum (pasó)

			// Empezar a desvanecer a partir de 20px antes del strum, llegar a alpha 0 a 120px después
			final FADE_START:Float = -20.0;
			final FADE_END:Float   = 120.0;
			if (distPast > FADE_START)
			{
				var t = FlxMath.bound((distPast - FADE_START) / (FADE_END - FADE_START), 0.0, 1.0);
				// alpha va de 1.0 → 0.0, pero mantenemos un mínimo de 0.05 para que no sea invisible bruscamente
				note.alpha = FlxMath.lerp(1.0, 0.05, t);
			}
		}

		// ── Modificadores Y per-nota (antes de asignar Y final) ──────────────
		if (_modState != null && !note.isSustainNote)
		{
			// NOTE_OFFSET_Y: offset plano
			if (_modState.noteOffsetY != 0)
				note.y += _modState.noteOffsetY;

			// DRUNK_Y: onda senoidal en Y por strumTime.
			// Fase ligeramente distinta a drunkX para que no sean idénticas.
			if (_modState.drunkY != 0)
				note.y += _modState.drunkY * Math.sin(
					note.strumTime * 0.001 * _modState.drunkFreq
					+ songPosition * 0.001
				);

			// BUMPY: toda la columna oscila al mismo tiempo (mismo phase para todas las notas).
			// A diferencia de DRUNK_Y, no depende del strumTime individual.
			if (_modState.bumpy != 0)
				note.y += _modState.bumpy * Math.sin(songPosition * 0.001 * _modState.bumpySpeed);
		}

		// Posición Y de sustains: noteY directo (fórmula original).
		// scale.y fue calculado en setupSustainNote() para que la altura de cada pieza
		// coincida con el espacio entre strumTimes adyacentes (stepCrochet * scrollSpeed).
		// Cualquier compensación de offset.y rompe esa alineación cuerpo↔tail.
		if (note.isSustainNote)
			note.y = noteY;

		// BUGFIX: El clip de sustains debe aplicarse a TODAS las notas largas
		// (jugador y CPU, upscroll y downscroll). Antes solo se aplicaba a
		// CPU en downscroll, lo que causaba que los cuerpos de los holds
		// se vieran "rotos" o solapados con el strum en el resto de casos.
		// Además, el clipRect nunca se limpiaba cuando dejaba de ser necesario,
		// dejando el rect viejo de la nota anterior asignado a la nota actual.
		if (note.isSustainNote)
		{
			// Umbral = borde superior del strum (strumLineY).
			// Antes era strumLineY + swagWidth/2 (+56px) lo que permitía que
			// la nota penetrara visualmente en el strum antes de empezar a clipear.
			var strumLineThreshold = strumLineY;

			if (downscroll)
			{
				// Downscroll: la nota baja de arriba hacia el strum.
				// Clipeamos la parte que ya pasó (está por debajo del strum).
				var noteEndPos = note.y - note.offset.y * note.scale.y + note.height;
				if (noteEndPos >= strumLineThreshold)
				{
					if (_cachedDownscroll)
						downscrollOff = 10;
					_sustainClipRect.x      = 0;
					_sustainClipRect.width  = note.frameWidth * 2;
					_sustainClipRect.height = (strumLineThreshold - note.y) / note.scale.y;
					_sustainClipRect.y      = note.frameHeight - _sustainClipRect.height + downscrollOff;
					// Usar copyFrom en lugar de asignar referencia directa para
					// que cada nota tenga su propio rect y no compartan el mismo objeto.
					if (note.clipRect == null) note.clipRect = new flixel.math.FlxRect();
					note.clipRect.copyFrom(_sustainClipRect);
					note.clipRect = note.clipRect; // forzar update interno de Flixel
				}
				else
				{
					note.clipRect = null;
				}
			}
			else
			{
				// Upscroll: la nota sube hacia el strum (Y decrece).
				// Clipeamos la parte superior que ya pasó por encima del strum.
				if (note.y < strumLineThreshold)
				{
					var clipY:Float = (strumLineThreshold - note.y) / note.scale.y;
					var clipH:Float = note.frameHeight - clipY;
					if (clipH > 0 && clipY >= 0)
					{
						_sustainClipRect.x      = 0;
						_sustainClipRect.width  = note.frameWidth * 2;
						_sustainClipRect.y      = clipY;
						_sustainClipRect.height = clipH;
						if (note.clipRect == null) note.clipRect = new flixel.math.FlxRect();
						note.clipRect.copyFrom(_sustainClipRect);
						note.clipRect = note.clipRect; // forzar update interno de Flixel
					}
					else
					{
						// Nota completamente por encima del strum: ocultar si ya fue consumida
						if (note.isSustainNote && note.wasGoodHit)
							note.visible = false;
						note.clipRect = null;
					}
				}
				else
				{
					note.clipRect = null;
				}
			}
		}
	}

	private function removeNote(note:Note):Void
	{
		note.kill();
		// Remover del grupo correcto según tipo de nota
		if (note.isSustainNote && sustainNotes != notes)
			sustainNotes.remove(note, true);
		else
			notes.remove(note, true);
		if (renderer != null)
			renderer.recycleNote(note);
	}

	public function hitNote(note:Note, rating:String):Void
	{
		if (note.wasGoodHit)
			return;
		note.wasGoodHit = true;
		handleStrumAnimation(note.noteData, note.strumsGroupIndex, true);
		// Guardar el tiempo de fin del hold al golpear el HEAD note.
		// BUG FIX: no sobreescribir si ya hay un hold activo para esta dirección.
		// Sin este check, un segundo head note en la misma dirección pisaba el tiempo
		// del hold activo → autoReleaseFinishedHolds lo cerraba antes de tiempo
		// → playEnd() se disparaba y el loop del splash se cortaba solo.
		if (!note.isSustainNote && note.sustainLength > 0 && !holdEndTimes.exists(note.noteData))
			holdEndTimes.set(note.noteData, note.strumTime + note.sustainLength);
		if (rating == "sick")
		{
			if (note.isSustainNote)
				handleSustainNoteHit(note);
			else if (_cachedNoteSplashes && renderer != null)
				createNormalSplash(note, true);
		}
		removeNote(note);
		if (onNoteHit != null)
			onNoteHit(note);
	}

	private function handleSustainNoteHit(note:Note):Void
	{
		var direction = note.noteData;
		if (!heldNotes.exists(direction))
		{
			heldNotes.set(direction, note);
			holdStartTimes.set(direction, Conductor.songPosition);

			// Hold covers solo si los note splashes están activados en opciones
			if (_cachedNoteSplashes && renderer != null)
			{
				var strum = getStrumForDirection(direction, note.strumsGroupIndex, true);
				if (strum != null)
				{
					var cover = renderer.startHoldCover(direction, strum.x - strum.offset.x + strum.frameWidth * 0.5, strum.y - strum.offset.y + strum.frameHeight * 0.5);
					// BUGFIX: indexOf evita doble-add de covers pre-calentados que ya
					// están en el grupo → doble update/draw causaba animación duplicada.
					if (cover != null && !_holdCoverSet.exists(cover) && holdCovers.members.indexOf(cover) < 0) {
						_holdCoverSet.set(cover, true);
						holdCovers.add(cover);
					}
				}
			}
		}
		// No llamar removeNote aquí — hitNote() ya lo hace después
	}

	public function releaseHoldNote(direction:Int):Void
	{
		if (!heldNotes.exists(direction))
			return;
		if (renderer != null)
			renderer.stopHoldCover(direction);
		heldNotes.remove(direction);
		holdStartTimes.remove(direction);
		holdEndTimes.remove(direction);
	}

	private function createNormalSplash(note:Note, isPlayer:Bool):Void
	{
		if (renderer == null)
			return;
		var strum = getStrumForDirection(note.noteData, note.strumsGroupIndex, isPlayer);
		if (strum != null)
		{
			var splash = renderer.spawnSplash(strum.x, strum.y, note.noteData);
			if (splash != null)
				splashes.add(splash);
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
			if (groupMap != null)
				return groupMap.get(direction);
		}

		// Grupos 0 y 1 — caché por dirección
		return isPlayer ? _playerStrumCache.get(direction) : _cpuStrumCache.get(direction);
	}

	public function missNote(note:Note):Void
	{
		if (note == null || note.wasGoodHit)
			return;
		// Para sustains: ya se contó el miss en updateActiveNotes, no volver a contar
		if (heldNotes.exists(note.noteData))
			releaseHoldNote(note.noteData);
		if (onNoteMiss != null && !note.isSustainNote)
			onNoteMiss(note);
		removeNote(note);
	}

	// ─── Rewind Restart (V-Slice style) ──────────────────────────────────────

	/**
	 * Actualiza SOLO la posición visual de las notas activas — sin spawn ni kill.
	 * Llamar durante la animación de rewind para que las notas deslicen hacia atrás.
	 */
	public function updatePositionsForRewind(songPosition:Float):Void
	{
		_rewindUpdateGroup(sustainNotes.members, sustainNotes.members.length, songPosition);
		if (sustainNotes != notes)
			_rewindUpdateGroup(notes.members, notes.members.length, songPosition);
		if (renderer != null)
			renderer.updateBatcher();
	}

	private inline function _rewindUpdateGroup(members:Array<Note>, len:Int, songPosition:Float):Void
	{
		for (i in 0...len)
		{
			final note = members[i];
			if (note == null || !note.alive)
				continue;
			updateNotePosition(note, songPosition);
			if (note.y < -CULL_DISTANCE || note.y > FlxG.height + CULL_DISTANCE)
				note.visible = false;
			else
				note.visible = true;
		}
	}

	/**
	 * Mata todas las notas activas y retrocede el índice de spawn
	 * al punto correcto para `targetTime` (generalmente inicio del countdown).
	 * Llamar al finalizar la animación de rewind.
	 */
	public function rewindTo(targetTime:Float):Void
	{
		// Matar todas las notas vivas en ambos grupos
		if (sustainNotes != notes)
		{
			var i = sustainNotes.members.length - 1;
			while (i >= 0)
			{
				var n = sustainNotes.members[i];
				if (n != null && n.alive)
					removeNote(n);
				i--;
			}
		}
		var i = notes.members.length - 1;
		while (i >= 0)
		{
			var n = notes.members[i];
			if (n != null && n.alive)
				removeNote(n);
			i--;
		}

		_prevSpawnedNote.clear();
		heldNotes.clear();
		_cpuHeldDirs[0] = _cpuHeldDirs[1] = _cpuHeldDirs[2] = _cpuHeldDirs[3] = false;
		holdStartTimes.clear();
		holdEndTimes.clear();
		cpuHoldEndTimes[0] = cpuHoldEndTimes[1] = cpuHoldEndTimes[2] = cpuHoldEndTimes[3] = -1;
		_missedHoldDir[0] = _missedHoldDir[1] = _missedHoldDir[2] = _missedHoldDir[3] = false;
		playerHeld = [false, false, false, false];
		_holdCoverSet.clear();

		// BUGFIX escala pixel: limpiar el pool de notas para que las nuevas se creen
		// desde cero con la skin activa correcta. Sin esto, notas recicladas del pool
		// pueden tener _noteScale = 0.7 (Default) si la skin se corrompió durante el juego,
		// causando que las notas pixel (scale 6.0) aparezcan en tamaño de notas normales.
		if (renderer != null)
			renderer.clearPools();

		// Retroceder el índice de spawn:
		// queremos empezar a spawnear desde notas cuyo strumTime ≥ targetTime - spawnWindow
		final spawnWindow:Float = 1800.0 / (songSpeed > 0 ? songSpeed : 1.0);
		var cutoff:Float = targetTime - spawnWindow;

		_unspawnIdx = 0;
		// Si targetTime es negativo (countdown), cutoff también es negativo → _unspawnIdx = 0 (correcto)
		if (cutoff > 0)
		{
			while (_unspawnIdx < unspawnNotes.length && unspawnNotes[_unspawnIdx].strumTime < cutoff)
				_unspawnIdx++;
		}

		trace('[NoteManager] rewindTo($targetTime) → _unspawnIdx=$_unspawnIdx / ${unspawnNotes.length}');
	}

	public function destroy():Void
	{
		unspawnNotes = [];
		_unspawnIdx = 0;
		_prevSpawnedNote.clear();
		heldNotes.clear();
		_cpuHeldDirs[0] = _cpuHeldDirs[1] = _cpuHeldDirs[2] = _cpuHeldDirs[3] = false;
		holdStartTimes.clear();
		holdEndTimes.clear();
		cpuHoldEndTimes[0] = cpuHoldEndTimes[1] = cpuHoldEndTimes[2] = cpuHoldEndTimes[3] = -1;
		_missedHoldDir[0] = _missedHoldDir[1] = _missedHoldDir[2] = _missedHoldDir[3] = false;
		_holdCoverSet.clear();
		_playerStrumCache = [];
		_cpuStrumCache = [];
		_strumGroupCache = [];
		sustainNotes = null;
		if (renderer != null)
		{
			renderer.clearPools();
			renderer.destroy();
		}
	}

	public function getPoolStats():String
		return renderer != null ? renderer.getPoolStats() : "No renderer";

	public function toggleBatching():Void
		if (renderer != null)
			renderer.toggleBatching();

	public function toggleHoldSplashes():Void
		if (renderer != null)
			renderer.toggleHoldSplashes();
}
