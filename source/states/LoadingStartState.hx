package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import openfl.display.BitmapData;
import flixel.text.FlxText;
import flixel.util.FlxColor;

using StringTools;

class LoadingStartState extends MusicBeatState
{
    var toBeFinished = 0;
	var finished = 0;

	var loading:FlxText;
	var musicloading:Bool = false;
	var musicgame:Array<String> = [	"Tutorial", 
									"Boopebo", 
									"Fresh", 
									"Dadbattle", 
									"Spookeez", 
									"South", 
									"Pico", 
									"Philly", 
									"Blammed", 
									"Satin-Panties", 
									"High", 
									"Milf",
									"Cocoa", 
									"Eggnog",
									"Senpai",
									"Roses",
									"Thorns"];

	var charactersloading:Bool = false;
	var characters:Array<String> = ["characters/BOYFRIEND", 
									"characters/week4/bfCar", 
									"characters/christmas/bfChristmas", 
									"characters/characters/weeb/bfPixel", "characters/weeb/bfPixelsDEAD",
									"characters/GF_assets", 
									"characters/week4/gfCar", 
									"characters/christmas/gfChristmas", 
									"characters/weeb/gfPixel",
									"characters/week1/DADDY_DEAREST", 
									"characters/spooky_kids_assets", 
									"characters/Monster_Assets",
									"characters/Pico_FNF_assetss", 
									"characters/week4/Mom_Assets", 
									"characters/week4/momCar",
									"characters/christmas/mom_dad_christmas_assets", 
									"characters/christmas/monsterChristmas",
									"characters/weeb/senpai", "characters/weeb/spirit", "characters/weeb/senpaiCrazy"];

	var loadingStart:Bool = false;

	override function create()
	{
        FlxG.save.bind('data');
		Highscore.load();
		KeyBinds.keyCheck();
		PlayerSettings.init();

        toBeFinished = Lambda.count(characters) + Lambda.count(musicgame);

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menu/menuBGloading'));
		add(bg);

        loading = new FlxText(0, 680);
        loading.size = 24;
        add(loading);

		preload();
		

		super.create();
	}

	override function update(elapsed:Float)
    {
        super.update(elapsed);

        if (musicloading && charactersloading)
        {
            FlxG.switchState(new states.TitleState());
            FlxG.camera.fade(FlxColor.BLACK, 0.8, false);
        }
	}

    function preload(){

        loading.text = "Loading Assets";

        if(!charactersloading){
            #if sys sys.thread.Thread.create(() -> { #end
                preloadAssets();
            #if sys }); #end
        }
        
        if(!musicloading){ 
            #if sys sys.thread.Thread.create(() -> { #end
                preloadMusic();
            #if sys }); #end
        }
    }

    function preloadMusic(){
        for(x in musicgame){
            FlxG.sound.cache(Paths.inst(x));
            FlxG.sound.cache(Paths.voices(x));
            loading.text = "Music Loaded (" + finished + "/" + toBeFinished + ")";
            trace("Chached " + x);
            finished++;
        }
        
        loading.text = "Songs loaded";
        musicloading = true;
    }

    function preloadAssets(){
        for(x in characters){
            loading.text = "Assets Loaded (" + finished + "/" + toBeFinished + ")";
            ImageCache.add(Paths.image(x));
            trace("Chached " + x);
            finished++;
        }
        loading.text = "Assets Loaded";
        charactersloading = true;
    }

}

//End of Loading and Start of Image Caching


class ImageCache{

    public static var cache:Map<String,FlxGraphic> = new Map<String,FlxGraphic>();

    public static function add(path:String):Void{
        
        var data:FlxGraphic = FlxGraphic.fromBitmapData(BitmapData.fromFile(path));
        data.persist = true;

        cache.set(path, data);
    }

    public static function get(path:String):FlxGraphic{
        return cache.get(path);
    }

    public static function exists(path:String){
        return cache.exists(path);
    }

}