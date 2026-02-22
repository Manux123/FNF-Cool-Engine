package;

import flixel.FlxG;
import flixel.FlxGame;
import flixel.FlxState;
import flixel.FlxSprite;
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

import CrashHandler;

#if debug
import funkin.debug.DebugConsole;
#end

import funkin.transitions.StickerTransition;

import openfl.system.System;

#if (desktop && cpp)
import data.Discord.DiscordClient;
import sys.thread.Thread;
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
 * @version 0.4.1B
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
		stage.align     = StageAlign.TOP_LEFT;
		// LOW = sin antialiasing de líneas vectoriales → menos trabajo del rasterizador.
		// Las notas y personajes usan texturas rasterizadas propias, no primitivas vectoriales.
		stage.quality   = openfl.display.StageQuality.LOW;

		// ── GC tuning (Haxe/hxcpp) ───────────────────────────────────────────
		// Objetivo: evitar pausas de GC durante el gameplay.
		//
		// setMinimumFreeSpace: cuánta RAM libre antes de que el GC haga major-GC.
		//   Más espacio libre → el GC actúa menos frecuentemente → menos stutters.
		//   Contrapartida: el proceso puede tener más RAM "reservada" entre GCs.
		//
		// setTargetHeapSize: reservar un heap fijo de ~192 MB de entrada.
		//   Sin esto el GC hace un major-GC cada vez que el heap crece más allá
		//   del objetivo, lo cual coincide con la carga de personajes/stage.
		//
		// threadPool: aumentar el pool de threads del GC concurrente para
		//   mover trabajo de GC fuera del thread principal.
		#if cpp
		// 32 MB de espacio libre antes de que el GC haga un major-cycle.
		// Codename Engine tiene objetos mas ligeros, asi que con 16 MB bastaba.
		// Con el lazy spawning de notas ya eliminamos la mayor presion al GC,
		// pero subir el threshold a 32 MB evita los picos durante carga de personajes.
		cpp.vm.Gc.setMinimumFreeSpace(32 * 1024 * 1024);
		cpp.vm.Gc.enable(true);
		#end

		// OpenFL uses hardware rendering automatically when available.
		// No manual renderer override needed — forcing __renderer = null
		// destroys the renderer entirely and causes a black screen.
	}
	
	/**
	 * Main game setup
	 * Initializes all game systems and subsystems
	 */
	private function setupGame():Void
	{
		// Calculate optimal zoom level
		calculateZoom();
		
		// Setup crash handler — activo en todas las builds de escritorio
		CrashHandler.init();
		
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

		mods.ModManager.init();
		
		// ── Callback de cambio de mod: limpiar caches ─────────────────────────
		// Cuando el usuario activa otro mod, liberamos los assets del anterior
		// para que no ocupen memoria innecesariamente.
		mods.ModManager.onModChanged = function(newMod:Null<String>)
		{
			Paths.forceClearCache();
			// Recargar lista de personajes/stages para incluir los del nuevo mod
			funkin.gameplay.objects.character.CharacterList.reload();
			#if cpp cpp.vm.Gc.run(true); #end
			#if hl  hl.Gc.major();       #end
			trace('[Main] Cache limpiado por cambio de mod → ${newMod ?? "base"}');
		};
		
		// Initialize Discord Rich Presence
		#if (desktop && cpp)
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
		
		// Aplicar FPS cap guardado (fpsTarget = Int, FPSCap = Bool legacy).
		// Si fpsTarget existe lo usamos; si no, migramos el flag binario viejo.
		if (FlxG.save.data.fpsTarget != null)
		{
			setMaxFps(Std.int(FlxG.save.data.fpsTarget));
		}
		else if (FlxG.save.data.FPSCap != null && FlxG.save.data.FPSCap)
		{
			// Migrar flag viejo: FPSCap=true era 120, false era 240
			FlxG.save.data.fpsTarget = 120;
			setMaxFps(120);
		}
		else
		{
			// Default 60 FPS (antes era 240, que consumia CPU sin beneficio visible)
			FlxG.save.data.fpsTarget = 60;
			setMaxFps(60);
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

		// ── Draw frame rate separado del update ────────────────────────────────
		// Permite actualizar lógica a 120hz pero renderizar a 60hz si el hardware
		// no puede sostener 120 FPS — evita stuttering en máquinas lentas.
		// Se ajusta automáticamente en initializeFramerate().
		FlxG.drawFramerate = framerate;
		FlxG.updateFramerate = framerate;

		// ── Desactivar el antialiasing global por defecto ──────────────────────
		// Cada sprite puede activarlo individualmente. A nivel global consume GPU.
		FlxSprite.defaultAntialiasing = false;
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
