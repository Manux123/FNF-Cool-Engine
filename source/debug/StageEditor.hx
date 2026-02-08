package debug;

import states.MusicBeatState;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.addons.display.FlxGridOverlay;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.addons.ui.*;
import flixel.math.FlxMath;
import openfl.net.FileReference;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.net.FileFilter;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import states.PlayState;
import flixel.ui.FlxButton;
import haxe.Json;
import lime.utils.Assets;
import sys.FileSystem;
import sys.io.File;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.group.FlxGroup;
import flixel.FlxBasic;

import objects.character.Character;
import states.MainMenuState;
import objects.stages.Stage;
import objects.character.CharacterList;

using StringTools;

/**
 * ═══════════════════════════════════════════════════════════════
 *                    STAGE EDITOR V3.3 - ASSET MANAGER
 * ═══════════════════════════════════════════════════════════════
 * 
 * NUEVAS FUNCIONALIDADES:
 * - 📝 Cambiar tipo de elemento (sprite, animated, group, etc.)
 * - 📁 Selector de archivos de imagen con importación automática
 * - 💾 Copia automática de archivos a assets/shared/images/stage/[stageName]/
 * - 🎨 Asset path actualizable manualmente
 * 
 * SISTEMA DE CÁMARAS DEL MOUSE:
 * - El mouse cambia automáticamente entre camHUD y camGame
 * - Cuando está sobre UI → camHUD (hitboxes perfectas en paneles)
 * - Cuando está en juego → camGame (selección y arrastre correcto)
 * 
 * FIXES PREVIOS:
 * - ✅ Panel derecho visible
 * - ✅ Hitboxes perfectas
 * - ✅ DELETE funcional
 * - ✅ Stage no se duplica
 * - ✅ Cambio fluido entre UI y juego
 * 
 * @version 3.3 Asset Manager
 */
class StageEditor extends MusicBeatState
{
	// ══════════════════════════════════════════════════════════════
	// CORE COMPONENTS
	// ══════════════════════════════════════════════════════════════
	
	var currentStage:Stage;
	var stageName:String = 'stage_week1';
	var stageData:StageData;
	
	var camGame:FlxCamera;
	var camHUD:FlxCamera;
	var camFollow:FlxObject;
	
	// ══════════════════════════════════════════════════════════════
	// UI COMPONENTS - DUAL PANEL SYSTEM
	// ══════════════════════════════════════════════════════════════
	
	// Panel izquierdo (Layers + Stage)
	var leftPanel:FlxSprite;
	var leftPanelWidth:Int = 300;
	var leftPanelVisible:Bool = true;
	var leftToggleBtn:SimpleButton;
	var leftContent:FlxGroup;
	
	// Panel derecho (Properties)
	var rightPanel:FlxSprite;
	var rightPanelWidth:Int = 300;
	var rightPanelVisible:Bool = true;
	var rightToggleBtn:SimpleButton;
	var rightContent:FlxGroup;
	
	// UI Elements
	var layerList:FlxTypedGroup<LayerItem>;
	var layerListY:Float = 200;
	var layerListHeight:Float = 400;
	var layerScroll:Float = 0;
	
	// Active inputs
	var activeInputs:Map<String, FlxUIInputText> = new Map();
	var activeSteppers:Map<String, FlxUINumericStepper> = new Map();
	
	// ══════════════════════════════════════════════════════════════
	// EDITOR STATE
	// ══════════════════════════════════════════════════════════════
	
	var selectedElement:StageElement = null;
	var selectedElementIndex:Int = -1;
	var selectedSprite:FlxSprite = null;
	
	var layerVisibility:Map<String, Bool> = new Map();
	var draggingElement:Bool = false;
	var dragOffset:Array<Float> = [0, 0];
	
	// Mouse camera management
	var currentMouseCamera:FlxCamera = null;
	
	// ══════════════════════════════════════════════════════════════
	// VISUAL HELPERS
	// ══════════════════════════════════════════════════════════════
	
	var gridBG:FlxSprite;
	var showGrid:Bool = true;
	
	var bfPlaceholder:Character;
	var dadPlaceholder:Character;
	var gfPlaceholder:Character;
	
	// ══════════════════════════════════════════════════════════════
	// INFO DISPLAYS
	// ══════════════════════════════════════════════════════════════
	
	var headerText:FlxText;
	var statusText:FlxText;
	var helpText:FlxText;
	
	var _file:FileReference;
	var _imageFile:FileReference; // Para seleccionar imágenes
	var selectedImagePath:String = ""; // Path temporal de la imagen seleccionada

	public function new(?stage:String = 'stage_week1')
	{
		super();
		stageName = stage;
	}
	
	override function create()
	{
		FlxG.mouse.visible = true;
		FlxG.mouse.useSystemCursor = true;
		FlxG.sound.playMusic(Paths.music('configurator'));
		states.FreeplayState.destroyFreeplayVocals();
		MainMenuState.musicFreakyisPlaying = false;
		
		// Cameras
		camGame = new FlxCamera();
		camHUD = new FlxCamera();
		camHUD.bgColor.alpha = 0;
		
		FlxG.cameras.reset(camGame);
		FlxG.cameras.add(camHUD, false);
		
		// Initialize mouse camera to game camera
		currentMouseCamera = camGame;
		
		// Grid background
		gridBG = FlxGridOverlay.create(50, 50, -1, -1, true, 0x22FFFFFF, 0x11000000);
		gridBG.scrollFactor.set(0.5, 0.5);
		add(gridBG);
		
		// Load stage
		loadStage(stageName);
		createPlaceholders();
		
		// Create UI
		createDualPanelUI();
		
		// Camera follow
		camFollow = new FlxObject(0, 0, 2, 2);
		camFollow.screenCenter();
		add(camFollow);
		camGame.follow(camFollow, LOCKON, 0.04);
		camGame.zoom = stageData.defaultZoom;
		
		super.create();
	}
	
	// ══════════════════════════════════════════════════════════════
	// STAGE MANAGEMENT
	// ══════════════════════════════════════════════════════════════
	
	function loadStage(name:String):Void
	{
		try
		{
			var file:String = Assets.getText(Paths.stageJSON(name));
			stageData = cast Json.parse(file);
			
			currentStage = new Stage(name);
			add(currentStage);
			
			if (stageData.elements != null)
			{
				for (i in 0...stageData.elements.length)
				{
					var elem = stageData.elements[i];
					if (elem.name != null)
						layerVisibility.set(elem.name, elem.visible != null ? elem.visible : true);
				}
			}
			
			trace("Stage loaded: " + name + " with " + stageData.elements.length + " elements");
		}
		catch (e:Dynamic)
		{
			trace("Could not load stage, creating new: " + e);
			createNewStage();
		}
	}
	
	function createNewStage():Void
	{
		stageData = {
			name: stageName,
			defaultZoom: 1.05,
			isPixelStage: false,
			elements: [],
			boyfriendPosition: [770, 450],
			dadPosition: [100, 100],
			gfPosition: [400, 130]
		};
		
		currentStage = new Stage(stageName);
		add(currentStage);
	}
	
	function reloadStage():Void
	{
		// Limpiar stage actual completamente
		if (currentStage != null)
		{
			remove(currentStage, true);
			currentStage.destroy();
			currentStage = null;
		}
		
		// Limpiar sprites seleccionados
		selectedSprite = null;
		
		// Garbage collection
		#if cpp
		cpp.vm.Gc.run(true);
		#end
		
		// Crear nuevo stage
		currentStage = new Stage(stageName);
		currentStage.stageData = stageData;
		currentStage.buildStage();
		
		// Insertar después del grid
		var insertIndex = members.indexOf(gridBG) + 1;
		
		// Asegurarse de insertar antes de los placeholders
		if (members.indexOf(bfPlaceholder) != -1)
		{
			insertIndex = Std.int(Math.min(insertIndex, members.indexOf(bfPlaceholder)));
		}
		
		insert(insertIndex, currentStage);
		
		// Actualizar UI
		updateLayerList();
		showNotification("Stage reloaded!");
	}
	
	function createPlaceholders():Void
	{
		bfPlaceholder = new Character(0, 0, 'bf', true);
		bfPlaceholder.alpha = 0.4;
		bfPlaceholder.setPosition(
			stageData.boyfriendPosition != null ? stageData.boyfriendPosition[0] : 770,
			stageData.boyfriendPosition != null ? stageData.boyfriendPosition[1] : 450
		);
		bfPlaceholder.dance();
		add(bfPlaceholder);
		
		dadPlaceholder = new Character(0, 0, 'dad');
		dadPlaceholder.alpha = 0.4;
		dadPlaceholder.setPosition(
			stageData.dadPosition != null ? stageData.dadPosition[0] : 100,
			stageData.dadPosition != null ? stageData.dadPosition[1] : 100
		);
		dadPlaceholder.dance();
		add(dadPlaceholder);
		
		gfPlaceholder = new Character(0, 0, 'gf');
		gfPlaceholder.alpha = 0.4;
		gfPlaceholder.setPosition(
			stageData.gfPosition != null ? stageData.gfPosition[0] : 400,
			stageData.gfPosition != null ? stageData.gfPosition[1] : 130
		);
		gfPlaceholder.dance();
		add(gfPlaceholder);
	}
	
	// ══════════════════════════════════════════════════════════════
	// DUAL PANEL UI CREATION
	// ══════════════════════════════════════════════════════════════
	
	function createDualPanelUI():Void
	{
		// ═══════════════════════════════════════════════════════════
		// PANEL IZQUIERDO (LAYERS + STAGE INFO)
		// ═══════════════════════════════════════════════════════════

		// Contenido izquierdo
		leftContent = new FlxGroup();
		leftContent.cameras = [camHUD];
		add(leftContent);
		
		leftPanel = new FlxSprite(0, 0);
		leftPanel.makeGraphic(leftPanelWidth, FlxG.height, 0xDD1a1a2e);
		leftPanel.scrollFactor.set();
		leftContent.add(leftPanel);
		
		// Borde derecho
		var leftBorder = new FlxSprite(leftPanelWidth, 0);
		leftBorder.makeGraphic(2, FlxG.height, 0xFF16213e);
		leftBorder.scrollFactor.set();
		leftContent.add(leftBorder);
		
		// Header izquierdo
		var leftHeader = new FlxSprite(0, 0);
		leftHeader.makeGraphic(leftPanelWidth, 50, 0xFF0f3460);
		leftHeader.scrollFactor.set();
		leftContent.add(leftHeader);
		
		var leftTitle = new FlxText(10, 15, leftPanelWidth - 60, "LAYERS", 18);
		leftTitle.setFormat(null, 18, FlxColor.WHITE, LEFT, OUTLINE, 0xFF000000);
		leftTitle.scrollFactor.set();
		leftContent.add(leftTitle);
		
		// Toggle button izquierdo
		leftToggleBtn = new SimpleButton(leftPanelWidth - 40, 10, 30, 30, "◄");
		leftToggleBtn.onClick = toggleLeftPanel;
		leftContent.add(leftToggleBtn);
		
		// Stage info compacto
		var stageInfo = new FlxText(10, 60, leftPanelWidth - 20, 'Stage: ${stageData.name}\nZoom: ${stageData.defaultZoom}\nElements: ${stageData.elements != null ? stageData.elements.length : 0}', 11);
		stageInfo.setFormat(null, 11, 0xFF888888, LEFT);
		stageInfo.scrollFactor.set();
		leftContent.add(stageInfo);
		
		// Separador
		var separator1 = new FlxSprite(10, 120);
		separator1.makeGraphic(leftPanelWidth - 20, 1, 0xFF444444);
		separator1.scrollFactor.set();
		leftContent.add(separator1);
		
		// Label de layers
		var layersLabel = new FlxText(10, 130, leftPanelWidth - 20, "LAYERS LIST:", 12);
		layersLabel.setFormat(null, 12, FlxColor.WHITE, LEFT);
		layersLabel.scrollFactor.set();
		leftContent.add(layersLabel);
		
		// Botón Add Element
		var addBtn = new SimpleButton(10, FlxG.height - 50, leftPanelWidth - 20, 40, "+ ADD ELEMENT");
		addBtn.onClick = addNewElement;
		leftContent.add(addBtn);
		
		// Botón Reload
		var reloadBtn = new SimpleButton(10, FlxG.height - 100, leftPanelWidth - 20, 40, "↻ RELOAD STAGE");
		reloadBtn.onClick = reloadStage;
		leftContent.add(reloadBtn);
		
		// Layer list
		layerList = new FlxTypedGroup<LayerItem>();
		leftContent.add(layerList);
		
		// ═══════════════════════════════════════════════════════════
		// PANEL DERECHO (PROPERTIES) - FIXED
		// ═══════════════════════════════════════════════════════════

		// Contenido derecho
		rightContent = new FlxGroup();
		rightContent.cameras = [camHUD];
		add(rightContent);
		
		rightPanel = new FlxSprite(FlxG.width - rightPanelWidth, 0);
		rightPanel.makeGraphic(rightPanelWidth, FlxG.height, 0xDD1a1a2e);
		rightPanel.scrollFactor.set();
		rightContent.add(rightPanel);
		
		// Borde izquierdo
		var rightBorder = new FlxSprite(FlxG.width - rightPanelWidth - 2, 0);
		rightBorder.makeGraphic(2, FlxG.height, 0xFF16213e);
		rightBorder.scrollFactor.set();
		rightContent.add(rightBorder);
		
		// Header derecho - FIXED: Ahora usa FlxG.width - rightPanelWidth
		var rightHeader = new FlxSprite(FlxG.width - rightPanelWidth, 0);
		rightHeader.makeGraphic(rightPanelWidth, 50, 0xFF0f3460);
		rightHeader.scrollFactor.set();
		rightContent.add(rightHeader);
		
		// Title derecho - FIXED: Ahora usa FlxG.width - rightPanelWidth
		var rightTitle = new FlxText(FlxG.width - rightPanelWidth + 50, 15, rightPanelWidth - 60, "PROPERTIES", 18);
		rightTitle.setFormat(null, 18, FlxColor.WHITE, LEFT, OUTLINE, 0xFF000000);
		rightTitle.scrollFactor.set();
		rightContent.add(rightTitle);
		
		// Toggle button derecho
		rightToggleBtn = new SimpleButton(FlxG.width - rightPanelWidth + 10, 10, 30, 30, "►");
		rightToggleBtn.onClick = toggleRightPanel;
		rightContent.add(rightToggleBtn);
		
		// ═══════════════════════════════════════════════════════════
		// STATUS BAR
		// ═══════════════════════════════════════════════════════════
		
		var statusBarBG = new FlxSprite(leftPanelWidth, FlxG.height - 30);
		statusBarBG.makeGraphic(FlxG.width - leftPanelWidth - rightPanelWidth, 30, 0xCC16213e);
		statusBarBG.cameras = [camHUD];
		statusBarBG.scrollFactor.set();
		add(statusBarBG);
		
		statusText = new FlxText(leftPanelWidth + 10, FlxG.height - 25, FlxG.width - leftPanelWidth - rightPanelWidth - 20, "", 12);
		statusText.setFormat(null, 12, FlxColor.WHITE, LEFT);
		statusText.cameras = [camHUD];
		statusText.scrollFactor.set();
		add(statusText);
		
		// ═══════════════════════════════════════════════════════════
		// HELP TEXT
		// ═══════════════════════════════════════════════════════════
		
		helpText = new FlxText(leftPanelWidth + 10, 10, FlxG.width - leftPanelWidth - rightPanelWidth - 20, "I/J/K/L - Camera | Q/E - Zoom | G - Grid | R - Reset | T - Reload | S - Save | ESC - Exit\nSelect images, change types, and manage assets in the Properties panel", 11);
		helpText.setFormat(null, 11, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		helpText.cameras = [camHUD];
		helpText.scrollFactor.set();
		add(helpText);
		
		// Initial update
		updateLayerList();
		updatePropertiesPanel();
	}
	
	// ══════════════════════════════════════════════════════════════
	// PANEL TOGGLE FUNCTIONS
	// ══════════════════════════════════════════════════════════════
	
	function toggleLeftPanel():Void
	{
		leftPanelVisible = !leftPanelVisible;
		
		var targetX = leftPanelVisible ? 0 : -leftPanelWidth;
		
		FlxTween.tween(leftPanel, {x: targetX}, 0.3, {ease: FlxEase.quadOut});
		FlxTween.tween(leftToggleBtn, {x: targetX + leftPanelWidth - 40}, 0.3, {ease: FlxEase.quadOut});
		
		leftToggleBtn.label.text = leftPanelVisible ? "◄" : "►";
		
		// Move all left content
		for (member in leftContent.members)
		{
			if (Std.isOfType(member, FlxSprite))
			{
				var sprite:FlxSprite = cast member;
				var offsetX = leftPanelVisible ? leftPanelWidth : 0;
				FlxTween.tween(sprite, {x: sprite.x - (leftPanelVisible ? -leftPanelWidth : leftPanelWidth)}, 0.3, {ease: FlxEase.quadOut});
			}
		}
	}
	
	function toggleRightPanel():Void
	{
		rightPanelVisible = !rightPanelVisible;
		
		var targetX = rightPanelVisible ? FlxG.width - rightPanelWidth : FlxG.width;
		
		FlxTween.tween(rightPanel, {x: targetX}, 0.3, {ease: FlxEase.quadOut});
		FlxTween.tween(rightToggleBtn, {x: targetX + 10}, 0.3, {ease: FlxEase.quadOut});
		
		rightToggleBtn.label.text = rightPanelVisible ? "►" : "◄";
		
		// Move all right content
		for (member in rightContent.members)
		{
			if (Std.isOfType(member, FlxSprite))
			{
				var sprite:FlxSprite = cast member;
				FlxTween.tween(sprite, {x: sprite.x + (rightPanelVisible ? -rightPanelWidth : rightPanelWidth)}, 0.3, {ease: FlxEase.quadOut});
			}
		}
	}
	
	// ══════════════════════════════════════════════════════════════
	// LAYER LIST
	// ══════════════════════════════════════════════════════════════
	
	function updateLayerList():Void
	{
		layerList.clear();
		
		if (stageData.elements == null) return;
		
		var startY:Float = layerListY;
		
		for (i in 0...stageData.elements.length)
		{
			var element = stageData.elements[i];
			var itemY = startY + (i * 45) - layerScroll;
			
			if (itemY > layerListY - 45 && itemY < layerListY + layerListHeight)
			{
				var item = new LayerItem(10, itemY, leftPanelWidth - 20, element, i);
				item.cameras = [camHUD];
				item.onSelect = function() { selectElement(i); };
				item.onToggleVis = function() { toggleLayerVisibility(element.name); };
				item.setSelected(i == selectedElementIndex);
				layerList.add(item);
			}
		}
	}
	
	// ══════════════════════════════════════════════════════════════
	// PROPERTIES PANEL
	// ══════════════════════════════════════════════════════════════
	
	function updatePropertiesPanel():Void
	{
		// Clear existing content but keep the panel background
		var membersToRemove:Array<FlxBasic> = [];
		for (member in rightContent.members)
		{
			if (member != rightPanel)
			{
				membersToRemove.push(member);
			}
		}
		
		for (member in membersToRemove)
		{
			rightContent.remove(member, true);
			if (member != null)
				member.destroy();
		}
		
		activeInputs.clear();
		activeSteppers.clear();
		
		if (selectedElement == null)
		{
			var noSelText = new FlxText(FlxG.width - rightPanelWidth + 20, 200, rightPanelWidth - 40, "No element selected\n\nClick on a layer\nto edit its properties", 14);
			noSelText.setFormat(null, 14, 0xFF666666, CENTER);
			noSelText.cameras = [camHUD];
			noSelText.scrollFactor.set(0, 0);
			rightContent.add(noSelText);
			return;
		}
		
		var contentX = FlxG.width - rightPanelWidth + 20;
		var contentY:Float = 70;
		var spacing:Float = 50;
		
		// Element name header
		var nameHeader = new FlxText(contentX, contentY, rightPanelWidth - 40, selectedElement.name != null ? selectedElement.name.toUpperCase() : "UNNAMED", 14);
		nameHeader.setFormat(null, 14, 0xFFe94560, LEFT);
		nameHeader.cameras = [camHUD];
		nameHeader.scrollFactor.set(0, 0);
		rightContent.add(nameHeader);
		
		// Name input
		contentY += 30;
		createPropLabel("Name", contentX, contentY);
		var nameInput = createPropInput(contentX, contentY + 20, selectedElement.name != null ? selectedElement.name : "");
		activeInputs.set("elementName", nameInput);
		
		// Type selector
		contentY += spacing;
		createPropLabel("Type", contentX, contentY);
		var typeDropdown = new FlxUIDropDownMenu(Std.int(contentX), Std.int(contentY + 20), 
			FlxUIDropDownMenu.makeStrIdLabelArray(["sprite", "animated", "group", "custom_class", "custom_class_group"], true),
			function(type:String) {
				selectedElement.type = type;
				showNotification("Type changed to: " + type);
				// Reload stage to apply changes
				reloadStage();
				selectElement(selectedElementIndex);
			});
		typeDropdown.selectedLabel = selectedElement.type;
		typeDropdown.cameras = [camHUD];
		typeDropdown.scrollFactor.set(0, 0);
		rightContent.add(typeDropdown);
		
		// Asset path
		contentY += spacing;
		createPropLabel("Asset Path", contentX, contentY);
		var assetInput = createPropInput(contentX, contentY + 20, selectedElement.asset != null ? selectedElement.asset : "");
		activeInputs.set("asset", assetInput);
		
		// Buttons row: Select image and Apply
		contentY += spacing;
		var buttonWidth = (rightPanelWidth - 45) / 2; // Dividir en 2 botones con espacio
		
		var selectImageBtn = new SimpleButton(contentX, Std.int(contentY), Std.int(buttonWidth), 30, "📁 SELECT");
		selectImageBtn.bgColor = 0xFF4a90e2;
		selectImageBtn.cameras = [camHUD];
		selectImageBtn.scrollFactor.set(0, 0);
		selectImageBtn.onClick = selectImageFile;
		rightContent.add(selectImageBtn);
		
		var applyBtn = new SimpleButton(contentX + buttonWidth + 5, Std.int(contentY), Std.int(buttonWidth), 30, "↻ APPLY");
		applyBtn.bgColor = 0xFF2ecc71;
		applyBtn.cameras = [camHUD];
		applyBtn.scrollFactor.set(0, 0);
		applyBtn.onClick = function() {
			reloadStage();
			selectElement(selectedElementIndex);
			showNotification("Changes applied!");
		};
		rightContent.add(applyBtn);
		
		// Position X
		contentY += spacing;
		createPropLabel("Position X", contentX, contentY);
		var xStepper = createPropStepper(contentX, contentY + 20, selectedElement.position[0], -5000, 5000, 1);
		activeSteppers.set("posX", xStepper);
		
		// Position Y
		contentY += spacing;
		createPropLabel("Position Y", contentX, contentY);
		var yStepper = createPropStepper(contentX, contentY + 20, selectedElement.position[1], -5000, 5000, 1);
		activeSteppers.set("posY", yStepper);
		
		// Z-Index
		contentY += spacing;
		createPropLabel("Z-Index", contentX, contentY);
		var zStepper = createPropStepper(contentX, contentY + 20, selectedElement.zIndex != null ? selectedElement.zIndex : 0, -100, 100, 1);
		activeSteppers.set("zIndex", zStepper);
		
		// Alpha
		contentY += spacing;
		createPropLabel("Alpha", contentX, contentY);
		var alphaStepper = createPropStepper(contentX, contentY + 20, selectedElement.alpha != null ? selectedElement.alpha : 1.0, 0, 1, 0.1);
		activeSteppers.set("alpha", alphaStepper);
		
		// Delete button
		contentY += spacing + 20;
		var deleteBtn = new SimpleButton(contentX, Std.int(contentY), rightPanelWidth - 40, 40, "✕ DELETE");
		deleteBtn.bgColor = 0xFFe94560;
		deleteBtn.cameras = [camHUD];
		deleteBtn.scrollFactor.set(0, 0);
		deleteBtn.onClick = deleteSelectedElement;
		rightContent.add(deleteBtn);
	}
	
	function createPropLabel(text:String, x:Float, y:Float):FlxText
	{
		var label = new FlxText(x, y, rightPanelWidth - 40, text, 11);
		label.setFormat(null, 11, 0xFF888888, LEFT);
		label.cameras = [camHUD];
		label.scrollFactor.set(0, 0);
		rightContent.add(label);
		return label;
	}
	
	// ══════════════════════════════════════════════════════════════
	// IMAGE FILE SELECTION
	// ══════════════════════════════════════════════════════════════
	
	function selectImageFile():Void
	{
		if (selectedElement == null) return;
		
		_imageFile = new FileReference();
		
		var imageFilter:FileFilter = new FileFilter("Image Files", "*.png;*.jpg;*.jpeg;*.bmp");
		
		_imageFile.addEventListener(Event.SELECT, onImageFileSelected);
		_imageFile.addEventListener(Event.CANCEL, onImageFileCancel);
		
		_imageFile.browse([imageFilter]);
	}
	
	function onImageFileSelected(e:Event):Void
	{
		_imageFile.removeEventListener(Event.SELECT, onImageFileSelected);
		_imageFile.removeEventListener(Event.CANCEL, onImageFileCancel);
		
		_imageFile.addEventListener(Event.COMPLETE, onImageFileLoaded);
		_imageFile.addEventListener(IOErrorEvent.IO_ERROR, onImageFileError);
		
		_imageFile.load();
	}
	
	function onImageFileLoaded(e:Event):Void
	{
		_imageFile.removeEventListener(Event.COMPLETE, onImageFileLoaded);
		_imageFile.removeEventListener(IOErrorEvent.IO_ERROR, onImageFileError);
		
		try
		{
			// Obtener el nombre del archivo sin extensión
			var fileName:String = _imageFile.name;
			var fileNameNoExt:String = fileName.substring(0, fileName.lastIndexOf('.'));
			var fileExt:String = fileName.substring(fileName.lastIndexOf('.'));
			
			// Determinar la ruta de destino basada en el stage
			// Por defecto: assets/shared/images/stage/[stageName]/
			#if sys
			var assetsPath:String = "assets/shared/images/stage/" + stageName + "/";
			
			// Crear el directorio si no existe
			if (!FileSystem.exists(assetsPath))
			{
				FileSystem.createDirectory(assetsPath);
				trace("Created directory: " + assetsPath);
			}
			
			// Guardar el archivo
			var destinationPath:String = assetsPath + fileName;
			File.saveBytes(destinationPath, _imageFile.data);
			
			// Actualizar el asset del elemento seleccionado
			// El path relativo para el juego sería: stageName/fileNameNoExt
			var assetPath:String = stageName + "/" + fileNameNoExt;
			selectedElement.asset = assetPath;
			
			// Actualizar el input de asset si existe
			if (activeInputs.exists("asset"))
			{
				activeInputs.get("asset").text = assetPath;
			}
			
			showNotification("Image imported: " + fileName);
			trace("Image saved to: " + destinationPath);
			trace("Asset path set to: " + assetPath);
			
			// Recargar el stage para mostrar la nueva imagen
			reloadStage();
			selectElement(selectedElementIndex);
			#else
			showNotification("File import only works in desktop builds!");
			#end
		}
		catch (e:Dynamic)
		{
			showNotification("Error importing image: " + e);
			trace("Error importing image: " + e);
		}
		
		_imageFile = null;
	}
	
	function onImageFileCancel(e:Event):Void
	{
		_imageFile.removeEventListener(Event.SELECT, onImageFileSelected);
		_imageFile.removeEventListener(Event.CANCEL, onImageFileCancel);
		_imageFile = null;
	}
	
	function onImageFileError(e:IOErrorEvent):Void
	{
		_imageFile.removeEventListener(Event.COMPLETE, onImageFileLoaded);
		_imageFile.removeEventListener(IOErrorEvent.IO_ERROR, onImageFileError);
		
		showNotification("Error loading image file!");
		trace("Error loading image: " + e);
		
		_imageFile = null;
	}
	
	function createPropInput(x:Float, y:Float, defaultValue:String):FlxUIInputText
	{
		var input = new FlxUIInputText(Std.int(x), Std.int(y), rightPanelWidth - 40, defaultValue, 12);
		input.cameras = [camHUD];
		input.scrollFactor.set(0, 0);
		input.backgroundColor = 0xFF2a2d3a;
		input.fieldBorderColor = 0xFF16213e;
		input.color = FlxColor.WHITE;
		rightContent.add(input);
		return input;
	}
	
	function createPropStepper(x:Float, y:Float, defaultValue:Float, min:Float, max:Float, step:Float):FlxUINumericStepper
	{
		var stepper = new FlxUINumericStepper(Std.int(x), Std.int(y), step, defaultValue, min, max, 2);
		stepper.cameras = [camHUD];
		stepper.scrollFactor.set(0, 0);
		rightContent.add(stepper);
		return stepper;
	}
	
	// ══════════════════════════════════════════════════════════════
	// ELEMENT SELECTION & EDITING
	// ══════════════════════════════════════════════════════════════
	
	function selectElement(index:Int):Void
	{
		if (index < 0 || index >= stageData.elements.length) return;
		
		selectedElementIndex = index;
		selectedElement = stageData.elements[index];
		
		if (selectedElement.name != null)
		{
			selectedSprite = currentStage.getElement(selectedElement.name);
			if (selectedSprite == null)
				selectedSprite = currentStage.getCustomClass(selectedElement.name);
		}
		
		updateLayerList();
		updatePropertiesPanel();
		
		statusText.text = 'Selected: ${selectedElement.name != null ? selectedElement.name : "unnamed"} (${selectedElement.type})';
	}
	
	function toggleLayerVisibility(name:String):Void
	{
		if (name == null) return;
		
		var isVisible = layerVisibility.exists(name) ? layerVisibility.get(name) : true;
		layerVisibility.set(name, !isVisible);
		
		for (elem in stageData.elements)
		{
			if (elem.name == name)
			{
				elem.visible = !isVisible;
				break;
			}
		}
		
		reloadStage();
	}
	
	function addNewElement():Void
	{
		var newElement:StageElement = {
			type: "sprite",
			name: "new_element_" + stageData.elements.length,
			asset: "stageback", // Asset por defecto
			position: [400, 300],
			scrollFactor: [1.0, 1.0],
			zIndex: 0,
			alpha: 1.0,
			visible: true
		};
		
		stageData.elements.push(newElement);
		reloadStage();
		selectElement(stageData.elements.length - 1);
		
		// Mostrar notificación
		showNotification("New element added! Click 'SELECT IMAGE' to choose a file.");
	}
	
	function deleteSelectedElement():Void
	{
		if (selectedElementIndex < 0 || selectedElementIndex >= stageData.elements.length) 
			return;
		
		// FIXED: Remover sprite del stage primero
		if (selectedSprite != null)
		{
			currentStage.remove(selectedSprite, true);
			selectedSprite.destroy();
			selectedSprite = null;
		}
		
		// Remover del array de datos
		stageData.elements.splice(selectedElementIndex, 1);
		
		// Limpiar selección
		selectedElement = null;
		selectedElementIndex = -1;
		
		// Recargar stage
		reloadStage();
		updatePropertiesPanel();
		
		showNotification("Element deleted!");
	}
	
	// ══════════════════════════════════════════════════════════════
	// UPDATE & INPUT
	// ══════════════════════════════════════════════════════════════
	
	override function update(elapsed:Float)
	{
		super.update(elapsed);
		
		// ═══════════════════════════════════════════════════════════
		// SISTEMA DE CAMBIO DE CÁMARA DEL MOUSE
		// ═══════════════════════════════════════════════════════════
		
		// Detectar si el mouse está sobre UI
		var mouseOverLeftPanel = leftPanelVisible && FlxG.mouse.screenX < leftPanelWidth;
		var mouseOverRightPanel = rightPanelVisible && FlxG.mouse.screenX > FlxG.width - rightPanelWidth;
		var mouseOverUI = mouseOverLeftPanel || mouseOverRightPanel;
		
		// Trackear qué cámara debería estar usando el mouse
		currentMouseCamera = mouseOverUI ? camHUD : camGame;
		
		// Update active inputs
		if (selectedElement != null)
		{
			if (activeInputs.exists("elementName"))
				selectedElement.name = activeInputs.get("elementName").text;
			
			if (activeInputs.exists("asset"))
				selectedElement.asset = activeInputs.get("asset").text;
			
			if (activeSteppers.exists("posX"))
			{
				selectedElement.position[0] = activeSteppers.get("posX").value;
				if (selectedSprite != null)
					selectedSprite.x = selectedElement.position[0];
			}
			
			if (activeSteppers.exists("posY"))
			{
				selectedElement.position[1] = activeSteppers.get("posY").value;
				if (selectedSprite != null)
					selectedSprite.y = selectedElement.position[1];
			}
			
			if (activeSteppers.exists("zIndex"))
				selectedElement.zIndex = Std.int(activeSteppers.get("zIndex").value);
			
			if (activeSteppers.exists("alpha"))
			{
				selectedElement.alpha = activeSteppers.get("alpha").value;
				if (selectedSprite != null)
					selectedSprite.alpha = selectedElement.alpha;
			}
		}
		
		// ESC - Exit
		if (FlxG.keys.justPressed.ESCAPE)
		{
			FlxG.sound.music.stop();
			states.LoadingState.loadAndSwitchState(new states.MainMenuState());
		}
		
		// T - Reload
		if (FlxG.keys.justPressed.T)
		{
			reloadStage();
		}
		
		// S - Save/Export
		if (FlxG.keys.justPressed.S)
		{
			exportStageJSON();
		}
		
		// Zoom (solo si no estás sobre UI)
		if (!mouseOverUI)
		{
			if (FlxG.keys.justPressed.E)
				camGame.zoom += 0.1;
			if (FlxG.keys.justPressed.Q)
				camGame.zoom = Math.max(0.1, camGame.zoom - 0.1);
		}
		
		// Reset camera
		if (FlxG.keys.justPressed.R)
		{
			camFollow.setPosition(FlxG.width / 2, FlxG.height / 2);
			camGame.zoom = stageData.defaultZoom;
		}
		
		// Toggle grid
		if (FlxG.keys.justPressed.G)
		{
			showGrid = !showGrid;
			gridBG.visible = showGrid;
		}
		
		// Camera movement (solo si no estás sobre UI)
		if (!mouseOverUI)
		{
			var camSpeed = 200 * (FlxG.keys.pressed.SHIFT ? 2 : 1);
			
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
			camFollow.velocity.set(0, 0);
		}
		
		// Mouse interaction
		handleMouseInteraction();
		
		// Layer scroll (solo si el mouse está en camHUD y sobre el panel izquierdo)
		if (currentMouseCamera == camHUD && FlxG.mouse.wheel != 0 && mouseOverLeftPanel)
		{
			layerScroll -= FlxG.mouse.wheel * 30;
			layerScroll = FlxMath.bound(layerScroll, 0, Math.max(0, stageData.elements.length * 45 - layerListHeight));
			updateLayerList();
		}
	}
	
	function handleMouseInteraction():Void
	{
		// Si el mouse está en camHUD, no interactuar con el juego
		if (currentMouseCamera == camHUD)
		{
			// Cancelar arrastre si estamos sobre UI
			if (draggingElement)
				draggingElement = false;
			return;
		}
		
		// A partir de aquí, el mouse está en camGame
		
		// Click to select
		if (FlxG.mouse.justPressed)
		{
			for (i in 0...stageData.elements.length)
			{
				var element = stageData.elements[i];
				var sprite:FlxSprite = null;
				
				if (element.name != null)
				{
					sprite = currentStage.getElement(element.name);
					if (sprite == null)
						sprite = currentStage.getCustomClass(element.name);
				}
				
				// Ahora overlaps funciona correctamente porque el mouse está en camGame
				if (sprite != null && FlxG.mouse.overlaps(sprite, camGame))
				{
					selectElement(i);
					draggingElement = true;
					dragOffset = [
						FlxG.mouse.x - sprite.x,
						FlxG.mouse.y - sprite.y
					];
					break;
				}
			}
		}
		
		// Drag element
		if (draggingElement && FlxG.mouse.pressed && selectedSprite != null)
		{
			var newX = FlxG.mouse.x - dragOffset[0];
			var newY = FlxG.mouse.y - dragOffset[1];
			
			selectedSprite.setPosition(newX, newY);
			selectedElement.position = [newX, newY];
			
			if (activeSteppers.exists("posX"))
				activeSteppers.get("posX").value = newX;
			if (activeSteppers.exists("posY"))
				activeSteppers.get("posY").value = newY;
		}
		
		// Stop dragging
		if (FlxG.mouse.justReleased)
		{
			draggingElement = false;
		}
	}
	
	function exportStageJSON():Void
	{
		var json = Json.stringify(stageData, null, "\t");
		
		_file = new FileReference();
		_file.addEventListener(Event.COMPLETE, onSaveComplete);
		_file.addEventListener(Event.CANCEL, onSaveCancel);
		_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file.save(json, stageData.name + ".json");
	}
	
	function onSaveComplete(_):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		showNotification("Stage exported successfully!");
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
		showNotification("Error exporting stage!");
	}
	
	function showNotification(text:String):Void
	{
		statusText.text = text;
		FlxG.sound.play(Paths.sound('confirmMenu'));
	}
}

// ══════════════════════════════════════════════════════════════
// SIMPLE BUTTON - FIXED: Ahora usa getScreenPosition
// ══════════════════════════════════════════════════════════════

class SimpleButton extends FlxSprite
{
	public var label:FlxText;
	public var onClick:Void->Void = null;
	public var bgColor:Int = 0xFF0f3460;
	
	var hovered:Bool = false;
	
	public function new(x:Float, y:Float, width:Int, height:Int, text:String)
	{
		super(x, y);
		
		makeGraphic(width, height, bgColor);
		scrollFactor.set(0, 0);
		
		label = new FlxText(x, y + (height - 14) / 2, width, text, 12);
		label.setFormat(null, 12, FlxColor.WHITE, CENTER);
		label.alignment = CENTER;
		label.scrollFactor.set(0, 0);
	}
	
	override function update(elapsed:Float):Void
	{
		super.update(elapsed);
		
		// Update label position
		label.setPosition(x, y + (height - 14) / 2);
		label.update(elapsed);
		
		// Usar overlaps con camHUD (los botones están en camHUD)
		var wasHovered = hovered;
		hovered = FlxG.mouse.overlaps(this, cameras[0]);
		
		// Color change on hover
		if (hovered != wasHovered)
		{
			color = hovered ? 0xFF16537e : 0xFFFFFFFF;
		}
		
		// Click detection
		if (hovered && FlxG.mouse.justPressed && onClick != null)
		{
			onClick();
			FlxG.sound.play(Paths.sound('scrollMenu'));
		}
	}
	
	override function draw():Void
	{
		super.draw();
		label.draw();
	}
	
	override function destroy():Void
	{
		label.destroy();
		super.destroy();
	}
}

// ══════════════════════════════════════════════════════════════
// LAYER ITEM - FIXED: Ahora usa getScreenPosition
// ══════════════════════════════════════════════════════════════

class LayerItem extends FlxSprite
{
	var element:StageElement;
	var index:Int;
	var nameText:FlxText;
	var typeText:FlxText;
	var visButton:FlxSprite;
	var isSelected:Bool = false;
	
	public var onSelect:Void->Void = null;
	public var onToggleVis:Void->Void = null;
	
	public function new(x:Float, y:Float, width:Int, element:StageElement, index:Int)
	{
		super(x, y);
		
		this.element = element;
		this.index = index;
		
		makeGraphic(width, 40, 0xFF2a2d3a);
		scrollFactor.set(0, 0);
		
		// Type badge
		var typeColor = getTypeColor();
		typeText = new FlxText(x + 5, y + 12, 50, element.type.substring(0, 3).toUpperCase(), 10);
		typeText.setFormat(null, 10, typeColor, CENTER);
		typeText.alignment = CENTER;
		typeText.scrollFactor.set(0, 0);
		
		// Name
		var displayName = element.name != null ? element.name : "unnamed_" + index;
		nameText = new FlxText(x + 60, y + 12, width - 95, displayName, 11);
		nameText.setFormat(null, 11, FlxColor.WHITE, LEFT);
		nameText.scrollFactor.set(0, 0);
		
		// Visibility button
		visButton = new FlxSprite(x + width - 25, y + 10);
		var isVisible = element.visible != null ? element.visible : true;
		visButton.makeGraphic(20, 20, isVisible ? 0xFF00ff00 : 0xFFff0000);
		visButton.scrollFactor.set(0, 0);
	}
	
	function getTypeColor():Int
	{
		return switch (element.type.toLowerCase())
		{
			case "sprite": 0xFF4a90e2;
			case "animated": 0xFFe94560;
			case "group": 0xFF9b59b6;
			case "custom_class": 0xFFf39c12;
			case "custom_class_group": 0xFFe67e22;
			default: 0xFF95a5a6;
		}
	}
	
	public function setSelected(selected:Bool):Void
	{
		isSelected = selected;
		color = selected ? 0xFF16537e : 0xFF2a2d3a;
	}
	
	override function update(elapsed:Float):Void
	{
		super.update(elapsed);
		
		typeText.setPosition(x + 5, y + 12);
		typeText.update(elapsed);
		
		nameText.setPosition(x + 60, y + 12);
		nameText.update(elapsed);
		
		visButton.setPosition(x + width - 25, y + 10);
		visButton.update(elapsed);
		
		// Usar overlaps con camHUD (los items están en camHUD)
		if (FlxG.mouse.justPressed)
		{
			// Verificar si el mouse está sobre este item
			if (FlxG.mouse.overlaps(this, cameras[0]))
			{
				// Check if clicking visibility button
				if (FlxG.mouse.overlaps(visButton, cameras[0]))
				{
					if (onToggleVis != null)
						onToggleVis();
				}
				else
				{
					if (onSelect != null)
						onSelect();
				}
			}
		}
	}
	
	override function draw():Void
	{
		super.draw();
		typeText.draw();
		nameText.draw();
		visButton.draw();
	}
	
	override function destroy():Void
	{
		typeText.destroy();
		nameText.destroy();
		visButton.destroy();
		super.destroy();
	}
}