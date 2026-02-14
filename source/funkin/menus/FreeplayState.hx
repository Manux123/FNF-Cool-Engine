package funkin.menus;

#if desktop
import data.Discord.DiscordClient;
#end
import flash.text.TextField;
import flixel.FlxG;
import lime.app.Application;
import flixel.FlxSprite;
import flixel.addons.display.FlxGridOverlay;
import flixel.addons.transition.FlxTransitionableState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.tweens.FlxEase;
import funkin.menus.StoryMenuState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import lime.utils.Assets;
import flixel.sound.FlxSound;
import openfl.utils.Assets as OpenFlAssets;
import flixel.effects.particles.FlxEmitter;
import funkin.states.LoadingState;
import flixel.effects.particles.FlxParticle;
import funkin.gameplay.objects.character.HealthIcon;
import funkin.data.Song;
import funkin.menus.FreeplayEditorState;
import funkin.gameplay.objects.hud.Highscore;
import funkin.scripting.StateScriptHandler;
import funkin.gameplay.PlayState;
import funkin.data.Conductor;
import extensions.CoolUtil;
import ui.Alphabet;

using StringTools;

import haxe.Json;
import haxe.format.JsonParser;

typedef Songs =
{
	var songsWeeks:Array<SongsInfo>;
}

typedef SongsInfo =
{
	var weekSongs:Array<String>;
	var songIcons:Array<String>;
	var color:Array<String>;
	var bpm:Array<Float>;
}

class FreeplayState extends funkin.states.MusicBeatState
{
	var toBeFinished = 0;
	var finished = 0;

	public static var songInfo:Songs;

	var songs:Array<SongMetadata> = [];

	var selector:FlxText;
	var discSpr:FlxSprite;

	private static var curSelected:Int = 0;
	private static var curDifficulty:Int = 1;

	var scoreBG:FlxSprite;
	var scoreText:FlxText;
	var diffText:FlxText;
	var lerpScore:Int = 0;
	var lerpRating:Float = 0;
	var intendedScore:Int = 0;
	var intendedRating:Float = 0;
	var songText:Alphabet;

	private var grpSongs:FlxTypedGroup<Alphabet>;
	private var curPlaying:Bool = false;

	private var iconArray:Array<HealthIcon> = [];

	public static var coolColors:Array<Int> = [];

	var bg:FlxSprite;
	var bgGradient:FlxSprite;
	var intendedColor:Int;
	var colorTween:FlxTween;

	// Nuevas variables para efectos visuales
	var particleEmitter:FlxEmitter;
	var screenBumpAmount:Float = 0;
	var bpmTarget:Float = 0;
	var beatTimer:Float = 0;
	var visualBars:FlxTypedGroup<FlxSprite>;
	var glowOverlay:FlxSprite;

	// Variables para el screen shake/bump al ritmo
	var camBumpIntensity:Float = 1.0;
	var lastScreenBumpBeat:Int = -1;

	override function create()
	{
		transIn = FlxTransitionableState.defaultTransIn;
		transOut = FlxTransitionableState.defaultTransOut;

		MainMenuState.musicFreakyisPlaying = false;
		if (vocals == null)
			FlxG.sound.playMusic(Paths.music('girlfriendsRingtone/girlfriendsRingtone'), 0.7);

		loadSongsData();
		if (songInfo != null)
		{
			songsSystem();
		}
		else
		{
			trace("Error loading song data");
		}

		#if desktop
		DiscordClient.changePresence("In the FreePlay", null);
		#end

		// === FONDO MEJORADO CON DEGRADADO ===
		bg = new FlxSprite();
		if (Paths.image('menu/menuDesat') != null)
		{
			bg.loadGraphic(Paths.image('menu/menuDesat'));
		}
		else
		{
			// Fallback: crear un fondo sólido si no existe la imagen
			bg.makeGraphic(FlxG.width, FlxG.height, 0xFF2A2A2A);
		}
		bg.color = 0xFF2A2A2A;
		bg.scrollFactor.set(0.1, 0.1);
		add(bg);

		// Degradado overlay para dar profundidad
		bgGradient = new FlxSprite();
		bgGradient.makeGraphic(FlxG.width, FlxG.height, FlxColor.TRANSPARENT, true);
		var gradientColors:Array<Int> = [0x00000000, 0x88000000];
		for (i in 0...FlxG.height)
		{
			var ratio:Float = i / FlxG.height;
			var alpha:Int = Std.int(ratio * 0x88);
			bgGradient.pixels.fillRect(new flash.geom.Rectangle(0, i, FlxG.width, 1), alpha << 24);
		}
		bgGradient.pixels.unlock();
		add(bgGradient);

		// === BARRAS VISUALES DE AUDIO (decorativas) ===
		visualBars = new FlxTypedGroup<FlxSprite>();
		add(visualBars);

		for (i in 0...10)
		{
			var bar:FlxSprite = new FlxSprite(0 + (i * 140), FlxG.height - 150 + 100);
			bar.makeGraphic(120, 220, FlxColor.fromRGB(100 + i * 15, 150, 255 - i * 15));
			bar.alpha = 0.3;
			bar.scrollFactor.set();
			visualBars.add(bar);
		}

		// === SISTEMA DE PARTÍCULAS ===
		particleEmitter = new FlxEmitter(0, 0, 50);
		particleEmitter.makeParticles(2, 2, FlxColor.WHITE, 50);
		particleEmitter.launchMode = FlxEmitterMode.SQUARE;
		particleEmitter.velocity.set(-50, -100, 50, -200);
		particleEmitter.lifespan.set(3, 6);
		particleEmitter.alpha.set(0.4, 0.8, 0, 0);
		particleEmitter.scale.set(1, 1, 0.5, 0.5);
		particleEmitter.width = FlxG.width;
		particleEmitter.y = FlxG.height;
		add(particleEmitter);
		particleEmitter.start(false, 0.1);

		grpSongs = new FlxTypedGroup<Alphabet>();
		add(grpSongs);

		for (i in 0...songs.length)
		{
			songText = new Alphabet(0, (70 * i) + 30, songs[i].songName, true, false);
			songText.isMenuItem = true;
			songText.targetY = i;
			grpSongs.add(songText);

			var icon:HealthIcon = new HealthIcon(songs[i].songCharacter);
			icon.sprTracker = songText;

			// CORRECCIÓN: Verificar que el icono se creó correctamente antes de agregarlo
			if (icon != null)
			{
				iconArray.push(icon);
				add(icon);
			}
		}

		#if HSCRIPT_ALLOWED
		StateScriptHandler.init();
		StateScriptHandler.loadStateScripts('FreeplayState', this);
		StateScriptHandler.callOnScripts('onCreate', []);
		#end

		// === OVERLAY DE GLOW PARA EFECTOS ===
		glowOverlay = new FlxSprite();
		glowOverlay.makeGraphic(FlxG.width, FlxG.height, FlxColor.WHITE);
		glowOverlay.alpha = 0;
		glowOverlay.blend = ADD;
		add(glowOverlay);

		// === UI MEJORADA ===
		scoreBG = new FlxSprite(FlxG.width * 0.65, 30);
		scoreBG.makeGraphic(1, 95, 0xFF000000);
		scoreBG.alpha = 0.7;
		add(scoreBG);

		scoreText = new FlxText(FlxG.width * 0.66, 45, 0, "", 28);
		scoreText.setFormat(Paths.font("vcr.ttf"), 28, FlxColor.WHITE, RIGHT);
		scoreText.setBorderStyle(OUTLINE, FlxColor.BLACK, 2);
		add(scoreText);

		diffText = new FlxText(FlxG.width * 0.66, 85, 0, "", 24);
		diffText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.CYAN, RIGHT);
		diffText.setBorderStyle(OUTLINE, FlxColor.BLACK, 2);
		add(diffText);

		var ratingText:FlxText = new FlxText(FlxG.width * 0.66, 115, 0, "", 20);
		ratingText.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.YELLOW, RIGHT);
		ratingText.setBorderStyle(OUTLINE, FlxColor.BLACK, 2);
		add(ratingText);

		if (songs.length > 0)
		{
			bg.color = songs[curSelected].color;
			intendedColor = bg.color;
		}
		else
		{
			bg.color = 0xFF2A2A2A;
			intendedColor = 0xFF2A2A2A;
		}
		changeSelection();
		changeDiff();

		// === TEXTO INFERIOR MEJORADO ===
		var textBG:FlxSprite = new FlxSprite(0, FlxG.height - 30);
		textBG.makeGraphic(FlxG.width, 30, 0xFF000000);
		textBG.alpha = 0.8;
		add(textBG);

		var leText:FlxText = new FlxText(0, FlxG.height - 26, FlxG.width, "SPACE: Preview Song | ENTER: Play | ESC: Back | E: Editor", 16);
		leText.scrollFactor.set();
		leText.setFormat('VCR OSD Mono', 16, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(leText);

		var versionShit:FlxText = new FlxText(12, FlxG.height - 26, 0, "FNF Cool Engine v" + Application.current.meta.get('version'), 12);
		versionShit.scrollFactor.set();
		versionShit.setFormat("VCR OSD Mono", 16, FlxColor.CYAN, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(versionShit);

		// Animación de entrada
		FlxTween.tween(bg, {alpha: 1, "scale.x": 1, "scale.y": 1}, 0.6, {ease: FlxEase.expoOut});

		super.create();

		#if HSCRIPT_ALLOWED
		StateScriptHandler.callOnScripts('postCreate', []);
		#end

		#if mobileC
		addVirtualPad(FULL, A_B);
		#end
	}

	function songsSystem()
	{
		for (i in 0...songInfo.songsWeeks.length)
		{
			#if !debug
			if (StoryMenuState.weekUnlocked[i])
			#end
			addWeek(songInfo.songsWeeks[i].weekSongs, i, songInfo.songsWeeks[i].songIcons);
			coolColors.push(Std.parseInt(songInfo.songsWeeks[i].color[i]));
		}
	}

	function loadSongsData():Void
	{
		var file:String = Assets.getText(Paths.jsonSong('songList'));
		try
		{
			songInfo = cast Json.parse(file);
		}
		catch (e:Dynamic)
		{
			trace("Error loading song data for " + file + ": " + e);
			songInfo = null;
		}
	}

	override function closeSubState()
	{
		changeSelection();
		super.closeSubState();
	}

	public function addSong(songName:String, weekNum:Int, songCharacter:String)
	{
		songs.push(new SongMetadata(songName, weekNum, songCharacter));
	}

	public function addWeek(songs:Array<String>, weekNum:Int, ?songCharacters:Array<String>)
	{
		if (songCharacters == null)
			songCharacters = ['bf'];

		var num:Int = 0;
		for (song in songs)
		{
			addSong(song, weekNum, songCharacters[num]);
			if (songCharacters.length != 1)
				num++;
		}
	}

	public static var vocals:FlxSound = null;
	public static var instPlaying:Int = -1;

	override function update(elapsed:Float)
	{
		#if HSCRIPT_ALLOWED
		StateScriptHandler.callOnScripts('onUpdate', [elapsed]);
		#end

		// Actualizar efectos visuales
		updateScreenBump(elapsed);
		updateVisualBars(elapsed);

		// Interpolar score
		lerpScore = Math.floor(FlxMath.lerp(lerpScore, intendedScore, boundTo(elapsed * 24, 0, 1)));
		lerpRating = FlxMath.lerp(lerpRating, intendedRating, boundTo(elapsed * 12, 0, 1));

		if (Math.abs(lerpScore - intendedScore) <= 10)
			lerpScore = intendedScore;
		if (Math.abs(lerpRating - intendedRating) <= 0.01)
			lerpRating = intendedRating;

		scoreText.text = 'PERSONAL BEST: ' + lerpScore;
		positionHighscore();

		var upP = controls.UP_P;
		var downP = controls.DOWN_P;
		var leftP = controls.LEFT_P;
		var rightP = controls.RIGHT_P;
		var accepted = FlxG.keys.justPressed.ENTER;
		var space = FlxG.keys.justPressed.SPACE;

		if (upP)
		{
			changeSelection(-1);
		}
		if (downP)
		{
			changeSelection(1);
		}

		if (leftP)
			changeDiff(-1);
		if (rightP)
			changeDiff(1);

		if (controls.BACK)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			FlxG.switchState(new MainMenuState());
		}

		// Abrir el editor con la tecla E
		if (FlxG.keys.justPressed.E)
		{
			FlxG.switchState(new FreeplayEditorState());
		}

		#if cpp
		if (space)
		{
			if (instPlaying != curSelected)
			{
				destroyFreeplayVocals();
				FlxG.sound.music.volume = 0;

				var poop:String = Highscore.formatSong(songs[curSelected].songName.toLowerCase(), curDifficulty);
				PlayState.SONG = Song.loadFromJson(poop, songs[curSelected].songName.toLowerCase());
				if (PlayState.SONG.needsVoices)
					vocals = new FlxSound().loadEmbedded(Paths.voices(PlayState.SONG.song));
				else
					vocals = new FlxSound();

				FlxG.sound.list.add(vocals);
				FlxG.sound.playMusic(Paths.inst(PlayState.SONG.song), 0.7);
				vocals.play();
				vocals.persist = true;
				vocals.looped = true;
				vocals.volume = 0.7;
				instPlaying = curSelected;

				// Establecer BPM para el screen bump
				if (songInfo != null && songInfo.songsWeeks.length > curSelected)
				{
					var weekIndex = songs[curSelected].week;
					if (weekIndex < songInfo.songsWeeks.length
						&& songInfo.songsWeeks[weekIndex].bpm != null
						&& songInfo.songsWeeks[weekIndex].bpm.length > 0)
					{
						bpmTarget = songInfo.songsWeeks[weekIndex].bpm[0];
					}
				}

				Conductor.changeBPM(bpmTarget);

				if (discSpr != null)
				{
					remove(discSpr);
					discSpr.destroy();
				}

				discSpr = new FlxSprite(750, 280);
				discSpr.frames = Paths.getSparrowAtlas('freeplay/record player freeplay');
				discSpr.antialiasing = FlxG.save.data.antialiasing;
				discSpr.animation.addByPrefix('idle', 'disco', 24);
				discSpr.animation.play('idle');
				discSpr.x += 750;
				discSpr.setGraphicSize(Std.int(discSpr.width * 0.5));
				discSpr.updateHitbox();
				add(discSpr);

				FlxTween.tween(discSpr, {"x": 750}, 0.6, {ease: FlxEase.elasticInOut});

				// Efecto de glow al reproducir
				FlxTween.tween(glowOverlay, {alpha: 0.15}, 0.2, {
					ease: FlxEase.quadOut,
					onComplete: function(twn:FlxTween)
					{
						FlxTween.tween(glowOverlay, {alpha: 0}, 0.4, {ease: FlxEase.quadIn});
					}
				});
			}
			else
			{
				destroyFreeplayVocals();
				FlxG.sound.playMusic(Paths.music('freakyMenu'));
				instPlaying = -1;

				if (discSpr != null)
				{
					FlxTween.tween(discSpr, {"x": discSpr.x + 750}, 0.6, {
						ease: FlxEase.elasticInOut,
						onComplete: function(twn:FlxTween)
						{
							if (discSpr != null)
							{
								remove(discSpr);
								discSpr.destroy();
								discSpr = null;
							}
						}
					});
				}
			}
		}
		#end

		if (accepted)
		{
			#if HSCRIPT_ALLOWED
			var cancelled = StateScriptHandler.callOnScriptsReturn('onAccept', [], false);
			if (cancelled)
				return;
			#end

			var songLowercase:String = songs[curSelected].songName.toLowerCase();
			var poop:String = Highscore.formatSong(songLowercase, curDifficulty);
			trace(poop);

			PlayState.SONG = Song.loadFromJson(poop, songLowercase);
			PlayState.isStoryMode = false;
			PlayState.storyDifficulty = curDifficulty;

			PlayState.storyWeek = songs[curSelected].week;
			trace('CURRENT WEEK: ' + getCurrentWeekNumber());
			if (colorTween != null)
			{
				colorTween.cancel();
			}
			FlxG.sound.music.volume = 0;

			FlxG.camera.flash(FlxColor.WHITE, 1);
			FlxG.sound.play(Paths.sound('confirmMenu'), 0.7);

			LoadingState.loadAndSwitchState(new PlayState());

			destroyFreeplayVocals();
		}

		super.update(elapsed);

		#if HSCRIPT_ALLOWED
		StateScriptHandler.callOnScripts('onUpdatePost', [elapsed]);
		#end
	}

	// === FUNCIÓN PARA SCREEN BUMP AL RITMO ===
	function updateScreenBump(elapsed:Float):Void
	{
		if (FlxG.sound.music != null && FlxG.sound.music.playing)
		{
			var curBPM:Float = bpmTarget > 0 ? bpmTarget : 102; // BPM por defecto
			var songPos:Float = Conductor.songPosition;

			beatTimer += elapsed * 1000;

			var calculatedBeat:Int = Math.floor((songPos / 1000) * (curBPM / 60));

			if (calculatedBeat != lastScreenBumpBeat && calculatedBeat % 1 == 0)
			{
				lastScreenBumpBeat = calculatedBeat;
				screenBump();

				// Bump de iconos cada 4 beats
				if (calculatedBeat % 4 == 0)
				{
					for (icon in iconArray)
					{
						if (icon != null && icon.scale != null)
						{
							icon.scale.set(1.3, 1.3);
							FlxTween.tween(icon.scale, {x: 1, y: 1}, 0.2, {ease: FlxEase.expoOut});
						}
					}
				}
			}
		}

		// Suavizar el zoom de vuelta
		FlxG.camera.zoom = FlxMath.lerp(FlxG.camera.zoom, 1, elapsed * 3);
	}

	// === BUMP DE PANTALLA ===
	function screenBump():Void
	{
		FlxG.camera.zoom += 0.015 * camBumpIntensity;

		// Pequeño shake
		FlxG.camera.shake(0.002, 0.05);

		// Pulse en el glow overlay
		if (glowOverlay != null)
		{
			glowOverlay.alpha = 0.05;
			FlxTween.tween(glowOverlay, {alpha: 0}, 0.3, {ease: FlxEase.quadOut});
		}
	}

	// === ACTUALIZAR BARRAS VISUALES ===
	function updateVisualBars(elapsed:Float):Void
	{
		var i:Int = 0;
		for (bar in visualBars)
		{
			if (bar != null && bar.scale != null)
			{
				var targetHeight:Float = 50 + Math.sin((beatTimer / 100) + i) * 40;
				bar.scale.y = FlxMath.lerp(bar.scale.y, targetHeight / 100, elapsed * 8);
				bar.y = FlxG.height - 150 + 100 - (bar.scale.y * 150);
			}
			i++;
		}
	}

	public static function destroyFreeplayVocals()
	{
		if (vocals != null)
		{
			vocals.stop();
			vocals.destroy();
		}
		vocals = null;
	}

	function changeDiff(change:Int = 0)
	{
		curDifficulty += change;

		if (curDifficulty < 0)
			curDifficulty = difficultyStuff.length - 1;
		if (curDifficulty >= difficultyStuff.length)
			curDifficulty = 0;

		#if !switch
		intendedScore = Highscore.getScore(songs[curSelected].songName, curDifficulty);
		intendedRating = Highscore.getRating(songs[curSelected].songName, curDifficulty);
		#end

		PlayState.storyDifficulty = curDifficulty;
		diffText.text = '< ' + CoolUtil.difficultyString() + ' >';
		positionHighscore();

		#if HSCRIPT_ALLOWED
		StateScriptHandler.callOnScripts('onDifficultyChanged', [curDifficulty]);
		#end
	}

	function changeSelection(change:Int = 0)
	{
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		curSelected += change;

		if (curSelected < 0)
			curSelected = songs.length - 1;
		if (curSelected >= songs.length)
			curSelected = 0;

		var newColor:Int = songs[curSelected].color;
		if (newColor != intendedColor)
		{
			if (colorTween != null)
			{
				colorTween.cancel();
			}
			intendedColor = newColor;
			colorTween = FlxTween.color(bg, 1, bg.color, intendedColor, {
				onComplete: function(twn:FlxTween)
				{
					colorTween = null;
				}
			});
		}

		#if !switch
		intendedScore = Highscore.getScore(songs[curSelected].songName, curDifficulty);
		intendedRating = Highscore.getRating(songs[curSelected].songName, curDifficulty);
		#end

		var bullShit:Int = 0;

		for (i in 0...iconArray.length)
		{
			if (iconArray[i] != null)
				iconArray[i].alpha = 0.6;
		}

		if (iconArray[curSelected] != null)
			iconArray[curSelected].alpha = 1;

		for (item in grpSongs.members)
		{
			if (item != null)
			{
				item.targetY = bullShit - curSelected;
				bullShit++;

				item.alpha = 0.6;

				if (item.targetY == 0)
				{
					item.alpha = 1;

					// Efecto de pulse en la canción seleccionada
					FlxTween.cancelTweensOf(item.scale);
					item.scale.set(1.05, 1.05);
					FlxTween.tween(item.scale, {x: 1, y: 1}, 0.3, {ease: FlxEase.expoOut});
				}
			}
		}

		// Pequeño bump al cambiar selección
		FlxG.camera.zoom = 1.02;

		changeDiff();

		#if HSCRIPT_ALLOWED
		StateScriptHandler.callOnScripts('onSelectionChanged', [curSelected]);
		StateScriptHandler.callOnScripts('onSongSelected', [songs[curSelected].songName]);
		#end
	}

	private function positionHighscore()
	{
		scoreText.x = FlxG.width - scoreText.width - 20;

		scoreBG.scale.x = FlxG.width - scoreText.x + 16;
		scoreBG.x = FlxG.width - (scoreBG.scale.x / 2);
		diffText.x = Std.int(scoreBG.x + (scoreBG.width / 2));
		diffText.x -= diffText.width / 2;
	}

	public static var difficultyStuff:Array<Dynamic> = [['Easy', '-easy'], ['Normal', ''], ['Hard', '-hard']];

	public static function boundTo(value:Float, min:Float, max:Float):Float
	{
		var newValue:Float = value;
		if (newValue < min)
			newValue = min;
		else if (newValue > max)
			newValue = max;
		return newValue;
	}

	public static function getCurrentWeekNumber():Int
	{
		return getWeekNumber(PlayState.storyWeek);
	}

	public static function getWeekNumber(num:Int):Int
	{
		var value:Int = 0;
		var weekNumber:Int = 0;

		if (songInfo != null && songInfo.songsWeeks != null)
			weekNumber = songInfo.songsWeeks.length;

		if (num < weekNumber)
		{
			value = num;
		}

		return value;
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

class SongMetadata
{
	public var songName:String = "";
	public var week:Int = 0;
	public var songCharacter:String = "";
	public var color:Int = -7179779;

	public function new(song:String, week:Int, songCharacter:String)
	{
		this.songName = song;
		this.week = week;
		this.songCharacter = songCharacter;
		if (week < funkin.menus.FreeplayState.coolColors.length)
		{
			this.color = funkin.menus.FreeplayState.coolColors[week];
		}
	}
}
