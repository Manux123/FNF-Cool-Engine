package funkin.menus;

#if desktop
import data.Discord.DiscordClient;
#end
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import funkin.transitions.StateTransition;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import ui.Alphabet;
import extensions.CoolUtil;

using StringTools;

class CreditsState extends funkin.states.MusicBeatState
{
	var curSelected:Int = 0;

	private var grpOptions:FlxTypedGroup<Alphabet>;
	private var bg:FlxSprite;
	private var descText:FlxText;

	private var creditsStuff:Array<Array<String>> = [];

	override function create()
	{
		super.create();

		#if desktop
		DiscordClient.changePresence("In the Credits", null);
		#end

		_loadCreditsFromFile();

		bg = new FlxSprite().loadGraphic(Paths.image('menu/menuDesat'));
		add(bg);

		grpOptions = new FlxTypedGroup<Alphabet>();
		add(grpOptions);

		descText = new FlxText(50, 600, 1180, "", 32);
		descText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER,
			FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		descText.scrollFactor.set();
		descText.borderSize = 2.4;
		add(descText);

		for (i in 0...creditsStuff.length)
		{
			var isSelectable:Bool = !_unselectableCheck(i);
			var optionText:Alphabet = new Alphabet(0, 70 * i, creditsStuff[i][0], !isSelectable, false);
			optionText.isMenuItem = true;
			optionText.screenCenter(X);
			if (isSelectable) optionText.x -= 70;
			optionText.targetY = i;
			grpOptions.add(optionText);
		}

		curSelected = 0;
		for (i in 0...creditsStuff.length)
			if (!_unselectableCheck(i)) { curSelected = i; break; }

		_updateDesc();
	}

	function _loadCreditsFromFile():Void
	{
		creditsStuff = [
			['Cool engine'],
			['Manux',        'manux',       'Main Programmer of Cool Engine',         'https://twitter.com/Manux',           '0xFFFFDD33'],
			['Juanen100',    'juan',        'Main Programmer of Cool Engine',         'https://github.com/Juanen100',        '0xAC41FF'],
			[''],
			['Engine Contributors'],
			['Clogsworth',   'clogsworth',  'Programmer and Musician',                'https://youtube.com/c/MrClogsworthYT','0xFFFFFFFF'],
			['JloorMC',      'jloor',       'Additional Programmer',                  'https://github.com/JloorMC',          '0xFF41CE'],
			[''],
			["Funkin' Crew"],
			['ninjamuffin99', '', 'Programmer of Friday Night Funkin', 'https://twitter.com/ninja_muffin99',  ''],
			['PhantomArcade', '', 'Animator of Friday Night Funkin',   'https://twitter.com/PhantomArcade3K', ''],
			['evilsk8r',      '', 'Artist of Friday Night Funkin',     'https://twitter.com/evilsk8r',        ''],
			['kawaisprite',   '', 'Composer of Friday Night Funkin',   'https://twitter.com/kawaisprite',     '']
		];

		#if sys
		try
		{
			final txtPath = Paths.txt('creditsList');
			if (sys.FileSystem.exists(txtPath))
			{
				final lines = CoolUtil.coolTextFile(txtPath);
				if (lines != null && lines.length > 0)
				{
					creditsStuff = [];
					for (line in lines)
						if (line.trim().length > 0)
							creditsStuff.push(line.split(':'));
				}
			}
		}
		catch (e:Dynamic) { trace('[CreditsState] No se pudo cargar creditsList: $e'); }
		#end
	}

	function _unselectableCheck(num:Int):Bool
		return creditsStuff[num].length <= 1;

	function _updateDesc():Void
	{
		if (creditsStuff.length == 0 || descText == null) return;
		final entry = creditsStuff[curSelected];
		descText.text = (entry.length > 2) ? entry[2] : '';
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (FlxG.sound.music != null && FlxG.sound.music.volume < 0.7)
			FlxG.sound.music.volume += 0.5 * FlxG.elapsed;

		if (controls.UP_P)
		{
			FlxG.sound.play(Paths.sound('menus/scrollMenu'));
			_changeSelection(-1);
		}
		if (controls.DOWN_P)
		{
			FlxG.sound.play(Paths.sound('menus/scrollMenu'));
			_changeSelection(1);
		}
		if (controls.BACK)
		{
			FlxG.sound.play(Paths.sound('menus/cancelMenu'));
			StateTransition.switchState(new funkin.menus.MainMenuState());
		}
		if (controls.ACCEPT)
		{
			final entry = creditsStuff[curSelected];
			if (entry.length > 3 && entry[3].length > 0)
			{
				#if linux
				Sys.command('/usr/bin/xdg-open', [entry[3]]);
				#else
				FlxG.openURL(entry[3]);
				#end
			}
		}
	}

	function _changeSelection(change:Int = 0):Void
	{
		curSelected = FlxMath.wrap(curSelected + change, 0, creditsStuff.length - 1);

		var attempts = 0;
		while (_unselectableCheck(curSelected) && attempts < creditsStuff.length)
		{
			curSelected = FlxMath.wrap(curSelected + (change >= 0 ? 1 : -1), 0, creditsStuff.length - 1);
			attempts++;
		}

		for (i in 0...grpOptions.length)
		{
			final item = grpOptions.members[i];
			if (item == null) continue;
			item.targetY = i - curSelected;
			item.alpha   = (item.targetY == 0) ? 1.0 : 0.6;
		}

		_updateDesc();
	}
}
