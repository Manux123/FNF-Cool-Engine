package mods.compat;

using StringTools;

import haxe.Json;
import funkin.data.Song;
import funkin.data.Section;

/**
 * VSliceConverter
 * ─────────────────────────────────────────────────────────────────────────────
 * Convierte el formato de chart de Friday Night Funkin' v0.5+ (V-Slice / "2.0.0")
 * al SwagSong nativo de Cool Engine.
 *
 * ── Estructura del chart V-Slice ─────────────────────────────────────────────
 *
 *  {
 *    "version": "2.0.0",
 *    "generatedBy": "Friday Night Funkin' - v0.8.1",
 *    "scrollSpeed": { "erect": 2.2, "nightmare": 2.8 },
 *    "events": [
 *      { "t": 0,     "e": "FocusCamera",  "v": { "char": 1, "x": 0, "y": 0 } },
 *      { "t": 1234,  "e": "ZoomCamera",   "v": { "zoom": 1.2, "ease": "expoOut", "duration": 32, "mode": "stage" } },
 *      { "t": 5678,  "e": "SetCameraBop", "v": { "rate": 2, "intensity": 1 } }
 *    ],
 *    "notes": {
 *      "erect": [
 *        { "t": 759.49, "d": 7 },
 *        { "t": 806.96, "d": 6, "l": 237.34 },
 *        { "t": 1518.99, "d": 3, "l": 427.22, "k": "hurt" }
 *      ],
 *      "nightmare": [ ... ]
 *    }
 *  }
 *
 * ── Codificación de la dirección/carril (campo "d") ──────────────────────────
 *
 *  d = direction + (strumlineIndex * 4)
 *
 *    d 0-3  → strumline 0 (player / BF)   → lane 0-3  en Cool Engine
 *    d 4-7  → strumline 1 (opponent / Dad) → lane 4-7  en Cool Engine
 *    d 8-11 → strumline 2 (extra)          → lane 8-11 en Cool Engine
 *
 *  Dentro de cada strumline:
 *    %4 == 0 → Left  (0)
 *    %4 == 1 → Down  (1)
 *    %4 == 2 → Up    (2)
 *    %4 == 3 → Right (3)
 *
 *  El valor "d" de V-Slice coincide directamente con el rawNoteData que Cool Engine
 *  espera en sectionNotes[1], por lo que NO necesita transformación.
 *
 * ── Archivo de metadata (separado) ───────────────────────────────────────────
 *
 *  V-Slice separa el chart de la metadata. Si se conoce el path del chart
 *  (pasado como `chartFilePath`), el converter busca automáticamente:
 *
 *    songs/{folder}/{folder}-metadata.json
 *    songs/{folder}/metadata.json
 *    songs/{folder}/{folder}-metadata-{variation}.json  (ej: erect)
 *
 *  La metadata contiene: BPM (timeChanges), characters, stage, etc.
 *
 *  Ejemplo de metadata:
 *  {
 *    "version": "2.2.0",
 *    "songName": "Senpai",
 *    "artist": "Kawai Sprite",
 *    "timeChanges": [ { "t": 0, "bpm": 115 }, { "t": 4500, "bpm": 120 } ],
 *    "playData": {
 *      "stage": "school",
 *      "characters": { "player": "bf-pixel", "girlfriend": "gf-pixel", "opponent": "senpai" },
 *      "difficulties": ["easy", "normal", "hard", "erect", "nightmare"]
 *    }
 *  }
 *
 * ── Eventos V-Slice soportados ────────────────────────────────────────────────
 *
 *  FocusCamera  → Camera Follow   (char 0=bf, 1=dad, 2=gf)
 *  ZoomCamera   → Camera Zoom     (zoom|duration)
 *  SetCameraBop → Camera Bop Rate (rate)
 *  PlayAnimation → Play Anim      (target:anim)
 *  SetCharacter  → Change Character
 *  (otros)      → pass-through
 */
class VSliceConverter
{
	// ── Entry point ───────────────────────────────────────────────────────────

	/**
	 * Convierte un chart V-Slice al formato SwagSong de Cool Engine.
	 *
	 * @param rawJson       Contenido JSON del archivo de chart.
	 * @param difficulty    Dificultad a extraer (ej: "erect", "hard").
	 * @param chartFilePath Path físico al archivo .json (para buscar metadata).
	 */
	public static function convertChart(rawJson:String, difficulty:String = 'hard', ?chartFilePath:String):SwagSong
	{
		trace('[VSliceConverter] Converting chart (diff=$difficulty)...');

		final root:Dynamic = Json.parse(rawJson);

		// Normalizar dificultad: si viene como "ugh-erect" (nombre de archivo completo),
		// extraer solo la parte de dificultad real ("erect") quitando el prefijo de canción.
		// Esto ocurre porque Song.loadFromJson pasa el filename como diff ("ugh-erect").
		if (chartFilePath != null && chartFilePath != '')
		{
			final folderName = _folderName(_parentDir(chartFilePath)).toLowerCase();
			final prefix = folderName + '-';
			if (difficulty.toLowerCase().startsWith(prefix))
				difficulty = difficulty.substr(prefix.length);
		}

		trace('[VSliceConverter] difficulty normalizada: $difficulty');

		// ── 1. Cargar metadata (BPM, personajes, stage) ──────────────────────
		final meta = _loadMetadata(root, chartFilePath, difficulty);

		final bpm:Float = meta.bpm;
		final stage:String = meta.stage;
		final player:String = meta.player;
		final gf:String = meta.gf;
		final opponent:String = meta.opponent;
		final timeChanges:Array<{t:Float, bpm:Float}> = meta.timeChanges;

		// ── 2. Determinar scroll speed ────────────────────────────────────────
		final scrollSpeedObj:Dynamic = root.scrollSpeed;
		var speed:Float = 1.0;
		if (scrollSpeedObj != null)
		{
			// Buscar la dificultad exacta, luego sin case, luego usar primera disponible
			var found:Null<Float> = null;
			for (d in _diffVariants(difficulty))
			{
				final v = Reflect.field(scrollSpeedObj, d);
				if (v != null)
				{
					found = _float(v, 1.0);
					break;
				}
			}
			if (found == null)
			{
				// Primera key del objeto
				for (k in Reflect.fields(scrollSpeedObj))
				{
					found = _float(Reflect.field(scrollSpeedObj, k), 1.0);
					break;
				}
			}
			if (found != null)
				speed = found;
		}

		// ── 3. Construir SwagSong base ────────────────────────────────────────
		final song:SwagSong = {
			song: meta.songName,
			bpm: bpm,
			speed: speed,
			needsVoices: true,
			stage: stage,
			validScore: true,
			notes: [],
			// Legacy fields (para que Song.parseJSONshit migre a nuevo sistema)
			player1: player,
			player2: opponent,
			gfVersion: gf,
			characters: null,
			strumsGroups: null,
			events: []
		};

		// ── 4. Obtener las notas para esta dificultad ─────────────────────────
		final allNotes:Dynamic = root.notes;
		var diffNotes:Array<Dynamic> = [];
		if (allNotes != null)
		{
			for (d in _diffVariants(difficulty))
			{
				final n = Reflect.field(allNotes, d);
				if (n != null && Std.isOfType(n, Array))
				{
					diffNotes = cast n;
					break;
				}
			}
			// Si no hay coincidencia, usar la primera dificultad disponible
			if (diffNotes.length == 0)
			{
				for (k in Reflect.fields(allNotes))
				{
					final n = Reflect.field(allNotes, k);
					if (n != null && Std.isOfType(n, Array))
					{
						diffNotes = cast n;
						break;
					}
				}
			}
		}

		// ── 5. Convertir notas a secciones ────────────────────────────────────
		_buildSections(song, diffNotes, timeChanges);

		// ── 6. Convertir eventos ──────────────────────────────────────────────
		final rawEvents:Dynamic = root.events;
		if (rawEvents != null && Std.isOfType(rawEvents, Array))
		{
			final evArr:Array<Dynamic> = cast rawEvents;
			for (ev in evArr)
			{
				final timeMs:Float = _float(ev.t, 0);
				final stepTime:Float = _msToStep(timeMs, bpm);
				final kind:String = _str(ev.e, '');
				final value:Dynamic = ev.v;

				final mapped = _mapEvent(kind, value);
				if (mapped != null)
					song.events.push({stepTime: stepTime, type: mapped.type, value: mapped.value});
			}
		}

		// ── 7. Eventos de BPM change desde timeChanges ───────────────────────
		// Solo añadir los cambios secundarios (el primero es el BPM base)
		for (i in 1...timeChanges.length)
		{
			final tc = timeChanges[i];
			final stepTime = _msToStep(tc.t, bpm);
			song.events.push({stepTime: stepTime, type: 'BPM Change', value: Std.string(tc.bpm)});
		}

		trace('[VSliceConverter] Done. Sections=${song.notes.length}, Events=${song.events.length}, BPM=$bpm, Stage=$stage');
		return song;
	}

	// ── Secciones ─────────────────────────────────────────────────────────────

	/**
	 * Agrupa las notas V-Slice en secciones de 16 pasos.
	 *
	 * Cada sección tiene una duración determinada por el BPM vigente en ese punto.
	 * Con múltiples timeChanges se recalcula la duración de sección dinámicamente.
	 *
	 * mustHitSection se determina por la mayoría de notas en esa sección:
	 *   - Si la mayoría son del jugador (d < 4), mustHitSection = true
	 *   - Si la mayoría son del oponente (d >= 4), mustHitSection = false
	 */
	static function _buildSections(song:SwagSong, notes:Array<Dynamic>, timeChanges:Array<{t:Float, bpm:Float}>):Void
	{
		if (notes == null || notes.length == 0)
		{
			// Al menos una sección vacía para que el engine no crashee
			song.notes.push(_emptySection(song.bpm, true));
			return;
		}

		// Ordenar notas por tiempo
		notes.sort((a, b) -> (_float(a.t, 0) < _float(b.t, 0)) ? -1 : 1);

		// Duración de una sección = 16 pasos = 4 beats
		// stepDurationMs = (60000 / bpm) / 4
		// sectionDurationMs = 16 * stepDurationMs = (60000 / bpm) * 4

		// Construir mapa de tiempo→BPM desde timeChanges
		final tcList = timeChanges.copy();
		tcList.sort((a, b) -> a.t < b.t ? -1 : 1);

		// Calcular dónde cae cada sección (en ms) para asignar notas correctamente
		final lastNoteTime:Float = _float(notes[notes.length - 1].t, 0) + _float(notes[notes.length - 1].l, 0);

		// Generar posiciones de secciones hasta cubrir todas las notas + 1 extra
		final sectionStarts:Array<Float> = [];
		final sectionBpms:Array<Float> = [];
		final sectionMustHits:Array<Bool> = [];
		final sectionNoteArrays:Array<Array<Dynamic>> = [];

		var cursor:Float = 0; // ms desde el inicio
		var currentBpm:Float = (tcList.length > 0) ? tcList[0].bpm : song.bpm;
		var tcIdx:Int = 1; // índice al siguiente cambio de BPM pendiente

		while (cursor <= lastNoteTime + _sectionDurationMs(currentBpm))
		{
			// Actualizar BPM si hay un cambio antes del cursor actual
			while (tcIdx < tcList.length && tcList[tcIdx].t <= cursor)
			{
				currentBpm = tcList[tcIdx].bpm;
				tcIdx++;
			}

			sectionStarts.push(cursor);
			sectionBpms.push(currentBpm);
			sectionNoteArrays.push([]);

			cursor += _sectionDurationMs(currentBpm);
		}

		// Asignar cada nota a su sección
		for (n in notes)
		{
			final t:Float = _float(n.t, 0);
			// Buscar sección por tiempo (binary-ish, lineal suficiente para chart sizes)
			var secIdx:Int = sectionStarts.length - 1;
			for (i in 0...sectionStarts.length - 1)
			{
				if (t < sectionStarts[i + 1])
				{
					secIdx = i;
					break;
				}
			}
			// El "d" de V-Slice = lane directamente en Cool Engine
			final lane:Int = Std.int(_float(n.d, 0));
			final hold:Float = _float(n.l, 0);
			final kind:String = (n.k != null) ? Std.string(n.k) : '';

			if (kind != '')
				sectionNoteArrays[secIdx].push([t, lane, hold, kind]);
			else
				sectionNoteArrays[secIdx].push([t, lane, hold]);
		}

		// Determinar mustHitSection.
		// En V-Slice la asignación de notas a strumlines está FIJA:
		//   d 0-3 (groupIdx=0) → siempre jugador (BF)
		//   d 4-7 (groupIdx=1) → siempre oponente (Dad/CPU)
		// NoteManager deriva quién toca una nota así:
		//   groupIdx 0 → gottaHitNote = mustHitSection
		//   groupIdx 1 → gottaHitNote = !mustHitSection
		// Para que esto funcione correctamente con el encoding absoluto de V-Slice,
		// mustHitSection DEBE ser true en TODAS las secciones.
		// Si fuera false, las notas d 0-3 irían al CPU y d 4-7 al jugador — incorrecto.
		// La cámara se controla con eventos FocusCamera, no con mustHitSection.
		for (i in 0...sectionNoteArrays.length)
			sectionMustHits.push(true);

		// Añadir secciones al song (omitir las completamente vacías al final)
		var lastNonEmpty:Int = 0;
		for (i in 0...sectionNoteArrays.length)
			if (sectionNoteArrays[i].length > 0)
				lastNonEmpty = i;

		for (i in 0...(lastNonEmpty + 2)) // +2 = incluir última vacía de cierre
		{
			if (i >= sectionStarts.length)
				break;
			song.notes.push({
				sectionNotes: i < sectionNoteArrays.length ? sectionNoteArrays[i] : [],
				lengthInSteps: 16,
				typeOfSection: 0,
				mustHitSection: i < sectionMustHits.length ? sectionMustHits[i] : true,
				bpm: i < sectionBpms.length ? sectionBpms[i] : song.bpm,
				changeBPM: i > 0 && i < sectionBpms.length && sectionBpms[i] != sectionBpms[i - 1],
				altAnim: false
			});
		}
	}

	static inline function _sectionDurationMs(bpm:Float):Float
		return (60000.0 / bpm) * 4.0; // 16 steps = 4 beats

	static function _emptySection(bpm:Float, mustHit:Bool):SwagSection
	{
		return {
			sectionNotes: [],
			lengthInSteps: 16,
			typeOfSection: 0,
			mustHitSection: mustHit,
			bpm: bpm,
			changeBPM: false,
			altAnim: false
		};
	}

	// ── Eventos ───────────────────────────────────────────────────────────────

	/**
	 * Convierte un evento V-Slice a su equivalente en Cool Engine.
	 * Devuelve null si el evento debe ignorarse.
	 */
	static function _mapEvent(kind:String, value:Dynamic):Null<{type:String, value:String}>
	{
		return switch (kind.toLowerCase())
		{
			// ── Cámara ────────────────────────────────────────────────────────
			case 'focuscamera', 'focus camera':
				/*
				 * V-Slice char index:
				 *   0 = player (BF)
				 *   1 = opponent (Dad)
				 *   2 = girlfriend (GF)
				 * Cool Engine Camera Follow value: "bf" / "dad" / "gf"
				 */
				final charIdx:Int = value != null ? Std.int(_float(value.char, 0)) : 0;
				final target = switch (charIdx)
				{
					case 0: 'bf';
					case 1: 'dad';
					case 2: 'gf';
					default: 'bf';
				};
				{type: 'Camera Follow', value: target};

			case 'zoomcamera', 'zoom camera':
				/*
				 * V-Slice: { zoom, ease, duration, mode }
				 * Cool Engine: "Camera Zoom" with value "zoom|duration"
				 */
				final zoom = value != null ? _str(value.zoom, '1') : '1';
				final duration = value != null ? _str(value.duration, '4') : '4';
				final ease = value != null ? _str(value.ease, '') : '';
				final mode = value != null ? _str(value.mode, '') : '';
				var composed = '$zoom|$duration';
				if (ease != '')
					composed += '|$ease';
				if (mode != '')
					composed += '|$mode';
				{type: 'Camera Zoom', value: composed};

			case 'setcamerabop', 'set camera bop', 'camerabop':
				final rate = value != null ? _str(value.rate, '1') : '1';
				{type: 'Camera Bop Rate', value: rate};

			// ── Animaciones ───────────────────────────────────────────────────
			case 'playanimation', 'play animation', 'play anim':
				/*
				 * V-Slice: { targetCharacterId, animation, force }
				 * Cool Engine: "Play Anim" with value "target:anim"
				 */
				if (value == null) {
					type: 'Play Anim', 
					value: 'bf:idle'
				}
				else
				{
					final target = _str(value.targetCharacterId ?? value.target, 'bf');
					final anim = _str(value.animation ?? value.anim, 'idle');
					{type: 'Play Anim', value: '$target:$anim'};
				}

			// ── Personajes ────────────────────────────────────────────────────
			case 'setcharacter', 'set character', 'change character':
				if (value == null) null; else
				{
					final target = _str(value.targetCharacterId ?? value.target, 'bf');
					final character = _str(value.characterId ?? value.character, 'bf');
					{type: 'Change Character', value: '$target|$character'};
				}

			// ── Salud ─────────────────────────────────────────────────────────
			case 'sethealth', 'set health', 'health':
				if (value == null) null; else {type: 'Health Change', value: _str(value.value ?? value.health, '1')};

			// ── HUD ───────────────────────────────────────────────────────────
			case 'sethudvisible', 'set hud visible', 'togglehud', 'toggle hud':
				{type: 'HUD Visible', value: 'toggle'};

			// ── Stage ─────────────────────────────────────────────────────────
			case 'setstage', 'set stage', 'changestage', 'change stage':
				if (value == null) null; else {type: 'Change Stage', value: _str(value.stageId ?? value.stage, 'stage')};

			// ── Desconocidos: pasar tal cual ──────────────────────────────────
			default:
				final valStr = (value != null) ? Json.stringify(value) : '';
				{type: kind, value: valStr};
		};
	}

	// ── Carga de metadata ─────────────────────────────────────────────────────

	/**
	 * Estructura de metadata resuelta (para uso interno).
	 */
	static var _MetaResult = {
		bpm: 100.0,
		stage: 'stage',
		player: 'bf',
		gf: 'gf',
		opponent: 'dad',
		songName: 'Unknown',
		timeChanges: new Array<{t:Float, bpm:Float}>()
	};

	/**
	 * Intenta cargar la metadata del song V-Slice.
	 *
	 * Orden de búsqueda (usando chartFilePath para determinar la carpeta):
	 *   1. {folder}/{songName}-metadata.json
	 *   2. {folder}/metadata.json
	 *   3. {folder}/{songName}-metadata-{variation}.json  (ej: senpai-metadata-erect.json)
	 *
	 * Si no se encuentra nada, usa valores por defecto.
	 */
	static function _loadMetadata(chartRoot:Dynamic, chartFilePath:Null<String>, difficulty:String):Dynamic
	{
		// Objeto resultado con defaults
		final result = {
			bpm: 100.0,
			stage: 'stage_week1',
			player: 'bf',
			gf: 'gf',
			opponent: 'dad',
			songName: 'Unknown',
			timeChanges: new Array<{t:Float, bpm:Float}>()
		};

		#if sys
		// Determinar la carpeta del chart
		if (chartFilePath != null && chartFilePath != '')
		{
			final dir = _parentDir(chartFilePath);
			// Inferir nombre de canción del nombre de carpeta o del archivo
			final folderName = _folderName(dir);
			result.songName = _capitalize(folderName);

			// Si la dificultad viene como "ugh-erect" (nombre de archivo completo),
			// extraer solo la parte de dificultad quitando el prefijo "ugh-".
			// Esto cubre loadFromJson que pasa el filename completo como diff.
			var cleanDiff = difficulty.toLowerCase();
			final prefix = folderName.toLowerCase() + '-';
			if (cleanDiff.startsWith(prefix))
				cleanDiff = cleanDiff.substr(prefix.length);

			// Variantes de casing del difficulty limpio (erect/Erect/ERECT)
			final _diffVarsFile:Array<String> = [];
			{
				inline function _addDV(v:String) if (v != '' && !_diffVarsFile.contains(v)) _diffVarsFile.push(v);
				_addDV(cleanDiff.toLowerCase());
				_addDV(cleanDiff.toUpperCase());
				_addDV(cleanDiff.charAt(0).toUpperCase() + cleanDiff.substr(1).toLowerCase());
				_addDV(cleanDiff);
				// También añadir la variante original por si acaso
				_addDV(difficulty.toLowerCase());
				_addDV(difficulty);
			}

			// IMPORTANTE: variante específica de dificultad PRIMERO, luego fallback genérico.
			// Si buscamos "erect" debe cargar ugh-metadata-erect.json ANTES que ugh-metadata.json,
			// ya que el genérico tiene stage/personajes de la versión base (no erect).
			final candidates:Array<String> = [];
			for (_dv in _diffVarsFile)
				candidates.push('$dir/${folderName}-metadata-${_dv}.json');
			candidates.push('$dir/${folderName}-metadata-default.json');
			// Genérico solo como último recurso
			candidates.push('$dir/$folderName-metadata.json');
			candidates.push('$dir/metadata.json');
			// También buscar en carpeta padre si estamos dentro de una subcarpeta de variación
			final parentDir = _parentDir(dir);
			final parentFolder = _folderName(parentDir);
			if (parentFolder != '' && parentFolder != folderName)
			{
				candidates.push('$parentDir/$parentFolder-metadata.json');
				candidates.push('$parentDir/metadata.json');
			}

			for (path in candidates)
			{
				if (!sys.FileSystem.exists(path))
					continue;
				try
				{
					final raw = sys.io.File.getContent(path);
					final meta:Dynamic = Json.parse(raw);
					_applyMetadata(meta, result);
					trace('[VSliceConverter] Metadata cargada desde: $path');
					break;
				}
				catch (e:Dynamic)
				{
					trace('[VSliceConverter] Error leyendo metadata "$path": $e');
				}
			}

			// BUGFIX: Si no encontramos metadata en el directorio del chart (p.ej. el chart
			// está en assets/ pero la metadata está en mods/base_game/songs/), buscar en
			// TODOS los mods instalados. Esto cubre el caso V-Slice donde base_game tiene
			// los charts en assets/ y la metadata en mods/base_game/.
			if (result.stage == 'stage_week1' && result.player == 'bf' && result.opponent == 'dad')
			{
				for (mod in mods.ModManager.installedMods)
				{
					if (!mods.ModManager.isEnabled(mod.id)) continue;
					final modSongDir = '${mods.ModManager.MODS_FOLDER}/${mod.id}/songs/$folderName';
					if (!sys.FileSystem.exists(modSongDir)) continue;

					final modCandidates:Array<String> = [
						'$modSongDir/$folderName-metadata.json',
						'$modSongDir/metadata.json',
					];
					for (_dv in _diffVarsFile)
						modCandidates.push('$modSongDir/${folderName}-metadata-${_dv}.json');
					modCandidates.push('$modSongDir/${folderName}-metadata-default.json');

					var foundInMod = false;
					for (mpath in modCandidates)
					{
						if (!sys.FileSystem.exists(mpath)) continue;
						try
						{
							final raw = sys.io.File.getContent(mpath);
							final meta:Dynamic = Json.parse(raw);
							_applyMetadata(meta, result);
							trace('[VSliceConverter] Metadata encontrada en mod "${mod.id}": $mpath');
							foundInMod = true;
							break;
						}
						catch (e:Dynamic)
						{
							trace('[VSliceConverter] Error leyendo metadata mod "$mpath": $e');
						}
					}
					if (foundInMod) break;
				}
			}
		}
		#end

		// Si no encontramos metadata, intentar extraer BPM de los eventos del chart
		// (algunos charts V-Slice tienen "timeChanges" en el propio chart - V-Slice 2.1+)
		if (result.timeChanges.length == 0)
		{
			final chartTc:Dynamic = chartRoot.timeChanges;
			if (chartTc != null && Std.isOfType(chartTc, Array))
				_parseTimeChanges(cast chartTc, result);
		}

		// BPM fallback: usar el primero de timeChanges
		if (result.timeChanges.length > 0)
			result.bpm = result.timeChanges[0].bpm;
		else
			result.timeChanges.push({t: 0.0, bpm: result.bpm});

		return result;
	}

	/** Aplica los campos de un JSON de metadata al objeto resultado. */
	static function _applyMetadata(meta:Dynamic, result:Dynamic):Void
	{
		// ── Nombre ───────────────────────────────────────────────────────────
		if (meta.songName != null)
			result.songName = _str(meta.songName, result.songName);

		// ── BPM / timeChanges ─────────────────────────────────────────────────
		final tcRaw:Dynamic = meta.timeChanges;
		if (tcRaw != null && Std.isOfType(tcRaw, Array))
			_parseTimeChanges(cast tcRaw, result);

		// ── playData ─────────────────────────────────────────────────────────
		final pd:Dynamic = meta.playData;
		if (pd != null)
		{
			if (pd.stage != null)
				result.stage = _str(pd.stage, result.stage);

			final chars:Dynamic = pd.characters;
			if (chars != null)
			{
				if (chars.player != null)
					result.player = _str(chars.player, result.player);
				if (chars.girlfriend != null)
					result.gf = _str(chars.girlfriend, result.gf);
				if (chars.opponent != null)
					result.opponent = _str(chars.opponent, result.opponent);
			}
		}
	}

	/** Parsea un array de timeChanges V-Slice → array de {t, bpm}. */
	static function _parseTimeChanges(arr:Array<Dynamic>, result:Dynamic):Void
	{
		result.timeChanges = [];
		for (tc in arr)
		{
			final t = _float(tc.t ?? tc.time ?? tc.timeStamp, 0.0);
			final bpm = _float(tc.bpm ?? tc.BPM, 100.0);
			if (bpm > 0)
				result.timeChanges.push({t: t, bpm: bpm});
		}
		if (result.timeChanges.length > 0)
			result.bpm = result.timeChanges[0].bpm;
	}

	// ── Helpers de rutas ──────────────────────────────────────────────────────

	static function _parentDir(path:String):String
	{
		final sep1 = path.lastIndexOf('/');
		final sep2 = path.lastIndexOf('\\');
		final sep = Std.int(Math.max(sep1, sep2));
		return sep >= 0 ? path.substr(0, sep) : '';
	}

	static function _folderName(dir:String):String
	{
		final sep1 = dir.lastIndexOf('/');
		final sep2 = dir.lastIndexOf('\\');
		final sep = Std.int(Math.max(sep1, sep2));
		return sep >= 0 ? dir.substr(sep + 1) : dir;
	}

	static function _capitalize(s:String):String
		return s.length > 0 ? s.charAt(0).toUpperCase() + s.substr(1) : s;

	// ── Helpers de conversión ─────────────────────────────────────────────────

	/**
	 * Genera variantes de nombre de dificultad para búsqueda tolerante.
	 * "Erect" → ["Erect", "erect", "ERECT"]
	 */
	static function _diffVariants(diff:String):Array<String>
	{
		final variants:Array<String> = [];
		function add(v:String)
			if (v != '' && !variants.contains(v))
				variants.push(v);
		add(diff);
		add(diff.toLowerCase());
		add(diff.toUpperCase());
		add(diff.charAt(0).toUpperCase() + diff.substr(1).toLowerCase());
		return variants;
	}

	/** Convierte milisegundos a pasos dados un BPM. */
	static inline function _msToStep(ms:Float, bpm:Float):Float
		return (ms / 1000.0) * (bpm / 60.0) * 4.0;

	// ── Extractores de campos con tipo seguro ─────────────────────────────────

	static inline function _str(v:Dynamic, def:String):String
		return (v != null) ? Std.string(v) : def;

	static inline function _float(v:Dynamic, def:Float):Float
	{
		if (v == null)
			return def;
		final f = Std.parseFloat(Std.string(v));
		return Math.isNaN(f) ? def : f;
	}
}
