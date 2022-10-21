package states.editors;

import flixel.util.FlxColor;
import flixel.FlxState;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.tweens.*;
import flixel.group.FlxSpriteGroup;
import Alphabet;

class Toolbox extends FlxState {

    public var optionShit = [
        "Load Mods"
    ];


    public var id = 1;

    public var yShit = 40;
    public var addBy = 60;
    public var timeBy = 0;

    public var curSelected = 1;

    public var menuItems = new FlxSpriteGroup();


    public var UP = FlxG.keys.justPressed.UP;
    public var DOWN = FlxG.keys.justPressed.DOWN;
    public var ENTER = FlxG.keys.justPressed.ENTER;

    public function loadState(num:Int) {
        
        
        var daChoice = optionShit[curSelected - 1];
        switch(daChoice) {
            case "Load Mods":
                FlxG.switchState(new states.ModsState());
        }
    }

    override public function create() {
        // var daChoice:String = optionShit[curSelected]; 
        // FlxG.switchState(optionMap[daChoice]);

        // Above is for later

        var bg = new FlxSprite().loadGraphic(Paths.image("menu/menuDesat"));
        add(bg);

        for (i in optionShit) {
            if (id == 1) {
                var OptionText = new Alphabet(13, yShit, i, true, false);
                OptionText.color = FlxColor.GREEN;
                FlxTween.tween(OptionText, {x: 100}, 0.45, {ease: FlxEase.quadOut});
                OptionText.ID = id;
                add(OptionText);

                menuItems.add(OptionText);

                id++;
                timeBy++;
                
            } else {
                var OptionText = new Alphabet(13, yShit+addBy*timeBy, i, true, false);
                OptionText.color = FlxColor.WHITE;
                OptionText.ID = id;
                add(OptionText);

                menuItems.add(OptionText);

                id++;
                timeBy++;   
            }
        }


        // Debugging Ids

        debugIds(); // If you don't want the ids to show in console comment this line out


    }

    public function debugIds() {
        menuItems.forEach(function(spr:FlxSprite) {
            trace("ID : " + spr.ID);
        });
    }

    override public function update(elapsed) {
        super.update(elapsed);
        
        if (FlxG.keys.justPressed.DOWN) {
            changeItem("DONW");
        }

        if (FlxG.keys.justPressed.UP) {
            changeItem("UP");
        }

        if (FlxG.keys.justPressed.ENTER) {
            loadState(0);
        }

        if (FlxG.keys.justPressed.ESCAPE) {
            FlxG.switchState(new states.MainMenuState());
        }
            
    } 

    public function changeItem(way:String) {
        var lWay = way.toLowerCase();

        if (lWay == "down") {
            if (curSelected == optionShit.length) {
                curSelected = 1;
            } else {
                curSelected++;
            }
        } 

        if (lWay == "up") {
            if (curSelected == 1) {
                curSelected = optionShit.length;
            } else {
                curSelected = curSelected - 1;
            }
        }

        menuItems.forEach(function(spr:FlxSprite) {
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