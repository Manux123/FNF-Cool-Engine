package states;

import mp4.FlxVideo;
import lime.utils.Assets;
import states.MusicBeatState;
import flixel.FlxState;
import flixel.FlxG;
#if (windows || web)
import mp4.MP4Handler;
#end

class VideoState extends MusicBeatState
{
    var videoPath:String;
    var nextState:FlxState;

    public function new(path:String,state:FlxState){
        super();

        this.videoPath = path;
        this.nextState = state;
    }

    #if (windows || web)
    var video:FlxVideo = new FlxVideo(0,0,FlxG.width,FlxG.height);
    #end

    public override function create(){
        FlxG.autoPause = true;

        #if (windows || web)
        if(Assets.exists(Paths.video(videoPath))){
            video.playVideo(Paths.video(videoPath),false,true);
    		video.finishCallback = function(){
                FlxG.sound.music.stop();
                LoadingState.loadAndSwitchState(nextState);
            }
        }
        else{
            trace('Not existing path: ' + Paths.video(videoPath));
            video.kill();
            FlxG.sound.music.stop();
            LoadingState.loadAndSwitchState(nextState);
        }
        #else
        trace('DUM ASS, THIS ONLY WORKS ON WINDOWS/HTML XDDDD');
        FlxG.sound.music.stop();
        LoadingState.loadAndSwitchState(nextState);
        #end

        super.create();
    }

    public override function update(elapsed:Float){
        super.update(elapsed);
        #if (windows || web)
        if(controls.ACCEPT){
            video.kill();
            FlxG.sound.music.stop();
            LoadingState.loadAndSwitchState(nextState);
        }
        #else
        video.kill();
        FlxG.sound.music.stop();
        LoadingState.loadAndSwitchState(nextState);
        #end
    }
}