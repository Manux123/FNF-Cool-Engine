package funkin.gameplay.notes;

import extensions.FlxAtlasFramesExt;
import lime.utils.Assets;
import funkin.gameplay.PlayState;
import flixel.FlxG;
import flixel.graphics.frames.FlxAtlasFrames;
import haxe.Json;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

// ==================== TYPEDEFS ====================

typedef NoteSkinData = {
	var name:String;
	var author:String;
	var ?description:String;
	var ?folder:String; // CORREGIDO: Folder específico de esta skin
	var normal:NoteSkinAssets;
	var ?pixel:NoteSkinAssets;
	var ?pixelEnds:NoteSkinAssets; // NUEVO: Para los holds de las notas pixel
	var ?animations:NoteAnimations;
	var ?offsetDefault:Bool;
}

typedef NoteSkinAssets = {
	var path:String;
	var ?type:String; // "sparrow", "packer", "image"
	var ?scale:Float;
	var ?antialiasing:Bool;
}

typedef NoteAnimations = {
	// Notas individuales
	var ?left:String;
	var ?down:String;
	var ?up:String;
	var ?right:String;
	
	// Holds (sustains)
	var ?leftHold:String;
	var ?downHold:String;
	var ?upHold:String;
	var ?rightHold:String;
	
	// Hold ends
	var ?leftHoldEnd:String;
	var ?downHoldEnd:String;
	var ?upHoldEnd:String;
	var ?rightHoldEnd:String;
	
	// Strums (flechas estáticas)
	var ?strumLeft:String;
	var ?strumDown:String;
	var ?strumUp:String;
	var ?strumRight:String;
	
	// Strums pressed
	var ?strumLeftPress:String;
	var ?strumDownPress:String;
	var ?strumUpPress:String;
	var ?strumRightPress:String;
	
	// Strums confirm
	var ?strumLeftConfirm:String;
	var ?strumDownConfirm:String;
	var ?strumUpConfirm:String;
	var ?strumRightConfirm:String;
}

// Splash separado del sistema de notas
typedef NoteSplashData = {
	var name:String;
	var author:String;
	var ?description:String;
	var ?folder:String;
	var assets:NoteSplashAssets;
	var animations:SplashAnimations;
}

typedef NoteSplashAssets = {
	var path:String;
	var ?type:String;
	var ?scale:Float;
	var ?antialiasing:Bool;
	var ?offset:Array<Float>; // [x, y]
}

typedef SplashAnimations = {
	// Prefijos de animación para cada dirección
	var left:Array<String>;
	var down:Array<String>;
	var up:Array<String>;
	var right:Array<String>;
	
	// Configuración adicional
	var ?framerate:Int;
	var ?randomFramerateRange:Int; // ±random range
}

// ==================== SISTEMA PRINCIPAL ====================

class NoteSkinSystem
{
	// Skins de notas
	public static var currentSkin:String = "Default";
	public static var availableSkins:Map<String, NoteSkinData> = new Map<String, NoteSkinData>();
	
	// Splashes (independiente)
	public static var currentSplash:String = "Default";
	public static var availableSplashes:Map<String, NoteSplashData> = new Map<String, NoteSplashData>();
	
	private static var initialized:Bool = false;

	public static var offsetDefault:Bool = true;

	// Rutas
	private static inline var SKINS_PATH:String = "assets/skins";
	private static inline var SPLASHES_PATH:String = "assets/splashes";
	private static inline var DEFAULT_NORMAL:String = "Default/NOTE_assets";
	private static inline var DEFAULT_PIXEL:String = "Default/arrows-pixels";
	private static inline var DEFAULT_PIXEL_ENDS:String = "Default/arrowEnds";
	private static inline var DEFAULT_SPLASH:String = "Default/noteSplashes";

	public static function init():Void
	{
		if (initialized) return;

		trace("Initializing Note Skin System...");
		
		// Descubrir skins y splashes
		discoverSkins();
		discoverSplashes();
		
		// Cargar configuraciones guardadas
		loadSavedSkin();
		loadSavedSplash();
		
		initialized = true;
		trace('Note Skin System initialized.');
		trace('  - Found ${Lambda.count(availableSkins)} note skins');
		trace('  - Found ${Lambda.count(availableSplashes)} splash styles');
	}

	// ==================== DESCUBRIMIENTO DE SKINS ====================

	private static function discoverSkins():Void
	{
		availableSkins.set("Default", getDefaultSkin());

		#if sys
		if (FileSystem.exists(SKINS_PATH) && FileSystem.isDirectory(SKINS_PATH))
		{
			for (skinFolder in FileSystem.readDirectory(SKINS_PATH))
			{
				var skinPath:String = '$SKINS_PATH/$skinFolder';
				
				if (FileSystem.isDirectory(skinPath))
				{
					var configPath:String = '$skinPath/skin.json';
					
					if (FileSystem.exists(configPath))
					{
						try
						{
							var jsonData:String = File.getContent(configPath);
							var skinData:NoteSkinData = Json.parse(jsonData);
							// CORREGIDO: Guardar el folder en la skin data
							skinData.folder = skinFolder;
							availableSkins.set(skinData.name, skinData);
							trace('Loaded note skin: ${skinData.name} from folder: $skinFolder');
							offsetDefault = skinData.offsetDefault;
						}
						catch (e:Dynamic)
						{
							trace('Error loading skin at $configPath: $e');
						}
					}
					else
					{
						var autoSkin:NoteSkinData = autoDetectSkin(skinPath, skinFolder);
						if (autoSkin != null)
						{
							availableSkins.set(autoSkin.name, autoSkin);
							trace('Auto-detected note skin: ${autoSkin.name} from folder: $skinFolder');
						}
					}
				}
			}
		}
		#else
		var skinsList:Array<String> = Assets.list().filter(path -> path.contains("skins/") && path.endsWith("skin.json"));
		
		for (skinPath in skinsList)
		{
			try
			{
				var jsonData:String = Assets.getText(skinPath);
				var skinData:NoteSkinData = Json.parse(jsonData);
				// Extraer folder del path
				var folderMatch = ~/skins\/([^\/]+)\//;
				if (folderMatch.match(skinPath))
				{
					skinData.folder = folderMatch.matched(1);
				}
				availableSkins.set(skinData.name, skinData);
				trace('Loaded note skin: ${skinData.name}');
			}
			catch (e:Dynamic)
			{
				trace('Error loading skin at $skinPath: $e');
			}
		}
		#end
	}

	// ==================== DESCUBRIMIENTO DE SPLASHES ====================

	private static function discoverSplashes():Void
	{
		availableSplashes.set("Default", getDefaultSplash());

		#if sys
		if (FileSystem.exists(SPLASHES_PATH) && FileSystem.isDirectory(SPLASHES_PATH))
		{
			for (splashFolder in FileSystem.readDirectory(SPLASHES_PATH))
			{
				var splashPath:String = '$SPLASHES_PATH/$splashFolder';
				
				if (FileSystem.isDirectory(splashPath))
				{
					var configPath:String = '$splashPath/splash.json';
					
					if (FileSystem.exists(configPath))
					{
						try
						{
							var jsonData:String = File.getContent(configPath);
							var splashData:NoteSplashData = Json.parse(jsonData);
							// CORREGIDO: Guardar el folder en la splash data
							splashData.folder = splashFolder;
							availableSplashes.set(splashData.name, splashData);
							trace('Loaded splash style: ${splashData.name} from folder: $splashFolder');
						}
						catch (e:Dynamic)
						{
							trace('Error loading splash at $configPath: $e');
						}
					}
					else
					{
						var autoSplash:NoteSplashData = autoDetectSplash(splashPath, splashFolder);
						if (autoSplash != null)
						{
							availableSplashes.set(autoSplash.name, autoSplash);
							trace('Auto-detected splash: ${autoSplash.name} from folder: $splashFolder');
						}
					}
				}
			}
		}
		#else
		var splashList:Array<String> = Assets.list().filter(path -> path.contains("splashes/") && path.endsWith("splash.json"));
		
		for (splashPath in splashList)
		{
			try
			{
				var jsonData:String = Assets.getText(splashPath);
				var splashData:NoteSplashData = Json.parse(jsonData);
				// Extraer folder del path
				var folderMatch = ~/splashes\/([^\/]+)\//;
				if (folderMatch.match(splashPath))
				{
					splashData.folder = folderMatch.matched(1);
				}
				availableSplashes.set(splashData.name, splashData);
				trace('Loaded splash style: ${splashData.name}');
			}
			catch (e:Dynamic)
			{
				trace('Error loading splash at $splashPath: $e');
			}
		}
		#end
	}

	// ==================== AUTO-DETECCIÓN ====================

	#if sys
	private static function autoDetectSkin(skinPath:String, folderName:String):NoteSkinData
	{
		var files:Array<String> = FileSystem.readDirectory(skinPath);
		var skinData:NoteSkinData = {
			name: folderName,
			author: "Unknown",
			folder: folderName, // CORREGIDO: Guardar folder
			normal: {
				path: "",
				type: "sparrow"
			}
		};

		for (file in files)
		{
			var lowerFile:String = file.toLowerCase();
			
			if (lowerFile.contains("note") && !lowerFile.contains("pixel") && lowerFile.endsWith(".png"))
			{
				skinData.normal.path = '${file.substr(0, file.length - 4)}';
				
				if (files.indexOf(file.substr(0, file.length - 4) + ".xml") != -1)
					skinData.normal.type = "sparrow";
				else
					skinData.normal.type = "image";
			}
			
			// Detectar notas pixel principales
			if (lowerFile.contains("pixel") && !lowerFile.contains("end") && lowerFile.endsWith(".png"))
			{
				skinData.pixel = {
					path: '${file.substr(0, file.length - 4)}',
					type: "image"
				};
			}
			
			// Detectar holds de notas pixel (arrowEnds, holdEnds, etc.)
			if ((lowerFile.contains("end") || lowerFile.contains("hold")) && lowerFile.contains("pixel") && lowerFile.endsWith(".png"))
			{
				skinData.pixelEnds = {
					path: '${file.substr(0, file.length - 4)}',
					type: "image"
				};
			}
		}

		return skinData.normal.path != "" ? skinData : null;
	}

	private static function autoDetectSplash(splashPath:String, folderName:String):NoteSplashData
	{
		var files:Array<String> = FileSystem.readDirectory(splashPath);
		var splashData:NoteSplashData = null;

		for (file in files)
		{
			var lowerFile:String = file.toLowerCase();
			
			if (lowerFile.contains("splash") && lowerFile.endsWith(".png"))
			{
				var baseName:String = file.substr(0, file.length - 4);
				var hasXml:Bool = files.indexOf(baseName + ".xml") != -1;
				
				splashData = {
					name: folderName,
					author: "Unknown",
					folder: folderName, // CORREGIDO: Guardar folder
					assets: {
						path: '$baseName',
						type: hasXml ? "sparrow" : "image"
					},
					animations: {
						left: ["note impact 1 purple", "note impact 2 purple"],
						down: ["note impact 1 blue", "note impact 2 blue"],
						up: ["note impact 1 green", "note impact 2 green"],
						right: ["note impact 1 red", "note impact 2 red"],
						framerate: 24
					}
				};
				break;
			}
		}

		return splashData;
	}
	#end

	// ==================== DEFAULTS ====================

	private static function getDefaultSkin():NoteSkinData
	{
		return {
			name: "Default",
			author: "ninjamuffin99",
			description: "Default Friday Night Funkin' notes",
			folder: "Default", // CORREGIDO: Folder Default
			normal: {
				path: "NOTE_assets",
				type: "sparrow",
				scale: 0.7,
				antialiasing: true
			},
			pixel: {
				path: "arrows-pixels",
				type: "image",
				antialiasing: false
			},
			pixelEnds: {
				path: "arrowEnds",
				type: "image",
				antialiasing: false
			},
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
				strumLeft: "left arrow",
				strumDown: "down arrow",
				strumUp: "up arrow",
				strumRight: "right arrow",
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

	private static function getDefaultSplash():NoteSplashData
	{
		return {
			name: "Default",
			author: "FNF Team",
			description: "Default note splash effects",
			folder: "Default", // CORREGIDO: Folder Default
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

	// ==================== CARGA/GUARDADO ====================

	private static function loadSavedSkin():Void
	{
		if (FlxG.save.data.noteSkin != null && availableSkins.exists(FlxG.save.data.noteSkin))
		{
			currentSkin = FlxG.save.data.noteSkin;
		}
		else
		{
			currentSkin = "Default";
			FlxG.save.data.noteSkin = "Default";
		}
		
		FlxG.save.flush();
	}

	private static function loadSavedSplash():Void
	{
		if (FlxG.save.data.noteSplash != null && availableSplashes.exists(FlxG.save.data.noteSplash))
		{
			currentSplash = FlxG.save.data.noteSplash;
		}
		else
		{
			currentSplash = "Default";
			FlxG.save.data.noteSplash = "Default";
		}
		
		FlxG.save.flush();
	}

	// ==================== SETTERS ====================

	public static function setSkin(skinName:String):Bool
	{
		if (availableSkins.exists(skinName))
		{
			currentSkin = skinName;
			FlxG.save.data.noteSkin = skinName;
			FlxG.save.flush();
			trace('Changed note skin to: $skinName');
			return true;
		}
		else
		{
			trace('Note skin "$skinName" not found!');
			return false;
		}
	}

	/**
	 * Aplica una skin SOLO para esta sesión sin tocar FlxG.save.
	 * Úsalo desde PlayState con el noteSkin del meta.json.
	 * Al salir de la canción llama restoreGlobalSkin() para volver
	 * a la preferencia global del jugador.
	 */
	public static function setTemporarySkin(skinName:String):Void
	{
		if (!initialized) init();

		// "default" y "" se resuelven a la skin global guardada
		if (skinName == null || skinName == '' || skinName == 'default')
		{
			currentSkin = FlxG.save.data.noteSkin != null ? FlxG.save.data.noteSkin : 'Default';
			trace('[NoteSkinSystem] setTemporarySkin → usando global: $currentSkin');
			return;
		}

		// Buscar la skin por nombre exacto o case-insensitive
		if (availableSkins.exists(skinName))
		{
			currentSkin = skinName;
			trace('[NoteSkinSystem] setTemporarySkin → "$skinName"');
		}
		else
		{
			// Intento case-insensitive
			for (key in availableSkins.keys())
			{
				if (key.toLowerCase() == skinName.toLowerCase())
				{
					currentSkin = key;
					trace('[NoteSkinSystem] setTemporarySkin → "$key" (matched "$skinName")');
					return;
				}
			}
			// No encontrada: usa la global
			currentSkin = FlxG.save.data.noteSkin != null ? FlxG.save.data.noteSkin : 'Default';
			trace('[NoteSkinSystem] setTemporarySkin → skin "$skinName" no encontrada, usando global: $currentSkin');
		}
	}

	/**
	 * Restaura la skin que el jugador tiene guardada globalmente.
	 * Llámalo en PlayState.destroy() para que al volver al menú
	 * todo siga con la preferencia del jugador.
	 */
	public static function restoreGlobalSkin():Void
	{
		currentSkin = FlxG.save.data.noteSkin != null ? FlxG.save.data.noteSkin : 'Default';
		trace('[NoteSkinSystem] restoreGlobalSkin → $currentSkin');
	}

	public static function setSplash(splashName:String):Bool
	{
		if (availableSplashes.exists(splashName))
		{
			currentSplash = splashName;
			FlxG.save.data.noteSplash = splashName;
			FlxG.save.flush();
			trace('Changed splash style to: $splashName');
			return true;
		}
		else
		{
			trace('Splash style "$splashName" not found!');
			return false;
		}
	}

	// ==================== GETTERS - SKINS ====================

	public static function getNoteSkin(?skinName:String):FlxAtlasFrames
	{
		if (!initialized) init();

		var skin:String = skinName != null ? skinName : currentSkin;
		var skinData:NoteSkinData = availableSkins.get(skin);

		if (skinData == null)
		{
			trace('Skin "$skin" not found, using Default');
			skinData = availableSkins.get("Default");
		}

		return loadAtlas(skinData.normal, skinData.folder);
	}

	public static function getPixelNoteSkin(?skinName:String):FlxAtlasFrames
	{
		if (!initialized) init();

		var skin:String = skinName != null ? skinName : currentSkin;
		var skinData:NoteSkinData = availableSkins.get(skin);

		if (skinData == null || skinData.pixel == null)
		{
			trace('Pixel skin not found for "$skin", using Default');
			skinData = availableSkins.get("Default");
		}

		return loadAtlas(skinData.pixel != null ? skinData.pixel : skinData.normal, skinData.folder);
	}

	// NUEVO: Getter para los holds de notas pixel
	public static function getPixelNoteEnds(?skinName:String):FlxAtlasFrames
	{
		if (!initialized) init();

		var skin:String = skinName != null ? skinName : currentSkin;
		var skinData:NoteSkinData = availableSkins.get(skin);

		if (skinData == null || skinData.pixelEnds == null)
		{
			trace('Pixel ends not found for "$skin", using Default');
			skinData = availableSkins.get("Default");
		}

		return loadAtlas(skinData.pixelEnds != null ? skinData.pixelEnds : skinData.pixel, skinData.folder);
	}

	public static function getSkinAnimations(?skinName:String):NoteAnimations
	{
		if (!initialized) init();

		var skin:String = skinName != null ? skinName : currentSkin;
		var skinData:NoteSkinData = availableSkins.get(skin);

		if (skinData == null || skinData.animations == null)
		{
			skinData = availableSkins.get("Default");
		}

		return skinData.animations;
	}

	// ==================== GETTERS - SPLASHES ====================

	public static function getSplashTexture(?splashName:String):FlxAtlasFrames
	{
		if (!initialized) init();

		var splash:String = splashName != null ? splashName : currentSplash;
		var splashData:NoteSplashData = availableSplashes.get(splash);

		if (splashData == null)
		{
			trace('Splash "$splash" not found, using Default');
			splashData = availableSplashes.get("Default");
		}

		// Para splashes, el folder está en assets/splashes/ no en assets/skins/
		return loadAtlasSplash(splashData.assets, splashData.folder);
	}

	public static function getSplashAnimations(?splashName:String):SplashAnimations
	{
		if (!initialized) init();

		var splash:String = splashName != null ? splashName : currentSplash;
		var splashData:NoteSplashData = availableSplashes.get(splash);

		if (splashData == null)
		{
			trace('Splash "$splash" not found, using Default');
			splashData = availableSplashes.get("Default");
		}

		return splashData.animations;
	}

	public static function getSplashData(?splashName:String):NoteSplashData
	{
		if (!initialized) init();

		var splash:String = splashName != null ? splashName : currentSplash;
		var splashData:NoteSplashData = availableSplashes.get(splash);

		if (splashData == null)
		{
			splashData = availableSplashes.get("Default");
		}

		return splashData;
	}

	// ==================== UTILIDADES ====================

	private static function loadAtlas(assets:Dynamic, ?folderName:String):FlxAtlasFrames
	{
		if (assets == null || assets.path == null)
		{
			trace('Invalid assets, loading default');
			return Paths.skinSprite('Default/NOTE_assets');
		}

		var path:String = assets.path;
		var type:String = assets.type != null ? assets.type : "sparrow";
		var folder:String = folderName != null ? folderName : "Default";

		if (!assetExists(path, folder))
		{
			trace('Asset not found at $folder/$path, loading default');
			return Paths.skinSprite('Default/NOTE_assets');
		}

		try
		{
			trace('Loading atlas: $folder/$path (type: $type)');
			switch (type.toLowerCase())
			{
				case "sparrow":
					return Paths.skinSprite('$folder/$path');
				
				case "packer":
					return Paths.skinSpriteTxt('$folder/$path');
				
				case "image":
					var graphic = FlxG.bitmap.add('assets/skins/$folder/$path.png');
					
					// Detect the type of image pixel
					var cols:Int = 17;
					var rows:Int = 17;
					
					// arrows-pixels.png is 7x7, arrowEnds.png is 8x2
					var pathLower:String = path.toLowerCase();
					if (pathLower.contains("end") || pathLower.contains("hold"))
					{
						cols = 7;
						rows = 6;
						trace('Detected pixel holds/ends: $cols×$rows');
					}
					else
					{
						trace('Detected pixel notes: $cols×$rows');
					}
					
					return FlxAtlasFramesExt.fromGraphic(graphic, cols, rows);
				default:
					trace('Unknown atlas type: $type, using sparrow');
					return Paths.skinSprite('$folder/$path');
			}
		}
		catch (e:Dynamic)
		{
			trace('Error loading atlas at $folder/$path: $e');
			return Paths.skinSprite('Default/NOTE_assets');
		}
	}

	// NUEVO: Método específico para cargar splashes (que están en assets/splashes/)
	private static function loadAtlasSplash(assets:Dynamic, ?folderName:String):FlxAtlasFrames
	{
		if (assets == null || assets.path == null)
		{
			trace('Invalid splash assets, loading default');
			return Paths.splashSprite('Default/noteSplashes');
		}

		var path:String = assets.path;
		var type:String = assets.type != null ? assets.type : "sparrow";
		var folder:String = folderName != null ? folderName : "Default";

		if (!splashAssetExists(path, folder))
		{
			trace('Splash asset not found at $folder/$path, loading default');
			return Paths.splashSprite('Default/noteSplashes');
		}

		try
		{
			trace('Loading splash atlas: $folder/$path (type: $type)');
			switch (type.toLowerCase())
			{
				case "sparrow":
					return Paths.splashSprite('$folder/$path');
				
				case "packer":
					return FlxAtlasFrames.fromSpriteSheetPacker(
						FlxG.bitmap.add('assets/splashes/$folder/$path.png'),
						'assets/splashes/$folder/$path.txt'
					);
				
				case "image":
					var graphic = FlxG.bitmap.add('assets/splashes/$folder/$path.png');
					return FlxAtlasFramesExt.fromGraphic(graphic, graphic.width, graphic.height);
				
				default:
					trace('Unknown atlas type: $type, using sparrow');
					return Paths.splashSprite('$folder/$path');
			}
		}
		catch (e:Dynamic)
		{
			trace('Error loading splash atlas at $folder/$path: $e');
			return Paths.splashSprite('Default/noteSplashes');
		}
	}

	private static function assetExists(path:String, folder:String):Bool
	{
		#if sys
		return FileSystem.exists('assets/skins/$folder/$path.png') || FileSystem.exists('$path.png');
		#else
		return Assets.exists('assets/skins/$folder/$path.png');
		#end
	}

	private static function splashAssetExists(path:String, folder:String):Bool
	{
		#if sys
		return FileSystem.exists('assets/splashes/$folder/$path.png') || FileSystem.exists('$path.png');
		#else
		return Assets.exists('assets/splashes/$folder/$path.png');
		#end
	}

	// ==================== HOLD COVERS ====================
	
	/**
	 * NUEVO: Verificar si existe holdCover para un color específico en el splash actual
	 */
	public static function holdCoverExists(color:String, ?splashName:String):Bool
	{
		if (!initialized) init();
		
		var splash:String = splashName != null ? splashName : currentSplash;
		var splashData:NoteSplashData = availableSplashes.get(splash);
		
		if (splashData == null)
			splashData = availableSplashes.get("Default");
		
		var folder:String = splashData.folder != null ? splashData.folder : "Default";
		var path:String = 'holdCover$color';
		
		return splashAssetExists(path, folder);
	}
	
	/**
	 * NUEVO: Obtener texture de holdCover para un color específico
	 */
	public static function getHoldCoverTexture(color:String, ?splashName:String):FlxAtlasFrames
	{
		if (!initialized) init();
		
		var splash:String = splashName != null ? splashName : currentSplash;
		var splashData:NoteSplashData = availableSplashes.get(splash);
		
		if (splashData == null)
		{
			trace('Splash "$splash" not found, using Default');
			splashData = availableSplashes.get("Default");
		}
		
		var folder:String = splashData.folder != null ? splashData.folder : "Default";
		var path:String = 'holdCover$color';
		
		// Verificar si existe
		if (!splashAssetExists(path, folder))
		{
			trace('HoldCover not found for color $color in folder $folder');
			return null;
		}
		
		try
		{
			trace('Loading holdCover: $folder/$path');
			return Paths.splashSprite('$folder/$path');
		}
		catch (e:Dynamic)
		{
			return Paths.splashSprite('Default/'+path);
			trace('Error loading holdCover at $folder/$path: $e');
		}
	}
	
	/**
	 * NUEVO: Obtener el folder del splash actual (para debug)
	 */
	public static function getCurrentSplashFolder():String
	{
		if (!initialized) init();
		
		var splashData:NoteSplashData = availableSplashes.get(currentSplash);
		
		if (splashData == null)
			splashData = availableSplashes.get("Default");
		
		return splashData.folder != null ? splashData.folder : "Default";
	}

	// ==================== LISTAS ====================

	public static function getSkinList():Array<String>
	{
		if (!initialized) init();
		
		var skins:Array<String> = [];
		for (key in availableSkins.keys())
		{
			skins.push(key);
		}
		return skins;
	}

	public static function getSplashList():Array<String>
	{
		if (!initialized) init();
		
		var splashes:Array<String> = [];
		for (key in availableSplashes.keys())
		{
			splashes.push(key);
		}
		return splashes;
	}

	public static function getSkinInfo(skinName:String):NoteSkinData
	{
		if (!initialized) init();
		return availableSkins.get(skinName);
	}

	public static function getSplashInfo(splashName:String):NoteSplashData
	{
		if (!initialized) init();
		return availableSplashes.get(splashName);
	}

	// ==================== EXPORT EXAMPLES ====================

	public static function exportSkinExample():String
	{
		var example:NoteSkinData = {
			name: "Custom Skin",
			author: "Your Name",
			description: "My custom note skin",
			normal: {
				path: "skins/custom/notes",
				type: "sparrow",
				scale: 0.7,
				antialiasing: true
			},
			pixel: {
				path: "skins/custom/notes-pixel",
				type: "image",
				antialiasing: false
			},
			pixelEnds: {
				path: "skins/custom/notes-pixel-ends",
				type: "image",
				antialiasing: false
			},
			animations: {
				left: "purple note",
				down: "blue note",
				up: "green note",
				right: "red note",
				leftHold: "purple hold",
				downHold: "blue hold",
				upHold: "green hold",
				rightHold: "red hold",
				leftHoldEnd: "purple tail",
				downHoldEnd: "blue tail",
				upHoldEnd: "green tail",
				rightHoldEnd: "red tail",
				strumLeft: "left arrow",
				strumDown: "down arrow",
				strumUp: "up arrow",
				strumRight: "right arrow",
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

		return Json.stringify(example, null, "  ");
	}

	public static function exportSplashExample():String
	{
		var example:NoteSplashData = {
			name: "Custom Splash",
			author: "Your Name",
			description: "My custom splash effect",
			assets: {
				path: "splashes/custom/splash",
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

		return Json.stringify(example, null, "  ");
	}
}