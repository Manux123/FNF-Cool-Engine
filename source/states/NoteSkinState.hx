package states;

import states.CacheState.ImageCache;
import Controls.KeyboardScheme;
import Controls.Control;
import flash.text.TextField;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.display.FlxGridOverlay;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.graphics.atlas.FlxAtlas;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.input.keyboard.FlxKey;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import states.OptionsMenuState;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;
import lime.utils.Assets;

class NoteSkinState extends states.MusicBeatState
{
	var selector:FlxText;
	var curSelected:Int = 0;
	var controlLabel:Alphabet;

	var previewSkins:FlxSprite;

	//var noteName = CoolUtil.coolTextFile(Paths.txt('noteName'));

	private var grpControls:FlxTypedGroup<Alphabet>;
	var versionShit:FlxText;
	var daNoteSkins:Array<String>;
	override function create()
	{
		var menuBG:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menu/menuDesat'));
		daNoteSkins = CoolUtil.coolTextFile(Paths.txt('noteSkinList'));

		menuBG.color = 0xFFea71fd;
		menuBG.setGraphicSize(Std.int(menuBG.width * 1.1));
		menuBG.updateHitbox();
		menuBG.screenCenter();
		menuBG.antialiasing = true;
		add(menuBG);

		previewSkins = new FlxSprite(1000, 450);
		previewSkins.frames = Paths.getSparrowAtlas('UI/NOTE_assets', 'shared');
		previewSkins.animation.addByPrefix('green', 'arrowUP');
		previewSkins.animation.addByPrefix('blue', 'arrowDOWN');
		previewSkins.animation.addByPrefix('purple', 'arrowLEFT');
		previewSkins.animation.addByPrefix('red', 'arrowRIGHT');
		add(previewSkins);

		grpControls = new FlxTypedGroup<Alphabet>();
		add(grpControls);

		for (i in 0...daNoteSkins.length)
		{
			controlLabel = new Alphabet(0, (70 * i) + 30, daNoteSkins[i], true, false);
			controlLabel.isMenuItem = true;
			controlLabel.targetY = i;
			grpControls.add(controlLabel);
			// DONT PUT X IN THE FIRST PARAMETER OF new ALPHABET() !!
		}

		#if mobileC
		addVirtualPad(UP_DOWN, A_B);
		#end
		
		super.create();
	}

	override function update(elapsed:Float)
	{
		//var noteSkinTex = CoolUtil.coolTextFile(Paths.txt('noteName'));
		super.update(elapsed);

		previewSkins.frames = NoteSkinDetector.noteSkinNormal();

		if(controls.BACK)
			FlxG.switchState(new OptionsMenuState());
			//FlxTween.tween(controlLabel, {x: controlLabel.x - 400}, 0.6, {ease: FlxEase.quadInOut, type: ONESHOT});
		if (controls.UP_P)
			changeSelection(-1);
		if (controls.DOWN_P)
			changeSelection(1);

		if(controls.ACCEPT)
		{
			FlxG.save.data.noteSkin = daNoteSkins[curSelected];
			FlxG.sound.play(Paths.sound('confirmMenu'));
			trace('Cur selected skin is ${FlxG.save.data.noteSkin} B)');
			/*switch(daNoteSkins[curSelected])
			{
				case 0:
					FlxG.save.data.noteSkin = 'Arrows';
				case 1:
					FlxG.save.data.noteSkin = 'Circles';
				case 2:
					FlxG.save.data.noteSkin = 'Quaver Skin';
				case 3:
					FlxG.save.data.noteSkin = 'StepMania';
				case 4:
					FlxG.save.data.noteSkin = noteSkinTex;
			}*/
		}
	}

	var isSettingControl:Bool = false;

	function changeSelection(change:Int = 0)
	{
		#if !switch
		// NGio.logEvent('Fresh');
		#end
		
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		curSelected += change;

		if (curSelected < 0)
			curSelected = grpControls.length - 1;
		if (curSelected >= grpControls.length)
			curSelected = 0;

		// selector.y = (70 * curSelected) + 30;

		var bullShit:Int = 0;

		for (item in grpControls.members)
		{
			item.targetY = bullShit - curSelected;
			bullShit++;

			item.alpha = 0.6;
			// item.setGraphicSize(Std.int(item.width * 0.8));

			if (item.targetY == 0)
			{
				item.alpha = 1;
				// item.setGraphicSize(Std.int(item.width));
			}
		}
	}
}