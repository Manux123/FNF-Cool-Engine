package funkin.cutscenes;

import lime.utils.Assets;
import funkin.states.MusicBeatState;
import flixel.FlxState;
import flixel.FlxG;
import funkin.cutscenes.MP4Handler;
import funkin.states.LoadingState;

// ────────────────────────────────────────────────────────────────────────────
// VideoState — plays an MP4 cutscene then transitions to the next state.
//
// On desktop (Windows / macOS / Linux) it uses MP4Handler backed by libVLC.
// On all other targets (mobile, html5) it skips the video and goes straight
// to nextState.
// ────────────────────────────────────────────────────────────────────────────

class VideoState extends MusicBeatState
{
	var videoPath:String;
	var nextState:FlxState;

	// MP4Handler works on every platform now — the stub handles unsupported ones.
	var video:MP4Handler = new MP4Handler();

	public function new(path:String, state:FlxState)
	{
		super();
		this.videoPath = path;
		this.nextState = state;
	}

	public override function create():Void
	{
		FlxG.autoPause = true;

		#if (cpp && !mobile)
		// Desktop: try to play the video file via VLC
		if (Assets.exists(Paths.video(videoPath)))
		{
			video.playMP4(Paths.video(videoPath));
			video.finishCallback = function()
			{
				if (FlxG.sound.music != null)
					FlxG.sound.music.stop();
				LoadingState.loadAndSwitchState(nextState);
			};
		}
		else
		{
			trace('VideoState: file not found — ' + Paths.video(videoPath) + ' — skipping.');
			_skipToNext();
		}
		#else
		// Mobile / HTML5: skip video entirely
		trace('VideoState: video playback not supported on this platform — skipping.');
		_skipToNext();
		#end

		super.create();
	}

	public override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		#if (cpp && !mobile)
		// Allow the player to skip the cutscene
		if (controls.ACCEPT)
		{
			video.kill();
			_skipToNext();
		}
		#end
	}

	// ── helpers ────────────────────────────────────────────────────────────

	function _skipToNext():Void
	{
		if (FlxG.sound.music != null)
			FlxG.sound.music.stop();
		LoadingState.loadAndSwitchState(nextState);
	}
}
