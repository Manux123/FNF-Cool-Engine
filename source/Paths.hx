package;

import flixel.FlxG;
import flixel.graphics.frames.FlxAtlasFrames;
import openfl.utils.AssetType;
import openfl.utils.Assets as OpenFlAssets;
import funkin.gameplay.PlayState;
import openfl.display.BitmapData as Bitmap;

class Paths
{
	inline public static var SOUND_EXT = #if web "mp3" #else "ogg" #end;

	static var currentLevel:String;

	static public function setCurrentLevel(name:String)
	{
		currentLevel = name.toLowerCase();
	}

	static function getPath(file:String, type:AssetType, library:Null<String>)
	{
		if (library != null)
			return getLibraryPath(file, library);

		if (currentLevel != null)
		{
			var levelPath = getLibraryPathForce(file, currentLevel);
			if (OpenFlAssets.exists(levelPath, type))
				return levelPath;

			levelPath = getLibraryPathForce(file, "shared");
			if (OpenFlAssets.exists(levelPath, type))
				return levelPath;
		}

		return getPreloadPath(file);
	}

	static public function getLibraryPath(file:String, library = "preload")
	{
		return if (library == "preload" || library == "default") getPreloadPath(file); else getLibraryPathForce(file, library);
	}

	inline static function getLibraryPathForce(file:String, library:String)
	{
		return '$library:assets/$library/$file';
	}

	inline static function getPreloadPath(file:String)
	{
		return 'assets/$file';
	}

	inline static public function file(file:String, type:AssetType = TEXT, ?library:String)
	{
		return getPath(file, type, library);
	}

	inline static public function txt(key:String, ?library:String)
	{
		return getPath('data/$key.txt', TEXT, library);
	}

	inline static public function songsTxt(key:String, ?library:String)
	{
		return 'songs:assets/songs/$key.txt';
	}

	inline static public function xml(key:String, ?library:String)
	{
		return getPath('data/$key.xml', TEXT, library);
	}

	
	inline static public function json(key:String, ?library:String)
	{
		return getPath('data/$key.json', TEXT, library);
	}

	inline static public function jsonSong(key:String)
	{
		return 'songs:assets/songs/$key.json';
	}

	inline static public function stageJSON(key:String)
	{
		return 'assets/stages/$key.json';
	}

	inline static public function characterJSON(key:String, ?library:String)
	{
		return getPath('characters/$key.json', TEXT, library);
	}

	static public function sound(key:String, ?library:String)
	{
		return getPath('sounds/$key.$SOUND_EXT', SOUND, library);
	}

	static public function soundStage(key:String, ?library:String)
	{
		return getPath('stages/$key.$SOUND_EXT', SOUND, library);
	}

	inline static public function soundRandom(key:String, min:Int, max:Int, ?library:String)
	{
		return sound(key + FlxG.random.int(min, max), library);
	}

	inline static public function video(key:String, ?library:String)
	{
		trace('assets/videos/$key.mp4');
		return getPath('videos/$key.mp4', BINARY, library);
	}

	inline static public function music(key:String, ?library:String)
	{
		return getPath('music/$key.$SOUND_EXT', MUSIC, library);
	}

	inline static public function voices(song:String)
	{
		trace('Loading VOICES');
		var loadingSong:Bool = true;
		if (loadingSong)
		{
			trace('Done Loading VOICES!');
			return 'songs:assets/songs/${song.toLowerCase()}/Voices.$SOUND_EXT';
		}
		else
		{
			trace('ERROR Loading VOICES :c');
			return 'songs:assets/songs/test/Voices.$SOUND_EXT';
		}
	}

	inline static public function inst(song:String)
	{
		trace('Loading INST');
		var loadingSong:Bool = true;
		if (loadingSong)
		{
			trace('Done Loading INST!');
			return 'songs:assets/songs/${song.toLowerCase()}/Inst.$SOUND_EXT';
		}
		else
		{
			trace('ERROR Loading INST :c');
			return 'songs:assets/songs/test/Inst.$SOUND_EXT';
		}
	}

	inline static public function image(key:String, ?library:String)
	{
		return getPath('images/$key.png', IMAGE, library);
	}

	inline static public function characterimage(key:String, ?library:String)
	{
		return getPath('characters/images/$key.png', IMAGE, library);
	}

	inline static public function imageStage(key:String, ?library:String)
	{
		return getPath('stages/' + PlayState.curStage + '/images/' + key + '.png', IMAGE, library);
	}

	inline static public function font(key:String)
	{
		return 'assets/fonts/$key';
	}

	inline static public function getSparrowAtlas(key:String, ?library:String)
	{
		return FlxAtlasFrames.fromSparrow(image(key, library), file('images/$key.xml', library));
	}

	inline static public function characterSprite(key:String, ?library:String)
	{
		return FlxAtlasFrames.fromSparrow(getPath('characters/images/$key.png', IMAGE, library), getPath('characters/images/$key.xml', TEXT, library));
	}

	inline static public function stageSprite(key:String, ?library:String)
	{
		return FlxAtlasFrames.fromSparrow(getPath('stages/' + PlayState.curStage + '/images/' + key + '.png', IMAGE, library), getPath('stages/' + PlayState.curStage + '/images/' + key + '.xml', TEXT, library));
	}

	inline static public function skinSprite(key:String, ?library:String)
	{
		return FlxAtlasFrames.fromSparrow(getPath('skins/$key.png', IMAGE, library), getPath('skins/$key.xml', TEXT, library));
	}
	
	inline static public function getPackerAtlas(key:String, ?library:String)
	{
		return FlxAtlasFrames.fromSpriteSheetPacker(image(key, library), file('images/$key.txt', library));
	}

	inline static public function characterSpriteTxt(key:String, ?library:String)
	{
		return FlxAtlasFrames.fromSpriteSheetPacker(getPath('characters/images/$key.png', IMAGE, library), file('characters/images/$key.txt', library));
	}

	inline static public function stageSpriteTxt(key:String, ?library:String)
	{
		return FlxAtlasFrames.fromSpriteSheetPacker(getPath('stages/' + PlayState.curStage + '/images/$key.png', IMAGE, library), file('stages/' + PlayState.curStage + '/images/$key.txt', library));
	}

	
	inline static public function splashSprite(key:String, ?library:String)
	{
		return FlxAtlasFrames.fromSparrow(getPath('splashes/$key.png', IMAGE, library), getPath('splashes/$key.xml', TEXT, library));
	}

	inline static public function skinSpriteTxt(key:String, ?library:String)
	{
		return FlxAtlasFrames.fromSpriteSheetPacker(getPath('skins/$key.png', IMAGE, library), file('skins/$key.txt', library));
	}
}
