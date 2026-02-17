package funkin.debug;

import flixel.math.FlxMath;
import funkin.gameplay.objects.character.Character.AnimData;
import funkin.gameplay.objects.character.Character.CharacterData;
import funkin.states.MusicBeatState;
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
import funkin.gameplay.objects.character.Character;
import funkin.menus.FreeplayState;
import extensions.CoolUtil;
import funkin.states.LoadingState;
import haxe.Json;
import funkin.menus.MainMenuState;
import funkin.gameplay.objects.character.HealthIcon;

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

	// UI Elements — Character tab
	var playerCheckbox:FlxUICheckBox;

	// UI Elements — Properties tab
	var antialiasingCheckbox:FlxUICheckBox;
	var scaleStepper:FlxUINumericStepper;
	var pathInput:FlxUIInputText;
	var spritemapNameInput:FlxUIInputText; // antes: animFileInput
	var isTxtCheckbox:FlxUICheckBox;
	var isSpritesheetCheckbox:FlxUICheckBox;
	var isFlxAnimateCheckbox:FlxUICheckBox; // antes: isAdobeAnimateCheckbox
	var healthIconInput:FlxUIInputText;
	var healthBarColorInput:FlxUIInputText;

	// UI Elements — Animation tab
	var animNameInput:FlxUIInputText;
	var animPrefixInput:FlxUIInputText;
	var animFramerateStepper:FlxUINumericStepper;
	var animLoopedCheckbox:FlxUICheckBox;
	var animSpecialCheckbox:FlxUICheckBox;
	var offsetXStepper:FlxUINumericStepper;
	var offsetYStepper:FlxUINumericStepper;

	var velocityPlus:Float = 1;
	var gridBG:FlxSprite;
	var showGrid:Bool = true;

	// Character data para exportar
	var characterData:CharacterData;
	var currentAnimData:Array<AnimData> = [];

	// Icon preview
	var iconPreview:HealthIcon;
	var iconBG:FlxSprite;

	// Ruta de la carpeta FlxAnimate importada (assets/images/<char>/)
	var flxAnimateFolderPath:String = "";

	public function new(daAnim:String = 'bf')
	{
		super();
		this.daAnim = daAnim;
	}

	// ── create ───────────────────────────────────────────────────────────────

	override function create()
	{
		FlxG.mouse.visible = true;
		FreeplayState.destroyFreeplayVocals();
		FlxG.sound.playMusic(Paths.music('configurator'));
		MainMenuState.musicFreakyisPlaying = false;

		camGame = new FlxCamera();
		camHUD  = new FlxCamera();
		camHUD.bgColor.alpha = 0;

		FlxG.cameras.reset(camGame);
		FlxG.cameras.add(camHUD, false);

		gridBG = FlxGridOverlay.create(50, 50, -1, -1, true, 0x33FFFFFF, 0x33000000);
		gridBG.scrollFactor.set(0.5, 0.5);
		add(gridBG);

		layeringbullshit = new FlxTypedGroup<FlxSprite>();
		add(layeringbullshit);

		setupUI();

		dumbTexts = new FlxTypedGroup<FlxText>();
		dumbTexts.cameras = [camHUD];
		add(dumbTexts);

		// Controles
		textControls = new FlxText(10, 10, FlxG.width - 20, '', 12);
		textControls.text = "CONTROLS:\n"
			+ "W/S - Switch Animation | ARROWS - Adjust Offset (SHIFT = x10)\n"
			+ "I/K - Camera Up/Down | J/L - Camera Left/Right\n"
			+ "Q/E - Zoom Out/In | SPACE - Play Anim | ESC - Exit\n"
			+ "G - Toggle Grid | R - Reset Camera | T - Toggle Ghost";
		textControls.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 2);
		textControls.color = FlxColor.WHITE;
		textControls.cameras = [camHUD];
		textControls.scrollFactor.set();
		add(textControls);

		textAnim = new FlxText(10, 120, 0, '', 20);
		textAnim.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 2);
		textAnim.color = FlxColor.CYAN;
		textAnim.cameras = [camHUD];
		textAnim.scrollFactor.set();
		add(textAnim);

		textInfo = new FlxText(10, 150, 0, '', 14);
		textInfo.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 2);
		textInfo.color = FlxColor.YELLOW;
		textInfo.cameras = [camHUD];
		textInfo.scrollFactor.set();
		add(textInfo);

		textHelp = new FlxText(10, FlxG.height - 60, FlxG.width - 20, '', 12);
		textHelp.text = "TIP: Use the UI tabs to edit character properties and create new animations!";
		textHelp.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 2);
		textHelp.color = FlxColor.LIME;
		textHelp.cameras = [camHUD];
		textHelp.scrollFactor.set();
		textHelp.alignment = CENTER;
		add(textHelp);

		// Icon preview
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

	// ── UI Setup ──────────────────────────────────────────────────────────────

	function setupUI():Void
	{
		var tabs = [
			{name: "Character",  label: "Character"},
			{name: "Animation",  label: "Animation"},
			{name: "Properties", label: "Properties"},
			{name: "Import",     label: "Import Assets"},
			{name: "Export",     label: "Export"}
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

	// ── Tab: Character ────────────────────────────────────────────────────────

	function addCharacterTab():Void
	{
		var tab = new FlxUI(null, UI_box);
		tab.name = "Character";

		var characters:Array<String> = CoolUtil.coolTextFile('assets/characters/characterList.txt');

		tab.add(new FlxText(10, 10, 0, "Select Character:", 12));

		var charDropdown = new FlxUIDropDownMenu(10, 30, FlxUIDropDownMenu.makeStrIdLabelArray(characters, true), function(character:String)
		{
			daAnim = characters[Std.parseInt(character)];
			displayCharacter(daAnim);
			loadCharacterData();
		});
		charDropdown.selectedLabel = daAnim;

		playerCheckbox = new FlxUICheckBox(10, 70, null, null, "Player Character (FlipX)", 180);
		playerCheckbox.checked = false;
		playerCheckbox.callback = function() { if (char != null) char.flipX = playerCheckbox.checked; };
		tab.add(playerCheckbox);

		var refreshBtn = new FlxButton(10, 110, "Refresh Character", function()
		{
			displayCharacter(daAnim);
			loadCharacterData();
		});
		tab.add(refreshBtn);

		tab.add(new FlxButton(10, 140, "Reset Camera", function()
		{
			camFollow.setPosition(FlxG.width / 2, FlxG.height / 2);
			camGame.zoom = 1;
		}));

		tab.add(new FlxButton(10, 170, "Toggle Grid", function()
		{
			showGrid = !showGrid;
			gridBG.visible = showGrid;
		}));

		tab.add(charDropdown);
		UI_box.addGroup(tab);
	}

	// ── Tab: Animation ────────────────────────────────────────────────────────

	function addAnimationTab():Void
	{
		var tab = new FlxUI(null, UI_box);
		tab.name = "Animation";

		var yPos = 10;

		var titleLabel = new FlxText(10, yPos, 0, "Add/Edit Animation", 14);
		titleLabel.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 1);
		tab.add(titleLabel);
		yPos += 25;

		tab.add(new FlxText(10, yPos, 0, "Name:", 10));
		yPos += 15;
		animNameInput = new FlxUIInputText(10, yPos, 200, '', 8);
		tab.add(animNameInput);
		yPos += 25;

		// Para FlxAnimate: este campo es el SN del símbolo
		// Para sprites normales: es el prefix del atlas XML
		tab.add(new FlxText(10, yPos, 0, "Prefix / Symbol SN:", 10));
		yPos += 15;
		animPrefixInput = new FlxUIInputText(10, yPos, 200, '', 8);
		tab.add(animPrefixInput);

		var prefixHint = new FlxText(10, yPos + 14, 280, "FlxAnimate: nombre exacto del símbolo (SN)", 8);
		prefixHint.color = FlxColor.BLACK;
		tab.add(prefixHint);
		yPos += 35;

		tab.add(new FlxText(10, yPos, 0, "Framerate:", 10));
		yPos += 15;
		animFramerateStepper = new FlxUINumericStepper(10, yPos, 1, 24, 1, 60, 0);
		tab.add(animFramerateStepper);
		yPos += 25;

		animLoopedCheckbox = new FlxUICheckBox(10, yPos, null, null, "Looped", 100);
		animLoopedCheckbox.checked = false;
		tab.add(animLoopedCheckbox);
		yPos += 20;

		animSpecialCheckbox = new FlxUICheckBox(10, yPos, null, null, "Special Anim", 100);
		animSpecialCheckbox.checked = false;
		tab.add(animSpecialCheckbox);
		yPos += 25;

		tab.add(new FlxText(10, yPos, 0, "Offset X:", 10));
		yPos += 15;
		offsetXStepper = new FlxUINumericStepper(10, yPos, 1, 0, -500, 500, 0);
		tab.add(offsetXStepper);
		yPos += 25;

		tab.add(new FlxText(10, yPos, 0, "Offset Y:", 10));
		yPos += 15;
		offsetYStepper = new FlxUINumericStepper(10, yPos, 1, 0, -500, 500, 0);
		tab.add(offsetYStepper);
		yPos += 30;

		tab.add(new FlxButton(10, yPos, "Add Animation",    function() { addNewAnimation(); }));
		tab.add(new FlxButton(130, yPos, "Delete Current", function() { deleteCurrentAnimation(); }));

		UI_box.addGroup(tab);
	}

	// ── Tab: Properties ───────────────────────────────────────────────────────

	function addPropertiesTab():Void
	{
		var tab = new FlxUI(null, UI_box);
		tab.name = "Properties";

		var yPos = 10;

		var titleLabel = new FlxText(10, yPos, 0, "Character Properties", 14);
		titleLabel.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 1);
		tab.add(titleLabel);
		yPos += 25;

		// Path — para FlxAnimate es la carpeta completa, para sprites el nombre del atlas
		tab.add(new FlxText(10, yPos, 0, "Sprite Path / Folder:", 10));
		yPos += 15;
		pathInput = new FlxUIInputText(10, yPos, 200, 'BOYFRIEND', 8);
		tab.add(pathInput);

		var pathHint = new FlxText(10, yPos + 14, 280, "FlxAnimate: ruta a la carpeta del personaje", 8);
		pathHint.color = FlxColor.BLACK;
		tab.add(pathHint);
		yPos += 35;

		// Spritemap Name — solo relevante para FlxAnimate (por defecto "spritemap1")
		tab.add(new FlxText(10, yPos, 0, "Spritemap Name:", 10));
		yPos += 15;
		spritemapNameInput = new FlxUIInputText(10, yPos, 200, 'spritemap1', 8);
		tab.add(spritemapNameInput);

		var smHint = new FlxText(10, yPos + 14, 280, "FlxAnimate only · Por defecto: spritemap1", 8);
		smHint.color = FlxColor.BLACK;
		tab.add(smHint);
		yPos += 35;

		// Health Icon
		tab.add(new FlxText(10, yPos, 0, "Health Icon:", 10));
		yPos += 15;
		healthIconInput = new FlxUIInputText(10, yPos, 200, 'bf', 8);
		healthIconInput.callback = function(text:String, action:String) { updateIconPreview(text); };
		tab.add(healthIconInput);
		yPos += 25;

		// Health Bar Color
		tab.add(new FlxText(10, yPos, 0, "Health Bar Color:", 10));
		yPos += 15;
		healthBarColorInput = new FlxUIInputText(10, yPos, 200, '#31B0D1', 8);
		tab.add(healthBarColorInput);
		yPos += 25;

		// Scale
		tab.add(new FlxText(10, yPos, 0, "Scale:", 10));
		yPos += 15;
		scaleStepper = new FlxUINumericStepper(10, yPos, 0.1, 1.0, 0.1, 10.0, 1);
		scaleStepper.value = 1.0;
		tab.add(scaleStepper);
		yPos += 30;

		antialiasingCheckbox = new FlxUICheckBox(10, yPos, null, null, "Antialiasing", 100);
		antialiasingCheckbox.checked = true;
		tab.add(antialiasingCheckbox);
		yPos += 25;

		// Formato — los tres son mutuamente exclusivos
		isTxtCheckbox = new FlxUICheckBox(10, yPos, null, null, "TXT Spritesheet", 150);
		isTxtCheckbox.checked = false;
		isTxtCheckbox.callback = function()
		{
			if (isTxtCheckbox.checked) { isSpritesheetCheckbox.checked = false; isFlxAnimateCheckbox.checked = false; }
		};
		tab.add(isTxtCheckbox);
		yPos += 20;

		isSpritesheetCheckbox = new FlxUICheckBox(10, yPos, null, null, "Spritesheet JSON", 150);
		isSpritesheetCheckbox.checked = false;
		isSpritesheetCheckbox.callback = function()
		{
			if (isSpritesheetCheckbox.checked) { isTxtCheckbox.checked = false; isFlxAnimateCheckbox.checked = false; }
		};
		tab.add(isSpritesheetCheckbox);
		yPos += 20;

		isFlxAnimateCheckbox = new FlxUICheckBox(10, yPos, null, null, "FlxAnimate (Adobe Animate)", 200);
		isFlxAnimateCheckbox.checked = false;
		isFlxAnimateCheckbox.callback = function()
		{
			if (isFlxAnimateCheckbox.checked) { isTxtCheckbox.checked = false; isSpritesheetCheckbox.checked = false; }
			// Recordatorio visual
			spritemapNameInput.color = isFlxAnimateCheckbox.checked ? FlxColor.ORANGE : FlxColor.WHITE;
		};
		tab.add(isFlxAnimateCheckbox);
		yPos += 30;

		tab.add(new FlxButton(10, yPos, "Apply Properties", function()
		{
			if (char != null)
			{
				char.antialiasing = antialiasingCheckbox.checked;
				char.scale.set(scaleStepper.value, scaleStepper.value);
				char.updateHitbox();
				updateIconPreview(healthIconInput.text);
			}
		}));

		UI_box.addGroup(tab);
	}

	// ── Tab: Import ───────────────────────────────────────────────────────────

	function addImportTab():Void
	{
		var tab = new FlxUI(null, UI_box);
		tab.name = "Import";

		var yPos = 10;

		var titleLabel = new FlxText(10, yPos, 0, "Import Assets", 14);
		titleLabel.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 1);
		tab.add(titleLabel);
		yPos += 25;

		// ── Standard sprite ──
		var stdLabel = new FlxText(10, yPos, 0, "Standard Sprite:", 12);
		stdLabel.color = FlxColor.CYAN;
		stdLabel.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 1);
		tab.add(stdLabel);
		yPos += 20;

		tab.add(new FlxButton(10, yPos, "Import Sprite PNG", function() { browseForFile("sprite"); }));

		tab.add(new FlxText(10, yPos + 22, 280, "Detecta XML/TXT automáticamente", 8));
		yPos += 50;

		// ── FlxAnimate ──
		var flxLabel = new FlxText(10, yPos, 0, "FlxAnimate (Adobe Animate):", 12);
		flxLabel.color = FlxColor.ORANGE;
		flxLabel.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 1);
		tab.add(flxLabel);
		yPos += 20;

		tab.add(new FlxText(10, yPos, 0, "Selecciona el spritemap PNG.\nDetecta spritemap.json y Animation.json\nautomáticamente de la misma carpeta.", 9));
		yPos += 40;

		tab.add(new FlxButton(10, yPos, "Import FlxAnimate", function() { browseForFlxAnimate(); }));
		yPos += 30;

		// Listar símbolos disponibles en Animation.json
		tab.add(new FlxButton(10, yPos, "List Symbols (Console)", function() { listAvailableSymbols(); }));

		var symHint = new FlxText(10, yPos + 22, 280, "Muestra los SN disponibles para usar como 'prefix'", 8);
		symHint.color = FlxColor.BLACK;
		tab.add(symHint);
		yPos += 50;

		// ── Health Icon ──
		var iconTitle = new FlxText(10, yPos, 0, "Health Icon:", 12);
		iconTitle.color = FlxColor.LIME;
		iconTitle.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 1);
		tab.add(iconTitle);
		yPos += 20;

		tab.add(new FlxButton(10, yPos, "Import Icon PNG", function() { browseForFile("icon"); }));
		tab.add(new FlxText(10, yPos + 22, 280, "300x150px (2 frames de 150x150)", 9));

		UI_box.addGroup(tab);
	}

	// ── Tab: Export ───────────────────────────────────────────────────────────

	function addExportTab():Void
	{
		var tab = new FlxUI(null, UI_box);
		tab.name = "Export";

		var yPos = 10;

		var titleLabel = new FlxText(10, yPos, 0, "Export Character", 14);
		titleLabel.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 1);
		tab.add(titleLabel);
		yPos += 30;

		tab.add(new FlxButton(10, yPos, "Export JSON",        function() { exportCharacterJSON(); }));
		yPos += 35;
		tab.add(new FlxButton(10, yPos, "Export Offsets TXT", function() { exportOffsetsTXT(); }));
		yPos += 35;
		tab.add(new FlxButton(10, yPos, "Copy JSON",          function() { copyJSONToClipboard(); }));
		yPos += 40;

		tab.add(new FlxText(10, yPos, 280,
			"Export JSON: Guarda todos los datos del personaje\n"
			+ "Offsets TXT: Solo los offsets de animaciones\n"
			+ "Copy JSON: Copiar al portapapeles", 10));

		UI_box.addGroup(tab);
	}

	// ── Lógica de animaciones ─────────────────────────────────────────────────

	function addNewAnimation():Void
	{
		if (animNameInput.text == "" || animPrefixInput.text == "")
		{
			setHelp("✗ Nombre y prefix son obligatorios!", FlxColor.RED);
			return;
		}

		var newAnim:AnimData = {
			name:      animNameInput.text,
			prefix:    animPrefixInput.text,
			framerate: animFramerateStepper.value,
			looped:    animLoopedCheckbox.checked,
			offsetX:   offsetXStepper.value,
			offsetY:   offsetYStepper.value
		};

		if (animSpecialCheckbox.checked)
			newAnim.specialAnim = true;

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

		reloadCharacterWithNewAnims();
		setHelp(exists ? "✓ Animación actualizada!" : "✓ Animación añadida!", FlxColor.LIME);

		animNameInput.text   = "";
		animPrefixInput.text = "";
	}

	function deleteCurrentAnimation():Void
	{
		if (animList.length == 0 || curAnim < 0 || curAnim >= animList.length)
			return;

		var animName = animList[curAnim];

		for (i in 0...currentAnimData.length)
		{
			if (currentAnimData[i].name == animName)
			{
				currentAnimData.splice(i, 1);
				break;
			}
		}

		reloadCharacterWithNewAnims();
		setHelp("✓ Animación eliminada: " + animName, FlxColor.LIME);

		if (curAnim >= animList.length)
			curAnim = animList.length - 1;
		if (curAnim < 0)
			curAnim = 0;
	}

	// ── Import: Standard sprite ───────────────────────────────────────────────

	function browseForFile(fileType:String):Void
	{
		#if sys
		var fileDialog = new FileDialog();
		switch (fileType)
		{
			case "sprite":
				fileDialog.onSelect.add(function(path) { onSpriteSelected(path); });
				fileDialog.browse(OPEN, "png", null, "Select Sprite PNG");
			case "icon":
				fileDialog.onSelect.add(function(path) { onFileSelected(path, "icon"); });
				fileDialog.browse(OPEN, "png", null, "Select Icon PNG");
		}
		#else
		FlxG.log.warn("File import solo disponible en desktop");
		#end
	}

	function onSpriteSelected(sourcePath:String):Void
	{
		#if sys
		try
		{
			var fileName = haxe.io.Path.withoutDirectory(sourcePath);
			var sourceDir = haxe.io.Path.directory(sourcePath) + "/";
			var baseName  = haxe.io.Path.withoutExtension(fileName);

			var destDir = "assets/characters/images/";
			if (!FileSystem.exists(destDir))
				FileSystem.createDirectory(destDir);

			File.copy(sourcePath, destDir + fileName);

			var xmlPath = sourceDir + baseName + ".xml";
			var txtPath = sourceDir + baseName + ".txt";

			if (FileSystem.exists(xmlPath))
			{
				File.copy(xmlPath, destDir + baseName + ".xml");
				setHelp("✓ PNG + XML importados", FlxColor.LIME);
			}
			else if (FileSystem.exists(txtPath))
			{
				File.copy(txtPath, destDir + baseName + ".txt");
				isTxtCheckbox.checked = true;
				setHelp("✓ PNG + TXT importados", FlxColor.LIME);
			}
			else
			{
				setHelp("⚠ PNG importado (no se encontró XML/TXT)", FlxColor.BLACK);
			}

			pathInput.text = baseName;
		}
		catch (err:Dynamic)
		{
			setHelp("✗ Error: " + err, FlxColor.RED);
		}
		#end
	}

	function onFileSelected(sourcePath:String, fileType:String):Void
	{
		#if sys
		try
		{
			var fileName = haxe.io.Path.withoutDirectory(sourcePath);
			var destDir  = (fileType == "icon") ? "assets/icons/" : "assets/characters/images/";
			var newFileName = fileName;

			if (!FileSystem.exists(destDir))
				FileSystem.createDirectory(destDir);

			if (fileType == "icon" && healthIconInput != null && healthIconInput.text != "")
			{
				var ext = haxe.io.Path.extension(fileName);
				newFileName = "icon-" + healthIconInput.text + "." + ext;
			}

			File.copy(sourcePath, destDir + newFileName);

			if (fileType == "icon" && healthIconInput != null)
				updateIconPreview(healthIconInput.text);

			setHelp("✓ " + newFileName + " importado!", FlxColor.LIME);
		}
		catch (err:Dynamic)
		{
			setHelp("✗ Error importando: " + err, FlxColor.RED);
		}
		#end
	}

	// ── Import: FlxAnimate ────────────────────────────────────────────────────

	/**
	 * Abre un FileDialog para seleccionar el PNG del spritemap.
	 * Detecta automáticamente el JSON del atlas y el Animation.json
	 * de la misma carpeta, y los copia todos a assets/images/<daAnim>/
	 */
	function browseForFlxAnimate():Void
	{
		#if sys
		var fileDialog = new FileDialog();
		fileDialog.onSelect.add(function(path:String) { onFlxAnimateSelected(path); });
		fileDialog.browse(OPEN, "png", null, "Select Spritemap PNG (FlxAnimate)");
		#else
		FlxG.log.warn("File import solo disponible en desktop");
		#end
	}

	function onFlxAnimateSelected(sourcePngPath:String):Void
	{
		#if sys
		try
		{
			var fileName  = haxe.io.Path.withoutDirectory(sourcePngPath);
			var sourceDir = haxe.io.Path.directory(sourcePngPath) + "/";
			var baseName  = haxe.io.Path.withoutExtension(fileName); // ej: "spritemap1"

			// Rutas que esperamos encontrar junto al PNG
			var atlasJsonSrc = sourceDir + baseName + ".json";    // spritemap1.json
			var animJsonSrc  = sourceDir + "Animation.json";

			if (!FileSystem.exists(atlasJsonSrc))
			{
				setHelp("✗ No se encontró " + baseName + ".json junto al PNG", FlxColor.RED);
				return;
			}

			// Destino: assets/characters/images/<daAnim>/
			// Coincide con Paths.characterFolder(daAnim)
			var destFolder = 'assets/characters/images/$daAnim/';
			if (!FileSystem.exists(destFolder))
				FileSystem.createDirectory(destFolder);

			// Copiar los tres archivos
			File.copy(sourcePngPath, destFolder + fileName);
			FlxG.log.notice("Copiado: " + destFolder + fileName);

			File.copy(atlasJsonSrc, destFolder + baseName + ".json");
			FlxG.log.notice("Copiado: " + destFolder + baseName + ".json");

			var hasAnimJson = FileSystem.exists(animJsonSrc);
			if (hasAnimJson)
			{
				File.copy(animJsonSrc, destFolder + "Animation.json");
				FlxG.log.notice("Copiado: " + destFolder + "Animation.json");
			}

			// Actualizar UI:
			// - path = nombre del personaje (ej: "myChar"), NO la ruta completa
			//   Character.hx lo convierte con Paths.characterFolder(path)
			// - spritemapName = nombre del PNG sin extensión (ej: "spritemap1")
			flxAnimateFolderPath          = destFolder;
			pathInput.text                = daAnim;       // ← solo el nombre del personaje
			spritemapNameInput.text       = baseName;
			isFlxAnimateCheckbox.checked  = true;
			isTxtCheckbox.checked         = false;
			isSpritesheetCheckbox.checked = false;

			// Auto-cargar animaciones desde Animation.json si existe
			if (hasAnimJson)
				loadAnimationsFromAnimationJson(destFolder + "Animation.json");

			var msg = "✓ FlxAnimate importado en " + destFolder;
			if (!hasAnimJson)
				msg += "\n⚠ Sin Animation.json — añade animaciones manualmente";
			setHelp(msg, hasAnimJson ? FlxColor.LIME : FlxColor.BLACK);
		}
		catch (err:Dynamic)
		{
			setHelp("✗ Error: " + err, FlxColor.RED);
		}
		#end
	}

	/**
	 * Lee el Animation.json y auto-genera currentAnimData con todos los
	 * símbolos del Symbol Dictionary (SD.S) como animaciones.
	 * El 'prefix' de cada animación = SN del símbolo.
	 */
	function loadAnimationsFromAnimationJson(animJsonPath:String):Void
	{
		#if sys
		try
		{
			var content = File.getContent(animJsonPath);
			var parsed:Dynamic = Json.parse(content);

			currentAnimData = [];

			// Registrar la animación principal (AN)
			if (parsed.AN != null)
			{
				currentAnimData.push({
					name:      parsed.AN.SN,
					prefix:    parsed.AN.SN,
					framerate: parsed.MD != null ? Std.int(parsed.MD.FRT) : 24,
					looped:    true,
					offsetX:   0,
					offsetY:   0
				});
			}

			// Registrar todos los símbolos del diccionario
			if (parsed.SD != null && parsed.SD.S != null)
			{
				for (sym in (cast parsed.SD.S : Array<Dynamic>))
				{
					currentAnimData.push({
						name:      sym.SN,
						prefix:    sym.SN,
						framerate: parsed.MD != null ? Std.int(parsed.MD.FRT) : 24,
						looped:    false,
						offsetX:   0,
						offsetY:   0
					});
				}
			}

			FlxG.log.notice('[AnimDebug] Cargados ' + currentAnimData.length + ' símbolos de Animation.json');
			reloadCharacterWithNewAnims();
		}
		catch (e:Dynamic)
		{
			FlxG.log.error('[AnimDebug] Error leyendo Animation.json: ' + e);
			setHelp("✗ Error leyendo Animation.json: " + e, FlxColor.RED);
		}
		#end
	}

	/**
	 * Lista en consola todos los símbolos (SN) disponibles en el Animation.json
	 * del personaje actual. Útil para saber qué poner como "prefix" en cada animación.
	 */
	function listAvailableSymbols():Void
	{
		// Primero intentar usar la API de la librería real flxanimate:
		// char.anim.symbolDictionary tiene todos los símbolos ya parseados.
		if (char != null && char._useFlxAnimate)
		{
			var symbols = char.anim.symbolDictionary;
			if (symbols != null)
			{
				trace("═══════════════════════════════════════════");
				trace("  SÍMBOLOS DISPONIBLES (flxanimate API)");
				trace("  (usa el SN como 'prefix' en tus anims)");
				trace("═══════════════════════════════════════════");
				for (key in symbols.keys())
					trace("    - " + key);
				trace("═══════════════════════════════════════════");
				setHelp("✓ Símbolos listados en consola", FlxColor.LIME);
				return;
			}
		}

		// Fallback: parsear Animation.json directamente
		#if sys
		var animJsonPath = flxAnimateFolderPath != ""
			? flxAnimateFolderPath + "Animation.json"
			: Paths.characterFolder(pathInput.text) + "Animation.json";

		if (!FileSystem.exists(animJsonPath))
		{
			setHelp("⚠ No se encontró Animation.json en: " + animJsonPath, FlxColor.BLACK);
			return;
		}

		try
		{
			var content = File.getContent(animJsonPath);
			var parsed:Dynamic = Json.parse(content);

			trace("═══════════════════════════════════════════");
			trace("  SÍMBOLOS DISPONIBLES EN Animation.json");
			trace("  (usa el SN como 'prefix' en tus anims)");
			trace("═══════════════════════════════════════════");
			if (parsed.AN != null)
				trace("  [AN] " + parsed.AN.SN + "  ← Animación principal");

			if (parsed.SD != null && parsed.SD.S != null)
			{
				trace("  [SD] Símbolos del diccionario:");
				for (sym in (cast parsed.SD.S : Array<Dynamic>))
					trace("    - " + sym.SN);
			}
			else
				trace("  (Sin Symbol Dictionary)");

			trace("═══════════════════════════════════════════");
			setHelp("✓ Símbolos listados en consola", FlxColor.LIME);
		}
		catch (e:Dynamic)
		{
			setHelp("✗ Error leyendo Animation.json: " + e, FlxColor.RED);
		}
		#else
		setHelp("⚠ Solo disponible en desktop", FlxColor.RED);
		#end
	}

	// ── Character display ─────────────────────────────────────────────────────

	function displayCharacter(character:String):Void
	{
		dumbTexts.forEach(function(text:FlxText)
		{
			dumbTexts.remove(text, true);
		});
		dumbTexts.clear();
		animList = [];

		if (char != null)      layeringbullshit.remove(char);
		if (ghostChar != null) layeringbullshit.remove(ghostChar);

		ghostChar = new Character(0, 0, character);
		ghostChar.alpha = 0.5;
		ghostChar.screenCenter();
		ghostChar.debugMode = true;
		layeringbullshit.add(ghostChar);

		char = new Character(0, 0, character);
		char.screenCenter();
		char.debugMode = true;
		layeringbullshit.add(char);

		char.flipX = playerCheckbox.checked;

		generateOffsetTexts();
	}

	function generateOffsetTexts(pushList:Bool = true):Void
	{
		var daLoop = 0;
		var startY = 180;

		for (anim => offsets in char.animOffsets)
		{
			var text = new FlxText(10, startY + (18 * daLoop), 0, anim + ": [" + offsets[0] + ", " + offsets[1] + "]", 14);
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
		dumbTexts.forEach(function(text:FlxText) { text.kill(); dumbTexts.remove(text, true); });
		dumbTexts.clear();
		generateOffsetTexts(false);
	}

	// ── loadCharacterData — carga el JSON del personaje en la UI ──────────────

	function loadCharacterData():Void
	{
		try
		{
			var jsonPath = Paths.characterJSON(daAnim);
			var content:String;

			#if sys
			if (FileSystem.exists(jsonPath))
				content = File.getContent(jsonPath);
			else
				content = lime.utils.Assets.getText(jsonPath);
			#else
			content = lime.utils.Assets.getText(jsonPath);
			#end

			characterData = cast Json.parse(content);

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

			var usingFlxAnimate = characterData.isFlxAnimate != null ? characterData.isFlxAnimate : false;
			if (isFlxAnimateCheckbox != null)
				isFlxAnimateCheckbox.checked = usingFlxAnimate;

			if (spritemapNameInput != null)
			{
				spritemapNameInput.text = (characterData.spritemapName != null && characterData.spritemapName != "")
					? characterData.spritemapName
					: "spritemap1";
				spritemapNameInput.color = usingFlxAnimate ? FlxColor.BLACK : FlxColor.WHITE;
			}

			if (healthIconInput != null)
			{
				healthIconInput.text = characterData.healthIcon != null ? characterData.healthIcon : daAnim;
				updateIconPreview(healthIconInput.text);
			}

			if (healthBarColorInput != null)
				healthBarColorInput.text = characterData.healthBarColor != null ? characterData.healthBarColor : "#31B0D1";

			currentAnimData = characterData.animations;

			if (usingFlxAnimate)
				flxAnimateFolderPath = Paths.characterFolder(characterData.path);
		}
		catch (e:Dynamic)
		{
			trace('[AnimDebug] No se encontraron datos para: ' + daAnim);
			currentAnimData = [];
		}
	}

	// ── reloadCharacterWithNewAnims ───────────────────────────────────────────

	function reloadCharacterWithNewAnims():Void
	{
		var tempData:CharacterData = {
			path:        pathInput.text,
			animations:  currentAnimData,
			isPlayer:    playerCheckbox.checked,
			antialiasing: antialiasingCheckbox.checked,
			scale:       scaleStepper.value
		};

		if (isTxtCheckbox.checked)
			tempData.isTxt = true;

		if (isSpritesheetCheckbox.checked)
			tempData.isSpritemap = true;

		if (isFlxAnimateCheckbox.checked)
		{
			tempData.isFlxAnimate = true;
			var sm = spritemapNameInput.text.trim();
			if (sm != "" && sm != "spritemap1")
				tempData.spritemapName = sm;
		}

		var jsonString = Json.stringify(tempData, null, '\t');

		#if sys
		try
		{
			if (!FileSystem.exists('assets/characters/'))
				FileSystem.createDirectory('assets/characters/');

			File.saveContent('assets/characters/' + daAnim + '.json', jsonString);
			displayCharacter(daAnim);
			loadCharacterData();
		}
		catch (e:Dynamic)
		{
			FlxG.log.error('[AnimDebug] Error guardando datos temporales: ' + e);
		}
		#end
	}

	// ── Export ────────────────────────────────────────────────────────────────

	function buildExportData():CharacterData
	{
		var exportData:CharacterData = {
			path:        pathInput.text,
			animations:  currentAnimData,
			isPlayer:    playerCheckbox.checked,
			antialiasing: antialiasingCheckbox.checked,
			scale:       scaleStepper.value
		};

		if (isTxtCheckbox.checked)
			exportData.isTxt = true;

		if (isSpritesheetCheckbox.checked)
			exportData.isSpritemap = true;

		if (isFlxAnimateCheckbox.checked)
		{
			exportData.isFlxAnimate = true;
			var sm = spritemapNameInput.text.trim();
			if (sm != "" && sm != "spritemap1")
				exportData.spritemapName = sm;
		}

		if (healthIconInput.text != "" && healthIconInput.text != daAnim)
			exportData.healthIcon = healthIconInput.text;

		if (healthBarColorInput.text != "" && healthBarColorInput.text != "#31B0D1")
			exportData.healthBarColor = healthBarColorInput.text;

		return exportData;
	}

	function exportCharacterJSON():Void
	{
		var jsonString = Json.stringify(buildExportData(), null, '\t');

		_file = new FileReference();
		_file.addEventListener(Event.COMPLETE, onSaveComplete);
		_file.addEventListener(Event.CANCEL,   onSaveCancel);
		_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file.save(jsonString, daAnim + ".json");
	}

	function exportOffsetsTXT():Void
	{
		var data = '';
		for (anim in animList)
		{
			if (char.animOffsets.exists(anim))
			{
				var offsets = char.animOffsets.get(anim);
				data += anim + " " + offsets[0] + " " + offsets[1] + "\n";
			}
		}

		if (data.length > 0)
		{
			_file = new FileReference();
			_file.addEventListener(Event.COMPLETE, onSaveComplete);
			_file.addEventListener(Event.CANCEL,   onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file.save(data.trim(), daAnim + "Offsets.txt");
		}
	}

	function copyJSONToClipboard():Void
	{
		var jsonString = Json.stringify(buildExportData(), null, '\t');
		#if desktop
		lime.system.Clipboard.text = jsonString;
		setHelp("✓ JSON copiado al portapapeles!", FlxColor.LIME);
		#else
		FlxG.log.warn("Clipboard no soportado en esta plataforma");
		#end
	}

	// ── File save events ──────────────────────────────────────────────────────

	function onSaveComplete(_):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL,   onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		setHelp("✓ Archivo guardado!", FlxColor.LIME);
	}

	function onSaveCancel(_):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL,   onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
	}

	function onSaveError(_):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL,   onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		setHelp("✗ Error guardando archivo!", FlxColor.RED);
	}

	// ── Icon preview ──────────────────────────────────────────────────────────

	function updateIconPreview(iconName:String):Void
	{
		if (iconPreview != null && iconName != null && iconName != "")
			iconPreview.updateIcon(iconName, false);
	}

	// ── Update ────────────────────────────────────────────────────────────────

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		// Usar char.hasCurAnim() para ser compatible con FlxAnimate y sprites normales
		if (char == null || !char.hasCurAnim())
			return;

		var curAnimName = char.getCurAnimName();

		// Display
		textAnim.text = "Current: " + curAnimName + " [" + (curAnim + 1) + "/" + animList.length + "]";

		if (animList.length > 0 && curAnim >= 0 && curAnim < animList.length)
		{
			var offsets = char.animOffsets.get(animList[curAnim]);
			if (offsets != null)
				textInfo.text = "Offset: [" + offsets[0] + ", " + offsets[1] + "] | Zoom: " + FlxMath.roundDecimal(camGame.zoom, 2);
		}

		if (ghostChar != null)
			ghostChar.flipX = char.flipX;

		// Exit
		if (FlxG.keys.justPressed.ESCAPE)
		{
			FlxG.mouse.visible = false;
			LoadingState.loadAndSwitchState(new MainMenuState());
		}

		// Zoom
		if (FlxG.keys.justPressed.E)
			camGame.zoom += 0.25;
		if (FlxG.keys.justPressed.Q)
			camGame.zoom = Math.max(0.25, camGame.zoom - 0.25);

		// Reset camera
		if (FlxG.keys.justPressed.R)
		{
			camFollow.setPosition(FlxG.width / 2, FlxG.height / 2);
			camGame.zoom = 1;
		}

		// Grid
		if (FlxG.keys.justPressed.G)
		{
			showGrid = !showGrid;
			gridBG.visible = showGrid;
		}

		// Ghost
		if (FlxG.keys.justPressed.T && ghostChar != null)
			ghostChar.visible = !ghostChar.visible;

		// Camera movement
		var camSpeed = 90 * (FlxG.keys.pressed.SHIFT ? 2 : 1);
		var moveH = FlxG.keys.pressed.J ? -1 : FlxG.keys.pressed.L ? 1 : 0;
		var moveV = FlxG.keys.pressed.I ? -1 : FlxG.keys.pressed.K ? 1 : 0;
		camFollow.velocity.set(moveH * camSpeed, moveV * camSpeed);

		// Animation switching
		if (FlxG.keys.justPressed.W)
		{
			curAnim--;
			if (curAnim < 0) curAnim = animList.length - 1;
		}
		if (FlxG.keys.justPressed.S)
		{
			curAnim++;
			if (curAnim >= animList.length) curAnim = 0;
		}

		if (FlxG.keys.justPressed.S || FlxG.keys.justPressed.W || FlxG.keys.justPressed.SPACE)
		{
			if (animList.length > 0 && curAnim >= 0 && curAnim < animList.length)
			{
				char.playAnim(animList[curAnim]);
				if (ghostChar != null) ghostChar.playAnim(animList[0]);
				updateOffsetTexts();
			}
		}

		// Offset adjustment
		var upP    = FlxG.keys.anyJustPressed([UP]);
		var rightP = FlxG.keys.anyJustPressed([RIGHT]);
		var downP  = FlxG.keys.anyJustPressed([DOWN]);
		var leftP  = FlxG.keys.anyJustPressed([LEFT]);
		var mult   = FlxG.keys.pressed.SHIFT ? 10 : 1;

		if ((upP || rightP || downP || leftP) && animList.length > 0 && curAnim >= 0 && curAnim < animList.length)
		{
			var selAnim  = animList[curAnim];
			var offsets  = char.animOffsets.get(selAnim);

			if (offsets != null)
			{
				if (upP)    offsets[1] += 1 * mult;
				if (downP)  offsets[1] -= 1 * mult;
				if (leftP)  offsets[0] += 1 * mult;
				if (rightP) offsets[0] -= 1 * mult;

				for (anim in currentAnimData)
				{
					if (anim.name == selAnim)
					{
						anim.offsetX = offsets[0];
						anim.offsetY = offsets[1];
						break;
					}
				}

				char.playAnim(selAnim);
				if (ghostChar != null) ghostChar.playAnim(animList[0]);
				updateOffsetTexts();
			}
		}
	}

	// ── Helpers ───────────────────────────────────────────────────────────────

	function setHelp(msg:String, color:FlxColor):Void
	{
		if (textHelp != null)
		{
			textHelp.text  = msg;
			textHelp.color = color;
		}
	}
}
