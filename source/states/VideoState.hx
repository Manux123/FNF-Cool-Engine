package states;

import flixel.input.actions.FlxAction.FlxActionDigital;
import lime.utils.Assets;
import flixel.FlxSprite;
import flixel.util.FlxColor;
import states.MusicBeatState;
import flixel.FlxState;
import flixel.FlxG;
import mp4.MP4Handler;

class VideoState extends MusicBeatState
{
    var videoPath:String;
    var nextState:FlxState;

    public function new(path:String,state:FlxState){
        super();

        this.videoPath = path;
        this.nextState = state;
    }

    var video:MP4Handler = new MP4Handler();

    public override function create(){
        FlxG.autoPause = true;

        #if (windows || androidC)
        if(Assets.exists(Paths.video(videoPath))){
            video.playMP4(Paths.video(videoPath));
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
        trace('DUM ASS, THIS ONLY WORKS ON WINDOWS XDDDD');
        video.kill();
        FlxG.sound.music.stop();
        LoadingState.loadAndSwitchState(nextState);
        #end

        #if androidC
        controls.addDefaultGamepad(0);
        #end

        super.create();
    }

    public override function update(elapsed:Float){
        super.update(elapsed);

        if(controls.ACCEPT){
            video.kill();
            FlxG.sound.music.stop();
            LoadingState.loadAndSwitchState(nextState);
        }
    }
}