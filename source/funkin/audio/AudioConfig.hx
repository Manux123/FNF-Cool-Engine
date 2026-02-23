package funkin.audio;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

/**
 * AudioConfig — lee `alsoft.ini` en runtime y expone sus valores al juego.
 *
 * ─── ¿Por qué? ───────────────────────────────────────────────────────────────
 * OpenAL Soft carga `alsoft.ini` antes de inicializar el device, así que ya
 * ajusta period_size, frequency, etc. por su cuenta. Sin embargo, el juego
 * puede necesitar saber esos valores para:
 *   • ajustar el tamaño de los buffers de streaming (Vorbis/OGG) para que
 *     coincidan con period_size → evita underruns (glitches de audio).
 *   • mostrar la latencia calculada en el panel de debug.
 *   • forzar que el sample-rate de Flixel coincida con el de OpenAL.
 *
 * ─── Funcionamiento ──────────────────────────────────────────────────────────
 * 1. Busca alsoft.ini junto al ejecutable y en el directorio de trabajo.
 * 2. Parsea las secciones [general] y [decoder] con un parser INI mínimo.
 * 3. Expone los valores como propiedades estáticas tipadas.
 * 4. Si no encuentra el archivo usa valores por defecto seguros.
 *
 * @author  Cool Engine Team
 * @since   0.5.1
 */
class AudioConfig
{
	// ── Valores parseados (expuestos como read-only) ─────────────────────────

	/** Sample rate del device OpenAL. Default: 44100 */
	public static var frequency(default, null):Int  = 44100;

	/** Frames por período de hardware. Default: 512 */
	public static var periodSize(default, null):Int = 512;

	/** Número de períodos en el buffer de hardware. Default: 3 */
	public static var periods(default, null):Int    = 3;

	/** ¿Está habilitado HRTF? */
	public static var hrtf(default, null):Bool = false;

	/** Tipo de resampler configurado. */
	public static var resampler(default, null):String = "fast_bsinc24";

	/** Ajuste de volumen master (dB). */
	public static var volumeAdjust(default, null):Float = 0.0;

	// ── Valores derivados ────────────────────────────────────────────────────

	/**
	 * Latencia total en milisegundos: (periodSize * periods / frequency) * 1000.
	 * Útil para el debug overlay y para ajustar el offset de sincronía.
	 */
	public static var latencyMs(get, never):Float;
	static inline function get_latencyMs():Float
		return (periodSize * periods / frequency) * 1000.0;

	/**
	 * Tamaño de buffer OGG recomendado para streaming sin underruns.
	 * Usamos el doble del period_size para tener un margen cómodo.
	 * Redondeo a la siguiente potencia de 2 para compatibilidad con ALSA/WASAPI.
	 */
	public static var streamingBufferSize(get, never):Int;
	static function get_streamingBufferSize():Int
	{
		var target:Int = periodSize * 2;
		var pow:Int = 1;
		while (pow < target) pow <<= 1;
		return pow;
	}

	// ── Estado interno ────────────────────────────────────────────────────────

	/** true si el archivo fue encontrado y parseado con éxito. */
	public static var loaded(default, null):Bool = false;

	/** Ruta desde la que se cargó el archivo (o null si se usaron defaults). */
	public static var sourcePath(default, null):Null<String> = null;

	// ── API pública ───────────────────────────────────────────────────────────

	/**
	 * Carga y parsea alsoft.ini.
	 * Llamar UNA VEZ en Main.setupGame() antes de inicializar el audio.
	 *
	 * @param customPath  Ruta alternativa. Si es null, busca en ubicaciones
	 *                    estándar (junto al exe, directorio de trabajo).
	 */
	public static function load(?customPath:String):Void
	{
		#if sys
		var path:Null<String> = customPath;

		if (path == null)
		{
			// Buscar en orden de prioridad
			final candidates:Array<String> = [
				"alsoft.ini",
				"assets/alsoft.ini",
				#if windows
				Sys.getEnv("APPDATA") + "/alsoft.ini",
				#end
				#if (linux || mac)
				(Sys.getEnv("HOME") ?? "") + "/.alsoftrc",
				"/etc/openal/alsoft.conf",
				#end
			];
			for (c in candidates)
			{
				if (c != null && FileSystem.exists(c))
				{
					path = c;
					break;
				}
			}
		}

		if (path == null)
		{
			trace('[AudioConfig] alsoft.ini no encontrado — usando defaults.');
			_applyDefaults();
			return;
		}

		try
		{
			_parseIni(File.getContent(path));
			sourcePath = path;
			loaded     = true;
			trace('[AudioConfig] Load since $path '
				+ '| ${frequency}Hz  period=${periodSize}×${periods}  latency=${latencyMs}ms');
		}
		catch (e:Dynamic)
		{
			trace('[AudioConfig] Error parseando $path: $e — usando defaults.');
			_applyDefaults();
		}
		#else
		// En HTML5/mobile no hay acceso al sistema de archivos; usar defaults.
		_applyDefaults();
		#end
	}

	/**
	 * Aplica el sample-rate a FlxG.sound si difiere del actual.
	 * Llamar después de load() y después de que FlxGame esté en escena.
	 */
	public static function applyToFlixel():Void
	{
		#if FLX_SOUND_SYSTEM
		// FlxSound no expone el sample-rate directamente, pero podemos
		// forzar el context de OpenAL a través del device si es necesario.
		// Lo que sí podemos hacer es ajustar el drawFramerate para compensar
		// cualquier drift si la frecuencia real difiere de 44100.
		// Por ahora simplemente logeamos — extensible en el futuro.
		trace('[AudioConfig] Flixel audio @ ${frequency}Hz  buffer=${streamingBufferSize} samples');
		#end
	}

	/** Devuelve un resumen legible para el debug overlay. */
	public static function debugString():String
	{
		return '${frequency}Hz | period=${periodSize}×${periods} | ${latencyMs}ms | buf=${streamingBufferSize}';
	}

	// ── Internals ─────────────────────────────────────────────────────────────

	static function _applyDefaults():Void
	{
		frequency    = 44100;
		periodSize   = 512;
		periods      = 3;
		hrtf         = false;
		resampler    = "fast_bsinc24";
		volumeAdjust = 0.0;
		loaded       = false;
	}

	/**
	 * Parser INI mínimo: soporta secciones [name], key=value y ; / # comentarios.
	 * Ignora líneas vacías y espacios alrededor de = y de los valores.
	 */
	static function _parseIni(content:String):Void
	{
		var currentSection:String = "";

		for (rawLine in content.split("\n"))
		{
			var line:String = rawLine.trim();

			// Ignorar vacías y comentarios
			if (line.length == 0 || line.charAt(0) == ";" || line.charAt(0) == "#")
				continue;

			// Sección
			if (line.charAt(0) == "[")
			{
				final end:Int = line.indexOf("]");
				if (end > 1) currentSection = line.substring(1, end).trim().toLowerCase();
				continue;
			}

			// key = value
			final eq:Int = line.indexOf("=");
			if (eq < 1) continue;

			// Strip inline comments after the value
			var rawVal:String = line.substring(eq + 1);
			final semiPos:Int = rawVal.indexOf(";");
			if (semiPos >= 0) rawVal = rawVal.substring(0, semiPos);
			final hashPos:Int = rawVal.indexOf("#");
			if (hashPos >= 0) rawVal = rawVal.substring(0, hashPos);

			final key:String = line.substring(0, eq).trim().toLowerCase();
			final val:String = rawVal.trim();

			_applyKeyValue(currentSection, key, val);
		}
	}

	static function _applyKeyValue(section:String, key:String, val:String):Void
	{
		switch (section)
		{
			case "general":
				switch (key)
				{
					case "frequency":
						final f:Int = Std.parseInt(val);
						if (f > 0) frequency = f;

					case "period_size":
						final p:Int = Std.parseInt(val);
						if (p > 0) periodSize = p;

					case "periods":
						final p:Int = Std.parseInt(val);
						if (p > 0) periods = p;

					case "hrtf":
						hrtf = (val == "true" || val == "1");

					case "resampler":
						if (val.length > 0) resampler = val;

					case "volume-adjust":
						volumeAdjust = Std.parseFloat(val);
				}

			case "decoder":
				// Reservado para futura integración (hq-mode, distance-comp…)
				// No se necesitan en gameplay estándar pero quedan disponibles.
		}
	}
}
