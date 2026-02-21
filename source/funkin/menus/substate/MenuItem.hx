package funkin.menus.substate;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.util.FlxColor;
#if sys
import sys.FileSystem;
#end

class MenuItem extends FlxSpriteGroup
{
	public var targetY:Float = 0;
	public var week:SafeSprite;
	public var flashingInt:Int = 0;

	public function new(x:Float, y:Float, weekNum:Int = 0)
	{
		super(x, y);
		week = new SafeSprite();

		var imgPath:String = Paths.image('menu/storymenu/titles/week' + weekNum);
		var loaded:Bool = false;

		#if sys
		if (FileSystem.exists(imgPath))
		{
			try
			{
				week.loadGraphic(imgPath);
				if (week.graphic != null && week.graphic.bitmap != null)
					loaded = true;
			}
			catch (e:Dynamic) { trace('[MenuItem] Error cargando week$weekNum: $e'); }
		}
		#else
		try
		{
			week.loadGraphic(imgPath);
			if (week.graphic != null && week.graphic.bitmap != null)
				loaded = true;
		}
		catch (e:Dynamic) { trace('[MenuItem] Error cargando week$weekNum: $e'); }
		#end

		if (!loaded || week.graphic == null || week.graphic.bitmap == null)
			week.makeGraphic(256, 80, 0xFF888888);

		add(week);
	}

	private var isFlashing:Bool = false;

	public function startFlashing():Void
	{
		isFlashing = true;
	}

	var fakeFramerate:Int = 6;

	override function update(elapsed:Float)
	{
		var fr = Math.round((1 / (elapsed > 0 ? elapsed : 1.0 / 60.0)) / 10);
		fakeFramerate = fr > 0 ? fr : 6;

		super.update(elapsed);
		y = FlxMath.lerp(y, (targetY * 120) + 480, 0.17);

		if (isFlashing)
			flashingInt += 1;

		if (flashingInt % fakeFramerate >= Math.floor(fakeFramerate / 2))
			week.color = 0xFF33ffff;
		else
			week.color = FlxColor.WHITE;
	}
}

/**
 * FlxSprite con override de draw() que corta el pipeline de render
 * si graphic o bitmap son null, evitando el crash en FlxDrawQuadsItem::render.
 */
class SafeSprite extends FlxSprite
{
	override function draw():Void
	{
		if (graphic == null || graphic.bitmap == null) return;
		super.draw();
	}
}
