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

// ── Sistema / ventana ─────────────────────────────────────────────────────────
import funkin.audio.AudioConfig;
import funkin.data.CameraUtil;
import funkin.system.MemoryUtil;
import funkin.system.SystemInfo;
import funkin.system.WindowManager;
import funkin.system.WindowManager.ScaleMode;
import funkin.cache.PathsCache;
import funkin.cache.FunkinCache;

// ── API nativa ────────────────────────────────────────────────────────────────
import extensions.CppAPI;
import extensions.InitAPI;

#if (desktop && cpp)
import data.Discord.DiscordClient;
import sys.thread.Thread;
#end

// ── Módulos de arranque ───────────────────────────────────────────────────────
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

	public static inline var ENGINE_VERSION:String = "0.5.0";

	// ── Entry point ───────────────────────────────────────────────────────────

	/**
	 * Primer código que ejecuta Haxe antes de instanciar Main.
	 * Usado para DPI-awareness que debe registrarse antes de cualquier ventana.
	 */
	@:keep
	static function __init__():Void
	{
		// Registrar DPI-awareness en Windows antes de que se cree la ventana.
		// Debe hacerse en __init__ porque new Main() ya puede implicar crear ventanas.
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

	/**
	 * Configura el stage de OpenFL.
	 * Establece: escala, alineación, calidad vectorial, GC tuning.
	 */
	private function setupStage():Void
	{
		stage.scaleMode = StageScaleMode.NO_SCALE;
		stage.align     = StageAlign.TOP_LEFT;

		// LOW = sin antialiasing vectorial. Los sprites usan sus propias texturas.
		// La calidad vectorial sólo afecta a primitivas Graphics (healthbar bg, etc.)
		stage.quality   = openfl.display.StageQuality.LOW;

		// ── GC tuning (hxcpp) ─────────────────────────────────────────────────
		// 32 MB de espacio libre mínimo antes de un major-GC cycle.
		// Reduce los stutters causados por el GC durante carga de personajes/stage.
		#if cpp
		cpp.vm.Gc.setMinimumFreeSpace(32 * 1024 * 1024);
		cpp.vm.Gc.enable(true);
		#end

		// ── Frame oscuro (Windows 10 1809+ / Windows 11) ──────────────────────
		// Se activa aquí (después de que el stage existe) para que HWND sea válido.
		#if (windows && cpp)
		InitAPI.setDarkMode(true);
		CppAPI.changeColor(0, 0, 0);
		#end
	}

	/**
	 * Inicialización principal del juego.
	 * Ver comentario de orden al inicio de la clase.
	 */
	private function setupGame():Void
	{
		calculateZoom();

		// ── Audio (ANTES de createGame → antes de que OpenAL init el device) ──
		AudioConfig.load();

		// ── CrashHandler + debug tools ────────────────────────────────────────
		CrashHandler.init();
		#if debug
		DebugConsole.init();
		#end

		// ── FunkinCache — DEBE instalarse ANTES de createGame() ──────────────
		// Reemplaza openfl.utils.Assets.cache para interceptar TODOS los loads
		// de OpenFL y liberar bitmaps/sounds automáticamente en cada cambio de
		// estado. Sin esto, OpenFL acumula assets indefinidamente en su caché
		// por defecto (~300-400 MB en gameplay).
		// FunkinCache.init() también suscribe a preStateSwitch/postStateSwitch
		// para rotar las capas current/second automáticamente, pero esas señales
		// solo están disponibles después de createGame() → se inicializan dentro
		// de FunkinCache.init() con FlxG.signals, así que llamamos DESPUÉS.

		// ── Juego ─────────────────────────────────────────────────────────────
		createGame();
		FunkinCache.init(); // FlxG ya disponible → suscribir señales
		AudioConfig.applyToFlixel();
		StickerTransition.init();

		// ── WindowManager (después de createGame, necesita FlxG.signals) ──────
		WindowManager.init(
			/* mode    */ LETTERBOX,
			/* minW    */ 640,
			/* minH    */ 360,
			/* baseW   */ GAME_WIDTH,
			/* baseH   */ GAME_HEIGHT
		);

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
		mods.ModManager.applyStartupMod(); // activa el startup mod si no hay sesión guardada
		// Aplicar branding del startup mod (título e icono) si hay uno activo
		WindowManager.applyModBranding(mods.ModManager.activeInfo());
		// Aplicar config de Discord del startup mod si hay uno activo
		#if (desktop && cpp)
		DiscordClient.applyModConfig(mods.ModManager.activeInfo());
		#end
		mods.ModManager.onModChanged = function(newMod:Null<String>)
		{
			Paths.forceClearCache();
			funkin.gameplay.objects.character.CharacterList.reload();
			MemoryUtil.collectMajor();
			trace('[Main] Cache cleaned. Mod active → ${newMod ?? "base"}');
			// Aplicar título e icono del mod al cambiar de mod (o restaurar al desactivar)
			WindowManager.applyModBranding(mods.ModManager.activeInfo());
			// Aplicar config de Discord (clientId, imagen, menuDetails)
			#if (desktop && cpp)
			DiscordClient.applyModConfig(mods.ModManager.activeInfo());
			#end
		};

		// ── Discord ───────────────────────────────────────────────────────────
		#if (desktop && cpp)
		DiscordClient.initialize();
		#end

		// ── SystemInfo (se completa en un frame posterior al arranque) ─────────
		// Requiere context3D para los datos de GPU, disponible sólo después del
		// primer frame de rendering. Llamamos en el siguiente ENTER_FRAME.
		stage.addEventListener(openfl.events.Event.ENTER_FRAME, _initSystemInfoDeferred);
	}

	// ── ENTER_FRAME deferred ──────────────────────────────────────────────────

	/**
	 * Inicializa SystemInfo en el primer frame después del arranque.
	 * Garantiza que context3D esté disponible para leer info de GPU.
	 */
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

		// Draw framerate separado del update permite hacer lógica a 120 Hz
		// pero renderizar a menos si el hardware no aguanta.
		FlxG.drawFramerate   = framerate;
		FlxG.updateFramerate = framerate;

		// Sin antialiasing global — cada sprite lo activa si lo necesita.
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

		// ── PathsCache: configuración inicial ─────────────────────────────────
		// Restaurar preferencia de GPU caching guardada.
		// Por defecto true en desktop; false en web/mobile.
		if (FlxG.save.data.gpuCaching != null)
			PathsCache.gpuCaching = FlxG.save.data.gpuCaching;

		// Exclusiones permanentes: assets siempre en memoria.
		// Paths.addExclusion los registra en PathsCache.dumpExclusions.
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
		// Limpiar filtros vacíos de la cámara principal para evitar el
		// off-screen render pass innecesario que los arrays vacíos provocan.
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
		FlxG.drawFramerate   = fps;
		FlxG.updateFramerate = fps;
	}

	public static function getGame():FlxGame
		return cast(Lib.current.getChildAt(0), FlxGame);
}
