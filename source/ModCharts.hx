package;

import flixel.FlxG;
import states.PlayState;
import flixel.tweens.FlxTween;

class ModCharts {
	private function update() {
		// is very cool modcharts lol

		trace('modcharts on yeah');
	}
}

class MiddleScroll extends ModCharts
{
	public function new() {

		for (i in 0...3) {
			  switch (playerStrums.members)
			  {
				case 0:
					FlxTween.tween(playerStrums, {x:     
					playerStrums.x +413}, 0.5, {type:PINGPONG});
					
				case 1:
					FlxTween.tween(playerStrums, {x:     
					playerStrums.x +525}, 0.5, {type:PINGPONG});
		  
				case 2:
					  FlxTween.tween(playerStrums, {x:     
					  playerStrums.x +637}, 0.5, {type:PINGPONG});
		  
				case 3:
					  FlxTween.tween(playerStrums, {x:     
					  playerStrums.x +749}, 0.5, {type:PINGPONG});
			}
		}
	}
}

class EffectArrowOne extends ModCharts //reference of the Galaxy Mod lol
{
	public function new() {

		for (i in 0...3) {
			  switch (playerStrums.members)
			  {
				case 0:
					FlxTween.tween(playerStrums, {x:     
					playerStrums.x +0}, 0.5, {type:PINGPONG});
					
				case 1:
					FlxTween.tween(playerStrums, {x:     
					playerStrums.x +0}, 0.5, {type:PINGPONG});
		  
				case 2:
					  FlxTween.tween(playerStrums, {x:     
					  playerStrums.x +0}, 0.5, {type:PINGPONG});
		  
				case 3:
					  FlxTween.tween(playerStrums, {x:     
					  playerStrums.x +0}, 0.5, {type:PINGPONG});
			}
		}
	}
}

class OneArrowDown extends ModCharts //reference of the QT Mod
{
	public function new() {

		for (i in 0) {
			  switch (playerStrums.members)
			  {
				case 0:
					FlxTween.tween(playerStrums, {x:     
					playerStrums.x +0}, 0.5, {type:PINGPONG});
			  }
			}
		for (i in 1) {
			  switch (playerStrums.members)
			  {
				case 1:
					FlxTween.tween(playerStrums, {x:     
					playerStrums.x +0}, 0.5, {type:PINGPONG});
			  }
			}
		  
		for (i in 2) {
			  switch (playerStrums.members)
			  {
				case 2:
					FlxTween.tween(playerStrums, {x:     
					playerStrums.x +0}, 0.5, {type:PINGPONG});
			  }
			}

		for (i in 3) {
			  switch (playerStrums.members)
			  {
				case 3:
					FlxTween.tween(playerStrums, {x:     
					playerStrums.x +0}, 0.5, {type:PINGPONG});
			  }
			}
			
	}
}