package states;

import flixel.FlxG;
import flixel.graphics.frames.FlxAtlasFrames;
import openfl.utils.AssetType;
import openfl.utils.Assets as OpenFlAssets;
import openfl.display.BitmapData as Bitmap;
import lime.utils.Assets;
#if sys
import sys.FileSystem;
#end

class ModsState
{
	public static var SOUND_EXT(default,set) = #if web "mp3" #else "ogg" #end;

	static var currentLevel:String = Paths.currentLevel;
	public static var modsArray:Array<ModsState> = [];
	
	static function set_SOUND_EXT(soundRound) {
		return SOUND_EXT = soundRound;
	}

	static function getPath(file:String, type:AssetType, ?library:String = null)
	{
		if (library != null)
			return getModLibPath(file, library);

		if (currentLevel != null)
		{
			var path = getLibraryMod(file, currentLevel);
			if (OpenFlAssets.exists(path, type))
				return path;
		}

		return getPreloadMod(file);
	}

	static public function getModLibPath(file:String, library = "images")
	{
		return if (library == "images" || library == "default") getPreloadMod(file); else getLibraryMod(file, library);
	}

	inline static function getLibraryMod(file:String, library:String)
	{
		return '$library:example_mods/$library/$file';
	}

	inline static function getPreloadMod(file:String)
	{
		return 'example_mods/$file';
	}

	inline static public function file(file:String, type:AssetType = TEXT, ?library:String)
	{
		return getPath(file, type, library);
	}

	inline static public function txt(key:String, ?library:String)
	{
		return getPath('data/$key.txt', TEXT, library);
	}

	inline static public function xml(key:String, ?library:String)
	{
		return getPath('data/$key.xml', TEXT, library);
	}

	inline static public function json(key:String, ?library:String)
	{
		return getPath('data/$key.json', TEXT, library);
	}

	static public function sound(key:String, ?library:String)
	{
		return getPath('sounds/$key.$SOUND_EXT', SOUND, library);
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
		if(loadingSong) {
			trace('Done Loading VOICES!');
			return 'songs:example_mods/songs/${song.toLowerCase()}/Voices.$SOUND_EXT';}
		else {
			('ERROR Loading INST :c');
			return 'defaultsong:assets/defaultsong/Voices.$SOUND_EXT';}
	}

	inline static public function inst(song:String)
	{
		trace('Loading INST');
		var loadingSong:Bool = true;
		if(loadingSong) {
			trace('Done Loading INST!');
			return 'songs:example_mods/songs/${song.toLowerCase()}/Inst.$SOUND_EXT';}
		else {
			trace('ERROR Loading INST :c');
			return 'defaultsong:assets/defaultsong/Inst.$SOUND_EXT';}
	}

	inline static public function image(key:String, ?library:String)
	{
		return getPath('images/$key.png', IMAGE, library);
	}

	inline static public function font(key:String)
	{
		return 'example_mods/fonts/$key';
	}

	inline static public function getSparrowAtlas(key:String, ?library:String)
	{
		return FlxAtlasFrames.fromSparrow(image(key, library), file('images/$key.xml', library));
	}

	inline static public function getPackerAtlas(key:String, ?library:String)
	{
		return FlxAtlasFrames.fromSpriteSheetPacker(image(key, library), file('images/$key.txt', library));
	}

	static public function modPaths(name:String) {
		#if MOD_ALL
			var path:String = name;
			var doPush:Bool = false;
			if(FileSystem.exists(ModsState.image(path))) {
				path = ModsState.getPreloadMod(path);
				doPush = true;
			} else {
				path = Paths.image(path);
				if(FileSystem.exists(path)) {
					doPush = false;
				}
			}
			/*
			if(doPush) 
				modsArray.push(new states.ModsState(path));*/
		#end
	}
}