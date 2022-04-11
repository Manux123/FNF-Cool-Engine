package;

import haxe.Int32;
import flixel.FlxGame;
import flixel.FlxState;
import openfl.Assets;
import openfl.Lib;
import openfl.display.FPS;
import openfl.display.Sprite;
import openfl.events.Event;
import states.CacheState;
import openfl.events.Event;
import states.TitleState;
import openfl.system.System;
import openfl.text.TextField;
import openfl.text.TextFormat;

class Main extends Sprite
{
	var gameWidth:Int = 1280; // Width of the game in pixels (might be less / more in actual pixels depending on your zoom).
	var gameHeight:Int = 720; // Height of the game in pixels (might be less / more in actual pixels depending on your zoom).
	var initialState:Class<FlxState> = TitleState; // The FlxState the game starts with.
	var zoom:Float = -1; // If -1, zoom is automatically calculated to fit the window dimensions.
	var framerate:Int = 120; // How many frames per second the game should run at.
	var skipSplash:Bool = true; // Whether to skip the flixel splash screen that appears in release mode.
	var startFullscreen:Bool = false; // Whether to start the game in fullscreen on desktop targets

	// You can pretty much ignore everything from here on - your code should go in your states.

	public static function main():Void
	{
		Lib.current.addChild(new Main());
	}

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

	private function init(?E:Event):Void
	{
		if (hasEventListener(Event.ADDED_TO_STAGE))
		{
			removeEventListener(Event.ADDED_TO_STAGE, init);
		}

		setupGame();
	}

	private function setupGame():Void
	{
		var stageWidth:Int = Lib.current.stage.stageWidth;
		var stageHeight:Int = Lib.current.stage.stageHeight;

		if (zoom == -1)
		{
			var ratioX:Float = stageWidth / gameWidth;
			var ratioY:Float = stageHeight / gameHeight;
			zoom = Math.min(ratioX, ratioY);
			gameWidth = Math.ceil(stageWidth / zoom);
			gameHeight = Math.ceil(stageHeight / zoom);
		}
/*
		#if !debug
		initialState = states.CacheState;
		#else*/
		initialState = states.TitleState;
		//#end

		#if (!html5 || !androidC)
		framerate = 120;
		#else
		framerate = 60;
		#end

		#if DEBUG_BUILD
		switchDevData();
		#end

		addChild(new FlxGame(gameWidth, gameHeight, initialState, zoom, framerate, framerate, skipSplash, startFullscreen));
		addChild(dataText);
		addChild(fps);
	}

	public final fps:FPSCount = new FPSCount(10, 3, 0xFFFFFF);
	public final dataText:DataText = new DataText(10,3);

	public function setMaxFps(fps:Int){
		openfl.Lib.current.stage.frameRate = fps;
	}
	public function switchDevData(){
		dataText.visible = !dataText.visible;
		fps.visible = !fps.visible;
	}
}

//Worked from Mic'd Up engine
class DataText extends TextField{
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
		defaultTextFormat = new TextFormat(openfl.utils.Assets.getFont(Paths.font("Funkin.otf")).fontName, 12, 0xFFFFFF);
		visible = false;

		addEventListener(Event.ENTER_FRAME, onEnter);
		width = 150;
		height = 70;
	}

	private function onEnter(_){
		var mem:Float = Math.round(System.totalMemory / (byteValue * byteValue));
		if (mem > memPeak){
			memPeak++;
			this.textColor = 0xFF0000;
		}
		else
			this.textColor = 0xFFFFFF;

		text = visible?'\nMEM: ${mem}MB\nMEM peak: ${memPeak}MB\nVersion: ${lime.app.Application.current.meta.get('version')}':"";	
	}
}
