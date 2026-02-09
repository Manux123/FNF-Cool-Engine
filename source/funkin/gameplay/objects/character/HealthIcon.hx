package funkin.gameplay.objects.character;

import flixel.FlxG;
import lime.utils.Assets;
import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;

using StringTools;

class HealthIcon extends FlxSprite
{
	public var sprTracker:FlxSprite;

	public function new(char:String = 'bf', isPlayer:Bool = false)
	{
		super();
		updateIcon(char, isPlayer);
	}

	public function updateIcon(char:String = 'bf', isPlayer:Bool = false)
	{	
		var path = Paths.image('icons/icon-' + char);
		if(!Assets.exists(path)) path = Paths.image('icons/icon-face');

		var graphic:FlxGraphic = FlxG.bitmap.add(path);
		
		antialiasing = true;
		loadGraphic(graphic, true, 150, 150);

		var iconCount:Int = Math.floor(graphic.width / 150);

		if (iconCount >= 3) 
		{
			animation.add('normal', [0], 0, false, isPlayer);
			animation.add('losing', [1], 0, false, isPlayer);
			animation.add('winning', [2], 0, false, isPlayer);
		}
		else if (iconCount == 2) 
		{
			animation.add('normal', [0], 0, false, isPlayer);
			animation.add('losing', [1], 0, false, isPlayer);
			animation.add('winning', [0], 0, false, isPlayer);
		}
		else 
		{
			animation.add('normal', [0], 0, false, isPlayer);
			animation.add('losing', [0], 0, false, isPlayer);
			animation.add('winning', [0], 0, false, isPlayer);
		}

		if (isPlayer)
			flipX = true;

		animation.play('normal');
		scrollFactor.set();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (sprTracker != null)
			setPosition(sprTracker.x + sprTracker.width + 10, sprTracker.y - 30);
	}
}