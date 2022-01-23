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
	var doPush:Bool = false;
	inline public static var SOUND_EXT = #if web "mp3" #else "ogg" #end;

	static var currentLevel:String = Paths.currentLevel;
	public static var modsArray:Array<ModsState> = [];
	var exitState:FlxText;
	var warning:FlxText;

	var nameSongs:String = '';
	var modsFolder:String;
	var modsFolders:Array<String>;
	var grpMods:FlxTypedGroup<Alphabet>;

	override function create(){
		#if desktop
		DiscordClient.changePresence("In the Mods Menu", null);
		#end

		//THIS CRASH WHEN IS EMPTY :I
		modsFolder = modsRoot('modsList');
		modsFolders = CoolUtil.coolTextFile(modsFolder);

		grpMods = new FlxTypedGroup<Alphabet>();

		#if MOD_ALL
			var path:String = modsFolder;
			for(i in 0... modsFolders.length){
				if(#if sys FileSystem.exists(path)#else
					OpenflAssets.exists(path)#end) {
					path = ModPaths.getPreloadMod("",modsFolders[i]);
					doPush = true;
				} else {
					path = ModPaths.getModImage(path,modsFolders[i]);
					if(!#if sys FileSystem.exists(path)
						#else OpenflAssets.exists(path)#end) {
						doPush = false;
					}
				}
			}
		#end

		for(i in 0... modsFolders.length){
			var modText:Alphabet = new Alphabet(0,(i + 1) * 100, modsFolders[i],false,true);
			modText.isMenuItem = true;
			modText.targetY = i;
			modText.screenCenter(X);
			grpMods.add(modText);
		}

		var bg:FlxSprite = new FlxSprite(-80).loadGraphic(Bitmap.fromFile(Paths.image('menu/menuBGBlue')));
		bg.scrollFactor.x = 0;
		bg.scrollFactor.y = 0.18;
		bg.screenCenter();
		bg.antialiasing = true;
		add(bg);

		var	black:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		black.screenCenter(X);
		black.alpha = 0.7;
		add(black);

		add(grpMods);

		exitState = new FlxText(0, 0, 0, "ESC to exit", 12);
		exitState.size = 28;
		exitState.y += 35;
		exitState.scrollFactor.set();
		exitState.screenCenter(X);
		exitState.setFormat("VCR OSD Mono", 28, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(exitState);

		super.create();
	}

	override function update(elapsed:Float){
		#if MOD_ALL
		if(!doPush) {
			warning = new FlxText(0, 0, 0, "NO MODS IN THE MODS FOLDER", 36);
			warning.size = 36;
			warning.scrollFactor.set();
			warning.screenCenter(X);
			warning.setFormat("VCR OSD Mono", 36, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			add(warning);
			new FlxTimer().start(1, function (tmrr:FlxTimer){
			FlxTween.tween(warning, {alpha: 0}, 1, {type:PINGPONG});});
		} else {
			//warning.kill(); kill it when it not initialiced isn't very smart
		}
		#end

		if(controls.BACK) {
			FlxG.switchState(new MainMenuState());
			FlxG.camera.flash(FlxColor.WHITE); }
		
		super.update(elapsed);
	}
	function modsRoot(key:String, ?library:String){
		return ModPaths.lol('$key.txt',TEXT,null,library);
	}
}