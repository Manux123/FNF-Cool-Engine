package funkin.data;

import haxe.Json;
import sys.FileSystem;
import sys.io.File;

/**
 * MetaData — Metadata por canción
 *
 * Archivo: assets/songs/{songName}/meta.json
 *
 * {
 *   "ui":           "default",    // script de UI  (null = global)
 *   "noteSkin":     "arrows",     // noteskin       (null = global)
 *   "hideCombo":    false,
 *   "hideRatings":  false,
 *   "hudVisible":   true
 * }
 */
typedef SongMetaData =
{
	@:optional var ui:Null<String>;
	@:optional var noteSkin:Null<String>;
	@:optional var overrideGlobal:Null<Bool>;
	@:optional var hideCombo:Null<Bool>;
	@:optional var hideRatings:Null<Bool>;
	@:optional var hudVisible:Null<Bool>;
}

class MetaData
{
	// ── Valores resueltos (meta > global > hardcoded) ────────────────────────
	public var ui:String              = 'default';
	public var noteSkin:String        = 'default';
	public var hideCombo:Bool         = false;
	public var hideRatings:Bool       = false;
	public var hudVisible:Bool        = true;

	/** Raw leído del JSON, útil para re-guardar sin perder campos */
	public var raw:SongMetaData;

	public function new() {}

	// ── Carga ────────────────────────────────────────────────────────────────

	public static function load(songName:String):MetaData
	{
		var meta   = new MetaData();
		var global = GlobalConfig.instance;

		var path = 'assets/songs/${songName.toLowerCase()}/meta.json';
		var rawData:SongMetaData = null;

		if (FileSystem.exists(path))
		{
			try
			{
				rawData    = cast Json.parse(File.getContent(path));
				meta.raw   = rawData;
				trace('[MetaData] Cargado: $path');
			}
			catch (e) { trace('[MetaData] Error al parsear meta.json de "$songName": $e'); }
		}
		else
		{
			trace('[MetaData] Sin meta.json para "$songName", usando GlobalConfig');
		}

		// Resolución con prioridad: meta > global > hardcoded
		meta.ui          = resolveStr(rawData?.ui,       global.ui,       'default');
		meta.noteSkin    = resolveStr(rawData?.noteSkin, global.noteSkin, 'default');
		meta.hideCombo   = resolveBool(rawData?.hideCombo,   false);
		meta.hideRatings = resolveBool(rawData?.hideRatings, false);
		meta.hudVisible  = resolveBool(rawData?.hudVisible,  true);

		trace('[MetaData] Resuelto — ui="${meta.ui}" noteSkin="${meta.noteSkin}"');
		return meta;
	}

	// ── Guardado ─────────────────────────────────────────────────────────────

	/**
	 * Guarda los valores actuales como meta.json en la carpeta de la canción.
	 * Crea el directorio si no existe.
	 */
	public static function save(songName:String, ui:String, noteSkin:String,
	                             ?hideCombo:Bool = false,
	                             ?hideRatings:Bool = false,
	                             ?hudVisible:Bool = true):Void
	{
		#if sys
		try
		{
			var dir = 'assets/songs/${songName.toLowerCase()}';
			if (!FileSystem.exists(dir))
				FileSystem.createDirectory(dir);

			var data:SongMetaData = {
				ui:           (ui       != null && ui       != '') ? ui       : null,
				noteSkin:     (noteSkin != null && noteSkin != '') ? noteSkin : null,
				hideCombo:    hideCombo,
				hideRatings:  hideRatings,
				hudVisible:   hudVisible
			};

			File.saveContent('$dir/meta.json', Json.stringify(data, null, '\t'));
			trace('[MetaData] Guardado: $dir/meta.json');
		}
		catch (e) { trace('[MetaData] Error al guardar meta.json: $e'); }
		#end
	}

	// ── Helpers ──────────────────────────────────────────────────────────────

	static inline function resolveStr(metaVal:Null<String>, globalVal:Null<String>, fallback:String):String
	{
		if (metaVal  != null && metaVal.length  > 0) return metaVal;
		if (globalVal != null && globalVal.length > 0) return globalVal;
		return fallback;
	}

	static inline function resolveBool(metaVal:Null<Bool>, fallback:Bool):Bool
		return (metaVal != null) ? metaVal : fallback;
}
