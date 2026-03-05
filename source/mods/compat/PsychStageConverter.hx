package mods.compat;

using StringTools;

import haxe.Json;
import funkin.gameplay.objects.stages.Stage;

/**
 * PsychStageConverter
 * ─────────────────────────────────────────────────────────────────────────────
 * Converts a Psych Engine 0.6.x / 0.7.x stage JSON into Cool Engine's StageData.
 *
 * ── Psych StageFile real (de StageData.hx) ──────────────────────────────────
 * {
 *   "directory":    "",          ← biblioteca de assets compartida (p.ej. "week4")
 *   "defaultZoom":  0.9,
 *   "isPixelStage": false,
 *   "stageUI":      "normal",    ← "normal" | "pixel" | custom
 *   "boyfriend":    [770, 100],  ← posición X/Y (array de 2 floats)
 *   "girlfriend":   [400, 130],
 *   "opponent":     [100, 100],
 *   "hide_girlfriend": false,
 *   "camera_boyfriend":  [0, 0],
 *   "camera_opponent":   [0, 0],
 *   "camera_girlfriend": [0, 0],  ← BUG FIX #6: campo que faltaba completamente
 *   "camera_speed":      1.0,     ← BUG FIX #7: campo que faltaba completamente
 *   "objects": [ ... ]            ← BUG FIX #5: Psych 0.6 usa "objects", no "stageObjects"
 * }
 *
 * ── Formato de cada objeto en Psych (campo "objects") ───────────────────────
 * {
 *   "name":         "bg",
 *   "image":        "stageback",
 *   "libraryName":  "",           ← overrides "directory" para este sprite
 *   "position":     [-600, -200],
 *   "scrollFactor": [0.9, 0.9],
 *   "scale":        [1, 1],       ← puede ser Float o Array<Float>
 *   "angle":        0,
 *   "alpha":        1,
 *   "isAnimated":   false,
 *   "frameRate":    24,
 *   "animations":   [],
 *   "startingAnim": "",
 *   "antialiasing": true,
 *   "visible":      true,
 *   "flipX":        false,
 *   "flipY":        false,
 *   "depth":        0,
 *   "color":        "0xFFFFFFFF",
 *   "blend":        ""
 * }
 *
 * ── Notas ────────────────────────────────────────────────────────────────────
 * - Psych 0.7.x Stage Editor guarda los sprites en "stageObjects"; Psych 0.6.x
 *   y la mayoría de mods los guardan en "objects". Este convertor soporta AMBOS.
 * - "directory" es el nombre de la biblioteca de assets de Psych (librería compartida).
 *   Se mapea a stageData.directory para que el cargador de stages pueda precargarlo.
 * - "libraryName" en cada objeto sobreescribe el directorio global por sprite.
 * - Lua scripts (.lua) asociados al stage son ignorados (no soportados).
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
		// Psych puede envolver en "stageJson" o almacenar plano
		final ps:Dynamic   = (Reflect.hasField(root, 'stageJson')) ? root.stageJson : root;

		// ── BUG FIX #8: "directory" — biblioteca de assets de Psych ──────────
		// Los mods de Psych usan esto para precargar una librería de assets
		// compartida (equivalente al swf/pack que usa FlxAtlasFrames).
		// Sin esto, los sprites del escenario no encuentran sus imágenes.
		final directory:String = _str(ps.directory, '');

		// ── Character positions ───────────────────────────────────────────────
		final gfPos  = _arr2(ps.girlfriend,      [400.0, 130.0]);
		final bfPos  = _arr2(ps.boyfriend,       [770.0, 450.0]);
		final dadPos = _arr2(ps.opponent,        [100.0, 100.0]);
		final camBF  = _arr2(ps.camera_boyfriend, [0.0, 0.0]);
		final camDad = _arr2(ps.camera_opponent,  [0.0, 0.0]);

		// BUG FIX #6: Psych tiene camera_girlfriend además de camera_boyfriend/opponent.
		// La versión anterior lo ignoraba completamente, rompiendo stages con GF activa.
		final camGF  = _arr2(ps.camera_girlfriend, [0.0, 0.0]);

		// BUG FIX #7: camera_speed controla la velocidad del lerp de cámara.
		// Sin este campo los cambios de cámara son instantáneos en lugar de suaves.
		final camSpeed:Float = _float(ps.camera_speed, 1.0);

		// ── Elements ──────────────────────────────────────────────────────────
		final elements:Array<Dynamic> = [];

		// BUG FIX #5: Psych 0.7.x Stage Editor usa "stageObjects", pero Psych 0.6.x
		// y la MAYORÍA de mods reales usan "objects". Hay que probar ambos.
		// Si ninguno existe, usar array vacío (stage sin sprites estáticos).
		var rawObjects:Dynamic = ps.stageObjects;
		if (rawObjects == null || !Std.isOfType(rawObjects, Array))
			rawObjects = ps.objects;
		final psychObjs:Array<Dynamic> = _getArray(rawObjects);

		for (i in 0...psychObjs.length)
		{
			final obj = psychObjs[i];
			final isAnimated = _bool(obj.isAnimated, false);
			final hasAnims   = isAnimated && _getArray(obj.animations).length > 0;

			// ── Image path ────────────────────────────────────────────────────
			// "libraryName" del objeto sobreescribe el "directory" global.
			// Si ambos están vacíos, la imagen es simplemente el filename.
			final lib   = _str(obj.libraryName != null ? obj.libraryName : directory, '');
			final img   = _str(obj.image, '');
			final asset = (lib != '') ? '$lib/$img' : img;

			// ── Position ──────────────────────────────────────────────────────
			final pos = _arr2(obj.position, [0.0, 0.0]);

			// ── Color: Psych usa "0xAARRGGBB" string ──────────────────────────
			final colorStr = _psychColorToCool(_str(obj.color, ''));

			// ── Build element ─────────────────────────────────────────────────
			final elem:Dynamic = {
				type:         hasAnims ? 'animated' : 'sprite',
				asset:        asset,
				position:     pos,
				// Psych usa "name" en algunos objetos; si no existe, generar uno
				name:         obj.name != null ? _str(obj.name, 'object_$i') : 'object_$i',
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
			directory:          directory,          // BUG FIX #8
			defaultZoom:        _float(ps.defaultZoom, 0.9),
			isPixelStage:       _bool(ps.isPixelStage, false),
			stageUI:            _str(ps.stageUI, 'normal'),
			hideGirlfriend:     _bool(ps.hide_girlfriend, false),
			gfPosition:         gfPos,
			boyfriendPosition:  bfPos,
			dadPosition:        dadPos,
			cameraBoyfriend:    camBF,
			cameraDad:          camDad,
			cameraGirlfriend:   camGF,              // BUG FIX #6
			cameraSpeed:        camSpeed,           // BUG FIX #7
			elements:           elements,
			scripts:            []                  // Lua scripts not supported
		};

		trace('[PsychStageConverter] Done. Elements: ${elements.length}, directory: "$directory"');
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

	// BUG FIX: algunos charts/stages de Psych serializan booleanos como enteros (0/1).
	// La versión anterior usaba `(v == true)` que devuelve false para el entero 1.
	// Eso rompía hide_girlfriend=1, isPixelStage=1, etc.
	static inline function _bool(v:Dynamic, def:Bool):Bool
	{
		if (v == null)  return def;
		if (v == true)  return true;
		if (v == false) return false;
		// Enteros: 0 = false, cualquier otro valor = true
		final n = Std.parseFloat(Std.string(v));
		if (!Math.isNaN(n)) return n != 0;
		return def;
	}
}
