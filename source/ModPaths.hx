package;

import flixel.FlxG;
import openfl.utils.AssetType;
import openfl.utils.Assets as OpenflAssets;

class ModPaths {
    static final currentLevel:String = Paths.currentLevel;
    private static final SOUND_EXT = Paths.SOUND_EXT;

    inline static public function modBGImage(key:String, mod:String){
		return getPath('$mod/images/BGs/$key.png', IMAGE, mod);
	}

    inline static public function modIconImage(key:String, mod:String){
		return getPath('$mod/images/Icons/$key.png', IMAGE, mod);
	}

    inline static public function getModTxt(key:String, mod:String){
        return getPath('data/$key.txt',TEXT,mod);
    }

    inline static public function getModXml(key:String, mod:String )
    {
        return getPath('data/$key.xml', TEXT,mod);
    }

    inline static public function getModJson(key:String, mod:String){
            return getPath('data/$key.json',TEXT,mod);
	}
    
    static public function getModSound(key:String, mod:String)
	{
		return getPath('sounds/$key.$SOUND_EXT', SOUND, mod);
	}

    inline static public function soundRandom(key:String, min:Int, max:Int, ?mod:String)
    {
        return getModSound(key + FlxG.random.int(min, max), mod);
    }

    inline static public function getModVideo(key:String, mod:String)
	{
		trace('mods/$mod/videos/$key.mp4');
		return getPath('videos/$key.mp4', BINARY, mod);
	}

    inline static public function getPreviewVideo(key:String, mod:String)
    {
        trace('mods/previewVids/$mod/$key.mp4');
        return 'mods/previewVids/$mod/$key.mp4';
    }

    inline static public function getModMusic(key:String, mod:String)
	{
		return getPath('music/$key.$SOUND_EXT',MUSIC, mod);
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
			return 'songs:assets/songs/bopeebo/Voices.$SOUND_EXT';}
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
			return 'songs:assets/songs/bopeebo/Inst.$SOUND_EXT';}
	}
    
    inline static public function getModImage(key:String, mod:String){
		return getPath('data/$key.json', IMAGE, mod);
	}

    inline static public function getModFont(key:String,mod:String)
	{
        return getPath('fonts/$key',BINARY,mod);
	}

    inline static public function getModScripts(key:String, mod:String){
        return getPath('scripts/$key', TEXT,mod);
    }

    static public function getPath(file:String, type:AssetType, ?mod:String)
    {
        var path = "";
        if(mod != null)
            path = 'mods/$mod/$file';
        else
            path = 'mods/$file';
        if(OpenflAssets.exists(path,type))
            return path;

        return 'mods';
    }

    static public function checkModCool(mod:String){
        return openfl.utils.Assets.exists('mods/$mod/mod.cool');
    }

    inline static public function getSparrowAtlas(key:String, ?mod:String)
    {
        return flixel.graphics.frames.FlxAtlasFrames.fromSparrow(getModImage(key, mod), getPath('images/$key.xml', TEXT, mod));
    }

    inline static public function getBGsAnimated(key:String, ?mod:String)
    {
        return flixel.graphics.frames.FlxAtlasFrames.fromSparrow(getModImage(key, mod), getPath('images/BGs/$key.xml', TEXT, mod));
    }
}