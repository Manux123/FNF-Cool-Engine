package;

import flixel.FlxG;
import flixel.graphics.frames.FlxAtlasFrames;
import openfl.utils.AssetType;
import openfl.utils.Assets as OpenFlAssets;
import openfl.display.BitmapData as Bitmap;
import animationdata.FunkinSprite;
import mods.ModManager;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

/**
	* Paths — a centralized routing system with mod and cache support.

	*
	* ─── Search Order (for each asset) ──────────────────────────────────────

	* 1. mods/{activeMod}/{path} ← the mod overwrites everything

	* 2. assets/{path} ← base game

	*
	* ─── Basic Usage ────────────────────────────────────────────────────────────

	* // No mod active → search only in assets/

	* Paths.image('ui/healthBar');

	*

	* // With mod active → look in mods/my-mod/ first

	* ModManager.setActive('my-mod');

	* Paths.image('ui/healthBar'); // may come from the mod

	*
	* ─── Cache ─────────────────────────────────────────────────────────────────────

	* • Bitmaps and atlases are cached by logical key (not by path) physical).

	* • The maximum size is controlled with `Paths.maxCacheSize`.

	* • The count is maintained with an Int, not with `[for (k in map.keys()) k].length`.
 */

class Paths
{
	public static inline var SOUND_EXT = #if web "mp3" #else "ogg" #end;

	// ─── Caché LRU ────────────────────────────────────────────────────────────
	// Implementación LRU (Least Recently Used):
	//   • Map para acceso O(1) al dato.
	//   • Array de claves en orden de último acceso (más reciente al final).
	//     Al hacer hit, la clave se mueve al final. Al evictar, se elimina el frente.
	//   • El bitmap/atlas evictado recibe .dispose() para liberar VRAM de inmediato.
	static var atlasCache:Map<String, FlxAtlasFrames> = [];
	static var bitmapCache:Map<String, Bitmap>         = [];

	// Órdenes LRU (índice 0 = más antiguo → candidato a evictar)
	static var _atlasLRU:Array<String>  = [];
	static var _bitmapLRU:Array<String> = [];

	static var atlasCount:Int  = 0;
	static var bitmapCount:Int = 0;
	static var cacheHits:Int   = 0;
	static var cacheMisses:Int = 0;
	static var totalLoads:Int  = 0;

	/**
	 * Tamaño máximo de cada caché (atlas + bitmaps por separado).
	 * 50 es suficiente para evitar re-cargar assets frecuentes sin acumular demasiada RAM.
	 */
	public static var maxCacheSize:Int = 25; // Reducido: 25 atlas/bitmaps es suficiente para FNF sin acumular RAM

	/** Desactivar para depuración — todos los accesos van a disco. */
	public static var cacheEnabled:Bool = true;

	// ─── Stage actual ─────────────────────────────────────────────────────────

	/** Actualizado por PlayState al cambiar de stage. */
	public static var currentStage:String = 'stage_week1';

	// ─── Core: resolve ────────────────────────────────────────────────────────

	/**
	 * Función central de resolución de paths.
	 *
	 * Busca en este orden:
	 *   1. `mods/{activeMod}/{file}`  (si hay mod activo)
	 *   2. `assets/{file}`
	 *
	 * Siempre devuelve un path (aunque no exista en disco) para que
	 * OpenFL/Lime puedan lanzar sus propios errores cuando proceda.
	 */
	public static function resolve(file:String, ?type:AssetType):String
	{
		// ── 1. Mod activo ─────────────────────────────────────────────────────
		final modPath = ModManager.resolveInMod(file);
		if (modPath != null)
			return modPath;

		// ── 2. Assets base ────────────────────────────────────────────────────
		return 'assets/$file';
	}

	/**
	 * Como `resolve`, pero también acepta una lista de paths alternativos
	 * que se intentan en orden si el primero no existe.
	 * Útil para búsquedas con rutas legacy.
	 */
	public static function resolveAny(candidates:Array<String>):String
	{
		for (c in candidates)
		{
			#if sys
			if (FileSystem.exists(c))
				return c;
			#else
			if (OpenFlAssets.exists(c))
				return c;
			#end
		}
		// Devolver el primero como fallback (dejará el error a OpenFL)
		return candidates[0];
	}

	/** ¿Existe el archivo `file` (en mod o en assets)? */
	public static function exists(file:String, ?type:AssetType):Bool
	{
		final path = resolve(file, type);
		#if sys
		return FileSystem.exists(path);
		#else
		return OpenFlAssets.exists(path, type);
		#end
	}

	/** Lee texto desde `file` (en mod o en assets). */
	public static function getText(file:String):String
	{
		final path = resolve(file, TEXT);
		#if sys
		if (FileSystem.exists(path))
			return File.getContent(path);
		#end
		return OpenFlAssets.getText(path);
	}

	// ─── Paths tipados ────────────────────────────────────────────────────────

	public static inline function file(file:String, type:AssetType = TEXT):String
		return resolve(file, type);

	public static inline function txt(key:String):String
		return resolve('data/$key.txt', TEXT);

	public static inline function xml(key:String):String
		return resolve('data/$key.xml', TEXT);

	public static inline function json(key:String):String
		return resolve('data/$key.json', TEXT);

	// Canciones
	public static function jsonSong(key:String):String
		return resolveAny([ModManager.resolveInMod('songs/$key.json') ?? '', 'assets/songs/$key.json'].filter(s -> s != ''));

	public static function songsTxt(key:String):String
		return resolve('songs/$key.txt', TEXT);

	// Characters
	public static function characterJSON(key:String):String
		return resolveAny([
			ModManager.resolveInMod('characters/$key.json') ?? '',
			'assets/characters/$key.json'
		].filter(s -> s != ''));

	// Stages
	public static function stageJSON(key:String):String
	{	return resolveAny([
			ModManager.resolveInMod('stages/$key.json') ?? '',
			'stages/$key.json'
		].filter(s -> s != ''));
	}

	// Imágenes
	public static inline function image(key:String):String
		return resolve('images/$key.png', IMAGE);

	inline static public function imageCutscene(key:String):String
		return resolve('$key.png',IMAGE);

	public static inline function characterimage(key:String):String
		return resolve('characters/images/$key.png', IMAGE);

	public static function characterFolder(key:String):String
		return resolve('characters/images/$key/');

	/** Imagen del stage actual. */
	public static function imageStage(key:String):Bitmap
	{
		// Candidatos en orden: Cool layout → Psych layout → base assets
		final candidates = [
			ModManager.resolveInMod('stages/$currentStage/images/$key.png'), // Cool
			ModManager.resolveInMod('images/stages/$key.png'),                // Psych
			ModManager.resolveInMod('images/$key.png'),                       // Psych flat
		].filter(p -> p != null);

		// ── 1. Rutas de mod — usar Lime directamente, NUNCA OpenFlAssets ───
		// lime.graphics.Image.fromFile() carga del disco nativo sin pasar por
		// el sistema de assets de OpenFL (que solo conoce los assets compilados).
		// BitmapData.fromBytes() falla porque espera openfl.utils.ByteArray,
		// no haxe.io.Bytes. BitmapData.fromImage() es la API correcta.
		#if sys
		for (modPath in candidates)
		{
			try
			{
				final limeImage = lime.graphics.Image.fromFile(modPath);
				if (limeImage != null)
				{
					final bmp = Bitmap.fromImage(limeImage);
					if (bmp != null) return bmp;
				}
			}
			catch (e:Dynamic)
			{
				trace('[Paths] imageStage: error cargando "$modPath": $e');
			}
		}
		#end

		// ── 2. Asset base ─────────────────────────────────────────────────
		final basePath = 'assets/stages/$currentStage/images/$key.png';
		#if sys
		if (FileSystem.exists(basePath))
		{
			try
			{
				final limeImage = lime.graphics.Image.fromFile(basePath);
				if (limeImage != null) return Bitmap.fromImage(limeImage);
			}
			catch (e:Dynamic) {}
		}
		#end

		// Último recurso: assets embebidos en el binario
		if (OpenFlAssets.exists(basePath, IMAGE))
			return OpenFlAssets.getBitmapData(basePath);

		trace('[Paths] imageStage: no encontrado "$key" (stage=$currentStage, mod=${ModManager.activeMod})');
		return null;
	}

	// Sonidos
	public static function sound(key:String):String
		return resolve('sounds/$key.$SOUND_EXT', SOUND);

	public static function soundStage(key:String):String
		return resolve('stages/$key.$SOUND_EXT', SOUND);

	public static inline function soundRandom(key:String, min:Int, max:Int):String
		return sound(key + FlxG.random.int(min, max));

	public static function music(key:String):String
		return resolve('music/$key.$SOUND_EXT', MUSIC);

	// Canciones — audio
	/**
	 * Genera variantes normalizadas de un nombre de carpeta para mods
	 * que usan espacios o guiones de forma distinta al nombre en el JSON.
	 * Ej: "Break It Down!" → ["break it down!", "break-it-down!", "break-it-down", ...]
	 */
	static function _songFolderVariants(name:String):Array<String>
	{
		final s = name.toLowerCase();
		final variants:Array<String> = [];
		function add(v:String) { v = v.trim(); if (v != '' && variants.indexOf(v) == -1) variants.push(v); }
		add(s);
		add(s.replace(' ', '-'));
		add(s.replace('-', ' '));
		add(s.replace('!', ''));
		add(s.replace(' ', '-').replace('!', ''));
		add(s.replace('-', ' ').replace('!', ''));
		return variants;
	}

	/** Resuelve la carpeta real de una canción en el mod activo o en assets/. */
	static function _resolveSongFolder(song:String):String
	{
		#if sys
		if (ModManager.isActive())
		{
			final modRoot = ModManager.modRoot();
			for (v in _songFolderVariants(song))
				for (base in ['$modRoot/songs', '$modRoot/assets/songs'])
					if (sys.FileSystem.isDirectory('$base/$v'))
						return '$base/$v';
		}
		// Fallback: assets/
		for (v in _songFolderVariants(song))
			if (sys.FileSystem.isDirectory('assets/songs/$v'))
				return 'assets/songs/$v';
		// Devuelve el path canónico aunque no exista (fallback final)
		return 'assets/songs/${song.toLowerCase()}';
		#else
		return 'assets/songs/${song.toLowerCase()}';
		#end
	}

	public static function inst(song:String):String
	{
		final folder = _resolveSongFolder(song);
		// Cool Engine layout: songs/name/song/Inst.ogg
		final withSubfolder = '$folder/song/Inst.$SOUND_EXT';
		#if sys
		if (sys.FileSystem.exists(withSubfolder)) return withSubfolder;
		// Psych Engine layout: songs/name/Inst.ogg (no /song/ subfolder)
		final flat = '$folder/Inst.$SOUND_EXT';
		if (sys.FileSystem.exists(flat)) return flat;
		#end
		return withSubfolder; // fallback for embedded assets
	}

	public static function voices(song:String):String
	{
		final folder = _resolveSongFolder(song);
		final withSubfolder = '$folder/song/Voices.$SOUND_EXT';
		#if sys
		if (sys.FileSystem.exists(withSubfolder)) return withSubfolder;
		final flat = '$folder/Voices.$SOUND_EXT';
		if (sys.FileSystem.exists(flat)) return flat;
		#end
		return withSubfolder;
	}

	// Vídeo — busca en mods/mod/videos/, mods/mod/cutscenes/videos/, assets/videos/, assets/cutscenes/videos/
	public static function video(key:String):String
	{
		final k = key.endsWith('.mp4') ? key.substr(0, key.length - 4) : key;
		return resolveAny([
			ModManager.resolveInMod('videos/$k.mp4')           ?? '',
			ModManager.resolveInMod('cutscenes/videos/$k.mp4') ?? '',
			'assets/videos/$k.mp4',
			'assets/cutscenes/videos/$k.mp4'
		].filter(s -> s != ''));
	}

	// Fuentes
	public static inline function font(key:String):String
		return resolve('fonts/$key');

	// Scripts
	public static function stageScripts(stageName:String):String
		return resolveAny([
			ModManager.resolveInMod('stages/$stageName/scripts') ?? '',
			'assets/stages/$stageName/scripts'
		].filter(s -> s != ''));

	// ─── Carga de audio ───────────────────────────────────────────────────────

	/** Carga el Inst de una canción desde disco o assets embebidos. */
	public static function loadInst(song:String):flixel.sound.FlxSound
		return loadSound(inst(song));

	/** Carga las Voices de una canción desde disco o assets embebidos. */
	public static function loadVoices(song:String):flixel.sound.FlxSound
		return loadSound(voices(song));

	static function loadSound(path:String):flixel.sound.FlxSound
	{
		final snd = new flixel.sound.FlxSound();
		try
		{
			#if sys
			if (FileSystem.exists(path))
			{
				snd.loadStream(path);
				return snd;
			}
			#end
			snd.loadEmbedded(path, false, false);
		}
		catch (e:Dynamic)
		{
			trace('[Paths] Error cargando audio "$path": $e');
		}
		return snd;
	}

	// ─── FunkinSprite helpers ─────────────────────────────────────────────────

	public static function animateAtlas(key:String):String
		return resolve(key);

	public static function characterAnimateAtlas(key:String):String
		return resolve('characters/images/$key');

	public static function hasAnimateAtlas(key:String):Bool
		return FunkinSprite.folderHasAnimateAtlas(resolve(key));

	public static function characterHasAnimateAtlas(key:String):Bool
		return FunkinSprite.folderHasAnimateAtlas(resolve('characters/images/$key'));

	public static inline function getFunkinSprite(x:Float, y:Float, key:String):FunkinSprite
		return FunkinSprite.create(x, y, key);

	public static inline function getCharacterSprite(x:Float, y:Float, key:String):FunkinSprite
		return FunkinSprite.createCharacter(x, y, key);

	// ─── Bitmap con caché ─────────────────────────────────────────────────────

	public static function getBitmap(key:String):Bitmap
	{
		totalLoads++;

		if (cacheEnabled && bitmapCache.exists(key))
		{
			cacheHits++;
			// LRU touch
			final pos = _bitmapLRU.indexOf(key);
			if (pos >= 0 && pos < _bitmapLRU.length - 1)
			{
				_bitmapLRU.splice(pos, 1);
				_bitmapLRU.push(key);
			}
			return bitmapCache.get(key);
		}
		cacheMisses++;

		final path = image(key);
		var bitmap:Bitmap = null;

		try
		{
			#if sys
			if (FileSystem.exists(path))
			{
				final limeImage = lime.graphics.Image.fromFile(path);
				if (limeImage != null) bitmap = Bitmap.fromImage(limeImage);
			}
			#end
			if (bitmap == null && !path.startsWith('mods/') && OpenFlAssets.exists(path, IMAGE))
				bitmap = OpenFlAssets.getBitmapData(path);
		}
		catch (e:Dynamic)
		{
			trace('[Paths] getBitmap "$key": $e');
		}

		if (cacheEnabled && bitmap != null)
			storeBitmap(key, bitmap);
		return bitmap;
	}

	// ─── Atlas Sparrow con caché ──────────────────────────────────────────────

	/**
	 * Carga un atlas Sparrow (PNG + XML) desde el mod activo o assets.
	 * La clave de caché es `key` (lógica, no la ruta física).
	 */
	public static function getSparrowAtlas(key:String):FlxAtlasFrames
		return _cachedAtlas(key, () -> _sparrow(image(key), resolve('images/$key.xml')));

	/**
	 * Resolves a character PNG path trying both engine layouts:
	 *   Cool Engine:  mods/mod/characters/images/NAME.png
	 *   Psych Engine: mods/mod/images/characters/NAME.png
	 */
	static function _resolveCharacterPng(key:String):String
		return resolveAny([
			ModManager.resolveInMod('characters/images/$key.png') ?? '',  // Cool
			ModManager.resolveInMod('images/characters/$key.png') ?? '',  // Psych
			'assets/characters/images/$key.png'
		].filter(s -> s != ''));

	static function _resolveCharacterXml(key:String):String
		return resolveAny([
			ModManager.resolveInMod('characters/images/$key.xml') ?? '',
			ModManager.resolveInMod('images/characters/$key.xml') ?? '',
			'assets/characters/images/$key.xml'
		].filter(s -> s != ''));

	static function _resolveCharacterTxt(key:String):String
		return resolveAny([
			ModManager.resolveInMod('characters/images/$key.txt') ?? '',
			ModManager.resolveInMod('images/characters/$key.txt') ?? '',
			'assets/characters/images/$key.txt'
		].filter(s -> s != ''));

	public static function characterSprite(key:String):FlxAtlasFrames
		return _cachedAtlas('char_$key', () -> _sparrow(_resolveCharacterPng(key), _resolveCharacterXml(key)));

	public static function stageSprite(key:String):FlxAtlasFrames
	{
		return _cachedAtlas('stage_$key', () ->
		{
			// Try Cool layout first, then Psych layout
			final pngPath = resolveAny([
				ModManager.resolveInMod('stages/$currentStage/images/$key.png') ?? '', // Cool
				ModManager.resolveInMod('images/stages/$key.png')                ?? '', // Psych
				ModManager.resolveInMod('images/$key.png')                       ?? '', // Psych flat
				'assets/stages/$currentStage/images/$key.png'
			].filter(s -> s != ''));
			final xmlPath = resolveAny([
				ModManager.resolveInMod('stages/$currentStage/images/$key.xml') ?? '',
				ModManager.resolveInMod('images/stages/$key.xml')                ?? '',
				ModManager.resolveInMod('images/$key.xml')                       ?? '',
				'assets/stages/$currentStage/images/$key.xml'
			].filter(s -> s != ''));
			final bmp = imageStage(key);
			return bmp != null ? _sparrowFromBitmap(bmp, xmlPath) : null;
		});
	}

	public static function skinSprite(key:String):FlxAtlasFrames
		return _cachedAtlas('skin_$key', () -> _sparrow(resolve('skins/$key.png', IMAGE), resolve('skins/$key.xml', TEXT)));

	public static function splashSprite(key:String):FlxAtlasFrames
		return _cachedAtlas('splash_$key', () -> _sparrow(resolve('splashes/$key.png', IMAGE), resolve('splashes/$key.xml', TEXT)));

	public static function getSparrowAtlasCutscene(key:String):FlxAtlasFrames
		return _cachedAtlas('cutscene_$key', () -> FlxAtlasFrames.fromSparrow('$key.png', '$key.xml'));

	// ─── Atlas Packer con caché ───────────────────────────────────────────────

	public static function getPackerAtlas(key:String):FlxAtlasFrames
		return _cachedAtlas('packer_$key', () -> _packer(image(key), resolve('images/$key.txt')));

	public static function characterSpriteTxt(key:String):FlxAtlasFrames
		return _cachedAtlas('char_txt_$key', () -> _packer(_resolveCharacterPng(key), _resolveCharacterTxt(key)));

	public static function stageSpriteTxt(key:String):FlxAtlasFrames
		return _cachedAtlas('stage_txt_$key', () ->
		{
			final pngPath = resolveAny([
				ModManager.resolveInMod('stages/$currentStage/images/$key.png') ?? '',
				ModManager.resolveInMod('images/stages/$key.png')                ?? '',
				ModManager.resolveInMod('images/$key.png')                       ?? '',
				'assets/stages/$currentStage/images/$key.png'
			].filter(s -> s != ''));
			final txtPath = resolveAny([
				ModManager.resolveInMod('stages/$currentStage/images/$key.txt') ?? '',
				ModManager.resolveInMod('images/stages/$key.txt')                ?? '',
				ModManager.resolveInMod('images/$key.txt')                       ?? '',
				'assets/stages/$currentStage/images/$key.txt'
			].filter(s -> s != ''));
			return _packer(pngPath, txtPath);
		});

	public static function skinSpriteTxt(key:String):FlxAtlasFrames
		return _cachedAtlas('skin_txt_$key', () -> _packer(resolve('skins/$key.png', IMAGE), resolve('skins/$key.txt', TEXT)));

	// ─── Gestión de caché ─────────────────────────────────────────────────────

	public static function clearCache():Void
	{
		atlasCache.clear();
		bitmapCache.clear();
		_atlasLRU  = [];
		_bitmapLRU = [];
		atlasCount  = 0;
		bitmapCount = 0;
		trace('[Paths] Caché local limpiado.');
	}

	public static function clearFlxBitmapCache():Void
	{
		FlxG.bitmap.clearCache();
		#if cpp cpp.vm.Gc.run(true); #end
		#if hl hl.Gc.major(); #end
		trace('[Paths] FlxG.bitmap limpiado.');
	}

	public static function clearAllCaches():Void
	{
		// Sólo limpiamos las referencias en el caché de Paths.
		// Los bitmaps vivos siguen siendo gestionados por FlxG.bitmap hasta que
		// super.destroy() destruya los sprites que los referencian.
		clearCache();
		clearFlxBitmapCache();
	}

	public static function forceClearCache():Void
	{
		for (a in atlasCache)
			if (a?.parent?.bitmap != null)
				a.parent.bitmap.dispose();
		atlasCache.clear();

		for (b in bitmapCache)
			b?.dispose();
		bitmapCache.clear();

		_atlasLRU  = [];
		_bitmapLRU = [];
		atlasCount  = 0;
		bitmapCount = 0;
		trace('[Paths] Caché vaciado con dispose().');
	}

	public static function setCacheEnabled(enabled:Bool):Void
	{
		cacheEnabled = enabled;
		if (!enabled)
			clearCache();
	}

	public static function getCacheStats():String
	{
		final hitRate = totalLoads > 0 ? Math.round((cacheHits / totalLoads) * 100) : 0;
		return '[Paths] Loads=$totalLoads  Hits=$cacheHits ($hitRate%)  Misses=$cacheMisses  '
			+ 'Atlas=$atlasCount/$maxCacheSize  Bitmaps=$bitmapCount/$maxCacheSize'
			+ (ModManager.isActive() ? '  Mod=${ModManager.activeMod}' : '');
	}

	public static function resetStats():Void
	{
		totalLoads = 0;
		cacheHits = 0;
		cacheMisses = 0;
	}

	// ─── Helpers internos (privados) ──────────────────────────────────────────

	/**
	 * Patrón de caché unificado para atlas.
	 * `loader` se llama solo si el atlas no está en caché.
	 * El LRU touch se hace en O(n) con splice — aceptable para n≤25.
	 */
	static function _cachedAtlas(key:String, loader:() -> FlxAtlasFrames):FlxAtlasFrames
	{
		totalLoads++;

		if (cacheEnabled && atlasCache.exists(key))
		{
			cacheHits++;
			// LRU touch: mover al final del array (más reciente)
			final pos = _atlasLRU.indexOf(key);
			if (pos >= 0 && pos < _atlasLRU.length - 1)
			{
				_atlasLRU.splice(pos, 1);
				_atlasLRU.push(key);
			}
			return atlasCache.get(key);
		}
		cacheMisses++;

		final atlas = loader();
		if (cacheEnabled && atlas != null)
			storeAtlas(key, atlas);
		return atlas;
	}

	/** Carga Sparrow desde paths (png + xml). */
	static function _sparrow(pngPath:String, xmlPath:String):FlxAtlasFrames
	{
		try
		{
			#if sys
			if (FileSystem.exists(pngPath) && FileSystem.exists(xmlPath))
			{
				final limeImage = lime.graphics.Image.fromFile(pngPath);
				if (limeImage != null)
				{
					final bmp = Bitmap.fromImage(limeImage);
					return FlxAtlasFrames.fromSparrow(bmp, File.getContent(xmlPath));
				}
			}
			// Si alguno de los paths es de mod y no se pudo cargar vía lime, no usar OpenFL
			if (pngPath.startsWith('mods/') || xmlPath.startsWith('mods/'))
			{
				trace('[Paths] _sparrow: asset de mod no encontrado pngPath="$pngPath" xmlPath="$xmlPath"');
				return null;
			}
			#end
			// Solo usar OpenFL string-based para assets base embebidos
			return FlxAtlasFrames.fromSparrow(pngPath, xmlPath);
		}
		catch (e:Dynamic)
		{
			trace('[Paths] _sparrow "$pngPath": $e');
			return null;
		}
	}

	/** Carga Sparrow desde un Bitmap ya cargado + path del XML. */
	static function _sparrowFromBitmap(bmp:Bitmap, xmlPath:String):FlxAtlasFrames
	{
		try
		{
			#if sys
			if (FileSystem.exists(xmlPath))
				return FlxAtlasFrames.fromSparrow(bmp, File.getContent(xmlPath));
			// Si el xmlPath apunta a assets base (no mod), intentar con OpenFlAssets
			if (!xmlPath.startsWith('mods/') && OpenFlAssets.exists(xmlPath, TEXT))
				return FlxAtlasFrames.fromSparrow(bmp, OpenFlAssets.getText(xmlPath));
			// Para paths de mod sin XML encontrado, no podemos cargar el atlas animado
			trace('[Paths] _sparrowFromBitmap: XML no encontrado en disco "$xmlPath"');
			return null;
			#else
			return FlxAtlasFrames.fromSparrow(bmp, OpenFlAssets.getText(xmlPath));
			#end
		}
		catch (e:Dynamic)
		{
			trace('[Paths] _sparrowFromBitmap: $e');
			return null;
		}
	}

	/** Carga Packer desde paths (png + txt). */
	static function _packer(pngPath:String, txtPath:String):FlxAtlasFrames
	{
		try
		{
			#if sys
			if (FileSystem.exists(pngPath) && FileSystem.exists(txtPath))
			{
				final limeImage = lime.graphics.Image.fromFile(pngPath);
				if (limeImage != null)
				{
					final bmp = Bitmap.fromImage(limeImage);
					return FlxAtlasFrames.fromSpriteSheetPacker(bmp, File.getContent(txtPath));
				}
			}
			#end
			return FlxAtlasFrames.fromSpriteSheetPacker(pngPath, txtPath);
		}
		catch (e:Dynamic)
		{
			trace('[Paths] _packer "$pngPath": $e');
			return null;
		}
	}

	static function storeAtlas(key:String, atlas:FlxAtlasFrames):Void
	{
		if (atlasCount >= maxCacheSize)
			evictAtlas();
		atlasCache.set(key, atlas);
		_atlasLRU.push(key);
		atlasCount++;
	}

	static function storeBitmap(key:String, bmp:Bitmap):Void
	{
		if (bitmapCount >= maxCacheSize)
			evictBitmap();
		bitmapCache.set(key, bmp);
		_bitmapLRU.push(key);
		bitmapCount++;
	}

	/**
	 * Evicta el atlas menos usado recientemente (LRU).
	 *
	 * IMPORTANTE: NO llamamos dispose() aquí.
	 * El BitmapData lo gestiona FlxG.bitmap; si hacemos dispose() mientras algún
	 * FlxSprite aún referencia ese FlxGraphic, el siguiente draw crashea
	 * (bitmap disposed but graphic still in FlxG.bitmap cache).
	 * Simplemente quitamos el atlas de NUESTRO caché → si nadie más lo referencia,
	 * el GC lo colectará en su momento.
	 */
	static function evictAtlas():Void
	{
		if (_atlasLRU.length == 0) return;
		final k = _atlasLRU.shift();
		atlasCache.remove(k);
		atlasCount--;
	}

	/**
	 * Evicta el bitmap menos usado recientemente (LRU).
	 * Igual que evictAtlas: no disponemos aquí para evitar crashes.
	 */
	static function evictBitmap():Void
	{
		if (_bitmapLRU.length == 0) return;
		final k = _bitmapLRU.shift();
		bitmapCache.remove(k);
		bitmapCount--;
	}
}
