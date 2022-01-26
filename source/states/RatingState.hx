package states;

import openfl.display.BitmapData;
import flixel.text.FlxText;
import states.PlayState;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.util.FlxColor;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.FlxSubState;
import flixel.util.FlxTimer;

class RatingState extends FlxSubState
{
//  var daRatings:String = "S";
    var comboText:FlxText;
    var bf:FlxSprite;
    override public function create()
    {
        FlxG.mouse.visible = false;
        if(FlxG.save.data.FPSCap)
			openfl.Lib.current.stage.frameRate = 120;
		else
			openfl.Lib.current.stage.frameRate = 240;
        
        FlxG.camera.fade(FlxColor.BLACK, 0.8, true);
        var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menu/menuBGBlue'));
		add(bg);

        var bg2:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menu/blackslines_finalrating'));
		add(bg2);

        FlxG.sound.playMusic(Paths.music('configurator'));

        var bfTex = Paths.getSparrowAtlas('menu/BOYFRIEND');
        bf = new FlxSprite(200, 400);
        bf.frames = bfTex;
		bf.animation.addByPrefix('idle', 'BF idle dance', 24, false);
        bf.animation.addByPrefix('hey', 'BF HEY!!', 24, false);
		bf.animation.play('idle');
		bf.antialiasing = true;
		add(bf);

        comboText = new FlxText(0,0,'Score: ${PlayState.songScore}\nSicks: ${PlayState.sicks}\nGoods: ${PlayState.goods}\nBads: ${PlayState.bads}\nShits: ${PlayState.shits}\nMisses: ${PlayState.misses}
        ');
        comboText.size = 28;
        comboText.setBorderStyle(FlxTextBorderStyle.OUTLINE,FlxColor.BLACK,4,1);
        comboText.color = FlxColor.WHITE;
        comboText.scrollFactor.set();
        add(comboText);

        var helpText:FlxText = new FlxText(0,650,'Press Enter To Continue');
        helpText.setBorderStyle(FlxTextBorderStyle.OUTLINE,FlxColor.BLACK,4,1);
        helpText.color = FlxColor.WHITE;
        helpText.size = 28;
        add(helpText);

        var daRank:FlxSprite = new FlxSprite(600, 400).loadGraphic(Paths.image('ratings/${Ranking.generateLetterRank()}'));
        daRank.scale.x = 1.5; //I tried other method but this is the one it worked
        daRank.scale.y = 1.5;
        daRank.antialiasing = true;
        add(daRank);
/*
        var daFC:FlxSprite = new FlxSprite(daRank.x,daRank.y).loadGraphic(BitmapData.fromFile(Paths.image('ratings/FC')));
        daFC.scale.x = 1.5; //I tried other method but this is the one it worked
        daFC.scale.y = 1.5;
        daFC.antialiasing = true;
        if(PlayState.misses == 0)
            add(daFC);*/

        var daLogo:FlxSprite = new FlxSprite(600, 200).loadGraphic(Paths.image('titlestate/daLogo'));
        daLogo.scale.x = 0.5;
        daLogo.scale.y = 0.5;   
        add(daLogo);

        FlxG.camera.flash(FlxColor.WHITE, 1);

        FlxTween.tween(bg, {alpha: 0.5},1.1+FlxG.random.float(-0.4,0.4));
        FlxTween.tween(daRank, {y:150},1.1+FlxG.random.float(-0.4,0.4),{ease: FlxEase.expoInOut});
        //FlxTween.tween(daFC, {y:150},1.1+FlxG.random.float(-0.4,0.4),{ease: FlxEase.expoInOut});
        FlxTween.tween(bf, {y:200},1.1+FlxG.random.float(-0.4,0.4),{ease: FlxEase.expoInOut});
    } 

    override function update(elapsed:Float)
    {
        super.update(elapsed);

        //bf.animation.play('idle', false);
        var pressedEnter:Bool = FlxG.keys.justPressed.ENTER;

        #if mobile
		for (touch in FlxG.touches.list)
		{
			if (touch.justPressed)
			{
				pressedEnter = true;
			}
		}
		#end

        if (pressedEnter)
            {   
                //bf.animation.stop();
                bf.animation.play('hey', true);

                FlxG.camera.flash(FlxColor.WHITE, 2.5);
                FlxG.sound.playMusic(Paths.music('freakyMenu'));
                //FlxG.sound.music.stop();

                new FlxTimer().start(2, function(tmr:FlxTimer)
                    {
                    // Strexx was here - Strexx
                    // Its not like u did something incredibly important - Juanen100
		    // you*    
        
                        if (PlayState.isStoryMode)
                        {
                            FlxG.switchState(new states.StoryMenuState());
                            FlxG.camera.fade(FlxColor.BLACK, 0.8, false);
                        }
                        else
                        {
                            FlxG.switchState(new states.FreeplayState());
                            FlxG.camera.fade(FlxColor.BLACK, 0.8, false);
                        }
                    });
            }
	}
    /*
    public override function press():Bool
    {
        PlayState.instance.openSubState(new FinalRaiting());
    }
    */
}
