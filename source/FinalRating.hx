package;

import flixel.text.FlxText;
import states.PlayState;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.util.FlxColor;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.FlxSubState;
import flixel.util.FlxTimer;

class FinalRating extends FlxSubState
{
//  var daRatings:String = "S";
    var comboText:FlxText;
    var bf:FlxSprite;
    override public function create()
    {
        FlxG.camera.fade(FlxColor.BLACK, 0.8, true);
        var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menu/menuBGBlue'));
		add(bg);

        var daLights:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menu/light_menu'));
        add(daLights);

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
        helpText.size = 28;
        add(helpText);

        var daRank:FlxSprite = new FlxSprite(600, 400).loadGraphic(Paths.image('ratings/${Rank.generateLetterRank()}'));
        daRank.scale.x = 1.5; //I tried other method but this is the one it worked
        daRank.scale.y = 1.5;
        daRank.antialiasing = true;
        add(daRank);

        var daLogo:FlxSprite = new FlxSprite(600, 200).loadGraphic(Paths.image('titlestate/daLogo'));
        daLogo.scale.x = 0.5;
        daLogo.scale.y = 0.5;
        add(daLogo);

        FlxG.camera.flash(FlxColor.WHITE, 1);

        FlxTween.tween(bg, {alpha: 0.5},1.1);
        FlxTween.tween(daRank, {y:150},1.1,{ease: FlxEase.expoInOut});
        FlxTween.tween(bf, {y:200},1.1,{ease: FlxEase.expoInOut});
    } 

    override function update(elapsed:Float)
    {
        super.update(elapsed);

        //bf.animation.play('idle', false);

        if (FlxG.keys.justPressed.ENTER)
            {   
                //bf.animation.stop();
                bf.animation.play('hey', true);

                FlxG.camera.flash(FlxColor.WHITE, 2.5);

                new FlxTimer().start(2, function(tmr:FlxTimer)
                    {
                    //Strexx estuvo aca
        
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