package funkin.menus;

import openfl.display.FPS;
#if desktop
import data.Discord.DiscordClient;
#end
import funkin.menus.KeyBindMenu;
import funkin.scripting.StateScriptHandler;
import funkin.gameplay.controls.CustomControlsState;
import funkin.gameplay.controls.Controls.KeyboardScheme;
import funkin.gameplay.controls.Controls.Control;
import funkin.data.Section.SwagSection;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import funkin.gameplay.notes.NoteSkinOptions;
import funkin.data.Song.SwagSong;
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
import extensions.CoolUtil;
import lime.utils.Assets;
import funkin.menus.FreeplayState;
import funkin.gameplay.PlayState;
import funkin.states.MusicBeatState;
import funkin.menus.MainMenuState;
import ui.Alphabet;

using StringTools;

/**
 * Main Options Menu - Categorized options with visual interface
 */
class OptionsMenuState extends MusicBeatState
{
	var selector:FlxText;
	var curSelected:Int = 0;
	var menuBG:FlxSprite;

	var controlsStrings:Array<String> = [];
	private var grpControls:FlxTypedGroup<Alphabet>;
	
	// Visual elements
	var categoryDesc:FlxText;
	var categoryIcons:FlxTypedGroup<FlxSprite>;

	public static var isPlayingMusic:Bool = false;
	public static var fromPause:Bool = false; // Track if opened from pause menu

	public static var optionsSong:String = '';
	
	override function create()
	{
		// Cargar scripts del state
		#if HSCRIPT_ALLOWED
		StateScriptHandler.init();
		StateScriptHandler.loadStateScripts('OptionsMenuState', this);
		StateScriptHandler.callOnScripts('onCreate', []);
		#end
		
		menuBG = new FlxSprite().loadGraphic(Paths.image('menu/menuBG'));
		controlsStrings = CoolUtil.coolStringFile(
			("\n" + 'Graphics') +
			("\n" + 'Gameplay') +
			("\n" + 'Optimization') +
			("\n" + 'Note Skin') +
			("\n" + 'Controls'));
		
		// Añadir categorías custom desde scripts
		#if HSCRIPT_ALLOWED
		var customCategories = StateScriptHandler.getCustomCategories();
		for (category in customCategories)
		{
			controlsStrings.push(category);
		}
		#end
		
		#if desktop
		DiscordClient.changePresence("In the Options", null);
		#end

		MainMenuState.musicFreakyisPlaying = false;
		if (!isPlayingMusic && FreeplayState.vocals == null && !fromPause){
			FlxG.sound.playMusic(Paths.music('configurator'));
		}

		menuBG.screenCenter();
		menuBG.antialiasing = FlxG.save.data.antialiasing;
		menuBG.color = 0xFF453F3F;
		add(menuBG);

		// Title text
		var titleText:FlxText = new FlxText(0, 30, FlxG.width, "OPTIONS MENU", 32);
		titleText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		titleText.borderSize = 2;
		add(titleText);

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

		// Category description
		categoryDesc = new FlxText(0, FlxG.height - 80, FlxG.width, "", 20);
		categoryDesc.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		categoryDesc.borderSize = 1.5;
		add(categoryDesc);
		
		updateCategoryDesc();

		#if mobileC
		addVirtualPad(UP_DOWN, A_B);
		#end
		super.create();
	}

	function updateCategoryDesc():Void
	{
		switch(curSelected)
		{
			case 0:
				categoryDesc.text = "Resolution, FPS, Window Mode";
			case 1:
				categoryDesc.text = "Downscroll, Ghost Tapping, Accuracy, etc.";
			case 2:
				categoryDesc.text = "Performance settings and optimizations";
			case 3:
				categoryDesc.text = "Customize your note appearance";
			case 4:
				categoryDesc.text = "Configure keyboard and gamepad controls";
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		
		#if HSCRIPT_ALLOWED
		StateScriptHandler.callOnScripts('onUpdate', [elapsed]);
		#end

		if (controls.UP_P)
			changeSelection(-1);
		if (controls.DOWN_P)
			changeSelection(1);

		if (controls.ACCEPT)
		{
			#if HSCRIPT_ALLOWED
			var cancelled = StateScriptHandler.callOnScriptsReturn('onAccept', [], false);
			if (cancelled) {
				FlxG.save.flush();
				return;
			}
			#end
			
			isPlayingMusic = true;
			switch(curSelected)
			{
				case 0:
					FlxG.switchState(new GraphicsOptionsMenu());
				case 1:
					FlxG.switchState(new GameplayOptionsMenu());
				case 2:
					FlxG.switchState(new OptimizationOptions());
				case 3:
					FlxG.switchState(new NoteSkinOptions());
				case 4:
					#if mobileC
					FlxG.switchState(new CustomControlsState());
					#else
					FlxG.state.openSubState(new KeyBindMenu());
					#end
				default:
					// Manejar categorías custom desde scripts
					#if HSCRIPT_ALLOWED
					StateScriptHandler.callOnScripts('onCategorySelected', [curSelected]);
					#end
			}
		}

		if (controls.BACK){
			#if HSCRIPT_ALLOWED
			var cancelled = StateScriptHandler.callOnScriptsReturn('onBack', [], false);
			if (cancelled) {
				FlxG.save.flush();
				return;
			}
			#end
			
			FlxG.sound.play(Paths.sound('cancelMenu'));
			if (!PlayState.isPlaying)
				FlxG.switchState(new MainMenuState());
			else{
				if (PlayState.SONG.song == null)
					PlayState.SONG.song = optionsSong;
				FlxG.switchState(new PlayState());
			}
			OptionsData.initSave();
			isPlayingMusic = false;
		}
		
		#if HSCRIPT_ALLOWED
		StateScriptHandler.callOnScripts('onUpdatePost', [elapsed]);
		#end
		
		FlxG.save.flush();
	}

	function changeSelection(change:Int = 0)
	{
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		curSelected += change;

		if (curSelected < 0)
			curSelected = grpControls.length - 1;
		if (curSelected >= grpControls.length)
			curSelected = 0;

		var bullShit:Int = 0;

		for (item in grpControls.members)
		{
			item.targetY = bullShit - curSelected;
			bullShit++;

			item.alpha = 0.3;

			if (item.targetY == 0)
			{
				item.alpha = 1;
			}
		}
		
		updateCategoryDesc();
		
		#if HSCRIPT_ALLOWED
		StateScriptHandler.callOnScripts('onSelectionChanged', [curSelected]);
		#end
	}
}

/**
 * Graphics Options Menu - Resolution, FPS, Window Mode
 */
class GraphicsOptionsMenu extends MusicBeatState
{
	var curSelected:Int = 0;
	var options:Array<Option> = [];
	private var grpControls:FlxTypedGroup<Alphabet>;
	private var grpValues:FlxTypedGroup<FlxText>;
	
	// Visual info panel
	var infoPanel:FlxSprite;
	var infoText:FlxText;
	var currentSettingsText:FlxText;

	override function create()
	{
		PlayState.isPlaying = false;
		
		// Cargar scripts
		#if HSCRIPT_ALLOWED
		StateScriptHandler.init();
		StateScriptHandler.loadStateScripts('GraphicsOptionsMenu', this);
		StateScriptHandler.callOnScripts('onCreate', []);
		#end
		
		// Background
		var menuBG:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menu/menuDesat'));
		menuBG.color = 0xFF453F3F;
		menuBG.setGraphicSize(Std.int(menuBG.width * 1.1));
		menuBG.updateHitbox();
		menuBG.screenCenter();
		menuBG.antialiasing = FlxG.save.data.antialiasing;
		add(menuBG);

		#if desktop
		DiscordClient.changePresence("Graphics Settings", null);
		
		options = [
			new ResolutionOption(),
			new FPSOption(),
			new WindowModeOption(),
			new AntiAliasingOption(),
			new FullscreenOption()
		];
		#else
		options = [
			new FPSOption(),
			new AntiAliasingOption()
		];
		#end
		
		// Añadir opciones custom desde scripts
		#if HSCRIPT_ALLOWED
		var customOptions = StateScriptHandler.getCustomOptions();
		for (customOpt in customOptions)
		{
			options.push(new ScriptOption(customOpt));
		}
		#end

		// Title
		var titleText:FlxText = new FlxText(0, 20, FlxG.width, "GRAPHICS OPTIONS", 32);
		titleText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		titleText.borderSize = 2;
		add(titleText);

		// Info panel background
		infoPanel = new FlxSprite(0, FlxG.height - 160).makeGraphic(FlxG.width, 160, FlxColor.BLACK);
		infoPanel.alpha = 0.7;
		add(infoPanel);

		// Current settings display
		currentSettingsText = new FlxText(20, FlxG.height - 150, FlxG.width - 40, "", 16);
		currentSettingsText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		add(currentSettingsText);
		
		// Info text
		infoText = new FlxText(20, FlxG.height - 90, FlxG.width - 40, "", 18);
		infoText.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.YELLOW, LEFT, OUTLINE, FlxColor.BLACK);
		infoText.borderSize = 1.5;
		add(infoText);

		grpControls = new FlxTypedGroup<Alphabet>();
		add(grpControls);
		
		grpValues = new FlxTypedGroup<FlxText>();
		add(grpValues);

		for (i in 0...options.length)
		{
			var controlLabel:Alphabet = new Alphabet(0, (70 * i) + 90, options[i].getName(), true, false);
			controlLabel.isMenuItem = true;
			controlLabel.targetY = i;
			controlLabel.alpha = 0.3;
			if(i == curSelected)
				controlLabel.alpha = 1;
			grpControls.add(controlLabel);
			
			// Value display on the right
			var valueText:FlxText = new FlxText(FlxG.width - 400, (70 * i) + 100, 380, options[i].getValue(), 24);
			valueText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.CYAN, RIGHT, OUTLINE, FlxColor.BLACK);
			valueText.borderSize = 1.5;
			valueText.alpha = 0.3;
			if(i == curSelected)
				valueText.alpha = 1;
			grpValues.add(valueText);
		}

		updateInfoPanel();
		updateCurrentSettings();

		#if mobileC
		addVirtualPad(FULL, A_B);
		#end

		super.create();
	}

	function updateInfoPanel():Void
	{
		infoText.text = options[curSelected].getDescription();
	}
	
	function updateCurrentSettings():Void
	{
		var res = OptionsData.getResolutionString();
		var fps = FlxG.drawFramerate;
		var mode = OptionsData.getWindowModeString();
		
		currentSettingsText.text = 'Current: $res @ ${fps}FPS | Mode: $mode';
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		
		#if HSCRIPT_ALLOWED
		StateScriptHandler.callOnScripts('onUpdate', [elapsed]);
		#end

		if (controls.BACK) {
			FlxG.sound.play(Paths.sound('cancelMenu'));
			#if HSCRIPT_ALLOWED
			StateScriptHandler.clearStateScripts();
			#end
			FlxG.switchState(new OptionsMenuState());
		}
		
		if (controls.UP_P)
			changeSelection(-1);
		if (controls.DOWN_P)
			changeSelection(1);

		if (controls.LEFT_P || controls.RIGHT_P)
		{
			var change = controls.LEFT_P ? -1 : 1;
			if (options[curSelected].change(change)) {
				updateValue();
				updateCurrentSettings();
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
				
				#if HSCRIPT_ALLOWED
				StateScriptHandler.callOnScripts('onOptionChanged', [options[curSelected].getName(), options[curSelected].getValue()]);
				#end
			}
		}

		if (controls.ACCEPT)
		{
			if (options[curSelected].press()) {
				updateValue();
				updateCurrentSettings();
				FlxG.sound.play(Paths.sound('confirmMenu'));
				
				#if HSCRIPT_ALLOWED
				StateScriptHandler.callOnScripts('onOptionSelected', [options[curSelected].getName()]);
				#end
			}
		}
		
		#if HSCRIPT_ALLOWED
		StateScriptHandler.callOnScripts('onUpdatePost', [elapsed]);
		#end
		
		FlxG.save.flush();
	}

	function updateValue():Void
	{
		grpValues.members[curSelected].text = options[curSelected].getValue();
	}

	function changeSelection(change:Int = 0)
	{
		FlxG.sound.play(Paths.sound("scrollMenu"), 0.4);

		curSelected += change;

		if (curSelected < 0)
			curSelected = options.length - 1;
		if (curSelected >= options.length)
			curSelected = 0;

		var bullShit:Int = 0;

		for (item in grpControls.members)
		{
			item.targetY = bullShit - curSelected;
			bullShit++;
			item.alpha = 0.3;
			if (item.targetY == 0)
				item.alpha = 1;
		}
		
		bullShit = 0;
		for (item in grpValues.members)
		{
			item.alpha = 0.3;
			if (bullShit == curSelected)
				item.alpha = 1;
			bullShit++;
		}
		
		updateInfoPanel();
	}
}

/**
 * Gameplay Options Menu - Game-specific settings
 */
class GameplayOptionsMenu extends MusicBeatState
{
	var curSelected:Int = 0;
	var options:Array<Option> = [
		new GhostTappingOption(),
		new NoteSplashesOption(),
		new DownscrollOption(),
		new MiddleScroll(),
		new HitSoundsOption(),
		new SickModeOption(),
		new AccuracyOption()
	];

	private var grpControls:FlxTypedGroup<Alphabet>;
	var versionShit:FlxText;
	
	override function create()
	{
		PlayState.isPlaying = false;
		var menuBG:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menu/menuDesat'));

		menuBG.color = 0xFF453F3F;
		menuBG.setGraphicSize(Std.int(menuBG.width * 1.1));
		menuBG.updateHitbox();
		menuBG.screenCenter();
		menuBG.antialiasing = FlxG.save.data.antialiasing;
		add(menuBG);

		grpControls = new FlxTypedGroup<Alphabet>();
		add(grpControls);
		
		#if desktop
		DiscordClient.changePresence("Gameplay Settings", null);
		#end

		// Title
		var titleText:FlxText = new FlxText(0, 20, FlxG.width, "GAMEPLAY OPTIONS", 32);
		titleText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		titleText.borderSize = 2;
		add(titleText);

		for (i in 0...options.length)
		{
			var controlLabel:Alphabet = new Alphabet(0, (70 * i) + 90, options[i].getDisplay(), true, false);
			controlLabel.isMenuItem = true;
			controlLabel.targetY = i;

			controlLabel.alpha = 0.3;
			if(i == curSelected)
				controlLabel.alpha = 1;

			grpControls.add(controlLabel);
		}

		var optionsBG:FlxSprite = new FlxSprite();
		optionsBG.frames = Paths.getSparrowAtlas('menu/menu_options');
	    optionsBG.animation.addByPrefix('idle', 'options basic', 24, false);
	    optionsBG.animation.play('idle');
	    optionsBG.antialiasing = FlxG.save.data.antialiasing;
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
				var ctrl:Alphabet = new Alphabet(0, (70 * curSelected) + 90, options[curSelected].getDisplay(), true, false);
				ctrl.isMenuItem = true;
				grpControls.add(ctrl);
			}
		}
		FlxG.save.flush();
	}

	function changeSelection(change:Int = 0)
	{
		FlxG.sound.play(Paths.sound("scrollMenu"), 0.4);

		curSelected += change;

		if (curSelected < 0)
			curSelected = grpControls.length - 1;
		if (curSelected >= grpControls.length)
			curSelected = 0;

		var bullShit:Int = 0;

		for (item in grpControls.members)
		{
			item.targetY = bullShit - curSelected;
			bullShit++;

			item.alpha = 0.3;

			if (item.targetY == 0)
			{
				item.alpha = 1;
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
		new GPURenderingOption(),
		new QualityLevelOption(),
		new AdaptiveQualityOption(),
		new TextureCacheOption(),
		new ShowStatsOption(),
		new StaticStageOption(),
		new ByeGF(),
		new ByePeople(),
		new EffectsOption()
	];

	private var grpControls:FlxTypedGroup<Alphabet>;
	var versionShit:FlxText;
	
	override function create()
	{
		PlayState.isPlaying = false;
		var menuBG:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menu/menuDesat'));

		menuBG.color = 0xFF453F3F;
		menuBG.setGraphicSize(Std.int(menuBG.width * 1.1));
		menuBG.updateHitbox();
		menuBG.screenCenter();
		menuBG.antialiasing = FlxG.save.data.antialiasing;
		add(menuBG);

		grpControls = new FlxTypedGroup<Alphabet>();
		add(grpControls);
		
		#if desktop
		DiscordClient.changePresence("Optimization Settings", null);
		#end

		// Title
		var titleText:FlxText = new FlxText(0, 20, FlxG.width, "OPTIMIZATION", 32);
		titleText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		titleText.borderSize = 2;
		add(titleText);

		for (i in 0...options.length)
		{
			var controlLabel:Alphabet = new Alphabet(0, (70 * i) + 90, options[i].getDisplay(), true, false);
			controlLabel.isMenuItem = true;
			controlLabel.targetY = i;

			controlLabel.alpha = 0.3;
			if(i == curSelected)
				controlLabel.alpha = 1;

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

		if (controls.BACK)
			FlxG.switchState(new OptionsMenuState());
		if (controls.UP_P)
			changeSelection(-1);
		if (controls.DOWN_P)
			changeSelection(1);

		if (controls.ACCEPT)
		{
			if (options[curSelected].press()) {
				grpControls.remove(grpControls.members[curSelected]);
				var ctrl:Alphabet = new Alphabet(0, (70 * curSelected) + 90, options[curSelected].getDisplay(), true, false);
				ctrl.isMenuItem = true;
				grpControls.add(ctrl);
			}
		}
		FlxG.save.flush();
	}

	function changeSelection(change:Int = 0)
	{
		FlxG.sound.play(Paths.sound("scrollMenu"), 0.4);

		curSelected += change;

		if (curSelected < 0)
			curSelected = grpControls.length - 1;
		if (curSelected >= grpControls.length)
			curSelected = 0;

		var bullShit:Int = 0;

		for (item in grpControls.members)
		{
			item.targetY = bullShit - curSelected;
			bullShit++;

			item.alpha = 0.3;

			if (item.targetY == 0)
			{
				item.alpha = 1;
			}
		}
	}
}

// ========================================
// OPTION BASE CLASS
// ========================================

class Option
{
	public function new()
	{
		display = updateDisplay();
	}

	private var description:String = "";
	private var display:String;
	private var acceptValues:Bool = false;

	public final function getDisplay():String
	{
		return display;
	}

	public final function getAccept():Bool
	{
		return acceptValues;
	}

	public function getDescription():String
	{
		return description;
	}

	public function getName():String
	{
		return display;
	}

	public function getValue():String
	{
		return "";
	}

	public function press():Bool
	{
		return false;
	}
	
	public function change(direction:Int):Bool
	{
		return false;
	}

	private function updateDisplay():String
	{
		return "";
	}
}

// ========================================
// GRAPHICS OPTIONS
// ========================================

class ResolutionOption extends Option
{
	var resolutions:Array<Array<Int>> = [
		[1280, 720],   // 720p
		[1920, 1080],  // 1080p
		[2560, 1440],  // 1440p
		[3840, 2160]   // 4K
	];
	var resNames:Array<String> = ["720p", "1080p", "1440p", "4K"];
	
	public override function getName():String { return "Resolution"; }
	
	public override function getValue():String
	{
		var idx = OptionsData.getCurrentResolutionIndex();
		return resNames[idx];
	}
	
	public override function getDescription():String
	{
		return "Change game resolution. Higher = Better quality but lower FPS.\nRequires restart to apply.";
	}
	
	public override function change(direction:Int):Bool
	{
		var current = OptionsData.getCurrentResolutionIndex();
		current += direction;
		
		if (current < 0) current = resolutions.length - 1;
		if (current >= resolutions.length) current = 0;
		
		FlxG.save.data.resolutionIndex = current;
		
		#if desktop
		// Apply immediately if not fullscreen
		if (!FlxG.fullscreen) {
			FlxG.resizeWindow(resolutions[current][0], resolutions[current][1]);
		}
		#end
		
		return true;
	}
}

class FPSOption extends Option
{
	var fpsOptions:Array<Int> = [60, 120, 144, 240, 999];
	var fpsNames:Array<String> = ["60 FPS", "120 FPS", "144 FPS", "240 FPS", "Unlimited"];
	
	public override function getName():String { return "Frame Rate"; }
	
	public override function getValue():String
	{
		var idx = OptionsData.getCurrentFPSIndex();
		return fpsNames[idx];
	}
	
	public override function getDescription():String
	{
		return "Target frame rate. 60 FPS recommended for best compatibility.\nHigher values = smoother but more CPU usage.";
	}
	
	public override function change(direction:Int):Bool
	{
		var current = OptionsData.getCurrentFPSIndex();
		current += direction;
		
		if (current < 0) current = fpsOptions.length - 1;
		if (current >= fpsOptions.length) current = 0;
		
		FlxG.save.data.fpsIndex = current;
		
		var targetFPS = fpsOptions[current];
		openfl.Lib.current.stage.frameRate = targetFPS;
		FlxG.updateFramerate = targetFPS;
		FlxG.drawFramerate = targetFPS;
		
		return true;
	}
}

class WindowModeOption extends Option
{
	var modes:Array<String> = ["Windowed", "Fullscreen", "Borderless"];
	
	public override function getName():String { return "Window Mode"; }
	
	public override function getValue():String
	{
		return modes[OptionsData.getWindowModeIndex()];
	}
	
	public override function getDescription():String
	{
		return "Window display mode.\nWindowed = Resizable window\nFullscreen = Exclusive fullscreen\nBorderless = Fullscreen window";
	}
	
	public override function change(direction:Int):Bool
	{
		#if desktop
		var current = OptionsData.getWindowModeIndex();
		current += direction;
		
		if (current < 0) current = modes.length - 1;
		if (current >= modes.length) current = 0;
		
		FlxG.save.data.windowMode = current;
		
		switch(current) {
			case 0: // Windowed
				FlxG.fullscreen = false;
			case 1: // Fullscreen
				FlxG.fullscreen = true;
			case 2: // Borderless
				FlxG.fullscreen = true;
				// Would need native extension for true borderless
		}
		
		return true;
		#else
		return false;
		#end
	}
}

class AntiAliasingOption extends Option
{
	public override function getName():String { return "Anti-Aliasing"; }
	
	public override function getValue():String
	{
		return FlxG.save.data.antialiasing ? "ON" : "OFF";
	}
	
	public override function getDescription():String
	{
		return "Smooth sprite edges. ON = Better quality, OFF = Better performance.";
	}
	
	public override function press():Bool
	{
		FlxG.save.data.antialiasing = !FlxG.save.data.antialiasing;
		return true;
	}
}

class FullscreenOption extends Option
{
	public override function press():Bool
	{
		#if desktop
		FlxG.fullscreen = !FlxG.fullscreen;
		display = updateDisplay();
		#end
		return true;
	}

	private override function updateDisplay():String
	{
		return !FlxG.fullscreen ? "Fullscreen Off" : "Fullscreen On";
	}
	
	public override function getDescription():String
	{
		return "Toggle fullscreen mode. Also accessible with F11.";
	}
}

// ========================================
// OPTIMIZATION OPTIONS
// ========================================

class GPURenderingOption extends Option
{
	public override function press():Bool
	{
		FlxG.save.data.gpuRendering = !FlxG.save.data.gpuRendering;
		display = updateDisplay();
		return true;
	}

	private override function updateDisplay():String
	{
		return FlxG.save.data.gpuRendering ? "GPU Rendering: ON" : "GPU Rendering: OFF";
	}
}

class QualityLevelOption extends Option
{
	var qualityLevels:Array<String> = ["LOW", "MEDIUM", "HIGH", "ULTRA"];
	
	public override function getName():String { return "Quality Level"; }
	
	public override function getValue():String
	{
		if (FlxG.save.data.qualityLevel == null) FlxG.save.data.qualityLevel = 2;
		return qualityLevels[FlxG.save.data.qualityLevel];
	}
	
	public override function change(direction:Int):Bool
	{
		if (FlxG.save.data.qualityLevel == null) FlxG.save.data.qualityLevel = 2;
		
		FlxG.save.data.qualityLevel += direction;
		
		if (FlxG.save.data.qualityLevel < 0) 
			FlxG.save.data.qualityLevel = qualityLevels.length - 1;
		if (FlxG.save.data.qualityLevel >= qualityLevels.length) 
			FlxG.save.data.qualityLevel = 0;
		
		return true;
	}
	
	private override function updateDisplay():String
	{
		return "Quality: " + getValue();
	}
}

class AdaptiveQualityOption extends Option
{
	public override function press():Bool
	{
		FlxG.save.data.adaptiveQuality = !FlxG.save.data.adaptiveQuality;
		display = updateDisplay();
		return true;
	}

	private override function updateDisplay():String
	{
		return FlxG.save.data.adaptiveQuality ? "Adaptive Quality: ON" : "Adaptive Quality: OFF";
	}
}

class TextureCacheOption extends Option
{
	public override function press():Bool
	{
		FlxG.save.data.textureCache = !FlxG.save.data.textureCache;
		Paths.setCacheEnabled(FlxG.save.data.textureCache);
		display = updateDisplay();
		return true;
	}

	private override function updateDisplay():String
	{
		return FlxG.save.data.textureCache ? "Texture Cache: ON" : "Texture Cache: OFF";
	}
}

class ShowStatsOption extends Option
{
	public override function press():Bool
	{
		FlxG.save.data.showStats = !FlxG.save.data.showStats;
		display = updateDisplay();
		return true;
	}

	private override function updateDisplay():String
	{
		return FlxG.save.data.showStats ? "Show Stats: ON" : "Show Stats: OFF";
	}
}

// ========================================
// STAGE/VISUAL OPTIONS
// ========================================

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

// ========================================
// GAMEPLAY OPTIONS
// ========================================

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

class GhostTappingOption extends Option{
	public override function press():Bool
		{
			FlxG.save.data.ghosttap = !FlxG.save.data.ghosttap;
			display = updateDisplay();
			return true;
		}
	
	private override function updateDisplay():String
	{
		return FlxG.save.data.ghosttap ? "Ghost Tapping: ON" : "Ghost Tapping: Off";
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

// ========================================
// SCRIPT OPTION - Wrapper para opciones de scripts
// ========================================

class ScriptOption extends Option
{
	var scriptData:Dynamic;
	
	public function new(scriptData:Dynamic)
	{
		this.scriptData = scriptData;
		super();
	}
	
	public override function getName():String 
	{ 
		if (scriptData.name != null)
			return scriptData.name;
		return "Script Option";
	}
	
	public override function getValue():String
	{
		if (scriptData.getValue != null && Reflect.isFunction(scriptData.getValue))
		{
			try {
				return Reflect.callMethod(null, scriptData.getValue, []);
			} catch (e:Dynamic) {
				trace('[ScriptOption] Error in getValue: $e');
			}
		}
		return "";
	}
	
	public override function getDescription():String
	{
		if (scriptData.description != null)
			return scriptData.description;
		return "Custom option from script";
	}
	
	public override function press():Bool
	{
		if (scriptData.onPress != null && Reflect.isFunction(scriptData.onPress))
		{
			try {
				var result = Reflect.callMethod(null, scriptData.onPress, []);
				return result == true;
			} catch (e:Dynamic) {
				trace('[ScriptOption] Error in onPress: $e');
			}
		}
		return false;
	}
	
	public override function change(direction:Int):Bool
	{
		if (scriptData.onChange != null && Reflect.isFunction(scriptData.onChange))
		{
			try {
				var result = Reflect.callMethod(null, scriptData.onChange, [direction]);
				return result == true;
			} catch (e:Dynamic) {
				trace('[ScriptOption] Error in onChange: $e');
			}
		}
		return false;
	}
}

// ========================================
// OPTIONS DATA HELPER
// ========================================

class OptionsData
{	
	public static function getResolutionString():String
	{
		var resolutions:Array<String> = ["1280x720", "1920x1080", "2560x1440", "3840x2160"];
		var idx = getCurrentResolutionIndex();
		return resolutions[idx];
	}
	
	public static function getCurrentResolutionIndex():Int
	{
		if (FlxG.save.data.resolutionIndex == null)
			FlxG.save.data.resolutionIndex = 1; // Default to 1080p
		return FlxG.save.data.resolutionIndex;
	}
	
	public static function getCurrentFPSIndex():Int
	{
		if (FlxG.save.data.fpsIndex == null)
			FlxG.save.data.fpsIndex = 0; // Default to 60 FPS
		return FlxG.save.data.fpsIndex;
	}
	
	public static function getWindowModeIndex():Int
	{
		if (FlxG.save.data.windowMode == null)
			FlxG.save.data.windowMode = 0; // Default to windowed
		return FlxG.save.data.windowMode;
	}
	
	public static function getWindowModeString():String
	{
		var modes:Array<String> = ["Windowed", "Fullscreen", "Borderless"];
		return modes[getWindowModeIndex()];
	}

	public static function initSave()
	{
		if (FlxG.save.data.downscroll == null)
			FlxG.save.data.downscroll = false;

		if (FlxG.save.data.accuracyDisplay == null)
			FlxG.save.data.accuracyDisplay = true;

		if (FlxG.save.data.notesplashes == null)
			FlxG.save.data.notesplashes = true;

		if (FlxG.save.data.middlescroll == null)
			FlxG.save.data.middlescroll = false;

		if(FlxG.save.data.HUD == null)
			FlxG.save.data.HUD = false;

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

		if (FlxG.save.data.ghosttap == null)
    		FlxG.save.data.ghosttap = false;

		if(FlxG.save.data.hitsounds == null)
			FlxG.save.data.hitsounds = false;
		
		if(FlxG.save.data.antialiasing == null)
			FlxG.save.data.antialiasing = true;
		
		// GPU OPTIMIZATION SETTINGS
		if (FlxG.save.data.gpuRendering == null)
			FlxG.save.data.gpuRendering = true;
		
		if (FlxG.save.data.qualityLevel == null)
			FlxG.save.data.qualityLevel = 2; // HIGH by default
		
		if (FlxG.save.data.adaptiveQuality == null)
			FlxG.save.data.adaptiveQuality = true;
		
		if (FlxG.save.data.textureCache == null)
			FlxG.save.data.textureCache = true;
		
		if (FlxG.save.data.showStats == null)
			FlxG.save.data.showStats = false;
		
		// GRAPHICS SETTINGS
		if (FlxG.save.data.resolutionIndex == null)
			FlxG.save.data.resolutionIndex = 1; // 1080p default
		
		if (FlxG.save.data.fpsIndex == null)
			FlxG.save.data.fpsIndex = 0; // 60 FPS default
		
		if (FlxG.save.data.windowMode == null)
			FlxG.save.data.windowMode = 0; // Windowed default

		Paths.setCacheEnabled(FlxG.save.data.textureCache);
		
		// Apply FPS setting
		var fpsOptions:Array<Int> = [60, 120, 144, 240, 999];
		var targetFPS = fpsOptions[getCurrentFPSIndex()];
		openfl.Lib.current.stage.frameRate = targetFPS;
		FlxG.updateFramerate = targetFPS;
		FlxG.drawFramerate = targetFPS;
	}
}
