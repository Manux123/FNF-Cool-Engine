package mods.compat;

using StringTools;

#if sys
import sys.FileSystem;
import sys.io.File;
#end
import haxe.Json;

/**
 * ModFormat
 * ─────────────────────────────────────────────────────────────────────────────
 * Identifies which engine a mod/file was built for.
 *
 * Detection order for mod folders:
 *   1. Explicit "format" / "engine" field in mod.json
 *   2. Codename: pack.json present
 *   3. Character file signatures (JSON fields or XML extension)
 *   4. Chart JSON event structure
 *   5. Stage file structure
 *   6. Fallback → COOL_ENGINE
 */
enum abstract ModFormat(String) to String
{
	var COOL_ENGINE     = "cool";
	var PSYCH_ENGINE    = "psych";
	var CODENAME_ENGINE = "codename";
	var VSLICE_ENGINE   = "vslice";
}

class ModFormatDetector
{
	// ─── Mod folder ───────────────────────────────────────────────────────────
	public static function detectFromFolder(modPath:String):ModFormat
	{
		#if sys
		// 1. Explicit declaration in mod.json
		final jsonPath = '$modPath/mod.json';
		if (FileSystem.exists(jsonPath))
		{
			try
			{
				final data:Dynamic = Json.parse(File.getContent(jsonPath));
				final raw = Std.string(data.format ?? data.engine ?? '').toLowerCase().trim();
				if (raw != '')
					return _fmtFromString(raw);
			}
			catch (_:Dynamic)
			{
			}
		}

		// 2. Codename: pack.json is their unique signature file
		if (FileSystem.exists('$modPath/pack.json'))
			return CODENAME_ENGINE;

		// 3. Psych: weekList.txt / weekList.json in songs/ is Psych-specific
		if (FileSystem.exists('$modPath/songs/weekList.txt')
			|| FileSystem.exists('$modPath/songs/weekList.json')
			|| FileSystem.exists('$modPath/weeks/weekList.txt'))
			return PSYCH_ENGINE;

		// 4. Character file check — scan ALL files, vote by count
		for (charDir in ['$modPath/characters', '$modPath/data/characters'])
		{
			if (!FileSystem.exists(charDir))
				continue;
			var xmlCount = 0;
			var psychHits = 0;
			for (f in FileSystem.readDirectory(charDir))
			{
				if (f.endsWith('.xml'))
				{
					xmlCount++;
					continue;
				}
				if (f.endsWith('.json'))
				{
					final r = detectFromCharJson(_read('$charDir/$f'));
					if (r == PSYCH_ENGINE)
						psychHits++;
					else if (r == CODENAME_ENGINE)
						xmlCount++;
				}
			}
			if (psychHits > 0 && psychHits >= xmlCount)
				return PSYCH_ENGINE;
			if (xmlCount > 0 && xmlCount > psychHits)
				return CODENAME_ENGINE;
		}

		// 5. Stage file check — Codename uses .hxs; check all JSON stages
		for (stageDir in ['$modPath/stages', '$modPath/data/stages'])
		{
			if (!FileSystem.exists(stageDir))
				continue;
			for (f in FileSystem.readDirectory(stageDir))
			{
				if (f.endsWith('.hxs'))
					return CODENAME_ENGINE;
				if (f.endsWith('.json'))
				{
					final content = _read('$stageDir/$f');
					if (content != null)
					{
						final r = detectFromStageJson(content);
						if (r != COOL_ENGINE)
							return r;
					}
				}
			}
		}

		// 6. Chart JSON check — scan up to 3 songs for a reliable signal
		final songsDir = '$modPath/songs';
		if (FileSystem.exists(songsDir))
		{
			var checked = 0;
			for (song in FileSystem.readDirectory(songsDir))
			{
				final songPath = '$songsDir/$song';
				if (!FileSystem.isDirectory(songPath))
					continue;
				for (diff in ['hard', 'normal', 'easy', 'chart'])
				{
					final p = '$songPath/$diff.json';
					if (!FileSystem.exists(p))
						continue;
					final r = detectFromChartJson(_read(p));
					if (r != COOL_ENGINE)
						return r;
					break;
				}
				if (++checked >= 3)
					break;
			}
		}

		// 7. Psych fallback: _meta.json is a Psych 0.7 metadata file
		if (FileSystem.exists('$modPath/data/_meta.json') || FileSystem.exists('$modPath/_meta.json'))
			return PSYCH_ENGINE;
		#end
		return COOL_ENGINE;
	}

	// ─── Chart JSON ───────────────────────────────────────────────────────────

	public static function detectFromChartJson(rawJson:String):ModFormat
	{
		if (rawJson == null || rawJson == '')
			return COOL_ENGINE;
		try
		{
			final root:Dynamic = Json.parse(rawJson);

			// ── Explicit format field (e.g. "psych_v1_convert") ──────────────
			final fmtField:String = Std.string(root.format ?? root.engine ?? '').toLowerCase().trim();
			if (fmtField.startsWith('psych')) return PSYCH_ENGINE;

			// ── Resolve song data object ──────────────────────────────────────
			// root.song can be EITHER a nested chart object {bpm,notes,...}
			// OR just a song-name string ("epic-battle") in flat Psych charts.
			// If it's a String we must NOT use it as the data object.
			final rootSong:Dynamic = root.song;
			final s:Dynamic = (rootSong != null && !Std.isOfType(rootSong, String)) ? rootSong : root;

			// Psych events: [[time, [[name,v1,v2]]]] — outer array elements are arrays
			final evts = s.events;
			if (evts != null && Std.isOfType(evts, Array))
			{
				final arr:Array<Dynamic> = cast evts;
				if (arr.length > 0 && Std.isOfType(arr[0], Array))
					return PSYCH_ENGINE;
			}

			// Codename / V-Slice: notes is an Object with difficulty sub-keys, not an Array
			final notes = s.notes;
			if (notes != null && !Std.isOfType(notes, Array))
			{
				// ── V-Slice detection ─────────────────────────────────────────────
				// V-Slice también tiene notes como objeto, pero se distingue por:
				//   1. Campo "generatedBy" que contiene "Friday Night Funkin'"
				//   2. Campo "version" en raíz con semver (ej: "2.0.0")
				//   3. Eventos con estructura {t, e, v} en lugar de arrays de arrays
				final generatedBy:String = Std.string(root.generatedBy ?? '').toLowerCase();
				if (generatedBy.contains('friday night funkin'))
					return VSLICE_ENGINE;

				// Comprobar versión semver en raíz (ej: "2.0.0", "2.2.0")
				final versionStr:String = Std.string(root.version ?? '');
				if (_isSemverChartVersion(versionStr))
					return VSLICE_ENGINE;

				// Comprobar estructura de eventos: V-Slice usa {t, e, v}
				final evts:Dynamic = root.events ?? s.events;
				if (evts != null && Std.isOfType(evts, Array))
				{
					final evArr:Array<Dynamic> = cast evts;
					if (evArr.length > 0)
					{
						final firstEv:Dynamic = evArr[0];
						// V-Slice: el evento tiene campo "e" (string con nombre del evento)
						if (Reflect.hasField(firstEv, 'e') && Std.isOfType(firstEv.e, String))
							return VSLICE_ENGINE;
					}
				}

				// Si ninguna señal V-Slice, es Codename
				return CODENAME_ENGINE;
			}

			// ── Flat Psych chart (no events array, no song wrapper) ──────────
			// Señales características:
			//   • player1 en root (Psych usa esto, Cool usa characters[])
			//   • sectionBeats en las secciones (campo exclusivo de Psych;
			//     Cool Engine usa lengthInSteps)
			//   • mustHitSection presente Y sin bpm a nivel raíz
			// Si se cumple alguna de estas, lo tratamos como Psych para que
			// PsychConverter genere los eventos Camera Follow correctamente.
			if (notes != null && Std.isOfType(notes, Array))
			{
				final notesArr:Array<Dynamic> = cast notes;
				if (notesArr.length > 0)
				{
					final firstSec:Dynamic = notesArr[0];
					// sectionBeats es un campo exclusivo de Psych
					if (firstSec.sectionBeats != null)
						return PSYCH_ENGINE;
				}
			}
			// player1 sin bpm a raíz → Psych plano (Cool nativo siempre tiene bpm)
			if (root.player1 != null && root.bpm == null && root.events == null)
				return PSYCH_ENGINE;
		}
		catch (_:Dynamic)
		{
		}
		return COOL_ENGINE;
	}

	// ─── Character JSON/XML ───────────────────────────────────────────────────

	/**
	 * Detects format from a character file content.
	 * Works for both JSON strings and XML strings.
	 */
	public static function detectFromCharContent(content:String):ModFormat
	{
		if (content == null || content == '')
			return COOL_ENGINE;
		final trimmed = content.ltrim();
		// XML starts with '<'
		if (trimmed.charAt(0) == '<')
			return CODENAME_ENGINE;
		return detectFromCharJson(content);
	}

	public static function detectFromCharJson(rawJson:String):ModFormat
	{
		if (rawJson == null || rawJson == '')
			return COOL_ENGINE;
		try
		{
			final c:Dynamic = Json.parse(rawJson);
			// Psych: has "no_antialiasing"
			if (Reflect.hasField(c, 'no_antialiasing'))
				return PSYCH_ENGINE;
			// Psych: has "image" + animations with "anim" field (not "path")
			if (Reflect.hasField(c, 'image') && !Reflect.hasField(c, 'path'))
			{
				if (c.animations != null && Std.isOfType(c.animations, Array))
				{
					final anims:Array<Dynamic> = cast c.animations;
					if (anims.length > 0 && Reflect.hasField(anims[0], 'anim'))
						return PSYCH_ENGINE;
				}
			}
			// Codename JSON: has "asset" instead of "path"
			if (Reflect.hasField(c, 'asset') && !Reflect.hasField(c, 'path'))
				return CODENAME_ENGINE;
		}
		catch (_:Dynamic)
		{
		}
		return COOL_ENGINE;
	}

	// ─── Stage JSON ───────────────────────────────────────────────────────────

	public static function detectFromStageJson(rawJson:String):ModFormat
	{
		if (rawJson == null || rawJson == '')
			return COOL_ENGINE;
		try
		{
			final root:Dynamic = Json.parse(rawJson);
			final ps = root.stageJson ?? root;

			// Psych 0.7.x full format: stageObjects array
			if (Reflect.hasField(ps, 'stageObjects'))
				return PSYCH_ENGINE;

			// Psych minimal format: character position fields boyfriend/girlfriend/opponent
			// (NocturnBg.json style — no stageObjects, just positions + zoom)
			if (Reflect.hasField(ps, 'boyfriend') || Reflect.hasField(ps, 'girlfriend') || Reflect.hasField(ps, 'opponent'))
				return PSYCH_ENGINE;

			// Psych legacy: bfPos/dadPos naming
			if (Reflect.hasField(root, 'bfPos') || Reflect.hasField(root, 'dadPos'))
				return PSYCH_ENGINE;

			// Codename variant A: sprites array
			if (Reflect.hasField(root, 'sprites'))
				return CODENAME_ENGINE;
			// Codename variant B: objects + characters
			if (Reflect.hasField(root, 'objects') && Reflect.hasField(root, 'characters'))
				return CODENAME_ENGINE;
		}
		catch (_:Dynamic)
		{
		}
		return COOL_ENGINE;
	}

	// ─── Helpers ─────────────────────────────────────────────────────────────

	static function _fmtFromString(s:String):ModFormat
	{
		return switch (s.toLowerCase())
		{
			case 'psych', 'psych_engine', 'psychengine': PSYCH_ENGINE;
			case 'codename', 'codename_engine', 'cne': CODENAME_ENGINE;
			case 'vslice', 'v-slice', 'funkin', 'fnf': VSLICE_ENGINE;
			default: COOL_ENGINE;
		};
	}

	/**
	 * Devuelve true si la cadena parece una versión semver de chart V-Slice.
	 * Ejemplo: "2.0.0", "2.1.0", "2.2.0"  → true
	 * "1.0.0" podría ser otra cosa → false (requerir mayor >= 2)
	 */
	static function _isSemverChartVersion(v:String):Bool
	{
		if (v == null || v == '') return false;
		final parts = v.split('.');
		if (parts.length < 2) return false;
		final major = Std.parseInt(parts[0]);
		// V-Slice chart versiones conocidas: 2.0.0, 2.1.0, 2.2.0
		return (major != null && major >= 2);
	}

	static function _read(path:String):String
	{
		#if sys
		try
		{
			return File.getContent(path);
		}
		catch (_:Dynamic)
		{
		}
		#end
		return null;
	}
}
