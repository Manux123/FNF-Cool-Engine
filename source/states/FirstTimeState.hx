package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import lime.app.Application;

class FirstTimeState extends states.MusicBeatState
{
	public static var firstTime:Bool = true;

	override function create()
	{
		super.create();
		var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		add(bg);
	    var txt:FlxText = new FlxText(0, 0, FlxG.width,
		"HEY! I think this is your first time playing.\nDo you want to have all the weeks locked?\nYes -> Enter\nNo -> Escape",
		32);
		txt.setFormat("VCR OSD Mono", 32, FlxColor.WHITE, CENTER);
		txt.screenCenter();
		add(txt);
	}

	override function update(elapsed:Float)
	{
		if (controls.ACCEPT)
		{
            firstTime = false;
			FlxG.save.data.weekLocked = true;
            FlxG.switchState(new TitleState());
		}
		if (controls.BACK)
		{
			firstTime = false;
            FlxG.save.data.weekLocked = false;
			FlxG.switchState(new TitleState());
		}
		super.update(elapsed);
	}
}
