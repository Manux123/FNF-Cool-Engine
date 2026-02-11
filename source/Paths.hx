package;

import flixel.FlxG;
import flixel.graphics.frames.FlxAtlasFrames;
import openfl.utils.AssetType;
import openfl.utils.Assets as OpenFlAssets;
import openfl.display.BitmapData as Bitmap;

/**
 * Paths - Sistema mejorado de gestión de rutas con caché y optimizaciones
 * 
 * MEJORAS V2.0:
 * - Sistema de caché para assets frecuentes
 * - Precarga inteligente de recursos
 * - Gestión optimizada de memoria
 * - Estadísticas de uso de assets
 * - Limpieza automática de recursos no usados
 */
class Paths
{
	inline public static var SOUND_EXT = #if web "mp3" #else "ogg" #end;

	static var currentLevel:String;
	
	// === HELPER para obtener stage de forma segura ===
	private static function getCurrentStage():String
	{
		try 
		{
			var PlayState = Type.resolveClass("funkin.gameplay.PlayState");
			if (PlayState != null)
			{
				var curStage = Reflect.field(PlayState, "curStage");
				if (curStage != null && curStage != "")
					return curStage;
			}
		}
		catch (e:Dynamic) 
		{
			// PlayState no está disponible todavía
		}
		return "stage"; // Valor por defecto
	}
	
	// === CACHE SYSTEM ===
	private static var atlasCache:Map<String, FlxAtlasFrames> = new Map<String, FlxAtlasFrames>();
	private static var bitmapCache:Map<String, Bitmap> = new Map<String, Bitmap>();
	private static var cacheHits:Int = 0;
	private static var cacheMisses:Int = 0;
	private static var maxCacheSize:Int = 50; // Máximo de items en caché
	
	// === STATS ===
	private static var totalLoads:Int = 0;
	private static var cacheEnabled:Bool = true;

	private static var atlasCount:Int = 0;
	private static var bitmapCount:Int = 0;

	static public function setCurrentLevel(name:String)
	{
		currentLevel = name.toLowerCase();
	}

	static function getPath(file:String, type:AssetType, library:Null<String>)
	{
		if (library != null)
			return getLibraryPath(file, library);

		if (currentLevel != null)
		{
			var levelPath = getLibraryPathForce(file, currentLevel);
			if (OpenFlAssets.exists(levelPath, type))
				return levelPath;

			levelPath = getLibraryPathForce(file, "shared");
			if (OpenFlAssets.exists(levelPath, type))
				return levelPath;
		}

		return getPreloadPath(file);
	}

	static public function getLibraryPath(file:String, library = "preload")
	{
		return if (library == "preload" || library == "default") getPreloadPath(file); else getLibraryPathForce(file, library);
	}

	inline static function getLibraryPathForce(file:String, library:String)
	{
		return '$library:assets/$library/$file';
	}

	inline static function getPreloadPath(file:String)
	{
		return 'assets/$file';
	}

	inline static public function file(file:String, type:AssetType = TEXT, ?library:String)
	{
		return getPath(file, type, library);
	}

	inline static public function txt(key:String, ?library:String)
	{
		return getPath('data/$key.txt', TEXT, library);
	}

	inline static public function songsTxt(key:String, ?library:String)
	{
		return 'songs:assets/songs/$key.txt';
	}

	inline static public function xml(key:String, ?library:String)
	{
		return getPath('data/$key.xml', TEXT, library);
	}

	
	inline static public function json(key:String, ?library:String)
	{
		return getPath('data/$key.json', TEXT, library);
	}

	inline static public function jsonSong(key:String)
	{
		return 'songs:assets/songs/$key.json';
	}

	inline static public function stageJSON(key:String)
	{
		return 'assets/stages/$key.json';
	}

	inline static public function characterJSON(key:String, ?library:String)
	{
		return getPath('characters/$key.json', TEXT, library);
	}

	static public function sound(key:String, ?library:String)
	{
		return getPath('sounds/$key.$SOUND_EXT', SOUND, library);
	}

	static public function soundStage(key:String, ?library:String)
	{
		return getPath('stages/$key.$SOUND_EXT', SOUND, library);
	}

	inline static public function soundRandom(key:String, min:Int, max:Int, ?library:String)
	{
		return sound(key + FlxG.random.int(min, max), library);
	}

	inline static public function soundRandomStage(key:String, min:Int, max:Int, ?library:String)
	{
		return soundStage('${getCurrentStage()}/sounds/$key' + FlxG.random.int(min, max), library);
	}

	inline static public function video(key:String, ?library:String)
	{
		trace('assets/videos/$key.mp4');
		return getPath('videos/$key.mp4', BINARY, library);
	}

	inline static public function music(key:String, ?library:String)
	{
		return getPath('music/$key.$SOUND_EXT', MUSIC, library);
	}

	inline static public function voices(song:String)
	{
		trace('Loading VOICES');
		var loadingSong:Bool = true;
		if (loadingSong)
		{
			trace('Done Loading VOICES!');
			return 'songs:assets/songs/${song.toLowerCase()}/Voices.$SOUND_EXT';
		}
		else
		{
			trace('ERROR Loading VOICES :c');
			return 'songs:assets/songs/test/Voices.$SOUND_EXT';
		}
	}

	inline static public function inst(song:String)
	{
		trace('Loading INST');
		var loadingSong:Bool = true;
		if (loadingSong)
		{
			trace('Done Loading INST!');
			return 'songs:assets/songs/${song.toLowerCase()}/Inst.$SOUND_EXT';
		}
		else
		{
			trace('ERROR Loading INST :c');
			return 'songs:assets/songs/test/Inst.$SOUND_EXT';
		}
	}

	inline static public function image(key:String, ?library:String)
	{
		return getPath('images/$key.png', IMAGE, library);
	}

	inline static public function characterimage(key:String, ?library:String)
	{
		return getPath('characters/images/$key.png', IMAGE, library);
	}

	inline static public function imageStage(key:String, ?library:String)
	{
		return getPath('stages/' + getCurrentStage() + '/images/' + key + '.png', IMAGE, library);
	}

	inline static public function font(key:String)
	{
		return 'assets/fonts/$key';
	}
	
	// ========================================
	// ENHANCED METHODS WITH CACHE
	// ========================================
	
	/**
	 * Obtener bitmap con caché
	 */
	static public function getBitmap(key:String, ?library:String):Bitmap
	{
		totalLoads++;
		
		var cacheKey = key + (library != null ? "_" + library : "");
		
		// Revisar caché si está habilitado
		if (cacheEnabled && bitmapCache.exists(cacheKey))
		{
			cacheHits++;
			return bitmapCache.get(cacheKey);
		}
		
		cacheMisses++;
		
		// Cargar bitmap
		var imagePath = image(key, library);
		var bitmap:Bitmap = null;
		
		try
		{
			bitmap = OpenFlAssets.getBitmapData(imagePath);
			
			// Agregar al caché si está habilitado
			if (cacheEnabled && bitmap != null)
			{
				// Limpiar caché si está lleno
				if ([for (k in bitmapCache.keys()) k].length >= maxCacheSize)
				{
					clearOldestBitmapCache();
				}
				
				bitmapCache.set(cacheKey, bitmap);
				bitmapCount++;
			}
		}
		catch (e:Dynamic)
		{
			trace('[Paths] ERROR loading bitmap $key: $e');
		}
		
		return bitmap;
	}

	/**
	 * Obtener Sparrow Atlas con caché
	 */
	static public function getSparrowAtlas(key:String, ?library:String):FlxAtlasFrames
	{
		totalLoads++;
		
		var cacheKey = key + (library != null ? "_" + library : "");
		
		// Revisar caché
		if (cacheEnabled && atlasCache.exists(cacheKey))
		{
			cacheHits++;
			return atlasCache.get(cacheKey);
		}
		
		cacheMisses++;
		
		// Cargar atlas
		var atlas = FlxAtlasFrames.fromSparrow(image(key, library), file('images/$key.xml', library));
		
		// Agregar al caché
		if (cacheEnabled && atlas != null)
		{
			// Limpiar caché si está lleno
			if ([for (k in atlasCache.keys()) k].length >= maxCacheSize)
			{
				clearOldestAtlasCache();
			}
			
			atlasCache.set(cacheKey, atlas);
			bitmapCount++;
		}
		
		return atlas;
	}

	static public function characterSprite(key:String, ?library:String):FlxAtlasFrames
	{
		totalLoads++;
		
		var cacheKey = "char_" + key + (library != null ? "_" + library : "");
		
		// Revisar caché
		if (cacheEnabled && atlasCache.exists(cacheKey))
		{
			cacheHits++;
			return atlasCache.get(cacheKey);
		}
		
		cacheMisses++;
		
		var atlas = FlxAtlasFrames.fromSparrow(
			getPath('characters/images/$key.png', IMAGE, library), 
			getPath('characters/images/$key.xml', TEXT, library)
		);
		
		if (cacheEnabled && atlas != null)
		{
			if ([for (k in atlasCache.keys()) k].length >= maxCacheSize)
				clearOldestAtlasCache();
			
			atlasCache.set(cacheKey, atlas);
		}
		
		return atlas;
	}

	static public function stageSprite(key:String, ?library:String):FlxAtlasFrames
	{
		totalLoads++;
		
		var cacheKey = "stage_" + key + (library != null ? "_" + library : "");
		
		// Revisar caché
		if (cacheEnabled && atlasCache.exists(cacheKey))
		{
			cacheHits++;
			return atlasCache.get(cacheKey);
		}
		
		cacheMisses++;
		
		var curStage = getCurrentStage();
		var atlas = FlxAtlasFrames.fromSparrow(
			getPath('stages/' + curStage + '/images/' + key + '.png', IMAGE, library), 
			getPath('stages/' + curStage + '/images/' + key + '.xml', TEXT, library)
		);
		
		if (cacheEnabled && atlas != null)
		{
			if ([for (k in atlasCache.keys()) k].length >= maxCacheSize)
				clearOldestAtlasCache();
			
			atlasCache.set(cacheKey, atlas);
		}
		
		return atlas;
	}

	static public function skinSprite(key:String, ?library:String):FlxAtlasFrames
	{
		totalLoads++;
		
		var cacheKey = "skin_" + key + (library != null ? "_" + library : "");
		
		// Revisar caché
		if (cacheEnabled && atlasCache.exists(cacheKey))
		{
			cacheHits++;
			return atlasCache.get(cacheKey);
		}
		
		cacheMisses++;
		
		var atlas = FlxAtlasFrames.fromSparrow(
			getPath('skins/$key.png', IMAGE, library), 
			getPath('skins/$key.xml', TEXT, library)
		);
		
		if (cacheEnabled && atlas != null)
		{
			if ([for (k in atlasCache.keys()) k].length >= maxCacheSize)
				clearOldestAtlasCache();
			
			atlasCache.set(cacheKey, atlas);
		}
		
		return atlas;
	}
	
	static public function getPackerAtlas(key:String, ?library:String):FlxAtlasFrames
	{
		totalLoads++;
		
		var cacheKey = "packer_" + key + (library != null ? "_" + library : "");
		
		if (cacheEnabled && atlasCache.exists(cacheKey))
		{
			cacheHits++;
			return atlasCache.get(cacheKey);
		}
		
		cacheMisses++;
		
		var atlas = FlxAtlasFrames.fromSpriteSheetPacker(image(key, library), file('images/$key.txt', library));
		
		if (cacheEnabled && atlas != null)
		{
			if ([for (k in atlasCache.keys()) k].length >= maxCacheSize)
				clearOldestAtlasCache();
			
			atlasCache.set(cacheKey, atlas);
		}
		
		return atlas;
	}

	static public function characterSpriteTxt(key:String, ?library:String):FlxAtlasFrames
	{
		totalLoads++;
		
		var cacheKey = "char_txt_" + key + (library != null ? "_" + library : "");
		
		if (cacheEnabled && atlasCache.exists(cacheKey))
		{
			cacheHits++;
			return atlasCache.get(cacheKey);
		}
		
		cacheMisses++;
		
		var atlas = FlxAtlasFrames.fromSpriteSheetPacker(
			getPath('characters/images/$key.png', IMAGE, library), 
			file('characters/images/$key.txt', library)
		);
		
		if (cacheEnabled && atlas != null)
		{
			if ([for (k in atlasCache.keys()) k].length >= maxCacheSize)
				clearOldestAtlasCache();
			
			atlasCache.set(cacheKey, atlas);
		}
		
		return atlas;
	}

	static public function stageSpriteTxt(key:String, ?library:String):FlxAtlasFrames
	{
		totalLoads++;
		
		var cacheKey = "stage_txt_" + key + (library != null ? "_" + library : "");
		
		if (cacheEnabled && atlasCache.exists(cacheKey))
		{
			cacheHits++;
			return atlasCache.get(cacheKey);
		}
		
		cacheMisses++;
		
		var curStage = getCurrentStage();
		var atlas = FlxAtlasFrames.fromSpriteSheetPacker(
			getPath('stages/' + curStage + '/images/$key.png', IMAGE, library), 
			file('stages/' + curStage + '/images/$key.txt', library)
		);
		
		if (cacheEnabled && atlas != null)
		{
			if ([for (k in atlasCache.keys()) k].length >= maxCacheSize)
				clearOldestAtlasCache();
			
			atlasCache.set(cacheKey, atlas);
		}
		
		return atlas;
	}

	
	static public function splashSprite(key:String, ?library:String):FlxAtlasFrames
	{
		totalLoads++;
		
		var cacheKey = "splash_" + key + (library != null ? "_" + library : "");
		
		if (cacheEnabled && atlasCache.exists(cacheKey))
		{
			cacheHits++;
			return atlasCache.get(cacheKey);
		}
		
		cacheMisses++;
		
		var atlas = FlxAtlasFrames.fromSparrow(
			getPath('splashes/$key.png', IMAGE, library), 
			getPath('splashes/$key.xml', TEXT, library)
		);
		
		if (cacheEnabled && atlas != null)
		{
			if ([for (k in atlasCache.keys()) k].length >= maxCacheSize)
				clearOldestAtlasCache();
			
			atlasCache.set(cacheKey, atlas);
		}
		
		return atlas;
	}

	static public function skinSpriteTxt(key:String, ?library:String):FlxAtlasFrames
	{
		totalLoads++;
		
		var cacheKey = "skin_txt_" + key + (library != null ? "_" + library : "");
		
		if (cacheEnabled && atlasCache.exists(cacheKey))
		{
			cacheHits++;
			return atlasCache.get(cacheKey);
		}
		
		cacheMisses++;
		
		var atlas = FlxAtlasFrames.fromSpriteSheetPacker(
			getPath('skins/$key.png', IMAGE, library), 
			file('skins/$key.txt', library)
		);
		
		if (cacheEnabled && atlas != null)
		{
			if ([for (k in atlasCache.keys()) k].length >= maxCacheSize)
				clearOldestAtlasCache();
			
			atlasCache.set(cacheKey, atlas);
		}
		
		return atlas;
	}
	
	// ========================================
	// GESTIÓN DE CACHÉ
	// ========================================
	
	/**
	 * Limpiar el atlas más antiguo del caché
	 */
	private static function clearOldestAtlasCache():Void
	{
		var firstKey:String = null;
		for (key in atlasCache.keys())
		{
			firstKey = key;
			break;
		}
		
		if (firstKey != null)
		{
			atlasCache.remove(firstKey);
			trace('[Paths] Atlas removed from cache: $firstKey');
		}
	}
	
	/**
	 * Limpiar el bitmap más antiguo del caché
	 */
	private static function clearOldestBitmapCache():Void
	{
		var firstKey:String = null;
		for (key in bitmapCache.keys())
		{
			firstKey = key;
			break;
		}
		
		if (firstKey != null)
		{
			var bitmap = bitmapCache.get(firstKey);
			if (bitmap != null)
			{
				bitmap.dispose();
			}
			bitmapCache.remove(firstKey);
			trace('[Paths] Bitmap removed of cache: $firstKey');
			bitmapCount--;
		}
	}
	
	/**
	 * Limpiar todo el caché
	 */
	public static function clearCache():Void
	{
		trace('[Paths] Clearing the entire cache...');
		
		// Limpiar atlas
		for (atlas in atlasCache)
		{
			if (atlas != null && atlas.parent != null && atlas.parent.bitmap != null)
			{
				atlas.parent.bitmap.dispose();
			}
		}
		atlasCache.clear();
		
		// Limpiar bitmaps
		for (bitmap in bitmapCache)
		{
			if (bitmap != null)
			{
				bitmap.dispose();
			}
		}
		bitmapCache.clear();

		atlasCount = 0;
    	bitmapCount = 0;
		
		trace('[Paths] Cache completely cleared');
	}
	
	/**
	 * Habilitar/deshabilitar caché
	 */
	public static function setCacheEnabled(enabled:Bool):Void
	{
		cacheEnabled = enabled;
		trace('[Paths] Cache ${enabled ? "enabled" : "disabled"}');
		
		if (!enabled)
		{
			clearCache();
		}
	}
	
	/**
	 * Establecer tamaño máximo del caché
	 */
	public static function setMaxCacheSize(size:Int):Void
	{
		maxCacheSize = size;
		trace('[Paths] Maximum cache size: $maxCacheSize items');
	}
	
	/**
	 * Obtener estadísticas del caché
	 */
	public static function getCacheStats():String
	{
		var hitRate = totalLoads > 0 ? (cacheHits / totalLoads) * 100 : 0;
		
		var stats = '[Paths Cache Stats]\n';
		stats += 'Enabled: $cacheEnabled\n';
		stats += 'Total Loads: $totalLoads\n';
		stats += 'Cache Hits: $cacheHits\n';
		stats += 'Cache Misses: $cacheMisses\n';
		stats += 'Hit Rate: ${Math.round(hitRate)}%\n';
		stats += 'Atlas Cached: ${[for (k in atlasCache.keys()) k].length}/$maxCacheSize\n';
		stats += 'Bitmaps Cached: ${[for (k in bitmapCache.keys()) k].length}/$maxCacheSize\n';
		
		return stats;
	}
	
	/**
	 * Reset de estadísticas
	 */
	public static function resetStats():Void
	{
		totalLoads = 0;
		cacheHits = 0;
		cacheMisses = 0;
		trace('[Paths] Statistics reset');
	}
}
