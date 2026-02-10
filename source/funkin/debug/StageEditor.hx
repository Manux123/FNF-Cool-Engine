package funkin.debug;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.ui.FlxButton;
import flixel.addons.ui.*;
import flixel.math.FlxPoint;
import flixel.math.FlxMath;
import haxe.Json;
import sys.io.File;
import sys.FileSystem;
import funkin.gameplay.objects.stages.Stage;
import funkin.gameplay.objects.stages.Stage.StageData;
import funkin.gameplay.objects.stages.Stage.StageElement;
import funkin.gameplay.objects.character.Character;
import funkin.gameplay.PlayState;
import lime.ui.FileDialog;
import funkin.menus.MainMenuState;

using StringTools;

typedef EditorHistory = {
	var data:StageData;
	var timestamp:Float;
}

class StageEditor extends FlxState
{
	// UI Groups
	var uiGroup:FlxTypedGroup<FlxSprite>;
	var leftPanel:FlxUITabMenu;
	var rightPanel:FlxUITabMenu;
	var topBar:FlxSprite;
	
	// Canvas and Stage
	var canvas:FlxSprite;
	var canvasGrid:FlxSprite;
	var stage:Stage;
	
	// Characters
	var boyfriend:Character;
	var dad:Character;
	var gf:Character;
	var charactersGroup:FlxTypedGroup<Character>;
	
	// Visual element sprites (for editing)
	var elementSprites:Map<String, FlxSprite> = new Map();
	var selectedVisualSprite:FlxSprite = null;
	var selectionBox:FlxSprite;
	
	// Data
	var stageData:StageData;
	var songData = PlayState.SONG;
	var selectedElementIndex:Int = -1;
	var clipboard:StageElement = null;
	
	// History (Undo/Redo)
	var history:Array<EditorHistory> = [];
	var historyIndex:Int = -1;
	var maxHistory:Int = 50;
	
	// Dragging
	var isDragging:Bool = false;
	var dragStartPos:FlxPoint;
	var dragElementStartPos:FlxPoint;
	
	// UI Elements
	var stageNameInput:FlxUIInputText;
	var defaultZoomStepper:FlxUINumericStepper;
	var elementsList:FlxUIList;
	var selectedElementText:FlxText;
	
	// Song/Character inputs
	var songNameInput:FlxUIInputText;
	var player1Input:FlxUIInputText;
	var player2Input:FlxUIInputText;
	var gfVersionInput:FlxUIInputText;
	
	// File
	var currentFilePath:String = "";
	var hasUnsavedChanges:Bool = false;
	
	// Camera
	var camEditor:flixel.FlxCamera;
	var camHUD:flixel.FlxCamera;
	var camZoom:Float = 0.7;
	var camFollow:FlxPoint;
	
	override public function create():Void
	{
		super.create();
		FlxG.mouse.visible = true;
		// Setup cameras
		camEditor = new flixel.FlxCamera();
		camHUD = new flixel.FlxCamera();
		camHUD.bgColor.alpha = 0;
		
		FlxG.cameras.reset(camEditor);
		FlxG.cameras.add(camHUD, false);
		
		camEditor.zoom = camZoom;
		camFollow = FlxPoint.get(FlxG.width / 2, FlxG.height / 2);
		
		// Inicializar con datos por defecto
		
		stageData = {
			name: "stage",
			defaultZoom: 0.9,
			isPixelStage: false,
			elements: [],
			gfVersion: "gf",
			boyfriendPosition: [770, 450],
			dadPosition: [100, 100],
			gfPosition: [400, 130],
			cameraBoyfriend: [0, 0],
			cameraDad: [0, 0],
			hideGirlfriend: false,
			scripts: []
		};
		
		dragStartPos = FlxPoint.get();
		dragElementStartPos = FlxPoint.get();
		
		setupCanvas();
		loadStageAndCharacters();
		setupOverlays(); // Grid y selectionBox deben ir después del stage
		setupUI();
		saveToHistory();
		
		FlxG.camera.bgColor = 0xFF1a1a2e;
	}
	
	function setupCanvas():Void
	{
		// Canvas background (detrás del stage)
		canvas = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, 0xFF0e0e1a);
		canvas.scrollFactor.set(0, 0);
		add(canvas);
		canvas.cameras = [camEditor];
	}
	
	function setupOverlays():Void
	{
		// Grid overlay (debe añadirse DESPUÉS del stage para estar encima)
		canvasGrid = new FlxSprite(0, 0);
		canvasGrid.makeGraphic(FlxG.width, FlxG.height, FlxColor.TRANSPARENT, true);
		canvasGrid.scrollFactor.set(1, 1);
		drawGrid();
		add(canvasGrid);
		canvasGrid.cameras = [camEditor];
		
		// Selection box (para mostrar el elemento seleccionado - debe estar al final)
		selectionBox = new FlxSprite();
		selectionBox.makeGraphic(1, 1, FlxColor.TRANSPARENT);
		selectionBox.visible = false;
		add(selectionBox);
		selectionBox.cameras = [camEditor];
	}
	
	function drawGrid():Void
	{
		var gridSize = 50;
		var width = Std.int(canvasGrid.width);
		var height = Std.int(canvasGrid.height);
		
		canvasGrid.pixels.fillRect(canvasGrid.pixels.rect, FlxColor.TRANSPARENT);
		
		// Vertical lines
		var x = 0;
		while (x < width)
		{
			for (y in 0...height)
			{
				canvasGrid.pixels.setPixel32(x, y, 0x33404055);
			}
			x += gridSize;
		}
		
		// Horizontal lines
		var y = 0;
		while (y < height)
		{
			for (x in 0...width)
			{
				canvasGrid.pixels.setPixel32(x, y, 0x33404055);
			}
			y += gridSize;
		}
	}
	
	function loadStageAndCharacters():Void
	{
		// Limpiar stage existente
		if (stage != null)
		{
			remove(stage);
			stage.destroy();
		}
		
		if (charactersGroup != null)
		{
			remove(charactersGroup);
			charactersGroup.destroy();
		}
		
		// Cargar el stage
		try
		{
			stage = new Stage(stageData.name);
			add(stage);
			stage.cameras = [camEditor];
			
			// Actualizar datos del stage
			if (stage.stageData != null)
			{
				stageData = stage.stageData;
			}
			
			// Crear mapeo de elementos visuales
			updateElementSprites();
			
			trace("Stage loaded: " + stageData.name);
		}
		catch (e:Dynamic)
		{
			trace("Error loading stage: " + e);
		}
		
		// Crear grupo de personajes
		charactersGroup = new FlxTypedGroup<Character>();
		add(charactersGroup);
		charactersGroup.cameras = [camEditor];
		
		// Cargar personajes
		loadCharacters();
	}
	
	function loadCharacters():Void
	{
		var gfChar = stageData.gfVersion != null ? stageData.gfVersion : songData.gfVersion;
		
		// Dad (player2)
		if (dad != null)
		{
			charactersGroup.remove(dad);
			dad.destroy();
		}
		
		dad = new Character(stageData.dadPosition[0], stageData.dadPosition[1], songData.player2, false);
		dad.alpha = 0.8; // Semi-transparente para indicar que es editable
		charactersGroup.add(dad);
		
		// GF
		if (!stageData.hideGirlfriend)
		{
			if (gf != null)
			{
				charactersGroup.remove(gf);
				gf.destroy();
			}
			
			gf = new Character(stageData.gfPosition[0], stageData.gfPosition[1], gfChar, false);
			gf.alpha = 0.8;
			charactersGroup.add(gf);
		}
		
		// Boyfriend (player1)
		if (boyfriend != null)
		{
			charactersGroup.remove(boyfriend);
			boyfriend.destroy();
		}
		
		boyfriend = new Character(stageData.boyfriendPosition[0], stageData.boyfriendPosition[1], songData.player1, true);
		boyfriend.alpha = 0.8;
		charactersGroup.add(boyfriend);
		
		trace("Characters loaded - BF: " + songData.player1 + ", Dad: " + songData.player2 + ", GF: " + gfChar);
	}
	
	function updateElementSprites():Void
	{
		// Crear referencias a los sprites del stage para poder editarlos
		elementSprites.clear();
		
		if (stage != null && stage.elements != null)
		{
			for (name => sprite in stage.elements)
			{
				elementSprites.set(name, sprite);
			}
		}
	}
	
	function setupUI():Void
	{
		uiGroup = new FlxTypedGroup<FlxSprite>();
		add(uiGroup);
		uiGroup.cameras = [camHUD];
		
		// Top Bar
		topBar = new FlxSprite(0, 0).makeGraphic(FlxG.width, 40, 0xFF2a2a3e);
		uiGroup.add(topBar);
		
		var title = new FlxText(10, 10, 0, "STAGE EDITOR - " + stageData.name, 16);
		title.setFormat(null, 16, FlxColor.WHITE, LEFT);
		uiGroup.add(title);
		
		// Botones del top bar
		var saveBtn = new FlxButton(FlxG.width - 480, 10, "Save JSON", saveJSON);
		var loadBtn = new FlxButton(FlxG.width - 380, 10, "Load JSON", loadJSON);
		var reloadBtn = new FlxButton(FlxG.width - 280, 10, "Reload", reloadStage);
		var undoBtn = new FlxButton(FlxG.width - 180, 10, "Undo", undo);
		var redoBtn = new FlxButton(FlxG.width - 110, 10, "Redo", redo);
		
		uiGroup.add(saveBtn);
		uiGroup.add(loadBtn);
		uiGroup.add(reloadBtn);
		uiGroup.add(undoBtn);
		uiGroup.add(redoBtn);
		
		// Panel izquierdo - Propiedades del Stage
		setupLeftPanel();
		
		// Panel derecho - Elementos
		setupRightPanel();
	}
	
	function setupLeftPanel():Void
	{
		var tabs = [
			{name: "Stage", label: "Stage Props"},
			{name: "Song", label: "Song Data"},
			{name: "Characters", label: "Char Positions"},
			{name: "Scripts", label: "Scripts"}
		];
		
		leftPanel = new FlxUITabMenu(null, tabs, true);
		leftPanel.resize(300, FlxG.height - 40);
		leftPanel.x = 0;
		leftPanel.y = 40;
		leftPanel.scrollFactor.set();
		uiGroup.add(leftPanel);
		
		// Tab: Stage Properties
		var stageTab = new FlxUI(null, leftPanel);
		stageTab.name = "Stage";
		
		stageNameInput = new FlxUIInputText(10, 10, 200, stageData.name);
		var stageNameLabel = new FlxText(10, 0, 0, "Stage Name:");
		
		defaultZoomStepper = new FlxUINumericStepper(10, 50, 0.05, stageData.defaultZoom, 0.1, 5, 2);
		var zoomLabel = new FlxText(10, 40, 0, "Default Zoom:");
		
		var pixelCheckbox = new FlxUICheckBox(10, 80, null, null, "Pixel Stage", 100);
		pixelCheckbox.checked = stageData.isPixelStage;
		
		var hideGFCheckbox = new FlxUICheckBox(10, 110, null, null, "Hide Girlfriend", 100);
		hideGFCheckbox.checked = stageData.hideGirlfriend;
		
		stageTab.add(stageNameLabel);
		stageTab.add(stageNameInput);
		stageTab.add(zoomLabel);
		stageTab.add(defaultZoomStepper);
		stageTab.add(pixelCheckbox);
		stageTab.add(hideGFCheckbox);
		
		leftPanel.addGroup(stageTab);
		
		// Tab: Song Data
		var songTab = new FlxUI(null, leftPanel);
		songTab.name = "Song";
		
		var songLabel = new FlxText(10, 10, 0, "Song Name:");
		songNameInput = new FlxUIInputText(10, 30, 200, songData.song);
		
		var p1Label = new FlxText(10, 60, 0, "Player 1 (BF):");
		player1Input = new FlxUIInputText(10, 80, 200, songData.player1);
		
		var p2Label = new FlxText(10, 110, 0, "Player 2 (Dad):");
		player2Input = new FlxUIInputText(10, 130, 200, songData.player2);
		
		var gfLabel = new FlxText(10, 160, 0, "GF Version:");
		gfVersionInput = new FlxUIInputText(10, 180, 200, songData.gfVersion);
		
		var loadCharsBtn = new FlxButton(10, 210, "Reload Characters", () -> {
			songData.player1 = player1Input.text;
			songData.player2 = player2Input.text;
			songData.gfVersion = gfVersionInput.text;
			loadCharacters();
		});
		
		songTab.add(songLabel);
		songTab.add(songNameInput);
		songTab.add(p1Label);
		songTab.add(player1Input);
		songTab.add(p2Label);
		songTab.add(player2Input);
		songTab.add(gfLabel);
		songTab.add(gfVersionInput);
		songTab.add(loadCharsBtn);
		
		leftPanel.addGroup(songTab);
		
		// Tab: Characters positions
		var charTab = new FlxUI(null, leftPanel);
		charTab.name = "Characters";
		
		var bfLabel = new FlxText(10, 10, 0, "Boyfriend Position:");
		var bfXStepper = new FlxUINumericStepper(10, 30, 10, stageData.boyfriendPosition[0], -2000, 2000, 0);
		var bfYStepper = new FlxUINumericStepper(150, 30, 10, stageData.boyfriendPosition[1], -2000, 2000, 0);
		
		var dadLabel = new FlxText(10, 70, 0, "Dad Position:");
		var dadXStepper = new FlxUINumericStepper(10, 90, 10, stageData.dadPosition[0], -2000, 2000, 0);
		var dadYStepper = new FlxUINumericStepper(150, 90, 10, stageData.dadPosition[1], -2000, 2000, 0);
		
		var gfLabel = new FlxText(10, 130, 0, "Girlfriend Position:");
		var gfXStepper = new FlxUINumericStepper(10, 150, 10, stageData.gfPosition[0], -2000, 2000, 0);
		var gfYStepper = new FlxUINumericStepper(150, 150, 10, stageData.gfPosition[1], -2000, 2000, 0);
		
		charTab.add(bfLabel);
		charTab.add(bfXStepper);
		charTab.add(bfYStepper);
		charTab.add(dadLabel);
		charTab.add(dadXStepper);
		charTab.add(dadYStepper);
		charTab.add(gfLabel);
		charTab.add(gfXStepper);
		charTab.add(gfYStepper);
		
		leftPanel.addGroup(charTab);
		
		// Tab: Scripts
		var scriptsTab = new FlxUI(null, leftPanel);
		scriptsTab.name = "Scripts";
		
		var addScriptBtn = new FlxButton(10, 10, "Add Script", addScript);
		scriptsTab.add(addScriptBtn);
		
		leftPanel.addGroup(scriptsTab);
	}
	
	function setupRightPanel():Void
	{
		var tabs = [
			{name: "Elements", label: "Elements"},
			{name: "Properties", label: "Properties"}
		];
		
		rightPanel = new FlxUITabMenu(null, tabs, true);
		rightPanel.resize(350, FlxG.height - 40);
		rightPanel.x = FlxG.width - 350;
		rightPanel.y = 40;
		rightPanel.scrollFactor.set();
		uiGroup.add(rightPanel);
		
		// Tab: Elements List
		var elementsTab = new FlxUI(null, rightPanel);
		elementsTab.name = "Elements";
		
		var addElementBtn = new FlxButton(10, 10, "Add Element", () -> {
			openAddElementMenu();
		});
		
		var deleteElementBtn = new FlxButton(120, 10, "Delete", deleteSelectedElement);
		var copyElementBtn = new FlxButton(200, 10, "Copy", copyElement);
		var pasteElementBtn = new FlxButton(260, 10, "Paste", pasteElement);
		
		elementsList = new FlxUIList(10, 50, null, 300, 500);
		
		elementsTab.add(addElementBtn);
		elementsTab.add(deleteElementBtn);
		elementsTab.add(copyElementBtn);
		elementsTab.add(pasteElementBtn);
		elementsTab.add(elementsList);
		
		rightPanel.addGroup(elementsTab);
		
		// Tab: Element Properties
		var propsTab = new FlxUI(null, rightPanel);
		propsTab.name = "Properties";
		
		selectedElementText = new FlxText(10, 10, 300, "No element selected\n\nClick on a stage element\nto select it!");
		selectedElementText.setFormat(null, 12, FlxColor.WHITE, LEFT);
		propsTab.add(selectedElementText);
		
		rightPanel.addGroup(propsTab);
		
		refreshElementsList();
	}
	
	function refreshElementsList():Void
	{
		if (elementsList == null) return;
		
		elementsList.clear();
		
		for (i in 0...stageData.elements.length)
		{
			var element = stageData.elements[i];
			var label = '${element.name != null ? element.name : "Element " + i} (${element.type})';
			
			var itemButton = new FlxButton(0, 0, label, () -> {
				selectElement(i);
			});
			itemButton.label.size = 10;
			
			elementsList.add(itemButton);
		}
	}
	
	function selectElement(index:Int):Void
	{
		selectedElementIndex = index;
		updatePropertiesPanel();
		updateSelectionBox();
	}
	
	function updateSelectionBox():Void
	{
		if (selectedElementIndex < 0 || selectedElementIndex >= stageData.elements.length)
		{
			selectionBox.visible = false;
			selectedVisualSprite = null;
			return;
		}
		
		var element = stageData.elements[selectedElementIndex];
		
		// Encontrar el sprite visual correspondiente
		if (element.name != null && elementSprites.exists(element.name))
		{
			selectedVisualSprite = elementSprites.get(element.name);
			
			// Dibujar caja de selección alrededor del sprite
			selectionBox.makeGraphic(
				Std.int(selectedVisualSprite.width + 4),
				Std.int(selectedVisualSprite.height + 4),
				FlxColor.TRANSPARENT
			);
			
			// Dibujar borde
			for (i in 0...Std.int(selectedVisualSprite.width + 4))
			{
				selectionBox.pixels.setPixel32(i, 0, 0xFFFFFF00);
				selectionBox.pixels.setPixel32(i, 1, 0xFFFFFF00);
				selectionBox.pixels.setPixel32(i, Std.int(selectedVisualSprite.height + 2), 0xFFFFFF00);
				selectionBox.pixels.setPixel32(i, Std.int(selectedVisualSprite.height + 3), 0xFFFFFF00);
			}
			
			for (i in 0...Std.int(selectedVisualSprite.height + 4))
			{
				selectionBox.pixels.setPixel32(0, i, 0xFFFFFF00);
				selectionBox.pixels.setPixel32(1, i, 0xFFFFFF00);
				selectionBox.pixels.setPixel32(Std.int(selectedVisualSprite.width + 2), i, 0xFFFFFF00);
				selectionBox.pixels.setPixel32(Std.int(selectedVisualSprite.width + 3), i, 0xFFFFFF00);
			}
			
			selectionBox.setPosition(
				selectedVisualSprite.x - 2,
				selectedVisualSprite.y - 2
			);
			
			selectionBox.visible = true;
		}
		else
		{
			selectionBox.visible = false;
			selectedVisualSprite = null;
		}
	}
	
	function updatePropertiesPanel():Void
	{
		if (selectedElementIndex < 0 || selectedElementIndex >= stageData.elements.length)
		{
			selectedElementText.text = "No element selected\n\nClick on a stage element\nto select it!";
			return;
		}
		
		var element = stageData.elements[selectedElementIndex];
		var info = 'Selected: ${element.name != null ? element.name : "Unnamed"}\n';
		info += 'Type: ${element.type}\n';
		info += 'Asset: ${element.asset}\n';
		info += 'Position: [${element.position[0]}, ${element.position[1]}]\n';
		
		if (element.scrollFactor != null)
			info += 'Scroll: [${element.scrollFactor[0]}, ${element.scrollFactor[1]}]\n';
		
		if (element.scale != null)
			info += 'Scale: [${element.scale[0]}, ${element.scale[1]}]\n';
		
		if (element.alpha != null)
			info += 'Alpha: ${element.alpha}\n';
		
		if (element.zIndex != null)
			info += 'Z-Index: ${element.zIndex}\n';
		
		selectedElementText.text = info;
	}
	
	function openAddElementMenu():Void
	{
		trace("Add element menu - To be implemented");
		// Aquí se abriría un diálogo para añadir nuevos elementos
	}
	
	function deleteSelectedElement():Void
	{
		if (selectedElementIndex >= 0 && selectedElementIndex < stageData.elements.length)
		{
			stageData.elements.splice(selectedElementIndex, 1);
			selectedElementIndex = -1;
			saveToHistory();
			reloadStage();
			refreshElementsList();
			updatePropertiesPanel();
			hasUnsavedChanges = true;
		}
	}
	
	function copyElement():Void
	{
		if (selectedElementIndex >= 0 && selectedElementIndex < stageData.elements.length)
		{
			clipboard = Reflect.copy(stageData.elements[selectedElementIndex]);
			trace("Element copied to clipboard");
		}
	}
	
	function pasteElement():Void
	{
		if (clipboard != null)
		{
			var newElement = Reflect.copy(clipboard);
			newElement.name = '${clipboard.name}_copy';
			newElement.position = [clipboard.position[0] + 20, clipboard.position[1] + 20];
			
			stageData.elements.push(newElement);
			saveToHistory();
			reloadStage();
			refreshElementsList();
			hasUnsavedChanges = true;
			trace("Element pasted");
		}
	}
	
	function moveElementLayer(index:Int, direction:String):Void
	{
		if (index < 0 || index >= stageData.elements.length)
			return;
		
		var newIndex:Int = -1;
		
		if (direction == "up" && index < stageData.elements.length - 1)
		{
			// Mover hacia arriba en el orden de capas (aumentar índice, renderiza encima)
			newIndex = index + 1;
		}
		else if (direction == "down" && index > 0)
		{
			// Mover hacia abajo en el orden de capas (disminuir índice, renderiza debajo)
			newIndex = index - 1;
		}
		
		if (newIndex != -1)
		{
			// Intercambiar elementos
			var temp = stageData.elements[index];
			stageData.elements[index] = stageData.elements[newIndex];
			stageData.elements[newIndex] = temp;
			
			// Actualizar índice seleccionado
			selectedElementIndex = newIndex;
			
			// Refrescar UI y guardar
			saveToHistory();
			reloadStage();
			refreshElementsList();
			updatePropertiesPanel();
			hasUnsavedChanges = true;
			
			trace('Element moved ${direction} to index ${newIndex}');
		}
	}
	
	function addScript():Void
	{
		// Aquí abrirías un diálogo para seleccionar un archivo
		// Por ahora añadimos una ruta de ejemplo
		var scriptPath = "scripts/myScript.hx";
		
		if (stageData.scripts == null)
			stageData.scripts = [];
			
		stageData.scripts.push(scriptPath);
		saveToHistory();
		hasUnsavedChanges = true;
		trace('Script added: $scriptPath');
	}
	
	function reloadStage():Void
	{
		// Remover overlays temporalmente
		if (canvasGrid != null)
		{
			remove(canvasGrid);
			canvasGrid.destroy();
			canvasGrid = null;
		}
		
		if (selectionBox != null)
		{
			remove(selectionBox);
			selectionBox.destroy();
			selectionBox = null;
		}
		
		// Recargar el stage y personajes con los datos actuales
		loadStageAndCharacters();
		
		// Recrear overlays encima
		setupOverlays();
		
		trace("Stage reloaded");
	}
	
	function saveToHistory():Void
	{
		// Eliminar histórico posterior si estamos en medio
		if (historyIndex < history.length - 1)
		{
			history.splice(historyIndex + 1, history.length - historyIndex - 1);
		}
		
		// Añadir nuevo estado
		var jsonStr = Json.stringify(stageData);
		var dataCopy:StageData = Json.parse(jsonStr);
		
		history.push({
			data: dataCopy,
			timestamp: Date.now().getTime()
		});
		
		historyIndex = history.length - 1;
		
		// Limitar tamaño del historial
		if (history.length > maxHistory)
		{
			history.shift();
			historyIndex--;
		}
	}
	
	function undo():Void
	{
		if (historyIndex > 0)
		{
			historyIndex--;
			var jsonStr = Json.stringify(history[historyIndex].data);
			stageData = Json.parse(jsonStr);
			reloadStage();
			refreshElementsList();
			updatePropertiesPanel();
			trace('Undo - History index: $historyIndex');
		}
	}
	
	function redo():Void
	{
		if (historyIndex < history.length - 1)
		{
			historyIndex++;
			var jsonStr = Json.stringify(history[historyIndex].data);
			stageData = Json.parse(jsonStr);
			reloadStage();
			refreshElementsList();
			updatePropertiesPanel();
			trace('Redo - History index: $historyIndex');
		}
	}
	
	function saveJSON():Void
	{
		var jsonString = Json.stringify(stageData, null, "\t");
		
		#if sys
		var savePath = 'assets/stages/${stageData.name}/${stageData.name}.json';
		
		// Crear directorio si no existe
		var dirPath = 'assets/stages/${stageData.name}';
		if (!FileSystem.exists(dirPath))
		{
			FileSystem.createDirectory(dirPath);
		}
		
		File.saveContent(savePath, jsonString);
		trace('Stage saved to: $savePath');
		hasUnsavedChanges = false;
		#else
		trace("Save not available on this platform");
		#end
	}
	
	function loadJSON():Void
	{
		#if sys
		// Aquí usarías un file dialog
		// Por ahora cargamos un archivo de ejemplo
		var loadPath = 'assets/stages/stage/stage.json';
		
		if (FileSystem.exists(loadPath))
		{
			var jsonString = File.getContent(loadPath);
			stageData = Json.parse(jsonString);
			
			// Resetear historial
			history = [];
			historyIndex = -1;
			saveToHistory();
			
			reloadStage();
			refreshElementsList();
			updatePropertiesPanel();
			
			trace('Stage loaded from: $loadPath');
			hasUnsavedChanges = false;
		}
		else
		{
			trace('File not found: $loadPath');
		}
		#else
		trace("Load not available on this platform");
		#end
	}
	
	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (FlxG.keys.justPressed.ESCAPE)
		{
			if (PlayState.isPlaying)
			{
				FlxG.mouse.visible = false;
				FlxG.switchState(new PlayState());
			}
			else
			{
				FlxG.mouse.visible = false;
				FlxG.switchState(new MainMenuState());
			}
		}
		
		handleCameraMovement(elapsed);
		handleInput();
		handleDragging();
		updateSelectionBox();
	}
	
	function handleCameraMovement(elapsed:Float):Void
	{
		// Mover cámara con WASD (sin SHIFT)
		var camSpeed:Float = 500 * elapsed;
		
		if (!FlxG.keys.pressed.SHIFT)
		{
			if (FlxG.keys.pressed.W)
				camFollow.y -= camSpeed;
			if (FlxG.keys.pressed.S)
				camFollow.y += camSpeed;
			if (FlxG.keys.pressed.A)
				camFollow.x -= camSpeed;
			if (FlxG.keys.pressed.D)
				camFollow.x += camSpeed;
		}
		
		// Zoom con scroll del mouse o Q/E
		if (FlxG.mouse.wheel != 0)
		{
			camZoom += FlxG.mouse.wheel * 0.05;
			camZoom = Math.max(0.1, Math.min(2.0, camZoom));
		}
		
		if (FlxG.keys.justPressed.Q)
		{
			camZoom -= 0.1;
			camZoom = Math.max(0.1, camZoom);
		}
		if (FlxG.keys.justPressed.E)
		{
			camZoom += 0.1;
			camZoom = Math.min(2.0, camZoom);
		}
		
		// Reset camera con R
		if (FlxG.keys.justPressed.R)
		{
			camFollow.set(FlxG.width / 2, FlxG.height / 2);
			camZoom = 0.7;
		}
		
		// Aplicar movimiento suave de cámara
		camEditor.scroll.x = FlxMath.lerp(camEditor.scroll.x, camFollow.x - FlxG.width / 2, 0.1);
		camEditor.scroll.y = FlxMath.lerp(camEditor.scroll.y, camFollow.y - FlxG.height / 2, 0.1);
		camEditor.zoom = FlxMath.lerp(camEditor.zoom, camZoom, 0.1);
	}
	
	function handleInput():Void
	{
		// Atajos de teclado
		if (FlxG.keys.pressed.CONTROL)
		{
			if (FlxG.keys.justPressed.Z)
				undo();
			else if (FlxG.keys.justPressed.Y)
				redo();
			else if (FlxG.keys.justPressed.C)
				copyElement();
			else if (FlxG.keys.justPressed.V)
				pasteElement();
			else if (FlxG.keys.justPressed.S)
				saveJSON();
			else if (FlxG.keys.justPressed.O)
				loadJSON();
		}
		
		if (FlxG.keys.justPressed.DELETE)
		{
			deleteSelectedElement();
		}
		
		// Arrow keys to move layers
		if (selectedElementIndex >= 0)
		{
			if (FlxG.keys.justPressed.UP && !FlxG.keys.pressed.SHIFT)
			{
				moveElementLayer(selectedElementIndex, "up");
			}
			else if (FlxG.keys.justPressed.DOWN && !FlxG.keys.pressed.SHIFT)
			{
				moveElementLayer(selectedElementIndex, "down");
			}
			
			// Arrow keys con SHIFT para mover posición pixel a pixel
			if (FlxG.keys.pressed.SHIFT)
			{
				var element = stageData.elements[selectedElementIndex];
				var moved = false;
				
				if (FlxG.keys.justPressed.UP)
				{
					element.position[1] -= 1;
					moved = true;
				}
				if (FlxG.keys.justPressed.DOWN)
				{
					element.position[1] += 1;
					moved = true;
				}
				if (FlxG.keys.justPressed.LEFT)
				{
					element.position[0] -= 1;
					moved = true;
				}
				if (FlxG.keys.justPressed.RIGHT)
				{
					element.position[0] += 1;
					moved = true;
				}
				
				if (moved)
				{
					if (selectedVisualSprite != null)
					{
						selectedVisualSprite.setPosition(element.position[0], element.position[1]);
					}
					updatePropertiesPanel();
					hasUnsavedChanges = true;
				}
			}
		}
	}
	
	
	function checkMouseOverUI():Bool
	{
		// Usar coordenadas de pantalla (sin transformación de cámara) para verificar UI
		var screenX = FlxG.mouse.screenX;
		var screenY = FlxG.mouse.screenY;
		
		// Verificar paneles
		if (leftPanel != null)
		{
			if (screenX >= leftPanel.x && screenX <= leftPanel.x + leftPanel.width &&
			    screenY >= leftPanel.y && screenY <= leftPanel.y + leftPanel.height)
			{
				return true;
			}
		}
		
		if (rightPanel != null)
		{
			if (screenX >= rightPanel.x && screenX <= rightPanel.x + rightPanel.width &&
			    screenY >= rightPanel.y && screenY <= rightPanel.y + rightPanel.height)
			{
				return true;
			}
		}
		
		// Verificar top bar
		if (topBar != null && screenY < topBar.height)
		{
			return true;
		}
		
		return false;
	}
	
	function handleDragging():Void
	{
		// No procesar clicks del stage si el mouse está sobre UI
		if (checkMouseOverUI())
			return;
		
		// Seleccionar elemento con click
		if (FlxG.mouse.justPressed)
		{
			// Verificar si hicimos click en algún sprite del stage
			var clickedIndex = -1;
			
			for (i in 0...stageData.elements.length)
			{
				var element = stageData.elements[i];
				if (element.name != null && elementSprites.exists(element.name))
				{
					var sprite = elementSprites.get(element.name);
					
					// Convertir posición del mouse a coordenadas del mundo
					var mouseWorldX = FlxG.mouse.x + camEditor.scroll.x;
					var mouseWorldY = FlxG.mouse.y + camEditor.scroll.y;
					
					if (sprite.overlapsPoint(new FlxPoint(mouseWorldX, mouseWorldY)))
					{
						clickedIndex = i;
						break;
					}
				}
			}
			
			if (clickedIndex >= 0)
			{
				selectElement(clickedIndex);
			}
		}
		
		// Drag del elemento seleccionado
		if (selectedElementIndex >= 0 && selectedElementIndex < stageData.elements.length)
		{
			if (FlxG.mouse.justPressed && selectedVisualSprite != null)
			{
				var mouseWorldX = FlxG.mouse.x + camEditor.scroll.x;
				var mouseWorldY = FlxG.mouse.y + camEditor.scroll.y;
				
				if (selectedVisualSprite.overlapsPoint(new FlxPoint(mouseWorldX, mouseWorldY)))
				{
					isDragging = true;
					dragStartPos.set(mouseWorldX, mouseWorldY);
					var element = stageData.elements[selectedElementIndex];
					dragElementStartPos.set(element.position[0], element.position[1]);
				}
			}
		}
		
		if (isDragging)
		{
			if (FlxG.mouse.pressed)
			{
				var mouseWorldX = FlxG.mouse.x + camEditor.scroll.x;
				var mouseWorldY = FlxG.mouse.y + camEditor.scroll.y;
				
				var dx = mouseWorldX - dragStartPos.x;
				var dy = mouseWorldY - dragStartPos.y;
				
				var element = stageData.elements[selectedElementIndex];
				element.position[0] = dragElementStartPos.x + dx;
				element.position[1] = dragElementStartPos.y + dy;
				
				if (selectedVisualSprite != null)
				{
					selectedVisualSprite.setPosition(element.position[0], element.position[1]);
				}
				
				updatePropertiesPanel();
			}
			else
			{
				isDragging = false;
				saveToHistory();
				hasUnsavedChanges = true;
			}
		}
	}
	
	override public function destroy():Void
	{
		dragStartPos.put();
		dragElementStartPos.put();
		camFollow.put();
		
		if (stage != null)
			stage.destroy();
		
		if (boyfriend != null)
			boyfriend.destroy();
		
		if (dad != null)
			dad.destroy();
		
		if (gf != null)
			gf.destroy();
		
		super.destroy();
	}
}
