package;

/**
 * CrashHandler — Gestor de crashes para Cool Engine.
 *
 * ── Por qué el handler anterior no servía ────────────────────────────────────
 *
 *  El stack trace que llegó es de tipo "Called from FlxDrawQuadsItem::render"
 *  — eso es una NULL OBJECT REFERENCE en C++. OpenFL's UncaughtErrorEvent
 *  NO captura ese tipo de error; solo captura excepciones lanzadas con `throw`.
 *  Los crashes de null ptr en C++ (hxcpp) requieren un hook diferente:
 *
 *    untyped __global__.__hxcpp_set_critical_error_handler(fn)
 *
 *  Sin ese hook, el juego se cierra silenciosamente sin mostrar nada.
 *
 * ── Qué hace este handler ────────────────────────────────────────────────────
 *
 *  1. UncaughtErrorEvent   → errores Haxe/OpenFL normales (throw, etc.)
 *  2. hxcpp critical hook  → null object reference, stack overflow, etc. (CPP only)
 *  3. Guarda un log en ./crash/CoolEngine_<timestamp>.txt
 *  4. Muestra un diálogo nativo con el error + ruta del log
 *  5. Cierra el juego limpiamente
 *
 * ── Uso ──────────────────────────────────────────────────────────────────────
 *
 *  CrashHandler.init();   // UNA sola vez en Main, ANTES de createGame()
 *
 * @author Cool Engine Team (basado en V-Slice CrashHandler)
 */

import openfl.Lib;
import openfl.events.UncaughtErrorEvent;
import haxe.CallStack;
import haxe.CallStack.StackItem;
import haxe.io.Path;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

#if (desktop && DISCORD_ALLOWED)
import data.Discord.DiscordClient;
#end

using StringTools;

class CrashHandler
{
	// ── Config ────────────────────────────────────────────────────────────────

	private static inline final CRASH_DIR  : String = "./crash/";
	private static inline final LOG_PREFIX : String = "CoolEngine_";
	private static inline final REPORT_URL : String = "https://github.com/Manux123/FNF-Cool-Engine/issues";

	private static inline final ENGINE_VERSION : String = "0.4.1B";

	// ── Estado interno ────────────────────────────────────────────────────────

	/** Evita loops de crash (crash dentro del crash handler). */
	private static var _handling : Bool = false;

	/** Inicializado una sola vez. */
	private static var _initialized : Bool = false;

	// =========================================================================
	//  API PÚBLICA
	// =========================================================================

	/**
	 * Inicializa los dos hooks de error.
	 * Llamar UNA sola vez desde Main.hx, ANTES de createGame().
	 */
	public static function init() : Void
	{
		if (_initialized) return;
		_initialized = true;

		// ── Hook 1: UncaughtErrorEvent (Haxe throws, OpenFL errors) ──────────
		Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(
			UncaughtErrorEvent.UNCAUGHT_ERROR,
			_onUncaughtError
		);

		// ── Hook 2: C++ critical errors (null object reference, etc.) ─────────
		// ESTE es el que faltaba. Sin él, los crashes de C++ (como
		// FlxDrawQuadsItem::render null bitmap) no son capturados.
		#if cpp
		untyped __global__.__hxcpp_set_critical_error_handler(_onCriticalError);
		#end

		trace("[CrashHandler] Inicializado (UncaughtError + C++ critical hook).");
	}

	/**
	 * Reporta un error manualmente (sin cerrar el juego por defecto).
	 * Útil en bloques try/catch donde se quiere loguear pero continuar.
	 *
	 * @param error    El error capturado.
	 * @param context  Descripción de dónde ocurrió.
	 * @param fatal    Si true, cierra el juego después de mostrar el diálogo.
	 */
	public static function report(error:Dynamic, ?context:String, fatal:Bool = false) : Void
	{
		var stack   = CallStack.exceptionStack(true);
		var message = _buildReport(Std.string(error), context, stack.length > 0 ? stack : CallStack.callStack());

		#if sys
		Sys.println(message);
		var path = _saveLog(message);
		if (path != null) Sys.println('[CrashHandler] Log → ${Path.normalize(path)}');
		#end

		if (fatal)
			_showAndExit(message);
		#if debug
		else
			_showDialog('[NON-FATAL]\n\n' + message, "Cool Engine — Error (no fatal)");
		#end
	}

	// =========================================================================
	//  HOOKS INTERNOS
	// =========================================================================

	/** Callback de OpenFL para errores lanzados con `throw`. */
	private static function _onUncaughtError(e:UncaughtErrorEvent) : Void
	{
		if (_handling) return;
		_handling = true;

		var stack   = CallStack.exceptionStack(true);
		var message = _buildReport(Std.string(e.error), "UncaughtErrorEvent", stack);

		#if sys
		Sys.println(message);
		_saveLog(message);
		#end

		_showAndExit(message);
	}

	/**
	 * Callback de hxcpp para NULL OBJECT REFERENCE, stack overflow, etc.
	 *
	 * IMPORTANTE: esta función es llamada desde C++ en un contexto muy bajo.
	 * NO puede lanzar excepciones ni acceder a estructuras OpenFL/Flixel que
	 * puedan estar corrompidas. Solo puede:
	 *   - Escribir a disco (sys.io.File)
	 *   - Mostrar un diálogo nativo (lime.app.Application.current.window.alert)
	 *   - Llamar a Sys.exit()
	 */
	#if cpp
	private static function _onCriticalError(message:String) : Void
	{
		if (_handling) return;
		_handling = true;

		// El call stack de hxcpp ya viene en `message` (formato texto).
		// Añadimos contexto adicional sin tocar estructuras Flixel/OpenFL.
		var report = _buildCriticalReport(message);

		#if sys
		try { Sys.println(report); } catch (_) {}
		_saveLog(report);
		#end

		// Mostrar diálogo. lime.app.Application es más robusto que FlxG aquí.
		try
		{
			lime.app.Application.current.window.alert(
				_truncate(report, 3000),
				"Cool Engine — Fatal Error"
			);
		}
		catch (_) {}

		Sys.exit(1);
	}
	#end

	// =========================================================================
	//  CONSTRUCCIÓN DEL REPORTE
	// =========================================================================

	private static function _buildReport(error:String, ?context:String, stack:Array<StackItem>) : String
	{
		var sb = new StringBuf();
		_header(sb);

		if (context != null && context.length > 0)
		{
			sb.add('Contexto : $context\n\n');
		}

		sb.add('Error    : $error\n\n');

		_appendStack(sb, stack);
		_footer(sb);

		return sb.toString();
	}

	#if cpp
	private static function _buildCriticalReport(cppMessage:String) : String
	{
		var sb = new StringBuf();
		_header(sb);
		sb.add('Tipo     : C++ Critical Error (null object reference / stack overflow)\n\n');
		sb.add('Mensaje  : $cppMessage\n\n');

		// Intentar añadir el state actual (puede fallar si Flixel está corrupto)
		try
		{
			if (flixel.FlxG.game != null && flixel.FlxG.state != null)
			{
				var cls = Type.getClass(flixel.FlxG.state);
				if (cls != null)
					sb.add('State    : ${Type.getClassName(cls)}\n\n');
			}
		}
		catch (_) {}

		sb.add('NOTA: El stack trace de C++ está incluido en el mensaje de arriba.\n\n');
		_footer(sb);
		return sb.toString();
	}
	#end

	private static function _header(sb:StringBuf) : Void
	{
		sb.add("===========================================\n");
		sb.add("       COOL ENGINE — CRASH REPORT\n");
		sb.add("===========================================\n\n");
		sb.add('Fecha    : ${Date.now().toString()}\n');
		sb.add('Versión  : $ENGINE_VERSION\n');
		sb.add('Sistema  : ${_systemName()}\n');
		#if sys
		sb.add('Memoria  : ${_memMB()} MB usados\n');
		#end
		sb.add('\n--- Estado Flixel ---\n');
		try
		{
			if (flixel.FlxG.game != null && flixel.FlxG.state != null)
			{
				var cls = Type.getClass(flixel.FlxG.state);
				sb.add('State : ${cls != null ? Type.getClassName(cls) : "??"}\n');
			}
			else sb.add('State : (FlxG no disponible)\n');
		}
		catch (_) { sb.add('State : (error al leer)\n'); }
		sb.add('\n===========================================\n\n');
	}

	private static function _footer(sb:StringBuf) : Void
	{
		sb.add('\n===========================================\n');
		sb.add('Reporta este error en:\n');
		sb.add('$REPORT_URL\n');
		sb.add('===========================================\n');
	}

	private static function _appendStack(sb:StringBuf, stack:Array<StackItem>) : Void
	{
		if (stack == null || stack.length == 0)
		{
			sb.add("--- Call Stack no disponible ---\n");
			return;
		}

		sb.add("--- Call Stack ---\n");
		for (item in stack)
		{
			switch (item)
			{
				case FilePos(_, file, line, column):
					var col = (column != null) ? ':$column' : '';
					sb.add('  $file : $line$col\n');
				case CFunction:
					sb.add("  [C Function]\n");
				case Module(m):
					sb.add('  [Module: $m]\n');
				case Method(cls, method):
					sb.add('  $cls.$method()\n');
				case LocalFunction(v):
					sb.add('  [LocalFunction #$v]\n');
				default:
					sb.add('  ${Std.string(item)}\n');
			}
		}
	}

	// =========================================================================
	//  HELPERS
	// =========================================================================

	private static function _saveLog(content:String) : Null<String>
	{
		#if sys
		try
		{
			if (!FileSystem.exists(CRASH_DIR))
				FileSystem.createDirectory(CRASH_DIR);

			var ts   = Date.now().toString().replace(" ", "_").replace(":", "-");
			var path = CRASH_DIR + LOG_PREFIX + ts + ".txt";
			File.saveContent(path, content + "\n");
			return path;
		}
		catch (e:Dynamic)
		{
			try { Sys.println("[CrashHandler] No se pudo guardar el log: " + e); } catch (_) {}
		}
		#end
		return null;
	}

	private static function _showAndExit(message:String) : Void
	{
		// Apagar Discord antes de cerrar
		#if (desktop && DISCORD_ALLOWED)
		try { DiscordClient.shutdown(); } catch (_) {}
		#end

		_showDialog(_truncate(message, 3000), "Cool Engine — Error Fatal");

		#if sys
		Sys.exit(1);
		#end
	}

	private static function _showDialog(message:String, title:String) : Void
	{
		try
		{
			lime.app.Application.current.window.alert(message, title);
		}
		catch (e:Dynamic)
		{
			// Si lime falla (puede pasar en un crash de render), intentar con SDL nativo
			try { Sys.println("[CrashHandler] Dialog failed: " + e); } catch (_) {}
			#if sys
			// Último recurso: imprimir en consola
			try { Sys.println("=== FATAL ===\n" + message); } catch (_) {}
			#end
		}
	}

	/** Trunca strings muy largos para que quepan en el diálogo. */
	private static function _truncate(s:String, max:Int) : String
	{
		if (s.length <= max) return s;
		return s.substr(0, max) + "\n\n[... truncado. Ver archivo en ./crash/]";
	}

	private static function _systemName() : String
	{
		#if sys return Sys.systemName();
		#elseif windows return "Windows";
		#elseif linux return "Linux";
		#elseif mac return "macOS";
		#else return "Unknown"; #end
	}

	#if sys
	private static function _memMB() : String
	{
		try
		{
			#if cpp
			var bytes = cpp.vm.Gc.memInfo64(cpp.vm.Gc.MEM_INFO_USAGE);
			return Std.string(Math.round(bytes / 1024 / 1024));
			#else
			return Std.string(Math.round(openfl.system.System.totalMemory / 1024 / 1024));
			#end
		}
		catch (_) { return "??"; }
	}
	#end
}
