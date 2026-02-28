package funkin.cache;

import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import openfl.media.Sound;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

// ── Compatibilidad con OpenFL antiguo / nuevo ─────────────────────────────────
#if (openfl >= "9.2.0")
import openfl.utils.Assets as OpenFLAssets;
#else
import openfl.Assets as OpenFLAssets;
#end
import animationdata.FunkinSprite;

using StringTools;

/**
 * PathsCache v3 — sistema de caché tricapa inspirado en V-Slice FunkinMemory.
 *
 * ─── Capas de caché ──────────────────────────────────────────────────────────
 *
 *   PERMANENTE  — UI esencial, countdown, fonts. Nunca se destruye.
 *   CURRENT     — Assets de la sesión actual (PlayState, menú…). Se rota al cambiar estado.
 *   PREVIOUS    — Assets de la sesión ANTERIOR, aún no destruidos.
 *                 Si el nuevo estado los necesita, se "rescatan" a CURRENT sin
 *                 recargar desde disco → evita stutter al volver al menú.
 *
 * ─── Diferencias con v2 ──────────────────────────────────────────────────────
 *  v2: un solo Map "localTrackedAssets" (Array O(n)) + exclusionSet.
 *  v3: tres Maps independientes + forceGPURender() (carga textura en GPU ANTES del primer draw)
 *
 * ─── Compatibilidad de librerías ─────────────────────────────────────────────
 *  OpenFL ≥ 9.2.0  : openfl.utils.Assets (nuevo path)
 *  OpenFL < 9.2.0  : openfl.Assets (path antiguo)
 *  Flixel ≥ 5.0.0  : FlxG.bitmap.get() devuelve Null<FlxGraphic>
 *  Flixel < 5.0.0  : igual pero sin null-safety
 *
 * @author Cool Engine Team
 * @version 3.0.0
 */
@:access(openfl.display.BitmapData)
class PathsCache
{
	// ── Singleton ─────────────────────────────────────────────────────────────

	public static var instance(get, null):PathsCache;
	static function get_instance():PathsCache
	{
		if (instance == null) instance = new PathsCache();
		return instance;
	}

	// ── Opciones globales ─────────────────────────────────────────────────────

	/**
	 * GPU caching: libera RAM después de subir la textura a la GPU.
	 * Solo tiene efecto en targets nativos (cpp/hl). En web no hace nada.
	 * Desktop con ≥ 2 GB VRAM: true. Dispositivos limitados: false.
	 */
	public static var gpuCaching:Bool =
		#if (desktop && !hl && cpp) true #else false #end;

	public static var lowMemoryMode(default, set):Bool = false;
	static function set_lowMemoryMode(v:Bool):Bool
	{
		lowMemoryMode = v;
		if (instance != null)
		{
			instance.maxGraphics = v ? 30 : 80;
			instance.maxSounds   = v ? 24 : 64;
		}
		return v;
	}

	/** Si true, los assets de música se transmiten desde disco en lugar de cargar en RAM. */
	public static var streamedMusic:Bool = false;

	// ── Límites de caché ─────────────────────────────────────────────────────

	public var maxGraphics:Int = 80;
	public var maxSounds:Int   = 64;

	// ── Tricapa de texturas ───────────────────────────────────────────────────
	// Inspirada directamente en FunkinMemory de V-Slice.

	/** Texturas que NUNCA se destruyen (UI, countdown, fonts). */
	final _permanentGraphics : Map<String, FlxGraphic> = [];

	/** Texturas de la sesión ACTUAL. */
	final _currentGraphics   : Map<String, FlxGraphic> = [];

	/** Texturas de la sesión ANTERIOR — candidatas a destrucción. */
	var   _previousGraphics  : Map<String, FlxGraphic> = [];

	// ── Tricapa de sonidos ────────────────────────────────────────────────────

	final _permanentSounds : Map<String, Sound> = [];
	final _currentSounds   : Map<String, Sound> = [];
	var   _previousSounds  : Map<String, Sound> = [];

	// ── API de compatibilidad pública (expuesta como antes para no romper callers) ──

	/**
	 * Todos los assets de la sesión actual (lectura) — Array para compatibilidad.
	 * El lookup interno usa los Maps, no este array.
	 */
	public var localTrackedAssets(get, never):Array<String>;
	inline function get_localTrackedAssets():Array<String>
	{
		// Construir bajo demanda (no es ruta caliente)
		final out:Array<String> = [];
		for (k in _currentGraphics.keys()) out.push(k);
		for (k in _currentSounds.keys())   out.push(k);
		return out;
	}

	/** Lectura directa de gráficos en caché. */
	public var currentTrackedGraphics(get, never):Map<String, FlxGraphic>;
	inline function get_currentTrackedGraphics() return _currentGraphics;

	/** Lectura directa de sonidos en caché. */
	public var currentTrackedSounds(get, never):Map<String, Sound>;
	inline function get_currentTrackedSounds() return _currentSounds;

	// ── Contadores O(1) ──────────────────────────────────────────────────────

	var _graphicCount : Int = 0;
	var _soundCount   : Int = 0;

	public function graphicCount():Int return _graphicCount;
	public function soundCount():Int   return _soundCount;

	/** Helper: cuenta entradas de un Map (Map no tiene .count() en Haxe std). */
	static inline function _count<K,V>(m:Map<K,V>):Int {
		var n = 0; for (_ in m) n++; return n;
	}

	// ── API de compatibilidad esperada por Paths.hx ───────────────────────────

	/** Devuelve true si la clave existe en alguna capa, el gráfico es no-nulo Y su bitmap no fue dispuesto. */
	public function hasValidGraphic(key:String):Bool {
		// BUGFIX: comprobar bitmap != null, no solo que el objeto FlxGraphic exista.
		// FunkinCache.clearSecondLayer() llama FlxG.bitmap.removeByKey() → g.destroy() → g.bitmap = null,
		// pero PathsCache._currentGraphics sigue sosteniendo la misma referencia muerta.
		// Sin esta comprobación, hasValidGraphic() devuelve true para un gráfico con bitmap=null
		// y el primer draw → FlxDrawQuadsItem::render null-object crash.
		var g = _permanentGraphics.get(key);
		if (g != null) return g.bitmap != null;
		g = _currentGraphics.get(key);
		if (g != null) {
			if (g.bitmap != null) return true;
			// Evictar entrada stale para que la siguiente carga lo recargue desde disco
			_currentGraphics.remove(key);
			_graphicCount--;
			return false;
		}
		g = _previousGraphics.get(key);
		if (g != null) return g.bitmap != null;
		return false;
	}

	/** Retorna el gráfico sin cargarlo desde disco (peek). */
	public inline function peekGraphic(key:String):Null<FlxGraphic> return getGraphic(key);

	/** Devuelve true si el sonido está en caché. */
	public function hasSound(key:String):Bool {
		if (_permanentSounds.exists(key)) return true;
		if (_currentSounds.exists(key))   return true;
		if (_previousSounds.exists(key))  return true;
		return false;
	}

	// ── Constructor ───────────────────────────────────────────────────────────

	function new() {}

	// ═══════════════════════════════════════════════════════════════════════════
	// GESTIÓN DE SESIÓN
	// ═══════════════════════════════════════════════════════════════════════════

	/**
	 * Inicia una nueva sesión.
	 * Los assets de current pasan a previous.
	 * Los assets que se carguen ahora se añaden a current.
	 */
	public function beginSession():Void
	{
		// No-op: FunkinCache maneja el lifecycle via preStateSwitch/postStateSwitch.
		// PathsCache ya no destruye FlxGraphics durante cambios de estado — es solo un loader.
		trace('[PathsCache] beginSession() — no-op, FunkinCache gestiona el lifecycle');
	}

	/**
	 * Rota las capas de gráficos: _current → _previous, _previous descartada.
	 * Llamar desde FunkinCache.preStateSwitch, ANTES de que el nuevo estado cargue assets.
	 *
	 * Por qué es necesario:
	 *   FunkinCache.clearSecondLayer() llama FlxG.bitmap.removeByKey() → g.destroy()
	 *   → g.bitmap = null sobre los gráficos de la sesión anterior.
	 *   Sin esta rotación, PathsCache._currentGraphics retiene esos FlxGraphics muertos
	 *   indefinidamente. hasValidGraphic() veía el objeto != null y devolvía true.
	 *   El nuevo estado obtenía un gráfico con bitmap=null, lo usaba en FlxAtlasFrames,
	 *   y el primer draw → FlxDrawQuadsItem::render → null-object crash.
	 *
	 * Con esta rotación:
	 *   - Los gráficos actuales se mueven a _previousGraphics.
	 *   - Si el nuevo estado los necesita, getGraphic() los rescata a _current (siempre
	 *     que bitmap != null — si ya fueron destruidos se descartan y se recargan).
	 *   - _currentGraphics queda vacío → hasValidGraphic() devuelve false → carga limpia.
	 */
	public function rotateSession():Void
	{
		// _currentGraphics y _previousGraphics son `final` — no se pueden reasignar.
		// Copiar current → previous y limpiar current en su lugar.
		_previousGraphics.clear();
		for (k => g in _currentGraphics)
			_previousGraphics.set(k, g);
		_currentGraphics.clear();
		_graphicCount = 0;
		// Nota: _permanentGraphics NO se rota — nunca se destruyen.
	}

	// ═══════════════════════════════════════════════════════════════════════════
	// TEXTURAS
	// ═══════════════════════════════════════════════════════════════════════════

	/**
	 * Carga o rescata una textura.
	 * Si existe en previous → la rescata sin tocar disco.
	 * Si existe en permanent/current → no hace nada.
	 * Si no existe → carga desde disco y la sube a GPU.
	 */
	public function cacheGraphic(key:String):Null<FlxGraphic>
	{
		// Ya en current o permanent
		if (_currentGraphics.exists(key)) return _currentGraphics.get(key);

		// Rescatar de previous (evita recarga desde disco)
		if (_previousGraphics.exists(key))
		{
			final g = _previousGraphics.get(key);
			_previousGraphics.remove(key);
			// BUGFIX: el gráfico puede haber sido destruido por clearPreviousSession() llamado
			// desde PlayState.destroy(). destroy() pone bitmap=null. No meter ese gráfico en
			// _currentGraphics — recargar desde disco en su lugar.
			if (g != null && g.bitmap != null)
			{
				_currentGraphics.set(key, g);
				_graphicCount++;
				// GPU caching: esta textura YA fue dibujada en la sesión anterior →
				// el upload a VRAM ocurrió. Es seguro llamar disposeImage() ahora.
				// Nota: a diferencia de _loadGraphic() (carga nueva), aquí no hay
				// riesgo de disponer antes del primer draw porque ya fue renderizada.
				#if (cpp && !hl)
				try {
					if (FlxG.stage != null && FlxG.stage.context3D != null) {
						final tex = g.bitmap.getTexture(FlxG.stage.context3D);
						if (tex != null) {
							@:privateAccess
							if (g.bitmap.image != null) g.bitmap.disposeImage();
						}
					}
				} catch (_:Dynamic) {}
				#end
				return g;
			}
			// Gráfico inválido — caer al _loadGraphic abajo
		}

		// Cargar desde disco
		return _loadGraphic(key, false);
	}

	/**
	 * Carga una textura y la marca como permanente.
	 * Usada durante el pre-caché de arranque.
	 */
	public function permanentCacheGraphic(key:String):Null<FlxGraphic>
	{
		if (_permanentGraphics.exists(key)) return _permanentGraphics.get(key);
		final g = _loadGraphic(key, true);
		if (g != null) { _permanentGraphics.set(key, g); _currentGraphics.set(key, g); }
		return g;
	}

	/** Registra un FlxGraphic ya existente en la sesión actual. */
	public function trackGraphic(key:String, graphic:FlxGraphic):Void
	{
		if (_currentGraphics.exists(key)) return;
		graphic.persist = true;
		_currentGraphics.set(key, graphic);
		_graphicCount++;
	}

	/**
	 * Rescata un FlxGraphic de _previousGraphics a _currentGraphics.
	 * Llamar cuando un atlas cacheado se reutiliza entre sesiones para
	 * evitar que su gráfico sea destruido por clearPreviousSession().
	 *
	 * BUGFIX: también rescata el BitmapData subyacente en FunkinCache.
	 * Sin esto, FunkinCache.clearSecondLayer() llama dispose() sobre el
	 * BitmapData que este FlxGraphic sigue usando → graphic.bitmap = null
	 * → FlxDrawQuadsItem::render null-object crash en el primer frame.
	 */
	public function rescueFromPrevious(key:String, graphic:FlxGraphic):Void
	{
		if (_currentGraphics.exists(key) || _permanentGraphics.exists(key)) return;
		if (_previousGraphics.exists(key))
		{
			_previousGraphics.remove(key);
		}
		graphic.persist = true;
		_currentGraphics.set(key, graphic);
		_graphicCount++;
	}

	/** Devuelve un FlxGraphic buscando en todas las capas. */
	public function getGraphic(key:String, ?bitmapData:openfl.display.BitmapData, allowGPU:Bool = true):Null<FlxGraphic>
	{
		// BUGFIX: siempre verificar bitmap != null antes de devolver un gráfico.
		// FunkinCache.clearSecondLayer() puede haber destruido el gráfico (g.bitmap = null)
		// mientras PathsCache._currentGraphics sigue sosteniendo la referencia.
		// Devolver un gráfico muerto → FlxAtlasFrames con bitmap=null → crash en primer render.
		var gPerm = _permanentGraphics.get(key);
		if (gPerm != null)
		{
			if (gPerm.bitmap != null) return gPerm;
			_permanentGraphics.remove(key); // permanente destruido — limpiar y recargar
		}
		var gCur = _currentGraphics.get(key);
		if (gCur != null)
		{
			if (gCur.bitmap != null) return gCur;
			// Stale: evictar para que la siguiente carga lo recargue desde disco
			_currentGraphics.remove(key);
			_graphicCount--;
		}
		// ── RESCUE: mover de previous a current para que sobreviva esta sesión ──
		if (_previousGraphics.exists(key))
		{
			final g = _previousGraphics.get(key);
			_previousGraphics.remove(key);
			// BUGFIX: si el gráfico fue destruido (bitmap=null), no rescatar — recargar.
			if (g != null && g.bitmap != null)
			{
				_currentGraphics.set(key, g);
				_graphicCount++;
						return g;
			}
			// Caer al bloque de bitmapData / retorno nulo abajo
		}
		// If a BitmapData was supplied, create and register the graphic now
		if (bitmapData != null) {
			var g = FlxGraphic.fromBitmapData(bitmapData, false, key, true);
			if (g != null) {
				g.persist = true;
				if (allowGPU) _forceGPURender(g);
				_currentGraphics.set(key, g);
				_graphicCount++;
			}
			return g;
		}
		return null;
	}

	function _loadGraphic(key:String, permanent:Bool):Null<FlxGraphic>
	{
		// Intentar con FlxG.bitmap primero (puede que Flixel ya lo tenga en caché propia)
		var existing = FlxG.bitmap.get(key);
		if (existing != null)
		{
			// BUGFIX CRÍTICO — FlxDrawQuadsItem::render null object reference:
			// FlxG.bitmap._cache conserva entradas cuyo FlxGraphic fue destruido por
			// clearPreviousSession() (llamado desde PlayState.destroy() vía clearUnusedMemory).
			// destroy() llama bitmap.dispose() → bitmap = null, pero la entrada sigue en el cache.
			// Si aceptamos ese gráfico sin verificar, lo metemos en _currentGraphics con bitmap=null
			// → FlxDrawQuadsItem::render falla en el primer frame con null object reference.
			// Solución: si bitmap es null, eliminar la entrada huérfana y recargar desde disco.
			if (existing.bitmap == null)
			{
				trace('[PathsCache] FlxGraphic huérfano detectado para "$key" (bitmap=null), recargando desde disco.');
				@:privateAccess FlxG.bitmap.removeKey(key);
				existing = null;
				// Caer al bloque de carga desde disco abajo
			}
			else
			{
				existing.persist = true;
				_currentGraphics.set(key, existing);
				_graphicCount++;
				// BUGFIX (crash FlxDrawQuadsItem::render):
				// FlxG.bitmap todavía contiene FlxGraphics de la sesión anterior —
				// no se limpian hasta postStateSwitch → clearPreviousSession().
				// Su BitmapData fue movido a bitmapData2 por moveToSecondLayer().
				// Si no lo rescatamos aquí, clearSecondLayer() llama dispose() sobre él
				// mientras este FlxGraphic (ya en _currentGraphics) sigue usándolo →
				// bitmap dispuesto en el primer frame de render → crash.
						return existing;
			}
		}

		// Cargar vía FlxGraphic.fromAssetKey — igual que V-Slice FunkinMemory.cacheTexture().
		// Es más directo que getBitmapData → fromBitmapData y funciona con todas las
		// versiones de OpenFL porque delega la resolución al pipeline nativo de Flixel.
		var g:FlxGraphic = null;
		try
		{
			g = FlxGraphic.fromAssetKey(key, false, null, true);
		}
		catch (e:Dynamic) { trace('[PathsCache] Error cargando "$key": $e'); return null; }

		if (g == null)
		{
			trace('[PathsCache] No se pudo cargar "$key"');
			return null;
		}

		g.persist = true;

		// GPU pre-render: llama getTexture() para registrar la textura en el pipeline de OpenFL.
		// El upload real de pixels ocurre en el PRIMER DRAW CALL del render thread.
		// NO llamamos disposeImage() aquí — los pixels deben existir hasta ese primer draw.
		// flushGPUCache() (llamado 5 frames después via ENTER_FRAME en PlayState.create())
		// se encarga de liberar los pixels DESPUÉS de confirmar que el render ocurrió.
		_forceGPURender(g);

		_currentGraphics.set(key, g);
		_graphicCount++;
		return g;
	}

	/**
	 * Pre-carga la textura en la GPU dibujando un sprite temporal.
	 * Replicado de V-Slice FunkinMemory.forceRender() para evitar el stutter
	 * del primer frame en el que OpenGL sube la textura.
	 *
	/**
	 * Pre-sube la textura a VRAM usando getTexture() directo.
	 *
	 * El dummy FlxSprite + draw() fue eliminado: instanciar un FlxSprite fuera
	 * del render loop causa stutter durante el precacheo (especialmente al
	 * cargar 40-100 texturas en LoadingState→PlayState). Flixel sube la textura
	 * a GPU en el primer draw call real, lo que ocurre suavemente dentro del
	 * frame loop cuando la loading screen ya está visible.
	 *
	 * getTexture() se mantiene como optimización opcional para context3D
	 * disponible (desktop, no web/mobile).
	 */
	static function _forceGPURender(graphic:FlxGraphic):Void
	{
		if (graphic == null || graphic.bitmap == null) return;
		#if (desktop && !hl)
		try
		{
			if (FlxG.stage != null && FlxG.stage.context3D != null)
				graphic.bitmap.getTexture(FlxG.stage.context3D);
		}
		catch (_:Dynamic) {}
		#end
	}

	// ═══════════════════════════════════════════════════════════════════════════
	// SONIDOS
	// ═══════════════════════════════════════════════════════════════════════════

	public function cacheSound(key:String):Null<Sound>
	{
		if (_currentSounds.exists(key)) return _currentSounds.get(key);

		// Rescatar de previous
		if (_previousSounds.exists(key))
		{
			final s = _previousSounds.get(key);
			_previousSounds.remove(key);
			if (s != null) { _currentSounds.set(key, s); _soundCount++; }
			return s;
		}

		return _loadSound(key, false);
	}

	public function permanentCacheSound(key:String):Null<Sound>
	{
		if (_permanentSounds.exists(key)) return _permanentSounds.get(key);
		final s = _loadSound(key, true);
		if (s != null) { _permanentSounds.set(key, s); _currentSounds.set(key, s); }
		return s;
	}

	public function getSound(key:String, ?sound:Sound, safety:Bool = false):Null<Sound>
	{
		if (_permanentSounds.exists(key)) return _permanentSounds.get(key);
		if (_currentSounds.exists(key))   return _currentSounds.get(key);
		if (_previousSounds.exists(key))  return _previousSounds.get(key);
		if (sound != null) {
			_currentSounds.set(key, sound);
			_soundCount++;
			return sound;
		}
		return null;
	}

	function _loadSound(key:String, permanent:Bool):Null<Sound>
	{
		var sound:Sound = null;
		try
		{
			if (OpenFLAssets.exists(key, openfl.utils.AssetType.SOUND)
			 || OpenFLAssets.exists(key, openfl.utils.AssetType.MUSIC))
				sound = OpenFLAssets.getSound(key, true);
		}
		catch (e:Dynamic) { trace('[PathsCache] Error de audio "$key": $e'); return null; }

		if (sound == null) return null;

		_currentSounds.set(key, sound);
		_soundCount++;
		return sound;
	}

	// ═══════════════════════════════════════════════════════════════════════════
	// LIBERACIÓN DE MEMORIA
	// ═══════════════════════════════════════════════════════════════════════════

	/**
	 * Destruye los assets de la sesión ANTERIOR que no fueron rescatados.
	 * Llamar después de `beginSession()` cuando la nueva sesión ya cargó sus assets.
	 */
	/**
	 * DEPRECATED — la destrucción de assets la hace FunkinCache.clearSecondLayer()
	 * via FlxG.bitmap.removeByKey (modelo Codename). Mantener como no-op para
	 * compatibilidad con Paths.clearPreviousSession() en PlayState/LoadingState.
	 */
	public function clearPreviousSession():Void
	{
		// No-op: FunkinCache.postStateSwitch ya llama clearSecondLayer() que
		// usa FlxG.bitmap.removeByKey para destruir los gráficos no rescatados.
		// Destruir FlxGraphics aquí (como hacía antes) causaba el crash porque
		// se destruían DESPUÉS de que los sprites del nuevo estado los cargaron.
		trace('[PathsCache] clearPreviousSession() — no-op, FunkinCache gestiona la destrucción');
	}

	

	function _clearPreviousGraphics():Void
	{
		// No-op: FunkinCache.clearSecondLayer() via FlxG.bitmap.removeByKey() maneja la destrucción.
		// Destruir FlxGraphics aquí causaba crashes porque ocurría después de que
		// los sprites del nuevo estado ya tenían referencias a esos gráficos.
		_previousGraphics.clear();
	}

	function _clearPreviousSounds():Void
	{
		for (key => sound in _previousSounds)
		{
			if (_permanentSounds.exists(key)) { _previousSounds.remove(key); continue; }
			if (sound == null) { _previousSounds.remove(key); continue; }
			try { OpenFLAssets.cache.removeSound(key); } catch(_) {}
			_previousSounds.remove(key);
		}

		// Limpiar las librerías de canciones completas — igual que V-Slice purgeSoundCache().
		// removeSound() por key individual no libera los bundles de audio de OpenFL.
		try { OpenFLAssets.cache.clear('songs'); }  catch(_) {}
		try { OpenFLAssets.cache.clear('music'); }  catch(_) {}

		if (_soundCount > maxSounds) _soundCount = _count(_currentSounds);
	}

	/** Limpieza completa (al salir del juego). */
	public function destroy():Void
	{
		_clearPreviousGraphics();
		for (k => g in _currentGraphics)
		{
			if (_permanentGraphics.exists(k)) continue;
			if (g == null) continue;
			FlxG.bitmap.remove(g);
			g.persist = false;
			try { g.destroy(); } catch(_) {}
		}
		_currentGraphics.clear();
		_permanentGraphics.clear();
		_currentSounds.clear();
		_permanentSounds.clear();
		_previousSounds.clear();
		_graphicCount = 0;
		_soundCount   = 0;
	}

	/** Limpieza de assets de un contexto específico (p.ej. "freeplay"). */
	public function clearContext(contextTag:String):Void
	{
		final toRemove:Array<String> = [];

		@:privateAccess
		if (FlxG.bitmap._cache != null)
		{
			@:privateAccess
			for (k in FlxG.bitmap._cache.keys())
			{
				if (!k.contains(contextTag)) continue;
				if (_permanentGraphics.exists(k) || k.contains('fonts')) continue;
				toRemove.push(k);
			}
		}

		for (k in toRemove)
		{
			final g = FlxG.bitmap.get(k);
			if (g != null) { g.destroy(); @:privateAccess FlxG.bitmap.removeKey(k); }
			_currentGraphics.remove(k);
			try { OpenFLAssets.cache.clear(k); } catch(_) {}
		}
	}

	// ═══════════════════════════════════════════════════════════════════════════
	// COMPAT — métodos esperados por Paths.hx y el resto del engine
	// ═══════════════════════════════════════════════════════════════════════════

	/** Lista de claves pendientes de marcar como permanentes. */
	var _pendingExclusions:Array<String> = [];

	/**
	 * Marca una clave como permanente (nunca se evicta).
	 * Si el asset ya está cargado en current, lo promueve a permanente.
	 * Si aún no está cargado, lo anota para promoverlo cuando se cargue.
	 */
	public function addExclusion(key:String):Void
	{
		final g = _currentGraphics.get(key);
		if (g != null) { _permanentGraphics.set(key, g); return; }
		final s = _currentSounds.get(key);
		if (s != null) { _permanentSounds.set(key, s); return; }
		if (!_pendingExclusions.contains(key))
			_pendingExclusions.push(key);
	}

	/** Libera assets de la sesión anterior. FunkinCache maneja la destrucción real. */
	public function clearStoredMemory():Void
	{
		// FunkinCache.clearSecondLayer() ya destruye via removeByKey en postStateSwitch.
		// Esta función queda como no-op para compatibilidad con Paths.clearStoredMemory().
		try { FlxG.bitmap.clearUnused(); } catch (_:Dynamic) {}
	}

	/** Destruye gráficos sin uso y fuerza GC. */
	public function clearUnusedMemory():Void
	{
		try { FlxG.bitmap.clearUnused(); } catch (_:Dynamic) {}
		try { openfl.system.System.gc(); } catch (_:Dynamic) {}
		#if cpp
		cpp.vm.Gc.run(true);
		try { cpp.vm.Gc.compact(); } catch (_:Dynamic) {}
		#end
		#if hl hl.Gc.major(); #end
	}

	/**
	 * GPU caching post-load flush: libera la RAM (imagen CPU) de todos los
	 * gráficos de la sesión actual que ya hayan sido subidos a VRAM.
	 *
	 * Llamar DESPUÉS de que el state haya completado su create() y haya
	 * renderizado al menos un frame — garantiza que context3D esté listo
	 * y que todas las texturas hayan sido subidas por OpenFL.
	 *
	 * Solo efectivo en desktop C++ (requiere OpenGL context3D).
	 * Libera típicamente 50-400 MB de RAM en canciones con muchos sprites.
	 */
	public function flushGPUCache():Void
	{
		#if (cpp && !hl)
		if (FlxG.stage == null || FlxG.stage.context3D == null) return;
		final ctx = FlxG.stage.context3D;
		var released = 0;
		var skipped  = 0;
		for (g in _currentGraphics)
		{
			if (g == null || g.bitmap == null) continue;
			// Nunca liberar permanentes — se reutilizan en cada state sin recarga
			if (_permanentGraphics.exists(g.key)) continue;
			// Si ya fue dispuesto (bitmap.image == null), saltear
			@:privateAccess
			if (g.bitmap.image == null) continue;
			try
			{
				final tex = g.bitmap.getTexture(ctx);
				if (tex != null)
				{
					g.bitmap.disposeImage(); // libera pixels CPU manteniendo textura GPU
					released++;
				}
				else
				{
					skipped++;
				}
			}
			catch (_:Dynamic) {}
		}
		if (released > 0 || skipped > 0)
			trace('[PathsCache] flushGPUCache: $released texturas liberadas a VRAM-only, $skipped sin textura GPU aún');
		#end
	}

	/**
	 * Versión selectiva: libera RAM de una textura específica si ya fue subida a VRAM.
	 * Útil para liberar sprites de personaje/stage individualmente.
	 */
	public function flushGPUCacheFor(key:String):Void
	{
		#if (cpp && !hl)
		if (FlxG.stage == null || FlxG.stage.context3D == null) return;
		var g = _currentGraphics.get(key);
		if (g == null) g = _previousGraphics.get(key);
		if (g == null || g.bitmap == null) return;
		try
		{
			final tex = g.bitmap.getTexture(FlxG.stage.context3D);
			@:privateAccess
			if (tex != null && g.bitmap.image != null) g.bitmap.disposeImage();
		}
		catch (_:Dynamic) {}
		#end
	}

	/** Limpieza total — alias de destroy() para cambio de mod / reinicio. */
	public function forceFullClear():Void
		destroy();

	/** Limpia assets de gameplay (prefijos char_, stage_, skin_). */
	public function clearGameplayAssets():Void
	{
		for (prefix in ['char_', 'stage_', 'skin_'])
			clearContext(prefix);
	}

	/** String compacto para el overlay de debug. */
	public function debugString():String
		return 'Cache: ${_count(_currentGraphics)} tex / ${_count(_currentSounds)} snd';

	/** Stats completos (alias de getStats). */
	public function fullStats():String
		return getStats();

	// ═══════════════════════════════════════════════════════════════════════════
	// STATS / DEBUG
	// ═══════════════════════════════════════════════════════════════════════════

	public function getStats():String
	{
		return '[PathsCache v3] Permanent: ${_count(_permanentGraphics)} tex / ${_count(_permanentSounds)} snd'
			+ ' | Current: ${_count(_currentGraphics)} tex / ${_count(_currentSounds)} snd'
			+ ' | Previous: ${_count(_previousGraphics)} tex / ${_count(_previousSounds)} snd';
	}
}
