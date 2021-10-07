package;

import PlayState;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.util.FlxColor;
import flixel.FlxObject;
import flixel.addons.transition.FlxTransitionableState;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;

class FinalRaiting extends MusicBeatState
{
    override public function create()
    {
        var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        bg.alpha = 0.55;
		add(bg);

        var bf:FlxSprite = new FlxSprite() = Paths.getSparrowAtlas('ratings/BOYFRIEND_RATING');
        bf.frames = bfTex;
		bf.animation.addByPrefix('hey', 'BF HEY!!', 24, false);
		bf.animation.play('hey');
		bf.antialiasing = true;
		add(bf);

        var daRatings:String = "S";

        if (daRatings == 'S')
        {
            var s:FlxSprite = new FlxSprite().loadGraphic(Paths.image('ratings/S'));
            add(s);
            
            if (daRating)
            {
                sicks = 1000;
                goods = 0;
                bads = 0;
                shits = 0;
                missess = 0;
            } 

            var bfsick:FlxSprite = new FlxSprite() = Paths.getSparrowAtlas('ratings/BOYFRIEND_RATING');
            bfsick.animation.addByPrefix('idle', 'BF idle dance', 24, false);
            bfsick.animation.play('idle');
            bfsick.antialiasing = true;
            add(bfsick);

        }

        if (daRatings == 'A')
        {
            var a:FlxSprite = new FlxSprite().loadGraphic(Paths.image('ratings/A'));
            add(a);
            
            if (daRating)
            {
                sicks = 150;
                goods = 50;
                bads = 20;
                shits = 5;
                missess = 1;
            } 

            var bffora:FlxSprite = new FlxSprite() = Paths.getSparrowAtlas('ratings/BOYFRIEND_RATING');
            bffora.animation.addByPrefix('idle', 'BF idle shaking', 24, false);
            bffora.animation.play('idle');
            bffora.antialiasing = true;
            add(bffora);

        }

        if (daRatings == 'B')
        {
            var b:FlxSprite = new FlxSprite().loadGraphic(Paths.image('ratings/B'));
            add(b);
            
            if (daRating)
            {
                sicks = 100;
                goods = 80;
                bads = 30;
                shits = 10;
                missess = 2;
            } 

            var bfforb:FlxSprite = new FlxSprite() = Paths.getSparrowAtlas('ratings/BOYFRIEND_RATING');
            bfforb.animation.addByPrefix('idle', 'BF hit', 24, false);
            bfforb.animation.play('idle');
            bfforb.antialiasing = true;
            add(bfforb);
        }

        if (daRatings == 'C')
        {
            var c:FlxSprite = new FlxSprite().loadGraphic(Paths.image('ratings/C'));
            add(c);
            
            if (daRating)
            {
                sicks = 0;
                goods = 2000;
                bads = 2000;
                shits = 2000;
                missess = 2000;
            } 

            var bfforc:FlxSprite = new FlxSprite() = Paths.getSparrowAtlas('ratings/BOYFRIEND_RATING');
            bfforc.animation.addByPrefix('idle', 'BF Dead Loop', 24, false);
            bfforc.animation.play('idle');
            bfforc.antialiasing = true;
            add(bfforc);
        }
    } 

    override function update(elapsed:Float)
    {
        super.update(elapsed);

            if (FlxG.keys.justPressed.ANY)
            {
                bf.animation.play('hey');

                if (PlayState.isStoryMode)
                { 
                    PlayState.storyPlaylist = weekData[curWeek];
                    PlayState.isStoryMode = true;
                    selectedWeek = true;
        
                    var diffic = "";
        
                    switch (curDifficulty)
                    {
                        case 0:
                            diffic = '-easy';
                        case 2:
                            diffic = '-hard';
                    }
        
                    PlayState.storyDifficulty = curDifficulty;
        
                    PlayState.SONG = Song.loadFromJson(PlayState.storyPlaylist[0].toLowerCase() + diffic, PlayState.storyPlaylist[0].toLowerCase());
                    PlayState.storyWeek = curWeek;
                    PlayState.campaignScore = 0;
                    new FlxTimer().start(1, function(tmr:FlxTimer)
                    {
                        LoadingState.loadAndSwitchState(new PlayState(), true);
                    });
                }
                else
                    PlayState.SONG = Song.loadFromJson(poop, songs[curSelected].songName.toLowerCase());
                    PlayState.isStoryMode = false;
                    PlayState.storyDifficulty = curDifficulty;
                    PlayState.storyWeek = songs[curSelected].week;
                    trace('CUR WEEK' + PlayState.storyWeek);
                    LoadingState.loadAndSwitchState(new PlayState());

                if (storyPlaylist.length <= 0)
                    { 
                        FlxG.sound.playMusic(Paths.music('freakyMenu'));

                        transIn = FlxTransitionableState.defaultTransIn;
                        transOut = FlxTransitionableState.defaultTransOut;
        
                        FlxG.switchState(new StoryMenuState());
        
                        // if ()
                        StoryMenuState.weekUnlocked[Std.int(Math.min(storyWeek + 1, StoryMenuState.weekUnlocked.length - 1))] = true;
        
                        if (SONG.validScore)
                        {
                            NGio.unlockMedal(60961);
                            Highscore.saveWeekScore(storyWeek, campaignScore, storyDifficulty);
                        }
        
                        FlxG.save.data.weekUnlocked = StoryMenuState.weekUnlocked;
                        FlxG.save.flush();    
                    }
                
                //if (daRating == 'S')
                //{
                //    
                //}
            }
	}
    public override function press():Bool
    {
        PlayState.instance.openSubState(new FinalRaiting());
    }
}