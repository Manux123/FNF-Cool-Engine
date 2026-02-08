package states;

import flixel.util.FlxSpriteUtil;
import flixel.input.FlxAccelerometer;
import Section.SwagSection;
import Song.SwagSong;
import shaders.WiggleEffect.WiggleEffectType;
import flixel.FlxBasic;
import debug.ChartingState;
import flixel.FlxCamera;
import flixel.FlxG;
import lime.app.Application;
import notes.NoteSkinSystem;
import states.RatingState;
import flixel.FlxGame;
import flixel.FlxObject;
import flixel.FlxSprite;
import objects.stages.Stage;
import flixel.FlxState;
import openfl.display.BitmapData;
import flixel.FlxSubState;
import flixel.addons.display.FlxGridOverlay;
import flixel.addons.effects.FlxTrail;
import flixel.addons.effects.FlxTrailArea;
import flixel.addons.effects.chainable.FlxEffectSprite;
import flixel.addons.effects.chainable.FlxWaveEffect;
import flixel.addons.transition.FlxTransitionableState;
import flixel.graphics.atlas.FlxAtlas;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.ui.FlxBar;
import flixel.util.FlxCollision;
import flixel.util.FlxColor;
import flixel.util.FlxSort;
import flixel.util.FlxStringUtil;
import flixel.util.FlxTimer;
import haxe.Json;
import flixel.graphics.frames.FlxFramesCollection;
import lime.utils.Assets;
import openfl.display.BlendMode;
import objects.hud.ScoreManager;
import objects.character.Character;
// notes
import notes.StrumNote;
import notes.Note;
import notes.NoteSplash;
import notes.NoteRenderer;
import openfl.display.StageQuality;
import openfl.filters.ShaderFilter;
import controls.KeyBindMenu;
import extensions.HScriptEventSystem;
#if mobileC
import ui.Mobilecontrols;
#end
#if desktop
import Discord.DiscordClient;
#end
#if sys
import sys.FileSystem;
#end
import debug.DebugConsole;

using StringTools;

class PlayState extends states.MusicBeatState
{
	public static var instance:PlayState = null; // epic shit

	#if mobileC
	var mcontrols:Mobilecontrols;
	#end

	// === OPTIMIZACIÓN Y FLEXIBILIDAD ===
	// Objeto reutilizable para evitar 'new FlxRect' cientos de veces por segundo en el update loop
	private var _reusableRect:FlxRect = new FlxRect();

	// === ADD HOOK SYSTEM ===
	public var onBeatHitHooks:Map<String, Int->Void> = new Map<String, Int->Void>();
	public var onStepHitHooks:Map<String, Int->Void> = new Map<String, Int->Void>();
	public var onUpdateHooks:Map<String, Float->Void> = new Map<String, Float->Void>();
	public var onNoteHitHooks:Map<String, Note->Void> = new Map<String, Note->Void>();
	public var onNoteMissHooks:Map<String, Note->Void> = new Map<String, Note->Void>();

	public static var curStage:String = '';
	public static var SONG:SwagSong;
	public static var isStoryMode:Bool = false;
	public static var storyWeek:Int = 0;
	public static var storyPlaylist:Array<String> = [];
	public static var storyDifficulty:Int = 1;
	public static var weekSong:Int = 0;
	public static var misses:Int = 0;
	public static var shits:Int = 0;
	public static var bads:Int = 0;
	public static var goods:Int = 0;
	public static var sicks:Int = 0;

	private var gfSing:Bool = false;
	#if desktop
	// Discord RPC variables
	var storyDifficultyText:String = "";
	var iconRPC:String = "";
	var songLength:Float = 0;
	var detailsText:String = "";
	var detailsPausedText:String = "";
	#end

	public var vocals:FlxSound;

	public var currentStage:Stage;

	var readya:FlxSprite;
	var readyCL:FlxSprite;
	var readyaIsntDestroyed:Bool = true;

	public var dad:Character;
	public var gf:Character;
	public var boyfriend:Character;

	public var notes:FlxTypedGroup<Note>;

	private var unspawnNotes:Array<Note> = [];

	var strumLiney:Float = 50;

	private var curSection:Int = 0;

	private var camFollow:FlxObject;

	private static var prevCamFollow:FlxObject;

	public var strumLineNotes:FlxTypedGroup<FlxSprite>;

	private var playerStrums:FlxTypedGroup<FlxSprite>;

	public static var cpuStrums:FlxTypedGroup<FlxSprite> = null;

	var camPos:FlxPoint;

	private var camZooming:Bool = false;

	public var curSong:String = "";

	private var gfSpeed:Int = 1;

	public var health:Float = 1;

	private var combo:Int = 0;

	public static var accuracy:Float = 0.00;

	private var totalNotesHit:Float = 0;
	private var totalPlayed:Int = 0;
	private var ss:Bool = false;

	private var healthBarBG:FlxSprite;
	private var healthBar:FlxBar;
	private var songPositionBar:Float = 0;

	public var noteRenderer:NoteRenderer;
	public var eventSystem:HScriptEventSystem;
	public var scoreManager:ScoreManager;

	var fullCombo:FlxText;
	var sickMode:FlxText;

	private var generatedMusic:Bool = false;

	public static var startingSong:Bool = false;

	public var iconP1:HealthIcon;
	public var iconP2:HealthIcon;
	public var camHUD:FlxCamera;
	public var camCountdown:FlxCamera;
	public var camGame:FlxCamera;

	var dialogue:Array<String> = [':bf:strange code', ':dad:>:]'];

	var notesAnim:Array<String> = ['LEFT', 'DOWN', 'UP', 'RIGHT'];

	var daNote:Note;
	var specialAnim:Bool = false;

	var songName:FlxText;
	var upperBoppers:FlxSprite;
	var bottomBoppers:FlxSprite;

	var fc:Bool = true;

	var wiggleShit:shaders.WiggleEffect = new shaders.WiggleEffect();

	var talking:Bool = true;
	private var SplashNote:NoteSplash;
	var grpNoteSplashes:FlxTypedGroup<NoteSplash>;

	public static var songScore:Int = 0;

	var scoreTxt:FlxText;

	public static var campaignScore:Int = 0;

	var defaultCamZoom:Float = 1.05;

	public static var daPixelZoom:Float = 6;

	// Movent Camera
	public static var theFunne:Bool = true;

	var funneEffect:FlxSprite;
	var inCutscene:Bool = false;

	public static var timeCurrently:Float = 0;
	public static var timeCurrentlyR:Float = 0;

	public static var dadnoteMovementXoffset:Int = 0;
	public static var dadnoteMovementYoffset:Int = 0;

	public static var bfnoteMovementXoffset:Int = 0;
	public static var bfnoteMovementYoffset:Int = 0;

	// OPTIMIZATION: Cache para sección actual
	private var cachedSection:SwagSection = null;
	private var cachedSectionIndex:Int = -1;

	// OPTIMIZATION: Timers para personajes
	private var dadHoldTimer:Float = 0;
	private var bfHoldTimer:Float = 0;
	private var gfHoldTimer:Float = 0;

	// OPTIMIZATION: Control de animaciones
	private var dadAnimFinished:Bool = true;
	private var bfAnimFinished:Bool = true;
	private var gfAnimFinished:Bool = true;

	// FIX: Constantes para control de animaciones
	private static inline var HOLD_THRESHOLD:Float = 0.001; // Conductor.stepCrochet * 4 * 0.01
	private static inline var SING_DURATION:Float = 0.6; // Duración de las animaciones de canto

	public static var isPlaying:Bool = false;

	override public function create()
	{
		instance = this;
		isPlaying = true;

		FlxG.mouse.visible = false;
		theFunne = FlxG.save.data.newInput;
		if (FlxG.sound.music != null)
			FlxG.sound.music.stop();

		if (FlxG.save.data.FPSCap)
			openfl.Lib.current.stage.frameRate = 120;
		else
			openfl.Lib.current.stage.frameRate = 240;

		// important
		if (SONG.stage == null)
			SONG.stage = 'stage_week1';

		curStage = SONG.stage;

		#if desktop
		// Making difficulty text for Discord Rich Presence.

		storyDifficultyText = CoolUtil.difficultyString();

		iconRPC = SONG.player2;

		// To avoid having duplicate images in Discord assets
		switch (iconRPC)
		{
			case 'monster-christmas':
				iconRPC = 'monster';
			case 'mom-car':
				iconRPC = 'mom';
		}

		// String that contains the mode defined here so it isn't necessary to call changePresence for each mode
		if (isStoryMode)
		{
			detailsText = "Story Mode: Week " + storyWeek;
		}
		else
		{
			detailsText = "Freeplay";
		}

		// String for when the game is paused
		detailsPausedText = "Paused - " + detailsText;

		// Updating Discord Rich Presence.
		updatePresence();
		#end

		// var gameCam:FlxCamera = FlxG.camera;
		camGame = new FlxCamera();
		camHUD = new FlxCamera();
		camHUD.bgColor.alpha = 0;

		camCountdown = new FlxCamera();
		camCountdown.bgColor.alpha = 0;

		FlxG.cameras.reset(camGame);
		FlxG.cameras.add(camHUD, false);
		FlxG.cameras.add(camCountdown, false);

		// FlxCamera.defaultCameras = [camGame];

		persistentUpdate = true;
		persistentDraw = true;

		dadnoteMovementXoffset = 0;
		dadnoteMovementYoffset = 0;

		bfnoteMovementXoffset = 0;
		bfnoteMovementYoffset = 0;

		MainMenuState.musicFreakyisPlaying = false;

		if (SONG == null)
			SONG = Song.loadFromJson('tutorial');

		grpNoteSplashes = new FlxTypedGroup<NoteSplash>();

		Conductor.mapBPMChanges(SONG);
		Conductor.changeBPM(SONG.bpm);

		switch (SONG.song.toLowerCase())
		{
			case 'tutorial':
				dialogue = ["Hey you're pretty cute.", 'Use the arrow keys to keep up \nwith me singing.'];
			case 'bopeebo':
				dialogue = [
					'HEY!',
					"You think you can just sing\nwith my daughter like that?",
					"If you want to date her...",
					"You're going to have to go \nthrough ME first!"
				];
			case 'fresh':
				dialogue = ["Not too shabby boy.", ""];
			case 'dadbattle':
				dialogue = [
					"gah you think you're hot stuff?",
					"If you can beat me here...",
					"Only then I will even CONSIDER letting you\ndate my daughter!"
				];
			case 'senpai':
				dialogue = dialogueFile('senpaiDialogue');
			case 'roses':
				dialogue = dialogueFile('rosesDialogue');
			case 'thorns':
				dialogue = dialogueFile('thornsDialogue');
		}

		setCurrentStage();
		setupStageCallbacks();

		var gfVersion:String = 'gf';

		if (SONG.gfVersion != null)
			gfVersion = SONG.gfVersion;

		gf = new Character(400, 130, gfVersion);
		gf.scrollFactor.set(0.95, 0.95);

		dad = new Character(100, 100, SONG.player2);

		camPos = new FlxPoint(dad.getGraphicMidpoint().x, dad.getGraphicMidpoint().y);

		boyfriend = new Character(770, 450, SONG.player1, true);

		applyStagePositions();

		// REPOSITIONING PER STAGE

		if (SONG.song.toLowerCase() == 'test')
		{
			dad.y += 510;
			dad.x += 250;
		}

		if (!FlxG.save.data.gfbye || !currentStage.hideGirlfriend)
			add(gf);

		add(dad);
		add(boyfriend);

		var dialogueBox:DialogueBox = new DialogueBox(false, dialogue);
		// doof.x += 70;
		// doof.y = FlxG.height * 0.5;
		dialogueBox.scrollFactor.set();
		dialogueBox.finishThing = startCountdown;

		Conductor.songPosition = -5000;

		if (FlxG.save.data.downscroll)
			strumLiney = FlxG.height - 165;

		strumLineNotes = new FlxTypedGroup<FlxSprite>();
		add(strumLineNotes);
		if (FlxG.save.data.notesplashes)
		{
			add(grpNoteSplashes);
			var sploosh = new NoteSplash(100, 100, 0);
			grpNoteSplashes.add(sploosh);
			sploosh.alpha = 0.0;

			trace(sploosh.frames);
		}

		playerStrums = new FlxTypedGroup<FlxSprite>();
		cpuStrums = new FlxTypedGroup<FlxSprite>();

		generateSong(SONG.song);

		// Initialize ScoreManager
		scoreManager = new ScoreManager();
		scoreManager.reset();
		trace('[PlayState] ScoreManager initialized');

		// Initialize HScriptEventSystem
		eventSystem = new HScriptEventSystem();
		eventSystem.playState = this;
		eventSystem.debugMode = false; // Set true for debugging
		if (SONG != null && SONG.song != null)
		{
			eventSystem.loadScript(SONG.song, "events");
			trace('[PlayState] Loaded events for: ${SONG.song}');
		}

		camFollow = new FlxObject(0, 0, 1, 1);

		camFollow.setPosition(camPos.x, camPos.y);

		if (prevCamFollow != null)
		{
			camFollow = prevCamFollow;
			prevCamFollow = null;
		}

		add(camFollow);

		FlxG.camera.follow(camFollow, LOCKON, 0.01);

		FlxG.camera.zoom = defaultCamZoom;
		FlxG.camera.focusOn(camFollow.getPosition());

		FlxG.worldBounds.set(0, 0, FlxG.width, FlxG.height);

		FlxG.fixedTimestep = false;

		healthBarBG = new FlxSprite(0, FlxG.height * 0.9).loadGraphic(Paths.image('UI/healthBar'));
		if (FlxG.save.data.downscroll)
			healthBarBG.y = 50;
		healthBarBG.screenCenter(X);
		healthBarBG.scrollFactor.set();
		add(healthBarBG);

		healthBar = new FlxBar(healthBarBG.x + 4, healthBarBG.y + 4, RIGHT_TO_LEFT, Std.int(healthBarBG.width - 8), Std.int(healthBarBG.height - 8), this,
			'health', 0, 2);
		healthBar.scrollFactor.set();

		var cpuColor = 0xFFa5004d;
		var playerColor = 0xFF31b0d1;
		switch (SONG.player1.toLowerCase())
		{
			case 'bf':
				playerColor = 0xFF31b0d1;
			case 'bf-pixel':
				playerColor = 0xFF7bd6f6;
			case 'bf-car':
				playerColor = 0xFF31b0d1;
			case 'bf-christmas':
				playerColor = 0xFF31b0d1;
			default:
				playerColor = 0xFF31b0d1;
		}

		switch (SONG.player2.toLowerCase())
		{
			case 'gf':
				cpuColor = 0xFFa5004d;
			case 'dad':
				cpuColor = 0xFFaf66ce;
			case 'spooky':
				cpuColor = 0xFFd57e00;
			case 'pico':
				cpuColor = 0xFFb7d855;
			case 'mom' | 'mom-car':
				cpuColor = 0xFFd8558e;
			case 'parents-christmas':
				cpuColor = 0xFFaf66ce;
			case 'monster-christmas' | 'monster':
				cpuColor = 0xFFf3ff6e;
			case 'senpai' | 'senpai-angry':
				cpuColor = 0xFFffaa6f;
			case 'spirit':
				cpuColor = 0xFFff3c6e;
			case 'bf-pixel-enemy':
				cpuColor = 0xFF7bd6f6;
			default:
				cpuColor = 0xFFFF0000;
		}

		healthBar.createFilledBar(cpuColor, playerColor);

		// healthBar
		add(healthBar);

		scoreTxt = new FlxText(45, healthBarBG.y + 50, 0, "", 32);
		scoreTxt.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 4, 1);
		scoreTxt.color = FlxColor.WHITE;
		scoreTxt.size = 22;
		scoreTxt.y -= 350;
		scoreTxt.scrollFactor.set();

		var versionShit:FlxText = new FlxText(5, FlxG.height - 19, 0, "FNF Cool Engine BETA - v" + Application.current.meta.get('version'), 12);
		versionShit.scrollFactor.set();
		versionShit.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(versionShit);

		var grpDataShit:FlxTypedGroup<FlxText> = new FlxTypedGroup<FlxText>();

		if (FlxG.save.data.sickmode)
		{
			sickMode = new FlxText(5, FlxG.height - 19, 0, "Sick Mode", 12);
			sickMode.scrollFactor.set();
			sickMode.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			sickMode.y -= 20;
			sickMode.visible = false;
			sickMode.ID = 1;
			grpDataShit.add(sickMode);
		}

		grpDataShit.forEach(function(spr:FlxText)
		{
			spr.visible = true;
			add(spr);
			spr.cameras = [camHUD];
			if (spr.ID == 0 && FlxG.save.data.sickmode)
			{
				spr.y -= 20;
			}
		});

		iconP1 = new HealthIcon(SONG.player1, true);
		iconP1.y = healthBar.y - (iconP1.height / 2);
		add(iconP1);

		iconP2 = new HealthIcon(SONG.player2, false);
		iconP2.y = healthBar.y - (iconP2.height / 2);
		add(iconP2);
		add(scoreTxt);

		strumLineNotes.cameras = [camHUD];
		notes.cameras = [camHUD];
		grpNoteSplashes.cameras = [camHUD];
		healthBar.cameras = [camHUD];
		healthBarBG.cameras = [camHUD];
		iconP1.cameras = [camHUD];
		iconP2.cameras = [camHUD];
		scoreTxt.cameras = [camHUD];
		dialogueBox.cameras = [camHUD];
		versionShit.cameras = [camHUD];

		#if mobileC
		mcontrols = new Mobilecontrols();
		switch (mcontrols.mode)
		{
			case VIRTUALPAD_RIGHT | VIRTUALPAD_LEFT | VIRTUALPAD_CUSTOM:
				controls.setVirtualPad(mcontrols._virtualPad, FULL, NONE);
			case HITBOX:
				controls.setHitBox(mcontrols._hitbox);
			default:
		}
		trackedinputs = controls.trackedinputs;
		controls.trackedinputs = [];

		var camcontrol = new FlxCamera();
		FlxG.cameras.add(camcontrol);
		camcontrol.bgColor.alpha = 0;
		mcontrols.cameras = [camcontrol];

		mcontrols.visible = false;
		add(mcontrols);
		#end

		startingSong = true;

		if (isStoryMode)
		{
			switch (curSong.toLowerCase())
			{
				case "winter-horrorland":
					var blackScreen:FlxSprite = new FlxSprite(0, 0).makeGraphic(Std.int(FlxG.width * 2), Std.int(FlxG.height * 2), FlxColor.BLACK);
					add(blackScreen);
					blackScreen.scrollFactor.set();
					camHUD.visible = false;

					new FlxTimer().start(0.1, function(tmr:FlxTimer)
					{
						remove(blackScreen);
						FlxG.sound.play(Paths.sound('Lights_Turn_On'));
						camFollow.y = -2050;
						camFollow.x += 200;
						FlxG.camera.focusOn(camFollow.getPosition());
						FlxG.camera.zoom = 1.5;

						new FlxTimer().start(0.8, function(tmr:FlxTimer)
						{
							camHUD.visible = true;
							remove(blackScreen);
							FlxTween.tween(FlxG.camera, {zoom: defaultCamZoom}, 2.5, {
								ease: FlxEase.quadInOut,
								onComplete: function(twn:FlxTween)
								{
									vsReady();
								}
							});
						});
					});

				case 'senpai' | 'thorns' | 'roses':
					if (curSong.toLowerCase() == 'roses')
						FlxG.sound.play(Paths.sound('ANGRY'));
					schoolIntro(dialogueBox);

				default:
					vsReady();
			}
		}
		else
		{
			switch (curSong.toLowerCase())
			{
				default:
					vsReady();
			}
		}

		super.create();
	}

	function setCurrentStage()
	{
		currentStage = new Stage(curStage);
		add(currentStage);

		defaultCamZoom = currentStage.defaultCamZoom;
	}

	function applyStagePositions():Void
	{
		// Aplicar posiciones base del stage
		if (boyfriend != null)
			boyfriend.setPosition(currentStage.boyfriendPosition.x, currentStage.boyfriendPosition.y);

		if (dad != null)
			dad.setPosition(currentStage.dadPosition.x, currentStage.dadPosition.y);

		if (gf != null)
		{
			gf.setPosition(currentStage.gfPosition.x, currentStage.gfPosition.y);

			// Ocultar GF si el stage lo requiere
			if (currentStage.hideGirlfriend)
				gf.visible = false;
		}

		switch (SONG.player2)
		{
			case 'gf':
				dad.setPosition(gf.x, gf.y);
				gf.visible = false;
				if (isStoryMode)
				{
					camPos.x += 600;
					tweenCamIn();
				}
			case "spooky":
				dad.y += 200;
			case "monster":
				dad.y += 100;
			case 'monster-christmas':
				dad.y += 130;
			case 'dad':
				camPos.x += 400;
			case 'pico':
				camPos.x += 600;
				dad.y += 300;
			case 'parents-christmas':
				dad.x -= 500;
			case 'senpai' | 'senpai-angry':
				dad.x += 150;
				dad.y += 360;
				camPos.set(dad.getGraphicMidpoint().x + 300 + dadnoteMovementXoffset, dad.getGraphicMidpoint().y + dadnoteMovementYoffset);
			case 'spirit':
				dad.x -= 150;
				dad.y += 100;
				camPos.set(dad.getGraphicMidpoint().x + 300 + dadnoteMovementXoffset, dad.getGraphicMidpoint().y + dadnoteMovementYoffset);
		}
	}

	function schoolIntro(?dialogueBox:DialogueBox):Void
	{
		var black:FlxSprite = new FlxSprite(-100, -100).makeGraphic(FlxG.width * 2, FlxG.height * 2, FlxColor.BLACK);
		black.scrollFactor.set();
		add(black);

		var red:FlxSprite = new FlxSprite(-100, -100).makeGraphic(FlxG.width * 2, FlxG.height * 2, 0xFFff1b31);
		red.scrollFactor.set();

		var senpaiEvil:FlxSprite = new FlxSprite();
		senpaiEvil.frames = Paths.characterSprite('weeb/senpaiCrazy');
		senpaiEvil.animation.addByPrefix('idle', 'Senpai Pre Explosion', 24, false);
		senpaiEvil.setGraphicSize(Std.int(senpaiEvil.width * 6));
		senpaiEvil.scrollFactor.set();
		senpaiEvil.updateHitbox();
		senpaiEvil.screenCenter();

		if (SONG.song.toLowerCase() == 'roses' || SONG.song.toLowerCase() == 'thorns')
		{
			remove(black);

			if (SONG.song.toLowerCase() == 'thorns')
			{
				add(red);
			}
		}

		new FlxTimer().start(0.3, function(tmr:FlxTimer)
		{
			black.alpha -= 0.15;

			if (black.alpha > 0)
			{
				tmr.reset(0.3);
			}
			else
			{
				if (dialogueBox != null)
				{
					inCutscene = true;
					if (SONG.song.toLowerCase() == 'thorns')
					{
						add(senpaiEvil);
						senpaiEvil.alpha = 0;
						new FlxTimer().start(0.3, function(swagTimer:FlxTimer)
						{
							senpaiEvil.alpha += 0.15;
							if (senpaiEvil.alpha < 1)
							{
								swagTimer.reset();
							}
							else
							{
								senpaiEvil.animation.play('idle');
								FlxG.sound.play(Paths.sound('Senpai_Dies'), 1, false, null, true, function()
								{
									remove(senpaiEvil);
									remove(red);
									FlxG.camera.fade(FlxColor.WHITE, 0.01, true, function()
									{
										add(dialogueBox);
									}, true);
								});
								new FlxTimer().start(3.2, function(deadTime:FlxTimer)
								{
									FlxG.camera.fade(FlxColor.WHITE, 1.6, false);
								});
							}
						});
					}
					else
					{
						add(dialogueBox);
					}
				}
				else
					vsReady();

				remove(black);
			}
		});
	}

	var startTimer:FlxTimer;
	var CPUvsCPUMode:Bool = false;
	var ready:FlxSprite;
	var set:FlxSprite;
	var go:FlxSprite;

	var introAssets:Map<String, Array<String>> = new Map<String, Array<String>>();
	var altSuffix:String = '';
	var introAlts:Array<String> = [];

	function startCountdown():Void
	{
		if (startedCountdown)
			return;

		#if mobileC
		mcontrols.visible = true;
		#end

		inCutscene = false;

		generateStaticArrows(0);
		generateStaticArrows(1);
		/*
			if (noteRenderer == null)
			{
				noteRenderer = new NoteRenderer(notes, playerStrums, cpuStrums);
				noteRenderer.downscroll = FlxG.save.data.downscroll;
				noteRenderer.strumLineY = strumLiney;
				noteRenderer.noteSpeed = SONG.speed;
				trace('[PlayState] Strums: player=' + playerStrums.length + ', cpu=' + cpuStrums.length);
		}*/

		talking = false;
		readyaIsntDestroyed = false; // This make so readya IS destroyed so it doesn't crashes the fucking game
		startedCountdown = true;
		Conductor.songPosition = 0;
		Conductor.songPosition -= Conductor.crochet * 5;

		var swagCounter:Int = 0;

		introAssets = new Map<String, Array<String>>();
		introAssets.set('default', ['UI/normal/ready', "UI/normal/set", "UI/normal/go"]);
		introAssets.set('school', ['UI/pixelUI/ready-pixel', 'UI/pixelUI/set-pixel', 'UI/pixelUI/date-pixel']);
		introAssets.set('schoolEvil', ['UI/pixelUI/ready-pixel', 'UI/pixelUI/set-pixel', 'UI/pixelUI/date-pixel']);

		altSuffix = (curStage.startsWith('school') ? '-pixel' : '');
		introAlts = introAssets.exists(curStage) ? introAssets.get(curStage) : introAssets.get('default');

		startTimer = new FlxTimer().start(Conductor.crochet / 1000, function(tmr:FlxTimer)
		{
			dad.dance();
			gf.dance();
			boyfriend.dance();

			switch (swagCounter)
			{
				case 0:
					readya.visible = false;
					FlxG.sound.play(Paths.sound('intro3' + altSuffix), 0.6);
				case 1:
					getCountdown(ready, 0, 2);
				case 2:
					getCountdown(set, 1, 1);
				case 3:
					getCountdown(go, 2, 32 // nose
						, true);
					finishCountdown();
			}
			swagCounter += 1;
		}, 5);
	}

	var previousFrameTime:Int = 0;
	var lastReportedPlayheadPosition:Int = 0;
	var songTime:Float = 0;

	function finishCountdown():Void
	{
		if (boyfriend.animOffsets.exists('hey'))
			boyfriend.playAnim('hey', false);
		if (dad.animOffsets.exists('hey'))
			dad.playAnim('hey', false);
		if (gf.animOffsets.exists('cheer'))
			gf.playAnim('cheer', false);
		FlxG.camera.flash(FlxColor.WHITE, 1);
	}

	function getCountdown(asset:FlxSprite, sip:Int, ?wea:Int, ?isGo = false)
	{
		asset = new FlxSprite().loadGraphic(Paths.image(introAlts[sip]));
		asset.cameras = [camCountdown];
		asset.scrollFactor.set();

		asset.scale.set(0.7, 0.7);

		if (curStage.startsWith('school'))
			asset.setGraphicSize(Std.int(asset.width * daPixelZoom));

		asset.updateHitbox();

		asset.screenCenter();

		asset.y -= 100;
		add(asset);
		FlxTween.tween(asset, {y: asset.y += 100, alpha: 0}, Conductor.crochet / 1000, {
			ease: FlxEase.cubeInOut,
			onComplete: function(twn:FlxTween)
			{
				asset.destroy();
			}
		});

		if (!isGo)
			FlxG.sound.play(Paths.sound('intro' + wea + altSuffix), 0.6);
		else
			FlxG.sound.play(Paths.sound('introGo' + altSuffix), 0.6);
	}

	function vsReady()
	{
		FlxG.mouse.visible = true;

		if (!curStage.startsWith('school'))
		{
			readya = new FlxSprite().loadGraphic(Paths.image('UI/normal/ready'));
			readya.scrollFactor.set();
			readya.updateHitbox();
			readya.screenCenter();
			add(readya);

			readyCL = new FlxSprite().loadGraphic(Paths.image('UI/normal/readyCL'));
			readyCL.scrollFactor.set();
			readyCL.updateHitbox();
			readyCL.screenCenter();
			readyCL.visible = false;
			add(readyCL);
		}
		else
		{
			readya = new FlxSprite().loadGraphic(Paths.image('UI/pixelUI/ready-pixel'));
			readya.scrollFactor.set();
			readya.scale.set(6, 6);
			readya.updateHitbox();
			readya.screenCenter();
			add(readya);

			readyCL = new FlxSprite().loadGraphic(Paths.image('UI/pixelUI/ready-pixel'));
			readyCL.scrollFactor.set();
			readyCL.scale.set(6, 6);
			readyCL.color = 0xFF5D5D5D;
			readyCL.updateHitbox();
			readyCL.screenCenter();
			readyCL.visible = false;
			add(readyCL);
		}
	}

	function startSong():Void
	{
		if (!songEnd)
		{
			startingSong = false;

			previousFrameTime = FlxG.game.ticks;
			lastReportedPlayheadPosition = 0;

			if (!paused)
				FlxG.sound.playMusic(Paths.inst(PlayState.SONG.song), 1, false);
			FlxG.sound.music.onComplete = endSong;
			vocals.play();

			#if desktop
			// Song duration in a float, useful for the time left feature
			songLength = FlxG.sound.music.length;

			// Updating Discord Rich Presence (with Time Left)

			updatePresence();
			#end
		}
	}

	var debugNum:Int = 0;

	private function generateSong(dataPath:String):Void
	{
		var songData = SONG;
		Conductor.changeBPM(songData.bpm);

		curSong = songData.song;

		if (SONG.needsVoices)
			vocals = new FlxSound().loadEmbedded(Paths.voices(PlayState.SONG.song));
		else
			vocals = new FlxSound();

		FlxG.sound.list.add(vocals);

		notes = new FlxTypedGroup<Note>();
		add(notes);

		var noteData:Array<SwagSection>;

		// NEW SHIT
		noteData = songData.notes;

		var playerCounter:Int = 0;

		var daBeats:Int = 0; // Not exactly representative of 'daBeats' lol, just how much it has looped
		for (section in noteData)
		{
			var coolSection:Int = Std.int(section.lengthInSteps / 4);

			for (songNotes in section.sectionNotes)
			{
				var daStrumTime:Float = songNotes[0];
				var daNoteData:Int = Std.int(songNotes[1] % 4);

				var gottaHitNote:Bool = section.mustHitSection;

				if (songNotes[1] > 3)
				{
					gottaHitNote = !section.mustHitSection;
				}

				var oldNote:Note;
				if (unspawnNotes.length > 0)
					oldNote = unspawnNotes[Std.int(unspawnNotes.length - 1)];
				else
					oldNote = null;

				var swagNote:Note = new Note(daStrumTime, daNoteData, oldNote);
				swagNote.sustainLength = songNotes[2];
				swagNote.scrollFactor.set(0, 0);

				var susLength:Float = swagNote.sustainLength;

				susLength = susLength / Conductor.stepCrochet;
				unspawnNotes.push(swagNote);

				for (susNote in 0...Math.floor(susLength))
				{
					oldNote = unspawnNotes[Std.int(unspawnNotes.length - 1)];

					var sustainNote:Note = new Note(daStrumTime + (Conductor.stepCrochet * susNote) + Conductor.stepCrochet, daNoteData, oldNote, true);
					sustainNote.scrollFactor.set();
					unspawnNotes.push(sustainNote);

					sustainNote.mustPress = gottaHitNote;

					if (sustainNote.mustPress)
					{
						sustainNote.x += FlxG.width / 2; // general offset
					}
				}

				swagNote.mustPress = gottaHitNote;

				if (swagNote.mustPress)
				{
					swagNote.x += FlxG.width / 2; // general offset
				}
				else
				{
				}
			}
			daBeats += 1;
		}

		unspawnNotes.sort(sortByShit);

		generatedMusic = true;
	}

	function sortByShit(Obj1:Note, Obj2:Note):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1.strumTime, Obj2.strumTime);
	}

	private function generateStaticArrows(player:Int):Void
	{
		for (i in 0...4)
		{
			var babyArrow:StrumNote = new StrumNote(0, strumLiney, i);
			babyArrow.updateHitbox();
			babyArrow.scrollFactor.set();

			if (!isStoryMode)
			{
				babyArrow.y -= 10;
				babyArrow.alpha = 0;
				FlxTween.tween(babyArrow, {y: babyArrow.y + 10, alpha: 1}, 1, {ease: FlxEase.circOut, startDelay: 0.5 + (0.2 * i)});
			}

			babyArrow.ID = i;

			switch (player)
			{
				case 0:
					cpuStrums.add(babyArrow);
					if (FlxG.save.data.middlescroll)
					{
						cpuStrums.members[i].visible = false;
					}
				case 1:
					playerStrums.add(babyArrow);
					if (FlxG.save.data.middlescroll)
					{
						playerStrums.members[i].x -= 250;
					}
			}

			babyArrow.animation.play('static');
			babyArrow.x += 50;
			babyArrow.x += ((FlxG.width / 2) * player) + 50;

			cpuStrums.forEach(function(spr:FlxSprite)
			{
				spr.centerOffsets(); // CPU arrows start out slightly off-center
			});

			playerStrums.forEach(function(spr:FlxSprite)
			{
				spr.centerOffsets(); // player arrows start out slightly off-center
			});

			strumLineNotes.add(babyArrow);
		}
	}

	function tweenCamIn():Void
	{
		FlxTween.tween(FlxG.camera, {zoom: 1.3}, (Conductor.stepCrochet * 4 / 1000), {ease: FlxEase.elasticInOut});
	}

	override function openSubState(SubState:FlxSubState)
	{
		if (paused)
		{
			if (FlxG.sound.music != null)
			{
				FlxG.sound.music.pause();
				vocals.pause();
			}

			#if desktop
			updatePresence(true);
			#end
			if (!startTimer.finished)
				startTimer.active = false;
		}

		super.openSubState(SubState);
	}

	override function closeSubState()
	{
		if (paused)
		{
			if (FlxG.sound.music != null && !startingSong)
			{
				resyncVocals();
			}

			if (!startTimer.finished)
				startTimer.active = true;
			paused = false;

			#if desktop
			if (startTimer.finished)
			{
				updatePresence();
			}
			else
			{
				updatePresence();
			}
			#end
		}

		super.closeSubState();
	}

	function dialogueFile(dialogue:String)
	{
		return CoolUtil.coolTextFile(Paths.songsTxt('${SONG.song.toLowerCase()}/${dialogue}'));
		trace('LOADING ' + dialogue);
	}

	public static var ranking:String = "N/A";

	function resyncVocals():Void
	{
		vocals.pause();

		FlxG.sound.music.play();
		Conductor.songPosition = FlxG.sound.music.time;
		vocals.time = Conductor.songPosition;
		vocals.play();

		#if desktop
		updatePresence();
		#end
	}

	public var paused:Bool = false;

	var startedCountdown:Bool = false;
	var canPause:Bool = true;

	override public function update(elapsed:Float)
	{
		if (FlxG.keys.justPressed.CONTROL)
			CPUvsCPUMode = false;

		songPositionBar = Conductor.songPosition;

		eventSystem.triggerUpdateEvents(elapsed);
		eventSystem.triggerConditionalEvents();
		for (hook in onUpdateHooks)
			hook(elapsed);

		if (readyaIsntDestroyed)
		{
			if (FlxG.mouse.overlaps(readya))
			{
				readyCL.visible = true;
				readya.visible = false;
				if (FlxG.mouse.justPressed)
				{
					FlxG.mouse.visible = false;
					readyCL.destroy();
					readya.destroy();
					startCountdown();
				}
			}
			else if (!FlxG.mouse.overlaps(readya))
			{
				readyCL.visible = false;
				readya.visible = true;
			}
		}

		#if debug
		DebugConsole.update();
		#end

		super.update(elapsed);

		updateCharacterAnimations(elapsed);

		if (dad.curCharacter == 'spirit')
		{
			dad.y += Mathf.sineByTime(elapsed) / 2;
		}

		// Sync legacy variables from ScoreManager
		songScore = scoreManager.score;
		misses = scoreManager.misses;
		accuracy = scoreManager.accuracy;

		if (FlxG.save.data.accuracyDisplay)
			scoreTxt.text = scoreManager.getHUDText(); // ✅ Or use your custom format
		else
			scoreTxt.text = 'Score: ${songScore}\nMisses: ${misses}';

		if (FlxG.keys.justPressed.ENTER && startedCountdown && canPause)
		{
			pauseMenu();
		}

		if (FlxG.keys.justPressed.SEVEN)
		{
			FlxG.switchState(new ChartingState());
		}

		if (FlxG.keys.justPressed.EIGHT)
		{
			FlxG.switchState(new debug.StageEditor(SONG.stage));
		}

		iconP1.setGraphicSize(Std.int(FlxMath.lerp(150, iconP1.width, 0.50)));
		iconP2.setGraphicSize(Std.int(FlxMath.lerp(150, iconP2.width, 0.50)));

		iconP1.updateHitbox();
		iconP2.updateHitbox();

		var iconOffset:Int = 26;

		iconP1.x = healthBar.x + (healthBar.width * (FlxMath.remapToRange(healthBar.percent, 0, 100, 100, 0) * 0.01) - iconOffset);
		iconP2.x = healthBar.x + (healthBar.width * (FlxMath.remapToRange(healthBar.percent, 0, 100, 100, 0) * 0.01)) - (iconP2.width - iconOffset);

		if (health > 2)
			health = 2;

		if (healthBar.percent < 20)
			iconP1.animation.curAnim.curFrame = 1;
		else
			iconP1.animation.curAnim.curFrame = 0;

		if (healthBar.percent > 80)
			iconP2.animation.curAnim.curFrame = 1;
		else
			iconP2.animation.curAnim.curFrame = 0;

		if (startingSong)
		{
			if (startedCountdown)
			{
				Conductor.songPosition += FlxG.elapsed * 1000;
				if (Conductor.songPosition >= 0)
					startSong();
			}
		}
		else
		{
			Conductor.songPosition += FlxG.elapsed * 1000;

			if (!paused)
			{
				songTime += FlxG.game.ticks - previousFrameTime;
				previousFrameTime = FlxG.game.ticks;

				// Interpolation type beat
				if (Conductor.lastSongPos != Conductor.songPosition)
				{
					songTime = (songTime + Conductor.songPosition) / 2;
					Conductor.lastSongPos = Conductor.songPosition;
				}
			}
		}

		if (vocals != null && SONG.needsVoices)
		{
			if (vocals.volume < 1)
			{
				vocals.volume += elapsed * 2; // Aumenta 2 por segundo
				if (vocals.volume > 1)
					vocals.volume = 1;
			}
		}

		if (generatedMusic && PlayState.SONG.notes[Std.int(curStep / 16)] != null)
			camMovement(PlayState.SONG.notes[Std.int(curStep / 16)].mustHitSection, elapsed);

		for (char in [boyfriend, dad])
		{
			if (char != null && char.animation.curAnim != null && char.animation.curAnim.name.startsWith('idle'))
			{
				if (char == boyfriend)
				{
					bfnoteMovementXoffset = 0;
					bfnoteMovementYoffset = 0;
				}
				else
				{
					dadnoteMovementXoffset = 0;
					dadnoteMovementYoffset = 0;
				}
			}
		}

		if (camZooming)
		{
			FlxG.camera.zoom = FlxMath.lerp(FlxG.camera.zoom, defaultCamZoom, FlxMath.bound(elapsed * 3.125, 0, 1));
			camHUD.zoom = FlxMath.lerp(camHUD.zoom, 1, FlxMath.bound(elapsed * 3.125, 0, 1));
		}

		FlxG.watch.addQuick("beats", curBeat);
		FlxG.watch.addQuick("steps", curStep);

		if (health <= 0)
			gameOver();

		if (unspawnNotes[0] != null)
		{
			if (unspawnNotes[0].strumTime - Conductor.songPosition < 1500)
			{
				var dunceNote:Note = unspawnNotes[0];
				notes.add(dunceNote);

				var index:Int = unspawnNotes.indexOf(dunceNote);
				unspawnNotes.splice(index, 1);
			}
		}

		if (generatedMusic)
		{
			notes.forEachAlive(function(daNote:Note)
			{
				// ========================================
				// ACTUALIZAR POSICIÓN DE LA NOTA
				// ========================================

				var strumLine:FlxSprite = null;

				if (daNote.mustPress)
				{
					if (playerStrums != null && daNote.noteData < playerStrums.length)
						strumLine = playerStrums.members[daNote.noteData];
				}
				else
				{
					if (cpuStrums != null && daNote.noteData < cpuStrums.length)
						strumLine = cpuStrums.members[daNote.noteData];
				}

				if (strumLine != null)
				{
					var distance = 0.45 * (Conductor.songPosition - daNote.strumTime) * FlxMath.roundDecimal(SONG.speed, 2);

					if (FlxG.save.data.downscroll)
						daNote.y = strumLine.y + distance;
					else
						daNote.y = strumLine.y - distance;
				}

				// Clipping para sustain notes
				if (daNote.isSustainNote && strumLine != null)
				{
					if (FlxG.save.data.downscroll)
					{
						if (daNote.y - daNote.offset.y * daNote.scale.y + daNote.height >= strumLine.y && daNote.y + daNote.offset.y * daNote.scale.y < strumLine.y)
						{
							var swagRect = new FlxRect(0, strumLine.y - daNote.y, daNote.width * 2, daNote.height * 2);
							swagRect.height /= daNote.scale.y;
							swagRect.y /= daNote.scale.y;
							daNote.clipRect = swagRect;
						}
					}
					else
					{
						if (daNote.y + daNote.offset.y * daNote.scale.y <= strumLine.y && daNote.y + daNote.height >= strumLine.y)
						{
							var swagRect = new FlxRect(0, 0, daNote.width / daNote.scale.x, daNote.height / daNote.scale.y);
							swagRect.height = (strumLine.y - daNote.y) / daNote.scale.y;
							daNote.clipRect = swagRect;
						}
					}
				}

				// ========================================
				// CPU NOTES - Segunda verificación (con animaciones)
				// ========================================
				if (!daNote.mustPress && daNote.wasGoodHit)
				{
					if (SONG.song != 'Tutorial')
						camZooming = true;

					var altAnim:String = "";

					if (SONG.notes[Math.floor(curStep / 16)] != null)
					{
						if (SONG.notes[Math.floor(curStep / 16)].altAnim)
							altAnim = '-alt';

						gf.canSing = SONG.notes[Math.floor(curStep / 16)].bothSing ? true : SONG.notes[Math.floor(curStep / 16)].gfSing;
						if (gf.canSing == true && !SONG.notes[Math.floor(curStep / 16)].bothSing)
						{
							dad.canSing = false;
							dad.dance();
							camPos.x -= 100;
							camPos.y -= 250;
							tweenCamIn();
						}
						else
							dad.canSing = true;

						if (!gf.canSing && gfAnimFinished && gf.animation.curAnim.name.startsWith('sing'))
							gf.dance();
					}

					if (FlxG.save.data.notesplashes)
						spawnNoteSplashOnNote(daNote, 0);

					if (dad.canSing)
						characterSing(dad, Std.int(Math.abs(daNote.noteData)), altAnim);

					if (gf.canSing)
						characterSing(gf, Std.int(Math.abs(daNote.noteData)), altAnim);

					cpuStrums.forEach(function(spr:FlxSprite)
					{
						if (Math.abs(daNote.noteData) == spr.ID)
						{
							spr.animation.play('confirm', true);
						}
						if (spr.animation.curAnim.name == 'confirm' && !curStage.startsWith('school') && (NoteSkinSystem.offsetDefault))
						{
							spr.centerOffsets();
							spr.offset.x -= 13;
							spr.offset.y -= 13;
						}
						else
							spr.centerOffsets();
					});

					dad.holdTimer = 0;

					if (SONG.needsVoices)
						vocals.volume = 1;

					daNote.kill();
					notes.remove(daNote, true);
					daNote.destroy();
					return;
				}

				// ========================================
				// MIDDLESCROLL
				// ========================================
				if (!daNote.mustPress && FlxG.save.data.middlescroll)
					daNote.alpha = 0;

				// ========================================
				// VERIFICACIÓN DE NOTAS FUERA DE PANTALLA
				// ========================================
				if (daNote.y < -daNote.height && !FlxG.save.data.downscroll || daNote.y >= strumLiney + 106 && FlxG.save.data.downscroll)
				{
					if (daNote.isSustainNote && daNote.wasGoodHit)
					{
						daNote.kill();
						notes.remove(daNote, true);
						daNote.destroy();
						return;
					}
					else if (daNote.mustPress)
					{
						vocals.volume = 0;
						noteMiss(daNote.noteData);
					}

					daNote.active = false;
					daNote.visible = false;
					daNote.kill();
					notes.remove(daNote, true);
					daNote.destroy();
				}
			});
		}

		cpuStrums.forEach(function(spr:FlxSprite)
		{
			if (spr.animation.finished)
			{
				spr.animation.play('static');
				spr.centerOffsets();
			}
		});

		if (!inCutscene && generatedMusic)
		{
			keyShit(); // ✅ Una sola llamada por frame
		}
	}

	function updatePresence(?paused:Bool = false)
	{
		#if desktop
		var details:String = (paused ? "Paused - " : "") + (isStoryMode ? "Story Mode: Week " + storyWeek : "Freeplay");
		var state:String = SONG.song + " (" + CoolUtil.difficultyString() + ")";

		// Solo añade detalles de puntuación si no está pausado para ahorrar recursos
		if (!paused)
			state += "\nAcc: " + Mathf.getPercentage(accuracy, 2) + "% | Score: " + songScore + " | Misses: " + misses;

		DiscordClient.changePresence(details, state, iconRPC, !paused, songLength - Conductor.songPosition);
		#end
	}

	var songEnd:Bool = false;

	public function endSong():Void
	{
		songEnd = true;
		canPause = false;
		isPlaying = false;
		FlxG.sound.music.volume = 0;
		vocals.volume = 0;
		if (SONG.validScore)
		{
			#if !switch
			Highscore.saveScore(SONG.song, songScore, storyDifficulty);
			#end
		}

		if (isStoryMode)
		{
			campaignScore += songScore;

			storyPlaylist.remove(storyPlaylist[0]);

			if (storyPlaylist.length <= 0)
			{
				FlxG.sound.playMusic(Paths.music('freakyMenu'));

				transIn = FlxTransitionableState.defaultTransIn;
				transOut = FlxTransitionableState.defaultTransOut;

				StoryMenuState.weekUnlocked[Std.int(Math.min(storyWeek + 1, StoryMenuState.weekUnlocked.length - 1))] = true;

				if (SONG.validScore)
				{
					Highscore.saveWeekScore(storyWeek, campaignScore, storyDifficulty);
				}
				FlxG.save.flush();

				LoadingState.loadAndSwitchState(new RatingState());
			}
			else
			{
				trace('LOADING NEXT SONG');
				trace(PlayState.storyPlaylist[0].toLowerCase() + CoolUtil.difficultyPath[storyDifficulty]);

				if (SONG.song.toLowerCase() == 'eggnog')
				{
					var blackShit:FlxSprite = new FlxSprite(-FlxG.width * FlxG.camera.zoom,
						-FlxG.height * FlxG.camera.zoom).makeGraphic(FlxG.width * 3, FlxG.height * 3, FlxColor.BLACK);
					blackShit.scrollFactor.set();
					add(blackShit);
					camHUD.visible = false;

					FlxG.sound.play(Paths.sound('Lights_Shut_off'));
				}

				FlxTransitionableState.skipNextTransIn = true;
				FlxTransitionableState.skipNextTransOut = true;
				prevCamFollow = camFollow;

				PlayState.SONG = Song.loadFromJson(PlayState.storyPlaylist[0].toLowerCase() + CoolUtil.difficultyPath[storyDifficulty],
					PlayState.storyPlaylist[0]);
				FlxG.sound.music.stop();

				LoadingState.loadAndSwitchState(new PlayState());
			}
		}
		else
		{
			trace('WENT BACK TO FREEPLAY??');
			FlxG.sound.music.stop();
			vocals.stop();

			LoadingState.loadAndSwitchState(new RatingState());
		}
	}

	var endingSong:Bool = false;

	private function gameOver()
	{
		boyfriend.stunned = true;

		persistentUpdate = false;
		persistentDraw = false;
		paused = true;

		FlxG.sound.music.stop();

		openSubState(new GameOverSubstate(boyfriend.getScreenPosition().x, boyfriend.getScreenPosition().y));

		#if desktop
		DiscordClient.changePresence(detailsText,
			"GAME OVER -- "
			+ SONG.song
			+ " ("
			+ storyDifficultyText
			+ ")\nAcc: "
			+ Mathf.getPercentage(accuracy, 2)
			+ "% | Score: "
			+ songScore
			+ " | Misses: "
			+ misses,
			iconRPC);
		#end
	}

	private function popUpScore(daNote:Note):Void
	{
		var noteDiff:Float = Math.abs(Conductor.songPosition - daNote.strumTime + 8);
		vocals.volume = 1;
		var score:Int = 350;

		var placement:String = Std.string(combo);

		var coolText:FlxText = new FlxText(0, 0, 0, placement, 32);
		coolText.screenCenter();
		coolText.x = FlxG.width * 0.55;

		var rating:FlxSprite = new FlxSprite();

		// ScoreManager handles everything automatically
		daNote.noteRating = scoreManager.processNoteHit(noteDiff);

		// Sync legacy variables (for backwards compatibility)
		songScore = scoreManager.score;
		combo = scoreManager.combo;
		sicks = scoreManager.sicks;
		goods = scoreManager.goods;
		bads = scoreManager.bads;
		shits = scoreManager.shits;
		accuracy = scoreManager.accuracy;

		// Health changes (you can keep your custom health logic)
		if (daNote.noteRating == 'sick')
		{
			health += 0.1;
			if (FlxG.save.data.hitsounds)
			{
				var hitSound:FlxSound = new FlxSound().loadEmbedded(Paths.sound('hitsounds/hit-${FlxG.random.int(1, 2)}'));
				hitSound.volume = 1 + FlxG.random.float(-0.2, 0.2);
				hitSound.looped = false;
				hitSound.play();
			}
			if (FlxG.save.data.notesplashes)
				spawnNoteSplashOnNote(daNote);
		}
		else if (daNote.noteRating == 'bad' || daNote.noteRating == 'shit')
		{
			health -= 0.03;
			if (FlxG.save.data.sickmode) // Sicks Mode
				gameOver();
		}

		songScore += score;

		var pixelShitPart1:String = "normal/score/";
		var pixelShitPart2:String = '';

		if (curStage.startsWith('school'))
		{
			pixelShitPart1 = 'pixelUI/score/';
			pixelShitPart2 = '-pixel';
		}

		rating.loadGraphic(Paths.image('UI/' + pixelShitPart1 + daNote.noteRating + pixelShitPart2));
		// rating.screenCenter();
		rating.x = coolText.x;
		rating.x -= 210 + 5;
		rating.y += 50;
		rating.acceleration.y = 550;
		rating.velocity.y -= FlxG.random.int(140, 175);
		rating.velocity.x -= FlxG.random.int(0, 10);
		rating.scrollFactor.set();
		rating.cameras = [camHUD];

		var comboSpr:FlxSprite = new FlxSprite().loadGraphic(Paths.image('UI/' + pixelShitPart1 + 'combo' + pixelShitPart2));
		comboSpr.screenCenter();
		comboSpr.x = coolText.x;
		comboSpr.alpha = 0;
		comboSpr.y += 200;
		comboSpr.acceleration.y = 600;
		comboSpr.velocity.y -= 150;

		comboSpr.velocity.x += FlxG.random.int(1, 10);
		// if (rating.path != null)
		add(rating);

		if (!curStage.startsWith('school'))
		{
			rating.setGraphicSize(Std.int(rating.width * 0.7));
			rating.antialiasing = true;
			comboSpr.setGraphicSize(Std.int(comboSpr.width * 0.7));
			comboSpr.antialiasing = true;
		}
		else
		{
			rating.setGraphicSize(Std.int(rating.width * daPixelZoom * 0.7));
			comboSpr.setGraphicSize(Std.int(comboSpr.width * daPixelZoom * 0.7));
		}

		comboSpr.updateHitbox();
		rating.updateHitbox();

		var seperatedScore:Array<Int> = [];

		var comboSplit:Array<String> = (combo + "").split('');

		if (comboSplit.length == 2)
			seperatedScore.push(0); // make sure theres a 0 in front or it looks weird lol!

		for (i in 0...comboSplit.length)
		{
			var str:String = comboSplit[i];
			seperatedScore.push(Std.parseInt(str));
		}

		var daLoop:Int = 0;
		for (i in seperatedScore)
		{
			var numScore:FlxSprite = new FlxSprite().loadGraphic(Paths.image('UI/' + pixelShitPart1 + 'nums/num' + Std.int(i) + pixelShitPart2));
			numScore.screenCenter();
			numScore.x = coolText.x + (43 * daLoop) - 90 + 40;
			numScore.scrollFactor.set();
			numScore.y -= 75;
			numScore.cameras = [camHUD];

			if (!curStage.startsWith('school'))
			{
				numScore.antialiasing = true;
				numScore.setGraphicSize(Std.int(numScore.width * 0.5));
			}
			else
			{
				numScore.setGraphicSize(Std.int(numScore.width * daPixelZoom));
			}
			numScore.updateHitbox();

			numScore.acceleration.y = FlxG.random.int(200, 300);
			numScore.velocity.y -= FlxG.random.int(140, 160);
			numScore.velocity.x = FlxG.random.float(-5, 5);
			add(numScore);

			FlxTween.tween(numScore, {alpha: 0}, 0.2, {
				onComplete: function(tween:FlxTween)
				{
					numScore.destroy();
				},
				startDelay: Conductor.crochet * 0.002
			});

			daLoop++;
		}

		coolText.text = Std.string(seperatedScore);

		FlxTween.tween(rating, {alpha: 0}, 0.2, {
			startDelay: Conductor.crochet * 0.001
		});

		FlxTween.tween(comboSpr, {alpha: 0}, 0.2, {
			onComplete: function(tween:FlxTween)
			{
				coolText.destroy();
				comboSpr.destroy();
				rating.destroy();
			},
			startDelay: Conductor.crochet * 0.001
		});
		curSection += 1;
	}

	function spawnNoteSplashOnNote(note:Note, ?player:Int = 1)
	{
		if (note != null)
		{
			var strum = playerStrums.members[note.noteData];
			if (player == 0)
				strum = cpuStrums.members[note.noteData];
			if (strum != null)
			{
				spawnNoteSplash(strum.x, strum.y, note.noteData, note);
			}
		}
	}

	public function spawnNoteSplash(x:Float, y:Float, data:Int, n:Note)
	{
		var splash:NoteSplash = grpNoteSplashes.recycle(NoteSplash);
		splash.setup(x, y, data); // Reinicializar el splash con la nueva posición y dirección
		grpNoteSplashes.add(splash);
	}

	public function NearlyEquals(value1:Float, value2:Float, unimportantDifference:Float = 10):Bool
	{
		return Math.abs(FlxMath.roundDecimal(value1, 1) - FlxMath.roundDecimal(value2, 1)) < unimportantDifference;
	}

	function camMovement(mustHitSection:Bool, elapsed:Float)
	{
		var targetChar:Character = (mustHitSection) ? boyfriend : dad;
		var targetCamPos:FlxPoint = targetChar.getMidpoint();

		targetCamPos.x += targetChar.cameraOffset[0];
		targetCamPos.y += targetChar.cameraOffset[1];

		if (mustHitSection)
		{
			targetCamPos.x -= 100;
			targetCamPos.y -= 100;
		}
		else
		{
			targetCamPos.x += 150;
			targetCamPos.y -= 100;
		}

		var lerpVal:Float = FlxMath.bound(elapsed * 2.4, 0, 1); // Velocidad de suavizado

		if (mustHitSection)
		{
			// Aplicamos el movimiento de nota de BF
			camFollow.x = FlxMath.lerp(camFollow.x, targetCamPos.x + bfnoteMovementXoffset, lerpVal);
			camFollow.y = FlxMath.lerp(camFollow.y, targetCamPos.y + bfnoteMovementYoffset, lerpVal);
		}
		else
		{
			camFollow.x = FlxMath.lerp(camFollow.x, targetCamPos.x + dadnoteMovementXoffset, lerpVal);
			camFollow.y = FlxMath.lerp(camFollow.y, targetCamPos.y + dadnoteMovementYoffset, lerpVal);
		}

		if (SONG.song.toLowerCase() == 'tutorial')
			tweenCamIn();

		targetCamPos.put();
	}

	function updateCPUNotes():Void
	{
		if (!generatedMusic)
			return;

		notes.forEachAlive(function(daNote:Note)
		{
			// OPTIMIZATION: Skip invisible notes
			if (daNote.y > FlxG.height)
			{
				daNote.active = false;
				daNote.visible = false;
				return;
			}

			daNote.visible = true;
			daNote.active = true;

			if (!daNote.mustPress && daNote.wasGoodHit)
			{
				if (SONG.song != 'Tutorial')
					camZooming = true;

				var altAnim:String = "";

				// OPTIMIZATION: Usar cached section
				var section = getCurrentSection();
				if (section != null)
				{
					if (section.altAnim)
						altAnim = '-alt';

					// FIX: Mejor manejo de GF y Dad
					gf.canSing = section.bothSing ? true : section.gfSing;

					if (gf.canSing && !section.bothSing)
					{
						dad.canSing = false;
						if (dadAnimFinished)
						{
							dad.dance();
						}
						camPos.x -= 100;
						camPos.y -= 250;
						tweenCamIn();
					}
					else
					{
						dad.canSing = true;
					}

					if (!gf.canSing && gfAnimFinished && gf.animation.curAnim.name.startsWith('sing'))
					{
						gf.dance();
					}
				}

				if (FlxG.save.data.notesplashes)
					spawnNoteSplashOnNote(daNote, 0);

				// FIX: Usar nuevas funciones de animación
				if (dad.canSing)
				{
					characterSing(dad, Std.int(Math.abs(daNote.noteData)), altAnim);
				}

				if (gf.canSing)
				{
					characterSing(gf, Std.int(Math.abs(daNote.noteData)), altAnim);
				}

				// OPTIMIZATION: Simplificar bucle de strums
				var noteID = Math.abs(daNote.noteData);
				cpuStrums.forEach(function(spr:FlxSprite)
				{
					if (spr.ID == noteID)
					{
						spr.animation.play('confirm', true);

						if (spr.animation.curAnim.name == 'confirm' && !curStage.startsWith('school'))
						{
							spr.centerOffsets();
							spr.offset.x -= 13;
							spr.offset.y -= 13;
						}
						else
						{
							spr.centerOffsets();
						}
					}
				});

				if (SONG.needsVoices)
					vocals.volume = 1;

				daNote.kill();
				notes.remove(daNote, true);
				safeRecycleNote(daNote);
			}

			var scrollSpeed = 0.45 * FlxMath.roundDecimal(SONG.speed, 2);
			var noteY:Float = 0;

			if (FlxG.save.data.downscroll)
				daNote.y = strumLiney + (Conductor.songPosition - daNote.strumTime) * scrollSpeed;
			else
				daNote.y = strumLiney - (Conductor.songPosition - daNote.strumTime) * scrollSpeed;

			if (daNote.isSustainNote && FlxG.save.data.downscroll)
			{
				daNote.y -= daNote.height;
				daNote.y += 125;

				var strumLineThreshold = (strumLiney + Note.swagWidth / 2);
				var noteEndPos = daNote.y - daNote.offset.y * daNote.scale.y + daNote.height;

				if (!daNote.mustPress && noteEndPos >= strumLineThreshold)
				{
					_reusableRect.x = 0;
					_reusableRect.y = 0;
					_reusableRect.width = daNote.frameWidth * 2;
					_reusableRect.height = daNote.frameHeight * 2;

					_reusableRect.height = (strumLineThreshold - daNote.y) / daNote.scale.y;
					_reusableRect.y = daNote.frameHeight - _reusableRect.height;

					daNote.clipRect = _reusableRect;
				}
			}
			else
			{
				noteY = strumLiney - (Conductor.songPosition - daNote.strumTime) * scrollSpeed;
			}

			daNote.y = noteY;

			if (!daNote.mustPress && FlxG.save.data.middlescroll)
				daNote.alpha = 0;

			// OPTIMIZATION: Combinar condiciones de eliminación
			var shouldRemove = false;
			if (!FlxG.save.data.downscroll)
			{
				shouldRemove = daNote.y < -daNote.height;
			}
			else
			{
				shouldRemove = daNote.y >= strumLiney + 106;
			}

			if (shouldRemove)
			{
				if (daNote.isSustainNote && daNote.wasGoodHit)
				{
					daNote.kill();
					notes.remove(daNote, true);
					safeRecycleNote(daNote);
				}
			}
		});
	}

	/**
	 * Reciclar nota de forma 100% segura - NUNCA crashea
	 */
	private function safeRecycleNote(note:Note):Void
	{
		if (note == null)
		{
			trace('[PlayState] WARNING: Intentando reciclar nota null');
			return;
		}

		// Opción 1: Si noteRenderer existe y funciona
		if (noteRenderer != null)
		{
			try
			{
				noteRenderer.recycleNote(note);
				return;
			}
			catch (e:Dynamic)
			{
				trace('[PlayState] ERROR en noteRenderer.recycleNote: ' + e);
				// Si falla, usar opción 2
			}
		}

		// Opción 2: Destruir la nota de forma segura
		try
		{
			note.kill();
			note.destroy();
		}
		catch (e:Dynamic)
		{
			trace('[PlayState] ERROR al destruir nota: ' + e);
			// Último recurso: solo matar
			try
			{
				note.kill();
			}
			catch (e2:Dynamic)
			{
				// No hacer nada, la nota quedará muerta eventualmente
				trace('[PlayState] No se pudo ni matar la nota');
			}
		}
	}

	function goodNoteHit(note:Note, resetMashViolation = true):Void
	{
		if (note.wasGoodHit)
			return;

		if (!note.wasGoodHit)
		{
			if (!note.isSustainNote)
			{
				popUpScore(note);
			}
			else
			{
				totalNotesHit += 1;
			}

			// FIX: Usar nueva función de animación
			if (boyfriend.canSing)
			{
				characterSing(boyfriend, note.noteData);
			}

			// OPTIMIZATION: Simplificar bucle de strums del jugador
			var noteID = Math.abs(note.noteData);
			playerStrums.forEach(function(spr:FlxSprite)
			{
				if (spr.ID == noteID)
				{
					spr.animation.play('confirm', true);
				}
			});

			note.wasGoodHit = true;
			vocals.volume = 1;

			note.kill();
			notes.remove(note, true);
			safeRecycleNote(note);

			updateAccuracy();
		}
	}

	private function keyShit():Void
	{
		// Arrays de input
		var arrowHitP:Array<Bool> = [controls.LEFT_P, controls.DOWN_P, controls.UP_P, controls.RIGHT_P];
		var arrowHit:Array<Bool> = [controls.LEFT, controls.DOWN, controls.UP, controls.RIGHT];
		var arrowHitR:Array<Bool> = [controls.LEFT_R, controls.DOWN_R, controls.UP_R, controls.RIGHT_R];

		if (boyfriend.stunned || !generatedMusic)
			return;

		// ========================================
		// PASO 1: PROCESAR NOTAS PRESIONADAS (PRESS)
		// ========================================
		var pressedKeys:Array<Int> = [];
		for (i in 0...4)
		{
			if (arrowHitP[i])
				pressedKeys.push(i);
		}

		// Para cada tecla presionada, buscar la nota más cercana
		for (direction in pressedKeys)
		{
			boyfriend.holdTimer = 0;

			// Recolectar todas las notas que pueden ser tocadas en esta dirección
			var possibleNotes:Array<Note> = [];

			notes.forEachAlive(function(daNote:Note)
			{
				if (daNote.canBeHit && daNote.mustPress && !daNote.tooLate && !daNote.wasGoodHit)
				{
					if (daNote.noteData == direction)
						possibleNotes.push(daNote);
				}
			});

			// Ordenar por tiempo (más cercana primero)
			possibleNotes.sort((a, b) -> Std.int(a.strumTime - b.strumTime));

			if (possibleNotes.length > 0)
			{
				var noteToHit:Note = null;

				// Verificar si hay múltiples notas al mismo tiempo (acordes/dobles)
				var firstNoteTime = possibleNotes[0].strumTime;
				var simultaneousNotes:Array<Note> = [];

				for (note in possibleNotes)
				{
					// Considerar "simultáneas" si están a menos de 10ms
					if (Math.abs(note.strumTime - firstNoteTime) < 10)
						simultaneousNotes.push(note);
					else
						break;
				}

				// Si hay notas simultáneas, verificar que todas sus teclas estén presionadas
				if (simultaneousNotes.length > 1)
				{
					var allKeysPressed:Bool = true;
					var requiredKeys:Array<Int> = [];

					for (note in simultaneousNotes)
					{
						requiredKeys.push(note.noteData);
						if (!arrowHitP[note.noteData])
						{
							allKeysPressed = false;
							break;
						}
					}

					// Si todas las teclas requeridas están presionadas, tocar todas
					if (allKeysPressed)
					{
						for (note in simultaneousNotes)
						{
							if (!note.wasGoodHit)
								goodNoteHit(note);
						}
					}
					else
					{
						// Si NO todas están presionadas, solo tocar la de esta dirección
						noteToHit = possibleNotes[0];
					}
				}
				else
				{
					// Nota individual, tocarla normalmente
					noteToHit = possibleNotes[0];
				}

				// Tocar la nota si no fue parte de un acorde
				if (noteToHit != null && !noteToHit.wasGoodHit)
				{
					goodNoteHit(noteToHit);
				}
			}
			else if (!FlxG.save.data.ghosttap)
			{
				// Ghost tap = miss
				noteMiss(direction);
			}
		}

		// ========================================
		// PASO 2: PROCESAR SUSTAINS (HOLD)
		// ========================================
		for (i in 0...4)
		{
			if (arrowHit[i])
			{
				notes.forEachAlive(function(daNote:Note)
				{
					if (daNote.canBeHit && daNote.mustPress && daNote.isSustainNote && !daNote.wasGoodHit)
					{
						if (daNote.noteData == i)
							goodNoteHit(daNote);
					}
				});
			}
		}

		// ========================================
		// PASO 3: ACTUALIZAR ANIMACIONES DE STRUMS
		// ========================================
		playerStrums.forEach(function(spr:FlxSprite)
		{
			if (arrowHitP[spr.ID] && spr.animation.curAnim.name != 'confirm')
				spr.animation.play('pressed');

			if (arrowHitR[spr.ID])
				spr.animation.play('static');

			// Ajustar offsets de confirm
			if (spr.animation.curAnim.name == 'confirm' && !curStage.startsWith('school') && NoteSkinSystem.offsetDefault)
			{
				spr.centerOffsets();
				spr.offset.x -= 13;
				spr.offset.y -= 13;
			}
			else
				spr.centerOffsets();
		});

		// ========================================
		// PASO 4: RESETEAR BOYFRIEND A IDLE SI NO HAY INPUT
		// ========================================
		var anyKeyHeld:Bool = false;
		for (held in arrowHit)
		{
			if (held)
			{
				anyKeyHeld = true;
				break;
			}
		}

		if (boyfriend.holdTimer > Conductor.stepCrochet * 4 * 0.001 && !anyKeyHeld)
		{
			if (boyfriend.animation.curAnim != null
				&& boyfriend.animation.curAnim.name.startsWith('sing')
				&& !boyfriend.animation.curAnim.name.endsWith('miss'))
			{
				boyfriend.playAnim('idle');
			}
		}
	}

	function noteMiss(direction:Int):Void
	{
		// ScoreManager handles miss tracking
		scoreManager.processMiss();

		// Sync legacy variables
		misses = scoreManager.misses;
		combo = scoreManager.combo;
		accuracy = scoreManager.accuracy;

		// Your custom miss effects (keep these)
		FlxG.sound.play(Paths.soundRandom('missnote', 1, 3), FlxG.random.float(0.1, 0.2));
		if (boyfriend != null)
			boyfriend.playAnim('sing' + notesAnim[direction] + 'miss', true);
		health -= 0.04;
		vocals.volume = 0;

		var placement:String = Std.string(combo);

		var coolText:FlxText = new FlxText(0, 0, 0, placement, 32);
		coolText.screenCenter();
		coolText.x = FlxG.width * 0.55;

		var rating:FlxSprite = new FlxSprite();
		rating.loadGraphic(Paths.image('UI/normal/score/miss'));
		// rating.screenCenter();
		rating.x = coolText.x - 40;
		rating.x -= 180;
		rating.y += 50;
		rating.acceleration.y = 550;
		rating.velocity.y -= FlxG.random.int(140, 175);
		rating.velocity.x -= FlxG.random.int(0, 10);
		rating.scrollFactor.set();
		rating.cameras = [camHUD];
		add(rating);

		if (!curStage.startsWith('school'))
		{
			rating.setGraphicSize(Std.int(rating.width * 0.7));
			rating.antialiasing = true;
		}
		else
		{
			rating.setGraphicSize(Std.int(rating.width * 0.7));
		}

		rating.updateHitbox();

		FlxTween.tween(rating, {alpha: 0}, 0.2, {
			startDelay: Conductor.crochet * 0.001
		});

		FlxTween.tween(rating, {alpha: 0}, 0.2, {
			onComplete: function(tween:FlxTween)
			{
				coolText.destroy();

				rating.destroy();
			},
			startDelay: Conductor.crochet * 0.001
		});
	}

	override function destroy()
	{
		// Cleanup integrated systems
		if (noteRenderer != null)
		{
			noteRenderer.destroy();
			noteRenderer = null;
		}

		if (eventSystem != null)
		{
			eventSystem.destroy();
			eventSystem = null;
		}

		if (scoreManager != null)
			scoreManager = null;

		// Clear hooks
		onBeatHitHooks.clear();
		onStepHitHooks.clear();
		onUpdateHooks.clear();
		onNoteHitHooks.clear();
		onNoteMissHooks.clear();

		super.destroy();
	}

	function badNoteCheck()
	{
		// REDO THIS SYSTEM!
		var pressedControls = [controls.LEFT_P, controls.DOWN_P, controls.UP_P, controls.RIGHT_P];
		for (pressed in pressedControls)
		{
			if (pressed)
				noteMiss(pressedControls.indexOf(pressed));
		}
		updateAccuracy();
	}

	function updateAccuracy()
	{
		totalPlayed += 1;
		accuracy = totalNotesHit / totalPlayed * 100;
	}

	function switchCharacter(player:String, character:String):Void
	{
		switch (player)
		{
			case 'Bf':
				remove(boyfriend);
				boyfriend = new Character(boyfriend.x, boyfriend.y, character);
				add(boyfriend);
				iconP1.animation.play(character);
			case 'Oponnent':
				remove(dad);
				dad = new Character(dad.x, dad.y, character);
				add(dad);
				iconP2.animation.play(character);
			case 'Gf':
				remove(gf);
				gf = new Character(gf.x, gf.y, character);
				add(gf);
		}
	}

	function getKeyPresses(note:Note):Int
	{
		var possibleNotes:Array<Note> = []; // copypasted but you already know that

		notes.forEachAlive(function(daNote:Note)
		{
			if (daNote.canBeHit && daNote.mustPress && !daNote.tooLate)
			{
				possibleNotes.push(daNote);
				possibleNotes.sort((a, b) -> Std.int(a.strumTime - b.strumTime));
			}
		});
		return possibleNotes.length;
	}

	var mashing:Int = 0;
	var mashViolations:Int = 0;

	function noteCheck(controlArray:Array<Bool>, note:Note):Void // sorry lol
	{
		if (controlArray[note.noteData])
		{
			for (b in controlArray)
			{
				if (b)
					mashing++;
			}

			// ANTI MASH CODE FOR THE BOYS

			if ((mashing <= getKeyPresses(note)) && mashViolations > 2 || !theFunne || !FlxG.save.data.mash_punish)
			{
				mashViolations++;
				goodNoteHit(note, (mashing <= getKeyPresses(note) + 1));
			}
			else
			{
				playerStrums.members[note.noteData].animation.play('static');
				trace('mash ' + mashing);
			}
		}
		else if (!theFunne && startedCountdown)
		{
			badNoteCheck();
		}
	}

	override function stepHit()
	{
		super.stepHit();

		for (key in onStepHitHooks.keys())
		{
			if (onStepHitHooks.exists(key))
				onStepHitHooks.get(key)(curStep);
		}

		for (hook in onStepHitHooks)
			hook(curStep);

		eventSystem.triggerStepEvents(curStep);

		if (FlxG.sound.music.time > Conductor.songPosition + 20 || FlxG.sound.music.time < Conductor.songPosition - 20)
		{
			resyncVocals();
		}

		#if desktop
		songLength = FlxG.sound.music.length;

		// Updating Discord Rich Presence (with Time Left)
		updatePresence();
		#end
	}

	var lightningStrikeBeat:Int = 0;
	var lightningOffset:Int = 8;
	var spookydance:Bool = false;

	function setupStageCallbacks():Void
	{
		switch (curStage)
		{
			case "philly":
				setupPhillyStage();
			case "limo":
				setupLimoStage();
			case "spooky":
				setupSpookyStage();
		}
	}

	function setupPhillyStage():Void
	{
		var trainSound = currentStage.getSound("trainSound");
		var phillyCityLights = currentStage.getGroup("phillyCityLights");
		var train = currentStage.getElement("train");

		var curLight:Int = 0;
		var trainMoving:Bool = false;
		var trainCooldown:Int = 0;

		currentStage.onBeatHit = function()
		{
			if (!trainMoving)
				trainCooldown += 1;

			if (curBeat % 4 == 0 && phillyCityLights != null)
			{
				phillyCityLights.forEach(function(light:FlxSprite)
				{
					light.visible = false;
				});

				curLight = FlxG.random.int(0, phillyCityLights.length - 1);
				phillyCityLights.members[curLight].visible = true;
			}

			if (curBeat % 8 == 4 && FlxG.random.bool(30) && !trainMoving && trainCooldown > 8)
			{
				trainCooldown = FlxG.random.int(-4, 0);
				trainMoving = true;
				if (trainSound != null)
					trainSound.play(true);
			}
		};

		currentStage.onUpdate = function(elapsed:Float)
		{
			if (trainMoving && train != null)
			{
				var trainFrameTiming:Float = 0;
				train.x -= 150;
				train.visible = false;

				if (train.x < -4000)
				{
					train.visible = true;
					new FlxTimer().start(2, function(tmr:FlxTimer)
					{
						FlxTween.tween(train, {x: 2000}, 3, {type: ONESHOT});
						trainMoving = false;
					});
				}
			}
		};
	}

	function pauseMenu()
	{
		persistentUpdate = false;
		persistentDraw = true;
		paused = true;
		FlxG.sound.pause();

		// 1 / 1000 chance for Gitaroo Man easter egg
		if (FlxG.random.bool(0.1))
		{
			FlxG.switchState(new GitarooPause());
		}
		else
		{
			openSubState(new PauseSubState());
		}
	}

	function setupSpookyStage():Void
	{
		var halloweenBG = currentStage.getElement("halloweenBG");
		var lightningStrikeBeat:Int = 0;
		var lightningOffset:Int = 8;

		currentStage.onBeatHit = function()
		{
			if (FlxG.random.bool(10) && curBeat > lightningStrikeBeat + lightningOffset)
			{
				FlxG.sound.play(Paths.soundRandom('thunder_', 1, 2));

				if (halloweenBG != null)
					halloweenBG.animation.play('lightning');

				lightningStrikeBeat = curBeat;
				lightningOffset = FlxG.random.int(8, 24);

				if (boyfriend != null)
					boyfriend.playAnim('scared', true);
				if (gf != null)
					gf.playAnim('scared', true);
			}
		};
	}

	function setupLimoStage():Void
	{
		var fastCar = currentStage.getElement("fastCar");
		var fastCarCanDrive:Bool = true;

		function resetFastCar():Void
		{
			if (fastCar != null)
			{
				fastCar.x = -12600;
				fastCar.y = FlxG.random.int(140, 250);
				fastCar.velocity.x = 0;
				fastCarCanDrive = true;
			}
		}

		function fastCarDrive():Void
		{
			if (fastCar != null)
			{
				FlxG.sound.play(Paths.soundRandom('carPass', 0, 1), 0.7);
				fastCar.velocity.x = (FlxG.random.int(170, 220) / FlxG.elapsed) * 3;
				fastCarCanDrive = false;
				new FlxTimer().start(2, function(tmr:FlxTimer)
				{
					resetFastCar();
				});
			}
		}
		resetFastCar();

		currentStage.onBeatHit = function()
		{
			if (FlxG.random.bool(10) && fastCarCanDrive)
				fastCarDrive();
		};
	}

	override function beatHit()
	{
		super.beatHit();
		for (key in onBeatHitHooks.keys())
		{
			if (onBeatHitHooks.exists(key))
				onBeatHitHooks.get(key)(curBeat);
		}

		eventSystem.triggerBeatEvents(curBeat);
		for (hook in onBeatHitHooks)
			hook(curBeat);

		currentStage.callCustomGroupMethod("main_crowd", "dance");
		currentStage.callCustomGroupMethod("far_crowd", "dance");
		currentStage.callCustomGroupMethod("limo_dancers_left", "dance");
		currentStage.callCustomGroupMethod("limo_dancers_right", "dance");

		if (curSong == 'Fresh')
		{
			switch (curBeat)
			{
				case 16:
					camZooming = true;
					gfSpeed = 2;
				case 48:
					gfSpeed = 1;
				case 80:
					gfSpeed = 2;
				case 112:
					gfSpeed = 1;
			}
		}

		if (currentStage != null)
			currentStage.beatHit(curBeat);

		// OPTIMIZATION: Cache de sección actual
		var section = getCurrentSection();

		if (section != null)
		{
			if (section.changeBPM)
			{
				Conductor.changeBPM(section.bpm);
				FlxG.log.add('CHANGED BPM!');
			}

			// FIX: Mejor control de dad dance
			if (section.mustHitSection)
			{
				if (dad != null && dadAnimFinished)
				{
					switch (dad.curCharacter)
					{
						case 'spooky':
							// Spooky tiene animación especial
							if (spookydance)
							{
								dad.playAnim('danceRight');
								spookydance = false;
							}
							else
							{
								dad.playAnim('danceLeft');
								spookydance = true;
							}
						case 'gf':
							// Spooky tiene animación especial
							if (spookydance)
							{
								dad.playAnim('danceRight');
								spookydance = false;
							}
							else
							{
								dad.playAnim('danceLeft');
								spookydance = true;
							}
						default:
							dad.dance();
					}
					dadHoldTimer = 0;
				}
			}
		}

		wiggleShit.update(Conductor.crochet);

		// HARDCODING FOR MILF ZOOMS!
		if (curSong.toLowerCase() == 'milf' && curBeat >= 168 && curBeat < 200 && camZooming && FlxG.camera.zoom < 1.35)
		{
			FlxG.camera.zoom += 0.015;
			camHUD.zoom += 0.03;
		}

		if (camZooming && FlxG.camera.zoom < 1.35 && curBeat % 4 == 0)
		{
			FlxG.camera.zoom *= 1.015;
			camHUD.zoom += 0.03;
		}

		// OPTIMIZATION: Simplificar actualización de iconos
		if (iconP1 != null)
		{
			iconP1.scale.set(1.2, 1.2);
			iconP1.updateHitbox();
		}

		if (iconP2 != null)
		{
			iconP2.scale.set(1.2, 1.2);
			iconP2.updateHitbox();
		}

		// FIX: GF dance con verificación de animación terminada
		if (curBeat % gfSpeed == 0)
		{
			if (gf != null && gfAnimFinished)
			{
				gf.dance();
				gfHoldTimer = 0;
			}
		}

		// FIX: Boyfriend idle con mejor control
		if (boyfriend != null && boyfriend.animation != null && boyfriend.animation.curAnim != null)
		{
			if (!boyfriend.animation.curAnim.name.startsWith("sing") && boyfriend.canSing && bfAnimFinished)
			{
				boyfriend.dance();
				bfHoldTimer = 0;
				specialAnim = false;
			}
		}

		// FIX: Dad idle con mejor control
		if (dad != null && dad.animation != null && dad.animation.curAnim != null)
		{
			if (!dad.animation.curAnim.name.startsWith("sing") && dad.canSing && dadAnimFinished)
			{
				switch (dad.curCharacter)
				{
					/*
						case 'spooky':
							if (spookydance)
							{
								dad.playAnim('danceRight');
								spookydance = false;
							}
							else
							{
								dad.playAnim('danceLeft');
								spookydance = true;
					}*/
					default:
						dad.dance();
				}
				dadHoldTimer = 0;
				specialAnim = false;
			}
		}

		// Special animations for specific songs
		if (curBeat % 8 == 7 && curSong == 'Bopeebo')
		{
			if (boyfriend != null)
			{
				boyfriend.playAnim('hey', true);
				specialAnim = true;
			}

			if (SONG.song == 'Tutorial' && dad != null && dad.curCharacter == 'gf')
			{
				dad.playAnim('cheer', true);
				specialAnim = true;
			}
		}

		// Special visual effects
		if (FlxG.save.data.specialVisualEffects)
		{
			if (curBeat == 24 && curSong == 'Philly')
			{
				FlxTween.tween(camHUD, {y: camHUD.y + 200}, 0.6, {ease: FlxEase.quadInOut, type: ONESHOT});
			}
			if (curBeat == 31 && curSong == 'Philly')
			{
				FlxTween.tween(camHUD, {y: camHUD.y - 200}, 0.6, {ease: FlxEase.quadInOut, type: ONESHOT});
			}
		}
	}

	var curLight:Int = 0;

	private function updateCharacterAnimations(elapsed:Float):Void
	{
		// OPTIMIZATION: Actualizar timers de hold
		dadHoldTimer += elapsed;
		bfHoldTimer += elapsed;
		gfHoldTimer += elapsed;

		// FIX: Dad animations - Resetear a idle si la animación terminó
		if (dad != null && dad.animation != null && dad.animation.curAnim != null)
		{
			var curAnim = dad.animation.curAnim.name;

			// Si está cantando y el timer expiró, volver a idle
			if (curAnim.startsWith('sing') && !curAnim.endsWith('miss'))
			{
				if (dadHoldTimer > SING_DURATION && dad.canSing)
				{
					dadAnimFinished = true;
					if (!specialAnim)
					{
						dad.dance();
					}
				}
			}

			// Resetear a idle si la animación terminó
			if (curAnim.startsWith('idle') && dadnoteMovementXoffset == 0 && dadnoteMovementYoffset == 0)
			{
				dadAnimFinished = true;
			}
		}

		// FIX: Boyfriend animations - Mejor control del idle
		if (boyfriend != null && boyfriend.animation != null && boyfriend.animation.curAnim != null)
		{
			var curAnim = boyfriend.animation.curAnim.name;

			// Si está cantando y el timer expiró, volver a idle
			if (curAnim.startsWith('sing') && !curAnim.endsWith('miss') || curAnim.startsWith('hey'))
			{
				// OPTIMIZATION: Usar constante en lugar de cálculo repetido
				var threshold = Conductor.stepCrochet * 4 * 0.001; // Convertir a segundos
				if (bfHoldTimer > threshold && boyfriend.canSing)
				{
					bfAnimFinished = true;
					if (!specialAnim)
					{
						boyfriend.playAnim('idle', true);
						boyfriend.holdTimer = 0;
					}
				}
			}

			// Resetear offsets cuando está en idle
			if (curAnim.startsWith('idle'))
			{
				bfnoteMovementYoffset = 0;
				bfnoteMovementXoffset = 0;
				bfAnimFinished = true;
			}
		}

		// FIX: GF animations
		if (gf != null && gf.animation != null && gf.animation.curAnim != null)
		{
			var curAnim = gf.animation.curAnim.name;

			if (curAnim.startsWith('sing'))
			{
				gfHoldTimer += elapsed;
				if (gfHoldTimer > SING_DURATION && gf.canSing)
				{
					gf.dance();
					gfHoldTimer = 0;
					gfAnimFinished = true; // Ahora sí puede bailar de nuevo
				}
			}
			else
			{
				// Resetear timer cuando NO está cantando
				gfHoldTimer = 0;

				// Resetear offsets de cámara (GF comparte cámara con dad)
				if (curAnim.startsWith('dance') || curAnim.startsWith('idle'))
				{
					dadnoteMovementYoffset = 0;
					dadnoteMovementXoffset = 0;
				}

				// NO poner gfAnimFinished = true cada frame
				// Se mantiene el valor que tenga (true después de cantar, o false durante canto)
			}
		}
	}

	public function characterSing(char:Character, noteData:Int, ?altAnim:String = ""):Void
	{
		if (char == null || !char.canSing)
			return;

		// === CORRECCIÓN PARA BOYFRIEND ===
		// Por defecto, BF no usa animaciones alternas (altAnim).
		// Esto evita que el juego busque "singUP-alt" si BF no lo tiene.
		if (char == boyfriend)
		{
			altAnim = "";
		}

		// Construir el nombre de la animación
		var animName:String = 'sing' + notesAnim[noteData] + altAnim;

		// === SISTEMA DE SEGURIDAD (Liberal/Flexible) ===
		// Si por alguna razón (script o mod) el personaje NO tiene la animación 'alt',
		// regresamos automáticamente a la animación normal para evitar glitches.
		if (!char.animOffsets.exists(animName) && char.animation.getByName(animName) == null)
		{
			animName = 'sing' + notesAnim[noteData];
		}

		// Optimización: Si ya está tocando esta animación, no la reinicies (evita "tartamudeo")
		if (char.animation.curAnim != null && char.animation.curAnim.name == animName)
			return;

		char.playAnim(animName, true);

		// Resetear timers específicos (Unificado)
		if (char == dad)
			dadHoldTimer = 0;
		else if (char == boyfriend)
			bfHoldTimer = 0;
		else if (char == gf)
			gfHoldTimer = 0;

		// Dentro de characterSing (versión simplificada de la lógica de cámara)
		var camOffsetAmt:Float = 30.0; // Ajusta la intensidad aquí

		// Reiniciamos offsets primero
		if (char == dad)
		{
			dadnoteMovementXoffset = 0;
			dadnoteMovementYoffset = 0;
		}
		if (char == boyfriend)
		{
			bfnoteMovementXoffset = 0;
			bfnoteMovementYoffset = 0;
		}

		// Calculamos nuevo offset
		var camX:Float = 0;
		var camY:Float = 0;

		switch (noteData)
		{
			case 0:
				camX = -camOffsetAmt; // LEFT
			case 1:
				camY = camOffsetAmt; // DOWN
			case 2:
				camY = -camOffsetAmt; // UP
			case 3:
				camX = camOffsetAmt; // RIGHT
		}

		// Asignamos
		if (char == dad)
		{
			dadnoteMovementXoffset = Std.int(camX);
			dadnoteMovementYoffset = Std.int(camY);
		}
		else if (char == boyfriend)
		{
			bfnoteMovementXoffset = Std.int(camX);
			bfnoteMovementYoffset = Std.int(camY);
		}
	}

	// OPTIMIZATION: Cachear sección actual para evitar accesos repetidos
	private function getCurrentSection():SwagSection
	{
		var sectionIndex = Math.floor(curStep / 16);

		if (cachedSectionIndex != sectionIndex)
		{
			cachedSectionIndex = sectionIndex;
			cachedSection = (SONG.notes[sectionIndex] != null) ? SONG.notes[sectionIndex] : null;
		}
		return cachedSection;
	}
}
