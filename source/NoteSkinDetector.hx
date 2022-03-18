package;

import lime.utils.Assets;
import flixel.FlxG;
//this isnt even an state XD
//It was supposed to be one lmao
class NoteSkinDetector
{
	inline static public function noteSkinPixel(path:String) {
		var returnPath:String='UI/arrows-pixels';
		if(FlxG.save.data.noteSkin == null)
			returnPath = Paths.image('UI/arrows-pixels');
		else if (FlxG.save.data.noteSkin == 'Circles')
			returnPath = Paths.image('UI/Circles-pixels');
		else
			returnPath = Paths.image('UI/${path}-pixels');
		return returnPath;
	}

	inline static public function noteSkinNormal(){
		var path:String = 'shared/UI/CAMELIANOTES_assets';

		var customNotes = CoolUtil.coolTextFile(Paths.txt('noteName'));

		switch (FlxG.save.data.noteSkin)
		{
			case 'Arrows':
				path = 'UI/NOTE_assets';
			case 'Circles':
				path = 'UI/Circles';
			case 'Quaver Skin':
				path = 'UI/QUAVER_assets';
			case 'StepMania':
				path = 'UI/CAMELIANOTES_assets';
			default:
				path = 'UI/' + customNotes;
		}

		var tex = Paths.getSparrowAtlas(path, 'shared');

		if(!Assets.exists(Paths.image(path))){
			tex = Paths.getSparrowAtlas('UI/NOTE_assets', 'shared');
			//trace('Assets Path: ' + Paths.getSparrowAtlas(path) + " Dosn't Exist"); FUCK IT LAGS SO MUCHHHHHHHHHHHHHHHHHHHHH
			trace('Loading: UI/NOTE_assets');  //Holy fuck it lags so much the game
		}

		return tex;
	}

	inline static public function noteSplashSkin(path:String) {
		if(Assets.exists(Paths.image(path)))
			return Paths.getSparrowAtlas('UI/${path}');
		else{
			//trace('Assets Path: ' + Paths.getSparrowAtlas('UI/${path}') + " Dosn't Exist");
			//trace('Loading: ' + Paths.getSparrowAtlas('UI/noteSplashes_clasic')); It lags as hell my game. Don't do that
			return Paths.getSparrowAtlas('UI/noteSplashes_clasic');
		}
	}
}