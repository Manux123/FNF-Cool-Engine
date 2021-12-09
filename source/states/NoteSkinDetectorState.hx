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
	inline static public function noteSkinPixel(patho:String) {
		if(FlxG.save.data.noteSkin == null)
			return BitmapData.fromFile(Paths.image('skins_arrows/pixels/arrows-pixels', 'shared'));
		else if (FlxG.save.data.noteSkin == 'Circles')
			return BitmapData.fromFile(Paths.image('skins_arrows/pixels/Circles-pixels', 'shared'));
		else
			return BitmapData.fromFile(Paths.image('skins_arrows/pixels/${patho}-pixels', 'shared'));
	}

	inline static public function noteSkinNormal(path:String) {
		if(FlxG.save.data.noteSkin == null || FlxG.save.data.noteSkin == 'Arrows')
			return Paths.getSparrowAtlas('UI/NOTE_assets', "shared");
		else if(FlxG.save.data.noteSkin == 'Quaver Skin')
			return Paths.getSparrowAtlas('UI/QUAVER_assets', "shared");
		else if(FlxG.save.data.noteSkin == 'Circles')
			return Paths.getSparrowAtlas('UI/Circles', "shared");
		else if(FlxG.save.data.noteSkin == 'Camellia')
			return Paths.getSparrowAtlas('UI/CAMELIANOTES_assets', "shared");
		else
			return Paths.getSparrowAtlas('skins_arrows/normals/${path}', "shared");
	}
}
