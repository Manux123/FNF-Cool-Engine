package states.editors;

import Alphabet;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import lime.app.Application;
import Paths;
import others.Config;

class Toolbox extends FlxState {
    var bg:FlxSprite;
    var ConfigMods:Alphabet;
    var ModShit:Alphabet;

    var curSelected = 0;

    override public function create() {
        super.create();

        bg = new FlxSprite().loadGraphic("assets/images/menu/menuDesat.png");
        bg.screenCenter();
        bg.color = 0xFF453F3F;
        add(bg);

        ModShit = new Alphabet(13, 40, "Load Mods", true, false);
        ModShit.color = FlxColor.GREEN;
        add(ModShit);

        ConfigMods = new Alphabet(13, 100, "Config Mods", true, false);
        ConfigMods.color = FlxColor.WHITE;
        add(ConfigMods);

        var versionShit1:FlxText = new FlxText(5, FlxG.height - 14, 0, 'Cool Engine - V${Application.current.meta.get('version')}', 12);
		versionShit1.scrollFactor.set();
		versionShit1.setFormat(Paths.font("Funkin.otf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		versionShit1.y -= 20;
		add(versionShit1);

    }

    override public function update(elapsed) {
        super.update(elapsed);

        switch (curSelected) {
            case 0:
                ModShit.color = FlxColor.GREEN;
                ConfigMods.color = FlxColor.WHITE;
            case 1:
                ModShit.color = FlxColor.WHITE;
                ConfigMods.color = FlxColor.GREEN;
        }

        if (FlxG.keys.justPressed.UP) {
            if (curSelected == 0) {
                trace("Cant");
            } else {
                curSelected = curSelected - 1;
            }
        } else if (FlxG.keys.justPressed.DOWN) {
            if (curSelected == 1) {
                trace("Cant");
            } else {
                curSelected = curSelected + 1;
            }
        } else if (FlxG.keys.justPressed.ESCAPE) {
            FlxG.switchState(new states.editors.DeveloperMenu());
        } else if (FlxG.keys.justPressed.ENTER) {
            switch (curSelected) {
                case 0:
                    FlxG.switchState(new states.ModsState());
            }
        }
    }
}