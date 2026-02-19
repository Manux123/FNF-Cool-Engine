package funkin.gameplay.objects.character;

// FunkinSprite reemplaza a FlxSprite + FlxAnimate manual
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
	/**
	 * Conservado por compatibilidad con JSONs existentes.
	 * FunkinSprite auto-detecta el tipo de asset — ya no es obligatorio.
	 */
	@:optional var isFlxAnimate:Bool;
	@:optional var spritemapName:String;
	@:optional var healthIcon:String;
	@:optional var healthBarColor:String;
	@:optional var cameraOffset:Array<Float>;
}

typedef AnimData =
{
	var offsetX:Float;
	var offsetY:Float;
	var name:String;
	var looped:Bool;
	var framerate:Float;
	/**
	 * Sprites normales : prefix del XML/TXT.
	 * FlxAnimate       : nombre exacto del símbolo (campo SN en Animation.json).
	 */
	var prefix:String;
	@:optional var specialAnim:Bool;
	@:optional var indices:Array<Int>;
}

/**
 * Character — Personaje jugable / NPC.
 *
 * Ahora extiende FunkinSprite, que unifica:
 *   - Texture Atlas de Adobe Animate (FlxAnimate internamente)
 *   - Sparrow Atlas  (PNG + XML)
 *   - Packer Atlas   (PNG + TXT)
 *
 * Ya NO es necesario gestionar un sub-sprite _flxAnimate a mano:
 * FunkinSprite expone playAnim / addAnim / animName / animFinished
 * de forma transparente para cualquier tipo de asset.
 */
class Character extends FunkinSprite
{
	public var animOffsets:Map<String, Array<Dynamic>>;
	public var debugMode:Bool = false;

	public var canSing:Bool     = true;
	public var stunned:Bool     = false;
	public var isPlayer:Bool    = false;
	public var specialAnim:Bool = false;
	public var curCharacter:String = 'bf';
	public var holdTimer:Float  = 0;

	public var healthIcon:String = 'bf';
	public var healthBarColor:FlxColor = FlxColor.fromString("#31B0D1");
	public var cameraOffset:Array<Float> = [0, 0];

	public var characterData:CharacterData;
	var danced:Bool = false;

	var _singAnimPrefix:String = "sing";
	var _idleAnim:String       = "idle";

	// ── Constructor ───────────────────────────────────────────────────────────

	public function new(x:Float, y:Float, ?character:String = "bf", ?isPlayer:Bool = false)
	{
		super(x, y); // FunkinSprite(x, y) → FlxAnimate(x, y)

		animOffsets   = new Map<String, Array<Dynamic>>();
		curCharacter  = character;
		this.isPlayer = isPlayer;
		antialiasing  = true;

		loadCharacterData(character);

		if (characterData != null)
		{
			characterLoad(curCharacter);
			trace('[Character] Cargado: ' + character);
		}
		else
		{
			trace('[Character] No se encontraron datos para "' + character + '", usando bf');
			loadCharacterData("bf");
			characterLoad("bf");
		}

		dance();

		isPlayer = characterData.isPlayer;

		if (isPlayer)
		{
			flipX = !flipX;
			if (!curCharacter.startsWith('bf'))
				flipAnimations();
		}
	}

	// ── Carga de datos ────────────────────────────────────────────────────────

	function loadCharacterData(character:String):Void
	{
		var jsonPath = Paths.characterJSON(character);

		try
		{
			var content:String;
			if (FileSystem.exists(jsonPath))
				content = File.getContent(jsonPath);
			else
				content = lime.utils.Assets.getText(jsonPath);

			characterData = cast Json.parse(content);

			healthIcon     = characterData.healthIcon     != null ? characterData.healthIcon     : character;
			healthBarColor = characterData.healthBarColor != null ? FlxColor.fromString(characterData.healthBarColor) : healthBarColor;
			cameraOffset   = characterData.cameraOffset   != null ? characterData.cameraOffset   : cameraOffset;
		}
		catch (e:Dynamic)
		{
			trace('[Character] Error cargando datos de "' + character + '": ' + e);
			characterData = null;
		}
	}

	function characterLoad(character:String):Void
	{
		// ─────────────────────────────────────────────────────────────────────
		// FunkinSprite.loadCharacterSparrow() auto-detecta en este orden:
		//   1. Texture Atlas (carpeta con Animation.json)  → FlxAnimate interno
		//   2. Sparrow  (PNG + XML)
		//   3. Packer   (PNG + TXT)
		// El campo JSON isFlxAnimate ya no es necesario.
		// ─────────────────────────────────────────────────────────────────────
		loadCharacterSparrow(characterData.path);

		if (isAnimateAtlas)
			trace('[Character] Modo Texture Atlas para "$curCharacter"');
		else
			trace('[Character] Modo Sparrow/Packer para "$curCharacter"');

		// Registrar animaciones con la API unificada de FunkinSprite
		for (animData in characterData.animations)
		{
			// addAnim() llama internamente a anim.addBySymbol (atlas)
			// o animation.addByPrefix / addByIndices (sparrow/packer)
			addAnim(
				animData.name,
				animData.prefix,
				Std.int(animData.framerate),
				animData.looped,
				(animData.indices != null && animData.indices.length > 0) ? animData.indices : null
			);

			var fa = isAnimateAtlas ? null : animation.getByName(animData.name);
			if (!isAnimateAtlas && (fa == null || fa.numFrames == 0))
				trace('[Character] WARN: "${animData.name}" 0 frames (prefix="${animData.prefix}")');

			addOffset(animData.name, animData.offsetX, animData.offsetY);
		}

		antialiasing = characterData.antialiasing;
		scale.set(characterData.scale, characterData.scale);
		updateHitbox();

		applyCharacterSpecificAdjustments();

		// Animación inicial
		if (animOffsets.exists('danceRight'))        playAnim('danceRight');
		else if (animOffsets.exists('danceLeft'))     playAnim('danceLeft');
		else if (animOffsets.exists(_idleAnim))       playAnim(_idleAnim);

		if (characterData.flipX != null && characterData.flipX)
			flipX = true;
	}

	// ── playAnim ──────────────────────────────────────────────────────────────

	/**
	 * Sobreescribe FunkinSprite.playAnim para añadir:
	 *   - Guardia canSing / specialAnim
	 *   - Aplicación de animOffsets
	 */
	override public function playAnim(AnimName:String, Force:Bool = false, Reversed:Bool = false, Frame:Int = 0):Void
	{
		if (!canSing && specialAnim)
			return;

		// FunkinSprite maneja atlas y sparrow de forma transparente
		super.playAnim(AnimName, Force, Reversed, Frame);

		var daOffset = animOffsets.get(AnimName);
		if (daOffset != null)
			offset.set(daOffset[0], daOffset[1]);
		else
			offset.set(0, 0);
	}

	// ── Estado de animación — delegados a FunkinSprite ────────────────────────

	/** Nombre de la animación activa (funciona en atlas y sparrow). */
	public function getCurAnimName():String
		return animName; // FunkinSprite.animName

	/** ¿Ha terminado la animación actual? */
	public function isCurAnimFinished():Bool
		return animFinished; // FunkinSprite.animFinished

	/** ¿Hay alguna animación activa? */
	public function hasCurAnim():Bool
		return animName != "";

	// ── Update ────────────────────────────────────────────────────────────────

	override function update(elapsed:Float)
	{
		// FunkinSprite (que extiende FlxAnimate) ya actualiza el sistema de
		// animaciones internamente — no hay que llamar a _flxAnimate.update().
		super.update(elapsed);

		if (!hasCurAnim())
			return;

		var curAnimName = getCurAnimName();
		var curAnimDone = isCurAnimFinished();

		if (!curCharacter.startsWith('bf'))
		{
			if (curAnimName.startsWith(_singAnimPrefix))
			{
				holdTimer += elapsed;
				var dadVar:Float = (curCharacter == 'dad') ? 6.1 : 4.0;
				if (holdTimer >= Conductor.stepCrochet * dadVar * 0.001)
				{
					dance();
					holdTimer = 0;
				}
			}
			else
			{
				holdTimer = 0;
				var hasDanceAnims = animOffsets.exists('danceLeft') && animOffsets.exists('danceRight');
				if (!hasDanceAnims && curAnimDone)
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
					playAnim(_idleAnim, true);
					holdTimer = 0;
				}
			}
			else
			{
				holdTimer = 0;
				if (curAnimName == _idleAnim && curAnimDone)
					playAnim(_idleAnim, true);
			}

			if (curAnimName.endsWith('miss') && curAnimDone)
				playAnim(_idleAnim, true, false, 10);

			if (curAnimName == 'firstDeath' && curAnimDone)
				playAnim('deathLoop');
		}

		handleSpecialAnimations();
	}

	// ── Draw ──────────────────────────────────────────────────────────────────

	// ── Animaciones especiales ────────────────────────────────────────────────

	function handleSpecialAnimations():Void
	{
		switch (curCharacter)
		{
			case 'gf' | 'gf-christmas' | 'gf-pixel' | 'gf-car':
				if (hasCurAnim() && getCurAnimName() == 'hairFall' && isCurAnimFinished())
					playAnim('danceRight');
		}
	}

	// ── Dance ─────────────────────────────────────────────────────────────────

	public function dance():Void
	{
		if (!debugMode && !specialAnim)
		{
			var hasDanceAnims = animOffsets.exists('danceLeft') && animOffsets.exists('danceRight');

			switch (curCharacter)
			{
				case 'gf' | 'gf-car' | 'gf-pixel' | 'gf-christmas' | 'gf-tankmen':
					if (!hasCurAnim() || !getCurAnimName().startsWith(_singAnimPrefix))
					{
						if (!hasCurAnim() || !getCurAnimName().startsWith('hair') || isCurAnimFinished())
						{
							danced = !danced;
							playAnim(danced ? 'danceRight' : 'danceLeft');
						}
					}

				case 'spooky':
					if (!hasCurAnim() || !getCurAnimName().startsWith(_singAnimPrefix))
					{
						danced = !danced;
						playAnim(danced ? 'danceRight' : 'danceLeft');
					}

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
				width  -= 100;
				height -= 100;
		}
	}

	function flipAnimations():Void
	{
		// Solo aplica en modo sparrow (no en atlas — FlxAnimate no expone los frames directamente)
		if (isAnimateAtlas) return; // FunkinSprite.isAnimateAtlas

		if (animation.getByName('singRIGHT') != null && animation.getByName('singLEFT') != null)
		{
			var oldRight = animation.getByName('singRIGHT').frames;
			animation.getByName('singRIGHT').frames = animation.getByName('singLEFT').frames;
			animation.getByName('singLEFT').frames  = oldRight;
		}
		if (animation.getByName('singRIGHTmiss') != null && animation.getByName('singLEFTmiss') != null)
		{
			var oldMiss = animation.getByName('singRIGHTmiss').frames;
			animation.getByName('singRIGHTmiss').frames = animation.getByName('singLEFTmiss').frames;
			animation.getByName('singLEFTmiss').frames  = oldMiss;
		}
	}

	// ── API pública ───────────────────────────────────────────────────────────

	public function addOffset(name:String, x:Float = 0, y:Float = 0):Void
		animOffsets[name] = [x, y];

	public function getAnimationList():Array<String>
	{
		var list:Array<String> = [];
		for (a in animOffsets.keys()) list.push(a);
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
		// FunkinSprite (FlxAnimate) limpia sus propios recursos internamente
		if (animOffsets != null) { animOffsets.clear(); animOffsets = null; }
		characterData = null;
		super.destroy();
	}
}
