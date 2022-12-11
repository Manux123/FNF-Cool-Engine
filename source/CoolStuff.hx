package;

import flixel.FlxSprite;

class MenuBackground extends FlxSprite {
    public function new() {
        super();
    }

    public function blueBG() {
        loadGraphic(Paths.image('menuBGBlue'));
    }
}