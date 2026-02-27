package funkin.states;

import flixel.FlxG;
import flixel.FlxObject;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import funkin.gameplay.PlayState;
import funkin.menus.StoryMenuState;
import funkin.menus.FreeplayState;
import funkin.states.LoadingState;
import funkin.data.Conductor;
import funkin.gameplay.objects.character.Character;
import funkin.transitions.StateTransition;
import funkin.scripting.StateScriptHandler;

using StringTools;

/**
* GameOverSubstate: coded from CharacterData, programmable using StateScriptHandler.

* Scripts in: assets/states/gameoversubstate/{script}.hx (same as any other state)
*
* Optional fields in the character's JSON:
 *   "charDeath":        "bf-dead"              (default)
 *   "gameOverSound":    "fnf_loss_sfx"         (default)
 *   "gameOverMusic":    "gameplay/gameOver"     (default)
 *   "gameOverEnd":      "gameplay/gameOverEnd"  (default)
 *   "gameOverBpm":      100                     (default)
 *   "gameOverCamFrame": 12                      (default)
 */

class GameOverSubstate extends MusicBeatSubstate
{
	public var bf:Character;
	public var camFollow:FlxObject;
	public var isEnding:Bool = false;

	var _loopMusic : String;
	var _endSound  : String;
	var _camFrame  : Int;

	public function new(x:Float, y:Float, boyfriend:Character)
	{
		super();

		if (PlayState.instance?.vocals?.playing ?? false)
			PlayState.instance.vocals.stop();

		final cd = boyfriend.characterData;

		// Read values ​​from CharacterData (all with defaults)
		final deathChar = (cd?.charDeath != null && cd.charDeath != '') ? cd.charDeath : 'bf-dead';
		final deathSound = cd?.gameOverSound    ?? 'fnf_loss_sfx';
		_loopMusic        = cd?.gameOverMusic   ?? 'gameplay/gameOver';
		_endSound         = cd?.gameOverEnd     ?? 'gameplay/gameOverEnd';
		_camFrame         = cd?.gameOverCamFrame ?? 12;
		final bpm         = cd?.gameOverBpm     ?? 100;

		Conductor.songPosition = 0;
		Conductor.changeBPM(bpm);

		bf = new Character(x, y, deathChar, true);
		add(bf);

		camFollow = new FlxObject(bf.getGraphicMidpoint().x, bf.getGraphicMidpoint().y, 1, 1);
		add(camFollow);

		FlxG.camera.scroll.set();
		FlxG.camera.target = null;

		FlxG.sound.play(Paths.sound(deathSound));
		bf.playAnim('firstDeath');

		// Load scripts just like any state (assets/states/gameoversubstate/)
		StateScriptHandler.init();
		StateScriptHandler.loadStateScripts('GameOverSubstate', this, [
			'bf'        => bf,
			'camFollow' => camFollow,
			'isEnding'  => false,
		]);
		StateScriptHandler.callOnScripts('onCreate', [this]);

		#if mobileC
		addVirtualPad(NONE, A_B);
		#end
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		StateScriptHandler.fireRaw('onUpdate', [elapsed]);

		if (controls.ACCEPT && !isEnding)
			if (!StateScriptHandler.callOnScripts('onRetry', [])) endBullshit();

		if (controls.BACK)
		{
			if (!StateScriptHandler.callOnScripts('onBack', []))
			{
				FlxG.sound.music?.stop();
				if (PlayState.isStoryMode)
					StateTransition.switchState(new StoryMenuState());
				else
					StateTransition.switchState(new FreeplayState());
			}
		}

		if (bf.animation.curAnim?.name == 'firstDeath')
		{
			if (bf.animation.curAnim.curFrame == _camFrame)
				FlxG.camera.follow(camFollow, LOCKON, 0.01);

			if (bf.animation.curAnim.finished)
			{
				StateScriptHandler.fireRaw('onDeathAnimFinished', []);
				if (FlxG.sound.music == null || !FlxG.sound.music.playing)
					FlxG.sound.playMusic(Paths.music(_loopMusic));
			}
		}

		if (FlxG.sound.music?.playing ?? false)
			Conductor.songPosition = FlxG.sound.music.time;
	}

	override function beatHit()
	{
		super.beatHit();
		StateScriptHandler.fireRaw('onBeatHit', [curBeat]);
	}

	public function endBullshit():Void
	{
		if (isEnding) return;
		isEnding = true;

		if (StateScriptHandler.callOnScripts('onEndConfirm', [])) { isEnding = false; return; }

		bf.playAnim('deathConfirm', true);
		FlxG.sound.music?.stop();
		FlxG.sound.play(Paths.music(_endSound));

		new FlxTimer().start(0.7, function(_)
		{
			FlxG.camera.fade(FlxColor.BLACK, 2, false, function()
			{
				LoadingState.loadAndSwitchState(new PlayState());
			});
		});
	}

	override function destroy()
	{
		StateScriptHandler.callOnScripts('onDestroy', []);
		StateScriptHandler.clearStateScripts();
		super.destroy();
	}
}
