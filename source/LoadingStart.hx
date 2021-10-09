package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxText;

using StringTools;

class LoadingStart extends MusicBeatState
{
	var loading:FlxText;
	var musicloading:Bool = Main.skipsound;
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

	var charactersloading:Bool = Main.skipcharacters;
	var characters:Array<String> = ["characters/BOYFRIEND", 
									"characters/week4/bfCar", 
									"christmas/bfChristmas", 
									"weeb/bfPixel", "weeb/bfPixelsDEAD",
									"characters/GF_assets", 
									"characters/week4/gfCar", 
									"christmas/gfChristmas", 
									"weeb/gfPixel",
									"characters/week1/DADDY_DEAREST", 
									"spooky_kids_assets", 
									"Monster_Assets",
									"Pico_FNF_assetss", 
									"characters/week4/Mom_Assets", 
									"characters/week4/momCar",
									"christmas/mom_dad_christmas_assets", 
									"christmas/monsterChristmas",
									"weeb/senpai", "weeb/spirit", "weeb/senpaiCrazy"];

	var loadingStart:Bool = false;

	override function create()
	{
		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menu/menuBGloading'));
		add(bg);

		if (musicgame)
		{
			loading.text = "Loading Songs"
		}

		if (charactersloading)
		{
			loading.text = "Loading Assets"
		}

		if (musicgame && charactersloading)
		{
			loading.text = "Finish"
		}

		super.create();
	}

	override function update(elapsed:Float)
    {
        super.update(elapsed);

        if (FlxG.keys.justPressed.ENTER)
            {   
                FlxG.switchState(new states.TitleState());
                FlxG.camera.fade(FlxColor.BLACK, 0.8, false);
            }
	}
}