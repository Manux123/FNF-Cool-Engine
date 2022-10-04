package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import lime.app.Application;
import states.TitleState;
#if sys
import sys.FileSystem;
#end

class OutdatedState extends MusicBeatState
{
	public static var leftState:Bool = false;

	public static var daVersionNeeded:String = "";
	
    public static var daChangelogNeeded:String = "";
	
	function userName():String {
	
		var env = Sys.environment();
		if (!env.exists("USERNAME")) {
			return "Guest";
		}
		return env["USERNAME"];
	}

	override function create()
	{
		super.create();
		var bg:FlxSprite = new FlxSprite().loadGraphic("assets/images/menu/menuBGLoading");
		add(bg);
		var ver = Application.current.meta.get('version');
	    var txt:FlxText = new FlxText(0, 0, FlxG.width,
		"HEY! You're running an outdated version of the Cool Engine!\nYour current version is "
		+ ver
		+ " while the most recent version is "
		+ daVersionNeeded
		+ " here are the features youre missing on\n"
		+ daChangelogNeeded		      
		+ "\n Press Space to go the GitHub page, or ESCAPE to ignore this.",
		32);
		txt.setFormat("VCR OSD Mono", 32, FlxColor.WHITE, CENTER);
		txt.screenCenter();
		add(txt);

		var leDate = Date.now();
		if (leDate.getMonth() == 10 && leDate.getDay() == 31)
		{
			txt.text = "HEY!" + userName() + "You're running an outdated version of the Cool Engine!\nYour current version is "
			+ ver
			+ " while the most recent version is "
			+ daVersionNeeded
			+ " here are the features youre missing on\n"
			+ daChangelogNeeded		      
			+ "\n Press Space to go the GitHub page, or ESCAPE to ignore this.";
		}
	}

	override function update(elapsed:Float)
	{
		if (controls.ACCEPT)
		{
			FlxG.openURL("https://github.com/Manux123/FNF-Cool-Engine");
		}
		if (controls.BACK)
		{
			leftState = true;
			FlxG.switchState(new MainMenuState());
		}
		super.update(elapsed);
	}
}