package states;

import lime.utils.Assets;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import openfl.display.BitmapData;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flash.display.BitmapData;

using StringTools;
class CacheState extends MusicBeatState
{
    var toBeFinished = 0;
	var finished = 0;
    var loadingbar:FlxSprite;

	var loading:FlxText;

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
    
    var objectsloading:Bool = false;
    var objects:Array<String> = [
        "freeplay/record player freeplay", 
        "menu/bg", "menu/blackslines_finalrating", 
        'menu/FNF_main_menu_assets', "menu/menuBG", 
        'menu/menuBGBlue', 'menu/menuBGMagenta', 
        'menu/menuChartingBG', 'menu/menuDesat',
        "menu/menuoptions", "menu/BOYFRIEND", 
        "ratings/A", 'ratings/B', 'ratings/C', 
        'ratings/D', 'ratings/F', 'ratings/S', 'ratings/SS', 
        'ratings/BOYFRIEND_RATING', 'titlestate/gfDanceTitle', 
        'titlestate/logoBumpin', 'titlestate/newgrounds_logo', 
        'titlestate/titleEnter', 'titlestate/titlestateBG',
        'UI/checkboxThingie'];
    var soundsloading:Bool = false;
    var sounds:Array<String> =[
        "confirmMenu","scrollMenu","cancelMenu",
        "intro1","intro2","intro3","introGo"];

	var loadingStart:Bool = false;

    var math:Float;

	override function create()
	{
        FlxG.mouse.visible = false;
        FlxG.sound.muteKeys = null;

        Highscore.load();
		KeyBinds.keyCheck();
		PlayerSettings.init();

        PlayerSettings.player1.controls.loadKeyBinds();

        toBeFinished = Lambda.count(characters) + Lambda.count(objects) + Lambda.count(sounds);

        var bg:FlxSprite = new FlxSprite().loadGraphic(BitmapData.fromFile(Paths.image('menu/menuBG')));
        add(bg);

        loading = new FlxText(0, 680);
        loading.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, RIGHT, OUTLINE,FlxColor.BLACK);
        loading.size = 20;
        add(loading);

		preload();
		

		super.create();
	}

	override function update(elapsed:Float)
    {
        super.update(elapsed);

        math = Mathf.getPercentage2(finished,toBeFinished);

        if (charactersloading && objectsloading && soundsloading)
        {
            FlxG.switchState(new states.TitleState());
            FlxG.camera.fade(FlxColor.BLACK, 0.8, false);
        }
	}

    function preload(){

        loading.text = "Loaded Objects: " + math;

        if(!charactersloading){
            #if sys sys.thread.Thread.create(() -> { #end
                preloadAssets();
            #if sys }); #end
        }

        if(!objectsloading){
            #if sys sys.thread.Thread.create(() -> { #end
                objectsAssets();
            #if sys }); #end
        }
        if(!soundsloading){
            #if sys sys.thread.Thread.create(() -> { #end
                soundsAssets();
            #if sys }); #end
        }
    }

    function preloadAssets(){
        for(x in characters){
            if(#if sys sys.FileSystem.exists(Paths.image(x))
                #else Assets.exists(Paths.image(x))#end){
                ImageCache.add(Paths.image(x));
            }
            else
                loading.text = "Error while loading\nImage in path " + Paths.image(x);
            trace("Chached " + x);
            finished++;
        charactersloading = true;
        }
    }

    function objectsAssets(){
        for(x in objects){
            if(#if sys sys.FileSystem.exists(Paths.image(x))
                #else Assets.exists(Paths.image(x))#end){
                loading.text = "Loaded Objects: " + math;
                ImageCache.add(Paths.image(x));
            }
            else{
                loading.text = "Error while loading\nImage in path " + Paths.image(x);
            }
            trace("Chached " + x);
            finished++;
        }
        objectsloading = true;
    }
    function soundsAssets(){
        for(x in sounds){
            if(#if sys sys.FileSystem.exists(Paths.sound(x))
                #else Assets.exists(Paths.sound(x)) #end){
                FlxG.sound.cache(Paths.sound(x));
            }
            else
                loading.text = "Error while loading\nSound in path " + Paths.sound(x);
        }
        soundsloading = true;
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