package mods.compat;

import haxe.Json;
import funkin.gameplay.objects.stages.Stage;

/**
 * CodenameStageConverter
 * ─────────────────────────────────────────────────────────────────────────────
 * Converts a Codename Engine stage JSON into Cool Engine's StageData.
 *
 * ── Codename stage JSON (variant A — "sprites" array) ────────────────────────
 * {
 *   "bfPos":      [770, 450],
 *   "dadPos":     [100, 100],
 *   "gfPos":      [400, 130],
 *   "camBF":      [0, 0],
 *   "camDad":     [0, 0],
 *   "defaultZoom": 0.9,
 *   "isPixelStage": false,
 *   "hideGF":     false,
 *   "sprites": [
 *     {
 *       "name":       "bg",
 *       "image":      "stageback",
 *       "x": -600,   "y": -200,
 *       "scrollX":    0.9,   "scrollY": 0.9,
 *       "scale":      1.0,
 *       "antialiasing": true,
 *       "alpha":      1.0,
 *       "flipX":      false,  "flipY": false,
 *       "zIndex":     0,
 *       "animated":   false,
 *       "animations": [],
 *       "startAnim":  ""
 *     }
 *   ]
 * }
 *
 * ── Codename stage JSON (variant B — "objects" + "characters") ───────────────
 * {
 *   "defaultCamZoom": 0.9,
 *   "isPixelStage":   false,
 *   "characters": {
 *     "bf":  { "x": 770, "y": 450, "cameraOffset": [0, 0] },
 *     "dad": { "x": 100, "y": 100, "cameraOffset": [0, 0] },
 *     "gf":  { "x": 400, "y": 130 }
 *   },
 *   "objects": [
 *     {
 *       "id":     "bg",
 *       "asset":  "stageback",
 *       "x": -600, "y": -200,
 *       "scroll": [0.9, 0.9],
 *       "scale":  1.0,
 *       "alpha":  1.0,
 *       "zIndex": 0,
 *       "animations": [],
 *       "defaultAnim": ""
 *     }
 *   ]
 * }
 */
class CodenameStageConverter
{
	/**
	 * Converts a raw Codename Engine stage JSON string into Cool Engine StageData.
	 */
	public static function convertStage(rawJson:String, stageName:String):Dynamic
	{
		trace('[CodenameStageConverter] Converting stage "$stageName"...');

		final root:Dynamic = Json.parse(rawJson);

		// Detect which CNE variant this is
		final isVariantB = Reflect.hasField(root, 'objects') && Reflect.hasField(root, 'characters');

		final stageData = isVariantB
			? _convertVariantB(root, stageName)
			: _convertVariantA(root, stageName);

		trace('[CodenameStageConverter] Done.');
		return stageData;
	}

	// ─── Variant A: "sprites" array ──────────────────────────────────────────

	static function _convertVariantA(root:Dynamic, stageName:String):Dynamic
	{
		final bfPos  = _arr2(root.bfPos,  [770.0, 450.0]);
		final dadPos = _arr2(root.dadPos, [100.0, 100.0]);
		final gfPos  = _arr2(root.gfPos,  [400.0, 130.0]);
		final camBF  = _arr2(root.camBF,  [0.0, 0.0]);
		final camDad = _arr2(root.camDad, [0.0, 0.0]);

		final elements:Array<Dynamic> = [];
		final sprites:Array<Dynamic>  = _getArray(root.sprites);

		for (i in 0...sprites.length)
		{
			final sp  = sprites[i];
			final animated = _bool(sp.animated, false) || _getArray(sp.animations).length > 0;

			// CNE scale can be Float or Array
			final scale = _cneScaleToCool(sp.scale);

			final elem:Dynamic = {
				type:         animated ? 'animated' : 'sprite',
				asset:        _str(sp.image ?? sp.asset, ''),
				position:     [_float(sp.x, 0.0), _float(sp.y, 0.0)],
				name:         _str(sp.name ?? sp.id, 'sprite_$i'),
				scrollFactor: [_float(sp.scrollX ?? 1.0, 1.0), _float(sp.scrollY ?? 1.0, 1.0)],
				scale:        scale,
				antialiasing: _bool(sp.antialiasing, true),
				alpha:        _float(sp.alpha, 1.0),
				flipX:        _bool(sp.flipX ?? sp.flip_x, false),
				flipY:        _bool(sp.flipY ?? sp.flip_y, false),
				visible:      _bool(sp.visible, true),
				zIndex:       Std.int(_float(sp.zIndex ?? sp.depth ?? i, i))
			};

			if (animated)
			{
				final coolAnims = _convertAnims(_getArray(sp.animations));
				Reflect.setField(elem, 'animations',     coolAnims);
				Reflect.setField(elem, 'firstAnimation', _str(sp.startAnim ?? sp.startingAnim, coolAnims.length > 0 ? coolAnims[0].name : ''));
			}

			elements.push(elem);
		}

		return {
			name:              stageName,
			defaultZoom:       _float(root.defaultZoom ?? root.zoom, 0.9),
			isPixelStage:      _bool(root.isPixelStage ?? root.pixel, false),
			hideGirlfriend:    _bool(root.hideGF ?? root.hide_girlfriend, false),
			gfPosition:        gfPos,
			boyfriendPosition: bfPos,
			dadPosition:       dadPos,
			cameraBoyfriend:   camBF,
			cameraDad:         camDad,
			elements:          elements,
			scripts:           []
		};
	}

	// ─── Variant B: "objects" + "characters" ─────────────────────────────────

	static function _convertVariantB(root:Dynamic, stageName:String):Dynamic
	{
		// Extract character positions from "characters" object
		final chars = root.characters ?? {};

		final bfData  :Dynamic = Reflect.field(chars, 'bf')  ?? Reflect.field(chars, 'player')   ?? {};
		final dadData :Dynamic = Reflect.field(chars, 'dad') ?? Reflect.field(chars, 'opponent') ?? {};
		final gfData  :Dynamic = Reflect.field(chars, 'gf')  ?? Reflect.field(chars, 'girlfriend') ?? {};

		final bfPos  = [_float(bfData.x,  770.0), _float(bfData.y,  450.0)];
		final dadPos = [_float(dadData.x, 100.0), _float(dadData.y, 100.0)];
		final gfPos  = [_float(gfData.x,  400.0), _float(gfData.y,  130.0)];
		final camBF  = _arr2(bfData.cameraOffset,  [0.0, 0.0]);
		final camDad = _arr2(dadData.cameraOffset, [0.0, 0.0]);

		final elements:Array<Dynamic> = [];
		final objects:Array<Dynamic>  = _getArray(root.objects);

		for (i in 0...objects.length)
		{
			final obj      = objects[i];
			final animated = _getArray(obj.animations).length > 0;
			final scale    = _cneScaleToCool(obj.scale);

			// In variant B, scroll can be Array [sx, sy] or separate fields
			final scrollArr:Array<Dynamic> = Std.isOfType(obj.scroll, Array) ? cast obj.scroll : null;
			final scrollX = scrollArr != null ? _float(scrollArr[0], 1.0) : _float(obj.scrollX ?? 1.0, 1.0);
			final scrollY = scrollArr != null ? _float(scrollArr[1], 1.0) : _float(obj.scrollY ?? 1.0, 1.0);

			final elem:Dynamic = {
				type:         animated ? 'animated' : 'sprite',
				asset:        _str(obj.asset ?? obj.image, ''),
				position:     [_float(obj.x, 0.0), _float(obj.y, 0.0)],
				name:         _str(obj.id ?? obj.name, 'object_$i'),
				scrollFactor: [scrollX, scrollY],
				scale:        scale,
				antialiasing: _bool(obj.antialiasing, true),
				alpha:        _float(obj.alpha, 1.0),
				flipX:        _bool(obj.flipX, false),
				flipY:        _bool(obj.flipY, false),
				visible:      _bool(obj.visible, true),
				zIndex:       Std.int(_float(obj.zIndex ?? obj.depth ?? i, i))
			};

			if (animated)
			{
				final coolAnims = _convertAnims(_getArray(obj.animations));
				Reflect.setField(elem, 'animations',     coolAnims);
				Reflect.setField(elem, 'firstAnimation', _str(obj.defaultAnim ?? obj.startAnim, coolAnims.length > 0 ? coolAnims[0].name : ''));
			}

			elements.push(elem);
		}

		return {
			name:              stageName,
			defaultZoom:       _float(root.defaultCamZoom ?? root.defaultZoom ?? root.zoom, 0.9),
			isPixelStage:      _bool(root.isPixelStage ?? root.pixel, false),
			hideGirlfriend:    _bool(root.hideGF ?? root.hide_girlfriend, false),
			gfPosition:        gfPos,
			boyfriendPosition: bfPos,
			dadPosition:       dadPos,
			cameraBoyfriend:   camBF,
			cameraDad:         camDad,
			elements:          elements,
			scripts:           []
		};
	}

	// ─── Shared helpers ───────────────────────────────────────────────────────

	/**
	 * Converts CNE animation entries to Cool Engine StageAnimation format.
	 * CNE: { name, anim/prefix, fps, loop/looped, offset/indices }
	 * Cool: { name, prefix, framerate, looped, indices }
	 */
	static function _convertAnims(cneAnims:Array<Dynamic>):Array<Dynamic>
	{
		final out:Array<Dynamic> = [];
		for (ca in cneAnims)
		{
			final indices = _getIntArray(ca.indices);
			out.push({
				name:      _str(ca.name,              'idle'),
				prefix:    _str(ca.anim ?? ca.prefix, 'idle'),
				framerate: Std.int(_float(ca.fps ?? ca.framerate, 24)),
				looped:    _bool(ca.loop ?? ca.looped, false),
				indices:   indices
			});
		}
		return out;
	}

	/**
	 * CNE scale: Float or null → Cool [sx, sy] Array.
	 */
	static function _cneScaleToCool(v:Dynamic):Array<Float>
	{
		if (v == null) return [1.0, 1.0];
		if (Std.isOfType(v, Array))
		{
			final a:Array<Dynamic> = cast v;
			return [
				_float(a.length > 0 ? a[0] : 1.0, 1.0),
				_float(a.length > 1 ? a[1] : 1.0, 1.0)
			];
		}
		final s = _float(v, 1.0);
		return [s, s];
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
