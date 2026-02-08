package notes;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;

class NoteSplash extends FlxSprite
{
	public var noteDatawea:Int = 0;

	public function new(x:Float, y:Float, noteData:Int = 0, ?splashName:String = null)
	{
		super(x, y);
		noteDatawea = noteData;
		setup(x, y, noteData, splashName);
	}

	public function setup(x:Float, y:Float, noteData:Int = 0, ?splashName:String = null)
	{
		this.x = x;
		this.y = y;
		noteDatawea = noteData;

		// Inicializar sistema
		NoteSkinSystem.init();

		// Limpiar animaciones anteriores si existen
		if (animation != null)
		{
			animation.destroyAnimations();
		}

		// Obtener datos del splash
		var splashData = NoteSkinSystem.getSplashData(splashName);
		
		if (splashData != null)
		{
			// Cargar frames
			frames = NoteSkinSystem.getSplashTexture(splashName);

			// Aplicar escala si está configurada
			if (splashData.assets.scale != null)
			{
				scale.set(splashData.assets.scale, splashData.assets.scale);
			}

			// Configurar antialiasing
			antialiasing = splashData.assets.antialiasing != null ? splashData.assets.antialiasing : true;

			// Aplicar offset si está configurado
			if (splashData.assets.offset != null && splashData.assets.offset.length >= 2)
			{
				offset.set(splashData.assets.offset[0], splashData.assets.offset[1]);
			}

			// CORREGIDO: Configurar animaciones correctamente según la dirección
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
			var directionNames:Array<String> = ["purple", "blue", "green", "red"];
			
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

			// IMPORTANTE: Reproducir la animación correcta según la dirección
			playAnimation(noteDatawea);

			// Configurar para auto-destruirse cuando termine la animación
			animation.finishCallback = function(name:String)
			{
				kill();
			};
		}
		else
		{
			// Fallback a splash por defecto
			trace('Warning: Could not load splash data, using default');
			loadDefaultSplash(noteDatawea);
		}

		updateHitbox();
		
		// Centrar el splash
		offset.x = width * 0.3;
		offset.y = height * 0.3;

		// Revivir el sprite si estaba muerto (para recycle)
		revive();
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

	function loadDefaultSplash(noteData:Int):Void
	{
		// Cargar splash por defecto de FNF
		frames = Paths.getSparrowAtlas('splashes/Default/noteSplashes_clasic');

		antialiasing = true;

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

		animation.finishCallback = function(name:String)
		{
			kill();
		};
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		// Auto-destruirse si la animación no está configurada correctamente
		if (animation.curAnim != null && animation.curAnim.finished)
		{
			kill();
		}
	}
}