package shaders;

import funkin.gameplay.objects.hud.Highscore;
import openfl.Lib;
import openfl.display.Shader;
import openfl.display.ShaderParameter;
import openfl.filters.ShaderFilter;

/**
 * ShadersHandler — Wrapper de shaders OpenFL legacy.
 *
 * IMPORTANTE: Los ShaderFilter NO se crean como static vars de clase porque
 * en ese momento el contexto OpenGL puede no estar listo, causando
 * "Invalid field:X" al acceder a ShaderData por primera vez.
 * Se usa lazy initialization: cada getter crea la instancia la primera vez.
 */
class ShadersHandler
{
	// ─── Lazy instances ───────────────────────────────────────────────────────

	static var _chromaticAberration:ShaderFilter;
	static var _mosaic:ShaderFilter;
	static var _brightShader:ShaderFilter;
	static var _directionalBlur:ShaderFilter;
	static var _scanlineShit:ShaderFilter;

	public static var chromaticAberration(get, never):ShaderFilter;
	public static var mosaic(get, never):ShaderFilter;
	public static var brightShader(get, never):ShaderFilter;
	public static var directionalBlur(get, never):ShaderFilter;
	public static var scanlineShit(get, never):ShaderFilter;

	static function get_chromaticAberration():ShaderFilter
	{
		if (_chromaticAberration == null) _chromaticAberration = new ShaderFilter(new ChromaticAberration());
		return _chromaticAberration;
	}
	static function get_mosaic():ShaderFilter
	{
		if (_mosaic == null) _mosaic = new ShaderFilter(new MosaicShader());
		return _mosaic;
	}
	static function get_brightShader():ShaderFilter
	{
		if (_brightShader == null) _brightShader = new ShaderFilter(new BrightShit());
		return _brightShader;
	}
	static function get_directionalBlur():ShaderFilter
	{
		if (_directionalBlur == null) _directionalBlur = new ShaderFilter(new DirectionalBlur());
		return _directionalBlur;
	}
	static function get_scanlineShit():ShaderFilter
	{
		if (_scanlineShit == null) _scanlineShit = new ShaderFilter(new Scanline());
		return _scanlineShit;
	}

	// ─── API ──────────────────────────────────────────────────────────────────

	public static function setBrightness(brightness:Float):Void
	{
		if (Highscore.nothing) brightness = 0.0; // EL PEPE
		_safeSet(brightShader.shader.data, 'brightness', [brightness]);
	}

	public static function setContrast(contrast:Float):Void
	{
		if (Highscore.nothing) contrast = 1.0;
		_safeSet(brightShader.shader.data, 'contrast', [contrast]);
	}

	public static function setChrome(chromeOffset:Float):Void
	{
		_safeSet(chromaticAberration.shader.data, 'rOffset', [chromeOffset]);
		_safeSet(chromaticAberration.shader.data, 'gOffset', [0.0]);
		_safeSet(chromaticAberration.shader.data, 'bOffset', [chromeOffset * -1]);
	}

	// lol, no vec4

	public static function setLines(scale:Float):Void
	{
		_safeSet(scanlineShit.shader.data, 'scale', [scale]);
	}

	//;-;

	public static function setStrength(strengthX:Float, strengthY:Float):Void
	{
		var data = mosaic.shader.data;
		var param:Dynamic = null;
		try { param = Reflect.field(data, 'uBlocksize'); } catch(_) { return; }
		if (param == null) return;
		try
		{
			if (param.value == null || param.value.length < 2)
				param.value = [strengthX, strengthY];
			else { param.value[0] = strengthX; param.value[1] = strengthY; }
		}
		catch(_) {}
	}

	// ─── Helper ───────────────────────────────────────────────────────────────

	/**
	 * Escribe en un ShaderParameter de forma segura.
	 * ShaderData.__get lanza "Invalid field:X" si el uniform no está registrado
	 * todavía → el try-catch de Reflect.field está SEPARADO del de .value.
	 */
	static function _safeSet(data:Dynamic, paramName:String, val:Array<Dynamic>):Void
	{
		var param:Dynamic = null;
		try { param = Reflect.field(data, paramName); } catch(_) { return; }
		if (param == null) return;
		try { cast(param, ShaderParameter<Dynamic>).value = val; } catch(_) {}
	}

	//blood shaders
}
