package funkin.system;

import flixel.FlxG;
import flixel.FlxCamera;
import flixel.FlxSprite;
import flixel.system.scaleModes.RatioScaleMode;
import flixel.system.scaleModes.StageSizeScaleMode;
import openfl.display.Sprite;
import openfl.display.Stage;
import openfl.events.Event;
import lime.app.Application;

using StringTools;

/**
 * WindowManager — gestión del tamaño de ventana, redimensionado y modos de escala.
 *
 * ─── Características ─────────────────────────────────────────────────────────
 *  1. Suscripción a `FlxG.signals.gameResized` para:
 *     • Recalcular la escala de la cámara.
 *     • Invalidar el cache de bitmaps de los FlashSprites (patrón NightmareVision)
 *       para evitar que las cámaras con filtros muestren artefactos visuales.
 *  2. Modos de escala (inspirados en los stretch modes de Godot):
 *     • LETTERBOX     — Mantiene el aspect ratio, añade barras negras (default).
 *     • STRETCH       — Estira para llenar toda la ventana.
 *     • PIXEL_PERFECT — Escala sólo a múltiplos enteros del tamaño base.
 *  3. Tamaño mínimo de ventana configurable.
 *  4. Helpers de fullscreen, minimize, maximize y focus.
 *  5. DPI-awareness en Windows a través de SetProcessDPIAware.
 *
 * ─── Uso ─────────────────────────────────────────────────────────────────────
 *   // En Main.setupGame() después de createGame():
 *   WindowManager.init(scaleMode: LETTERBOX, minW: 640, minH: 360);
 *
 * @author  Cool Engine Team
 * @since   0.5.1
 */
class WindowManager
{
	// ── Configuración ──────────────────────────────────────────────────────────

	/** Modo de escala activo. Cambiar con `setScaleMode()`. */
	public static var scaleMode(default, null):ScaleMode = LETTERBOX;

	/** Ancho mínimo de ventana en píxeles (0 = sin límite). */
	public static var minWidth:Int = 640;

	/** Alto mínimo de ventana en píxeles (0 = sin límite). */
	public static var minHeight:Int = 360;

	/** Si true, el overlay de debug (DataInfoUI) se reposiciona en cada resize. */
	public static var repositionHUD:Bool = true;

	/** true después de llamar init(). */
	public static var initialized(default, null):Bool = false;

	// ── Estado interno ────────────────────────────────────────────────────────
	static var _baseWidth:Int = 1280;
	static var _baseHeight:Int = 720;

	// ── Init ─────────────────────────────────────────────────────────────────

	/**
	 * Inicializa el sistema de ventana.
	 *
	 * @param mode    Modo de escala inicial.
	 * @param minW    Ancho mínimo de ventana (px).
	 * @param minH    Alto mínimo de ventana (px).
	 * @param baseW   Resolución lógica base horizontal (igual a gameWidth en Main).
	 * @param baseH   Resolución lógica base vertical.
	 */
	public static function init(mode:ScaleMode = LETTERBOX, minW:Int = 640, minH:Int = 360, baseW:Int = 1280, baseH:Int = 720):Void
	{
		if (initialized)
			return;

		_baseWidth = baseW;
		_baseHeight = baseH;
		minWidth = minW;
		minHeight = minH;

		// Registrar DPI-awareness en Windows antes de que lime cree el window
		_registerDPIAwareness();

		// Aplicar el modo de escala inicial
		applyScaleMode(mode);

		// Suscribirse a cambios de tamaño de ventana
		FlxG.signals.gameResized.add(_onResize);

		// Suscribirse también al evento nativo de lima para min-size
		#if !html5
		if (Application.current != null && Application.current.window != null)
		{
			Application.current.window.onResize.add(_onLimeResize);
			// Establecer título consistente
			// Application.current.window.title ya lo gestiona project.xml
		}
		#end

		initialized = true;
		trace('[WindowManager] Inicializado. Modo=$mode  Base=${_baseWidth}×${_baseHeight}  Min=${minW}×${minH}');
	}

	// ── Scale modes ────────────────────────────────────────────────────────────

	/**
	 * Cambia el modo de escala en caliente.
	 * Llama a onResize para que surta efecto de inmediato.
	 */
	public static function applyScaleMode(mode:ScaleMode):Void
	{
		scaleMode = mode;
		switch (mode)
		{
			case LETTERBOX:
				// RatioScaleMode: mantiene relación de aspecto, barras negras.
				// Equivale al stretch_mode = VIEWPORT + aspect = KEEP en Godot.
				FlxG.scaleMode = new RatioScaleMode(false);

			case STRETCH:
				// StageSizeScaleMode: estira para llenar. Sin barras.
				// Equivale a stretch_mode = 2D + aspect = IGNORE en Godot.
				FlxG.scaleMode = new StageSizeScaleMode();

			case PIXEL_PERFECT:
				// Escala sólo a múltiplos enteros del tamaño base.
				// Ideal para estéticas pixel art.
				// Equivale a stretch_mode = VIEWPORT + aspect = KEEP_HEIGHT con integer scale en Godot.
				FlxG.scaleMode = new PixelPerfectScaleMode(_baseWidth, _baseHeight);
		}
	}

	// ── Fullscreen ────────────────────────────────────────────────────────────

	/** Activa/desactiva el fullscreen real (no el "fake" de OpenFL). */
	public static function toggleFullscreen():Void
	{
		FlxG.fullscreen = !FlxG.fullscreen;
	}

	public static var isFullscreen(get, never):Bool;

	static inline function get_isFullscreen():Bool
		return FlxG.fullscreen;

	/** Minimiza la ventana. */
	public static function minimize():Void
	{
		#if !html5
		if (Application.current?.window != null)
			Application.current.window.minimized = true; // Changed from minimize()
		#end
	}

	/** Restaura la ventana si estaba minimizada. */
	public static function restore():Void
	{
		#if !html5
		if (Application.current?.window != null)
			Application.current.window.minimized = false; // Changed from restore()
		#end
	}

	/** Mueve y redimensiona la ventana a valores específicos. */
	public static function setWindowBounds(x:Int, y:Int, w:Int, h:Int):Void
	{
		#if !html5
		final win = Application.current?.window;
		if (win == null)
			return;
		w = Std.int(Math.max(w, minWidth));
		h = Std.int(Math.max(h, minHeight));
		win.move(x, y);
		win.resize(w, h);
		#end
	}

	/** Centra la ventana en el monitor primario. */
	public static function centerOnScreen():Void
	{
		#if !html5
		final win = Application.current?.window;
		if (win == null)
			return;
		final sw = lime.system.System.getDisplay(0)?.currentMode?.width ?? 1920;
		final sh = lime.system.System.getDisplay(0)?.currentMode?.height ?? 1080;
		win.move(Std.int((sw - win.width) / 2), Std.int((sh - win.height) / 2));
		#end
	}

	// ── Tamaño actual ────────────────────────────────────────────────────────
	public static var windowWidth(get, never):Int;

	static inline function get_windowWidth():Int
	{
		#if !html5
		return Application.current?.window?.width ?? FlxG.stage.stageWidth;
		#else
		return FlxG.stage.stageWidth;
		#end
	}

	public static var windowHeight(get, never):Int;

	static inline function get_windowHeight():Int
	{
		#if !html5
		return Application.current?.window?.height ?? FlxG.stage.stageHeight;
		#else
		return FlxG.stage.stageHeight;
		#end
	}

	/** Relación de aspecto real de la ventana. */
	public static var aspectRatio(get, never):Float;

	static inline function get_aspectRatio():Float
		return windowWidth / windowHeight;

	// ── Handlers ─────────────────────────────────────────────────────────────

	/**
	 * Callback de `FlxG.signals.gameResized`.
	 * Invalida los caches de sprite en todas las cámaras para evitar artefactos
	 * al redimensionar una cámara que tiene filtros aplicados.
	 *
	 * Técnica de NightmareVision: forzar __cacheBitmap = null en el flashSprite
	 * de cada cámara, que es el Sprite de OpenFL que contiene el render target
	 * de esa cámara. Si no se hace, el render target tiene el tamaño anterior
	 * y los filtros se aplican sobre una textura con resolución obsoleta.
	 */
	@:access(flixel.FlxCamera)
	static function _onResize(w:Int, h:Int):Void
	{
		// Invalidar cache de cada cámara con filtros activos
		if (FlxG.cameras != null)
		{
			for (cam in FlxG.cameras.list)
			{
				if (cam != null && cam._filters != null)
					_resetSpriteCache(cam.flashSprite);
			}
		}

		// Invalidar cache del game container
		if (FlxG.game != null)
			_resetSpriteCache(FlxG.game);

		// Si estamos en modo PIXEL_PERFECT, recalcular la escala entera
		if (scaleMode == PIXEL_PERFECT)
			applyScaleMode(PIXEL_PERFECT);

		trace('[WindowManager] Resize → ${w}×${h}  Ratio=${Math.round(aspectRatio * 100) / 100}');
	}

	/** Callback nativo de lime para enforcement del tamaño mínimo. */
	static function _onLimeResize(w:Int, h:Int):Void
	{
		#if !html5
		if (minWidth <= 0 && minHeight <= 0)
			return;
		final win = Application.current?.window;
		if (win == null)
			return;
		var clamped:Bool = false;
		var newW = w;
		var newH = h;
		if (minWidth > 0 && w < minWidth)
		{
			newW = minWidth;
			clamped = true;
		}
		if (minHeight > 0 && h < minHeight)
		{
			newH = minHeight;
			clamped = true;
		}
		if (clamped)
			win.resize(newW, newH);
		#end
	}

	/**
	 * Invalida el cache de bitmap de un Sprite de OpenFL.
	 * Después del resize, OpenFL puede reutilizar un cacheBitmap con las
	 * dimensiones antiguas → artefactos visuales. Forzamos su regeneración.
	 */
	@:access(openfl.display.DisplayObject)
	static function _resetSpriteCache(sprite:Sprite):Void
	{
		if (sprite == null)
			return;
		@:privateAccess
		{
			sprite.__cacheBitmap = null;
			sprite.__cacheBitmapData = null;
		}
	}

	// ── DPI awareness ─────────────────────────────────────────────────────────

	/**
	 * Registra el proceso como DPI-aware en Windows.
	 * Sin esto, Windows escala la ventana automáticamente en monitores HiDPI,
	 * produciendo un aspecto borroso y coords de mouse incorrectas.
	 * 
	 * Codename Engine hace esto en NativeAPI.registerAsDPICompatible();
	 * nosotros lo integramos directamente aquí para no depender de otra clase.
	 */
	static function _registerDPIAwareness():Void
	{
		#if (windows && cpp)
		// SetProcessDPIAware es la versión simple (Win Vista+).
		// SetProcessDpiAwarenessContext con DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2
		// es la versión moderna (Win 10 1703+) pero requiere más cabeceras.
		// La versión simple es suficiente para FNF-style games.
		extensions.InitAPI.setDPIAware();
		#end
	}
}

// ── Enum ScaleMode ────────────────────────────────────────────────────────────

/**
 * Modos de escala disponibles.
 *
 * Equivalencias con Godot 4.x:
 *  - LETTERBOX     → Viewport stretch + Keep aspect
 *  - STRETCH       → Canvas Items + Ignore aspect
 *  - PIXEL_PERFECT → Viewport stretch + Keep aspect + Integer scale
 */
enum ScaleMode
{
	/** Mantiene aspect ratio, barras negras (letterboxing). */
	LETTERBOX;

	/** Estira para llenar. Puede distorsionar. */
	STRETCH;

	/**
	 * Sólo escala a múltiplos enteros. Sin blurring.
	 * Ideal para assets pixel art o en resoluciones bajas.
	 */
	PIXEL_PERFECT;
}

// ── PixelPerfectScaleMode ─────────────────────────────────────────────────────

/**
 * Modo de escala que mantiene el aspecto ratio usando sólo múltiplos enteros.
 *
 * Ejemplo: juego 320×180 en pantalla 1920×1080 → escala=6 → 1920×1080 exactos.
 * Sin interpolación bilinear → píxeles nítidos.
 *
 * Inspirado en el comportamiento de Godot con `integer_scaling = true`.
 */
@:access(flixel.system.scaleModes.BaseScaleMode)
class PixelPerfectScaleMode extends RatioScaleMode
{
	var _baseW:Int;
	var _baseH:Int;

	public function new(baseW:Int, baseH:Int)
	{
		super(false);
		_baseW = baseW;
		_baseH = baseH;
	}

	override public function updateGameSize(Width:Int, Height:Int):Void
	{
		// Calcular el mayor múltiplo entero que cabe en la ventana
		var scale:Int = Std.int(Math.max(1, Math.min(Math.floor(Width / _baseW), Math.floor(Height / _baseH))));

		gameSize.x = _baseW * scale;
		gameSize.y = _baseH * scale;
	}
}
