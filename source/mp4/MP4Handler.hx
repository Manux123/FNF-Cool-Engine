package mp4;

import states.LoadingState;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import openfl.events.Event;
#if windows
import vlc.VlcBitmap;

// THIS IS FOR TESTING
// DONT STEAL MY CODE >:(
class MP4Handler
{
	public var finishCallback:Void->Void;
	public var stateCallback:FlxState;

	public var bitmap:VlcBitmap;

	public var sprite:FlxSprite;

	public function new()
	{
	}

	public function playMP4(path:String, ?midSong:Bool = false, ?repeat:Bool = false, ?outputTo:FlxSprite = null, ?isWindow:Bool = false,
			?isFullscreen:Bool = false):Void
	{
		if (!midSong)
		{
			if (FlxG.sound.music != null)
			{
				FlxG.sound.music.stop();
			}
		}

		bitmap = new VlcBitmap();

		var targetRatio:Float = 16 / 9;
		var screenWidth:Float = FlxG.stage.stageWidth;
		var screenHeight:Float = FlxG.stage.stageHeight;
		var screenRatio:Float = screenWidth / screenHeight;

		if (screenRatio > targetRatio)
		{
			bitmap.width = screenHeight * targetRatio; // Usando asignación directa
			bitmap.height = screenHeight;
		}
		else
		{
			bitmap.width = screenWidth;
			bitmap.height = screenWidth / targetRatio;
		}

		bitmap.x = (screenWidth - bitmap.width) / 2;
		bitmap.y = (screenHeight - bitmap.height) / 2;

		bitmap.onVideoReady = onVLCVideoReady;
		bitmap.onComplete = onVLCComplete;
		bitmap.onError = onVLCError;

		FlxG.stage.addEventListener(Event.ENTER_FRAME, update);

		if (repeat)
			bitmap.repeat = -1;
		else
			bitmap.repeat = 0;

		bitmap.inWindow = isWindow;
		bitmap.fullscreen = isFullscreen;

		FlxG.addChildBelowMouse(bitmap);
		bitmap.play(checkFile(path));

		if (outputTo != null)
		{
			// lol this is bad kek
			bitmap.alpha = 0;

			sprite = outputTo;
		}
	}

	function checkFile(fileName:String):String
	{
		var pDir = "";
		var appDir = "file:///" + Sys.getCwd() + "/";

		if (fileName.indexOf(":") == -1) // Not a path
			pDir = appDir;
		else if (fileName.indexOf("file://") == -1 || fileName.indexOf("http") == -1) // C:, D: etc? ..missing "file:///" ?
			pDir = "file:///";

		return pDir + fileName;
	}

	/////////////////////////////////////////////////////////////////////////////////////

	function onVLCVideoReady()
	{
		trace("video loaded!");

		if (sprite != null)
			sprite.loadGraphic(bitmap.bitmapData);
	}

	public function onVLCComplete()
	{
		FlxG.stage.removeEventListener(Event.ENTER_FRAME, update);
		bitmap.stop();

		// Clean player, just in case! Actually no.

		FlxG.camera.fade(FlxColor.BLACK, 0, false);

		trace("Big, Big Chungus, Big Chungus!");

		new FlxTimer().start(0.3, function(tmr:FlxTimer)
		{
			if (finishCallback != null)
			{
				finishCallback();
			}
			else if (stateCallback != null)
			{
				LoadingState.loadAndSwitchState(stateCallback);
			}

			if (bitmap != null)
			{
				bitmap.dispose();
				if (FlxG.stage.contains(bitmap))
				{
					FlxG.stage.removeChild(bitmap);
				}
			}
		});
	}

	public function kill()
	{
		bitmap.stop();

		if (finishCallback != null)
		{
			finishCallback();
		}

		bitmap.visible = false;
	}

	function onVLCError()
	{
		if (finishCallback != null)
		{
			finishCallback();
		}
		else if (stateCallback != null)
		{
			LoadingState.loadAndSwitchState(stateCallback);
		}
	}

	function update(e:Event)
	{
		if (FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE)
		{
			if (bitmap.isPlaying)
			{
				onVLCComplete();
			}
		}

		bitmap.volume = FlxG.sound.volume + 0.000005;

		if (FlxG.sound.volume <= 0.1)
			bitmap.volume = 0;
	}
}
#end
