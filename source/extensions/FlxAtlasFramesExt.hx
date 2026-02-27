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
	 * BUGFIX: guarda contra graphic==null para evitar NPE en NoteSkinSystem.loadAtlas
	 */
	public static function fromGraphic(graphic:FlxGraphic, frameWidth:Int, frameHeight:Int, ?name:String):FlxAtlasFrames
	{
		if (graphic == null)
		{
			trace('[FlxAtlasFramesExt] fromGraphic: graphic es null — se devuelve null');
			return null;
		}

		if (name == null)
			name = graphic.key;

		var frames = new FlxAtlasFrames(graphic);

		var cols = Std.int(graphic.width / frameWidth);
		var rows = Std.int(graphic.height / frameHeight);

		// Protección ante dimensiones inválidas (frame más grande que el bitmap)
		if (cols <= 0) cols = 1;
		if (rows <= 0) rows = 1;

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
