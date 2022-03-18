package debug;

import states.MusicBeatState;
import lime.utils.Assets;
import flixel.ui.FlxButton;
import flixel.util.*;
import flixel.tweens.*;
import flixel.*;

using StringTools;

class MenuDebug extends MusicBeatState
{
	var nose:FlxButton;
	var ola:FlxButton;

	override public function create() 
	{
		FlxG.mouse.visible = true;
		if (FlxG.sound.music != null)
			FlxG.sound.music.stop();
		nose = new FlxButton(450, 450, "Menu Characters", clickNose);
		nose.scale.set(1.8, 1.8);
		add(nose);

		super.create();
	}

	private function clickNose(){
		FlxTween.tween(nose, {"x": -1000}, 1, {ease: FlxEase.elasticInOut});
		new FlxTimer().start(1, function(tmr:FlxTimer)
			FlxG.switchState(new SelectCharacters()));
	}
}

class SelectCharacters extends MusicBeatState
{
	var nose:FlxButton;
	var ola:FlxButton;

	override public function create() 
	{
		FlxG.mouse.visible = true;
		if (FlxG.sound.music != null)
			FlxG.sound.music.stop();
		nose = new FlxButton(100, 450, "Boyfriend", clickNose);
		nose.scale.set(1.8, 1.8);
		add(nose);

		ola = new FlxButton(400, 450, "Opponent", clickOla);
		ola.scale.set(1.8, 1.8);
		add(ola);

		super.create();
	}

	private function clickNose(){
		FlxTween.tween(nose, {"x": -1000}, 1, {ease: FlxEase.elasticInOut});
		new FlxTimer().start(1, function(tmr:FlxTimer)
			FlxG.switchState(new states.AnimationDebug(states.PlayState.SONG.player1)));
	}

	private function clickOla(){
		FlxTween.tween(ola, {"x": -1000}, 1, {ease: FlxEase.elasticInOut});
		new FlxTimer().start(1, function(tmr:FlxTimer)
			FlxG.switchState(new states.AnimationDebug(states.PlayState.SONG.player2)));
	}
}
