package scripting;

import flixel.FlxState;
import API;

class Script {

    public static function onCreate() {
        // Runs when the script is loaded
        API.log("Script has been activated");
    }

    public static function onUpdate() {
        // Runs when PlayState is updated
    }

    public static function onDeath() {
        // Runs when boyfriend dies
    }
}