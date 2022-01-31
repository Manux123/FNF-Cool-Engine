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
}

class StageData {
    public var name:String;
    public var defaultZoom:Float;
    public var stagePices:Array<Dynamic>;
    public var animationsData:Array<String>;
    public var picesOffsets:Array<Dynamic>;

    public function new(name,defaultZoom,stagePices){
        this.name = name;
        this.defaultZoom = defaultZoom;
        this.stagePices = stagePices;
    }

    public static function loadFromJson(stage:String):StageFile {
        var rawJson = null;
		var jsonRawFile:String = ('assets/stages/$stage.json');
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