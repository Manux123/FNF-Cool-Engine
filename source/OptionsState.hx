package;

import flixel.FlxG;
import flixel.group.FlxSpriteGroup;
import flixel.FlxSprite;

class OptionsState extends MusicBeatState {
    var bg:FlxSprite;

    var options = ['Preferances'];

    var id = 1;
    var timeBy = 1;
    var curSelected = 1;

    var group = new FlxSpriteGroup();

    override public function create() {
        super.create();

        bg = new FlxSprite().loadGraphic(Paths.image('menuBGBlue'));
        add(bg);

        for (i in options) {
            if (id == 1) {
                var Option = new Alphabet(0, 100, i, true,false);
                Option.ID = id;
                
                add(Option);
                group.add(Option);

                id++;
                timeBy++;
            } else {
                var Option = new Alphabet(0, 100*timeBy, i, true,false);
                Option.ID = id;
                Option.alpha = 0.7;

                add(Option);
                group.add(Option);

                id++;
                timeBy++;    
            }
        }
    }
    
    override public function update(elapsed) {
        super.update(elapsed);

        group.forEach(function(spr:FlxSprite) {
            spr.screenCenter(X);
        });

        if (FlxG.keys.justPressed.ESCAPE) {FlxG.switchState(new MainMenuState());}
        if (FlxG.keys.justPressed.DOWN) {changeItem(1);}
        if (FlxG.keys.justPressed.UP) {changeItem(-1);}
        if (FlxG.keys.justPressed.ENTER) {
            var daChoice = options[curSelected-1];
            switch(daChoice) {
                case "Preferances":
                    FlxG.switchState(new options.Prefrences.Preferances());
            }
        }
    }

    public function changeItem(huh:Int) {
        curSelected += huh;

        if(curSelected==1){
            curSelected=options.length;
        }
        if(curSelected==options.length) {
            curSelected=1;
        }

        group.forEach(function(spr:FlxSprite) {
            if (curSelected == spr.ID) {
                spr.alpha = 1;
            } else {
                spr.alpha = 0.7;
            }
        });
    }

}