package;

import lime.utils.Assets;
import flixel.FlxG;
//this isnt even an state XD
class NoteSkinDetector
{
	inline static public function noteSkinPixel(path:String) {
		var returnPath:String='skins_arrows/pixels/arrows-pixels';
		if(FlxG.save.data.noteSkin == null)
			returnPath = Paths.image('skins_arrows/pixels/arrows-pixels');
		else if (FlxG.save.data.noteSkin == 'Circles')
			returnPath = Paths.image('skins_arrows/pixels/Circles-pixels');
		else
			returnPath = Paths.image('skins_arrows/pixels/${path}-pixels');
		return returnPath;
	}

	inline static public function noteSkinNormal(){
		var path:String = 'UI/NOTE_assets';

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
		}

		var tex = Paths.getSparrowAtlas(path);

		if(!Assets.exists(Paths.image(path))){
			tex = Paths.getSparrowAtlas('UI/NOTE_assets');
			trace('Assets Path: ' + Paths.getSparrowAtlas(path) + " Dosn't Exist");
			trace('Loading: UI/NOTE_assets'); 
		}

		return tex;
	}

	inline static public function noteSplashSkin(path:String) {
		if(Assets.exists(Paths.image(path)))
			return Paths.getSparrowAtlas('UI/${path}');
		else{
			trace('Assets Path: ' + Paths.getSparrowAtlas('UI/${path}') + " Dosn't Exist");
			trace('Loading: ' + Paths.getSparrowAtlas('UI/noteSplashes_clasic'));
			return Paths.getSparrowAtlas('UI/noteSplashes_clasic');
		}
	}
}