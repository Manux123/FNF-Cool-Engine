package;

import flixel.FlxG;
import openfl.utils.AssetType;
import openfl.utils.Assets as OpenflAssets;

class ModPaths {
    static final currentLevel:String = Paths.currentLevel;
    private static final SOUND_EXT = Paths.SOUND_EXT;

    inline static public function getModFile(file:String, mod:String, type:AssetType = TEXT){
        return getPath(file, type, mod);
    }

    inline static public function modBGImage(key:String, mod:String, ?library:String){
		return getPath('$mod/images/BGs/$key.png', IMAGE, mod, library);
	}

    inline static public function getModTxt(key:String, mod:String, ?library:String){
        if(mod != null)
            return getPath('$mod/data/$key.txt',TEXT,library);
        else
            return getPath('$key.txt',TEXT,library);
	}

    inline static public function getModXml(key:String, mod:String ,?library:String)
    {
        return getPath('data/$key.xml', TEXT, library);
    }

    inline static public function getModJson(key:String, mod:String, ?library:String){
        if(mod != null)
            return getPath('$mod/data/$key.json', TEXT, library);
        else
            return getPath('data/$key.json',TEXT,library);
	}

    static public function getModSound(key:String, mod:String, ?library:String)
	{
		return getPath('$mod/sounds/$key.$SOUND_EXT', SOUND, mod, library);
	}

    inline static public function soundRandom(key:String, min:Int, max:Int, ?library:String)
    {
        return getModSound(key + FlxG.random.int(min, max), library);
    }

    inline static public function getModVideo(key:String, mod:String, ?library:String)
	{
		trace('mods/$mod/videos/$key.mp4');
		return getPath('$mod/videos/$key.mp4', BINARY, mod, library);
	}

    inline static public function getModMusic(key:String, mod:String, ?library:String)
	{
		return getPath('$mod/music/$key.$SOUND_EXT',MUSIC, mod, library);
	}

    inline static public function getModVoices(song:String, mod:String)
	{
		trace('Loading VOICES');
		var loadingSong:Bool = true;
		if(loadingSong) {
			trace('Done Loading VOICES!');
			return 'mods/$mod/songs/${song.toLowerCase()}/Voices.$SOUND_EXT';}
		else {
			trace('ERROR Loading INST :c');
			return 'mods/$mod/defaultsong/Voices.$SOUND_EXT';}
	}

    inline static public function getModInst(song:String, mod:String)
	{
		trace('Loading INST');
		var loadingSong:Bool = true;
		if(loadingSong) {
			trace('Done Loading INST!');
			return 'mods/$mod/songs/${song.toLowerCase()}/Inst.$SOUND_EXT';}
		else {
			trace('ERROR Loading INST :c');
			return 'mods/$mod/defaultsong/Inst.$SOUND_EXT';}
	}
    
    inline static public function getModImage(key:String, mod:String, ?library:String){
		return getPath('$mod/data/$key.json', IMAGE, mod, library);
	}

    inline static public function modBGVideo(key:String, mod:String){
		return getPath('$mod/videos/freeplay/$key.mp4', BINARY, mod, null);
	}

    inline static public function modIconImage(key:String, mod:String, ?library:String){
		return getPath('$mod/images/Icons/$key.png', IMAGE, mod, library);
	}

    inline static public function getModFont(key:String,mod:String)
	{
		return 'mods/$mod/fonts/$key';
	}

    static public function getPath(file:String, type:AssetType, ?mod:String, ?library:String)
    {
        if (library != null)
            return getModLibPath(file, mod, library);
        
        if (currentLevel != null)
        {
            var path = getLibraryMod(file,mod);
            if (OpenflAssets.exists(path, type))
                return path;
        }
        
        return getPreloadMod(file,null);
    }

    static public function getModLibPath(file:String, mod:String, library = "images")
    {
        return if (library == "images" || library == "default") getPreloadMod(file,mod); else getLibraryMod(file, mod);
    }

    static public function getModCool(mod:String){
        return 'mods/$mod/mod.cool';
    }

    inline static function getLibraryMod(file:String, ?mod:String = null)
    {
        if(mod != null)
            return 'mods/$mod/$file';
        else
            return 'mods/$file';
    }

    inline static public function getPreloadMod(file:String,?mod:String = null)
	{
        if(mod != null)
            return 'mods/$mod/$file';
        return 'mods/$file';
	}

    inline static public function getSparrowAtlas(key:String, ?mod:String)
    {
        return flixel.graphics.frames.FlxAtlasFrames.fromSparrow(getModImage(key, mod), getModFile('images/$key.xml', mod));
    }

    inline static public function getBGsAnimated(key:String, ?mod:String)
    {
        return flixel.graphics.frames.FlxAtlasFrames.fromSparrow(getModImage(key, mod), getModFile('images/BGs/$key.xml', mod));
    }
}