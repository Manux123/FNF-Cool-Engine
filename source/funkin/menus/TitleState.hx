package funkin.menus;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.input.gamepad.FlxGamepad;
import funkin.debug.charting.ChartingState;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import lime.app.Application;
import funkin.data.Conductor;
import funkin.states.OutdatedSubState;
import data.PlayerSettings;
import ui.Alphabet;
import funkin.scripting.StateScriptHandler;
import funkin.transitions.StateTransition;
import haxe.Json;

using StringTools;

/**
 * Estructura de datos de titlescreen.json
 *
 * Ruta: assets/data/titlescreen.json
 *
 * Ejemplo completo:
 * {
 *   "bpm": 102,
 *   "introBeats": [
 *     { "beat": 1, "texts": ["ninjamuffin99", "phantomArcade", "kawaisprite", "evilsk8er"] },
 *     { "beat": 3, "texts": ["present"] },
 *     { "beat": 4, "clear": true },
 *     { "beat": 5, "texts": ["Cool Engine Team"] },
 *     { "beat": 7, "texts": ["Manux", "Juanen100", "MrClogsworthYt", "JloorMC", "Overcharged Dev"] },
 *     { "beat": 8, "clear": true },
 *     { "beat": 9, "random": true },
 *     { "beat": 11, "randomSecond": true },
 *     { "beat": 12, "clear": true },
 *     { "beat": 13, "texts": ["Friday"] },
 *     { "beat": 14, "texts": ["Night"] },
 *     { "beat": 15, "texts": ["Funkin"] },
 *     { "beat": 16, "skipIntro": true }
 *   ],
 *   "randomLines": [
 *     ["Thx PabloelproxD210", "for the Android port LOL"],
 *     ["Thx Chase for...", "SOMTHING"],
 *     ["Thx TheStrexx for", "you'r 3 commits :D"]
 *   ]
 * }
 */
typedef TitleBeat = {
	var beat:Int;
	@:optional var texts:Array<String>;
	@:optional var clear:Bool;
	@:optional var random:Bool;
	@:optional var randomSecond:Bool;
	@:optional var skipIntro:Bool;
}

typedef TitleScreenData = {
	@:optional var bpm:Float;
	@:optional var introBeats:Array<TitleBeat>;
	@:optional var randomLines:Array<Array<String>>;
}

class TitleState extends funkin.states.MusicBeatState
{
	static var initialized:Bool = false;

	var blackScreen:FlxSprite;
	var credGroup:FlxGroup;
	var credTextShit:Alphabet;
	var textGroup:FlxGroup;
	var ngSpr:FlxSprite;

	// var curWacky:Array<String> = [];
	var wackyImage:FlxSprite;

	/** Datos cargados de assets/data/titlescreen.json */
	var titleData:TitleScreenData = null;
	/** Lista de pares de strings aleatorios (del JSON). */
	var _randomLines:Array<Array<String>> = [];
	/** Índice de la línea random elegida este ciclo. */
	var _randomIdx:Int = 0;

	static function _loadTitleData():TitleScreenData
	{
		// Prioridad: mod > assets base
		var paths:Array<String> = [];
		#if sys
		var modRoot = mods.ModManager.modRoot();
		if (modRoot != null)
			paths.push(modRoot + '/data/titlescreen.json');
		paths.push('assets/data/titlescreen.json');
		for (p in paths)
		{
			if (sys.FileSystem.exists(p))
			{
				try { return cast haxe.Json.parse(sys.io.File.getContent(p)); }
				catch (e:Dynamic) { trace('[TitleState] Error parseando $p: $e'); }
			}
		}
		#end
		return null;
	}

	override public function create():Void
	{
		PlayerSettings.init();
		
		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.getGraphic('menu/menuBGtitle'));
		add(bg);

		MainMenuState.musicFreakyisPlaying = true;

		// DEBUG BULLSHIT

		#if HSCRIPT_ALLOWED
		StateScriptHandler.init();
		StateScriptHandler.loadStateScripts('TitleState', this);
		StateScriptHandler.callOnScripts('onCreate', []);
		#end

		if (FlxG.save.data.weekUnlocked != null)
		{
			if (StoryMenuState.weekUnlocked.length < 4)
				StoryMenuState.weekUnlocked.insert(0, true);

			if (!StoryMenuState.weekUnlocked[0])
				StoryMenuState.weekUnlocked[0] = true;
		}

		#if FREEPLAY
		StateTransition.switchState(new FreeplayState());
		#elseif CHARTING
		StateTransition.switchState(new ChartingState());
		#elseif MAINMENU
		StateTransition.switchState(new MainMenuState());
		#else
		titleData = _loadTitleData();
		// Cargar líneas aleatorias del JSON (si existen) o usar los defaults del engine
		if (titleData != null && titleData.randomLines != null && titleData.randomLines.length > 0)
			_randomLines = titleData.randomLines;
		else
			_randomLines = [
				['Thx PabloelproxD210', 'for the Android port LOL'],
				['Thx Chase for...', 'SOMTHING'],
				['Thx TheStrexx for', "you'r 3 commits :D"]
			];
		startIntro();
		#end

		super.create();
	}

	var logoBl:FlxSprite;
	var gfDance:FlxSprite;
	var danceLeft:Bool = false;
	var titleText:FlxSprite;
	var transitioning:Bool = false;

	function startIntro()
	{
		persistentUpdate = true;

		logoBl = new FlxSprite(-150, -100);
		logoBl.frames = Paths.getSparrowAtlas('titlestate/logoBumpin');
		logoBl.antialiasing = true;
		logoBl.animation.addByPrefix('bump', 'logo bumpin', 24);
		logoBl.animation.play('bump');
		logoBl.updateHitbox();
		// logoBl.screenCenter();
		// logoBl.color = FlxColor.BLACK;

		// FlxTween.tween(logoBl, {y: logoBl.y + 50}, 0.6, {ease: FlxEase.quadInOut, type: ONESHOT});

		gfDance = new FlxSprite(FlxG.width * 0.4, FlxG.height * 0.07);
		gfDance.frames = Paths.getSparrowAtlas('titlestate/gfDanceTitle');
		gfDance.animation.addByIndices('danceLeft', 'gfDance', [30, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14], "", 24, false);
		gfDance.animation.addByIndices('danceRight', 'gfDance', [15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29], "", 24, false);
		gfDance.antialiasing = true;
		add(gfDance);
		add(logoBl);

		titleText = new FlxSprite(100, FlxG.height * 0.8);
		titleText.frames = Paths.getSparrowAtlas('titlestate/titleEnter');
		titleText.animation.addByPrefix('idle', "Press Enter to Begin", 24);
		titleText.animation.addByPrefix('press', "ENTER PRESSED", 24);
		titleText.antialiasing = true;
		titleText.animation.play('idle');
		titleText.updateHitbox();
		// titleText.screenCenter(X);
		add(titleText);

		credGroup = new FlxGroup();
		add(credGroup);
		textGroup = new FlxGroup();

		blackScreen = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		credGroup.add(blackScreen);

		credTextShit = new Alphabet(0, 0, "ninjamuffin99\nPhantomArcade\nkawaisprite\nevilsk8er", true);
		credTextShit.screenCenter();

		// credTextShit.alignment = CENTER;

		credTextShit.visible = false;

		ngSpr = new FlxSprite(0, FlxG.height * 0.52).loadGraphic(Paths.image('titlestate/newgrounds_logo'));
		add(ngSpr);
		ngSpr.visible = false;
		ngSpr.setGraphicSize(Std.int(ngSpr.width * 0.8));
		ngSpr.updateHitbox();
		ngSpr.screenCenter(X);
		ngSpr.antialiasing = true;

		FlxTween.tween(credTextShit, {y: credTextShit.y + 20}, 2.9, {ease: FlxEase.quadInOut, type: PINGPONG});

		FlxG.mouse.visible = false;

		if (initialized)
		{
			// Coming back from a mod restart — music was destroyed, restart it
			if (FlxG.sound.music == null || !FlxG.sound.music.playing)
			{
				final snd = Paths.loadMusic('freakyMenu');
				if (snd != null) FlxG.sound.playMusic(snd, 0.7);
				else FlxG.sound.playMusic(Paths.music('freakyMenu'), 0.7);
				Conductor.changeBPM(titleData != null && titleData.bpm != null ? titleData.bpm : 102);
			}
			skipIntro();
		}
		else
		{
			transIn = null;
			transOut = null;

			final freakyPath = Paths.music('freakyMenu');
			final freakySnd  = Paths.loadMusic('freakyMenu');
			if (freakySnd != null)
				FlxG.sound.playMusic(freakySnd, 0);
			else
				FlxG.sound.playMusic(freakyPath, 0);

			FlxG.sound.music.fadeIn(4, 0, 0.7);
			Conductor.changeBPM(titleData != null && titleData.bpm != null ? titleData.bpm : 102);
			initialized = true;
		}

		#if HSCRIPT_ALLOWED
		// Los sprites se crearon en startIntro() DESPUÉS de loadStateScripts(),
		// así que hay que re-sincronizar los campos del state ahora que ya existen.
		StateScriptHandler.refreshStateFields(this);
		StateScriptHandler.callOnScripts('postCreate', []);
		#end
	}

	override function update(elapsed:Float)
	{
		if (FlxG.sound.music != null)
			Conductor.songPosition = FlxG.sound.music.time;
		// FlxG.watch.addQuick('amp', FlxG.sound.music.amplitude);

		#if HSCRIPT_ALLOWED
		StateScriptHandler.callOnScripts('onUpdate', [elapsed]);
		#end

		if (FlxG.keys.justPressed.F11)
		{
			FlxG.fullscreen = !FlxG.fullscreen;
		}

		var pressedEnter:Bool = FlxG.keys.justPressed.ENTER;

		#if mobile
		for (touch in FlxG.touches.list)
		{
			if (touch.justPressed)
			{
				pressedEnter = true;
			}
		}
		#end

		var gamepad:FlxGamepad = FlxG.gamepads.lastActive;

		if (gamepad != null)
		{
			if (gamepad.justPressed.START)
				pressedEnter = true;

			#if switch
			if (gamepad.justPressed.B)
				pressedEnter = true;
			#end
		}

		if (pressedEnter && !transitioning && skippedIntro)
		{
			if (titleText != null)
				titleText.animation.play('press');

			if (FlxG.save.data.flashing)
				FlxG.camera.flash(FlxColor.WHITE, 1);
			FlxG.sound.play(Paths.sound('menus/confirmMenu'), 0.7);

			transitioning = true;
			// FlxG.sound.music.stop();

			new FlxTimer().start(2, function(tmr:FlxTimer)
			{
				// Check if version is outdated also changelog

				var http = new haxe.Http("https://raw.githubusercontent.com/Manux123/FNF-Cool-Engine/master/ver.thing");
				var returnedData:Array<String> = [];
				var version:String = Application.current.meta.get('version');

				http.onData = function(data:String)
				{
					returnedData[0] = data.substring(0, data.indexOf('-'));
					returnedData[1] = data.substring(data.indexOf('+'), data.length);
					if (!version.contains(returnedData[0].trim()) && !OutdatedSubState.leftState)
					{
						trace('Poor guy, he is outdated');
						OutdatedSubState.daVersionNeeded = returnedData[0];
						OutdatedSubState.daChangelogNeeded = returnedData[1];
						StateTransition.switchState(new OutdatedSubState());
					}
					else
					{
						// StateTransition.switchState(new states.VideoState('test/sus',new states.PlayState()));
						StateTransition.switchState(new MainMenuState());
					}
				}

				http.onError = function(error)
				{
					trace('error: $error');
					StateTransition.switchState(new MainMenuState()); // fail but we go anyway
				}

				http.request();
			});
			// FlxG.sound.play(Paths.music('titleShoot'), 0.7);
		}

		if (pressedEnter && !skippedIntro)
		{
			skipIntro();
		}

		super.update(elapsed);

		#if HSCRIPT_ALLOWED
		StateScriptHandler.callOnScripts('onUpdatePost', [elapsed]);
		#end
	};

	function createCoolText(textArray:Array<String>)
	{
		for (i in 0...textArray.length)
		{
			var money:Alphabet = new Alphabet(0, 0, textArray[i], true, false);
			money.screenCenter(X);
			money.y += (i * 60) + 200;
			credGroup.add(money);
			textGroup.add(money);
		}
	}

	function addMoreText(text:String, yOffset:Float = 0)
	{
		var coolText:Alphabet = new Alphabet(0, 0, text, true, false);
		coolText.screenCenter(X);
		if (yOffset != 0)
			coolText.y -= yOffset;
		credGroup.add(coolText);
		textGroup.add(coolText);

		FlxTween.tween(coolText, {y: coolText.y + (textGroup.length * 60) + 150}, 0.4, {
			ease: FlxEase.expoInOut,
			onComplete: function(flxTween:FlxTween)
			{
			}
		});
	}

	function deleteCoolText()
	{
		while (textGroup.members.length > 0)
		{
			credGroup.remove(textGroup.members[0], true);
			textGroup.remove(textGroup.members[0], true);
		}
	}


	override function beatHit()
	{
		super.beatHit();

		#if HSCRIPT_ALLOWED
		StateScriptHandler.callOnScripts('onBeatHit', [curBeat]);
		#end

		logoBl.animation.play('bump');
		danceLeft = !danceLeft;

		if (danceLeft)
			gfDance.animation.play('danceRight');
		else
			gfDance.animation.play('danceLeft');

		FlxG.log.add(curBeat);

		FlxTween.tween(FlxG.camera, {zoom: 1.02}, 0.3, {ease: FlxEase.quadOut, type: BACKWARD});

		switch (curBeat)
		{
			// La secuencia de intro se lee de titlescreen.json (campo "introBeats").
			// Si no existe el JSON, se usan los valores hardcodeados como fallback.
			default:
				if (titleData != null && titleData.introBeats != null)
				{
					// JSON-driven: buscar si hay una entrada para este beat
					for (entry in titleData.introBeats)
					{
						if (entry.beat != curBeat) continue;
						if (entry.clear == true)        deleteCoolText();
						if (entry.skipIntro == true)    { skipIntro(); break; }
						if (entry.random == true)
						{
							_randomIdx = FlxG.random.int(0, _randomLines.length - 1);
							if (_randomLines[_randomIdx].length > 0)
								createCoolText([_randomLines[_randomIdx][0]]);
						}
						if (entry.randomSecond == true)
						{
							if (_randomLines[_randomIdx].length > 1)
								addMoreText(_randomLines[_randomIdx][1]);
						}
						if (entry.texts != null)
						{
							// Si ya hay texto visible, usar addMoreText para cada línea;
							// si no hay, usar createCoolText para la primera y addMoreText para el resto.
							if (textGroup.length == 0)
							{
								createCoolText(entry.texts);
							}
							else
							{
								for (t in entry.texts)
									addMoreText(t);
							}
						}
						break;
					}
				}
				else
				{
					// Fallback hardcodeado — misma secuencia de siempre
					switch (curBeat)
					{
						case 0:  deleteCoolText();
						case 1:  createCoolText(['ninjamuffin99', 'phantomArcade', 'kawaisprite', 'evilsk8er']);
						case 3:  addMoreText('present');
						case 4:  deleteCoolText();
						case 5:  createCoolText(['Cool Engine Team']);
						case 7:
							addMoreText('Manux');
							addMoreText('Juanen100');
							addMoreText('MrClogsworthYt');
							addMoreText('JloorMC');
							addMoreText('Overcharged Dev');
						case 8:
							deleteCoolText();
							ngSpr.visible = false;
						case 9:
							_randomIdx = FlxG.random.int(0, _randomLines.length - 1);
							createCoolText([_randomLines[_randomIdx][0]]);
						case 11:
							if (_randomLines[_randomIdx].length > 1)
								addMoreText(_randomLines[_randomIdx][1]);
						case 12: deleteCoolText();
						case 13: addMoreText('Friday');
						case 14: addMoreText('Night');
						case 15: addMoreText('Funkin');
						case 16: skipIntro();
					}
				}
		}
	}

	var skippedIntro:Bool = false;

	function skipIntro():Void
	{
		if (!skippedIntro)
		{
			remove(ngSpr);

			if (FlxG.save.data.flashing)
				FlxG.camera.flash(FlxColor.WHITE, 4);
			remove(credGroup);

			FlxTween.tween(logoBl, {y: -100}, 1.4, {ease: FlxEase.expoInOut});

			logoBl.angle = -4;

			new FlxTimer().start(0.01, function(tmr:FlxTimer)
			{
				if (logoBl.angle == -4)
					FlxTween.angle(logoBl, logoBl.angle, 4, 4, {ease: FlxEase.quartInOut});
				if (logoBl.angle == 4)
					FlxTween.angle(logoBl, logoBl.angle, -4, 4, {ease: FlxEase.quartInOut});
			}, 0);

			skippedIntro = true;
		}
	}

	override function destroy()
	{
		#if HSCRIPT_ALLOWED
		StateScriptHandler.callOnScripts('onDestroy', []);
		StateScriptHandler.clearStateScripts();
		#end

		super.destroy();
	}
}
