package states.editors;

import others.Notify;
import flixel.util.FlxColor;
import flixel.FlxG;
import flixel.FlxState;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.group.FlxSpriteGroup;
import Alphabet;

class Toolbox extends FlxState {
    
    // Config Shit 

    public var OptionsShit = [
        "Load Mods",
        "Config Mods"
    ];

    public var minCur = 1;
    public var maxCur = 2;

    // Pos shit


    public var yShit = 40;
    public var addBy = 60;
    public var fuckMeSideways = 0;

    public var curSelected = 1;

    public var idShit = 1;

    public var firstOption = true;

    // Group Shit 

    public var OptionGroup = new FlxSpriteGroup();

    // Edit this function for adding custom menu buttons 

    public function loadState() {
        switch (curSelected) {
            case 1:
                FlxG.switchState(new states.ModsState());
            case 2:
                trace("Menu Not Complete!");
        }
    }

    override public function create() {
        super.create();

        Notify.NText = "This Menu is in Beta.";
        openSubState(new others.Notify());

        var bg = new FlxSprite().loadGraphic("assets/images/menu/menuDesat.png");
        bg.screenCenter();
        bg.color = 0xFF453F3F;
        add(bg);

        for (i in OptionsShit) {
            if (firstOption) {
                var OptionShit = new Alphabet(0,yShit,i, true, false);
                OptionGroup.add(OptionShit);
                add(OptionShit);
                OptionShit.ID = idShit;

                trace("ID : " + OptionShit.ID);

                idShit++;
                firstOption = false;
                fuckMeSideways++;
            } else {
                var OptionShit = new Alphabet(0,yShit + addBy * fuckMeSideways, i, true, false);
                OptionGroup.add(OptionShit);
                add(OptionShit);
                OptionShit.ID = idShit;

                trace("ID : " + OptionShit.ID);
                
                fuckMeSideways++;
                idShit++;
            }
        }
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
            loadState();
        }

        if (FlxG.keys.justPressed.ESCAPE) {
            Notify.removeNotification();
            FlxG.switchState(new states.MainMenuState());
        }

        OptionGroup.screenCenter(X);
    }

    public function changeItem(way:String) {
        if (way.toLowerCase() == "down") {
            if (curSelected == maxCur) {
                curSelected = minCur;
            } else {
                curSelected++;
            }
        }

        if (way.toLowerCase() == "up") {
            if (curSelected == minCur) {
                curSelected = maxCur;
            } else {
                curSelected = curSelected -1;
            }
        }

        OptionGroup.forEach(function(spr:FlxSprite) {
            if (spr.ID == curSelected) {
                spr.color = FlxColor.GREEN;
            } else {
                spr.color = FlxColor.WHITE;
            }
        });
    }
}