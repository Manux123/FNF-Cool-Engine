package;

import states.PlayState;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.util.FlxColor;

class FinalRating extends states.MusicBeatState
{
    override public function create()
    {
        var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        bg.alpha = 0.55;
		add(bg);

        var bfTex = Paths.getSparrowAtlas('menu/BOYFRIEND');
        var bf:FlxSprite = new FlxSprite();
        bf.frames = bfTex;
		bf.animation.addByPrefix('idle', 'BF HEY!!', 24, false);
		bf.animation.play('idle');
		bf.antialiasing = true;
		add(bf);

        var daRatings:String = "S";

        if (daRatings == 'S')
        {
            var s:FlxSprite = new FlxSprite().loadGraphic(Paths.image('ratings/S'));
            add(s);
        
        }

        if (daRatings == 'A')
        {
            var a:FlxSprite = new FlxSprite().loadGraphic(Paths.image('ratings/A'));
            add(a);
             
        }

        if (daRatings == 'B')
        {
            var b:FlxSprite = new FlxSprite().loadGraphic(Paths.image('ratings/B'));
            add(b);
            
        }

        if (daRatings == 'C')
        {
            var c:FlxSprite = new FlxSprite().loadGraphic(Paths.image('ratings/C'));
            add(c);
            
        }
    } 

    override function update(elapsed:Float)
    {
        super.update(elapsed);

			if (controls.BACK)
			{
                if (FlxG.keys.justPressed.ENTER)
                {
                    FlxG.camera.flash(FlxColor.WHITE, 4);
                    
				    if (PlayState.isStoryMode)
                        FlxG.switchState(new states.StoryMenuState());
                    else
                        FlxG.switchState(new states.FreeplayState());
                }
			}
	}
    /*
    public override function press():Bool
    {
        PlayState.instance.openSubState(new FinalRaiting());
    }
    */
}