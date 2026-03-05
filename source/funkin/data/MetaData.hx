package funkin.data;

import haxe.Json;
import sys.FileSystem;
import sys.io.File;
import mods.ModManager;

using StringTools;
/**
 * MetaData — Metadata por canción.
 *
 * Archivo: assets/songs/{songName}/meta.json
 *
 * Jerarquía de prioridad: meta.json > global.json > stage override > preferencia global
 *
 * Ejemplo completo de meta.json:
 * {
 *   "ui":              "default",
 *   "noteSkin":        "MyPixelSkin",
 *   "noteSplash":      "Default",
 *
 *   "holdCoverEnabled": true,
 *   "holdCoverSkin":    "pixelNoteHoldCover",
 *   "holdCoverFormat":  "sparrow",
 *   "holdCoverFrameW":  36,
 *   "holdCoverFrameH":  32,
 *
 *   "stageSkins": {
 *     "school":     "DefaultPixel",
 *     "schoolEvil": "DefaultPixel",
 *     "stage":      "Default"
 *   },
 *
 *   "hideCombo":    false,
 *   "hideRatings":  false,
 *   "hudVisible":   true,
 *   "introVideo":   "bopeebo-intro",
 *   "outroVideo":   "bopeebo-outro",
 *   "midSongVideo": false
 * }
 *
 * Formatos de atlas soportados en holdCoverFormat:
 *   "sparrow" — TextureAtlas XML (ej: pixelNoteHoldCover.xml). DEFAULT.
 *               PNG + XML con animaciones "loop" y "explode".
 *   "packer"  — Starling/Packer TXT. PNG + TXT.
 *   "grid"    — Spritesheet en grilla uniforme. Solo PNG.
 *               Requiere holdCoverFrameW + holdCoverFrameH.
 *               Primeras N frames = "loop", siguientes N = "explode".
 */
typedef SongMetaData =
{
	@:optional var ui:Null<String>;
	@:optional var noteSkin:Null<String>;
	@:optional var noteSplash:Null<String>;
	@:optional var stageSkins:Null<Dynamic>;

	/**
	 * Overrides por dificultad. La clave es el sufijo de dificultad SIN el guión
	 * (ej: "erect", "hard", "nightmare"). Los campos presentes en el objeto
	 * tienen prioridad sobre los valores base del meta.json para esa dificultad.
	 *
	 * Ejemplo:
	 *   "difficultyOverrides": {
	 *     "erect":     { "artist": "NyaWithMe" },
	 *     "nightmare": { "artist": "NyaWithMe" }
	 *   }
	 *
	 * Campos soportados actualmente: artist.
	 * (Fácil de extender a otros campos en MetaData.load)
	 */
	@:optional var difficultyOverrides:Null<Dynamic>;

	// ── Hold Cover ─────────────────────────────────────────────────────────
	@:optional var holdCoverEnabled:Null<Bool>;
	@:optional var holdCoverSkin:Null<String>;
	@:optional var holdCoverFormat:Null<String>;
	@:optional var holdCoverFrameW:Null<Int>;
	@:optional var holdCoverFrameH:Null<Int>;

	// ── HUD ────────────────────────────────────────────────────────────────
	@:optional var overrideGlobal:Null<Bool>;
	@:optional var hideCombo:Null<Bool>;
	@:optional var hideRatings:Null<Bool>;
	@:optional var hudVisible:Null<Bool>;
	@:optional var introVideo:Null<String>;
	@:optional var outroVideo:Null<String>;
	@:optional var midSongVideo:Null<Bool>;
	@:optional var disableCameraZoom:Null<Bool>;
	@:optional var artist:Null<String>;
}

class MetaData
{
	public var ui:String = 'default';
	public var noteSkin:String = 'default';
	public var noteSplash:Null<String> = null;
	public var stageSkins:Null<Map<String, String>> = null;

	// ── Hold Cover ──────────────────────────────────────────────────────────
	/** null = usar GlobalConfig.holdCoverEnabled */
	public var holdCoverEnabled:Null<Bool> = null;
	/** null = usar GlobalConfig.holdCoverSkin o el builtin */
	public var holdCoverSkin:Null<String> = null;
	/** "sparrow" | "packer" | "grid" */
	public var holdCoverFormat:String = 'sparrow';
	/** Ancho de frame para formato "grid" */
	public var holdCoverFrameW:Int = 0;
	/** Alto de frame para formato "grid" */
	public var holdCoverFrameH:Int = 0;

	public var hideCombo:Bool = false;
	public var hideRatings:Bool = false;
	public var hudVisible:Bool = true;
	public var introVideo:Null<String> = null;
	public var outroVideo:Null<String> = null;
	public var midSongVideo:Bool = false;
	public var disableCameraZoom:Bool = false;
	public var artist:Null<String> = null;

	public var raw:SongMetaData;

	public function new() {}

	public static function load(songName:String, ?difficulty:String):MetaData
	{
		var meta = new MetaData();
		var global = GlobalConfig.instance;

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

		meta.ui        = resolveStr(rawData?.ui,       global.ui,       'default');
		meta.noteSkin  = resolveStr(rawData?.noteSkin, global.noteSkin, 'default');
		meta.noteSplash = (rawData?.noteSplash != null && rawData.noteSplash != '')
			? rawData.noteSplash : null;

		if (rawData?.stageSkins != null)
		{
			meta.stageSkins = new Map<String, String>();
			var obj:Dynamic = rawData.stageSkins;
			for (field in Reflect.fields(obj))
			{
				var val = Std.string(Reflect.field(obj, field));
				if (val != null && val != '') meta.stageSkins.set(field, val);
			}
			if (!meta.stageSkins.iterator().hasNext()) meta.stageSkins = null;
		}

		// ── Hold Cover ───────────────────────────────────────────────────────
		// holdCoverEnabled: meta tiene prioridad; null = deja que GlobalConfig decida
		meta.holdCoverEnabled = (rawData?.holdCoverEnabled != null) ? rawData.holdCoverEnabled : null;

		// holdCoverSkin: meta > global
		if (rawData?.holdCoverSkin != null && rawData.holdCoverSkin != '')
			meta.holdCoverSkin = rawData.holdCoverSkin;
		else if (global.holdCoverSkin != null && global.holdCoverSkin != '')
			meta.holdCoverSkin = global.holdCoverSkin;

		// holdCoverFormat: meta > 'sparrow'
		final fmt = rawData?.holdCoverFormat;
		meta.holdCoverFormat = (fmt != null && fmt != '') ? fmt.toLowerCase() : 'sparrow';

		meta.holdCoverFrameW = (rawData?.holdCoverFrameW != null) ? rawData.holdCoverFrameW : 0;
		meta.holdCoverFrameH = (rawData?.holdCoverFrameH != null) ? rawData.holdCoverFrameH : 0;

		meta.hideCombo   = resolveBool(rawData?.hideCombo,   false);
		meta.hideRatings = resolveBool(rawData?.hideRatings, false);
		meta.hudVisible  = resolveBool(rawData?.hudVisible,  true);
		meta.introVideo        = rawData?.introVideo  ?? null;
		meta.outroVideo        = rawData?.outroVideo  ?? null;
		meta.midSongVideo      = resolveBool(rawData?.midSongVideo,      false);
		meta.disableCameraZoom = resolveBool(rawData?.disableCameraZoom, false);
		meta.artist = (rawData?.artist != null && rawData.artist != '') ? rawData.artist : null;

		// ── Difficulty overrides ─────────────────────────────────────────────
		// Normalizar dificultad: quitar guión inicial si viene con él ("-erect" → "erect").
		// La clave en el JSON no lleva guión para que sea más legible.
		if (difficulty != null && rawData?.difficultyOverrides != null)
		{
			final diffKey = difficulty.startsWith('-') ? difficulty.substr(1) : difficulty;
			final ov:Dynamic = Reflect.field(rawData.difficultyOverrides, diffKey);
			if (ov != null)
			{
				// artist
				final ovArtist:Null<String> = Reflect.field(ov, 'artist');
				if (ovArtist != null && ovArtist != '') meta.artist = ovArtist;

				// Añadir aquí más campos en el futuro siguiendo el mismo patrón:
				// final ovXxx = Reflect.field(ov, 'xxx');
				// if (ovXxx != null) meta.xxx = ovXxx;

				trace('[MetaData] difficultyOverrides["$diffKey"] aplicado');
			}
		}

		trace('[MetaData] Resuelto — noteSkin="${meta.noteSkin}" holdCoverEnabled=${meta.holdCoverEnabled} holdCoverSkin="${meta.holdCoverSkin}" holdCoverFormat="${meta.holdCoverFormat}"');
		return meta;
	}

	/**
	 * Guarda los valores actuales como meta.json en la carpeta de la canción.
	 */
	public static function save(songName:String, ui:String, noteSkin:String,
	                            ?noteSplash:String = null,
	                            ?stageSkins:Map<String,String> = null,
	                            ?holdCoverEnabled:Null<Bool> = null,
	                            ?holdCoverSkin:Null<String> = null,
	                            ?holdCoverFormat:String = 'sparrow',
	                            ?holdCoverFrameW:Int = 0,
	                            ?holdCoverFrameH:Int = 0,
	                            ?hideCombo:Bool = false,
	                            ?hideRatings:Bool = false,
	                            ?hudVisible:Bool = true):Void
	{
		#if sys
		try
		{
			var dir = 'assets/songs/${songName.toLowerCase()}';
			if (!FileSystem.exists(dir)) FileSystem.createDirectory(dir);

			var stageSkinsObj:Dynamic = null;
			if (stageSkins != null)
			{
				stageSkinsObj = {};
				for (stage in stageSkins.keys())
					Reflect.setField(stageSkinsObj, stage, stageSkins.get(stage));
			}

			var data:SongMetaData = {
				ui:         (ui != null && ui != '') ? ui : null,
				noteSkin:   (noteSkin != null && noteSkin != '') ? noteSkin : null,
				noteSplash: (noteSplash != null && noteSplash != '') ? noteSplash : null,
				stageSkins: stageSkinsObj,
				holdCoverEnabled: holdCoverEnabled,
				holdCoverSkin:   (holdCoverSkin != null && holdCoverSkin != '') ? holdCoverSkin : null,
				holdCoverFormat: (holdCoverFormat != null && holdCoverFormat != 'sparrow') ? holdCoverFormat : null,
				holdCoverFrameW: (holdCoverFrameW > 0) ? holdCoverFrameW : null,
				holdCoverFrameH: (holdCoverFrameH > 0) ? holdCoverFrameH : null,
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

	static inline function resolveStr(metaVal:Null<String>, globalVal:Null<String>, fallback:String):String
	{
		if (metaVal != null && metaVal.length > 0) return metaVal;
		if (globalVal != null && globalVal.length > 0) return globalVal;
		return fallback;
	}

	static inline function resolveBool(metaVal:Null<Bool>, fallback:Bool):Bool
		return (metaVal != null) ? metaVal : fallback;
}
