package states;

import flixel.util.FlxColor;
import flixel.FlxState;
import Alphabet;
import flixel.FlxSprite;
import flixel.FlxG;
import flixel.text.FlxText;

class CreditsDescriptionState extends FlxState {
    
    public static var Description:String;

    var bg:FlxSprite;
    var description:FlxText;
    var exitState:FlxText;

    override public function create() {
        super.create();

        bg = new FlxSprite().loadGraphic(Paths.image("menu/menuDesat"));
        add(bg);

        exitState = new FlxText(0, 0, 0, "ESC to exit", 12);
		exitState.size = 28;
		exitState.y += 35;
		exitState.scrollFactor.set();
		exitState.screenCenter(X);
		exitState.setFormat("VCR OSD Mono", 28, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(exitState);


        description = new FlxText(0,0,0,Description,30);
        description.color = FlxColor.GREEN;
        description.screenCenter();
        add(description);
    }

    override public function update(elapsed) {
        super.update(elapsed);

        if (FlxG.keys.justPressed.ESCAPE) {
            FlxG.switchState(new states.CreditState());
        }
    }
}