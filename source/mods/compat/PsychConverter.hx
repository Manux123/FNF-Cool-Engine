package mods.compat;

using StringTools;

import haxe.Json;
import funkin.data.Song;
import funkin.data.Section;

/**
 * PsychConverter
 * ─────────────────────────────────────────────────────────────────────────────
 * Translates Psych Engine 0.6.x / 0.7.x data formats into Cool Engine's
 * native SwagSong / CharacterData structures.
 *
 * ── Psych chart structure (reference) ───────────────────────────────────────
 * {
 *   "song": {
 *     "song": "Bopeebo",
 *     "bpm": 100,  "speed": 1,  "needsVoices": true,
 *     "player1": "bf",  "player2": "dad",  "gfVersion": "gf",
 *     "stage": "stage",
 *     "notes": [
 *       {
 *         "sectionNotes": [[time, lane, sustainLength, ?noteType], ...],
 *         "mustHitSection": true,
 *         "sectionBeats": 4,        ← Psych SIEMPRE usa sectionBeats, nunca lengthInSteps
 *         "bpm": 100,  "changeBPM": false,
 *         "altAnim": false,  "gfSection": false
 *       }
 *     ],
 *     "events": [
 *       [time, [["Camera Follow Opponent", "", ""], ...]]
 *     ]
 *   }
 * }
 *
 * ── Psych character structure (reference) ────────────────────────────────────
 * {
 *   "animations": [
 *     { "anim": "idle", "name": "BF idle dance", "fps": 24,
 *       "loop": false, "offsets": [0, 0], "indices": [] }
 *   ],
 *   "no_antialiasing": false,
 *   "image": "characters/BOYFRIEND",
 *   "position": [0, 0],
 *   "camera_position": [0, 0],
 *   "healthicon": "bf",
 *   "healthbar_colors": [49, 176, 209],
 *   "flip_x": false,
 *   "scale": 1,
 *   "sing_duration": 4,
 *   "vocals_file": "",
 *   "gameOverChar": "bf-dead",
 *   "gameOverSound": "fnf_loss_sfx",
 *   "gameOverLoop": "gameOver",
 *   "gameOverEnd": "gameOverEnd"
 * }
 */
class PsychConverter
{
	// ─── Chart ────────────────────────────────────────────────────────────────

	/**
	 * Converts a raw Psych Engine chart JSON string into a Cool Engine SwagSong.
	 *
	 * @param rawJson   The full content of the Psych difficulty JSON file.
	 * @param difficulty  Used only for tracing (e.g. "hard").
	 */
	public static function convertChart(rawJson:String, ?difficulty:String = 'unknown'):SwagSong
	{
		trace('[PsychConverter] Converting chart ($difficulty)...');

		final root:Dynamic  = Json.parse(rawJson);
		// root.song can be EITHER a nested chart object {bpm, notes, ...}
		// OR just a song-name String (flat Psych charts without wrapper).
		// When it's a String we must NOT use it as the data object.
		final rootSong:Dynamic = root.song;
		final isWrapped:Bool   = rootSong != null && !Std.isOfType(rootSong, String);
		final ps:Dynamic       = isWrapped ? rootSong : root;
		// Song name: prefer the String root.song (flat) or the nested ps.song field
		final songName:String  = isWrapped ? _str(ps.song, 'unknown')
		                                   : (rootSong != null ? Std.string(rootSong) : _str(ps.song, 'unknown'));

		// ── Basic fields ─────────────────────────────────────────────────────
		final song:SwagSong = {
			song:        songName,
			bpm:         _float(ps.bpm, 100),
			speed:       _float(ps.speed, 1),
			needsVoices: _bool(ps.needsVoices, true),
			stage:       _str(ps.stage, 'stage'),
			validScore:  true,
			notes:       [],
			// Legacy fields — kept so Song.parseJSONshit migration still works
			player1:     _str(ps.player1, 'bf'),
			player2:     _str(ps.player2, 'dad'),
			gfVersion:   _str(ps.gfVersion ?? ps.player3, 'gf'),
			characters:  null,
			strumsGroups: null,
			events:      []
		};

		// ── Detección de versión del chart (lane format) ─────────────────────
		// Psych 0.6+ usa lanes ABSOLUTAS: 0-3 = siempre player, 4-7 = siempre CPU.
		// Psych pre-0.6 / vanilla FNF usa lanes RELATIVAS: 0-3 = el personaje que
		// canta en esa sección (según mustHitSection), 4-7 = el otro.
		//
		// La detección por `sectionBeats` NO es fiable: algunos charts tienen
		// sectionBeats en secciones vacías pero usan lanes relativas en las demás,
		// o son charts "mixtos" editados parcialmente en Psych 0.6+.
		//
		// Heurística correcta: contar notas en secciones mustHit=FALSE.
		//   · Formato relativo → el oponente canta en 0-3 (predominan 0-3)
		//   · Formato absoluto → el oponente canta en 4-7 (predominan 4-7)
		// Si hay ≥10 notas de muestra y >60% están en 0-3 → lanes relativas.
		// Fallback a sectionBeats si no hay suficientes muestras.
		final psychSections:Array<Dynamic> = (ps.notes != null && Std.isOfType(ps.notes, Array))
			? cast ps.notes : [];

		var isNewPsychFormat:Bool = _detectAbsoluteLanes(psychSections);
		trace('[PsychConverter] Formato detectado: ${isNewPsychFormat ? "Psych 0.6+ (lanes absolutas)" : "pre-0.6 / vanilla (lanes relativas)"}');

		// ── Notes / sections ─────────────────────────────────────────────────

		for (sec in psychSections)
		{
			// Psych 0.6+ SIEMPRE usa `sectionBeats` (por defecto 4).
			// Charts viejos usan `lengthInSteps` directamente.
			// Fallback a 4 beats / 16 steps si ninguno está presente.
			final stepsInSec:Int = (sec.lengthInSteps != null)
				? Std.int(_float(sec.lengthInSteps, 16))
				: Std.int(_float(sec.sectionBeats, 4) * 4);
			final mustHit:Bool    = _bool(sec.mustHitSection, true);

			final converted:SwagSection = {
				// LANE CONVERSION:
				// • Psych 0.6+ → lanes ABSOLUTAS: 0-3=player, 4-7=CPU siempre.
				//   Cool Engine usa lanes relativas, así que cuando mustHitSection=false
				//   hay que invertir 0-3↔4-7 para que el flip interno quede correcto.
				// • Psych pre-0.6 / vanilla FNF → lanes RELATIVAS: ya están en el
				//   formato que espera Cool Engine. NO invertir.
				sectionNotes:   _convertNotes(sec.sectionNotes, mustHit, isNewPsychFormat),
				lengthInSteps:  stepsInSec,
				typeOfSection:  0,
				mustHitSection: mustHit,
				bpm:            _float(sec.bpm, song.bpm),
				changeBPM:      _bool(sec.changeBPM, false),
				altAnim:        _bool(sec.altAnim, false),
				gfSing:         _bool(sec.gfSection, false)
			};
			song.notes.push(converted);
		}

		// ── Camera Follow desde mustHitSection / gfSection ───────────────────
		// Psych define el target de cámara por sección (mustHitSection + gfSection).
		// Cool Engine usa eventos explícitos "Camera Follow" en el array events.
		// Los generamos aquí para que funcionen correctamente aunque el chart
		// tenga además otros eventos explícitos (BPM change, etc.), ya que
		// EventManager.generateCameraFollow() solo corre cuando events está vacío.
		_convertCameraFromSections(psychSections, song);

		// ── Events ───────────────────────────────────────────────────────────
		// Hay tres formatos posibles:
		//
		//   A) Psych 0.6+ (arrays anidados):
		//      [ [timeMs, [ [name, v1, v2], ... ]], ... ]
		//
		//   B) Pre-0.6 con eventos inline en sectionNotes (lane negativa):
		//      Ya se descartan silenciosamente en _convertNotes.
		//
		//   C) Charts en formato Cool Engine nativo:
		//      [ {stepTime, type, value}, ... ]
		//      Ocurre en charts viejos creados o parcialmente convertidos para Cool Engine.
		//
		// Detectamos el formato mirando el primer elemento de ps.events.
		final psychEventsRaw:Array<Dynamic> = (ps.events != null && Std.isOfType(ps.events, Array))
			? cast ps.events : [];

		if (psychEventsRaw.length > 0)
		{
			final firstEvt:Dynamic = psychEventsRaw[0];
			final isCoolNative:Bool = firstEvt != null
				&& !Std.isOfType(firstEvt, Array)
				&& (Reflect.hasField(firstEvt, 'stepTime') || Reflect.hasField(firstEvt, 'type'));

			if (isCoolNative)
			{
				// ── Formato C: ya en formato Cool Engine — copiar directamente ──
				trace('[PsychConverter] Eventos en formato Cool Engine nativo — copiando directamente.');
				for (ev in psychEventsRaw)
				{
					if (ev == null) continue;
					song.events.push({
						stepTime: _float(ev.stepTime, 0),
						type:     _str(ev.type, ''),
						value:    _str(ev.value, '')
					});
				}
			}
			else
			{
				// ── Formato A: Psych 0.6+  [ [timeMs, [[name,v1,v2],...]], ... ] ──
				for (evtGroup in psychEventsRaw)
				{
					if (!Std.isOfType(evtGroup, Array)) continue;
					final arr:Array<Dynamic> = cast evtGroup;
					if (arr.length < 2) continue;

					final timeMs:Float             = _float(arr[0], 0);
					final stepTime:Float           = _msToStep(timeMs, song.bpm);
					final innerList:Array<Dynamic> = Std.isOfType(arr[1], Array) ? cast arr[1] : [];

					for (ev in innerList)
					{
						if (!Std.isOfType(ev, Array)) continue;
						final evArr:Array<Dynamic> = cast ev;
						final evName  = _str(evArr[0], '');
						final evVal1  = _str(evArr[1], '');
						final evVal2  = _str(evArr[2], '');

						final coolType  = _mapEventType(evName);
						final coolValue = _mapEventValue(evName, evVal1, evVal2);

						song.events.push({
							stepTime: stepTime,
							type:     coolType,
							value:    coolValue
						});
					}
				}
			}
		}

		// ── Build characters + strumsGroups from legacy fields ────────────────
		// (Song.parseJSONshit will also do this, but we do it here so the
		//  returned SwagSong is already fully populated)
		_buildCharactersFromLegacy(song);

		trace('[PsychConverter] Done. Sections: ${song.notes.length}, Events: ${song.events.length}');
		return song;
	}

	// ─── Character ────────────────────────────────────────────────────────────

	/**
	 * Converts a raw Psych Engine character JSON string into a Cool Engine
	 * CharacterData-compatible Dynamic object.
	 *
	 * The returned object can be cast to `CharacterData` directly.
	 */
	public static function convertCharacter(rawJson:String, charName:String):Dynamic
	{
		trace('[PsychConverter] Converting character "$charName"...');

		final p:Dynamic = Json.parse(rawJson);

		// ── Animations ───────────────────────────────────────────────────────
		// Psych: { anim, name, fps, loop, offsets:[x,y], indices:[] }
		// Cool : { name, prefix, framerate, looped, offsetX, offsetY, indices }
		final anims:Array<Dynamic> = [];
		if (p.animations != null && Std.isOfType(p.animations, Array))
		{
			final psychAnims:Array<Dynamic> = cast p.animations;
			for (pa in psychAnims)
			{
				final offsets:Array<Dynamic> = (pa.offsets != null && Std.isOfType(pa.offsets, Array))
					? cast pa.offsets : [0, 0];

				final indices:Array<Int> = (pa.indices != null && Std.isOfType(pa.indices, Array)
					&& (cast pa.indices:Array<Dynamic>).length > 0)
					? cast pa.indices : null;

				anims.push({
					name:      _str(pa.anim,  'idle'),    // Psych uses "anim" for the internal name
					prefix:    _str(pa.name,  'idle'),    // Psych uses "name" for the XML prefix
					framerate: _float(pa.fps, 24),
					looped:    _bool(pa.loop, false),
					offsetX:   offsets.length > 0 ? _float(offsets[0], 0) : 0.0,
					offsetY:   offsets.length > 1 ? _float(offsets[1], 0) : 0.0,
					indices:   indices
				});
			}
		}

		// ── Health-bar color  [R, G, B] → "#RRGGBB" ──────────────────────────
		var healthBarColor:String = '#31B0D1';
		if (p.healthbar_colors != null && Std.isOfType(p.healthbar_colors, Array))
		{
			final rgb:Array<Dynamic> = cast p.healthbar_colors;
			if (rgb.length >= 3)
			{
				final r = Std.int(_float(rgb[0], 49));
				final g = Std.int(_float(rgb[1], 176));
				final b = Std.int(_float(rgb[2], 209));
				healthBarColor = '#' + _hex2(r) + _hex2(g) + _hex2(b);
			}
		}

		// ── Camera offset desde "camera_position" ────────────────────────────
		// Psych guarda la posición de cámara en "camera_position" (no en "position").
		// "position" es el offset global del sprite en el mundo.
		var camOffset:Array<Float> = [0.0, 0.0];
		if (p.camera_position != null && Std.isOfType(p.camera_position, Array))
		{
			final cp:Array<Dynamic> = cast p.camera_position;
			camOffset = [_float(cp[0], 0), _float(cp[1], 0)];
		}

		// BUG FIX #CHARPOS: Psych almacena el offset global del sprite en "position" [x, y].
		// Este offset se SUMA a la posición del stage (DAD_X/BF_X/GF_X etc.).
		// La versión anterior ignoraba este campo, dejando los personajes mal posicionados.
		var positionOffset:Array<Float> = [0.0, 0.0];
		if (p.position != null && Std.isOfType(p.position, Array))
		{
			final pos:Array<Dynamic> = cast p.position;
			positionOffset = [_float(pos[0], 0), _float(pos[1], 0)];
		}

		// BUG FIX #4: Mapear campos de Game Over de Psych → Cool
		// Psych: gameOverChar → Cool: charDeath
		// Psych: gameOverSound → Cool: gameOverSound
		// Psych: gameOverLoop  → Cool: gameOverMusic (bucle del tema)
		// Psych: gameOverEnd   → Cool: gameOverEnd
		final charDeath:String     = p.gameOverChar  != null ? _str(p.gameOverChar,  '') : '';
		final gameOverSound:String = p.gameOverSound != null ? _str(p.gameOverSound, '') : '';
		final gameOverMusic:String = p.gameOverLoop  != null ? _str(p.gameOverLoop,  '') : '';
		final gameOverEnd:String   = p.gameOverEnd   != null ? _str(p.gameOverEnd,   '') : '';

		// ── Build Cool Engine CharacterData ───────────────────────────────────
		final coolChar:Dynamic = {
			// Psych stores "image" as e.g. "characters/BOYFRIEND"
			// Cool stores "path" relative to the characters/ folder
			path:           _normalizePath(_str(p.image, 'characters/$charName')),
			animations:     anims,
			isPlayer:       false, // determined at runtime by PlayState
			antialiasing:   !_bool(p.no_antialiasing, false),
			scale:          _float(p.scale, 1),
			flipX:          _bool(p.flip_x, false),
			healthIcon:     _str(p.healthicon, charName),
			healthBarColor: healthBarColor,
			cameraOffset:   camOffset,
			positionOffset: positionOffset   // BUG FIX #CHARPOS
		};

		// Solo añadir campos opcionales si tienen valor (evita contaminar el objeto)
		if (charDeath     != '') Reflect.setField(coolChar, 'charDeath',     charDeath);
		if (gameOverSound != '') Reflect.setField(coolChar, 'gameOverSound', gameOverSound);
		if (gameOverMusic != '') Reflect.setField(coolChar, 'gameOverMusic', gameOverMusic);
		if (gameOverEnd   != '') Reflect.setField(coolChar, 'gameOverEnd',   gameOverEnd);

		trace('[PsychConverter] Character "$charName" done. Anims: ${anims.length}');
		return coolChar;
	}

	// ─── Helpers ─────────────────────────────────────────────────────────────

	/**
	 * Genera eventos "Camera Follow" a partir de mustHitSection / gfSection.
	 *
	 * Psych Engine no usa eventos explícitos para los cambios de cámara por sección —
	 * los define implícitamente con mustHitSection (true=BF, false=Dad) y gfSection (GF).
	 * Cool Engine los necesita como ChartEvent { type: "Camera Follow", value: target }.
	 *
	 * Solo se genera un evento cuando el target CAMBIA respecto al anterior, para no
	 * saturar la lista. Se coloca al COMIENZO del array events para que los eventos
	/**
	 * Detecta si un chart usa lanes ABSOLUTAS (Psych 0.6+) o RELATIVAS (pre-0.6).
	 *
	 * En formato ABSOLUTO las secciones del oponente (mustHitSection=false) tienen
	 * sus notas en lanes 4-7 (CPU siempre en la mitad superior).
	 * En formato RELATIVO esas mismas secciones tienen las notas del oponente en
	 * 0-3 (relativo al rol de esa sección).
	 *
	 * Muestra: notas en secciones mustHit=FALSE.
	 * Devuelve true (absoluto) si la mayoría (>60%) están en lanes 4-7.
	 * Devuelve false (relativo) si la mayoría están en 0-3.
	 * Si no hay suficiente muestra (<10 notas), cae al fallback de sectionBeats.
	 */
	static function _detectAbsoluteLanes(psychSections:Array<Dynamic>):Bool
	{
		var low  = 0; // lanes 0-3  → predominan en formato relativo
		var high = 0; // lanes 4-7  → predominan en formato absoluto

		for (sec in psychSections)
		{
			if (_bool(sec.mustHitSection, true)) continue; // solo secciones del oponente
			final raw = sec.sectionNotes;
			if (raw == null || !Std.isOfType(raw, Array)) continue;
			for (n in (cast raw:Array<Dynamic>))
			{
				if (!Std.isOfType(n, Array)) continue;
				final lane = Std.int(_float((cast n:Array<Dynamic>)[1], 0));
				if (lane < 0) continue; // ignorar event-notes legacy
				if (lane < 4) low++ else high++;
			}
		}

		final total = low + high;
		if (total < 10)
		{
			// Muestra insuficiente — fallback: ¿alguna sección tiene sectionBeats?
			trace('[PsychConverter] Muestra de lanes insuficiente ($total notas), usando fallback sectionBeats.');
			for (sec in psychSections)
				if (sec.sectionBeats != null) return true;
			return false;
		}

		final pctHigh = high / total;
		trace('[PsychConverter] Lane sample: $total notas en secciones oponente → ${Math.round(pctHigh*100)}% en 4-7.');
		// >60% en 4-7 → formato absoluto (Psych 0.6+)
		return pctHigh > 0.6;
	}

	/**
	 * explícitos del chart (Hey!, BPM Change, etc.) puedan sobrescribir si hace falta.
	 *
	 * @param psychSections  Array de secciones crudas del JSON de Psych.
	 * @param song           SwagSong en construcción (se modificará su .events).
	 */
	static function _convertCameraFromSections(psychSections:Array<Dynamic>, song:SwagSong):Void
	{
		var currentStep:Float = 0;
		var currentBpm:Float  = song.bpm;
		var lastTarget:String = ''; // '' = ningún evento emitido aún

		final cameraEvents:Array<funkin.data.Song.ChartEvent> = [];

		for (sec in psychSections)
		{
			// BUG FIX #1 (también aquí): usar sectionBeats para calcular los steps
			final beats:Float        = _float(sec.sectionBeats, 4);
			final stepsInSec:Float   = beats * 4;

			// Determinar target de cámara según flags de Psych
			final isGfSection  = _bool(sec.gfSection, false);
			final mustHitSec   = _bool(sec.mustHitSection, true);
			// BUG FIX #3: usar 'player'/'opponent' consistentemente con EventManager,
			// NO 'bf'/'dad' como hacía antes el mapeo de eventos explícitos.
			final target:String = isGfSection ? 'gf' : (mustHitSec ? 'player' : 'opponent');

			// Solo emitir evento si el target cambia (o es el primer step)
			if (target != lastTarget)
			{
				cameraEvents.push({
					stepTime: currentStep,
					type:     'Camera Follow',
					value:    target
				});
				lastTarget = target;
			}

			if (_bool(sec.changeBPM, false) && _float(sec.bpm, 0) > 0)
				currentBpm = _float(sec.bpm, currentBpm);

			currentStep += stepsInSec;
		}

		// Insertar al frente para que los eventos explícitos (procesados después)
		// queden al final y prevalezcan en el EventManager cuando comparte step.
		var insertIdx = 0;
		for (evt in cameraEvents)
		{
			song.events.insert(insertIdx, evt);
			insertIdx++;
		}

		trace('[PsychConverter] ${cameraEvents.length} Camera Follow generados desde mustHitSection.');
	}

	/**
	 * Converts a Psych sectionNotes array to Cool's format.
	 *
	 * Psych note: [time:Float, lane:Int, sustainLength:Float, ?noteType:String]
	 * Cool note : [time:Float, lane:Int, sustainLength:Float, ?noteType:String]
	 *
	 * Preserva noteType (índice 3) si es un String válido.
	 *
	 * LANE CONVERSION:
	 *   • Psych 0.6+ (isNewPsychFormat=true) → lanes ABSOLUTAS: 0-3=player, 4-7=CPU.
	 *     Cool Engine usa relativas → invertir 0-3↔4-7 cuando mustHitSection=false.
	 *   • Pre-0.6 / vanilla FNF (isNewPsychFormat=false) → lanes RELATIVAS:
	 *     ya coinciden con Cool Engine. NO invertir.
	 */
	static function _convertNotes(raw:Dynamic, mustHitSection:Bool = true, isNewPsychFormat:Bool = true):Array<Dynamic>
	{
		final out:Array<Dynamic> = [];
		if (raw == null || !Std.isOfType(raw, Array)) return out;
		final arr:Array<Dynamic> = cast raw;
		for (n in arr)
		{
			if (!Std.isOfType(n, Array)) continue;
			final note:Array<Dynamic> = cast n;

			// Ignorar notas de evento (lane negativa — son eventos legacy de Psych 0.5)
			final rawLane = Std.int(_float(note[1], 0));
			if (rawLane < 0) continue;

			// Psych 0.6+: lanes absolutas → invertir cuando mustHitSection=false
			// para que Cool Engine (que usa relativas) las asigne al personaje correcto.
			// Pre-0.6: lanes ya son relativas → no tocar.
			final lane:Int = (isNewPsychFormat && !mustHitSection)
				? ((rawLane < 4) ? rawLane + 4 : rawLane - 4)
				: rawLane;

			final noteTime:Float    = _float(note[0], 0);
			final noteSustain:Float = _float(note[2], 0);

			// Preservar noteType (índice 3) si es un String válido
			final noteType:String = (note.length > 3 && note[3] != null && Std.isOfType(note[3], String))
				? Std.string(note[3]) : '';

			if (noteType != '' && noteType != 'Default Note')
				out.push([noteTime, lane, noteSustain, noteType]);
			else
				out.push([noteTime, lane, noteSustain]);
		}
		return out;
	}

	/**
	 * Maps Psych Engine event names → Cool Engine equivalents.
	 *
	 * ── Psych events covered ─────────────────────────────────────────────────
	 *  Camera Follow Opponent / Focus Camera On Opponent  → Camera Follow (opponent)
	 *  Camera Follow Player  / Focus Camera On BF         → Camera Follow (player)
	 *  Change BPM / BPM Change                            → BPM Change
	 *  Hey!                                               → Play Anim
	 *  Alt Idle Animation / Alt Anim                      → Alt Anim
	 *  Camera Zoom / Zoom Camera                          → Camera Zoom
	 *  Camera Flash / Flash Camera                        → Camera Flash
	 *  Camera Shake / Shake Camera                        → Camera Shake
	 *  Camera Fade / Fade Camera                          → Camera Fade
	 *  Play Animation                                     → Play Anim
	 *  Change Character                                   → Change Character
	 *  Set Property / Change Property                     → Set Var
	 *  Play Sound                                         → Play Sound
	 *  Change Music                                       → Music Change
	 *  Play Video / Show Movie                            → Play Video
	 *  Toggle HUD / Hide HUD / Show HUD                   → HUD Visible
	 *  Set Health / Add Health / Remove Health            → Health Change / Add Health
	 *  End Song                                           → End Song
	 *  Run Haxe Code / Run Function                       → Run Script
	 */
	static function _mapEventType(psychName:String):String
	{
		return switch (psychName.toLowerCase())
		{
			// ── Cámara ────────────────────────────────────────────────────────
			case 'camera follow opponent', 'focus camera on opponent',
			     'camera follow player',   'focus camera on bf',
			     'camera follow gf',       'focus camera on gf',
			     'follow camera',          'camera follow':
				'Camera Follow';

			case 'change bpm', 'bpm change':
				'BPM Change';

			case 'camera zoom', 'zoom camera', 'set camera zoom':
				'Camera Zoom';

			case 'camera flash', 'flash camera', 'flash screen':
				'Camera Flash';

			case 'camera shake', 'shake camera', 'screen shake':
				'Camera Shake';

			case 'camera fade', 'fade camera', 'fade screen':
				'Camera Fade';

			// ── Animaciones ───────────────────────────────────────────────────
			case 'hey!', 'hey':
				'Play Anim';

			case 'alt idle animation', 'alt anim', 'alt idle':
				'Alt Anim';

			case 'play animation', 'character anim':
				'Play Anim';

			// ── Personajes ────────────────────────────────────────────────────
			case 'change character', 'swap character', 'character change':
				'Change Character';

			// ── HUD ───────────────────────────────────────────────────────────
			case 'toggle hud', 'hide hud', 'show hud', 'set hud visible':
				'HUD Visible';

			// ── Salud ─────────────────────────────────────────────────────────
			case 'set health', 'health change':
				'Health Change';

			case 'add health', 'gain health':
				'Add Health';

			// ── Audio ─────────────────────────────────────────────────────────
			case 'play sound', 'sound':
				'Play Sound';

			case 'change music', 'set music', 'music change':
				'Music Change';

			// ── Video ─────────────────────────────────────────────────────────
			case 'play video', 'show movie', 'play cutscene', 'video':
				'Play Video';

			// ── Scripting ─────────────────────────────────────────────────────
			case 'set property', 'change property', 'set variable':
				'Set Var';

			case 'run haxe code', 'run function', 'call function':
				'Run Script';

			case 'end song', 'finish song':
				'End Song';

			default:
				psychName; // Pasar desconocidos tal cual
		};
	}

	/**
	 * Convierte los valores v1/v2 de Psych al formato de valor único de Cool Engine.
	 * Cool Engine usa un solo campo `value` (con separador `|` para dos valores).
	 *
	 * BUG FIX #3: Los eventos explícitos de cámara ahora usan 'player'/'opponent'
	 * en lugar de 'bf'/'dad', consistente con EventManager y _convertCameraFromSections.
	 */
	static function _mapEventValue(psychName:String, v1:String, v2:String):String
	{
		return switch (psychName.toLowerCase())
		{
			// BUG FIX #3: cámara usa 'opponent'/'player', no 'dad'/'bf'
			case 'camera follow opponent', 'focus camera on opponent':
				v2 != '' ? 'opponent|$v2' : 'opponent';

			case 'camera follow player', 'focus camera on bf':
				v2 != '' ? 'player|$v2' : 'player';

			case 'camera follow gf', 'focus camera on gf':
				'gf';

			// Hey!: v1 = target (BF/DAD/BOTH)
			case 'hey!', 'hey':
				switch (v1.toLowerCase())
				{
					case 'bf', 'boyfriend': 'bf:hey';
					case 'dad', 'opponent': 'dad:hey';
					default:               'bf:hey';
				};

			// Alt anim: v1 = BF/DAD/BOTH, v2 no usado
			case 'alt idle animation', 'alt anim', 'alt idle':
				switch (v1.toLowerCase())
				{
					case 'bf', 'boyfriend': 'bf|true';
					case 'dad', 'opponent': 'dad|true';
					default:               'bf|true';
				};

			// Camera Zoom: v1=targetZoom, v2=duration
			case 'camera zoom', 'zoom camera', 'set camera zoom':
				v2 != '' ? '$v1|$v2' : v1;

			// Toggle HUD: normalizar a true/false
			case 'toggle hud':
				'toggle';
			case 'hide hud':
				'false';
			case 'show hud', 'set hud visible':
				v1 != '' ? v1 : 'true';

			// Flash/Shake/Fade: combinar color+duración en v1|v2
			case 'camera flash', 'flash camera', 'flash screen',
			     'camera shake', 'shake camera', 'screen shake',
			     'camera fade',  'fade camera',  'fade screen':
				v1 != '' && v2 != '' ? '$v1|$v2' : (v1 != '' ? v1 : v2);

			// Play Video: v1=nombre video, v2=midSong
			case 'play video', 'show movie', 'play cutscene', 'video':
				v2 != '' ? '$v1|$v2' : v1;

			// Play Animation: Psych Engine v1=animName, v2=target(bf/dad/gf/0/1/2)
			// Cool Engine 'Play Anim' espera: value="target|animName"
			// BUG FIX: Sin este case caía al default produciendo "animName|target",
			// lo que hacía que EventManager tratara el nombre de anim como slot y
			// getCharacterByName("hey") devolvía null → animación nunca se ejecutaba.
			case 'play animation', 'character anim':
				final coolTarget = switch (v2.toLowerCase().trim())
				{
					case 'bf' | 'boyfriend': 'bf';
					case 'gf' | 'girlfriend': 'gf';
					case '1': 'bf';  // índice numérico Psych
					case '2': 'gf';  // índice numérico Psych
					default: (v2 != '') ? v2 : 'dad'; // dad es el default en Psych
				};
				v1 != '' ? '$coolTarget|$v1' : coolTarget;

			// Set Property / Run Function
			case 'set property', 'change property', 'set variable':
				'$v1|$v2';
			case 'run haxe code', 'run function', 'call function':
				v1;

			default:
				v1 != '' ? (v2 != '' ? '$v1|$v2' : v1) : v2;
		};
	}

	/** Populates song.characters and song.strumsGroups from legacy player1/player2 fields. */
	static function _buildCharactersFromLegacy(song:SwagSong):Void
	{
		if (song.characters != null && song.characters.length > 0) return;

		// BUG FIX A: 3 groups [gf(0), cpu(1), player(2)] — same as Song.parseJSONshit.
		// With only 2 groups, allStrumsGroups[1]='player_strums_0' → PlayState CPU routing
		// maps Dad's notes in BF sections to BF → BF sings opponent notes.

		// BUG FIX B: Always set explicit 'type' for EVERY character.
		// CharacterSlot._resolveCharType falls back to NAME INFERENCE when type==null.
		// Non-standard names like 'ray' (player1) don't start with 'bf' →
		// get typed as 'Opponent' → placed at dadPosition instead of boyfriendPosition
		// → visible on screen when the stage intentionally puts them off-screen.
		final gfName  = _str(song.gfVersion, 'gf');
		final dadName = _str(song.player2,   'dad');
		final bfName  = _str(song.player1,   'bf');

		song.characters = [
			{ name: gfName,  x: 0.0, y: 0.0, visible: true, isGF: true,  type: 'Girlfriend', strumsGroup: 'gf_strums_0'     },
			{ name: dadName, x: 0.0, y: 0.0, visible: true, isGF: false, type: 'Opponent',   strumsGroup: 'cpu_strums_0'    },
			{ name: bfName,  x: 0.0, y: 0.0, visible: true, isGF: false, type: 'Player',     strumsGroup: 'player_strums_0' }
		];

		song.strumsGroups = [
			{ id: 'gf_strums_0',     x: 400.0, y: 50.0, visible: false, cpu: true,  spacing: 110.0 },
			{ id: 'cpu_strums_0',    x: 100.0, y: 50.0, visible: true,  cpu: true,  spacing: 110.0 },
			{ id: 'player_strums_0', x: 740.0, y: 50.0, visible: true,  cpu: false, spacing: 110.0 }
		];
	}

	/** Converts milliseconds to step time given a BPM. */
	static inline function _msToStep(ms:Float, bpm:Float):Float
		return (ms / 1000) * (bpm / 60) * 4;

	/** Strips a leading "characters/" prefix from Psych image paths. */
	static function _normalizePath(path:String):String
	{
		// Psych stores "characters/BOYFRIEND"; Cool stores just "BOYFRIEND"
		// (Paths.characterJSON adds the folder automatically)
		if (path.startsWith('characters/'))
			return path.substr('characters/'.length);
		return path;
	}

	// ── Type-safe field extractors ────────────────────────────────────────────

	static inline function _str(v:Dynamic, def:String):String
		return (v != null) ? Std.string(v) : def;

	static inline function _float(v:Dynamic, def:Float):Float
	{
		if (v == null) return def;
		final f = Std.parseFloat(Std.string(v));
		return Math.isNaN(f) ? def : f;
	}

	// BUG FIX: Some Psych chart editors store booleans as integers (0/1).
	// Standard Haxe `v == true` returns false for the integer 1 because
	// they are different types in strict equality. This would cause
	// mustHitSection to always return the default (true), breaking all
	// sections where mustHitSection should be false.
	static inline function _bool(v:Dynamic, def:Bool):Bool
	{
		if (v == null)   return def;
		if (v == true)   return true;
		if (v == false)  return false;
		// Handle integer encoding: 0 = false, anything else = true
		final n = Std.parseFloat(Std.string(v));
		if (!Math.isNaN(n)) return n != 0;
		return def;
	}

	static function _hex2(n:Int):String
	{
		final h = StringTools.hex(n & 0xFF, 2);
		return h.length < 2 ? '0$h' : h;
	}
}
