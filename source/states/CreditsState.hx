package states;

#if desktop
import Discord.DiscordClient;
#end
import flash.text.TextField;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.display.FlxGridOverlay;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import lime.utils.Assets;

using StringTools;

class CreditsState extends MusicBeatState
{
	var curSelected:Int = 1;

	private var grpOptions:FlxTypedGroup<Alphabet>;

	private static var creditsStuff:Array<Dynamic> = [ 
		['Cool engine'],
		['Manux',		"Main Programmer of cool Engine",					'https://twitter.com/Manux'],
                ['Clogsworth',  "Additional Programmer and Musician of cool Engine",				'https://youtube.com/c/MrClogsworthYT'],
		[''],
		["Funkin' Crew"],
		['ninjamuffin99',		"Programmer of Friday Night Funkin",				'https://twitter.com/ninja_muffin99'],
		['PhantomArcade',   	"Animator of Friday Night Funkin",					'https://twitter.com/PhantomArcade3K'],
		['evilsk8r',			"Artist of Friday Night Funkin",					'https://twitter.com/evilsk8r'],
		['kawaisprite',           	"Composer of Friday Night Funkin",					'https://twitter.com/kawaisprite']
	];

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
			changeSelection(-1);
		}
		if (downP)
		{
			changeSelection(1);
		}

		if (controls.BACK)
		{
			if(colorTween != null) {
				colorTween.cancel();
			}
			FlxG.sound.play(Paths.sound('cancelMenu'));
			FlxG.switchState(new MainMenuState());
		}
		if(controls.ACCEPT) {
			#if linux
			Sys.command('/usr/bin/xdg-open', (creditsStuff[curSelected][3])]);
			#else
			FlxG.openURL(creditsStuff[curSelected][3]);
			#end
		}
		super.update(elapsed);
	}

	function changeSelection(change:Int = 0)
	{
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		do {
			curSelected += change;
			if (curSelected < 0)
				curSelected = creditsStuff.length - 1;
			if (curSelected >= creditsStuff.length)
				curSelected = 0;

		var bullShit:Int = 0;

		for (item in grpOptions.members)
		{
			item.targetY = bullShit - curSelected;
			bullShit++;

			if(!unselectableCheck(bullShit-1)) {
				item.alpha = 0.6;
				if (item.targetY == 0) {
					item.alpha = 1;
				}
			}
		}
		descText.text = creditsStuff[curSelected][2];
	}

	private function unselectableCheck(num:Int):Bool {
		return creditsStuff[num].length <= 1;
	}
}
