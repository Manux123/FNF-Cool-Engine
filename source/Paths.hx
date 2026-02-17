package;

import flixel.FlxG;
import flixel.graphics.frames.FlxAtlasFrames;
import openfl.utils.AssetType;
import openfl.utils.Assets as OpenFlAssets;
import openfl.display.BitmapData as Bitmap;

#if sys
import sys.FileSystem;
#end


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

	static function getPath(file:String, type:AssetType)
	{
		if (currentLevel != null)
		{
			var levelPath = getPreloadPath(file);
			if (OpenFlAssets.exists(levelPath, type))
				return levelPath;
		}

		return getPreloadPath(file);
	}

	inline static function getPreloadPath(file:String)
	{
		return 'assets/$file';
	}

	inline static public function file(file:String, type:AssetType = TEXT)
	{
		return getPath(file, type);
	}

	inline static public function txt(key:String)
	{
		return getPath('data/$key.txt', TEXT);
	}

	inline static public function songsTxt(key:String)
	{
		return 'assets/songs/$key.txt';
	}

	inline static public function xml(key:String)
	{
		return getPath('data/$key.xml', TEXT);
	}

	
	inline static public function json(key:String)
	{
		return getPath('data/$key.json', TEXT);
	}

	inline static public function jsonSong(key:String)
	{
		return 'assets/songs/$key.json';
	}

	inline static public function stageJSON(key:String)
	{
		return 'assets/stages/$key.json';
	}

	inline static public function characterJSON(key:String)
	{
		return getPath('characters/$key.json', TEXT);
	}

	static public function sound(key:String)
	{
		return getPath('sounds/$key.$SOUND_EXT', SOUND);
	}

	static public function soundStage(key:String)
	{
		return getPath('stages/$key.$SOUND_EXT', SOUND);
	}

	inline static public function soundRandom(key:String, min:Int, max:Int)
	{
		return sound(key + FlxG.random.int(min, max));
	}

	inline static public function soundRandomStage(key:String, min:Int, max:Int)
	{
		return soundStage('${getCurrentStage()}/sounds/$key' + FlxG.random.int(min, max));
	}

	inline static public function video(key:String)
	{
		trace('assets/videos/$key.mp4');
		return getPath('cutscenes/videos/$key.mp4', BINARY);
	}

	inline static public function music(key:String)
	{
		return getPath('music/$key.$SOUND_EXT', MUSIC);
	}

	inline static public function voices(song:String)
	{
		var songKey:String = song.toLowerCase();
		var path:String = 'assets/songs/$songKey/Voices.$SOUND_EXT';
		
		#if sys
		// Esto detecta archivos agregados sin compilar
		if (FileSystem.exists(path))
			return path;
		#end

		return path; 
	}

	inline static public function inst(song:String)
	{
		var songKey:String = song.toLowerCase();
		var path:String = 'assets/songs/$songKey/Inst.$SOUND_EXT';
		
		#if sys
		// Si el archivo existe en la carpeta, lo devuelve aunque el juego no lo "conozca"
		if (FileSystem.exists(path))
			return path;
		#end

		return path;
	}

	/**
	 * Carga el instrumental de una canción de forma segura
	 * Soporta archivos externos agregados sin compilar
	 */
	static public function loadInst(song:String):flixel.sound.FlxSound
	{
		var songKey:String = song.toLowerCase();
		var path:String = 'assets/songs/$songKey/Inst.$SOUND_EXT';
		
		#if sys
		// Si el archivo existe físicamente, cargarlo desde el sistema de archivos
		if (FileSystem.exists(path))
		{
			trace('[Paths] Loading external Inst from file system: $path');
			var sound = new flixel.sound.FlxSound();
			// loadStream carga directamente desde el sistema de archivos
			sound.loadStream(path);
			return sound;
		}
		#end
		
		// Archivo en el asset manifest - usar método normal con Paths.inst()
		trace('[Paths] Loading embedded Inst from assets: $path');
		var sound = new flixel.sound.FlxSound();
		
		// Intentar cargar desde assets embebidos
		try 
		{
			sound.loadEmbedded(inst(song), false, false);
		}
		catch (e:Dynamic)
		{
			trace('[Paths] ERROR loading Inst: $e');
		}
		
		return sound;
	}

	/**
	 * Carga las voces de una canción de forma segura
	 * Soporta archivos externos agregados sin compilar
	 */
	static public function loadVoices(song:String):flixel.sound.FlxSound
	{
		var songKey:String = song.toLowerCase();
		var path:String = 'assets/songs/$songKey/Voices.$SOUND_EXT';
		
		#if sys
		// Si el archivo existe físicamente, cargarlo desde el sistema de archivos
		if (FileSystem.exists(path))
		{
			trace('[Paths] Loading external Voices from file system: $path');
			var sound = new flixel.sound.FlxSound();
			// loadStream carga directamente desde el sistema de archivos
			sound.loadStream(path);
			return sound;
		}
		#end
		
		// Archivo en el asset manifest - usar método normal
		trace('[Paths] Loading embedded Voices from assets: $path');
		var sound = new flixel.sound.FlxSound();
		
		// Intentar cargar desde assets embebidos
		try 
		{
			sound.loadEmbedded(voices(song), false, false);
		}
		catch (e:Dynamic)
		{
			trace('[Paths] ERROR loading Voices: $e');
		}
		
		return sound;
	}

	inline static public function image(key:String)
	{
		return getPath('images/$key.png', IMAGE);
	}

	inline static public function imageCutscene(key:String)
	{
		return '$key.png';
	}

	inline static public function characterimage(key:String)
	{
		return getPath('characters/images/$key.png', IMAGE);
	}

	public static function characterFolder(key:String):String
	{
		var path = 'assets/characters/images/$key/';
		
		return path;
	}

	inline static public function imageStage(key:String)
	{
		return getPath('stages/' + getCurrentStage() + '/images/' + key + '.png', IMAGE);
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
	static public function getBitmap(key:String):Bitmap
	{
		totalLoads++;
		
		var cacheKey = key;
		
		// Revisar caché si está habilitado
		if (cacheEnabled && bitmapCache.exists(cacheKey))
		{
			cacheHits++;
			return bitmapCache.get(cacheKey);
		}
		
		cacheMisses++;
		
		// Cargar bitmap
		var imagePath = image(key);
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
	static public function getSparrowAtlas(key:String):FlxAtlasFrames
	{
		totalLoads++;
		
		var cacheKey = key;
		
		// Revisar caché
		if (cacheEnabled && atlasCache.exists(cacheKey))
		{
			cacheHits++;
			return atlasCache.get(cacheKey);
		}
		
		cacheMisses++;
		
		// Cargar atlas
		var atlas = FlxAtlasFrames.fromSparrow(image(key), file('images/$key.xml'));
		
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

	static public function getSparrowAtlasCutscene(key:String):FlxAtlasFrames
	{
		totalLoads++;
		
		var cacheKey = key;
		
		// Revisar caché
		if (cacheEnabled && atlasCache.exists(cacheKey))
		{
			cacheHits++;
			return atlasCache.get(cacheKey);
		}
		
		cacheMisses++;
		
		// Cargar atlas
		var atlas = FlxAtlasFrames.fromSparrow(imageCutscene(key), '$key.xml');
		
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

	static public function characterSprite(key:String):FlxAtlasFrames
	{
		totalLoads++;
		
		var cacheKey = "char_" + key;
		
		// Revisar caché
		if (cacheEnabled && atlasCache.exists(cacheKey))
		{
			cacheHits++;
			return atlasCache.get(cacheKey);
		}
		
		cacheMisses++;
		
		var atlas = FlxAtlasFrames.fromSparrow(
			getPath('characters/images/$key.png', IMAGE), 
			getPath('characters/images/$key.xml', TEXT)
		);
		
		if (cacheEnabled && atlas != null)
		{
			if ([for (k in atlasCache.keys()) k].length >= maxCacheSize)
				clearOldestAtlasCache();
			
			atlasCache.set(cacheKey, atlas);
		}
		
		return atlas;
	}

	static public function stageSprite(key:String):FlxAtlasFrames
	{
		totalLoads++;
		
		var cacheKey = "stage_" + key;
		
		// Revisar caché
		if (cacheEnabled && atlasCache.exists(cacheKey))
		{
			cacheHits++;
			return atlasCache.get(cacheKey);
		}
		
		cacheMisses++;
		
		var curStage = getCurrentStage();
		var atlas = FlxAtlasFrames.fromSparrow(
			getPath('stages/' + curStage + '/images/$key.png', IMAGE), 
			getPath('stages/' + curStage + '/images/$key.xml', TEXT)
		);
		
		if (cacheEnabled && atlas != null)
		{
			if ([for (k in atlasCache.keys()) k].length >= maxCacheSize)
				clearOldestAtlasCache();
			
			atlasCache.set(cacheKey, atlas);
		}
		
		return atlas;
	}

	static public function skinSprite(key:String):FlxAtlasFrames
	{
		totalLoads++;
		
		var cacheKey = "skin_" + key;
		
		// Revisar caché
		if (cacheEnabled && atlasCache.exists(cacheKey))
		{
			cacheHits++;
			return atlasCache.get(cacheKey);
		}
		
		cacheMisses++;
		
		var atlas = FlxAtlasFrames.fromSparrow(
			getPath('skins/$key.png', IMAGE), 
			getPath('skins/$key.xml', TEXT)
		);
		
		if (cacheEnabled && atlas != null)
		{
			if ([for (k in atlasCache.keys()) k].length >= maxCacheSize)
				clearOldestAtlasCache();
			
			atlasCache.set(cacheKey, atlas);
		}
		
		return atlas;
	}
	
	static public function getPackerAtlas(key:String):FlxAtlasFrames
	{
		totalLoads++;
		
		var cacheKey = "packer_" + key;
		
		if (cacheEnabled && atlasCache.exists(cacheKey))
		{
			cacheHits++;
			return atlasCache.get(cacheKey);
		}
		
		cacheMisses++;
		
		var atlas = FlxAtlasFrames.fromSpriteSheetPacker(image(key), file('images/$key.txt'));
		
		if (cacheEnabled && atlas != null)
		{
			if ([for (k in atlasCache.keys()) k].length >= maxCacheSize)
				clearOldestAtlasCache();
			
			atlasCache.set(cacheKey, atlas);
		}
		
		return atlas;
	}

	static public function characterSpriteTxt(key:String):FlxAtlasFrames
	{
		totalLoads++;
		
		var cacheKey = "char_txt_" + key;
		
		if (cacheEnabled && atlasCache.exists(cacheKey))
		{
			cacheHits++;
			return atlasCache.get(cacheKey);
		}
		
		cacheMisses++;
		
		var atlas = FlxAtlasFrames.fromSpriteSheetPacker(
			getPath('characters/images/$key.png', IMAGE), 
			file('characters/images/$key.txt')
		);
		
		if (cacheEnabled && atlas != null)
		{
			if ([for (k in atlasCache.keys()) k].length >= maxCacheSize)
				clearOldestAtlasCache();
			
			atlasCache.set(cacheKey, atlas);
		}
		
		return atlas;
	}

	static public function stageSpriteTxt(key:String):FlxAtlasFrames
	{
		totalLoads++;
		
		var cacheKey = "stage_txt_" + key;
		
		if (cacheEnabled && atlasCache.exists(cacheKey))
		{
			cacheHits++;
			return atlasCache.get(cacheKey);
		}
		
		cacheMisses++;
		
		var curStage = getCurrentStage();
		var atlas = FlxAtlasFrames.fromSpriteSheetPacker(
			getPath('stages/' + curStage + '/images/$key.png', IMAGE), 
			file('stages/' + curStage + '/images/$key.txt')
		);
		
		if (cacheEnabled && atlas != null)
		{
			if ([for (k in atlasCache.keys()) k].length >= maxCacheSize)
				clearOldestAtlasCache();
			
			atlasCache.set(cacheKey, atlas);
		}
		
		return atlas;
	}

	
	static public function splashSprite(key:String):FlxAtlasFrames
	{
		totalLoads++;
		
		var cacheKey = "splash_" + key;
		
		if (cacheEnabled && atlasCache.exists(cacheKey))
		{
			cacheHits++;
			return atlasCache.get(cacheKey);
		}
		
		cacheMisses++;
		
		var atlas = FlxAtlasFrames.fromSparrow(
			getPath('splashes/$key.png', IMAGE), 
			getPath('splashes/$key.xml', TEXT)
		);
		
		if (cacheEnabled && atlas != null)
		{
			if ([for (k in atlasCache.keys()) k].length >= maxCacheSize)
				clearOldestAtlasCache();
			
			atlasCache.set(cacheKey, atlas);
		}
		
		return atlas;
	}

	static public function skinSpriteTxt(key:String):FlxAtlasFrames
	{
		totalLoads++;
		
		var cacheKey = "skin_txt_" + key;
		
		if (cacheEnabled && atlasCache.exists(cacheKey))
		{
			cacheHits++;
			return atlasCache.get(cacheKey);
		}
		
		cacheMisses++;
		
		var atlas = FlxAtlasFrames.fromSpriteSheetPacker(
			getPath('skins/$key.png', IMAGE), 
			file('skins/$key.txt')
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
			// NO hacemos dispose - dejamos que el GC lo maneje
			// para evitar crashes cuando se vuelve a estados anteriores
			bitmapCache.remove(firstKey);
			trace('[Paths] Bitmap removed from cache: $firstKey');
			bitmapCount--;
		}
	}
	
	/**
	 * Limpiar todo el caché
	 * NOTA: NO hace dispose() de los recursos para evitar crashes
	 * El garbage collector se encargará de liberarlos cuando ya no se usen
	 */
	public static function clearCache():Void
	{
		trace('[Paths] Clearing the entire cache...');
		
		// Limpiar caché local
		atlasCache.clear();
		bitmapCache.clear();

		atlasCount = 0;
    	bitmapCount = 0;
		
		trace('[Paths] Cache completely cleared (resources left to GC)');
	}
	
	/**
	 * Limpiar FlxG.bitmap (caché global de HaxeFlixel)
	 * Usa clearCache() que limpia automáticamente gráficos no persistentes
	 * Usar al salir de estados pesados como PlayState
	 */
	public static function clearFlxBitmapCache():Void
	{
		trace('[Paths] Clearing FlxG.bitmap cache...');
		
		// FlxG.bitmap.clearCache() limpia todos los gráficos no persistentes
		// Los gráficos con persist=true se mantienen
		FlxG.bitmap.clearCache();
		
		// Forzar garbage collection para liberar memoria inmediatamente
		#if cpp
		cpp.vm.Gc.run(true);
		#elseif hl
		hl.Gc.major();
		#end
		
		trace('[Paths] Cleared non-persistent graphics from FlxG.bitmap');
	}
	
	/**
	 * Limpiar TODO el caché incluyendo FlxG.bitmap
	 * Usar entre estados para prevenir memory leaks
	 */
	public static function clearAllCaches():Void
	{
		clearCache();
		clearFlxBitmapCache();
		trace('[Paths] All caches cleared');
	}
	
	/**
	 * Limpiar caché de forma agresiva con dispose()
	 * ADVERTENCIA: Solo usar cuando estés 100% seguro de que ningún sprite
	 * está usando estos recursos (ej: al cerrar el juego)
	 */
	public static function forceClearCache():Void
	{
		trace('[Paths] FORCE clearing cache with dispose()...');
		
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
		
		trace('[Paths] Cache FORCE cleared with dispose()');
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