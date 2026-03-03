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

import funkin.transitions.StickerTransition;
import openfl.system.System;

import funkin.audio.AudioConfig;
import funkin.data.CameraUtil;
import funkin.system.MemoryUtil;
import funkin.system.SystemInfo;
import funkin.system.WindowManager;
import funkin.system.WindowManager.ScaleMode;
import funkin.cache.PathsCache;
import funkin.cache.FunkinCache;

import extensions.CppAPI;
import extensions.InitAPI;

#if (desktop && cpp)
import data.Discord.DiscordClient;
import sys.thread.Thread;
#end

import funkin.data.KeyBinds;
import funkin.gameplay.notes.NoteSkinSystem;

using StringTools;

/**
 * Main — punto de entrada de Cool Engine.
 *
 * ─── Orden de inicialización ─────────────────────────────────────────────────
 *  1. DPI-awareness + dark mode (antes de cualquier ventana)
 *  2. GC tuning (antes de cargar nada)
 *  3. Stage config
 *  4. AudioConfig.load() (antes de createGame → antes de que OpenAL se init)
 *  5. CrashHandler, DebugConsole
 *  6. createGame() → FlxG disponible
 *  7. AudioConfig.applyToFlixel()
 *  8. WindowManager.init() → suscripción a resize, scale mode
 *  9. Sistemas que dependen de FlxG (save, keybinds, nota skins…)
 * 10. UI overlays
 * 11. SystemInfo.init() (necesita context3D → después del primer frame)
 *
 * @author Cool Engine Team
 * @version 0.5.1
 */
class Main extends Sprite
{
	// ── Configuración del juego ────────────────────────────────────────────────

	private static inline var GAME_WIDTH:Int  = 1280;
	private static inline var GAME_HEIGHT:Int = 720;
	private static inline var BASE_FPS:Int    = 120;

	private var gameWidth:Int  = GAME_WIDTH;
	private var gameHeight:Int = GAME_HEIGHT;
	private var zoom:Float     = -1;
	private var framerate:Int  = BASE_FPS;
	private var skipSplash:Bool       = true;
	private var startFullscreen:Bool  = false;

	private var initialState:Class<FlxState> = CacheState;

	// ── UI ────────────────────────────────────────────────────────────────────

	public final data:DataInfoUI = new DataInfoUI(10, 3);

	// ── Versiones ─────────────────────────────────────────────────────────────

	public static inline var ENGINE_VERSION:String = "0.6.0";

	// ── Entry point ───────────────────────────────────────────────────────────

	@:keep
	static function __init__():Void
	{
		#if (windows && cpp)
		InitAPI.setDPIAware();
		#end
	}

	public static function main():Void
	{
		Lib.current.addChild(new Main());
	}

	// ── Constructor ───────────────────────────────────────────────────────────

	public function new()
	{
		super();

		if (stage != null)
			init();
		else
			addEventListener(Event.ADDED_TO_STAGE, init);
	}

	// ── Init ─────────────────────────────────────────────────────────────────

	private function init(?e:Event):Void
	{
		if (hasEventListener(Event.ADDED_TO_STAGE))
			removeEventListener(Event.ADDED_TO_STAGE, init);

		setupStage();
		setupGame();
	}

	private function setupStage():Void
	{
		stage.scaleMode = StageScaleMode.NO_SCALE;
		stage.align     = StageAlign.TOP_LEFT;
		stage.quality   = openfl.display.StageQuality.LOW;

		#if cpp
		cpp.vm.Gc.setMinimumFreeSpace(32 * 1024 * 1024);
		cpp.vm.Gc.enable(true);
		#end

		#if (windows && cpp)
		InitAPI.setDarkMode(true);
		CppAPI.changeColor(0, 0, 0);
		#end
	}

	private function setupGame():Void
	{
		calculateZoom();

		// ── Audio (ANTES de createGame) ────────────────────────────────────────
		AudioConfig.load();

		// ── CrashHandler ──────────────────────────────────────────────────────
		CrashHandler.init();

		// ── Juego ─────────────────────────────────────────────────────────────
		createGame();
		FunkinCache.init();
		AudioConfig.applyToFlixel();
		StickerTransition.init();

		// ── WindowManager ──────────────────────────────────────────────────────
		WindowManager.init(
			/* mode    */ LETTERBOX,
			/* minW    */ 960,
			/* minH    */ 540,
			/* baseW   */ GAME_WIDTH,
			/* baseH   */ GAME_HEIGHT
		);

		// ── FIX: Tamaño inicial de ventana más grande ──────────────────────────
		#if !html5
		if (lime.app.Application.current?.window != null)
		{
			lime.app.Application.current.window.resize(1280, 720);
			WindowManager.centerOnScreen();
		}
		#end

		// ── Sistemas que dependen de FlxG ─────────────────────────────────────
		initializeSaveSystem();
		initializeGameSystems();
		initializeFramerate();
		initializeCameras();

		// ── UI overlays ───────────────────────────────────────────────────────
		addChild(data);
		FlxG.plugins.add(new SoundTray());
		disableDefaultSoundTray();

		// ── Mods ──────────────────────────────────────────────────────────────
		mods.ModManager.init();
		mods.ModManager.applyStartupMod();
		WindowManager.applyModBranding(mods.ModManager.activeInfo());
		#if (desktop && cpp)
		DiscordClient.applyModConfig(mods.ModManager.activeInfo());
		#end
		mods.ModManager.onModChanged = function(newMod:Null<String>)
		{
			Paths.forceClearCache();
			funkin.gameplay.objects.character.CharacterList.reload();
			MemoryUtil.collectMajor();
			trace('[Main] Cache cleaned. Mod active → ${newMod ?? "base"}');
			WindowManager.applyModBranding(mods.ModManager.activeInfo());
			#if (desktop && cpp)
			DiscordClient.applyModConfig(mods.ModManager.activeInfo());
			#end
		};

		// ── Discord ───────────────────────────────────────────────────────────
		#if (desktop && cpp)
		DiscordClient.initialize();
		#end

		// ── SystemInfo (deferred al primer frame) ──────────────────────────────
		stage.addEventListener(openfl.events.Event.ENTER_FRAME, _initSystemInfoDeferred);
	}

	// ── ENTER_FRAME deferred ──────────────────────────────────────────────────

	private function _initSystemInfoDeferred(_:openfl.events.Event):Void
	{
		stage.removeEventListener(openfl.events.Event.ENTER_FRAME, _initSystemInfoDeferred);
		SystemInfo.init();
	}

	// ── Helpers de inicialización ─────────────────────────────────────────────

	private function calculateZoom():Void
	{
		if (zoom == -1)
		{
			var stageW:Int = Lib.current.stage.stageWidth;
			var stageH:Int = Lib.current.stage.stageHeight;
			zoom       = Math.min(stageW / gameWidth, stageH / gameHeight);
			gameWidth  = Math.ceil(stageW / zoom);
			gameHeight = Math.ceil(stageH / zoom);
		}
	}

	private function createGame():Void
	{
		addChild(new FlxGame(
			gameWidth, gameHeight, initialState,
			#if (flixel < "5.0.0") zoom, #end
			framerate, framerate, skipSplash, startFullscreen
		));

		// FIX: drawFramerate y updateFramerate se asignan solo en initializeFramerate()
		// para evitar el error "Invalid field" al llamarlos antes de que FlxG esté listo.
		// NO se duplican aquí.

		FlxSprite.defaultAntialiasing = false;
	}

	private function initializeSaveSystem():Void
	{
		FlxG.save.bind('coolengine', 'manux');
		funkin.menus.OptionsMenuState.OptionsData.initSave();
		funkin.gameplay.objects.hud.Highscore.load();
	}

	private function initializeGameSystems():Void
	{
		NoteSkinSystem.init();
		KeyBinds.keyCheck();
		PlayerSettings.init();
		PlayerSettings.player1.controls.loadKeyBinds();

		FlxG.mouse.useSystemCursor = false;
		FlxG.mouse.load(Paths.image('menu/cursor/cursor-default'));

		if (FlxG.save.data.gpuCaching != null)
			PathsCache.gpuCaching = FlxG.save.data.gpuCaching;

		Paths.addExclusion(Paths.music('freakyMenu'));
		Paths.addExclusion(Paths.image('menu/cursor/cursor-default'));
	}

	private function initializeFramerate():Void
	{
		#if (!html5 && !androidC)
		framerate = 120;
		#else
		framerate = 60;
		#end

		if (FlxG.save.data.fpsTarget != null)
		{
			setMaxFps(Std.int(FlxG.save.data.fpsTarget));
		}
		else if (FlxG.save.data.FPSCap != null && FlxG.save.data.FPSCap)
		{
			FlxG.save.data.fpsTarget = 120;
			setMaxFps(120);
		}
		else
		{
			FlxG.save.data.fpsTarget = 60;
			setMaxFps(60);
		}
	}

	private function initializeCameras():Void
	{
		CameraUtil.pruneEmptyFilters(FlxG.camera);
	}

	private function disableDefaultSoundTray():Void
	{
		FlxG.sound.volumeUpKeys   = null;
		FlxG.sound.volumeDownKeys = null;
		FlxG.sound.muteKeys       = null;
		#if FLX_SOUND_SYSTEM
		@:privateAccess
		{
			if (FlxG.game.soundTray != null)
			{
				FlxG.game.soundTray.visible = false;
				FlxG.game.soundTray.active  = false;
			}
		}
		#end
	}

	// ── Public API ────────────────────────────────────────────────────────────

	public function setMaxFps(fps:Int):Void
	{
		openfl.Lib.current.stage.frameRate = fps;
		FlxG.updateFramerate = fps;
		FlxG.drawFramerate   = fps;
	}

	public static function getGame():FlxGame
		return cast(Lib.current.getChildAt(0), FlxGame);
}