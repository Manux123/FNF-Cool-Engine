package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import lime.app.Application;

class Changelog extends states.MusicBeatState
{
	
  public static var daChangelogNeeded:String = "If i knew the lastest feature i'll say it, i promise";

	override function create()
	{
		super.create();
		var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		add(bg);
		var ver = Application.current.meta.get('version');
		var txt:FlxText = new FlxText(0, 0, FlxG.width,
			"Features: "
			+ daChangelogNeeded		      
			+ "Press backspace to return",
			32);
		txt.setFormat("VCR OSD Mono", 32, FlxColor.WHITE, CENTER);
		txt.screenCenter();
		add(txt);
	}
  	override function update(elapsed:Float)
	{
    
		if (controls.BACK)
		{
			leftState = true;
			FlxG.switchState(new MainMenuState());
		}
		super.update(elapsed);
	}
}
