package objects.character;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.animation.FlxBaseAnimation;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.math.FlxMath;
import flixel.util.FlxColor;

using StringTools;

import haxe.Json;
import haxe.format.JsonParser;
import lime.utils.Assets;

typedef CharacterData =
{
	var path:String;
	var animations:Array<AnimData>;
	var isPlayer:Bool;
	var antialiasing:Bool;
	var scale:Float;
	@:optional var flipX:Bool;
	@:optional var indices:Array<Int>;
	@:optional var isTxt:Bool;
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
	var prefix:String;
	@:optional var specialAnim:Bool;
	@:optional var indices:Array<Int>;
}

class Character extends FlxSprite
{
	public var animOffsets:Map<String, Array<Dynamic>>;
	public var debugMode:Bool = false;

	public var canSing:Bool = true;
	public var stunned:Bool = false;
	public var isPlayer:Bool = false;
	public var specialAnim:Bool = false;
	public var curCharacter:String = 'bf';
	public var holdTimer:Float = 0;

	// Additional properties
	public var healthIcon:String = 'bf';
	public var healthBarColor:FlxColor = FlxColor.fromString("#31B0D1");
	public var cameraOffset:Array<Float> = [0, 0];

	var characterData:CharacterData;
	var danced:Bool = false;

	// Performance optimization: cache frequently used values
	var _singAnimPrefix:String = "sing";
	var _idleAnim:String = "idle";

	public function new(x:Float, y:Float, ?character:String = "bf", ?isPlayer:Bool = false)
	{
		super(x, y);

		animOffsets = new Map<String, Array<Dynamic>>();
		curCharacter = character;
		this.isPlayer = isPlayer;

		antialiasing = true;

		// Load character from JSON
		loadCharacterData(character);

		if (characterData != null)
		{
			characterLoad(curCharacter);
			trace("Loaded character data for: " + character);
		}
		else
		{
			trace("Character data not found for: " + character + ", loading default");
			loadCharacterData("bf");
			characterLoad("bf");
		}

		dance();

		if (isPlayer)
		{
			flipX = !flipX;

			// Doesn't flip for BF, since his are already in the right place
			if (!curCharacter.startsWith('bf'))
			{
				flipAnimations();
			}
		}
	}

	function loadCharacterData(character:String):Void
	{
		try
		{
			var file:String = Assets.getText(Paths.characterJSON(character));
			characterData = cast Json.parse(file);

			// Load additional properties
			if (characterData.healthIcon != null)
				healthIcon = characterData.healthIcon;
			else
				healthIcon = character;

			if (characterData.healthBarColor != null)
				healthBarColor = FlxColor.fromString(characterData.healthBarColor);

			if (characterData.cameraOffset != null)
				cameraOffset = characterData.cameraOffset;
		}
		catch (e:Dynamic)
		{
			trace("Error loading character data for " + character + ": " + e);
			characterData = null;
		}
	}

	function characterLoad(character:String):Void
	{
		// Load sprite sheet
		if (characterData.isTxt != null && characterData.isTxt)
			frames = Paths.characterSpriteTxt(characterData.path);
		else
			frames = Paths.characterSprite(characterData.path);

		// Add animations
		for (anim in characterData.animations)
		{
			// Check if animation uses indices
			if (anim.indices != null && anim.indices.length > 0)
			{
				animation.addByIndices(anim.name, anim.prefix, anim.indices, "", Std.int(anim.framerate), anim.looped);
			}
			else
			{
				animation.addByPrefix(anim.name, anim.prefix, Std.int(anim.framerate), anim.looped);
			}

			if (anim.specialAnim != null && anim.specialAnim)
			{
				specialAnim = true;
			}

			addOffset(anim.name, anim.offsetX, anim.offsetY);
		}

		// Apply character properties
		antialiasing = characterData.antialiasing;
		scale.set(characterData.scale, characterData.scale);
		updateHitbox();

		// Handle character-specific adjustments
		applyCharacterSpecificAdjustments();

		// Play initial animation
		if (animOffsets.exists('danceRight'))
			playAnim('danceRight');
		else if (animOffsets.exists(_idleAnim))
			playAnim(_idleAnim);

		// Apply flipX from JSON if specified
		if (characterData.flipX != null && characterData.flipX)
		{
			flipX = true;
		}
	}

	function applyCharacterSpecificAdjustments():Void
	{
		// Handle pixel characters or specific character adjustments
		switch (curCharacter)
		{
			case 'bf-pixel-enemy':
				width -= 100;
				height -= 100;
				// Add more character-specific adjustments here
		}
	}

	function flipAnimations():Void
	{
		// Flip LEFT and RIGHT animations for player characters
		if (animation.getByName('singRIGHT') != null && animation.getByName('singLEFT') != null)
		{
			var oldRight = animation.getByName('singRIGHT').frames;
			animation.getByName('singRIGHT').frames = animation.getByName('singLEFT').frames;
			animation.getByName('singLEFT').frames = oldRight;
		}

		// Flip MISS animations if they exist
		if (animation.getByName('singRIGHTmiss') != null && animation.getByName('singLEFTmiss') != null)
		{
			var oldMiss = animation.getByName('singRIGHTmiss').frames;
			animation.getByName('singRIGHTmiss').frames = animation.getByName('singLEFTmiss').frames;
			animation.getByName('singLEFTmiss').frames = oldMiss;
		}
	}

	override function update(elapsed:Float)
	{
		if (animation.curAnim == null)
		{
			super.update(elapsed);
			return;
		}

		// Handle non-BF characters (DAD, GF, etc)
		if (!curCharacter.startsWith('bf'))
		{
			if (animation.curAnim.name.startsWith(_singAnimPrefix))
			{
				holdTimer += elapsed;

				var dadVar:Float = 4;
				if (curCharacter == 'dad')
					dadVar = 6.1;

				if (holdTimer >= Conductor.stepCrochet * dadVar * 0.001)
				{
					dance();
					holdTimer = 0;
				}
			}
			else
			{
				// FIX PROBLEMA 1: Dad vuelve a idle en loop
				holdTimer = 0;
				if (animation.curAnim.finished)
				{
					dance();
				}
			}
		}
		else if (!debugMode)
		{
			// Handle BF characters
			if (animation.curAnim.name.startsWith(_singAnimPrefix))
			{
				holdTimer += elapsed;
			}
			else
			{
				holdTimer = 0;

				// FIX PROBLEMA 3: Boyfriend idle hace loop
				if (animation.curAnim.name == _idleAnim && animation.curAnim.finished)
				{
					playAnim(_idleAnim, true);
				}
			}

			// Handle miss animations
			if (animation.curAnim.name.endsWith('miss') && animation.curAnim.finished)
			{
				playAnim(_idleAnim, true, false, 10);
			}

			// Handle death animations
			if (animation.curAnim.name == 'firstDeath' && animation.curAnim.finished)
			{
				playAnim('deathLoop');
			}
		}

		// Handle GF specific animations
		handleSpecialAnimations();

		super.update(elapsed);
	}

	function handleSpecialAnimations():Void
	{
		switch (curCharacter)
		{
			case 'gf' | 'gf-christmas' | 'gf-pixel' | 'gf-car':
				if (animation.curAnim != null && animation.curAnim.name == 'hairFall' && animation.curAnim.finished)
				{
					playAnim('danceRight');
				}
		}
	}

	/**
	 * FOR GF DANCING SHIT
	 */
	public function dance():Void
	{
		if (!debugMode && !specialAnim)
		{
			switch (curCharacter)
			{
				case 'gf' | 'gf-car' | 'gf-pixel' | 'gf-christmas':
					// FIX PROBLEMA 2: GF no baila a lo loco
					if (animation.curAnim == null || !animation.curAnim.name.startsWith(_singAnimPrefix))
					{
						// Solo cambiamos el lado del baile si la animación de 'hair' (pelo) terminó o no existe
						if (animation.curAnim == null || !animation.curAnim.name.startsWith('hair') || animation.curAnim.finished)
						{
							danced = !danced;

							if (danced)
								playAnim('danceRight');
							else
								playAnim('danceLeft');
						}
					}

				case 'spooky':
					// Mismo fix para Spooky
					//var currentAnim = animation.curAnim != null ? animation.curAnim.name : "";
					if (animation.curAnim == null || !animation.curAnim.name.startsWith(_singAnimPrefix))
					{
						danced = !danced; // Cambia entre danceLeft y danceRight [cite: 36]

						if (danced)
							playAnim('danceRight');
						else
							playAnim('danceLeft');
					}

				default:
					playAnim(_idleAnim);
			}
		}
	}

	public function playAnim(AnimName:String, Force:Bool = false, Reversed:Bool = false, Frame:Int = 0):Void
	{
		if (!canSing && specialAnim)
			return;

		animation.play(AnimName, Force, Reversed, Frame);

		// Apply offset
		var daOffset = animOffsets.get(AnimName);
		if (daOffset != null)
		{
			offset.set(daOffset[0], daOffset[1]);
		}
		else
			offset.set(0, 0);
	}

	public function addOffset(name:String, x:Float = 0, y:Float = 0):Void
	{
		animOffsets[name] = [x, y];
	}

	/**
	 * Get all animation names
	 */
	public function getAnimationList():Array<String>
	{
		var list:Array<String> = [];
		for (anim in animOffsets.keys())
		{
			list.push(anim);
		}
		return list;
	}

	/**
	 * Check if animation exists
	 */
	public function hasAnimation(name:String):Bool
	{
		return animOffsets.exists(name);
	}

	/**
	 * Get animation offset
	 */
	public function getOffset(name:String):Array<Dynamic>
	{
		return animOffsets.get(name);
	}

	/**
	 * Update animation offset
	 */
	public function updateOffset(name:String, x:Float, y:Float):Void
	{
		if (animOffsets.exists(name))
		{
			animOffsets.set(name, [x, y]);
		}
	}

	/**
	 * Clean up
	 */
	override function destroy():Void
	{
		animOffsets.clear();
		animOffsets = null;
		characterData = null;
		super.destroy();
	}
}
