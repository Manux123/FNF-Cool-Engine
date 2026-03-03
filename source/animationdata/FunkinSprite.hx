package animationdata;

import animate.FlxAnimate;
import animate.FlxAnimateFrames;
import animate.internal.Timeline;

import flixel.graphics.frames.FlxAtlasFrames;
import flixel.math.FlxPoint;
import openfl.utils.Assets as OpenFlAssets;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

/**
 * FunkinSprite — Sprite unificado con flixel-animate (MaybeMaru fork).
 * ─────────────────────────────────────────────────────────────────────────────
 * extends FlxAnimate directamente — sin sprite interno, sin sync de props.
 *
 * Sistema multi-atlas al estilo V-Slice:
 *   • Cada carpeta de Animate se carga como FlxAnimateFrames independiente.
 *   • Se combinan en memoria con FlxAnimateFrames.combineAtlas().
 *   • Sin manipulación de filesystem / directorios temporales.
 *   • Compatible con targets no-sys (HTML5, etc.).
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

	/**
	 * Caché de FlxAnimateFrames individuales por carpeta.
	 * Evita re-parsear Animation.json en cada carga del mismo personaje.
	 */
	static var _animateFrameCache:Map<String, FlxAnimateFrames> = [];

	// ══════════════════════════════════════════════════════════════════════════
	//  GESTIÓN DE VIDA ÚTIL DE ATLASES (por instancia, al estilo V-Slice)
	// ══════════════════════════════════════════════════════════════════════════

	/**
	 * Atlases cargados para ESTA instancia con destroyOnNoUse = false.
	 * Se liberan en destroy() restaurando destroyOnNoUse = true,
	 * lo que permite que Flixel los limpie cuando ya no se usen.
	 *
	 * Equivalente a _usedAtlases en MultiSparrowCharacter / MultiAnimateAtlasCharacter de V-Slice.
	 */
	var _usedAtlases:Array<FlxAnimateFrames> = [];

	/**
	 * Registra un atlas como "en uso" por esta instancia y marca
	 * destroyOnNoUse = false para evitar que Flixel lo destruya antes de tiempo.
	 */
	function _trackAtlas(atlas:FlxAnimateFrames):Void
	{
		if (atlas == null || atlas.parent == null) return;
		if (_usedAtlases.contains(atlas)) return;
		atlas.parent.destroyOnNoUse = false;
		_usedAtlases.push(atlas);
	}

	/**
	 * Libera todos los atlases rastreados, restaurando destroyOnNoUse = true.
	 * Llamar antes de super.destroy() o antes de recargar el sprite.
	 */
	public function releaseTrackedAtlases():Void
	{
		for (atlas in _usedAtlases)
		{
			if (atlas == null || atlas.parent == null) continue;
			atlas.parent.destroyOnNoUse = true;
		}
		_usedAtlases = [];
	}

	override public function destroy():Void
	{
		releaseTrackedAtlases();
		super.destroy();
	}

	public static function invalidateCache(key:String):Void
	{
		_frameCache.remove(key);
		_atlasResCache.remove(key);
		final idx = _frameLRU.indexOf(key);
		if (idx >= 0) _frameLRU.splice(idx, 1);
		// Invalidar también caché de FlxAnimateFrames si la key coincide con una carpeta
		_animateFrameCache.remove(key);
		trace('[FunkinSprite] Cache invalidado: $key');
	}

	public static function clearAllCaches():Void
	{
		_frameCache.clear();
		_atlasResCache.clear();
		_frameLRU = [];
		_animateFrameCache.clear();
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

		trace('[FunkinSprite] WARNING: asset not found para "$assetPath"');
		return this;
	}

	/**
	 * Carga un Texture Atlas de Adobe Animate (carpeta única).
	 */
	public function loadAnimateAtlas(folderPath:String):FunkinSprite
	{
		releaseTrackedAtlases();
		final fullPath = (folderPath.startsWith('assets/') || folderPath.startsWith('mods/'))
			? folderPath
			: 'assets/$folderPath';
		_preloadFolderBitmaps(fullPath);
		final atlas:FlxAnimateFrames = FlxAnimateFrames.fromAnimate(fullPath);
		if (atlas != null) _trackAtlas(atlas);
		this.frames = atlas;
		trace('[FunkinSprite] Texture Atlas cargado: $fullPath');
		return this;
	}

	/**
	 * Carga múltiples carpetas de Adobe Animate y las fusiona al estilo V-Slice.
	 *
	 * El primer elemento de `folders` actúa como el ATLAS PRINCIPAL (el que contiene
	 * el Animation.json con la timeline y los frame labels usados por todas las
	 * animaciones). Los elementos siguientes son SUBATLASES (texturas adicionales).
	 *
	 * Replica MultiAnimateAtlasCharacter de V-Slice:
	 *   1. Cargar mainTexture (folders[0])
	 *   2. Cargar subTexturas (folders[1..])
	 *   3. combineAtlas([main, sub1, sub2, ...])
	 *   4. Rastrear todos en _usedAtlases para liberarlos en destroy()
	 *
	 * YA NO se usa unique=true ni se cachea el combined bajo key compuesta.
	 * El ciclo de vida se gestiona via _usedAtlases + destroyOnNoUse por instancia.
	 */
	public function loadMultiAnimateAtlas(folders:Array<String>):FunkinSprite
	{
		if (folders == null || folders.length == 0) return this;
		if (folders.length == 1) return loadAnimateAtlas(folders[0]);

		releaseTrackedAtlases();

		// Resolver paths absolutos
		final fullPaths:Array<String> = [];
		for (folder in folders)
		{
			fullPaths.push((folder.startsWith('assets/') || folder.startsWith('mods/'))
				? folder : 'assets/$folder');
		}

		final textureList:Array<FlxAnimateFrames> = [];

		// ── 1. Atlas principal (folders[0]) ───────────────────────────────────
		final mainPath = fullPaths[0];
		if (!folderHasAnimateAtlas(mainPath))
		{
			trace('[FunkinSprite] loadMultiAnimateAtlas: sin Animation.json en path principal $mainPath.');
			return this;
		}
		_preloadFolderBitmaps(mainPath);
		final mainAtlas:FlxAnimateFrames = FlxAnimateFrames.fromAnimate(mainPath);
		if (mainAtlas == null)
		{
			trace('[FunkinSprite] loadMultiAnimateAtlas: fromAnimate→null para $mainPath.');
			return this;
		}
		_trackAtlas(mainAtlas);
		textureList.push(mainAtlas);

		// ── 2. Subatlases (folders[1..]) ──────────────────────────────────────
		final addedPaths:Array<String> = [mainPath];
		for (i in 1...fullPaths.length)
		{
			final subPath = fullPaths[i];
			if (addedPaths.contains(subPath)) continue;
			if (!folderHasAnimateAtlas(subPath))
			{
				trace('[FunkinSprite] loadMultiAnimateAtlas: sin Animation.json en $subPath, saltando.');
				continue;
			}
			_preloadFolderBitmaps(subPath);
			final subAtlas:FlxAnimateFrames = FlxAnimateFrames.fromAnimate(subPath);
			if (subAtlas == null)
			{
				trace('[FunkinSprite] loadMultiAnimateAtlas: fromAnimate→null para $subPath, saltando.');
				continue;
			}
			_trackAtlas(subAtlas);
			textureList.push(subAtlas);
			addedPaths.push(subPath);
		}

		if (textureList.length == 1)
		{
			this.frames = textureList[0];
			return this;
		}

		// ── 3. combineAtlas ───────────────────────────────────────────────────
		final combined = FlxAnimateFrames.combineAtlas(cast textureList);
		if (combined != null)
		{
			_trackAtlas(cast combined);
			this.frames = combined;
			trace('[FunkinSprite] Multi-atlas combinado: ${textureList.length} atlas → (${fullPaths.join(", ")})');
		}
		else
		{
			this.frames = textureList[0];
			trace('[FunkinSprite] WARN: combineAtlas→null — usando atlas principal (${fullPaths[0]}).');
		}
		return this;
	}

	// ── Resolución de .sheets multi-animate ──────────────────────────────────

	/**
	 * Busca un archivo .sheets para el personaje y, si sus entradas son carpetas
	 * de Adobe Animate, devuelve la lista de paths absolutos.
	 * Devuelve null si no hay .sheets o si las entradas no son Animate.
	 */
	static function resolveMultiAnimateFolders(charKey:String):Null<Array<String>>
	{
		#if sys
		final candidates = [
			mods.ModManager.resolveInMod('characters/images/$charKey.sheets'),
			mods.ModManager.resolveInMod('images/characters/$charKey.sheets'),
			'assets/characters/images/$charKey.sheets'
		];

		var sheetsPath:Null<String> = null;
		for (c in candidates)
			if (c != null && FileSystem.exists(c)) { sheetsPath = c; break; }

		if (sheetsPath == null) return null;

		try
		{
			final keys:Array<String> = haxe.Json.parse(File.getContent(sheetsPath));
			if (keys == null || keys.length == 0) return null;

			final folders:Array<String> = [];
			for (key in keys)
			{
				final folder = _resolveAnimateFolderForKey(charKey, key);
				if (folder != null) folders.push(folder);
			}

			// Solo continuar si AL MENOS la primera es Animate
			if (folders.length > 0 && folderHasAnimateAtlas(folders[0]))
				return folders;
		}
		catch (e:Dynamic)
		{
			trace('[FunkinSprite] resolveMultiAnimateFolders error: $e');
		}
		#end
		return null;
	}

	/**
	 * Resuelve un key de .sheets (relativo a characters/images/) a una
	 * carpeta de Animate, buscando en mod y en assets.
	 */
	static function _resolveAnimateFolderForKey(charKey:String, key:String):Null<String>
	{
		#if sys
		final isSubfolder = !key.contains('/') || key.startsWith(charKey);

		final candidatePaths = [
			mods.ModManager.resolveInMod('characters/images/$key'),
			mods.ModManager.resolveInMod('images/characters/$key'),
			'assets/characters/images/$key',
		];
		if (isSubfolder)
		{
			final base = 'characters/images/$charKey/$key';
			candidatePaths.unshift(mods.ModManager.resolveInMod(base) ?? '');
			candidatePaths.push('assets/$base');
		}

		for (p in candidatePaths)
			if (p != null && p != '' && folderHasAnimateAtlas(p)) return p;
		#end
		return null;
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
		else trace('[FunkinSprite] WARNING: Sparrow not found para "$key"');
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
		else trace('[FunkinSprite] WARNING: Packer not found para "$key"');
		return this;
	}

	/** Personaje: Multi-Atlas → Atlas único → Sparrow → Packer → placeholder. */
	public function loadCharacterSparrow(key:String):FunkinSprite
	{
		// BUGFIX: Algunos character JSON tienen path como "tankmen/basic/spritemap1"
		// apuntando directamente al nombre del spritemap. La carpeta real del atlas
		// Animate es "tankmen/basic/" (el padre). Detectar y normalizar este patrón.
		var resolvedKey = key;
		{
			final spritemapRe = ~/\/spritemap\d*$/i;
			if (spritemapRe.match(key))
			{
				final parentKey = spritemapRe.replace(key, '');
				if (parentKey.length > 0)
				{
					trace('[FunkinSprite] loadCharacterSparrow: ruta con spritemap detectada "$key" → folder "$parentKey"');
					resolvedKey = parentKey;
				}
			}
		}

		// 1. .sheets con múltiples carpetas Animate (Tankman, etc.)
		final multiAnimFolders = resolveMultiAnimateFolders(resolvedKey);
		if (multiAnimFolders != null) return loadMultiAnimateAtlas(multiAnimFolders);

		// 2. Carpeta única de Adobe Animate
		final atlasFolder = resolveAtlasFolder('characters/images/$resolvedKey');
		if (atlasFolder != null) return loadAnimateAtlas(atlasFolder);

		final ck = 'char_sparrow:$resolvedKey';
		var c = _frameCache.get(ck);
		if (c != null) { @:privateAccess final v = c.parent != null && c.parent.bitmap != null; if (v) { _frameCacheTouch(ck); this.frames = c; return this; } _frameCache.remove(ck); }
		var f = Paths.characterSprite(resolvedKey);
		if (f != null) { _frameCachePut(ck, f); this.frames = f; return this; }

		final ckTxt = 'char_packer:$resolvedKey';
		var ct = _frameCache.get(ckTxt);
		if (ct != null) { @:privateAccess final v = ct.parent != null && ct.parent.bitmap != null; if (v) { _frameCacheTouch(ckTxt); this.frames = ct; return this; } _frameCache.remove(ckTxt); }
		var ft = Paths.characterSpriteTxt(resolvedKey);
		if (ft != null) { _frameCachePut(ckTxt, ft); this.frames = ft; return this; }

		trace('[FunkinSprite] WARNING: No graphics for "$key" (resolved: "$resolvedKey") — placeholder invisible');
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
		else { trace('[FunkinSprite] WARNING: Stage asset not found para "$key" — placeholder invisible'); makeGraphic(1, 1, 0x00000000); visible = false; }
		return this;
	}

	// ══════════════════════════════════════════════════════════════════════════
	//  ANIMACIONES
	// ══════════════════════════════════════════════════════════════════════════

	/**
	 * Añade una animación.
	 * Para atlases auto-detecta si el prefix es frame label o símbolo.
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
				trace('[FunkinSprite] WARN: addAnim("$name", "$prefix") — not found en atlas.');
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
			// Buscar en el timeline principal
			final tl:Timeline = this.library.timeline;
			if (tl != null)
				for (layer in tl.layers)
					for (frame in layer.frames)
						if (frame.name != null && frame.name.rtrim() == name)
							return true;

			// FIX: También buscar en los timelines de atlases secundarios (multi-atlas)
			@:privateAccess
			final collections = this.library.addedCollections;
			if (collections != null)
			{
				for (col in collections)
				{
					@:privateAccess
					final colTl:Timeline = col.timeline;
					if (colTl == null) continue;
					for (layer in colTl.layers)
						for (frame in layer.frames)
							if (frame.name != null && frame.name.rtrim() == name)
								return true;
				}
			}
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
	 * FIX: Usa library.existsSymbol / getSymbol para buscar en addedCollections también.
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

			// FIX: existsSymbol busca en dictionary principal Y en addedCollections
			if (this.library.existsSymbol(name))
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

	public static function resolveAtlasFolder(key:String):Null<String>
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


	static function _preloadFolderBitmaps(folderPath:String):Void
	{
		#if sys
		if (!FileSystem.exists(folderPath)) return;
		try {
			for (file in FileSystem.readDirectory(folderPath)) {
				if (!file.endsWith(".png")) continue;
				final fp = folderPath + "/" + file;
				if (openfl.utils.Assets.cache.hasBitmapData(fp)) continue;
				var g = flixel.FlxG.bitmap.get(fp);
				if (g != null && g.bitmap != null) continue;
				try {
					final bmp = openfl.display.BitmapData.fromFile(fp);
					if (bmp != null) openfl.utils.Assets.cache.setBitmapData(fp, bmp);
				} catch (_:Dynamic) {}
			}
		} catch (_:Dynamic) {}
		#end
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
