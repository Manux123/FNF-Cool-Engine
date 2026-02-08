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
	
	var velocityPlus:Float = 1;
	var gridBG:FlxSprite;
	var showGrid:Bool = true;
	
	// Character data for JSON export
	var characterData:CharacterData;
	var currentAnimData:Array<AnimData> = [];

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
			{name: "Export", label: "Export"}
		];

		UI_box = new FlxUITabMenu(null, tabs, true);
		UI_box.cameras = [camHUD];
		UI_box.resize(320, 400);
		UI_box.x = FlxG.width - UI_box.width - 10;
		UI_box.y = 10;
		add(UI_box);

		addCharacterTab();
		addAnimationTab();
		addPropertiesTab();
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
		var fpsLabel = new FlxText(10, yPos, 0, "Framerate:", 10);
		tab.add(fpsLabel);
		yPos += 15;
		animFramerateStepper = new FlxUINumericStepper(10, yPos, 1, 24, 1, 120, 0);
		tab.add(animFramerateStepper);
		yPos += 30;

		// Looped
		animLoopedCheckbox = new FlxUICheckBox(10, yPos, null, null, "Looped", 100);
		animLoopedCheckbox.checked = false;
		tab.add(animLoopedCheckbox);
		yPos += 25;

		// Special anim
		animSpecialCheckbox = new FlxUICheckBox(10, yPos, null, null, "Special Anim", 100);
		animSpecialCheckbox.checked = false;
		tab.add(animSpecialCheckbox);
		yPos += 30;

		// Offset X
		var offsetXLabel = new FlxText(10, yPos, 0, "Offset X:", 10);
		tab.add(offsetXLabel);
		yPos += 15;
		offsetXStepper = new FlxUINumericStepper(10, yPos, 1, 0, -9999, 9999, 0);
		tab.add(offsetXStepper);
		yPos += 30;

		// Offset Y
		var offsetYLabel = new FlxText(10, yPos, 0, "Offset Y:", 10);
		tab.add(offsetYLabel);
		yPos += 15;
		offsetYStepper = new FlxUINumericStepper(10, yPos, 1, 0, -9999, 9999, 0);
		tab.add(offsetYStepper);
		yPos += 35;

		// Add/Update button
		var addAnimBtn = new FlxButton(10, yPos, "Add/Update Anim", function()
		{
			addOrUpdateAnimation();
		});
		tab.add(addAnimBtn);
		yPos += 30;

		// Delete button
		var deleteAnimBtn = new FlxButton(10, yPos, "Delete Current Anim", function()
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

		// Path input
		var pathLabel = new FlxText(10, yPos, 0, "Sprite Path:", 10);
		tab.add(pathLabel);
		yPos += 15;
		pathInput = new FlxUIInputText(10, yPos, 200, 'characters/BOYFRIEND', 8);
		tab.add(pathInput);
		yPos += 25;

		// Scale
		var scaleLabel = new FlxText(10, yPos, 0, "Scale:", 10);
		tab.add(scaleLabel);
		yPos += 15;
		scaleStepper = new FlxUINumericStepper(10, yPos, 0.1, 1, 0.1, 10, 1);
		scaleStepper.value = 1;
		tab.add(scaleStepper);
		yPos += 30;

		// Antialiasing
		antialiasingCheckbox = new FlxUICheckBox(10, yPos, null, null, "Antialiasing", 100);
		antialiasingCheckbox.checked = true;
		tab.add(antialiasingCheckbox);
		yPos += 25;

		// Is TXT
		isTxtCheckbox = new FlxUICheckBox(10, yPos, null, null, "Use .txt format", 120);
		isTxtCheckbox.checked = false;
		tab.add(isTxtCheckbox);
		yPos += 35;

		// Apply properties button
		var applyBtn = new FlxButton(10, yPos, "Apply Properties", function()
		{
			applyProperties();
		});
		tab.add(applyBtn);

		UI_box.addGroup(tab);
	}

	function addExportTab():Void
	{
		var tab = new FlxUI(null, UI_box);
		tab.name = "Export";

		var yPos = 10;

		var titleLabel = new FlxText(10, yPos, 0, "Export Options", 14);
		titleLabel.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 1);
		tab.add(titleLabel);
		yPos += 30;

		// Export JSON button
		var exportJsonBtn = new FlxButton(10, yPos, "Export Character JSON", function()
		{
			exportCharacterJSON();
		});
		tab.add(exportJsonBtn);
		yPos += 35;

		// Export offsets (old format)
		var exportOffsetsBtn = new FlxButton(10, yPos, "Export Offsets (TXT)", function()
		{
			exportOffsetsTXT();
		});
		tab.add(exportOffsetsBtn);
		yPos += 35;

		// Copy JSON to clipboard
		var copyJsonBtn = new FlxButton(10, yPos, "Copy JSON", function()
		{
			copyJSONToClipboard();
		});
		tab.add(copyJsonBtn);
		yPos += 40;

		var infoText = new FlxText(10, yPos, 280, 
			"Export creates a complete JSON file that can be used directly with the Character class.", 10);
		infoText.color = FlxColor.GRAY;
		tab.add(infoText);

		UI_box.addGroup(tab);
	}

	function loadCharacterData():Void
	{
		try
		{
			var file:String = Assets.getText(Paths.characterJSON(daAnim));
			characterData = cast Json.parse(file);
			
			// Update UI with loaded data
			if (characterData != null)
			{
				pathInput.text = characterData.path;
				scaleStepper.value = characterData.scale;
				antialiasingCheckbox.checked = characterData.antialiasing;
				playerCheckbox.checked = characterData.isPlayer;
				
				if (characterData.isTxt != null)
					isTxtCheckbox.checked = characterData.isTxt;
				
				currentAnimData = characterData.animations;
			}
		}
		catch (e:Dynamic)
		{
			trace("Could not load character data: " + e);
			// Initialize with default data
			characterData = {
				path: 'characters/' + daAnim.toUpperCase(),
				animations: [],
				isPlayer: false,
				antialiasing: true,
				scale: 1
			};
			currentAnimData = [];
		}
	}

	function addOrUpdateAnimation():Void
	{
		if (animNameInput.text == '' || animPrefixInput.text == '')
		{
			FlxG.log.warn("Animation name and prefix cannot be empty!");
			return;
		}

		var newAnim:AnimData = {
			name: animNameInput.text,
			prefix: animPrefixInput.text,
			offsetX: offsetXStepper.value,
			offsetY: offsetYStepper.value,
			framerate: animFramerateStepper.value,
			looped: animLoopedCheckbox.checked
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

		// Add to character
		if (char != null)
		{
			char.animation.addByPrefix(newAnim.name, newAnim.prefix, 
				Std.int(newAnim.framerate), newAnim.looped);
			char.addOffset(newAnim.name, newAnim.offsetX, newAnim.offsetY);
		}

		// Refresh display
		displayCharacter(daAnim);
		FlxG.log.notice("Animation '" + newAnim.name + "' added/updated!");
	}

	function deleteCurrentAnimation():Void
	{
		if (animList.length == 0 || curAnim < 0 || curAnim >= animList.length)
			return;

		var animToDelete = animList[curAnim];
		
		// Remove from current anim data
		for (i in 0...currentAnimData.length)
		{
			if (currentAnimData[i].name == animToDelete)
			{
				currentAnimData.splice(i, 1);
				break;
			}
		}

		// Refresh display
		displayCharacter(daAnim);
		FlxG.log.notice("Animation '" + animToDelete + "' deleted!");
	}

	function applyProperties():Void
	{
		if (char == null)
			return;

		char.scale.set(scaleStepper.value, scaleStepper.value);
		char.updateHitbox();
		char.antialiasing = antialiasingCheckbox.checked;

		FlxG.log.notice("Properties applied!");
	}

	function exportCharacterJSON():Void
	{
		// Build complete character data
		var exportData:CharacterData = {
			path: pathInput.text,
			animations: currentAnimData,
			isPlayer: playerCheckbox.checked,
			antialiasing: antialiasingCheckbox.checked,
			scale: scaleStepper.value
		};

		if (isTxtCheckbox.checked)
			exportData.isTxt = true;

		if (playerCheckbox.checked)
			exportData.flipX = true;

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

		var jsonString = Json.stringify(exportData, null, '\t');
		
		#if desktop
		lime.system.Clipboard.text = jsonString;
		FlxG.log.notice("JSON copied to clipboard!");
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