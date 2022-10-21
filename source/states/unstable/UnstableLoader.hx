package states.unstable;

import flixel.FlxState;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.tweens.*;
import flixel.util.*;
import Alphabet;

class UnstableLoader extends FlxState {

    public var options = [
        "MainMenu BETA"
    ];

    public var menuItems = new FlxSpriteGroup();
    
    public var yShit = 40;
    public var addBy = 60;
    public var timeBy = 0;

    public var curSelected = 1;

    public var id = 1;

    public function loadState() {
        var daChoice = options[curSelected-1];

        switch(daChoice) {
            case "MainMenu BETA":
                FlxG.switchState(new states.unstable.MainMenuBETA());
        }
    }

    override public function create() {
        super.create();

        var bg = new FlxSprite().loadGraphic(Paths.image("menu/menuBGBlue"));
        add(bg);

        for (i in options) {
            if (id == 1) {
                var Option = new Alphabet(13, yShit, i, true, false);
                Option.color = FlxColor.GREEN;
                FlxTween.tween(Option, {x: 100}, 0.45, {ease: FlxEase.quadOut});
                add(Option);
                Option.ID = id;
                menuItems.add(Option);

                id++;
                timeBy++;
            } else {
                var Option = new Alphabet(13, yShit+addBy*timeBy, i, true, false);
                add(Option);
                Option.ID = id;
                menuItems.add(Option);

                id++;
                timeBy++;
            }
        }
    }

    override public function update(elapsed) {
        super.update(elapsed);

        if (FlxG.keys.justPressed.DOWN) {
            changeItem("D");
        }

        if (FlxG.keys.justPressed.UP) {
            changeItem("U");
        }

        if (FlxG.keys.justPressed.ENTER) {
            loadState();
        }

        if (FlxG.keys.justPressed.ESCAPE) {
            FlxG.switchState(new states.MainMenuState());
        }
    }

    public function changeItem(way:String) {
        way = way.toLowerCase();

        if (way == "d") {
            if (curSelected == options.length) {
                curSelected = 1;
            } else {
                curSelected++;
            }
        } 

        if (way == "u") {
            if (curSelected == 1) {
                curSelected = options.length;
            } else {
                curSelected = curSelected - 1;
            }
        }

        menuItems.forEach(function(spr:FlxSprite) {
            if (spr.ID == curSelected) {
                FlxTween.tween(spr, {x: 100}, 0.45, {ease: FlxEase.quadOut});
                spr.color = FlxColor.GREEN;
            } else {
                FlxTween.tween(spr, {x: 13}, 0.45, {ease: FlxEase.quadIn});
                spr.color = FlxColor.WHITE;
            }
        });
    }


}