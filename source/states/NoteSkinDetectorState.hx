package states;

import flixel.FlxG;

class NoteSkinDetectorState extends states.MusicBeatState
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

	inline static public function noteSkinNormal(path:String) {
		var returnPath:String='UI/NOTE_assets';
		if(FlxG.save.data.noteSkin == null || FlxG.save.data.noteSkin == 'Arrows')
			returnPath = 'UI/NOTE_assets';
		else if(FlxG.save.data.noteSkin == 'Quaver Skin')
			returnPath = 'UI/QUAVER_assets';
		else if(FlxG.save.data.noteSkin == 'Circles')
			returnPath = 'UI/Circles';
		else
			returnPath = 'skins_arrows/normals/${path}';

		return returnPath;
	}
}