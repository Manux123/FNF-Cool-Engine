package funkin.debug;

import flixel.math.FlxMath;
import funkin.gameplay.objects.character.Character.AnimData;
import funkin.gameplay.objects.character.Character.CharacterData;
import funkin.gameplay.objects.stages.Stage;
import funkin.states.MusicBeatState;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.FlxCamera;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxTimer;
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
import funkin.debug.ColorPickerWheel;
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
	public var daAnim:String = 'bf';
	var camFollow:FlxObject;
	var camHUD:FlxCamera;
	var camGame:FlxCamera;
	var camUI:FlxCamera; // cámara invisible cameras[0]: da coordenadas estables al mouse (zoom siempre 1)
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
	var offsetXStepper:FlxUINumericStepper;
	var offsetYStepper:FlxUINumericStepper;

	var velocityPlus:Float = 1;
	var gridBG:FlxSprite;
	var showGrid:Bool = true;

	// Mouse drag para offsets (click derecho)
	var isDraggingOffset:Bool = false;
	var dragLastX:Float = 0;
	var dragLastY:Float = 0;

	// Nombre original de la animación que se está editando.
	// null = modo "Add" (nueva animación). String = modo "Edit" (modificar existente).
	var editingAnimName:String = null;

	// Botón "Add Animation" — necesitamos referencia para cambiar su label
	var addAnimBtn:FlxButton;

	// Character data para exportar
	var characterData:CharacterData;
	var currentAnimData:Array<AnimData> = [];

	public var currentStage:Stage;

	// Icon preview
	var iconPreview:HealthIcon;
	var iconBG:FlxSprite;

	// Ruta de la carpeta FlxAnimate importada (assets/images/<char>/)
	var flxAnimateFolderPath:String = "";

	// ── Variables visuales ────────────────────────────────────────────────────
	// Panel oscuro detrás de la lista de offsets / controles (lado izquierdo)
	var leftPanel:FlxSprite;
	// Barra de header con nombre del personaje actual
	var charHeaderBg:FlxSprite;
	var charHeaderText:FlxText;
	// Barra de estado inferior (reemplaza textHelp flotante)
	var statusBar:FlxSprite;
	// Borde decorativo del panel UI derecho
	var uiPanelBg:FlxSprite;

	// Posición X de inicio fuera de pantalla para el slide-in del panel
	static inline var PANEL_HIDDEN_X:Float = 1500;

	// Fila de highlight para la animación seleccionada en la lista
	var animRowHighlight:FlxSprite;
	// Acento de color actual del estado (verde=ok, rojo=error, cyan=info)
	var statusAccentBar:FlxSprite;
	// Preview de healthBar en el HUD (esquina inferior, debajo del ícono)
	var hudHealthBar:FlxSprite;
	var hudHealthBarLabel:FlxText;
	var charDeathInput:FlxText;
	// Color actual seleccionado para la healthBar
	var currentHealthBarColor:FlxColor = FlxColor.fromString("#31B0D1");

	public function new(daAnim:String = 'bf')
	{
		super();
		this.daAnim = daAnim;
	}

	// ── create ───────────────────────────────────────────────────────────────

	override function create()
	{
		funkin.debug.themes.EditorTheme.load();
		FlxG.mouse.visible = true;
		FreeplayState.destroyFreeplayVocals();
		FlxG.sound.playMusic(Paths.music('configurator'));
		MainMenuState.musicFreakyisPlaying = false;

		camGame = new FlxCamera();
		camHUD = new FlxCamera();
		camHUD.bgColor.alpha = 0;

		// camUI es una cámara completamente transparente y vacía que se pone
		// en cameras[0] para que FlxG.mouse.x/y use siempre zoom=1.
		// Sin esto, cuando camGame tiene zoom != 1, flixel-ui calcula mal
		// las posiciones de click en FlxUIInputText y el HUD deja de responder.
		camUI = new FlxCamera();
		camUI.bgColor.alpha = 0;

		FlxG.cameras.reset(camUI); // cameras[0] → FlxG.camera = camUI (zoom 1 fijo)
		FlxG.cameras.add(camGame, false); // renders encima de camUI
		FlxG.cameras.add(camHUD, false); // renders encima de todo

		currentStage = new Stage('stage_week1');
		currentStage.cameras = [camGame];
		add(currentStage);

		layeringbullshit = new FlxTypedGroup<FlxSprite>();
		layeringbullshit.cameras = [camGame];
		add(layeringbullshit);

		setupUI();

		dumbTexts = new FlxTypedGroup<FlxText>();
		dumbTexts.cameras = [camHUD];

		// ── Panel oscuro izquierdo ────────────────────────────────────────────
		// Cubre el área de controles + lista de offsets
		leftPanel = new FlxSprite(0, 0);
		leftPanel.makeGraphic(340, FlxG.height, (funkin.debug.themes.EditorTheme.current.bgPanel & 0x00FFFFFF) | 0xCC000000);
		leftPanel.cameras = [camHUD];
		leftPanel.scrollFactor.set();
		add(leftPanel);

		// Borde derecho del panel izquierdo (línea accent cyan)
		var leftPanelBorder = new FlxSprite(340, 0);
		leftPanelBorder.makeGraphic(2, FlxG.height, funkin.debug.themes.EditorTheme.current.accent);
		leftPanelBorder.cameras = [camHUD];
		leftPanelBorder.scrollFactor.set();
		add(leftPanelBorder);

		// ── Header del personaje (arriba del panel izquierdo) ─────────────────
		charHeaderBg = new FlxSprite(0, 0);
		charHeaderBg.makeGraphic(340, 36, funkin.debug.themes.EditorTheme.current.accent);
		charHeaderBg.cameras = [camHUD];
		charHeaderBg.scrollFactor.set();
		add(charHeaderBg);

		charHeaderText = new FlxText(8, 6, 330, '', 16);
		charHeaderText.color = funkin.debug.themes.EditorTheme.current.bgDark;
		charHeaderText.cameras = [camHUD];
		charHeaderText.scrollFactor.set();
		charHeaderText.font = "VCR OSD Mono";
		add(charHeaderText);

		// ── Fila de highlight de la animación seleccionada ────────────────────
		animRowHighlight = new FlxSprite(4, 0);
		animRowHighlight.makeGraphic(332, 20, (funkin.debug.themes.EditorTheme.current.accent & 0x00FFFFFF) | 0x44000000);
		animRowHighlight.cameras = [camHUD];
		animRowHighlight.scrollFactor.set();
		animRowHighlight.visible = false;
		add(animRowHighlight);

		add(dumbTexts);

		// ── Textos de controles ───────────────────────────────────────────────
		var controlsBg = new FlxSprite(4, 40);
		controlsBg.makeGraphic(332, 85, 0x22FFFFFF);
		controlsBg.cameras = [camHUD];
		controlsBg.scrollFactor.set();
		add(controlsBg);

		textControls = new FlxText(8, 42, 328, '', 10);
		textControls.text = "W/S · Switch Anim   ARROWS · Offset (SHIFT=x10)\n" + "I/K · Cam Up/Down   J/L · Cam Left/Right\n"
			+ "SCROLL · Zoom   SPACE · Play   R · Reset   T · Ghost\n" + "RIGHT DRAG · Move Offset (SHIFT=x3)   ESC · Exit";
		textControls.setBorderStyle(FlxTextBorderStyle.OUTLINE, 0xFF0A0A0F, 1);
		textControls.color = funkin.debug.themes.EditorTheme.current.textSecondary;
		textControls.cameras = [camHUD];
		textControls.scrollFactor.set();
		add(textControls);

		// ── Texto de animación actual ─────────────────────────────────────────
		textAnim = new FlxText(8, 132, 330, '', 18);
		textAnim.setBorderStyle(FlxTextBorderStyle.OUTLINE, 0xFF0A0A0F, 2);
		textAnim.color = funkin.debug.themes.EditorTheme.current.accent;
		textAnim.cameras = [camHUD];
		textAnim.scrollFactor.set();
		add(textAnim);

		// ── Texto de offset / zoom ────────────────────────────────────────────
		textInfo = new FlxText(8, 154, 330, '', 12);
		textInfo.setBorderStyle(FlxTextBorderStyle.OUTLINE, 0xFF0A0A0F, 1);
		textInfo.color = funkin.debug.themes.EditorTheme.current.warning;
		textInfo.cameras = [camHUD];
		textInfo.scrollFactor.set();
		add(textInfo);

		// ── Barra de estado inferior ──────────────────────────────────────────
		statusBar = new FlxSprite(0, FlxG.height - 30);
		statusBar.makeGraphic(FlxG.width, 30, (funkin.debug.themes.EditorTheme.current.bgDark & 0x00FFFFFF) | 0xDD000000);
		statusBar.cameras = [camHUD];
		statusBar.scrollFactor.set();
		add(statusBar);

		// Acento de color en la barra de estado (izquierda, 4px)
		statusAccentBar = new FlxSprite(0, FlxG.height - 30);
		statusAccentBar.makeGraphic(4, 30, funkin.debug.themes.EditorTheme.current.accent);
		statusAccentBar.cameras = [camHUD];
		statusAccentBar.scrollFactor.set();
		add(statusAccentBar);

		textHelp = new FlxText(12, FlxG.height - 24, FlxG.width - 200, '', 12);
		textHelp.text = "TIP · Use the UI tabs to edit properties and animations";
		textHelp.setBorderStyle(FlxTextBorderStyle.OUTLINE, 0xFF0A0A0F, 1);
		textHelp.color = funkin.debug.themes.EditorTheme.current.accent;
		textHelp.cameras = [camHUD];
		textHelp.scrollFactor.set();
		add(textHelp);

		// ✨ Botón de tema en barra de estado (esquina inferior derecha)
		var _themeBtn = new flixel.ui.FlxButton(FlxG.width - 75, FlxG.height - 28, "\u2728 Theme", function()
		{
			openSubState(new funkin.debug.themes.ThemePickerSubState());
		});
		_themeBtn.cameras = [camHUD];
		_themeBtn.scrollFactor.set();
		add(_themeBtn);

		// ── Icon preview ──────────────────────────────────────────────────────
		var iconAreaX = FlxG.width - 340 + 5; // dentro del panel derecho no existe aún, lo ponemos en la barra inferior
		// Lo dejamos en la esquina inferior izquierda del status bar a la derecha
		var iconX = FlxG.width - 185;
		var iconY = FlxG.height - 185;

		iconBG = new FlxSprite(iconX - 10, iconY - 28);
		iconBG.makeGraphic(170, 162, (funkin.debug.themes.EditorTheme.current.bgDark & 0x00FFFFFF) | 0xEE000000);
		iconBG.cameras = [camHUD];
		add(iconBG);

		// Borde superior del recuadro del ícono (línea cyan)
		var iconTopBorder = new FlxSprite(iconX - 10, iconY - 28);
		iconTopBorder.makeGraphic(170, 2, funkin.debug.themes.EditorTheme.current.accent);
		iconTopBorder.cameras = [camHUD];
		add(iconTopBorder);

		var iconLabel = new FlxText(iconX - 10, iconY - 22, 170, "ICON PREVIEW", 10);
		iconLabel.alignment = CENTER;
		iconLabel.color = funkin.debug.themes.EditorTheme.current.accent;
		iconLabel.setBorderStyle(FlxTextBorderStyle.OUTLINE, 0xFF0A0A0F, 1);
		iconLabel.cameras = [camHUD];
		add(iconLabel);

		iconPreview = new HealthIcon('bf', false);
		iconPreview.setPosition(iconX, iconY - 8);
		iconPreview.cameras = [camHUD];
		iconPreview.scale.set(0.8, 0.8);
		add(iconPreview);

		// ── Preview de la healthBar en el HUD ─────────────────────────────────
		// Se muestra debajo del ícono, siempre visible con el color del personaje
		hudHealthBarLabel = new FlxText(iconX - 10, iconY + 150, 170, "HEALTH BAR", 10);
		hudHealthBarLabel.alignment = CENTER;
		hudHealthBarLabel.color = funkin.debug.themes.EditorTheme.current.accent;
		hudHealthBarLabel.setBorderStyle(FlxTextBorderStyle.OUTLINE, 0xFF0A0A0F, 1);
		hudHealthBarLabel.cameras = [camHUD];
		add(hudHealthBarLabel);

		hudHealthBar = new FlxSprite(iconX - 10, iconY + 164);
		hudHealthBar.loadGraphic(Paths.image("UI/healthBar"));
		hudHealthBar.setGraphicSize(168, 20);
		hudHealthBar.updateHitbox();
		hudHealthBar.cameras = [camHUD];
		hudHealthBar.color = currentHealthBarColor;
		add(hudHealthBar);

		// ── Slide-in del panel derecho al abrir ───────────────────────────────
		UI_box.x = PANEL_HIDDEN_X;
		uiPanelBg.x = PANEL_HIDDEN_X - 4;
		FlxTween.tween(UI_box, {x: FlxG.width - UI_box.width - 10}, 0.45, {ease: FlxEase.quartOut});
		FlxTween.tween(uiPanelBg, {x: FlxG.width - UI_box.width - 14}, 0.45, {ease: FlxEase.quartOut});

		// Fade-in del panel izquierdo
		leftPanel.alpha = 0;
		leftPanelBorder.alpha = 0;
		charHeaderBg.alpha = 0;
		charHeaderText.alpha = 0;
		FlxTween.tween(leftPanel, {alpha: 1}, 0.5, {ease: FlxEase.quartOut, startDelay: 0.1});
		FlxTween.tween(leftPanelBorder, {alpha: 1}, 0.5, {ease: FlxEase.quartOut, startDelay: 0.15});
		FlxTween.tween(charHeaderBg, {alpha: 1}, 0.4, {ease: FlxEase.quartOut, startDelay: 0.2});
		FlxTween.tween(charHeaderText, {alpha: 1}, 0.4, {ease: FlxEase.quartOut, startDelay: 0.25});

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

		// Panel oscuro detrás del tab menu (se crea aquí para poder referenciar el tamaño)
		uiPanelBg = new FlxSprite(UI_box.x - 4, UI_box.y - 4);
		uiPanelBg.makeGraphic(Std.int(UI_box.width) + 8, Std.int(UI_box.height) + 8, (funkin.debug.themes.EditorTheme.current.bgDark & 0x00FFFFFF) | 0xDD000000);
		uiPanelBg.cameras = [camHUD];
		add(uiPanelBg);

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

		var characters:Array<String> = funkin.gameplay.objects.character.CharacterList.getAllCharacters();

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
		playerCheckbox.callback = function()
		{
			if (char != null)
				char.flipX = playerCheckbox.checked;
		};
		tab.add(playerCheckbox);

		tab.add(new FlxText(10, 95, 0, "Death Character:", 10));
		charDeathInput = new FlxUIInputText(10, 108, 200, '', 8);
		tab.add(charDeathInput);
		var charDeathHint = new FlxText(10, 122, 280, "Ej: bf-dead  (empty = default)", 8);
		charDeathHint.color = FlxColor.BLACK;
		tab.add(charDeathHint);

		var refreshBtn = new FlxButton(10, 140, "Refresh Character", function()
		{
			displayCharacter(daAnim);
			loadCharacterData();
		});
		tab.add(refreshBtn);

		tab.add(new FlxButton(10, 170, "Reset Camera", function()
		{
			camFollow.setPosition(FlxG.width / 2, FlxG.height / 2);
			camGame.zoom = 1;
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

		var prefixHint = new FlxText(10, yPos + 14, 280, "FlxAnimate: name exact of símbol (SN)", 8);
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

		// Botón Add/Update — su label cambia según si estás editando o agregando
		addAnimBtn = new FlxButton(10, yPos, "Add Animation", function()
		{
			addNewAnimation();
		});
		tab.add(addAnimBtn);

		// Botón "New" — limpia los campos y vuelve a modo Add
		tab.add(new FlxButton(130, yPos, "New / Clear", function()
		{
			editingAnimName = null;
			animNameInput.text = "";
			animPrefixInput.text = "";
			animFramerateStepper.value = 24;
			animLoopedCheckbox.checked = false;
			offsetXStepper.value = 0;
			offsetYStepper.value = 0;
			if (addAnimBtn != null)
				addAnimBtn.text = "Add Animation";
			setHelp("Cleared fields — Add mode", FlxColor.CYAN);
		}));
		yPos += 30;

		tab.add(new FlxButton(10, yPos, "Delete Current", function()
		{
			deleteCurrentAnimation();
		}));
		yPos += 30;

		tab.add(new FlxButton(10, yPos, "← Load Selected", function()
		{
			loadAnimIntoUI();
		}));

		var loadHint = new FlxText(10, yPos + 22, 280, "Load the selected animation (W/S) for editing", 8);
		loadHint.color = FlxColor.BLACK;
		tab.add(loadHint);

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

		var pathHint = new FlxText(10, yPos + 14, 280, "FlxAnimate: path to the character's folder", 8);
		pathHint.color = FlxColor.BLACK;
		tab.add(pathHint);
		yPos += 35;

		// Spritemap Name — solo relevante para FlxAnimate (por defecto "spritemap1")
		tab.add(new FlxText(10, yPos, 0, "Spritemap Name:", 10));
		yPos += 15;
		spritemapNameInput = new FlxUIInputText(10, yPos, 200, 'spritemap1', 8);
		tab.add(spritemapNameInput);

		var smHint = new FlxText(10, yPos + 14, 280, "FlxAnimate only · Default: spritemap1", 8);
		smHint.color = FlxColor.BLACK;
		tab.add(smHint);
		yPos += 35;

		// Health Icon
		tab.add(new FlxText(10, yPos, 0, "Health Icon:", 10));
		yPos += 15;
		healthIconInput = new FlxUIInputText(10, yPos, 200, 'bf', 8);
		healthIconInput.callback = function(text:String, action:String)
		{
			updateIconPreview(text);
		};
		tab.add(healthIconInput);
		yPos += 25;

		// Health Bar Color — campo de texto + swatch clickeable que abre el picker
		tab.add(new FlxText(10, yPos, 0, "Health Bar Color:", 10));
		yPos += 15;
		healthBarColorInput = new FlxUIInputText(10, yPos, 155, '#31B0D1', 8);
		healthBarColorInput.callback = function(text:String, action:String)
		{
			try
			{
				var parsed = FlxColor.fromString(text);
				currentHealthBarColor = parsed;
				if (hudHealthBar != null)
					hudHealthBar.color = parsed;
			}
			catch (_)
			{
			}
		};
		tab.add(healthBarColorInput);

		// Swatch de color (cuadrado que muestra el color actual)
		// Es un FlxButton sin texto que abre el ColorPickerWheel
		var colorSwatchBtn = new FlxButton(170, yPos - 1, "", function()
		{
			// Parsear el color actual del input para pasárselo al picker
			var startColor = currentHealthBarColor;
			try
			{
				startColor = FlxColor.fromString(healthBarColorInput.text);
			}
			catch (_)
			{
			}

			var picker = new ColorPickerWheel(startColor);
			picker.onColorSelected = function(selectedColor:FlxColor)
			{
				currentHealthBarColor = selectedColor;
				var hex = "#" + selectedColor.toHexString(false, false).toUpperCase();
				healthBarColorInput.text = hex;
				if (hudHealthBar != null)
				{
					hudHealthBar.color = selectedColor;
					// Pequeño bounce en la healthBar del HUD como feedback
					FlxTween.cancelTweensOf(hudHealthBar.scale);
					hudHealthBar.scale.set(1, 1.3);
					FlxTween.tween(hudHealthBar.scale, {x: 1, y: 1}, 0.25, {ease: FlxEase.backOut});
				}
			};
			picker.cameras = [camHUD];
			openSubState(picker);
		});

		// Pintar el botón con el color actual y darle tamaño de swatch
		colorSwatchBtn.makeGraphic(28, 20, currentHealthBarColor);
		tab.add(colorSwatchBtn);

		var pickBtn = new FlxButton(202, yPos - 1, "Pick", function()
		{
			var startColor = currentHealthBarColor;
			try
			{
				startColor = FlxColor.fromString(healthBarColorInput.text);
			}
			catch (_)
			{
			}

			var picker = new ColorPickerWheel(startColor);
			picker.onColorSelected = function(selectedColor:FlxColor)
			{
				currentHealthBarColor = selectedColor;
				var hex = "#" + selectedColor.toHexString(false, false).toUpperCase();
				healthBarColorInput.text = hex;
				if (hudHealthBar != null)
				{
					hudHealthBar.color = selectedColor;
					FlxTween.cancelTweensOf(hudHealthBar.scale);
					hudHealthBar.scale.set(1, 1.3);
					FlxTween.tween(hudHealthBar.scale, {x: 1, y: 1}, 0.25, {ease: FlxEase.backOut});
				}
				// Actualizar el swatch del botón
				colorSwatchBtn.makeGraphic(28, 20, selectedColor);
			};
			picker.cameras = [camHUD];
			openSubState(picker);
		});
		tab.add(pickBtn);
		yPos += 30;

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
			if (isTxtCheckbox.checked)
			{
				isSpritesheetCheckbox.checked = false;
				isFlxAnimateCheckbox.checked = false;
			}
		};
		tab.add(isTxtCheckbox);
		yPos += 20;

		isSpritesheetCheckbox = new FlxUICheckBox(10, yPos, null, null, "Spritesheet JSON", 150);
		isSpritesheetCheckbox.checked = false;
		isSpritesheetCheckbox.callback = function()
		{
			if (isSpritesheetCheckbox.checked)
			{
				isTxtCheckbox.checked = false;
				isFlxAnimateCheckbox.checked = false;
			}
		};
		tab.add(isSpritesheetCheckbox);
		yPos += 20;

		isFlxAnimateCheckbox = new FlxUICheckBox(10, yPos, null, null, "FlxAnimate (Adobe Animate)", 200);
		isFlxAnimateCheckbox.checked = false;
		isFlxAnimateCheckbox.callback = function()
		{
			if (isFlxAnimateCheckbox.checked)
			{
				isTxtCheckbox.checked = false;
				isSpritesheetCheckbox.checked = false;
			}
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

		tab.add(new FlxButton(10, yPos, "Import Sprite PNG", function()
		{
			browseForFile("sprite");
		}));

		tab.add(new FlxText(10, yPos + 22, 280, "Automatically detects XML/TXT", 8));
		yPos += 50;

		// ── FlxAnimate ──
		var flxLabel = new FlxText(10, yPos, 0, "FlxAnimate (Adobe Animate):", 12);
		flxLabel.color = FlxColor.ORANGE;
		flxLabel.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 1);
		tab.add(flxLabel);
		yPos += 20;

		tab.add(new FlxText(10, yPos, 0, "Select the PNG spritemap.\nAutomatically detects spritemap.json and Animation.json\nfrom the same folder.", 9));
		yPos += 40;

		tab.add(new FlxButton(10, yPos, "Import FlxAnimate", function()
		{
			browseForFlxAnimate();
		}));
		yPos += 30;

		// Listar símbolos disponibles en Animation.json
		tab.add(new FlxButton(10, yPos, "List Symbols (Console)", function()
		{
			listAvailableSymbols();
		}));

		var symHint = new FlxText(10, yPos + 22, 280, "Shows the available SNs to use as a 'prefix''", 8);
		symHint.color = FlxColor.BLACK;
		tab.add(symHint);
		yPos += 50;

		// ── Health Icon ──
		var iconTitle = new FlxText(10, yPos, 0, "Health Icon:", 12);
		iconTitle.color = FlxColor.LIME;
		iconTitle.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 1);
		tab.add(iconTitle);
		yPos += 20;

		tab.add(new FlxButton(10, yPos, "Import Icon PNG", function()
		{
			browseForFile("icon");
		}));
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

		tab.add(new FlxButton(10, yPos, "Export JSON", function()
		{
			exportCharacterJSON();
		}));
		yPos += 35;
		tab.add(new FlxButton(10, yPos, "Export Offsets TXT", function()
		{
			exportOffsetsTXT();
		}));
		yPos += 35;
		tab.add(new FlxButton(10, yPos, "Copy JSON", function()
		{
			copyJSONToClipboard();
		}));
		yPos += 40;

		tab.add(new FlxText(10, yPos, 280,
			"Export JSON: Saves all character data\n" + "Offsets TXT: Only animation offsets\n" + "Copy JSON: Copies to clipboard", 10));

		UI_box.addGroup(tab);
	}

	// ── Lógica de animaciones ─────────────────────────────────────────────────

	function addNewAnimation():Void
	{
		var newName = animNameInput.text.trim();
		var newPrefix = animPrefixInput.text.trim();

		if (newName == "" || newPrefix == "")
		{
			setHelp("✗ Name and prefix are required!", FlxColor.RED);
			return;
		}

		var newAnim:AnimData = {
			name: newName,
			prefix: newPrefix,
			framerate: animFramerateStepper.value,
			looped: animLoopedCheckbox.checked,
			offsetX: offsetXStepper.value,
			offsetY: offsetYStepper.value
		};

		if (editingAnimName != null)
		{
			// ── Modo EDIT: actualizar la animación cuyo nombre original es editingAnimName ──
			var found = false;
			for (i in 0...currentAnimData.length)
			{
				if (currentAnimData[i].name == editingAnimName)
				{
					currentAnimData[i] = newAnim;
					found = true;
					break;
				}
			}

			if (!found)
			{
				// Por si acaso no existía, agregarla
				currentAnimData.push(newAnim);
			}

			reloadCharacterWithNewAnims();
			setHelp("✓ Animation updated: " + newName, FlxColor.LIME);

			// Mantener la selección apuntando a la anim recién editada
			var newIdx = animList.indexOf(newName);
			if (newIdx >= 0)
				curAnim = newIdx;

			// Volver a modo Add
			editingAnimName = null;
			if (addAnimBtn != null)
				addAnimBtn.text = "Add Animation";
		}
		else
		{
			// ── Modo ADD: nunca sobreescribir, error si el nombre ya existe ──
			var alreadyExists = false;
			for (anim in currentAnimData)
			{
				if (anim.name == newName)
				{
					alreadyExists = true;
					break;
				}
			}

			if (alreadyExists)
			{
				setHelp('✗ "' + newName + '" it already exists — use "← Load Selected" to edit it', FlxColor.RED);
				return;
			}

			currentAnimData.push(newAnim);
			reloadCharacterWithNewAnims();
			setHelp("✓ Animation add: " + newName, FlxColor.LIME);
		}

		// Limpiar campos tras Add (no tras Edit, para comodidad)
		if (editingAnimName == null)
		{
			animNameInput.text = "";
			animPrefixInput.text = "";
		}
	}

	/**
	 * Rellena los campos del tab Animation con los datos de la animación
	 * seleccionada actualmente (curAnim). Así puedes editar cualquier anim
	 * sin tener que escribir todo desde cero.
	 */
	function loadAnimIntoUI():Void
	{
		if (animList.length == 0 || curAnim < 0 || curAnim >= animList.length)
		{
			setHelp("⚠ No animation selected", FlxColor.BLACK);
			return;
		}

		var animName = animList[curAnim];

		for (anim in currentAnimData)
		{
			if (anim.name == animName)
			{
				animNameInput.text = anim.name;
				animPrefixInput.text = anim.prefix != null ? anim.prefix : "";
				animFramerateStepper.value = anim.framerate != 0 ? anim.framerate : 24;
				animLoopedCheckbox.checked = anim.looped;
				offsetXStepper.value = anim.offsetX;
				offsetYStepper.value = anim.offsetY;

				// Entrar en modo EDIT — guardar qué anim estamos modificando
				editingAnimName = animName;
				if (addAnimBtn != null)
					addAnimBtn.text = "Update Anim";

				setHelp('← Editing: $animName  |  "New / Clear" for cancel', FlxColor.CYAN);
				UI_box.selected_tab_id = "Animation";
				return;
			}
		}

		setHelp("⚠ Animation not found in dates", FlxColor.BLACK);
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
		setHelp("✓ Animation erased: " + animName, FlxColor.LIME);

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
				fileDialog.onSelect.add(function(path)
				{
					onSpriteSelected(path);
				});
				fileDialog.browse(OPEN, "png", null, "Select Sprite PNG");
			case "icon":
				fileDialog.onSelect.add(function(path)
				{
					onFileSelected(path, "icon");
				});
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
			var baseName = haxe.io.Path.withoutExtension(fileName);

			var destDir = Paths.resolve("characters/images/");
			if (!FileSystem.exists(destDir))
				FileSystem.createDirectory(destDir);

			File.copy(sourcePath, destDir + fileName);

			var xmlPath = sourceDir + baseName + ".xml";
			var txtPath = sourceDir + baseName + ".txt";

			if (FileSystem.exists(xmlPath))
			{
				File.copy(xmlPath, destDir + baseName + ".xml");
				setHelp("✓ PNG + XML importeds", FlxColor.LIME);
			}
			else if (FileSystem.exists(txtPath))
			{
				File.copy(txtPath, destDir + baseName + ".txt");
				isTxtCheckbox.checked = true;
				setHelp("✓ PNG + TXT importeds", FlxColor.LIME);
			}
			else
			{
				setHelp("⚠ PNG imported (not found XML/TXT)", FlxColor.BLACK);
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
			var destDir = (fileType == "icon") ? Paths.resolve("icons/") : Paths.resolve("characters/images/");
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

			setHelp("✓ " + newFileName + " imported!", FlxColor.LIME);
		}
		catch (err:Dynamic)
		{
			setHelp("✗ Error importing: " + err, FlxColor.RED);
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
		fileDialog.onSelect.add(function(path:String)
		{
			onFlxAnimateSelected(path);
		});
		fileDialog.browse(OPEN, "png", null, "Select Spritemap PNG (FlxAnimate)");
		#else
		FlxG.log.warn("File import only available on desktop");
		#end
	}

	function onFlxAnimateSelected(sourcePngPath:String):Void
	{
		#if sys
		try
		{
			var fileName = haxe.io.Path.withoutDirectory(sourcePngPath);
			var sourceDir = haxe.io.Path.directory(sourcePngPath) + "/";
			var baseName = haxe.io.Path.withoutExtension(fileName); // ej: "spritemap1"

			// Rutas que esperamos encontrar junto al PNG
			var atlasJsonSrc = sourceDir + baseName + ".json"; // spritemap1.json
			var animJsonSrc = sourceDir + "Animation.json";

			if (!FileSystem.exists(atlasJsonSrc))
			{
				setHelp("✗ Not found " + baseName + ".json next to PNG", FlxColor.RED);
				return;
			}

			// Destino: assets/characters/images/<daAnim>/
			// Coincide con Paths.characterFolder(daAnim)
			var destFolder = Paths.resolve('characters/images/$daAnim/');
			if (!FileSystem.exists(destFolder))
				FileSystem.createDirectory(destFolder);

			// Copiar los tres archivos
			File.copy(sourcePngPath, destFolder + fileName);
			FlxG.log.notice("Copied: " + destFolder + fileName);

			File.copy(atlasJsonSrc, destFolder + baseName + ".json");
			FlxG.log.notice("Copied: " + destFolder + baseName + ".json");

			var hasAnimJson = FileSystem.exists(animJsonSrc);
			if (hasAnimJson)
			{
				File.copy(animJsonSrc, destFolder + "Animation.json");
				FlxG.log.notice("Copied: " + destFolder + "Animation.json");
			}

			// Actualizar UI:
			// - path = nombre del personaje (ej: "myChar"), NO la ruta completa
			//   Character.hx lo convierte con Paths.characterFolder(path)
			// - spritemapName = nombre del PNG sin extensión (ej: "spritemap1")
			flxAnimateFolderPath = destFolder;
			pathInput.text = daAnim; // ← solo el nombre del personaje
			spritemapNameInput.text = baseName;
			isFlxAnimateCheckbox.checked = true;
			isTxtCheckbox.checked = false;
			isSpritesheetCheckbox.checked = false;

			// Auto-cargar animaciones desde Animation.json si existe
			if (hasAnimJson)
				loadAnimationsFromAnimationJson(destFolder + "Animation.json");

			var msg = "✓ FlxAnimate imported in " + destFolder;
			if (!hasAnimJson)
				msg += "\n⚠ No Animation.json — add animations manually";
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
					name: parsed.AN.SN,
					prefix: parsed.AN.SN,
					framerate: parsed.MD != null ? Std.int(parsed.MD.FRT) : 24,
					looped: true,
					offsetX: 0,
					offsetY: 0
				});
			}

			// Registrar todos los símbolos del diccionario
			if (parsed.SD != null && parsed.SD.S != null)
			{
				for (sym in (cast parsed.SD.S : Array<Dynamic>))
				{
					currentAnimData.push({
						name: sym.SN,
						prefix: sym.SN,
						framerate: parsed.MD != null ? Std.int(parsed.MD.FRT) : 24,
						looped: false,
						offsetX: 0,
						offsetY: 0
					});
				}
			}

			FlxG.log.notice('[AnimDebug] Loaded ' + currentAnimData.length + ' simbols of Animation.json');
			reloadCharacterWithNewAnims();
		}
		catch (e:Dynamic)
		{
			FlxG.log.error('[AnimDebug] Error reading Animation.json: ' + e);
			setHelp("✗ Error reading Animation.json: " + e, FlxColor.RED);
		}
		#end
	}

	/**
	 * Lista en consola todos los símbolos (SN) disponibles en el Animation.json
	 * del personaje actual. Útil para saber qué poner como "prefix" en cada animación.
	 */
	function listAvailableSymbols():Void
	{
		// Fallback: parsear Animation.json directamente
		#if sys
		var animJsonPath = flxAnimateFolderPath != "" ? flxAnimateFolderPath + "Animation.json" : Paths.characterFolder(pathInput.text) + "Animation.json";

		if (!FileSystem.exists(animJsonPath))
		{
			setHelp("⚠ Not found Animation.json in: " + animJsonPath, FlxColor.BLACK);
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
				trace("  [SD] Símbols of diccionary:");
				for (sym in (cast parsed.SD.S : Array<Dynamic>))
					trace("    - " + sym.SN);
			}
			else
				trace("  (No Symbol Dictionary)");

			trace("═══════════════════════════════════════════");
			setHelp("✓ Símbols listed in console", FlxColor.LIME);
		}
		catch (e:Dynamic)
		{
			setHelp("✗ Error reading Animation.json: " + e, FlxColor.RED);
		}
		#else
		setHelp("⚠ Only available in desktop", FlxColor.RED);
		#end
	}

	// ── Character display ─────────────────────────────────────────────────────

	function displayCharacter(character:String):Void
	{
		// Al cambiar de personaje, cancelar cualquier edición pendiente
		editingAnimName = null;
		if (addAnimBtn != null)
			addAnimBtn.text = "Add Animation";
		dumbTexts.forEach(function(text:FlxText)
		{
			dumbTexts.remove(text, true);
		});
		dumbTexts.clear();
		animList = [];

		if (char != null)
			layeringbullshit.remove(char);
		if (ghostChar != null)
			layeringbullshit.remove(ghostChar);

		ghostChar = new Character(0, 0, character);
		ghostChar.alpha = 0.5;
		ghostChar.screenCenter();
		ghostChar.debugMode = true;
		layeringbullshit.add(ghostChar);

		char = new Character(0, 0, character);
		char.screenCenter();
		char.debugMode = true;
		layeringbullshit.add(char);
		// NO sobreescribir flipX aquí — Character.hx ya lo aplica desde el JSON.
		// loadCharacterData() actualizará el checkbox y sincronizará tras esto.

		// Actualizar header con el nombre del personaje
		if (charHeaderText != null)
		{
			charHeaderText.text = "  ▶  " + daAnim.toUpperCase();
			// Pequeño bounce en el header
			FlxTween.cancelTweensOf(charHeaderText);
			charHeaderText.alpha = 0;
			FlxTween.tween(charHeaderText, {alpha: 1}, 0.3, {ease: FlxEase.quartOut});
		}

		generateOffsetTexts();
	}

	function generateOffsetTexts(pushList:Bool = true):Void
	{
		var daLoop = 0;
		var startY = 174;
		var rowH = 20;

		for (anim => offsets in char.animOffsets)
		{
			var rowY = startY + (rowH * daLoop);
			var isCur = (daLoop == curAnim);

			// Fondo da fila alternado
			var rowBg = new FlxSprite(4, rowY);
			rowBg.makeGraphic(332, rowH - 1, isCur ? 0x5500E5FF : (daLoop % 2 == 0 ? 0x22FFFFFF : 0x11FFFFFF));
			rowBg.scrollFactor.set();
			rowBg.cameras = [camHUD];
			rowBg.alpha = 0;
			dumbTexts.add(cast rowBg);
			FlxTween.tween(rowBg, {alpha: 1}, 0.2, {startDelay: daLoop * 0.03, ease: FlxEase.quartOut});

			// Punto de color a la izquierda para la fila activa
			if (isCur)
			{
				var dot = new FlxSprite(4, rowY);
				dot.makeGraphic(4, rowH - 1, 0xFF00E5FF);
				dot.scrollFactor.set();
				dot.cameras = [camHUD];
				dumbTexts.add(cast dot);
			}

			var label = anim + "  [" + offsets[0] + ", " + offsets[1] + "]";
			var text = new FlxText(10, rowY + 3, 328, label, 11);
			text.scrollFactor.set();
			text.setBorderStyle(FlxTextBorderStyle.OUTLINE, 0xFF0A0A0F, 1);
			text.color = isCur ? 0xFF00E5FF : 0xFFCCCCCC;
			text.cameras = [camHUD];
			text.alpha = 0;
			dumbTexts.add(text);
			FlxTween.tween(text, {alpha: 1}, 0.2, {startDelay: daLoop * 0.03 + 0.05, ease: FlxEase.quartOut});

			if (pushList)
				animList.push(anim);

			daLoop++;
		}

		// Mover el highlight a la posición correcta
		if (animRowHighlight != null)
		{
			animRowHighlight.y = startY + (rowH * curAnim);
			animRowHighlight.visible = animList.length > 0;
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
			{
				playerCheckbox.checked = characterData.isPlayer;
				// Sincronizar flipX con el valor real del JSON
				if (char != null)
					char.flipX = characterData.isPlayer;
				if (ghostChar != null)
					ghostChar.flipX = characterData.isPlayer;
			}

			if (charDeathInput != null)
				charDeathInput.text = characterData.charDeath != null ? characterData.charDeath : "";

			if (isTxtCheckbox != null)
				isTxtCheckbox.checked = characterData.isTxt != null ? characterData.isTxt : false;

			if (isSpritesheetCheckbox != null)
				isSpritesheetCheckbox.checked = characterData.isSpritemap != null ? characterData.isSpritemap : false;

			var usingFlxAnimate = characterData.isFlxAnimate != null ? characterData.isFlxAnimate : false;
			if (isFlxAnimateCheckbox != null)
				isFlxAnimateCheckbox.checked = usingFlxAnimate;

			if (spritemapNameInput != null)
			{
				spritemapNameInput.text = (characterData.spritemapName != null && characterData.spritemapName != "") ? characterData.spritemapName : "spritemap1";
				spritemapNameInput.color = usingFlxAnimate ? FlxColor.BLACK : FlxColor.WHITE;
			}

			if (healthIconInput != null)
			{
				healthIconInput.text = characterData.healthIcon != null ? characterData.healthIcon : daAnim;
				updateIconPreview(healthIconInput.text);
			}

			if (healthBarColorInput != null)
			{
				var colorStr = characterData.healthBarColor != null ? characterData.healthBarColor : "#31B0D1";
				healthBarColorInput.text = colorStr;
				try
				{
					currentHealthBarColor = FlxColor.fromString(colorStr);
					if (hudHealthBar != null)
						hudHealthBar.color = currentHealthBarColor;
				}
				catch (_)
				{
				}
			}

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

		if (isFlxAnimateCheckbox.checked)
		{
			tempData.isFlxAnimate = true;
			var sm = spritemapNameInput.text.trim();
			if (sm != "" && sm != "spritemap1")
				tempData.spritemapName = sm;
		}

		if (charDeathInput != null && charDeathInput.text.trim() != "")
			tempData.charDeath = charDeathInput.text.trim();

		var jsonString = Json.stringify(tempData, null, '\t');

		#if sys
		try
		{
			if (!FileSystem.exists(Paths.resolve('characters/')))
				FileSystem.createDirectory(Paths.resolve('characters/'));

			File.saveContent(Paths.resolve('characters/' + daAnim + '.json'), jsonString);
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

		if (charDeathInput != null && charDeathInput.text.trim() != "")
			exportData.charDeath = charDeathInput.text.trim();

		return exportData;
	}

	function exportCharacterJSON():Void
	{
		var jsonString = Json.stringify(buildExportData(), null, '\t');

		_file = new FileReference();
		_file.addEventListener(Event.COMPLETE, onSaveComplete);
		_file.addEventListener(Event.CANCEL, onSaveCancel);
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
			_file.addEventListener(Event.CANCEL, onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file.save(data.trim(), daAnim + "Offsets.txt");
		}
	}

	function copyJSONToClipboard():Void
	{
		var jsonString = Json.stringify(buildExportData(), null, '\t');
		#if desktop
		lime.system.Clipboard.text = jsonString;
		setHelp("✓ JSON copied to clipboard!", FlxColor.LIME);
		#else
		FlxG.log.warn("Clipboard not supported on this platform");
		#end
	}

	// ── File save events ──────────────────────────────────────────────────────

	function onSaveComplete(_):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		setHelp("✓ File saved!", FlxColor.LIME);
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
		setHelp("✗ Error saving file!", FlxColor.RED);
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
		textAnim.text = "▶  " + curAnimName + "  [" + (curAnim + 1) + "/" + animList.length + "]";

		if (animList.length > 0 && curAnim >= 0 && curAnim < animList.length)
		{
			var offsets = char.animOffsets.get(animList[curAnim]);
			if (offsets != null)
				textInfo.text = "Offset: [" + offsets[0] + ", " + offsets[1] + "]   Zoom: " + FlxMath.roundDecimal(camGame.zoom, 2);
		}

		// Mover el highlight a la fila activa (lerp suave)
		if (animRowHighlight != null && animList.length > 0)
		{
			var targetY = 174.0 + (20.0 * curAnim);
			animRowHighlight.y += (targetY - animRowHighlight.y) * 0.25;
			animRowHighlight.visible = true;
		}

		if (ghostChar != null)
			ghostChar.flipX = char.flipX;

		// Exit — ESC siempre funciona aunque estés escribiendo
		if (FlxG.keys.justPressed.ESCAPE)
		{
			FlxG.mouse.visible = false;
			LoadingState.loadAndSwitchState(new MainMenuState());
		}

		// ── Zoom con rueda del mouse (siempre activo, no requiere teclado) ────
		if (FlxG.mouse.wheel != 0 && !isMouseOverHUD())
		{
			camGame.zoom = Math.max(0.1, camGame.zoom + FlxG.mouse.wheel * 0.1);
		}

		// ── Todo lo demás se bloquea si el usuario está escribiendo en un campo ─
		if (isTyping())
			return;

		// Reset camera
		if (FlxG.keys.justPressed.R)
		{
			camFollow.setPosition(FlxG.width / 2, FlxG.height / 2);
			camGame.zoom = 1;
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
			if (curAnim < 0)
				curAnim = animList.length - 1;
		}
		if (FlxG.keys.justPressed.S)
		{
			curAnim++;
			if (curAnim >= animList.length)
				curAnim = 0;
		}

		if (FlxG.keys.justPressed.S || FlxG.keys.justPressed.W || FlxG.keys.justPressed.SPACE)
		{
			if (animList.length > 0 && curAnim >= 0 && curAnim < animList.length)
			{
				char.playAnim(animList[curAnim]);
				if (ghostChar != null)
					ghostChar.playAnim(animList[0]);
				updateOffsetTexts();

				// Bounce visual en el texto de animación
				FlxTween.cancelTweensOf(textAnim);
				textAnim.scale.set(1.15, 1.15);
				FlxTween.tween(textAnim.scale, {x: 1, y: 1}, 0.25, {ease: FlxEase.backOut});

				// Solo auto-cargar en la UI si YA estábamos en modo Edit,
				// para no pisar lo que el usuario estaba escribiendo
				if (editingAnimName != null)
					loadAnimIntoUI();
			}
		}

		// ── Offset adjustment por teclado ─────────────────────────────────────
		var upP = FlxG.keys.anyJustPressed([UP]);
		var rightP = FlxG.keys.anyJustPressed([RIGHT]);
		var downP = FlxG.keys.anyJustPressed([DOWN]);
		var leftP = FlxG.keys.anyJustPressed([LEFT]);
		var mult = FlxG.keys.pressed.SHIFT ? 10 : 1;

		if ((upP || rightP || downP || leftP) && animList.length > 0 && curAnim >= 0 && curAnim < animList.length)
		{
			var selAnim = animList[curAnim];
			var offsets = char.animOffsets.get(selAnim);

			if (offsets != null)
			{
				if (upP)
					offsets[1] += 1 * mult;
				if (downP)
					offsets[1] -= 1 * mult;
				if (leftP)
					offsets[0] += 1 * mult;
				if (rightP)
					offsets[0] -= 1 * mult;

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
				if (ghostChar != null)
					ghostChar.playAnim(animList[0]);
				updateOffsetTexts();

				// Flash amarillo → normal en textInfo como feedback
				// NOTA: no se usa FlxTween.tween con {} vacío porque VarTween
				// explota al intentar leer propiedades nulas (crash en update).
				FlxTween.cancelTweensOf(textInfo);
				textInfo.color = 0xFFFFFFFF;
				new FlxTimer().start(0.3, function(_)
				{
					if (textInfo != null)
						textInfo.color = 0xFFFFE566;
				});
			}
		}

		// ── Offset adjustment por mouse (click derecho + arrastrar) ───────────
		// Click derecho: arrastrar para mover el offset de la animación actual.
		// La sensibilidad es 1px de mouse = 1px de offset (SHIFT = x3).
		if (!isMouseOverHUD())
		{
			var mouseMult = FlxG.keys.pressed.SHIFT ? 3 : 1;

			if (FlxG.mouse.justPressed)
			{
				isDraggingOffset = true;
				dragLastX = FlxG.mouse.screenX;
				dragLastY = FlxG.mouse.screenY;
			}

			if (isDraggingOffset && FlxG.mouse.pressed)
			{
				var dx = (FlxG.mouse.screenX - dragLastX) * mouseMult;
				var dy = (FlxG.mouse.screenY - dragLastY) * mouseMult;
				dragLastX = FlxG.mouse.screenX;
				dragLastY = FlxG.mouse.screenY;

				if ((Math.abs(dx) > 0 || Math.abs(dy) > 0) && animList.length > 0 && curAnim >= 0 && curAnim < animList.length)
				{
					var selAnim = animList[curAnim];
					var offsets = char.animOffsets.get(selAnim);

					if (offsets != null)
					{
						// Arrastrar derecha = offset X decrece (igual que flecha derecha)
						offsets[0] -= dx;
						offsets[1] -= dy;

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
						if (ghostChar != null)
							ghostChar.playAnim(animList[0]);
						updateOffsetTexts();
					}
				}
			}

			if (FlxG.mouse.justReleased)
				isDraggingOffset = false;
		}
		else
		{
			// Si el mouse está sobre la UI, cancelar drag para no interferir
			if (FlxG.mouse.justReleased)
				isDraggingOffset = false;
		}
	} // end update

	// ── Helpers ───────────────────────────────────────────────────────────────

	/**
	 * Devuelve true si el cursor está sobre cualquier elemento del HUD
	 * (panel izquierdo, panel UI derecho, barra inferior, área de ícono).
	 * Se usa para bloquear el drag de offsets cuando el usuario hace click
	 * sobre la interfaz en lugar del área de juego.
	 */
	function isMouseOverHUD():Bool
	{
		if (FlxG.mouse.overlaps(UI_box, camHUD))
			return true;
		if (FlxG.mouse.overlaps(leftPanel, camHUD))
			return true;
		if (FlxG.mouse.overlaps(statusBar, camHUD))
			return true;
		if (FlxG.mouse.overlaps(iconBG, camHUD))
			return true;
		return false;
	}

	function setHelp(msg:String, color:FlxColor):Void
	{
		if (textHelp != null)
		{
			textHelp.text = msg;
			textHelp.color = color;
		}

		// Pulsar el acento de la barra de estado con el color del mensaje
		if (statusAccentBar != null)
		{
			statusAccentBar.color = color;
			FlxTween.cancelTweensOf(statusAccentBar);
			statusAccentBar.alpha = 1;
			FlxTween.tween(statusAccentBar, {alpha: 0.4}, 1.2, {ease: FlxEase.quartOut, onComplete: function(_)
			{
				statusAccentBar.alpha = 0.4;
			}});
		}
	}

	/**
	 * Devuelve true si cualquier campo de texto tiene el foco actualmente.
	 * Se usa para bloquear los atajos de teclado mientras el usuario escribe.
	 */
	function isTyping():Bool
	{
		// FlxUIInputText tiene hasFocus cuando está activo
		if (animNameInput != null && animNameInput.hasFocus)
			return true;
		if (animPrefixInput != null && animPrefixInput.hasFocus)
			return true;
		if (pathInput != null && pathInput.hasFocus)
			return true;
		if (spritemapNameInput != null && spritemapNameInput.hasFocus)
			return true;
		if (healthIconInput != null && healthIconInput.hasFocus)
			return true;
		if (healthBarColorInput != null && healthBarColorInput.hasFocus)
			return true;
		return false;
	}
}
