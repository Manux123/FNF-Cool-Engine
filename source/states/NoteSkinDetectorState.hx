package states;

import openfl.display.BitmapData;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import lime.utils.Assets;
import flixel.graphics.FlxGraphic;
import Note;

class NoteSkinDetectorState extends states.MusicBeatState
{
	public static function noteskindetector()
	{
		var noteskinsfile:String;
		var noteskinspixel:String;
		var xml:String;
		var skins:Bool = false;
		var notesArray:Array;

		if(FileSystem.exists(Paths.getPreloadPath('assets/preload/images/skins_arrows'))) {
				(noteskinsfile.exists) = '.png';
				(xml.content) = '.xml';

				noteskinsfile = Paths.file('assets/preload/images/skins_arrows');
				skins = true;
			} 

		if(FileSystem.exists(Paths.getPreloadPath('assets/preload/images/skins_arrows'))) {
				(noteskinspixel.exists) = '-pixel.png';

				noteskinspixel = Paths.file('assets/preload/images/skins_arrows');
				skins = true;
			}

			if(skins) {
				notesArray.push(new NoteSkinDetectorState(noteskinsfile + noteskinspixel));
			}
	}

	override function update() {
		//messi

	}
}
