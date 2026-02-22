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
 * FunkinSprite (VERSIÓN CORREGIDA)
 * ─────────────────────────────────────────────────────────────
 * Reemplaza FlxSprite en todo el engine.
 * Detecta automáticamente si el asset es:
 *
 *   ① Texture Atlas de Adobe Animate
 *      → Carpeta con  Animation.json  +  spritemap1.png
 *      → Usa FlxAnimate INTERNO
 *
 *   ② Sparrow Atlas normal
 *      → PNG + XML  (formato Sparrow v2)
 *      → Usa FlxAtlasFrames.fromSparrow
 *
 *   ③ Packer Atlas (txt)
 *      → PNG + TXT
 *      → Usa FlxAtlasFrames.fromSpriteSheetPacker
 *
 *   ④ Imagen estática
 *      → Solo PNG, sin atlas
 *      → loadGraphic normal
 *
 * CORRECCIÓN: Ahora extiende FlxSprite y usa FlxAnimate como instancia interna.
 */
class FunkinSprite extends FlxSprite
{
	// ─── Estado ────────────────────────────────────────────────
	public var isAnimateAtlas(default, null):Bool = false;

	/** Nombre/key del asset actualmente cargado */
	public var currentAssetKey(default, null):String = '';

	/** Instancia interna de FlxAnimate (solo cuando isAnimateAtlas = true) */
	var _animateSprite:FlxAnimate;

	// ─── Constructor ───────────────────────────────────────────
	public function new(x:Float = 0, y:Float = 0)
	{
		super(x, y);
	}

	// ══════════════════════════════════════════════════════════
	//  MÉTODOS DE CARGA
	// ══════════════════════════════════════════════════════════

	/**
	 * CARGA AUTOMÁTICA — detecta el tipo según los archivos disponibles.
	 *
	 * Orden de prioridad:
	 *   1. Carpeta con Animation.json  → Texture Atlas (FlxAnimate)
	 *   2. PNG + XML                   → Sparrow
	 *   3. PNG + TXT                   → Packer
	 *   4. Solo PNG                    → Estático
	 *
	 * @param assetPath  Path SIN extensión, relativo a assets/
	 *                   Ej: "characters/images/bf"
	 *                       "images/freeplay/dj-bf/dj-bf"
	 */
	public function loadAsset(assetPath:String):FunkinSprite
	{
		currentAssetKey = assetPath;

		// ① ¿Es un texture atlas? (carpeta con Animation.json)
		//    El path en este caso apunta a la CARPETA, no al archivo
		var atlasFolder = resolveAtlasFolder(assetPath);
		if (atlasFolder != null)
		{
			return loadAnimateAtlas(atlasFolder);
		}

		// ② ¿Existe PNG + XML? → Sparrow
		if (assetExists('assets/$assetPath.xml'))
		{
			return loadSparrow(assetPath);
		}

		// ③ ¿Existe PNG + TXT? → Packer
		if (assetExists('assets/$assetPath.txt'))
		{
			return loadPacker(assetPath);
		}

		// ④ Fallback → imagen estática
		if (assetExists('assets/$assetPath.png'))
		{
			loadGraphic('assets/$assetPath.png');
		}
		else
		{
			trace('[FunkinSprite] WARNING: no se encontró ningún asset para "$assetPath"');
		}

		isAnimateAtlas = false;
		return this;
	}

	/**
	 * Carga un Texture Atlas de Adobe Animate.
	 * @param folderPath  Carpeta que contiene Animation.json y spritemap*.png
	 *                    Puede ser relativo a assets/ o path absoluto.
	 */
	public function loadAnimateAtlas(folderPath:String):FunkinSprite
	{
		isAnimateAtlas = true;

		// FlxAnimate espera el path completo a la carpeta
		var fullPath = folderPath.startsWith('assets/') ? folderPath : 'assets/$folderPath';

		// Limpiar atlas anterior si había uno
		if (_animateSprite != null)
		{
			_animateSprite.destroy();
			_animateSprite = null;
		}

		// Crear nueva instancia de FlxAnimate
		_animateSprite = new FlxAnimate(x, y);
		_animateSprite.loadAtlas(fullPath);

		// Hacer invisible el FlxSprite base (solo renderizamos el FlxAnimate)
		visible = false;

		trace('[FunkinSprite] Texture Atlas cargado: $fullPath');
		return this;
	}

	/**
	 * Carga un Sparrow atlas (PNG + XML).
	 * @param key  Key sin extensión. Se buscará en assets/[key].png y assets/[key].xml
	 */
	public function loadSparrow(key:String):FunkinSprite
	{
		isAnimateAtlas = false;

		// Limpiar FlxAnimate si había uno
		if (_animateSprite != null)
		{
			_animateSprite.destroy();
			_animateSprite = null;
		}

		// Hacer visible el FlxSprite base
		visible = true;

		var frames = Paths.getSparrowAtlas(key);
		if (frames != null)
		{
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
	 * Carga un Packer atlas (PNG + TXT).
	 * @param key  Key sin extensión
	 */
	public function loadPacker(key:String):FunkinSprite
	{
		isAnimateAtlas = false;

		// Limpiar FlxAnimate si había uno
		if (_animateSprite != null)
		{
			_animateSprite.destroy();
			_animateSprite = null;
		}

		// Hacer visible el FlxSprite base
		visible = true;

		var frames = Paths.getPackerAtlas(key);
		if (frames != null)
		{
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
	 * Carga un Sparrow de personaje (assets/characters/images/).
	 */
	public function loadCharacterSparrow(key:String):FunkinSprite
	{
		// Intentar texture atlas primero
		var atlasPath = 'characters/images/$key';
		var atlasFolder = resolveAtlasFolder(atlasPath);
		if (atlasFolder != null)
			return loadAnimateAtlas(atlasFolder);

		// Fallback a Sparrow normal de personaje
		isAnimateAtlas = false;

		// Limpiar FlxAnimate si había uno
		if (_animateSprite != null)
		{
			_animateSprite.destroy();
			_animateSprite = null;
		}

		visible = true;

		var frames = Paths.characterSprite(key);
		if (frames != null)
		{
			this.frames = frames;
		}
		else
		{
			// Intentar con txt
			var framesTxt = Paths.characterSpriteTxt(key);
			if (framesTxt != null) this.frames = framesTxt;
		}

		// Guard: si no se encontraron frames, usar placeholder invisible
		// para evitar null object reference en FlxDrawQuadsItem::render
		if (!isAnimateAtlas && this.frames == null)
		{
			trace('[FunkinSprite] WARNING: No graphics found for "" — using invisible placeholder');
			makeGraphic(1, 1, 0x00000000);
			visible = false;
		}

		return this;
	}

	/**
	 * Carga un Sparrow de stage (assets/stages/STAGE/images/).
	 */
	public function loadStageSparrow(key:String):FunkinSprite
	{
		isAnimateAtlas = false;

		// Limpiar FlxAnimate si había uno
		if (_animateSprite != null)
		{
			_animateSprite.destroy();
			_animateSprite = null;
		}

		visible = true;

		var frames = Paths.stageSprite(key);
		if (frames != null) this.frames = frames;
		return this;
	}

	// ══════════════════════════════════════════════════════════
	//  WRAPPER DE ANIMACIONES
	//  Funcionan igual para Atlas y para Sparrow/Packer
	// ══════════════════════════════════════════════════════════

	/**
	 * Añade animación por prefijo — funciona en ambos modos.
	 * En atlas de Animate usa anim.addByAnimIndices / addBySymbol.
	 * En Sparrow usa animation.addByPrefix normal.
	 */
	public function addAnim(name:String, prefix:String, fps:Int = 24, looped:Bool = true,
		?indices:Array<Int>):Void
	{
		if (isAnimateAtlas && _animateSprite != null)
		{
			// addBySymbolIndices cuando hay índices específicos,
			// addBySymbol para la animación completa del símbolo.
			if (indices != null && indices.length > 0)
				_animateSprite.anim.addBySymbolIndices(name, prefix, indices, fps, looped);
			else
				_animateSprite.anim.addBySymbol(name, prefix, fps, looped);
		}
		else
		{
			// FlxSprite normal
			if (indices != null && indices.length > 0)
				this.animation.addByIndices(name, prefix, indices, '', fps, looped);
			else
				this.animation.addByPrefix(name, prefix, fps, looped);
		}
	}

	/**
	 * Reproducir animación — funciona en ambos modos.
	 * @param force  Si true, reinicia la animación aunque ya esté corriendo
	 */
	public function playAnim(name:String, force:Bool = false, reversed:Bool = false,
		startFrame:Int = 0):Void
	{
		if (isAnimateAtlas && _animateSprite != null)
		{
			_animateSprite.anim.play(name, force, reversed, startFrame);
		}
		else
		{
			this.animation.play(name, force, reversed, startFrame);
		}
	}

	/**
	 * ¿La animación actual terminó?
	 */
	public var animFinished(get, never):Bool;
	function get_animFinished():Bool
	{
		if (isAnimateAtlas && _animateSprite != null)
			return _animateSprite.anim != null && _animateSprite.anim.finished;
		return this.animation.curAnim != null && this.animation.curAnim.finished;
	}

	/**
	 * Nombre de la animación actual
	 */
	public var animName(get, never):String;
	function get_animName():String
	{
		if (isAnimateAtlas && _animateSprite != null)
			return _animateSprite.anim != null ? _animateSprite.anim.curSymbol?.name ?? '' : '';
		return this.animation.curAnim != null ? this.animation.curAnim.name : '';
	}

	/**
	 * ¿Existe esta animación?
	 */
	public function hasAnim(name:String):Bool
	{
		if (isAnimateAtlas && _animateSprite != null)
			return _animateSprite.anim != null && _animateSprite.anim.existsByName(name);
		return this.animation.getByName(name) != null;
	}

	// ══════════════════════════════════════════════════════════
	//  UTILIDADES
	// ══════════════════════════════════════════════════════════

	/**
	 * Offset de animación — aplica un offset x/y al sprite según la anim activa.
	 * Llama esto después de playAnim().
	 */
	public function applyAnimOffset(offsetX:Float, offsetY:Float):Void
	{
		if (isAnimateAtlas && _animateSprite != null)
			_animateSprite.offset.set(offsetX, offsetY);
		else
			this.offset.set(offsetX, offsetY);
	}

	/**
	 * Escalar manteniendo hitbox actualizado.
	 */
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

	// ══════════════════════════════════════════════════════════
	//  OVERRIDE DE UPDATE Y DRAW
	// ══════════════════════════════════════════════════════════

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (isAnimateAtlas && _animateSprite != null)
		{
			// Sincronizar posición del FlxAnimate con el contenedor
			_animateSprite.x = this.x;
			_animateSprite.y = this.y;
			_animateSprite.update(elapsed);
		}
	}

	override public function draw():Void
	{
		if (isAnimateAtlas && _animateSprite != null)
		{
			// Dibujar el FlxAnimate en lugar del sprite base
			_animateSprite.draw();
		}
		else
		{
			// Dibujar el sprite normal
			super.draw();
		}
	}

	// ══════════════════════════════════════════════════════════
	//  DETECCIÓN DE TIPO DE ASSET (interno)
	// ══════════════════════════════════════════════════════════

	/**
	 * Dado un key como "characters/images/bf", busca si existe
	 * una carpeta con Animation.json.
	 *
	 * Patrones buscados:
	 *   assets/[key]/Animation.json          ← la carpeta ES el key
	 *   assets/[key]-atlas/Animation.json    ← convención "-atlas"
	 *
	 * Retorna el path a la carpeta si existe, null si no.
	 */
	static function resolveAtlasFolder(key:String):Null<String>
	{
		// key is typically 'characters/images/NAME' or 'stages/STAGE/images/NAME'
		final charPrefix  = 'characters/images/';
		final stagePrefix = 'stages/';

		final isCharKey  = key.startsWith(charPrefix);
		final charName   = isCharKey ? key.substr(charPrefix.length) : null;

		var candidates = [
			'assets/$key',
			'assets/${key}-atlas',
			key, // absolute path fallback
		];

		if (mods.ModManager.activeMod != null)
		{
			final base = '${mods.ModManager.MODS_FOLDER}/${mods.ModManager.activeMod}';

			if (isCharKey)
			{
				// Cool Engine layout: mods/mod/characters/images/NAME
				candidates.unshift('$base/characters/images/$charName');
				// Psych Engine layout: mods/mod/images/characters/NAME
				candidates.unshift('$base/images/characters/$charName');
			}
			else if (key.startsWith(stagePrefix))
			{
				// For stage atlas keys like 'stages/STAGE/images/NAME',
				// extract the image name after the last /images/ segment
				final imgIdx = key.lastIndexOf('/images/');
				final imgName = imgIdx >= 0 ? key.substr(imgIdx + 8) : key;
				// Cool Engine layout: mods/mod/stages/STAGE/images/NAME
				candidates.unshift('$base/$key');
				// Psych Engine layout: mods/mod/images/stages/NAME
				candidates.unshift('$base/images/stages/$imgName');
				candidates.unshift('$base/images/$imgName');
			}
			else
			{
				// Generic mod path attempt
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

	/**
	 * Verifica si una carpeta contiene un Texture Atlas de Animate.
	 * Busca Animation.json dentro de ella.
	 */
	public static function folderHasAnimateAtlas(folderPath:String):Bool
	{
		var jsonPath = '$folderPath/Animation.json';

		#if sys
		return FileSystem.exists(jsonPath);
		#else
		return OpenFlAssets.exists(jsonPath);
		#end
	}

	/**
	 * Verifica si un asset existe (cualquier tipo de archivo).
	 */
	static function assetExists(path:String):Bool
	{
		#if sys
		return FileSystem.exists(path);
		#else
		return OpenFlAssets.exists(path);
		#end
	}

	// ══════════════════════════════════════════════════════════
	//  STATIC FACTORIES (atajos para crear sprites rápido)
	// ══════════════════════════════════════════════════════════

	/**
	 * Crea un FunkinSprite con auto-detección.
	 */
	public static function create(x:Float, y:Float, assetPath:String):FunkinSprite
	{
		var spr = new FunkinSprite(x, y);
		spr.loadAsset(assetPath);
		return spr;
	}

	/**
	 * Crea un FunkinSprite de personaje.
	 */
	public static function createCharacter(x:Float, y:Float, charKey:String):FunkinSprite
	{
		var spr = new FunkinSprite(x, y);
		spr.loadCharacterSparrow(charKey);
		return spr;
	}

	// ══════════════════════════════════════════════════════════
	//  DESTRUIR
	// ══════════════════════════════════════════════════════════

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