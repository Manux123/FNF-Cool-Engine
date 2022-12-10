package;

import openfl.system.System;
import openfl.utils.Assets;
import flixel.FlxG;

class MemoryManagement {
    public static function clear() {
        FlxG.bitmap.dumpCache();
        FlxG.bitmap.clearCache();
        Assets.cache.clear();
        System.gc();
}
}