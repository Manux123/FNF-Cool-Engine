package extensions;

import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.frames.FlxFrame;
import flixel.graphics.FlxGraphic;
import flixel.math.FlxRect;
import flixel.math.FlxPoint;

class FlxAtlasFramesExt
{
	/**
	 * Recreación del antiguo FlxAtlasFrames.fromGraphic
	 */
	public static function fromGraphic(graphic:FlxGraphic, frameWidth:Int, frameHeight:Int, ?name:String):FlxAtlasFrames
	{
		if (name == null)
			name = graphic.key;

		var frames = new FlxAtlasFrames(graphic);

		var cols = Std.int(graphic.width / frameWidth);
		var rows = Std.int(graphic.height / frameHeight);

		var index = 0;

		for (y in 0...rows)
		{
			for (x in 0...cols)
			{
				var rect = FlxRect.get(x * frameWidth, y * frameHeight, frameWidth, frameHeight);

				var frame = frames.addAtlasFrame(rect, FlxPoint.get(frameWidth, frameHeight), FlxPoint.get(0, 0), name + "_" + index);
				index++;
			}
		}

		return frames;
	}
}
