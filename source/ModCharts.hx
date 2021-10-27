package;

import flixel.FlxG;
import states.PlayState;
import flixel.tweens.FlxTween;

class ModCharts
{

}

class MiddleScroll
{
	public function new()
	{

		for (i in 0...3) {
			  switch (playerStrums.members)
			  
			  case 0:
				FlxTween.tween(playerStrums, {x:     
				playerStrums.x +413}, 0.5, {type:PINGPONG}
				
			  case 1:
				FlxTween.tween(playerStrums, {x:     
				playerStrums.x +525}, 0.5, {type:PINGPONG}
		  
			  case 2:
				  FlxTween.tween(playerStrums, {x:     
				  playerStrums.x +637}, 0.5, {type:PINGPONG}
		  
			  case 3:
				  FlxTween.tween(playerStrums, {x:     
				  playerStrums.x +749}, 0.5, {type:PINGPONG}
		  
			}
	}
}