package mods.compat;

using StringTools;

import haxe.Json;
import funkin.gameplay.objects.stages.Stage;

/**
 * PsychStageConverter
 * ─────────────────────────────────────────────────────────────────────────────
 * Converts a Psych Engine 0.7.x stage JSON into Cool Engine's StageData.
 *
 * ── Psych 0.7.x stage JSON structure ────────────────────────────────────────
 * Psych wraps everything in a "stageJson" key, OR stores it flat:
 *
 * {
 *   "stageJson": {
 *     "defaultZoom":    0.9,
 *     "isPixelStage":   false,
 *     "hide_girlfriend": false,
 *     "girlfriend":     [400, 130],
 *     "boyfriend":      [770, 450],
 *     "opponent":       [100, 100],
 *     "camera_boyfriend": [0, 0],
 *     "camera_opponent":  [0, 0],
 *     "stageObjects": [
 *       {
 *         "image":        "stageback",
 *         "libraryName":  "",
 *         "position":     [-600, -200],
 *         "scrollFactor": [0.9, 0.9],
 *         "scale":        [1, 1],
 *         "angle":        0,
 *         "alpha":        1,
 *         "isAnimated":   false,
 *         "frameRate":    24,
 *         "animations":   [],
 *         "startingAnim": "",
 *         "antialiasing": true,
 *         "visible":      true,
 *         "flipX":        false,
 *         "flipY":        false,
 *         "depth":        0,
 *         "color":        "0xFFFFFFFF",
 *         "blend":        ""
 *       }
 *     ]
 *   }
 * }
 *
 * ── Notes ────────────────────────────────────────────────────────────────────
 * - Psych stages may also have a companion Lua script. This converter handles
 *   only the JSON part. Lua scripts are silently ignored (unsupported).
 * - "libraryName" is Psych's atlas library system — we treat it as a path prefix.
 * - "depth" in Psych = zIndex in Cool (lower depth = drawn first).
 */
class PsychStageConverter
{
	/**
	 * Converts a raw Psych stage JSON string into a Cool Engine StageData object.
	 * The returned Dynamic can be cast directly to StageData.
	 */
	public static function convertStage(rawJson:String, stageName:String):Dynamic
	{
		trace('[PsychStageConverter] Converting stage "$stageName"...');

		final root:Dynamic = Json.parse(rawJson);
		// Psych can wrap in "stageJson" or store flat
		final ps:Dynamic   = (Reflect.hasField(root, 'stageJson')) ? root.stageJson : root;

		// ── Character positions ───────────────────────────────────────────────
		final gfPos  = _arr2(ps.girlfriend,      [400.0, 130.0]);
		final bfPos  = _arr2(ps.boyfriend,       [770.0, 450.0]);
		final dadPos = _arr2(ps.opponent,        [100.0, 100.0]);
		final camBF  = _arr2(ps.camera_boyfriend, [0.0, 0.0]);
		final camDad = _arr2(ps.camera_opponent,  [0.0, 0.0]);

		// ── Elements ──────────────────────────────────────────────────────────
		final elements:Array<Dynamic> = [];
		final psychObjs:Array<Dynamic> = _getArray(ps.stageObjects);

		for (i in 0...psychObjs.length)
		{
			final obj = psychObjs[i];
			final isAnimated = _bool(obj.isAnimated, false);
			final hasAnims   = isAnimated && _getArray(obj.animations).length > 0;

			// ── Image path ────────────────────────────────────────────────────
			// Psych stores just the filename (e.g. "stageback").
			// "libraryName" is an optional atlas library prefix (usually blank).
			final lib   = _str(obj.libraryName, '');
			final img   = _str(obj.image, '');
			final asset = (lib != '') ? '$lib/$img' : img;

			// ── Position ──────────────────────────────────────────────────────
			final pos = _arr2(obj.position, [0.0, 0.0]);

			// ── Color: Psych uses "0xAARRGGBB" string ──────────────────────────
			final colorStr = _psychColorToCool(_str(obj.color, ''));

			// ── Build element ─────────────────────────────────────────────────
			final elem:Dynamic = {
				type:         hasAnims ? 'animated' : 'sprite',
				asset:        asset,
				position:     pos,
				name:         'object_$i',
				scrollFactor: _arr2(obj.scrollFactor, [1.0, 1.0]),
				scale:        _psychScaleToCool(obj.scale),
				antialiasing: _bool(obj.antialiasing, true),
				alpha:        _float(obj.alpha, 1.0),
				flipX:        _bool(obj.flipX, false),
				flipY:        _bool(obj.flipY, false),
				visible:      _bool(obj.visible, true),
				zIndex:       Std.int(_float(obj.depth, i)),
				blend:        _str(obj.blend, ''),
				color:        colorStr
			};

			// ── Animations ────────────────────────────────────────────────────
			if (hasAnims)
			{
				final coolAnims:Array<Dynamic> = [];
				for (pa in _getArray(obj.animations))
				{
					coolAnims.push({
						name:      _str(pa.name ?? pa.anim, 'idle'),
						prefix:    _str(pa.prefix ?? pa.name, 'idle'),
						framerate: Std.int(_float(pa.fps ?? pa.frameRate ?? obj.frameRate, 24)),
						looped:    _bool(pa.loop ?? pa.looped, false),
						indices:   _getIntArray(pa.indices)
					});
				}
				Reflect.setField(elem, 'animations',     coolAnims);
				Reflect.setField(elem, 'firstAnimation', _str(obj.startingAnim, coolAnims[0].name));
			}

			elements.push(elem);
		}

		// ── Assemble StageData ────────────────────────────────────────────────
		final stageData:Dynamic = {
			name:               stageName,
			defaultZoom:        _float(ps.defaultZoom, 0.9),
			isPixelStage:       _bool(ps.isPixelStage, false),
			hideGirlfriend:     _bool(ps.hide_girlfriend, false),
			gfPosition:         gfPos,
			boyfriendPosition:  bfPos,
			dadPosition:        dadPos,
			cameraBoyfriend:    camBF,
			cameraDad:          camDad,
			elements:           elements,
			scripts:            []   // Lua scripts not supported
		};

		trace('[PsychStageConverter] Done. Elements: ${elements.length}');
		return stageData;
	}

	// ─── Helpers ─────────────────────────────────────────────────────────────

	/**
	 * Psych scale can be:
	 *   - Array<Float>  [sx, sy]
	 *   - Float         uniform scale
	 *   - null          → default [1, 1]
	 */
	static function _psychScaleToCool(v:Dynamic):Array<Float>
	{
		if (v == null) return [1.0, 1.0];
		if (Std.isOfType(v, Array))
		{
			final a:Array<Dynamic> = cast v;
			return [
				_float(a.length > 0 ? a[0] : 1, 1.0),
				_float(a.length > 1 ? a[1] : 1, 1.0)
			];
		}
		final s = _float(v, 1.0);
		return [s, s];
	}

	/**
	 * Psych color: "0xAARRGGBB" string → Cool "#RRGGBB" string.
	 * Returns empty string if color is white/default (no point adding it).
	 */
	static function _psychColorToCool(s:String):String
	{
		if (s == '' || s == null) return '';
		s = s.replace('0x', '').replace('#', '').toUpperCase();
		// AARRGGBB → strip AA, keep RRGGBB
		if (s.length == 8) s = s.substr(2);
		if (s == 'FFFFFF' || s == 'ffffff') return '';
		return '#$s';
	}

	static function _arr2(v:Dynamic, def:Array<Float>):Array<Float>
	{
		if (v == null || !Std.isOfType(v, Array)) return def;
		final a:Array<Dynamic> = cast v;
		return [
			_float(a.length > 0 ? a[0] : def[0], def[0]),
			_float(a.length > 1 ? a[1] : def[1], def[1])
		];
	}

	static function _getArray(v:Dynamic):Array<Dynamic>
	{
		if (v != null && Std.isOfType(v, Array)) return cast v;
		return [];
	}

	static function _getIntArray(v:Dynamic):Array<Int>
	{
		if (v == null || !Std.isOfType(v, Array)) return null;
		final a:Array<Dynamic> = cast v;
		if (a.length == 0) return null;
		return [for (x in a) Std.int(_float(x, 0))];
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
}
