package funkin.gameplay.objects.stages;

import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.math.FlxPoint;
import flixel.sound.FlxSound;
import flixel.util.FlxColor;
import haxe.Json;
import lime.utils.Assets;
// Scripting
import funkin.scripting.ScriptHandler;

using StringTools;

typedef StageData =
{
	var name:String;
	var defaultZoom:Float;
	var isPixelStage:Bool;
	var elements:Array<StageElement>;
	@:optional var gfVersion:String;
	@:optional var boyfriendPosition:Array<Float>;
	@:optional var dadPosition:Array<Float>;
	@:optional var gfPosition:Array<Float>;
	@:optional var cameraBoyfriend:Array<Float>;
	@:optional var cameraDad:Array<Float>;
	@:optional var hideGirlfriend:Bool;
	@:optional var scripts:Array<String>;
}

typedef StageElement =
{
	var type:String; // "sprite", "animated", "group", "sound", "custom_class", "custom_class_group"
	var asset:String;
	var position:Array<Float>;
	@:optional var name:String;
	@:optional var scrollFactor:Array<Float>;
	@:optional var scale:Array<Float>;
	@:optional var antialiasing:Bool;
	@:optional var active:Bool;
	@:optional var alpha:Float;
	@:optional var flipX:Bool;
	@:optional var flipY:Bool;
	@:optional var color:String;
	@:optional var blend:String;
	@:optional var visible:Bool;
	@:optional var zIndex:Int;

	// For animated sprites
	@:optional var animations:Array<StageAnimation>;
	@:optional var firstAnimation:String;

	// For groups
	@:optional var members:Array<StageMember>;

	// For sounds
	@:optional var volume:Float;
	@:optional var looped:Bool;

	// For custom classes (BackgroundGirls, BackgroundDancer, etc.)
	@:optional var className:String; // e.g., "BackgroundGirls", "BackgroundDancer"
	@:optional var customProperties:Dynamic; // Properties específicas de la clase

	// For custom class groups (múltiples instancias)
	@:optional var instances:Array<CustomClassInstance>;
}

typedef CustomClassInstance =
{
	var position:Array<Float>;
	@:optional var name:String; // Nombre único para esta instancia
	@:optional var scrollFactor:Array<Float>;
	@:optional var scale:Array<Float>;
	@:optional var alpha:Float;
	@:optional var flipX:Bool;
	@:optional var flipY:Bool;
	@:optional var customProperties:Dynamic;
}

typedef StageAnimation =
{
	var name:String;
	var prefix:String;
	@:optional var framerate:Int;
	@:optional var looped:Bool;
	@:optional var indices:Array<Int>;
}

typedef StageMember =
{
	var asset:String;
	var position:Array<Float>;
	@:optional var scrollFactor:Array<Float>;
	@:optional var scale:Array<Float>;
	@:optional var animations:Array<StageAnimation>;
}

class Stage extends FlxTypedGroup<FlxBasic>
{
	public var stageData:StageData;
	public var curStage:String;

	public var elements:Map<String, FlxSprite> = new Map<String, FlxSprite>();
	public var groups:Map<String, FlxTypedGroup<FlxSprite>> = new Map<String, FlxTypedGroup<FlxSprite>>();
	public var customClasses:Map<String, FlxSprite> = new Map<String, FlxSprite>(); // Para instancias individuales
	public var customClassGroups:Map<String, FlxTypedGroup<FlxSprite>> = new Map<String, FlxTypedGroup<FlxSprite>>(); // Para grupos
	public var sounds:Map<String, FlxSound> = new Map<String, FlxSound>();
	
	public var defaultCamZoom:Float = 1.05;
	public var isPixelStage:Bool = false;

	// Character positions
	public var boyfriendPosition:FlxPoint = new FlxPoint(770, 450);
	public var dadPosition:FlxPoint = new FlxPoint(100, 100);
	public var gfPosition:FlxPoint = new FlxPoint(400, 130);

	// Camera offsets
	public var cameraBoyfriend:FlxPoint = new FlxPoint(0, 0);
	public var cameraDad:FlxPoint = new FlxPoint(0, 0);

	public var gfVersion:String = 'gf';
	public var hideGirlfriend:Bool = false;

	// Callbacks for stage-specific logic
	public var onBeatHit:Void->Void = null;
	public var onStepHit:Void->Void = null;
	public var onUpdate:Float->Void = null;

	// Scripting
	public var scripts:Array<String> = [];

	private var scriptsLoaded:Bool = false;

	public function new(stageName:String)
	{
		super();
		curStage = stageName;
		loadStage(stageName);
	}

	function loadStage(stageName:String):Void
	{
		try
		{
			var file:String = Assets.getText(Paths.stageJSON(stageName));
			stageData = cast Json.parse(file);

			for (script in ScriptHandler.stageScripts)
			{
				script.call('onStageCreate', [this]);
			}

			if (stageData != null)
			{
				buildStage();
				trace("Loaded stage: " + stageName);
			}
			else
			{
				trace("Stage data is null for: " + stageName);
				loadDefaultStage();
			}
		}
		catch (e:Dynamic)
		{
			trace("Error loading stage " + stageName + ": " + e);
			loadDefaultStage();
		}
	}

	public function buildStage():Void
	{
		// Load basic properties
		defaultCamZoom = stageData.defaultZoom;
		isPixelStage = stageData.isPixelStage;

		if (stageData.gfVersion != null)
			gfVersion = stageData.gfVersion;

		if (stageData.hideGirlfriend != null)
			hideGirlfriend = stageData.hideGirlfriend;

		// Load positions
		if (stageData.boyfriendPosition != null)
			boyfriendPosition.set(stageData.boyfriendPosition[0], stageData.boyfriendPosition[1]);

		if (stageData.dadPosition != null)
			dadPosition.set(stageData.dadPosition[0], stageData.dadPosition[1]);

		if (stageData.gfPosition != null)
			gfPosition.set(stageData.gfPosition[0], stageData.gfPosition[1]);

		if (stageData.cameraBoyfriend != null)
			cameraBoyfriend.set(stageData.cameraBoyfriend[0], stageData.cameraBoyfriend[1]);

		if (stageData.cameraDad != null)
			cameraDad.set(stageData.cameraDad[0], stageData.cameraDad[1]);

		// Sort elements by zIndex
		if (stageData.elements != null)
		{
			stageData.elements.sort(function(a, b)
			{
				var azIndex = a.zIndex != null ? a.zIndex : 0;
				var bzIndex = b.zIndex != null ? b.zIndex : 0;
				return azIndex - bzIndex;
			});

			// Build elements
			for (element in stageData.elements)
			{
				createElement(element);
			}
		}

		if (stageData.scripts != null && stageData.scripts.length > 0)
		{
			trace('[Stage] Loading scripts del stage desde JSON...');
			scripts = stageData.scripts;
			loadStageScripts();
		}
		else
		{
			// Intentar cargar scripts desde la carpeta del stage
			trace('[Stage] Intentando cargar scripts desde carpeta...');
			var stagePath = 'assets/stages/${curStage}/scripts/';

			#if sys
			if (sys.FileSystem.exists(stagePath))
			{
				trace('[Stage] Carpeta de scripts encontrada: $stagePath');
				var files = sys.FileSystem.readDirectory(stagePath);

				for (file in files)
				{
					if (file.endsWith('.hx') || file.endsWith('.hscript'))
					{
						trace('[Stage] Cargando script: $file');
						scripts.push(file);
					}
				}

				if (scripts.length > 0)
				{
					// Cargar los scripts encontrados
					loadStageScripts();
					trace('[Stage] ${scripts.length} scripts cargados desde carpeta');
				}
				else
				{
					trace('[Stage] No se encontraron scripts en la carpeta');
				}
			}
			else
			{
				trace('[Stage] Carpeta de scripts no existe: $stagePath');
			}
			#else
			trace('[Stage] Carga de scripts desde carpeta no disponible en esta plataforma');
			#end
		}
	}

	function createElement(element:StageElement):Void
	{
		switch (element.type.toLowerCase())
		{
			case "sprite":
				createSprite(element);
			case "animated":
				createAnimatedSprite(element);
			case "group":
				createGroup(element);
			case "sound":
				createSound(element);
			case "custom_class":
				createCustomClass(element);
			case "custom_class_group":
				createCustomClassGroup(element);
			default:
				trace("Unknown element type: " + element.type);
		}
	}

	function createSprite(element:StageElement):Void
	{
		var sprite:FlxSprite = new FlxSprite(element.position[0], element.position[1]);
		sprite.loadGraphic(Paths.imageStage(element.asset));

		applyElementProperties(sprite, element);

		add(sprite);

		if (element.name != null)
			elements.set(element.name, sprite);
	}

	function createAnimatedSprite(element:StageElement):Void
	{
		var sprite:FlxSprite = new FlxSprite(element.position[0], element.position[1]);

		// Load frames
		if (element.asset.endsWith('.txt'))
			sprite.frames = Paths.stageSpriteTxt(element.asset.replace('.txt', ''));
		else
			sprite.frames = Paths.stageSprite(element.asset);

		// Add animations
		if (element.animations != null)
		{
			for (anim in element.animations)
			{
				if (anim.indices != null && anim.indices.length > 0)
				{
					sprite.animation.addByIndices(anim.name, anim.prefix, anim.indices, "", anim.framerate != null ? anim.framerate : 24,
						anim.looped != null ? anim.looped : false);
				}
				else
				{
					sprite.animation.addByPrefix(anim.name, anim.prefix, anim.framerate != null ? anim.framerate : 24,
						anim.looped != null ? anim.looped : false);
				}
			}

			// Play first animation
			if (element.firstAnimation != null)
				sprite.animation.play(element.firstAnimation);
			else if (element.animations.length > 0)
				sprite.animation.play(element.animations[0].name);
		}

		applyElementProperties(sprite, element);

		add(sprite);

		if (element.name != null)
			elements.set(element.name, sprite);
	}

	function createGroup(element:StageElement):Void
	{
		var group:FlxTypedGroup<FlxSprite> = new FlxTypedGroup<FlxSprite>();

		if (element.members != null)
		{
			for (member in element.members)
			{
				var sprite:FlxSprite = new FlxSprite(member.position[0], member.position[1]);
				sprite.loadGraphic(Paths.imageStage(member.asset));

				if (member.scrollFactor != null)
					sprite.scrollFactor.set(member.scrollFactor[0], member.scrollFactor[1]);

				if (member.scale != null)
				{
					sprite.setGraphicSize(Std.int(sprite.width * member.scale[0]), Std.int(sprite.height * member.scale[1]));
					sprite.updateHitbox();
				}

				if (member.animations != null)
				{
					for (anim in member.animations)
					{
						if (anim.indices != null && anim.indices.length > 0)
						{
							sprite.animation.addByIndices(anim.name, anim.prefix, anim.indices, "", anim.framerate != null ? anim.framerate : 24,
								anim.looped != null ? anim.looped : false);
						}
						else
						{
							sprite.animation.addByPrefix(anim.name, anim.prefix, anim.framerate != null ? anim.framerate : 24,
								anim.looped != null ? anim.looped : false);
						}
					}
				}

				sprite.antialiasing = !isPixelStage;
				group.add(sprite);
			}
		}

		add(group);

		if (element.name != null)
			groups.set(element.name, group);
	}

	function createCustomClass(element:StageElement):Void
	{
		if (element.className == null)
		{
			trace("Custom class element missing className property");
			return;
		}

		var sprite:FlxSprite = createCustomClassInstance(element.className, element.position[0], element.position[1], element.customProperties);

		if (sprite != null)
		{
			// IMPORTANTE: Aplicar propiedades DESPUÉS de crear la instancia
			applyElementProperties(sprite, element);

			add(sprite);

			if (element.name != null)
				customClasses.set(element.name, sprite);

			trace("Created custom class: " + element.className + " at " + element.position[0] + ", " + element.position[1]);
		}
		else
		{
			trace("Failed to create custom class: " + element.className);
		}
	}

	function createCustomClassGroup(element:StageElement):Void
	{
		if (element.className == null)
		{
			trace("Custom class group missing className property");
			return;
		}

		if (element.instances == null || element.instances.length == 0)
		{
			trace("Custom class group has no instances");
			return;
		}

		var group:FlxTypedGroup<FlxSprite> = new FlxTypedGroup<FlxSprite>();

		for (i in 0...element.instances.length)
		{
			var instance = element.instances[i];

			var sprite:FlxSprite = createCustomClassInstance(element.className, instance.position[0], instance.position[1], instance.customProperties);

			if (sprite != null)
			{
				// Aplicar propiedades de la instancia individual
				if (instance.scrollFactor != null)
					sprite.scrollFactor.set(instance.scrollFactor[0], instance.scrollFactor[1]);

				if (instance.scale != null)
				{
					sprite.setGraphicSize(Std.int(sprite.width * instance.scale[0]), Std.int(sprite.height * instance.scale[1]));
					sprite.updateHitbox();
				}

				if (instance.alpha != null)
					sprite.alpha = instance.alpha;

				if (instance.flipX != null)
					sprite.flipX = instance.flipX;

				if (instance.flipY != null)
					sprite.flipY = instance.flipY;

				// Aplicar antialiasing
				sprite.antialiasing = !isPixelStage;

				group.add(sprite);

				// Guardar instancia individual si tiene nombre
				if (instance.name != null)
				{
					customClasses.set(instance.name, sprite);
				}

				trace("Created instance " + i + " of " + element.className);
			}
		}

		// Aplicar propiedades del grupo
		if (element.scrollFactor != null)
		{
			for (sprite in group.members)
			{
				if (sprite != null)
					sprite.scrollFactor.set(element.scrollFactor[0], element.scrollFactor[1]);
			}
		}

		add(group);

		if (element.name != null)
			customClassGroups.set(element.name, group);

		trace("Created custom class group: " + element.className + " with " + group.length + " instances");
	}

	private function loadStageScripts():Void
	{
		if (scriptsLoaded)
			return;

		for (scriptPath in scripts)
		{
			// El path puede ser relativo o absoluto
			var fullPath = scriptPath;

			// Si es relativo, agregamos el path base
			if (!scriptPath.startsWith('assets/'))
			{
				fullPath = 'assets/stages/${curStage}/scripts/$scriptPath';
			}

			ScriptHandler.loadScript(fullPath, "stage");
		}

		scriptsLoaded = true;

		// Exponer el stage a los scripts
		ScriptHandler.setOnStageScripts('stage', this);
		ScriptHandler.setOnStageScripts('currentStage', this);

		// Llamar onStageCreate en los scripts
		ScriptHandler.callOnStageScripts('onStageCreate', []);

		trace('[Stage] Scripts cargados: ${scripts.length}');
	}

	/**
	 * Crea una instancia de una clase personalizada
	 * FIX: Asegurarse de que las clases se crean correctamente con frames
	 */
	function createCustomClassInstance(className:String, x:Float, y:Float, ?customProps:Dynamic):FlxSprite
	{
		var sprite:FlxSprite = null;

		try
		{
			switch (className)
			{
				case "BackgroundGirls":
					// Crear usando Type.createInstance para mejor compatibilidad
					var bgClass = funkin.gameplay.objects.stages.BackgroundGirls;
					if (bgClass != null)
					{
						sprite = Type.createInstance(bgClass, [x, y]);
						// Aplicar propiedades personalizadas
						if (customProps != null && customProps.scared == true)
						{
							Reflect.callMethod(sprite, Reflect.field(sprite, "getScared"), []);
						}
					}
					else
					{
						trace("BackgroundGirls class not found!");
					}

				case "BackgroundDancer":
					var dancerClass = funkin.gameplay.objects.stages.BackgroundDancer;
					if (dancerClass != null)
					{
						sprite = Type.createInstance(dancerClass, [x, y]);
					}
					else
					{
						trace("BackgroundDancer class not found!");
					}

				// Agrega más clases personalizadas aquí
				default:
					trace("Unknown custom class: " + className);
					return null;
			}
		}
		catch (e:Dynamic)
		{
			trace("Error creating custom class " + className + ": " + e);
			return null;
		}

		return sprite;
	}
	
	function createSound(element:StageElement):Void
	{
		var sound:FlxSound = new FlxSound().loadEmbedded(Paths.soundStage('$curStage/sounds/'+element.asset));

		if (element.volume != null)
			sound.volume = element.volume;

		if (element.looped != null)
			sound.looped = element.looped;

		FlxG.sound.list.add(sound);

		if (element.name != null)
			sounds.set(element.name, sound);
	}

	function applyElementProperties(sprite:FlxSprite, element:StageElement):Void
	{
		if (element.scrollFactor != null)
			sprite.scrollFactor.set(element.scrollFactor[0], element.scrollFactor[1]);

		if (element.scale != null)
		{
			sprite.setGraphicSize(Std.int(sprite.width * element.scale[0]), Std.int(sprite.height * element.scale[1]));
			sprite.updateHitbox();
		}

		if (element.antialiasing != null)
			sprite.antialiasing = element.antialiasing;
		else
			sprite.antialiasing = !isPixelStage;

		if (element.active != null)
			sprite.active = element.active;

		if (element.alpha != null)
			sprite.alpha = element.alpha;

		if (element.flipX != null)
			sprite.flipX = element.flipX;

		if (element.flipY != null)
			sprite.flipY = element.flipY;

		if (element.color != null)
			sprite.color = FlxColor.fromString(element.color);

		if (element.blend != null)
		{
			switch (element.blend.toLowerCase())
			{
				case "add":
					sprite.blend = openfl.display.BlendMode.ADD;
				case "multiply":
					sprite.blend = openfl.display.BlendMode.MULTIPLY;
				case "screen":
					sprite.blend = openfl.display.BlendMode.SCREEN;
				default:
					sprite.blend = openfl.display.BlendMode.NORMAL;
			}
		}

		if (element.visible != null)
			sprite.visible = element.visible;
	}

	function loadDefaultStage():Void
	{
		// Fallback to default stage
		defaultCamZoom = 0.9;
		isPixelStage = false;

		var bg:FlxSprite = new FlxSprite(-600, -200).loadGraphic(Paths.imageStage('stageback'));
		bg.antialiasing = true;
		bg.scrollFactor.set(0.9, 0.9);
		bg.active = false;
		add(bg);

		var stageFront:FlxSprite = new FlxSprite(-650, 600).loadGraphic(Paths.imageStage('stagefront'));
		stageFront.setGraphicSize(Std.int(stageFront.width * 1.1));
		stageFront.updateHitbox();
		stageFront.antialiasing = true;
		stageFront.scrollFactor.set(0.9, 0.9);
		stageFront.active = false;
		add(stageFront);

		var stageCurtains:FlxSprite = new FlxSprite(-500, -300).loadGraphic(Paths.imageStage('stagecurtains'));
		stageCurtains.setGraphicSize(Std.int(stageCurtains.width * 0.9));
		stageCurtains.updateHitbox();
		stageCurtains.antialiasing = true;
		stageCurtains.scrollFactor.set(1.3, 1.3);
		stageCurtains.active = false;
		add(stageCurtains);
	}

	// Helper functions to get elements
	public function getElement(name:String):FlxSprite
	{
		return elements.get(name);
	}

	public function getGroup(name:String):FlxTypedGroup<FlxSprite> {
		// Primero buscamos en grupos normales
		if (groups.exists(name))
			return groups.get(name);
		
		// Si no, buscamos en grupos de clases personalizadas
		return customClassGroups.get(name);
	}

	public function getCustomClass(name:String):FlxSprite
	{
		return customClasses.get(name);
	}

	public function getCustomClassGroup(name:String):FlxTypedGroup<FlxSprite>
	{
		return customClassGroups.get(name);
	}

	public function getSound(name:String):FlxSound
	{
		return sounds.get(name);
	}

	// Método para llamar funciones en una instancia específica
	public function callCustomMethod(elementName:String, methodName:String, ?args:Array<Dynamic>):Dynamic
	{
		var element = customClasses.get(elementName);
		if (element == null)
		{
			trace("Custom class element not found: " + elementName);
			return null;
		}

		var method = Reflect.field(element, methodName);
		if (method == null)
		{
			trace("Method not found: " + methodName);
			return null;
		}

		if (args == null)
			args = [];

		return Reflect.callMethod(element, method, args);
	}

	// Método para llamar funciones en todas las instancias de un grupo
	public function callCustomGroupMethod(groupName:String, methodName:String, ?args:Array<Dynamic>):Void
	{
		var group = customClassGroups.get(groupName);
		if (group == null)
		{
			trace("Custom class group not found: " + groupName);
			return;
		}

		if (args == null)
			args = [];

		for (sprite in group.members)
		{
			if (sprite != null)
			{
				var method = Reflect.field(sprite, methodName);
				if (method != null)
				{
					Reflect.callMethod(sprite, method, args);
				}
			}
		}
	}

	// Callbacks
	public function beatHit(curBeat:Int):Void
	{
		if (scriptsLoaded)
			ScriptHandler.callOnStageScripts('onBeatHit', [curBeat]);

		if (onBeatHit != null)
			onBeatHit();

		// Llamar dance() en instancias individuales
		for (name => sprite in customClasses)
		{
			if (Reflect.hasField(sprite, "dance"))
			{
				Reflect.callMethod(sprite, Reflect.field(sprite, "dance"), []);
			}
		}

		// Llamar dance() en grupos
		for (name => group in customClassGroups)
		{
			for (sprite in group.members)
			{
				if (sprite != null && Reflect.hasField(sprite, "dance"))
				{
					Reflect.callMethod(sprite, Reflect.field(sprite, "dance"), []);
				}
			}
		}
	}

	public function stepHit(curStep:Int):Void
	{
		if (scriptsLoaded)
			ScriptHandler.callOnStageScripts('onStepHit', [curStep]);

		if (onStepHit != null)
			onStepHit();
	}

	override public function update(elapsed:Float):Void
	{
		if (scriptsLoaded)
			ScriptHandler.callOnStageScripts('onUpdate', [elapsed]);

		super.update(elapsed);

		if (onUpdate != null)
			onUpdate(elapsed);

		if (scriptsLoaded)
			ScriptHandler.callOnStageScripts('onUpdatePost', [elapsed]);
	}

	override public function destroy():Void
	{
		if (scriptsLoaded)
		{
			ScriptHandler.callOnStageScripts('onDestroy', []);
			ScriptHandler.clearStageScripts();
			scriptsLoaded = false;
		}

		super.destroy();
	}
}
