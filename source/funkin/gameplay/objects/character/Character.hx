package funkin.gameplay.objects.character;

import flixel.FlxSprite;
import flixel.util.FlxColor;
import funkin.data.Conductor;
import haxe.Json;
import sys.io.File;
import sys.FileSystem;

// ── Librería oficial FlxAnimate (Dot-Stuff/flxanimate) ────────────────────────
import flxanimate.FlxAnimate;

using StringTools;

typedef CharacterData =
{
	var path:String;
	var animations:Array<AnimData>;
	var isPlayer:Bool;
	var antialiasing:Bool;
	var scale:Float;
	@:optional var flipX:Bool;
	@:optional var isTxt:Bool;
	@:optional var isSpritemap:Bool;
	/** Si es true, usa la librería FlxAnimate (Dot-Stuff/flxanimate) */
	@:optional var isFlxAnimate:Bool;
	/** Solo informativo — flxanimate auto-detecta los spritemaps en la carpeta */
	@:optional var spritemapName:String;
	@:optional var healthIcon:String;
	@:optional var healthBarColor:String;
	@:optional var cameraOffset:Array<Float>;
}

typedef AnimData =
{
	var offsetX:Float;
	var offsetY:Float;
	var name:String;
	var looped:Bool;
	var framerate:Float;
	/**
	 * Sprites normales : prefix del XML/TXT.
	 * FlxAnimate       : nombre exacto del símbolo (campo SN en Animation.json).
	 */
	var prefix:String;
	@:optional var specialAnim:Bool;
	@:optional var indices:Array<Int>;
}

/**
 * Character — Personaje jugable/NPC.
 *
 * Extiende FlxSprite (NO FlxAnimate). Para personajes con atlas Adobe Animate
 * se crea un sub-sprite FlxAnimate (_flxAnimate) cuyo ciclo de vida se maneja
 * completamente desde aquí. Esto evita que el pipeline de FlxAnimate interfiera
 * con los personajes de sprite normal.
 *
 *   Modo normal    → frames = Paths.characterSprite(...)
 *                    animation.addByPrefix / animation.play
 *
 *   Modo FlxAnimate → _flxAnimate = new FlxAnimate(x, y)
 *                     _flxAnimate.loadAtlas(folderPath)
 *                     _flxAnimate.anim.addBySymbol / _flxAnimate.anim.play
 */
class Character extends FlxSprite
{
	public var animOffsets:Map<String, Array<Dynamic>>;
	public var debugMode:Bool = false;

	public var canSing:Bool     = true;
	public var stunned:Bool     = false;
	public var isPlayer:Bool    = false;
	public var specialAnim:Bool = false;
	public var curCharacter:String = 'bf';
	public var holdTimer:Float  = 0;

	public var healthIcon:String = 'bf';
	public var healthBarColor:FlxColor = FlxColor.fromString("#31B0D1");
	public var cameraOffset:Array<Float> = [0, 0];

	var characterData:CharacterData;
	var danced:Bool = false;

	/** true sólo cuando el JSON tiene isFlxAnimate:true */
	public var _useFlxAnimate:Bool = false;
	/** Sub-sprite FlxAnimate; null para personajes de sprite normal */
	var _flxAnimate:FlxAnimate = null;
	/** Nombre de la animación actual en modo FlxAnimate (FlxAnim no expone .name) */
	var _curFlxAnimName:String = "";

	var _singAnimPrefix:String = "sing";
	var _idleAnim:String       = "idle";

	// ── Acceso a la API de FlxAnimate para AnimationDebug ────────────────────

	/**
	 * Acceso al FlxAnim interno cuando el personaje usa FlxAnimate.
	 * Devuelve null si el personaje es un sprite normal.
	 */
	public var anim(get, never):flxanimate.animate.FlxAnim;
	inline function get_anim():flxanimate.animate.FlxAnim
		return _flxAnimate != null ? _flxAnimate.anim : null;

	// ── Constructor ───────────────────────────────────────────────────────────

	public function new(x:Float, y:Float, ?character:String = "bf", ?isPlayer:Bool = false)
	{
		super(x, y);

		animOffsets   = new Map<String, Array<Dynamic>>();
		curCharacter  = character;
		this.isPlayer = isPlayer;
		antialiasing  = true;

		loadCharacterData(character);

		if (characterData != null)
		{
			characterLoad(curCharacter);
			trace('[Character] Cargado: ' + character);
		}
		else
		{
			trace('[Character] No se encontraron datos para "' + character + '", usando bf');
			loadCharacterData("bf");
			characterLoad("bf");
		}

		dance();

		isPlayer = characterData.isPlayer;

		if (isPlayer)
		{
			flipX = !flipX;
			if (!curCharacter.startsWith('bf'))
				flipAnimations();
		}
	}

	// ── Carga de datos ────────────────────────────────────────────────────────

	function loadCharacterData(character:String):Void
	{
		var jsonPath = Paths.characterJSON(character);

		try
		{
			var content:String;
			if (FileSystem.exists(jsonPath))
				content = File.getContent(jsonPath);
			else
				content = lime.utils.Assets.getText(jsonPath);

			characterData = cast Json.parse(content);

			healthIcon     = characterData.healthIcon     != null ? characterData.healthIcon     : character;
			healthBarColor = characterData.healthBarColor != null ? FlxColor.fromString(characterData.healthBarColor) : healthBarColor;
			cameraOffset   = characterData.cameraOffset   != null ? characterData.cameraOffset   : cameraOffset;
		}
		catch (e:Dynamic)
		{
			trace('[Character] Error cargando datos de "' + character + '": ' + e);
			characterData = null;
		}
	}

	function characterLoad(character:String):Void
	{
		_useFlxAnimate = (characterData.isFlxAnimate != null && characterData.isFlxAnimate);

		if (_useFlxAnimate)
		{
			// ── Modo FlxAnimate ──────────────────────────────────────────────
			var folderPath = Paths.characterFolder(characterData.path);
            // Aseguramos quitar la barra final para que FlxAnimate no se confunda
			folderPath = haxe.io.Path.removeTrailingSlashes(folderPath);

			trace('Ruta FlxAnimate: ' + folderPath);
			
			trace('[Character] Intentando cargar FlxAnimate en: ' + folderPath);

            // IMPORTANTE: FlxAnimate a veces falla si no se le dan Settings.
            // Creamos la instancia.
			_flxAnimate = new FlxAnimate(x, y, folderPath);

			if (_flxAnimate.anim.metadata == null)
			{
				trace('[Character] ERROR: Atlas FlxAnimate no cargado o metadata corrupta para "' + curCharacter + '"');
				_flxAnimate = null;
				_useFlxAnimate = false;
                // Intentar cargar como sprite normal por seguridad o dejar como placeholder
			}
			else
			{
				for (animData in characterData.animations)
				{
                    // NOTA: addBySymbol requiere el nombre del SÍMBOLO en Adobe Animate, 
                    // no el nombre de la animación en el XML. Asegúrate que animData.prefix
                    // coincida con el nombre en la biblioteca de Animate.
					_flxAnimate.anim.addBySymbol(animData.name, animData.prefix, Std.int(animData.framerate));
					addOffset(animData.name, animData.offsetX, animData.offsetY);
				}
			}
		}
		else
		{
			// ── Modo sprite normal ───────────────────────────────────────────
			if (characterData.isTxt != null && characterData.isTxt)
				frames = Paths.characterSpriteTxt(characterData.path);
			else
				frames = Paths.characterSprite(characterData.path);

			if (frames == null)
			{
				trace('[Character] ERROR CRITICO: frames null para "' + curCharacter + '" path="' + characterData.path + '"');
			}
			else
			{
				trace('[Character] frames OK: ' + frames.frames.length + ' frames para "' + curCharacter + '"');

				for (animData in characterData.animations)
				{
					if (animData.indices != null && animData.indices.length > 0)
						animation.addByIndices(animData.name, animData.prefix, animData.indices, "", Std.int(animData.framerate), animData.looped);
					else
						animation.addByPrefix(animData.name, animData.prefix, Std.int(animData.framerate), animData.looped);

					var flxAnim = animation.getByName(animData.name);
					if (flxAnim == null || flxAnim.numFrames == 0)
						trace('[Character] WARN: "' + animData.name + '" 0 frames (prefix="' + animData.prefix + '")');

					addOffset(animData.name, animData.offsetX, animData.offsetY);
				}
			}
		}

		antialiasing = characterData.antialiasing;
		scale.set(characterData.scale, characterData.scale);
		updateHitbox();

		applyCharacterSpecificAdjustments();

		// Animación inicial
		if (animOffsets.exists('danceRight'))        playAnim('danceRight');
		else if (animOffsets.exists('danceLeft'))     playAnim('danceLeft');
		else if (animOffsets.exists(_idleAnim))       playAnim(_idleAnim);

		if (characterData.flipX != null && characterData.flipX)
			flipX = true;
	}

	// ── playAnim ──────────────────────────────────────────────────────────────

	public function playAnim(AnimName:String, Force:Bool = false, Reversed:Bool = false, Frame:Int = 0):Void
	{
		if (!canSing && specialAnim)
			return;

		if (_useFlxAnimate && _flxAnimate != null)
		{
			// Nunca llamar play() si el atlas no se cargó correctamente:
			// anim.metadata null → crash en FlxAnim.hx línea 284 (metadata.name).
			if (_flxAnimate.anim.metadata == null) return;

			// Force=true en la primera llamada: FlxAnim.play() comprueba finished
			// antes de que exista un símbolo activo y petaría sin este flag.
			var forcePlay = Force || (_curFlxAnimName == "");
			_flxAnimate.anim.play(AnimName, forcePlay, Reversed, Frame);
			_curFlxAnimName = AnimName;
		}
		else
		{
			animation.play(AnimName, Force, Reversed, Frame);
		}

		var daOffset = animOffsets.get(AnimName);
		if (daOffset != null)
			offset.set(daOffset[0], daOffset[1]);
		else
			offset.set(0, 0);
	}

	// ── Estado de animación ───────────────────────────────────────────────────

	public function getCurAnimName():String
	{
		if (_useFlxAnimate)
			return _curFlxAnimName;
		return animation.curAnim != null ? animation.curAnim.name : "";
	}

	public function isCurAnimFinished():Bool
	{
		if (_useFlxAnimate && _flxAnimate != null)
			return _flxAnimate.anim.finished;
		return animation.curAnim != null ? animation.curAnim.finished : true;
	}

	public function hasCurAnim():Bool
	{
		if (_useFlxAnimate)
			return _curFlxAnimName != "";
		return animation.curAnim != null;
	}

	// ── Update ────────────────────────────────────────────────────────────────

	override function update(elapsed:Float)
	{
		// Actualizar el sub-sprite FlxAnimate (avanza su sistema anim interno)
		if (_useFlxAnimate && _flxAnimate != null)
			_flxAnimate.update(elapsed);

		super.update(elapsed);

		if (!hasCurAnim())
			return;

		var curAnimName = getCurAnimName();
		var curAnimDone = isCurAnimFinished();

		if (!curCharacter.startsWith('bf'))
		{
			if (curAnimName.startsWith(_singAnimPrefix))
			{
				holdTimer += elapsed;
				var dadVar:Float = (curCharacter == 'dad') ? 6.1 : 4.0;
				if (holdTimer >= Conductor.stepCrochet * dadVar * 0.001)
				{
					dance();
					holdTimer = 0;
				}
			}
			else
			{
				holdTimer = 0;
				var hasDanceAnims = animOffsets.exists('danceLeft') && animOffsets.exists('danceRight');
				if (!hasDanceAnims && curAnimDone)
					dance();
			}
		}
		else if (!debugMode)
		{
			if (curAnimName.startsWith(_singAnimPrefix))
			{
				holdTimer += elapsed;
				if (holdTimer >= Conductor.stepCrochet * 4 * 0.001 && canSing)
				{
					playAnim(_idleAnim, true);
					holdTimer = 0;
				}
			}
			else
			{
				holdTimer = 0;
				if (curAnimName == _idleAnim && curAnimDone)
					playAnim(_idleAnim, true);
			}

			if (curAnimName.endsWith('miss') && curAnimDone)
				playAnim(_idleAnim, true, false, 10);

			if (curAnimName == 'firstDeath' && curAnimDone)
				playAnim('deathLoop');
		}

		handleSpecialAnimations();
	}

	// ── Draw ─────────────────────────────────────────────────────────────────

	override function draw()
	{
        // Si usamos FlxAnimate, secuestramos el draw para pintar el sub-sprite
		if (_useFlxAnimate && _flxAnimate != null)
		{
            // Sincronización completa antes de dibujar
			_flxAnimate.setPosition(x, y); // Usar setPosition es más limpio
			_flxAnimate.offset.copyFrom(offset); // Cuidado aquí (ver nota abajo)
			_flxAnimate.scale.copyFrom(scale);
			_flxAnimate.flipX = flipX;
			_flxAnimate.flipY = flipY;
			_flxAnimate.alpha = alpha;
			_flxAnimate.antialiasing = antialiasing;
			_flxAnimate.cameras = cameras; // ¡Muy importante!
			_flxAnimate.scrollFactor.copyFrom(scrollFactor);
            
            // Forzar el color si es necesario (FlxAnimate a veces ignora color si no se aplica a los frames)
            if (color != FlxColor.WHITE) _flxAnimate.color = color;

			_flxAnimate.draw();
		}
		else
		{
			super.draw();
		}
	}

	// ── Animaciones especiales ────────────────────────────────────────────────

	function handleSpecialAnimations():Void
	{
		switch (curCharacter)
		{
			case 'gf' | 'gf-christmas' | 'gf-pixel' | 'gf-car':
				if (hasCurAnim() && getCurAnimName() == 'hairFall' && isCurAnimFinished())
					playAnim('danceRight');
		}
	}

	// ── Dance ─────────────────────────────────────────────────────────────────

	public function dance():Void
	{
		if (!debugMode && !specialAnim)
		{
			var hasDanceAnims = animOffsets.exists('danceLeft') && animOffsets.exists('danceRight');

			switch (curCharacter)
			{
				case 'gf' | 'gf-car' | 'gf-pixel' | 'gf-christmas' | 'gf-tankmen':
					if (!hasCurAnim() || !getCurAnimName().startsWith(_singAnimPrefix))
					{
						if (!hasCurAnim() || !getCurAnimName().startsWith('hair') || isCurAnimFinished())
						{
							danced = !danced;
							playAnim(danced ? 'danceRight' : 'danceLeft');
						}
					}

				case 'spooky':
					if (!hasCurAnim() || !getCurAnimName().startsWith(_singAnimPrefix))
					{
						danced = !danced;
						playAnim(danced ? 'danceRight' : 'danceLeft');
					}

				default:
					if (hasDanceAnims)
					{
						if (!hasCurAnim() || !getCurAnimName().startsWith(_singAnimPrefix))
						{
							danced = !danced;
							playAnim(danced ? 'danceRight' : 'danceLeft');
						}
					}
					else
					{
						playAnim(_idleAnim);
					}
			}
		}
	}

	// ── Ajustes específicos ───────────────────────────────────────────────────

	function applyCharacterSpecificAdjustments():Void
	{
		switch (curCharacter)
		{
			case 'bf-pixel-enemy':
				width  -= 100;
				height -= 100;
		}
	}

	function flipAnimations():Void
	{
		// Solo aplica en modo sprite normal (FlxAnimationController)
		if (_useFlxAnimate) return;

		if (animation.getByName('singRIGHT') != null && animation.getByName('singLEFT') != null)
		{
			var oldRight = animation.getByName('singRIGHT').frames;
			animation.getByName('singRIGHT').frames = animation.getByName('singLEFT').frames;
			animation.getByName('singLEFT').frames  = oldRight;
		}
		if (animation.getByName('singRIGHTmiss') != null && animation.getByName('singLEFTmiss') != null)
		{
			var oldMiss = animation.getByName('singRIGHTmiss').frames;
			animation.getByName('singRIGHTmiss').frames = animation.getByName('singLEFTmiss').frames;
			animation.getByName('singLEFTmiss').frames  = oldMiss;
		}
	}

	// ── API pública ───────────────────────────────────────────────────────────

	public function addOffset(name:String, x:Float = 0, y:Float = 0):Void
		animOffsets[name] = [x, y];

	public function getAnimationList():Array<String>
	{
		var list:Array<String> = [];
		for (a in animOffsets.keys()) list.push(a);
		return list;
	}

	public function hasAnimation(name:String):Bool
		return animOffsets.exists(name);

	public function getOffset(name:String):Array<Dynamic>
		return animOffsets.get(name);

	public function updateOffset(name:String, x:Float, y:Float):Void
	{
		if (animOffsets.exists(name))
			animOffsets.set(name, [x, y]);
	}

	// ── Destruir ──────────────────────────────────────────────────────────────

	override function destroy():Void
	{
		if (_flxAnimate != null)
		{
			_flxAnimate.destroy();
			_flxAnimate = null;
		}
		if (animOffsets != null) { animOffsets.clear(); animOffsets = null; }
		characterData = null;
		super.destroy();
	}
}
