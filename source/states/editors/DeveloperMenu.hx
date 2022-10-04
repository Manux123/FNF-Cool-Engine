package states.editors; // What?

import flixel.FlxState;
import flixel.text.FlxText;
import flixel.FlxSprite; // Why is it red?
import Alphabet;
import flixel.FlxG;
import flixel.util.FlxColor;

class DeveloperMenu extends FlxState{
    
    public var curSelected = 0;

    override public function create() {
        var bg = new FlxSprite().loadGraphic("assets/images/menu/menuDesat.png");
        bg.screenCenter();
        bg.color = 0xFF453F3F;
        add(bg);

        var Toolbox:Alphabet = new Alphabet(13, 40, "Toolbox", true, false);
        Toolbox.color = FlxColor.GREEN;
        add(Toolbox);
        
        super.create();

    }

    override public function update(elapsed) {
        super.update(elapsed);

        if (FlxG.keys.justPressed.ESCAPE) {
            FlxG.switchState(new states.MainMenuState());   
        }

        if (FlxG.keys.justPressed.UP) {
            switch (curSelected) {
                case 0:
                    trace("Cant");
            } 
        } else if (FlxG.keys.justPressed.DOWN) {
            switch (curSelected) {
                case 0:
                    trace("Cant");
            }
        } else if (FlxG.keys.justPressed.ENTER) {
            switch (curSelected) {
                case 0:
                    FlxG.switchState(new states.editors.classes.Toolbox());
            }
        }
    }
}
