package funkin.data;

import funkin.data.Section.SwagSection;
import haxe.Json;
import haxe.format.JsonParser;
import lime.utils.Assets;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

/**
 * Datos de un slot de personaje
 */
typedef CharacterSlotData =
{
	var name:String; // Nombre del personaje (ej: "bf", "dad", "pico")
	var x:Float; // Posición X
	var y:Float; // Posición Y
	var ?flip:Bool; // Voltear sprite
	var ?scale:Float; // Escala del personaje
	var ?visible:Bool; // Visibilidad del personaje
	// === CAMPOS DEL CHART EDITOR ===
	var ?type:String; // "Opponent", "Player", "Girlfriend", "Other"
	var ?strumsGroup:String; // ID del StrumsGroup al que está vinculado (para la cámara y las notas)
	var ?isGF:Bool;  // true si el personaje es la GF (solo baila, no canta notas)
}

/**
 * Datos de un grupo de strums (4 flechas)
 */
typedef StrumsGroupData =
{
	var id:String; // ID único del grupo (ej: "bf_strums_1", "dad_strums_1")
	var x:Float; // Posición X base
	var y:Float; // Posición Y
	var visible:Bool; // Si se muestran o no
	var cpu:Bool; // Si es CPU o jugador
	var ?spacing:Float; // Espaciado entre flechas (default 160)
	var ?scale:Float; // Escala de las flechas
	var ?characters:Array<String>; // Personajes vinculados a este grupo (igual que Codename)
}

/**
 * Evento del chart editor (Camera, BPM Change, etc.)
 */
typedef ChartEvent =
{
	var stepTime:Float; // Step en el que ocurre
	var type:String;    // "Camera", "BPM Change", "Alt Anim", "Play Anim", "Camera Zoom", etc.
	var value:String;   // Valor del evento (ej: "dad", "1.2", etc.)
}

/**
 * SwagSong MEJORADO - Soporte para múltiples personajes
 */
typedef SwagSong =
{
	var song:String;
	var notes:Array<SwagSection>;
	var bpm:Float;
	var needsVoices:Bool;
	var speed:Float;
	
	// === LEGACY SUPPORT (compatibilidad con charts viejos) ===
	@:optional var player1:String; // BF (legacy)
	@:optional var player2:String; // Dad (legacy)
	@:optional var gfVersion:String; // GF (legacy)
	
	// === NUEVO SISTEMA MULTI-CHARACTER ===
	@:optional var characters:Array<CharacterSlotData>; // Array de personajes
	@:optional var strumsGroups:Array<StrumsGroupData>; // Array de grupos de strums

	// === EVENTOS DEL CHART EDITOR ===
	@:optional var events:Array<ChartEvent>; // Eventos (camera, bpm change, etc.)
	
	var stage:String;
	var validScore:Bool;

	// === V-SLICE AUDIO VARIATION ===
	/**
	 * Variante de audio forzada por el metadata V-Slice (playData.characters.instrumental).
	 * Si está definida, Paths.inst() / Paths.voices() usan este sufijo en lugar del
	 * sufijo de dificultad. Ej: "erect" → carga Inst-erect.ogg para TODAS las dificultades.
	 * Null = comportamiento normal (usar sufijo de dificultad).
	 */
	@:optional var instSuffix:Null<String>;

	/** Artista de la canción (leído del campo "artist" del metadata V-Slice). */
	@:optional var artist:Null<String>;
}

class Song
{
	public var song:String;
	public var notes:Array<SwagSection>;
	public var bpm:Float;
	public var needsVoices:Bool = true;
	public var speed:Float = 1;

	// Legacy
	public var player1:String = 'bf';
	public var player2:String = 'dad';
	public var gfVersion:String = 'gf';
	
	// Nuevo sistema
	public var characters:Array<CharacterSlotData> = [];
	public var strumsGroups:Array<StrumsGroupData> = [];

	public function new(song, notes, bpm)
	{
		this.song = song;
		this.notes = notes;
		this.bpm = bpm;
	}

	/**
	 * Carga un chart desde JSON.
	 *
	 * Orden de búsqueda:
	 *   1. mods/{activeMod}/songs/{folder}/{jsonInput}.json
	 *   2. assets/songs/{folder}/{jsonInput}.json
	 */
	/**
	 * Genera variantes normalizadas de un nombre para cubrir mods Cool Engine
	 * que usan espacios en lugar de guiones y caracteres especiales distintos.
	 * Ejemplo: "break it down!" → ["break it down!", "break-it-down!", "break-it-down", ...]
	 */
	static function _nameVariants(name:String):Array<String>
	{
		final variants:Array<String> = [];
		function add(v:String) { v = v.trim(); if (v != '' && variants.indexOf(v) == -1) variants.push(v); }
		add(name);
		add(name.replace(' ', '-'));
		add(name.replace('-', ' '));
		add(name.replace('!', ''));
		add(name.replace(' ', '-').replace('!', ''));
		add(name.replace('-', ' ').replace('!', ''));
		return variants;
	}

	/**
	 * Resuelve la ruta real de un chart con normalización de
	 * espacios/guiones y caracteres especiales en folder y diff.
	 * Busca en el mod activo primero, luego en assets/.
	 * @return  Ruta al .json, o null si no existe.
	 */
	public static function findChart(folder:String, diff:String):Null<String>
	{
		#if sys
		final folderVars = _nameVariants(folder.toLowerCase());
		final diffVars   = _nameVariants(diff.toLowerCase());

		// Buscar en TODOS los mods habilitados (no solo el activo).
		// Esto permite que songs de mods como "base_game" sean encontradas
		// aunque el mod activo sea otro (p.ej. "zone-tan").
		final modsToSearch:Array<String> = [];
		if (mods.ModManager.isActive())
			modsToSearch.push(mods.ModManager.modRoot());
		#if sys
		for (mod in mods.ModManager.installedMods)
		{
			if (!mods.ModManager.isEnabled(mod.id)) continue;
			final root = '${mods.ModManager.MODS_FOLDER}/${mod.id}';
			if (!modsToSearch.contains(root))
				modsToSearch.push(root);
		}
		#end

		for (modRoot in modsToSearch)
		{
			for (fv in folderVars)
				for (dv in diffVars)
				{
					// Cool / Psych flat: songs/name/hard.json
					for (base in ['$modRoot/songs', '$modRoot/assets/songs'])
					{
						final p = '$base/$fv/$dv.json';
						if (FileSystem.exists(p)) return p;
					}
					// V-Slice: songs/name/name-chart.json  (todos los diffs en un archivo)
					for (base in ['$modRoot/songs', '$modRoot/assets/songs'])
					{
						final p = '$base/$fv/$fv-chart.json';
						if (FileSystem.exists(p)) return p;
					}
					// Psych: data/name/name-diff.json  o  data/name/diff.json
					for (base in ['$modRoot/data', '$modRoot/assets/data'])
					{
						for (p in ['$base/$fv/$fv-$dv.json', '$base/$fv/$dv.json'])
							if (FileSystem.exists(p)) return p;
					}
				}
		}

		for (fv in folderVars)
			for (dv in diffVars)
			{
				final p = 'assets/songs/$fv/$dv.json';
				if (FileSystem.exists(p)) return p;
			}

		// V-Slice: assets/songs/name/name-chart.json  (todos los diffs en un archivo)
		for (fv in folderVars)
		{
			final p = 'assets/songs/$fv/$fv-chart.json';
			if (FileSystem.exists(p)) return p;
		}

		return null;
		#else
		final assetPath = Paths.jsonSong('${folder.toLowerCase()}/${diff.toLowerCase()}');
		return Assets.exists(assetPath) ? assetPath : null;
		#end
	}

	/**
	 * Carga un chart desde JSON con normalización automática de nombres.
	 * Cubre mods Cool Engine con espacios/guiones mezclados en folder o diff.
	 */
	public static function loadFromJson(jsonInput:String, ?folder:String):SwagSong
	{
		final songFolder = folder != null ? folder.toLowerCase() : '';
		final diffName   = jsonInput.toLowerCase();

		trace('[Song] loadFromJson: folder=$folder, diff=$jsonInput');

		// ── Prioridad 1: archivo .level (nuevo formato) ───────────────────
		#if sys
		final levelSuffix = _diffNameToSuffix(songFolder, diffName);
		final levelSong   = funkin.data.LevelFile.loadDiff(songFolder, levelSuffix);
		if (levelSong != null)
		{
			trace('[Song] Cargado desde .level: $songFolder diff=$levelSuffix');
			ensureMigrated(levelSong);
			levelSong.validScore = true;
			return levelSong;
		}
		#end

		// ── Prioridad 2: .json legacy ─────────────────────────────────────
		var rawJson:String = null;

		#if sys
		final resolvedPath = findChart(songFolder, diffName);
		if (resolvedPath != null)
		{
			rawJson = File.getContent(resolvedPath).trim();
			trace('[Song] Cargado desde: $resolvedPath');
		}
		#else
		final assetPath = Paths.jsonSong('$songFolder/$diffName');
		if (Assets.exists(assetPath))
		{
			rawJson = Assets.getText(assetPath).trim();
			trace('[Song] Cargado desde Assets: $assetPath');
		}
		#end

		if (rawJson == null)
		{
			trace('[Song] ERROR: Chart not found: $songFolder/$diffName');
			throw 'Chart not found: $songFolder/$diffName';
		}

		while (rawJson.length > 0 && rawJson.charAt(rawJson.length - 1) != '}')
			rawJson = rawJson.substr(0, rawJson.length - 1);

		return parseJSONshit(rawJson, resolvedPath, diffName);
	}

	/**
	 * Convierte el diffName que usa loadFromJson (ej: 'bopeebo-hard' o 'hard')
	 * al sufijo que usa LevelFile (ej: '-hard' o '').
	 */
	static function _diffNameToSuffix(folder:String, diffName:String):String
	{
		// Quitar el prefijo del folder si viene con él (ej: 'bopeebo-hard' → '-hard')
		if (diffName.startsWith(folder + '-'))
			return diffName.substr(folder.length);
		// Sufijo puro (ej: 'hard' → '-hard', 'normal'/'folder' → '')
		if (diffName == 'normal' || diffName == folder) return '';
		if (diffName == 'easy')  return '-easy';
		if (diffName == 'hard')  return '-hard';
		return '-' + diffName;
	}

	public static function parseJSONshit(rawJson:String, ?chartFilePath:String = null,
	                                      ?difficulty:String = 'hard'):SwagSong
	{
		trace('[Song] === parseJSONshit LLAMADO ===');
		
		var swagShit:SwagSong = cast mods.compat.ModCompatLayer.loadChart(rawJson, difficulty, chartFilePath);
		
		swagShit.validScore = true;
		
		trace('[Song] characters antes de migración: ' + (swagShit.characters != null ? swagShit.characters.length + ' personajes' : 'NULL'));
		trace('[Song] strumsGroups antes de migración: ' + (swagShit.strumsGroups != null ? swagShit.strumsGroups.length + ' grupos' : 'NULL'));
		
		// === AUTO-MIGRATION: Convertir formato legacy a nuevo ===
		if (swagShit.characters == null || swagShit.characters.length == 0)
		{
			trace('[Song] Detectado formato legacy, convirtiendo a nuevo formato...');
			trace('[Song] player1 (bf): ' + swagShit.player1);
			trace('[Song] player2 (dad): ' + swagShit.player2);
			trace('[Song] gfVersion: ' + swagShit.gfVersion);
			
			swagShit.characters = [];
			swagShit.strumsGroups = [];
			
			// Crear personajes por defecto.
			// BUG FIX: Usar 'type' explícito — CharacterSlot infiere por nombre si type==null.
			// Nombres no estándar ('ray', 'mighty') → tipificados como Opponent → posición incorrecta.
			var gfChar:CharacterSlotData = {
				name: swagShit.gfVersion != null ? swagShit.gfVersion : 'gf',
				x: 0, y: 0, visible: true,
				isGF: true, type: 'Girlfriend',
				strumsGroup: 'gf_strums_0'
			};
			
			var dadChar:CharacterSlotData = {
				name: swagShit.player2 != null ? swagShit.player2 : 'dad',
				x: 0, y: 0, visible: true,
				type: 'Opponent',
				strumsGroup: 'cpu_strums_0'
			};
			
			var bfChar:CharacterSlotData = {
				name: swagShit.player1 != null ? swagShit.player1 : 'bf',
				x: 0, y: 0, visible: true,
				type: 'Player',
				strumsGroup: 'player_strums_0'
			};
			
			swagShit.characters = [gfChar, dadChar, bfChar];
			
			// Crear grupos de strums por defecto
			// GF tiene su propio grid (visible: false por defecto — no tiene notas propias)
			var gfStrums:StrumsGroupData = {
				id: 'gf_strums_0',
				x: 400,
				y: 50,
				visible: false,  // Las flechas de GF están ocultas por defecto
				cpu: true,
				spacing: 110,
				characters: [gfChar.name]
			};

			var cpuStrums:StrumsGroupData = {
				id: 'cpu_strums_0',
				x: 100,
				y: 50,
				visible: true,
				cpu: true,
				spacing: 110,
				characters: [dadChar.name]
			};
			
			var playerStrums:StrumsGroupData = {
				id: 'player_strums_0',
				x: 740,
				y: 50,
				visible: true,
				cpu: false,
				spacing: 110,
				characters: [bfChar.name]
			};
			
			swagShit.strumsGroups = [gfStrums, cpuStrums, playerStrums];
			
			trace('[Song] Migración completa:');
			trace('[Song]   - characters: ${swagShit.characters.length}');
			for (i in 0...swagShit.characters.length)
				trace('[Song]     [$i] ${swagShit.characters[i].name}');
			trace('[Song]   - strumsGroups: ${swagShit.strumsGroups.length}');
			for (group in swagShit.strumsGroups)
				trace('[Song]     - ${group.id} (CPU: ${group.cpu})');
		}
		else
		{
			trace('[Song] Formato nuevo detectado, verificando strumsGroups...');
			trace('[Song]   - characters: ${swagShit.characters.length}');
			trace('[Song]   - strumsGroups: ${swagShit.strumsGroups != null ? swagShit.strumsGroups.length : 0}');

			// BUGFIX: El JSON tiene characters pero NO strumsGroups.
			// Crear grupos por defecto para que loadStrums() pueda construirlos
			// correctamente, incluyendo el grupo de GF con visible:false.
			// Sin este bloque, SONG.strumsGroups queda null → loadStrums() hace return
			// temprano → strumsGroups=[] en PlayState → en _finishRestart el loop de
			// visibilidad no se ejecuta, dejando posibles strums residuales visibles.
			if (swagShit.strumsGroups == null || swagShit.strumsGroups.length == 0)
			{
				var gfName  = (swagShit.gfVersion != null && swagShit.gfVersion != '') ? swagShit.gfVersion : 'gf';
				var dadName = 'dad';
				var bfName  = 'bf';

				// Leer nombres reales desde el array de characters ya presente
				for (i in 0...swagShit.characters.length)
				{
					var c = swagShit.characters[i];
					if (c == null) continue;
					if (i == 0) gfName  = c.name;
					if (i == 1) dadName = c.name;
					if (i == 2) bfName  = c.name;
				}

				swagShit.strumsGroups = [
					{
						id: 'gf_strums_0',
						x: 400, y: 50,
						visible: false, // GF nunca muestra sus strums por defecto
						cpu: true,
						spacing: 110,
						characters: [gfName]
					},
					{
						id: 'cpu_strums_0',
						x: 100, y: 50,
						visible: true,
						cpu: true,
						spacing: 110,
						characters: [dadName]
					},
					{
						id: 'player_strums_0',
						x: 740, y: 50,
						visible: true,
						cpu: false,
						spacing: 110,
						characters: [bfName]
					}
				];

				trace('[Song] strumsGroups generados por defecto (characters existentes, strumsGroups ausentes)');
			}
		}
		
		return swagShit;
	}
	
	/**
	 * Garantiza que un SwagSong cargado directamente (sin pasar por parseJSONshit)
	 * tenga strumsGroups y characters correctos — incluido el grupo de GF.
	 * Llamar desde ChartingState.onLoadComplete() y al inicializar desde PlayState.SONG.
	 */
	public static function ensureMigrated(song:SwagSong):Void
	{
		if (song == null) return;
		if (song.characters != null && song.characters.length > 0 &&
		    song.strumsGroups != null && song.strumsGroups.length > 0)
			return; // ya migrado

		// Ejecutar la misma lógica de migración que parseJSONshit
		var gfName  = (song.gfVersion != null && song.gfVersion != '') ? song.gfVersion : 'gf';
		var dadName = (song.player2   != null && song.player2   != '') ? song.player2   : 'dad';
		var bfName  = (song.player1   != null && song.player1   != '') ? song.player1   : 'bf';

		if (song.characters == null || song.characters.length == 0)
		{
			song.characters = [
				{ name: gfName,  x: 0, y: 0, visible: true, isGF: true,  type: 'Girlfriend', strumsGroup: 'gf_strums_0'     },
				{ name: dadName, x: 0, y: 0, visible: true, type: 'Opponent',                strumsGroup: 'cpu_strums_0'    },
				{ name: bfName,  x: 0, y: 0, visible: true, type: 'Player',                 strumsGroup: 'player_strums_0' }
			];
		}

		if (song.strumsGroups == null || song.strumsGroups.length == 0)
		{
			song.strumsGroups = [
				{ id: 'gf_strums_0',     x: 400, y: 50, visible: false, cpu: true,  spacing: 110, characters: [gfName]  },
				{ id: 'cpu_strums_0',    x: 100, y: 50, visible: true,  cpu: true,  spacing: 110, characters: [dadName] },
				{ id: 'player_strums_0', x: 740, y: 50, visible: true,  cpu: false, spacing: 110, characters: [bfName]  }
			];
		}
	}

	/**
	 * Auto-detecta las dificultades disponibles para una canción escaneando
	 * los archivos de chart (.json) en la carpeta de la canción.
	 *
	 * Ejemplo: si hay "alone-nightmare.json", devuelve ['Nightmare', '-nightmare'].
	 * Si hay "alone.json" o "normal.json", devuelve ['Normal', ''] (sufijo vacío).
	 *
	 * El orden es: easy → normal → hard → resto (alfabético).
	 *
	 * @param folder  Nombre de la carpeta de la canción (ej: "alone")
	 * @return Array de pares [label, suffix], ej: [['Easy','-easy'],['Nightmare','-nightmare']]
	 *         Si no se detecta nada, devuelve las 3 dificultades clásicas.
	 */
	public static function getAvailableDifficulties(folder:String):Array<Array<String>>
	{
		#if sys
		final folderLow = folder.toLowerCase();
		final found:Map<String, Bool> = new Map(); // sufijo → existe

		// ── Dificultades desde el .level (nuevo formato) ──────────────────
		{
			final levelPath = funkin.data.LevelFile.resolvePath(folderLow);
			if (levelPath != null)
			{
				try
				{
					final level : funkin.data.LevelFile.LevelData =
						cast haxe.Json.parse(sys.io.File.getContent(levelPath));
					if (level.difficulties != null)
						for (dk in Reflect.fields(level.difficulties))
							found.set(dk, true);
				}
				catch (_) {}
			}
		}

		// Rutas donde buscar charts
		final searchDirs:Array<String> = ['assets/songs/$folderLow'];
		if (mods.ModManager.isActive())
		{
			final mr = mods.ModManager.modRoot();
			searchDirs.unshift('$mr/songs/$folderLow');
			searchDirs.unshift('$mr/assets/songs/$folderLow');
			searchDirs.unshift('$mr/data/$folderLow');
			searchDirs.unshift('$mr/assets/data/$folderLow');
		}
		searchDirs.push('assets/data/$folderLow');

		for (dir in searchDirs)
		{
			if (!FileSystem.exists(dir) || !FileSystem.isDirectory(dir)) continue;
			for (entry in FileSystem.readDirectory(dir))
			{
				final entryLow = entry.toLowerCase();
				if (!entryLow.endsWith('.json')) continue;
				// Ignorar meta, configuración, etc.
				if (entryLow == 'meta.json' || entryLow == 'config.json') continue;

				final base = entryLow.substr(0, entryLow.length - 5); // quitar ".json"

				// ── Filtro V-Slice: ignorar archivos de metadata ──────────────────
				// Archivos como "senpai-metadata.json", "senpai-metadata-erect.json",
				// "metadata.json" NO son charts, son metadatos del song en formato V-Slice.
				if (base.contains('metadata')) continue;
				// Ignorar archivos de manifest de chart (ej: "senpai-chart.json")
				if (base.endsWith('-chart') || base == 'chart') continue;

				// ── Filtro de nombre: solo aceptar archivos que empiecen con el folder ──
				// Archivos que NO empiecen con el nombre de la canción (ej: "hard.json" suelto,
				// "config_extra.json", etc.) no se identifican como dificultades.
				// Solo se exceptúa "normal.json" por compatibilidad histórica.
				if (!base.startsWith(folderLow) && base != 'normal') continue;

				var suffix:String;
				// Formato "songname-diff.json"  ej: "alone-nightmare.json"
				if (base.startsWith(folderLow + '-'))
					suffix = base.substr(folderLow.length); // "-nightmare"
				// Formato "diff.json" == "songname.json" (dificultad normal) o "normal.json"
				else if (base == folderLow || base == 'normal')
					suffix = ''; // dificultad normal
				else
					continue; // ya filtrado arriba; por seguridad, skip

				found.set(suffix, true);
			}
		}

		// Si no encontramos nada, fallback a las 3 clásicas
		if (!found.keys().hasNext())
			return [['Easy', '-easy'], ['Normal', ''], ['Hard', '-hard']];

		// Construir array con orden preferido: easy, normal, hard, resto
		final ordered:Array<Array<String>> = [];
		final knownOrder:Array<Array<String>> = [
			['-easy',   'Easy'],
			['',        'Normal'],
			['-normal', 'Normal'],
			['-hard',   'Hard']
		];

		for (pair in knownOrder)
		{
			if (found.exists(pair[0]))
			{
				ordered.push([pair[1], pair[0]]);
				found.remove(pair[0]);
			}
		}

		// El resto en orden alfabético
		final extras:Array<String> = [for (k in found.keys()) k];
		extras.sort((a, b) -> a < b ? -1 : a > b ? 1 : 0);
		for (suffix in extras)
		{
			// Capitalizar: "-nightmare" → "Nightmare"
			final label = suffix.substr(1, 1).toUpperCase() + suffix.substr(2);
			ordered.push([label, suffix]);
		}

		return ordered;
		#else
		return [['Easy', '-easy'], ['Normal', ''], ['Hard', '-hard']];
		#end
	}


	public static function getCharacter(SONG:SwagSong, index:Int):CharacterSlotData
	{
		if (SONG.characters != null && index >= 0 && index < SONG.characters.length)
			return SONG.characters[index];
		return null;
	}
	
	/**
	 * NUEVO: Obtener grupo de strums por ID
	 */
	public static function getStrumsGroup(SONG:SwagSong, id:String):StrumsGroupData
	{
		if (SONG.strumsGroups != null)
		{
			for (group in SONG.strumsGroups)
			{
				if (group.id == id)
					return group;
			}
		}
		return null;
	}
	
	/**
	 * NUEVO: Obtener todos los grupos de strums CPU
	 */
	public static function getCPUStrumsGroups(SONG:SwagSong):Array<StrumsGroupData>
	{
		var cpuGroups:Array<StrumsGroupData> = [];
		if (SONG.strumsGroups != null)
		{
			for (group in SONG.strumsGroups)
			{
				if (group.cpu)
					cpuGroups.push(group);
			}
		}
		return cpuGroups;
	}
	
	/**
	 * NUEVO: Obtener todos los grupos de strums del jugador
	 */
	public static function getPlayerStrumsGroups(SONG:SwagSong):Array<StrumsGroupData>
	{
		var playerGroups:Array<StrumsGroupData> = [];
		if (SONG.strumsGroups != null)
		{
			for (group in SONG.strumsGroups)
			{
				if (!group.cpu)
					playerGroups.push(group);
			}
		}
		return playerGroups;
	}
}