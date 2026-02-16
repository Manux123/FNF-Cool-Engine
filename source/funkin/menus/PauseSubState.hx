package funkin.menus;

import funkin.gameplay.controls.Controls.Control;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.addons.transition.FlxTransitionableState;
import funkin.transitions.StickerTransition;
import flixel.group.FlxGroup.FlxTypedGroup;
import funkin.gameplay.GameState;
import flixel.input.keyboard.FlxKey;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import funkin.scripting.StateScriptHandler;
import flixel.tweens.FlxEase;
import funkin.gameplay.PlayState;
import extensions.CoolUtil;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import ui.Alphabet;

class PauseSubState extends funkin.states.MusicBeatSubstate
{
	var grpMenuShit:FlxTypedGroup<Alphabet>;
	var menuItems:Array<String> = ['Resume', 'Restart Song', 'Options', 'Exit to menu'];
	var curSelected:Int = 0;

	var pauseMusic:FlxSound;

	// Visual enhancements
	var bg:FlxSprite;
	var levelInfo:FlxText;
	var levelDifficulty:FlxText;
	var levelDeaths:FlxText;
	var levelAuthor:FlxText;

	public function new()
	{
		super();

		#if HSCRIPT_ALLOWED
		StateScriptHandler.init();
		StateScriptHandler.loadStateScripts('PauseSubState', this);
		StateScriptHandler.callOnScripts('onCreate', []);
		#end

		if (PlayState.storyPlaylist.length > 1 && PlayState.isStoryMode)
		{
			menuItems.insert(2, "Skip Song");
		}

		pauseMusic = new FlxSound().loadEmbedded(Paths.music('breakfast'), true, true);
		pauseMusic.volume = 0;
		pauseMusic.play(false, FlxG.random.int(0, Std.int(pauseMusic.length / 2)));

		FlxG.sound.list.add(pauseMusic);

		// Background with gradient effect
		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0;
		bg.scrollFactor.set();
		add(bg);

		// Song info with better styling
		levelInfo = new FlxText(FlxG.width - 400, 20, 380, "", 32);
		levelInfo.text = PlayState.SONG.song;
		levelInfo.scrollFactor.set();
		levelInfo.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, RIGHT, OUTLINE, FlxColor.BLACK);
		levelInfo.borderSize = 2;
		levelInfo.updateHitbox();
		add(levelInfo);

		levelDifficulty = new FlxText(FlxG.width - 400, 60, 380, "", 24);
		levelDifficulty.text = "Difficulty: " + CoolUtil.difficultyString();
		levelDifficulty.scrollFactor.set();
		levelDifficulty.setFormat(Paths.font('vcr.ttf'), 24, FlxColor.WHITE, RIGHT, OUTLINE, FlxColor.BLACK);
		levelDifficulty.borderSize = 1.5;
		levelDifficulty.updateHitbox();
		add(levelDifficulty);

		// Death counter
		levelDeaths = new FlxText(FlxG.width - 400, 95, 380, "", 20);
		levelDeaths.text = "Deaths: " + GameState.deathCounter;
		levelDeaths.scrollFactor.set();
		levelDeaths.setFormat(Paths.font('vcr.ttf'), 20, FlxColor.WHITE, RIGHT, OUTLINE, FlxColor.BLACK);
		levelDeaths.borderSize = 1.5;
		add(levelDeaths);

		// Accuracy display
		levelAuthor = new FlxText(FlxG.width - 400, 125, 380, "", 20);
		levelAuthor.text = "Author: " + GameState.listAuthor;
		levelAuthor.scrollFactor.set();
		levelAuthor.setFormat(Paths.font('vcr.ttf'), 20, FlxColor.WHITE, RIGHT, OUTLINE, FlxColor.BLACK);
		levelAuthor.borderSize = 1.5;
		add(levelAuthor);

		// Initial alpha
		levelDifficulty.alpha = 0;
		levelInfo.alpha = 0;
		levelDeaths.alpha = 0;
		levelAuthor.alpha = 0;

		// Tween animations
		FlxTween.tween(bg, {alpha: 0.7}, 0.4, {ease: FlxEase.quartInOut});
		FlxTween.tween(levelInfo, {alpha: 1, x: levelInfo.x + 10}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.3});
		FlxTween.tween(levelDifficulty, {alpha: 1, x: levelDifficulty.x + 10}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.4});
		FlxTween.tween(levelDeaths, {alpha: 1, x: levelDeaths.x + 10}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.5});
		FlxTween.tween(levelAuthor, {alpha: 1, x: levelAuthor.x + 10}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.6});

		// Menu items
		grpMenuShit = new FlxTypedGroup<Alphabet>();
		add(grpMenuShit);

		for (i in 0...menuItems.length)
		{
			var songText:Alphabet = new Alphabet(0, (70 * i) + 30, menuItems[i], true, false);
			songText.isMenuItem = true;
			songText.targetY = i;
			songText.alpha = 0;
			grpMenuShit.add(songText);

			// Stagger the menu items animation
			FlxTween.tween(songText, {alpha: 0.6}, 0.3, {
				ease: FlxEase.quartOut,
				startDelay: 0.3 + (i * 0.05)
			});
		}

		changeSelection();

		cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];

		// Help text at bottom
		var helpText:FlxText = new FlxText(20, FlxG.height - 40, FlxG.width - 40, "ENTER: Select  |  ARROWS: Navigate  |  ESC: Resume", 16);
		helpText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.GRAY, CENTER, OUTLINE, FlxColor.BLACK);
		helpText.scrollFactor.set();
		helpText.alpha = 0;
		add(helpText);

		FlxTween.tween(helpText, {alpha: 0.7}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.7});
	}

	override function update(elapsed:Float)
	{
		#if HSCRIPT_ALLOWED
		StateScriptHandler.callOnScripts('onUpdate', [elapsed]);
		#end

		if (pauseMusic.volume < 0.5)
			pauseMusic.volume += 0.01 * elapsed;

		super.update(elapsed);

		var upP = controls.UP_P;
		var downP = controls.DOWN_P;
		var accepted = controls.ACCEPT;

		if (upP)
		{
			changeSelection(-1);
		}
		if (downP)
		{
			changeSelection(1);
		}

		// ESC to resume
		if (FlxG.keys.justPressed.ESCAPE || controls.BACK)
		{
			close();
			FlxG.sound.resume();
			if (PlayState.instance != null)
				PlayState.instance.paused = false;
		}

		if (accepted)
		{
			var daSelected:String = menuItems[curSelected];

			#if HSCRIPT_ALLOWED
			StateScriptHandler.callOnScripts('onMenuItemSelected', [menuItems[curSelected], curSelected]);
			#end

			switch (daSelected)
			{
				case "Resume":
					close();
					FlxG.sound.resume();
					if (PlayState.instance != null)
						PlayState.instance.paused = false;
				case "Restart Song":
					FlxG.resetState();
				case "Skip Song":
					if (PlayState.instance != null)
						PlayState.instance.endSong();
				case "Options":
					OptionsMenuState.fromPause = true;
					openSubState(new OptionsMenuState());
				case "Exit to menu":
					PlayState.isPlaying = false;
					if (PlayState.isStoryMode){
						StickerTransition.start(function() {
							FlxG.switchState(new StoryMenuState());
						});
					}
					else{
						StickerTransition.start(function() {
							FlxG.switchState(new FreeplayState());
						});
					}
			}
		}

		#if HSCRIPT_ALLOWED
		StateScriptHandler.callOnScripts('onUpdatePost', [elapsed]);
		#end
	}

	override function destroy()
	{
		pauseMusic.destroy();
		#if HSCRIPT_ALLOWED
		StateScriptHandler.callOnScripts('onDestroy', []);
		StateScriptHandler.clearStateScripts();
		#end
		super.destroy();
	}

	function changeSelection(change:Int = 0):Void
	{
		FlxG.sound.play(Paths.sound('menus/scrollMenu'), 0.4);
		
		curSelected += change;

		if (curSelected < 0)
			curSelected = menuItems.length - 1;
		if (curSelected >= menuItems.length)
			curSelected = 0;

		var bullShit:Int = 0;

		for (item in grpMenuShit.members)
		{
			item.targetY = bullShit - curSelected;
			bullShit++;

			item.alpha = 0.6;

			if (item.targetY == 0)
			{
				item.alpha = 1;
				// Scale effect on selected item
				FlxTween.cancelTweensOf(item.scale);
				FlxTween.tween(item.scale, {x: 1.1, y: 1.1}, 0.1, {ease: FlxEase.quadOut});
			}
			else
			{
				FlxTween.cancelTweensOf(item.scale);
				FlxTween.tween(item.scale, {x: 1, y: 1}, 0.1, {ease: FlxEase.quadOut});
			}
		}

		#if HSCRIPT_ALLOWED
		StateScriptHandler.callOnScripts('onSelectionChanged', [curSelected]);
		#end
	}
}
