package options;

import flixel.FlxG;

class OptionsPreload {
    public static function loadSettings() {
        if (FlxG.save.data.downscroll == null) {
            FlxG.save.data.downscroll = false;
        }
    }
}