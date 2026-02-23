package funkin.cache;

import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import flixel.system.FlxAssets;
import openfl.display.BitmapData;
import openfl.media.Sound;
import openfl.Assets;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

/**
 * PathsCache — sistema de caché de assets para Cool Engine.
 *
 * ─── Inspiración ─────────────────────────────────────────────────────────────
 * Basado en FunkinCache de NightmareVision, adaptado y extendido para
 * el sistema de mods y la arquitectura de Paths de Cool Engine.
 *
 * ─── Diferencias clave respecto a la caché anterior de Paths ─────────────────
 *
 *  1. CACHÉ DE FlxGraphic (antes era BitmapData puro)
 *     FlxGraphic se integra directamente con FlxG.bitmap: cuando un sprite
 *     usa el mismo FlxGraphic, Flixel NO duplica la textura en VRAM.
 *     Con BitmapData podían existir múltiples copias del mismo asset en GPU.
 *
 *  2. GPU TEXTURE UPLOAD + CPU IMAGE DISPOSE  ← el mayor ahorro de RAM
 *     Cuando gpuCaching=true:
 *       - Se sube el BitmapData como textura OpenGL (en VRAM).
 *       - Se libera la copia decodificada en RAM del sistema (`disposeImage()`).
 *       - Para una textura 1024×1024 RGBA esto libera ~4 MB de RAM por asset.
 *       - Con 30 personajes/stage assets → ~120 MB de RAM liberados.
 *     Cuando gpuCaching=false: se conserva el BitmapData en RAM (útil para
 *     efectos que necesiten leer píxeles en CPU, como tintado dinámico).
 *
 *  3. SONIDOS CACHEADOS (currentTrackedSounds)
 *     Sound.fromFile() cada vez que se necesita un sonido de UI es costoso.
 *     Ahora los sonidos se guardan y se reutilizan entre estados.
 *
 *  4. SISTEMA MARK-AND-SWEEP (localTrackedAssets)
 *     Cada estado llama a markInUse(key) para sus assets.
 *     clearStoredMemory() → libera todo lo que NO está marcado + resetea marcas.
 *     clearUnusedMemory() → libera de currentTrackedGraphics lo no marcado.
 *     Esto es más preciso que el LRU puro: el LRU puede evictar un asset que
 *     aún está en uso por el estado actual; el mark-and-sweep no.
 *
 *  5. DUMP EXCLUSIONS
 *     Assets que NUNCA deben evictarse (freakyMenu, cursor, UI permanente).
 *     Se añaden con `addExclusion(key)`.
 *
 *  6. disposeGraphic() CORRECTA
 *     Libera el texture de GPU (bitmap.__texture.dispose()) ANTES de llamar
 *     FlxG.bitmap.remove(). Sin el dispose del texture, la VRAM no se libera
 *     aunque el FlxGraphic sea eliminado del caché de Flixel.
 *
 *  7. LRU COMO RESPALDO (maxSize)
 *     Si se alcanza maxGraphics, se evicta el FlxGraphic menos recientemente
 *     usado que no esté en dumpExclusions ni en localTrackedAssets.
 *
 * ─── Ciclo de vida típico ─────────────────────────────────────────────────────
 *
 *   // Al entrar en un estado (p.ej. PlayState.create):
 *   PathsCache.beginSession();          // marca inicio, NO borra nada
 *
 *   // Al cargar assets (interno, Paths lo llama automáticamente):
 *   PathsCache.getGraphic(key, bmp);    // cachea y marca como "en uso"
 *
 *   // Al salir del estado (PlayState.destroy):
 *   PathsCache.clearStoredMemory();     // borra todo lo fuera de uso
 *   PathsCache.clearUnusedMemory();     // borra gráficos no marcados + GC
 *
 * @author  Cool Engine Team
 * @since   0.5.1
 */
@:access(openfl.display.BitmapData)
class PathsCache
{
	// ── Singleton ─────────────────────────────────────────────────────────────

	/** Instancia global. Se inicializa la primera vez que se accede. */
	public static var instance(get, null):PathsCache;
	static function get_instance():PathsCache
	{
		if (instance == null) instance = new PathsCache();
		return instance;
	}

	// ── Opciones ──────────────────────────────────────────────────────────────

	/**
	 * Activa el GPU caching: sube texturas a VRAM y libera la imagen en RAM.
	 * Por defecto true en desktop, false en web/mobile (sin context3D fiable).
	 * El usuario puede cambiarlo desde las opciones.
	 */
	public static var gpuCaching:Bool =
		#if (desktop && !hl) true #else false #end;

	/**
	 * Límite de FlxGraphics en caché antes de empezar a evictar.
	 * 80 cubre generosamente personajes + stage + UI sin desperdiciar RAM.
	 */
	public static var maxGraphics:Int = 80;

	/** Límite de sonidos en caché. Los sonidos son mucho más ligeros. */
	public static var maxSounds:Int = 64;

	// ── Almacenamiento ────────────────────────────────────────────────────────

	/**
	 * Graphics actualmente en caché: key → FlxGraphic.
	 * Todos tienen persist=true y destroyOnNoUse=false mientras estén aquí.
	 */
	public final currentTrackedGraphics:Map<String, FlxGraphic> = [];

	/**
	 * Sonidos actualmente en caché: key → Sound.
	 */
	public final currentTrackedSounds:Map<String, Sound> = [];

	/**
	 * Assets marcados como "en uso" en la sesión actual (estado/canción).
	 * Se resetea en beginSession() o clearStoredMemory().
	 * Usar markInUse(key) para añadir; el sistema lo llama automáticamente.
	 */
	public final localTrackedAssets:Array<String> = [];

	/**
	 * Assets que NUNCA se evictan aunque no estén en localTrackedAssets.
	 * Ejemplo: freakyMenu, cursor, iconos de UI permanente.
	 */
	public final dumpExclusions:Array<String> = [];

	// ── LRU para gráficos ─────────────────────────────────────────────────────
	// Respaldo cuando el mark-and-sweep no puede determinar qué evictar.

	var _graphicLRU:Array<String>      = [];
	var _graphicLRUPos:Map<String,Int> = [];

	// ── Estadísticas ─────────────────────────────────────────────────────────

	public var graphicHits(default, null):Int  = 0;
	public var graphicMisses(default, null):Int = 0;
	public var soundHits(default, null):Int    = 0;
	public var soundMisses(default, null):Int  = 0;
	public var gpuUploads(default, null):Int   = 0;
	public var gpuDisposes(default, null):Int  = 0;

	// ── Init ─────────────────────────────────────────────────────────────────

	public function new()
	{
		// Exclusiones por defecto: assets de UI permanente que siempre están
		// en pantalla o se acceden con mucha frecuencia.
		dumpExclusions.push('assets/music/freakyMenu.ogg');
		dumpExclusions.push('assets/music/freakyMenu.mp3');
		dumpExclusions.push('assets/images/menu/cursor/cursor-default.png');
		dumpExclusions.push('assets/images/icons/icon-bf.png');
	}

	// ── API pública ───────────────────────────────────────────────────────────

	/**
	 * Inicia una nueva sesión (nuevo estado/canción).
	 * Resetea localTrackedAssets sin borrar nada del caché.
	 * Llamar al inicio de create() en cada estado.
	 */
	public function beginSession():Void
	{
		#if (haxe >= "4.0.0")
		localTrackedAssets.resize(0);
		#else
		localTrackedAssets.splice(0, localTrackedAssets.length);
		#end
	}

	/**
	 * Marca una clave como "en uso" en la sesión actual.
	 * Llamado automáticamente por getGraphic() y getSound().
	 */
	public inline function markInUse(key:String):Void
	{
		if (!localTrackedAssets.contains(key))
			localTrackedAssets.push(key);
	}

	/**
	 * Añade una clave a las exclusiones permanentes.
	 */
	public inline function addExclusion(key:String):Void
	{
		if (!dumpExclusions.contains(key))
			dumpExclusions.push(key);
	}

	// ── Gráficos ──────────────────────────────────────────────────────────────

	/**
	 * Obtiene o crea un FlxGraphic para la clave dada.
	 *
	 * Si el graphic ya está en caché, lo devuelve y lo marca como en uso.
	 * Si no, lo crea desde `bitmap`, opcionalmente lo sube a GPU (si gpuCaching),
	 * lo cachea y lo devuelve.
	 *
	 * @param key       Clave lógica del asset (path resuelto o key de Paths).
	 * @param bitmap    BitmapData fuente. Sólo se usa si no está en caché.
	 * @param allowGPU  Si false, ignora gpuCaching para este asset específico.
	 * @return FlxGraphic listo para usar, o null si bitmap era null.
	 */
	public function getGraphic(key:String, bitmap:BitmapData, allowGPU:Bool = true):Null<FlxGraphic>
	{
		// ── Cache hit ─────────────────────────────────────────────────────────
		if (currentTrackedGraphics.exists(key))
		{
			graphicHits++;
			markInUse(key);
			_lruTouch(key);
			return currentTrackedGraphics.get(key);
		}

		graphicMisses++;

		if (bitmap == null) return null;

		// ── GPU upload ────────────────────────────────────────────────────────
		if (allowGPU && gpuCaching)
			_uploadToGPU(bitmap);

		// ── Crear FlxGraphic ──────────────────────────────────────────────────
		// fromBitmapData con cache=false evita que Flixel lo meta en SU propio
		// caché con una clave diferente; lo gestionamos nosotros.
		var graphic:FlxGraphic = FlxGraphic.fromBitmapData(bitmap, false, key, false);
		graphic.persist         = true;  // no destruir al cambiar de estado
		graphic.destroyOnNoUse  = false; // no destruir cuando useCount llegue a 0

		// ── Registrar en FlxG.bitmap ──────────────────────────────────────────
		// Necesario para que FlxSprite lo encuentre por clave.
		@:privateAccess
		FlxG.bitmap._cache.set(key, graphic);

		return _storeGraphic(key, graphic);
	}

	/**
	 * Obtiene un FlxGraphic directamente de la caché (sin cargarlo).
	 * Devuelve null si no está cacheado.
	 */
	public inline function peekGraphic(key:String):Null<FlxGraphic>
		return currentTrackedGraphics.get(key);

	/**
	 * ¿Está este graphic en la caché y sigue siendo válido?
	 */
	public function hasValidGraphic(key:String):Bool
	{
		final g = currentTrackedGraphics.get(key);
		return g != null && g.bitmap != null;
	}

	// ── Sonidos ───────────────────────────────────────────────────────────────

	/**
	 * Cachea y devuelve un Sound.
	 * Si ya está en caché, lo devuelve sin recargarlo.
	 *
	 * @param key    Clave lógica (path resuelto).
	 * @param sound  Instancia de Sound ya cargada. Sólo se usa en un miss.
	 * @param safety Si true y sound es null, devuelve un beep de Flixel.
	 */
	public function getSound(key:String, sound:Null<Sound>, safety:Bool = false):Null<Sound>
	{
		if (currentTrackedSounds.exists(key))
		{
			soundHits++;
			markInUse(key);
			return currentTrackedSounds.get(key);
		}

		soundMisses++;

		if (sound == null)
		{
			if (safety)
			{
				trace('[PathsCache] Sound "$key" no encontrado — usando beep de fallback.');
				return flixel.system.FlxAssets.getSound('flixel/sounds/beep');
			}
			return null;
		}

		// Evictar si se supera el límite
		if (_soundCount() >= maxSounds)
			_evictOldestSound();

		currentTrackedSounds.set(key, sound);
		markInUse(key);
		return sound;
	}

	/**
	 * ¿Está este sonido en la caché?
	 */
	public inline function hasSound(key:String):Bool
		return currentTrackedSounds.exists(key);

	// ── Limpieza: patrón clearStoredMemory / clearUnusedMemory ───────────────

	/**
	 * Limpia assets que NO están en localTrackedAssets ni en dumpExclusions.
	 *
	 * ─── Qué hace exactamente ────────────────────────────────────────────────
	 *  • Gráficos: los que no están en uso se marcan para destrucción
	 *    (destroyOnNoUse=true) pero NO se destruyen todavía. La destrucción
	 *    real ocurre en clearUnusedMemory() o cuando useCount llega a 0.
	 *  • Sonidos: se eliminan directamente del caché de OpenFL y de nuestra Map.
	 *  • Resetea localTrackedAssets para la próxima sesión.
	 *  • Limpia el caché interno de canciones de OpenFL.
	 *
	 * Llamar al final de PlayState.destroy() ANTES de clearUnusedMemory().
	 */
	public function clearStoredMemory():Void
	{
		// ── Desmarcar graphics fuera de uso ───────────────────────────────────
		@:privateAccess
		for (key in FlxG.bitmap._cache.keys())
		{
			if (!currentTrackedGraphics.exists(key)) continue;
			if (!localTrackedAssets.contains(key) && !dumpExclusions.contains(key))
			{
				var g = FlxG.bitmap.get(key);
				if (g != null) g.destroyOnNoUse = true;
			}
		}

		// ── Limpiar sonidos fuera de uso ──────────────────────────────────────
		var soundsRemoved = 0;
		for (key in currentTrackedSounds.keys())
		{
			if (!localTrackedAssets.contains(key) && !dumpExclusions.contains(key))
			{
				Assets.cache.clear(key);
				currentTrackedSounds.remove(key);
				soundsRemoved++;
			}
		}

		// ── Resetear marcas de sesión ─────────────────────────────────────────
		localTrackedAssets.resize(0);

		// ── Limpiar caché de canciones de OpenFL ──────────────────────────────
		// OpenFL guarda una referencia interna a cada Sound cargado de songs/.
		// Sin esto la RAM de audio no se libera entre canciones.
		try { openfl.Assets.cache.clear("songs"); } catch (_:Dynamic) {}

		if (soundsRemoved > 0)
			trace('[PathsCache] clearStoredMemory: $soundsRemoved sonidos liberados.');
	}

	/**
	 * Destruye los FlxGraphics que quedaron marcados como no usados en
	 * clearStoredMemory() + fuerza un ciclo de GC.
	 *
	 * ─── Orden recomendado ───────────────────────────────────────────────────
	 *   clearStoredMemory();   // marcar + limpiar sonidos
	 *   clearUnusedMemory();   // destruir gráficos + GC
	 *
	 * Llamar DESPUÉS de clearStoredMemory(). No llamar durante gameplay.
	 */
	public function clearUnusedMemory():Void
	{
		var graphicsRemoved = 0;

		for (key in currentTrackedGraphics.keys())
		{
			if (!localTrackedAssets.contains(key) && !dumpExclusions.contains(key))
			{
				disposeGraphic(currentTrackedGraphics.get(key));
				currentTrackedGraphics.remove(key);
				_lruRemove(key);
				graphicsRemoved++;
			}
		}

		// GC completo después de liberar potencialmente decenas de texturas
		openfl.system.System.gc();
		#if cpp
		cpp.vm.Gc.run(true);
		cpp.vm.Gc.compact();
		#elseif hl
		hl.Gc.major();
		#end

		if (graphicsRemoved > 0)
			trace('[PathsCache] clearUnusedMemory: $graphicsRemoved gráfico(s) destruidos.');
	}

	/**
	 * Vacía completamente el caché: gráficos + sonidos + exclusiones + LRU.
	 * Usar sólo al cambiar de mod o al cerrar el juego.
	 */
	public function forceFullClear():Void
	{
		// Destruir todos los gráficos
		for (g in currentTrackedGraphics) disposeGraphic(g);
		currentTrackedGraphics.clear();

		// Limpiar sonidos
		for (key in currentTrackedSounds.keys()) Assets.cache.clear(key);
		currentTrackedSounds.clear();

		// Resetear LRU y marcas
		_graphicLRU  = [];
		_graphicLRUPos = [];
		localTrackedAssets.resize(0);

		// Limpiar cachés de Flixel y OpenFL
		FlxG.bitmap.clearCache();
		try { openfl.Assets.cache.clear(); } catch (_:Dynamic) {}

		#if cpp cpp.vm.Gc.run(true); cpp.vm.Gc.compact(); #end
		#if hl hl.Gc.major(); #end

		trace('[PathsCache] forceFullClear: caché completamente vaciado.');
	}

	/**
	 * Limpia SÓLO los assets de gameplay (char_, stage_, skin_) sin tocar UI.
	 * Más rápido que forceFullClear. Llamar desde PlayState.destroy().
	 */
	public function clearGameplayAssets():Void
	{
		final prefixes = ["char_", "stage_", "skin_", "splash_"];
		final toRemove:Array<String> = [];

		for (key in currentTrackedGraphics.keys())
		{
			if (dumpExclusions.contains(key)) continue;
			for (p in prefixes)
			{
				if (key.startsWith(p)) { toRemove.push(key); break; }
			}
		}

		for (key in toRemove)
		{
			disposeGraphic(currentTrackedGraphics.get(key));
			currentTrackedGraphics.remove(key);
			_lruRemove(key);
		}

		if (toRemove.length > 0)
			trace('[PathsCache] clearGameplayAssets: ${toRemove.length} gráficos de gameplay liberados.');
	}

	// ── Dispose individual ────────────────────────────────────────────────────

	/**
	 * Destruye un FlxGraphic correctamente:
	 *  1. Libera la textura de GPU (bitmap.__texture.dispose()) — lo que
	 *     FunkinCache hace y la implementación por defecto de Flixel NO hace.
	 *  2. Llama FlxG.bitmap.remove() para quitar del caché de Flixel.
	 *
	 * Sin el paso 1, la VRAM no se libera aunque el objeto sea nulificado.
	 */
	@:access(openfl.display.BitmapData)
	public function disposeGraphic(graphic:Null<FlxGraphic>):Void
	{
		if (graphic == null) return;
		try
		{
			if (graphic.bitmap != null && graphic.bitmap.__texture != null)
			{
				graphic.bitmap.__texture.dispose();
				gpuDisposes++;
			}
			graphic.destroyOnNoUse = true;
		}
		catch (e:Dynamic)
		{
			trace('[PathsCache] disposeGraphic error: $e');
		}
		@:privateAccess FlxG.bitmap.remove(graphic);
	}

	// ── Stats ─────────────────────────────────────────────────────────────────

	/** String de debug compacto para el overlay. */
	public function debugString():String
	{
		final gCount   = _graphicCount();
		final sCount   = _soundCount();
		final hitRate  = (graphicHits + soundHits) > 0
			? Math.round(graphicHits / (graphicHits + graphicMisses) * 100) : 0;
		return 'Gfx: $gCount/$maxGraphics  Snd: $sCount/$maxSounds  Hits: ${hitRate}%  GPU↑: $gpuUploads';
	}

	/** String de stats extendido para el debug console. */
	public function fullStats():String
	{
		return '[PathsCache]\n'
			+ '  Gráficos:  cached=${_graphicCount()}/$maxGraphics  hits=$graphicHits  misses=$graphicMisses\n'
			+ '  Sonidos:   cached=${_soundCount()}/$maxSounds  hits=$soundHits  misses=$soundMisses\n'
			+ '  GPU:       uploads=$gpuUploads  disposes=$gpuDisposes  gpuCaching=$gpuCaching\n'
			+ '  Sesión:    enUso=${localTrackedAssets.length}  exclusiones=${dumpExclusions.length}';
	}

	// ── Internos ──────────────────────────────────────────────────────────────

	/** Almacena un FlxGraphic en la caché, con evicción LRU si es necesario. */
	function _storeGraphic(key:String, graphic:FlxGraphic):FlxGraphic
	{
		if (_graphicCount() >= maxGraphics)
			_evictLRUGraphic();

		currentTrackedGraphics.set(key, graphic);
		_lruPush(key);
		markInUse(key);
		return graphic;
	}

	/** Sube un BitmapData a GPU y libera la imagen en RAM del sistema. */
	@:access(openfl.display.BitmapData)
	function _uploadToGPU(bitmap:BitmapData):Void
	{
		if (bitmap == null) return;
		try
		{
			// Premultiplied alpha → requerido por OpenGL para blending correcto
			bitmap.image.premultiplied = true;

			// Subir al context3D de OpenFL — esto crea la textura en VRAM
			bitmap.getTexture(FlxG.stage.context3D);

			// Asegurarse de que la superficie esté disponible para lecturas GL
			bitmap.getSurface();

			// ── Liberar la imagen en RAM del sistema ──────────────────────────
			// Después del upload, bitmap.image contiene los bytes del PNG/BMP
			// decodificados en RAM (~4 MB para 1024×1024 RGBA).
			// Ya no los necesitamos porque la GPU tiene su propia copia.
			// FunkinCache hace exactamente esto en cacheBitmap().
			bitmap.disposeImage();

			// Asegurarse de que el bitmap sigue siendo "readable" para Flixel
			// (algunos efectos como tintado lo necesitan incluso sin imagen en RAM)
			bitmap.readable = true;

			gpuUploads++;
		}
		catch (e:Dynamic)
		{
			// Algunos drivers o plataformas pueden no soportar esto —
			// en ese caso simplemente no liberamos la imagen en RAM.
			trace('[PathsCache] GPU upload falló para un asset: $e');
		}
	}

	/** Evicta el FlxGraphic menos recientemente usado que pueda evictarse. */
	function _evictLRUGraphic():Void
	{
		// Buscar desde el más antiguo un candidato evictable
		var i = 0;
		while (i < _graphicLRU.length)
		{
			final key = _graphicLRU[i];
			if (!dumpExclusions.contains(key) && !localTrackedAssets.contains(key))
			{
				disposeGraphic(currentTrackedGraphics.get(key));
				currentTrackedGraphics.remove(key);
				_graphicLRU.splice(i, 1);
				// Recalcular posiciones
				for (j in i..._graphicLRU.length)
					_graphicLRUPos.set(_graphicLRU[j], j);
				_graphicLRUPos.remove(key);
				return;
			}
			i++;
		}
		// Si todos están protegidos, ampliar el límite temporalmente
		trace('[PathsCache] LRU: todos los gráficos son exclusiones o están en uso, no se evictó ninguno.');
	}

	/** Evicta el sonido más antiguo del caché (FIFO simple, sin LRU). */
	function _evictOldestSound():Void
	{
		for (key in currentTrackedSounds.keys())
		{
			if (!dumpExclusions.contains(key) && !localTrackedAssets.contains(key))
			{
				Assets.cache.clear(key);
				currentTrackedSounds.remove(key);
				return;
			}
		}
	}

	inline function _graphicCount():Int
	{
		var n = 0;
		for (_ in currentTrackedGraphics) n++;
		return n;
	}

	inline function _soundCount():Int
	{
		var n = 0;
		for (_ in currentTrackedSounds) n++;
		return n;
	}

	// ── LRU helpers ───────────────────────────────────────────────────────────

	inline function _lruPush(key:String):Void
	{
		_graphicLRUPos.set(key, _graphicLRU.length);
		_graphicLRU.push(key);
	}

	function _lruTouch(key:String):Void
	{
		if (!_graphicLRUPos.exists(key)) return;
		final idx = _graphicLRUPos.get(key);
		if (idx == _graphicLRU.length - 1) return;
		_graphicLRU.splice(idx, 1);
		for (i in idx..._graphicLRU.length)
			_graphicLRUPos.set(_graphicLRU[i], i);
		_graphicLRUPos.set(key, _graphicLRU.length);
		_graphicLRU.push(key);
	}

	function _lruRemove(key:String):Void
	{
		if (!_graphicLRUPos.exists(key)) return;
		final idx = _graphicLRUPos.get(key);
		_graphicLRU.splice(idx, 1);
		_graphicLRUPos.remove(key);
		for (i in idx..._graphicLRU.length)
			_graphicLRUPos.set(_graphicLRU[i], i);
	}
}
