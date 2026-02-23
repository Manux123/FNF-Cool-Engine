package ui;

import openfl.display.Sprite;
import openfl.display.Shape;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.events.Event;
import openfl.system.System;
import flixel.FlxG;
import funkin.system.SystemInfo;
import funkin.system.WindowManager;
import funkin.audio.AudioConfig;

/**
 * DataInfoUI — overlay de debug/stats superpuesto sobre el juego.
 *
 * ─── Capas de información ────────────────────────────────────────────────────
 *  • FPSCount    — FPS + RAM usada + RAM pico  (siempre visible si showFps=true)
 *  • SystemPanel — OS, CPU, GPU, VRAM, RAM total  (toggle con F3)
 *  • StatsPanel  — GPU renderer, draw calls, cache, audio config  (toggle con F3)
 *
 * ─── Controles ───────────────────────────────────────────────────────────────
 *  F3         — alterna visibilidad de SystemPanel + StatsPanel
 *  Shift+F3   — alterna visibilidad de todo el overlay
 *
 * @author  Cool Engine Team
 * @since   0.5.1
 */
class DataInfoUI extends Sprite
{
	public var fps:FPSCount;
	public var systemPanel:SystemPanel;
	public var statsPanel:StatsPanel;

	/** @deprecated Mantener compatibilidad con código que lee .gpuEnabled */
	public static var gpuEnabled:Bool = true;
	public static var saveData:Dynamic = null;

	private var _bg:Shape;
	private var _expanded:Bool = false;

	public function new(x:Float = 10, y:Float = 3)
	{
		super();

		saveData = _getSaveData();
		gpuEnabled = (saveData?.gpuRendering ?? true);

		// Fondo semitransparente — se redimensiona con el contenido
		_bg = new Shape();
		_updateBG(230, 18);
		addChild(_bg);

		// FPS counter
		fps = new FPSCount(x, y, 0xFFFFFF);
		addChild(fps);

		// Panel de info del sistema (oculto por defecto)
		systemPanel = new SystemPanel(x, y + 18);
		systemPanel.visible = false;
		addChild(systemPanel);

		// Panel de stats de rendimiento (oculto por defecto)
		statsPanel = new StatsPanel(x, y + 18 + SystemPanel.HEIGHT + 4);
		statsPanel.visible = false;
		addChild(statsPanel);

		// Restaurar estado previo guardado
		var showExpanded = saveData?.showDebugStats ?? false;
		if (showExpanded) _setExpanded(true);

		this.x = x;
		this.y = y;
	}

	// ── Toggles ────────────────────────────────────────────────────────────────

	public function toggleExpanded():Void
	{
		_setExpanded(!_expanded);
		if (saveData != null) saveData.showDebugStats = _expanded;
	}

	private function _setExpanded(v:Bool):Void
	{
		_expanded = v;
		systemPanel.visible = v;
		statsPanel.visible  = v;
		var bgH = v ? (18 + SystemPanel.HEIGHT + StatsPanel.HEIGHT + 8) : 18;
		_updateBG(230, bgH);
	}

	/** Toggle legacy para compatibilidad (antes se llamaba toggleGPUStats). */
	public inline function toggleGPUStats():Void toggleExpanded();

	// ── Helpers ────────────────────────────────────────────────────────────────

	private function _updateBG(w:Float, h:Float):Void
	{
		_bg.graphics.clear();
		_bg.graphics.beginFill(0x000000, 0.55);
		_bg.graphics.drawRoundRect(0, 0, w, h, 4);
		_bg.graphics.endFill();
	}

	private static function _getSaveData():Dynamic
	{
		if (FlxG.save != null && FlxG.save.data != null)
			return FlxG.save.data;
		return null;
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// SystemPanel — info estática del hardware (no cambia cada frame)
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Muestra OS / CPU / GPU / VRAM / RAM total.
 * El contenido se carga una sola vez (los datos no cambian en runtime).
 */
class SystemPanel extends TextField
{
	public static inline var HEIGHT:Int = 64;

	public function new(x:Float, y:Float)
	{
		super();

		this.x           = x + 4;
		this.y           = y;
		this.width       = 210;
		this.height      = HEIGHT;
		this.selectable  = false;
		this.mouseEnabled = false;
		this.defaultTextFormat = new TextFormat("_sans", 9, 0xAADDFF);
		this.multiline   = true;
		this.wordWrap    = false;

		// Rellenar cuando SystemInfo esté listo (puede no estarlo aún)
		if (SystemInfo.initialized)
			_fill();
		else
			this.text = "System Info cargando...";

		// Rellenar en el primer frame si aún no está listo
		addEventListener(Event.ENTER_FRAME, _onEnter);
	}

	private var _filled:Bool = false;

	private function _onEnter(_):Void
	{
		if (!_filled && SystemInfo.initialized)
		{
			_fill();
			_filled = true;
			removeEventListener(Event.ENTER_FRAME, _onEnter);
		}
	}

	private function _fill():Void
	{
		var lines:Array<String> = [];

		if (SystemInfo.osName  != "Unknown") lines.push('OS:  ${SystemInfo.osName}');
		if (SystemInfo.cpuName != "Unknown") lines.push('CPU: ${SystemInfo.cpuName}');

		var gpuLine = '';
		if (SystemInfo.gpuName != "Unknown") gpuLine += 'GPU: ${SystemInfo.gpuName}';
		if (SystemInfo.vRAM    != "Unknown") gpuLine += '  VRAM: ${SystemInfo.vRAM}';
		if (gpuLine.length > 0) lines.push(gpuLine);

		if (SystemInfo.gpuMaxTextureSize != "Unknown")
			lines.push('    Max tex: ${SystemInfo.gpuMaxTextureSize}');

		var ramLine = '';
		if (SystemInfo.totalRAM != "Unknown") ramLine = 'RAM: ${SystemInfo.totalRAM}';
		if (SystemInfo.ramType.length > 0)    ramLine += '  ${SystemInfo.ramType}';
		if (ramLine.length > 0) lines.push(ramLine);

		if (lines.length == 0) lines.push("(System info no disponible)");
		this.text = lines.join("\n");
		_filled = true;
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// StatsPanel — stats de rendimiento dinámicas (actualizadas cada 0.5s)
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Muestra: resolución de ventana, modo de escala, draw calls, cache, audio config.
 * Actualización periódica para no consumir CPU en cada frame.
 */
class StatsPanel extends TextField
{
	public static inline var HEIGHT:Int = 72;
	private static inline var UPDATE_INTERVAL:Float = 0.5;

	private var _elapsed:Float = 0;

	public function new(x:Float, y:Float)
	{
		super();

		this.x            = x + 4;
		this.y            = y;
		this.width        = 210;
		this.height       = HEIGHT;
		this.selectable   = false;
		this.mouseEnabled = false;
		this.defaultTextFormat = new TextFormat("_sans", 9, 0x00FF88);
		this.multiline    = true;
		this.wordWrap     = false;
		this.text         = "Stats cargando...";

		addEventListener(Event.ENTER_FRAME, _onEnter);
	}

	private function _onEnter(e:Event):Void
	{
		_elapsed += FlxG.elapsed;
		if (_elapsed < UPDATE_INTERVAL) return;
		_elapsed = 0;
		_refresh();
	}

	private function _refresh():Void
	{
		var lines:Array<String> = [];

		// ── Ventana ──
		var ww = WindowManager.windowWidth;
		var wh = WindowManager.windowHeight;
		var mode = WindowManager.scaleMode;
		lines.push('Win: ${ww}×${wh}  Scale: $mode${WindowManager.isFullscreen ? " [FS]" : ""}');

		// ── Lógica del juego ──
		lines.push('Game: ${FlxG.width}×${FlxG.height}  FPS target: ${FlxG.updateFramerate}');

		// ── Draw calls y GPU renderer (desde PlayState si disponible) ──
		var drawCalls = 0;
		var sprites   = 0;
		var culled    = 0;
		try
		{
			var ps = cast(FlxG.state, funkin.gameplay.PlayState);
			if (ps?.optimizationManager?.gpuRenderer != null)
			{
				drawCalls = ps.optimizationManager.gpuRenderer.drawCalls;
				sprites   = ps.optimizationManager.gpuRenderer.spritesRendered;
				culled    = ps.optimizationManager.gpuRenderer.spritesCulled;
			}
		}
		catch (_:Dynamic) {}

		lines.push('GPU: DC=$drawCalls  Spr=$sprites  Cull=$culled');

		// ── GC / Memoria ──
		var usedMB   = Math.round(openfl.system.System.totalMemory / (1024 * 1024));
		var gcPaused = funkin.system.MemoryUtil.disableCount > 0;
		lines.push('Mem: ${usedMB} MB  GC: ${gcPaused ? "paused" : "active"}');

		// ── Audio (OpenAL) ──
		if (AudioConfig.loaded)
			lines.push('Audio: ${AudioConfig.debugString()}');
		else
			lines.push('Audio: default config');

		// ── Cache Paths ──
		lines.push('Cache: ${Paths.cacheDebugString()}');

		this.text = lines.join("\n");
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// GPUStatsText — alias legacy (evita romper código existente)
// ─────────────────────────────────────────────────────────────────────────────
@:deprecated("Usa StatsPanel. GPUStatsText se mantendrá como alias vacío.")
class GPUStatsText extends TextField
{
	public static function getSaveData():Dynamic
	{
		if (FlxG.save != null && FlxG.save.data != null) return FlxG.save.data;
		return null;
	}

	public function new(x:Float, y:Float)
	{
		super();
		this.x = x; this.y = y;
		this.selectable = false; this.mouseEnabled = false;
		this.width = 10; this.height = 10;
		this.visible = false;
	}

	/** @deprecated No-op. */
	public function updateStats():Void {}
}
