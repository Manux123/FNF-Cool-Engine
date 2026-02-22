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
 *         "sectionNotes": [[time, lane, sustainLength], ...],
 *         "mustHitSection": true,
 *         "bpm": 100,  "changeBPM": false,
 *         "lengthInSteps": 16,
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
 *   "healthicon": "bf",
 *   "healthbar_colors": [49, 176, 209],
 *   "flip_x": false,
 *   "scale": 1
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

		// ── Notes / sections ─────────────────────────────────────────────────
		final psychSections:Array<Dynamic> = (ps.notes != null && Std.isOfType(ps.notes, Array))
			? cast ps.notes : [];

		for (sec in psychSections)
		{
			final converted:SwagSection = {
				sectionNotes:   _convertNotes(sec.sectionNotes),
				lengthInSteps:  Std.int(_float(sec.lengthInSteps, 16)),
				typeOfSection:  0,
				mustHitSection: _bool(sec.mustHitSection, true),
				bpm:            _float(sec.bpm, song.bpm),
				changeBPM:      _bool(sec.changeBPM, false),
				altAnim:        _bool(sec.altAnim, false),
				gfSing:         _bool(sec.gfSection, false)
			};
			song.notes.push(converted);
		}

		// ── Events ───────────────────────────────────────────────────────────
		// Psych format: Array<[Float, Array<[String, String, String]>]>
		// Cool format : Array<{stepTime, type, value}>
		final psychEvents:Array<Dynamic> = (ps.events != null && Std.isOfType(ps.events, Array))
			? cast ps.events : [];

		for (evtGroup in psychEvents)
		{
			if (!Std.isOfType(evtGroup, Array)) continue;
			final arr:Array<Dynamic> = cast evtGroup;
			if (arr.length < 2) continue;

			final timeMs:Float          = _float(arr[0], 0);
			final stepTime:Float        = _msToStep(timeMs, song.bpm);
			final innerList:Array<Dynamic> = Std.isOfType(arr[1], Array) ? cast arr[1] : [];

			for (ev in innerList)
			{
				if (!Std.isOfType(ev, Array)) continue;
				final evArr:Array<Dynamic> = cast ev;
				final evName  = _str(evArr[0], '');
				final evVal1  = _str(evArr[1], '');
				final evVal2  = _str(evArr[2], '');

				// Map known Psych event names → Cool Engine equivalents
				final coolType  = _mapEventType(evName);
				final coolValue = _mapEventValue(evName, evVal1, evVal2);

				song.events.push({
					stepTime: stepTime,
					type:     coolType,
					value:    coolValue
				});
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

		// ── Camera offset from "position" field ───────────────────────────────
		// Psych "position" = global offset, not camera-specific; we map it to
		// cameraOffset as a best approximation.
		var camOffset:Array<Float> = [0.0, 0.0];
		if (p.camera_position != null && Std.isOfType(p.camera_position, Array))
		{
			final cp:Array<Dynamic> = cast p.camera_position;
			camOffset = [_float(cp[0], 0), _float(cp[1], 0)];
		}

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
			cameraOffset:   camOffset
		};

		trace('[PsychConverter] Character "$charName" done. Anims: ${anims.length}');
		return coolChar;
	}

	// ─── Helpers ─────────────────────────────────────────────────────────────

	/** Converts a Psych sectionNotes array to Cool's format.
	 *  Psych note: [time:Float, lane:Int, sustainLength:Float, ?altAnim:Bool]
	 *  Cool note : same structure — already compatible, just ensure types. */
	static function _convertNotes(raw:Dynamic):Array<Dynamic>
	{
		final out:Array<Dynamic> = [];
		if (raw == null || !Std.isOfType(raw, Array)) return out;
		final arr:Array<Dynamic> = cast raw;
		for (n in arr)
		{
			if (!Std.isOfType(n, Array)) continue;
			final note:Array<Dynamic> = cast n;
			// [time, lane, sustainLength]  — already matches Cool's format
			out.push([
				_float(note[0], 0),
				Std.int(_float(note[1], 0)),
				_float(note[2], 0)
			]);
		}
		return out;
	}

	/**
	 * Maps Psych Engine event names → Cool Engine equivalents.
	 *
	 * ── Psych events covered ─────────────────────────────────────────────────
	 *  Camera Follow Opponent / Focus Camera On Opponent  → Camera Follow (dad)
	 *  Camera Follow Player  / Focus Camera On BF         → Camera Follow (bf)
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
	 */
	static function _mapEventValue(psychName:String, v1:String, v2:String):String
	{
		return switch (psychName.toLowerCase())
		{
			// Cámara: mapear target a nombre interno
			case 'camera follow opponent', 'focus camera on opponent':
				v2 != '' ? 'dad|$v2' : 'dad';

			case 'camera follow player', 'focus camera on bf':
				v2 != '' ? 'bf|$v2' : 'bf';

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

		song.characters = [
			{ name: song.gfVersion ?? 'gf',  x: 0.0, y: 0.0, visible: true, type: 'Girlfriend' },
			{ name: song.player2   ?? 'dad', x: 0.0, y: 0.0, visible: true, type: 'Opponent'   },
			{ name: song.player1   ?? 'bf',  x: 0.0, y: 0.0, visible: true, type: 'Player'     }
		];

		song.strumsGroups = [
			{ id: 'cpu_strums_0',    x: 100.0, y: 50.0, visible: true, cpu: true,  spacing: 110.0 },
			{ id: 'player_strums_0', x: 740.0, y: 50.0, visible: true, cpu: false, spacing: 110.0 }
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

	static inline function _bool(v:Dynamic, def:Bool):Bool
		return (v != null) ? (v == true) : def;

	static function _hex2(n:Int):String
	{
		final h = StringTools.hex(n & 0xFF, 2);
		return h.length < 2 ? '0$h' : h;
	}
}
