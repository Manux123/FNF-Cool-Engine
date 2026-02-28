package funkin.gameplay.notes;

import funkin.gameplay.controls.Controls.KeyboardScheme;
import funkin.gameplay.controls.Controls.Control;
import flash.text.TextField;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.display.FlxGridOverlay;
import funkin.transitions.StateTransition;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.input.keyboard.FlxKey;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import funkin.menus.OptionsMenuState;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import lime.utils.Assets;
import ui.Alphabet;

enum PreviewMode
{
	STATIC; // Notas estáticas
	ANIMATED; // Notas animadas cayendo
	GAMEPLAY; // Simulación de gameplay
}

class NoteSkinOptions extends funkin.states.MusicBeatState
{
	// Selección
	var curSelected:Int = 0;
	var currentTab:Int = 0; // 0 = Skins, 1 = Splashes, 2 = Settings

	// Listas
	var noteSkins:Array<String> = [];
	var noteSplashes:Array<String> = [];

	// Grupos
	var grpSkins:FlxTypedGroup<Alphabet>;
	var grpSplashes:FlxTypedGroup<Alphabet>;
	var grpSettings:FlxTypedGroup<Alphabet>;
	var grpTabs:FlxTypedGroup<Alphabet>;

	// UI Elements
	var bg:FlxSprite;
	var titleText:FlxText;
	var infoText:FlxText;
	var authorText:FlxText;
	var descText:FlxText;
	var controlsText:FlxText;
	var statsText:FlxText;
	var tabIndicator:FlxSprite;

	// Panel backgrounds - MEJORADO
	var leftPanel:FlxSprite;
	var rightPanel:FlxSprite;
	var previewPanel:FlxSprite;

	// Preview - MEJORADO con offsets correctos
	var previewNotes:FlxTypedGroup<FlxSprite>;
	var previewStrums:FlxTypedGroup<StrumNote>;
	var previewSplashes:FlxTypedGroup<NoteSplash>;
	var previewBG:FlxSprite;
	var previewMode:PreviewMode = ANIMATED;

	// Settings options - MEJORADO
	var settingsOptions:Array<String> = [
		"Reset to Default",
		"Export Current Config",
		"Preview Mode: Animated",
		"Show Animation Names: OFF",
		"Edit Animations",
		"Refresh Skins List"
	];
	var showAnimNames:Bool = false;
	var editingAnimations:Bool = false;

	// Animation
	var noteAnimTimer:FlxTimer;
	var noteYPositions:Array<Float> = [];
	var noteVelocities:Array<Float> = [];
	var autoPlayTimer:Float = 0;

	// NUEVO: Dimensiones mejoradas
	static inline var LEFT_PANEL_WIDTH:Int = 500;
	static inline var RIGHT_PANEL_WIDTH:Int = 720;
	static inline var PANEL_PADDING:Int = 20;
	static inline var STRUM_BASE_X:Int = 700;
	static inline var STRUM_BASE_Y:Int = 400;
	static inline var STRUM_SPACING:Int = 112;

	override function create()
	{
		initialize();
		super.create();
	}

	function initialize():Void
	{
		// Inicializar sistema
		NoteSkinSystem.init();

		// Obtener listas
		refreshLists();

		// Background con gradiente
		bg = new FlxSprite().loadGraphic(Paths.image('menu/menuDesat'));
		bg.color = 0xFF9B59D0;
		bg.setGraphicSize(Std.int(bg.width * 1.1));
		bg.updateHitbox();
		bg.screenCenter();
		bg.antialiasing = FlxG.save.data.antialiasing;
		add(bg);

		// Panel izquierdo (lista) - MEJORADO
		leftPanel = new FlxSprite(PANEL_PADDING, 90).makeGraphic(LEFT_PANEL_WIDTH, FlxG.height - 180, FlxColor.BLACK);
		leftPanel.alpha = 0.6;
		add(leftPanel);

		// Panel derecho (info y preview) - MEJORADO
		rightPanel = new FlxSprite(LEFT_PANEL_WIDTH + PANEL_PADDING * 2, 90).makeGraphic(RIGHT_PANEL_WIDTH, 200, FlxColor.BLACK);
		rightPanel.alpha = 0.6;
		add(rightPanel);

		// Panel de preview - NUEVO
		previewPanel = new FlxSprite(LEFT_PANEL_WIDTH + PANEL_PADDING * 2, 310).makeGraphic(RIGHT_PANEL_WIDTH, 380, FlxColor.BLACK);
		previewPanel.alpha = 0.5;
		add(previewPanel);

		// Title - MEJORADO
		titleText = new FlxText(0, 15, FlxG.width, "NOTE CUSTOMIZATION", 40);
		titleText.setFormat(Paths.font("vcr.ttf"), 40, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		titleText.borderSize = 3;
		add(titleText);

		// Tabs
		setupTabs();

		// Tab indicator (línea debajo del tab seleccionado)
		tabIndicator = new FlxSprite(40, 130).makeGraphic(150, 5, FlxColor.CYAN);
		add(tabIndicator);

		// Lists
		setupLists();

		// Info texts - MEJORADO con mejor posicionamiento
		setupInfoTexts();

		// Controls text
		controlsText = new FlxText(0, FlxG.height - 70, FlxG.width, "", 18);
		controlsText.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		controlsText.borderSize = 2;
		add(controlsText);

		// Stats text - MEJORADO
		statsText = new FlxText(0, FlxG.height - 40, FlxG.width, "", 16);
		statsText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.LIME, CENTER, OUTLINE, FlxColor.BLACK);
		statsText.borderSize = 2;
		updateStatsText();
		add(statsText);

		// Preview setup - MEJORADO con offsets correctos
		setupPreview();

		// Initialize positions
		for (i in 0...4)
		{
			noteYPositions.push(250);
			noteVelocities.push(200 + FlxG.random.float(-50, 50));
		}

		// Set initial selection
		curSelected = noteSkins.indexOf(NoteSkinSystem.currentSkin);
		if (curSelected == -1)
			curSelected = 0;

		changeSelection(999); //Making them a big number will for sure reset to the first option on the list
		changeTab(999);

		#if mobileC
		addVirtualPad(FULL, A_B_X_Y);
		#end
	}

	function refreshLists():Void
	{
		noteSkins = NoteSkinSystem.getSkinList();
		noteSplashes = NoteSkinSystem.getSplashList();

		// Ordenar
		noteSkins.sort((a, b) -> a.toLowerCase() < b.toLowerCase() ? -1 : 1);
		noteSplashes.sort((a, b) -> a.toLowerCase() < b.toLowerCase() ? -1 : 1);
	}

	function setupTabs():Void
	{
		grpTabs = new FlxTypedGroup<Alphabet>();
		add(grpTabs);

		var tabs:Array<String> = ["SKINS", "SPLASHES", "SETTINGS"];
		var tabSpacing:Float = FlxG.width / 3;
		
		for (i in 0...tabs.length)
		{
			var tab = new Alphabet(0, 0, tabs[i], true, false);
			tab.x = (tabSpacing * i) + (tabSpacing / 2) - (tab.width / 2);
			tab.y = 55;
			tab.isMenuItem = false;
			tab.alpha = 0.6;
			grpTabs.add(tab);
		}
	}

	function setupLists():Void
	{
		// Skins list
		grpSkins = new FlxTypedGroup<Alphabet>();
		add(grpSkins);

		for (i in 0...noteSkins.length)
		{
			var skinLabel = new Alphabet(0, 120 + (i * 70), noteSkins[i], false, false);
			skinLabel.isMenuItem = true;
			skinLabel.targetY = i;
			grpSkins.add(skinLabel);
		}

		// Splashes list
		grpSplashes = new FlxTypedGroup<Alphabet>();
		add(grpSplashes);

		for (i in 0...noteSplashes.length)
		{
			var splashLabel = new Alphabet(0, 120 + (i * 70), noteSplashes[i], false, false);
			splashLabel.isMenuItem = true;
			splashLabel.targetY = i;
			grpSplashes.add(splashLabel);
		}
		grpSplashes.visible = false;

		// Settings list
		grpSettings = new FlxTypedGroup<Alphabet>();
		add(grpSettings);

		for (i in 0...settingsOptions.length)
		{
			var settingLabel = new Alphabet(0, 120 + (i * 70), settingsOptions[i], false, false);
			settingLabel.isMenuItem = true;
			settingLabel.targetY = i;
			grpSettings.add(settingLabel);
		}
		grpSettings.visible = false;
	}

	function setupInfoTexts():Void
	{
		var infoX:Float = LEFT_PANEL_WIDTH + PANEL_PADDING * 2 + 20;
		
		infoText = new FlxText(infoX, 125, RIGHT_PANEL_WIDTH - 40, "", 28);
		infoText.setFormat(Paths.font("vcr.ttf"), 28, FlxColor.CYAN, LEFT, OUTLINE, FlxColor.BLACK);
		infoText.borderSize = 2;
		add(infoText);

		authorText = new FlxText(infoX, 165, RIGHT_PANEL_WIDTH - 40, "", 20);
		authorText.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.LIME, LEFT, OUTLINE, FlxColor.BLACK);
		authorText.borderSize = 2;
		add(authorText);

		descText = new FlxText(infoX, 200, RIGHT_PANEL_WIDTH - 40, "", 18);
		descText.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		descText.borderSize = 2;
		descText.wordWrap = true;
		add(descText);
	}

	function setupPreview():Void
	{
		previewStrums = new FlxTypedGroup<StrumNote>();
		add(previewStrums);

		previewNotes = new FlxTypedGroup<FlxSprite>();
		add(previewNotes);

		previewSplashes = new FlxTypedGroup<NoteSplash>();
		add(previewSplashes);

		// Create strums - MEJORADO con posicionamiento centrado
		for (i in 0...4)
		{
			var strum = new StrumNote(STRUM_BASE_X -10, STRUM_BASE_Y + 80, i);
			strum.scale.set(0.7, 0.7);
			strum.updateHitbox();
			previewStrums.add(strum);
		}

		// Create notes
		for (i in 0...4)
		{
			var note = new FlxSprite(0, noteYPositions[i]);
			previewNotes.add(note);
		}

		updatePreview();
	}

	function updatePreview():Void
	{
		switch (currentTab)
		{
			case 0:
				updateNotesPreview();
			case 1:
				updateSplashPreview();
			case 2:
				updateSettingsPreview();
		}
	}

	function updateNotesPreview():Void
	{
		var selectedSkin:String = noteSkins[curSelected];
		var frames = NoteSkinSystem.getNoteSkin(selectedSkin);
		var anims = NoteSkinSystem.getSkinAnimations(selectedSkin);

		// Update info
		var skinInfo = NoteSkinSystem.getSkinInfo(selectedSkin);
		if (skinInfo != null)
		{
			infoText.text = '${skinInfo.name}';
			authorText.text = 'By ${skinInfo.author}';
			var desc:String = skinInfo.description != null ? skinInfo.description : "No description available.";

			if (showAnimNames && anims != null)
			{
				desc += '\n\n--- ANIMATIONS ---';
				if (anims.left != null)
					desc += '\nLeft: ${anims.left}';
				if (anims.down != null)
					desc += '\nDown: ${anims.down}';
				if (anims.up != null)
					desc += '\nUp: ${anims.up}';
				if (anims.right != null)
					desc += '\nRight: ${anims.right}';
			}

			descText.text = desc;
		}

		// Update strums
		for (i in 0...previewStrums.members.length)
		{
			var strum = previewStrums.members[i];
			strum.frames = frames;
			
			// Load animations
			if (anims != null)
			{
				switch (i)
				{
					case 0:
						if (anims.strumLeft != null)
							strum.animation.addByPrefix('static', anims.strumLeft);
						if (anims.strumLeftPress != null)
							strum.animation.addByPrefix('pressed', anims.strumLeftPress, 24, false);
						if (anims.strumLeftConfirm != null)
							strum.animation.addByPrefix('confirm', anims.strumLeftConfirm, 24, false);
					case 1:
						if (anims.strumDown != null)
							strum.animation.addByPrefix('static', anims.strumDown);
						if (anims.strumDownPress != null)
							strum.animation.addByPrefix('pressed', anims.strumDownPress, 24, false);
						if (anims.strumDownConfirm != null)
							strum.animation.addByPrefix('confirm', anims.strumDownConfirm, 24, false);
					case 2:
						if (anims.strumUp != null)
							strum.animation.addByPrefix('static', anims.strumUp);
						if (anims.strumUpPress != null)
							strum.animation.addByPrefix('pressed', anims.strumUpPress, 24, false);
						if (anims.strumUpConfirm != null)
							strum.animation.addByPrefix('confirm', anims.strumUpConfirm, 24, false);
					case 3:
						if (anims.strumRight != null)
							strum.animation.addByPrefix('static', anims.strumRight);
						if (anims.strumRightPress != null)
							strum.animation.addByPrefix('pressed', anims.strumRightPress, 24, false);
						if (anims.strumRightConfirm != null)
							strum.animation.addByPrefix('confirm', anims.strumRightConfirm, 24, false);
				}
			}
			
			strum.animation.play('static', true);
			strum.centerOffsets();
			strum.centerOrigin();
		}

		// Update notes
		for (i in 0...previewNotes.members.length)
		{
			var note = previewNotes.members[i];
			note.frames = frames;
			
			if (anims != null)
			{
				switch (i)
				{
					case 0:
						if (anims.left != null)
							note.animation.addByPrefix('scroll', anims.left);
					case 1:
						if (anims.down != null)
							note.animation.addByPrefix('scroll', anims.down);
					case 2:
						if (anims.up != null)
							note.animation.addByPrefix('scroll', anims.up);
					case 3:
						if (anims.right != null)
							note.animation.addByPrefix('scroll', anims.right);
				}
			}
			
			note.animation.play('scroll');
			note.scale.set(0.7, 0.7);
			note.updateHitbox();
			note.x = STRUM_BASE_X + Note.swagWidth * i;
		}
	}

	function updateSplashPreview():Void
	{
		var selectedSplash:String = noteSplashes[curSelected];
		
		// Update info
		var splashInfo = NoteSkinSystem.getSplashInfo(selectedSplash);
		if (splashInfo != null)
		{
			infoText.text = '${splashInfo.name}';
			authorText.text = 'By ${splashInfo.author}';
			var desc:String = splashInfo.description != null ? splashInfo.description : "No description available.";

			var splashAnims = splashInfo.animations;
			if (showAnimNames && splashAnims != null)
			{
				desc += '\n\n--- ANIMATIONS ---';
				desc += '\nLeft: ${splashAnims.left}';
				desc += '\nDown: ${splashAnims.down}';
				desc += '\nUp: ${splashAnims.up}';
				desc += '\nRight: ${splashAnims.right}';
				desc += '\nFramerate: ${splashAnims.framerate != null ? splashAnims.framerate : 24}';
			}

			descText.text = desc;
		}

		// Update strums for splash preview
		for (i in 0...previewStrums.members.length)
		{
			var strum = previewStrums.members[i];
			strum.frames = NoteSkinSystem.getNoteSkin();
			strum.animation.play('static', true);
		}
	}

	function updateSettingsPreview():Void
	{
		infoText.text = "Settings";
		authorText.text = "";
		descText.text = "Configure note skin system settings and preview options.";
	}

	function testSplash():Void
	{
		for (i in 0...4)
		{
			testSplashSingle(i);
		}
	}

	function testSplashSingle(direction:Int):Void
	{
		var selectedSplash:String = noteSplashes[curSelected >= 0 && curSelected < noteSplashes.length ? curSelected : 0];
		if (currentTab != 1)
			selectedSplash = null;

		var strum = previewStrums.members[direction];
		var splash = new NoteSplash();
		splash.setup(strum.x, strum.y, direction, selectedSplash);
		// CORREGIDO: Centrar el splash correctamente
		splash.x -= splash.width / 2;
		splash.y -= splash.height / 2;
		previewSplashes.add(splash);
	}

	function executeSettingOption():Void
	{
		switch (curSelected)
		{
			case 0: // Reset to Default
				NoteSkinSystem.setSkin("Default");
				NoteSkinSystem.setSplash("Default");
				FlxG.sound.play(Paths.sound('menus/confirmMenu'));
				updateStatsText();
				showNotification("Reset to default!");

			case 1: // Export Current Config
				var skinExample = NoteSkinSystem.exportSkinExample();
				var splashExample = NoteSkinSystem.exportSplashExample();
				trace("=== SKIN EXAMPLE ===\n" + skinExample);
				trace("=== SPLASH EXAMPLE ===\n" + splashExample);
				FlxG.sound.play(Paths.sound('menus/confirmMenu'));
				showNotification("Config exported to console!");

			case 2: // Preview Mode
				cyclePreviewMode();

			case 3: // Show Animation Names
				showAnimNames = !showAnimNames;
				settingsOptions[3] = "Show Animation Names: " + (showAnimNames ? "ON" : "OFF");
				refreshSettingsList();
				updatePreview();
				FlxG.sound.play(Paths.sound('menus/scrollMenu'));

			case 4: // Edit Animations
				// NUEVO: Abrir editor de animaciones
				FlxG.sound.play(Paths.sound('menus/confirmMenu'));
				openAnimationEditor();

			case 5: // Refresh Skins List
				initialize();
				FlxG.sound.play(Paths.sound('menus/confirmMenu'));
				showNotification("Lists refreshed!");
		}
	}

	// NUEVO: Editor de animaciones
	function openAnimationEditor():Void
	{
		// TODO: Implementar editor completo
		// Por ahora, mostrar info y permitir cambiar algunas animaciones básicas
		showNotification("Animation Editor - Coming Soon!");
		
		// Obtener skin actual
		var skin = currentTab == 0 ? noteSkins[curSelected] : null;
		var splash = currentTab == 1 ? noteSplashes[curSelected] : null;
		
		if (skin != null)
		{
			var skinData = NoteSkinSystem.getSkinInfo(skin);
			trace('Current skin animations: ${skinData.animations}');
		}
		
		if (splash != null)
		{
			var splashData = NoteSkinSystem.getSplashInfo(splash);
			trace('Current splash animations: ${splashData.animations}');
		}
	}

	function cyclePreviewMode():Void
	{
		switch (previewMode)
		{
			case STATIC:
				previewMode = ANIMATED;
				settingsOptions[2] = "Preview Mode: Animated";
			case ANIMATED:
				previewMode = GAMEPLAY;
				settingsOptions[2] = "Preview Mode: Gameplay";
			case GAMEPLAY:
				previewMode = STATIC;
				settingsOptions[2] = "Preview Mode: Static";
		}

		refreshSettingsList();
		updatePreview();
		FlxG.sound.play(Paths.sound('menus/scrollMenu'));
	}

	function refreshSettingsList():Void
	{
		grpSettings.clear();
		for (i in 0...settingsOptions.length)
		{
			var settingLabel = new Alphabet(0, 120 + (i * 70), settingsOptions[i], false, false);
			settingLabel.isMenuItem = true;
			settingLabel.targetY = i;
			grpSettings.add(settingLabel);
		}
		changeSelection(0);
	}

	function showNotification(text:String):Void
	{
		var notif = new FlxText(0, 320, FlxG.width, text, 32);
		notif.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.LIME, CENTER, OUTLINE, FlxColor.BLACK);
		notif.borderSize = 3;
		notif.alpha = 0;
		add(notif);

		FlxTween.tween(notif, {alpha: 1}, 0.3, {
			onComplete: function(twn:FlxTween)
			{
				new FlxTimer().start(1.8, function(tmr:FlxTimer)
				{
					FlxTween.tween(notif, {alpha: 0}, 0.3, {
						onComplete: function(twn:FlxTween)
						{
							notif.destroy();
						}
					});
				});
			}
		});
	}

	function updateStatsText():Void
	{
		var currentSkin = NoteSkinSystem.currentSkin;
		var currentSplash = NoteSkinSystem.currentSplash;
		statsText.text = 'Active: $currentSkin (Skin) | $currentSplash (Splash) | Available: ${noteSkins.length} skins, ${noteSplashes.length} splashes';
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		// Update preview animations
		if (currentTab == 0 && previewMode != STATIC)
		{
			updateNoteAnimations(elapsed);
		}

		// Navigation
		if (controls.BACK)
		{
			FlxG.sound.play(Paths.sound('menus/cancelMenu'));
			StateTransition.switchState(new OptionsMenuState());
		}

		if (controls.UP_P)
			changeSelection(-1);

		if (controls.DOWN_P)
			changeSelection(1);

		if (controls.LEFT_P)
			changeTab(-1);

		if (controls.RIGHT_P)
			changeTab(1);

		// Accept
		if (controls.ACCEPT)
		{
			if (currentTab == 0)
			{
				var selectedSkin:String = noteSkins[curSelected];
				NoteSkinSystem.setSkin(selectedSkin);
				FlxG.sound.play(Paths.sound('menus/confirmMenu'));
				highlightSelection(grpSkins, FlxColor.LIME);
				updateStatsText();
				updatePreview();
				showNotification('$selectedSkin selected!');
			}
			else if (currentTab == 1)
			{
				var selectedSplash:String = noteSplashes[curSelected];
				NoteSkinSystem.setSplash(selectedSplash);
				FlxG.sound.play(Paths.sound('menus/confirmMenu'));
				highlightSelection(grpSplashes, FlxColor.CYAN);
				updateStatsText();
				showNotification('$selectedSplash selected!');
			}
			else if (currentTab == 2)
			{
				executeSettingOption();
			}
		}

		// Test splash with SPACE
		#if !mobile
		if (FlxG.keys.justPressed.SPACE && currentTab == 1)
		{
			testSplash();
		}
		#end

		updateControlsText();
	}

	function updateNoteAnimations(elapsed:Float):Void
	{
		for (i in 0...4)
		{
			var note = previewNotes.members[i];

			if (previewMode == ANIMATED)
			{
				// Simple falling animation
				noteYPositions[i] += noteVelocities[i] * elapsed;

				if (noteYPositions[i] > STRUM_BASE_Y + 100)
				{
					noteYPositions[i] = 250;
				}

				note.y = noteYPositions[i];
			}
			else if (previewMode == GAMEPLAY)
			{
				// Simulate gameplay with hit timing
				autoPlayTimer += elapsed;

				noteYPositions[i] += noteVelocities[i] * elapsed;

				// Check if note hits strum
				if (Math.abs(noteYPositions[i] - STRUM_BASE_Y) < 20)
				{
					if (autoPlayTimer > 0.6)
					{
						previewStrums.members[i].animation.play('confirm', true);
						testSplashSingle(i);
						noteYPositions[i] = 250;
						autoPlayTimer = 0;
					}
				}
				else if (noteYPositions[i] > STRUM_BASE_Y + 100)
				{
					noteYPositions[i] = 250;
				}

				note.y = noteYPositions[i];
			}
		}
	}

	function highlightSelection(grp:FlxTypedGroup<Alphabet>, color:FlxColor):Void
	{
		for (item in grp.members)
		{
			FlxTween.cancelTweensOf(item);
			if (item.targetY == 0)
			{
				FlxTween.color(item, 0.3, FlxColor.WHITE, color, {
					onComplete: function(twn:FlxTween)
					{
						FlxTween.color(item, 0.3, color, FlxColor.WHITE);
					}
				});
			}
		}
	}

	function updateControlsText():Void
	{
		switch (currentTab)
		{
			case 0:
				controlsText.text = "↑↓ Navigate | ←→ Switch Tab | ENTER Select Skin | ESC Back";
			case 1:
				controlsText.text = "↑↓ Navigate | ←→ Switch Tab | ENTER Select Splash | SPACE Test All | ESC Back";
			case 2:
				controlsText.text = "↑↓ Navigate | ←→ Switch Tab | ENTER Execute Option | ESC Back";
		}
	}

	function changeSelection(change:Int = 0):Void
	{
		if (change != 0)
			FlxG.sound.play(Paths.sound('menus/scrollMenu'), 0.4);

		curSelected += change;

		var maxItems:Int = currentTab == 0 ? noteSkins.length : currentTab == 1 ? noteSplashes.length : settingsOptions.length;

		if (curSelected < 0)
			curSelected = maxItems - 1;
		if (curSelected >= maxItems)
			curSelected = 0;

		var grp:FlxTypedGroup<Alphabet> = currentTab == 0 ? grpSkins : currentTab == 1 ? grpSplashes : grpSettings;
		var bullShit:Int = 0;

		for (item in grp.members)
		{
			item.targetY = bullShit - curSelected;
			bullShit++;

			item.alpha = 0.5;

			if (item.targetY == 0)
			{
				item.alpha = 1;
			}
		}

		updatePreview();
	}

	function changeTab(change:Int = 0):Void
	{
		if (change != 0)
			FlxG.sound.play(Paths.sound('menus/scrollMenu'), 0.4);

		currentTab += change;

		if (currentTab < 0)
			currentTab = 2;
		if (currentTab > 2)
			currentTab = 0;

		// Update tab visuals
		var bullShit:Int = 0;
		for (item in grpTabs.members)
		{
			item.alpha = 0.5;
			if (bullShit == currentTab)
			{
				item.alpha = 1;
				// Animar el indicador
				FlxTween.tween(tabIndicator, {x: item.x, width: item.width}, 0.3, {ease: FlxEase.cubeOut});
			}
			bullShit++;
		}

		// Show/hide groups
		grpSkins.visible = (currentTab == 0);
		grpSplashes.visible = (currentTab == 1);
		grpSettings.visible = (currentTab == 2);

		// Set selection
		if (currentTab == 0)
		{
			curSelected = noteSkins.indexOf(NoteSkinSystem.currentSkin);
			if (curSelected == -1)
				curSelected = 0;
		}
		else if (currentTab == 1)
		{
			curSelected = noteSplashes.indexOf(NoteSkinSystem.currentSplash);
			if (curSelected == -1)
				curSelected = 0;
		}
		else
		{
			curSelected = 0;
		}

		changeSelection(0);
	}

	override function destroy()
	{
		if (noteAnimTimer != null)
			noteAnimTimer.cancel();

		super.destroy();
	}
}