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
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.addons.display.shapes.FlxShapeArrow;
import flixel.math.FlxPoint;
#if sys
import sys.FileSystem;
#end
import openfl.utils.Assets as OpenflAssets;

using StringTools;

class ModsState extends states.MusicBeatState
{
	//DEJENLO COMO ARRAY NOMAS, NO LO CAMBIEN >:(
	public static var usableMods:Array<Bool>;
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

		usableMods = [];//Clear all cuz this can cause errors :/
		
		#if MOD_ALL
		if(modsFolders.length != 0 || modsFolders != []){
			grpMods = new FlxTypedGroup<Alphabet>();

			for(i in 0... modsFolders.length){
				if(usableMods.length == 0 || usableMods == [])
					usableMods.push(OpenflAssets.exists(ModPaths.getModCool(modsFolders[i])));

				var modText:Alphabet = new Alphabet(0,(i + 1) * 100, modsFolders[i],false);
				modText.isMenuItem = true;
				modText.targetY = i;					
				modText.screenCenter(X);
				grpMods.add(modText);
				if(!usableMods[i])
					modText.changeText('${modsFolders[i]} (is not usable)');
			}
		}
		else{
			var modText:FlxText = new FlxText(0, 1 * 100, 'The folder is empty',false);
			modText.screenCenter(X);
			add(modText);
		}
		add(grpMods);
		#end

		super.create();
	}

	var curSelected:Int = 0;
	override function update(elapsed:Float){
		#if MOD_ALL
		if(modsFolders.length == 0 || modsFolders == []){
			warning = new FlxText(0, 0, 0, "NO MODS IN THE MODS FOLDER", 36);
			warning.size = 36;
			warning.scrollFactor.set();
			warning.screenCenter(X);
			warning.setFormat("VCR OSD Mono", 36, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			add(warning);
			new FlxTimer().start(1, function (tmrr:FlxTimer){
			FlxTween.tween(warning, {alpha: 0}, 1, {type:PINGPONG});});
		}

		if(controls.BACK) {
			LoadingState.loadAndSwitchState(new MainMenuState());
			FlxG.camera.flash(FlxColor.WHITE);
		}
		if(modsFolders.length != 0 || modsFolders != []) 
			if(controls.ACCEPT && usableMods[curSelected]){
				openSubState(new USure());
				ModsFreeplayState.mod = modsFolders[curSelected];
			}
		#else
		LoadingState.loadAndSwitchState(new MainMenuState());
		#end
		super.update(elapsed);
	}

	private function changeSelection(change:Int):Void{
		
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		curSelected+=change;
		if (curSelected < 0)
			curSelected = modsFolders.length - 1;
		if (curSelected >= modsFolders.length)
			curSelected = 0;

		var bullShit:Int = 0;

		for (item in grpMods.members)
		{
			item.targetY = bullShit - curSelected;
			bullShit++;

			item.alpha = 0.6;

			if (item.targetY == 0)
			{
				item.alpha = 1;
			}
		}
	}
}

class USure extends states.MusicBeatSubstate
{
	var wasPressed:Bool = false;
	var areYouSure:FlxText = new FlxText();
	var ye:FlxText = new FlxText();
	var NO:FlxText = new FlxText();
	var marker:FlxShapeArrow;

	var theText:Array<FlxText> = [];
	var selected:Int = 0;

	var blackBox:FlxSprite;

	override function create()
	{
		super.create();

		blackBox = new FlxSprite(0,0).makeGraphic(FlxG.width,FlxG.height,FlxColor.BLACK);
        add(blackBox);

		marker = new FlxShapeArrow(0, 0, FlxPoint.weak(0, 0), FlxPoint.weak(0, 1), 24, {color: FlxColor.WHITE});

		areYouSure.setFormat(null, 176, FlxColor.WHITE, FlxTextAlign.CENTER);
		areYouSure.text = "Are you sure you want to load this mod?";
		areYouSure.y = 1;
		areYouSure.screenCenter(X);
		add(areYouSure);

		theText.push(ye);
		theText.push(NO);
		ye.text = "Yes";
		NO.text = "No";

		for (i in 0...theText.length)
		{
			theText[i].setFormat(null, 24, FlxColor.WHITE, FlxTextAlign.CENTER);
			theText[i].screenCenter(Y);
			theText[i].x = (i * FlxG.width / theText.length + FlxG.width / theText.length / 2) - theText[i].width / 2;
			add(theText[i]);
		}

		add(marker);

		blackBox.alpha = 0;
		ye.alpha = 0;
		NO.alpha = 0;
		areYouSure.alpha = 0;
		FlxTween.tween(blackBox, {alpha: 0.7}, 1, {ease: FlxEase.expoInOut});
		FlxTween.tween(ye, {alpha: 1}, 1, {ease: FlxEase.expoInOut});
		FlxTween.tween(NO, {alpha: 1}, 1, {ease: FlxEase.expoInOut});
		FlxTween.tween(areYouSure, {alpha: 1}, 1, {ease: FlxEase.expoInOut});
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		/*Debug.quickWatch(areYouSure, 'x');
		Debug.quickWatch(areYouSure, 'y');*/

		if (FlxG.keys.justPressed.ENTER && !wasPressed)
		{
			wasPressed = true;
			switch (selected)
			{
				case 0:
					FlxG.switchState(new ModsFreeplayState());
				case 1:
					FlxG.switchState(new MainMenuState());
			}
		}

		if (FlxG.keys.justPressed.LEFT)
		{
			changeSelection(-1);
		}

		if (FlxG.keys.justPressed.RIGHT)
		{
			changeSelection(1);
		}

		marker.x = theText[selected].x + theText[selected].width / 2 - marker.width / 2;
		marker.y = theText[selected].y - marker.height - 5;
	}

	function changeSelection(direction:Int = 0)
	{
		if (wasPressed)
			return;

		selected = selected + direction;
		if (selected < 0)
			selected = theText.length - 1;
		else if (selected >= theText.length)
			selected = 0;
	}
}