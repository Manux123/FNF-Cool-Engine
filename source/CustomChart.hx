/*Code by overcharged dev
thanks for helping me fix the code 
<3*/

package;

import haxe.Json;
import lime.utils.Assets;

using StringTools;

typedef SwagModChart = {
    var modcharts:String;
    var steps:Array<Int>;
    var events:Array<String>;
    var values:Array<String>;
}

class CustomChart {
    public var modchart:String;
    public var steps:Array<Int>;
    public var events:Array<String>;
    public var values:Array<String>;

    public function new(modchart,steps,events,values) {
        this.modchart = modchart;
        this.steps = steps;
        this.events = events;
        this.values = values;
    }

    public static function loadFromJson():SwagModChart
    {
        var rawJson = Assets.getText(Std.string('assets/modcharts'+ states.PlayState.SONG.song.toLowerCase() + '/modcharts.json')).trim();
    
        while (!rawJson.endsWith("}"))
        {
            rawJson = rawJson.substr(0, rawJson.length - 1);
            // LOL GOING THROUGH THE BULLSHIT TO CLEAN IDK WHATS STRANGE
        }

        return parseMod(rawJson);
    }

    public static function parseMod(rawData:String):SwagModChart
    {
        var swagShit:SwagModChart = cast Json.parse(rawData).modChart;
        return swagShit;
    }
} 