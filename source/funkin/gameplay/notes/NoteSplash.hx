package funkin.gameplay.notes;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.util.FlxTimer;
import funkin.gameplay.notes.NoteSkinSystem.NoteSplashData;

/**
 * NoteSplash MEJORADO - Con soporte para notas largas (holds)
 * 
 * NUEVAS CARACTERÍSTICAS:
 * - Splashes específicos para hold notes usando archivos holdCover
 * - Splashes para el inicio de hold notes
 * - Splashes continuos mientras se mantiene la nota
 * - Splash especial al terminar hold notes
 * - Sistema de pooling optimizado
 */
class NoteSplash extends FlxSprite
{
	public var noteDatawea:Int = 0;
	
	// OPTIMIZATION: Flag para saber si está en uso
	public var inUse:Bool = false;
	
	// NUEVO: Tipo de splash
	public var splashType:SplashType = NORMAL;
	
	// NUEVO: Para hold splashes
	public var isHoldSplash:Bool = false;
	private var holdTimer:FlxTimer = null;
	private var holdInterval:Float = 0.15; // Intervalo entre splashes de hold (segundos)
	
	// NUEVO: Para splashes de release (al soltar la nota)
	public var isReleaseSplash:Bool = false;

	public function new(x:Float, y:Float, noteData:Int = 0, ?splashName:String = null)
	{
		super(x, y);
		noteDatawea = noteData;
		//holdTimer = new FlxTimer();
		setup(x, y, noteData, splashName);
	}
	
	public function setup(x:Float, y:Float, noteData:Int = 0, ?splashName:String = null, ?type:SplashType = NORMAL)
	{
		this.x = x;
		this.y = y;
		noteDatawea = noteData;
		inUse = true;
		splashType = type;
		
		// Configurar según el tipo de splash
		isHoldSplash = (type == HOLD_START || type == HOLD_CONTINUOUS);
		isReleaseSplash = (type == HOLD_END);

		// Inicializar sistema
		NoteSkinSystem.init();

		// Limpiar animaciones anteriores si existen
		if (animation != null)
		{
			animation.destroyAnimations();
		}

		// NUEVO: Para hold splashes, usar archivos holdCover específicos
		if (isHoldSplash || isReleaseSplash)
		{
			loadHoldCoverSplash(noteData, type);
		}
		else
		{
			// Obtener datos del splash normal
			var splashData = NoteSkinSystem.getSplashData(splashName);
			
			if (splashData != null)
			{
				loadNormalSplash(splashData, noteData);
			}
			else
			{
				// Fallback a splash por defecto
				trace('Warning: Could not load splash data, using default');
				loadDefaultSplash(noteDatawea, type);
			}
		}

		updateHitbox();
		
		// Centrar el splash
		offset.x = width * 0.3;
		offset.y = height * 0.3;
		
		// NUEVO: Alpha diferente según tipo
		if (isHoldSplash)
			alpha = 0.7; // Hold splashes semi-transparentes
		else if (isReleaseSplash)
			alpha = 0.8; // Release splash completamente visible
		else
			alpha = 0.8; // Normal splash visible

		// FIX: ASEGURAR QUE EL SPLASH SEA VISIBLE
		visible = true;
		active = true;
		
		// Revivir el sprite si estaba muerto (para recycle)
		revive();
	}
	
	/**
	 * NUEVO: Cargar splash específico para hold covers
	 * AHORA CON DETECCIÓN AUTOMÁTICA DE SKIN
	 */
	function loadHoldCoverSplash(noteData:Int, type:SplashType):Void
	{
		// Mapear colores según la dirección de la nota
		var colorNames:Array<String> = ["Purple", "Blue", "Green", "Red"]; // left, down, up, right
		var color:String = colorNames[noteData];
		
		try
		{
			// NUEVO: Verificar si existe holdCover en la skin/splash actual
			if (!NoteSkinSystem.holdCoverExists(color))
			{
				trace('Warning: holdCover$color not found in current splash (${NoteSkinSystem.getCurrentSplashFolder()}), using default splash');
				loadDefaultSplash(noteData, type);
				return;
			}
			
			// NUEVO: Cargar frames del holdCover usando el sistema automático
			frames = NoteSkinSystem.getHoldCoverTexture(color);
			
			if (frames == null)
			{
				trace('Warning: Could not load holdCover for color $color, using default');
				loadDefaultSplash(noteData, type);
				return;
			}
			
			antialiasing = true;
			
			// Escala según el tipo
			if (type == HOLD_START)
			{
				scale.set(1.0, 1.0); // Start splash mediano
			}
			else if (type == HOLD_CONTINUOUS)
			{
				scale.set(1.0, 1.0); // Continuous splash más pequeño
			}
			else if (type == HOLD_END)
			{
				scale.set(1.0, 1.0); // End splash más grande
			}
			
			// Configurar animaciones según el tipo de hold splash
			var framerate:Int = 24;
			
			if (type == HOLD_START)
			{
				// Animación de inicio de hold
				animation.addByPrefix('holdStart', 'holdCoverStart${color}', framerate, false);
				animation.play('holdStart', true);
			}
			else if (type == HOLD_CONTINUOUS)
			{
				// Animación continua mientras se mantiene
				animation.addByPrefix('holdContinuous', 'holdCover${color}', framerate * 2, true); // Loop
				animation.play('holdContinuous', true);
			}
			else if (type == HOLD_END)
			{
				// Animación de release/fin de hold
				animation.addByPrefix('holdEnd', 'holdCoverEnd${color}', framerate, false);
				animation.play('holdEnd', true);
				
				// Auto-destruirse cuando termine la animación de release
				animation.finishCallback = function(name:String)
				{
					recycleSplash();
				};
			}
			
			trace('Loaded holdCover splash: $color from ${NoteSkinSystem.getCurrentSplashFolder()} (type: $type)');
		}
		catch (e:Dynamic)
		{
			trace('Error loading holdCover splash: $e');
			loadDefaultSplash(noteData, type);
		}
	}
	
	/**
	 * Cargar splash normal (no hold)
	 */
	function loadNormalSplash(splashData:NoteSplashData, noteData:Int):Void
	{
		// Cargar frames
		frames = NoteSkinSystem.getSplashTexture();

		// Aplicar escala
		var splashScale:Float = splashData.assets.scale != null ? splashData.assets.scale : 1.0;
		scale.set(splashScale, splashScale);

		// Configurar antialiasing
		antialiasing = splashData.assets.antialiasing != null ? splashData.assets.antialiasing : true;

		// Aplicar offset si está configurado
		if (splashData.assets.offset != null && splashData.assets.offset.length >= 2)
		{
			offset.set(splashData.assets.offset[0], splashData.assets.offset[1]);
		}

		// Configurar animaciones
		var anims = splashData.animations;
		var framerate:Int = anims.framerate != null ? anims.framerate : 24;
		var randomRange:Int = anims.randomFramerateRange != null ? anims.randomFramerateRange : 0;

		// Ajustar framerate con randomización si está configurado
		if (randomRange > 0)
		{
			framerate += FlxG.random.int(-randomRange, randomRange);
		}

		// Agregar todas las animaciones para cada dirección
		var directions:Array<String> = ["left", "down", "up", "right"];
		
		for (i in 0...4)
		{
			var animList:Array<String> = null;
			
			switch (i)
			{
				case 0: animList = anims.left;
				case 1: animList = anims.down;
				case 2: animList = anims.up;
				case 3: animList = anims.right;
			}

			if (animList != null && animList.length > 0)
			{
				// Agregar cada variación de animación
				for (j in 0...animList.length)
				{
					var animPrefix:String = animList[j];
					var animName:String = '${directions[i]}_$j';
					
					animation.addByPrefix(animName, animPrefix, framerate, false);
				}
			}
		}

		// Reproducir la animación correcta según la dirección
		playAnimation(noteData);

		// Auto-destruirse cuando termine la animación
		animation.finishCallback = function(name:String)
		{
			recycleSplash();
		};
	}
	
	/**
	 * NUEVO: Iniciar splash continuo para hold note
	 */
	public function startContinuousSplash(x:Float, y:Float, noteData:Int, ?splashName:String = null):Void
	{
		setup(x, y, noteData, splashName, HOLD_CONTINUOUS);
		
		// REUTILIZACIÓN DEL TIMER
		if (holdTimer == null) {
			holdTimer = new FlxTimer();
		} else {
			holdTimer.cancel(); // Lo detenemos si estaba haciendo otra cosa
		}
		
		// Usamos el mismo objeto holdTimer
		holdTimer.start(holdInterval, function(timer:FlxTimer)
		{
			if (animation.curAnim != null)
			{
				animation.curAnim.restart();
			}
			
			// Efecto visual
			this.x = x + FlxG.random.float(-5, 5);
			this.y = y + FlxG.random.float(-5, 5);
			
		}, 0);
	}
	
	/**
	 * NUEVO: Detener splash continuo
	 */
	public function stopContinuousSplash():Void
	{
		if (holdTimer != null)
		{
			holdTimer.cancel();
		}
		
		recycleSplash();
	}
	
	// OPTIMIZATION: Método para reciclar splash (Object Pooling)
	public function recycleSplash():Void
	{
		// Cancelar timer si existe
		if (holdTimer != null)
		{
			holdTimer.cancel();
		}
		
		inUse = false;
		visible = false;
		active = false;
		isHoldSplash = false;
		isReleaseSplash = false;
		kill();
	}

	function playAnimation(noteData:Int):Void
	{
		var splashData = NoteSkinSystem.getSplashData();
		if (splashData == null) return;

		var anims = splashData.animations;
		var animList:Array<String> = null;
		var directionName:String = "";

		// Obtener la lista de animaciones para esta dirección
		switch (noteData)
		{
			case 0: 
				animList = anims.left;
				directionName = "left";
			case 1: 
				animList = anims.down;
				directionName = "down";
			case 2: 
				animList = anims.up;
				directionName = "up";
			case 3: 
				animList = anims.right;
				directionName = "right";
		}

		// Si hay múltiples variaciones, elegir una al azar
		if (animList != null && animList.length > 0)
		{
			var randomIndex:Int = FlxG.random.int(0, animList.length - 1);
			var animName:String = '${directionName}_$randomIndex';
			
			animation.play(animName, true);
		}
	}

	function loadDefaultSplash(noteData:Int, ?type:SplashType = NORMAL):Void
	{
		// Cargar splash por defecto de FNF
		frames = Paths.getSparrowAtlas('splashes/Default/noteSplashes_clasic');

		antialiasing = true;

		// NUEVO: Escala según tipo
		if (type == HOLD_START || type == HOLD_CONTINUOUS)
			scale.set(0.7, 0.7);
		else if (type == HOLD_END)
			scale.set(1.2, 1.2);

		// Configurar animaciones por defecto
		animation.addByPrefix('purple_0', 'note impact 1 purple', 24, false);
		animation.addByPrefix('purple_1', 'note impact 2 purple', 24, false);
		animation.addByPrefix('blue_0', 'note impact 1 blue', 24, false);
		animation.addByPrefix('blue_1', 'note impact 2 blue', 24, false);
		animation.addByPrefix('green_0', 'note impact 1 green', 24, false);
		animation.addByPrefix('green_1', 'note impact 2 green', 24, false);
		animation.addByPrefix('red_0', 'note impact 1 red', 24, false);
		animation.addByPrefix('red_1', 'note impact 2 red', 24, false);

		// Reproducir animación aleatoria según dirección
		var directions:Array<String> = ['purple', 'blue', 'green', 'red'];
		var randomVar:Int = FlxG.random.int(0, 1);
		animation.play('${directions[noteData]}_$randomVar', true);

		if (type != HOLD_CONTINUOUS)
		{
			animation.finishCallback = function(name:String)
			{
				recycleSplash();
			};
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		// Auto-reciclarse si la animación no está configurada correctamente
		if (!isHoldSplash && animation.curAnim != null && animation.curAnim.finished)
		{
			recycleSplash();
		}
	}
	
	override function destroy()
	{
		if (holdTimer != null)
		{
			holdTimer.cancel();
			holdTimer.destroy();
			holdTimer = null;
		}
		
		super.destroy();
	}
}

/**
 * NUEVO: Enum para tipos de splash
 */
enum SplashType
{
	NORMAL;          // Splash normal al golpear una nota
	HOLD_START;      // Splash al inicio de una hold note
	HOLD_CONTINUOUS; // Splash continuo mientras se mantiene la nota
	HOLD_END;        // Splash al soltar/terminar la hold note
}