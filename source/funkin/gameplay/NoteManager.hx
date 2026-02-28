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
	public var splashes:FlxTypedGroup<NoteSplash>;
	public var holdCovers:FlxTypedGroup<NoteHoldCover>;

	// Datos crudos — solo primitivas, cero FlxSprites hasta spawnNotes()
	private var unspawnNotes:Array<NoteRawData> = [];
	private var _unspawnIdx:Int = 0;
	// BUGFIX: trackeado por dirección para evitar cross-chain en holds simultáneos
	private var _prevSpawnedNote:Map<Int, Note> = new Map();

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

	private static inline var CULL_DISTANCE:Float = 2000;

	private var _scrollSpeed:Float = 0.45;
	var downscrollOff:Float = 0;

	// === CALLBACKS ===
	public var onNoteMiss:Note->Void = null;
	public var onCPUNoteHit:Note->Void = null;
	public var onNoteHit:Note->Void = null;

	// Hold note tracking
	private var heldNotes:Map<Int, Note> = new Map();
	private var holdStartTimes:Map<Int, Float> = new Map();

	/**
	 * Estado de teclas presionadas — actualizado desde PlayState cada frame
	 * (inputHandler.held[0..3]).  Usado para distinguir si un sustain está
	 * siendo mantenido o fue soltado antes de tiempo.
	 */
	public var playerHeld:Array<Bool> = [false, false, false, false];

	/**
	 * Set de noteData (0-3) cuyos sustains ya contaron un miss este ciclo.
	 * Evita sumar un miss por CADA pieza del hold; solo se cuenta UNA vez.
	 */
	private var _missedHoldDir:Map<Int, Bool> = new Map();
	// Buffer preallocado para autoReleaseFinishedHolds — cero allocs por frame
	private var _autoReleaseBuffer:Array<Int> = [];
	// Tracking de qué direcciones está "manteniendo" el CPU (para hold covers)
	private var cpuHeldDirs:Map<Int, Bool> = new Map();

	public function new(notes:FlxTypedGroup<Note>, playerStrums:FlxTypedGroup<FlxSprite>, cpuStrums:FlxTypedGroup<FlxSprite>,
			splashes:FlxTypedGroup<NoteSplash>, holdCovers:FlxTypedGroup<NoteHoldCover>, ?playerStrumsGroup:StrumsGroup, ?cpuStrumsGroup:StrumsGroup, ?allStrumsGroups:Array<StrumsGroup>)
	{
		this.notes = notes;
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
	private function autoReleaseFinishedHolds():Void
	{
		final members = notes.members;
		final len = members.length;

		// ── Jugador ──────────────────────────────────────────────────────────
		if (heldNotes.keys().hasNext())
		{
			_autoReleaseBuffer.resize(0);
			for (dir in heldNotes.keys())
			{
				if (!_hasPendingSustain(dir, true, members, len))
					_autoReleaseBuffer.push(dir);
			}
			for (dir in _autoReleaseBuffer)
				releaseHoldNote(dir);
		}

		// ── CPU ──────────────────────────────────────────────────────────────
		if (cpuHeldDirs.keys().hasNext())
		{
			_autoReleaseBuffer.resize(0);
			for (dir in cpuHeldDirs.keys())
			{
				if (!_hasPendingSustain(dir, false, members, len))
					_autoReleaseBuffer.push(dir);
			}
			for (dir in _autoReleaseBuffer)
			{
				if (renderer != null) renderer.stopHoldCover(dir, false);
				cpuHeldDirs.remove(dir);
			}
		}
	}

	/**
	 * Devuelve true si quedan piezas de sustain pendientes para una dirección,
	 * buscando tanto en las notas ya spawneadas como en las futuras (unspawnNotes).
	 * Sin revisar unspawnNotes, los holds largos se liberaban prematuramente.
	 */
	private function _hasPendingSustain(dir:Int, isPlayer:Bool, members:Array<Note>, len:Int):Bool
	{
		// 1. Notas spawneadas y activas
		for (i in 0...len)
		{
			final n = members[i];
			if (n != null && n.alive && n.isSustainNote && n.noteData == dir && n.mustPress == isPlayer)
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

			final note = renderer.getNote(raw.strumTime, raw.noteData, _prevSpawnedNote.get(raw.noteData), raw.isSustainNote, raw.mustHitNote);
			note.strumsGroupIndex = raw.strumsGroupIndex;
			note.noteType = raw.noteType;
			note.sustainLength = raw.sustainLength;
			note.visible = true;
			note.active = true;
			note.alpha = raw.isSustainNote ? 0.6 : 1.0;

			_prevSpawnedNote.set(raw.noteData, note);
			notes.add(note);
			// Sin splice: el array NoteRawData es ~50 bytes/nota (trivial en RAM).
			// El splice O(n) causaba un hiccup visible al 75% de la canción.
		}
	}

	private function updateActiveNotes(songPosition:Float):Void
	{
		final members = notes.members;
		final len = members.length;
		final hitWindow:Float = Conductor.safeZoneOffset;

		// Limpiar el set de miss-por-hold al inicio de cada frame
		_missedHoldDir.clear();

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
							// Tecla mantenida: marcar como golpeada y eliminar limpiamente
							note.wasGoodHit = true;
							removeNote(note);
						}
						else
						{
							// Tecla soltada: fallar el sustain
							// Desvanecer la nota en lugar de eliminarla (feedback visual)
							note.alpha = 0.2;
							note.tooLate = true;

							// Contar UN miss por grupo de hold, no uno por pieza
							if (!_missedHoldDir.exists(dir))
							{
								_missedHoldDir.set(dir, true);
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
				note.visible = false;
			else
			{
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
		if (!note.isSustainNote && !FlxG.save.data.middlescroll && FlxG.save.data.notesplashes && renderer != null)
			createNormalSplash(note, false);
/*
		// Hold covers para CPU (como v-slice): solo en la primera pieza de sustain
		if (note.isSustainNote && !FlxG.save.data.middlescroll && FlxG.save.data.notesplashes && renderer != null)
		{
			
			var dir = note.noteData;
			if (!cpuHeldDirs.exists(dir))
			{
				cpuHeldDirs.set(dir, true);
				var strum = getStrumForDirection(dir, note.strumsGroupIndex, false);
				if (strum != null)
				{
					var cover = renderer.startHoldCover(dir, strum.x, strum.y, false);
					if (cover != null && holdCovers.members.indexOf(cover) < 0)
						holdCovers.add(cover);
				}
			}
		}*/

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
			if (strumNote != null)
				strumNote.playAnim('confirm', true);
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
			note.angle = strum.angle;
			// updateHitbox() solo cuando la escala realmente cambió (evita
			// recalcular dimensiones en cada frame para cada nota activa).
			final newSX = strum.scale.x;
			final newSY = note.isSustainNote ? note.scale.y : strum.scale.y;
			final scaleChanged = note.scale.x != newSX || note.scale.y != newSY;
			note.scale.x = newSX;
			if (!note.isSustainNote)
				note.scale.y = newSY;
			if (scaleChanged)
				note.updateHitbox();
			note.alpha = FlxMath.bound(strum.alpha, 0.05, 1.0);
			note.x = strum.x + (strum.width - note.width) / 2;
		}

		if (note.isSustainNote && downscroll && !note.mustPress)
		{
			var strumLineThreshold = (strumLineY + Note.swagWidth / 2);
			var noteEndPos = note.y - note.offset.y * note.scale.y + note.height;
			if (noteEndPos >= strumLineThreshold)
			{
				var clipRect = note.clipRect;
				if (clipRect == null)
					clipRect = new flixel.math.FlxRect();
				clipRect.width = note.frameWidth * 2;
				clipRect.height = (strumLineThreshold - note.y) / note.scale.y;
				if (FlxG.save.data.downscroll)
					downscrollOff = 10;
				clipRect.y = note.frameHeight - clipRect.height + downscrollOff;
				note.clipRect = clipRect;
			}
		}
	}

	private function removeNote(note:Note):Void
	{
		note.kill();
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
		if (rating == "sick")
		{/*
			if (note.isSustainNote)
				handleSustainNoteHit(note);
			else*/
			if (!note.isSustainNote && FlxG.save.data.notesplashes && renderer != null)
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
			if (FlxG.save.data.notesplashes && renderer != null)
			{
				var strum = getStrumForDirection(direction, note.strumsGroupIndex, true);
				if (strum != null)
				{
					var cover = renderer.startHoldCover(direction, strum.x, strum.y);
					// Solo añadir al grupo si no está ya (el pool puede reutilizar objetos)
					if (cover != null && holdCovers.members.indexOf(cover) < 0)
						holdCovers.add(cover);
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
		final members = notes.members;
		final len = members.length;
		for (i in 0...len)
		{
			final note = members[i];
			if (note == null || !note.alive)
				continue;
			updateNotePosition(note, songPosition);

			// Culling suave: ocultar si sale de pantalla, pero no matar
			if (note.y < -CULL_DISTANCE || note.y > FlxG.height + CULL_DISTANCE)
				note.visible = false;
			else
				note.visible = true;
		}
		if (renderer != null)
			renderer.updateBatcher();
	}

	/**
	 * Mata todas las notas activas y retrocede el índice de spawn
	 * al punto correcto para `targetTime` (generalmente inicio del countdown).
	 * Llamar al finalizar la animación de rewind.
	 */
	public function rewindTo(targetTime:Float):Void
	{
		// Matar todas las notas vivas
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
		cpuHeldDirs.clear();
		holdStartTimes.clear();
		_missedHoldDir.clear();
		playerHeld = [false, false, false, false];

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
		cpuHeldDirs.clear();
		holdStartTimes.clear();
		_missedHoldDir.clear();
		_playerStrumCache = [];
		_cpuStrumCache = [];
		_strumGroupCache = [];
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
