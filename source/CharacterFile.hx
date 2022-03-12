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
	var healthBarColor:Int;
};

class CharacterFile{
    public var char:String = 'dad';
    public var texture:String = ''; //abueno po lo pongo yo que quieres que te diga
    public var xOffset:Int = 0;
    public var yOffset:Int = 0;
    public var anims:Array<String> = [];
	public var healthBarColor:String;

    
}