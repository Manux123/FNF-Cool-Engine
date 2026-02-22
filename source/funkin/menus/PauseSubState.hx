package funkin.menus;

import funkin.gameplay.controls.Controls.Control;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxSubState;
import funkin.transitions.StickerTransition;
import flixel.group.FlxGroup.FlxTypedGroup;
import funkin.gameplay.GameState;
import flixel.input.keyboard.FlxKey;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import funkin.scripting.StateScriptHandler;
import funkin.transitions.StateTransition;
import flixel.tweens.FlxEase;
import funkin.gameplay.PlayState;
import funkin.data.CoolUtil;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import ui.Alphabet;

class PauseSubState extends funkin.states.MusicBeatSubstate
{
	var grpMenuShit:FlxTypedGroup<Alphabet>;
	var menuItems:Array<String> = ['Resume', 'Restart Song', 'Options', 'Exit to menu'];
	var curSelected:Int = 0;

	var pauseMusic:FlxSound;

	// Visual elements
	var bg:FlxSprite;
	var levelInfo:FlxText;
	var levelDifficulty:FlxText;
	var levelDeaths:FlxText;
	var levelAuthor:FlxText;
	var helpText:FlxText;

	// Camera usado por este substate — determinado al inicio.
	var _pauseCam:flixel.FlxCamera;

	public function new()
	{
		super();

		// ── CRÍTICO: determinar la cámara ANTES de crear cualquier sprite.
		// Se asigna cameras=[_pauseCam] en el substate Y en cada sprite individual.
		// Esto evita que los sprites rendericen en la cámara equivocada (crash de
		// renderizado en 2ª apertura cuando la cámara por defecto cambia de estado).
		_pauseCam = FlxG.cameras.list[FlxG.cameras.list.length - 1];
		cameras = [_pauseCam];

		#if HSCRIPT_ALLOWED
		StateScriptHandler.init();
		StateScriptHandler.loadStateScripts('PauseSubState', this);
		StateScriptHandler.callOnScripts('onCreate', []);
		#end

		if (PlayState.storyPlaylist.length > 1 && PlayState.isStoryMode)
			menuItems.insert(2, "Skip Song");

		// ── Limpiar entradas muertas del sound list ──────────────────────────
		_cleanSoundList();

		// ── Música de pausa ──────────────────────────────────────────────────
		pauseMusic = new FlxSound().loadEmbedded(Paths.music('breakfast'), true, true);
		pauseMusic.volume = 0;
		pauseMusic.play(false, FlxG.random.int(0, Std.int(pauseMusic.length / 2)));
		FlxG.sound.list.add(pauseMusic);

		// ── Fondo (1×1 pixel escalado: evita alojar ~8 MB por bitmap 1920×1080) ──
		bg = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		bg.setGraphicSize(FlxG.width, FlxG.height);
		bg.updateHitbox();
		bg.alpha = 0;
		bg.scrollFactor.set();
		bg.cameras = [_pauseCam];
		add(bg);

		// ── Info de canción ────────────────────────────────────────────────────
		levelInfo = new FlxText(FlxG.width - 400, 20, 380, PlayState.SONG.song, 32);
		levelInfo.scrollFactor.set();
		levelInfo.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, RIGHT, OUTLINE, FlxColor.BLACK);
		levelInfo.borderSize = 2;
		levelInfo.updateHitbox();
		levelInfo.alpha = 0;
		levelInfo.cameras = [_pauseCam];
		add(levelInfo);

		levelDifficulty = new FlxText(FlxG.width - 400, 60, 380, "Difficulty: " + CoolUtil.difficultyString(), 24);
		levelDifficulty.scrollFactor.set();
		levelDifficulty.setFormat(Paths.font('vcr.ttf'), 24, FlxColor.WHITE, RIGHT, OUTLINE, FlxColor.BLACK);
		levelDifficulty.borderSize = 1.5;
		levelDifficulty.updateHitbox();
		levelDifficulty.alpha = 0;
		levelDifficulty.cameras = [_pauseCam];
		add(levelDifficulty);

		levelDeaths = new FlxText(FlxG.width - 400, 95, 380, "Deaths: " + GameState.deathCounter, 20);
		levelDeaths.scrollFactor.set();
		levelDeaths.setFormat(Paths.font('vcr.ttf'), 20, FlxColor.WHITE, RIGHT, OUTLINE, FlxColor.BLACK);
		levelDeaths.borderSize = 1.5;
		levelDeaths.alpha = 0;
		levelDeaths.cameras = [_pauseCam];
		add(levelDeaths);

		levelAuthor = new FlxText(FlxG.width - 400, 125, 380, "Author: " + GameState.listAuthor, 20);
		levelAuthor.scrollFactor.set();
		levelAuthor.setFormat(Paths.font('vcr.ttf'), 20, FlxColor.WHITE, RIGHT, OUTLINE, FlxColor.BLACK);
		levelAuthor.borderSize = 1.5;
		levelAuthor.alpha = 0;
		levelAuthor.cameras = [_pauseCam];
		add(levelAuthor);

		// ── Tweens de entrada ──────────────────────────────────────────────────
		FlxTween.tween(bg,              {alpha: 0.7},                          0.4, {ease: FlxEase.quartInOut});
		FlxTween.tween(levelInfo,       {alpha: 1, x: levelInfo.x + 10},       0.4, {ease: FlxEase.quartInOut, startDelay: 0.3});
		FlxTween.tween(levelDifficulty, {alpha: 1, x: levelDifficulty.x + 10}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.4});
		FlxTween.tween(levelDeaths,     {alpha: 1, x: levelDeaths.x + 10},     0.4, {ease: FlxEase.quartInOut, startDelay: 0.5});
		FlxTween.tween(levelAuthor,     {alpha: 1, x: levelAuthor.x + 10},     0.4, {ease: FlxEase.quartInOut, startDelay: 0.6});

		// ── Ítems del menú ──────────────────────────────────────────────────────
		grpMenuShit = new FlxTypedGroup<Alphabet>();
		grpMenuShit.cameras = [_pauseCam];
		add(grpMenuShit);

		for (i in 0...menuItems.length)
		{
			var songText:Alphabet = new Alphabet(0, (70 * i) + 30, menuItems[i], true, false);
			songText.isMenuItem = true;
			songText.targetY = i;
			songText.alpha = 0;
			grpMenuShit.add(songText);

			FlxTween.tween(songText, {alpha: 0.6}, 0.3, {
				ease: FlxEase.quartOut,
				startDelay: 0.3 + (i * 0.05)
			});
		}

		changeSelection(0, true);

		// ── Texto de ayuda ─────────────────────────────────────────────────────
		helpText = new FlxText(20, FlxG.height - 40, FlxG.width - 40,
			"ENTER: Select  |  ARROWS: Navigate  |  ESC: Resume", 16);
		helpText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.GRAY, CENTER, OUTLINE, FlxColor.BLACK);
		helpText.scrollFactor.set();
		helpText.alpha = 0;
		helpText.cameras = [_pauseCam];
		add(helpText);

		FlxTween.tween(helpText, {alpha: 0.7}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.7});
	}

	override function update(elapsed:Float)
	{
		#if HSCRIPT_ALLOWED
		StateScriptHandler.callOnScripts('onUpdate', [elapsed]);
		#end

		if (pauseMusic != null && pauseMusic.volume < 0.5)
			pauseMusic.volume += 0.01 * elapsed;

		super.update(elapsed);

		if (controls.UP_P)   changeSelection(-1);
		if (controls.DOWN_P) changeSelection(1);

		if (FlxG.keys.justPressed.ESCAPE || controls.BACK)
		{
			close();
			FlxG.sound.resume();
			if (PlayState.instance != null)
				PlayState.instance.paused = false;
		}

		if (controls.ACCEPT)
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
					if (PlayState.isStoryMode)
						StickerTransition.start(() -> StateTransition.switchState(new StoryMenuState()));
					else
						StickerTransition.start(() -> StateTransition.switchState(new FreeplayState()));
			}
		}

		#if HSCRIPT_ALLOWED
		StateScriptHandler.callOnScripts('onUpdatePost', [elapsed]);
		#end
	}

	override function destroy()
	{
		// ── 1. Cancelar todos los tweens sobre elementos visuales ANTES de que
		//       super.destroy() libere los objetos subyacentes. Un tween activo
		//       sobre un objeto ya destruido escribe en memoria libre → crash en
		//       la 2ª apertura del pause menu.
		if (bg != null)             { FlxTween.cancelTweensOf(bg);             bg = null; }
		if (levelInfo != null)      { FlxTween.cancelTweensOf(levelInfo);      levelInfo = null; }
		if (levelDifficulty != null){ FlxTween.cancelTweensOf(levelDifficulty); levelDifficulty = null; }
		if (levelDeaths != null)    { FlxTween.cancelTweensOf(levelDeaths);    levelDeaths = null; }
		if (levelAuthor != null)    { FlxTween.cancelTweensOf(levelAuthor);    levelAuthor = null; }
		if (helpText != null)       { FlxTween.cancelTweensOf(helpText);       helpText = null; }

		if (grpMenuShit != null)
		{
			for (item in grpMenuShit.members)
			{
				if (item != null)
				{
					FlxTween.cancelTweensOf(item);
					FlxTween.cancelTweensOf(item.scale);
				}
			}
			grpMenuShit = null;
		}

		// ── 2. Destruir la música de pausa: sacar de FlxG.sound.list ANTES
		//       de llamar destroy() para que FlxG.sound.resume() de las capas
		//       superiores no opera sobre un sonido ya destruido.
		if (pauseMusic != null)
		{
			pauseMusic.stop();
			FlxG.sound.list.remove(pauseMusic, true);
			pauseMusic.destroy();
			pauseMusic = null;
		}

		// ── 3. Scripts
		#if HSCRIPT_ALLOWED
		StateScriptHandler.callOnScripts('onDestroy', []);
		StateScriptHandler.clearStateScripts();
		#end

		// ── 4. super.destroy() destruye todos los miembros restantes del grupo.
		super.destroy();
	}

	// ─── Helpers privados ────────────────────────────────────────────────────

	/** Limpia entradas muertas del sound list para evitar acumulación. */
	private static function _cleanSoundList():Void
	{
		var i = FlxG.sound.list.length - 1;
		while (i >= 0)
		{
			var s = FlxG.sound.list.members[i];
			if (s != null && !s.alive)
				FlxG.sound.list.remove(s, true);
			i--;
		}
	}

	function changeSelection(change:Int = 0, silent:Bool = false):Void
	{
		// Guard: no operar si grpMenuShit ya fue nullificado (ej. durante destroy).
		if (grpMenuShit == null) return;

		if (!silent)
			FlxG.sound.play(Paths.sound('menus/scrollMenu'), 0.4);

		curSelected += change;
		if (curSelected < 0)                  curSelected = menuItems.length - 1;
		if (curSelected >= menuItems.length)   curSelected = 0;

		var bullShit:Int = 0;
		for (item in grpMenuShit.members)
		{
			item.targetY = bullShit - curSelected;
			bullShit++;

			item.alpha = (item.targetY == 0) ? 1.0 : 0.6;

			FlxTween.cancelTweensOf(item.scale);
			FlxTween.tween(item.scale,
				{x: item.targetY == 0 ? 1.1 : 1.0, y: item.targetY == 0 ? 1.1 : 1.0},
				0.1, {ease: FlxEase.quadOut});
		}

		#if HSCRIPT_ALLOWED
		StateScriptHandler.callOnScripts('onSelectionChanged', [curSelected]);
		#end
	}
}
