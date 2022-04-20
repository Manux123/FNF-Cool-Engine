package states;

import mp4.FlxVideo;
import lime.utils.Assets;
import states.MusicBeatState;
import flixel.FlxState;
import flixel.FlxG;
import mp4.MP4Handler;
import Paths;


class VideoState extends MusicBeatState
{
    var path:String;
    var state:FlxState;

    public function new(path:String,state:FlxState){
        super();

        this.path = path;
        this.state = state;
    }

    final video:FlxVideo = new FlxVideo(0,0,FlxG.width,FlxG.height);

    public override function create(){
        FlxG.autoPause = true;

        if(Assets.exists(Paths.video(videoPath)){
            video.playVideo(Paths.video(videoPath),false,true);
    		video.finishCallback = function(){
                endVideo(false);
            }
        }
        else{
            trace('Not existing path: ' + Paths.video(videoPath));
            endVideo(false);
        }
        #if !(windows || web)
        trace('DUM ASS, THIS ONLY WORKS ON WINDOWS/HTML XDDDD');
        endVideo();
        #end

        super.create();
    }

    public override function update(elapsed:Float){
        super.update(elapsed);
        if(controls.ACCEPT)endVideo(false);
    }
    private inline function endVideo(kill:Bool):Void{
        if(kill)video.kill();
        FlxG.sound.music.stop();
        LoadingState.loadAndSwitchState(new PlayState());
    }
}
