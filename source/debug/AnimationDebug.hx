package debug;

import flixel.math.FlxMath;
import objects.character.Character.AnimData;
import objects.character.Character.CharacterData;
import states.MusicBeatState;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.FlxCamera;
import flixel.addons.display.FlxGridOverlay;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.addons.ui.FlxInputText;
import flixel.addons.ui.FlxUI9SliceSprite;
import flixel.addons.ui.FlxUI;
import flixel.addons.ui.FlxUIGroup;
import flixel.addons.ui.FlxUICheckBox;
import flixel.addons.ui.FlxUIDropDownMenu;
import flixel.addons.ui.FlxUIInputText;
import flixel.addons.ui.FlxUINumericStepper;
import flixel.addons.ui.FlxUITabMenu;
import flixel.addons.ui.FlxUITooltip.FlxUITooltipStyle;
import openfl.net.FileReference;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.ui.FlxButton;
import flixel.ui.FlxSpriteButton;
import objects.character.Character;
import haxe.Json;
import lime.utils.Assets;
import states.MainMenuState;
import HealthIcon;

// Import Adobe Animate utilities
import animationdata.AdobeAnimateAtlasParser;
import animationdata.AdobeAnimateAnimationParser;
import animationdata.AdobeAnimateValidator;

#if sys
import sys.FileSystem;
import sys.io.File;
import lime.ui.FileDialog;
#end

using StringTools;

class AnimationDebug extends MusicBeatState
{
	var UI_box:FlxUITabMenu;
	
	var char:Character;
	var textAnim:FlxText;
	var textInfo:FlxText;
	var textControls:FlxText;
	var textHelp:FlxText;
	var dumbTexts:FlxTypedGroup<FlxText>;
	var layeringbullshit:FlxTypedGroup<FlxSprite>;
	var animList:Array<String> = [];
	var curAnim:Int = 0;
	var daAnim:String = 'bf';
	var camFollow:FlxObject;
	var camHUD:FlxCamera;
	var camGame:FlxCamera;
	var _file:FileReference;
	var ghostChar:Character;

	// UI Elements
	var playerCheckbox:FlxUICheckBox;
	var antialiasingCheckbox:FlxUICheckBox;
	var scaleStepper:FlxUINumericStepper;
	var pathInput:FlxUIInputText;
	var animNameInput:FlxUIInputText;
	var animPrefixInput:FlxUIInputText;
	var animFramerateStepper:FlxUINumericStepper;
	var animLoopedCheckbox:FlxUICheckBox;
	var animSpecialCheckbox:FlxUICheckBox;
	var offsetXStepper:FlxUINumericStepper;
	var offsetYStepper:FlxUINumericStepper;
	var isTxtCheckbox:FlxUICheckBox;
	var isSpritesheetCheckbox:FlxUICheckBox;
	var isAdobeAnimateCheckbox:FlxUICheckBox; // NEW
	var healthIconInput:FlxUIInputText;
	var healthBarColorInput:FlxUIInputText;
	var animFileInput:FlxUIInputText; // NEW: for Animation.json path
	
	var velocityPlus:Float = 1;
	var gridBG:FlxSprite;
	var showGrid:Bool = true;
	
	// Character data for JSON export
	var characterData:CharacterData;
	var currentAnimData:Array<AnimData> = [];
	
	// Icon preview
	var iconPreview:HealthIcon;
	var iconBG:FlxSprite;
	
	// Import tracking
	var importedFiles:Map<String, String> = new Map();
	
	// Adobe Animate tracking
	var adobeAtlasPath:String = "";
	var adobeAnimPath:String = "";

	public function new(daAnim:String = 'bf')
	{
		super();
		this.daAnim = daAnim;
	}

	override function create()
	{
		FlxG.mouse.visible = true;
		states.FreeplayState.destroyFreeplayVocals();
		FlxG.sound.playMusic(Paths.music('configurator'));

		MainMenuState.musicFreakyisPlaying = false;

		camGame = new FlxCamera();
		camHUD = new FlxCamera();
		camHUD.bgColor.alpha = 0;

		FlxG.cameras.reset(camGame);
		FlxG.cameras.add(camHUD, false);

		// Background grid
		gridBG = FlxGridOverlay.create(50, 50, -1, -1, true, 0x33FFFFFF, 0x33000000);
		gridBG.scrollFactor.set(0.5, 0.5);
		add(gridBG);

		layeringbullshit = new FlxTypedGroup<FlxSprite>();
		add(layeringbullshit);

		// UI Setup
		setupUI();

		// Text displays
		dumbTexts = new FlxTypedGroup<FlxText>();
		dumbTexts.cameras = [camHUD];
		add(dumbTexts);

		// Controls text
		textControls = new FlxText(10, 10, FlxG.width - 20, '', 12);
		textControls.text = "CONTROLS:\n" +
			"W/S - Switch Animation | ARROWS - Adjust Offset (SHIFT = x10)\n" +
			"I/K - Camera Up/Down | J/L - Camera Left/Right\n" +
			"Q/E - Zoom Out/In | SPACE - Play Anim | ESC - Exit\n" +
			"G - Toggle Grid | R - Reset Camera | T - Toggle Ghost";
		textControls.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 2);
		textControls.color = FlxColor.WHITE;
		textControls.cameras = [camHUD];
		textControls.scrollFactor.set();
		add(textControls);

		// Current animation display
		textAnim = new FlxText(10, 120, 0, '', 20);
		textAnim.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 2);
		textAnim.color = FlxColor.CYAN;
		textAnim.cameras = [camHUD];
		textAnim.scrollFactor.set();
		add(textAnim);

		// Info display
		textInfo = new FlxText(10, 150, 0, '', 14);
		textInfo.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 2);
		textInfo.color = FlxColor.YELLOW;
		textInfo.cameras = [camHUD];
		textInfo.scrollFactor.set();
		add(textInfo);

		// Help text
		textHelp = new FlxText(10, FlxG.height - 60, FlxG.width - 20, '', 12);
		textHelp.text = "TIP: Use the UI tabs to edit character properties and create new animations!";
		textHelp.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 2);
		textHelp.color = FlxColor.LIME;
		textHelp.cameras = [camHUD];
		textHelp.scrollFactor.set();
		textHelp.alignment = CENTER;
		add(textHelp);

		// Icon preview setup
		iconBG = new FlxSprite(FlxG.width - 200, FlxG.height - 200);
		iconBG.makeGraphic(170, 170, 0xFF000000);
		iconBG.cameras = [camHUD];
		add(iconBG);

		iconPreview = new HealthIcon('bf', false);
		iconPreview.setPosition(FlxG.width - 185, FlxG.height - 185);
		iconPreview.cameras = [camHUD];
		iconPreview.scale.set(0.8, 0.8);
		add(iconPreview);

		var iconLabel = new FlxText(FlxG.width - 200, FlxG.height - 220, 170, "ICON PREVIEW", 12);
		iconLabel.alignment = CENTER;
		iconLabel.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 2);
		iconLabel.cameras = [camHUD];
		add(iconLabel);

		camFollow = new FlxObject(0, 0, 2, 2);
		camFollow.screenCenter();
		add(camFollow);
		camGame.follow(camFollow);

		displayCharacter(daAnim);
		loadCharacterData();

		super.create();
	}

	function setupUI():Void
	{
		var tabs = [
			{name: "Character", label: "Character"},
			{name: "Animation", label: "Animation"},
			{name: "Properties", label: "Properties"},
			{name: "Import", label: "Import Assets"},
			{name: "Export", label: "Export"}
		];

		UI_box = new FlxUITabMenu(null, tabs, true);
		UI_box.cameras = [camHUD];
		UI_box.resize(320, 450);
		UI_box.x = FlxG.width - UI_box.width - 10;
		UI_box.y = 10;
		add(UI_box);

		addCharacterTab();
		addAnimationTab();
		addPropertiesTab();
		addImportTab();
		addExportTab();
	}

	function addCharacterTab():Void
	{
		var tab = new FlxUI(null, UI_box);
		tab.name = "Character";

		var characters:Array<String> = CoolUtil.coolTextFile('assets/characters/characterList.txt');

		var label = new FlxText(10, 10, 0, "Select Character:", 12);
		tab.add(label);

		var charDropdown = new FlxUIDropDownMenu(10, 30, FlxUIDropDownMenu.makeStrIdLabelArray(characters, true), function(character:String)
		{
			daAnim = characters[Std.parseInt(character)];
			displayCharacter(daAnim);
			loadCharacterData();
		});
		charDropdown.selectedLabel = daAnim;

		playerCheckbox = new FlxUICheckBox(10, 70, null, null, "Player Character (FlipX)", 180);
		playerCheckbox.checked = false;
		playerCheckbox.callback = function()
		{
			if (char != null)
				char.flipX = playerCheckbox.checked;
		};
		tab.add(playerCheckbox);

		var refreshBtn = new FlxButton(10, 110, "Refresh Character", function()
		{
			displayCharacter(daAnim);
			loadCharacterData();
		});
		tab.add(refreshBtn);

		var resetCamBtn = new FlxButton(10, 140, "Reset Camera", function()
		{
			camFollow.setPosition(FlxG.width / 2, FlxG.height / 2);
			camGame.zoom = 1;
		});
		tab.add(resetCamBtn);

		var toggleGridBtn = new FlxButton(10, 170, "Toggle Grid", function()
		{
			showGrid = !showGrid;
			gridBG.visible = showGrid;
		});
		tab.add(toggleGridBtn);

		tab.add(charDropdown);

		UI_box.addGroup(tab);
	}

	function addAnimationTab():Void
	{
		var tab = new FlxUI(null, UI_box);
		tab.name = "Animation";

		var yPos = 10;

		var titleLabel = new FlxText(10, yPos, 0, "Add/Edit Animation", 14);
		titleLabel.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 1);
		tab.add(titleLabel);
		yPos += 25;

		// Animation name
		var nameLabel = new FlxText(10, yPos, 0, "Name:", 10);
		tab.add(nameLabel);
		yPos += 15;
		animNameInput = new FlxUIInputText(10, yPos, 200, '', 8);
		tab.add(animNameInput);
		yPos += 25;

		// Animation prefix
		var prefixLabel = new FlxText(10, yPos, 0, "Prefix:", 10);
		tab.add(prefixLabel);
		yPos += 15;
		animPrefixInput = new FlxUIInputText(10, yPos, 200, '', 8);
		tab.add(animPrefixInput);
		yPos += 25;

		// Framerate
		var framerateLabel = new FlxText(10, yPos, 0, "Framerate:", 10);
		tab.add(framerateLabel);
		yPos += 15;
		animFramerateStepper = new FlxUINumericStepper(10, yPos, 1, 24, 1, 60, 0);
		tab.add(animFramerateStepper);
		yPos += 25;

		// Looped checkbox
		animLoopedCheckbox = new FlxUICheckBox(10, yPos, null, null, "Looped", 100);
		animLoopedCheckbox.checked = false;
		tab.add(animLoopedCheckbox);
		yPos += 20;

		// Special anim checkbox
		animSpecialCheckbox = new FlxUICheckBox(10, yPos, null, null, "Special Anim", 100);
		animSpecialCheckbox.checked = false;
		tab.add(animSpecialCheckbox);
		yPos += 25;

		// Offset X
		var offsetXLabel = new FlxText(10, yPos, 0, "Offset X:", 10);
		tab.add(offsetXLabel);
		yPos += 15;
		offsetXStepper = new FlxUINumericStepper(10, yPos, 1, 0, -500, 500, 0);
		tab.add(offsetXStepper);
		yPos += 25;

		// Offset Y
		var offsetYLabel = new FlxText(10, yPos, 0, "Offset Y:", 10);
		tab.add(offsetYLabel);
		yPos += 15;
		offsetYStepper = new FlxUINumericStepper(10, yPos, 1, 0, -500, 500, 0);
		tab.add(offsetYStepper);
		yPos += 30;

		// Add animation button
		var addAnimBtn = new FlxButton(10, yPos, "Add Animation", function()
		{
			addNewAnimation();
		});
		tab.add(addAnimBtn);
		yPos += 30;

		// Delete animation button
		var deleteAnimBtn = new FlxButton(10, yPos, "Delete Current", function()
		{
			deleteCurrentAnimation();
		});
		tab.add(deleteAnimBtn);

		UI_box.addGroup(tab);
	}

	function addPropertiesTab():Void
	{
		var tab = new FlxUI(null, UI_box);
		tab.name = "Properties";

		var yPos = 10;

		var titleLabel = new FlxText(10, yPos, 0, "Character Properties", 14);
		titleLabel.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 1);
		tab.add(titleLabel);
		yPos += 25;

		// Path
		var pathLabel = new FlxText(10, yPos, 0, "Sprite Path:", 10);
		tab.add(pathLabel);
		yPos += 15;
		pathInput = new FlxUIInputText(10, yPos, 200, 'BOYFRIEND', 8);
		tab.add(pathInput);
		yPos += 25;

		// Animation File (for Adobe Animate)
		var animFileLabel = new FlxText(10, yPos, 0, "Animation File:", 10);
		tab.add(animFileLabel);
		yPos += 15;
		animFileInput = new FlxUIInputText(10, yPos, 200, '', 8);
		animFileInput.color = FlxColor.BLACK;
		var animFileHint = new FlxText(215, yPos + 3, 0, "Adobe Animate only", 8);
		animFileHint.color = FlxColor.BLACK;
		tab.add(animFileInput);
		tab.add(animFileHint);
		yPos += 25;

		// Health Icon
		var iconLabel = new FlxText(10, yPos, 0, "Health Icon:", 10);
		tab.add(iconLabel);
		yPos += 15;
		healthIconInput = new FlxUIInputText(10, yPos, 200, 'bf', 8);
		healthIconInput.callback = function(text:String, action:String)
		{
			updateIconPreview(text);
		};
		tab.add(healthIconInput);
		yPos += 25;

		// Health Bar Color
		var colorLabel = new FlxText(10, yPos, 0, "Health Bar Color:", 10);
		tab.add(colorLabel);
		yPos += 15;
		healthBarColorInput = new FlxUIInputText(10, yPos, 200, '#31B0D1', 8);
		tab.add(healthBarColorInput);
		yPos += 25;

		// Scale
		var scaleLabel = new FlxText(10, yPos, 0, "Scale:", 10);
		tab.add(scaleLabel);
		yPos += 15;
		scaleStepper = new FlxUINumericStepper(10, yPos, 0.1, 1.0, 0.1, 10.0, 1);
		scaleStepper.value = 1.0;
		tab.add(scaleStepper);
		yPos += 30;

		// Antialiasing
		antialiasingCheckbox = new FlxUICheckBox(10, yPos, null, null, "Antialiasing", 100);
		antialiasingCheckbox.checked = true;
		tab.add(antialiasingCheckbox);
		yPos += 25;

		// Is TXT format
		isTxtCheckbox = new FlxUICheckBox(10, yPos, null, null, "TXT Spritesheet", 150);
		isTxtCheckbox.checked = false;
		isTxtCheckbox.callback = function() {
			if (isTxtCheckbox.checked) {
				isSpritesheetCheckbox.checked = false;
				isAdobeAnimateCheckbox.checked = false;
			}
		};
		tab.add(isTxtCheckbox);
		yPos += 20;

		// Is Spritesheet JSON format
		isSpritesheetCheckbox = new FlxUICheckBox(10, yPos, null, null, "Spritesheet JSON", 150);
		isSpritesheetCheckbox.checked = false;
		isSpritesheetCheckbox.callback = function() {
			if (isSpritesheetCheckbox.checked) {
				isTxtCheckbox.checked = false;
				isAdobeAnimateCheckbox.checked = false;
			}
		};
		tab.add(isSpritesheetCheckbox);
		yPos += 20;

		// Is Adobe Animate format (NEW)
		isAdobeAnimateCheckbox = new FlxUICheckBox(10, yPos, null, null, "Adobe Animate", 150);
		isAdobeAnimateCheckbox.checked = false;
		isAdobeAnimateCheckbox.callback = function() {
			if (isAdobeAnimateCheckbox.checked) {
				isTxtCheckbox.checked = false;
				isSpritesheetCheckbox.checked = false;
				animFileInput.color = FlxColor.BLACK;
			} else {
				animFileInput.color = FlxColor.GRAY;
			}
		};
		tab.add(isAdobeAnimateCheckbox);
		yPos += 30;

		// Apply button
		var applyBtn = new FlxButton(10, yPos, "Apply Properties", function()
		{
			if (char != null)
			{
				char.antialiasing = antialiasingCheckbox.checked;
				char.scale.set(scaleStepper.value, scaleStepper.value);
				char.updateHitbox();
				updateIconPreview(healthIconInput.text);
				FlxG.log.notice("Properties applied!");
			}
		});
		tab.add(applyBtn);

		UI_box.addGroup(tab);
	}

	function addImportTab():Void
	{
		var tab = new FlxUI(null, UI_box);
		tab.name = "Import";

		var yPos = 10;

		var titleLabel = new FlxText(10, yPos, 0, "Import Assets", 14);
		titleLabel.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 1);
		tab.add(titleLabel);
		yPos += 25;

		var infoText = new FlxText(10, yPos, 280, "Import files from any directory. They will be copied to assets/characters/images/", 10);
		infoText.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 1);
		tab.add(infoText);
		yPos += 50;

		// Standard sprite import section
		var standardLabel = new FlxText(10, yPos, 0, "Standard Sprite:", 12);
		standardLabel.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 1);
		standardLabel.color = FlxColor.CYAN;
		tab.add(standardLabel);
		yPos += 20;

		// Import PNG button (auto-detects XML/TXT)
		var importSpriteBtn = new FlxButton(10, yPos, "Import Sprite PNG", function()
		{
			browseForFile("sprite");
		});
		tab.add(importSpriteBtn);
		
		var spriteHint = new FlxText(10, yPos + 22, 280, "Auto-detects XML/TXT with same name", 8);
		spriteHint.color = FlxColor.BLACK;
		tab.add(spriteHint);
		yPos += 50;

		// Adobe Animate section (NEW)
		var adobeLabel = new FlxText(10, yPos, 0, "Adobe Animate:", 12);
		adobeLabel.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 1);
		adobeLabel.color = FlxColor.ORANGE;
		tab.add(adobeLabel);
		yPos += 20;

		var adobeInfo = new FlxText(10, yPos, 280, "Import PNG + Atlas JSON + Animation JSON", 9);
		tab.add(adobeInfo);
		yPos += 18;

		// Import Adobe Animate button
		var importAdobeBtn = new FlxButton(10, yPos, "Import Adobe Animate", function()
		{
			browseForAdobeAnimate();
		});
		tab.add(importAdobeBtn);
		
		var adobeHint = new FlxText(10, yPos + 22, 280, "Select atlas PNG (auto-detects JSONs)", 8);
		adobeHint.color = FlxColor.BLACK;
		tab.add(adobeHint);
		yPos += 50;

		// Validate Adobe Animate files button
		var validateBtn = new FlxButton(10, yPos, "Validate Adobe Files", function()
		{
			validateAdobeAnimateFiles();
		});
		tab.add(validateBtn);
		yPos += 35;

		// Icon import section
		var iconTitle = new FlxText(10, yPos, 0, "Health Icon:", 12);
		iconTitle.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 1);
		iconTitle.color = FlxColor.LIME;
		tab.add(iconTitle);
		yPos += 20;

		var importIconBtn = new FlxButton(10, yPos, "Import Icon PNG", function()
		{
			browseForFile("icon");
		});
		tab.add(importIconBtn);
		yPos += 25;

		var iconInfoText = new FlxText(10, yPos, 280, "Icon should be 300x150px (2 frames of 150x150)", 9);
		iconInfoText.color = FlxColor.BLACK;
		tab.add(iconInfoText);

		UI_box.addGroup(tab);
	}

	function addExportTab():Void
	{
		var tab = new FlxUI(null, UI_box);
		tab.name = "Export";

		var yPos = 10;

		var titleLabel = new FlxText(10, yPos, 0, "Export Character", 14);
		titleLabel.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 1);
		tab.add(titleLabel);
		yPos += 30;

		// Export JSON button
		var exportJsonBtn = new FlxButton(10, yPos, "Export JSON", function()
		{
			exportCharacterJSON();
		});
		tab.add(exportJsonBtn);
		yPos += 35;

		// Export Offsets TXT button
		var exportTxtBtn = new FlxButton(10, yPos, "Export Offsets TXT", function()
		{
			exportOffsetsTXT();
		});
		tab.add(exportTxtBtn);
		yPos += 35;

		// Copy JSON to clipboard button
		var copyJsonBtn = new FlxButton(10, yPos, "Copy JSON", function()
		{
			copyJSONToClipboard();
		});
		tab.add(copyJsonBtn);
		yPos += 40;

		var infoText = new FlxText(10, yPos, 280, "Export JSON: Save complete character data\nOffsets TXT: Export animation offsets only\nCopy JSON: Copy to clipboard", 10);
		infoText.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 1);
		tab.add(infoText);

		UI_box.addGroup(tab);
	}

	function addNewAnimation():Void
	{
		if (animNameInput.text == "" || animPrefixInput.text == "")
		{
			if (textHelp != null)
			{
				textHelp.text = "✗ Animation name and prefix are required!";
				textHelp.color = FlxColor.RED;
			}
			return;
		}

		var newAnim:AnimData = {
			name: animNameInput.text,
			prefix: animPrefixInput.text,
			framerate: animFramerateStepper.value,
			looped: animLoopedCheckbox.checked,
			offsetX: offsetXStepper.value,
			offsetY: offsetYStepper.value
		};

		if (animSpecialCheckbox.checked)
			newAnim.specialAnim = true;

		// Check if animation already exists
		var exists = false;
		for (i in 0...currentAnimData.length)
		{
			if (currentAnimData[i].name == newAnim.name)
			{
				currentAnimData[i] = newAnim;
				exists = true;
				break;
			}
		}

		if (!exists)
			currentAnimData.push(newAnim);

		// Reload character with new animation
		reloadCharacterWithNewAnims();

		if (textHelp != null)
		{
			textHelp.text = exists ? "✓ Animation updated!" : "✓ Animation added!";
			textHelp.color = FlxColor.LIME;
		}

		// Clear inputs
		animNameInput.text = "";
		animPrefixInput.text = "";
	}

	function deleteCurrentAnimation():Void
	{
		if (animList.length > 0 && curAnim >= 0 && curAnim < animList.length)
		{
			var animName = animList[curAnim];
			
			// Remove from current anim data
			for (i in 0...currentAnimData.length)
			{
				if (currentAnimData[i].name == animName)
				{
					currentAnimData.splice(i, 1);
					break;
				}
			}

			// Reload character
			reloadCharacterWithNewAnims();

			if (textHelp != null)
			{
				textHelp.text = "✓ Animation deleted: " + animName;
				textHelp.color = FlxColor.LIME;
			}

			// Adjust current animation index
			if (curAnim >= animList.length)
				curAnim = animList.length - 1;
			if (curAnim < 0)
				curAnim = 0;
		}
	}

	/**
	 * NEW: Browse for Adobe Animate files
	 */
	function browseForAdobeAnimate():Void
	{
		#if sys
		var fileDialog = new FileDialog();
		fileDialog.onSelect.add(function(path:String) {
			onAdobeAnimateSelected(path);
		});
		fileDialog.browse(OPEN, "png", null, "Select Adobe Animate PNG");
		#else
		FlxG.log.warn("File import only available on desktop platforms");
		#end
	}

	/**
	 * NEW: Handle Adobe Animate file selection
	 */
	function onAdobeAnimateSelected(sourcePath:String):Void
	{
		#if sys
		try
		{
			var fileName = haxe.io.Path.withoutDirectory(sourcePath);
			var sourceDir = haxe.io.Path.directory(sourcePath) + "/";
			var baseName = haxe.io.Path.withoutExtension(fileName);
			
			trace("Selected: " + fileName);
			trace("Source directory: " + sourceDir);
			trace("Base name: " + baseName);
			
			// Look for associated JSON files
			var atlasJsonPath = sourceDir + baseName + ".json";
			var animJsonPath = sourceDir + "Animation.json";
			
			var hasAtlasJson = FileSystem.exists(atlasJsonPath);
			var hasAnimJson = FileSystem.exists(animJsonPath);
			
			trace("Atlas JSON exists: " + hasAtlasJson + " (" + atlasJsonPath + ")");
			trace("Animation JSON exists: " + hasAnimJson + " (" + animJsonPath + ")");
			
			if (!hasAtlasJson)
			{
				FlxG.log.warn("Atlas JSON not found: " + baseName + ".json");
				if (textHelp != null)
				{
					textHelp.text = "✗ Atlas JSON not found! Need " + baseName + ".json";
					textHelp.color = FlxColor.RED;
				}
				return;
			}
			
			if (!hasAnimJson)
			{
				FlxG.log.warn("Animation JSON not found: Animation.json");
				if (textHelp != null)
				{
					textHelp.text = "⚠ Animation.json not found in same directory";
					textHelp.color = FlxColor.ORANGE;
				}
			}
			
			// Create destination directory
			var destDir = 'assets/characters/images/$daAnim/';
			if (!FileSystem.exists(destDir))
				FileSystem.createDirectory(destDir);
			
			// Copy PNG
			var destPng = destDir + fileName;
			File.copy(sourcePath, destPng);
			FlxG.log.notice("Copied: " + fileName);
			
			// Copy Atlas JSON
			var destAtlasJson = destDir + baseName + ".json";
			File.copy(atlasJsonPath, destAtlasJson);
			FlxG.log.notice("Copied: " + baseName + ".json");
			
			adobeAtlasPath = 'spritemap1';
			
			// Copy Animation JSON if it exists
			if (hasAnimJson)
			{
				var destAnimJson = destDir + "Animation.json";
				File.copy(animJsonPath, destAnimJson);
				FlxG.log.notice("Copied: Animation.json");
				
				adobeAnimPath = 'Animation';
			}
			
			// Update UI
			pathInput.text = adobeAtlasPath;
			if (hasAnimJson)
				animFileInput.text = adobeAnimPath;
			isAdobeAnimateCheckbox.checked = true;
			animFileInput.color = FlxColor.BLACK;
			
			// Load animations from Adobe Animate
			loadFromAdobeAnimate();
			
			if (textHelp != null)
			{
				var msg = "✓ Adobe Animate files imported!";
				if (!hasAnimJson)
					msg += " (No Animation.json)";
				textHelp.text = msg;
				textHelp.color = FlxColor.LIME;
			}
		}
		catch (err:Dynamic)
		{
			FlxG.log.error("Error importing Adobe Animate: " + err);
			if (textHelp != null)
			{
				textHelp.text = "✗ Error: " + err;
				textHelp.color = FlxColor.RED;
			}
		}
		#end
	}

	/**
	 * NEW: Load animations from Adobe Animate files
	 */
	function loadFromAdobeAnimate():Void
	{
		#if sys
		if (adobeAtlasPath == "")
		{
			FlxG.log.warn("No Adobe Animate atlas path set!");
			return;
		}
		
		try
		{
			var atlasJsonPath = "assets/" + adobeAtlasPath + ".json";
			
			// Check if Animation.json exists
			var hasAnimations = false;
			if (adobeAnimPath != "")
			{
				var animJsonPath = "assets/" + adobeAnimPath + ".json";
				if (FileSystem.exists(animJsonPath))
				{
					hasAnimations = true;
					
					// Parse animations using AdobeAnimateAnimationParser
					var animations = AdobeAnimateAnimationParser.parse(animJsonPath);
					
					// Clear current animations
					currentAnimData = [];
					
					// Convert to AnimData format
					for (animName in animations.keys())
					{
						var adobeAnim = animations.get(animName);
						
						var animData:AnimData = {
							name: animName,
							prefix: animName, // Use name as prefix
							framerate: adobeAnim.framerate,
							looped: adobeAnim.looped,
							offsetX: 0,
							offsetY: 0
						};
						
						currentAnimData.push(animData);
					}
					
					FlxG.log.notice("Loaded " + currentAnimData.length + " animations from Adobe Animate");
				}
			}
			
			// Reload character
			reloadCharacterWithNewAnims();
			
			if (textHelp != null)
			{
				if (hasAnimations)
					textHelp.text = "✓ Loaded " + currentAnimData.length + " animations!";
				else
					textHelp.text = "⚠ No Animation.json - add animations manually";
				textHelp.color = hasAnimations ? FlxColor.LIME : FlxColor.ORANGE;
			}
		}
		catch (err:Dynamic)
		{
			FlxG.log.error("Error loading Adobe Animate: " + err);
			if (textHelp != null)
			{
				textHelp.text = "✗ Error: " + err;
				textHelp.color = FlxColor.RED;
			}
		}
		#end
	}

	/**
	 * NEW: Validate Adobe Animate files
	 */
	function validateAdobeAnimateFiles():Void
	{
		#if sys
		if (adobeAtlasPath == "" || adobeAnimPath == "")
		{
			if (textHelp != null)
			{
				textHelp.text = "⚠ Import Adobe Animate files first!";
				textHelp.color = FlxColor.ORANGE;
			}
			return;
		}
		
		try
		{
			var atlasPath = "assets/" + adobeAtlasPath;
			var animPath = "assets/" + adobeAnimPath;
			
			trace("\n========================================");
			trace("VALIDATING ADOBE ANIMATE FILES");
			trace("========================================");
			
			AdobeAnimateValidator.validate(atlasPath, animPath);
			
			if (textHelp != null)
			{
				textHelp.text = "✓ Check console for validation results";
				textHelp.color = FlxColor.LIME;
			}
		}
		catch (err:Dynamic)
		{
			FlxG.log.error("Error validating: " + err);
			if (textHelp != null)
			{
				textHelp.text = "✗ Validation error: " + err;
				textHelp.color = FlxColor.RED;
			}
		}
		#end
	}

	function browseForFile(fileType:String):Void
	{
		#if sys
		var fileDialog = new FileDialog();
		
		switch(fileType)
		{
			case "sprite":
				fileDialog.onSelect.add(function(path:String) {
					onSpriteSelected(path);
				});
				fileDialog.browse(OPEN, "png", null, "Select Sprite PNG");
			
			case "icon":
				fileDialog.onSelect.add(function(path:String) {
					onFileSelected(path, "icon");
				});
				fileDialog.browse(OPEN, "png", null, "Select Icon PNG");
		}
		#else
		FlxG.log.warn("File import only available on desktop platforms");
		#end
	}

	/**
	 * NEW: Handle sprite selection with auto-detection of XML/TXT
	 */
	function onSpriteSelected(sourcePath:String):Void
	{
		#if sys
		try
		{
			var fileName = haxe.io.Path.withoutDirectory(sourcePath);
			var sourceDir = haxe.io.Path.directory(sourcePath) + "/";
			var baseName = haxe.io.Path.withoutExtension(fileName);
			
			trace("Selected sprite: " + fileName);
			trace("Looking for associated files in: " + sourceDir);
			
			var destDir = "assets/characters/images/";
			if (!FileSystem.exists(destDir))
				FileSystem.createDirectory(destDir);
			
			// Copy PNG
			var destPng = destDir + fileName;
			File.copy(sourcePath, destPng);
			FlxG.log.notice("Copied: " + fileName);
			
			// Look for XML with same name
			var xmlPath = sourceDir + baseName + ".xml";
			if (FileSystem.exists(xmlPath))
			{
				var destXml = destDir + baseName + ".xml";
				File.copy(xmlPath, destXml);
				FlxG.log.notice("Auto-detected and copied: " + baseName + ".xml");
				
				if (textHelp != null)
				{
					textHelp.text = "✓ Imported PNG + XML";
					textHelp.color = FlxColor.LIME;
				}
			}
			else
			{
				// Look for TXT with same name
				var txtPath = sourceDir + baseName + ".txt";
				if (FileSystem.exists(txtPath))
				{
					var destTxt = destDir + baseName + ".txt";
					File.copy(txtPath, destTxt);
					FlxG.log.notice("Auto-detected and copied: " + baseName + ".txt");
					isTxtCheckbox.checked = true;
					
					if (textHelp != null)
					{
						textHelp.text = "✓ Imported PNG + TXT";
						textHelp.color = FlxColor.LIME;
					}
				}
				else
				{
					FlxG.log.warn("No XML or TXT found with name: " + baseName);
					if (textHelp != null)
					{
						textHelp.text = "⚠ PNG imported (no XML/TXT found)";
						textHelp.color = FlxColor.ORANGE;
					}
				}
			}
			
			// Update path input
			pathInput.text = baseName;
			
			// Track imported file
			importedFiles.set("sprite", destPng);
		}
		catch (err:Dynamic)
		{
			FlxG.log.error("Error importing sprite: " + err);
			if (textHelp != null)
			{
				textHelp.text = "✗ Error: " + err;
				textHelp.color = FlxColor.RED;
			}
		}
		#end
	}

	function onFileSelected(sourcePath:String, fileType:String):Void
	{
		#if sys
		try
		{
			// Get file data
			var fileName = haxe.io.Path.withoutDirectory(sourcePath);
			
			var destDir = "";
			var newFileName = fileName;
			
			// Determine destination based on file type
			if (fileType == "icon")
			{
				destDir = "assets/icons/";
				// Rename icon file to match format
				if (healthIconInput != null && healthIconInput.text != "")
				{
					var ext = haxe.io.Path.extension(fileName);
					newFileName = "icon-" + healthIconInput.text + "." + ext;
				}
			}
			else
			{
				destDir = "assets/characters/images/";
			}
			
			// Create directory if it doesn't exist
			if (!FileSystem.exists(destDir))
			{
				FileSystem.createDirectory(destDir);
			}
			
			var destPath = destDir + newFileName;
			
			// Copy file
			File.copy(sourcePath, destPath);
			
			FlxG.log.notice("File imported: " + newFileName);
			FlxG.log.notice("Saved to: " + destPath);
			
			// Track imported files
			importedFiles.set(fileType, destPath);
			
			// Update icon preview if icon was imported
			if (fileType == "icon" && healthIconInput != null)
			{
				updateIconPreview(healthIconInput.text);
			}
			
			// Show success message
			if (textHelp != null)
			{
				textHelp.text = "✓ " + fileName + " imported successfully!";
				textHelp.color = FlxColor.LIME;
			}
		}
		catch (err:Dynamic)
		{
			FlxG.log.error("Error importing file: " + err);
			if (textHelp != null)
			{
				textHelp.text = "✗ Error importing file: " + err;
				textHelp.color = FlxColor.RED;
			}
		}
		#end
	}

	function updateIconPreview(iconName:String):Void
	{
		if (iconPreview != null && iconName != null && iconName != "")
		{
			iconPreview.updateIcon(iconName, false);
		}
	}

	function reloadCharacterWithNewAnims():Void
	{
		// Create temporary character data
		var tempData:CharacterData = {
			path: pathInput.text,
			animations: currentAnimData,
			isPlayer: playerCheckbox.checked,
			antialiasing: antialiasingCheckbox.checked,
			scale: scaleStepper.value
		};

		if (isTxtCheckbox.checked)
			tempData.isTxt = true;
		
		if (isSpritesheetCheckbox.checked)
			tempData.isSpritemap = true;
		
		if (isAdobeAnimateCheckbox.checked)
		{
			tempData.isAdobeAnimate = true;
			if (animFileInput.text != "")
				tempData.animationFile = animFileInput.text;
		}

		// Save temporary JSON
		var jsonString = Json.stringify(tempData, null, '\t');
		
		#if sys
		try
		{
			if (!FileSystem.exists('assets/characters/'))
				FileSystem.createDirectory('assets/characters/');
			
			File.saveContent('assets/characters/' + daAnim + '.json', jsonString);
			
			// Reload character
			displayCharacter(daAnim);
			loadCharacterData();
		}
		catch (e:Dynamic)
		{
			FlxG.log.error("Error saving temp character data: " + e);
		}
		#end
	}

	function loadCharacterData():Void
	{
		try
		{
			var file:String = Assets.getText(Paths.characterJSON(daAnim));
			characterData = cast Json.parse(file);
			
			// Load into UI
			if (pathInput != null)
				pathInput.text = characterData.path;
			
			if (scaleStepper != null)
				scaleStepper.value = characterData.scale;
			
			if (antialiasingCheckbox != null)
				antialiasingCheckbox.checked = characterData.antialiasing;
			
			if (playerCheckbox != null)
				playerCheckbox.checked = characterData.isPlayer;
			
			if (isTxtCheckbox != null)
				isTxtCheckbox.checked = characterData.isTxt != null ? characterData.isTxt : false;
			
			if (isSpritesheetCheckbox != null)
				isSpritesheetCheckbox.checked = characterData.isSpritemap != null ? characterData.isSpritemap : false;
			
			if (isAdobeAnimateCheckbox != null)
				isAdobeAnimateCheckbox.checked = characterData.isAdobeAnimate != null ? characterData.isAdobeAnimate : false;
			
			if (animFileInput != null)
			{
				animFileInput.text = characterData.animationFile != null ? characterData.animationFile : "";
				animFileInput.color = isAdobeAnimateCheckbox.checked ? FlxColor.BLACK : FlxColor.WHITE;
			}
			
			if (healthIconInput != null)
			{
				healthIconInput.text = characterData.healthIcon != null ? characterData.healthIcon : daAnim;
				updateIconPreview(healthIconInput.text);
			}
			
			if (healthBarColorInput != null)
				healthBarColorInput.text = characterData.healthBarColor != null ? characterData.healthBarColor : "#31B0D1";
			
			// Load animations
			currentAnimData = characterData.animations;
		}
		catch (e:Dynamic)
		{
			trace("Could not load character data for: " + daAnim);
			currentAnimData = [];
		}
	}

	function exportCharacterJSON():Void
	{
		var exportData:CharacterData = {
			path: pathInput.text,
			animations: currentAnimData,
			isPlayer: playerCheckbox.checked,
			antialiasing: antialiasingCheckbox.checked,
			scale: scaleStepper.value
		};

		if (isTxtCheckbox.checked)
			exportData.isTxt = true;
		
		if (isSpritesheetCheckbox.checked)
			exportData.isSpritemap = true;
		
		if (isAdobeAnimateCheckbox.checked)
		{
			exportData.isAdobeAnimate = true;
			if (animFileInput.text != "")
				exportData.animationFile = animFileInput.text;
		}
		
		if (healthIconInput.text != "" && healthIconInput.text != daAnim)
			exportData.healthIcon = healthIconInput.text;
		
		if (healthBarColorInput.text != "" && healthBarColorInput.text != "#31B0D1")
			exportData.healthBarColor = healthBarColorInput.text;

		var jsonString = Json.stringify(exportData, null, '\t');

		if (jsonString != null && jsonString.length > 0)
		{
			_file = new FileReference();
			_file.addEventListener(Event.COMPLETE, onSaveComplete);
			_file.addEventListener(Event.CANCEL, onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file.save(jsonString, daAnim + ".json");
		}
	}

	function exportOffsetsTXT():Void
	{
		var data:String = '';
		for (anim in animList)
		{
			if (char.animOffsets.exists(anim))
			{
				var offsets = char.animOffsets.get(anim);
				data += anim + " " + offsets[0] + " " + offsets[1] + "\n";
			}
		}

		if (data != null && data.length > 0)
		{
			_file = new FileReference();
			_file.addEventListener(Event.COMPLETE, onSaveComplete);
			_file.addEventListener(Event.CANCEL, onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file.save(data.trim(), daAnim + "Offsets.txt");
		}
	}

	function copyJSONToClipboard():Void
	{
		var exportData:CharacterData = {
			path: pathInput.text,
			animations: currentAnimData,
			isPlayer: playerCheckbox.checked,
			antialiasing: antialiasingCheckbox.checked,
			scale: scaleStepper.value
		};

		if (isTxtCheckbox.checked)
			exportData.isTxt = true;
		
		if (isSpritesheetCheckbox.checked)
			exportData.isSpritemap = true;
		
		if (isAdobeAnimateCheckbox.checked)
		{
			exportData.isAdobeAnimate = true;
			if (animFileInput.text != "")
				exportData.animationFile = animFileInput.text;
		}
		
		if (healthIconInput.text != "" && healthIconInput.text != daAnim)
			exportData.healthIcon = healthIconInput.text;
		
		if (healthBarColorInput.text != "" && healthBarColorInput.text != "#31B0D1")
			exportData.healthBarColor = healthBarColorInput.text;

		var jsonString = Json.stringify(exportData, null, '\t');
		
		#if desktop
		lime.system.Clipboard.text = jsonString;
		FlxG.log.notice("JSON copied to clipboard!");
		if (textHelp != null)
		{
			textHelp.text = "✓ JSON copied to clipboard!";
			textHelp.color = FlxColor.LIME;
		}
		#else
		FlxG.log.warn("Clipboard not supported on this platform");
		#end
	}

	function onSaveComplete(_):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		FlxG.log.notice("File saved successfully!");
		if (textHelp != null)
		{
			textHelp.text = "✓ File saved successfully!";
			textHelp.color = FlxColor.LIME;
		}
	}

	function onSaveCancel(_):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
	}

	function onSaveError(_):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		FlxG.log.error("Error saving file!");
		if (textHelp != null)
		{
			textHelp.text = "✗ Error saving file!";
			textHelp.color = FlxColor.RED;
		}
	}

	function displayCharacter(character:String):Void
	{
		// Clear previous texts
		dumbTexts.forEach(function(text:FlxText)
		{
			dumbTexts.remove(text, true);
		});
		dumbTexts.clear();

		animList = [];

		// Remove old characters
		if (char != null)
			layeringbullshit.remove(char);

		if (ghostChar != null)
			layeringbullshit.remove(ghostChar);

		// Create ghost character
		ghostChar = new Character(0, 0, character);
		ghostChar.alpha = 0.5;
		ghostChar.screenCenter();
		ghostChar.debugMode = true;
		layeringbullshit.add(ghostChar);

		// Create main character
		char = new Character(0, 0, character);
		char.screenCenter();
		char.debugMode = true;
		layeringbullshit.add(char);

		char.flipX = playerCheckbox.checked;

		// Generate offset display
		generateOffsetTexts();
	}

	function generateOffsetTexts(pushList:Bool = true):Void
	{
		var daLoop:Int = 0;
		var startY:Int = 180;

		for (anim => offsets in char.animOffsets)
		{
			var text:FlxText = new FlxText(10, startY + (18 * daLoop), 0, anim + ": [" + offsets[0] + ", " + offsets[1] + "]", 14);
			text.scrollFactor.set();
			text.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 2);
			text.color = (daLoop == curAnim) ? FlxColor.CYAN : FlxColor.WHITE;
			dumbTexts.add(text);

			if (pushList)
				animList.push(anim);

			daLoop++;
		}
	}

	function updateOffsetTexts():Void
	{
		dumbTexts.forEach(function(text:FlxText)
		{
			text.kill();
			dumbTexts.remove(text, true);
		});
		dumbTexts.clear();

		generateOffsetTexts(false);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (char == null || char.animation.curAnim == null)
			return;

		// Update displays
		textAnim.text = "Current: " + char.animation.curAnim.name + " [" + (curAnim + 1) + "/" + animList.length + "]";
		
		if (animList.length > 0 && curAnim >= 0 && curAnim < animList.length)
		{
			var currentAnimName = animList[curAnim];
			var offsets = char.animOffsets.get(currentAnimName);
			if (offsets != null)
				textInfo.text = "Offset: [" + offsets[0] + ", " + offsets[1] + "] | Zoom: " + FlxMath.roundDecimal(camGame.zoom, 2);
		}

		// Ghost follows main character flip
		if (ghostChar != null)
			ghostChar.flipX = char.flipX;

		// Exit
		if (FlxG.keys.justPressed.ESCAPE)
		{
			FlxG.mouse.visible = false;
			states.LoadingState.loadAndSwitchState(new states.MainMenuState());
		}

		// Camera zoom
		if (FlxG.keys.justPressed.E)
			camGame.zoom += 0.25;
		if (FlxG.keys.justPressed.Q)
			camGame.zoom = Math.max(0.25, camGame.zoom - 0.25);

		// Camera reset
		if (FlxG.keys.justPressed.R)
		{
			camFollow.setPosition(FlxG.width / 2, FlxG.height / 2);
			camGame.zoom = 1;
		}

		// Toggle grid
		if (FlxG.keys.justPressed.G)
		{
			showGrid = !showGrid;
			gridBG.visible = showGrid;
		}

		// Toggle ghost
		if (FlxG.keys.justPressed.T)
		{
			if (ghostChar != null)
				ghostChar.visible = !ghostChar.visible;
		}

		// Camera movement
		var camSpeed = 90 * (FlxG.keys.pressed.SHIFT ? 2 : 1);
		
		if (FlxG.keys.pressed.I || FlxG.keys.pressed.J || FlxG.keys.pressed.K || FlxG.keys.pressed.L)
		{
			if (FlxG.keys.pressed.I)
				camFollow.velocity.y = -camSpeed;
			else if (FlxG.keys.pressed.K)
				camFollow.velocity.y = camSpeed;
			else
				camFollow.velocity.y = 0;

			if (FlxG.keys.pressed.J)
				camFollow.velocity.x = -camSpeed;
			else if (FlxG.keys.pressed.L)
				camFollow.velocity.x = camSpeed;
			else
				camFollow.velocity.x = 0;
		}
		else
		{
			camFollow.velocity.set();
		}

		// Animation switching
		if (FlxG.keys.justPressed.W)
		{
			curAnim--;
			if (curAnim < 0)
				curAnim = animList.length - 1;
		}

		if (FlxG.keys.justPressed.S)
		{
			curAnim++;
			if (curAnim >= animList.length)
				curAnim = 0;
		}

		// Play animation
		if (FlxG.keys.justPressed.S || FlxG.keys.justPressed.W || FlxG.keys.justPressed.SPACE)
		{
			if (animList.length > 0 && curAnim >= 0 && curAnim < animList.length)
			{
				char.playAnim(animList[curAnim]);
				if (ghostChar != null)
					ghostChar.playAnim(animList[0]);
				updateOffsetTexts();
			}
		}

		// Offset adjustment
		var upP = FlxG.keys.anyJustPressed([UP]);
		var rightP = FlxG.keys.anyJustPressed([RIGHT]);
		var downP = FlxG.keys.anyJustPressed([DOWN]);
		var leftP = FlxG.keys.anyJustPressed([LEFT]);

		var multiplier = FlxG.keys.pressed.SHIFT ? 10 : 1;

		if (upP || rightP || downP || leftP)
		{
			if (animList.length > 0 && curAnim >= 0 && curAnim < animList.length)
			{
				var currentAnimName = animList[curAnim];
				var offsets = char.animOffsets.get(currentAnimName);
				
				if (offsets != null)
				{
					if (upP)
						offsets[1] += 1 * multiplier;
					if (downP)
						offsets[1] -= 1 * multiplier;
					if (leftP)
						offsets[0] += 1 * multiplier;
					if (rightP)
						offsets[0] -= 1 * multiplier;

					// Update in current anim data
					for (anim in currentAnimData)
					{
						if (anim.name == currentAnimName)
						{
							anim.offsetX = offsets[0];
							anim.offsetY = offsets[1];
							break;
						}
					}

					char.playAnim(currentAnimName);
					if (ghostChar != null)
						ghostChar.playAnim(animList[0]);
					updateOffsetTexts();
				}
			}
		}
	}
}