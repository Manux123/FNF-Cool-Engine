package states;

import Controls.KeyboardScheme;
import Controls.Control;
import flash.text.TextField;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.display.FlxGridOverlay;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.graphics.atlas.FlxAtlas;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.input.keyboard.FlxKey;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import lime.utils.Assets;

class NoteSkinState extends states.MusicBeatState
{
	var selector:FlxText;
	var curSelected:Int = 0;

	var previewSkins:FlxSprite;
	
	var noteSkinTex:FlxAtlasFrames;

	private var grpControls:FlxTypedGroup<Alphabet>;
	var camGame:FlxCamera;
	var versionShit:FlxText;
	override function create()
	{
		camGame = new FlxCamera();
		FlxG.cameras.add(camGame);
		FlxCamera.defaultCameras = [camGame];
		var menuBG:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menu/menuDesat'));
		var daNoteSkins = CoolUtil.coolTextFile(Paths.txt('noteSkinList'));

		menuBG.color = 0xFFea71fd;
		menuBG.setGraphicSize(Std.int(menuBG.width * 1.1));
		menuBG.updateHitbox();
		menuBG.screenCenter();
		menuBG.antialiasing = true;
		add(menuBG);

		noteSkinTex = Paths.getSparrowAtlas('UI/NOTE_assets', 'shared');

		previewSkins = new FlxSprite(1000, 450);
		previewSkins.frames = noteSkinTex;
		previewSkins.animation.addByPrefix('green', 'arrowUP');
		previewSkins.animation.addByPrefix('blue', 'arrowDOWN');
		previewSkins.animation.addByPrefix('purple', 'arrowLEFT');
		previewSkins.animation.addByPrefix('red', 'arrowRIGHT');
		add(previewSkins);

		grpControls = new FlxTypedGroup<Alphabet>();
		add(grpControls);

		for (i in 0...daNoteSkins.length)
		{
				var controlLabel:Alphabet = new Alphabet(0, (70 * i) + 30, daNoteSkins[i], true, false);
				controlLabel.isMenuItem = true;
				controlLabel.targetY = i;
				grpControls.add(controlLabel);
			// DONT PUT X IN THE FIRST PARAMETER OF new ALPHABET() !!
		}


		versionShit = new FlxText(5, FlxG.height - 18, 0, "Offset (Left, Right): " + FlxG.save.data.offset, 12);
		versionShit.scrollFactor.set();
		versionShit.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		//add(versionShit);

		super.create();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		var noteName = CoolUtil.coolTextFile(Paths.txt('noteName'));

		switch (FlxG.save.data.noteSkin)
		{
			case 'Arrows':
				previewSkins.frames = Paths.getSparrowAtlas('UI/NOTE_assets', 'shared');
			case 'Circles':
				previewSkins.frames = Paths.getSparrowAtlas('UI/Circles', 'shared');
			case 'Quaver Skin':
				previewSkins.frames = Paths.getSparrowAtlas('UI/QUAVER_assets', 'shared');
			case noteName:
				previewSkins.frames = Paths.getSparrowAtlas('skins_arrows/normals/${noteName}', 'shared');
		}

		if(controls.BACK)
			FlxG.switchState(new options.SectionsOptions());
		if (controls.UP_P)
			changeSelection(-1);
		if (controls.DOWN_P)
			changeSelection(1);

		if(controls.ACCEPT)
		{
			switch(curSelected)
			{
				case 0:
					FlxG.save.data.noteSkin = 'Arrows';
				case 1:
					FlxG.save.data.noteSkin = 'Circles';
				case 2:
					FlxG.save.data.noteSkin = 'Quaver Skin';
				case 3:
					FlxG.save.data.noteSkin = noteName;
			}
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