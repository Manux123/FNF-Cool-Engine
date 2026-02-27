package funkin.gameplay.objects.character;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;

#if sys
import sys.FileSystem;
#end

using StringTools;

@:keep
class HealthIcon extends FlxSprite
{
	public var sprTracker:FlxSprite;

	/** Last char loaded — avoids redundant reloads when updateIcon is called with the same char. */
	private var _lastChar:String = '';
	private var _isPlayer:Bool   = false;

	public function new(char:String = 'bf', isPlayer:Bool = false)
	{
		super();
		updateIcon(char, isPlayer);
	}

	public function updateIcon(char:String = 'bf', isPlayer:Bool = false)
	{
		// Skip reload if same character — avoids unnecessary disk I/O and alloc
		if (char == _lastChar && isPlayer == _isPlayer && frames != null)
		{
			// Just re-apply flip in case isPlayer changed
			flipX = isPlayer;
			return;
		}

		_lastChar  = char;
		_isPlayer  = isPlayer;

		// ── Resolve path + logical key ────────────────────────────────────────
		// We track the logical key so that Paths.getGraphic receives the same
		// key that image() will resolve — avoiding the "no encontrado" mismatch
		// that caused the null-object crash in FlxDrawQuadsItem::render.
		var iconKey  = 'icons/icon-' + char;
		var path     = Paths.image(iconKey);

		#if sys
		var iconExists = FileSystem.exists(path);
		if (!iconExists)
		{
			// Psych mods store icons without the "icon-" prefix
			final altKey  = 'icons/' + char;
			final altPath = Paths.image(altKey);
			if (FileSystem.exists(altPath)) { path = altPath; iconKey = altKey; iconExists = true; }
		}
		if (!iconExists)
		{
			iconKey = 'icons/icon-face';
			path    = Paths.image(iconKey);
		}
		#else
		if (!openfl.utils.Assets.exists(path))
		{
			iconKey = 'icons/icon-face';
			path    = Paths.image(iconKey);
		}
		#end

		// ── Load through PathsCache so the graphic is tracked and freed properly ──
		var graphic:FlxGraphic = null;

		#if sys
		if (FileSystem.exists(path))
		{
			// Pass the resolved logical key so getGraphic builds the correct path
			graphic = Paths.getGraphic(iconKey);
			// Fallback: if getGraphic still can't resolve, load directly and register
			// in Flixel's bitmap cache so it is properly freed on state cleanup.
			if (graphic == null)
			{
				final bmp = openfl.display.BitmapData.fromFile(path);
				if (bmp != null)
				{
					graphic = FlxGraphic.fromBitmapData(bmp, false, path, true);
					if (graphic != null) graphic.persist = true;
				}
			}
		}
		#end

		if (graphic == null)
			graphic = FlxG.bitmap.add(path);

		if (graphic == null)
		{
			trace('[HealthIcon] Could not load icon for "$char" — using transparent placeholder to avoid FlxDrawQuadsItem crash');
			// BUGFIX: without a graphic, frames == null, which causes a null object
			// reference in FlxDrawQuadsItem::render on the very first draw call.
			// makeGraphic() guarantees a valid BitmapData/frames even when the asset
			// is missing, so the icon is invisible but the game does not crash.
			makeGraphic(150, 150, 0x00000000);
			return;
		}

		antialiasing = true;
		loadGraphic(graphic, true, 150, 150);

		final iconCount:Int = Math.floor(graphic.width / 150);

		if (iconCount >= 3)
		{
			animation.add('normal',  [0], 0, false, isPlayer);
			animation.add('losing',  [1], 0, false, isPlayer);
			animation.add('winning', [2], 0, false, isPlayer);
		}
		else if (iconCount == 2)
		{
			animation.add('normal',  [0], 0, false, isPlayer);
			animation.add('losing',  [1], 0, false, isPlayer);
			animation.add('winning', [0], 0, false, isPlayer);
		}
		else
		{
			animation.add('normal',  [0], 0, false, isPlayer);
			animation.add('losing',  [0], 0, false, isPlayer);
			animation.add('winning', [0], 0, false, isPlayer);
		}

		flipX = isPlayer;

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
