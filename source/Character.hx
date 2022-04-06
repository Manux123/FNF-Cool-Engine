package;

import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import openfl.utils.Assets;
import lime.utils.Assets;
import states.ModsState;
import states.ModsFreeplayState;

using StringTools;

typedef CharacterData =
{
	var char:String;
    var texture:String;
    var xOffset:Int;
    var yOffset:Int;
    var anims:Array<String>;
	var healthBarColor:String;
};

class Character extends FlxSprite
{
	public var animOffsets:Map<String, Array<Dynamic>>;
	public var debugMode:Bool = false;

	public var canSing:Bool = true;

	public var isPlayer:Bool = false;
	public var specialAnim:Bool = false;
	public var curCharacter:String = 'bf';

	public var holdTimer:Float = 0;
	public var healthBarColor:String;
	public var bfDefaultColor:String = "FF31b0d1";

	public static final animationsMap:Map<Int,String> = [
		0 => 'singLEFT',
		1 => 'singDOWN',
		2 => 'singUP',
		3 => 'singRIGHT'
	];

	var tex:FlxAtlasFrames;

	public function new(x:Float, y:Float, ?character:String = "bf", ?isPlayer:Bool = false)
	{
		super(x, y);
		
		animOffsets = new Map<String, Array<Dynamic>>();
		curCharacter = character;
		this.isPlayer = isPlayer;
		
		antialiasing = true;

		switch (curCharacter)
		{
			case 'gf':
				// GIRLFRIEND CODE
				tex = Paths.getSparrowAtlas('characters/GF_assets');
				frames = tex;
				gilfriendAnimation();

				loadOffsetFile(curCharacter);

				playAnim('danceRight');

				healthBarColor = "FFa5004d";

			case 'gf-christmas':
				tex = Paths.getSparrowAtlas('christmas/gfChristmas');
				frames = tex;
				gilfriendAnimation();

				loadOffsetFile(curCharacter);

				playAnim('danceRight');
				
			healthBarColor = "FFa5004d";

			case 'gf-car':
				tex = Paths.getSparrowAtlas('characters/week4/gfCar');
				frames = tex;
				animation.addByIndices('singUP', 'GF Dancing Beat Hair blowing CAR', [0], "", 24, false);
				animation.addByIndices('danceLeft', 'GF Dancing Beat Hair blowing CAR', [30, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14], "", 24, false);
				animation.addByIndices('danceRight', 'GF Dancing Beat Hair blowing CAR', [15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29], "", 24,
					false);

				loadOffsetFile(curCharacter);

				playAnim('danceRight');

			healthBarColor = "FFa5004d";

			case 'gf-pixel':
				tex = Paths.getSparrowAtlas('weeb/gfPixel');
				frames = tex;
				animation.addByIndices('singUP', 'GF IDLE', [2], "", 24, false);
				animation.addByIndices('danceLeft', 'GF IDLE', [30, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14], "", 24, false);
				animation.addByIndices('danceRight', 'GF IDLE', [15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29], "", 24, false);

				loadOffsetFile(curCharacter);

				playAnim('danceRight');

				setGraphicSize(Std.int(width * states.PlayState.daPixelZoom));
				updateHitbox();
				antialiasing = false;

			healthBarColor = "FFa5004d";

			case 'dad':
				// DAD ANIMATION?
				//ANIMATIONS FROM TEXT FILE WIP!?!?!?!

				//loadAnimations(); beta

				tex = Paths.getSparrowAtlas('characters/week1/DADDY_DEAREST');
				frames = tex;
				animation.addByPrefix('idle', 'Dad idle dance', 24, false);
				animation.addByPrefix('singUP', 'Dad Sing Note UP', 24, false);
				animation.addByPrefix('singRIGHT', 'Dad Sing Note RIGHT', 24, false);
				animation.addByPrefix('singDOWN', 'Dad Sing Note DOWN', 24, false);
				animation.addByPrefix('singLEFT', 'Dad Sing Note LEFT', 24, false);

				loadOffsetFile(curCharacter);

				playAnim('idle');

				healthBarColor = "FFaf66ce";

			case 'spooky':
				// SPOOKY MONTH!
				tex = Paths.getSparrowAtlas('characters/week2/spooky_kids_assets');
				frames = tex;
				animation.addByPrefix('singUP', 'spooky UP NOTE', 24, false);
				animation.addByPrefix('singDOWN', 'spooky DOWN note', 24, false);
				animation.addByPrefix('singLEFT', 'note sing left', 24, false);
				animation.addByPrefix('singRIGHT', 'spooky sing right', 24, false);
				animation.addByIndices('danceLeft', 'spooky dance idle', [0, 2, 6], "", 12, false);
				animation.addByIndices('danceRight', 'spooky dance idle', [8, 10, 12, 14], "", 12, false);

				loadOffsetFile(curCharacter);

				playAnim('danceRight');

				healthBarColor = "FFd57e00";

			case 'mom':
				tex = Paths.getSparrowAtlas('characters/week4/Mom_Assets');
				frames = tex;

				animation.addByPrefix('idle', "Mom Idle", 24, false);
				animation.addByPrefix('singUP', "Mom Up Pose", 24, false);
				animation.addByPrefix('singDOWN', "MOM DOWN POSE", 24, false);
				animation.addByPrefix('singLEFT', 'Mom Left Pose', 24, false);
				// ANIMATION IS CALLED MOM LEFT POSE BUT ITS FOR THE RIGHT
				// CUZ DAVE IS DUMB!
				animation.addByPrefix('singRIGHT', 'Mom Pose Left', 24, false);

				loadOffsetFile(curCharacter);

				playAnim('idle');

				healthBarColor = "FFd8558e";

			case 'mom-car':
				tex = Paths.getSparrowAtlas('characters/week4/momCar');
				frames = tex;

				animation.addByPrefix('idle', "Mom Idle", 24, false);
				animation.addByPrefix('singUP', "Mom Up Pose", 24, false);
				animation.addByPrefix('singDOWN', "MOM DOWN POSE", 24, false);
				animation.addByPrefix('singLEFT', 'Mom Left Pose', 24, false);
				animation.addByPrefix('singRIGHT', 'Mom Pose Left', 24, false);

				loadOffsetFile(curCharacter);

				playAnim('idle');

				healthBarColor = "FFd8558e";

			case 'monster':
				tex = Paths.getSparrowAtlas('characters/week2/Monster_Assets');
				frames = tex;
				animation.addByPrefix('idle', 'monster idle', 24, false);
				animation.addByPrefix('singUP', 'monster up note', 24, false);
				animation.addByPrefix('singDOWN', 'monster down', 24, false);
				animation.addByPrefix('singLEFT', 'Monster Right note', 24, false);
				animation.addByPrefix('singRIGHT', 'Monster left note', 24, false);

				loadOffsetFile(curCharacter);

				playAnim('idle');

				healthBarColor = "FFf3ff6e";

			case 'monster-christmas':
				tex = Paths.getSparrowAtlas('christmas/monsterChristmas');
				frames = tex;
				animation.addByPrefix('idle', 'monster idle', 24, false);
				animation.addByPrefix('singUP', 'monster up note', 24, false);
				animation.addByPrefix('singDOWN', 'monster down', 24, false);
				animation.addByPrefix('singLEFT', 'Monster Right note', 24, false);
				animation.addByPrefix('singRIGHT', 'Monster left note', 24, false);

				loadOffsetFile(curCharacter);

				playAnim('idle');

				healthBarColor = "FFf3ff6e";

			case 'pico':
				tex = Paths.getSparrowAtlas('Pico_FNF_assetss');
				frames = tex;
				animation.addByPrefix('idle', "Pico Idle Dance", 24);
				animation.addByPrefix('singUP', 'pico Up note0', 24, false);
				animation.addByPrefix('singDOWN', 'Pico Down Note0', 24, false);
				if (isPlayer)
				{
					animation.addByPrefix('singLEFT', 'Pico NOTE LEFT0', 24, false);
					animation.addByPrefix('singRIGHT', 'Pico Note Right0', 24, false);
					animation.addByPrefix('singRIGHTmiss', 'Pico Note Right Miss', 24, false);
					animation.addByPrefix('singLEFTmiss', 'Pico NOTE LEFT miss', 24, false);
				}
				else
				{
					// Need to be flipped! REDO THIS LATER!
					animation.addByPrefix('singLEFT', 'Pico Note Right0', 24, false);
					animation.addByPrefix('singRIGHT', 'Pico NOTE LEFT0', 24, false);
					animation.addByPrefix('singRIGHTmiss', 'Pico NOTE LEFT miss', 24, false);
					animation.addByPrefix('singLEFTmiss', 'Pico Note Right Miss', 24, false);
				}

				animation.addByPrefix('singUPmiss', 'pico Up note miss', 24);
				animation.addByPrefix('singDOWNmiss', 'Pico Down Note MISS', 24);

				loadOffsetFile(curCharacter);

				playAnim('idle');

				flipX = true;

				healthBarColor = "FFb7d855";

			case 'bf':
				tex = Paths.getSparrowAtlas('characters/BOYFRIEND');
				frames = tex;
				boyfriendAnimation();

				loadOffsetFile(curCharacter);

				playAnim('idle');

				flipX = true;

			case 'bf-christmas':
				tex = Paths.getSparrowAtlas('christmas/bfChristmas');
				frames = tex;
				boyfriendAnimation();

				loadOffsetFile(curCharacter);

				playAnim('idle');

				flipX = true;

			case 'bf-car':
				tex = Paths.getSparrowAtlas('characters/week4/bfCar');
				frames = tex;
				boyfriendAnimation();

				loadOffsetFile(curCharacter);

				playAnim('idle');

				flipX = true;

			case 'bf-pixel':
				frames = Paths.getSparrowAtlas('weeb/bfPixel');
				animation.addByPrefix('idle', 'BF IDLE', 24, false);
				animation.addByPrefix('singUP', 'BF UP NOTE', 24, false);
				animation.addByPrefix('singLEFT', 'BF LEFT NOTE', 24, false);
				animation.addByPrefix('singRIGHT', 'BF RIGHT NOTE', 24, false);
				animation.addByPrefix('singDOWN', 'BF DOWN NOTE', 24, false);
				animation.addByPrefix('singUPmiss', 'BF UP MISS', 24, false);
				animation.addByPrefix('singLEFTmiss', 'BF LEFT MISS', 24, false);
				animation.addByPrefix('singRIGHTmiss', 'BF RIGHT MISS', 24, false);
				animation.addByPrefix('singDOWNmiss', 'BF DOWN MISS', 24, false);

				loadOffsetFile(curCharacter);

				setGraphicSize(Std.int(width * 6));
				updateHitbox();

				playAnim('idle');

				width -= 100;
				height -= 100;

				antialiasing = false;

				flipX = true;

			case 'bf-pixel-dead':
				frames = Paths.getSparrowAtlas('weeb/bfPixelsDEAD');
				animation.addByPrefix('singUP', "BF Dies pixel", 24, false);
				animation.addByPrefix('firstDeath', "BF Dies pixel", 24, false);
				animation.addByPrefix('deathLoop', "Retry Loop", 24, true);
				animation.addByPrefix('deathConfirm', "RETRY CONFIRM", 24, false);
				animation.play('firstDeath');

				loadOffsetFile(curCharacter);
				playAnim('firstDeath');

				setGraphicSize(Std.int(width * 6));
				updateHitbox();

				antialiasing = false;
				
				flipX = true;

			case 'bf-dead':
				frames = Paths.getSparrowAtlas('characters/BF_dead');
				animation.addByPrefix('firstDeath', "BF dies", 24, false);
				animation.addByPrefix('deathLoop', "BF Dead Loop", 24, true);
				animation.addByPrefix('deathConfirm', "BF Dead confirm", 24, false);
				animation.play('firstDeath');

				loadOffsetFile(curCharacter);
				playAnim('firstDeath');
				
				flipX = true;

			case 'senpai':
				frames = Paths.getSparrowAtlas('weeb/senpai');
				animation.addByPrefix('idle', 'Senpai Idle', 24, false);
				animation.addByPrefix('singUP', 'SENPAI UP NOTE', 24, false);
				animation.addByPrefix('singLEFT', 'SENPAI LEFT NOTE', 24, false);
				animation.addByPrefix('singRIGHT', 'SENPAI RIGHT NOTE', 24, false);
				animation.addByPrefix('singDOWN', 'SENPAI DOWN NOTE', 24, false);

				loadOffsetFile(curCharacter);

				playAnim('idle');

				setGraphicSize(Std.int(width * 6));
				updateHitbox();

				antialiasing = false;

				healthBarColor = "FFffaa6f";

			case 'senpai-angry':
				frames = Paths.getSparrowAtlas('weeb/senpai');
				animation.addByPrefix('idle', 'Angry Senpai Idle', 24, false);
				animation.addByPrefix('singUP', 'Angry Senpai UP NOTE', 24, false);
				animation.addByPrefix('singLEFT', 'Angry Senpai LEFT NOTE', 24, false);
				animation.addByPrefix('singRIGHT', 'Angry Senpai RIGHT NOTE', 24, false);
				animation.addByPrefix('singDOWN', 'Angry Senpai DOWN NOTE', 24, false);

				loadOffsetFile(curCharacter);

				playAnim('idle');

				setGraphicSize(Std.int(width * 6));
				updateHitbox();

				antialiasing = false;

				healthBarColor = "FFffaa6f";

			case 'spirit':
				frames = Paths.getPackerAtlas('weeb/spirit');
				animation.addByPrefix('idle', "idle spirit_", 24, false);
				animation.addByPrefix('singUP', "up_", 24, false);
				animation.addByPrefix('singRIGHT', "right_", 24, false);
				animation.addByPrefix('singLEFT', "left_", 24, false);
				animation.addByPrefix('singDOWN', "spirit down_", 24, false);

				loadOffsetFile(curCharacter);

				setGraphicSize(Std.int(width * 6));
				updateHitbox();

				playAnim('idle');

				antialiasing = false;
				healthBarColor = "FFff3c6e";

			case 'parents-christmas':
				frames = Paths.getSparrowAtlas('christmas/mom_dad_christmas_assets');
				animation.addByPrefix('idle', 'Parent Christmas Idle', 24, false);
				animation.addByPrefix('singUP', 'Parent Up Note Dad', 24, false);
				animation.addByPrefix('singDOWN', 'Parent Down Note Dad', 24, false);
				animation.addByPrefix('singLEFT', 'Parent Left Note Dad', 24, false);
				animation.addByPrefix('singRIGHT', 'Parent Right Note Dad', 24, false);

				animation.addByPrefix('singUP-alt', 'Parent Up Note Mom', 24, false);

				animation.addByPrefix('singDOWN-alt', 'Parent Down Note Mom', 24, false);
				animation.addByPrefix('singLEFT-alt', 'Parent Left Note Mom', 24, false);
				animation.addByPrefix('singRIGHT-alt', 'Parent Right Note Mom', 24, false);

				loadOffsetFile(curCharacter);

				playAnim('idle');

				healthBarColor = "FFaf66ce";
			case 'bf-pixel-enemy':
				frames = Paths.getSparrowAtlas('weeb/bfPixel', 'week6');
				animation.addByPrefix('idle', 'BF IDLE', 24, false);
				animation.addByPrefix('singUP', 'BF UP NOTE', 24, false);
				animation.addByPrefix('singLEFT', 'BF RIGHT NOTE', 24, false);
				animation.addByPrefix('singRIGHT', 'BF LEFT NOTE', 24, false);
				animation.addByPrefix('singDOWN', 'BF DOWN NOTE', 24, false);
				loadOffsetFile(curCharacter);
	
				setGraphicSize(Std.int(width * 6));
				updateHitbox();
	
				playAnim('idle');
	
				width -= 100;
				height -= 100;
	
				antialiasing = false;
	
				flipX = true;
				healthBarColor = "FF7bd6f6";

			default:
				if(isPlayer) {
					tex = Paths.getSparrowAtlas('characters/BOYFRIEND');
						frames = tex;
						boyfriendAnimation();

						loadOffsetFile(curCharacter);

						playAnim('idle');

						flipX = true;
						
						healthBarColor = "FF7bd6f6";
				}
				else {
					if(states.ModsFreeplayState.onMods){
						states.PlayState.SONG.player2 = curCharacter;
						var characterFile:CharacterData = loadFromJson(curCharacter);
						frames = ModPaths.getSparrowAtlas('mods/${ModsFreeplayState.mod}/images/Characters/' + characterFile.texture,states.ModsFreeplayState.mod);
						loadAnimations();
						loadOffsetFile(characterFile.char);
						healthBarColor = characterFile.healthBarColor;
					}
					else{
						tex = Paths.getSparrowAtlas('characters/week1/DADDY_DEAREST');
						frames = tex;
						animation.addByPrefix('idle', 'Dad idle dance', 24, false);
						animation.addByPrefix('singUP', 'Dad Sing Note UP', 24, false);
						animation.addByPrefix('singRIGHT', 'Dad Sing Note RIGHT', 24, false);
						animation.addByPrefix('singDOWN', 'Dad Sing Note DOWN', 24, false);
						animation.addByPrefix('singLEFT', 'Dad Sing Note LEFT', 24, false);

						loadOffsetFile(curCharacter);

						playAnim('idle');
						healthBarColor = "FFa5004d";
					}
				}
		}

		if(!healthBarColor.startsWith("#"))
			healthBarColor = "#" + healthBarColor;

		dance();

		if (isPlayer)
		{
			flipX = !flipX;

			// Doesn't flip for BF, since his are already in the right place???
			if (!curCharacter.startsWith('bf'))
			{
				// var animArray
				var oldRight = animation.getByName('singRIGHT').frames;
				animation.getByName('singRIGHT').frames = animation.getByName('singLEFT').frames;
				animation.getByName('singLEFT').frames = oldRight;

				// IF THEY HAVE MISS ANIMATIONS??
				if (animation.getByName('singRIGHTmiss') != null)
				{
					var oldMiss = animation.getByName('singRIGHTmiss').frames;
					animation.getByName('singRIGHTmiss').frames = animation.getByName('singLEFTmiss').frames;
					animation.getByName('singLEFTmiss').frames = oldMiss;
				}
			}
		}
	}

	public function loadOffsetFile(character:String)
	{
		if(!Assets.exists(Paths.txt('characters/offsets/' + character + "Offsets")) || ModsFreeplayState.onMods && !Assets.exists(ModPaths.getModTxt('characters/offsets/' + character + "Offsets", ModsFreeplayState.mod))){
			addOffset('idle');
			addOffset("singUP");
			addOffset("singRIGHT");
			addOffset("singLEFT");
			addOffset("singDOWN");
		}
		else{
			var offset:Array<String> = CoolUtil.coolTextFile(Paths.txt('characters/offsets/' + character + "Offsets"));
			if(states.ModsFreeplayState.onMods && states.ModsState.usableMods[states.ModsState.modsFolders.indexOf(ModsFreeplayState.mod)])
				offset = CoolUtil.coolTextFile(ModPaths.getModTxt('characters/offsets/' + character + "Offsets", ModsFreeplayState.mod));
	
			for (i in 0...offset.length)
			{
				var data:Array<String> = offset[i].split(' ');
				addOffset(data[0], Std.parseInt(data[1]), Std.parseInt(data[2]));
			}
		}
	}

	public static function loadFromJson(character:String):CharacterData
	{
		var rawJson = null;
		var jsonRawFile:String = ('assets/data/characters/$character.json');
		if(ModsFreeplayState.onMods && ModsState.usableMods[ModsState.modsFolders.indexOf(ModsFreeplayState.mod)] == true)
			jsonRawFile = ('mods/${ModsFreeplayState.mod}/data/characters/$character.json');

		trace(jsonRawFile);

		if(Assets.exists(jsonRawFile))
			rawJson = Assets.getText(jsonRawFile).trim();

		while (!rawJson.endsWith("}")){
			rawJson = rawJson.substr(0, rawJson.length - 1);
		}

		return (cast haxe.Json.parse(rawJson).character);
	}

	public function loadAnimations(){
		trace('Loading Anims');
		var characterFile:CharacterData = loadFromJson(curCharacter);
		var fuck:Array<String> = characterFile.anims;
		for(i in 0... fuck.length){
			var split = fuck[i].split(':');
			animation.addByPrefix(split[0],split[1],24,false);
			trace('Loaded Anim ' + split[0]);
		}
	}

	override function update(elapsed:Float)
	{
		if (!curCharacter.startsWith('bf'))
		{
			if (animation.curAnim.name.startsWith('sing'))
			{
				holdTimer += elapsed;
			}

			var dadVar:Float = 4;

			if (curCharacter == 'dad')
				dadVar = 6.1;
			if (holdTimer >= Conductor.stepCrochet * dadVar * 0.001)
			{
				dance();
				holdTimer = 0;
			}
		}

		switch (curCharacter)
		{
			case 'gf':
				if (animation.curAnim.name == 'hairFall' && animation.curAnim.finished)
					playAnim('danceRight');
		}

		super.update(elapsed);
	}

	private var danced:Bool = false;

	/**
	 * FOR GF DANCING SHIT
	 */
	public function dance()
	{
		if (!debugMode && !specialAnim)
		{
			switch (curCharacter)
			{
				case 'gf' | 'gf-car' | 'gf-pixel' | 'gf-christmas':
					if (!animation.curAnim.name.startsWith('hair'))
					{
						danced = !danced;

						if (danced)
							playAnim('danceRight');
						else
							playAnim('danceLeft');
					}

				case 'spooky':
					danced = !danced;

					if (danced)
						playAnim('danceRight');
					else
						playAnim('danceLeft');
				default:
					playAnim('idle',true);
			}
		}
	}

	public function playAnim(AnimName:String, Force:Bool = false, Reversed:Bool = false, Frame:Int = 0):Void
	{
		if (canSing && !specialAnim){
			animation.play(AnimName, Force, Reversed, Frame);

			var daOffset = animOffsets.get(AnimName);
			if (animOffsets.exists(AnimName))
			{
				offset.set(daOffset[0], daOffset[1]);
			}
			else
				offset.set(0, 0);
			
			if (!AnimName.startsWith("sing") && AnimName != 'idle'){
				canSing = true;
					animation.finishCallback = function(lol:String)
					{
						canSing = true;
					}
			}
	
			if (curCharacter == 'gf')
			{
				if (AnimName == 'singLEFT')
				{
					danced = true;
				}
				else if (AnimName == 'singRIGHT')
				{
					danced = false;
				}
	
				if (AnimName == 'singUP' || AnimName == 'singDOWN')
				{
					danced = !danced;
				}
			}
		}
	}

	public function boyfriendAnimation():Void {
	animation.addByPrefix('idle', 'BF idle dance', 24, false);
	animation.addByPrefix('singUP', 'BF NOTE UP0', 24, false);
	animation.addByPrefix('singLEFT', 'BF NOTE LEFT0', 24, false);
	animation.addByPrefix('singRIGHT', 'BF NOTE RIGHT0', 24, false);
	animation.addByPrefix('singDOWN', 'BF NOTE DOWN0', 24, false);
	animation.addByPrefix('singUPmiss', 'BF NOTE UP MISS', 24, false);
	animation.addByPrefix('singLEFTmiss', 'BF NOTE LEFT MISS', 24, false);
	animation.addByPrefix('singRIGHTmiss', 'BF NOTE RIGHT MISS', 24, false);
	animation.addByPrefix('singDOWNmiss', 'BF NOTE DOWN MISS', 24, false);
	animation.addByPrefix('hey', 'BF HEY', 24, false);

	animation.addByPrefix('scared', 'BF idle shaking', 24); }

	public function gilfriendAnimation():Void {
	animation.addByPrefix('cheer', 'GF Cheer', 24, false);
	animation.addByPrefix('singLEFT', 'GF left note', 24, false);
	animation.addByPrefix('singRIGHT', 'GF Right Note', 24, false);
	animation.addByPrefix('singUP', 'GF Up Note', 24, false);
	animation.addByPrefix('singDOWN', 'GF Down Note', 24, false);
	animation.addByIndices('sad', 'gf sad', [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], "", 24, false);
	animation.addByIndices('danceLeft', 'GF Dancing Beat', [30, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14], "", 24, false);
	animation.addByIndices('danceRight', 'GF Dancing Beat', [15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29], "", 24, false);
	animation.addByIndices('hairBlow', "GF Dancing Beat Hair blowing", [0, 1, 2, 3], "", 24);
	animation.addByIndices('hairFall', "GF Dancing Beat Hair Landing", [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], "", 24, false);
	animation.addByPrefix('scared', 'GF FEAR', 24); }

	public function addOffset(name:String, x:Float = 0, y:Float = 0)
	{
		animOffsets[name] = [x, y];
	}
}
