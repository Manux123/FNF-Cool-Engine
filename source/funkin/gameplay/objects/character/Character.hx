package funkin.gameplay.objects.character;

import animationdata.FunkinSprite;
import flixel.util.FlxColor;
import funkin.data.Conductor;
import haxe.Json;
import sys.io.File;
import sys.FileSystem;

using StringTools;

typedef CharacterData =
{
	var path:String;
	var animations:Array<AnimData>;
	var isPlayer:Bool;
	var antialiasing:Bool;
	var scale:Float;
	@:optional var charDeath:String;
	@:optional var flipX:Bool;
	@:optional var isTxt:Bool;
	@:optional var isSpritemap:Bool;
	@:optional var isFlxAnimate:Bool;
	@:optional var spritemapName:String;
	@:optional var healthIcon:String;
	@:optional var healthBarColor:String;
	@:optional var cameraOffset:Array<Float>;
	@:optional var gameOverSound:String;
	@:optional var gameOverMusic:String;
	@:optional var gameOverEnd:String;
	@:optional var gameOverBpm:Float;
	@:optional var gameOverCamFrame:Int;
}

// También modificar AnimData para incluir la hoja a la que pertenece:

typedef AnimData =
{
	var offsetX:Float;
	var offsetY:Float;
	var name:String;
	var looped:Bool;
	var framerate:Float;
	var prefix:String;
	@:optional var indices:Array<Int>;
	@:optional var assetPath:String;
	@:optional var renderType:String;
	/**
	 * Voltear horizontalmente SOLO para esta animación, independiente del flipX global.
	 * Útil cuando un sub-atlas tiene el sprite dibujado en la dirección contraria.
	 *
	 * El flipX resultante es: (flipX_global) XOR (flipX_anim).
	 * Ejemplos:
	 *   personaje sin flipX global + anim.flipX=true  → sprite volteado
	 *   personaje con flipX global + anim.flipX=true  → sprite sin voltear (se cancelan)
	 *   personaje con flipX global + anim.flipX=false → sprite volteado (normal)
	 */
	@:optional var flipX:Bool;
}

/**
	* Character — Playable character / NPC with advanced data cache.
	*
	* ─── Cache Improvements (v2) ───────────────────────────────────────────────────

	* • _dataCache — Caches CharacterData (result of JSON.parse) by character name. Eliminates the cost of File.getContent() +

	* JSON.parse() on repeated loads (e.g., same song is played

	repeated, or same character in multiple stages). Parsing

	a ~2 KB JSON file takes ~0.3-1 ms; negligible once,

	but if repeated 20 times in a session, it adds ~15 ms of I/O.

	* • _pathCache — Caches the path resolved by ModCompatLayer for each character.

	* Avoids traversing the compat layer paths on each load.

	* • invalidateCharCache(name) — Invalidates specific entries (mod reload).

	* • clearCharCaches() — Complete clearing.
	*
	* FunkinSprite already caches FlxAtlasFrames → texture assets are not

	duplicated even if the same character is instantiated multiple times.
 */
class Character extends FunkinSprite
{
	public var animOffsets:Map<String, Array<Dynamic>>;
	public var debugMode:Bool = false;

	public var canSing:Bool = true;
	public var stunned:Bool = false;
	public var isPlayer:Bool = false;
	public var curCharacter:String = 'bf';
	public var holdTimer:Float = 0;

	public var healthIcon:String = 'bf';
	public var healthBarColor:FlxColor = FlxColor.fromString("#31B0D1");
	public var cameraOffset:Array<Float> = [0, 0];

	public var characterData:CharacterData;

	var danced:Bool = false;
	var _singAnimPrefix:String = "sing";
	var _idleAnim:String = "idle";

	/** flipX base del personaje (sin per-anim flipX). Guardado en characterLoad(). */
	var _baseFlipX:Bool = false;

	// ══════════════════════════════════════════════════════════════════════════
	//  CACHÉS ESTÁTICOS
	// ══════════════════════════════════════════════════════════════════════════

	/**
	 * Caché de CharacterData parseados.
	 * key → nombre del personaje (p.ej. "bf", "dad", "gf")
	 *
	 * Almacena el Dynamic ya casteado para que clone() sea O(1) mediante
	 * haxe.Json.parse(haxe.Json.stringify(data)) — deep-copy barato.
	 * Esto garantiza que modificar el CharacterData de una instancia no
	 * corrompa el dato cacheado (inmutabilidad lógica).
	 */
	static var _dataCache:Map<String, String> = []; // key → JSON string del data

	/**
	 * Caché de rutas resueltas por ModCompatLayer.
	 * key → nombre del personaje, value → path absoluto al JSON
	 */
	static var _pathCache:Map<String, String> = [];

	/** Invalida las entradas de un personaje específico (recarga de mod). */
	public static function invalidateCharCache(charName:String):Void
	{
		_dataCache.remove(charName);
		_pathCache.remove(charName);
		// Invalidar también el caché de frames de FunkinSprite
		FunkinSprite.invalidateCache('char_sparrow:$charName');
		FunkinSprite.invalidateCache('char_packer:$charName');
		trace('[Character] Cache invalidado para: $charName');
	}

	/** Limpia todos los cachés de Character. */
	public static function clearCharCaches():Void
	{
		_dataCache.clear();
		_pathCache.clear();
		trace('[Character] Todos los cachés de Character limpiados.');
	}

	// ── Constructor ───────────────────────────────────────────────────────────

	public function new(x:Float, y:Float, ?character:String = "bf", ?isPlayer:Bool = false)
	{
		super(x, y);

		animOffsets = new Map<String, Array<Dynamic>>();
		curCharacter = character;
		this.isPlayer = isPlayer;
		antialiasing = true;

		loadCharacterData(character);

		if (characterData != null)
		{
			characterLoad(curCharacter);
			trace('[Character] Cargado: $character');
		}
		else
		{
			trace('[Character] No se encontraron datos para "$character", usando bf');
			loadCharacterData("bf");
			characterLoad("bf");
		}

		dance();

		isPlayer = characterData.isPlayer;

		if (characterData.flipX != null && characterData.flipX)
			flipX = characterData.flipX;

		if (isPlayer)
		{
			flipX = !flipX;
		}

		// Guardar el flipX base AQUÍ, cuando ya están aplicados isPlayer y flipX del JSON.
		// playAnim() usará este valor como base para el XOR con AnimData.flipX.
		_baseFlipX = this.flipX;

		// Re-danzar con el _baseFlipX ya correcto para que la pose inicial sea la adecuada.
		dance();
	}

	// ── Carga de datos con caché ──────────────────────────────────────────────

	function loadCharacterData(character:String):Void
	{
		// ── Caché hit ─────────────────────────────────────────────────────────
		if (_dataCache.exists(character))
		{
			try
			{
				// Deep-copy del JSON cacheado para aislar la instancia
				characterData = cast haxe.Json.parse(_dataCache.get(character));
				applyCharacterDataDefaults(characterData, character);
				return;
			}
			catch (e:Dynamic)
			{
				// Si el JSON cacheado está corrupto, invalidar y recargar
				trace('[Character] Cache corrupto para "$character", recargando...');
				_dataCache.remove(character);
			}
		}

		// ── Caché miss: cargar desde disco ────────────────────────────────────
		var jsonPath = _pathCache.get(character);
		if (jsonPath == null)
		{
			jsonPath = mods.compat.ModCompatLayer.resolveCharacterPath(character);
			_pathCache.set(character, jsonPath);
		}

		try
		{
			var content:String;
			if (FileSystem.exists(jsonPath))
				content = File.getContent(jsonPath);
			else
				content = lime.utils.Assets.getText(jsonPath);

			characterData = cast mods.compat.ModCompatLayer.loadCharacter(content, character);

			// Guardar en caché como JSON string (deep-copy)
			_dataCache.set(character, haxe.Json.stringify(characterData));

			applyCharacterDataDefaults(characterData, character);
		}
		catch (e:Dynamic)
		{
			trace('[Character] Error cargando datos de "$character": $e');
			characterData = null;
		}
	}

	/** Aplica valores derivados del CharacterData (healthIcon, barColor, etc.) */
	function applyCharacterDataDefaults(data:CharacterData, character:String):Void
	{
		healthIcon = data.healthIcon != null ? data.healthIcon : character;
		healthBarColor = data.healthBarColor != null ? FlxColor.fromString(data.healthBarColor) : healthBarColor;
		cameraOffset = data.cameraOffset != null ? data.cameraOffset : cameraOffset;
	}

	function characterLoad(character:String):Void
	{
		// ── Multi-atlas al estilo V-Slice ────────────────────────────────────
		// Recolectamos todos los assetPath únicos por animación.
		// Si alguna animación tiene su propio assetPath, construimos el atlas
		// combinado igual que MultiSparrowCharacter / MultiAnimateAtlasCharacter.
		//
		// El primer path siempre es el path principal (characterData.path).
		// Los sub-paths se añaden en orden de aparición (sin duplicados).
		// Esto permite que BF-holding-GF, Tankman, etc. funcionen
		// sin necesidad de un archivo .sheets externo.

		final mainPath:String = characterData.path;
		final subPaths:Array<String> = [];
		var needsMultiAtlas:Bool = false;

		for (animData in characterData.animations)
		{
			if (animData.assetPath == null || animData.assetPath == mainPath) continue;
			if (subPaths.contains(animData.assetPath)) continue;
			subPaths.push(animData.assetPath);
			needsMultiAtlas = true;
		}

		if (needsMultiAtlas)
		{
			// V-Slice style: main primero, subs después.
			// IMPORTANTE: usamos resolveAtlasFolder() que ya sabe buscar en mods/ primero
			// y luego en assets/. Así "tankman/basic" → "mods/base_game/characters/images/tankman/basic"
			// si existe ahí, o "assets/characters/images/tankman/basic" si no.
			// NO construimos el path a mano para evitar ignorar el mod activo.
			final resolveCharAtlas = (p:String) -> {
				// Si ya es un path absoluto resuelto (mods/ o assets/) lo usamos directo
				if (p.startsWith('assets/') || p.startsWith('mods/')) return p;
				// Normalizar a clave relativa a characters/images/
				final charKey = p.startsWith('characters/images/') ? p : 'characters/images/$p';
				// resolveAtlasFolder busca en mods → assets y devuelve el path real con Animation.json
				final resolved = animationdata.FunkinSprite.resolveAtlasFolder(charKey);
				if (resolved != null) return resolved;
				// Fallback: devolver como estaba (loadMultiAnimateAtlas lo intentará con assets/)
				return charKey;
			};

			final allPaths:Array<String> = [resolveCharAtlas(mainPath)].concat(subPaths.map(resolveCharAtlas));
			trace('[Character] Multi-atlas para "$curCharacter": ${allPaths.length} atlases → ${allPaths.join(", ")}');
			loadMultiAnimateAtlas(allPaths);
		}
		else
		{
			// FunkinSprite auto-detecta Atlas → Sparrow → Packer
			loadCharacterSparrow(mainPath);
		}

		if (isAnimateAtlas)
			trace('[Character] Modo Texture Atlas para "$curCharacter"');
		else
			trace('[Character] Modo Sparrow/Packer para "$curCharacter"');

		for (animData in characterData.animations)
		{
			addAnim(animData.name, animData.prefix, Std.int(animData.framerate), animData.looped,
				(animData.indices != null && animData.indices.length > 0) ? animData.indices : null);

			var fa = isAnimateAtlas ? null : animation.getByName(animData.name);
			if (!isAnimateAtlas && (fa == null || fa.numFrames == 0))
				trace('[Character] WARN: "${animData.name}" 0 frames (prefix="${animData.prefix}")');

			addOffset(animData.name, animData.offsetX, animData.offsetY);
		}

		antialiasing = characterData.antialiasing;
		scale.set(characterData.scale, characterData.scale);
		updateHitbox();

		applyCharacterSpecificAdjustments();

		// NOTA: _baseFlipX NO se guarda aquí porque isPlayer y flipX del JSON
		// se aplican DESPUÉS en el constructor. Se guarda allí, tras esas modificaciones.

		if (animOffsets.exists('danceRight'))
			playAnim('danceRight');
		else if (animOffsets.exists('danceLeft'))
			playAnim('danceLeft');
		else if (animOffsets.exists(_idleAnim))
			playAnim(_idleAnim);
	}

	// ── playAnim ──────────────────────────────────────────────────────────────

	override public function playAnim(AnimName:String, Force:Bool = false, Reversed:Bool = false, Frame:Int = 0):Void
	{
		super.playAnim(AnimName, Force, Reversed, Frame);

		var daOffset = animOffsets.get(AnimName);
		if (daOffset != null)
			offset.set(daOffset[0], daOffset[1]);
		else
			offset.set(0, 0);

		// ── flipX por animación ────────────────────────────────────────────────
		// Buscar si esta animación tiene flipX propio en el CharacterData.
		// Resultado = _baseFlipX XOR anim.flipX:
		//   false XOR false = false  (sin voltear)
		//   false XOR true  = true   (voltear)
		//   true  XOR false = true   (voltear, normal para isPlayer)
		//   true  XOR true  = false  (se cancelan, útil si el sub-atlas ya viene volteado)
		if (characterData != null)
		{
			for (anim in characterData.animations)
			{
				if (anim.name == AnimName)
				{
					this.flipX = _baseFlipX != (anim.flipX == true);
					break;
				}
			}
		}
	}

	// ── Estado de animación ───────────────────────────────────────────────────

	public function getCurAnimName():String
		return animName;

	public function isCurAnimFinished():Bool
		return animFinished;

	public function hasCurAnim():Bool
		return animName != "";

	public function isPlayingSpecialAnim():Bool
	{
		var name = getCurAnimName();
		if (name == '' || isCurAnimFinished())
			return false;
		if (name.startsWith(_singAnimPrefix))
			return false;
		if (name == _idleAnim)
			return false;
		if (name.startsWith('dance'))
			return false;
		if (name.endsWith('miss'))
			return false;
		if (name == 'firstDeath')
			return false;
		if (name == 'deathLoop')
			return false;
		return true;
	}

	// ── Update ────────────────────────────────────────────────────────────────

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (!hasCurAnim())
			return;

		// En modo debug no se hace nada automático con las animaciones
		// (ni idle, ni sing timeout, ni dance) — el usuario controla todo.
		if (debugMode)
			return;

		var curAnimName = getCurAnimName();
		var curAnimDone = isCurAnimFinished();

		if (!isPlayer)
		{
			if (curAnimName.startsWith(_singAnimPrefix))
			{
				holdTimer += elapsed;
				var dadVar:Float = (curCharacter == 'dad') ? 6.1 : 4.0;
				if (holdTimer >= Conductor.stepCrochet * dadVar * 0.001)
				{
					holdTimer = 0;
					returnToIdle();
				}
			}
			else
			{
				holdTimer = 0;
				if (curAnimDone)
					dance();
			}
		}
		else if (!debugMode)
		{
			if (curAnimName.startsWith(_singAnimPrefix))
			{
				holdTimer += elapsed;
				if (holdTimer >= Conductor.stepCrochet * 4 * 0.001 && canSing)
				{
					returnToIdle();
					holdTimer = 0;
				}
			}
			else
			{
				holdTimer = 0;
				if (curAnimDone)
				{
					if (curAnimName == 'firstDeath')
						playAnim('deathLoop');
					else
						returnToIdle();
				}
			}
		}
	}

	// ── Dance ─────────────────────────────────────────────────────────────────

	public function returnToIdle():Void
	{
		var hasDanceAnims = animOffsets.exists('danceLeft') && animOffsets.exists('danceRight');
		if (hasDanceAnims)
		{
			danced = !danced;
			playAnim(danced ? 'danceRight' : 'danceLeft');
		}
		else
		{
			playAnim(_idleAnim);
		}
	}

	public function dance():Void
	{
		if (!debugMode && !isPlayingSpecialAnim())
		{
			var hasDanceAnims = animOffsets.exists('danceLeft') && animOffsets.exists('danceRight');

			switch (curCharacter)
			{
				default:
					if (hasDanceAnims)
					{
						if (!hasCurAnim() || !getCurAnimName().startsWith(_singAnimPrefix))
						{
							danced = !danced;
							playAnim(danced ? 'danceRight' : 'danceLeft');
						}
					}
					else
					{
						if (!hasCurAnim() || !getCurAnimName().startsWith(_singAnimPrefix))
							playAnim(_idleAnim);
					}
			}
		}
	}

	// ── Ajustes específicos ───────────────────────────────────────────────────

	function applyCharacterSpecificAdjustments():Void
	{
		switch (curCharacter)
		{
			case 'bf-pixel-enemy':
				width -= 100;
				height -= 100;
		}
	}

	function flipAnimations():Void
	{
		if (isAnimateAtlas)
			return;

		if (animation.getByName('singRIGHT') != null && animation.getByName('singLEFT') != null)
		{
			var oldRight = animation.getByName('singRIGHT').frames;
			animation.getByName('singRIGHT').frames = animation.getByName('singLEFT').frames;
			animation.getByName('singLEFT').frames = oldRight;
		}
		if (animation.getByName('singRIGHTmiss') != null && animation.getByName('singLEFTmiss') != null)
		{
			var oldMiss = animation.getByName('singRIGHTmiss').frames;
			animation.getByName('singRIGHTmiss').frames = animation.getByName('singLEFTmiss').frames;
			animation.getByName('singLEFTmiss').frames = oldMiss;
		}
	}

	// ── API pública ───────────────────────────────────────────────────────────

	public function addOffset(name:String, x:Float = 0, y:Float = 0):Void
		animOffsets[name] = [x, y];

	public function getAnimationList():Array<String>
	{
		var list:Array<String> = [];
		for (a in animOffsets.keys())
			list.push(a);
		return list;
	}

	public function hasAnimation(name:String):Bool
		return animOffsets.exists(name);

	public function getOffset(name:String):Array<Dynamic>
		return animOffsets.get(name);

	public function updateOffset(name:String, x:Float, y:Float):Void
	{
		if (animOffsets.exists(name))
			animOffsets.set(name, [x, y]);
	}

	// ── Destruir ──────────────────────────────────────────────────────────────

	override function destroy():Void
	{
		// Liberar los atlases cargados con destroyOnNoUse=false (al estilo V-Slice destroy())
		// Esto restaura destroyOnNoUse=true para que Flixel los pueda limpiar de memoria.
		releaseTrackedAtlases();

		if (animOffsets != null)
		{
			animOffsets.clear();
			animOffsets = null;
		}
		characterData = null;
		super.destroy();
	}
}
