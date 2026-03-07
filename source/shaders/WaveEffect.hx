package shaders;

import flixel.system.FlxAssets.FlxShader;

class WaveEffect extends FlxShader
{
	@:glFragmentSource('
		#pragma header

		uniform float uTime;
		uniform float uAmplitude;
		uniform float uFrequency;
		uniform float uSpeed;

		void main()
		{
			vec2 uv = openfl_TextureCoordv;

			// Efecto de ola horizontal
			uv.x += sin(uv.y * uFrequency + uTime * uSpeed) * uAmplitude;

			vec4 color = flixel_texture2D(bitmap, uv);
			gl_FragColor = color;
		}
	')

	public var time(default, set):Float = 0.0;
	public var amplitude(default, set):Float = 0.01;
	public var frequency(default, set):Float = 10.0;
	public var speed(default, set):Float = 2.0;

	public function new()
	{
		super();
		try { uTime.value      = [0.0];  } catch (_:Dynamic) {}
		try { uAmplitude.value = [0.01]; } catch (_:Dynamic) {}
		try { uFrequency.value = [10.0]; } catch (_:Dynamic) {}
		try { uSpeed.value     = [2.0];  } catch (_:Dynamic) {}
	}

	public function update(elapsed:Float):Void
	{
		time += elapsed;
	}

	function set_time(v:Float):Float
	{
		time = v;
		try { uTime.value = [v]; } catch (_:Dynamic) {}
		return v;
	}

	function set_amplitude(v:Float):Float
	{
		amplitude = v;
		try { uAmplitude.value = [v]; } catch (_:Dynamic) {}
		return v;
	}

	function set_frequency(v:Float):Float
	{
		frequency = v;
		try { uFrequency.value = [v]; } catch (_:Dynamic) {}
		return v;
	}

	function set_speed(v:Float):Float
	{
		speed = v;
		try { uSpeed.value = [v]; } catch (_:Dynamic) {}
		return v;
	}
}
