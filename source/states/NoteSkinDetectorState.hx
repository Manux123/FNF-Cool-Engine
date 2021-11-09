package states;

import haxe.display.Display.Package;
import openfl.display.BitmapData;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import lime.utils.Assets;
import flixel.graphics.FlxGraphic;
import Note;

class NoteSkinDetectorState extends states.MusicBeatState
{
	public static var noteName:Array<String>;
	override function create() {
	 	noteName = CoolUtil.coolTextFile(Paths.txt('Fraking'));
	}
	inline static public function noteSkinPixel(patho:String) {
		if(FlxG.save.data.noteSkin == null)
			return BitmapData.fromFile(Paths.image('skins_arrows/pixels/arrows-pixels', 'week6'));
		else
			return BitmapData.fromFile(Paths.image('skins_arrows/pixels/${patho}-pixels', 'week6'));
	}

	inline static public function noteSkinNormal(path:String) {
		if(FlxG.save.data.noteSkin == null || FlxG.save.data.noteSkin == 'Arrows')
			return Paths.getSparrowAtlas('UI/NOTE_assets', "shared");
		else if(FlxG.save.data.noteSkin == noteName)
			return Paths.getSparrowAtlas('skins_arrows/normals/${path}', "shared");
		else
			return Paths.getSparrowAtlas('UI/${path}', "shared");
	}
}
