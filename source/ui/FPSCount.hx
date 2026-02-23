package ui;

import haxe.Timer;
import haxe.Int32;
import openfl.events.Event;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.system.System;
import lime.app.Application;
#if gl_stats
import openfl.display._internal.stats.Context3DStats;
import openfl.display._internal.stats.DrawCallContext;
#end

/**
 * FPSCount — muestra FPS + Memoria en una sola línea:
 *   FPS: 124 • Memory: 152MB/500MB
 *
 * DataText queda como alias/wrapper vacío para no romper
 * código existente que lo instancie (simplemente no hace nada).
 */
#if !openfl_debug
@:fileXml('tags="haxe,release"')
@:noDebug
#end
class FPSCount extends TextField
{
	/** FPS actual (accesible desde fuera si se necesita). */
	public var currentFPS(default, null):Int;

	@:noCompletion private var cacheCount:Int;
	@:noCompletion private var currentTime:Float;
	@:noCompletion private var times:Array<Float>;
	@:noCompletion private var showFps:Int = 0;

	@:noCompletion private var memPeak:Float = 0;
	@:noCompletion private var byteValue:Int32 = 1024;

	public function new(x:Float = 10, y:Float = 10, color:Int = 0xFFFFFF)
	{
		super();

		this.x = x;
		this.y = y;

		#if androidC
		byteValue = 1000;
		#end

		currentFPS  = 0;
		selectable  = false;
		mouseEnabled = false;
		defaultTextFormat = new TextFormat(
			openfl.utils.Assets.getFont(Paths.font("Funkin.otf")).fontName,
			14, color
		);

		visible = true;
		autoSize = openfl.text.TextFieldAutoSize.LEFT;
		text = "FPS: 0 - Memory: 0MB/0MB";

		cacheCount  = 0;
		currentTime = 0;
		times       = [];

		addEventListener(Event.ENTER_FRAME, function(e)
		{
			var time = openfl.Lib.getTimer();
			_onEnter(time - currentTime);
		});
	}

	private function _onEnter(deltaTime:Float):Void
	{
		currentTime += deltaTime;
		times.push(currentTime);

		while (times[0] < currentTime - 1000)
			times.shift();

		var currentCount = times.length;
		currentFPS = Math.round((currentCount + cacheCount) / 2);

		// Color según FPS
		if (currentFPS > showFps)
		{
			showFps = currentFPS;
			textColor = 0x17FF00; // verde — subiendo
		}
		else if (currentFPS < showFps)
		{
			textColor = 0xFF4444; // rojo — bajando
			showFps = currentFPS;
		}
		else
			textColor = 0xFFFFFF; // blanco — estable

		if (currentCount != cacheCount && visible)
		{
			// Memoria
			var mem:Float = Math.round(System.totalMemory / (byteValue * byteValue));
			if (mem > memPeak) memPeak = mem;

			text = 'FPS: $showFps - Memory: ${mem}MB/${memPeak}MB';

			#if (gl_stats && !disable_cffi && (!html5 || !canvas))
			text += "  DC: " + Context3DStats.totalDrawCalls();
			#end
		}

		cacheCount = currentCount;
	}
}
