package funkin.data;

import haxe.Json;
import sys.FileSystem;
import sys.io.File;
import mods.ModManager;

/**
 * MetaData — Metadata por canción.
 *
 * Archivo: assets/songs/{songName}/meta.json
 *
 * Jerarquía de prioridad para noteSkin / noteSplash:
 *   meta.json  >  global.json  >  stage override  >  preferencia global del jugador
 *
 * Ejemplo completo de meta.json:
 * {
 *   "ui":           "default",
 *   "noteSkin":     "MyPixelSkin",   // skin para TODA la canción (override total)
 *   "noteSplash":   "Default",       // splash para TODA la canción
 *   "stageSkins": {                  // overrides por stage (si la canción cambia de stage)
 *     "school":     "DefaultPixel",
 *     "schoolEvil": "DefaultPixel",
 *     "stage":      "Default"
 *   },
 *   "hideCombo":    false,
 *   "hideRatings":  false,
 *   "hudVisible":   true,
 *   "introVideo":   "bopeebo-intro",
 *   "outroVideo":   "bopeebo-outro",
 *   "midSongVideo": false
 * }
 *
 * Si solo quieres que stage "school" use la skin pixel y los demás la global,
 * omite "noteSkin" y usa solo "stageSkins": { "school": "DefaultPixel" }.
 */
typedef SongMetaData =
{
	@:optional var ui:Null<String>;
	// ── Skins de notas ─────────────────────────────────────────────────────
	/** Skin de notas para toda la canción. Null → resuelve por stage o global. */
	@:optional var noteSkin:Null<String>;
	/** Splash de notas para toda la canción. Null → usa el global del jugador. */
	@:optional var noteSplash:Null<String>;
	/**
	 * Overrides de skin por nombre de stage.
	 * Solo se aplica si noteSkin es null (no hay override global de canción).
	 * Ejemplo: { "school": "DefaultPixel", "stage": "MyFancySkin" }
	 */
	@:optional var stageSkins:Null<Dynamic>;
	// ── HUD ────────────────────────────────────────────────────────────────
	@:optional var overrideGlobal:Null<Bool>;
	@:optional var hideCombo:Null<Bool>;
	@:optional var hideRatings:Null<Bool>;
	@:optional var hudVisible:Null<Bool>;
	// ── Video cutscenes ────────────────────────────────────────────────────
	@:optional var introVideo:Null<String>;
	@:optional var outroVideo:Null<String>;
	@:optional var midSongVideo:Null<Bool>;
}

class MetaData
{
	// ── Valores resueltos (meta > global > hardcoded) ────────────────────────
	public var ui:String = 'default';
	public var noteSkin:String = 'default';
	/** Splash de notas para toda la canción. Null = usa la preferencia global del jugador. */
	public var noteSplash:Null<String> = null;
	/**
	 * Mapa stage → skin leído del campo "stageSkins" del meta.json.
	 * Null si no hay overrides de stage en este meta.
	 * PlayState lo pasa a NoteSkinSystem.registerStageSkin() antes de generar notas.
	 */
	public var stageSkins:Null<Map<String, String>> = null;

	public var hideCombo:Bool = false;
	public var hideRatings:Bool = false;
	public var hudVisible:Bool = true;
	// ── Video cutscenes ────────────────────────────────────────────────────
	public var introVideo:Null<String> = null;
	public var outroVideo:Null<String> = null;
	public var midSongVideo:Bool = false;

	/** Raw leído del JSON, útil para re-guardar sin perder campos */
	public var raw:SongMetaData;

	public function new() {}

	// ── Carga ────────────────────────────────────────────────────────────────

	public static function load(songName:String):MetaData
	{
		var meta = new MetaData();
		var global = GlobalConfig.instance;

		// Buscar meta.json con prioridad: mod activo → assets base
		var path:String = null;
		#if sys
		final songKey = songName.toLowerCase();
		final modPath = ModManager.resolveInMod('songs/$songKey/meta.json');
		if (modPath != null) path = modPath;
		else
		{
			final basePath = 'assets/songs/$songKey/meta.json';
			if (FileSystem.exists(basePath)) path = basePath;
		}
		#else
		path = 'assets/songs/${songName.toLowerCase()}/meta.json';
		#end

		var rawData:SongMetaData = null;

		if (path != null && FileSystem.exists(path))
		{
			try
			{
				rawData = cast Json.parse(File.getContent(path));
				meta.raw = rawData;
				trace('[MetaData] Cargado: $path');
			}
			catch (e)
			{
				trace('[MetaData] Error al parsear meta.json de "$songName": $e');
			}
		}
		else
		{
			trace('[MetaData] Sin meta.json para "$songName", usando GlobalConfig');
		}

		// Resolución con prioridad: meta > global > hardcoded
		meta.ui        = resolveStr(rawData?.ui,       global.ui,       'default');
		meta.noteSkin  = resolveStr(rawData?.noteSkin, global.noteSkin, 'default');
		meta.noteSplash = (rawData?.noteSplash != null && rawData.noteSplash != '')
			? rawData.noteSplash
			: null; // null = usa la preferencia global del jugador sin tocarla

		// ── stageSkins: convertir el objeto Dynamic del JSON a Map<String,String> ──
		if (rawData?.stageSkins != null)
		{
			meta.stageSkins = new Map<String, String>();
			var obj:Dynamic = rawData.stageSkins;
			for (field in Reflect.fields(obj))
			{
				var val = Std.string(Reflect.field(obj, field));
				if (val != null && val != '') meta.stageSkins.set(field, val);
			}
			if (meta.stageSkins.iterator().hasNext())
				trace('[MetaData] stageSkins cargados: ' + [for (k in meta.stageSkins.keys()) '$k→${meta.stageSkins.get(k)}'].join(', '));
			else
				meta.stageSkins = null; // mapa vacío → tratar como null
		}

		meta.hideCombo   = resolveBool(rawData?.hideCombo,   false);
		meta.hideRatings = resolveBool(rawData?.hideRatings, false);
		meta.hudVisible  = resolveBool(rawData?.hudVisible,  true);
		// ── Video cutscenes ──────────────────────────────────────────────────
		meta.introVideo   = rawData?.introVideo  ?? null;
		meta.outroVideo   = rawData?.outroVideo  ?? null;
		meta.midSongVideo = resolveBool(rawData?.midSongVideo, false);

		trace('[MetaData] Resuelto — ui="${meta.ui}" noteSkin="${meta.noteSkin}" noteSplash="${meta.noteSplash}"');
		return meta;
	}

	// ── Guardado ─────────────────────────────────────────────────────────────

	/**
	 * Guarda los valores actuales como meta.json en la carpeta de la canción.
	 * Crea el directorio si no existe.
	 */
	public static function save(songName:String, ui:String, noteSkin:String,
	                            ?noteSplash:String = null,
	                            ?stageSkins:Map<String,String> = null,
	                            ?hideCombo:Bool = false, ?hideRatings:Bool = false,
	                            ?hudVisible:Bool = true):Void
	{
		#if sys
		try
		{
			var dir = 'assets/songs/${songName.toLowerCase()}';
			if (!FileSystem.exists(dir))
				FileSystem.createDirectory(dir);

			// Convertir Map<String,String> a objeto Dynamic para JSON
			var stageSkinsObj:Dynamic = null;
			if (stageSkins != null)
			{
				stageSkinsObj = {};
				for (stage in stageSkins.keys())
					Reflect.setField(stageSkinsObj, stage, stageSkins.get(stage));
			}

			var data:SongMetaData = {
				ui:         (ui        != null && ui        != '') ? ui        : null,
				noteSkin:   (noteSkin  != null && noteSkin  != '') ? noteSkin  : null,
				noteSplash: (noteSplash != null && noteSplash != '') ? noteSplash : null,
				stageSkins: stageSkinsObj,
				hideCombo:   hideCombo,
				hideRatings: hideRatings,
				hudVisible:  hudVisible
			};

			File.saveContent('$dir/meta.json', Json.stringify(data, null, '\t'));
			trace('[MetaData] Guardado: $dir/meta.json');
		}
		catch (e)
		{
			trace('[MetaData] Error al guardar meta.json: $e');
		}
		#end
	}

	// ── Helpers ──────────────────────────────────────────────────────────────

	static inline function resolveStr(metaVal:Null<String>, globalVal:Null<String>, fallback:String):String
	{
		if (metaVal != null && metaVal.length > 0)
			return metaVal;
		if (globalVal != null && globalVal.length > 0)
			return globalVal;
		return fallback;
	}

	static inline function resolveBool(metaVal:Null<Bool>, fallback:Bool):Bool
		return (metaVal != null) ? metaVal : fallback;
}
