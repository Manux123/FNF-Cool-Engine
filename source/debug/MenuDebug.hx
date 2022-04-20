/*package debug;

import states.MusicBeatState;
import flixel.group.FlxGroup.FlxTypedGroup;
import lime.utils.Assets;
import flixel.ui.FlxButton;
import flixel.util.*;
import flixel.tweens.*;
import flixel.*;

using StringTools;

class MenuDebug extends MusicBeatState
{
	var bg:FlxSprite;
	var daMenuButton:FlxButton;
	var dabuttonstage:FlxButton;
	var ola:FlxButton;

	override public function create() 
	{
		FlxG.mouse.visible = true;
		if (FlxG.sound.music != null)
			FlxG.sound.music.stop();
		FlxG.sound.playMusic(Paths.music('configurator'));

		bg = new FlxSprite().loadGraphic(Paths.image('menu/menuDesat'));
		bg.color = 0xFFaa00ff;
		//add(bg);

		daMenuButton = new FlxButton(250, 450, "Menu Characters", clickNose);
		//daMenuButton.loadGraphic(Paths.image('UI/button', 'shared'));
		//daMenuButton.color = 0xFFad217F;
		//daMenuButton.scale.set(0, 0.5);
		daMenuButton.updateHitbox();
		add(daMenuButton);

		dabuttonstage = new FlxButton(650, 450, "Stage Debug", clickStage);
		//daMenuButton.loadGraphic(Paths.image('UI/button', 'shared'));
		//daMenuButton.color = 0xFFad217F;
		//dabuttonstage.scale.set(0, 0.5);
		dabuttonstage.updateHitbox();
		add(dabuttonstage);

		super.create();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
	}

	private function clickNose(){
		FlxTween.tween(daMenuButton, {"x": -1000}, 1, {ease: FlxEase.elasticInOut});
		new FlxTimer().start(1, function(tmr:FlxTimer)
			FlxG.switchState(new SelectCharacters()));
	}

	private function clickStage(){
		FlxTween.tween(dabuttonstage, {"x": -1000}, 1, {ease: FlxEase.elasticInOut});
		new FlxTimer().start(1, function(tmr:FlxTimer)
			FlxG.switchState(new StageDebug()));
	}
}

class SelectCharacters extends MusicBeatState
{
	var nose:FlxButton;
	var ola:FlxButton;

	override public function create() 
	{
		FlxG.mouse.visible = true;
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
*/ // forgor dis
