package;

import openfl.utils.Assets;
import states.ModsState;
import states.ModsFreeplayState;

using StringTools;

typedef CharacterData =
{
	var char:String;
    var texture:String;
    var xOffset:Int;
    var yOffset:Int;
    var anims:Array<String>;
};

class CharacterFile{
    public var char:String = 'dad';
    public var texture:String = 'nu c, que lo ponga el juan xd';
    public var xOffset:Int = 0;
    public var yOffset:Int = 0;
    public var anims:Array<String> = [];

    public static function loadFromJson(character:String):CharacterData
	{
		var rawJson = null;
		var jsonRawFile:String = ('assets/data/characters/$character.json');
		if(ModsFreeplayState.onMods && ModsState.usableMods[ModsState.modsFolders.indexOf(ModsFreeplayState.mod)] == true)
			jsonRawFile = ('mods/${ModsFreeplayState.mod!=null?ModsFreeplayState.mod:'example_mod'}/data/characters/$character.json');

		if(Assets.exists(jsonRawFile))
			rawJson = Assets.getText(jsonRawFile).trim();

		while (!rawJson.endsWith("}")){
			rawJson = rawJson.substr(0, rawJson.length - 1);
		}

		return (cast haxe.Json.parse(rawJson).character);
	}
}