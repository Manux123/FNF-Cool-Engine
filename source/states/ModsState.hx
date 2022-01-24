package states;

import flixel.group.FlxGroup.FlxTypedGroup;
import openfl.display.Sprite;
#if desktop
import Discord.DiscordClient;
#end
import flixel.text.FlxText;
import flixel.FlxSprite;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import states.MusicBeatState;
import flixel.FlxG;
import flixel.graphics.frames.FlxAtlasFrames;
import openfl.utils.AssetType;
import openfl.display.BitmapData as Bitmap;
import flixel.input.keyboard.FlxKey;
import flixel.util.FlxTimer;
import lime.utils.Assets;
#if sys
import sys.FileSystem;
#end
import openfl.utils.Assets as OpenflAssets;

using StringTools;

class ModsState extends states.MusicBeatState
{
	//DEJENLO COMO ARRAY NOMAS, NO LO CAMBIEN >:(
	public static var usableMods:Array<Bool> = [];
	public static var modsFolders:Array<String>;
	var exitState:FlxText;
	var warning:FlxText;

	var nameSongs:String = '';
	var grpMods:FlxTypedGroup<Alphabet>;

	override function create(){
		#if desktop
		DiscordClient.changePresence("In the Mods Menu", null);
		#end

		modsFolders = CoolUtil.coolTextFile("mods/modsList.txt");

		var bg:FlxSprite = new FlxSprite(-80).loadGraphic(Paths.image('menu/menuBGBlue'));
		bg.scrollFactor.x = 0;
		bg.scrollFactor.y = 0.18;
		bg.screenCenter();
		bg.antialiasing = true;
		add(bg);

		var	black:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		black.screenCenter(X);
		black.alpha = 0.7;
		add(black);

		exitState = new FlxText(0, 0, 0, "ESC to exit", 12);
		exitState.size = 28;
		exitState.y += 35;
		exitState.scrollFactor.set();
		exitState.screenCenter(X);
		exitState.setFormat("VCR OSD Mono", 28, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(exitState);

		//Clear all cuz this can cause errors :/
		while(usableMods.length > 0){
			usableMods.pop();
		}
		if(modsFolders.length != 0){
			grpMods = new FlxTypedGroup<Alphabet>();

			for(i in 0... modsFolders.length){
				if(usableMods.length == 0)
					usableMods.push(OpenflAssets.exists(ModPaths.getModPath(modsFolders[i]))?true:false);

				var modText:Alphabet = new Alphabet(0,(i + 1) * 100, modsFolders[i],false);
				modText.isMenuItem = true;
				modText.targetY = i;					
				modText.screenCenter(X);
				grpMods.add(modText);
				if(!usableMods[i])
					modText.changeText('${modsFolders[i]} (is not usable)');
			}
			add(grpMods);
		}
		else{
			var modText:Alphabet = new Alphabet(0, 1 * 100, 'The folder is empty',false);
			modText.isMenuItem = true;
			modText.targetY = 0;					
			modText.screenCenter(X);
			grpMods.add(modText);
			add(grpMods);
		}

		super.create();
	}

	override function update(elapsed:Float){
		#if MOD_ALL
		if(modsFolders.length == 0){
			warning = new FlxText(0, 0, 0, "NO MODS IN THE MODS FOLDER", 36);
			warning.size = 36;
			warning.scrollFactor.set();
			warning.screenCenter(X);
			warning.setFormat("VCR OSD Mono", 36, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			add(warning);
			new FlxTimer().start(1, function (tmrr:FlxTimer){
			FlxTween.tween(warning, {alpha: 0}, 1, {type:PINGPONG});});
		}
		#else
		LoadingState.loadAndSwitchState(new MainMenuState());
		FlxG.camera.flash(FlxColor.WHITE);
		#end

		if(controls.BACK) {
			LoadingState.loadAndSwitchState(new MainMenuState());
			FlxG.camera.flash(FlxColor.WHITE);
		}
		
		super.update(elapsed);
	}
}