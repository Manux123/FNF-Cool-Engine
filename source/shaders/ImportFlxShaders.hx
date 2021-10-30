package shaders;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.util.FlxColor;

class ImportFlxShaders
{
	override public function create()
	{
		switch (SONG.song.toLowerCase()) {	

			case 'high': //beta

				var effect:FlxSprite = new FlxSprite(-120, -50).loadGraphic(Paths.image('shaders/sunday-week4'));
				effect.scrollFactor.set(0.1, 0.1);
				add(effect);
		}
	}
}
