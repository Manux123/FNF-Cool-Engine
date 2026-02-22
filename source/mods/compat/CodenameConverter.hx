package mods.compat;

using StringTools;

import haxe.Json;
import funkin.data.Song;
import funkin.data.Section;

/**
 * CodenameConverter
 * ─────────────────────────────────────────────────────────────────────────────
 * Translates Codename Engine (CNE) data formats into Cool Engine's native
 * SwagSong / CharacterData structures.
 *
 * ── Codename chart structure (reference) ─────────────────────────────────────
 * {
 *   "song": {
 *     "song": "Bopeebo",
 *     "bpm": 100,  "speed": 1,  "needsVoices": true,
 *     "player":   "bf",
 *     "opponent": "dad",
 *     "gf":       "gf",
 *     "stage":    "stage",
 *     "notes": {
 *       "easy":   [ ...sections ],
 *       "normal": [ ...sections ],
 *       "hard":   [ ...sections ]
 *     },
 *     "events": [
 *       { "time": 1234, "name": "Camera Move", "params": ["dad"] }
 *     ]
 *   }
 * }
 *
 * CNE sections are identical in structure to base-game sections.
 *
 * ── Codename character structure (reference) ─────────────────────────────────
 * {
 *   "asset":      "characters/bf",
 *   "animations": [
 *     { "name": "idle",  "anim": "BF idle dance",
 *       "fps": 24,  "loop": false,  "offset": [0, 0] }
 *   ],
 *   "antialiasing": true,
 *   "scale":        1,
 *   "icon":         "bf",
 *   "color":        [49, 176, 209],
 *   "flipX":        false,
 *   "position":     [0, 0],
 *   "cameraOffset": [0, 0],
 *   "isPlayer":     false
 * }
 */
class CodenameConverter
{
	// ─── Chart ────────────────────────────────────────────────────────────────

	/**
	 * Converts a raw Codename Engine chart JSON string into a Cool Engine SwagSong.
	 *
	 * @param rawJson     Full content of the CNE chart JSON.
	 * @param difficulty  Which difficulty key to extract from `notes` object.
	 *                    Defaults to "hard", falls back to first available key.
	 */
	public static function convertChart(rawJson:String, ?difficulty:String = 'hard'):SwagSong
	{
		trace('[CodenameConverter] Converting chart (difficulty=$difficulty)...');

		final root:Dynamic = Json.parse(rawJson);
		final cs:Dynamic   = root.song ?? root;

		// ── Basic fields ─────────────────────────────────────────────────────
		final song:SwagSong = {
			song:        _str(cs.song,  'unknown'),
			bpm:         _float(cs.bpm, 100),
			speed:       _float(cs.speed, 1),
			needsVoices: _bool(cs.needsVoices, true),
			stage:       _str(cs.stage, 'stage'),
			validScore:  true,
			notes:       [],
			// Legacy fields
			player1:     _str(cs.player   ?? cs.player1, 'bf'),
			player2:     _str(cs.opponent ?? cs.player2, 'dad'),
			gfVersion:   _str(cs.gf       ?? cs.gfVersion ?? cs.player3, 'gf'),
			characters:  null,
			strumsGroups: null,
			events:      []
		};

		// ── Notes ─────────────────────────────────────────────────────────────
		// CNE can store notes either as:
		//   a) An Object with difficulty keys: { "easy": [...], "hard": [...] }
		//   b) A plain Array (same as base-game / legacy)
		final notesField = cs.notes;
		var sections:Array<Dynamic> = [];

		if (notesField != null)
		{
			if (Std.isOfType(notesField, Array))
			{
				// Already a flat array — treat as base-game format
				sections = cast notesField;
			}
			else
			{
				// Object with difficulty keys — pick requested diff or first available
				var picked:Array<Dynamic> = null;
				final tryDiffs = [difficulty, 'hard', 'normal', 'easy'];
				for (d in tryDiffs)
				{
					final v = Reflect.field(notesField, d);
					if (v != null && Std.isOfType(v, Array))
					{
						picked = cast v;
						trace('[CodenameConverter] Using difficulty key "$d"');
						break;
					}
				}
				if (picked == null)
				{
					// Grab whatever first field is there
					final fields = Reflect.fields(notesField);
					if (fields.length > 0)
					{
						final v = Reflect.field(notesField, fields[0]);
						if (Std.isOfType(v, Array)) picked = cast v;
					}
				}
				sections = picked ?? [];
			}
		}

		for (sec in sections)
			song.notes.push(_convertSection(sec, song.bpm));

		// ── Events ────────────────────────────────────────────────────────────
		// CNE events: Array<{ time:Float, name:String, params:Array<Dynamic> }>
		final cneEvents:Array<Dynamic> = (cs.events != null && Std.isOfType(cs.events, Array))
			? cast cs.events : [];

		for (ev in cneEvents)
		{
			final timeMs:Float          = _float(ev.time, 0);
			final stepTime:Float        = _msToStep(timeMs, song.bpm);
			final params:Array<Dynamic> = (ev.params != null && Std.isOfType(ev.params, Array))
				? cast ev.params : [];

			final coolType  = _mapEventType(_str(ev.name, ''));
			final coolValue = _mapEventValue(_str(ev.name, ''), params);

			song.events.push({
				stepTime: stepTime,
				type:     coolType,
				value:    coolValue
			});
		}

		// ── Characters & strums ───────────────────────────────────────────────
		_buildCharactersFromLegacy(song);

		trace('[CodenameConverter] Done. Sections: ${song.notes.length}, Events: ${song.events.length}');
		return song;
	}

	// ─── Character ────────────────────────────────────────────────────────────

	/**
	 * Converts a raw Codename Engine character JSON string into a Cool Engine
	 * CharacterData-compatible Dynamic object.
	 */
	public static function convertCharacter(rawJson:String, charName:String):Dynamic
	{
		trace('[CodenameConverter] Converting character "$charName"...');

		final c:Dynamic = Json.parse(rawJson);

		// ── Animations ────────────────────────────────────────────────────────
		// CNE: { name, anim, fps, loop, offset:[x,y] }
		// Cool: { name, prefix, framerate, looped, offsetX, offsetY, indices }
		final anims:Array<Dynamic> = [];
		if (c.animations != null && Std.isOfType(c.animations, Array))
		{
			final cneAnims:Array<Dynamic> = cast c.animations;
			for (ca in cneAnims)
			{
				final offset:Array<Dynamic> = (ca.offset != null && Std.isOfType(ca.offset, Array))
					? cast ca.offset : [0, 0];

				final indices:Array<Int> = (ca.indices != null && Std.isOfType(ca.indices, Array)
					&& (cast ca.indices:Array<Dynamic>).length > 0)
					? cast ca.indices : null;

				anims.push({
					// CNE "name" = internal anim name, "anim" = XML prefix
					name:      _str(ca.name,  'idle'),
					prefix:    _str(ca.anim ?? ca.prefix, 'idle'),
					framerate: _float(ca.fps, 24),
					looped:    _bool(ca.loop ?? ca.looped, false),
					offsetX:   offset.length > 0 ? _float(offset[0], 0) : 0.0,
					offsetY:   offset.length > 1 ? _float(offset[1], 0) : 0.0,
					indices:   indices
				});
			}
		}

		// ── Color [R,G,B] → "#RRGGBB" ─────────────────────────────────────────
		var healthBarColor:String = '#31B0D1';
		if (c.color != null && Std.isOfType(c.color, Array))
		{
			final rgb:Array<Dynamic> = cast c.color;
			if (rgb.length >= 3)
			{
				final r = Std.int(_float(rgb[0], 49));
				final g = Std.int(_float(rgb[1], 176));
				final b = Std.int(_float(rgb[2], 209));
				healthBarColor = '#' + _hex2(r) + _hex2(g) + _hex2(b);
			}
		}

		// ── Camera offset ─────────────────────────────────────────────────────
		var camOffset:Array<Float> = [0.0, 0.0];
		if (c.cameraOffset != null && Std.isOfType(c.cameraOffset, Array))
		{
			final co:Array<Dynamic> = cast c.cameraOffset;
			camOffset = [_float(co[0], 0), _float(co[1], 0)];
		}

		// ── Build Cool Engine CharacterData ───────────────────────────────────
		final coolChar:Dynamic = {
			// CNE uses "asset", e.g. "characters/bf"  →  strip prefix
			path:           _normalizePath(_str(c.asset ?? c.image, 'characters/$charName')),
			animations:     anims,
			isPlayer:       _bool(c.isPlayer, false),
			antialiasing:   _bool(c.antialiasing, true),
			scale:          _float(c.scale, 1),
			flipX:          _bool(c.flipX ?? c.flip_x, false),
			healthIcon:     _str(c.icon ?? c.healthicon, charName),
			healthBarColor: healthBarColor,
			cameraOffset:   camOffset
		};

		trace('[CodenameConverter] Character "$charName" done. Anims: ${anims.length}');
		return coolChar;
	}

	// ─── Helpers ─────────────────────────────────────────────────────────────

	static function _convertSection(sec:Dynamic, defaultBpm:Float):SwagSection
	{
		// CNE sections have essentially the same structure as base-game sections
		return {
			sectionNotes:   _convertNotes(sec.sectionNotes),
			lengthInSteps:  Std.int(_float(sec.lengthInSteps, 16)),
			typeOfSection:  0,
			mustHitSection: _bool(sec.mustHitSection, true),
			bpm:            _float(sec.bpm, defaultBpm),
			changeBPM:      _bool(sec.changeBPM, false),
			altAnim:        _bool(sec.altAnim, false),
			gfSing:         _bool(sec.gfSection ?? sec.gfSing, false)
		};
	}

	static function _convertNotes(raw:Dynamic):Array<Dynamic>
	{
		final out:Array<Dynamic> = [];
		if (raw == null || !Std.isOfType(raw, Array)) return out;
		final arr:Array<Dynamic> = cast raw;
		for (n in arr)
		{
			if (!Std.isOfType(n, Array)) continue;
			final note:Array<Dynamic> = cast n;
			out.push([
				_float(note[0], 0),
				Std.int(_float(note[1], 0)),
				_float(note[2], 0)
			]);
		}
		return out;
	}

	/** Maps CNE event names → Cool Engine types. */
	static function _mapEventType(cneName:String):String
	{
		return switch (cneName.toLowerCase())
		{
			case 'camera move', 'focus on', 'camera follow':
				'Camera';
			case 'change bpm', 'bpm change':
				'BPM Change';
			case 'play animation', 'play anim':
				'Play Anim';
			case 'alt anim', 'alt animation':
				'Alt Anim';
			case 'camera zoom', 'zoom camera':
				'Camera Zoom';
			default:
				cneName;
		};
	}

	static function _mapEventValue(cneName:String, params:Array<Dynamic>):String
	{
		final p0 = params.length > 0 ? _str(params[0], '') : '';
		final p1 = params.length > 1 ? _str(params[1], '') : '';

		return switch (cneName.toLowerCase())
		{
			case 'camera move', 'focus on', 'camera follow':
				// CNE usually passes "dad", "bf", "gf"
				p0.toLowerCase();
			default:
				p0 != '' ? p0 : p1;
		};
	}

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

	static inline function _msToStep(ms:Float, bpm:Float):Float
		return (ms / 1000) * (bpm / 60) * 4;

	static function _normalizePath(path:String):String
	{
		if (path.startsWith('characters/')) return path.substr('characters/'.length);
		if (path.startsWith('chars/'))      return path.substr('chars/'.length);
		return path;
	}

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
