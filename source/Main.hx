package;

import flixel.FlxG;
import flixel.FlxGame;
import flixel.FlxState;
import openfl.Assets;
import openfl.Lib;
import openfl.display.Sprite;
import openfl.events.Event;
import CacheState;
import openfl.events.Event;
import ui.DataInfoUI;
import funkin.menus.TitleState;
#if debug
import openfl.events.UncaughtErrorEvent;
import haxe.CallStack;
import haxe.io.Path;
import funkin.debug.DebugConsole;
#end

import lime.app.Application;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

// init
import funkin.data.KeyBinds;
import funkin.gameplay.notes.NoteSkinSystem;
import extensions.CppAPI;
#if desktop
import data.Discord.DiscordClient;
import sys.thread.Thread;
#end

class Main extends Sprite
{
	var gameWidth:Int = 1280; // Width of the game in pixels (might be less / more in actual pixels depending on your zoom).
	var gameHeight:Int = 720; // Height of the game in pixels (might be less / more in actual pixels depending on your zoom).
	var initialState:Class<FlxState> = TitleState; // The FlxState the game starts with.
	var zoom:Float = -1; // If -1, zoom is automatically calculated to fit the window dimensions.
	var framerate:Int = 120; // How many frames per second the game should run at.
	var skipSplash:Bool = true; // Whether to skip the flixel splash screen that appears in release mode.
	var startFullscreen:Bool = false; // Whether to start the game in fullscreen on desktop targets

	public final data:DataInfoUI = new DataInfoUI(10,3);

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
			zoom = Math.min(stageWidth / gameWidth, stageHeight / gameHeight);
			gameWidth = Math.ceil(stageWidth / zoom);
			gameHeight = Math.ceil(stageHeight / zoom);
		}
		/*
			#if !debug
			initialState = states.CacheState;
			#else */
		initialState = CacheState;
		// #end

		// En el constructor:
		#if debug
		DebugConsole.init();
		#end

		FlxG.save.bind('coolengine', 'manux');

		NoteSkinSystem.init();

		funkin.menus.OptionsMenuState.OptionsData.initSave();
		KeyBinds.keyCheck();

		funkin.gameplay.objects.hud.Highscore.load();

		#if (!html5 || !androidC)
		framerate = 120;
		#else
		framerate = 60;
		#end

		#if CRASH_HANDLER
		Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onCrash);
		#end

		CppAPI.changeColor(0,0,0);

		addChild(new FlxGame(gameWidth, gameHeight, initialState, #if (flixel < "5.0.0") zoom, #end framerate, framerate, skipSplash, startFullscreen));

		addChild(data);

		#if desktop
		DiscordClient.initialize();
		#end
	}

	public function setMaxFps(fps:Int)
	{
		openfl.Lib.current.stage.frameRate = fps;
	}
}

#if debug
function onCrash(e:UncaughtErrorEvent):Void
{
	var errMsg:String = "";
	var path:String;
	var callStack:Array<StackItem> = CallStack.exceptionStack(true);
	var dateNow:String = Date.now().toString();

	dateNow = dateNow.replace(" ", "_");
	dateNow = dateNow.replace(":", "'");

	path = "./crash/" + "CoolEngine_" + dateNow + ".txt";

	for (stackItem in callStack)
	{
		switch (stackItem)
		{
			case FilePos(s, file, line, column):
				errMsg += file + " (line " + line + ")\n";
			default:
				Sys.println(stackItem);
		}
	}

	errMsg += "\nUncaught Error: " + e.error;
	/*
	 * remove if you're modding and want the crash log message to contain the link
	 * please remember to actually modify the link for the github page to report the issues to.
	 */
	//
	errMsg += "\nPlease report this error to the GitHub page: https://github.com/Manux123/FNF-Cool-Engine\n\n> Crash Handler written by: sqirra-rng";

	if (!FileSystem.exists("./crash/"))
		FileSystem.createDirectory("./crash/");

	File.saveContent(path, errMsg + "\n");

	Sys.println(errMsg);
	Sys.println("Crash dump saved in " + Path.normalize(path));

	Application.current.window.alert(errMsg, "Error!");
	#if DISCORD_ALLOWED
	DiscordClient.shutdown();
	#end
	Sys.exit(1);
}
#end
