package animationdata;

import flxanimate.FlxAnimate;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.math.FlxPoint;
import openfl.utils.Assets as OpenFlAssets;

#if sys
import sys.FileSystem;
#end

using StringTools;

/**
 * FunkinSprite — Sprite unificado del engine con caché de frames avanzada.
 * ─────────────────────────────────────────────────────────────────────────────
 * Detecta automáticamente el tipo de asset:
 *   ① Texture Atlas (Adobe Animate)  → carpeta con Animation.json
 *   ② Sparrow Atlas                  → PNG + XML
 *   ③ Packer Atlas                   → PNG + TXT
 *   ④ Imagen estática                → Solo PNG
 *
 * ─── Mejoras de caché (v2) ───────────────────────────────────────────────────
 *  • _frameCache    — Cachea FlxAtlasFrames parseados. Si dos personajes usan
 *                     el mismo sheet, comparten frames sin duplicar el parsing
 *                     de XML/TXT ni VRAM (el FlxGraphic subyacente ya se
 *                     comparte via PathsCache).
 *  • _atlasResCache — Cachea el resultado de resolveAtlasFolder() (si la
 *                     carpeta existe o no). Evita llamar FileSystem.exists()
 *                     repetidamente para el mismo key, que en HDD es ~0.5ms
 *                     por llamada y puede acumularse en stages con muchos sprites.
 *  • invalidateCache(key)  — API pública para invalidar entradas específicas al
 *                            recargar mods en caliente.
 *  • clearAllCaches()      — Limpieza total (cambio de mod, reinicio, etc.)
 */
class FunkinSprite extends FlxSprite
{
	// ─── Estado ────────────────────────────────────────────────────────────────
	public var isAnimateAtlas(default, null):Bool = false;

	/** Key del asset actualmente cargado */
	public var currentAssetKey(default, null):String = '';

	/** Instancia interna de FlxAnimate (sólo cuando isAnimateAtlas = true) */
	var _animateSprite:FlxAnimate;

	// ══════════════════════════════════════════════════════════════════════════
	//  CACHÉS ESTÁTICOS
	// ══════════════════════════════════════════════════════════════════════════

	/**
	 * Caché de FlxAtlasFrames parseados.
	 *
	 * key   → path completo al asset (p. ej. "assets/characters/images/bf")
	 * value → FlxAtlasFrames ya parseado y listo para asignar a .frames
	 *
	 * VRAM: los frames sólo contienen FlxRect + referencia al FlxGraphic.
	 * El FlxGraphic (textura real) ya está cacheado en PathsCache.
	 * Por tanto este caché es ligero (~1-4 KB por atlas).
	 */
	static var _frameCache:Map<String, FlxAtlasFrames> = [];

	/**
	 * Caché de resolución de carpetas de atlas.
	 *
	 * key   → key de asset (sin extensión)
	 * value → path a la carpeta si tiene Animation.json, null si no
	 *
	 * Evita llamadas repetidas a FileSystem.exists() para el mismo key.
	 */
	static var _atlasResCache:Map<String, Null<String>> = [];

	/** LRU simple para _frameCache (máx. 120 entradas; los frames son ligeros) */
	static var _frameLRU:Array<String> = [];
	static final MAX_FRAME_CACHE = 120;

	// ── API de invalidación ────────────────────────────────────────────────────

	/**
	 * Invalida una entrada del caché de frames y de resolución de atlas.
	 * Útil al recargar un mod en caliente: el asset puede haber cambiado.
	 */
	public static function invalidateCache(key:String):Void
	{
		_frameCache.remove(key);
		_atlasResCache.remove(key);
		final idx = _frameLRU.indexOf(key);
		if (idx >= 0) _frameLRU.splice(idx, 1);
		trace('[FunkinSprite] Cache invalidado: $key');
	}

	/**
	 * Limpia todos los cachés estáticos.
	 * Llamar al cambiar de mod o al reiniciar el engine.
	 */
	public static function clearAllCaches():Void
	{
		_frameCache.clear();
		_atlasResCache.clear();
		_frameLRU  = [];
		trace('[FunkinSprite] Todos los cachés limpiados.');
	}

	/**
	 * Elimina del _frameCache solo las entradas cuyo atlas ya no es válido
	 * (bitmap dispuesto o graphic nulo). Preserva entradas válidas de la
	 * sesión actual para que los sprites en pantalla puedan reutilizarlas.
	 * Llamar desde PathsCache.clearPreviousSession() en lugar de clearAllCaches().
	 */
	public static function pruneStaleCache():Void
	{
		final toRemove:Array<String> = [];
		for (key => atlas in _frameCache)
		{
			@:privateAccess
			final valid = atlas != null && atlas.parent != null && atlas.parent.bitmap != null;
			if (!valid)
				toRemove.push(key);
		}
		for (key in toRemove)
			_frameCache.remove(key);
		if (toRemove.length > 0)
			trace('[FunkinSprite] pruneStaleCache: ${toRemove.length} entradas stale eliminadas.');
	}

	// ── Internos de LRU ───────────────────────────────────────────────────────

	static function _frameCachePut(key:String, frames:FlxAtlasFrames):Void
	{
		if (_frameLRU.length >= MAX_FRAME_CACHE)
		{
			// Evictar el más antiguo
			final evict = _frameLRU.shift();
			_frameCache.remove(evict);
		}
		_frameCache.set(key, frames);
		_frameLRU.push(key);
	}

	static function _frameCacheTouch(key:String):Void
	{
		final idx = _frameLRU.indexOf(key);
		if (idx >= 0)
		{
			_frameLRU.splice(idx, 1);
			_frameLRU.push(key);
		}
	}

	// ══════════════════════════════════════════════════════════════════════════
	//  CONSTRUCTOR
	// ══════════════════════════════════════════════════════════════════════════

	public function new(x:Float = 0, y:Float = 0)
	{
		super(x, y);
	}

	// ══════════════════════════════════════════════════════════════════════════
	//  CARGA DE ASSETS
	// ══════════════════════════════════════════════════════════════════════════

	/**
	 * Carga automática — detecta el tipo de asset según los archivos disponibles.
	 *
	 * Prioridad:
	 *   1. Carpeta con Animation.json  → Texture Atlas
	 *   2. PNG + XML                   → Sparrow
	 *   3. PNG + TXT                   → Packer
	 *   4. Solo PNG                    → Estático
	 *
	 * @param assetPath  Path sin extensión (relativo a assets/)
	 *                   Ej: "characters/images/bf"
	 */
	public function loadAsset(assetPath:String):FunkinSprite
	{
		currentAssetKey = assetPath;

		final atlasFolder = resolveAtlasFolder(assetPath);
		if (atlasFolder != null)
			return loadAnimateAtlas(atlasFolder);

		if (assetExists('assets/$assetPath.xml'))
			return loadSparrow(assetPath);

		if (assetExists('assets/$assetPath.txt'))
			return loadPacker(assetPath);

		if (assetExists('assets/$assetPath.png'))
			loadGraphic('assets/$assetPath.png');
		else
			trace('[FunkinSprite] WARNING: no se encontró ningún asset para "$assetPath"');

		isAnimateAtlas = false;
		return this;
	}

	/**
	 * Carga un Texture Atlas de Adobe Animate.
	 * No usa _frameCache porque FlxAnimate gestiona sus propios frames internamente.
	 */
	public function loadAnimateAtlas(folderPath:String):FunkinSprite
	{
		isAnimateAtlas = true;

		final fullPath = folderPath.startsWith('assets/') ? folderPath : 'assets/$folderPath';

		if (_animateSprite != null)
		{
			_animateSprite.destroy();
			_animateSprite = null;
		}

		_animateSprite = new FlxAnimate(x, y);
		_animateSprite.loadAtlas(fullPath);
		// No establecer visible=false aquí: el override de draw() ya delega en
		// _animateSprite.draw() y nunca llama super.draw(), así que el sprite
		// base no se pinta. Poner visible=false impide que FlxGroup llame draw()
		// y el atlas nunca se renderiza.

		trace('[FunkinSprite] Texture Atlas cargado: $fullPath');
		return this;
	}

	/**
	 * Carga un Sparrow atlas (PNG + XML) con caché de frames.
	 *
	 * Si ya se cargó este asset antes, reutiliza los FlxAtlasFrames cacheados
	 * en lugar de volver a parsear el XML completo.
	 */
	public function loadSparrow(key:String):FunkinSprite
	{
		isAnimateAtlas = false;
		_clearAnimateSprite();
		visible = true;

		final cacheKey = 'sparrow:$key';
		var cached = _frameCache.get(cacheKey);
		if (cached != null)
		{
			@:privateAccess
			final valid = cached.parent != null && cached.parent.bitmap != null;
			if (valid)
			{
				// BUGFIX: rescue the FlxGraphic from _previousGraphics → _currentGraphics
				// so that Paths.clearPreviousSession() doesn't destroy it while this
				// sprite still holds a reference via this.frames.
				_frameCacheTouch(cacheKey);
				this.frames = cached;
				return this;
			}
			// Atlas stale → evict and reload
			_frameCache.remove(cacheKey);
			final idx = _frameLRU.indexOf(cacheKey);
			if (idx >= 0) _frameLRU.splice(idx, 1);
		}

		final frames = Paths.getSparrowAtlas(key);
		if (frames != null)
		{
			_frameCachePut(cacheKey, frames);
			this.frames = frames;
			trace('[FunkinSprite] Sparrow cargado: $key');
		}
		else
		{
			trace('[FunkinSprite] WARNING: Sparrow no encontrado para "$key"');
		}

		return this;
	}

	/**
	 * Carga un Packer atlas (PNG + TXT) con caché de frames.
	 */
	public function loadPacker(key:String):FunkinSprite
	{
		isAnimateAtlas = false;
		_clearAnimateSprite();
		visible = true;

		final cacheKey = 'packer:$key';
		var cached = _frameCache.get(cacheKey);
		if (cached != null)
		{
			@:privateAccess
			final valid = cached.parent != null && cached.parent.bitmap != null;
			if (valid)
			{
				// BUGFIX: rescue the FlxGraphic from _previousGraphics → _currentGraphics
				_frameCacheTouch(cacheKey);
				this.frames = cached;
				return this;
			}
			// Atlas stale → evict and reload
			_frameCache.remove(cacheKey);
			final idx = _frameLRU.indexOf(cacheKey);
			if (idx >= 0) _frameLRU.splice(idx, 1);
		}

		final frames = Paths.getPackerAtlas(key);
		if (frames != null)
		{
			_frameCachePut(cacheKey, frames);
			this.frames = frames;
			trace('[FunkinSprite] Packer cargado: $key');
		}
		else
		{
			trace('[FunkinSprite] WARNING: Packer no encontrado para "$key"');
		}

		return this;
	}

	/**
	 * Carga un sprite de personaje (assets/characters/images/) con caché de frames.
	 *
	 * Orden: Texture Atlas → Sparrow → Packer → placeholder invisible.
	 * Usa _frameCache para Sparrow/Packer, evitando re-parsear el XML/TXT
	 * cuando el mismo personaje aparece en varias escenas o se recarga.
	 */
	public function loadCharacterSparrow(key:String):FunkinSprite
	{
		final atlasPath   = 'characters/images/$key';
		final atlasFolder = resolveAtlasFolder(atlasPath);
		if (atlasFolder != null)
			return loadAnimateAtlas(atlasFolder);

		isAnimateAtlas = false;
		_clearAnimateSprite();
		visible = true;

		// ── Sparrow via caché ─────────────────────────────────────────────────
		final cacheKey = 'char_sparrow:$key';
		var cached = _frameCache.get(cacheKey);
		if (cached != null)
		{
			// BUGFIX: Validar bitmap antes de reutilizar — atlas stale → FlxDrawQuadsItem crash
			@:privateAccess
			final valid = cached.parent != null && cached.parent.bitmap != null;
			if (valid)
			{
				_frameCacheTouch(cacheKey);
				this.frames = cached;
				return this;
			}
			_frameCache.remove(cacheKey);
		}

		var frames = Paths.characterSprite(key);
		if (frames != null)
		{
			_frameCachePut(cacheKey, frames);
			this.frames = frames;
			return this;
		}

		// ── Packer fallback ───────────────────────────────────────────────────
		final cacheKeyTxt = 'char_packer:$key';
		var cachedTxt = _frameCache.get(cacheKeyTxt);
		if (cachedTxt != null)
		{
			// BUGFIX: misma validación de atlas stale
			@:privateAccess
			final validTxt = cachedTxt.parent != null && cachedTxt.parent.bitmap != null;
			if (validTxt)
			{
				// BUGFIX #2: rescue del FlxGraphic de _previousGraphics → _currentGraphics
				_frameCacheTouch(cacheKeyTxt);
				this.frames = cachedTxt;
				return this;
			}
			_frameCache.remove(cacheKeyTxt);
		}

		var framesTxt = Paths.characterSpriteTxt(key);
		if (framesTxt != null)
		{
			_frameCachePut(cacheKeyTxt, framesTxt);
			this.frames = framesTxt;
			return this;
		}

		// ── Placeholder invisible ─────────────────────────────────────────────
		trace('[FunkinSprite] WARNING: No graphics found for "$key" — usando placeholder invisible');
		makeGraphic(1, 1, 0x00000000);
		visible = false;
		return this;
	}

	/**
	 * Carga un sprite de stage (assets/stages/STAGE/images/) con caché de frames.
	 */
	public function loadStageSparrow(key:String):FunkinSprite
	{
		isAnimateAtlas = false;
		_clearAnimateSprite();
		visible = true;

		final cacheKey = 'stage_sparrow:$key';
		var cached = _frameCache.get(cacheKey);
		if (cached != null)
		{
			// BUGFIX: Validar que el atlas cacheado sigue siendo válido (bitmap no dispuesto).
			// Un atlas stale de una sesión anterior causa FlxDrawQuadsItem crash en el primer render.
			@:privateAccess
			final valid = cached.parent != null && cached.parent.bitmap != null;
			if (valid)
			{
				_frameCacheTouch(cacheKey);
				this.frames = cached;
				return this;
			}
			// Atlas inválido → eliminarlo del caché y recargar
			_frameCache.remove(cacheKey);
		}

		final frames = Paths.stageSprite(key);
		if (frames != null)
		{
			_frameCachePut(cacheKey, frames);
			this.frames = frames;
		}
		else
		{
			// BUGFIX: Sin este fallback, this.frames queda null y el sprite se renderiza igual
			// → crash en FlxDrawQuadsItem::render. Usar placeholder invisible como loadCharacterSparrow.
			trace('[FunkinSprite] WARNING: Stage asset no encontrado para "$key" — placeholder invisible');
			makeGraphic(1, 1, 0x00000000);
			visible = false;
		}
		return this;
	}

	// ── Helper interno ────────────────────────────────────────────────────────

	inline function _clearAnimateSprite():Void
	{
		if (_animateSprite != null)
		{
			_animateSprite.destroy();
			_animateSprite = null;
		}
	}

	// ══════════════════════════════════════════════════════════════════════════
	//  WRAPPER DE ANIMACIONES
	// ══════════════════════════════════════════════════════════════════════════

	public function addAnim(name:String, prefix:String, fps:Int = 24, looped:Bool = true,
		?indices:Array<Int>):Void
	{
		if (isAnimateAtlas && _animateSprite != null)
		{
			if (indices != null && indices.length > 0)
				_animateSprite.anim.addBySymbolIndices(name, prefix, indices, fps, looped);
			else
				_animateSprite.anim.addBySymbol(name, prefix, fps, looped);
		}
		else
		{
			if (indices != null && indices.length > 0)
				this.animation.addByIndices(name, prefix, indices, '', fps, looped);
			else
				this.animation.addByPrefix(name, prefix, fps, looped);
		}
	}

	public function playAnim(name:String, force:Bool = false, reversed:Bool = false,
		startFrame:Int = 0):Void
	{
		if (isAnimateAtlas && _animateSprite != null)
			_animateSprite.anim.play(name, force, reversed, startFrame);
		else
			this.animation.play(name, force, reversed, startFrame);
	}

	public var animFinished(get, never):Bool;
	function get_animFinished():Bool
	{
		if (isAnimateAtlas && _animateSprite != null)
			return _animateSprite.anim != null && _animateSprite.anim.finished;
		return this.animation.curAnim != null && this.animation.curAnim.finished;
	}

	public var animName(get, never):String;
	function get_animName():String
	{
		if (isAnimateAtlas && _animateSprite != null)
			return _animateSprite.anim != null ? _animateSprite.anim.curSymbol?.name ?? '' : '';
		return this.animation.curAnim != null ? this.animation.curAnim.name : '';
	}

	public function hasAnim(name:String):Bool
	{
		if (isAnimateAtlas && _animateSprite != null)
			return _animateSprite.anim != null && _animateSprite.anim.existsByName(name);
		return this.animation.getByName(name) != null;
	}

	// ══════════════════════════════════════════════════════════════════════════
	//  UTILIDADES
	// ══════════════════════════════════════════════════════════════════════════

	public function applyAnimOffset(offsetX:Float, offsetY:Float):Void
	{
		if (isAnimateAtlas && _animateSprite != null)
			_animateSprite.offset.set(offsetX, offsetY);
		else
			this.offset.set(offsetX, offsetY);
	}

	public function setScale(scaleX:Float, scaleY:Float):Void
	{
		if (isAnimateAtlas && _animateSprite != null)
		{
			_animateSprite.scale.set(scaleX, scaleY);
			_animateSprite.updateHitbox();
		}
		else
		{
			this.scale.set(scaleX, scaleY);
			this.updateHitbox();
		}
	}

	// ══════════════════════════════════════════════════════════════════════════
	//  UPDATE / DRAW
	// ══════════════════════════════════════════════════════════════════════════

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (isAnimateAtlas && _animateSprite != null)
		{
			_syncToAnimate();
			_animateSprite.update(elapsed);
		}
	}

	private function _syncToAnimate():Void
	{
		_animateSprite.x              = this.x;
		_animateSprite.y              = this.y;
		_animateSprite.alpha          = this.alpha;
		_animateSprite.angle          = this.angle;
		_animateSprite.scale.x        = this.scale.x;
		_animateSprite.scale.y        = this.scale.y;
		_animateSprite.flipX          = this.flipX;
		_animateSprite.flipY          = this.flipY;
		_animateSprite.visible        = this.visible;
		_animateSprite.scrollFactor.x = this.scrollFactor.x;
		_animateSprite.scrollFactor.y = this.scrollFactor.y;
		_animateSprite.cameras        = this.cameras;
		// Bug fix: sincronizar offset para que los offsets de animación funcionen
		_animateSprite.offset.set(this.offset.x, this.offset.y);
		// Bug fix: sincronizar antialiasing
		_animateSprite.antialiasing   = this.antialiasing;
	}

	override public function draw():Void
	{
		if (isAnimateAtlas && _animateSprite != null)
		{
			_syncToAnimate();
			_animateSprite.draw();
		}
		else
		{
			super.draw();
		}
	}

	// ══════════════════════════════════════════════════════════════════════════
	//  DETECCIÓN DE TIPO DE ASSET
	// ══════════════════════════════════════════════════════════════════════════

	/**
	 * Resuelve si un key tiene un Texture Atlas asociado, usando caché.
	 *
	 * Sin caché: PlayState con 20 sprites llama FileSystem.exists() ~60 veces
	 * (3 candidatos × 20 sprites) cada vez que se recarga el stage.
	 * Con caché: sólo la primera vez por key.
	 */
	static function resolveAtlasFolder(key:String):Null<String>
	{
		if (_atlasResCache.exists(key))
			return _atlasResCache.get(key);

		final result = _resolveAtlasFolderImpl(key);
		_atlasResCache.set(key, result);
		return result;
	}

	/** Implementación real de la búsqueda (sin caché). */
	static function _resolveAtlasFolderImpl(key:String):Null<String>
	{
		final charPrefix  = 'characters/images/';
		final stagePrefix = 'stages/';

		final isCharKey  = key.startsWith(charPrefix);
		final charName   = isCharKey ? key.substr(charPrefix.length) : null;

		var candidates = [
			'assets/$key',
			'assets/${key}-atlas',
			key,
		];

		if (mods.ModManager.activeMod != null)
		{
			final base = '${mods.ModManager.MODS_FOLDER}/${mods.ModManager.activeMod}';

			if (isCharKey)
			{
				candidates.unshift('$base/characters/images/$charName');
				candidates.unshift('$base/images/characters/$charName');
			}
			else if (key.startsWith(stagePrefix))
			{
				final imgIdx  = key.lastIndexOf('/images/');
				final imgName = imgIdx >= 0 ? key.substr(imgIdx + 8) : key;
				candidates.unshift('$base/$key');
				candidates.unshift('$base/images/stages/$imgName');
				candidates.unshift('$base/images/$imgName');
			}
			else
			{
				candidates.unshift('$base/$key');
			}
		}

		for (folder in candidates)
		{
			if (folderHasAnimateAtlas(folder))
				return folder;
		}

		return null;
	}

	public static function folderHasAnimateAtlas(folderPath:String):Bool
	{
		final jsonPath = '$folderPath/Animation.json';
		#if sys
		return FileSystem.exists(jsonPath);
		#else
		return OpenFlAssets.exists(jsonPath);
		#end
	}

	static function assetExists(path:String):Bool
	{
		#if sys
		return FileSystem.exists(path);
		#else
		return OpenFlAssets.exists(path);
		#end
	}

	// ══════════════════════════════════════════════════════════════════════════
	//  FACTORIES ESTÁTICAS
	// ══════════════════════════════════════════════════════════════════════════

	public static function create(x:Float, y:Float, assetPath:String):FunkinSprite
	{
		final spr = new FunkinSprite(x, y);
		spr.loadAsset(assetPath);
		return spr;
	}

	public static function createCharacter(x:Float, y:Float, charKey:String):FunkinSprite
	{
		final spr = new FunkinSprite(x, y);
		spr.loadCharacterSparrow(charKey);
		return spr;
	}

	// ══════════════════════════════════════════════════════════════════════════
	//  DESTRUIR
	// ══════════════════════════════════════════════════════════════════════════

	override public function destroy():Void
	{
		if (_animateSprite != null)
		{
			_animateSprite.destroy();
			_animateSprite = null;
		}
		super.destroy();
	}
}