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
// En desktop usa MP4Handler (libVLC).
// En otras plataformas salta el video directamente.
//
// Skip: solo con ESCAPE (para estados standalone como intro screens).
// ────────────────────────────────────────────────────────────────────────────

class VideoState extends MusicBeatState
{
	var videoPath:String;
	var nextState:FlxState;

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
		trace('VideoState: video playback not supported on this platform — skipping.');
		_skipToNext();
		#end

		super.create();
	}

	public override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		#if (cpp && !mobile)
		// Solo ESCAPE para saltar en VideoState standalone (no ENTER — ese abre pausa en gameplay)
		if (FlxG.keys.justPressed.ESCAPE)
		{
			video.kill();
			_skipToNext();
		}
		#end
	}

	function _skipToNext():Void
	{
		if (FlxG.sound.music != null)
			FlxG.sound.music.stop();
		LoadingState.loadAndSwitchState(nextState);
	}
}
