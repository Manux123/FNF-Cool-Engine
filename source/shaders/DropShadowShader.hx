package shaders;

import flixel.FlxSprite;
import flixel.graphics.frames.FlxFrame;
import flixel.math.FlxAngle;
import flixel.system.FlxAssets.FlxShader;
import flixel.util.FlxColor;
import openfl.display.BitmapData;
import openfl.utils.Assets;

/**
 * DropShadowShader — Portado de V-Slice (Funkin') para Cool Engine.
 *
 * Recrea el drop shadow / rim-light de Adobe Animate/Flash.
 * Incluye también el filtro Adjust Color (hue, saturation, brightness, contrast).
 *
 * Propiedades:
 *   color         — color del drop shadow (FlxColor)
 *   angle         — ángulo en grados (0=derecha, 90=arriba, 180=izquierda, 270=abajo)
 *   distance      — distancia en píxeles de textura
 *   strength      — multiplicador de alfa del shadow
 *   threshold     — umbral de brillo: píxeles por debajo NO reciben shadow (útil para outlines)
 *   antialiasAmt  — muestras AA para suavizar bordes del threshold (0 = sin AA, default 2)
 *   useAltMask    — activar la máscara alternativa
 *   altMaskImage  — BitmapData de la máscara alternativa (canal azul = zona de máscara)
 *   maskThreshold — umbral alternativo aplicado dentro de la máscara
 *   attachedSprite — sprite cuya info de frame se usa para las bounds del shadow
 *   baseHue / baseSaturation / baseBrightness / baseContrast — Adjust Color
 */
class DropShadowShader extends FlxShader
{
	// ── Propiedades con setters ───────────────────────────────────────────────

	public var color(default, set):FlxColor;
	public var angle(default, set):Float;
	public var distance(default, set):Float;
	public var strength(default, set):Float;
	public var threshold(default, set):Float;
	public var antialiasAmt(default, set):Float;
	public var useAltMask(default, set):Bool;
	public var altMaskImage(default, set):BitmapData;
	public var maskThreshold(default, set):Float;
	public var attachedSprite(default, set):FlxSprite;

	public var baseHue(default, set):Float;
	public var baseSaturation(default, set):Float;
	public var baseBrightness(default, set):Float;
	public var baseContrast(default, set):Float;

	// ── setAdjustColor helper ─────────────────────────────────────────────────

	/**
	 * Atajo para fijar los 4 valores de Adjust Color de una sola vez.
	 * @param b brightness
	 * @param h hue
	 * @param c contrast
	 * @param s saturation
	 */
	public function setAdjustColor(b:Float, h:Float, c:Float, s:Float):Void
	{
		baseBrightness = b;
		baseHue        = h;
		baseContrast   = c;
		baseSaturation = s;
	}

	// ── Setters ───────────────────────────────────────────────────────────────

	function set_baseHue(val:Float):Float
	{
		baseHue = val;
		hue.value = [val];
		return val;
	}

	function set_baseSaturation(val:Float):Float
	{
		baseSaturation = val;
		saturation.value = [val];
		return val;
	}

	function set_baseBrightness(val:Float):Float
	{
		baseBrightness = val;
		brightness.value = [val];
		return val;
	}

	function set_baseContrast(val:Float):Float
	{
		baseContrast = val;
		contrast.value = [val];
		return val;
	}

	function set_threshold(val:Float):Float
	{
		threshold = val;
		thr.value = [val];
		return val;
	}

	function set_antialiasAmt(val:Float):Float
	{
		antialiasAmt = val;
		AA_STAGES.value = [val];
		return val;
	}

	function set_color(col:FlxColor):FlxColor
	{
		color = col;
		dropColor.value = [color.red / 255, color.green / 255, color.blue / 255];
		return color;
	}

	function set_angle(val:Float):Float
	{
		angle = val;
		ang.value = [angle * FlxAngle.TO_RAD];
		return angle;
	}

	function set_distance(val:Float):Float
	{
		distance = val;
		dist.value = [val];
		return val;
	}

	function set_strength(val:Float):Float
	{
		strength = val;
		str.value = [val];
		return val;
	}

	function set_attachedSprite(spr:FlxSprite):FlxSprite
	{
		attachedSprite = spr;
		if (spr != null && spr.frame != null)
			updateFrameInfo(spr.frame);
		return spr;
	}

	/**
	 * Carga la imagen de la máscara alternativa.
	 * Funciona tanto en HTML5 como en targets nativos.
	 * @param path Path devuelto por Paths.image() o similar
	 */
	public function loadAltMask(path:String):Void
	{
		#if html5
		BitmapData.loadFromFile(path).onComplete(function(bmp:BitmapData)
		{
			altMaskImage = bmp;
		});
		#else
		altMaskImage = Assets.getBitmapData(path, false);
		#end
	}

	/**
	 * Actualiza las bounds y el offset de rotación del frame actual.
	 * Llamar en cada cambio de frame (p.ej. en onUpdate del stage script).
	 * @param frame Frame actual del sprite adjunto
	 */
	public function updateFrameInfo(frame:FlxFrame):Void
	{
		// uv.right/bottom son la posición derecha/inferior, no el tamaño
		uFrameBounds.value = [frame.uv.left, frame.uv.top, frame.uv.right, frame.uv.bottom];
		// Compensar frames rotados en el atlas
		angOffset.value = [frame.angle * FlxAngle.TO_RAD];
	}

	function set_altMaskImage(bitmapData:BitmapData):BitmapData
	{
		altMask.input = bitmapData;
		return bitmapData;
	}

	function set_maskThreshold(val:Float):Float
	{
		maskThreshold = val;
		thr2.value = [val];
		return val;
	}

	function set_useAltMask(val:Bool):Bool
	{
		useAltMask = val;
		useMask.value = [val];
		return val;
	}

	// ── GLSL ─────────────────────────────────────────────────────────────────

	@:glFragmentSource('
		#pragma header

		// Drop Shadow / Rim-Light shader.
		// Incluye recreación del filtro Adjust Color de Adobe Animate/Flash.
		// Adjust Color por Rozebud (https://github.com/ThatRozebudDude)
		// Adaptado del shader de Andrey-Postelzhuk:
		//   https://forum.unity.com/threads/hue-saturation-brightness-contrast-shader.260649/
		// Rotación de matiz: https://www.w3.org/TR/filter-effects/#feColorMatrixElement

		// (frame.left, frame.top, frame.right, frame.bottom) en UV
		uniform vec4 uFrameBounds;

		uniform float ang;
		uniform float dist;
		uniform float str;
		uniform float thr;

		// Compensación de frames rotados en el atlas
		uniform float angOffset;

		uniform sampler2D altMask;
		uniform bool useMask;
		uniform float thr2;

		uniform vec3 dropColor;

		uniform float hue;
		uniform float saturation;
		uniform float brightness;
		uniform float contrast;

		uniform float AA_STAGES;

		const vec3 grayscaleValues = vec3(0.3098039215686275, 0.607843137254902, 0.0823529411764706);
		const float e = 2.718281828459045;

		vec3 applyHueRotate(vec3 aColor, float aHue){
			float angle = radians(aHue);
			mat3 m1 = mat3(0.213, 0.213, 0.213, 0.715, 0.715, 0.715, 0.072, 0.072, 0.072);
			mat3 m2 = mat3(0.787, -0.213, -0.213, -0.715, 0.285, -0.715, -0.072, -0.072, 0.928);
			mat3 m3 = mat3(-0.213, 0.143, -0.787, -0.715, 0.140, 0.715, 0.928, -0.283, 0.072);
			mat3 m = m1 + cos(angle) * m2 + sin(angle) * m3;
			return m * aColor;
		}

		vec3 applySaturation(vec3 aColor, float value){
			if(value > 0.0){ value = value * 3.0; }
			value = (1.0 + (value / 100.0));
			vec3 grayscale = vec3(dot(aColor, grayscaleValues));
			return clamp(mix(grayscale, aColor, value), 0.0, 1.0);
		}

		vec3 applyContrast(vec3 aColor, float value){
			value = (1.0 + (value / 100.0));
			if(value > 1.0){
				value = (((0.00852259 * pow(e, 4.76454 * (value - 1.0))) * 1.01) - 0.0086078159) * 10.0;
				value += 1.0;
			}
			return clamp((aColor - 0.25) * value + 0.25, 0.0, 1.0);
		}

		vec3 applyHSBCEffect(vec3 color){
			color = color + ((brightness) / 255.0);
			color = applyHueRotate(color, hue);
			color = applyContrast(color, contrast);
			color = applySaturation(color, saturation);
			return color;
		}

		vec2 hash22(vec2 p) {
			vec3 p3 = fract(vec3(p.xyx) * vec3(.1031, .1030, .0973));
			p3 += dot(p3, p3.yzx + 33.33);
			return fract((p3.xx + p3.yz) * p3.zy);
		}

		float intensityPass(vec2 fragCoord, float curThreshold, bool useMask) {
			vec4 col = texture2D(bitmap, fragCoord);

			float maskIntensity = 0.0;
			if(useMask == true){
				maskIntensity = mix(0.0, 1.0, texture2D(altMask, fragCoord).b);
			}

			if(col.a == 0.0){
				return 0.0;
			}

			float intensity = dot(col.rgb, vec3(0.3098, 0.6078, 0.0823));
			intensity = maskIntensity > 0.0 ? float(intensity > thr2) : float(intensity > thr);
			return intensity;
		}

		float antialias(vec2 fragCoord, float curThreshold, bool useMask) {
			if (AA_STAGES == 0.0) {
				return intensityPass(fragCoord, curThreshold, useMask);
			}

			const int MAX_AA = 8;
			float AA_TOTAL_PASSES = AA_STAGES * AA_STAGES + 1.0;
			const float AA_JITTER = 0.5;

			float color = intensityPass(fragCoord, curThreshold, useMask);
			for (int i = 0; i < MAX_AA * MAX_AA; i++) {
				int x = i / MAX_AA;
				int y = i - (MAX_AA * int(i / MAX_AA));
				if (float(x) >= AA_STAGES || float(y) >= AA_STAGES) { continue; }
				vec2 offset = AA_JITTER * (2.0 * hash22(vec2(float(x), float(y))) - 1.0) / openfl_TextureSize.xy;
				color += intensityPass(fragCoord + offset, curThreshold, useMask);
			}

			return color / AA_TOTAL_PASSES;
		}

		// BUGFIX createDropShadow: el algoritmo original tomaba intensity del pixel ACTUAL
		// (que es 0 para pixeles transparentes), por lo que la sombra nunca aparecia
		// detras del sprite. El algoritmo correcto es: mirar el pixel en la direccion
		// contraria al offset (el "lanzador de sombra") para decidir si mostrar sombra
		// en el pixel actual. Esto hace que la sombra aparezca en pixeles transparentes
		// que tienen un pixel opaco cerca en la direccion del offset.
		//
		// Composicion correcta (premultiplicada):
		//   shadowContrib = shadowCasterAlpha * str * (1 - spriteAlpha)
		//   outRGB = spritePremult + dropColor * shadowContrib
		//   outA   = spriteAlpha + shadowContrib

		void main()
		{
			vec4 col = texture2D(bitmap, openfl_TextureCoordv); // premultiplied RGBA

			// --- Calcular donde esta el lanzador de sombra ---
			vec2 imageRatio = vec2(1.0 / openfl_TextureSize.x, 1.0 / openfl_TextureSize.y);
			vec2 shadowSourceUV = vec2(
				openfl_TextureCoordv.x + (dist * cos(ang + angOffset) * imageRatio.x),
				openfl_TextureCoordv.y - (dist * sin(ang + angOffset) * imageRatio.y)
			);

			// Alpha del pixel que lanza sombra sobre el pixel actual
			float shadowCasterAlpha = 0.0;
			if (shadowSourceUV.x > uFrameBounds.x && shadowSourceUV.y > uFrameBounds.y
			&&  shadowSourceUV.x < uFrameBounds.z && shadowSourceUV.y < uFrameBounds.w)
			{
				float srcIntensity = antialias(shadowSourceUV, thr, useMask);
				shadowCasterAlpha = srcIntensity * str;
			}

			// --- Aplicar HSBC al color del sprite (despreemultiplicado) ---
			vec3 unpremult = col.a > 0.0 ? col.rgb / col.a : vec3(0.0);
			vec3 hsbc = clamp(applyHSBCEffect(unpremult), 0.0, 1.0);

			// --- Composicion sombra + sprite (premultiplied) ---
			// La sombra solo contribuye donde el sprite es transparente/semi-transparente
			float shadowContrib = clamp(shadowCasterAlpha * (1.0 - col.a), 0.0, 1.0);

			vec3 outRgb  = hsbc * col.a + dropColor.rgb * shadowContrib;
			float outA   = clamp(col.a + shadowContrib, 0.0, 1.0);

			gl_FragColor = vec4(outRgb, outA);
		}
	')
	public function new()
	{
		super();

		angle        = 0;
		strength     = 1;
		distance     = 15;
		threshold    = 0.1;

		baseHue        = 0;
		baseSaturation = 0;
		baseBrightness = 0;
		baseContrast   = 0;

		antialiasAmt = 2;
		useAltMask   = false;

		angOffset.value = [0];
	}
}
