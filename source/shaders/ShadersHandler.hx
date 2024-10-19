package shaders;

import openfl.Lib;
import openfl.display.Shader;
import openfl.filters.ShaderFilter;
import openfl8.*;

class ShadersHandler
{
	public static var chromaticAberration:ShaderFilter = new ShaderFilter(new ChromaticAberration());
	public static var mosaic:ShaderFilter = new ShaderFilter(new MosaicShader());
	public static var brightShader:ShaderFilter = new ShaderFilter(new BrightShit());
	public static var directionalBlur:ShaderFilter = new ShaderFilter(new DirectionalBlur());
	public static var scanlineShit:ShaderFilter = new ShaderFilter(new Scanline());

	public static function setBrightness(brightness:Float):Void
	{
		if (Highscore.nothing)
		{
			brightness = 0.0;
			// EL PEPE
		}

		brightShader.shader.data.brightness.value = [brightness];
	}

	public static function setContrast(contrast:Float):Void
	{
		if (Highscore.nothing)
		{
			contrast = 1.0;
		}

		brightShader.shader.data.contrast.value = [contrast];
	}

	public static function setChrome(chromeOffset:Float):Void
	{
		chromaticAberration.shader.data.rOffset.value = [chromeOffset];
		chromaticAberration.shader.data.gOffset.value = [0.0];
		chromaticAberration.shader.data.bOffset.value = [chromeOffset * -1];
	}

	// lol, no vec4

	public static function setLines(scale:Float):Void
	{
		scanlineShit.shader.data.scale.value = [scale];
	}

	//;-;

	public static function setStrength(strengthX:Float, strengthY:Float):Void
	{
		mosaic.shader.data.uBlocksize.value[0] = strengthX;
		mosaic.shader.data.uBlocksize.value[1] = strengthY;
	}

	//blood shaders
}