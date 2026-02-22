package funkin.gameplay.objects.character;

import flixel.FlxG;
import lime.utils.Assets;
#if sys
import sys.FileSystem;
#end
import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;

using StringTools;

@:keep

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
		// Construir path resolviendo mod activo
		var path = Paths.image('icons/icon-' + char);

		// Assets.exists() falla con rutas de filesystem de mods en native cpp.
		// Usamos FileSystem.exists() en sys y Assets.exists() solo como fallback.
		var iconExists:Bool = false;
		#if sys
		iconExists = sys.FileSystem.exists(path);
		if (!iconExists)
		{
			// Psych mods guardan iconos en images/icons/ sin prefijo "icon-"
			final altPath = Paths.image('icons/' + char);
			if (sys.FileSystem.exists(altPath)) { path = altPath; iconExists = true; }
		}
		#else
		iconExists = Assets.exists(path);
		#end

		if (!iconExists) path = Paths.image('icons/icon-face');

		// Cargar BitmapData con fromFile en sys (soporta rutas de mod en disco)
		var graphic:FlxGraphic = null;
		#if sys
		if (sys.FileSystem.exists(path))
		{
			final bmp = openfl.display.BitmapData.fromFile(path);
			if (bmp != null)
				graphic = flixel.graphics.FlxGraphic.fromBitmapData(bmp, false, path);
		}
		#end
		if (graphic == null)
			graphic = FlxG.bitmap.add(path);
		
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