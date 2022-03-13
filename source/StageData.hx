package;

import haxe.Json;
import haxe.format.JsonParser;
import states.ModsFreeplayState;
import lime.utils.Assets;
import states.ModsState;

using StringTools;

typedef StageFile = {
    var name:String;
    var defaultZoom:Float;
    var stagePices:Array<Dynamic>;
    var animationsData:Array<String>;
    var picesOffsets:Array<Dynamic>;
    var scrollOffsets:Array<Dynamic>;
    var antialiasing:Bool;
    var screenCenter:Bool;
    var center:Array<String>;
}

class StageData {
    public var name:String;
    public var defaultZoom:Float;
    public var stagePices:Array<Dynamic>;
    public var animationsData:Array<String>;
    public var picesOffsets:Array<Dynamic>;
    public var scrollOffsets:Array<Dynamic>;
    public var antialiasing:Bool = true;
    public var screenCenter:Bool = false;
    public var center:Array<String> = ['X', 'Y'];

    public function new(name,defaultZoom,stagePices,screenCenter,center){
        this.name = name;
        this.defaultZoom = defaultZoom;
        this.stagePices = stagePices;
        this.screenCenter = screenCenter;
        this.center = center;
    }

    public static function loadFromJson(stage:String):StageFile {
        var rawJson = null;
		var jsonRawFile:String = ('assets/data/stages/$stage.json');
		if(ModsFreeplayState.onMods && ModsState.usableMods[ModsState.modsFolders.indexOf(ModsFreeplayState.mod)] == true)
			jsonRawFile = ('mods/${ModsFreeplayState.mod}/data/stages/$stage.json');

		if(Assets.exists(jsonRawFile))
			rawJson = Assets.getText(jsonRawFile).trim();

		while (!rawJson.endsWith("}")){
			rawJson = rawJson.substr(0, rawJson.length - 1);
		}

		return (cast haxe.Json.parse(rawJson).stage);
    }
}