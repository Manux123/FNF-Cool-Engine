package;

import flixel.FlxG;
import flixel.FlxGame;
import flixel.FlxState;
import openfl.Assets;
import openfl.Lib;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.display.StageScaleMode;
import openfl.display.StageAlign;
import CacheState;
import ui.DataInfoUI;
import ui.SoundTray;
import funkin.menus.TitleState;
import data.PlayerSettings;

#if debug
import openfl.events.UncaughtErrorEvent;
import haxe.CallStack;
import haxe.io.Path;
import funkin.debug.DebugConsole;
#end

import funkin.transitions.StickerTransition;

#if desktop
import data.Discord.DiscordClient;
import sys.thread.Thread;
#end

#if sys
import sys.FileSystem;
import sys.io.File;
#end

// Initialization modules
import funkin.data.KeyBinds;
import funkin.gameplay.notes.NoteSkinSystem;
import extensions.CppAPI;

using StringTools;

/**
 * Main entry point for Cool Engine
 * Handles game initialization, configuration, and core setup
 * 
 * @author Cool Engine Team
 * @version 0.4.0B
 */
class Main extends Sprite
{
	// ==================== GAME CONFIGURATION ====================
	
	/** Game window dimensions */
	private var gameWidth:Int = 1280;
	private var gameHeight:Int = 720;
	
	/** Initial game state */
	private var initialState:Class<FlxState> = CacheState;
	
	/** Zoom level (-1 for automatic calculation) */
	private var zoom:Float = -1;
	
	/** Target framerate */
	private var framerate:Int = 120;
	
	/** Skip HaxeFlixel splash screen */
	private var skipSplash:Bool = true;
	
	/** Start in fullscreen mode */
	private var startFullscreen:Bool = false;
	
	// ==================== UI COMPONENTS ====================
	
	/** Data/FPS overlay */
	public final data:DataInfoUI = new DataInfoUI(10, 3);
	
	// ==================== STATIC ENTRY POINT ====================
	
	/**
	 * Application entry point
	 * Called by OpenFL runtime
	 */
	public static function main():Void
	{
		Lib.current.addChild(new Main());
	}
	
	// ==================== CONSTRUCTOR ====================
	
	public function new()
	{
		super();
		
		if (stage != null)
		{
			init();
		}
		else
		{
			addEventListener(Event.ADDED_TO_STAGE, init);
		}
	}
	
	// ==================== INITIALIZATION ====================
	
	/**
	 * Initialize the application
	 * Called when added to stage
	 */
	private function init(?E:Event):Void
	{
		if (hasEventListener(Event.ADDED_TO_STAGE))
		{
			removeEventListener(Event.ADDED_TO_STAGE, init);
		}
		
		setupStage();
		setupGame();
	}
	
	/**
	 * Configure stage properties
	 * Sets up scaling, alignment, and quality
	 */
	private function setupStage():Void
	{
		stage.scaleMode = StageScaleMode.NO_SCALE;
		stage.align = StageAlign.TOP_LEFT;
		stage.quality = openfl.display.StageQuality.LOW; // Better performance
	}
	
	/**
	 * Main game setup
	 * Initializes all game systems and subsystems
	 */
	private function setupGame():Void
	{
		// Calculate optimal zoom level
		calculateZoom();
		
		// Setup crash handler (debug builds only)
		#if CRASH_HANDLER
		setupCrashHandler();
		#end
		
		// Initialize debugging tools
		#if debug
		DebugConsole.init();
		#end
		
		// Set window background color (black)
		CppAPI.changeColor(0, 0, 0);
		
		// Create the FlxGame instance FIRST (required for FlxG to be initialized)
		createGame();

		StickerTransition.init();
		
		// Now initialize systems that depend on FlxG
		initializeSaveSystem();
		initializeGameSystems();
		initializeFramerate();
		
		// Add UI overlays
		addChild(data);
		
		// Initialize global SoundTray (will be added to each state automatically)
		FlxG.plugins.add(new SoundTray());
		
		// Disable default FlxG sound tray (using custom SoundTray)
		disableDefaultSoundTray();
		
		// Initialize Discord Rich Presence
		#if desktop
		DiscordClient.initialize();
		#end
	}
	
	// ==================== SYSTEM INITIALIZATION ====================
	
	/**
	 * Calculate and set optimal zoom level
	 * Adjusts game dimensions to fit window
	 */
	private function calculateZoom():Void
	{
		if (zoom == -1)
		{
			var stageWidth:Int = Lib.current.stage.stageWidth;
			var stageHeight:Int = Lib.current.stage.stageHeight;
			
			zoom = Math.min(stageWidth / gameWidth, stageHeight / gameHeight);
			gameWidth = Math.ceil(stageWidth / zoom);
			gameHeight = Math.ceil(stageHeight / zoom);
		}
	}
	
	/**
	 * Initialize save data system
	 * Binds save file and loads persistent data
	 */
	private function initializeSaveSystem():Void
	{
		// Bind save file (company: manux, project: coolengine)
		FlxG.save.bind('coolengine', 'manux');
		
		// Initialize options data (creates default settings if needed)
		funkin.menus.OptionsMenuState.OptionsData.initSave();
		
		// Load high scores
		funkin.gameplay.objects.hud.Highscore.load();
	}
	
	/**
	 * Initialize game-specific systems
	 * Sets up keybinds, note skins, player settings, etc.
	 */
	private function initializeGameSystems():Void
	{
		// Initialize note skin system
		NoteSkinSystem.init();
		
		// Load and verify key bindings
		KeyBinds.keyCheck();
		
		// Initialize player settings
		PlayerSettings.init();
		PlayerSettings.player1.controls.loadKeyBinds();

		FlxG.mouse.useSystemCursor = false;
		FlxG.mouse.load(Paths.image('menu/cursor/cursor-default'));
	}
	
	/**
	 * Set target framerate based on platform
	 * Uses lower framerate on web/mobile for better performance
	 */
	private function initializeFramerate():Void
	{
		#if (!html5 && !androidC)
		// Desktop/powerful platforms: 120 FPS
		framerate = 120;
		#else
		// Web/mobile: 60 FPS
		framerate = 60;
		#end
		
		// Apply FPS cap from saved settings
		if (FlxG.save.data.FPSCap != null && FlxG.save.data.FPSCap)
		{
			setMaxFps(120);
		}
		else
		{
			setMaxFps(240);
		}
	}
	
	/**
	 * Create the main FlxGame instance
	 * Initializes HaxeFlixel game engine
	 */
	private function createGame():Void
	{
		addChild(new FlxGame(
			gameWidth, 
			gameHeight, 
			initialState, 
			#if (flixel < "5.0.0") zoom, #end
			framerate, 
			framerate, 
			skipSplash, 
			startFullscreen
		));
	}
	
	/**
	 * Disable HaxeFlixel's default sound tray
	 * We use a custom SoundTray implementation
	 */
	private function disableDefaultSoundTray():Void
	{
		// Disable default volume key bindings
		FlxG.sound.volumeUpKeys = null;
		FlxG.sound.volumeDownKeys = null;
		FlxG.sound.muteKeys = null;
		
		// Hide and disable the built-in sound tray UI
		#if FLX_SOUND_SYSTEM
		@:privateAccess
		{
			if (FlxG.game.soundTray != null)
			{
				FlxG.game.soundTray.visible = false;
				FlxG.game.soundTray.active = false;
			}
		}
		#end
	}
	
	// ==================== CRASH HANDLER ====================
	
	#if CRASH_HANDLER
	/**
	 * Setup crash handler for uncaught errors
	 * Logs crashes to file and displays error dialog
	 */
	private function setupCrashHandler():Void
	{
		Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(
			UncaughtErrorEvent.UNCAUGHT_ERROR, 
			onCrash
		);
	}
	
	/**
	 * Handle uncaught errors
	 * Creates crash log and displays error to user
	 */
	private function onCrash(e:UncaughtErrorEvent):Void
	{
		var errorMessage:String = "";
		var crashPath:String;
		var callStack:Array<StackItem> = CallStack.exceptionStack(true);
		var timestamp:String = Date.now().toString();
		
		// Sanitize timestamp for filename
		timestamp = timestamp.replace(" ", "_");
		timestamp = timestamp.replace(":", "'");
		
		crashPath = "./crash/CoolEngine_" + timestamp + ".txt";
		
		// Build error message from call stack
		for (stackItem in callStack)
		{
			switch (stackItem)
			{
				case FilePos(s, file, line, column):
					errorMessage += file + " (line " + line + ")\n";
				default:
					Sys.println(stackItem);
			}
		}
		
		errorMessage += "\nUncaught Error: " + e.error;
		errorMessage += "\n\nPlease report this error to: https://github.com/Manux123/FNF-Cool-Engine";
		errorMessage += "\n\n> Crash Handler written by: sqirra-rng";
		
		// Save crash log
		saveCrashLog(crashPath, errorMessage);
		
		// Display error to user
		Sys.println(errorMessage);
		Sys.println("Crash dump saved in " + Path.normalize(crashPath));
		
		lime.app.Application.current.window.alert(errorMessage, "Cool Engine - Fatal Error");
		
		// Shutdown Discord RPC if active
		#if DISCORD_ALLOWED
		DiscordClient.shutdown();
		#end
		
		// Exit application
		Sys.exit(1);
	}
	
	/**
	 * Save crash log to file
	 * Creates crash directory if it doesn't exist
	 */
	private function saveCrashLog(path:String, content:String):Void
	{
		#if sys
		try
		{
			if (!FileSystem.exists("./crash/"))
			{
				FileSystem.createDirectory("./crash/");
			}
			
			File.saveContent(path, content + "\n");
		}
		catch (e:Dynamic)
		{
			Sys.println("Failed to save crash log: " + e);
		}
		#end
	}
	#end
	
	// ==================== PUBLIC API ====================
	
	/**
	 * Set maximum framerate
	 * @param fps Target frames per second
	 */
	public function setMaxFps(fps:Int):Void
	{
		openfl.Lib.current.stage.frameRate = fps;
	}
	
	/**
	 * Get current game instance
	 * @return FlxGame instance
	 */
	public static function getGame():FlxGame
	{
		return cast(Lib.current.getChildAt(0), FlxGame);
	}
}
