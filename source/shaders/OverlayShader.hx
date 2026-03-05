package shaders;

import flixel.system.FlxAssets.FlxShader;

class OverlayShader extends FlxShader
{
	@:glFragmentSource('
		#pragma header

		uniform vec4 uBlendColor;

		// FIX 1: firma GLSL correcta — la sintaxis "base:Vec3 : Vec3" era Haxe, no GLSL
		// FIX 2: renombrado a blendOverlay (el algoritmo era overlay, no lighten)
		vec3 blendOverlay(vec3 base, vec3 blend)
		{
			return mix(
				1.0 - 2.0 * (1.0 - base) * (1.0 - blend),
				2.0 * base * blend,
				step(base, vec3(0.5))
			);
		}

		// FIX 3: base y blend son vec4 — hay que pasar .rgb a la función vec3
		//        y reconstruir el alpha correctamente
		vec4 blendOverlayAlpha(vec4 base, vec4 blend, float opacity)
		{
			vec3 blended = blendOverlay(base.rgb, blend.rgb);
			return vec4(blended * opacity + base.rgb * (1.0 - opacity), base.a);
		}

		void main()
		{
			vec4 base    = texture2D(bitmap, openfl_TextureCoordv);
			gl_FragColor = blendOverlayAlpha(base, uBlendColor, uBlendColor.a);
		}')
	public function new()
	{
		super();
		try { uBlendColor.value = [1.0, 1.0, 1.0, 1.0]; } catch (_:Dynamic) {}
	}
}
