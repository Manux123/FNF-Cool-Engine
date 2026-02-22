package mods.compat;

#if sys
import sys.FileSystem;
import sys.io.File;
#end
import haxe.Json;
import funkin.data.Song;
import mods.compat.ModFormat;
import mods.compat.ModFormat.ModFormatDetector;

using StringTools;

/**
 * ModCompatLayer
 * ─────────────────────────────────────────────────────────────────────────────
 * Single entry-point for ALL mod compatibility.
 * Handles charts, characters (JSON + XML), and stages for Psych and Codename.
 *
 * ═══════════════════════════════════════════════════════════════════════════
 * INTEGRATION — 3 one-line changes in the engine
 * ═══════════════════════════════════════════════════════════════════════════
 *
 * 1. Song.hx — replace the last line of loadFromJson():
 *      return mods.compat.ModCompatLayer.loadChart(rawJson);
 *
 * 2. Character.hx — inside loadCharacterData(), replace:
 *      characterData = cast Json.parse(content);
 *    with:
 *      characterData = cast mods.compat.ModCompatLayer.loadCharacter(content, character);
 *
 *    ALSO update the path lookup above it from:
 *      var jsonPath = Paths.characterJSON(character);
 *    to:
 *      var jsonPath = mods.compat.ModCompatLayer.resolveCharacterPath(character);
 *
 * 3. Stage.hx — inside loadStage(), replace:
 *      stageData = cast Json.parse(file);
 *    with:
 *      stageData = cast mods.compat.ModCompatLayer.loadStage(file, stageName);
 *
 *    ALSO update the path lookup before it from:
 *      var file:String = Paths.getText(Paths.stageJSON(stageName));
 *    to:
 *      var file:String = mods.compat.ModCompatLayer.readStageFile(stageName);
 *      if (file == null) { loadDefaultStage(); return; }
 *
 * ═══════════════════════════════════════════════════════════════════════════
 * What is auto-converted
 * ═══════════════════════════════════════════════════════════════════════════
 *
 *  Format          Charts  Characters (JSON)  Characters (XML)  Stages (JSON)
 *  ─────────────   ──────  ─────────────────  ────────────────  ─────────────
 *  Psych 0.6/0.7     ✓           ✓                  —               ✓
 *  Codename (CNE)    ✓           ✓                  ✓               ✓
 *  Cool Engine       ✓           ✓                  —               ✓  (native)
 *
 * NOT supported (no workaround possible):
 *   - Psych Lua scripts (.lua files)
 *   - Codename .hxs stage scripts (different API — falls back to default stage)
 *   - Custom engine-specific UI scripts
 *
 * Audio paths are resolved automatically via ModPathResolver:
 *   Psych/CNE:  songs/name/Inst.ogg      →  found and used directly
 *   Cool:       songs/name/song/Inst.ogg →  found and used directly
 */
class ModCompatLayer
{
	// ─── Charts ───────────────────────────────────────────────────────────────

	/**
	 * Parses a chart JSON string → SwagSong (Cool Engine format).
	 * Drop-in replacement for Song.parseJSONshit(rawJson).
	 */
	public static function loadChart(rawJson:String, ?difficulty:String = 'hard'):SwagSong
	{
		final fmt = ModFormatDetector.detectFromChartJson(rawJson);
		trace('[ModCompatLayer] Chart format: $fmt');
		return switch (fmt)
		{
			case ModFormat.PSYCH_ENGINE:    PsychConverter.convertChart(rawJson, difficulty);
			case ModFormat.CODENAME_ENGINE: CodenameConverter.convertChart(rawJson, difficulty);
			default:
				final _root:Dynamic = Json.parse(rawJson);
				// root.song can be a nested chart object OR just a song-name String
				// (flat Psych charts). Only use it as the chart object when it's not a String.
				final _rootSong:Dynamic = _root.song;
				cast (_rootSong != null && !Std.isOfType(_rootSong, String) ? _rootSong : _root);
		};
	}

	// ─── Characters ───────────────────────────────────────────────────────────

	/**
	 * Resolves the correct character file path for a given character name,
	 * trying all engine-specific folder layouts.
	 *
	 * Use this INSTEAD OF Paths.characterJSON(character).
	 * Falls back to Paths.characterJSON() if the mod resolver finds nothing.
	 */
	public static function resolveCharacterPath(name:String):String
	{
		// Try mod-specific layouts first (handles Codename's data/characters/)
		final modPath = ModPathResolver.characterFile(name);
		if (modPath != null) return modPath;
		// Fallback to standard Cool/Psych layout via Paths
		return Paths.characterJSON(name);
	}

	/**
	 * Parses character file content → Cool Engine CharacterData (Dynamic).
	 * Handles JSON (Cool/Psych/Codename) and XML (Codename) automatically.
	 *
	 * Drop-in replacement for Json.parse(content) in Character.loadCharacterData().
	 */
	public static function loadCharacter(content:String, charName:String):Dynamic
	{
		final fmt = ModFormatDetector.detectFromCharContent(content);
		trace('[ModCompatLayer] Character "$charName" format: $fmt');

		// XML content → Codename XML converter
		if (content != null && content.ltrim().charAt(0) == '<')
			return CodenameXmlConverter.convertCharacter(content, charName);

		return switch (fmt)
		{
			case ModFormat.PSYCH_ENGINE:    PsychConverter.convertCharacter(content, charName);
			case ModFormat.CODENAME_ENGINE: CodenameConverter.convertCharacter(content, charName);
			default:              Json.parse(content);
		};
	}

	// ─── Stages ───────────────────────────────────────────────────────────────

	/**
	 * Reads and returns the raw stage file content for a given stage name.
	 * Tries all engine-specific locations.
	 *
	 * Returns null if:
	 *   - No file found at all
	 *   - File is a Codename .hxs script (unsupported — caller should use default stage)
	 *
	 * Use this INSTEAD OF reading Paths.stageJSON() directly.
	 */
	public static function readStageFile(stageName:String):Null<String>
	{
		#if sys
		// 1. Try mod-specific layouts
		final modPath = ModPathResolver.stageFile(stageName);
		if (modPath != null)
		{
			// .hxs = Codename HScript stage — can't parse as JSON, use default
			if (modPath.endsWith('.hxs'))
			{
				trace('[ModCompatLayer] Stage "$stageName" is a Codename .hxs script — using default stage.');
				return null;
			}
			return File.getContent(modPath).trim();
		}

		// 2. Fall back to standard Cool Engine path
		// Paths.stageJSON devuelve un path relativo (sin assets/) pensado para
		// Paths.getText, que internamente llama a resolve() y añade el prefijo.
		final coolContent = Paths.getText(Paths.stageJSON(stageName));
		if (coolContent != null && coolContent.length > 0)
			return coolContent;
		#else
		// Non-sys: use standard Paths
		final p = Paths.stageJSON(stageName);
		if (openfl.utils.Assets.exists(p))
			return openfl.utils.Assets.getText(p);
		#end
		return null;
	}

	/**
	 * Parses a stage JSON string → Cool Engine StageData (Dynamic).
	 * Auto-detects Psych / Codename / Cool formats.
	 *
	 * Drop-in replacement for Json.parse(file) in Stage.loadStage().
	 */
	public static function loadStage(rawJson:String, stageName:String):Dynamic
	{
		final fmt = ModFormatDetector.detectFromStageJson(rawJson);
		trace('[ModCompatLayer] Stage "$stageName" format: $fmt');
		return switch (fmt)
		{
			case ModFormat.PSYCH_ENGINE:    PsychStageConverter.convertStage(rawJson, stageName);
			case ModFormat.CODENAME_ENGINE: CodenameStageConverter.convertStage(rawJson, stageName);
			default:              Json.parse(rawJson);
		};
	}

	// ─── Audio path helpers ───────────────────────────────────────────────────

	/**
	 * Resolves the Inst.ogg path for a song, trying both audio layouts.
	 * Use this INSTEAD OF Paths.inst(song) when a mod might be Psych/Codename.
	 *
	 * Returns the standard Paths.inst() result as fallback.
	 */
	public static function resolveInst(song:String):String
	{
		final modPath = ModPathResolver.inst(song);
		return modPath ?? Paths.inst(song);
	}

	/**
	 * Resolves the Voices.ogg path for a song.
	 */
	public static function resolveVoices(song:String):String
	{
		final modPath = ModPathResolver.voices(song);
		return modPath ?? Paths.voices(song);
	}

	// ─── Format queries ───────────────────────────────────────────────────────

	/** Returns the detected ModFormat of the currently active mod (cached). */
	public static function getActiveModFormat():ModFormat
	{
		final modId = ModManager.activeMod;
		return modId != null ? getModFormat(modId) : COOL_ENGINE;
	}

	/** Returns the detected ModFormat of any installed mod by ID (cached). */
	public static function getModFormat(modId:String):ModFormat
	{
		if (_fmtCache.exists(modId)) return _fmtCache.get(modId);
		#if sys
		final fmt = ModFormatDetector.detectFromFolder('${ModManager.MODS_FOLDER}/$modId');
		_fmtCache.set(modId, fmt);
		trace('[ModCompatLayer] Mod "$modId" → $fmt');
		return fmt;
		#else
		return COOL_ENGINE;
		#end
	}

	/** Clears the format detection cache. Call after installing/removing mods. */
	public static function clearCache():Void _fmtCache.clear();

	// ─── Mod Freeplay + Story songs ──────────────────────────────────────────

	/**
	 * Escanea todos los mods habilitados en busca de semanas en formato
	 * Psych Engine y las convierte al formato ModSongsInfo de Cool Engine.
	 *
	 * Cubre el formato real de Psych 0.6/0.7:
	 *   data/weeks/myweek.json  →  {songs:[["name","icon",[R,G,B]],...],
	 *                               weekCharacters:["","bf",""],
	 *                               hideFreeplay, hideStoryMode,
	 *                               hiddenUntilUnlocked, startUnlocked,
	 *                               freeplayColor:[R,G,B], storyName, weekName}
	 *
	 * Cada semana devuelta tiene:
	 *   • hideFreeplay  → si es true, FreeplayState la omite
	 *   • showInStoryMode[] → si todo es false, StoryMenuState la omite
	 *
	 * Llamar desde loadSongsData() de FreeplayState Y StoryMenuState justo
	 * después de parsear el songList.json base, y hacer push a songsWeeks.
	 */
	public static function getModSongsInfo():Array<ModSongsInfo>
	{
		final result:Array<ModSongsInfo> = [];

		#if sys
		for (mod in mods.ModManager.installedMods)
		{
			if (!mod.enabled) continue;

			final base = '${mods.ModManager.MODS_FOLDER}/${mod.id}';
			var loaded = false;

			// ── A: data/freeplaySonglist.json (lista plana, sin Story Mode) ──
			for (fp in ['$base/data/freeplaySonglist.json', '$base/freeplaySonglist.json'])
			{
				if (!FileSystem.exists(fp)) continue;
				try
				{
					final raw:Dynamic = Json.parse(File.getContent(fp).trim());
					final list:Array<Dynamic> = (raw.songs != null && Std.isOfType(raw.songs, Array))
						? cast raw.songs
						: (Std.isOfType(raw, Array) ? cast raw : []);
					if (list.length == 0) continue;

					final week = _weekFromFreeplayList(list, mod.name);
					if (week.weekSongs.length > 0)
					{
						result.push(week);
						loaded = true;
						trace('[ModCompatLayer] Mod "${mod.id}" — ${week.weekSongs.length} songs via freeplaySonglist.json');
					}
				}
				catch (e:Dynamic) { trace('[ModCompatLayer] Error parsing $fp: $e'); }
				if (loaded) break;
			}
			if (loaded) continue;

			// ── B: data/weeks/*.json — formato real de Psych ─────────────────
			for (weekDir in ['$base/data/weeks', '$base/weeks'])
			{
				if (!FileSystem.exists(weekDir) || !FileSystem.isDirectory(weekDir)) continue;

				final files = FileSystem.readDirectory(weekDir);
				files.sort((a, b) -> a < b ? -1 : 1);

				for (wf in files)
				{
					if (!wf.endsWith('.json')) continue;
					try
					{
						final w:Dynamic = Json.parse(File.getContent('$weekDir/$wf').trim());
						final week = _weekFromPsychWeekJson(w, mod.name);
						if (week.weekSongs.length > 0)
						{
							result.push(week);
							trace('[ModCompatLayer] Mod "${mod.id}" — week "${week.weekName}" (${week.weekSongs.length} songs) from $wf');
						}
					}
					catch (e:Dynamic) { trace('[ModCompatLayer] Error parsing $weekDir/$wf: $e'); }
				}
				break; // primer directorio válido
			}
		}
		#end

		trace('[ModCompatLayer] getModSongsInfo → ${result.length} week(s) from mods');
		return result;
	}

	// ─── Conversión interna ───────────────────────────────────────────────────

	/**
	 * Convierte el formato real de semana de Psych 0.6/0.7:
	 *
	 *  {
	 *    "storyName":          "el es candel y esto es",
	 *    "weekName":           "candelweek",
	 *    "difficulties":       "Hard",
	 *    "hideFreeplay":       false,
	 *    "hideStoryMode":      false,
	 *    "hiddenUntilUnlocked":false,
	 *    "startUnlocked":      true,
	 *    "weekBackground":     "stage",
	 *    "freeplayColor":      [146, 113, 253],
	 *    "weekCharacters":     ["", "bf", ""],
	 *    "songs": [
	 *      ["Epic-Battle",        "candel",     [255, 73, 113]],
	 *      ["candelero",          "candel",     [255, 73, 113]],
	 *      ["Dusk-of-corruption", "evilcandel", [86, 173, 255]]
	 *    ]
	 *  }
	 */
	static function _weekFromPsychWeekJson(w:Dynamic, modFallback:String):ModSongsInfo
	{
		final songs:Array<String>       = [];
		final icons:Array<String>       = [];
		final colors:Array<String>      = [];   // color POR CANCIÓN (índice 2 de cada entry)
		final bpms:Array<Float>         = [];
		final showInStory:Array<Bool>   = [];

		// hideFreeplay / hideStoryMode
		final hideFreeplay:Bool   = w.hideFreeplay   == true;
		final hideStoryMode:Bool  = w.hideStoryMode  == true;

		// locked: true si hiddenUntilUnlocked=true O startUnlocked=false
		final startUnlocked:Bool  = w.startUnlocked == null ? true : (w.startUnlocked == true);
		final locked:Bool         = (w.hiddenUntilUnlocked == true) || !startUnlocked;

		// Color de semana para freeplay (freeplayColor)
		final weekFreeplayColor:String = _parseColorArr(w.freeplayColor);

		// Parsear canciones: cada entry es ["nombre", "icono", [R,G,B]]
		if (w.songs != null && Std.isOfType(w.songs, Array))
		{
			final list:Array<Dynamic> = cast w.songs;
			for (entry in list)
			{
				if (!Std.isOfType(entry, Array)) continue;
				final arr:Array<Dynamic> = cast entry;
				final name = arr.length > 0 ? Std.string(arr[0]).trim() : '';
				if (name == '') continue;

				songs.push(name);
				icons.push(arr.length > 1 && arr[1] != null ? Std.string(arr[1]) : 'bf');

				// Color por canción (arr[2]) — si no existe, usar freeplayColor
				colors.push(arr.length > 2 && arr[2] != null
					? _parseColor(arr[2])
					: weekFreeplayColor);

				bpms.push(100.0); // Psych weeks no incluyen BPM por canción
				showInStory.push(!hideStoryMode);
			}
		}

		// Nombre visible de la semana — preferir storyName, luego weekName
		final weekName:String = (w.storyName != null && Std.string(w.storyName).trim() != '')
			? Std.string(w.storyName)
			: (w.weekName != null ? Std.string(w.weekName) : modFallback);

		// weekCharacters: Psych guarda [leftOpponent, bf/center, rightGF]
		// Cool Engine espera lo mismo — pasamos directo
		var chars:Array<String> = ['', 'bf', ''];
		if (w.weekCharacters != null && Std.isOfType(w.weekCharacters, Array))
		{
			final wc:Array<Dynamic> = cast w.weekCharacters;
			// Rellenar posibles huecos con cadena vacía
			chars = [
				wc.length > 0 && wc[0] != null ? Std.string(wc[0]) : '',
				wc.length > 1 && wc[1] != null ? Std.string(wc[1]) : 'bf',
				wc.length > 2 && wc[2] != null ? Std.string(wc[2]) : ''
			];
		}

		return {
			weekSongs:       songs,
			songIcons:       icons,
			color:           colors,
			bpm:             bpms,
			weekName:        weekName,
			weekCharacters:  chars,
			locked:          locked,
			hideFreeplay:    hideFreeplay,
			showInStoryMode: showInStory,
			weekBackground:  w.weekBackground != null ? Std.string(w.weekBackground) : 'stage'
		};
	}

	/**
	 * Convierte el formato freeplaySonglist.json de Psych:
	 *   [ {"name":"...", "icon":"...", "color":[R,G,B], "bpm":100} ]
	 * Estas canciones NUNCA aparecen en Story Mode (no tienen semana).
	 */
	static function _weekFromFreeplayList(list:Array<Dynamic>, modName:String):ModSongsInfo
	{
		final songs:Array<String>     = [];
		final icons:Array<String>     = [];
		final colors:Array<String>    = [];
		final bpms:Array<Float>       = [];

		for (entry in list)
		{
			final name:String = entry.name != null       ? Std.string(entry.name)
			                  : entry.songName != null   ? Std.string(entry.songName) : null;
			if (name == null || name.trim() == '') continue;

			songs.push(name);
			icons.push(entry.icon != null ? Std.string(entry.icon) : 'bf');
			colors.push(_parseColor(entry.color));
			bpms.push(entry.bpm != null ? Std.parseFloat(Std.string(entry.bpm)) : 100.0);
		}

		return {
			weekSongs:       songs,
			songIcons:       icons,
			color:           colors,
			bpm:             bpms,
			weekName:        modName,
			weekCharacters:  ['', 'bf', ''],
			locked:          false,
			hideFreeplay:    false,
			showInStoryMode: [for (_ in songs) false], // solo freeplay
			weekBackground:  'stage'
		};
	}

	// ─── Helpers de color ─────────────────────────────────────────────────────

	/**
	 * Convierte un campo "freeplayColor":[R,G,B] a string "0xFFRRGGBB".
	 * Devuelve "0xFF9271FD" (violeta) si el input es null o inválido.
	 */
	static inline function _parseColorArr(raw:Dynamic):String
		return _parseColor(raw);

	/**
	 * Convierte distintos formatos de color de Psych a "0xFFRRGGBB":
	 *   [R, G, B]     → "0xFFRRGGBB"
	 *   "RRGGBB"      → "0xFFRRGGBB"
	 *   "#RRGGBB"     → "0xFFRRGGBB"
	 *   null/inválido → "0xFF9271FD"  (violeta por defecto)
	 */
	static function _parseColor(raw:Dynamic):String
	{
		if (raw == null) return '0xFF9271FD';

		if (Std.isOfType(raw, Array))
		{
			final rgb:Array<Dynamic> = cast raw;
			if (rgb.length >= 3)
			{
				final r = StringTools.hex(Std.int(Std.parseFloat(Std.string(rgb[0]))) & 0xFF, 2);
				final g = StringTools.hex(Std.int(Std.parseFloat(Std.string(rgb[1]))) & 0xFF, 2);
				final b = StringTools.hex(Std.int(Std.parseFloat(Std.string(rgb[2]))) & 0xFF, 2);
				return '0xFF${r.toUpperCase()}${g.toUpperCase()}${b.toUpperCase()}';
			}
			return '0xFF9271FD';
		}

		var s = Std.string(raw).trim();
		if (s.startsWith('#'))  s = s.substr(1);
		if (s.toLowerCase().startsWith('0x')) s = s.substr(2);
		return switch (s.length)
		{
			case 6:  '0xFF${s.toUpperCase()}';
			case 8:  '0x${s.toUpperCase()}';
			default: '0xFF9271FD';
		};
	}

	static var _fmtCache:Map<String, ModFormat> = new Map();
}

/**
 * Estructura de semana compatible con SongsInfo (StoryMenuState/FreeplayState).
 * Campos extra respecto a SongsInfo nativa de Cool Engine:
 *   hideFreeplay   → la semana NO aparece en FreeplayState
 *   weekBackground → nombre del fondo para StoryMenuState (e.g. "stage")
 */
typedef ModSongsInfo =
{
	var weekSongs        : Array<String>;
	var songIcons        : Array<String>;
	var color            : Array<String>;
	var bpm              : Array<Float>;
	@:optional var weekName        : String;
	@:optional var weekCharacters  : Array<String>;
	@:optional var locked          : Bool;
	@:optional var showInStoryMode : Array<Bool>;
	// Campos exclusivos de mods
	@:optional var hideFreeplay    : Bool;
	@:optional var weekBackground  : String;
}
