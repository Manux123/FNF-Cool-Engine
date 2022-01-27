package states;

import flixel.text.FlxText;
import flixel.FlxSprite;
import flixel.util.FlxColor;
import states.MusicBeatState;
import flixel.FlxG;
import flixel.input.keyboard.FlxKey;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.addons.display.shapes.FlxShapeArrow;
import flixel.math.FlxPoint;

class UnloadModState extends states.MusicBeatSubstate
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

		areYouSure.setFormat(Paths.font("Funkin.otf"), 36, FlxColor.WHITE, FlxTextAlign.CENTER);
		areYouSure.text = "It seems like you already have a mod running\nDo you want to unload it and load a new one?";
		areYouSure.y = 176;
		areYouSure.screenCenter(X);
		add(areYouSure);

		theText.push(ye);
		theText.push(NO);
		ye.text = "Yes";
		NO.text = "No";

		for (i in 0...theText.length)
		{
			theText[i].setFormat(Paths.font("Funkin.otf"), 24, FlxColor.WHITE, FlxTextAlign.CENTER);
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

		if (FlxG.keys.justPressed.ENTER && !wasPressed)
		{
			wasPressed = true;
			switch (selected)
			{
				case 0:
					FlxG.switchState(new ModsState());
					ModsFreeplayState.onMods = false;
				case 1:
					FlxG.switchState(new MainMenuState());
					ModsFreeplayState.onMods = true;
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