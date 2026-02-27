package;

import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import openfl.display.BitmapData as Bitmap;
import openfl.media.Sound;
import openfl.utils.AssetType;
import openfl.utils.Assets as OpenFlAssets;
import animationdata.FunkinSprite;
import mods.ModManager;
import funkin.cache.PathsCache;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

/**
 * Paths — sistema centralizado de resolución de rutas con caché avanzado.
 *
 * ─── Arquitectura del caché ───────────────────────────────────────────────────
 *
 *  ANTES (Paths viejo):
 *    bitmapCache:Map<String, BitmapData>   — cacheaba el bitmap en RAM
 *    atlasCache: Map<String, FlxAtlasFrames> — cacheaba los frames
 *    ¡La textura estaba SIEMPRE en RAM aunque ya estuviese subida a GPU!
 *
 *  AHORA (Paths + PathsCache):
 *    PathsCache.currentTrackedGraphics    — FlxGraphic con GPU caching opcional
 *    PathsCache.currentTrackedSounds      — Sound cacheados
 *    atlasCache: Map<String, FlxAtlasFrames> — sólo los frames (ligeros)
 *
 *  El FlxGraphic que construye PathsCache integra con FlxG.bitmap nativo de
 *  Flixel (FlxSprite.loadGraphic() lo encuentra automáticamente). Cuando
 *  gpuCaching=true el BitmapData en RAM se libera después del upload → ahorra
 *  ~4 MB por textura 1024×1024.
 *
 * ─── Ciclo de vida del caché ──────────────────────────────────────────────────
 *
 *   // Al inicio de un estado que carga assets pesados (p.ej. PlayState):
 *   Paths.beginSession();
 *
 *   // Durante la carga — se llama automáticamente por getGraphic / getSound
 *
 *   // Al destruir el estado:
 *   Paths.clearStoredMemory();   // sonidos fuera de uso + marcar gráficos
 *   Paths.clearUnusedMemory();   // destruir gráficos marcados + GC
 *
 * @author Cool Engine Team
 * @version 0.5.0
 */
class Paths
{
	public static inline var SOUND_EXT = #if web "mp3" #else "ogg" #end;

	// ── Acceso al caché principal ─────────────────────────────────────────────

	/** Instancia global de PathsCache. Nunca null. */
	public static var cache(get, never):PathsCache;
	static inline function get_cache():PathsCache return PathsCache.instance;

	// ── Caché de atlas (sólo frames, los bitmaps están en PathsCache) ─────────
	//
	// FlxAtlasFrames es ligero: sólo contiene un array de FlxRect + referencia
	// al FlxGraphic. No tiene datos de píxeles propios.
	// El bitmap real vive en PathsCache (GPU o RAM según gpuCaching).
	// LRU eliminado: FNF nunca necesita evictar atlases durante gameplay.
	// Los frames se liberan con clearPreviousSession(), no por eviction.

	static var atlasCache:Map<String, FlxAtlasFrames> = [];
	static var atlasCount:Int = 0;

	/**
	 * Límite de atlases en caché.
	 * Aumentado a 200 (antes: 80) ya que sin LRU no hay eviction durante
	 * gameplay — los atlases se limpian en bloque al cambiar de sesión.
	 */
	public static var maxAtlasCache:Int = 200;

	/** Si false todos los accesos van a disco (útil para depuración). */
	public static var cacheEnabled:Bool = true;

	// ── Stage actual ──────────────────────────────────────────────────────────

	/** Actualizado por PlayState al cambiar de stage. */
	public static var currentStage:String = 'stage_week1';

	// ── Opciones de GPU ───────────────────────────────────────────────────────

	/**
	 * Alias de PathsCache.gpuCaching para compatibilidad con opciones guardadas.
	 * Cambiar aquí también cambia el comportamiento de PathsCache.
	 */
	public static var gpuCaching(get, set):Bool;
	static inline function get_gpuCaching():Bool return PathsCache.gpuCaching;
	static inline function set_gpuCaching(v:Bool):Bool { PathsCache.gpuCaching = v; return v; }

	// ── Gestión de sesión (delegados a PathsCache) ────────────────────────────

	/**
	 * Inicia una nueva sesión de caché.
	 * Resetea localTrackedAssets sin borrar nada.
	 * Llamar al inicio de create() en cada estado pesado.
	 */
	public static inline function beginSession():Void
		cache.beginSession();

	/**
	 * Destruye los assets de la sesión anterior que no fueron rescatados.
	 * Llamar al FINAL de create() de un estado pesado, después de cargar
	 * todos los assets — esto da tiempo a que los assets compartidos sean
	 * rescatados de _previousGraphics a _currentGraphics durante la carga.
	 */
	public static inline function clearPreviousSession():Void
	{
		cache.clearPreviousSession();
		_pruneInvalidAtlases();
	}

	/**
	 * Añade una clave a las exclusiones permanentes (nunca se evicta).
	 * Ejemplo: Paths.addExclusion(Paths.music('freakyMenu'));
	 */
	public static inline function addExclusion(key:String):Void
		cache.addExclusion(key);

	/**
	 * Libera assets de sonido + gráficos no marcados (fuera de localTrackedAssets).
	 * Llamar al salir de un estado pesado ANTES de clearUnusedMemory().
	 */
	public static inline function clearStoredMemory():Void
	{
		cache.clearStoredMemory();
		// Limpiar también atlases cuya graphic ya no está en PathsCache
		_pruneInvalidAtlases();
	}

	/**
	 * Destruye los gráficos marcados por clearStoredMemory() + fuerza GC.
	 * Llamar DESPUÉS de clearStoredMemory().
	 */
	public static inline function clearUnusedMemory():Void
		cache.clearUnusedMemory();

	// ── Core: resolve ─────────────────────────────────────────────────────────

	/**
	 * Resuelve un archivo al path físico correcto.
	 * Orden: mods/{activeMod}/{file} → assets/{file}
	 */
	public static function resolve(file:String, ?type:AssetType):String
	{
		final modPath = ModManager.resolveInMod(file);
		if (modPath != null) return modPath;
		return 'assets/$file';
	}

	/**
	 * Resolve a path for WRITING (saving files).
	 * Unlike resolve(), this does NOT check if the file exists —
	 * it always returns the mod path if a mod is active.
	 * Use this whenever you need to save/create a file.
	 *
	 * Examples:
	 *   resolveWrite('characters/bf.json') → 'mods/myMod/characters/bf.json'  (mod active)
	 *   resolveWrite('characters/bf.json') → 'assets/characters/bf.json'      (no mod)
	 */
	public static function resolveWrite(file:String):String
	{
		#if sys
		if (ModManager.isActive())
			return '${ModManager.modRoot()}/$file';
		#end
		return 'assets/$file';
	}

	/**
	 * Ensure the directory for a file path exists, then return the path.
	 * Convenience wrapper for write operations.
	 */
	public static function ensureDir(filePath:String):String
	{
		#if sys
		final dir = haxe.io.Path.directory(filePath);
		if (dir != '' && !sys.FileSystem.exists(dir))
			sys.FileSystem.createDirectory(dir);
		#end
		return filePath;
	}


	public static function resolveAny(candidates:Array<String>):String
	{
		for (c in candidates)
		{
			if (c == null || c == '') continue;
			#if sys
			if (FileSystem.exists(c)) return c;
			#else
			if (OpenFlAssets.exists(c)) return c;
			#end
		}
		return candidates.filter(s -> s != null && s != '')[0] ?? '';
	}

	/** ¿Existe el archivo (en mod o en assets)? */
	public static function exists(file:String, ?type:AssetType):Bool
	{
		final path = resolve(file, type);
		#if sys
		return FileSystem.exists(path);
		#else
		return OpenFlAssets.exists(path, type);
		#end
	}

	/** Lee texto desde file (en mod o en assets). */
	public static function getText(file:String):String
	{
		final path = resolve(file, TEXT);
		#if sys
		if (FileSystem.exists(path)) return File.getContent(path);
		#end
		return OpenFlAssets.getText(path);
	}

	// ── Paths tipados ─────────────────────────────────────────────────────────

	public static inline function file(file:String, type:AssetType = TEXT):String
		return resolve(file, type);

	public static inline function txt(key:String):String
		return resolve('data/$key.txt', TEXT);

	public static inline function xml(key:String):String
		return resolve('data/$key.xml', TEXT);

	public static inline function json(key:String):String
		return resolve('data/$key.json', TEXT);

	public static function jsonSong(key:String):String
		return resolveAny([ModManager.resolveInMod('songs/$key.json') ?? '', 'assets/songs/$key.json']);

	public static function songsTxt(key:String):String
		return resolve('songs/$key.txt', TEXT);

	public static function characterJSON(key:String):String
		return resolveAny([
			ModManager.resolveInMod('characters/$key.json') ?? '',
			'assets/characters/$key.json'
		]);

	public static function stageJSON(key:String):String
		return resolveAny([
			ModManager.resolveInMod('stages/$key.json') ?? '',
			'stages/$key.json'
		]);

	public static inline function image(key:String):String
		return resolve('images/$key.png', IMAGE);

	public static inline function imageCutscene(key:String):String
		return resolve('$key.png', IMAGE);

	public static inline function characterimage(key:String):String
		return resolve('characters/images/$key.png', IMAGE);

	public static function characterFolder(key:String):String
		return resolve('characters/images/$key/');

	public static function sound(key:String):String
	{
		final path = resolve('sounds/$key.$SOUND_EXT', SOUND);
		#if sys
		// Devolver el path si existe en disco aunque no esté en el manifest de OpenFL
		if (FileSystem.exists(path)) return path;
		// Fallback: buscar directamente en assets/ para builds sin recompilar
		final direct = 'assets/sounds/$key.$SOUND_EXT';
		if (FileSystem.exists(direct)) return direct;
		#end
		return path;
	}

	public static function soundStage(key:String):String
	{
		final path = resolve('stages/$key.$SOUND_EXT', SOUND);
		#if sys
		if (FileSystem.exists(path)) return path;
		#end
		return path;
	}

	public static inline function soundRandom(key:String, min:Int, max:Int):String
		return sound(key + FlxG.random.int(min, max));

	public static function music(key:String):String
	{
		final path = resolve('music/$key.$SOUND_EXT', MUSIC);
		#if sys
		// Devolver el path del disco directamente para builds no recompiladas
		if (FileSystem.exists(path)) return path;
		// Fallback: assets/ base
		final direct = 'assets/music/$key.$SOUND_EXT';
		if (FileSystem.exists(direct)) return direct;
		#end
		return path;
	}

	public static inline function font(key:String):String
		return resolve('fonts/$key');

	public static function video(key:String):String
	{
		final k = key.endsWith('.mp4') ? key.substr(0, key.length - 4) : key;
		return resolveAny([
			ModManager.resolveInMod('videos/$k.mp4')           ?? '',
			ModManager.resolveInMod('cutscenes/videos/$k.mp4') ?? '',
			'assets/videos/$k.mp4',
			'assets/cutscenes/videos/$k.mp4'
		]);
	}

	public static function stageScripts(stageName:String):String
		return resolveAny([
			ModManager.resolveInMod('stages/$stageName/scripts') ?? '',
			'assets/stages/$stageName/scripts'
		]);

	// ── Carga de gráficos ─────────────────────────────────────────────────────

	/**
	 * Carga un BitmapData desde disco o assets embebidos.
	 * Internamente pasa por PathsCache → si gpuCaching=true, la imagen en RAM
	 * se libera después del upload y se devuelve FlxGraphic.bitmap (que puede
	 * estar en modo "GPU only"; los píxeles no son accesibles desde CPU).
	 *
	 * Para efectos que necesiten leer píxeles desde CPU (tintado dinámico, etc.)
	 * usar getGraphic() con allowGPU=false.
	 *
	 * @deprecated Preferir getGraphic() para integración completa con Flixel.
	 */
	public static function getBitmap(key:String, allowGPU:Bool = true):Null<Bitmap>
	{
		final g = getGraphic(key, allowGPU);
		return g?.bitmap;
	}

	/**
	 * Carga y cachea un FlxGraphic para la clave dada.
	 *
	 * • Busca primero en PathsCache (cache hit → O(1), sin I/O).
	 * • En miss: carga desde disco via Lime → crea FlxGraphic → sube a GPU si
	 *   gpuCaching=true → libera imagen en RAM → cachea en PathsCache.
	 * • El FlxGraphic resultante tiene persist=true + destroyOnNoUse=false.
	 *
	 * @param key       Clave lógica del asset (sin prefijo "images/", sin ".png").
	 * @param allowGPU  Si false, deshabilita GPU caching para este asset.
	 */
	public static function getGraphic(key:String, allowGPU:Bool = true):Null<FlxGraphic>
	{
		// Resolver path físico
		final path = image(key);
		// Clave de PathsCache = path físico (único y estable entre llamadas)
		final cacheKey = path;

		// Cache hit en PathsCache
		if (cacheEnabled && cache.hasValidGraphic(cacheKey))
			return cache.peekGraphic(cacheKey);

		// Cache miss → cargar desde disco
		final bmp = _loadBitmapFromDisk(path);
		if (bmp == null)
		{
			trace('[Paths] getGraphic: no encontrado "$key" (path="$path")');
			return null;
		}

		return cacheEnabled ? cache.getGraphic(cacheKey, bmp, allowGPU)
		                    : FlxGraphic.fromBitmapData(bmp, false, cacheKey, false);
	}

	// ── Imagen del stage (path especial) ──────────────────────────────────────

	/**
	 * Carga la imagen de un asset de stage.
	 * Internamente usa PathsCache para GPU caching.
	 */
	public static function imageStage(key:String):Null<Bitmap>
	{
		final path = _resolveStageImagePath(key);
		if (path == null) return null;

		// Intentar desde PathsCache primero
		if (cacheEnabled && cache.hasValidGraphic(path))
			return cache.peekGraphic(path)?.bitmap;

		final bmp = _loadBitmapFromDisk(path);
		if (bmp == null) return null;

		if (cacheEnabled) cache.getGraphic(path, bmp);
		return bmp;
	}

	// ── Carga de sonidos ─────────────────────────────────────────────────────

	/**
	 * Carga un sonido desde disco y lo cachea en PathsCache.
	 * Reutiliza la instancia Sound si ya estaba cacheada (sin I/O).
	 *
	 * @param path    Path físico del sonido (resultado de Paths.sound(), .music(), etc.)
	 * @param safety  Si true y no se encuentra, devuelve un beep de fallback.
	 */
	public static function getSound(path:String, safety:Bool = false):Null<Sound>
	{
		// Cache hit
		if (cacheEnabled && cache.hasSound(path))
			return cache.getSound(path, null, safety);

		// Cache miss → cargar
		var snd:Sound = null;
		try
		{
			#if sys
			if (FileSystem.exists(path))
			{
				snd = Sound.fromFile(path);
			}
			else
			#end
			if (OpenFlAssets.exists(path, SOUND))
				snd = OpenFlAssets.getSound(path, false);
			else if (OpenFlAssets.exists(path, MUSIC))
				snd = OpenFlAssets.getSound(path, false);
		}
		catch (e:Dynamic) { trace('[Paths] getSound "$path": $e'); }

		return cacheEnabled ? cache.getSound(path, snd, safety) : snd;
	}

	/**
	 * Carga música de forma segura desde el filesystem o assets embebidos.
	 * Úsalo en lugar de FlxG.sound.playMusic(Paths.music(...)) cuando el path
	 * puede venir de una carpeta de mods (no está en el manifest de OpenFL).
	 */
	public static function loadMusic(key:String):Null<Sound>
	{
		final path = music(key);
		return getSound(path);
	}

	// ── Carga de audio de canción (streaming) ─────────────────────────────────

	/** Carga el Inst de una canción usando streaming. */
	public static function loadInst(song:String):flixel.sound.FlxSound
		return _loadStreamingSound(inst(song));

	/** Carga las Voices de una canción usando streaming. */
	public static function loadVoices(song:String):flixel.sound.FlxSound
		return _loadStreamingSound(voices(song));

	/**
	 * Carga un FlxSound en modo streaming.
	 * Las canciones NUNCA se meten en PathsCache (son demasiado grandes y
	 * se usan una sola vez). Se cargan directamente como stream desde disco.
	 *
	 * POR QUÉ STREAMING:
	 *   loadEmbedded() decodifica el OGG completo a PCM en RAM al cargar.
	 *   3 min × 44.1 kHz × 16-bit × 2 canales = ~32 MB por pista.
	 *   Inst + Voices = 64–120 MB. Con streaming → sólo un buffer de segundos.
	 */
	static function _loadStreamingSound(path:String):flixel.sound.FlxSound
	{
		final snd = new flixel.sound.FlxSound();
		try
		{
			#if sys
			if (FileSystem.exists(path)) { snd.loadStream(path); return snd; }

			// Asset embebido → volcar a tmp para hacer stream
			final bytes = lime.utils.Assets.getBytes(path);
			if (bytes != null)
			{
				final tmpDir  = Sys.getEnv('TEMP') ?? Sys.getEnv('TMPDIR') ?? '/tmp';
				final tmpFile = '$tmpDir/funkin_stream_${path.split('/').pop() ?? "audio"}';
				if (!FileSystem.exists(tmpFile)) File.saveBytes(tmpFile, bytes);
				snd.loadStream(tmpFile);
				return snd;
			}
			#end
			snd.loadEmbedded(path, false, false);
		}
		catch (e:Dynamic) { trace('[Paths] _loadStreamingSound "$path": $e'); }
		return snd;
	}

	// ── Song paths ────────────────────────────────────────────────────────────

	public static function inst(song:String):String
	{
		final folder = _resolveSongFolder(song);
		#if sys
		final withSub = '$folder/song/Inst.$SOUND_EXT';
		if (FileSystem.exists(withSub)) return withSub;
		final flat = '$folder/Inst.$SOUND_EXT';
		if (FileSystem.exists(flat)) return flat;
		#end
		return '$folder/song/Inst.$SOUND_EXT';
	}

	public static function voices(song:String):String
	{
		final folder = _resolveSongFolder(song);
		#if sys
		final withSub = '$folder/song/Voices.$SOUND_EXT';
		if (FileSystem.exists(withSub)) return withSub;
		final flat = '$folder/Voices.$SOUND_EXT';
		if (FileSystem.exists(flat)) return flat;
		#end
		return '$folder/song/Voices.$SOUND_EXT';
	}

	// ── FunkinSprite helpers ─────────────────────────────────────────────────

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

	// ── Atlas Sparrow con caché ───────────────────────────────────────────────

	/**
	 * Carga un atlas Sparrow (PNG + XML).
	 *
	 * El FlxGraphic del PNG pasa por PathsCache (GPU caching).
	 * El FlxAtlasFrames se cachea separadamente (es sólo metadata de frames).
	 */
	public static function getSparrowAtlas(key:String):FlxAtlasFrames
		return _cachedAtlas(key, () -> _sparrow(image(key), resolve('images/$key.xml')));

	public static function characterSprite(key:String):FlxAtlasFrames
		return _cachedAtlas('char_$key', () ->
			_sparrow(_resolveCharacterPng(key), _resolveCharacterXml(key)));

	public static function stageSprite(key:String):FlxAtlasFrames
		return _cachedAtlas('stage_$key', () ->
		{
			final pngPath = resolveAny([
				ModManager.resolveInMod('stages/$currentStage/images/$key.png') ?? '',
				ModManager.resolveInMod('images/stages/$key.png')                ?? '',
				ModManager.resolveInMod('images/$key.png')                       ?? '',
				'assets/stages/$currentStage/images/$key.png'
			]);
			final xmlPath = resolveAny([
				ModManager.resolveInMod('stages/$currentStage/images/$key.xml') ?? '',
				ModManager.resolveInMod('images/stages/$key.xml')                ?? '',
				ModManager.resolveInMod('images/$key.xml')                       ?? '',
				'assets/stages/$currentStage/images/$key.xml'
			]);
			final stageBmp = _resolveStageImagePath(key);
			if (stageBmp == null) return null;
			return _sparrowFromPath(stageBmp, xmlPath);
		});

	public static function skinSprite(key:String):FlxAtlasFrames
		return _cachedAtlas('skin_$key', () ->
			_sparrow(resolve('skins/$key.png', IMAGE), resolve('skins/$key.xml', TEXT)));

	public static function splashSprite(key:String):FlxAtlasFrames
		return _cachedAtlas('splash_$key', () ->
			_sparrow(resolve('splashes/$key.png', IMAGE), resolve('splashes/$key.xml', TEXT)));

	public static function getSparrowAtlasCutscene(key:String):FlxAtlasFrames
		return _cachedAtlas('cutscene_$key', () ->
			FlxAtlasFrames.fromSparrow('$key.png', '$key.xml'));

	// ── Atlas Packer con caché ────────────────────────────────────────────────

	public static function getPackerAtlas(key:String):FlxAtlasFrames
		return _cachedAtlas('packer_$key', () ->
			_packer(image(key), resolve('images/$key.txt')));

	public static function characterSpriteTxt(key:String):FlxAtlasFrames
		return _cachedAtlas('char_txt_$key', () ->
			_packer(_resolveCharacterPng(key), _resolveCharacterTxt(key)));

	public static function stageSpriteTxt(key:String):FlxAtlasFrames
		return _cachedAtlas('stage_txt_$key', () ->
		{
			final pngPath = resolveAny([
				ModManager.resolveInMod('stages/$currentStage/images/$key.png') ?? '',
				ModManager.resolveInMod('images/stages/$key.png')                ?? '',
				'assets/stages/$currentStage/images/$key.png'
			]);
			final txtPath = resolveAny([
				ModManager.resolveInMod('stages/$currentStage/images/$key.txt') ?? '',
				ModManager.resolveInMod('images/stages/$key.txt')                ?? '',
				'assets/stages/$currentStage/images/$key.txt'
			]);
			return _packer(pngPath, txtPath);
		});

	public static function skinSpriteTxt(key:String):FlxAtlasFrames
		return _cachedAtlas('skin_txt_$key', () ->
			_packer(resolve('skins/$key.png', IMAGE), resolve('skins/$key.txt', TEXT)));

	// ── Gestión del caché de atlas ────────────────────────────────────────────

	/**
	 * Limpia el caché de atlas + delega a PathsCache.
	 * Los FlxGraphics del PNG se liberan via PathsCache.
	 */
	public static function clearCache():Void
	{
		for (atlas in atlasCache)
		{
			if (atlas?.parent != null)
			{
				atlas.parent.destroyOnNoUse = true;
				if (atlas.parent.useCount <= 0)
					atlas.parent.destroy();
			}
		}
		atlasCache.clear();
		atlasCount = 0;
		trace('[Paths] Atlas cache limpiado.');
	}

	/**
	 * Limpia entradas del atlasCache cuyo FlxGraphic ya fue dispuesto.
	 * Llamar después de GC/compact para que atlas invalidados sean detectados.
	 * Así el siguiente acceso fuerza una recarga limpia desde disco.
	 */
	
	public static inline function pruneAtlasCache():Void{
		_pruneInvalidAtlases();
	}

	public static function clearFlxBitmapCache():Void
	{
		FlxG.bitmap.clearCache();
		try { openfl.utils.Assets.cache.clear(); } catch (_:Dynamic) {}
		#if cpp cpp.vm.Gc.run(true); #end
		#if hl hl.Gc.major(); #end
		trace('[Paths] FlxG.bitmap + OpenFL cache limpiados.');
	}

	/**
	 * Limpia TODO: atlas + PathsCache.forceFullClear() + Flixel.
	 * Sólo para cambio de mod o reinicio.
	 */
	public static function clearAllCaches():Void
	{
		clearCache();
		cache.forceFullClear();
		clearFlxBitmapCache();
	}

	/**
	 * @deprecated Alias de clearAllCaches() para compatibilidad.
	 */
	public static inline function forceClearCache():Void
		clearAllCaches();

	/** Limpia SÓLO assets de gameplay sin tocar UI/menús. */
	public static function clearGameplayCache():Void
	{
		// Limpiar atlases con prefijos de gameplay
		final prefixes = ["char_", "stage_", "skin_"];
		final toRemove:Array<String> = [];
		for (key in atlasCache.keys())
			for (p in prefixes)
				if (key.startsWith(p)) { toRemove.push(key); break; }

		for (key in toRemove)
		{
			final atlas = atlasCache.get(key);
			atlasCache.remove(key);
			atlasCount--;
			if (atlas?.parent != null)
			{
				atlas.parent.destroyOnNoUse = true;
				if (atlas.parent.useCount <= 0) atlas.parent.destroy();
			}
		}

		// Delegar los gráficos a PathsCache
		cache.clearGameplayAssets();

		if (toRemove.length > 0)
			trace('[Paths] clearGameplayCache: ${toRemove.length} atlas(es) + gráficos de gameplay liberados.');
	}

	public static function setCacheEnabled(enabled:Bool):Void
	{
		cacheEnabled = enabled;
		if (!enabled) clearCache();
	}

	// ── Stats ─────────────────────────────────────────────────────────────────

	/** String compacto para el debug overlay. */
	public static function cacheDebugString():String
		return 'Atlas: $atlasCount/$maxAtlasCache  ' + cache.debugString();

	/** Stats completos. */
	public static function getCacheStats():String
		return '[Paths] Atlas=$atlasCount/$maxAtlasCache\n' + cache.fullStats();

	// ── Internos: carga de bitmaps ────────────────────────────────────────────

	/**
	 * Carga un BitmapData desde disco (via Lime) o desde assets embebidos.
	 * NO cachea nada — es el nivel más bajo de carga.
	 */
	static function _loadBitmapFromDisk(path:String):Null<Bitmap>
	{
		try
		{
			#if sys
			if (FileSystem.exists(path))
			{
				final img = lime.graphics.Image.fromFile(path);
				if (img != null) return Bitmap.fromImage(img);
			}
			#end
			if (!path.startsWith('mods/') && OpenFlAssets.exists(path, IMAGE))
				return OpenFlAssets.getBitmapData(path, false);
		}
		catch (e:Dynamic)
		{
			trace('[Paths] _loadBitmapFromDisk "$path": $e');
		}
		return null;
	}

	// ── Internos: atlas ───────────────────────────────────────────────────────

	/**
	 * Patrón de caché unificado para FlxAtlasFrames.
	 * Valida el atlas antes de devolverlo: si el bitmap fue dispuesto,
	 * elimina la entrada y recarga.
	 */
	static function _cachedAtlas(key:String, loader:() -> FlxAtlasFrames):FlxAtlasFrames
	{
		if (cacheEnabled && atlasCache.exists(key))
		{
			final cached = atlasCache.get(key);
			if (_atlasValid(cached))
			{
				// Rescue: si el FlxGraphic del atlas está en _previousGraphics,
				// moverlo a _currentGraphics para que sobreviva esta sesión.
				if (cached.parent != null)
					cache.rescueFromPrevious(cached.parent.key, cached.parent);
				return cached;
			}
			// Inválido → limpiar y recargar
			atlasCache.remove(key);
			atlasCount--;
		}

		final atlas = loader();
		if (cacheEnabled && atlas != null)
			_storeAtlas(key, atlas);
		return atlas;
	}

	/**
	 * Carga Sparrow: obtiene el FlxGraphic de PathsCache (con GPU upload) y
	 * construye el FlxAtlasFrames desde el FlxGraphic + contenido del XML.
	 *
	 * Pasar FlxGraphic en vez de BitmapData a fromSparrow() garantiza que
	 * Flixel use el MISMO objeto de textura que PathsCache, sin duplicarlo.
	 */
	static function _sparrow(pngPath:String, xmlPath:String):FlxAtlasFrames
	{
		try
		{
			// Obtener o crear el FlxGraphic via PathsCache
			final graphic = _getGraphicForPath(pngPath);
			if (graphic == null)
			{
				trace('[Paths] _sparrow: PNG no encontrado "$pngPath"');
				return null;
			}

			// Leer el XML
			final xmlContent = _readXml(xmlPath);
			if (xmlContent == null)
			{
				trace('[Paths] _sparrow: XML no encontrado "$xmlPath"');
				return null;
			}

			// fromSparrow acepta FlxGraphic directamente — sin duplicar textura
			return FlxAtlasFrames.fromSparrow(graphic, xmlContent);
		}
		catch (e:Dynamic)
		{
			trace('[Paths] _sparrow "$pngPath": $e');
			return null;
		}
	}

	/** Variante de _sparrow que recibe el path físico directamente (no image()). */
	static function _sparrowFromPath(pngPath:String, xmlPath:String):FlxAtlasFrames
	{
		try
		{
			final graphic = _getGraphicForPath(pngPath);
			if (graphic == null) return null;
			final xmlContent = _readXml(xmlPath);
			if (xmlContent == null) return null;
			return FlxAtlasFrames.fromSparrow(graphic, xmlContent);
		}
		catch (e:Dynamic)
		{
			trace('[Paths] _sparrowFromPath "$pngPath": $e');
			return null;
		}
	}

	/** Carga Packer: igual que _sparrow pero para txt. */
	static function _packer(pngPath:String, txtPath:String):FlxAtlasFrames
	{
		try
		{
			final graphic = _getGraphicForPath(pngPath);
			if (graphic == null) return null;

			final txtContent = _readXml(txtPath); // reutilizar el mismo helper
			if (txtContent == null) return null;

			return FlxAtlasFrames.fromSpriteSheetPacker(graphic, txtContent);
		}
		catch (e:Dynamic)
		{
			trace('[Paths] _packer "$pngPath": $e');
			return null;
		}
	}

	/**
	 * Obtiene o crea un FlxGraphic para un path físico.
	 * Usa PathsCache con el path físico como clave.
	 */
	static function _getGraphicForPath(pngPath:String):Null<FlxGraphic>
	{
		// Hit rápido en PathsCache
		if (cacheEnabled && cache.hasValidGraphic(pngPath))
			return cache.peekGraphic(pngPath);

		// Cargar bitmap y registrar en PathsCache
		final bmp = _loadBitmapFromDisk(pngPath);
		if (bmp == null) return null;

		return cacheEnabled ? cache.getGraphic(pngPath, bmp)
		                    : FlxGraphic.fromBitmapData(bmp, false, pngPath, false);
	}

	/** Lee contenido XML/TXT desde disco o assets embebidos. */
	static function _readXml(xmlPath:String):Null<String>
	{
		try
		{
			#if sys
			if (FileSystem.exists(xmlPath)) return File.getContent(xmlPath);
			#end
			if (OpenFlAssets.exists(xmlPath, TEXT)) return OpenFlAssets.getText(xmlPath);
		}
		catch (e:Dynamic) { trace('[Paths] _readXml "$xmlPath": $e'); }
		return null;
	}

	static function _storeAtlas(key:String, atlas:FlxAtlasFrames):Void
	{
		// Sin eviction durante gameplay — clearPreviousSession() libera en bloque.
		if (atlas?.parent != null)
			atlas.parent.destroyOnNoUse = false; // PathsCache gestiona el ciclo de vida
		atlasCache.set(key, atlas);
		atlasCount++;
	}

	static inline function _atlasValid(atlas:FlxAtlasFrames):Bool
	{
		try { return atlas != null && atlas.parent != null && atlas.parent.bitmap != null; }
		catch (_:Dynamic) { return false; }
	}

	/** Elimina del caché de atlas cualquier entrada cuyo FlxGraphic ya no esté en PathsCache. */
	static function _pruneInvalidAtlases():Void
	{
		final toRemove:Array<String> = [];
		for (key in atlasCache.keys())
			if (!_atlasValid(atlasCache.get(key))) toRemove.push(key);
		for (key in toRemove)
		{
			atlasCache.remove(key);
			atlasCount--;
		}
	}

	// ── Resolve helpers privados ──────────────────────────────────────────────

	static function _resolveStageImagePath(key:String):Null<String>
	{
		final candidates = [
			ModManager.resolveInMod('stages/$currentStage/images/$key.png'),
			ModManager.resolveInMod('images/stages/$key.png'),
			ModManager.resolveInMod('images/$key.png'),
		].filter(p -> p != null);

		#if sys
		for (p in candidates) if (FileSystem.exists(p)) return p;
		final base = 'assets/stages/$currentStage/images/$key.png';
		if (FileSystem.exists(base)) return base;
		#end
		final base = 'assets/stages/$currentStage/images/$key.png';
		if (OpenFlAssets.exists(base, IMAGE)) return base;
		return null;
	}

	static function _resolveCharacterPng(key:String):String
		return resolveAny([
			ModManager.resolveInMod('characters/images/$key.png') ?? '',
			ModManager.resolveInMod('images/characters/$key.png') ?? '',
			'assets/characters/images/$key.png'
		]);

	static function _resolveCharacterXml(key:String):String
		return resolveAny([
			ModManager.resolveInMod('characters/images/$key.xml') ?? '',
			ModManager.resolveInMod('images/characters/$key.xml') ?? '',
			'assets/characters/images/$key.xml'
		]);

	static function _resolveCharacterTxt(key:String):String
		return resolveAny([
			ModManager.resolveInMod('characters/images/$key.txt') ?? '',
			ModManager.resolveInMod('images/characters/$key.txt') ?? '',
			'assets/characters/images/$key.txt'
		]);

	static function _songFolderVariants(name:String):Array<String>
	{
		final s = name.toLowerCase();
		final v:Array<String> = [];
		function add(x:String) { x = x.trim(); if (x != '' && !v.contains(x)) v.push(x); }
		add(s); add(s.replace(' ', '-')); add(s.replace('-', ' '));
		add(s.replace('!', '')); add(s.replace(' ', '-').replace('!', ''));
		return v;
	}

	static function _resolveSongFolder(song:String):String
	{
		#if sys
		if (ModManager.isActive())
		{
			final modRoot = ModManager.modRoot();
			for (v in _songFolderVariants(song))
				for (base in ['$modRoot/songs', '$modRoot/assets/songs'])
					if (sys.FileSystem.isDirectory('$base/$v')) return '$base/$v';
		}
		for (v in _songFolderVariants(song))
			if (sys.FileSystem.isDirectory('assets/songs/$v')) return 'assets/songs/$v';
		#end
		return 'assets/songs/${song.toLowerCase()}';
	}

}
