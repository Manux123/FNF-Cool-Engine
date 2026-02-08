
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

// Integrated systems
import objects.hud.ScoreManager;
import objects.character.Character;
import notes.StrumNote;
import notes.Note;
import notes.NoteSplash;
import notes.NoteRenderer;
import extensions.HScriptEventSystem;

import openfl.display.StageQuality;
import openfl.filters.ShaderFilter;
import controls.KeyBindMenu;

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

/**
 * ═══════════════════════════════════════════════════════════════════════════════
 *                     PLAYSTATE - OPTIMIZED & MODULAR
 * ═══════════════════════════════════════════════════════════════════════════════
 * 
 * INTEGRATED SYSTEMS:
 * ✓ NoteRenderer       - Object pooling, automatic culling, optimized rendering
 * ✓ ScoreManager       - Complete scoring system with accuracy and rankings
 * ✓ HScriptEventSystem - Editable events without recompiling (mods/custom stages)
 * 
 * OPTIMIZATIONS:
 * ✓ Object pooling to prevent GC (Garbage Collection)
 * ✓ Cached sections and repeated calculations
 * ✓ Extensible hook system (onBeatHit, onStepHit, onUpdate)
 * ✓ Separation of concerns (each system does ONE thing well)
 * 
 * MODULAR ARCHITECTURE:
 * ✓ Stages can register hooks without modifying PlayState
 * ✓ HScript scripts can add dynamic logic
 * ✓ Modular and extensible event system
 * ✓ Easy to extend with new systems (plugins)
 * 
 * ═══════════════════════════════════════════════════════════════════════════════
 */
class PlayState extends states.MusicBeatState
{
	// ═══════════════════════════════════════════════════════════════════════════
	//                             CORE SYSTEMS
	// ═══════════════════════════════════════════════════════════════════════════
	
	public static var instance:PlayState = null;
	
	// Integrated modular systems
	public var noteRenderer:NoteRenderer;        // Optimized note rendering with pooling
	public var scoreManager:ScoreManager;        // Complete scoring system
	public var eventSystem:HScriptEventSystem;   // Dynamic event system
	
	// ═══════════════════════════════════════════════════════════════════════════
	//                         EXTENSIBILITY HOOKS
	// ═══════════════════════════════════════════════════════════════════════════
	
	// Hook system: External functions can be registered to execute on specific events
	// This makes the code "modular": you can add logic from stages or scripts without recompiling
	public var onBeatHitHooks:Map<String, Int->Void> = new Map<String, Int->Void>();
	public var onStepHitHooks:Map<String, Int->Void> = new Map<String, Int->Void>();
	public var onUpdateHooks:Map<String, Float->Void> = new Map<String, Float->Void>();
	public var onNoteHitHooks:Map<String, Note->Void> = new Map<String, Note->Void>();
	public var onNoteMissHooks:Map<String, Note->Void> = new Map<String, Note->Void>();
	
	// ═══════════════════════════════════════════════════════════════════════════
	//                              GAME STATE
	// ═══════════════════════════════════════════════════════════════════════════
	
	public static var curStage:String = '';
	public static var SONG:SwagSong;
	public static var isStoryMode:Bool = false;
	public static var storyWeek:Int = 0;
	public static var storyPlaylist:Array<String> = [];
	public static var storyDifficulty:Int = 1;
	public static var weekSong:Int = 0;
	public static var isPlaying:Bool = false;
	
	// Legacy score variables (kept for compatibility, but ScoreManager handles the logic)
	public static var songScore:Int = 0;
	public static var campaignScore:Int = 0;
	public static var misses:Int = 0;
	public static var shits:Int = 0;
	public static var bads:Int = 0;
	public static var goods:Int = 0;
	public static var sicks:Int = 0;
	public static var accuracy:Float = 0.00;
	
	#if mobileC
	var mcontrols:Mobilecontrols;
	#end
	
	#if desktop
	// Discord RPC variables
	var storyDifficultyText:String = "";
	var iconRPC:String = "";
	var songLength:Float = 0;
	var detailsText:String = "";
	var detailsPausedText:String = "";
	#end
	
	// ═══════════════════════════════════════════════════════════════════════════
	//                           GAME OBJECTS
	// ═══════════════════════════════════════════════════════════════════════════
	
	public var vocals:FlxSound;
	public var currentStage:Stage;
	
	// Characters
	public var dad:Character;
	public var gf:Character;
	public var boyfriend:Character;
	
	// Notes
	public var notes:FlxTypedGroup<Note>;
	private var unspawnNotes:Array<Note> = [];
	public var strumLineNotes:FlxTypedGroup<FlxSprite>;
	private var playerStrums:FlxTypedGroup<FlxSprite>;
	public static var cpuStrums:FlxTypedGroup<FlxSprite> = null;
	
	// Note splashes
	var grpNoteSplashes:FlxTypedGroup<NoteSplash>;
	private var SplashNote:NoteSplash;
	
	// Camera
	public var camHUD:FlxCamera;
	public var camCountdown:FlxCamera;
	public var camGame:FlxCamera;
	private var camFollow:FlxObject;
	private static var prevCamFollow:FlxObject;
	var camPos:FlxPoint;
	private var camZooming:Bool = false;
	var defaultCamZoom:Float = 1.05;
	
	// UI Elements
	private var healthBarBG:FlxSprite;
	private var healthBar:FlxBar;
	public var health:Float = 1;
	public var iconP1:HealthIcon;
	public var iconP2:HealthIcon;
	var scoreTxt:FlxText;
	var fullCombo:FlxText;
	var sickMode:FlxText;
	
	// Countdown
	var readya:FlxSprite;
	var readyCL:FlxSprite;
	var readyaIsntDestroyed:Bool = true;
	var startTimer:FlxTimer;
	var ready:FlxSprite;
	var set:FlxSprite;
	var go:FlxSprite;
	
	// ═══════════════════════════════════════════════════════════════════════════
	//                         OPTIMIZATION VARIABLES
	// ═══════════════════════════════════════════════════════════════════════════
	
	// Reusable objects to avoid 'new' calls in update loop
	private var _reusableRect:FlxRect = new FlxRect();
	
	// Section caching to avoid repeated array access
	private var cachedSection:SwagSection = null;
	private var cachedSectionIndex:Int = -1;
	
	// Character animation timers
	private var dadHoldTimer:Float = 0;
	private var bfHoldTimer:Float = 0;
	private var gfHoldTimer:Float = 0;
	
	// Animation state flags
	private var dadAnimFinished:Bool = true;
	private var bfAnimFinished:Bool = true;
	private var gfAnimFinished:Bool = true;
	
	// Animation constants
	private static inline var HOLD_THRESHOLD:Float = 0.001;
	private static inline var SING_DURATION:Float = 0.6;
	
	// ═══════════════════════════════════════════════════════════════════════════
	//                          GAMEPLAY VARIABLES
	// ═══════════════════════════════════════════════════════════════════════════
	
	var strumLiney:Float = 50;
	private var curSection:Int = 0;
	public var curSong:String = "";
	private var gfSpeed:Int = 1;
	private var combo:Int = 0;
	private var totalNotesHit:Float = 0;
	private var totalPlayed:Int = 0;
	private var ss:Bool = false;
	private var songPositionBar:Float = 0;
	private var generatedMusic:Bool = false;
	public static var startingSong:Bool = false;
	
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
	
	public static var daPixelZoom:Float = 6;
	public static var theFunne:Bool = true;
	var funneEffect:FlxSprite;
	var inCutscene:Bool = false;
	
	public static var timeCurrently:Float = 0;
	public static var timeCurrentlyR:Float = 0;
	
	// Camera movement offsets
	public static var dadnoteMovementXoffset:Int = 0;
	public static var dadnoteMovementYoffset:Int = 0;
	public static var bfnoteMovementXoffset:Int = 0;
	public static var bfnoteMovementYoffset:Int = 0;
	
	// Misc
	private var gfSing:Bool = false;
	public var paused:Bool = false;
	var startedCountdown:Bool = false;
	var canPause:Bool = true;
	var CPUvsCPUMode:Bool = false;
	
	var introAssets:Map<String, Array<String>> = new Map<String, Array<String>>();
	var altSuffix:String = '';
	var introAlts:Array<String> = [];
	
	var previousFrameTime:Int = 0;
	var lastReportedPlayheadPosition:Int = 0;
	var songTime:Float = 0;
	
	var debugNum:Int = 0;
	var curLight:Int = 0;
	var spookydance:Bool = false;
	var songEnd:Bool = false;
	public static var ranking:String = "N/A";
	
	// ═══════════════════════════════════════════════════════════════════════════
	//                              CREATE
	// ═══════════════════════════════════════════════════════════════════════════
	
	override public function create()
	{
		instance = this;
		isPlaying = true;
		
		FlxG.mouse.visible = false;
		theFunne = FlxG.save.data.newInput;
		
		if (FlxG.sound.music != null)
			FlxG.sound.music.stop();
		
		// Set FPS cap
		if (FlxG.save.data.FPSCap)
			openfl.Lib.current.stage.frameRate = 120;
		else
			openfl.Lib.current.stage.frameRate = 240;
		
		// Initialize stage
		if (SONG.stage == null)
			SONG.stage = 'stage_week1';
		
		curStage = SONG.stage;
		
		#if desktop
		// Discord Rich Presence setup
		storyDifficultyText = CoolUtil.difficultyString();
		iconRPC = SONG.player2;
		
		// Avoid duplicate images in Discord assets
		switch (iconRPC)
		{
			case 'senpai-angry':
				iconRPC = 'senpai';
			case 'monster-christmas':
				iconRPC = 'monster';
			case 'mom-car':
				iconRPC = 'mom';
		}
		
		// Mode string
		if (isStoryMode)
			detailsText = "Story Mode: Week " + storyWeek;
		else
			detailsText = "Freeplay";
		
		detailsPausedText = "Paused - " + detailsText;
		updatePresence();
		#end
		
		// ═══════════════════════════════════════════════════════════════════════
		//                    INITIALIZE INTEGRATED SYSTEMS
		// ═══════════════════════════════════════════════════════════════════════
		
		// Initialize ScoreManager
		scoreManager = new ScoreManager();
		scoreManager.reset();
		trace('[PlayState] ScoreManager initialized');
		
		// Initialize HScriptEventSystem
		eventSystem = new HScriptEventSystem();
		eventSystem.playState = this;
		eventSystem.debugMode = false; // Set to true for event debugging
		trace('[PlayState] HScriptEventSystem initialized');
		
		// Load event scripts for this song
		if (SONG != null && SONG.song != null)
		{
			eventSystem.loadScript(SONG.song, "events"); // Loads /assets/data/{song}/events.hscript
			trace('[PlayState] Loaded events for song: ${SONG.song}');
		}
		
		// ═══════════════════════════════════════════════════════════════════════
		
		// Setup cameras
		camGame = new FlxCamera();
		camHUD = new FlxCamera();
		camHUD.bgColor.alpha = 0;
		camCountdown = new FlxCamera();
		camCountdown.bgColor.alpha = 0;
		
		FlxG.cameras.reset(camGame);
		FlxG.cameras.add(camHUD, false);
		FlxG.cameras.add(camCountdown, false);
		
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
		
		// Load dialogue for specific songs
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
		
		// Setup stage
		setCurrentStage();
		setupStageCallbacks();
		
		// Initialize characters
		var gfVersion:String = 'gf';
		if (SONG.gfVersion != null)
			gfVersion = SONG.gfVersion;
		
		gf = new Character(400, 130, gfVersion);
		gf.scrollFactor.set(0.95, 0.95);
		
		dad = new Character(100, 100, SONG.player2);
		camPos = new FlxPoint(dad.getGraphicMidpoint().x, dad.getGraphicMidpoint().y);
		
		boyfriend = new Character(770, 450, SONG.player1, true);
		
		applyStagePositions();
		
		// Special repositioning for test song
		if (SONG.song.toLowerCase() == 'test')
		{
			dad.y += 510;
			dad.x += 250;
		}
		
		// Add characters to stage
		if (!FlxG.save.data.gfbye && !currentStage.hideGirlfriend)
			add(gf);
		
		add(dad);
		add(boyfriend);
		
		// Setup dialogue
		var dialogueBox:DialogueBox = new DialogueBox(false, dialogue);
		dialogueBox.scrollFactor.set();
		dialogueBox.finishThing = startCountdown;
		
		Conductor.songPosition = -5000;
		
		// Adjust strum line for downscroll
		if (FlxG.save.data.downscroll)
			strumLiney = FlxG.height - 165;
		
		// Create strum line notes
		strumLineNotes = new FlxTypedGroup<FlxSprite>();
		add(strumLineNotes);
		
		// Add note splashes
		if (FlxG.save.data.notesplashes)
		{
			add(grpNoteSplashes);
			var sploosh = new NoteSplash(100, 100, 0);
			grpNoteSplashes.add(sploosh);
			sploosh.alpha = 0.0;
		}
		
		playerStrums = new FlxTypedGroup<FlxSprite>();
		cpuStrums = new FlxTypedGroup<FlxSprite>();
		
		// Generate song notes
		generateSong(SONG.song);
		
		// ═══════════════════════════════════════════════════════════════════════
		//                    INITIALIZE NOTE RENDERER
		// ═══════════════════════════════════════════════════════════════════════
		
		noteRenderer = new NoteRenderer(notes, playerStrums, cpuStrums);
		noteRenderer.downscroll = FlxG.save.data.downscroll;
		noteRenderer.strumLineY = strumLiney;
		noteRenderer.noteSpeed = SONG.speed;
		trace('[PlayState] NoteRenderer initialized with pool');
		
		// ═══════════════════════════════════════════════════════════════════════
		
		// Setup camera follow
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
		
		// Health bar
		healthBarBG = new FlxSprite(0, FlxG.height * 0.9).loadGraphic(Paths.image('UI/healthBar'));
		if (FlxG.save.data.downscroll)
			healthBarBG.y = 50;
		healthBarBG.screenCenter(X);
		healthBarBG.scrollFactor.set();
		add(healthBarBG);
		
		healthBar = new FlxBar(healthBarBG.x + 4, healthBarBG.y + 4, RIGHT_TO_LEFT, 
			Std.int(healthBarBG.width - 8), Std.int(healthBarBG.height - 8), this, 'health', 0, 2);
		healthBar.scrollFactor.set();
		
		// Health bar colors based on characters
		var cpuColor = getCharacterColor(SONG.player2);
		var playerColor = getCharacterColor(SONG.player1);
		
		healthBar.createFilledBar(cpuColor, playerColor);
		add(healthBar);
		
		// Score text
		scoreTxt = new FlxText(45, healthBarBG.y + 50, 0, "", 32);
		scoreTxt.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 4, 1);
		scoreTxt.color = FlxColor.WHITE;
		scoreTxt.size = 22;
		scoreTxt.y -= 350;
		scoreTxt.scrollFactor.set();
		
		// Version text
		var versionShit:FlxText = new FlxText(5, FlxG.height - 19, 0, 
			"FNF Cool Engine BETA - v" + Application.current.meta.get('version'), 12);
		versionShit.scrollFactor.set();
		versionShit.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(versionShit);
		
		// Mode indicators
		var grpDataShit:FlxTypedGroup<FlxText> = new FlxTypedGroup<FlxText>();
		
		if (FlxG.save.data.perfectmode)
		{
			fullCombo = new FlxText(5, FlxG.height - 19, 0, "Full Combo Mode", 12);
			fullCombo.scrollFactor.set();
			fullCombo.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			fullCombo.y -= 20;
			fullCombo.visible = false;
			fullCombo.ID = 0;
			grpDataShit.add(fullCombo);
		}
		
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
				spr.y -= 20;
		});
		
		// Health icons
		iconP1 = new HealthIcon(SONG.player1, true);
		iconP1.y = healthBar.y - (iconP1.height / 2);
		add(iconP1);
		
		iconP2 = new HealthIcon(SONG.player2, false);
		iconP2.y = healthBar.y - (iconP2.height / 2);
		add(iconP2);
		
		add(scoreTxt);
		
		// Set cameras for all UI elements
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
		
		// Song-specific intro logic
		if (isStoryMode)
		{
			switch (curSong.toLowerCase())
			{
				case "winter-horrorland":
					var blackScreen:FlxSprite = new FlxSprite(0, 0).makeGraphic(
						Std.int(FlxG.width * 2), Std.int(FlxG.height * 2), FlxColor.BLACK);
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
			vsReady();
		}
		
		super.create();
	}
	
	// ═══════════════════════════════════════════════════════════════════════════
	//                          HELPER FUNCTIONS
	// ═══════════════════════════════════════════════════════════════════════════
	
	/**
	 * Get character health bar color
	 */
	function getCharacterColor(char:String):Int
	{
		return switch (char.toLowerCase())
		{
			case 'bf' | 'bf-car' | 'bf-christmas': 0xFF31b0d1;
			case 'bf-pixel': 0xFF7bd6f6;
			case 'gf': 0xFFa5004d;
			case 'dad' | 'parents-christmas': 0xFFaf66ce;
			case 'spooky': 0xFFd57e00;
			case 'pico': 0xFFb7d855;
			case 'mom' | 'mom-car': 0xFFd8558e;
			case 'monster-christmas' | 'monster': 0xFFf3ff6e;
			case 'senpai' | 'senpai-angry': 0xFFffaa6f;
			case 'spirit': 0xFFff3c6e;
			case 'bf-pixel-enemy': 0xFF7bd6f6;
			default: 0xFFFF0000;
		}
	}
	
	/**
	 * Setup stage and apply default settings
	 */
	function setCurrentStage()
	{
		currentStage = new Stage(curStage);
		add(currentStage);
		defaultCamZoom = currentStage.defaultCamZoom;
	}
	
	/**
	 * Setup callbacks for stage-specific events
	 * This is where stages can register their own hooks without modifying PlayState
	 */
	function setupStageCallbacks():Void
	{
		// Example: Register stage-specific beat events
		// currentStage.registerBeatHook(this);
		
		// Stages can add hooks like:
		// onBeatHitHooks.set("stage_lightning", function(beat:Int) { /* lightning effect */ });
		// onStepHitHooks.set("stage_train", function(step:Int) { /* train movement */ });
	}
	
	/**
	 * Apply character positions from stage data
	 */
	function applyStagePositions():Void
	{
		if (boyfriend != null)
			boyfriend.setPosition(currentStage.boyfriendPosition.x, currentStage.boyfriendPosition.y);
		
		if (dad != null)
			dad.setPosition(currentStage.dadPosition.x, currentStage.dadPosition.y);
		
		if (gf != null)
		{
			gf.setPosition(currentStage.gfPosition.x, currentStage.gfPosition.y);
			if (currentStage.hideGirlfriend)
				gf.visible = false;
		}
		
		// Character-specific adjustments
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
				camPos.set(dad.getGraphicMidpoint().x + 300 + dadnoteMovementXoffset, 
					dad.getGraphicMidpoint().y + dadnoteMovementYoffset);
			case 'spirit':
				dad.x -= 150;
				dad.y += 100;
				camPos.set(dad.getGraphicMidpoint().x + 300 + dadnoteMovementXoffset, 
					dad.getGraphicMidpoint().y + dadnoteMovementYoffset);
		}
	}
	
	// ═══════════════════════════════════════════════════════════════════════════
	//                          INTRO/COUNTDOWN
	// ═══════════════════════════════════════════════════════════════════════════
	
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
				add(red);
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
		
		talking = false;
		readyaIsntDestroyed = false;
		startedCountdown = true;
		Conductor.songPosition = 0;
		Conductor.songPosition -= Conductor.crochet * 5;
		
		var swagCounter:Int = 0;
		
		introAssets = new Map<String, Array<String>>();
		introAssets.set('default', ['UI/normal/ready', "UI/normal/set", "UI/normal/go"]);
		introAssets.set('school', ['UI/pixelUI/ready-pixel', 'UI/pixelUI/set-pixel', 'UI/pixelUI/date-pixel']);
		
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
					getCountdown(go, 2, 32, true);
					finishCountdown();
			}
			swagCounter += 1;
		}, 5);
	}
	
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
		asset.scrollFactor.set();
		asset.cameras = [camCountdown];
		asset.scale.set(0.8, 0.8);
		
		if (curStage.startsWith('school'))
			asset.setGraphicSize(Std.int(asset.width * daPixelZoom));
		
		asset.updateHitbox();
		asset.screenCenter();
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
			songLength = FlxG.sound.music.length;
			updatePresence();
			#end
		}
	}
	
	// ═══════════════════════════════════════════════════════════════════════════
	//                          SONG GENERATION
	// ═══════════════════════════════════════════════════════════════════════════
	
	private function generateSong(dataPath:String):Void
	{
		var songData = SONG;
		Conductor.changeBPM(songData.bpm);
		curSong = songData.song;
		
		// Load vocals
		if (SONG.needsVoices)
			vocals = new FlxSound().loadEmbedded(Paths.voices(PlayState.SONG.song));
		else
			vocals = new FlxSound();
		
		FlxG.sound.list.add(vocals);
		
		// Create notes group
		notes = new FlxTypedGroup<Note>();
		add(notes);
		
		var noteData:Array<SwagSection> = songData.notes;
		var playerCounter:Int = 0;
		var daBeats:Int = 0;
		
		// Parse chart and create notes
		for (section in noteData)
		{
			var coolSection:Int = Std.int(section.lengthInSteps / 4);
			
			for (songNotes in section.sectionNotes)
			{
				var daStrumTime:Float = songNotes[0];
				var daNoteData:Int = Std.int(songNotes[1] % 4);
				var gottaHitNote:Bool = section.mustHitSection;
				
				if (songNotes[1] > 3)
					gottaHitNote = !section.mustHitSection;
				
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
				
				// Generate sustain notes
				for (susNote in 0...Math.floor(susLength))
				{
					oldNote = unspawnNotes[Std.int(unspawnNotes.length - 1)];
					
					var sustainNote:Note = new Note(daStrumTime + (Conductor.stepCrochet * susNote) + Conductor.stepCrochet, 
						daNoteData, oldNote, true);
					sustainNote.scrollFactor.set();
					unspawnNotes.push(sustainNote);
					sustainNote.mustPress = gottaHitNote;
					
					if (sustainNote.mustPress)
						sustainNote.x += FlxG.width / 2;
				}
				
				swagNote.mustPress = gottaHitNote;
				
				if (swagNote.mustPress)
					swagNote.x += FlxG.width / 2;
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
				FlxTween.tween(babyArrow, {y: babyArrow.y + 10, alpha: 1}, 1, 
					{ease: FlxEase.circOut, startDelay: 0.5 + (0.2 * i)});
			}
			
			babyArrow.ID = i;
			
			switch (player)
			{
				case 0:
					cpuStrums.add(babyArrow);
					if (FlxG.save.data.middlescroll)
						cpuStrums.members[i].visible = false;
				case 1:
					playerStrums.add(babyArrow);
					if (FlxG.save.data.middlescroll)
						playerStrums.members[i].x -= 250;
			}
			
			babyArrow.animation.play('static');
			babyArrow.x += 50;
			babyArrow.x += ((FlxG.width / 2) * player) + 50;
			
			cpuStrums.forEach(function(spr:FlxSprite)
			{
				spr.centerOffsets();
			});
			
			playerStrums.forEach(function(spr:FlxSprite)
			{
				spr.centerOffsets();
			});
			
			strumLineNotes.add(babyArrow);
		}
	}
	
	function tweenCamIn():Void
	{
		FlxTween.tween(FlxG.camera, {zoom: 1.3}, (Conductor.stepCrochet * 4 / 1000), {ease: FlxEase.elasticInOut});
	}
	
	// ═══════════════════════════════════════════════════════════════════════════
	//                              UPDATE LOOP
	// ═══════════════════════════════════════════════════════════════════════════
	
	override public function update(elapsed:Float)
	{
		if (FlxG.keys.justPressed.CONTROL)
			CPUvsCPUMode = false;
		
		songPositionBar = Conductor.songPosition;
		
		// ═══════════════════════════════════════════════════════════════════════
		//                    TRIGGER EVENT SYSTEM HOOKS
		// ═══════════════════════════════════════════════════════════════════════
		
		// Update HScript events
		eventSystem.triggerUpdateEvents(elapsed);
		eventSystem.triggerConditionalEvents();
		
		// Execute custom update hooks (for stages/mods)
		for (hook in onUpdateHooks)
			hook(elapsed);
		
		// ═══════════════════════════════════════════════════════════════════════
		
		// Ready button logic
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
		
		// Update character animations
		updateCharacterAnimations(elapsed);
		
		// Special dad floating effect
		if (dad.curCharacter == 'spirit')
			dad.y += Mathf.sineByTime(elapsed);
		
		// ═══════════════════════════════════════════════════════════════════════
		//                    UPDATE SCORE DISPLAY (ScoreManager)
		// ═══════════════════════════════════════════════════════════════════════
		
		// Sync legacy variables with ScoreManager
		songScore = scoreManager.score;
		misses = scoreManager.misses;
		accuracy = scoreManager.accuracy;
		sicks = scoreManager.sicks;
		goods = scoreManager.goods;
		bads = scoreManager.bads;
		shits = scoreManager.shits;
		
		// Update score text
		if (FlxG.save.data.accuracyDisplay)
			scoreTxt.text = scoreManager.getHUDText();
		else
			scoreTxt.text = 'Score: ${songScore}\nMisses: ${misses}';
		
		// ═══════════════════════════════════════════════════════════════════════
		
		// Pause menu
		if (FlxG.keys.justPressed.ENTER && startedCountdown && canPause)
			pauseMenu();
		
		// Chart editor hotkey
		if (FlxG.keys.justPressed.SEVEN)
			FlxG.switchState(new ChartingState());
		
		// Update health icons
		iconP1.setGraphicSize(Std.int(FlxMath.lerp(150, iconP1.width, 0.50)));
		iconP2.setGraphicSize(Std.int(FlxMath.lerp(150, iconP2.width, 0.50)));
		iconP1.updateHitbox();
		iconP2.updateHitbox();
		
		var iconOffset:Int = 26;
		iconP1.x = healthBar.x + (healthBar.width * (FlxMath.remapToRange(healthBar.percent, 0, 100, 100, 0) * 0.01) - iconOffset);
		iconP2.x = healthBar.x + (healthBar.width * (FlxMath.remapToRange(healthBar.percent, 0, 100, 100, 0) * 0.01)) - (iconP2.width - iconOffset);
		
		// Clamp health
		if (health > 2)
			health = 2;
		
		// Update icon frames based on health
		if (healthBar.percent < 20)
			iconP1.animation.curAnim.curFrame = 1;
		else
			iconP1.animation.curAnim.curFrame = 0;
		
		if (healthBar.percent > 80)
			iconP2.animation.curAnim.curFrame = 1;
		else
			iconP2.animation.curAnim.curFrame = 0;
		
		// Song position updates
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
				
				// Interpolation
				if (Conductor.lastSongPos != Conductor.songPosition)
				{
					songTime = (songTime + Conductor.songPosition) / 2;
					Conductor.lastSongPos = Conductor.songPosition;
				}
			}
		}
		
		// Camera movement
		if (generatedMusic && PlayState.SONG.notes[Std.int(curStep / 16)] != null)
			camMovement(PlayState.SONG.notes[Std.int(curStep / 16)].mustHitSection, elapsed);
		
		// Reset note movement offsets when idle
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
		
		// Camera zoom lerp
		if (camZooming)
		{
			FlxG.camera.zoom = FlxMath.lerp(FlxG.camera.zoom, defaultCamZoom, FlxMath.bound(elapsed * 3.125, 0, 1));
			camHUD.zoom = FlxMath.lerp(camHUD.zoom, 1, FlxMath.bound(elapsed * 3.125, 0, 1));
		}
		
		FlxG.watch.addQuick("beats", curBeat);
		FlxG.watch.addQuick("steps", curStep);
		
		// Game over check
		if (health <= 0)
			gameOver();
		
		// ═══════════════════════════════════════════════════════════════════════
		//                   NOTE SPAWNING & RENDERING (NoteRenderer)
		// ═══════════════════════════════════════════════════════════════════════
		
		// Spawn notes from unspawnNotes array
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
		
		// Update notes using NoteRenderer (optimized with pooling & culling)
		if (generatedMusic && noteRenderer != null)
		{
			noteRenderer.update(Conductor.songPosition, SONG.speed, elapsed);
		}
		
		// ═══════════════════════════════════════════════════════════════════════
		//                          NOTE HIT LOGIC
		// ═══════════════════════════════════════════════════════════════════════
		
		if (generatedMusic)
		{
			notes.forEachAlive(function(daNote:Note)
			{
				// CPU notes (dad/opponent)
				if (!daNote.mustPress && daNote.wasGoodHit)
				{
					if (SONG.song != 'Tutorial')
						camZooming = true;
					
					var altAnim:String = "";
					
					if (SONG.notes[Math.floor(curStep / 16)] != null)
					{
						if (SONG.notes[Math.floor(curStep / 16)].altAnim)
							altAnim = '-alt';
						
						// GF singing logic
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
						
						if (!gf.canSing && gfAnimFinished)
							gf.dance();
					}
					
					// Note splash
					if (FlxG.save.data.notesplashes)
						spawnNoteSplashOnNote(daNote, 0);
					
					// Sing animation
					if (gf.canSing)
					{
						gfAnimFinished = false;
						characterSing(gf, daNote.noteData, altAnim);
					}
					else
					{
						dadAnimFinished = false;
						characterSing(dad, daNote.noteData, altAnim);
					}
					
					// Remove note
					daNote.kill();
					notes.remove(daNote, true);
					
					// Recycle note through NoteRenderer pool
					if (noteRenderer != null)
						noteRenderer.recycleNote(daNote);
				}
				
				// Player notes hit logic
				if (daNote.mustPress)
				{
					// Downscroll position check
					if (FlxG.save.data.downscroll && daNote.y > strumLiney + 106 || !FlxG.save.data.downscroll && daNote.y < strumLiney - 106)
					{
						if (daNote.isSustainNote && daNote.wasGoodHit)
						{
							daNote.kill();
							notes.remove(daNote, true);
							if (noteRenderer != null)
								noteRenderer.recycleNote(daNote);
						}
					}
				}
				
				// Auto-miss notes that are too late
				if (daNote.tooLate || daNote.wasGoodHit)
				{
					if (daNote.tooLate)
					{
						// Process miss
						noteMiss(daNote);
					}
					
					daNote.active = false;
					daNote.visible = false;
					
					daNote.kill();
					notes.remove(daNote, true);
					
					// Recycle note
					if (noteRenderer != null)
						noteRenderer.recycleNote(daNote);
				}
			});
		}
		
		// ═══════════════════════════════════════════════════════════════════════
		//                          PLAYER INPUT
		// ═══════════════════════════════════════════════════════════════════════
		
		keyShit();
	}
	
	// ═══════════════════════════════════════════════════════════════════════════
	//                      CHARACTER ANIMATION CONTROL
	// ═══════════════════════════════════════════════════════════════════════════
	
	/**
	 * Update character animations with optimized timing
	 */
	private function updateCharacterAnimations(elapsed:Float):Void
	{
		// Update hold timers
		dadHoldTimer += elapsed;
		bfHoldTimer += elapsed;
		gfHoldTimer += elapsed;
		
		// Dad animations
		if (dad != null && dad.animation != null && dad.animation.curAnim != null)
		{
			var curAnim = dad.animation.curAnim.name;
			
			// Return to idle after singing
			if (curAnim.startsWith('sing') && !curAnim.endsWith('miss'))
			{
				if (dadHoldTimer > SING_DURATION && dad.canSing)
				{
					dadAnimFinished = true;
					if (!specialAnim)
						dad.dance();
				}
			}
			
			// Reset when idle
			if (curAnim.startsWith('idle') && dadnoteMovementXoffset == 0 && dadnoteMovementYoffset == 0)
				dadAnimFinished = true;
		}
		
		// Boyfriend animations
		if (boyfriend != null && boyfriend.animation != null && boyfriend.animation.curAnim != null)
		{
			var curAnim = boyfriend.animation.curAnim.name;
			
			// Return to idle after singing
			if (curAnim.startsWith('sing') && !curAnim.endsWith('miss') || curAnim.startsWith('hey'))
			{
				var threshold = Conductor.stepCrochet * 4 * 0.001;
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
			
			// Reset offsets when idle
			if (curAnim.startsWith('idle'))
			{
				bfnoteMovementYoffset = 0;
				bfnoteMovementXoffset = 0;
				bfAnimFinished = true;
			}
		}
		
		// GF animations
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
					gfAnimFinished = true;
				}
			}
			else
			{
				gfHoldTimer = 0;
				
				// Reset camera offsets
				if (curAnim.startsWith('dance') || curAnim.startsWith('idle'))
				{
					dadnoteMovementYoffset = 0;
					dadnoteMovementXoffset = 0;
				}
			}
		}
	}
	
	/**
	 * Make a character sing
	 * Handles animation fallback and camera offsets
	 */
	public function characterSing(char:Character, noteData:Int, ?altAnim:String = ""):Void
	{
		if (char == null || !char.canSing)
			return;
		
		// Boyfriend doesn't use alt anims by default
		if (char == boyfriend)
			altAnim = "";
		
		// Build animation name
		var animName:String = 'sing' + notesAnim[noteData] + altAnim;
		
		// Safety: fall back to normal anim if alt doesn't exist
		if (!char.animOffsets.exists(animName) && char.animation.getByName(animName) == null)
			animName = 'sing' + notesAnim[noteData];
		
		// Don't restart same animation (prevents stuttering)
		if (char.animation.curAnim != null && char.animation.curAnim.name == animName)
			return;
		
		char.playAnim(animName, true);
		
		// Reset hold timers
		if (char == dad)
			dadHoldTimer = 0;
		else if (char == boyfriend)
			bfHoldTimer = 0;
		else if (char == gf)
			gfHoldTimer = 0;
		
		// Camera movement offsets
		var camOffsetAmt:Float = 30.0;
		
		// Reset offsets first
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
		
		// Calculate new offset
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
		
		// Apply offset
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
	
	// ═══════════════════════════════════════════════════════════════════════════
	//                          CAMERA MOVEMENT
	// ═══════════════════════════════════════════════════════════════════════════
	
	function camMovement(playerTurn:Bool, elapsed:Float)
	{
		if (playerTurn)
		{
			camFollow.x = boyfriend.getMidpoint().x - 100 + bfnoteMovementXoffset;
			camFollow.y = boyfriend.getMidpoint().y - 100 + bfnoteMovementYoffset;
		}
		else
		{
			camFollow.x = dad.getMidpoint().x + 150 + dadnoteMovementXoffset;
			camFollow.y = dad.getMidpoint().y - 100 + dadnoteMovementYoffset;
		}
	}
	
	// ═══════════════════════════════════════════════════════════════════════════
	//                          NOTE SPLASH EFFECTS
	// ═══════════════════════════════════════════════════════════════════════════
	
	public function spawnNoteSplashOnNote(note:Note, player:Int)
	{
		if (note != null)
		{
			var strum:StrumNote = null;
			
			if (player == 0)
			{
				if (cpuStrums != null && cpuStrums.members[note.noteData] != null)
					strum = cast(cpuStrums.members[note.noteData], StrumNote);
			}
			else
			{
				if (playerStrums != null && playerStrums.members[note.noteData] != null)
					strum = cast(playerStrums.members[note.noteData], StrumNote);
			}
			
			if (strum != null)
			{
				spawnNoteSplash(strum.x, strum.y, note.noteData);
			}
		}
	}
	
	public function spawnNoteSplash(x:Float, y:Float, data:Int)
	{
		var splash:NoteSplash = grpNoteSplashes.recycle(NoteSplash);
		splash.setupNoteSplash(x, y, data);
		grpNoteSplashes.add(splash);
	}
	
	// ═══════════════════════════════════════════════════════════════════════════
	//                     NOTE HIT/MISS PROCESSING
	// ═══════════════════════════════════════════════════════════════════════════
	
	/**
	 * Process note hit using ScoreManager
	 */
	function noteHit(note:Note):Void
	{
		if (!note.wasGoodHit)
		{
			if (!note.isSustainNote)
			{
				// Calculate note timing difference
				var noteDiff:Float = Math.abs(note.strumTime - Conductor.songPosition);
				
				// Process hit through ScoreManager
				var rating:String = scoreManager.processNoteHit(noteDiff);
				
				// Display rating popup
				popUpScore(rating);
				
				// Update combo
				combo = scoreManager.combo;
				
				// Execute custom note hit hooks
				for (hook in onNoteHitHooks)
					hook(note);
			}
			
			// Sing animation
			if (note.mustPress)
			{
				bfAnimFinished = false;
				characterSing(boyfriend, note.noteData);
			}
			
			// Health gain
			if (!note.isSustainNote)
				health += 0.023;
			else
				health += 0.004;
			
			// Mark as hit
			note.wasGoodHit = true;
			vocals.volume = 1;
			
			// Sustain note clipping
			if (note.isSustainNote)
			{
				note.active = false;
			}
		}
	}
	
	/**
	 * Process note miss using ScoreManager
	 */
	function noteMiss(note:Note):Void
	{
		// Process miss through ScoreManager
		scoreManager.processMiss();
		
		// Update combo
		combo = 0;
		
		// Execute custom note miss hooks
		for (hook in onNoteMissHooks)
			hook(note);
		
		// Play miss sound
		FlxG.sound.play(Paths.soundRandom('missnote', 1, 3), FlxG.random.float(0.1, 0.2));
		
		// Miss animation
		if (boyfriend != null)
			boyfriend.playAnim('sing' + notesAnim[note.noteData] + 'miss', true);
		
		// Health penalty
		health -= 0.04;
		vocals.volume = 0;
		
		// Perfect/Sick mode penalties
		if (FlxG.save.data.perfectmode)
			health = 0;
		
		if (FlxG.save.data.sickmode && scoreManager.sickCombo)
			health = 0;
	}
	
	/**
	 * Display rating popup
	 */
	function popUpScore(rating:String):Void
	{
		var pixelShitPart1:String = "";
		var pixelShitPart2:String = '';
		
		if (curStage.startsWith('school'))
		{
			pixelShitPart1 = 'weeb/pixelUI/';
			pixelShitPart2 = '-pixel';
		}
		
		var ratingPath:String = pixelShitPart1 + rating + pixelShitPart2;
		
		var ratingSprite:FlxSprite = new FlxSprite().loadGraphic(Paths.image(ratingPath));
		ratingSprite.screenCenter();
		ratingSprite.x = FlxG.width * 0.55 - 40;
		ratingSprite.y -= 60;
		ratingSprite.acceleration.y = 550;
		ratingSprite.velocity.y -= FlxG.random.int(140, 175);
		ratingSprite.velocity.x -= FlxG.random.int(0, 10);
		
		if (curStage.startsWith('school'))
		{
			ratingSprite.setGraphicSize(Std.int(ratingSprite.width * daPixelZoom * 0.7));
		}
		else
		{
			ratingSprite.setGraphicSize(Std.int(ratingSprite.width * 0.7));
			ratingSprite.antialiasing = true;
		}
		
		ratingSprite.updateHitbox();
		
		add(ratingSprite);
		
		FlxTween.tween(ratingSprite, {alpha: 0}, 0.2, {
			onComplete: function(tween:FlxTween)
			{
				ratingSprite.destroy();
			},
			startDelay: Conductor.crochet * 0.001
		});
		
		// Combo popup
		if (combo >= 10)
		{
			var comboSpr:FlxSprite = new FlxSprite().loadGraphic(Paths.image(pixelShitPart1 + 'combo' + pixelShitPart2));
			comboSpr.screenCenter();
			comboSpr.x = FlxG.width * 0.55;
			comboSpr.y -= 60;
			comboSpr.acceleration.y = 600;
			comboSpr.velocity.y -= 150;
			
			if (curStage.startsWith('school'))
			{
				comboSpr.setGraphicSize(Std.int(comboSpr.width * daPixelZoom * 0.7));
			}
			else
			{
				comboSpr.setGraphicSize(Std.int(comboSpr.width * 0.7));
				comboSpr.antialiasing = true;
			}
			
			comboSpr.updateHitbox();
			add(comboSpr);
			
			FlxTween.tween(comboSpr, {alpha: 0}, 0.2, {
				onComplete: function(tween:FlxTween)
				{
					comboSpr.destroy();
				},
				startDelay: Conductor.crochet * 0.001
			});
		}
	}
	
	// ═══════════════════════════════════════════════════════════════════════════
	//                          PLAYER INPUT
	// ═══════════════════════════════════════════════════════════════════════════
	
	function keyShit():Void
	{
		var upP = controls.UP_P;
		var rightP = controls.RIGHT_P;
		var downP = controls.DOWN_P;
		var leftP = controls.LEFT_P;
		
		var upR = controls.UP_R;
		var rightR = controls.RIGHT_R;
		var downR = controls.DOWN_R;
		var leftR = controls.LEFT_R;
		
		var controlArray:Array<Bool> = [leftP, downP, upP, rightP];
		
		// Press logic
		if (controlArray.contains(true) && generatedMusic)
		{
			boyfriend.holdTimer = 0;
			
			var possibleNotes:Array<Note> = [];
			var directionList:Array<Int> = [];
			var dumbNotes:Array<Note> = [];
			
			notes.forEachAlive(function(daNote:Note)
			{
				if (daNote.canBeHit && daNote.mustPress && !daNote.tooLate && !daNote.wasGoodHit)
				{
					if (directionList.contains(daNote.noteData))
					{
						for (coolNote in possibleNotes)
						{
							if (coolNote.noteData == daNote.noteData && Math.abs(daNote.strumTime - coolNote.strumTime) < 10)
							{
								dumbNotes.push(daNote);
								break;
							}
							else if (coolNote.noteData == daNote.noteData && daNote.strumTime < coolNote.strumTime)
							{
								possibleNotes.remove(coolNote);
								possibleNotes.push(daNote);
								break;
							}
						}
					}
					else
					{
						possibleNotes.push(daNote);
						directionList.push(daNote.noteData);
					}
				}
			});
			
			for (note in dumbNotes)
			{
				FlxG.log.add("killing dumb ass note at " + note.strumTime);
				note.kill();
				notes.remove(note, true);
				if (noteRenderer != null)
					noteRenderer.recycleNote(note);
			}
			
			possibleNotes.sort((a, b) -> Std.int(a.strumTime - b.strumTime));
			
			var dontCheck = false;
			
			for (i in 0...controlArray.length)
			{
				if (controlArray[i] && !directionList.contains(i))
					dontCheck = true;
			}
			
			if (possibleNotes.length > 0 && !dontCheck)
			{
				for (i in 0...possibleNotes.length)
				{
					var daNote = possibleNotes[i];
					
					if (controlArray[daNote.noteData])
					{
						noteHit(daNote);
					}
				}
			}
			else if (!FlxG.save.data.ghost)
			{
				// Ghost tapping disabled - miss on bad input
				for (i in 0...controlArray.length)
				{
					if (controlArray[i])
						noteMissPress(i);
				}
			}
		}
		
		// Release logic
		if ((upR || rightR || downR || leftR) && generatedMusic)
		{
			notes.forEachAlive(function(daNote:Note)
			{
				if (daNote.isSustainNote && daNote.wasGoodHit)
				{
					var released:Bool = false;
					
					if (daNote.noteData == 0 && leftR)
						released = true;
					else if (daNote.noteData == 1 && downR)
						released = true;
					else if (daNote.noteData == 2 && upR)
						released = true;
					else if (daNote.noteData == 3 && rightR)
						released = true;
					
					if (released)
					{
						daNote.kill();
						notes.remove(daNote, true);
						if (noteRenderer != null)
							noteRenderer.recycleNote(daNote);
					}
				}
			});
		}
	}
	
	function noteMissPress(direction:Int = 1):Void
	{
		if (!boyfriend.stunned)
		{
			health -= 0.05;
			
			if (combo > 5 && gf.animOffsets.exists('sad'))
				gf.playAnim('sad');
			
			combo = 0;
			scoreManager.combo = 0;
			
			if (!boyfriend.animation.curAnim.name.startsWith('sing'))
				boyfriend.playAnim('sing' + notesAnim[direction] + 'miss', true);
			
			vocals.volume = 0;
		}
	}
	
	// ═══════════════════════════════════════════════════════════════════════════
	//                          BEAT/STEP EVENTS
	// ═══════════════════════════════════════════════════════════════════════════
	
	override function beatHit()
	{
		super.beatHit();
		
		// ═══════════════════════════════════════════════════════════════════════
		//                    TRIGGER EVENT SYSTEM HOOKS
		// ═══════════════════════════════════════════════════════════════════════
		
		// Trigger HScript beat events
		eventSystem.triggerBeatEvents(curBeat);
		
		// Execute custom beat hooks (for stages/mods)
		for (hook in onBeatHitHooks)
			hook(curBeat);
		
		// ═══════════════════════════════════════════════════════════════════════
		
		// Stage beat events
		if (currentStage != null)
			currentStage.beatHit(curBeat);
		
		wiggleShit.update(Conductor.crochet);
		
		// MILF zoom hardcoding
		if (curSong.toLowerCase() == 'milf' && curBeat >= 168 && curBeat < 200 && camZooming && FlxG.camera.zoom < 1.35)
		{
			FlxG.camera.zoom += 0.015;
			camHUD.zoom += 0.03;
		}
		
		// Beat zoom
		if (camZooming && FlxG.camera.zoom < 1.35 && curBeat % 4 == 0)
		{
			FlxG.camera.zoom *= 1.015;
			camHUD.zoom += 0.03;
		}
		
		// Icon bop
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
		
		// GF dance
		if (curBeat % gfSpeed == 0)
		{
			if (gf != null && gfAnimFinished)
			{
				gf.dance();
				gfHoldTimer = 0;
			}
		}
		
		// Boyfriend idle
		if (boyfriend != null && boyfriend.animation != null && boyfriend.animation.curAnim != null)
		{
			if (!boyfriend.animation.curAnim.name.startsWith("sing") && boyfriend.canSing && bfAnimFinished)
			{
				boyfriend.dance();
				bfHoldTimer = 0;
				specialAnim = false;
			}
		}
		
		// Dad idle
		if (dad != null && dad.animation != null && dad.animation.curAnim != null)
		{
			if (!dad.animation.curAnim.name.startsWith("sing") && dad.canSing && dadAnimFinished)
			{
				switch (dad.curCharacter)
				{
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
						}
					default:
						dad.dance();
				}
				dadHoldTimer = 0;
				specialAnim = false;
			}
		}
		
		// Song-specific events
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
	
	override function stepHit()
	{
		super.stepHit();
		
		// ═══════════════════════════════════════════════════════════════════════
		//                    TRIGGER EVENT SYSTEM HOOKS
		// ═══════════════════════════════════════════════════════════════════════
		
		// Trigger HScript step events
		eventSystem.triggerStepEvents(curStep);
		
		// Execute custom step hooks (for stages/mods)
		for (hook in onStepHitHooks)
			hook(curStep);
		
		// ═══════════════════════════════════════════════════════════════════════
		
		// Resync vocals if needed
		if (FlxG.sound.music.time > Conductor.songPosition + 20 || FlxG.sound.music.time < Conductor.songPosition - 20)
		{
			resyncVocals();
		}
	}
	
	// ═══════════════════════════════════════════════════════════════════════════
	//                          PAUSE/RESUME
	// ═══════════════════════════════════════════════════════════════════════════
	
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
				resyncVocals();
			
			if (!startTimer.finished)
				startTimer.active = true;
			
			paused = false;
			
			#if desktop
			updatePresence();
			#end
		}
		
		super.closeSubState();
	}
	
	function pauseMenu()
	{
		paused = true;
		openSubState(new PauseSubState(boyfriend.getScreenPosition().x, boyfriend.getScreenPosition().y));
	}
	
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
	
	// ═══════════════════════════════════════════════════════════════════════════
	//                          GAME OVER
	// ═══════════════════════════════════════════════════════════════════════════
	
	function gameOver()
	{
		boyfriend.stunned = true;
		
		persistentUpdate = false;
		persistentDraw = false;
		paused = true;
		
		vocals.stop();
		FlxG.sound.music.stop();
		
		openSubState(new GameOverSubstate(boyfriend.getScreenPosition().x, boyfriend.getScreenPosition().y));
		
		#if desktop
		updatePresence(false, "Game Over - " + detailsText);
		#end
	}
	
	// ═══════════════════════════════════════════════════════════════════════════
	//                          END SONG
	// ═══════════════════════════════════════════════════════════════════════════
	
	function endSong():Void
	{
		songEnd = true;
		canPause = false;
		FlxG.sound.music.volume = 0;
		vocals.volume = 0;
		
		// Save highscore using ScoreManager
		if (!isStoryMode)
		{
			scoreManager.saveHighscore(SONG.song, storyDifficulty);
		}
		
		if (isStoryMode)
		{
			campaignScore += songScore;
			
			storyPlaylist.remove(storyPlaylist[0]);
			
			if (storyPlaylist.length <= 0)
			{
				FlxG.sound.playMusic(Paths.music('freakyMenu'));
				MainMenuState.musicFreakyisPlaying = true;
				
				FlxG.switchState(new StoryMenuState());
				
				StoryMenuState.weekUnlocked[Std.int(Math.min(storyWeek + 1, StoryMenuState.weekUnlocked.length - 1))] = true;
				
				FlxG.save.data.weekUnlocked = StoryMenuState.weekUnlocked;
				FlxG.save.flush();
			}
			else
			{
				var difficulty:String = "";
				
				if (storyDifficulty == 0)
					difficulty = '-easy';
				
				if (storyDifficulty == 2)
					difficulty = '-hard';
				
				FlxTransitionableState.skipNextTransIn = true;
				FlxTransitionableState.skipNextTransOut = true;
				prevCamFollow = camFollow;
				
				PlayState.SONG = Song.loadFromJson(PlayState.storyPlaylist[0].toLowerCase() + difficulty, PlayState.storyPlaylist[0]);
				FlxG.sound.music.stop();
				
				FlxG.switchState(new PlayState());
			}
		}
		else
		{
			FlxG.switchState(new FreeplayState());
		}
	}
	
	// ═══════════════════════════════════════════════════════════════════════════
	//                          MISC HELPERS
	// ═══════════════════════════════════════════════════════════════════════════
	
	function dialogueFile(dialogue:String)
	{
		return CoolUtil.coolTextFile(Paths.songsTxt('${SONG.song.toLowerCase()}/${dialogue}'));
	}
	
	/**
	 * Get cached section to avoid repeated array access
	 * OPTIMIZATION: Cache section lookup
	 */
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
	
	#if desktop
	function updatePresence(?gameOver:Bool = false, ?detailsOverride:String = "")
	{
		if (detailsOverride != "")
			DiscordClient.changePresence(detailsOverride, SONG.song + " (" + storyDifficultyText + ")", iconRPC);
		else
			DiscordClient.changePresence(detailsText, SONG.song + " (" + storyDifficultyText + ")", iconRPC, true, songLength);
	}
	#end
	
	// ═══════════════════════════════════════════════════════════════════════════
	//                          CLEANUP
	// ═══════════════════════════════════════════════════════════════════════════
	
	override function destroy()
	{
		// Cleanup integrated systems
		if (noteRenderer != null)
		{
			noteRenderer.destroy();
			noteRenderer = null;
		}
	}