package shaders;

import flixel.FlxSprite;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.system.FlxAssets.FlxShader;
import flixel.util.FlxColor;

/**
 * Tipos de máscara disponibles.
 */
enum abstract MaskType(Int) to Int
{
	/** Recorte rectangular: oculta fuera de (x, y, w, h) en UV [0..1] */
	var RECT       = 0;
	/** Recorte por el lado izquierdo — todo lo que esté a la IZQUIERDA de maskX se oculta */
	var LEFT       = 1;
	/** Recorte por el lado derecho — todo lo que esté a la DERECHA de maskX se oculta */
	var RIGHT      = 2;
	/** Recorte por arriba — todo lo que esté ENCIMA de maskY se oculta */
	var TOP        = 3;
	/** Recorte por abajo — todo lo que esté DEBAJO de maskY se oculta */
	var BOTTOM     = 4;
	/** Máscara circular / elíptica, centrada en (cx, cy) con radios (rx, ry) en UV */
	var CIRCLE     = 5;
	/** Máscara angular: oculta píxeles fuera del ángulo desde la esquina superior-izquierda (port de V-Slice AngleMask) */
	var ANGLE      = 6;
}

// ─────────────────────────────────────────────────────────────────────────────
//  MaskShader  —  Un único FlxShader que cubre todos los tipos de máscara
// ─────────────────────────────────────────────────────────────────────────────
//
//  Cómo funciona:
//    • uniform int uMaskType  selecciona la rama en el fragmento.
//    • uniform vec4 uMaskRect  → [x0, y0, x1, y1] en UV (0..1) para RECT.
//    • uniform float uMaskEdge → [valor] posición del borde para LEFT/RIGHT/TOP/BOTTOM.
//    • uniform vec4 uMaskCircle → [cx, cy, rx, ry] en UV para CIRCLE.
//    • uniform vec2 uMaskAngle  → [endX, endY] en pixels para ANGLE.
//    • uniform float uSoftness  → suavizado del borde (0 = duro, 0.01..0.05 = suave).
//    • uniform bool  uInvert    → invierte la máscara.
//
//  Todos los valores por defecto muestran el sprite completo sin recortar.

class MaskShader extends FlxShader
{
	// ── Propiedades públicas con setters seguros ──────────────────────────────

	/** Tipo de máscara activo (default RECT que muestra todo). */
	public var maskType(default, set):MaskType = RECT;

	/** Borde de recorte para LEFT/RIGHT/TOP/BOTTOM en pixels del sprite. */
	public var maskEdgePx(default, set):Float = 0.0;

	/** Rect de recorte para RECT, en pixels del sprite. */
	public var maskRect(default, set):FlxRect = new FlxRect(0, 0, 9999, 9999);

	/** Centro y radios para CIRCLE en pixels. */
	public var circleCenterPx(default, set):FlxPoint = new FlxPoint(0, 0);
	public var circleRadiusPx(default, set):FlxPoint = new FlxPoint(50, 50);

	/** Punto final del ángulo (en pixels del sprite) para ANGLE. */
	public var angleEndPx(default, set):FlxPoint = new FlxPoint(90, 100);

	/** Suavizado de borde [0..0.05 aprox]. 0 = hard. */
	public var softness(default, set):Float = 0.0;

	/** Invierte la máscara. */
	public var inverted(default, set):Bool = false;

	// ── GLSL ─────────────────────────────────────────────────────────────────

	@:glFragmentSource('
		#pragma header

		// ── Uniforms ──────────────────────────────────────────────────────────
		uniform int   uMaskType;    // 0=RECT 1=LEFT 2=RIGHT 3=TOP 4=BOTTOM 5=CIRCLE 6=ANGLE
		uniform vec4  uMaskRect;    // [x0,y0,x1,y1] UV
		uniform float uMaskEdge;    // posición de borde UV para L/R/T/B
		uniform vec4  uMaskCircle;  // [cx,cy,rx,ry] UV
		uniform vec2  uMaskAngle;   // [endX,endY] UV
		uniform float uSoftness;    // suavizado del borde
		uniform bool  uInvert;

		// ── Anti-aliasing helper (igual que V-Slice AngleMask) ────────────────
		vec2 hash22(vec2 p)
		{
			vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
			p3 += dot(p3, p3.yzx + 33.33);
			return fract((p3.xx + p3.yz) * p3.zy);
		}

		// ── Cálculo del alpha de máscara para cada tipo ───────────────────────
		float rectMask(vec2 uv)
		{
			float xOk = smoothstep(uMaskRect.x - uSoftness, uMaskRect.x + uSoftness, uv.x)
			          * (1.0 - smoothstep(uMaskRect.z - uSoftness, uMaskRect.z + uSoftness, uv.x));
			float yOk = smoothstep(uMaskRect.y - uSoftness, uMaskRect.y + uSoftness, uv.y)
			          * (1.0 - smoothstep(uMaskRect.w - uSoftness, uMaskRect.w + uSoftness, uv.y));
			return xOk * yOk;
		}

		float edgeMask(vec2 uv)
		{
			// LEFT  (1): visible si uv.x > edge
			// RIGHT (2): visible si uv.x < edge
			// TOP   (3): visible si uv.y > edge
			// BOTTOM(4): visible si uv.y < edge
			if (uMaskType == 1) return smoothstep(uMaskEdge - uSoftness, uMaskEdge + uSoftness, uv.x);
			if (uMaskType == 2) return 1.0 - smoothstep(uMaskEdge - uSoftness, uMaskEdge + uSoftness, uv.x);
			if (uMaskType == 3) return smoothstep(uMaskEdge - uSoftness, uMaskEdge + uSoftness, uv.y);
			/* BOTTOM (4) */ return 1.0 - smoothstep(uMaskEdge - uSoftness, uMaskEdge + uSoftness, uv.y);
		}

		float circleMask(vec2 uv)
		{
			vec2 center = uMaskCircle.xy;
			vec2 radius = uMaskCircle.zw;
			vec2 d = (uv - center) / max(radius, vec2(0.0001));
			float dist = dot(d, d); // 1.0 en el borde del elipse
			return 1.0 - smoothstep(1.0 - uSoftness * 8.0, 1.0 + uSoftness * 8.0, dist);
		}

		float angleMaskPass(vec2 uv)
		{
			vec2 start = vec2(0.0, 0.0);
			vec2 end   = uMaskAngle;

			float dx = end.x - start.x;
			float dy = end.y - start.y;
			float angle = atan(dy, dx);

			vec2 delta = uv - start;
			float uvAngle = atan(delta.y, delta.x);

			return uvAngle < angle ? 1.0 : 0.0;
		}

		float angleMask(vec2 uv)
		{
			// Misma técnica AA de V-Slice AngleMask
			// FIX: loop vars deben ser int en GLSL, no float
			const int   AA_STAGES_I = 2;
			const float AA_STAGES   = 2.0;
			const float AA_TOTAL    = AA_STAGES * AA_STAGES + 1.0;
			const float AA_JITTER   = 0.5;

			float color = angleMaskPass(uv);
			for (int xi = 0; xi < AA_STAGES_I; xi++)
			{
				for (int yi = 0; yi < AA_STAGES_I; yi++)
				{
					vec2 offset = AA_JITTER * (2.0 * hash22(vec2(float(xi), float(yi))) - 1.0) / openfl_TextureSize.xy;
					color += angleMaskPass(uv + offset);
				}
			}
			return color / AA_TOTAL;
		}

		// ── Main ──────────────────────────────────────────────────────────────
		void main()
		{
			vec4 color = flixel_texture2D(bitmap, openfl_TextureCoordv);

			float maskAlpha;
			if      (uMaskType == 0) maskAlpha = rectMask(openfl_TextureCoordv);
			else if (uMaskType == 5) maskAlpha = circleMask(openfl_TextureCoordv);
			else if (uMaskType == 6) maskAlpha = angleMask(openfl_TextureCoordv);
			else                     maskAlpha = edgeMask(openfl_TextureCoordv);

			if (uInvert) maskAlpha = 1.0 - maskAlpha;

			color.a *= maskAlpha;
			gl_FragColor = color;
		}')

	// ── Constructor ──────────────────────────────────────────────────────────

	public function new()
	{
		super();
		_initDefaults();
	}

	function _initDefaults():Void
	{
		// Rect que cubre todo → sin recorte visible por defecto
		try { uMaskType.value   = [MaskType.RECT];  } catch (_:Dynamic) {}
		try { uMaskRect.value   = [0.0, 0.0, 1.0, 1.0]; } catch (_:Dynamic) {}
		try { uMaskEdge.value   = [0.5];            } catch (_:Dynamic) {}
		try { uMaskCircle.value = [0.5, 0.5, 0.5, 0.5]; } catch (_:Dynamic) {}
		try { uMaskAngle.value  = [1.0, 1.0];       } catch (_:Dynamic) {}
		try { uSoftness.value   = [0.0];             } catch (_:Dynamic) {}
		try { uInvert.value     = [false];           } catch (_:Dynamic) {}
	}

	// ── Setters ──────────────────────────────────────────────────────────────

	function set_maskType(v:MaskType):MaskType
	{
		maskType = v;
		try { uMaskType.value = [v]; } catch (_:Dynamic) {}
		return v;
	}

	/** Recibe posición en pixels del sprite; la convierte a UV internamente. */
	function set_maskEdgePx(px:Float):Float
	{
		maskEdgePx = px;
		// Para LEFT/RIGHT usamos X, para TOP/BOTTOM usamos Y — ambos en UV relativo al bitmap
		try {
			final sizeX = openfl_TextureSize.value != null ? openfl_TextureSize.value[0] : 1.0;
			final sizeY = openfl_TextureSize.value != null ? openfl_TextureSize.value[1] : 1.0;
			final uv = switch (cast(maskType, Int))
			{
				case 3, 4: px / (sizeY > 0 ? sizeY : 1.0);
				default:   px / (sizeX > 0 ? sizeX : 1.0);
			}
			uMaskEdge.value = [uv];
		} catch (_:Dynamic) {}
		return px;
	}

	function set_maskRect(r:FlxRect):FlxRect
	{
		maskRect = r;
		try {
			final sx = openfl_TextureSize.value != null ? openfl_TextureSize.value[0] : 1.0;
			final sy = openfl_TextureSize.value != null ? openfl_TextureSize.value[1] : 1.0;
			uMaskRect.value = [r.x / sx, r.y / sy, (r.x + r.width) / sx, (r.y + r.height) / sy];
		} catch (_:Dynamic) {}
		return r;
	}

	function set_circleCenterPx(p:FlxPoint):FlxPoint
	{
		circleCenterPx = p;
		_updateCircle();
		return p;
	}

	function set_circleRadiusPx(p:FlxPoint):FlxPoint
	{
		circleRadiusPx = p;
		_updateCircle();
		return p;
	}

	function _updateCircle():Void
	{
		try {
			final sx = openfl_TextureSize.value != null ? openfl_TextureSize.value[0] : 1.0;
			final sy = openfl_TextureSize.value != null ? openfl_TextureSize.value[1] : 1.0;
			uMaskCircle.value = [
				circleCenterPx.x / sx, circleCenterPx.y / sy,
				circleRadiusPx.x / sx, circleRadiusPx.y / sy
			];
		} catch (_:Dynamic) {}
	}

	function set_angleEndPx(p:FlxPoint):FlxPoint
	{
		angleEndPx = p;
		try {
			final sx = openfl_TextureSize.value != null ? openfl_TextureSize.value[0] : 1.0;
			final sy = openfl_TextureSize.value != null ? openfl_TextureSize.value[1] : 1.0;
			uMaskAngle.value = [p.x / sx, p.y / sy];
		} catch (_:Dynamic) {}
		return p;
	}

	function set_softness(v:Float):Float
	{
		softness = v;
		try { uSoftness.value = [v]; } catch (_:Dynamic) {}
		return v;
	}

	function set_inverted(v:Bool):Bool
	{
		inverted = v;
		try { uInvert.value = [v]; } catch (_:Dynamic) {}
		return v;
	}
}
