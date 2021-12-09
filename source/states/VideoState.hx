package states;

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

    public static var isCutscene = true;
    public function new(path:String,state:FlxState) {
        super();

        videoPath = path;
        nextState = state;
    }

    var video:MP4Handler;

    public override function create(){
        super.create();
        var videoGrp:FlxSprite = new FlxSprite(0,0);

        video.playMP4(Paths.video(videoPath),null,videoGrp);

        //yes, it's duplicated shit
        //deal with it B)
		video.finishCallback = function(){
            funnyChange = true;
            FlxG.switchState(nextState);
            FlxG.sound.music.stop();
            isCutscene = false;
        };

        add(videoGrp);
    }

    var funnyChange:Bool = false;

    public override function update(elapsed:Float){
        super.update(elapsed);

        if (isCutscene)
            video.onVLCComplete();

        if(controls.ACCEPT && !funnyChange)
            changeState();
    }

    public function changeState(){
        funnyChange = true;
        FlxG.sound.music.stop();
        FlxG.switchState(nextState);
        isCutscene = false;
    }
}