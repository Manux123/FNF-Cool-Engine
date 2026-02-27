package ui;

import haxe.Int32;
import openfl.events.Event;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.system.System;
#if gl_stats
import openfl.display._internal.stats.Context3DStats;
import openfl.display._internal.stats.DrawCallContext;
#end

/**
 * FPSCount — muestra FPS + Memoria.
 *
 * v2: Ring buffer O(1) en vez de Array + shift() O(n).
 *   ANTES: times.push() + while(shift()) movía el array entero cada frame.
 *   AHORA: escritura circular, sin alocaciones ni copies en el game loop.
 */
#if !openfl_debug
@:fileXml('tags="haxe,release"')
@:noDebug
#end
class FPSCount extends TextField
{
	public var currentFPS(default, null):Int;

	@:noCompletion private var cacheCount:Int = 0;
	@:noCompletion private var currentTime:Float = 0.0;
	@:noCompletion private var showFps:Int = 0;
	@:noCompletion private var memPeak:Float = 0;
	@:noCompletion private var byteValue:Int32 = 1024;

	// ── Ring buffer: 120 slots fijos (suficiente para 60+ fps en 1 segundo) ──
	static inline var RING_CAP:Int = 120;
	@:noCompletion private var _ring:Array<Float>;
	@:noCompletion private var _ringHead:Int = 0;   // siguiente posición de escritura
	@:noCompletion private var _ringFill:Int = 0;   // cuántas entradas válidas hay

	public function new(x:Float = 10, y:Float = 10, color:Int = 0xFFFFFF)
	{
		super();
		this.x = x;
		this.y = y;

		#if androidC
		byteValue = 1000;
		#end

		currentFPS   = 0;
		selectable   = false;
		mouseEnabled = false;
		defaultTextFormat = new TextFormat(
			openfl.utils.Assets.getFont(Paths.font("Funkin.otf")).fontName,
			14, color
		);
		visible  = true;
		autoSize = openfl.text.TextFieldAutoSize.LEFT;
		text     = "FPS: 0 - Memory: 0MB/0MB";

		// Pre-alocar buffer una sola vez — cero alocaciones en el game loop
		_ring = [for (_ in 0...RING_CAP) 0.0];

		addEventListener(Event.ENTER_FRAME, _onFrame);
	}

	@:noCompletion
	private function _onFrame(_:Event):Void
	{
		var now:Float = openfl.Lib.getTimer();
		var dt:Float  = now - currentTime;
		currentTime   = now;

		// ── Escribir en el ring buffer (O(1), sin alocación) ─────────────────
		_ring[_ringHead] = now;
		_ringHead = (_ringHead + 1) % RING_CAP;
		if (_ringFill < RING_CAP) _ringFill++;

		// ── Contar frames dentro del último segundo ───────────────────────────
		// Leemos desde la entrada más reciente hacia atrás hasta que un
		// timestamp quede fuera de la ventana de 1000 ms.
		var cutoff:Float = now - 1000.0;
		var validCount:Int = 0;
		for (k in 0..._ringFill)
		{
			var idx:Int = ((_ringHead - 1 - k) % RING_CAP + RING_CAP) % RING_CAP;
			if (_ring[idx] < cutoff) break;
			validCount++;
		}

		currentFPS = Math.round((validCount + cacheCount) / 2);

		if (currentFPS > showFps)        { showFps = currentFPS; textColor = 0x17FF00; }
		else if (currentFPS < showFps)   { textColor = 0xFF4444; showFps = currentFPS; }
		else                             { textColor = 0xFFFFFF; }

		if (validCount != cacheCount && visible)
		{
			var mem:Float = Math.round(System.totalMemory / (byteValue * byteValue));
			if (mem > memPeak) memPeak = mem;
			text = 'FPS: $showFps - Memory: ${mem}MB/${memPeak}MB';
			#if (gl_stats && !disable_cffi && (!html5 || !canvas))
			text += "  DC: " + Context3DStats.totalDrawCalls();
			#end
		}

		cacheCount = validCount;
	}
}
