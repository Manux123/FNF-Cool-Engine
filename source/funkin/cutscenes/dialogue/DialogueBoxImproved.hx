package funkin.cutscenes.dialogue;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.text.FlxTypeText;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import funkin.gameplay.PlayState;
import ui.Alphabet;
import funkin.cutscenes.dialogue.DialogueData;
import funkin.cutscenes.dialogue.DialogueData.DialogueConversation;

using StringTools;

/**
 * DialogueBox mejorado con soporte para JSON y múltiples estilos
 */
class DialogueBoxImproved extends FlxSpriteGroup
{
	// === SPRITES ===
	var box:FlxSprite;
	var portraitLeft:FlxSprite;
	var portraitRight:FlxSprite;
	var handSelect:FlxSprite;
	var bgFade:FlxSprite;

	// === TEXTO ===
	var swagDialogue:FlxTypeText;
	var dropText:FlxText;
	var controlsText:FlxText;

	// === DATOS ===
	var conversation:DialogueConversation;
	var currentMessageIndex:Int = 0;
	var currentStyle:DialogueStyle;

	// === CALLBACKS ===
	public var finishThing:Void->Void;

	var textFinished:Bool = false;

	// === ESTADO ===
	var dialogueOpened:Bool = false;
	var dialogueStarted:Bool = false;
	var isEnding:Bool = false;

	// === CONFIGURACIÓN ===
	var pixelZoom:Float = 6.0; // PlayStateConfig.PIXEL_ZOOM

	// === RUTAS DE ASSETS ===
	static final PIXEL_BOX_PATH = 'UI/pixelUI/dialogue/';
	static final NORMAL_BOX_PATH = 'UI/normal/dialogue/';
	static final PIXEL_PORTRAIT_PATH = 'UI/pixelUI/dialogue/portraits/';
	static final NORMAL_PORTRAIT_PATH = 'UI/normal/dialogue/portraits/';

	/**
	 * Constructor desde JSON
	 */
	public function new(dialoguePath:String)
	{
		super();

		// Cargar datos desde JSON
		conversation = DialogueData.loadDialogue(dialoguePath);

		if (conversation == null)
		{
			trace('Failed to load dialogue from: $dialoguePath');
			return;
		}

		// Determinar estilo
		currentStyle = (conversation.style == 'pixel') ? DialogueStyle.PIXEL : DialogueStyle.NORMAL;

		// Crear fondo
		createBackground();

		// Crear elementos según el estilo
		if (currentStyle == DialogueStyle.PIXEL)
		{
			createPixelDialogue();
		}
		else
		{
			createNormalDialogue();
		}

		// Crear texto de controles
		createControlsText();
	}

	/**
	 * Constructor legacy (para compatibilidad)
	 */
	public static function fromArray(talkingRight:Bool = true, dialogueList:Array<String>, style:String = 'pixel'):DialogueBoxImproved
	{
		// Convertir array antiguo a formato JSON
		var messages:Array<DialogueMessage> = [];

		for (line in dialogueList)
		{
			var splitName:Array<String> = line.split(":");
			var character = splitName[1];
			var text = line.substr(splitName[1].length + 2).trim();

			messages.push({
				character: character,
				text: text,
				bubbleType: 'normal',
				speed: 0.04
			});
		}

		var conv:DialogueConversation = {
			name: "legacy_dialogue",
			style: style,
			backgroundColor: "#B3DFD8",
			fadeTime: 0.83,
			messages: messages
		};

		if (PlayState.SONG.song == null)
			PlayState.SONG.song = 'Test';
		// Crear archivo temporal
		var tempPath = 'assets/songs/${PlayState.SONG.song.toLowerCase()}/temp_dialogue.json';
		DialogueData.saveDialogue(tempPath, conv);

		return new DialogueBoxImproved(tempPath);
	}

	/**
	 * Crear fondo con fade
	 */
	function createBackground():Void
	{
		var bgColor:FlxColor = FlxColor.fromString(conversation.backgroundColor ?? '#B3DFD8');

		bgFade = new FlxSprite(-200, -200).makeGraphic(Std.int(FlxG.width * 1.3), Std.int(FlxG.height * 1.3), bgColor);
		bgFade.scrollFactor.set();
		bgFade.alpha = 0;
		add(bgFade);

		// Fade in
		var fadeTime = conversation.fadeTime ?? 0.83;
		new FlxTimer().start(fadeTime / 5, function(tmr:FlxTimer)
		{
			bgFade.alpha += (1 / 5) * 0.7;
			if (bgFade.alpha > 0.7)
				bgFade.alpha = 0.7;
		}, 5);
	}

	/**
	 * Crear diálogo estilo pixel
	 */
	function createPixelDialogue():Void
	{
		// Caja de diálogo
		box = new FlxSprite(-20, 45);

		var firstMessage = conversation.messages[0];
		var boxPath = firstMessage.boxSprite ?? PIXEL_BOX_PATH + 'dialogueBox-pixel';

		box.frames = Paths.getSparrowAtlas(boxPath);
		box.animation.addByPrefix('normalOpen', 'Text Box Appear', 24, false);
		box.animation.addByIndices('normal', 'Text Box Appear', [4], "", 24);
		box.animation.play('normalOpen');
		box.setGraphicSize(Std.int(box.width * pixelZoom * 0.9));
		box.updateHitbox();
		box.screenCenter(X);
		add(box);

		// Portraits
		createPixelPortraits();

		// Texto con sombra
		dropText = new FlxText(242, 502, Std.int(FlxG.width * 0.6), "", 32);
		dropText.font = 'Pixel Arial 11 Bold';
		dropText.color = 0xFFD89494;
		add(dropText);

		swagDialogue = new FlxTypeText(240, 500, Std.int(FlxG.width * 0.6), "", 32);
		swagDialogue.font = 'Pixel Arial 11 Bold';
		swagDialogue.color = 0xFF3F2021;

		var soundPath = firstMessage.sound ?? 'pixelText';
		swagDialogue.sounds = [FlxG.sound.load(Paths.sound(soundPath), 0.6)];
		add(swagDialogue);

		// Hand selector
		handSelect = new FlxSprite(FlxG.width * 0.9, FlxG.height * 0.9);
		handSelect.loadGraphic(Paths.image('UI/pixelUI/dialogue/hand_textbox'));
		add(handSelect);
	}

	/**
	 * Crear diálogo estilo normal
	 */
	function createNormalDialogue():Void
	{
		// Caja de diálogo
		box = new FlxSprite(0, FlxG.height - 350);

		var firstMessage = conversation.messages[0];
		var boxPath = firstMessage.boxSprite ?? NORMAL_BOX_PATH + 'speech_bubble_talking';

		box.frames = Paths.getSparrowAtlas(boxPath);
		box.animation.addByPrefix('normalOpen', 'Speech Bubble Normal Open', 24, false);
		box.animation.addByPrefix('normal', 'speech bubble normal', 24, true);
		box.animation.addByPrefix('loud', 'speech bubble loud open', 24, false);
		box.animation.play('normalOpen');
		box.screenCenter(X);
		add(box);

		// Portraits
		createNormalPortraits();

		// Texto
		swagDialogue = new FlxTypeText(180, FlxG.height - 250, Std.int(FlxG.width * 0.7), "", 42);
		swagDialogue.font = 'VCR OSD Mono';
		swagDialogue.color = FlxColor.BLACK;

		var soundPath = firstMessage.sound ?? 'dialogueText';
		swagDialogue.sounds = [FlxG.sound.load(Paths.sound(soundPath), 0.6)];
		add(swagDialogue);
	}

	/**
	 * Crear portraits estilo pixel
	 */
	function createPixelPortraits():Void
	{
		// Portrait izquierdo (opponent)
		portraitLeft = new FlxSprite(-20, 40);
		portraitLeft.frames = Paths.getSparrowAtlas(PIXEL_PORTRAIT_PATH + 'senpaiPortrait');
		portraitLeft.animation.addByPrefix('enter', 'Senpai Portrait Enter', 24, false);
		portraitLeft.setGraphicSize(Std.int(portraitLeft.width * pixelZoom * 0.9));
		portraitLeft.updateHitbox();
		portraitLeft.scrollFactor.set();
		portraitLeft.screenCenter(X);
		portraitLeft.visible = false;
		add(portraitLeft);

		// Portrait derecho (boyfriend)
		portraitRight = new FlxSprite(0, 40);
		portraitRight.frames = Paths.getSparrowAtlas(PIXEL_PORTRAIT_PATH + 'bfPortrait');
		portraitRight.animation.addByPrefix('enter', 'Boyfriend portrait enter', 24, false);
		portraitRight.setGraphicSize(Std.int(portraitRight.width * pixelZoom * 0.9));
		portraitRight.updateHitbox();
		portraitRight.scrollFactor.set();
		portraitRight.visible = false;
		add(portraitRight);
	}

	/**
	 * Crear portraits estilo normal
	 */
	function createNormalPortraits():Void
	{
		// Portrait izquierdo (opponent)
		portraitLeft = new FlxSprite(50, FlxG.height - 500);
		portraitLeft.frames = Paths.getSparrowAtlas(NORMAL_PORTRAIT_PATH + 'dad-portrait');
		portraitLeft.animation.addByPrefix('idle', 'dad portrait', 24, false);
		portraitLeft.animation.addByPrefix('enter', 'dad portrait enter', 24, false);
		portraitLeft.scrollFactor.set();
		portraitLeft.visible = false;
		add(portraitLeft);

		// Portrait derecho (boyfriend)
		portraitRight = new FlxSprite(FlxG.width - 450, FlxG.height - 500);
		portraitRight.frames = Paths.getSparrowAtlas(NORMAL_PORTRAIT_PATH + 'bf-portrait');
		portraitRight.animation.addByPrefix('idle', 'bf portrait', 24, false);
		portraitRight.animation.addByPrefix('enter', 'bf portrait enter', 24, false);
		portraitRight.scrollFactor.set();
		portraitRight.visible = false;
		add(portraitRight);
	}

	/**
	 * Crear texto de controles
	 */
	function createControlsText():Void
	{
		controlsText = new FlxText(0, 50, 'Press ENTER to continue | SHIFT to skip');
		controlsText.size = 24;
		controlsText.x = FlxG.width - controlsText.width - 20;
		controlsText.y = FlxG.height - 60;
		controlsText.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 3, 1);
		controlsText.color = FlxColor.WHITE;
		controlsText.scrollFactor.set();
		add(controlsText);
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		// Actualizar sombra del texto (solo pixel)
		if (currentStyle == DialogueStyle.PIXEL && dropText != null)
		{
			dropText.text = swagDialogue.text;
		}

		// Esperar a que la caja termine de abrir
		if (box.animation.curAnim != null)
		{
			if (box.animation.curAnim.name == 'normalOpen' && box.animation.curAnim.finished)
			{
				box.animation.play('normal');
				dialogueOpened = true;
			}
		}

		// Iniciar diálogo
		if (dialogueOpened && !dialogueStarted)
		{
			startDialogue();
			dialogueStarted = true;
		}

		// Input para avanzar
		handleInput();
	}

	/**
	 * Manejar input del jugador
	 */
	function handleInput():Void
	{
		if (!dialogueStarted || isEnding)
			return;

		// 1. SKIP COMPLETO CON SHIFT (Se mantiene intacto)
		if (FlxG.keys.justPressed.SHIFT)
		{
			FlxG.sound.play(Paths.sound('clickText'), 0.8);
			endDialogue();
			return;
		}

		// 2. AVANZAR O COMPLETAR TEXTO
		var acceptInput = FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE;

		if (acceptInput)
		{
			if (!textFinished)
			{
				swagDialogue.skip();
				textFinished = true; // Forzamos a true porque skip() termina el texto
				return;
			}

			// Si ya terminó, avanzamos
			FlxG.sound.play(Paths.sound('clickText'), 0.8);
			currentMessageIndex++;

			if (currentMessageIndex >= conversation.messages.length)
			{
				endDialogue();
			}
			else
			{
				startDialogue();
			}
		}
	}

	/**
	 * Iniciar el mensaje actual
	 */
	function startDialogue():Void
	{
		if (currentMessageIndex >= conversation.messages.length)
		{
			endDialogue();
			return;
		}

		var msg = conversation.messages[currentMessageIndex];

		// Actualizar texto
		swagDialogue.resetText(msg.text);
		swagDialogue.start(msg.speed ?? 0.04, true, false, null, function()
		{
			textFinished = true;
		});

		// Actualizar portraits
		updatePortraits(msg.character);

		// Actualizar animación de la caja según el tipo
		if (currentStyle == DialogueStyle.NORMAL)
		{
			switch (msg.bubbleType)
			{
				case 'loud':
					box.animation.play('loud');
				case 'normal' | _:
					box.animation.play('normal');
			}
		}
	}

	/**
	 * Actualizar portraits según el personaje
	 */
	function updatePortraits(character:String):Void
	{
		switch (character.toLowerCase())
		{
			case 'dad':
				portraitRight.visible = false;
				if (!portraitLeft.visible)
				{
					portraitLeft.visible = true;
					portraitLeft.animation.play('enter');
				}

			case 'bf' | 'boyfriend':
				portraitLeft.visible = false;
				if (!portraitRight.visible)
				{
					portraitRight.visible = true;
					portraitRight.animation.play('enter');
				}
		}
	}

	/**
	 * Terminar el diálogo
	 */
	function endDialogue():Void
	{
		if (isEnding)
			return;
		isEnding = true;

		// Fade out
		new FlxTimer().start(0.2, function(tmr:FlxTimer)
		{
			box.alpha -= 1 / 5;
			bgFade.alpha -= 1 / 5 * 0.7;
			portraitLeft.visible = false;
			portraitRight.visible = false;
			swagDialogue.alpha -= 1 / 5;

			if (dropText != null)
				dropText.alpha = swagDialogue.alpha;

			if (handSelect != null)
				handSelect.alpha -= 1 / 5;

			controlsText.alpha -= 1 / 5;
		}, 5);

		new FlxTimer().start(1.2, function(tmr:FlxTimer)
		{
			if (finishThing != null)
				finishThing();
			kill();
		});
	}
}
