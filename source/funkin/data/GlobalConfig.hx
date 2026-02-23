package funkin.data;

import haxe.Json;
import sys.FileSystem;
import sys.io.File;
import mods.ModManager;

/**
 * GlobalConfig — Configuración global de UI y noteskin.
 *
 * Archivo: assets/data/config/global.json
 *
 * Ejemplo de global.json:
 * {
 *   "ui":          "default",    // script de UI por defecto
 *   "noteSkin":    "arrows",     // noteskin por defecto
 *   "healthColors": ["#FF0000", "#66FF33"]
 * }
 *
 * Jerarquía de prioridad al resolver:
 *   meta.json de song  >  global.json  >  valores hardcoded
 */
class GlobalConfig
{
	// ─── Singleton ──────────────────────────────────────────────────────────────
	public static var instance(get, null):GlobalConfig;
	private static var _instance:GlobalConfig;

	static function get_instance():GlobalConfig
	{
		if (_instance == null)
			_instance = load();
		return _instance;
	}

	/** Fuerza una recarga desde disco (útil si el usuario cambia opciones en runtime) */
	public static function reload():Void
	{
		_instance = load();
	}

	// ─── Propiedades ────────────────────────────────────────────────────────────

	/** Nombre del script de UI en assets/ui/{ui}/script.hx */
	public var ui:String = 'default';

	/** Nombre del noteskin en assets/skins/{noteSkin}/skin.json */
	public var noteSkin:String = 'default';

	/** Nombre del splash en assets/splashes/{noteSplash}/splash.json */
	public var noteSplash:String = 'Default';

	/** Colores de la health bar [izq, der] en hex */
	public var healthColors:Null<Array<String>> = null;

	// ─── Carga ──────────────────────────────────────────────────────────────────

	function new() {}

	static function load():GlobalConfig
	{
		var cfg = new GlobalConfig();

		// Prioridad: mod activo → assets base
		var path:String = null;
		#if sys
		final modPath = ModManager.resolveInMod('data/config/global.json');
		if (modPath != null) path = modPath;
		else
		{
			final basePath = 'assets/data/config/global.json';
			if (FileSystem.exists(basePath)) path = basePath;
		}
		#else
		path = 'assets/data/config/global.json';
		#end

		if (path == null)
		{
			trace('[GlobalConfig] No existe global.json, usando defaults');
			return cfg;
		}

		try
		{
			var raw:Dynamic = Json.parse(File.getContent(path));

			if (raw.ui != null)          cfg.ui         = Std.string(raw.ui);
			if (raw.noteSkin != null)    cfg.noteSkin   = Std.string(raw.noteSkin);
			if (raw.noteSplash != null)  cfg.noteSplash = Std.string(raw.noteSplash);
			if (raw.healthColors != null) cfg.healthColors = cast raw.healthColors;

			trace('[GlobalConfig] Cargado — ui="${cfg.ui}" noteSkin="${cfg.noteSkin}" noteSplash="${cfg.noteSplash}"');
		}
		catch (e)
		{
			trace('[GlobalConfig] Error al parsear global.json: ${e}');
		}

		return cfg;
	}

	// ─── Save ───────────────────────────────────────────────────────────────────

	/** Guarda la configuración actual a disco */
	public function save():Void
	{
		var path = 'assets/data/config/global.json';
		try
		{
			var data = {
				ui:           ui,
				noteSkin:     noteSkin,
				noteSplash:   noteSplash,
				healthColors: healthColors
			};
			File.saveContent(path, Json.stringify(data, null, '\t'));
			trace('[GlobalConfig] Guardado en $path');
		}
		catch (e)
		{
			trace('[GlobalConfig] Error al guardar: ${e}');
		}
	}
}
