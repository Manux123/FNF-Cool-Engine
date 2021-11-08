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
		/* I don't know how to program Bv
		var daStage:String = states.PlayState.curStage;
		var noteSkinsPixel:FlxSprite;
		var noteSkins:FlxAtlasFrames;
		var i:Int = 0;

		switch(daStage) {
			case 'school' | 'schoolEvil':
				noteSkinsPixel = new FlxSprite().loadGraphic('skins_arrows/arrowspixel-' + i);

				animation.add('greenScroll', [6]);
				animation.add('redScroll', [7]);
				animation.add('blueScroll', [5]);
				animation.add('purpleScroll', [4]);

				if (isSustainNote)
				{
					loadGraphic(Paths.image('skins_arrows/pixelbars-' + i), true, 7, 6);

					animation.add('purpleholdend', [4]);
					animation.add('greenholdend', [6]);
					animation.add('redholdend', [7]);
					animation.add('blueholdend', [5]);

					animation.add('purplehold', [0]);
					animation.add('greenhold', [2]);
					animation.add('redhold', [3]);
					animation.add('bluehold', [1]);
				}

				setGraphicSize(Std.int(width * states.PlayState.daPixelZoom));
				updateHitbox();

			case 'default':
				noteSkins.frames = Paths.getSparrowAtlas('skins_arrows/arrows-' + i);

				animation.addByPrefix('greenScroll', 'green0');
				animation.addByPrefix('redScroll', 'red0');
				animation.addByPrefix('blueScroll', 'blue0');
				animation.addByPrefix('purpleScroll', 'purple0');

				animation.addByPrefix('purpleholdend', 'pruple end hold');
				animation.addByPrefix('greenholdend', 'green hold end');
				animation.addByPrefix('redholdend', 'red hold end');
				animation.addByPrefix('blueholdend', 'blue hold end');

				animation.addByPrefix('purplehold', 'purple hold piece');
				animation.addByPrefix('greenhold', 'green hold piece');
				animation.addByPrefix('redhold', 'red hold piece');
				animation.addByPrefix('bluehold', 'blue hold piece');

				setGraphicSize(Std.int(width * 0.7));
				updateHitbox();
				antialiasing = true; 
			
		}*/
	}
}