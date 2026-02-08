package ui;

import haxe.Timer;
import openfl.events.Event;
import openfl.text.TextField;
import openfl.text.TextFormat;
#if gl_stats
import openfl.display._internal.stats.Context3DStats;
import openfl.display._internal.stats.DrawCallContext;
#end

import lime.app.Application;

import haxe.Int32;

import openfl.system.System;

/**
	The FPS class provides an easy-to-use monitor to display
	the current frame rate of an OpenFL project
**/
#if !openfl_debug
@:fileXml('tags="haxe,release"')
@:noDebug
#end

class FPSCount extends TextField
{
	/**
		The current frame rate, expressed using frames-per-second
	**/
	public var currentFPS(default, null):Int;

	@:noCompletion private var cacheCount:Int;
	@:noCompletion private var currentTime:Float;
	@:noCompletion private var times:Array<Float>;
    @:noCompletion private var showFps:Int = 0;

	public function new(x:Float = 10, y:Float = 10, color:Int = 0x000000)
	{
		super();

		this.x = x;
		this.y = y;

		currentFPS = 0;
		selectable = false;
		mouseEnabled = false;
		defaultTextFormat = new TextFormat(openfl.utils.Assets.getFont(Paths.font("Funkin.otf")).fontName, 14, color);
		
		// CORREGIDO: Ahora visible por defecto (se controla desde Main.hx)
		visible = true;
		
		text = "FPS: ";

		cacheCount = 0;
		currentTime = 0;
		times = [];

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
		{
			times.shift();
		}

		var currentCount = times.length;
		currentFPS = Math.round((currentCount + cacheCount) / 2);
		
		// Cambio de color según FPS
        if(currentFPS > showFps){
            showFps = currentFPS;
            this.textColor = 0x17FF00; // Verde cuando sube
        }
        else if(currentFPS < showFps){
            this.textColor = 0xFF0000; // Rojo cuando baja
            showFps = currentFPS;
        }
        else
            this.textColor = 0xFFFFFF; // Blanco cuando es estable

		// CORREGIDO: Actualizar texto solo si es visible (optimización)
		if (currentCount != cacheCount && visible)
		{
			text = 'FPS: $showFps';

			#if (gl_stats && !disable_cffi && (!html5 || !canvas))
			text += "\ntotalDC: " + Context3DStats.totalDrawCalls();
			text += "\nstageDC: " + Context3DStats.contextDrawCalls(DrawCallContext.STAGE);
			text += "\nstage3DDC: " + Context3DStats.contextDrawCalls(DrawCallContext.STAGE3D);
			#end
		}

		cacheCount = currentCount;
	}
}

// Worked from Mic'd Up engine
class DataText extends TextField
{
	@:noCompletion private var memPeak:Float = 0;
	@:noCompletion private var byteValue:Int32 = 1024;

	public function new(inX:Float = 10.0, inY:Float = 10.0)
	{
		super();

		#if androidC
		byteValue = 1000;
		#end

		x = inX;
		y = inY;
		selectable = false;
		defaultTextFormat = new TextFormat(openfl.utils.Assets.getFont(Paths.font("Funkin.otf")).fontName, 14, 0xFFFFFF);

		// CORREGIDO: Inicialmente invisible, pero puede activarse desde Main
		visible = true;

		addEventListener(Event.ENTER_FRAME, onEnter);
		width = 150;
		height = 70;
	}

	private function onEnter(_)
	{
		var mem:Float = Math.round(System.totalMemory / (byteValue * byteValue));
		if (mem > memPeak)
		{
			memPeak++;
			this.textColor = 0xFF0000;
		}
		else
			this.textColor = 0xFFFFFF;

		text = visible ? '\nMEM: ${mem}MB\nMEM peak: ${memPeak}MB\nVersion: ${Application.current.meta.get('version')}' : "";
	}
}