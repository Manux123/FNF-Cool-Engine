package;

/**
	* CrashHandler — Global uncaught error handler for Cool Engine.

	* Functionality:
	* 1. Initializes only once from Main.setupGame().
	* 2. Listens for OpenFL's `UncaughtErrorEvent` for runtime errors.
	* 3. Also installs a hook on `haxe.Exception` (neko/cpp) to catch uncaught throws before OpenFL receives them.
	* 4. Saves the crash log to ./crash/ with a timestamp.
	* 5. Displays a dialog to the user and closes the game cleanly.

	* Usage:
	* // In Main.hx, inside setupGame():
	* CrashHandler.init();

	* To report an error manually from anywhere in the project:
	* CrashHandler.report(error, "optional context");
	*
	* @author Cool Engine Team
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
#if desktop
import data.Discord.DiscordClient;
#end

using StringTools;

class CrashHandler
{
	// ── Constantes ────────────────────────────────────────────────────────────

	/** Carpeta donde se guardan los logs de crash. */
	private static inline final CRASH_DIR:String = "./crash/";

	/** Prefijo del archivo de log. */
	private static inline final LOG_PREFIX:String = "CoolEngine_";

	/** URL a donde se reportan los crashes. */
	private static inline final REPORT_URL:String = "https://github.com/Manux123/FNF-Cool-Engine/issues";

	// ── Estado ────────────────────────────────────────────────────────────────

	/** Evita que se procesen múltiples crashes en cascada. */
	private static var _handling:Bool = false;

	/** Indica si el handler ya fue inicializado. */
	private static var _initialized:Bool = false;

	// =========================================================================
	//  API PÚBLICA
	// =========================================================================

	/**
	 * Inicializa el gestor de crashes.
	 * Llamar UNA sola vez desde Main, antes de crear el FlxGame.
	 */
	public static function init():Void
	{
		if (_initialized)
			return;
		_initialized = true;

		// Hook de OpenFL — captura excepciones lanzadas dentro del event loop.
		Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onUncaughtError);

		trace("[CrashHandler] Inicializado correctamente.");
	}

	/**
	 * Reporta un error manualmente desde cualquier parte del proyecto.
	 * Útil para bloques try/catch donde se quiere loguear pero no interrumpir.
	 *
	 * @param error    El error capturado (String, Exception, Dynamic…).
	 * @param context  Descripción opcional de dónde ocurrió el error.
	 * @param fatal    Si es true, cierra el juego después del reporte.
	 */
	public static function report(error:Dynamic, ?context:String, fatal:Bool = false):Void
	{
		var stack = CallStack.exceptionStack(true);
		var callStack = CallStack.callStack();
		var message = buildMessage(error, context, stack.length > 0 ? stack : callStack);

		// Siempre loguear en consola.
		Sys.println(message);

		// Guardar en disco.
		var path = saveCrashLog(message);
		if (path != null)
			Sys.println('[CrashHandler] Log guardado en: ${Path.normalize(path)}');

		if (fatal)
		{
			showDialogAndExit(message);
		}
		else
		{
			// En modo no-fatal solo mostramos el trace; el juego sigue.
			#if debug
			lime.app.Application.current.window.alert('[NON-FATAL ERROR]\n\n' + message, "Cool Engine — Error");
			#end
		}
	}

	// =========================================================================
	//  INTERNOS
	// =========================================================================

	/** Callback de OpenFL para errores no capturados. */
	private static function onUncaughtError(e:UncaughtErrorEvent):Void
	{
		// Prevenir procesamiento doble.
		if (_handling)
			return;
		_handling = true;

		var stack = CallStack.exceptionStack(true);
		var message = buildMessage(e.error, null, stack);

		Sys.println(message);

		var path = saveCrashLog(message);
		if (path != null)
			Sys.println('[CrashHandler] Log guardado en: ${Path.normalize(path)}');

		showDialogAndExit(message);
	}

	/**
	 * Construye el mensaje de error completo con call stack formateado.
	 */
	private static function buildMessage(error:Dynamic, ?context:String, stack:Array<StackItem>):String
	{
		var lines:Array<String> = [];

		lines.push("=== COOL ENGINE — CRASH REPORT ===");
		lines.push("Fecha     : " + Date.now().toString());
		lines.push("Versión   : 0.4.1B");
		lines.push("Plataforma: " + getSystemInfo());
		lines.push("");

		if (context != null && context.length > 0)
		{
			lines.push("Contexto: " + context);
			lines.push("");
		}

		lines.push("Error: " + Std.string(error));
		lines.push("");

		// ── Call Stack ────────────────────────────────────────────────────────
		if (stack.length > 0)
		{
			lines.push("--- Call Stack ---");
			for (item in stack)
			{
				switch (item)
				{
					case FilePos(s, file, line, column):
						var col = column != null ? ':${column}' : '';
						lines.push('  $file : line $line$col');
					case CFunction:
						lines.push("  [C Function]");
					case Module(m):
						lines.push('  [Module: $m]');
					case Method(classname, method):
						lines.push('  $classname.$method()');
					case LocalFunction(v):
						lines.push('  [Local function #$v]');
					default:
						lines.push("  " + Std.string(item));
				}
			}
		}
		else
		{
			lines.push("--- Call Stack no disponible ---");
		}

		lines.push("");
		lines.push("Por favor reporta este error en:");
		lines.push(REPORT_URL);
		lines.push("");
		lines.push("==================================");

		return lines.join("\n");
	}

	/**
	 * Guarda el log en disco y devuelve la ruta del archivo creado.
	 * Devuelve null si no se pudo guardar.
	 */
	private static function saveCrashLog(content:String):Null<String>
	{
		#if sys
		try
		{
			if (!FileSystem.exists(CRASH_DIR))
				FileSystem.createDirectory(CRASH_DIR);

			// Timestamp seguro para nombres de archivo.
			var ts = Date.now().toString().replace(" ", "_").replace(":", "-");
			var path = CRASH_DIR + LOG_PREFIX + ts + ".txt";

			File.saveContent(path, content + "\n");
			return path;
		}
		catch (e:Dynamic)
		{
			Sys.println("[CrashHandler] No se pudo guardar el log: " + e);
		}
		#end
		return null;
	}

	/**
	 * Muestra el diálogo de error y cierra la aplicación limpiamente.
	 */
	private static function showDialogAndExit(message:String):Void
	{
		// Apagar Discord RPC antes de cerrar.
		#if (desktop && DISCORD_ALLOWED)
		try
		{
			DiscordClient.shutdown();
		}
		catch (_)
		{
		}
		#end

		// Mostrar diálogo nativo.
		try
		{
			lime.app.Application.current.window.alert(message, "Cool Engine — Error Fatal");
		}
		catch (_)
		{
		}

		Sys.exit(1);
	}

	/**
	 * Información del sistema operativo para el log.
	 */
	private static function getSystemInfo():String
	{
		#if sys
		return Sys.systemName();
		#elseif windows
		return "Windows";
		#elseif linux
		return "Linux";
		#elseif mac
		return "macOS";
		#elseif html5
		return "HTML5";
		#else
		return "Unknown";
		#end
	}
}
