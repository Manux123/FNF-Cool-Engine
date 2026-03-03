package shaders;

// STOLEN FROM HAXEFLIXEL DEMO LOL
import flixel.system.FlxAssets.FlxShader;
import openfl.display.ShaderParameter;

enum WiggleEffectType
{
	DREAMY;
	WAVY;
	HEAT_WAVE_HORIZONTAL;
	HEAT_WAVE_VERTICAL;
	FLAG;
}

class WiggleEffect
{
	public var shader(default, null):WiggleShader = new WiggleShader();
	public var effectType(default, set):WiggleEffectType = DREAMY;
	public var waveSpeed(default, set):Float = 0;
	public var waveFrequency(default, set):Float = 0;
	public var waveAmplitude(default, set):Float = 0;

	public function new():Void
	{
		// Uniforms are initialized in WiggleShader.new() after super().
		// Do NOT access shader.uXxx here — ShaderData.__get throws
		// "Invalid field:X" if OpenGL hasn't finished linking the program yet.
	}

	public function update(elapsed:Float):Void
	{
		_safeAdd(shader.uTime, elapsed, 0.0);
	}

	function set_effectType(v:WiggleEffectType):WiggleEffectType
	{
		effectType = v;
		_safeSet(shader.effectType, WiggleEffectType.getConstructors().indexOf(Std.string(v)));
		return v;
	}

	function set_waveSpeed(v:Float):Float
	{
		waveSpeed = v;
		_safeSet(shader.uSpeed, v);
		return v;
	}

	function set_waveFrequency(v:Float):Float
	{
		waveFrequency = v;
		_safeSet(shader.uFrequency, v);
		return v;
	}

	function set_waveAmplitude(v:Float):Float
	{
		waveAmplitude = v;
		_safeSet(shader.uWaveAmplitude, v);
		return v;
	}

	/** Writes a single value into a ShaderParameter safely. Never throws. */
	static inline function _safeSet(param:Dynamic, v:Dynamic):Void
	{
		try
		{
			if (param.value != null) param.value[0] = v;
			else                     param.value    = [v];
		}
		catch (_:Dynamic) {}
	}

	/**
	 * Adds `delta` to value[0] of a ShaderParameter.
	 * If value is null, initialises it to [fallback + delta].
	 */
	static inline function _safeAdd(param:Dynamic, delta:Float, fallback:Float):Void
	{
		try
		{
			if (param.value != null) param.value[0] = (param.value[0] : Float) + delta;
			else                     param.value    = [fallback + delta];
		}
		catch (_:Dynamic) {}
	}
}

class WiggleShader extends FlxShader
{
	@:glFragmentSource('
		#pragma header
		//uniform float tx, ty; // x,y waves phase
		uniform float uTime;
		
		const int EFFECT_TYPE_DREAMY = 0;
		const int EFFECT_TYPE_WAVY = 1;
		const int EFFECT_TYPE_HEAT_WAVE_HORIZONTAL = 2;
		const int EFFECT_TYPE_HEAT_WAVE_VERTICAL = 3;
		const int EFFECT_TYPE_FLAG = 4;
		
		uniform int effectType;
		
		/**
		 * How fast the waves move over time
		 */
		uniform float uSpeed;
		
		/**
		 * Number of waves over time
		 */
		uniform float uFrequency;
		
		/**
		 * How much the pixels are going to stretch over the waves
		 */
		uniform float uWaveAmplitude;

		vec2 sineWave(vec2 pt)
		{
			float x = 0.0;
			float y = 0.0;
			
			if (effectType == EFFECT_TYPE_DREAMY) 
			{
				float w = 1 / openfl_TextureSize.x;
				float h = 6 / openfl_TextureSize.y;

				pt.y = floor(pt.y / h) * h;
				float offsetX = sin(pt.y * uFrequency + uTime * uSpeed) * uWaveAmplitude;
                pt.x += offsetX;
			}
			else if (effectType == EFFECT_TYPE_WAVY) 
			{
				float offsetY = sin(pt.x * uFrequency + uTime * uSpeed) * uWaveAmplitude;
				pt.y += offsetY;
			}
			else if (effectType == EFFECT_TYPE_HEAT_WAVE_HORIZONTAL)
			{
				x = sin(pt.x * uFrequency + uTime * uSpeed) * uWaveAmplitude;
			}
			else if (effectType == EFFECT_TYPE_HEAT_WAVE_VERTICAL)
			{
				y = sin(pt.y * uFrequency + uTime * uSpeed) * uWaveAmplitude;
			}
			else if (effectType == EFFECT_TYPE_FLAG)
			{
				y = sin(pt.y * uFrequency + 10.0 * pt.x + uTime * uSpeed) * uWaveAmplitude;
				x = sin(pt.x * uFrequency + 5.0 * pt.y + uTime * uSpeed) * uWaveAmplitude;
			}
			
			return vec2(pt.x + x, pt.y + y);
		}

		void main()
		{
			vec2 uv = sineWave(openfl_TextureCoordv);
			gl_FragColor = texture2D(bitmap, uv);
		}')

	public function new()
	{
		super();
		// After super(), the GLSL is compiled and uniforms are registered
		// in ShaderData. Safe to initialise default values here.
		try { uTime.value        = [0.0]; } catch (_:Dynamic) {}
		try { effectType.value   = [0];   } catch (_:Dynamic) {}
		try { uSpeed.value       = [0.0]; } catch (_:Dynamic) {}
		try { uFrequency.value   = [0.0]; } catch (_:Dynamic) {}
		try { uWaveAmplitude.value = [0.0]; } catch (_:Dynamic) {}
	}
}
