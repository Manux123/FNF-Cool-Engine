package funkin.menus;

#if desktop
import data.Discord.DiscordClient;
#end
import flash.text.TextField;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.display.FlxGridOverlay;
import flixel.group.FlxGroup.FlxTypedGroup;
import funkin.transitions.StateTransition;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import lime.utils.Assets;
import ui.Alphabet;

using StringTools;

class CreditsState extends funkin.statesMusicBeatState
{
	//THIS BETTER WORK
	var curSelected:Int = 1;

	private var grpOptions:FlxTypedGroup<Alphabet>;

	getShit();

	/*private static var creditsStuff:Array<Dynamic> = [ 
		['Cool engine'],
		['Manux',		'manux',		'Main Programmer of Cool Engine',					'https://twitter.com/Manux',	0xFFFFDD33],
		['Juanen100',  'juan',		'Main Programmer of Cool Engine',				'https://github.com/Juanen100',	0xAC41FF],
        [''],
		['Engine Contributors'],
        ['Clogsworth',  'clogsworth',		'Additional Programmer and Musician of Cool Engine',				'https://youtube.com/c/MrClogsworthYT',	0xFFFFFFFF],
		['JloorMC',  'jloor',		'Additional Programmer of Cool Engine',				'https://github.com/JloorMC',	0xFF41CE],
		['OverchargedDev',  'overDev',		'Additional Programmer and Dumbass of Cool Engine',				'https://twitter.com/KillerBeanFan2',	0x4158FF],
		[''],
		['Special Thanks'],
		['DaimBruh',  'daim',		'Programmer of Cool Engine',				'https://github.com/DaimBruh',	0xFBB67C],
		['PabloelproxD210',  'pablo',		'Cool Engine Android port',				'https://github.com/PabloelproxD210',	0xFFFFFF],
		['ChaseToDie',  'chase',		'Programmer of Cool Engine',				'https://github.com/Chasetodie',	0x4823FF],
		['PolybiusProxy',  'polybius',		'MP4 Extension',				'https://twitter.com/polybiusproxy',	0xFFA641],
		[''],
		["Funkin' Crew"],
		['ninjamuffin99',		"Programmer of Friday Night Funkin",				'https://twitter.com/ninja_muffin99'],
		['PhantomArcade',   	"Animator of Friday Night Funkin",					'https://twitter.com/PhantomArcade3K'],
		['evilsk8r',			"Artist of Friday Night Funkin",					'https://twitter.com/evilsk8r'],
		['kawaisprite',           	"Composer of Friday Night Funkin",					'https://twitter.com/kawaisprite']
	];*/
	private static var creditsStuff:Array<Dynamic> = pussy;

	var bg:FlxSprite;
	var descText:FlxText;

	override function create()
	{
		#if desktop
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Credits", null);
		#end

		bg = new FlxSprite().loadGraphic(Paths.image('menu/menuDesat'));
		add(bg);

		grpOptions = new FlxTypedGroup<Alphabet>();
		add(grpOptions);

		for (i in 0...creditsStuff.length)
		{
			var isSelectable:Bool = !unselectableCheck(i);
			var optionText:Alphabet = new Alphabet(0, 70 * i, creditsStuff[i][0], !isSelectable, false);
			optionText.isMenuItem = true;
			optionText.screenCenter(X);
			if(isSelectable) {
				optionText.x -= 70;
			}
			//optionText.forceX = optionText.x;
			optionText.targetY = i;
			grpOptions.add(optionText);

			if(isSelectable) {

				descText = new FlxText(50, 600, 1180, "", 32);
				descText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
				descText.scrollFactor.set();
				descText.borderSize = 2.4;
				add(descText);
        	}
		}
	}	
	
	descText.text = creditsStuff[curSelected][2];

	private function unselectableCheck(num:Int):Bool {
		return creditsStuff[num].length <= 1;
	}
	var pussy;
	private function getShit():Void{
		var text = CoolUtil.coolTextFile(Paths.txt("creditsList"));
		for(i in 0... text.lenght){
			pussy.push(text[i].split(":"));
		}
	} 
	override function update(elapsed:Float)
	{
		if (FlxG.sound.music.volume < 0.7)
		{
			FlxG.sound.music.volume += 0.5 * FlxG.elapsed;
		}

		var upP = controls.UP_P;
		var downP = controls.DOWN_P;

		if (upP)
		{
			FlxG.sound.play(Paths.sound('menus/scrollMenu'));
			changeSelection(-1);
		}
		if (downP)
		{
			FlxG.sound.play(Paths.sound('menus/scrollMenu'));
			changeSelection(1);
		}

		if (controls.BACK)
		{
			FlxG.sound.play(Paths.sound('menus/cancelMenu'));
			StateTransition.switchState(new MainMenuState());
		}
		if(controls.ACCEPT) {
			#if linux
			Sys.command('/usr/bin/xdg-open', (creditsStuff[curSelected][3]));
			#else
			FlxG.openURL(creditsStuff[curSelected][3]);
			#end
		}
		super.update(elapsed);
	}
}