package funkin.menus;

#if desktop
import data.Discord.DiscordClient;
#end
import funkin.scripting.StateScriptHandler;
import funkin.gameplay.controls.CustomControlsState;
import funkin.gameplay.notes.NoteSkinOptions;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import extensions.CoolUtil;
import funkin.gameplay.PlayState;
import funkin.states.MusicBeatState;
import funkin.states.MusicBeatSubstate;
import funkin.menus.MainMenuState;
import data.PlayerSettings;
import openfl.Lib;

/**
 * Options Menu - Sistema de tabs integrado con keybinds
 * EXTENSIBLE: Usa StateScriptHandler para opciones dinámicas
 */
class OptionsMenuState extends MusicBeatSubstate
{
	// Categorías principales (se pueden agregar más desde scripts)
	var categories:Array<String> = ['General', 'Graphics', 'Gameplay', 'Controls', 'Note Skin', 'Offset'];
	var curCategory:Int = 0;
	
	// UI Elements
	var menuBG:FlxSprite;
	var categoryTexts:FlxTypedGroup<FlxText>;
	var contentPanel:FlxTypedGroup<FlxSprite>;
	
	// Current tab content
	var optionNames:FlxTypedGroup<FlxText>;
	var optionValues:FlxTypedGroup<FlxText>;
	var curSelected:Int = 0;
	var currentOptions:Array<Dynamic> = [];
	
	// Keybind state
	var bindingState:String = "select"; // "select", "binding"
	var tempKey:String = "";
	var keyBindNames:Array<String> = ["LEFT", "DOWN", "UP", "RIGHT", "RESET"];
	var defaultKeys:Array<String> = ["A", "S", "W", "D", "R"];
	var blacklistKeys:Array<String> = ["ESCAPE", "ENTER", "BACKSPACE", "SPACE"];
	var keys:Array<String> = [];
	
	var warningText:FlxText;
	var bindingIndicator:FlxText;
	
	public static var fromPause:Bool = false;

	override function create()
	{
		#if HSCRIPT_ALLOWED
		StateScriptHandler.init();
		StateScriptHandler.loadStateScripts('OptionsMenuState', this);
		
		// Cargar categorías custom desde scripts
		loadCustomCategoriesFromScripts();
		
		StateScriptHandler.callOnScripts('onCreate', []);
		#end
		
		#if desktop
		DiscordClient.changePresence("Options Menu", null);
		#end

		// Inicializar keybinds
		loadKeyBinds();

		// Background semi-transparente (ajustar alpha si viene desde pause)
		var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = fromPause ? 0.5 : 0.7;
		bg.scrollFactor.set();
		add(bg);

		// Borde del panel (agregar primero para que esté detrás)
		var borderThickness = 3;
		var panelBorder = new FlxSprite(50 - borderThickness, 80 - borderThickness)
			.makeGraphic(Std.int(FlxG.width - 100 + borderThickness * 2), Std.int(FlxG.height - 160 + borderThickness * 2), 0xFF2a2a2a);
		panelBorder.scrollFactor.set();
		add(panelBorder);
		
		// Panel principal con borde
		menuBG = new FlxSprite(50, 80).makeGraphic(FlxG.width - 100, FlxG.height - 160, 0xFF0a0a0a);
		menuBG.scrollFactor.set();
		add(menuBG);

		// Título del menú
		var titleText = new FlxText(0, 20, FlxG.width, "OPTIONS MENU", 48);
		titleText.setFormat(Paths.font("Funkin.otf"), 48, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		titleText.borderSize = 3;
		titleText.scrollFactor.set();
		add(titleText);

		// Crear contentPanel ANTES de usarlo
		contentPanel = new FlxTypedGroup<FlxSprite>();
		add(contentPanel);

		// Categorías en la parte superior con backgrounds individuales
		categoryTexts = new FlxTypedGroup<FlxText>();
		add(categoryTexts);

		var categoryWidth = (FlxG.width - 120) / categories.length;
		var tabHeight = 40;
		var tabY = 85;
		
		for (i in 0...categories.length)
		{
			// Background de la pestaña (inicialmente inactiva)
			var tabBG = new FlxSprite(60 + (i * categoryWidth), tabY).makeGraphic(Std.int(categoryWidth - 4), tabHeight, 0xFF1a1a1a);
			tabBG.scrollFactor.set();
			tabBG.ID = i;
			contentPanel.add(tabBG);
			
			// Borde superior de la pestaña
			var tabBorder = new FlxSprite(tabBG.x, tabBG.y - 2).makeGraphic(Std.int(tabBG.width), 2, 0xFF444444);
			tabBorder.scrollFactor.set();
			tabBorder.ID = i;
			contentPanel.add(tabBorder);
			
			var categoryText:FlxText = new FlxText(60 + (i * categoryWidth), tabY + 8, categoryWidth, categories[i], 24);
			categoryText.setFormat(Paths.font("Funkin.otf"), 22, 0xFF888888, CENTER, OUTLINE, FlxColor.BLACK);
			categoryText.borderSize = 2;
			categoryText.ID = i;
			categoryText.scrollFactor.set();
			categoryTexts.add(categoryText);
		}
		
		// Separador horizontal entre pestañas y contenido
		var separator = new FlxSprite(menuBG.x, tabY + tabHeight).makeGraphic(Std.int(menuBG.width), 3, 0xFF444444);
		separator.scrollFactor.set();
		add(separator);
		
		// Indicador de pestaña activa (barra inferior)
		var activeIndicator = new FlxSprite(0, tabY + tabHeight - 3).makeGraphic(Std.int(categoryWidth - 4), 3, FlxColor.CYAN);
		activeIndicator.scrollFactor.set();
		activeIndicator.ID = -1; // ID especial para el indicador
		contentPanel.add(activeIndicator);

		optionNames = new FlxTypedGroup<FlxText>();
		add(optionNames);

		optionValues = new FlxTypedGroup<FlxText>();
		add(optionValues);

		// Warning text para keybinds
		warningText = new FlxText(0, 140, FlxG.width, "", 20);
		warningText.setFormat(Paths.font("Funkin.otf"), 20, FlxColor.RED, CENTER, OUTLINE, FlxColor.BLACK);
		warningText.borderSize = 2;
		warningText.alpha = 0;
		warningText.scrollFactor.set();
		add(warningText);

		// Binding indicator
		bindingIndicator = new FlxText(0, FlxG.height - 120, FlxG.width, "", 22);
		bindingIndicator.setFormat(Paths.font("Funkin.otf"), 22, FlxColor.YELLOW, CENTER, OUTLINE, FlxColor.BLACK);
		bindingIndicator.borderSize = 2;
		bindingIndicator.visible = false;
		bindingIndicator.scrollFactor.set();
		add(bindingIndicator);

		// Footer con ayuda de controles
		var footerBG = new FlxSprite(menuBG.x, FlxG.height - 100).makeGraphic(Std.int(menuBG.width), 50, 0xFF1a1a1a);
		footerBG.scrollFactor.set();
		add(footerBG);
		
		var footerBorder = new FlxSprite(footerBG.x, footerBG.y).makeGraphic(Std.int(footerBG.width), 2, 0xFF444444);
		footerBorder.scrollFactor.set();
		add(footerBorder);
		
		var helpText = new FlxText(footerBG.x + 20, footerBG.y + 12, footerBG.width - 40, 
			"← → : Change Tab  |  ↑ ↓ : Navigate  |  ENTER : Toggle/Select  |  ESC : Back", 18);
		helpText.setFormat(Paths.font("Funkin.otf"), 18, 0xFFAAAAAA, CENTER, OUTLINE, FlxColor.BLACK);
		helpText.borderSize = 1.5;
		helpText.scrollFactor.set();
		add(helpText);

		loadCategory(curCategory);

		// Configurar cámaras si se abre desde pause menu
		if (fromPause)
		{
			cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
		}

		super.create();
	}

	#if HSCRIPT_ALLOWED
	/**
	 * Carga categorías custom registradas desde scripts
	 */
	function loadCustomCategoriesFromScripts():Void
	{
		var customCategories = StateScriptHandler.getCustomCategories();
		for (categoryName in customCategories)
		{
			if (!categories.contains(categoryName))
			{
				categories.push(categoryName);
			}
		}
	}
	#end

	function loadKeyBinds()
	{
		// Verificar que existan los keybinds
		if (FlxG.save.data.leftBind == null) FlxG.save.data.leftBind = "A";
		if (FlxG.save.data.downBind == null) FlxG.save.data.downBind = "S";
		if (FlxG.save.data.upBind == null) FlxG.save.data.upBind = "W";
		if (FlxG.save.data.rightBind == null) FlxG.save.data.rightBind = "D";
		if (FlxG.save.data.killBind == null) FlxG.save.data.killBind = "R";

		keys = [
			FlxG.save.data.leftBind,
			FlxG.save.data.downBind,
			FlxG.save.data.upBind,
			FlxG.save.data.rightBind,
			FlxG.save.data.killBind
		];
	}

	function saveKeyBinds()
	{
		FlxG.save.data.leftBind = keys[0];
		FlxG.save.data.downBind = keys[1];
		FlxG.save.data.upBind = keys[2];
		FlxG.save.data.rightBind = keys[3];
		FlxG.save.data.killBind = keys[4];

		FlxG.save.flush();
		PlayerSettings.player1.controls.loadKeyBinds();
	}

	function loadCategory(index:Int)
	{
		// Limpiar contenido anterior
		optionNames.clear();
		optionValues.clear();
		currentOptions = [];
		curSelected = 0;
		bindingState = "select";
		bindingIndicator.visible = false;

		var categoryName = categories[index];

		switch (categoryName)
		{
			case 'General':
				loadGeneralOptions();
			case 'Graphics':
				loadGraphicsOptions();
			case 'Gameplay':
				loadGameplayOptions();
			case 'Controls':
				loadControlsOptions();
			case 'Note Skin':
				loadNoteSkinOptions();
			case 'Offset':
				loadOffsetOptions();
			default:
				// Categoría custom desde script
				#if HSCRIPT_ALLOWED
				loadCustomCategory(categoryName);
				#end
		}

		// Agregar opciones custom a categorías existentes desde scripts
		#if HSCRIPT_ALLOWED
		loadCustomOptionsForCategory(categoryName);
		#end

		updateCategoryDisplay();
		updateOptionDisplay();
	}

	#if HSCRIPT_ALLOWED
	/**
	 * Carga una categoría custom completa desde scripts
	 */
	function loadCustomCategory(categoryName:String):Void
	{
		// Llamar a los scripts para obtener opciones de esta categoría
		var customOptions = StateScriptHandler.callOnScriptsReturn('getOptionsForCategory', [categoryName]);
		
		if (customOptions != null && Std.isOfType(customOptions, Array))
		{
			var optionsArray:Array<Dynamic> = cast customOptions;
			for (opt in optionsArray)
			{
				currentOptions.push(opt);
			}
		}
		
		createOptionTexts();
	}

	/**
	 * Carga opciones custom que se agregan a categorías existentes
	 */
	function loadCustomOptionsForCategory(categoryName:String):Void
	{
		// Llamar a los scripts para obtener opciones adicionales para esta categoría
		var additionalOptions = StateScriptHandler.callOnScriptsReturn('getAdditionalOptionsForCategory', [categoryName]);
		
		if (additionalOptions != null && Std.isOfType(additionalOptions, Array))
		{
			var optionsArray:Array<Dynamic> = cast additionalOptions;
			for (opt in optionsArray)
			{
				currentOptions.push(opt);
			}
			
			// Recrear los textos con las opciones adicionales
			optionNames.clear();
			optionValues.clear();
			createOptionTexts();
		}
	}
	#end

	function loadGeneralOptions()
	{
		currentOptions = [
			{
				name: "Flashing Lights",
				get: function() return FlxG.save.data.flashing ? "ON" : "OFF",
				toggle: function() { FlxG.save.data.flashing = !FlxG.save.data.flashing; }
			},
			{
				name: "Camera Zoom",
				get: function() return FlxG.save.data.camZoom ? "ON" : "OFF",
				toggle: function() { FlxG.save.data.camZoom = !FlxG.save.data.camZoom; }
			},
			{
				name: "Show HUD",
				get: function() return FlxG.save.data.HUD ? "OFF" : "ON",
				toggle: function() { FlxG.save.data.HUD = !FlxG.save.data.HUD; }
			},
			{
				name: "FPS Counter",
				get: function() {
					var mainInstance = cast(openfl.Lib.current.getChildAt(0), Main);
					return mainInstance.data.visible ? "ON" : "OFF";
				},
				toggle: function() {
					var mainInstance = cast(openfl.Lib.current.getChildAt(0), Main);
					mainInstance.data.visible = !mainInstance.data.visible;
				}
			}
		];

		createOptionTexts();
	}

	function loadGraphicsOptions()
	{
		currentOptions = [
			{
				name: "Anti-Aliasing",
				get: function() return FlxG.save.data.antialiasing ? "ON" : "OFF",
				toggle: function() { FlxG.save.data.antialiasing = !FlxG.save.data.antialiasing; }
			},
			{
				name: "Note Splashes",
				get: function() return FlxG.save.data.notesplashes ? "ON" : "OFF",
				toggle: function() { FlxG.save.data.notesplashes = !FlxG.save.data.notesplashes; }
			},
			{
				name: "Visual Effects",
				get: function() return FlxG.save.data.specialVisualEffects ? "ON" : "OFF",
				toggle: function() { FlxG.save.data.specialVisualEffects = !FlxG.save.data.specialVisualEffects; }
			},
			{
				name: "Static Stage",
				get: function() return FlxG.save.data.staticstage ? "ON" : "OFF",
				toggle: function() { FlxG.save.data.staticstage = !FlxG.save.data.staticstage; }
			}
		];

		createOptionTexts();
	}

	function loadGameplayOptions()
	{
		currentOptions = [
			{
				name: "Downscroll",
				get: function() return FlxG.save.data.downscroll ? "ON" : "OFF",
				toggle: function() { FlxG.save.data.downscroll = !FlxG.save.data.downscroll; }
			},
			{
				name: "Middlescroll",
				get: function() return FlxG.save.data.middlescroll ? "ON" : "OFF",
				toggle: function() { FlxG.save.data.middlescroll = !FlxG.save.data.middlescroll; }
			},
			{
				name: "Ghost Tapping",
				get: function() return FlxG.save.data.ghosttap ? "ON" : "OFF",
				toggle: function() { FlxG.save.data.ghosttap = !FlxG.save.data.ghosttap; }
			},
			{
				name: "Accuracy Display",
				get: function() return FlxG.save.data.accuracyDisplay ? "ON" : "OFF",
				toggle: function() { FlxG.save.data.accuracyDisplay = !FlxG.save.data.accuracyDisplay; }
			},
			{
				name: "Sick Mode",
				get: function() return FlxG.save.data.sickmode ? "ON" : "OFF",
				toggle: function() { FlxG.save.data.sickmode = !FlxG.save.data.sickmode; }
			},
			{
				name: "Hit Sounds",
				get: function() return FlxG.save.data.hitsounds ? "ON" : "OFF",
				toggle: function() { FlxG.save.data.hitsounds = !FlxG.save.data.hitsounds; }
			}
		];

		createOptionTexts();
	}

	function loadControlsOptions()
	{
		currentOptions = [];

		// Cargar keybinds actuales
		for (i in 0...5)
		{
			var keyIndex = i;
			currentOptions.push({
				name: keyBindNames[i],
				get: function() return keys[keyIndex],
				toggle: function() { startBinding(keyIndex); },
				isKeybind: true
			});
		}

		// Opción de resetear
		currentOptions.push({
			name: "Reset to Default",
			get: function() return "BACKSPACE",
			toggle: function() { resetKeybinds(); },
			isKeybind: false
		});

		createOptionTexts();
	}

	function loadNoteSkinOptions()
	{
		currentOptions = [
			{
				name: "Note Skin Settings",
				get: function() return "PRESS ENTER",
				toggle: function() { 
					FlxG.switchState(new NoteSkinOptions());
				}
			}
		];

		createOptionTexts();
	}

	function loadOffsetOptions()
	{
		currentOptions = [
			{
				name: "Audio Offset",
				get: function() return FlxG.save.data.offset + " ms",
				toggle: function() { 
					openSubState(new OffsetCalibrationState());
				}
			}
		];

		createOptionTexts();
	}

	function createOptionTexts()
	{
		var startY = 180; // Más abajo para dar espacio a las pestañas
		var spacing = 55; // Más espaciado para mejor lectura

		for (i in 0...currentOptions.length)
		{
			var nameText:FlxText = new FlxText(90, startY + (i * spacing), 600, currentOptions[i].name, 26);
			nameText.setFormat(Paths.font("Funkin.otf"), 26, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
			nameText.borderSize = 2;
			nameText.ID = i;
			nameText.scrollFactor.set();
			optionNames.add(nameText);

			var valueText:FlxText = new FlxText(FlxG.width - 400, startY + (i * spacing), 320, currentOptions[i].get(), 26);
			valueText.setFormat(Paths.font("Funkin.otf"), 26, FlxColor.CYAN, RIGHT, OUTLINE, FlxColor.BLACK);
			valueText.borderSize = 2;
			valueText.ID = i;
			valueText.scrollFactor.set();
			optionValues.add(valueText);
		}
	}

	function updateCategoryDisplay()
	{
		var categoryWidth = (FlxG.width - 120) / categories.length;
		
		// Actualizar textos de categorías
		categoryTexts.forEach(function(txt:FlxText)
		{
			if (txt.ID == curCategory)
			{
				txt.color = FlxColor.WHITE;
				txt.setFormat(Paths.font("Funkin.otf"), 24, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
				
				// Animar el texto
				FlxTween.cancelTweensOf(txt.scale);
				FlxTween.tween(txt.scale, {x: 1.05, y: 1.05}, 0.2, {ease: FlxEase.quadOut});
			}
			else
			{
				txt.color = 0xFF888888;
				txt.setFormat(Paths.font("Funkin.otf"), 22, 0xFF888888, CENTER, OUTLINE, FlxColor.BLACK);
				
				FlxTween.cancelTweensOf(txt.scale);
				FlxTween.tween(txt.scale, {x: 1, y: 1}, 0.2, {ease: FlxEase.quadOut});
			}
		});
		
		// Actualizar backgrounds de pestañas
		contentPanel.forEach(function(sprite:FlxSprite)
		{
			if (sprite.ID >= 0 && sprite.ID < categories.length)
			{
				if (sprite.ID == curCategory)
				{
					// Pestaña activa - más clara y brillante
					sprite.color = 0xFF2a2a2a;
					sprite.alpha = 1;
				}
				else
				{
					// Pestaña inactiva - más oscura
					sprite.color = 0xFF1a1a1a;
					sprite.alpha = 0.7;
				}
			}
			
			// Mover el indicador de pestaña activa
			if (sprite.ID == -1) // El indicador tiene ID -1
			{
				var targetX = 60 + (curCategory * categoryWidth);
				FlxTween.cancelTweensOf(sprite);
				FlxTween.tween(sprite, {x: targetX}, 0.3, {ease: FlxEase.quadOut});
			}
		});
	}

	function updateOptionDisplay()
	{
		optionNames.forEach(function(txt:FlxText)
		{
			if (txt.ID == curSelected)
			{
				txt.color = FlxColor.CYAN;
				txt.alpha = 1;
				
				// Animar el texto seleccionado
				FlxTween.cancelTweensOf(txt.scale);
				FlxTween.tween(txt.scale, {x: 1.08, y: 1.08}, 0.15, {ease: FlxEase.quadOut});
			}
			else
			{
				txt.color = FlxColor.WHITE;
				txt.alpha = 0.6;
				
				FlxTween.cancelTweensOf(txt.scale);
				FlxTween.tween(txt.scale, {x: 1, y: 1}, 0.15, {ease: FlxEase.quadOut});
			}
		});

		optionValues.forEach(function(txt:FlxText)
		{
			if (txt.ID == curSelected)
			{
				txt.alpha = 1;
				txt.color = FlxColor.YELLOW;
				
				// Animar el valor seleccionado
				FlxTween.cancelTweensOf(txt.scale);
				FlxTween.tween(txt.scale, {x: 1.08, y: 1.08}, 0.15, {ease: FlxEase.quadOut});
			}
			else
			{
				txt.alpha = 0.6;
				txt.color = FlxColor.CYAN;
				
				FlxTween.cancelTweensOf(txt.scale);
				FlxTween.tween(txt.scale, {x: 1, y: 1}, 0.15, {ease: FlxEase.quadOut});
			}
			
			txt.text = currentOptions[txt.ID].get();
		});
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		#if HSCRIPT_ALLOWED
		StateScriptHandler.callOnScripts('onUpdate', [elapsed]);
		#end

		// Si estamos esperando un keybind
		if (bindingState == "binding")
		{
			handleKeyBinding();
			return;
		}

		// Navegación de categorías
		if (controls.LEFT_P && currentOptions.length > 0)
		{
			changeCategory(-1);
		}
		if (controls.RIGHT_P && currentOptions.length > 0)
		{
			changeCategory(1);
		}

		// Navegación de opciones
		if (controls.UP_P)
		{
			changeSelection(-1);
		}
		if (controls.DOWN_P)
		{
			changeSelection(1);
		}

		// Aceptar/Toggle opción
		if (controls.ACCEPT && currentOptions.length > 0)
		{
			FlxG.sound.play(Paths.sound('menus/confirmMenu'));
			var optionName = currentOptions[curSelected].name;
			currentOptions[curSelected].toggle();
			updateOptionDisplay();
			FlxG.save.flush();
			
			// Si estamos en pause menu
			if (fromPause)
			{
				// Verificar si es una configuración SEGURA para aplicar en tiempo real
				if (isGameplaySetting(optionName))
				{
					applyGameplaySettingsRealtime();
				}
				// Advertir si requiere reinicio
				else if (requiresRestart(optionName))
				{
					showWarning("Restart song to apply changes");
				}
			}
		}

		// Reset keybinds con BACKSPACE (solo en Controls)
		if (FlxG.keys.justPressed.BACKSPACE && categories[curCategory] == 'Controls')
		{
			resetKeybinds();
		}

		// Volver
		if (controls.BACK)
		{
			FlxG.sound.play(Paths.sound('menus/cancelMenu'));
			
			if (fromPause)
			{
				fromPause = false;
				close();
			}
			else
			{
				FlxG.switchState(new MainMenuState());
			}
		}

		#if HSCRIPT_ALLOWED
		StateScriptHandler.callOnScripts('onUpdatePost', [elapsed]);
		#end
	}

	function changeCategory(change:Int)
	{
		FlxG.sound.play(Paths.sound('menus/scrollMenu'), 0.4);
		curCategory += change;

		if (curCategory < 0)
			curCategory = categories.length - 1;
		if (curCategory >= categories.length)
			curCategory = 0;

		loadCategory(curCategory);
	}

	function changeSelection(change:Int)
	{
		if (currentOptions.length == 0) return;

		FlxG.sound.play(Paths.sound('menus/scrollMenu'), 0.4);
		curSelected += change;

		if (curSelected < 0)
			curSelected = currentOptions.length - 1;
		if (curSelected >= currentOptions.length)
			curSelected = 0;

		updateOptionDisplay();
	}

	// === KEYBIND FUNCTIONS ===

	function startBinding(keyIndex:Int)
	{
		bindingState = "binding";
		tempKey = keys[keyIndex];
		
		bindingIndicator.text = "Press any key for " + keyBindNames[keyIndex] + "...\nESC to cancel";
		bindingIndicator.visible = true;
		
		// Cambiar el valor mostrado a "?"
		optionValues.members[curSelected].text = "?";
	}

	function handleKeyBinding()
	{
		// Cancelar con ESC
		if (FlxG.keys.justPressed.ESCAPE)
		{
			keys[curSelected] = tempKey;
			bindingState = "select";
			bindingIndicator.visible = false;
			updateOptionDisplay();
			FlxG.sound.play(Paths.sound('menus/cancelMenu'));
			return;
		}

		// Esperar cualquier tecla
		if (FlxG.keys.justPressed.ANY)
		{
			var pressedKey = FlxG.keys.getIsDown()[0].ID.toString();
			
			if (isKeyValid(pressedKey, curSelected))
			{
				keys[curSelected] = pressedKey;
				saveKeyBinds();
				bindingState = "select";
				bindingIndicator.visible = false;
				updateOptionDisplay();
				FlxG.sound.play(Paths.sound('menus/scrollMenu'));
				
				// Advertir si hay duplicados (pero permitirlos)
				if (hasDuplicateKeys())
				{
					showWarning("Warning: Duplicate keys detected");
				}
			}
			else
			{
				// Mostrar warning
				keys[curSelected] = tempKey;
				showWarning("Invalid key! Key is blocked.");
				bindingState = "select";
				bindingIndicator.visible = false;
				updateOptionDisplay();
				FlxG.sound.play(Paths.sound('menus/cancelMenu'));
			}
		}
	}

	function isKeyValid(key:String, keyIndex:Int):Bool
	{
		// Verificar si está en la blacklist (estas teclas NUNCA se permiten)
		for (blockedKey in blacklistKeys)
		{
			if (key == blockedKey)
				return false;
		}

		// Para RESET, no puede usar ninguna tecla de dirección
		// (esto sí es importante para evitar problemas de input)
		if (keyIndex == 4)
		{
			for (i in 0...4)
			{
				if (keys[i] == key)
					return false;
			}
		}

		// ✅ CAMBIO: Ya NO bloqueamos duplicados en direcciones
		// Permitimos que el usuario configure DFJK aunque D ya esté en uso
		// Solo mostramos una advertencia

		return true;
	}

	/**
	 * Verifica si hay teclas duplicadas en las direcciones
	 */
	function hasDuplicateKeys():Bool
	{
		for (i in 0...4)
		{
			for (j in i + 1...4)
			{
				if (keys[i] == keys[j])
					return true;
			}
		}
		return false;
	}

	function resetKeybinds()
	{
		FlxG.sound.play(Paths.sound('menus/confirmMenu'));
		
		for (i in 0...5)
		{
			keys[i] = defaultKeys[i];
		}
		
		saveKeyBinds();
		loadCategory(curCategory); // Recargar para actualizar valores
		
		showWarning("Keybinds reset to default!");
	}

	function showWarning(text:String)
	{
		warningText.text = text;
		warningText.alpha = 1;
		
		FlxTween.tween(warningText, {alpha: 0}, 0.5, {
			ease: FlxEase.circOut,
			startDelay: 2
		});
	}

	/**
	 * Determina si una configuración es SEGURA para aplicar en tiempo real
	 * Solo configuraciones visuales/UI que no afectan la lógica del juego
	 */
	function isGameplaySetting(optionName:String):Bool
	{
		var safeGameplaySettings = [
			"Ghost Tapping",      // Seguro: solo afecta siguiente input
			"Show HUD",           // Seguro: solo visual
			"Note Splashes",      // Seguro: solo visual
			"Accuracy Display",   // Seguro: solo visual
			"Anti-Aliasing"       // Seguro: solo visual
		];
		
		// Configuraciones que REQUIEREN REINICIO (NO en tiempo real):
		// - Downscroll: requiere reposicionar strums y notas en vuelo
		// - Middlescroll: requiere reorganizar layout completo
		// - Perfect Mode/Sick Mode: cambian lógica de scoring
		// - Static Stage: puede causar memory leaks
		
		return safeGameplaySettings.contains(optionName);
	}

	/**
	 * Verifica si una configuración requiere reiniciar la canción
	 */
	function requiresRestart(optionName:String):Bool
	{
		var restartRequired = [
			"Downscroll",
			"Middlescroll",
			"Perfect Mode",
			"Sick Mode",
			"Static Stage",
			"Special Visual Effects",
			"GF Bye",
			"Background Bye"
		];
		
		return restartRequired.contains(optionName);
	}

	/**
	 * Aplica las configuraciones de gameplay en tiempo real al PlayState
	 */
	function applyGameplaySettingsRealtime():Void
	{
		if (PlayState.instance != null)
		{
			trace('[OptionsMenuState] Applying gameplay settings in real-time');
			PlayState.instance.updateGameplaySettings();
		}
	}

	// === CLASE DE COMPATIBILIDAD PARA Main.hx ===
	
	/**
	 * Inicializa los valores por defecto de las opciones
	 * Llamado desde Main.hx
	 */
	public static function initSave():Void
	{
		OptionsData.initSave();
	}
}

/**
 * Clase de compatibilidad con el sistema antiguo
 */
class OptionsData
{
	public static function initSave():Void
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
	}
}

/**
 * Offset Calibration State - Metrónomo a 100 BPM
 */
class OffsetCalibrationState extends MusicBeatSubstate
{
	var metronomeSound:String = "menus/chartingSounds/metronome";
	var bpm:Float = 100;
	var beatTime:Float = 0;
	var currentBeat:Int = 0;
	
	var instructions:FlxText;
	var offsetDisplay:FlxText;
	var beatIndicator:FlxSprite;
	var visualMetronome:FlxSprite;
	var tapCounter:FlxText;
	
	var taps:Array<Float> = [];
	var maxTaps:Int = 8;
	
	var countdownText:FlxText;
	var isCountingDown:Bool = true;
	var countdownTimer:Float = 3;

	override function create()
	{
		super.create();

		// Background
		var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0.85;
		add(bg);

		// Panel principal
		var panel:FlxSprite = new FlxSprite(0, 0).makeGraphic(800, 600, 0xFF1a1a1a);
		panel.screenCenter();
		add(panel);

		// Título
		var title:FlxText = new FlxText(0, panel.y + 30, FlxG.width, "OFFSET CALIBRATION", 40);
		title.setFormat(Paths.font("Funkin.otf"), 40, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		title.borderSize = 3;
		add(title);

		// Instrucciones
		instructions = new FlxText(0, panel.y + 100, FlxG.width, 
			"Press SPACE in sync with the beat!\n\n" +
			"The metronome will play at 100 BPM\n" +
			"Press 8 times to calculate your offset", 24);
		instructions.setFormat(Paths.font("Funkin.otf"), 24, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		instructions.borderSize = 2;
		add(instructions);

		// Indicador visual de beat (círculo que pulsa)
		visualMetronome = new FlxSprite(0, 0).makeGraphic(120, 120, FlxColor.TRANSPARENT);
		visualMetronome.screenCenter();
		visualMetronome.y = panel.y + 280;
		add(visualMetronome);

		// Beat indicator
		beatIndicator = new FlxSprite(0, 0).makeGraphic(100, 100, FlxColor.CYAN);
		beatIndicator.screenCenter();
		beatIndicator.y = visualMetronome.y + 10;
		beatIndicator.alpha = 0;
		add(beatIndicator);

		// Display de offset actual
		offsetDisplay = new FlxText(0, panel.y + 420, FlxG.width, "Current Offset: " + FlxG.save.data.offset + " ms", 28);
		offsetDisplay.setFormat(Paths.font("Funkin.otf"), 28, FlxColor.YELLOW, CENTER, OUTLINE, FlxColor.BLACK);
		offsetDisplay.borderSize = 2;
		add(offsetDisplay);

		// Contador de taps
		tapCounter = new FlxText(0, panel.y + 470, FlxG.width, "Taps: 0/" + maxTaps, 24);
		tapCounter.setFormat(Paths.font("Funkin.otf"), 24, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		tapCounter.borderSize = 2;
		add(tapCounter);

		// Countdown
		countdownText = new FlxText(0, 0, FlxG.width, "3", 80);
		countdownText.setFormat(Paths.font("Funkin.otf"), 80, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		countdownText.borderSize = 4;
		countdownText.screenCenter();
		add(countdownText);

		// Controles en la parte inferior
		var controlsText:FlxText = new FlxText(0, panel.y + 530, FlxG.width, 
			"SPACE: Tap | R: Reset | +/-: Adjust manually | ESC: Back", 18);
		controlsText.setFormat(Paths.font("Funkin.otf"), 18, FlxColor.GRAY, CENTER, OUTLINE, FlxColor.BLACK);
		controlsText.borderSize = 1.5;
		add(controlsText);

		// Inicializar offset si no existe
		if (FlxG.save.data.offset == null)
			FlxG.save.data.offset = 0;
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		// Countdown inicial
		if (isCountingDown)
		{
			countdownTimer -= elapsed;
			countdownText.text = Std.string(Math.ceil(countdownTimer));
			
			if (countdownTimer <= 0)
			{
				isCountingDown = false;
				countdownText.visible = false;
				beatTime = 0;
			}
			return;
		}

		// Actualizar timer del beat
		beatTime += elapsed;
		var beatDuration = 60 / bpm; // Tiempo por beat en segundos

		// Reproducir metrónomo en cada beat
		if (beatTime >= beatDuration)
		{
			beatTime = 0;
			currentBeat++;
			playMetronome();
			flashBeatIndicator();
		}

		// Input del usuario
		if (FlxG.keys.justPressed.SPACE)
		{
			recordTap();
		}

		// Ajuste manual con PLUS o MINUS
		if (FlxG.keys.justPressed.PLUS || FlxG.keys.justPressed.NUMPADPLUS)
		{
			FlxG.save.data.offset += 1;
			updateOffsetDisplay();
			FlxG.sound.play(Paths.sound('menus/scrollMenu'));
		}
		if (FlxG.keys.justPressed.MINUS || FlxG.keys.justPressed.NUMPADMINUS)
		{
			FlxG.save.data.offset -= 1;
			updateOffsetDisplay();
			FlxG.sound.play(Paths.sound('menus/scrollMenu'));
		}

		// Reset
		if (FlxG.keys.justPressed.R)
		{
			taps = [];
			updateTapCounter();
			FlxG.sound.play(Paths.sound('menus/cancelMenu'));
		}

		// Volver
		if (FlxG.keys.justPressed.ESCAPE || controls.BACK)
		{
			FlxG.sound.play(Paths.sound('menus/cancelMenu'));
			FlxG.save.flush();
			close();
		}

		// Animación del indicador visual
		beatIndicator.alpha = FlxMath.lerp(beatIndicator.alpha, 0, elapsed * 5);
		beatIndicator.scale.set(FlxMath.lerp(beatIndicator.scale.x, 1, elapsed * 8), 
								FlxMath.lerp(beatIndicator.scale.y, 1, elapsed * 8));
	}

	function playMetronome()
	{
		FlxG.sound.play(Paths.soundRandom(metronomeSound,1,2), 0.5);
	}

	function flashBeatIndicator()
	{
		beatIndicator.alpha = 1;
		beatIndicator.scale.set(1.3, 1.3);
	}

	function recordTap()
	{
		// Registrar el tiempo del tap relativo al beat
		var tapOffset = beatTime * 1000; // Convertir a milisegundos
		taps.push(tapOffset);

		FlxG.sound.play(Paths.sound('menus/scrollMenu'), 0.7);

		// Visual feedback
		beatIndicator.alpha = 0.5;
		beatIndicator.color = FlxColor.YELLOW;

		updateTapCounter();

		// Si completamos los taps necesarios, calcular offset
		if (taps.length >= maxTaps)
		{
			calculateOffset();
		}
	}

	function calculateOffset()
	{
		// Calcular el promedio de los offsets
		var sum:Float = 0;
		for (tap in taps)
		{
			sum += tap;
		}
		
		var average = sum / taps.length;
		var beatDurationMs = (60 / bpm) * 1000;
		
		// Calcular el offset real (cuánto antes o después está presionando)
		var offset = Std.int(average - (beatDurationMs / 2));
		
		FlxG.save.data.offset = offset;
		updateOffsetDisplay();
		
		// Reset taps
		taps = [];
		updateTapCounter();
		
		FlxG.sound.play(Paths.sound('menus/confirmMenu'));
		
		// Feedback visual
		beatIndicator.color = FlxColor.LIME;
		flashBeatIndicator();
	}

	function updateOffsetDisplay()
	{
		offsetDisplay.text = "Current Offset: " + FlxG.save.data.offset + " ms";
	}

	function updateTapCounter()
	{
		tapCounter.text = "Taps: " + taps.length + "/" + maxTaps;
	}
}