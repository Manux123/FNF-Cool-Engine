package funkin.gameplay.notes;

import extensions.FlxAtlasFramesExt;
import lime.utils.Assets;
import funkin.gameplay.PlayState;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import openfl.display.BitmapData;
import haxe.Json;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

// ==================== TYPEDEFS ====================

/**
 * Definición de textura de skin.
 *
 * Para type "sparrow": usa path.xml (Sparrow Atlas).
 * Para type "packer":  usa path.txt (TexturePacker).
 * Para type "image":   usa path.png dividido en frames de frameWidth×frameHeight píxeles.
 *                      El número de filas/columnas se calcula automáticamente.
 */
typedef NoteSkinTexture =
{
	var path:String;
	var ?type:String; // "sparrow" | "packer" | "image"  (default: "sparrow")
	var ?frameWidth:Int; // solo para type "image" — ancho de cada frame en píxeles
	var ?frameHeight:Int; // solo para type "image" — alto  de cada frame en píxeles
	var ?scale:Float; // escala aplicada al sprite (default: 1.0)
	var ?antialiasing:Bool; // default: true para normal, false para pixel
}

/**
 * Definición de una animación individual.
 *
 * Formatos aceptados en el JSON:
 *   String shorthand:   "purple0"
 *   Objeto prefix:      {"prefix": "purple0"}
 *   Objeto prefix+fps:  {"prefix": "purple0", "framerate": 12}
 *   Objeto indices:     {"indices": [4]}
 *   Objeto multi-frame: {"indices": [12, 16], "framerate": 24}
 *   Objeto con loop:    {"indices": [0, 1, 2], "framerate": 12, "loop": true}
 */
typedef NoteAnimDef =
{
	var ?prefix:String;
	var ?indices:Array<Int>;
	var ?framerate:Int;
	var ?loop:Bool;
}

/**
 * Todas las animaciones de una skin.
 *
 * Los campos son Dynamic para aceptar tanto el String shorthand como el
 * objeto NoteAnimDef completo. El helper addAnimToSprite() maneja ambos.
 *
 * Separación lógica:
 *   Notas (Scroll): left, down, up, right
 *   Hold pieces:    leftHold, downHold, upHold, rightHold
 *   Hold tails:     leftHoldEnd, downHoldEnd, upHoldEnd, rightHoldEnd
 *   Strum static:   strumLeft/Down/Up/Right
 *   Strum pressed:  strumLeft/Down/Up/RightPress
 *   Strum confirm:  strumLeft/Down/Up/RightConfirm
 */
typedef NoteSkinAnims =
{
	var ?left:Dynamic;
	var ?down:Dynamic;
	var ?up:Dynamic;
	var ?right:Dynamic;
	var ?leftHold:Dynamic;
	var ?downHold:Dynamic;
	var ?upHold:Dynamic;
	var ?rightHold:Dynamic;
	var ?leftHoldEnd:Dynamic;
	var ?downHoldEnd:Dynamic;
	var ?upHoldEnd:Dynamic;
	var ?rightHoldEnd:Dynamic;
	var ?strumLeft:Dynamic;
	var ?strumDown:Dynamic;
	var ?strumUp:Dynamic;
	var ?strumRight:Dynamic;
	var ?strumLeftPress:Dynamic;
	var ?strumDownPress:Dynamic;
	var ?strumUpPress:Dynamic;
	var ?strumRightPress:Dynamic;
	var ?strumLeftConfirm:Dynamic;
	var ?strumDownConfirm:Dynamic;
	var ?strumUpConfirm:Dynamic;
	var ?strumRightConfirm:Dynamic;
}

// Alias de compatibilidad — código que usaba NoteAnimations sigue compilando
typedef NoteAnimations = NoteSkinAnims;

/**
 * Datos completos de una skin de notas.
 *
 * La skin pixel y la skin normal son ENTIDADES COMPLETAMENTE INDEPENDIENTES.
 * No hay ninguna lógica hardcodeada de "school → pixel". En su lugar:
 *   - Crea una skin con isPixel:true y sus texturas/animaciones propias
 *   - Registra qué stage la usa con NoteSkinSystem.registerStageSkin(stage, skinName)
 *   - O llama NoteSkinSystem.setTemporarySkin(skinName) desde tu PlayState/Stage
 *
 * Campos clave:
 *   texture:      textura de notas (cabeza) y strums
 *   holdTexture:  textura de sustain pieces + tails (null → usa texture)
 *   isPixel:      activa modo pixel (antialiasing false por defecto)
 *   confirmOffset: aplica offset -13,-13 al strum confirm (default: true)
 *   sustainOffset: offset X extra para notas sustain (default: 0; pixel usa 30)
 *   holdStretch:  multiplicador de scale.y en hold chain (default: 1.0; pixel usa 1.19)
 *   animations:   todas las anims de notas + strums, usando NoteAnimDef
 */
typedef NoteSkinData =
{
	var name:String;
	var ?author:String;
	var ?description:String;
	var ?folder:String;
	// ── Texturas ──────────────────────────────────────────────────────────
	var texture:NoteSkinTexture;
	var ?holdTexture:NoteSkinTexture; // sustain pieces + tails (null → usa texture)
	// ── Flags y ajustes ───────────────────────────────────────────────────
	var ?isPixel:Bool;
	var ?confirmOffset:Bool; // default: true
	var ?offsetDefault:Bool; // alias legacy de confirmOffset
	var ?sustainOffset:Float; // default: 0.0
	var ?holdStretch:Float; // default: 1.0
	// ── Animaciones ───────────────────────────────────────────────────────
	var animations:NoteSkinAnims;
}

// ── Splash (sistema independiente, no cambia) ─────────────────────────────────

typedef NoteSplashData =
{
	var name:String;
	var author:String;
	var ?description:String;
	var ?folder:String;
	var assets:NoteSplashAssets;
	var animations:SplashAnimations;
}

typedef NoteSplashAssets =
{
	var path:String;
	var ?type:String;
	var ?scale:Float;
	var ?antialiasing:Bool;
	var ?offset:Array<Float>;
}

typedef SplashAnimations =
{
	var left:Array<String>;
	var down:Array<String>;
	var up:Array<String>;
	var right:Array<String>;
	var ?framerate:Int;
	var ?randomFramerateRange:Int;
}

// ==================== SISTEMA PRINCIPAL ====================

class NoteSkinSystem
{
	public static var currentSkin:String = "Default";
	public static var currentSplash:String = "Default";

	/**
	 * Splash elegido permanentemente por el jugador.
	 * Solo se modifica con setSplash() (que guarda en disco).
	 * setTemporarySplash() y applySplashForStage() modifican currentSplash
	 * pero NO _globalSplash, por lo que restoreGlobalSplash() siempre
	 * vuelve al valor real del jugador — sin importar si el save.data
	 * fue corrompido por el bug anterior que llamaba setSplash() en cada cancion.
	 */
	private static var _globalSplash:String = "Default";

	public static var availableSkins:Map<String, NoteSkinData> = new Map();
	public static var availableSplashes:Map<String, NoteSplashData> = new Map();

	/**
	 * Mapa stage-name → skin-name.
	 * Defaults registrados en init(). Editable vía registerStageSkin().
	 */
	private static var stageSkinMap:Map<String, String> = new Map();

	private static var stageSplashMap:Map<String, String> = new Map();

	private static var initialized:Bool = false;

	/** Último mod activo durante el init — si cambia, forzamos re-init. */
	private static var _lastInitMod:Null<String> = null;

	/** Si la skin actual aplica el offset -13,-13 estándar en confirm. */
	public static var offsetDefault:Bool = true;

	// Paths calculados en init() según el mod activo
	private static var SKINS_PATH:String = "assets/skins";
	private static var SPLASHES_PATH:String = "assets/splashes";

	// ==================== INIT ====================

	public static function init():Void
	{
		// Si el mod activo cambió desde el último init, forzar re-inicialización
		// para que se descubran las skins del nuevo mod.
		final currentMod:Null<String> = mods.ModManager.activeMod;
		if (initialized && currentMod == _lastInitMod)
			return;

		if (initialized)
		{
			// Reiniciar estado para el nuevo mod
			availableSkins = new Map();
			availableSplashes = new Map();
			stageSkinMap = new Map();
			stageSplashMap = new Map();
			_globalSplash = "Default";
			initialized = false;
		}

		trace("[NoteSkinSystem] Initializing...");

		// Calcular paths en runtime según el mod activo
		// SIEMPRE apuntamos a assets/ como base (los skins de mod se descubren
		// adicionalmente en discoverSkins / discoverSplashes).
		SKINS_PATH = "assets/skins";
		SPLASHES_PATH = "assets/splashes";

		_lastInitMod = currentMod;

		// Skins built-in
		availableSkins.set("Default", getDefaultSkin());
		availableSkins.set("Pixel", getDefaultPixelSkin());

		// Defaults de stage → skin (editables con registerStageSkin)
		stageSkinMap.set("school", "Pixel");
		stageSkinMap.set("schoolEvil", "Pixel");

		// Defaults de stage → splash (editables con registerStageSplash)
		// Se aplican con applySplashForStage() — sin guardar en disco (temporal).
		stageSplashMap.set("school", "PixelSplash");
		stageSplashMap.set("schoolEvil", "PixelSplash");

		discoverSkins();
		discoverSplashes();
		loadSavedSkin();
		loadSavedSplash();

		initialized = true;
		trace('[NoteSkinSystem] Ready — ${Lambda.count(availableSkins)} skins, ${Lambda.count(availableSplashes)} splashes');
	}

	// ==================== STAGE → SKIN MAPPING ====================

	/**
	 * Registra la skin a usar para un stage concreto.
	 * Llama esto desde tu Stage.hx o PlayState al cargar el stage.
	 *
	 *   NoteSkinSystem.registerStageSkin("schoolEvil", "DefaultPixel");
	 *   NoteSkinSystem.registerStageSkin("myCustomStage", "MyFancySkin");
	 */
	public static function registerStageSkin(stageName:String, skinName:String):Void
	{
		stageSkinMap.set(stageName, skinName);
		trace('[NoteSkinSystem] Stage "$stageName" → skin "$skinName"');
	}

	/**
	 * Devuelve el nombre de skin configurado para un stage, o null si no hay override.
	 */
	public static function getSkinNameForStage(stageName:String):String
	{
		return stageSkinMap.exists(stageName) ? stageSkinMap.get(stageName) : null;
	}

	/**
	 * Aplica temporalmente la skin asignada al stage.
	 * Si el stage no tiene skin propia, restaura la skin global del jugador.
	 *
	 * Úsalo en PlayState al cargar el stage:
	 *   NoteSkinSystem.applySkinForStage(PlayState.curStage);
	 */
	public static function applySkinForStage(stageName:String):Void
	{
		var skinForStage = getSkinNameForStage(stageName);
		if (skinForStage != null)
			setTemporarySkin(skinForStage);
		else
			restoreGlobalSkin();
	}

	/** Registra el splash a usar para un stage concreto (temporal, sin guardar). */
	public static function registerStageSplash(stageName:String, splashName:String):Void
	{
		stageSplashMap.set(stageName, splashName);
		trace('[NoteSkinSystem] Stage "$stageName" → splash "$splashName"');
	}

	/** Devuelve el nombre de splash configurado para un stage, o null si no hay override. */
	public static function getSplashNameForStage(stageName:String):String
	{
		return stageSplashMap.exists(stageName) ? stageSplashMap.get(stageName) : null;
	}

	/**
	 * Aplica temporalmente el splash asignado al stage.
	 * Si el stage no tiene splash propio, restaura el splash global del jugador.
	 * Llama esto justo despues de applySkinForStage() en PlayState.
	 */
	public static function applySplashForStage(stageName:String):Void
	{
		var splashForStage = getSplashNameForStage(stageName);
		if (splashForStage != null)
			setTemporarySplash(splashForStage);
		else
			restoreGlobalSplash();
	}

	// ==================== DESCUBRIMIENTO ====================

	private static function discoverSkins():Void
	{
		#if sys
		// Descubrir siempre desde assets/skins (base)
		_discoverSkinsInPath(SKINS_PATH);
		// Adicionalmente desde el mod activo (overrides y añadidos)
		final modRoot = mods.ModManager.modRoot();
		if (modRoot != null)
		{
			final modSkinsPath = '$modRoot/skins';
			if (modSkinsPath != SKINS_PATH)
				_discoverSkinsInPath(modSkinsPath);
		}
		#else
		for (skinPath in Assets.list().filter(p -> p.contains("skins/") && p.endsWith("skin.json")))
		{
			try
			{
				var data:NoteSkinData = Json.parse(Assets.getText(skinPath));
				var m = ~/skins\/([^\/]+)\//;
				if (m.match(skinPath))
					data.folder = m.matched(1);
				availableSkins.set(data.name, data);
			}
			catch (e:Dynamic)
			{
				trace('[NoteSkinSystem] Error loading $skinPath: $e');
			}
		}
		#end
	}

	#if sys
	private static function _discoverSkinsInPath(basePath:String):Void
	{
		if (!FileSystem.exists(basePath) || !FileSystem.isDirectory(basePath))
			return;
		for (skinFolder in FileSystem.readDirectory(basePath))
		{
			var skinPath = '$basePath/$skinFolder';
			if (!FileSystem.isDirectory(skinPath))
				continue;
			var configPath = '$skinPath/skin.json';
			if (FileSystem.exists(configPath))
			{
				try
				{
					var data:NoteSkinData = Json.parse(File.getContent(configPath));
					data.folder = skinFolder;
					availableSkins.set(data.name, data);
					trace('[NoteSkinSystem] Loaded skin "${data.name}" from $basePath/$skinFolder');
				}
				catch (e:Dynamic)
				{
					trace('[NoteSkinSystem] Error loading $configPath: $e');
				}
			}
			else
			{
				var auto = autoDetectSkin(skinPath, skinFolder);
				if (auto != null)
				{
					availableSkins.set(auto.name, auto);
					trace('[NoteSkinSystem] Auto-detected skin "${auto.name}"');
				}
			}
		}
	}
	#end

	private static function discoverSplashes():Void
	{
		availableSplashes.set("Default", getDefaultSplash());
		#if sys
		_discoverSplashesInPath(SPLASHES_PATH);
		// Adicionalmente desde el mod activo
		final modRoot = mods.ModManager.modRoot();
		if (modRoot != null)
		{
			final modSplashesPath = '$modRoot/splashes';
			if (modSplashesPath != SPLASHES_PATH)
				_discoverSplashesInPath(modSplashesPath);
		}
		#else
		for (splashPath in Assets.list().filter(p -> p.contains("splashes/") && p.endsWith("splash.json")))
		{
			try
			{
				var data:NoteSplashData = Json.parse(Assets.getText(splashPath));
				var m = ~/splashes\/([^\/]+)\//;
				if (m.match(splashPath))
					data.folder = m.matched(1);
				availableSplashes.set(data.name, data);
			}
			catch (e:Dynamic)
			{
				trace('[NoteSkinSystem] Error loading $splashPath: $e');
			}
		}
		#end
	}

	#if sys
	private static function _discoverSplashesInPath(basePath:String):Void
	{
		if (!FileSystem.exists(basePath) || !FileSystem.isDirectory(basePath))
			return;
		for (splashFolder in FileSystem.readDirectory(basePath))
		{
			var splashPath = '$basePath/$splashFolder';
			if (!FileSystem.isDirectory(splashPath))
				continue;
			var configPath = '$splashPath/splash.json';
			if (FileSystem.exists(configPath))
			{
				try
				{
					var data:NoteSplashData = Json.parse(File.getContent(configPath));
					data.folder = splashFolder;
					availableSplashes.set(data.name, data);
				}
				catch (e:Dynamic)
				{
					trace('[NoteSkinSystem] Error loading $configPath: $e');
				}
			}
			else
			{
				var auto = autoDetectSplash(splashPath, splashFolder);
				if (auto != null)
					availableSplashes.set(auto.name, auto);
			}
		}
	}
	#end

	// ==================== AUTO-DETECCIÓN ====================
	#if sys
	private static function autoDetectSkin(skinPath:String, folderName:String):NoteSkinData
	{
		var files = FileSystem.readDirectory(skinPath);
		var mainPath = "";
		var mainType = "sparrow";
		var holdPath = "";

		for (file in files)
		{
			var lower = file.toLowerCase();
			if (!lower.endsWith(".png"))
				continue;
			var base = file.substr(0, file.length - 4);
			var hasXml = files.indexOf(base + ".xml") != -1;
			var hasTxt = files.indexOf(base + ".txt") != -1;
			var isHold = lower.contains("hold") || lower.contains("end");

			if (isHold && holdPath == "")
				holdPath = base;
			else if (!isHold && mainPath == "")
			{
				mainPath = base;
				mainType = hasXml ? "sparrow" : (hasTxt ? "packer" : "image");
			}
		}

		if (mainPath == "")
			return null;

		var skin:NoteSkinData = {
			name: folderName,
			author: "Unknown",
			folder: folderName,
			texture: {path: mainPath, type: mainType},
			animations: {}
		};
		if (holdPath != "")
			skin.holdTexture = {path: holdPath, type: "image"};

		return skin;
	}

	private static function autoDetectSplash(splashPath:String, folderName:String):NoteSplashData
	{
		var files = FileSystem.readDirectory(splashPath);
		for (file in files)
		{
			if (!file.toLowerCase().contains("splash") || !file.toLowerCase().endsWith(".png"))
				continue;
			var base = file.substr(0, file.length - 4);
			var hasXml = files.indexOf(base + ".xml") != -1;
			return {
				name: folderName,
				author: "Unknown",
				folder: folderName,
				assets: {path: base, type: hasXml ? "sparrow" : "image"},
				animations: {
					left: ["note impact 1 purple", "note impact 2 purple"],
					down: ["note impact 1 blue", "note impact 2 blue"],
					up: ["note impact 1 green", "note impact 2 green"],
					right: ["note impact 1 red", "note impact 2 red"],
					framerate: 24
				}
			};
		}
		return null;
	}
	#end

	// ==================== DEFAULTS ====================

	/**
	 * Skin normal por defecto — NOTE_assets.xml, animaciones sparrow estándar FNF.
	 */
	private static function getDefaultSkin():NoteSkinData
	{
		return {
			name: "Default",
			author: "ninjamuffin99",
			description: "Default Friday Night Funkin' notes",
			folder: "Default",
			texture: {
				path: "NOTE_assets",
				type: "sparrow",
				scale: 0.7,
				antialiasing: true
			},
			confirmOffset: true,
			animations: {
				left: "purple0",
				down: "blue0",
				up: "green0",
				right: "red0",
				leftHold: "purple hold piece",
				downHold: "blue hold piece",
				upHold: "green hold piece",
				rightHold: "red hold piece",
				leftHoldEnd: "pruple end hold",
				downHoldEnd: "blue hold end",
				upHoldEnd: "green hold end",
				rightHoldEnd: "red hold end",
				strumLeft: "arrowLEFT",
				strumDown: "arrowDOWN",
				strumUp: "arrowUP",
				strumRight: "arrowRIGHT",
				strumLeftPress: "left press",
				strumDownPress: "down press",
				strumUpPress: "up press",
				strumRightPress: "right press",
				strumLeftConfirm: "left confirm",
				strumDownConfirm: "down confirm",
				strumUpConfirm: "up confirm",
				strumRightConfirm: "right confirm"
			}
		};
	}

	/**
	 * Skin PIXEL por defecto — arrows-pixels.png + arrowEnds.png, animaciones por índice.
	 *
	 * Layout arrows-pixels.png (frameWidth=17, frameHeight=17):
	 *   fila 0 (frames  0-3):  strums static
	 *   fila 1 (frames  4-7):  notas scroll
	 *   fila 2 (frames  8-11): strums pressed
	 *   fila 3 (frames 12-15): confirm frame 1
	 *   fila 4 (frames 16-19): confirm frame 2
	 *
	 * Layout arrowEnds.png (frameWidth=7, frameHeight=6):
	 *   fila 0 (frames  0-3):  hold pieces
	 *   fila 1 (frames  4-7):  hold tails
	 */
	private static function getDefaultPixelSkin():NoteSkinData
	{
		return {
			name: "Pixel",
			author: "ninjamuffin99",
			description: "Default pixel/week 6 note skin",
			folder: "Default",
			isPixel: true,
			confirmOffset: false,
			sustainOffset: 30.0,
			holdStretch: 1.19,
			texture: {
				path: "arrows-pixels",
				type: "image",
				frameWidth: 17,
				frameHeight: 17,
				scale: 6.0,
				antialiasing: false
			},
			holdTexture: {
				path: "arrowEnds",
				type: "image",
				frameWidth: 7,
				frameHeight: 6,
				scale: 6.0,
				antialiasing: false
			},
			animations: {
				// Notas scroll — fila 1 (frames 4-7)
				left: {indices: [4]},
				down: {indices: [5]},
				up: {indices: [6]},
				right: {indices: [7]},
				// Hold pieces — fila 0 de arrowEnds (frames 0-3)
				leftHold: {indices: [0]},
				downHold: {indices: [1]},
				upHold: {indices: [2]},
				rightHold: {indices: [3]},
				// Hold tails — fila 1 de arrowEnds (frames 4-7)
				leftHoldEnd: {indices: [4]},
				downHoldEnd: {indices: [5]},
				upHoldEnd: {indices: [6]},
				rightHoldEnd: {indices: [7]},
				// Strums static — fila 0 (frames 0-3)
				strumLeft: {indices: [0]},
				strumDown: {indices: [1]},
				strumUp: {indices: [2]},
				strumRight: {indices: [3]},
				// Strums pressed — filas 1+2 (fps 12)
				strumLeftPress: {indices: [4, 8], framerate: 12},
				strumDownPress: {indices: [5, 9], framerate: 12},
				strumUpPress: {indices: [6, 10], framerate: 12},
				strumRightPress: {indices: [7, 11], framerate: 12},
				// Strums confirm — filas 3+4 (fps 24)
				strumLeftConfirm: {indices: [12, 16], framerate: 24},
				strumDownConfirm: {indices: [13, 17], framerate: 24},
				strumUpConfirm: {indices: [14, 18], framerate: 24},
				strumRightConfirm: {indices: [15, 19], framerate: 24}
			}
		};
	}

	private static function getDefaultSplash():NoteSplashData
	{
		return {
			name: "Default",
			author: "FNF Team",
			description: "Default note splash effects",
			folder: "Default",
			assets: {
				path: "noteSplashes",
				type: "sparrow",
				scale: 1.0,
				antialiasing: true,
				offset: [0, 0]
			},
			animations: {
				left: ["note impact 1 purple", "note impact 2 purple"],
				down: ["note impact 1 blue", "note impact 2 blue"],
				up: ["note impact 1 green", "note impact 2 green"],
				right: ["note impact 1 red", "note impact 2 red"],
				framerate: 24,
				randomFramerateRange: 3
			}
		};
	}

	// ==================== CARGA / GUARDADO ====================

	private static function loadSavedSkin():Void
	{
		if (FlxG.save.data.noteSkin != null && availableSkins.exists(FlxG.save.data.noteSkin))
		{
			currentSkin = FlxG.save.data.noteSkin;
		}
		else
		{
			currentSkin = "Default";
			if (FlxG.save.data.noteSkin != "Default")
			{
				FlxG.save.data.noteSkin = "Default";
				FlxG.save.flush(); // solo flush cuando realmente cambia algo
			}
		}
	}

	private static function loadSavedSplash():Void
	{
		// Determinar el splash global del jugador a partir del save.
		// SANITIZACIÓN: si el save tiene un splash que es específico de pixel
		// (e.g. "PixelSplash") almacenado por el bug antiguo que llamaba setSplash()
		// desde PlayState en cada cancion — lo reseteamos a "Default".
		// Un jugador que QUIERA PixelSplash global lo tiene que elegir manualmente
		// en el menú de opciones (que llama setSplash() explícitamente).
		// La heurística: si el save tiene "PixelSplash" pero no hay skin Pixel activa
		// global, revertir. Mas simple: los splash que contengan "pixel" en el nombre
		// (case-insensitive) no deben ser el splash global por defecto.
		var savedSplash:String = FlxG.save.data.noteSplash;
		var isValidGlobal:Bool = (savedSplash != null
			&& availableSplashes.exists(savedSplash)
			&& savedSplash.toLowerCase().indexOf('pixel') < 0); // no pixel-only splashes as global default

		if (isValidGlobal)
		{
			_globalSplash = savedSplash;
			currentSplash = savedSplash;
		}
		else
		{
			_globalSplash = "Default";
			currentSplash = "Default";
			// Reparar el save si estaba corrompido
			if (FlxG.save.data.noteSplash != "Default")
			{
				FlxG.save.data.noteSplash = "Default";
				FlxG.save.flush();
			}
		}
	}

	// ==================== SETTERS ====================

	public static function setSkin(skinName:String):Bool
	{
		if (!availableSkins.exists(skinName))
		{
			trace('Note skin "$skinName" not found!');
			return false;
		}
		currentSkin = skinName;
		FlxG.save.data.noteSkin = skinName;
		FlxG.save.flush();
		return true;
	}

	public static function setTemporarySkin(skinName:String):Void
	{
		if (!initialized)
			init();
		if (skinName == null || skinName == '' || skinName == 'default')
		{
			currentSkin = FlxG.save.data.noteSkin != null ? FlxG.save.data.noteSkin : 'Default';
			return;
		}
		if (availableSkins.exists(skinName))
		{
			currentSkin = skinName;
			return;
		}
		for (key in availableSkins.keys())
		{
			if (key.toLowerCase() == skinName.toLowerCase())
			{
				currentSkin = key;
				return;
			}
		}
		currentSkin = FlxG.save.data.noteSkin != null ? FlxG.save.data.noteSkin : 'Default';
		trace('[NoteSkinSystem] Skin "$skinName" no encontrada, usando global: $currentSkin');
	}

	public static function restoreGlobalSkin():Void
	{
		currentSkin = FlxG.save.data.noteSkin != null ? FlxG.save.data.noteSkin : 'Default';
	}

	public static function setSplash(splashName:String):Bool
	{
		if (!availableSplashes.exists(splashName))
		{
			trace('Splash "$splashName" not found!');
			return false;
		}
		// BUGFIX: actualizar _globalSplash ademas de currentSplash y save.data
		// para que restoreGlobalSplash() use siempre el valor correcto.
		_globalSplash = splashName;
		currentSplash = splashName;
		FlxG.save.data.noteSplash = splashName;
		FlxG.save.flush();
		return true;
	}

	/**
	 * Cambia el splash TEMPORALMENTE sin guardar en disco ni tocar _globalSplash.
	 * Usa esto desde PlayState / Stage para sobreescribir el splash por cancion
	 * sin contaminar la preferencia global del jugador.
	 * Llama restoreGlobalSplash() al salir del PlayState.
	 */
	public static function setTemporarySplash(splashName:String):Void
	{
		if (!initialized)
			init();
		if (splashName == null || splashName == '' || splashName == 'default')
		{
			// Splash vacío en meta = usar el global del jugador
			currentSplash = _globalSplash;
			return;
		}
		if (availableSplashes.exists(splashName))
		{
			currentSplash = splashName;
			return;
		}
		for (key in availableSplashes.keys())
		{
			if (key.toLowerCase() == splashName.toLowerCase())
			{
				currentSplash = key;
				return;
			}
		}
		// Fallback al global (sin tocar _globalSplash)
		currentSplash = _globalSplash;
		trace('[NoteSkinSystem] Splash "$splashName" no encontrado, usando global: $currentSplash');
	}

	/**
	 * Restaura currentSplash al valor elegido por el jugador (_globalSplash).
	 * BUGFIX: ya no usa FlxG.save.data.noteSplash directamente — el save puede
	 * estar corrompido con "PixelSplash" por el bug anterior que llamaba setSplash()
	 * en cada cancion de school. _globalSplash solo lo toca loadSavedSplash() y setSplash().
	 */
	public static function restoreGlobalSplash():Void
	{
		currentSplash = _globalSplash;
	}

	// ==================== GETTERS DE SKIN ====================

	/**
	 * Devuelve el NoteSkinData completo de la skin actual.
	 * Úsalo en Note.hx / StrumNote.hx — contiene textura, escala, anims, flags, todo.
	 */
	public static function getCurrentSkinData(?skinName:String):NoteSkinData
	{
		if (!initialized)
			init();
		var skin = skinName != null ? skinName : currentSkin;
		var data = availableSkins.get(skin);
		if (data == null)
			data = availableSkins.get("Default");
		return data;
	}

	/**
	 * Carga y devuelve el FlxAtlasFrames de una NoteSkinTexture.
	 * Usa folder de la skin como prefijo de assets.
	 */
	public static function loadSkinFrames(tex:NoteSkinTexture, ?folder:String):FlxAtlasFrames
	{
		return loadAtlas(tex, folder != null ? folder : "Default");
	}

	// ── Helpers de escala convenientes ───────────────────────────────────

	public static function getNoteScale(?skinName:String):Float
	{
		var d = getCurrentSkinData(skinName);
		return (d != null && d.texture != null && d.texture.scale != null) ? d.texture.scale : 0.7;
	}

	public static function getPixelNoteScale(?skinName:String):Float
	{
		var d = getCurrentSkinData(skinName);
		return (d != null && d.texture != null && d.texture.scale != null) ? d.texture.scale : funkin.gameplay.PlayStateConfig.PIXEL_ZOOM;
	}

	public static function getPixelEndsScale(?skinName:String):Float
	{
		var d = getCurrentSkinData(skinName);
		if (d == null)
			return funkin.gameplay.PlayStateConfig.PIXEL_ZOOM;
		var tex = d.holdTexture != null ? d.holdTexture : d.texture;
		return (tex != null && tex.scale != null) ? tex.scale : funkin.gameplay.PlayStateConfig.PIXEL_ZOOM;
	}

	// ── Getters legacy (siguen funcionando para código externo) ──────────

	public static function getNoteSkin(?skinName:String):FlxAtlasFrames
	{
		var d = getCurrentSkinData(skinName);
		return loadAtlas(d.texture, d.folder);
	}

	public static function getPixelNoteSkin(?skinName:String):FlxAtlasFrames
	{
		var d = getCurrentSkinData(skinName);
		return loadAtlas(d.texture, d.folder);
	}

	public static function getPixelNoteEnds(?skinName:String):FlxAtlasFrames
	{
		var d = getCurrentSkinData(skinName);
		var tex = d.holdTexture != null ? d.holdTexture : d.texture;
		return loadAtlas(tex, d.folder);
	}

	public static function getSkinAnimations(?skinName:String):NoteSkinAnims
	{
		var d = getCurrentSkinData(skinName);
		return d != null ? d.animations : null;
	}

	// ==================== HELPER: AÑADIR ANIMACIÓN ====================

	/**
	 * Añade una animación a un FlxSprite desde un campo de animación del JSON.
	 *
	 * Acepta:
	 *   String:         "purple0"                     → addByPrefix("purple0")
	 *   Objeto prefix:  {"prefix":"purple0"}           → addByPrefix("purple0")
	 *   Objeto indices: {"indices":[4],"framerate":24} → animation.add([4], 24)
	 *
	 * Si def es null no hace nada — la animación simplemente no se registra.
	 *
	 * @param overrideLoop  When non-null, forces the loop flag regardless of what
	 *                      the JSON definition says.  Pass `false` for strum
	 *                      animations (pressed / confirm) so that
	 *                      animation.curAnim.finished works correctly and the
	 *                      auto-reset to 'static' fires as expected.
	 *                      Passing `null` (default) preserves the original
	 *                      behaviour: loop comes from the def object, or defaults
	 *                      to false for indices/prefix objects and false for plain
	 *                      strings (previously defaulted to Flixel's loop=true).
	 */
	public static function addAnimToSprite(sprite:FlxSprite, animName:String, def:Dynamic, ?overrideLoop:Bool):Void
	{
		if (sprite == null || def == null)
			return;

		if (Std.isOfType(def, String))
		{
			// Plain string shorthand — no framerate or loop info in the def.
			// Default to loop=false so strum confirm/pressed finish correctly.
			// overrideLoop takes precedence when explicitly supplied.
			var loop:Bool = overrideLoop != null ? overrideLoop : false;
			sprite.animation.addByPrefix(animName, cast(def, String), 24, loop);
			return;
		}

		var prefix:String = def.prefix;
		var indices:Dynamic = def.indices;
		var fps:Int = def.framerate != null ? Std.int(def.framerate) : 24;
		// overrideLoop wins; fall back to the def's loop field; then false.
		var loop:Bool = overrideLoop != null ? overrideLoop : (def.loop != null ? (def.loop == true) : false);

		if (indices != null)
		{
			var arr:Array<Int> = [];
			for (v in (indices : Array<Dynamic>))
				arr.push(Std.int(v));
			sprite.animation.add(animName, arr, fps, loop);
		}
		else if (prefix != null)
		{
			sprite.animation.addByPrefix(animName, prefix, fps, loop);
		}
		else
		{
			trace('[NoteSkinSystem] addAnimToSprite: "$animName" no tiene prefix ni indices — ignorado');
		}
	}

	// ==================== GETTERS DE SPLASH ====================

	public static function getSplashTexture(?splashName:String):FlxAtlasFrames
	{
		if (!initialized)
			init();
		var d = availableSplashes.get(splashName != null ? splashName : currentSplash);
		if (d == null)
			d = availableSplashes.get("Default");
		return loadAtlasSplash(d.assets, d.folder);
	}

	public static function getSplashAnimations(?splashName:String):SplashAnimations
	{
		if (!initialized)
			init();
		var d = availableSplashes.get(splashName != null ? splashName : currentSplash);
		if (d == null)
			d = availableSplashes.get("Default");
		return d.animations;
	}

	public static function getSplashData(?splashName:String):NoteSplashData
	{
		if (!initialized)
			init();
		var d = availableSplashes.get(splashName != null ? splashName : currentSplash);
		if (d == null)
			d = availableSplashes.get("Default");
		return d;
	}

	// ==================== HOLD COVERS ====================

	public static function holdCoverExists(color:String, ?splashName:String):Bool
	{
		if (!initialized)
			init();
		var d = availableSplashes.get(splashName != null ? splashName : currentSplash);
		if (d == null)
			d = availableSplashes.get("Default");
		return splashAssetExists('holdCover$color', d.folder != null ? d.folder : "Default");
	}

	public static function getHoldCoverTexture(color:String, ?splashName:String):FlxAtlasFrames
	{
		if (!initialized)
			init();
		var d = availableSplashes.get(splashName != null ? splashName : currentSplash);
		if (d == null)
			d = availableSplashes.get("Default");
		var folder = d.folder != null ? d.folder : "Default";
		var path = 'holdCover$color';
		if (!splashAssetExists(path, folder))
			return null;
		try
		{
			return Paths.splashSprite('$folder/$path');
		}
		catch (e:Dynamic)
		{
			return Paths.splashSprite('Default/$path');
		}
	}

	public static function getCurrentSplashFolder():String
	{
		if (!initialized)
			init();
		var d = availableSplashes.get(currentSplash);
		if (d == null)
			d = availableSplashes.get("Default");
		return d.folder != null ? d.folder : "Default";
	}

	// ==================== LISTAS ====================

	public static function getSkinList():Array<String>
	{
		if (!initialized)
			init();
		return [for (k in availableSkins.keys()) k];
	}

	public static function getSplashList():Array<String>
	{
		if (!initialized)
			init();
		return [for (k in availableSplashes.keys()) k];
	}

	public static function getSkinInfo(n:String):NoteSkinData
	{
		if (!initialized)
			init();
		return availableSkins.get(n);
	}

	public static function getSplashInfo(n:String):NoteSplashData
	{
		if (!initialized)
			init();
		return availableSplashes.get(n);
	}

	// ==================== CARGA INTERNA DE ATLAS ====================

	private static function loadAtlas(tex:Dynamic, ?folderName:String):FlxAtlasFrames
	{
		if (tex == null || tex.path == null)
		{
			trace('[NoteSkinSystem] loadAtlas: textura inválida, usando Default');
			var fallback = Paths.skinSprite('Default/NOTE_assets');
			if (fallback != null) return fallback;
			return _makeFallbackFrames();
		}

		var path:String = tex.path;
		var type:String = tex.type != null ? tex.type : "sparrow";
		var folder:String = folderName != null ? folderName : "Default";

		if (!assetExists(path, folder))
		{
			trace('[NoteSkinSystem] loadAtlas: "$folder/$path" no encontrado, usando Default');
			var fallback = Paths.skinSprite('Default/NOTE_assets');
			if (fallback != null) return fallback;
			return _makeFallbackFrames();
		}

		try
		{
			var result:FlxAtlasFrames = null;
			switch (type.toLowerCase())
			{
				case "sparrow":
					result = Paths.skinSprite('$folder/$path');

				case "packer":
					result = Paths.skinSpriteTxt('$folder/$path');

				case "image":
					var graphic = FlxG.bitmap.add('assets/skins/$folder/$path.png');
					if (graphic == null) throw 'PNG no encontrado para image skin: $folder/$path';
					// BUGFIX: FlxG.bitmap.add() deja persist=false y useCount=0.
					// FunkinCache.clearSecondLayer() → clearUnused() destruye cualquier
					// gráfico con persist=false + useCount=0 al final de postStateSwitch,
					// ANTES de que los StrumNotes/Notes hayan dibujado su primer frame.
					// Resultado: frame.parent.bitmap = null → FlxDrawQuadsItem::render crash.
					// Solución: marcar persist=true y registrar en PathsCache para que el
					// sistema de caché lo gestione correctamente entre sesiones.
					graphic.persist = true;
					graphic.destroyOnNoUse = false;
					funkin.cache.PathsCache.instance.trackGraphic('assets/skins/$folder/$path.png', graphic);
					// Dimensiones de frame leídas del JSON — sin hardcodeo por nombre de archivo
					var fw:Int = tex.frameWidth != null ? Std.int(tex.frameWidth) : 17;
					var fh:Int = tex.frameHeight != null ? Std.int(tex.frameHeight) : 17;
					trace('[NoteSkinSystem] image atlas $folder/$path — frame: ${fw}×${fh}px');
					result = FlxAtlasFramesExt.fromGraphic(graphic, fw, fh);

				default:
					trace('[NoteSkinSystem] tipo desconocido "$type" en $folder/$path, usando sparrow');
					result = Paths.skinSprite('$folder/$path');
			}

			if (result != null) return result;

			// Resultado null (ej: XML faltante con PNG presente) → fallback Default
			trace('[NoteSkinSystem] loadAtlas: "$folder/$path" devolvió null, probando Default');
			var fallback = Paths.skinSprite('Default/NOTE_assets');
			if (fallback != null) return fallback;
			return _makeFallbackFrames();
		}
		catch (e:Dynamic)
		{
			trace('[NoteSkinSystem] Error cargando $folder/$path: $e');
			var fallback = Paths.skinSprite('Default/NOTE_assets');
			if (fallback != null) return fallback;
			return _makeFallbackFrames();
		}
	}

	/**
	 * Último recurso: crea un FlxAtlasFrames de 1×1 píxel para que los sprites
	 * nunca tengan frames=null. Sin esto, cualquier StrumNote/Note con skin rota
	 * causa FlxDrawQuadsItem::render crash en el primer frame de PlayState.
	 */
	private static function _makeFallbackFrames():FlxAtlasFrames
	{
		trace('[NoteSkinSystem] FALLBACK: usando frames de 1×1 para evitar crash de render');
		var bmp = new openfl.display.BitmapData(1, 1, true, 0x00000000);
		var g = FlxG.bitmap.add(bmp, false, 'note_skin_fallback_${Math.random()}');
		if (g == null)
		{
			// Último último recurso: crear FlxGraphic directamente
			g = flixel.graphics.FlxGraphic.fromBitmapData(bmp, false, null, false);
		}
		// fromGraphic con frames 1×1 → atlas de 1 frame, 1×1 px
		return FlxAtlasFramesExt.fromGraphic(g, 1, 1);
	}

	private static function loadAtlasSplash(assets:Dynamic, ?folderName:String):FlxAtlasFrames
	{
		if (assets == null || assets.path == null)
			return Paths.splashSprite('Default/noteSplashes');
		var path = (assets.path : String);
		var type = assets.type != null ? (assets.type : String) : "sparrow";
		var folder = folderName != null ? folderName : "Default";
		if (!splashAssetExists(path, folder))
			return Paths.splashSprite('Default/noteSplashes');
		try
		{
			switch (type.toLowerCase())
			{
				case "sparrow":
					return Paths.splashSprite('$folder/$path');
				case "packer":
					return FlxAtlasFrames.fromSpriteSheetPacker(FlxG.bitmap.add('assets/splashes/$folder/$path.png'), 'assets/splashes/$folder/$path.txt');
				case "image":
					var g = FlxG.bitmap.add('assets/splashes/$folder/$path.png');
					if (g == null) throw 'PNG no encontrado para image splash: $folder/$path';
					// BUGFIX: igual que loadAtlas "image" — persist=true para evitar que
					// clearSecondLayer() → clearUnused() destruya el gráfico antes del primer render.
					g.persist = true;
					g.destroyOnNoUse = false;
					funkin.cache.PathsCache.instance.trackGraphic('assets/splashes/$folder/$path.png', g);
					return FlxAtlasFramesExt.fromGraphic(g, g.width, g.height);
				default:
					return Paths.splashSprite('$folder/$path');
			}
		}
		catch (e:Dynamic)
		{
			return Paths.splashSprite('Default/noteSplashes');
		}
	}

	private static function assetExists(path:String, folder:String):Bool
	{
		#if sys
		// Comprobar primero en el mod activo, luego en assets base.
		// Sin esto, skins en mods/MyMod/skins/ZoneNotes/NOTE_assets.png
		// son ignoradas y el juego cae silenciosamente al Default.
		final modRoot = mods.ModManager.modRoot();
		if (modRoot != null && sys.FileSystem.exists('$modRoot/skins/$folder/$path.png'))
			return true;
		return sys.FileSystem.exists('assets/skins/$folder/$path.png') || sys.FileSystem.exists('$path.png');
		#else
		return openfl.utils.Assets.exists('assets/skins/$folder/$path.png');
		#end
	}

	private static function splashAssetExists(path:String, folder:String):Bool
	{
		#if sys
		// Misma lógica que assetExists: comprobar mod primero.
		final modRoot = mods.ModManager.modRoot();
		if (modRoot != null && sys.FileSystem.exists('$modRoot/splashes/$folder/$path.png'))
			return true;
		return sys.FileSystem.exists('assets/splashes/$folder/$path.png') || sys.FileSystem.exists('$path.png');
		#else
		return openfl.utils.Assets.exists('assets/splashes/$folder/$path.png');
		#end
	}

	// ==================== EXPORT EXAMPLES ====================

	/**
	 * Genera un JSON de ejemplo para una skin normal.
	 * Colócalo en:  assets/skins/MiSkin/skin.json
	 */
	public static function exportSkinExample():String
	{
		return Json.stringify({
			name: "Custom Skin",
			author: "Your Name",
			description: "My custom note skin",
			texture: {
				path: "NOTE_assets",
				type: "sparrow",
				scale: 0.7,
				antialiasing: true
			},
			confirmOffset: true,
			animations: {
				left: "purple0",
				down: "blue0",
				up: "green0",
				right: "red0",
				leftHold: "purple hold piece",
				downHold: "blue hold piece",
				upHold: "green hold piece",
				rightHold: "red hold piece",
				leftHoldEnd: "pruple end hold",
				downHoldEnd: "blue hold end",
				upHoldEnd: "green hold end",
				rightHoldEnd: "red hold end",
				strumLeft: "arrowLEFT",
				strumDown: "arrowDOWN",
				strumUp: "arrowUP",
				strumRight: "arrowRIGHT",
				strumLeftPress: "left press",
				strumDownPress: "down press",
				strumUpPress: "up press",
				strumRightPress: "right press",
				strumLeftConfirm: "left confirm",
				strumDownConfirm: "down confirm",
				strumUpConfirm: "up confirm",
				strumRightConfirm: "right confirm"
			}
		}, null, "  ");
	}

	/**
	 * Genera un JSON de ejemplo para una skin PIXEL.
	 * Colócalo en:  assets/skins/MiSkinPixel/skin.json
	 *
	 * Para asociarlo a un stage:
	 *   NoteSkinSystem.registerStageSkin("miStage", "MiSkinPixel");
	 * O desde PlayState:
	 *   NoteSkinSystem.applySkinForStage(PlayState.curStage);
	 */
	public static function exportPixelSkinExample():String
	{
		return Json.stringify({
			name: "Custom Pixel Skin",
			author: "Your Name",
			description: "My pixel note skin",
			isPixel: true,
			confirmOffset: false,
			sustainOffset: 30,
			holdStretch: 1.19,
			texture: {
				path: "arrows-pixels",
				type: "image",
				frameWidth: 17,
				frameHeight: 17,
				scale: 6.0,
				antialiasing: false
			},
			holdTexture: {
				path: "arrowEnds",
				type: "image",
				frameWidth: 7,
				frameHeight: 6,
				scale: 6.0,
				antialiasing: false
			},
			animations: {
				left: {indices: [4]},
				down: {indices: [5]},
				up: {indices: [6]},
				right: {indices: [7]},
				leftHold: {indices: [0]},
				downHold: {indices: [1]},
				upHold: {indices: [2]},
				rightHold: {indices: [3]},
				leftHoldEnd: {indices: [4]},
				downHoldEnd: {indices: [5]},
				upHoldEnd: {indices: [6]},
				rightHoldEnd: {indices: [7]},
				strumLeft: {indices: [0]},
				strumDown: {indices: [1]},
				strumUp: {indices: [2]},
				strumRight: {indices: [3]},
				strumLeftPress: {indices: [4, 8], framerate: 12},
				strumDownPress: {indices: [5, 9], framerate: 12},
				strumUpPress: {indices: [6, 10], framerate: 12},
				strumRightPress: {indices: [7, 11], framerate: 12},
				strumLeftConfirm: {indices: [12, 16], framerate: 24},
				strumDownConfirm: {indices: [13, 17], framerate: 24},
				strumUpConfirm: {indices: [14, 18], framerate: 24},
				strumRightConfirm: {indices: [15, 19], framerate: 24}
			}
		}, null, "  ");
	}

	public static function exportSplashExample():String
	{
		return Json.stringify({
			name: "Custom Splash",
			author: "Your Name",
			description: "My custom splash",
			assets: {
				path: "noteSplashes",
				type: "sparrow",
				scale: 1.0,
				antialiasing: true,
				offset: [0, 0]
			},
			animations: {
				left: ["note impact 1 purple", "note impact 2 purple"],
				down: ["note impact 1 blue", "note impact 2 blue"],
				up: ["note impact 1 green", "note impact 2 green"],
				right: ["note impact 1 red", "note impact 2 red"],
				framerate: 24,
				randomFramerateRange: 3
			}
		}, null, "  ");
	}
}
