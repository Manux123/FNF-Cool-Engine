package states;

import haxe.Exception;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.FlxG;
import flixel.FlxSprite;
import sys.FileSystem;
import sys.io.File;
import flixel.addons.transition.FlxTransitionSprite.GraphicTransTileDiamond;
import flixel.addons.transition.FlxTransitionableState;
import flixel.addons.transition.TransitionData;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.text.FlxText;

using StringTools;

class LoadingStartState extends MusicBeatState
{
    var toBeDone = 0;
    var done = 0;

    var text:FlxText;
    var bg:FlxSprite;

	override function create()
	{
        FlxG.mouse.visible = false;

        FlxG.worldBounds.set(0,0);

        bg = new FlxSprite().loadGraphic(Paths.image('titlestate/titlestateBG'));
		bg.scrollFactor.set();
		bg.antialiasing = true;
		add(bg);

        text = new FlxText(FlxG.width / 2 + 250, FlxG.height / 2 + 300,0,"Loading...");
        text.size = 34;
        text.alignment = FlxTextAlign.CENTER;

        add(text);
        
        sys.thread.Thread.create(() -> {
            cache();
        });


        super.create();
    }

    var calledDone = false;

    override function update(elapsed) 
    {

        if (toBeDone != 0 && done != toBeDone)
        {
            var alpha = truncateFloat(done / toBeDone * 100,2) / 100;
            text.alpha = 1;
            text.text = "Loading... (" + done + "/" + toBeDone + ")";
        }

        super.update(elapsed);
    }

    function truncateFloat( number : Float, precision : Int): Float {
		var num = number;
		num = num * Math.pow(10, precision);
		num = Math.round( num ) / Math.pow(10, precision);
		return num;
		}

    function cache()
    {

        var images = [];
        var music = [];

        trace("caching images...");

        for (i in FileSystem.readDirectory(FileSystem.absolutePath("assets/shared/images")))
        {
            if (!i.endsWith(".png"))
                continue;
            images.push(i);
        }

        trace("caching music...");

        for (i in FileSystem.readDirectory(FileSystem.absolutePath("assets/songs")))
        {
            music.push(i);
        }

        toBeDone = Lambda.count(images) + Lambda.count(music);

        for (i in music)
        {
            FlxG.sound.cache(Paths.inst(i));
            FlxG.sound.cache(Paths.voices(i));
            done++;
        }

        trace("Finished caching...");

        FlxG.switchState(new TitleState());
    }

}