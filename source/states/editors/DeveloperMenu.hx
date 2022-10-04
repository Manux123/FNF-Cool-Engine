package states.editors; // What?

import flixel.FlxState;
import flixel.text.FlxText;
import flixel.FlxSprite; // Why is it red?
import Alphabet;
import flixel.FlxG;
import flixel.util.FlxColor;
import lime.app.Application;

class DeveloperMenu extends FlxState{
    
    public var curSelected = 0;

    var Toolbox:Alphabet;

    override public function create() {
        var bg = new FlxSprite().loadGraphic("assets/images/menu/menuDesat.png");
        bg.screenCenter();
        bg.color = 0xFF453F3F;
        add(bg);

        Toolbox = new Alphabet(13, 40, "Toolbox", true, false);
        Toolbox.color = FlxColor.GREEN;
        add(Toolbox);
        
        super.create();

        var versionShit1:FlxText = new FlxText(5, FlxG.height - 14, 0, 'Cool Engine - V${Application.current.meta.get('version')}', 12);
		versionShit1.scrollFactor.set();
		versionShit1.setFormat(Paths.font("Funkin.otf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		versionShit1.y -= 20;
		add(versionShit1);

    }

    override public function update(elapsed) {
        super.update(elapsed);

        if (FlxG.keys.justPressed.ESCAPE) {
            FlxG.switchState(new states.MainMenuState());   
        }

        switch (curSelected) {
            case 0:
                Toolbox.color = FlxColor.GREEN;
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
            FlxG.sound.play(Paths.sound('confirmMenu'));
            switch (curSelected) {
                case 0:
                    FlxG.switchState(new states.editors.Toolbox());
            }
        } else if (FlxG.keys.justPressed.ESCAPE) {
            FlxG.switchState(new states.MainMenuState());
        }
    }
}
