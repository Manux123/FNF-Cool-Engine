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

class NoteManager
{
	// === GROUPS ===
	public var notes:FlxTypedGroup<Note>;
	public var splashes:FlxTypedGroup<NoteSplash>; // NUEVO: Grupo de splashes

	private var unspawnNotes:Array<Note> = [];

	// === STRUMS ===
	private var playerStrums:FlxTypedGroup<FlxSprite>;
	private var cpuStrums:FlxTypedGroup<FlxSprite>;

	// ✅ Referencias a StrumsGroup para animaciones
	private var playerStrumsGroup:StrumsGroup;
	private var cpuStrumsGroup:StrumsGroup;

	// ✅ Lista COMPLETA de todos los grupos de strums (incluye grupos extra)
	private var allStrumsGroups:Array<StrumsGroup>;

	// === RENDERER ===
	private var renderer:NoteRenderer;

	// === CONFIG ===
	public var strumLineY:Float = 50;
	public var downscroll:Bool = false;
	public var middlescroll:Bool = false;

	private var songSpeed:Float = 1.0;

	// === OPTIMIZATION ===
	private static inline var CULL_DISTANCE:Float = 2000;

	private var _scrollSpeed:Float = 0.45;

	var downscrollOff:Float = 0;

	// === CALLBACKS ===
	public var onNoteMiss:Note->Void = null;
	public var onCPUNoteHit:Note->Void = null;
	public var onNoteHit:Note->Void = null; // NUEVO: Callback para hits del jugador

	// NUEVO: Tracking de hold notes presionadas
	private var heldNotes:Map<Int, Note> = new Map(); // dirección -> nota
	private var holdStartTimes:Map<Int, Float> = new Map(); // dirección -> tiempo de inicio

	public function new(notes:FlxTypedGroup<Note>, playerStrums:FlxTypedGroup<FlxSprite>, cpuStrums:FlxTypedGroup<FlxSprite>,
			splashes:FlxTypedGroup<NoteSplash>, ?playerStrumsGroup:StrumsGroup, ?cpuStrumsGroup:StrumsGroup,
			?allStrumsGroups:Array<StrumsGroup>)
	{
		this.notes = notes;
		this.playerStrums = playerStrums;
		this.cpuStrums = cpuStrums;
		this.splashes = splashes; // NUEVO
		this.playerStrumsGroup = playerStrumsGroup; // ✅ Guardar referencia
		this.cpuStrumsGroup = cpuStrumsGroup; // ✅ Guardar referencia
		this.allStrumsGroups = allStrumsGroups; // ✅ Lista completa de grupos

		// Crear renderer con pooling y batching
		renderer = new NoteRenderer(notes, playerStrums, cpuStrums);
	}

	/**
	 * Generar notas desde SONG data
	 */
	public function generateNotes(SONG:SwagSong):Void
	{
		unspawnNotes = [];
		songSpeed = SONG.speed;
		_scrollSpeed = 0.45 * FlxMath.roundDecimal(songSpeed, 2);

		trace('[NoteManager] === GENERANDO NOTAS ===');
		trace('[NoteManager] Song speed: $songSpeed, scroll speed: $_scrollSpeed');
		trace('[NoteManager] Secciones totales: ${SONG.notes.length}');

		var notesCount = 0;
		var sectionIndex = 0;

		for (section in SONG.notes)
		{
			trace('[NoteManager] Procesando sección $sectionIndex - mustHitSection: ${section.mustHitSection}');

			for (songNotes in section.sectionNotes)
			{
				var daStrumTime:Float = songNotes[0];
				var rawNoteData:Int = Std.int(songNotes[1]);
				var daNoteData:Int = rawNoteData % 4;
				var groupIdx:Int = Math.floor(rawNoteData / 4);

				// ✅ FIXED: Determinar gottaHitNote según el grupo de strums
				// Grupos 0 y 1: lógica legacy con mustHitSection (swap entre BF y DAD)
				// Grupos 2+: seguir el flag CPU del StrumsGroup correspondiente
				var gottaHitNote:Bool;
				if (allStrumsGroups != null && groupIdx < allStrumsGroups.length && groupIdx >= 2)
				{
					// Grupo extra: no participa en el swap mustHitSection
					gottaHitNote = !allStrumsGroups[groupIdx].isCPU;
				}
				else
				{
					// Lógica original para grupos 0 y 1
					gottaHitNote = section.mustHitSection;
					if (groupIdx == 1)
						gottaHitNote = !section.mustHitSection;
				}

				var oldNote:Note = null;
				if (unspawnNotes.length > 0)
					oldNote = unspawnNotes[unspawnNotes.length - 1];

				var swagNote:Note = renderer.getNote(daStrumTime, daNoteData, oldNote, false, gottaHitNote);
				// ✅ FIXED: Asignar el índice de grupo correcto
				swagNote.strumsGroupIndex = groupIdx;

				notesCount++;

				// Sustain notes
				var susLength:Float = songNotes[2];
				if (susLength > 0)
				{
					swagNote.sustainLength = susLength;
					var floorSus:Int = Math.floor(susLength / Conductor.stepCrochet);

					for (susNote in 0...floorSus)
					{
						oldNote = unspawnNotes[unspawnNotes.length - 1];

						var sustainNote:Note = renderer.getNote(daStrumTime + (Conductor.stepCrochet * susNote) + Conductor.stepCrochet, daNoteData, oldNote,
							true, gottaHitNote);
						// ✅ FIXED: Las notas sustain también necesitan el índice de grupo
						sustainNote.strumsGroupIndex = groupIdx;
						unspawnNotes.push(sustainNote);
						notesCount++;
					}
				}

				unspawnNotes.push(swagNote);
			}

			sectionIndex++;
		}

		unspawnNotes.sort((a, b) -> Std.int(a.strumTime - b.strumTime));

		trace('[NoteManager] Total notas generadas: $notesCount');
		trace('[NoteManager] Notas en unspawnNotes: ${unspawnNotes.length}');
		if (unspawnNotes.length > 0)
		{
			trace('[NoteManager] Primera nota: t=${unspawnNotes[0].strumTime}ms, mustPress=${unspawnNotes[0].mustPress}');
			trace('[NoteManager] Última nota: t=${unspawnNotes[unspawnNotes.length - 1].strumTime}ms');
		}
		trace('[NoteManager] === GENERACIÓN COMPLETA ===');
	}

	/**
	 * Update notas - Spawning y movimiento
	 */
	public function update(songPosition:Float):Void
	{
		spawnNotes(songPosition);
		updateActiveNotes(songPosition);
		updateStrumAnimations();

		// NUEVO: Actualizar batcher y hold splashes
		if (renderer != null)
		{
			renderer.updateBatcher();
			renderer.updateHoldSplashes();
		}
	}

	private function spawnNotes(songPosition:Float):Void
	{
		var spawnedCount = 0;
		var spawnTime:Float = 2000 / songSpeed;
		while (unspawnNotes.length > 0 && unspawnNotes[0].strumTime - songPosition < spawnTime)
		{
			var note = unspawnNotes.shift();

			note.visible = true;
			note.active = true;
			note.alpha = note.isSustainNote ? 0.6 : 1.0;

			notes.add(note);
			spawnedCount++;
		}

		if (spawnedCount > 0)
		{
			trace('[NoteManager] Spawned $spawnedCount notas, quedan ${unspawnNotes.length}');
		}
	}

	private function updateActiveNotes(songPosition:Float):Void
	{
		var playerNotesCount = 0;
		var checkedNotes = 0;

		notes.forEachAlive(function(note:Note)
		{
			updateNotePosition(note, songPosition);

			if (!note.mustPress && note.strumTime <= songPosition)
			{
				handleCPUNote(note);
				return;
			}

			// Contar notas del jugador para debug
			if (note.mustPress && !note.isSustainNote)
			{
				playerNotesCount++;

				// Debug cada 60 frames (aproximadamente 1 segundo)
				if (checkedNotes % 60 == 0)
				{
					var timeDiff = songPosition - note.strumTime;
					trace('[NoteManager] 🔍 Nota jugador - noteData=${note.noteData}, strumTime=${note.strumTime}, songPos=$songPosition, diff=$timeDiff, wasGoodHit=${note.wasGoodHit}, tooLate=${note.tooLate}');
				}
				checkedNotes++;
			}

			// ✅ FIX: Marcar la nota como tooLate si pasó el tiempo límite
			// Esto permite que InputHandler.checkMisses() detecte la nota correctamente
			// SOLO para notas normales (no sustain notes)
			if (note.mustPress && !note.wasGoodHit && !note.isSustainNote && songPosition > note.strumTime + 350)
			{
				note.tooLate = true;
				note.canBeHit = false;
				trace('[NoteManager] ⚠️ Nota marcada como tooLate! noteData=${note.noteData}, strumTime=${note.strumTime}, songPos=$songPosition');
				// No llamamos a missNote aquí - InputHandler.checkMisses() lo hará
			}

			manageNoteVisibility(note);
		});
	}

	private function handleCPUNote(note:Note):Void
	{
		note.wasGoodHit = true;
		if (onCPUNoteHit != null)
			onCPUNoteHit(note);

		handleStrumAnimation(note.noteData, note.strumsGroupIndex, false);

		// NUEVO: No crear splash para CPU notes si son sustain notes intermedias
		if (!note.isSustainNote && !FlxG.save.data.middlescroll && FlxG.save.data.notesplashes)
		{
			createNormalSplash(note, false);
		}

		removeNote(note);
	}

	private function manageNoteVisibility(note:Note):Void
	{
		if (note.y < -CULL_DISTANCE || note.y > FlxG.height + CULL_DISTANCE)
		{
			note.visible = false;
		}
		else
		{
			note.visible = true;
			if (!note.mustPress && middlescroll)
				note.alpha = 0;
		}

		if (shouldRemoveNote(note))
		{
			removeNote(note);
		}
	}

	private function updateStrumAnimations():Void
	{
		var resetStrum = function(spr:FlxSprite)
		{
			if (spr.animation.curAnim != null && spr.animation.curAnim.name == 'confirm' && spr.animation.finished)
			{
				spr.animation.play('static');
				spr.centerOffsets();
			}
		};
		cpuStrums.forEach(resetStrum);
		playerStrums.forEach(resetStrum);
	}

	private function handleStrumAnimation(data:Int, strumsGroupIndex:Int, isPlayer:Bool):Void
	{
		var noteID = Std.int(Math.abs(data));

		if (allStrumsGroups != null && allStrumsGroups.length > 0)
		{
			if (strumsGroupIndex <= 1)
			{
				// Igual que getStrumForDirection: grupos 0/1 se resuelven con isPlayer,
				// no con el índice, porque el swap de mustHitSection los puede invertir.
				var group = isPlayer ? playerStrumsGroup : cpuStrumsGroup;
				if (group != null)
				{
					group.playConfirm(noteID);
					return;
				}
			}
			else if (strumsGroupIndex < allStrumsGroups.length)
			{
				allStrumsGroups[strumsGroupIndex].playConfirm(noteID);
				return;
			}
		}

		// Fallback: StrumsGroup legacy
		var strumsGroup = isPlayer ? playerStrumsGroup : cpuStrumsGroup;
		if (strumsGroup != null)
		{
			strumsGroup.playConfirm(noteID);
			return;
		}

		// Fallback final: FlxTypedGroup directamente
		var targetGroup = isPlayer ? playerStrums : cpuStrums;

		targetGroup.forEach(function(spr:FlxSprite)
		{
			if (spr.ID == noteID)
			{
				if (Std.isOfType(spr, StrumNote))
				{
					var strumNote:StrumNote = cast(spr, StrumNote);
					strumNote.playAnim('confirm', true);
				}
				else
				{
					spr.animation.play('confirm', true);
					spr.centerOffsets();

					if (NoteSkinSystem.offsetDefault && !PlayState.SONG.stage.startsWith('school'))
					{
						spr.offset.x -= 13;
						spr.offset.y -= 13;
					}
				}
			}
		});
	}

	/**
	 * Limpia las notas que ocurren antes de un tiempo específico.
	 * Útil para saltar secciones en el Charting State.
	 */
	public function clearNotesBefore(time:Float):Void
	{
		// Mientras haya notas y la primera nota sea anterior al tiempo deseado (con un pequeño margen de 100ms)
		while (unspawnNotes.length > 0 && unspawnNotes[0].strumTime < time - 100)
		{
			var note = unspawnNotes.shift(); // Eliminar de la lista de espera
			if (note != null)
			{
				note.kill(); // Marcar como muerta
				note.destroy(); // Liberar memoria
			}
		}

		trace('[NoteManager] Notas antiguas eliminadas para iniciar en: ' + time);
	}

	private function updateNotePosition(note:Note, songPosition:Float):Void
	{
		var noteY:Float = 0;

		if (downscroll)
			noteY = strumLineY + (songPosition - note.strumTime) * _scrollSpeed;
		else
			noteY = strumLineY - (songPosition - note.strumTime) * _scrollSpeed;

		note.y = noteY;

		// Sincronizar posición y transformadas del strum → nota cada frame.
		// Así los modcharts que mueven/rotan/escalan/ocultan strums afectan
		// visualmente a todas las notas que caen sobre ellos, tanto en
		// PlayState como en el editor, sin necesitar código extra en ninguno.
		var strum = getStrumForDirection(note.noteData, note.strumsGroupIndex, note.mustPress);
		if (strum != null)
		{
			// Heredar transformadas del strum
			note.angle = strum.angle;
			note.scale.x = strum.scale.x;
			if (!note.isSustainNote)
				note.scale.y = strum.scale.y;
			note.updateHitbox();
			note.alpha = FlxMath.bound(strum.alpha, 0.05, 1.0);

			// Centrar X con hitbox ya actualizado
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

	private function shouldRemoveNote(note:Note):Bool
	{
		// ✅ CRÍTICO: NO eliminar notas del jugador que no han sido golpeadas
		// Estas notas deben marcarse como tooLate primero para generar el miss
		if (note.mustPress && !note.wasGoodHit && !note.tooLate)
		{
			// No eliminar hasta que se marque como tooLate
			return false;
		}

		// Eliminar notas que ya salieron de la pantalla
		if (!downscroll)
			return note.y < -note.height;
		else
			return note.y >= strumLineY + 106;
	}

	private function removeNote(note:Note):Void
	{
		note.kill();
		notes.remove(note, true);

		if (renderer != null)
			renderer.recycleNote(note);
	}

	/**
	 * MEJORADO: Procesar hit de nota del jugador con splashes
	 */
	public function hitNote(note:Note, rating:String):Void
	{
		if (note.wasGoodHit)
			return;

		note.wasGoodHit = true;
		handleStrumAnimation(note.noteData, note.strumsGroupIndex, true);

		if (rating == "sick")
		{
			// NUEVO: Gestionar splashes según tipo de nota
			if (note.isSustainNote)
			{
				handleSustainNoteHit(note);
			}
			else
			{
				// Nota normal - splash normal
				createNormalSplash(note, true);
			}
		}
		// Notes should always be removed regardless of the rating lmao
		removeNote(note);

		// Callback
		if (onNoteHit != null)
			onNoteHit(note);
	}

	/**
	 * NUEVO: Manejar hit de sustain note
	 */
	private function handleSustainNoteHit(note:Note):Void
	{
		var direction = note.noteData;

		// Si es la primera parte de la hold note
		if (!heldNotes.exists(direction))
		{
			// Marcar como held
			heldNotes.set(direction, note);
			holdStartTimes.set(direction, Conductor.songPosition);

			// Crear splash de inicio
			var strum = getStrumForDirection(direction, note.strumsGroupIndex, true);
			if (strum != null && renderer != null)
			{
				var splash = renderer.createHoldStartSplash(note, strum.x, strum.y);
				if (splash != null)
					splashes.add(splash);

				// Iniciar splash continuo
				var continuousSplash = renderer.startHoldContinuousSplash(note, strum.x, strum.y);
				if (continuousSplash != null)
					splashes.add(continuousSplash);
			}
		}

		// Remover la nota sustain
		removeNote(note);
	}

	/**
	 * NUEVO: Cuando se suelta una tecla de hold note
	 */
	public function releaseHoldNote(direction:Int):Void
	{
		if (!heldNotes.exists(direction))
			return;

		var note = heldNotes.get(direction);
		var strum = getStrumForDirection(direction, note.strumsGroupIndex, true);

		if (strum != null && renderer != null)
		{
			// Detener splash continuo y crear splash de release
			renderer.stopHoldSplash(note, strum.x, strum.y);
		}

		heldNotes.remove(direction);
		holdStartTimes.remove(direction);
	}

	/**
	 * NUEVO: Crear splash normal
	 */
	private function createNormalSplash(note:Note, isPlayer:Bool):Void
	{
		if (renderer == null)
			return;

		var strum = getStrumForDirection(note.noteData, note.strumsGroupIndex, isPlayer);
		if (strum != null)
		{
			var splash = renderer.getSplash(strum.x, strum.y, note.noteData);
			if (splash != null)
				splashes.add(splash);
		}
	}

	/**
	 * Obtener el StrumNote correcto para posicionar/animar una nota.
	 *
	 * Por qué NO usamos strumsGroupIndex directamente para grupos 0 y 1:
	 *   En el formato clásico de FNF todos los noteData son 0-3, por lo que
	 *   groupIdx = floor(noteData / 4) es siempre 0 para cualquier nota.
	 *   Eso hace que tanto notas del jugador como del CPU tengan strumsGroupIndex=0.
	 *   El campo mustPress (isPlayer) es el único dato fiable para los dos grupos
	 *   estandar — fue calculado correctamente con mustHitSection en generateNotes().
	 *   Solo para grupos extra (>= 2) el índice es unívoco y seguro de usar directo.
	 */
	private function getStrumForDirection(direction:Int, strumsGroupIndex:Int, isPlayer:Bool):FlxSprite
	{
		if (allStrumsGroups != null && allStrumsGroups.length > 0)
		{
			if (strumsGroupIndex <= 1)
			{
				// Grupos 0 y 1: usar isPlayer para elegir el grupo correcto,
				// ya que mustHitSection puede haberlos intercambiado en los datos.
				var group = isPlayer ? playerStrumsGroup : cpuStrumsGroup;
				if (group != null)
					return group.getStrum(direction);
			}
			else if (strumsGroupIndex < allStrumsGroups.length)
			{
				// Grupos extra (>= 2): el índice es directo, sin swap.
				return allStrumsGroups[strumsGroupIndex].getStrum(direction);
			}
		}

		// Fallback legacy (sin allStrumsGroups)
		var targetGroup = isPlayer ? playerStrums : cpuStrums;
		var strum:FlxSprite = null;

		targetGroup.forEach(function(spr:FlxSprite)
		{
			if (spr.ID == direction)
				strum = spr;
		});

		return strum;
	}

	/**
	 * Procesar miss de nota
	 */
	public function missNote(note:Note):Void
	{
		// Si era una hold note, liberar
		if (heldNotes.exists(note.noteData))
		{
			releaseHoldNote(note.noteData);
		}

		if (onNoteMiss != null)
			onNoteMiss(note);

		removeNote(note);
	}

	/**
	 * Limpiar todo
	 */
	public function destroy():Void
	{
		unspawnNotes = [];
		heldNotes.clear();
		holdStartTimes.clear();

		if (renderer != null)
		{
			renderer.clearPools();
			renderer.destroy();
		}
	}

	/**
	 * Obtener estadísticas del pool
	 */
	public function getPoolStats():String
	{
		return renderer != null ? renderer.getPoolStats() : "No renderer";
	}

	/**
	 * NUEVO: Toggle batching
	 */
	public function toggleBatching():Void
	{
		if (renderer != null)
			renderer.toggleBatching();
	}

	/**
	 * NUEVO: Toggle hold splashes
	 */
	public function toggleHoldSplashes():Void
	{
		if (renderer != null)
			renderer.toggleHoldSplashes();
	}
}
