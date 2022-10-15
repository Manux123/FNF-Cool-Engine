package states;

import states.CreditsDescriptionState;
import flixel.FlxCamera.FlxCameraFollowStyle;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.group.FlxSpriteGroup;
import flixel.FlxState;
import flixel.FlxG;
import flixel.FlxSprite;
import Alphabet;
import flixel.util.FlxColor;

class CreditState extends FlxState {

    // Item Shit

    public var pisspoop = [
        "Manux123",
        "Jloor",
        "Chasetodie",
        "Jotaro Gaming",
        "Overcharged Dev",
        "FairyBoy",
        "Zero Artist",
        "Juanen100",
        "XuelDev"
    ];

    public var descs = [
        "(Retired) Programmer Friday Night Funkin : Cool Engine",
        "(Retired) Programmer Friday Night Funkin: Cool Engine",
        "(Retired) Programmer Friday Night Funkin: Cool Engine",
        "Programmer of Friday Night Funkin: Cool Engine",
        "(Retired) Programmer Friday Night Funkin: Cool Engine",
        "(Retired) Artist Friday Night Funkin: Cool Engine",
        "(Retired) Artist Friday Night Funkin: Cool Engine",
        "Programmer of Friday Night Funkin: Cool Engine",
        "Programmer of Friday Night Funkin: Cool Engine"
    ];

    public var debug = false;

    public var curSelected = 1;

    public var yShit = 40;
    public var addBy = 60;
    public var timeBy = 0;

    public var id = 1;

    public var fC = true;

    public var credGroup = new FlxSpriteGroup();

    public var bg:FlxSprite;
    


    override public function create() {

        bg = new FlxSprite().loadGraphic(Paths.image("menu/menuDesat"));
        add(bg);

        for (i in pisspoop) {
            if (fC) {
                var Person = new Alphabet(13, yShit, i, true, false);
                Person.ID = id;

                FlxTween.tween(Person, {x: 100}, 0.45, {ease: FlxEase.quadOut});

                Person.color = FlxColor.GREEN;

                add(Person);
                credGroup.add(Person);

                // Add da shit
                id++;
                timeBy++;
                fC = false;
            } else {
                var Person = new Alphabet(13, yShit+addBy*timeBy, i, true, false);
                Person.ID = id;

                add(Person);
                credGroup.add(Person);

                // Add da shit
                id++;
                timeBy++;
            }
        }

        if (debug == true) {
            debugIds();
        }
    }

    public function debugIds() {
        credGroup.forEach(function(spr:FlxSprite) {
            trace("ID : " + spr.ID);
        });
    }

    override public function update(elapsed) {
        super.update(elapsed);

        if (FlxG.keys.justPressed.DOWN) {
            changeItem("DOWN");
        }

        if (FlxG.keys.justPressed.UP) {
            changeItem("UP");
        }

        if (FlxG.keys.justPressed.ENTER) {
            var daChoice = curSelected - 1;
            CreditsDescriptionState.Description = descs[daChoice];
            FlxG.switchState(new states.CreditsDescriptionState());
        }

        if (FlxG.keys.justPressed.ESCAPE) {
            FlxG.switchState(new states.MainMenuState());
        }

        // credGroup.screenCenter(X);
    }

    public function changeItem(way:String) {
        if (way == "DOWN") {
            if (curSelected == pisspoop.length) {
                curSelected = 1;
            } else {
                curSelected++;
            }
        }

        if (way == "UP") {
            if (curSelected == 1) {
                curSelected = pisspoop.length;
            } else {
                curSelected = curSelected - 1;
            }
        }

        credGroup.forEach(function(spr:FlxSprite) {
            if (spr.ID == curSelected) {
                FlxTween.tween(spr, {x: 100}, 0.45, {ease: FlxEase.quadOut});
                spr.color = FlxColor.GREEN;
                // FlxG.camera.follow(bg, FlxCameraFollowStyle.TOPDOWN);
            } else {
                FlxTween.tween(spr, {x: 13}, 0.45, {ease: FlxEase.quadIn});
                spr.color = FlxColor.WHITE;

            }
        });
    }
}