package funkin.gameplay.objects.character;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.animation.FlxBaseAnimation;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.math.FlxMath;
import flixel.util.FlxColor;
import funkin.data.Conductor;

using StringTools;

import haxe.Json;
import haxe.format.JsonParser;
import lime.utils.Assets;
// Importar parsers de Adobe Animate
import animationdata.AdobeAnimateAnimationParser;
import animationdata.AnimateAtlasParser;

typedef CharacterData = {
	var path:String;
	var animations:Array<AnimData>;
	var isPlayer:Bool;
	var antialiasing:Bool;
	var scale:Float;
	@:optional var flipX:Bool;
	@:optional var indices:Array<Int>;
	@:optional var isTxt:Bool;
	@:optional var isSpritemap:Bool;
	@:optional var isAdobeAnimate:Bool; // Nuevo: indica formato Adobe Animate
	@:optional var animationFile:String; // Nuevo: ruta al Animation.json
	@:optional var healthIcon:String;
	@:optional var healthBarColor:String;
	@:optional var cameraOffset:Array<Float>;
}

typedef AnimData = {
	var offsetX:Float;
	var offsetY:Float;
	var name:String;
	var looped:Bool;
	var framerate:Float;
	var prefix:String;
	@:optional var specialAnim:Bool;
	@:optional var indices:Array<Int>;
}

class Character extends FlxSprite {
	public var animOffsets:Map<String, Array<Dynamic>>;
	public var debugMode:Bool = false;

	public var canSing:Bool = true;
	public var stunned:Bool = false;
	public var isPlayer:Bool = false;
	public var specialAnim:Bool = false;
	public var curCharacter:String = 'bf';
	public var holdTimer:Float = 0;

	// Additional properties
	public var healthIcon:String = 'bf';
	public var healthBarColor:FlxColor = FlxColor.fromString("#31B0D1");
	public var cameraOffset:Array<Float> = [0, 0];

	var characterData:CharacterData;
	var danced:Bool = false;

	// Performance optimization: cache frequently used values
	var _singAnimPrefix:String = "sing";
	var _idleAnim:String = "idle";

	// Adobe Animate support
	var _adobeAnimateAnims:Map<String, AdobeAnimateAnimation>;
	var _spritIndexMap:Map<String, Int>;

	public function new(x:Float, y:Float, ?character:String = "bf", ?isPlayer:Bool = false) {
		super(x, y);

		animOffsets = new Map<String, Array<Dynamic>>();
		curCharacter = character;
		this.isPlayer = isPlayer;

		antialiasing = true;

		// Load character from JSON
		loadCharacterData(character);

		if (characterData != null) {
			characterLoad(curCharacter);
			trace("Loaded character data for: " + character);
		} else {
			trace("Character data not found for: " + character + ", loading default");
			loadCharacterData("bf");
			characterLoad("bf");
		}

		dance();
		
		isPlayer = characterData.isPlayer;

		if (isPlayer) {
			flipX = !flipX;

			// Doesn't flip for BF, since his are already in the right place
			if (!curCharacter.startsWith('bf')) {
				flipAnimations();
			}
		}
	}

	function loadCharacterData(character:String):Void {
		try {
			var file:String = Assets.getText(Paths.characterJSON(character));
			characterData = cast Json.parse(file);

			// Load additional properties
			if (characterData.healthIcon != null)
				healthIcon = characterData.healthIcon;
			else
				healthIcon = character;

			if (characterData.healthBarColor != null)
				healthBarColor = FlxColor.fromString(characterData.healthBarColor);

			if (characterData.cameraOffset != null)
				cameraOffset = characterData.cameraOffset;
		} catch (e:Dynamic) {
			trace("Error loading character data for " + character + ": " + e);
			characterData = null;
		}
	}

	function characterLoad(character:String):Void {
		// Determinar el formato y cargar sprites
		if (characterData.isAdobeAnimate != null && characterData.isAdobeAnimate) {
			// NUEVO: Cargar desde formato Adobe Animate
			loadFromAdobeAnimate(characterData.path, characterData.animationFile);
		} else if (characterData.isSpritemap != null && characterData.isSpritemap) {
			// Load from spritesheet JSON format
			loadSpritesheetJSON(characterData.path);
		} else if (characterData.isTxt != null && characterData.isTxt) {
			// Load from TXT format
			frames = Paths.characterSpriteTxt(characterData.path);
		} else {
			// Load from standard XML format
			frames = Paths.characterSprite(characterData.path);
		}

		// Add animations
		for (anim in characterData.animations) {
			// Check if animation uses indices
			if (anim.indices != null && anim.indices.length > 0) {
				animation.addByIndices(anim.name, anim.prefix, anim.indices, "", Std.int(anim.framerate), anim.looped);
			} else {
				animation.addByPrefix(anim.name, anim.prefix, Std.int(anim.framerate), anim.looped);
			}

			if (anim.specialAnim != null && anim.specialAnim) {
				specialAnim = true;
			}

			addOffset(anim.name, anim.offsetX, anim.offsetY);
		}

		// Apply character properties
		antialiasing = characterData.antialiasing;
		scale.set(characterData.scale, characterData.scale);
		updateHitbox();

		// Handle character-specific adjustments
		applyCharacterSpecificAdjustments();

		// Play initial animation
		if (animOffsets.exists('danceRight'))
			playAnim('danceRight');
		else if (animOffsets.exists(_idleAnim))
			playAnim(_idleAnim);

		// Apply flipX from JSON if specified
		if (characterData.flipX != null && characterData.flipX) {
			flipX = true;
		}
	}

	/**
	 * VERSIÓN MEJORADA: Carga sprites y animaciones desde formato Adobe Animate
	 * - Soporte para Sparrow XML (GF_assets.xml) 
	 * - Soporte para JSON con AnimateAtlasParser
	 * - Validación de sprites
	 * - Mejor manejo de errores
	 * - Logging detallado
	 */
	function loadFromAdobeAnimate(atlasPath:String, ?animationPath:String):Void {
		try {
			trace("╔════════════════════════════════════════╗");
			trace("║  Cargando Adobe Animate Atlas         ║");
			trace("╚════════════════════════════════════════╝");

			// Construir ruta al archivo de animaciones
			var animJsonPath = animationPath != null ? Paths.characterJSON('images/$curCharacter/' + animationPath) : null;

			if (animJsonPath == null || animJsonPath == "") {
				trace("✗ ERROR: Se requiere archivo de animaciones (Animation.json)");
				return;
			}

			trace("\n📦 Formato detectado: JSON personalizado");

			var atlasJsonPath = Paths.characterJSON('images/$curCharacter/' + atlasPath);

			trace("  📄 Animation JSON: " + animJsonPath);
			trace("  📄 Atlas JSON: " + atlasJsonPath);

			// ═══ VALIDACIÓN DE SPRITES (solo en debug) ═══
			#if debug
			trace("\n🔍 Validando sprites...");
			var missingSprites = AnimateAtlasParser.validateSprites(animJsonPath, atlasJsonPath);

			if (Lambda.count(missingSprites) > 0) {
				trace("⚠️  ADVERTENCIA: Se encontraron sprites faltantes:");
				for (symbolName in missingSprites.keys()) {
					trace("  ├─ Símbolo: " + symbolName);
					var sprites = missingSprites.get(symbolName);
					for (i in 0...sprites.length) {
						var isLast = (i == sprites.length - 1);
						var prefix = isLast ? "  └──" : "  ├──";
						trace(prefix + " Falta: " + sprites[i]);
					}
				}
				trace("\n💡 SOLUCIÓN: Usa '.xml' en lugar de 'spritemap1.json'");
			} else {
				trace("✓ Todos los sprites están presentes");
			}
			#end

			// ═══ PARSEAR ANIMATEATLAS ═══
			trace("\n⚙️  Parseando AnimateAtlas...");
			frames = AnimateAtlasParser.parseAnimateAtlas(animJsonPath, atlasJsonPath, 800, // frameWidth - aumentado para sprites grandes
				800 // frameHeight - aumentado para sprites grandes
			);

			if (frames == null) {
				trace("✗ ERROR: No se pudo parsear AnimateAtlas");
				trace("\n🔎 Posibles causas:");
				trace("  1. Los nombres en Animation.json no coinciden con el atlas");
				trace("  2. El archivo atlas está corrupto o mal formateado");
				trace("  3. Necesitas usar .xml en lugar de spritemap1.json");
				trace("\n💡 Solución recomendada:");
				trace("  En tu JSON de personaje, cambia:");
				trace('    "path": ".xml"  ← Usa este');
				trace('    NO uses: "path": "spritemap1.json"');
				return;
			}

			trace("✓ AnimateAtlas parseado exitosamente");
			trace("  Total de frames compuestos: " + frames.frames.length);

			// ═══════════════════════════════════════════════════════
			// AGREGAR ANIMACIONES
			// ═══════════════════════════════════════════════════════
			trace("\n🎬 Agregando animaciones...");
			trace("─────────────────────────────────────────");

			var successCount = 0;
			var failCount = 0;

			for (anim in characterData.animations) {
				var symbolName = anim.prefix;

				if (symbolName == null || symbolName == "") {
					trace("⚠️  '" + anim.name + "' sin prefix → Saltando");
					failCount++;
					continue;
				}

				try {
					if (anim.indices != null && anim.indices.length > 0) {
						// Usar índices específicos
						animation.addByIndices(anim.name, symbolName, anim.indices, "", Std.int(anim.framerate), anim.looped);

						trace("✓ " + StringTools.rpad(anim.name, " ", 20) + " │ Indices: " + anim.indices.length + " frames de '" + symbolName + "'");
					} else {
						// Usar todos los frames del símbolo
						animation.addByPrefix(anim.name, symbolName, Std.int(anim.framerate), anim.looped);

						trace("✓ " + StringTools.rpad(anim.name, " ", 20) + " │ Prefix: '" + symbolName + "' @ " + anim.framerate + "fps");
					}

					// Agregar offset
					addOffset(anim.name, anim.offsetX, anim.offsetY);
					successCount++;
				} catch (e:Dynamic) {
					trace("✗ ERROR en '" + anim.name + "': " + e);
					failCount++;
				}
			}

			trace("─────────────────────────────────────────");
			trace("📊 Resumen de carga:");
			trace("  ✓ Exitosas: " + successCount);
			if (failCount > 0)
				trace("  ✗ Fallidas:  " + failCount);
			trace("  📝 Total:    " + (successCount + failCount));

			if (successCount == 0) {
				trace("\n⚠️  ADVERTENCIA CRÍTICA: No se agregó ninguna animación");
				trace("  Verifica que characterData.animations tenga los nombres correctos");
				trace("  Los 'prefix' deben coincidir con los símbolos en Animation.json");
			} else {
				trace("\n🎉 ¡Carga completada exitosamente!");
			}

			trace("╚════════════════════════════════════════╝\n");
		} catch (e:Dynamic) {
			trace("\n╔════════════════════════════════════════╗");
			trace("║  ✗✗✗ ERROR CRÍTICO ✗✗✗                ║");
			trace("╚════════════════════════════════════════╝");
			trace("Error: " + e);

			#if debug
			trace("\n📋 Stack trace:");
			var stack = haxe.CallStack.exceptionStack();
			for (item in stack) {
				trace("  " + item);
			}
			#end

			// Intentar fallback
			trace("\n🔄 Intentando fallback a carga estándar...");
			try {
				frames = Paths.characterSprite(characterData.path);
				trace("✓ Fallback exitoso - usando carga estándar");
			} catch (fallbackError:Dynamic) {
				trace("✗ Fallback también falló: " + fallbackError);
				trace("💀 No se puede cargar el personaje");
			}
		}
	}

	/**
	 * NUEVO: Crea automáticamente animaciones desde el archivo de Adobe Animate
	 */
	function autoCreateAnimationsFromAdobe():Void {
		if (_adobeAnimateAnims == null)
			return;

		trace("Auto-creando animaciones desde Adobe Animate...");

		for (animName in _adobeAnimateAnims.keys()) {
			var adobeAnim = _adobeAnimateAnims.get(animName);

			// Obtener índices de frames
			var frameIndices = AdobeAnimateAnimationParser.getFrameIndices(adobeAnim, _spritIndexMap);

			if (frameIndices.length > 0) {
				// Agregar animación por índices
				animation.addByIndices(animName, "", // prefix vacío porque usamos índices directos
					frameIndices, "", Std.int(adobeAnim.framerate), adobeAnim.looped);

				// Agregar offset por defecto (puede ser ajustado luego)
				addOffset(animName, 0, 0);

				trace("Animación auto-creada: " + animName + " (" + frameIndices.length + " frames)");
			}
		}
	}

	function loadSpritesheetJSON(path:String):Void {
		// For spritesheet JSON, we need to create frames from the PNG and JSON data
		// This assumes the JSON contains frame data in a standard format

		try {
			// Load the PNG
			var imagePath = Paths.characterimage('$curCharacter/' + path);

			// Try to load a corresponding JSON file for frame data
			// The JSON might be in the same directory with a .json extension
			var jsonPath = path + ".json";

			// For now, we'll use the standard frame loading
			// This can be extended to parse custom JSON formats
			loadGraphic(imagePath);

			trace("Loaded spritesheet from: " + path);
		} catch (e:Dynamic) {
			trace("Error loading spritesheet: " + e);
			// Fallback to standard loading
			frames = Paths.characterSprite(path);
		}
	}

	function applyCharacterSpecificAdjustments():Void {
		// Handle pixel characters or specific character adjustments
		switch (curCharacter) {
			case 'bf-pixel-enemy':
				width -= 100;
				height -= 100;
				// Add more character-specific adjustments here
		}
	}

	function flipAnimations():Void {
		// Flip LEFT and RIGHT animations for player characters
		if (animation.getByName('singRIGHT') != null && animation.getByName('singLEFT') != null) {
			var oldRight = animation.getByName('singRIGHT').frames;
			animation.getByName('singRIGHT').frames = animation.getByName('singLEFT').frames;
			animation.getByName('singLEFT').frames = oldRight;
		}

		// Flip MISS animations if they exist
		if (animation.getByName('singRIGHTmiss') != null && animation.getByName('singLEFTmiss') != null) {
			var oldMiss = animation.getByName('singRIGHTmiss').frames;
			animation.getByName('singRIGHTmiss').frames = animation.getByName('singLEFTmiss').frames;
			animation.getByName('singLEFTmiss').frames = oldMiss;
		}
	}

	override function update(elapsed:Float) {
		if (animation.curAnim == null) {
			super.update(elapsed);
			return;
		}

		// Handle non-BF characters (DAD, GF, etc)
		if (!curCharacter.startsWith('bf')) {
			if (animation.curAnim.name.startsWith(_singAnimPrefix)) {
				holdTimer += elapsed;

				var dadVar:Float = 4;
				if (curCharacter == 'dad')
					dadVar = 6.1;

				if (holdTimer >= Conductor.stepCrochet * dadVar * 0.001) {
					dance();
					holdTimer = 0;
				}
			} else {
				// FIX PROBLEMA 1: Dad vuelve a idle en loop
				holdTimer = 0;
				if (animation.curAnim.finished) {
					dance();
				}
			}
		} else if (!debugMode) {
			// Handle BF characters
			if (animation.curAnim.name.startsWith(_singAnimPrefix)) {
				holdTimer += elapsed;
			} else {
				holdTimer = 0;

				// FIX PROBLEMA 3: Boyfriend idle hace loop
				if (animation.curAnim.name == _idleAnim && animation.curAnim.finished) {
					playAnim(_idleAnim, true);
				}
			}

			// Handle miss animations
			if (animation.curAnim.name.endsWith('miss') && animation.curAnim.finished) {
				playAnim(_idleAnim, true, false, 10);
			}

			// Handle death animations
			if (animation.curAnim.name == 'firstDeath' && animation.curAnim.finished) {
				playAnim('deathLoop');
			}
		}

		// Handle GF specific animations
		handleSpecialAnimations();

		super.update(elapsed);
	}

	function handleSpecialAnimations():Void {
		switch (curCharacter) {
			case 'gf' | 'gf-christmas' | 'gf-pixel' | 'gf-car':
				if (animation.curAnim != null && animation.curAnim.name == 'hairFall' && animation.curAnim.finished) {
					playAnim('danceRight');
				}
		}
	}

	/**
	 * FOR GF DANCING SHIT
	 */
	public function dance():Void {
		if (!debugMode && !specialAnim) {
			switch (curCharacter) {
				case 'gf' | 'gf-car' | 'gf-pixel' | 'gf-christmas':
					// FIX PROBLEMA 2: GF no baila a lo loco
					if (animation.curAnim == null || !animation.curAnim.name.startsWith(_singAnimPrefix)) {
						// Solo cambiamos el lado del baile si la animación de 'hair' (pelo) terminó o no existe
						if (animation.curAnim == null || !animation.curAnim.name.startsWith('hair') || animation.curAnim.finished) {
							danced = !danced;

							if (danced)
								playAnim('danceRight');
							else
								playAnim('danceLeft');
						}
					}

				case 'spooky':
					// Mismo fix para Spooky
					// var currentAnim = animation.curAnim != null ? animation.curAnim.name : "";
					if (animation.curAnim == null || !animation.curAnim.name.startsWith(_singAnimPrefix)) {
						danced = !danced; // Cambia entre danceLeft y danceRight [cite: 36]

						if (danced)
							playAnim('danceRight');
						else
							playAnim('danceLeft');
					}

				default:
					playAnim(_idleAnim);
			}
		}
	}

	public function playAnim(AnimName:String, Force:Bool = false, Reversed:Bool = false, Frame:Int = 0):Void {
		if (!canSing && specialAnim)
			return;

		animation.play(AnimName, Force, Reversed, Frame);

		// Apply offset
		var daOffset = animOffsets.get(AnimName);
		if (daOffset != null) {
			offset.set(daOffset[0], daOffset[1]);
		} else
			offset.set(0, 0);
	}

	public function addOffset(name:String, x:Float = 0, y:Float = 0):Void {
		animOffsets[name] = [x, y];
	}

	/**
	 * Get all animation names
	 */
	public function getAnimationList():Array<String> {
		var list:Array<String> = [];
		for (anim in animOffsets.keys()) {
			list.push(anim);
		}
		return list;
	}

	/**
	 * Check if animation exists
	 */
	public function hasAnimation(name:String):Bool {
		return animOffsets.exists(name);
	}

	/**
	 * Get animation offset
	 */
	public function getOffset(name:String):Array<Dynamic> {
		return animOffsets.get(name);
	}

	/**
	 * Update animation offset
	 */
	public function updateOffset(name:String, x:Float, y:Float):Void {
		if (animOffsets.exists(name)) {
			animOffsets.set(name, [x, y]);
		}
	}

	/**
	 * Clean up
	 */
	override function destroy():Void {
		animOffsets.clear();
		animOffsets = null;
		characterData = null;

		if (_adobeAnimateAnims != null) {
			_adobeAnimateAnims.clear();
			_adobeAnimateAnims = null;
		}

		if (_spritIndexMap != null) {
			_spritIndexMap.clear();
			_spritIndexMap = null;
		}

		super.destroy();
	}
}