package states;

import openfl.display.FPS;
import openfl.Lib;
#if desktop
import Discord.DiscordClient;
#end
import controls.KeyBindMenu;
import controls.CustomControlsState;
import Controls.KeyboardScheme;
import Controls.Control;
import Section.SwagSection;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import Song.SwagSong;
import flash.text.TextField;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.display.FlxGridOverlay;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.input.keyboard.FlxKey;
import flixel.FlxSubState;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import lime.utils.Assets;
import states.MusicBeatState;

using StringTools;

class OptionsMenuState extends MusicBeatState
{
	var selector:FlxText;
	var curSelected:Int = 0;
	var menuBG:FlxSprite;

	var controlsStrings:Array<String> = [];

	private var grpControls:FlxTypedGroup<Alphabet>;
	override function create()
	{
		menuBG = new FlxSprite().loadGraphic(Paths.image('menu/menuBG'));
		controlsStrings = CoolUtil.coolStringFile(
			("\n" + 'Preferences') +
			("\n" + 'Game Options') +
			("\n" + 'Optimization') +
			("\n" + 'Note Skin') +
			("\n" + 'Controls')#if DEBUG_BUILD +
			("\n" + 'Debug')#end);
		
		//trace(controlsStrings);

		#if desktop
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Sections", null);
		#end

		menuBG.screenCenter();
		menuBG.antialiasing = true;
		menuBG.color = 0xFF453F3F;
		add(menuBG);

		grpControls = new FlxTypedGroup<Alphabet>();
		add(grpControls);

		for(i in 0... controlsStrings.length){
			var controlLabel:Alphabet = new Alphabet(0, (i + 1) * 100, controlsStrings[i], true, false);
			controlLabel.isMenuItem = false;
			controlLabel.targetY = i;

			controlLabel.alpha = 0.3;
			if(i == curSelected)
				controlLabel.alpha = 1;

			controlLabel.screenCenter(X);
			grpControls.add(controlLabel);
		}

		#if mobileC
		addVirtualPad(UP_DOWN, A_B);
		#end
		super.create();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

			if (controls.BACK) {
				FlxG.switchState(new MainMenuState());
				OptionsData.initSave(); }
			if (controls.UP_P)
				changeSelection(-1);
			if (controls.DOWN_P)
				changeSelection(1);

			if (controls.ACCEPT)
			{
				/*
				if (curSelected != 5) Useless
					grpControls.remove(grpControls.members[curSelected]);*/
				switch(curSelected)
				{
					case 0:
						LoadingState.loadAndSwitchState(new OptionsMenu());
					case 1:
						LoadingState.loadAndSwitchState(new MenuGameOptions());
					case 2:
						LoadingState.loadAndSwitchState(new OptimizationOptions());
					case 3:
						LoadingState.loadAndSwitchState(new NoteSkinState());
					case 4:
						#if mobileC
						LoadingState.loadAndSwitchState(new CustomControlsState());
						#else
						FlxG.state.openSubState(new KeyBindMenu());
						#end
					case 5:
						LoadingState.loadAndSwitchState(new DebugOptions());
				}
			}
		FlxG.save.flush();
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

			item.alpha = 0.3;
			// item.setGraphicSize(Std.int(item.width * 0.8));

			if (item.targetY == 0)
			{
				item.alpha = 1;
				// item.setGraphicSize(Std.int(item.width));
			}
		}
	}
}

class OptionsMenu extends MusicBeatState
{
	var selector:FlxText;
	var curSelected:Int = 0;

	public static var canDoRight:Bool = false;
	public static var canDoLeft:Bool = false;

	var options:Array<Option> = [
		new NewInputOption(),
		new AntiSmashOption(),
		new NoteSplashesOption(),
		new DownscrollOption(),
		new RatingSystem(),
		new MiddleScroll(),
		new HitSoundsOption(),
		#if desktop
		new FPSCap(),
		new Fullscreen(),
		#end
		new AccuracyOption()
	];

	private var grpControls:FlxTypedGroup<Alphabet>;
	var versionShit:FlxText;
	override function create()
	{
		KeyBindMenu.isPlaying = false;
		var menuBG:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menu/menuDesat'));

		menuBG.color = 0xFF453F3F;
		menuBG.setGraphicSize(Std.int(menuBG.width * 1.1));
		menuBG.updateHitbox();
		menuBG.screenCenter();
		menuBG.antialiasing = true;
		add(menuBG);

		if(FlxG.save.data.FPSCap)
			openfl.Lib.current.stage.frameRate = 120;
		else
			openfl.Lib.current.stage.frameRate = 240;

		grpControls = new FlxTypedGroup<Alphabet>();
		add(grpControls);
		
		#if desktop
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Options", null);
		#end

		for (i in 0...options.length)
		{
			var controlLabel:Alphabet = new Alphabet(0, (70 * i) + 30, options[i].getDisplay(), true, false);
			controlLabel.isMenuItem = true;
			controlLabel.targetY = i;

			controlLabel.alpha = 0.3;
			if(i == curSelected)
				controlLabel.alpha = 1;

			grpControls.add(controlLabel);
			// DONT PUT X IN THE FIRST PARAMETER OF new ALPHABET() !!
		}

		var optionsBG:FlxSprite = new FlxSprite();
		optionsBG.frames = Paths.getSparrowAtlas('menu/menuoptions');
	    optionsBG.animation.addByPrefix('idle', 'options basic', 24, false);
	    optionsBG.animation.play('idle');
	    optionsBG.antialiasing = true;
		optionsBG.screenCenter(X);
	    add(optionsBG);

		versionShit = new FlxText(5, FlxG.height - 18, 0, "Offset (Left, Right): " + FlxG.save.data.offset, 12);
		versionShit.scrollFactor.set();
		versionShit.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(versionShit);

		#if mobileC
		addVirtualPad(FULL, A_B);
		#end

		super.create();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

			if (controls.BACK)
				FlxG.switchState(new OptionsMenuState());
			if (controls.UP_P)
				changeSelection(-1);
			if (controls.DOWN_P)
				changeSelection(1);

			if (controls.RIGHT_R)
			{
				FlxG.save.data.offset++;
				versionShit.text = "Offset (Left, Right): " + FlxG.save.data.offset;
			}

			if (controls.LEFT_R)
				{
					FlxG.save.data.offset--;
					versionShit.text = "Offset (Left, Right): " + FlxG.save.data.offset;
				}
	

			if (controls.ACCEPT)
			{
				if (options[curSelected].press()) {
					grpControls.remove(grpControls.members[curSelected]);
					var ctrl:Alphabet = new Alphabet(0, (70 * curSelected) + 30, options[curSelected].getDisplay(), true, false);
					ctrl.isMenuItem = true;
					grpControls.add(ctrl);
				}
			}
		FlxG.save.flush();
	}

	var isSettingControl:Bool = false;

	function changeSelection(change:Int = 0)
	{
		#if !switch
		// NGio.logEvent("Fresh");
		#end
		
		FlxG.sound.play(Paths.sound("scrollMenu"), 0.4);

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

			item.alpha = 0.3;
			// item.setGraphicSize(Std.int(item.width * 0.8));

			if (item.targetY == 0)
			{
				item.alpha = 1;
				// item.setGraphicSize(Std.int(item.width));
			}
		}
	}
}

class MenuGameOptions extends MusicBeatState
{
	var selector:FlxText;
	var curSelected:Int = 0;

	var options:Array<Option> = [
		new SickModeOption(),
		new PerfectModeOption(),
		new HellModeOption()
	];

	private var grpControls:FlxTypedGroup<Alphabet>;
	public static var versionShit:FlxText;
	override function create()
	{
		var menuBG:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menu/menuBGBlue'));

		menuBG.setGraphicSize(Std.int(menuBG.width * 1.1));
		menuBG.updateHitbox();
		menuBG.screenCenter();
		menuBG.antialiasing = true;
		add(menuBG);

		grpControls = new FlxTypedGroup<Alphabet>();
		add(grpControls);
		
		#if desktop
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Options", null);
		#end

		for (i in 0...options.length)
		{
			var controlLabel:Alphabet = new Alphabet(0, (70 * i) + 30, options[i].getDisplay(), true, false);
			controlLabel.isMenuItem = true;
			controlLabel.targetY = i;

			controlLabel.alpha = 0.3;
			if(i == curSelected)
				controlLabel.alpha = 1;

			grpControls.add(controlLabel);
			// DONT PUT X IN THE FIRST PARAMETER OF new ALPHABET() !!
		}

		versionShit = new FlxText(5, FlxG.height - 18, 0, "Offset (Left, Right): " + FlxG.save.data.offset, 12);
		versionShit.scrollFactor.set();
		versionShit.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(versionShit);

		#if mobileC
		addVirtualPad(FULL, A_B);
		#end
		super.create();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

			if (controls.BACK)
				FlxG.switchState(new OptionsMenuState());
			if (controls.UP_P)
				changeSelection(-1);
			if (controls.DOWN_P)
				changeSelection(1);

			switch(curSelected)
			{
				case 0:
					versionShit.text = 'Full Combo Mode: You need to do full combo or else you die';
				case 1:
					versionShit.text = 'Only Sick Mode: You need to do sicks, not goods, or shits';
				case 2:
					versionShit.text = 'Hell Mode: It removes more health than it should';
			}

			if (controls.RIGHT_R)
			{
				FlxG.save.data.offset++;
				versionShit.text = "Offset (Left, Right): " + FlxG.save.data.offset;
			}

			if (controls.LEFT_R)
				{
					FlxG.save.data.offset--;
					versionShit.text = "Offset (Left, Right): " + FlxG.save.data.offset;
				}
	

			if (controls.ACCEPT)
			{
				if (options[curSelected].press()) {
					grpControls.remove(grpControls.members[curSelected]);
					var ctrl:Alphabet = new Alphabet(0, (70 * curSelected) + 30, options[curSelected].getDisplay(), true, false);
					ctrl.isMenuItem = true;
					grpControls.add(ctrl);
				}
			}
		FlxG.save.flush();
	}

	var isSettingControl:Bool = false;

	function changeSelection(change:Int = 0)
	{
		#if !switch
		// NGio.logEvent("Fresh");
		#end
		
		FlxG.sound.play(Paths.sound("scrollMenu"), 0.4);

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

			item.alpha = 0.3;
			// item.setGraphicSize(Std.int(item.width * 0.8));

			if (item.targetY == 0)
			{
				item.alpha = 1;
				// item.setGraphicSize(Std.int(item.width));
			}
		}
	}
}

class DebugOptions extends MusicBeatState{
	var selector:FlxText;
	var curSelected:Int = 0;

	public static var canDoRight:Bool = false;
	public static var canDoLeft:Bool = false;

	var options:Array<Option> = [
		new ShowDevData()
	];

	private var grpControls:FlxTypedGroup<Alphabet>;
	var versionShit:FlxText;
	override function create()
	{
		var menuBG:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menu/menuDesat'));

		menuBG.color = 0xFF453F3F;
		menuBG.setGraphicSize(Std.int(menuBG.width * 1.1));
		menuBG.updateHitbox();
		menuBG.screenCenter();
		menuBG.antialiasing = true;
		add(menuBG);

		grpControls = new FlxTypedGroup<Alphabet>();
		add(grpControls);
		
		#if desktop
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Options", null);
		#end

		for (i in 0...options.length)
		{
			var controlLabel:Alphabet = new Alphabet(0, (70 * i) + 30, options[i].getDisplay(), true, false);
			controlLabel.isMenuItem = true;
			controlLabel.targetY = i;

			controlLabel.alpha = 0.3;
			if(i == curSelected)
				controlLabel.alpha = 1;

			grpControls.add(controlLabel);
			// DONT PUT X IN THE FIRST PARAMETER OF new ALPHABET() !!
		}

		var optionsBG:FlxSprite = new FlxSprite();
		optionsBG.frames = Paths.getSparrowAtlas('menu/menuoptions');
	    optionsBG.animation.addByPrefix('idle', 'options basic', 24, false);
	    optionsBG.animation.play('idle');
	    optionsBG.antialiasing = true;
		optionsBG.screenCenter(X);
	    add(optionsBG);

		versionShit = new FlxText(5, FlxG.height - 18, 0, "Offset (Left, Right): " + FlxG.save.data.offset, 12);
		versionShit.scrollFactor.set();
		versionShit.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(versionShit);

		#if mobileC
		addVirtualPad(FULL, A_B);
		#end
		super.create();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

			if (controls.BACK)
				FlxG.switchState(new OptionsMenuState());
			if (controls.UP_P)
				changeSelection(-1);
			if (controls.DOWN_P)
				changeSelection(1);


			if (controls.RIGHT_R)
			{
				FlxG.save.data.offset++;
				versionShit.text = "Offset (Left, Right): " + FlxG.save.data.offset;
			}

			if (controls.LEFT_R)
				{
					FlxG.save.data.offset--;
					versionShit.text = "Offset (Left, Right): " + FlxG.save.data.offset;
				}
	

			if (controls.ACCEPT)
			{
				if (options[curSelected].press()) {
					grpControls.remove(grpControls.members[curSelected]);
					var ctrl:Alphabet = new Alphabet(0, (70 * curSelected) + 30, options[curSelected].getDisplay(), true, false);
					ctrl.isMenuItem = true;
					grpControls.add(ctrl);
				}
			}
		FlxG.save.flush();
	}

	var isSettingControl:Bool = false;

	function changeSelection(change:Int = 0)
	{
		#if !switch
		// NGio.logEvent("Fresh");
		#end
		
		FlxG.sound.play(Paths.sound("scrollMenu"), 0.4);

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

			item.alpha = 0.3;
			// item.setGraphicSize(Std.int(item.width * 0.8));

			if (item.targetY == 0)
			{
				item.alpha = 1;
				// item.setGraphicSize(Std.int(item.width));
			}
		}
	}
}

class OptimizationOptions extends MusicBeatState
{
	var selector:FlxText;
	var curSelected:Int = 0;

	public static var canDoRight:Bool = false;
	public static var canDoLeft:Bool = false;

	var options:Array<Option> = [
		new StaticStageOption(),
		new ByePeople(),
        new ByeGF(),
		//new EffectsOption()
	];

	private var grpControls:FlxTypedGroup<Alphabet>;
	var versionShit:FlxText;
	override function create()
	{
		var menuBG:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menu/menuDesat'));

		menuBG.color = 0xFF453F3F;
		menuBG.setGraphicSize(Std.int(menuBG.width * 1.1));
		menuBG.updateHitbox();
		menuBG.screenCenter();
		menuBG.antialiasing = true;
		add(menuBG);

		grpControls = new FlxTypedGroup<Alphabet>();
		add(grpControls);
		
		#if desktop
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Options", null);
		#end

		for (i in 0...options.length)
		{
			var controlLabel:Alphabet = new Alphabet(0, (70 * i) + 30, options[i].getDisplay(), true, false);
			controlLabel.isMenuItem = true;
			controlLabel.targetY = i;

			controlLabel.alpha = 0.3;
			if(i == curSelected)
				controlLabel.alpha = 1;

			grpControls.add(controlLabel);
			// DONT PUT X IN THE FIRST PARAMETER OF new ALPHABET() !!
		}

		var optionsBG:FlxSprite = new FlxSprite();
		optionsBG.frames = Paths.getSparrowAtlas('menu/menuoptions');
	    optionsBG.animation.addByPrefix('idle', 'options basic', 24, false);
	    optionsBG.animation.play('idle');
	    optionsBG.antialiasing = true;
		optionsBG.screenCenter(X);
	    add(optionsBG);

		versionShit = new FlxText(5, FlxG.height - 18, 0, "Offset (Left, Right): " + FlxG.save.data.offset, 12);
		versionShit.scrollFactor.set();
		versionShit.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(versionShit);

		#if mobileC
		addVirtualPad(FULL, A_B);
		#end
		super.create();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

			if (controls.BACK)
				FlxG.switchState(new OptionsMenuState());
			if (controls.UP_P)
				changeSelection(-1);
			if (controls.DOWN_P)
				changeSelection(1);


			if (controls.RIGHT_R)
			{
				FlxG.save.data.offset++;
				versionShit.text = "Offset (Left, Right): " + FlxG.save.data.offset;
			}

			if (controls.LEFT_R)
				{
					FlxG.save.data.offset--;
					versionShit.text = "Offset (Left, Right): " + FlxG.save.data.offset;
				}
	

			if (controls.ACCEPT)
			{
				if (options[curSelected].press()) {
					grpControls.remove(grpControls.members[curSelected]);
					var ctrl:Alphabet = new Alphabet(0, (70 * curSelected) + 30, options[curSelected].getDisplay(), true, false);
					ctrl.isMenuItem = true;
					grpControls.add(ctrl);
				}
			}
		FlxG.save.flush();
	}

	var isSettingControl:Bool = false;

	function changeSelection(change:Int = 0)
	{
		#if !switch
		// NGio.logEvent("Fresh");
		#end
		
		FlxG.sound.play(Paths.sound("scrollMenu"), 0.4);

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

			item.alpha = 0.3;
			// item.setGraphicSize(Std.int(item.width * 0.8));

			if (item.targetY == 0)
			{
				item.alpha = 1;
				// item.setGraphicSize(Std.int(item.width));
			}
		}
	}
}

class Option
{
	public function new()
	{
		display = updateDisplay();
	}

	private var display:String;
	public final function getDisplay():String
	{
		return display;
	}

	// Returns whether the label is to be updated.
	public function press():Bool { return throw "stub!"; }
	public function pressL():Bool { return throw "stub!"; }
	public function pressR():Bool { return throw "stub!"; }
	private function updateDisplay():String { return throw "stub!"; }
}

class StaticStageOption extends Option
{
	public override function press():Bool
	{
		FlxG.save.data.staticstage = !FlxG.save.data.staticstage;
		display = updateDisplay();
		return true;
	}

	private override function updateDisplay():String
	{
		return FlxG.save.data.staticstage ? "Static Stage" : "Normal Stage";
	}
}

class ShowDevData extends Option{
	public override function press():Bool{
		(cast (Lib.current.getChildAt(0), Main)).switchDevData();
		display = updateDisplay();
		return true;
	}
	private override function updateDisplay():String
	{
		return (cast (Lib.current.getChildAt(0), Main)).dataText.visible == true ? "Dev Data: On" : "Dev Data: Off";
		
	}
}

class ByeGF extends Option
{
	public override function press():Bool
	{
		FlxG.save.data.gfbye = !FlxG.save.data.gfbye;
		display = updateDisplay();
		return true;
	}

	private override function updateDisplay():String
	{
		return FlxG.save.data.gfbye ? "Remove GF" : "Add GF";
	}
}

class ByePeople extends Option
{
	public override function press():Bool
	{
		FlxG.save.data.byebg = !FlxG.save.data.byebg;
		display = updateDisplay();
		return true;
	}

	private override function updateDisplay():String
	{
		return FlxG.save.data.byebg ? "Remove BG Stuff" : "Add BG Stuff";
	}
}

class DownscrollOption extends Option
{
	public override function press():Bool
	{
		FlxG.save.data.downscroll = !FlxG.save.data.downscroll;
		display = updateDisplay();
		return true;
	}

	private override function updateDisplay():String
	{
		return FlxG.save.data.downscroll ? "Downscroll" : "Upscroll";
	}
}

class AntiSmashOption extends Option{
	public override function press():Bool
		{
			FlxG.save.data.antiSmash = !FlxG.save.data.antiSmash;
			display = updateDisplay();
			return true;
		}
	
	private override function updateDisplay():String
	{
		return FlxG.save.data.antiSmash ? "AntiSmash: ON" : "AntiSmash: Off";
	}
}

class RatingSystem extends Option{
	public override function press():Bool{
		FlxG.save.data.framesRanking = !FlxG.save.data.framesRanking;
		display = updateDisplay();
		return true;
	}

	private override function updateDisplay():String
	{
		return FlxG.save.data.framesRanking ? "Frames Ranking System" : "MS Ranking System";
	}
}

class FPSCap extends Option
{
	public override function press():Bool
	{
		FlxG.save.data.noFpsCap = !FlxG.save.data.noFpsCap;
			openfl.Lib.current.stage.frameRate = FlxG.save.data.FPSCap?120:240;

		display = updateDisplay();
		return true;
	}

	private override function updateDisplay():String
	{
		return !FlxG.save.data.noFpsCap ? "FPS Capped" : "FPS Not Capped";
	}
}

class AccuracyOption extends Option
{
	public override function press():Bool
	{
		FlxG.save.data.accuracyDisplay = !FlxG.save.data.accuracyDisplay;
		display = updateDisplay();
		return true;
	}

	private override function updateDisplay():String
	{
		return "Accuracy " + (!FlxG.save.data.accuracyDisplay ? "off" : "on");
	}
}

class NewInputOption extends Option
{
	public override function press():Bool
	{
		FlxG.save.data.newInput = !FlxG.save.data.newInput;
		display = updateDisplay();
		return true;
	}

	private override function updateDisplay():String
	{
		return !FlxG.save.data.newInput ? "Traditional Input" : "New Input";
	}
}

class MiddleScroll extends Option
{
	public override function press():Bool
	{
		FlxG.save.data.middlescroll = !FlxG.save.data.middlescroll;
		display = updateDisplay();
		return true;
	}

	private override function updateDisplay():String
	{
		return !FlxG.save.data.middlescroll ? "Middlescroll Off" : "Middlescroll On";
	}
}

class Fullscreen extends Option
{
	public override function press():Bool
	{
		FlxG.fullscreen = !FlxG.fullscreen;
		display = updateDisplay();
		return true;
	}

	private override function updateDisplay():String
	{
		return !FlxG.fullscreen ? "Fullscreen Off" : "Fullscreen On";
	}
}

class PerfectModeOption extends Option
{
	public override function press():Bool
	{
		FlxG.save.data.perfectmode = !FlxG.save.data.perfectmode;
		display = updateDisplay();
		return true;
	}

	private override function updateDisplay():String
	{
		return FlxG.save.data.perfectmode ? "Full Combo Mode" : "Normal Mode";
	}
}

class SickModeOption extends Option
{
	public override function press():Bool
	{
		FlxG.save.data.sickmode = !FlxG.save.data.sickmode;
		display = updateDisplay();
		return true;
	}

	private override function updateDisplay():String
	{
		return FlxG.save.data.sickmode ? "Only Sick Mode" : "SGB Mode";
	}
}

class NoteSplashesOption extends Option
{
	public override function press():Bool
	{
		FlxG.save.data.notesplashes = !FlxG.save.data.notesplashes;
		display = updateDisplay();
		return true;
	}

	private override function updateDisplay():String
	{
		return FlxG.save.data.notesplashes ? "Notes Splashes On" : "Notes Splashes Off";
	}
}

class EffectsOption extends Option
{
	public override function press():Bool
	{
		FlxG.save.data.specialVisualEffects = !FlxG.save.data.specialVisualEffects;
		display = updateDisplay();
		return true;
	}

	private override function updateDisplay():String
	{
		return FlxG.save.data.specialVisualEffects ? "Visual Effects On" : "Visual Effects Off";
	}
}

class HellModeOption extends Option
{
	public override function press():Bool
	{
		FlxG.save.data.hellmode = !FlxG.save.data.hellmode;
		display = updateDisplay();
		return true;
	}

	private override function updateDisplay():String
	{
		return FlxG.save.data.hellmode ? "Hell Mode On" : "Hell Mode Off";
	}
}

class HitSoundsOption extends Option
{
	public override function press():Bool
	{
		FlxG.save.data.hitsounds = !FlxG.save.data.hitsounds;
		display = updateDisplay();
		return true;
	}

	private override function updateDisplay():String
	{
		return FlxG.save.data.hitsounds ? "Hit Sounds On" : "Hit Sounds Off";
	}
}

class OptionsData
{
	public static function initSave()
		{
			if (FlxG.save.data.newInput == null)
				FlxG.save.data.newInput = true;
	
			if (FlxG.save.data.downscroll == null)
				FlxG.save.data.downscroll = false;

			if(FlxG.save.data.framesRanking == null)
				FlxG.save.data.framesRanking = true;
	
			if (FlxG.save.data.dfjk == null)
				FlxG.save.data.dfjk = false;
	
			if (FlxG.save.data.accuracyDisplay == null)
				FlxG.save.data.accuracyDisplay = true;
	
			if (FlxG.save.data.accuracyDisplay == null)
				FlxG.save.data.accuracyDisplay = true;

			if (FlxG.save.data.notesplashes == null)
				FlxG.save.data.notesplashes = true;

			if (FlxG.save.data.middlescroll == null)
				FlxG.save.data.middlescroll = false;

			if(FlxG.save.data.HUD == null)
				FlxG.save.data.HUD = false;
			
			if(FlxG.save.data.HUDTime == null)
				FlxG.save.data.HUDTime = false;

			if(FlxG.save.data.camZoom == null)
				FlxG.save.data.camZoom = false;

			if(FlxG.save.data.flashing == null)
				FlxG.save.data.flashing = false;
	
			if (FlxG.save.data.offset == null)
				FlxG.save.data.offset = 0;
			
			if(FlxG.save.data.perfectmode == null)
				FlxG.save.data.perfectmode = false;

			if(FlxG.save.data.sickmode == null)
				FlxG.save.data.sickmode = false;

			if(FlxG.save.data.staticstage == null)
				FlxG.save.data.staticstage = false;

			if(FlxG.save.data.specialVisualEffects == null)
				FlxG.save.data.specialVisualEffects = true;

			if(FlxG.save.data.gfbye == null)
				FlxG.save.data.gfbye = false;

			if(FlxG.save.data.byebg == null)
				FlxG.save.data.byebg = false;

			if(FlxG.save.data.hellmode == null)
				FlxG.save.data.hellmode = false;

			if(FlxG.save.data.hitsounds == null)
				FlxG.save.data.hitsounds = false;
		}
}

