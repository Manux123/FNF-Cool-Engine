package funkin.cutscenes;

import funkin.states.LoadingState;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import openfl.events.Event;

// ────────────────────────────────────────────────────────────────────────────
// MP4Handler — VLC-backed MP4 playback
//
// Supported platforms:  Windows · macOS · Linux  (all desktop cpp targets)
// Unsupported:          Android · iOS · HTML5
//
// macOS prerequisites:
//   brew install --cask vlc   OR   brew install libvlc
//
// Linux prerequisites:
//   sudo apt install libvlc-dev   (Debian/Ubuntu)
//   sudo dnf install vlc-devel    (Fedora)
// ────────────────────────────────────────────────────────────────────────────

#if (cpp && !mobile)
import vlc.VlcBitmap;

class MP4Handler
{
	public var finishCallback:Void->Void;
	public var stateCallback:FlxState;

	public var bitmap:VlcBitmap;
	public var sprite:FlxSprite;

	public function new() {}

	public function playMP4(path:String, ?midSong:Bool = false, ?repeat:Bool = false,
		?outputTo:FlxSprite = null, ?isWindow:Bool = false, ?isFullscreen:Bool = false):Void
	{
		if (!midSong)
		{
			if (FlxG.sound.music != null)
				FlxG.sound.music.stop();
		}

		bitmap = new VlcBitmap();

		// Maintain 16:9 aspect ratio centred on screen
		var targetRatio:Float = 16 / 9;
		var screenWidth:Float  = FlxG.stage.stageWidth;
		var screenHeight:Float = FlxG.stage.stageHeight;
		var screenRatio:Float  = screenWidth / screenHeight;

		if (screenRatio > targetRatio)
		{
			bitmap.width  = screenHeight * targetRatio;
			bitmap.height = screenHeight;
		}
		else
		{
			bitmap.width  = screenWidth;
			bitmap.height = screenWidth / targetRatio;
		}

		bitmap.x = (screenWidth  - bitmap.width)  / 2;
		bitmap.y = (screenHeight - bitmap.height) / 2;

		bitmap.onVideoReady = onVLCVideoReady;
		bitmap.onComplete   = onVLCComplete;
		bitmap.onError      = onVLCError;

		FlxG.stage.addEventListener(Event.ENTER_FRAME, update);

		bitmap.repeat     = repeat ? -1 : 0;
		bitmap.inWindow   = isWindow;
		bitmap.fullscreen = isFullscreen;

		FlxG.addChildBelowMouse(bitmap);
		bitmap.play(normalisePath(path));

		if (outputTo != null)
		{
			// Render into a FlxSprite instead of the stage directly
			bitmap.alpha = 0;
			sprite = outputTo;
		}
	}

	/** 
	 * Normalise the path so libVLC always receives a valid URI.
	 * Works on Windows (C:\\...), macOS (/Users/...) and Linux (/home/...).
	 */
	function normalisePath(fileName:String):String
	{
		// Already a full URI?
		if (fileName.indexOf("file://") != -1 || fileName.indexOf("http") == 0)
			return fileName;

		#if windows
		// Windows absolute path → file:///C:/path/to/file
		if (fileName.indexOf(":") != -1)
			return "file:///" + fileName.split("\\").join("/");
		#end

		// Relative path → prepend CWD as file URI
		var cwd = Sys.getCwd().split("\\").join("/");
		// Ensure trailing slash
		if (!cwd.endsWith("/"))
			cwd += "/";

		#if (mac || linux)
		// Unix: path already uses forward slashes
		return "file://" + cwd + fileName;
		#else
		return "file:///" + cwd + fileName;
		#end
	}

	/////////////////////////////////////////////////////////////////////////////////////

	function onVLCVideoReady():Void
	{
		trace("MP4Handler: video loaded!");

		if (sprite != null)
			sprite.loadGraphic(bitmap.bitmapData);
	}

	public function onVLCComplete():Void
	{
		FlxG.stage.removeEventListener(Event.ENTER_FRAME, update);
		bitmap.stop();

		FlxG.camera.fade(FlxColor.BLACK, 0, false);

		new FlxTimer().start(0.3, function(tmr:FlxTimer)
		{
			if (finishCallback != null)
				finishCallback();
			else if (stateCallback != null)
				LoadingState.loadAndSwitchState(stateCallback);

			if (bitmap != null)
			{
				bitmap.dispose();
				if (FlxG.stage.contains(bitmap))
					FlxG.stage.removeChild(bitmap);
			}
		});
	}

	public function kill():Void
	{
		if (bitmap == null)
			return;

		bitmap.stop();

		if (finishCallback != null)
			finishCallback();

		bitmap.visible = false;
	}

	function onVLCError():Void
	{
		trace("MP4Handler: VLC error — file not found or codec issue.");

		if (finishCallback != null)
			finishCallback();
		else if (stateCallback != null)
			LoadingState.loadAndSwitchState(stateCallback);
	}

	function update(e:Event):Void
	{
		// Skip video with Enter or Space
		if (FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE)
		{
			if (bitmap != null && bitmap.isPlaying)
				onVLCComplete();
		}

		if (bitmap != null)
		{
			bitmap.volume = FlxG.sound.volume + 0.000005;
			if (FlxG.sound.volume <= 0.1)
				bitmap.volume = 0;
		}
	}
}

#else

// ── Stub for unsupported platforms (mobile, html5) ──────────────────────────
// Provides the same public API so the rest of the codebase compiles cleanly,
// but shows a warning and skips to the next state immediately.
class MP4Handler
{
	public var finishCallback:Void->Void;
	public var stateCallback:flixel.FlxState;
	public var bitmap:Dynamic  = null;
	public var sprite:Dynamic  = null;

	public function new() {}

	public function playMP4(path:String, ?midSong:Bool = false, ?repeat:Bool = false,
		?outputTo:Dynamic = null, ?isWindow:Bool = false, ?isFullscreen:Bool = false):Void
	{
		trace("MP4Handler: VLC video playback is not supported on this platform. Skipping.");
		_skip();
	}

	public function onVLCComplete():Void { _skip(); }
	public function kill():Void         { _skip(); }

	inline function _skip():Void
	{
		if (finishCallback != null)
			finishCallback();
		else if (stateCallback != null)
			funkin.states.LoadingState.loadAndSwitchState(stateCallback);
	}
}

#end
