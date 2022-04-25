package;

import states.CacheState.ImageCache;
import lime.utils.Assets;
import flixel.FlxSprite;
import states.ModsState;

using StringTools;

class HealthIcon extends FlxSprite
{
	// rewrite using da new icon system as ninjamuffin would say it
	public var sprTracker:FlxSprite;
	public var threeicon:Int;

	public function new(char:String = 'bf', isPlayer:Bool = false)
	{
		super();
		loadChar4(char);		
		updateIcon(char, isPlayer);
	}

	//this shit is for week 4 DX
	public function loadChar4(char:String){
		if(char.startsWith('bf') && !char.endsWith('pixel') && !char.endsWith('pixel-enemy'))
			char = 'bf';
		if(char.startsWith('mom'))
			char = 'mom';
	}

	//not thad used, cuz normally you dont forget to set the same name to the icon XD
	//put it if your dum, but this can brake loadChar4 function, so...
	public function antiCrash(char:String){
		if(char == null || !Assets.exists(Paths.image('icons/icon-' + char)))
			char = 'face';
		if(char == null || !Assets.exists(ModPaths.modIconImage('icon-' + char, states.ModsFreeplayState.mod)) && states.ModsFreeplayState.onMods)
			char = 'face';
	}

	public function updateIcon(char:String = 'bf', isPlayer:Bool = false)
	{
		if ((!char.endsWith('pixel')) && (char.contains('-')))
			char = char.substring(0, char.indexOf('-'));

		antialiasing = true;
		if(!states.ModsFreeplayState.onMods) 
			loadGraphic(Paths.image('icons/icon-' + char), true, 150, 150);
		else 
			loadGraphic(ModPaths.modIconImage('icon-' + char, states.ModsFreeplayState.mod), true, 150, 150);

		if (char.startsWith('bf'))
			loadGraphic(Paths.image('icons/icon-bf'), true, 150, 150);
		
		animation.add('icon', [0, 1], 0, false, isPlayer);
		animation.play('icon');
		scrollFactor.set();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (sprTracker != null)
			setPosition(sprTracker.x + sprTracker.width + 10, sprTracker.y - 30);
	}
}