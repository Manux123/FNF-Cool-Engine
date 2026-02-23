package extensions;

import extensions.InitAPI;
import openfl.Lib;
import flixel.FlxG;
import flixel.system.scaleModes.StageSizeScaleMode;
import flixel.system.scaleModes.BaseScaleMode;

/**
 * CppAPI — fachada de alto nivel sobre InitAPI y otras funciones nativas.
 *
 * Agrupa las llamadas nativas con una API más limpia y platform-safe.
 * Añade: dark mode, DPI awareness, y helpers de ventana.
 */
class CppAPI
{
	// ── Colores de ventana ────────────────────────────────────────────────────

	/**
	 * Cambia el color del borde de la ventana (DWM).
	 * No-op en macOS/Linux.
	 */
	public static inline function changeColor(r:Int, g:Int, b:Int):Void
		InitAPI.setWindowBorderColor(r, g, b);

	/**
	 * Cambia el color del título de la ventana.
	 * No-op en macOS/Linux.
	 */
	public static inline function changeCaptionColor(r:Int, g:Int, b:Int):Void
		InitAPI.setWindowCaptionColor(r, g, b);

	// ── Modo oscuro ───────────────────────────────────────────────────────────

	/**
	 * Activa el frame oscuro inmersivo del sistema.
	 * Disponible en Windows 10 1809+ y Windows 11.
	 */
	public static inline function enableDarkMode():Void
		InitAPI.setDarkMode(true);

	/** Desactiva el frame oscuro (vuelve al tema claro). */
	public static inline function disableDarkMode():Void
		InitAPI.setDarkMode(false);

	// ── DPI ───────────────────────────────────────────────────────────────────

	/**
	 * Registra el proceso como DPI-aware.
	 * Llamar ANTES de que se cree la ventana, idealmente en el static __init__.
	 * Ver InitAPI.setDPIAware() para detalles.
	 */
	public static inline function registerDPIAware():Void
		InitAPI.setDPIAware();

	// ── Helpers de ventana ────────────────────────────────────────────────────

	/** Devuelve el título actual de la ventana de lima. */
	public static var windowTitle(get, never):String;
	static inline function get_windowTitle():String
	{
		#if !html5
		return lime.app.Application.current?.window?.title ?? "";
		#else
		return "";
		#end
	}

	/** Cambia el título de la ventana en runtime. */
	public static function setWindowTitle(title:String):Void
	{
		#if !html5
		if (lime.app.Application.current?.window != null)
			lime.app.Application.current.window.title = title;
		#end
	}
}
