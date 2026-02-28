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
import funkin.cutscenes.VideoManager;
import funkin.data.Song;

// ─────────────────────────────────────────────────────────────────────────────
// Modos del menú de pausa
// ─────────────────────────────────────────────────────────────────────────────
enum PauseMode
{
	Standard;   // Gameplay normal
	Difficulty; // Submenú de cambio de dificultad
	Cutscene;   // Pausado durante cutscene de video
}

class PauseSubState extends funkin.states.MusicBeatSubstate
{
	var grpMenuShit:FlxTypedGroup<Alphabet>;

	// Entradas base para cada modo
	static final ENTRIES_STANDARD:Array<String> = [
		'Resume', 'Restart Song', 'Change Difficulty', 'Options', 'Exit to menu'
	];
	static final ENTRIES_CUTSCENE:Array<String> = [
		'Resume', 'Skip Cutscene', 'Exit to menu'
	];

	var menuItems:Array<String> = [];
	var curSelected:Int         = 0;
	var currentMode:PauseMode   = Standard;

	/** true si se abrió durante una cutscene de video. */
	var isCutsceneMode:Bool = false;

	var pauseMusic:FlxSound;

	// Visual elements
	var bg:FlxSprite;
	var levelInfo:FlxText;
	var levelDifficulty:FlxText;
	var levelDeaths:FlxText;
	var levelAuthor:FlxText;
	var helpText:FlxText;

	var _pauseCam:flixel.FlxCamera;

	/**
	 * @param cutsceneMode  Pasar `true` cuando se pausa durante un video en curso.
	 */
	public function new(?cutsceneMode:Bool = false)
	{
		super();

		isCutsceneMode = cutsceneMode;

		// ── Cámara — siempre la última de la lista para estar encima de todo ──
		_pauseCam = FlxG.cameras.list[FlxG.cameras.list.length - 1];
		cameras = [_pauseCam];

		#if HSCRIPT_ALLOWED
		StateScriptHandler.init();
		StateScriptHandler.loadStateScripts('PauseSubState', this);
		StateScriptHandler.callOnScripts('onCreate', []);
		#end

		_cleanSoundList();

		// Música de pausa
		pauseMusic = new FlxSound().loadEmbedded(Paths.music('breakfast'), true, true);
		pauseMusic.volume = 0;
		pauseMusic.play(false, FlxG.random.int(0, Std.int(pauseMusic.length / 2)));
		FlxG.sound.list.add(pauseMusic);

		// Fondo semitransparente (1×1 escalado para no alocar un bitmap enorme)
		bg = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		bg.setGraphicSize(FlxG.width, FlxG.height);
		bg.updateHitbox();
		bg.alpha = 0;
		bg.scrollFactor.set();
		bg.cameras = [_pauseCam];
		add(bg);

		// Info de la canción (esquina superior derecha)
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

		// Tweens de entrada
		FlxTween.tween(bg,              {alpha: 0.7},                          0.4, {ease: FlxEase.quartInOut});
		FlxTween.tween(levelInfo,       {alpha: 1, x: levelInfo.x + 10},       0.4, {ease: FlxEase.quartInOut, startDelay: 0.3});
		FlxTween.tween(levelDifficulty, {alpha: 1, x: levelDifficulty.x + 10}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.4});
		FlxTween.tween(levelDeaths,     {alpha: 1, x: levelDeaths.x + 10},     0.4, {ease: FlxEase.quartInOut, startDelay: 0.5});
		FlxTween.tween(levelAuthor,     {alpha: 1, x: levelAuthor.x + 10},     0.4, {ease: FlxEase.quartInOut, startDelay: 0.6});

		// Grupo de ítems del menú
		grpMenuShit = new FlxTypedGroup<Alphabet>();
		grpMenuShit.cameras = [_pauseCam];
		add(grpMenuShit);

		// Texto de ayuda (parte inferior)
		helpText = new FlxText(20, FlxG.height - 40, FlxG.width - 40,
			"ENTER: Select  |  ARROWS: Navigate  |  ESC: Resume", 16);
		helpText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.GRAY, CENTER, OUTLINE, FlxColor.BLACK);
		helpText.scrollFactor.set();
		helpText.alpha = 0;
		helpText.cameras = [_pauseCam];
		add(helpText);

		FlxTween.tween(helpText, {alpha: 0.7}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.7});

		// Cargar el modo inicial
		switchMode(isCutsceneMode ? Cutscene : Standard);
	}

	// ─────────────────────────────────────────────────────────────────────────
	// Update
	// ─────────────────────────────────────────────────────────────────────────

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

		// ESC / BACK: volver al menú padre o hacer resume
		if (FlxG.keys.justPressed.ESCAPE || controls.BACK)
		{
			if (currentMode == Difficulty)
				switchMode(Standard);
			else
				_doResume();
			return;
		}

		if (controls.ACCEPT)
		{
			var daSelected:String = menuItems[curSelected];

			#if HSCRIPT_ALLOWED
			StateScriptHandler.callOnScripts('onMenuItemSelected', [daSelected, curSelected]);
			#end

			switch (daSelected)
			{
				case "Resume":
					_doResume();

				case "Restart Song":
					if (PlayState.instance != null)
						PlayState.instance.startRewindRestart();
					close();

				case "Skip Song":
					if (PlayState.instance != null)
						PlayState.instance.endSong();

				case "Change Difficulty":
					switchMode(Difficulty);

				case "Options":
					OptionsMenuState.fromPause = true;
					openSubState(new OptionsMenuState());

				case "Exit to menu":
					PlayState.isPlaying = false;
					if (PlayState.isStoryMode)
						StickerTransition.start(() ->
						{
							FlxG.sound.resume();
							StateTransition.switchState(new StoryMenuState());
						});
					else
						StickerTransition.start(() ->
						{
							FlxG.sound.resume();
							StateTransition.switchState(new FreeplayState());
						});

				case "Skip Cutscene":
					_skipCutscene();

				case "Back":
					switchMode(Standard);

				default:
					// Selección de dificultad generada dinámicamente
					if (currentMode == Difficulty)
						_applyDifficulty(daSelected);
			}
		}

		#if HSCRIPT_ALLOWED
		StateScriptHandler.callOnScripts('onUpdatePost', [elapsed]);
		#end
	}

	// ─────────────────────────────────────────────────────────────────────────
	// Cambio de modo
	// ─────────────────────────────────────────────────────────────────────────

	function switchMode(mode:PauseMode):Void
	{
		currentMode = mode;
		curSelected = 0;

		switch (mode)
		{
			case Standard:
				menuItems = ENTRIES_STANDARD.copy();
				// Añadir "Skip Song" en modo historia con playlist > 1
				if (PlayState.storyPlaylist.length > 1 && PlayState.isStoryMode)
					menuItems.insert(2, "Skip Song");

			case Cutscene:
				menuItems = ENTRIES_CUTSCENE.copy();

			case Difficulty:
				menuItems = [];
				for (i in 0...CoolUtil.difficultyArray.length)
				{
					// Marcar la dificultad activa con un indicador visual
					var label = CoolUtil.difficultyArray[i];
					if (i == PlayState.storyDifficulty)
						label += "  ◀";
					menuItems.push(label);
				}
				menuItems.push("Back");
		}

		_rebuildMenu();
	}

	function _rebuildMenu():Void
	{
		if (grpMenuShit != null)
		{
			for (item in grpMenuShit.members)
				if (item != null) FlxTween.cancelTweensOf(item);
			grpMenuShit.clear();
		}

		for (i in 0...menuItems.length)
		{
			var songText:Alphabet = new Alphabet(0, (70 * i) + 30, menuItems[i], true, false);
			songText.isMenuItem = true;
			songText.targetY    = i;
			songText.alpha      = 0;
			grpMenuShit.add(songText);

			FlxTween.tween(songText, {alpha: 0.6}, 0.3, {
				ease: FlxEase.quartOut,
				startDelay: 0.1 + (i * 0.04)
			});
		}

		changeSelection(0, true);
	}

	// ─────────────────────────────────────────────────────────────────────────
	// Acciones
	// ─────────────────────────────────────────────────────────────────────────

	/**
	 * Resume: si hay video pausado, lo reanuda.
	 * Solo llama FlxG.sound.resume() si la pausa vino de gameplay normal
	 * (no de un video), para no arrancar la música en medio de una cutscene.
	 */
	function _doResume():Void
	{
		if (isCutsceneMode && VideoManager.isPlaying)
		{
			// Volvemos a un video: solo reanudar el video.
			// FlxG.sound.pause/resume NO se llamaron, así que no hay nada que restaurar.
			VideoManager.resume();
		}
		else
		{
			// Pausa normal de gameplay: restaurar todos los sonidos.
			FlxG.sound.resume();
		}

		close();

		if (PlayState.instance != null)
			PlayState.instance.paused = false;
	}

	/**
	 * Skip cutscene: para el video y reanuda el gameplay.
	 * La música empezará cuando el countdown termine normalmente.
	 */
	function _skipCutscene():Void
	{
		// Restaurar estado de PlayState ANTES de stop() para que el callback
		// de finishCallback (que llama startCountdown) encuentre el estado correcto.
		if (PlayState.instance != null)
		{
			PlayState.instance.inCutscene = false;
			PlayState.instance.canPause   = true;
			PlayState.instance.paused     = false;
		}

		// stop() → kill() → finishCallback() → startCountdown() / continueAfterSong()
		if (VideoManager.isPlaying)
			VideoManager.stop();

		close();
	}

	/**
	 * Aplica la dificultad elegida del submenú y reinicia la canción.
	 */
	function _applyDifficulty(label:String):Void
	{
		// Quitar el marcador "  ◀" si aparece
		var cleanLabel = label.split("  ◀")[0];
		var idx = CoolUtil.difficultyArray.indexOf(cleanLabel);
		if (idx == -1) return;

		if (idx == PlayState.storyDifficulty)
		{
			// Misma dificultad: restart normal sin recargar chart
			if (PlayState.instance != null)
				PlayState.instance.startRewindRestart();
			close();
			return;
		}

		PlayState.storyDifficulty = idx;

		// Recargar chart con la nueva dificultad
		var songId = PlayState.SONG.song.toLowerCase();
		PlayState.SONG = Song.loadFromJson(songId + CoolUtil.difficultyPath[idx], songId);

		// Actualizar etiqueta antes de resetear
		if (levelDifficulty != null)
			levelDifficulty.text = "Difficulty: " + CoolUtil.difficultyString();

		// Reset completo del state para aplicar el nuevo chart
		FlxG.resetState();
	}

	// ─────────────────────────────────────────────────────────────────────────
	// closeSubState override
	// ─────────────────────────────────────────────────────────────────────────

	override function closeSubState():Void
	{
		super.closeSubState();
		if (funkin.menus.OptionsMenuState.pendingRewind)
		{
			funkin.menus.OptionsMenuState.pendingRewind = false;
			if (PlayState.instance != null)
				FlxG.resetState();
		}
	}

	// ─────────────────────────────────────────────────────────────────────────
	// Destroy
	// ─────────────────────────────────────────────────────────────────────────

	override function destroy()
	{
		if (bg != null)             { FlxTween.cancelTweensOf(bg);              bg = null; }
		if (levelInfo != null)      { FlxTween.cancelTweensOf(levelInfo);       levelInfo = null; }
		if (levelDifficulty != null){ FlxTween.cancelTweensOf(levelDifficulty); levelDifficulty = null; }
		if (levelDeaths != null)    { FlxTween.cancelTweensOf(levelDeaths);     levelDeaths = null; }
		if (levelAuthor != null)    { FlxTween.cancelTweensOf(levelAuthor);     levelAuthor = null; }
		if (helpText != null)       { FlxTween.cancelTweensOf(helpText);        helpText = null; }

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

		if (pauseMusic != null)
		{
			pauseMusic.stop();
			FlxG.sound.list.remove(pauseMusic, true);
			pauseMusic.destroy();
			pauseMusic = null;
		}

		#if HSCRIPT_ALLOWED
		StateScriptHandler.callOnScripts('onDestroy', []);
		StateScriptHandler.clearStateScripts();
		#end

		super.destroy();

		// Seguridad: si el substate se destruyó sin pasar por Resume/Exit
		// Solo restaurar sonido si NO hay un video activo (la música la gestiona VideoManager/startSong).
		if (!VideoManager.isPlaying)
			FlxG.sound.resume();
	}

	// ─────────────────────────────────────────────────────────────────────────
	// Helpers privados
	// ─────────────────────────────────────────────────────────────────────────

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
		if (grpMenuShit == null) return;

		if (!silent)
			FlxG.sound.play(Paths.sound('menus/scrollMenu'), 0.4);

		curSelected += change;
		if (curSelected < 0)                 curSelected = menuItems.length - 1;
		if (curSelected >= menuItems.length) curSelected = 0;

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
