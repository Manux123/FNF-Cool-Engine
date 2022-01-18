package states;

#if desktop
import Discord.DiscordClient;
#end
import flixel.text.FlxText;
import flixel.FlxSprite;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import states.MusicBeatState;
import flixel.FlxG;
import flixel.graphics.frames.FlxAtlasFrames;
import openfl.utils.AssetType;
import openfl.utils.Assets as OpenFlAssets;
import openfl.display.BitmapData as Bitmap;
import flixel.input.keyboard.FlxKey;
import flixel.util.FlxTimer;
import lime.utils.Assets;
#if sys
import sys.FileSystem;
#end

class ModsState extends states.MusicBeatState
{
	var doPush:Bool = false;
	inline public static var SOUND_EXT = #if web "mp3" #else "ogg" #end;

	static var currentLevel:String = Paths.currentLevel;
	public static var modsArray:Array<ModsState> = [];
	var exitState:FlxText;
	var warning:FlxText;

	override function create(){
		#if desktop
		DiscordClient.changePresence("In the Menu Mods", null);
		#end

		var bg:FlxSprite = new FlxSprite(-80).loadGraphic(Bitmap.fromFile(Paths.image('menu/menuBGBlue')));
		bg.scrollFactor.x = 0;
		bg.scrollFactor.y = 0.18;
		bg.screenCenter();
		bg.antialiasing = true;
		add(bg);

		var	black:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		black.screenCenter(X);
		black.alpha = 0.7;
		add(black);

		exitState = new FlxText(0, 0, 0, "ESC to exit", 12);
		exitState.size = 28;
		exitState.y += 35;
		exitState.scrollFactor.set();
		exitState.screenCenter(X);
		exitState.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(exitState);

		super.create();
	}

	override function update(elapsed:Float){
		#if MOD_ALL
		var nameSongs:String = '';
		var folderModsOn:String = 'mods/data/songs/' + PlayState.SONG.song.toLowerCase() + '/' + nameSongs + '.json'; //its searches for the preload folder, not the mods folder
		modPaths(folderModsOn);

		if(!doPush) {
			warning = new FlxText(0, 0, 0, "NO MODS IN THE FOLDER example_mods", 12);
			warning.size = 36;
			warning.scrollFactor.set();
			warning.screenCenter(X);
			warning.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			add(warning);
			new FlxTimer().start(1, function (tmrr:FlxTimer){
			FlxTween.tween(warning, {alpha: 0}, 1, {type:PINGPONG});});
		} else {
			warning.kill(); }
		#end

		if(controls.BACK) {
			FlxG.switchState(new MainMenuState());
			FlxG.camera.flash(FlxColor.WHITE); }
		
		super.update(elapsed);
	}

	public static function modPaths(name:String) {
		#if MOD_ALL
			var doPush = false;
			var path:String = name;
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

	static public function setCurrentLevel(name:String)
	{
		currentLevel = name.toLowerCase();
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
}