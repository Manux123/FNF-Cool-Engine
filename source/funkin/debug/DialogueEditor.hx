package funkin.debug;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import funkin.cutscenes.dialogue.DialogueData;
import funkin.cutscenes.dialogue.DialogueBoxImproved;
import funkin.cutscenes.dialogue.DialogueData.DialogueConversation;
import funkin.gameplay.PlayState;
import flixel.addons.ui.FlxInputText;

/**
 * Editor visual de diálogos (versión simplificada sin FlxUI)
 */
class DialogueEditor extends FlxState
{
	// === UI ELEMENTOS ===
	var bg:FlxSprite;
	var titleText:FlxText;
	var messageList:FlxTypedGroup<FlxText>;
	var messageButtons:FlxTypedGroup<FlxButton>;

	// === INPUTS (usando FlxText editables simples) ===
	var nameText:FlxInputText;
	var styleText:FlxInputText;
	var bgColorText:FlxInputText;
	var characterText:FlxInputText;
	var messageText:FlxInputText;
	var bubbleTypeText:FlxInputText;
	var speedText:FlxInputText;

	// === BOTONES ===
	var addMessageBtn:FlxButton;
	var removeMessageBtn:FlxButton;
	var saveBtn:FlxButton;
	var loadBtn:FlxButton;
	var testBtn:FlxButton;
	var clearBtn:FlxButton;
	var toggleStyleBtn:FlxButton;
	var cycleBubbleBtn:FlxButton;

	// === DATOS ===
	var conversation:DialogueConversation;
	var selectedMessageIndex:Int = -1;

	// === PREVIEW ===
	var previewBox:DialogueBoxImproved;

	// === LAYOUT ===
	static final PADDING = 10;
	static final LEFT_PANEL_WIDTH = 300;
	static final MIDDLE_PANEL_WIDTH = 400;

	// === EDITANDO ===
	var editingField:FlxText = null;
	var currentInput:String = "";

	override public function create():Void
	{
		super.create();

        FlxG.sound.playMusic(Paths.music('chartEditorLoop/chartEditorLoop'),0.7);
        
		if (PlayState.SONG.song == null)
			PlayState.SONG.song = 'Test';

		// Inicializar conversación vacía
		conversation = {
			name: "new_dialogue",
			style: "pixel",
			backgroundColor: "#B3DFD8",
			fadeTime: 0.83,
			messages: []
		};

		// Crear UI
		createBackground();
		createLeftPanel();
		createMiddlePanel();
		createRightPanel();
		createInstructions();

		FlxG.mouse.visible = true;
	}

	/**
	 * Crear fondo
	 */
	function createBackground():Void
	{
		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF1A1A1A);
		add(bg);

		titleText = new FlxText(0, PADDING, FlxG.width, "DIALOGUE EDITOR", 32);
		titleText.alignment = CENTER;
		titleText.setBorderStyle(OUTLINE, FlxColor.BLACK, 2);
		add(titleText);
	}

	/**
	 * Crear instrucciones
	 */
	function createInstructions():Void
	{
		var instructions = new FlxText(PADDING, FlxG.height
			- 80, FlxG.width
			- PADDING * 2,
			"CLICK en los campos para editar | ENTER para confirmar | ESC para cancelar\n"
			+ "CTRL+S: Guardar | CTRL+T: Probar | CTRL+N: Nuevo mensaje", 12);
		instructions.alignment = CENTER;
		instructions.setBorderStyle(OUTLINE, FlxColor.BLACK, 1);
		add(instructions);
	}

	/**
	 * Crear panel izquierdo (info general)
	 */
	function createLeftPanel():Void
	{
		var startY = 60;
		var x = PADDING;

		// Título
		var panelTitle = new FlxText(x, startY, LEFT_PANEL_WIDTH, "GENERAL INFO", 20);
		panelTitle.setBorderStyle(OUTLINE, FlxColor.BLACK, 2);
		add(panelTitle);
		startY += 30;

		// Nombre
		var nameLabel = new FlxText(x, startY, LEFT_PANEL_WIDTH, "Name:", 16);
		add(nameLabel);
		startY += 20;

		nameText = createEditableText(x, startY, LEFT_PANEL_WIDTH - 20, conversation.name);
		add(nameText);
		startY += 35;

		// Estilo
		var styleLabel = new FlxText(x, startY, LEFT_PANEL_WIDTH, "Style:", 16);
		add(styleLabel);
		startY += 20;

		styleText = createEditableText(x, startY, 150, conversation.style);
		add(styleText);

		toggleStyleBtn = new FlxButton(x + 160, startY - 2, "TOGGLE", function()
		{
			conversation.style = (conversation.style == "pixel") ? "normal" : "pixel";
			styleText.text = conversation.style;
		});
		toggleStyleBtn.makeGraphic(120, 25, FlxColor.CYAN);
		toggleStyleBtn.label.color = FlxColor.BLACK;
		toggleStyleBtn.label.size = 12;
		add(toggleStyleBtn);
		startY += 40;

		// Color de fondo
		var bgColorLabel = new FlxText(x, startY, LEFT_PANEL_WIDTH, "Background Color:", 16);
		add(bgColorLabel);
		startY += 20;

		bgColorText = createEditableText(x, startY, LEFT_PANEL_WIDTH - 20, conversation.backgroundColor);
		add(bgColorText);
		startY += 35;

		// Botones de archivo
		var btnWidth = (LEFT_PANEL_WIDTH - 30) / 2;

		saveBtn = new FlxButton(x, startY, "SAVE", saveDialogue);
		saveBtn.makeGraphic(Std.int(btnWidth), 30, FlxColor.GREEN);
		saveBtn.label.color = FlxColor.BLACK;
		add(saveBtn);

		loadBtn = new FlxButton(x + btnWidth + 10, startY, "LOAD", loadDialogue);
		loadBtn.makeGraphic(Std.int(btnWidth), 30, FlxColor.BLUE);
		loadBtn.label.color = FlxColor.BLACK;
		add(loadBtn);
		startY += 40;

		// Botones de acciones
		testBtn = new FlxButton(x, startY, "TEST", testDialogue);
		testBtn.makeGraphic(Std.int(btnWidth), 30, FlxColor.YELLOW);
		testBtn.label.color = FlxColor.BLACK;
		add(testBtn);

		clearBtn = new FlxButton(x + btnWidth + 10, startY, "CLEAR", clearDialogue);
		clearBtn.makeGraphic(Std.int(btnWidth), 30, FlxColor.RED);
		clearBtn.label.color = FlxColor.BLACK;
		add(clearBtn);
	}
	
	/**
	 * Crear panel del medio (lista de mensajes)
	 */
	function createMiddlePanel():Void
	{
		var startY = 60;
		var x = LEFT_PANEL_WIDTH + PADDING * 2;

		// Título
		var panelTitle = new FlxText(x, startY, MIDDLE_PANEL_WIDTH, "MESSAGES", 20);
		panelTitle.setBorderStyle(OUTLINE, FlxColor.BLACK, 2);
		add(panelTitle);
		startY += 30;

		// Lista de mensajes
		messageList = new FlxTypedGroup<FlxText>();
		add(messageList);

		messageButtons = new FlxTypedGroup<FlxButton>();
		add(messageButtons);

		// Botón agregar mensaje
		addMessageBtn = new FlxButton(x, FlxG.height - 120, "ADD MESSAGE (Ctrl+N)", addMessage);
		addMessageBtn.makeGraphic(MIDDLE_PANEL_WIDTH, 30, FlxColor.GREEN);
		addMessageBtn.label.color = FlxColor.BLACK;
		add(addMessageBtn);

		refreshMessageList();
	}

	/**
	 * Crear panel derecho (editar mensaje)
	 */
	function createRightPanel():Void
	{
		var startY = 60;
		var x = LEFT_PANEL_WIDTH + MIDDLE_PANEL_WIDTH + PADDING * 3;
		var panelWidth = FlxG.width - x - PADDING;

		// Título
		var panelTitle = new FlxText(x, startY, panelWidth, "EDIT MESSAGE", 20);
		panelTitle.setBorderStyle(OUTLINE, FlxColor.BLACK, 2);
		add(panelTitle);
		startY += 30;

		// Personaje
		var charLabel = new FlxText(x, startY, panelWidth, "Character (dad/bf):", 16);
		add(charLabel);
		startY += 20;

		characterText = createEditableText(x, startY, panelWidth - 20, "dad");
		add(characterText);
		startY += 35;

		// Texto del mensaje
		var textLabel = new FlxText(x, startY, panelWidth, "Text (click to edit):", 16);
		add(textLabel);
		startY += 20;

		messageText = createEditableText(x, startY, panelWidth - 20, "Type your dialogue here...", 14);
		// messageText.fieldHeight = 100;
		add(messageText);
		startY += 110;

		// Tipo de burbuja
		var bubbleLabel = new FlxText(x, startY, panelWidth, "Bubble Type:", 16);
		add(bubbleLabel);
		startY += 20;

		bubbleTypeText = createEditableText(x, startY, 150, "normal");
		add(bubbleTypeText);

		cycleBubbleBtn = new FlxButton(x + 160, startY - 2, "CYCLE", function()
		{
			var types = ["normal", "loud", "angry", "evil"];
			var current = types.indexOf(bubbleTypeText.text);
			var next = (current + 1) % types.length;
			bubbleTypeText.text = types[next];
		});
		cycleBubbleBtn.makeGraphic(120, 25, FlxColor.CYAN);
		cycleBubbleBtn.label.color = FlxColor.BLACK;
		cycleBubbleBtn.label.size = 12;
		add(cycleBubbleBtn);
		startY += 35;

		// Velocidad
		var speedLabel = new FlxText(x, startY, panelWidth, "Speed (0.01-0.1):", 16);
		add(speedLabel);
		startY += 20;

		speedText = createEditableText(x, startY, panelWidth - 20, "0.04");
		add(speedText);
		startY += 35;

		// Botones
		var btnWidth = (panelWidth - 30) / 2;

		var updateBtn = new FlxButton(x, startY, "UPDATE", updateCurrentMessage);
		updateBtn.makeGraphic(Std.int(btnWidth), 30, FlxColor.CYAN);
		updateBtn.label.color = FlxColor.BLACK;
		add(updateBtn);

		removeMessageBtn = new FlxButton(x + btnWidth + 10, startY, "REMOVE", removeMessage);
		removeMessageBtn.makeGraphic(Std.int(btnWidth), 30, FlxColor.RED);
		removeMessageBtn.label.color = FlxColor.BLACK;
		add(removeMessageBtn);
	}

	/**
	 * Crear texto editable
	 */
	function createEditableText(x:Float, y:Float, width:Float, initialText:String, ?size:Int = 16):FlxInputText
	{
		// FlxInputText(x, y, width, textoInicial, tamañoLetra, colorTexto, colorFondo)
		var inputText = new FlxInputText(x, y, Std.int(width), initialText, size, FlxColor.WHITE, 0x33FFFFFF);
		inputText.setBorderStyle(OUTLINE, FlxColor.BLACK, 1);

		// Esto permite que el componente maneje el teclado automáticamente
		inputText.focusGained = () -> inputText.color = FlxColor.YELLOW;
		inputText.focusLost = () -> inputText.color = FlxColor.WHITE;

		return inputText;
	}

	/**
	 * Refrescar lista de mensajes
	 */
	function refreshMessageList():Void
	{
		messageList.clear();
		messageButtons.clear();

		var startY = 100;
		var x = LEFT_PANEL_WIDTH + PADDING * 2;

		for (i in 0...conversation.messages.length)
		{
			var msg = conversation.messages[i];
			var preview = msg.character + ": " + msg.text.substr(0, 30);
			if (msg.text.length > 30)
				preview += "...";

			var msgText = new FlxText(x, startY, MIDDLE_PANEL_WIDTH - 60, preview, 14);
			msgText.color = (selectedMessageIndex == i) ? FlxColor.YELLOW : FlxColor.WHITE;
			messageList.add(msgText);

			var selectBtn = new FlxButton(x + MIDDLE_PANEL_WIDTH - 50, startY - 2, "EDIT", function()
			{
				selectMessage(i);
			});
			selectBtn.makeGraphic(50, 20, FlxColor.GRAY);
			selectBtn.label.size = 10;
			messageButtons.add(selectBtn);

			startY += 25;
		}
	}

	/**
	 * Seleccionar mensaje para editar
	 */
	function selectMessage(index:Int):Void
	{
		selectedMessageIndex = index;
		var msg = conversation.messages[index];

		characterText.text = msg.character;
		messageText.text = msg.text;
		speedText.text = Std.string(msg.speed ?? 0.04);
		bubbleTypeText.text = msg.bubbleType ?? "normal";

		refreshMessageList();
	}

	/**
	 * Agregar nuevo mensaje
	 */
	function addMessage():Void
	{
		conversation.messages.push({
			character: "dad",
			text: "New message",
			bubbleType: "normal",
			speed: 0.04
		});

		selectedMessageIndex = conversation.messages.length - 1;
		selectMessage(selectedMessageIndex);
	}

	/**
	 * Actualizar mensaje actual
	 */
	function updateCurrentMessage():Void
	{
		if (selectedMessageIndex < 0 || selectedMessageIndex >= conversation.messages.length)
			return;

		var msg = conversation.messages[selectedMessageIndex];
		msg.character = characterText.text;
		msg.text = messageText.text;
		msg.bubbleType = bubbleTypeText.text;
		msg.speed = Std.parseFloat(speedText.text);

		// Actualizar info general
		conversation.name = nameText.text;
		conversation.style = styleText.text;
		conversation.backgroundColor = bgColorText.text;

		refreshMessageList();
	}

	/**
	 * Eliminar mensaje
	 */
	function removeMessage():Void
	{
		if (selectedMessageIndex < 0 || selectedMessageIndex >= conversation.messages.length)
			return;

		conversation.messages.splice(selectedMessageIndex, 1);
		selectedMessageIndex = -1;

		// Limpiar inputs
		characterText.text = "";
		messageText.text = "";
		speedText.text = "0.04";
		bubbleTypeText.text = "normal";

		refreshMessageList();
	}

	/**
	 * Guardar diálogo
	 */
	function saveDialogue():Void
	{
		// Actualizar datos antes de guardar
		conversation.name = nameText.text;
		conversation.style = styleText.text;
		conversation.backgroundColor = bgColorText.text;

		var path = 'assets/songs/${PlayState.SONG.song.toLowerCase()}/' + conversation.name + '.json';

		if (DialogueData.saveDialogue(path, conversation))
		{
			trace('Dialogue saved successfully to: $path');
			showMessage("SAVED!", FlxColor.GREEN);
		}
		else
		{
			trace('Failed to save dialogue');
			showMessage("SAVE FAILED!", FlxColor.RED);
		}
	}

	/**
	 * Cargar diálogo
	 */
	function loadDialogue():Void
	{
		// Por ahora, cargar un archivo hardcodeado
		var path = 'assets/songs/${PlayState.SONG.song.toLowerCase()}/' + nameText.text + '.json';
		var loaded = DialogueData.loadDialogue(path);

		if (loaded != null)
		{
			conversation = loaded;
			nameText.text = conversation.name;
			bgColorText.text = conversation.backgroundColor;
			styleText.text = conversation.style;
			selectedMessageIndex = -1;
			refreshMessageList();

			trace('Dialogue loaded from: $path');
			showMessage("LOADED!", FlxColor.GREEN);
		}
		else
		{
			showMessage("LOAD FAILED!", FlxColor.RED);
		}
	}

	/**
	 * Probar diálogo
	 */
	function testDialogue():Void
	{
		// Actualizar datos antes de probar
		conversation.name = nameText.text;
		conversation.style = styleText.text;
		conversation.backgroundColor = bgColorText.text;

		// Guardar temporalmente
		var tempPath = 'assets/songs/${PlayState.SONG.song.toLowerCase()}/temp_test.json';
		DialogueData.saveDialogue(tempPath, conversation);

		// Crear preview
		if (previewBox != null)
		{
			remove(previewBox);
			previewBox.destroy();
		}

		previewBox = new DialogueBoxImproved(tempPath);
		previewBox.finishThing = function()
		{
			remove(previewBox);
			previewBox = null;
		};
		add(previewBox);
	}

	/**
	 * Limpiar todo
	 */
	function clearDialogue():Void
	{
		conversation = {
			name: "new_dialogue",
			style: "pixel",
			backgroundColor: "#B3DFD8",
			fadeTime: 0.83,
			messages: []
		};

		nameText.text = conversation.name;
		bgColorText.text = conversation.backgroundColor;
		styleText.text = conversation.style;
		selectedMessageIndex = -1;

		characterText.text = "";
		messageText.text = "";
		speedText.text = "0.04";
		bubbleTypeText.text = "normal";

		refreshMessageList();
	}

	/**
	 * Mostrar mensaje temporal
	 */
	function showMessage(msg:String, color:FlxColor):Void
	{
		var successText = new FlxText(0, FlxG.height / 2, FlxG.width, msg, 40);
		successText.alignment = CENTER;
		successText.color = color;
		successText.setBorderStyle(OUTLINE, FlxColor.BLACK, 3);
		add(successText);

		new flixel.util.FlxTimer().start(1.5, function(tmr)
		{
			remove(successText);
		});
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		// Atajos de teclado
		if (FlxG.keys.justPressed.ESCAPE)
		{
			FlxG.switchState(new funkin.gameplay.PlayState());
			PlayState.instance.paused = false;
            FlxG.mouse.visible = false;
		}

		if (nameText.hasFocus || messageText.hasFocus || characterText.hasFocus)
			return;

		if (FlxG.keys.pressed.CONTROL)
		{
			if (FlxG.keys.justPressed.S)
			{
				saveDialogue();
			}

			if (FlxG.keys.justPressed.T)
			{
				testDialogue();
			}

			if (FlxG.keys.justPressed.N)
			{
				addMessage();
			}
		}
	}
}
