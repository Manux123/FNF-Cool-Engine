package animationdata;

import animate.FlxAnimate;
import animate.FlxAnimateFrames;
import animate.internal.Timeline;

import flixel.graphics.frames.FlxAtlasFrames;
import flixel.math.FlxPoint;
import openfl.utils.Assets as OpenFlAssets;

#if sys
import sys.FileSystem;
#end

using StringTools;

/**
 * FunkinSprite — Sprite unificado con flixel-animate (MaybeMaru fork).
 * ─────────────────────────────────────────────────────────────────────────────
 * extends FlxAnimate directamente — sin sprite interno, sin sync de props.
 *
 * Fixes respecto a la versión anterior:
 *   • loadAtlas()       → this.frames = FlxAnimateFrames.fromAnimate(path)
 *   • hasAnimateAtlas   → @:access(animate.FlxAnimateController) en la clase
 *   • dictionary.keys() → [for (k in ...) k]  (Iterator no tiene .array())
 *   • @:privateAccess   → solo donde accedemos a campos privados de la lib
 */
@:access(animate.FlxAnimateController)
class FunkinSprite extends FlxAnimate
{
	// ── Compatibilidad con código existente ───────────────────────────────────

	/** true si el asset cargado es un Texture Atlas de Adobe Animate. */
	public var isAnimateAtlas(get, never):Bool;
	inline function get_isAnimateAtlas():Bool
	{
		@:privateAccess return this.anim.hasAnimateAtlas;
	}

	/** Key del asset actualmente cargado. */
	public var currentAssetKey(default, null):String = '';

	// ══════════════════════════════════════════════════════════════════════════
	//  CACHÉS ESTÁTICOS  (Sparrow / Packer)
	// ══════════════════════════════════════════════════════════════════════════

	static var _frameCache:Map<String, FlxAtlasFrames>  = [];
	static var _atlasResCache:Map<String, Null<String>> = [];
	static var _frameLRU:Array<String>                  = [];
	static final MAX_FRAME_CACHE = 30;

	public static function invalidateCache(key:String):Void
	{
		_frameCache.remove(key);
		_atlasResCache.remove(key);
		final idx = _frameLRU.indexOf(key);
		if (idx >= 0) _frameLRU.splice(idx, 1);
		trace('[FunkinSprite] Cache invalidado: $key');
	}

	public static function clearAllCaches():Void
	{
		_frameCache.clear();
		_atlasResCache.clear();
		_frameLRU = [];
		trace('[FunkinSprite] Todos los cachés limpiados.');
	}

	public static function pruneStaleCache():Void
	{
		final toRemove:Array<String> = [];
		for (key => atlas in _frameCache)
		{
			@:privateAccess
			final valid = atlas != null && atlas.parent != null && atlas.parent.bitmap != null;
			if (!valid) toRemove.push(key);
		}
		for (key in toRemove) _frameCache.remove(key);
		if (toRemove.length > 0)
			trace('[FunkinSprite] pruneStaleCache: ${toRemove.length} entradas eliminadas.');
	}

	static function _frameCachePut(key:String, frames:FlxAtlasFrames):Void
	{
		if (_frameLRU.length >= MAX_FRAME_CACHE)
		{
			final evict = _frameLRU.shift();
			_frameCache.remove(evict);
		}
		_frameCache.set(key, frames);
		_frameLRU.push(key);
	}

	static function _frameCacheTouch(key:String):Void
	{
		final idx = _frameLRU.indexOf(key);
		if (idx >= 0) { _frameLRU.splice(idx, 1); _frameLRU.push(key); }
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
	 * Detección automática:
	 *   1. Carpeta Animation.json → Texture Atlas
	 *   2. PNG + XML              → Sparrow
	 *   3. PNG + TXT              → Packer
	 *   4. Solo PNG               → Estático
	 */
	public function loadAsset(assetPath:String):FunkinSprite
	{
		currentAssetKey = assetPath;
		final atlasFolder = resolveAtlasFolder(assetPath);
		if (atlasFolder != null) return loadAnimateAtlas(atlasFolder);

		// Rutas candidatas: mod primero (si hay mod activo), luego assets/
		final candidates:Array<String> = [];
		if (mods.ModManager.activeMod != null)
		{
			final base = '${mods.ModManager.MODS_FOLDER}/${mods.ModManager.activeMod}';
			candidates.push('$base/$assetPath');
		}
		candidates.push('assets/$assetPath');

		for (base in candidates)
		{
			if (assetExists('$base.xml')) return loadSparrow(base == 'assets/$assetPath' ? assetPath : base);
			if (assetExists('$base.txt')) return loadPacker(base == 'assets/$assetPath' ? assetPath : base);
			if (assetExists('$base.png'))
			{
				loadGraphic('$base.png');
				return this;
			}
		}

		trace('[FunkinSprite] WARNING: asset no encontrado para "$assetPath"');
		return this;
	}

	/**
	 * Carga un Texture Atlas de Adobe Animate.
	 *
	 * FIX: La versión anterior llamaba _animateSprite.loadAtlas(path) sobre un
	 * FlxAnimate externo. flixel-animate carga el atlas asignando frames:
	 *   this.frames = FlxAnimateFrames.fromAnimate(fullPath)
	 * Esto es lo mismo que hace V-Slice en Paths.getAnimateAtlas().
	 */
	public function loadAnimateAtlas(folderPath:String):FunkinSprite
	{
		// No añadir prefijo 'assets/' si la ruta ya es absoluta o apunta a mods/
		final fullPath = (folderPath.startsWith('assets/') || folderPath.startsWith('mods/'))
			? folderPath
			: 'assets/$folderPath';
		this.frames = FlxAnimateFrames.fromAnimate(fullPath);
		trace('[FunkinSprite] Texture Atlas cargado: $fullPath');
		return this;
	}

	/** Sparrow (PNG + XML) con caché. */
	public function loadSparrow(key:String):FunkinSprite
	{
		final cacheKey = 'sparrow:$key';
		var cached = _frameCache.get(cacheKey);
		if (cached != null)
		{
			@:privateAccess
			final valid = cached.parent != null && cached.parent.bitmap != null;
			if (valid) { _frameCacheTouch(cacheKey); this.frames = cached; return this; }
			_frameCache.remove(cacheKey); _frameLRU.remove(cacheKey);
		}
		final frames = Paths.getSparrowAtlas(key);
		if (frames != null) { _frameCachePut(cacheKey, frames); this.frames = frames; trace('[FunkinSprite] Sparrow: $key'); }
		else trace('[FunkinSprite] WARNING: Sparrow no encontrado para "$key"');
		return this;
	}

	/** Packer (PNG + TXT) con caché. */
	public function loadPacker(key:String):FunkinSprite
	{
		final cacheKey = 'packer:$key';
		var cached = _frameCache.get(cacheKey);
		if (cached != null)
		{
			@:privateAccess
			final valid = cached.parent != null && cached.parent.bitmap != null;
			if (valid) { _frameCacheTouch(cacheKey); this.frames = cached; return this; }
			_frameCache.remove(cacheKey); _frameLRU.remove(cacheKey);
		}
		final frames = Paths.getPackerAtlas(key);
		if (frames != null) { _frameCachePut(cacheKey, frames); this.frames = frames; trace('[FunkinSprite] Packer: $key'); }
		else trace('[FunkinSprite] WARNING: Packer no encontrado para "$key"');
		return this;
	}

	/** Personaje (assets/characters/images/): Atlas → Sparrow → Packer → placeholder. */
	public function loadCharacterSparrow(key:String):FunkinSprite
	{
		final atlasFolder = resolveAtlasFolder('characters/images/$key');
		if (atlasFolder != null) return loadAnimateAtlas(atlasFolder);

		final ck = 'char_sparrow:$key';
		var c = _frameCache.get(ck);
		if (c != null) { @:privateAccess final v = c.parent != null && c.parent.bitmap != null; if (v) { _frameCacheTouch(ck); this.frames = c; return this; } _frameCache.remove(ck); }
		var f = Paths.characterSprite(key);
		if (f != null) { _frameCachePut(ck, f); this.frames = f; return this; }

		final ckTxt = 'char_packer:$key';
		var ct = _frameCache.get(ckTxt);
		if (ct != null) { @:privateAccess final v = ct.parent != null && ct.parent.bitmap != null; if (v) { _frameCacheTouch(ckTxt); this.frames = ct; return this; } _frameCache.remove(ckTxt); }
		var ft = Paths.characterSpriteTxt(key);
		if (ft != null) { _frameCachePut(ckTxt, ft); this.frames = ft; return this; }

		trace('[FunkinSprite] WARNING: No graphics for "$key" — placeholder invisible');
		makeGraphic(1, 1, 0x00000000); visible = false;
		return this;
	}

	/** Stage sprite (assets/stages/) con caché. */
	public function loadStageSparrow(key:String):FunkinSprite
	{
		final ck = 'stage_sparrow:$key';
		var c = _frameCache.get(ck);
		if (c != null) { @:privateAccess final v = c.parent != null && c.parent.bitmap != null; if (v) { _frameCacheTouch(ck); this.frames = c; return this; } _frameCache.remove(ck); }
		final f = Paths.stageSprite(key);
		if (f != null) { _frameCachePut(ck, f); this.frames = f; }
		else { trace('[FunkinSprite] WARNING: Stage asset no encontrado para "$key" — placeholder invisible'); makeGraphic(1, 1, 0x00000000); visible = false; }
		return this;
	}

	// ══════════════════════════════════════════════════════════════════════════
	//  ANIMACIONES
	// ══════════════════════════════════════════════════════════════════════════

	/**
	 * Añade una animación.
	 * Para atlases auto-detecta si el prefix es frame label o símbolo,
	 * evitando el crash get_loopType/curInstance null del flxanimate antiguo.
	 */
	public function addAnim(name:String, prefix:String, fps:Int = 24, looped:Bool = true,
		?indices:Array<Int>):Void
	{
		@:privateAccess
		if (this.anim.hasAnimateAtlas)
		{
			if (indices != null && indices.length > 0)
			{
				if (_frameLabelExists(prefix))
					this.anim.addByFrameLabelIndices(name, prefix, indices, fps, looped);
				else
					this.anim.addBySymbolIndices(name, prefix, indices, fps, looped);
			}
			else
			{
				if (_frameLabelExists(prefix))
					this.anim.addByFrameLabel(name, prefix, fps, looped);
				else
					this.anim.addBySymbol(name, prefix, fps, looped);
			}
			if (!this.animation.getNameList().contains(name))
				trace('[FunkinSprite] WARN: addAnim("$name", "$prefix") — no encontrado en atlas.');
		}
		else
		{
			if (indices != null && indices.length > 0)
				this.animation.addByIndices(name, prefix, indices, '', fps, looped);
			else
				this.animation.addByPrefix(name, prefix, fps, looped);
		}
	}

	/** Reproduce una animación. Guard con hasAnim() evita crashes. */
	public function playAnim(name:String, force:Bool = false, reversed:Bool = false,
		startFrame:Int = 0):Void
	{
		if (!hasAnim(name))
		{
			trace('[FunkinSprite] WARN: playAnim("$name") — no existe, ignorando.');
			return;
		}
		this.animation.play(name, force, reversed, startFrame);
	}

	public var animFinished(get, never):Bool;
	inline function get_animFinished():Bool return this.animation.finished;

	public var animName(get, never):String;
	inline function get_animName():String return this.animation.name ?? '';

	/**
	 * true si la animación existe.
	 * Para atlases: si existe como label/símbolo pero no fue añadida, la añade.
	 */
	public function hasAnim(name:String):Bool
	{
		@:privateAccess
		if (this.anim.hasAnimateAtlas)
		{
			if (this.animation.getNameList().contains(name)) return true;
			return _addAnimIfExists(name);
		}
		return this.animation.getByName(name) != null;
	}

	// ══════════════════════════════════════════════════════════════════════════
	//  UTILIDADES
	// ══════════════════════════════════════════════════════════════════════════

	public function applyAnimOffset(offsetX:Float, offsetY:Float):Void
		this.offset.set(offsetX, offsetY);

	public function setScale(scaleX:Float, scaleY:Float):Void
	{
		this.scale.set(scaleX, scaleY);
		this.updateHitbox();
	}

	// ══════════════════════════════════════════════════════════════════════════
	//  HELPERS PRIVADOS — frame labels / símbolos
	// ══════════════════════════════════════════════════════════════════════════

	function _frameLabelExists(name:String):Bool
	{
		try
		{
			final tl:Timeline = this.library.timeline;
			if (tl == null) return false;
			for (layer in tl.layers)
				for (frame in layer.frames)
					if (frame.name != null && frame.name.rtrim() == name)
						return true;
		}
		catch (_) {}
		return false;
	}

	public function getFrameLabelList():Array<String>
	{
		final result:Array<String> = [];
		try
		{
			final tl:Timeline = this.library.timeline;
			if (tl == null) return result;
			for (layer in tl.layers)
				for (frame in layer.frames)
					if (frame.name != null && frame.name.rtrim() != '' && !result.contains(frame.name))
						result.push(frame.name);
		}
		catch (_) {}
		return result;
	}

	/**
	 * Intenta registrar la animación si existe en el atlas.
	 *
	 * FIX: dictionary.keys() devuelve un Iterator, NO un Array.
	 * .array() no existe en Iterator — usamos [for (k in iter) k].
	 * V-Slice usa .array() porque su flixel fork parchea KeyValueIterator,
	 * nosotros lo hacemos compatible sin ese parche.
	 */
	function _addAnimIfExists(name:String):Bool
	{
		try
		{
			if (_frameLabelExists(name))
			{
				this.anim.addByFrameLabel(name, name, Std.int(this.library.frameRate), false);
				return true;
			}

			// FIX: Iterator → Array via comprensión, no .array()
			@:privateAccess
			final symbols:Array<String> = [for (k in this.library.dictionary.keys()) k];
			if (symbols.contains(name))
			{
				this.anim.addBySymbol(name, name, Std.int(this.library.frameRate), false);
				return true;
			}
		}
		catch (_) {}
		return false;
	}

	// ══════════════════════════════════════════════════════════════════════════
	//  DETECCIÓN DE TIPO DE ASSET
	// ══════════════════════════════════════════════════════════════════════════

	static function resolveAtlasFolder(key:String):Null<String>
	{
		if (_atlasResCache.exists(key)) return _atlasResCache.get(key);
		final result = _resolveAtlasFolderImpl(key);
		_atlasResCache.set(key, result);
		return result;
	}

	static function _resolveAtlasFolderImpl(key:String):Null<String>
	{
		final isCharKey = key.startsWith('characters/images/');
		final charName  = isCharKey ? key.substr('characters/images/'.length) : null;
		var candidates  = ['assets/$key', 'assets/${key}-atlas', key];

		if (mods.ModManager.activeMod != null)
		{
			final base = '${mods.ModManager.MODS_FOLDER}/${mods.ModManager.activeMod}';
			if (isCharKey)
			{
				candidates.unshift('$base/characters/images/$charName');
				candidates.unshift('$base/images/characters/$charName');
			}
			else if (key.startsWith('stages/'))
			{
				final imgIdx  = key.lastIndexOf('/images/');
				final imgName = imgIdx >= 0 ? key.substr(imgIdx + 8) : key;
				candidates.unshift('$base/$key');
				candidates.unshift('$base/images/stages/$imgName');
				candidates.unshift('$base/images/$imgName');
			}
			else
				candidates.unshift('$base/$key');
		}

		for (folder in candidates)
			if (folderHasAnimateAtlas(folder)) return folder;
		return null;
	}

	public static function folderHasAnimateAtlas(folderPath:String):Bool
	{
		#if sys
		return FileSystem.exists('$folderPath/Animation.json');
		#else
		return OpenFlAssets.exists('$folderPath/Animation.json');
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
	//  FACTORIES
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
}
