package funkin.states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import lime.app.Application;
import funkin.menus.MainMenuState;
import funkin.transitions.StateTransition;

class OutdatedSubState extends funkin.states.MusicBeatState
{
	public static var leftState:Bool = false;

	public static var daVersionNeeded:String = "If i knew the lastest version i'll say it, i promise";
	
    public static var daChangelogNeeded:String = "If i knew the lastests features i'll say it, i promise";

	override function create()
	{
		super.create();
		var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
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
			StateTransition.switchState(new MainMenuState());
		}
		super.update(elapsed);
	}
}
