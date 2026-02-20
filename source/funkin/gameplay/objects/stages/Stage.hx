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
// FunkinSprite — reemplaza FlxSprite para sprites animados del stage
import animationdata.FunkinSprite;
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
	@:optional var className:String;
	@:optional var customProperties:Dynamic;

	// For custom class groups
	@:optional var instances:Array<CustomClassInstance>;
}

typedef CustomClassInstance =
{
	var position:Array<Float>;
	@:optional var name:String;
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

	// Los mapas siguen tipados como FlxSprite — FunkinSprite extiende FlxAnimate
	// que a su vez extiende FlxSprite, así que la compatibilidad está garantizada.
	public var elements:Map<String, FlxSprite> = new Map<String, FlxSprite>();
	public var groups:Map<String, FlxTypedGroup<FlxSprite>> = new Map<String, FlxTypedGroup<FlxSprite>>();
	public var customClasses:Map<String, FlxSprite> = new Map<String, FlxSprite>();
	public var customClassGroups:Map<String, FlxTypedGroup<FlxSprite>> = new Map<String, FlxTypedGroup<FlxSprite>>();
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
			var file:String = Paths.getText(Paths.stageJSON(stageName));
			stageData = cast Json.parse(file);
			trace('stagefile: $file');

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
			trace('[Stage] Intentando cargar scripts desde carpeta...');
			// Busca en mod primero, luego en assets
			var stagePath = Paths.stageScripts(curStage);

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

	// ── Sprite estático ───────────────────────────────────────────────────────
	// Para imágenes sin animación se sigue usando FlxSprite (más ligero).

	function createSprite(element:StageElement):Void
	{
		var sprite:FlxSprite = new FlxSprite(element.position[0], element.position[1]);
		sprite.loadGraphic(Paths.imageStage(element.asset));

		applyElementProperties(sprite, element);
		add(sprite);

		if (element.name != null)
			elements.set(element.name, sprite);
	}

	// ── Sprite animado — ahora usa FunkinSprite ───────────────────────────────
	/**
	 * createAnimatedSprite — integración FunkinSprite
	 *
	 * FunkinSprite.loadStageSparrow() detecta automáticamente Sparrow vs Packer.
	 * FunkinSprite.addAnim()  / playAnim() funcionan igual para ambos formatos.
	 *
	 * El JSON del stage no necesita cambios — los campos "animations" y
	 * "firstAnimation" se siguen usando exactamente igual.
	 */
	function createAnimatedSprite(element:StageElement):Void
	{
		var sprite:FunkinSprite = new FunkinSprite(element.position[0], element.position[1]);

		// Cargar frames: Sparrow (XML) o Packer (TXT) — auto-detectado
		var assetKey:String = element.asset.endsWith('.txt')
			? element.asset.replace('.txt', '')
			: element.asset;

		sprite.loadStageSparrow(assetKey);

		// Añadir animaciones con la API unificada
		if (element.animations != null)
		{
			for (anim in element.animations)
			{
				sprite.addAnim(
					anim.name,
					anim.prefix,
					anim.framerate != null ? anim.framerate : 24,
					anim.looped != null ? anim.looped : false,
					(anim.indices != null && anim.indices.length > 0) ? anim.indices : null
				);
			}

			// Reproducir la primera animación
			if (element.firstAnimation != null)
				sprite.playAnim(element.firstAnimation);
			else if (element.animations.length > 0)
				sprite.playAnim(element.animations[0].name);
		}

		applyElementProperties(sprite, element);
		add(sprite);

		if (element.name != null)
			elements.set(element.name, sprite);
	}

	// ── Grupo de sprites — miembros animados usan FunkinSprite ───────────────

	function createGroup(element:StageElement):Void
	{
		var group:FlxTypedGroup<FlxSprite> = new FlxTypedGroup<FlxSprite>();

		if (element.members != null)
		{
			for (member in element.members)
			{
				// Si el miembro tiene animaciones, usar FunkinSprite; si no, FlxSprite estático
				var hasAnims = member.animations != null && member.animations.length > 0;

				if (hasAnims)
				{
					var spr:FunkinSprite = new FunkinSprite(member.position[0], member.position[1]);
					spr.loadStageSparrow(member.asset);

					for (anim in member.animations)
					{
						spr.addAnim(
							anim.name,
							anim.prefix,
							anim.framerate != null ? anim.framerate : 24,
							anim.looped != null ? anim.looped : false,
							(anim.indices != null && anim.indices.length > 0) ? anim.indices : null
						);
					}

					// Reproducir la primera animación
					if (member.animations.length > 0)
						spr.playAnim(member.animations[0].name);

					if (member.scrollFactor != null)
						spr.scrollFactor.set(member.scrollFactor[0], member.scrollFactor[1]);

					if (member.scale != null)
					{
						spr.scale.set(member.scale[0], member.scale[1]);
						spr.updateHitbox();
					}

					spr.antialiasing = !isPixelStage;
					group.add(spr);
				}
				else
				{
					// Sin animaciones → FlxSprite estático (más ligero)
					var spr:FlxSprite = new FlxSprite(member.position[0], member.position[1]);
					spr.loadGraphic(Paths.imageStage(member.asset));

					if (member.scrollFactor != null)
						spr.scrollFactor.set(member.scrollFactor[0], member.scrollFactor[1]);

					if (member.scale != null)
					{
						spr.setGraphicSize(Std.int(spr.width * member.scale[0]), Std.int(spr.height * member.scale[1]));
						spr.updateHitbox();
					}

					spr.antialiasing = !isPixelStage;
					group.add(spr);
				}
			}
		}

		add(group);

		if (element.name != null)
			groups.set(element.name, group);
	}

	// ── Custom classes ────────────────────────────────────────────────────────

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

				sprite.antialiasing = !isPixelStage;

				group.add(sprite);

				if (instance.name != null)
					customClasses.set(instance.name, sprite);

				trace("Created instance " + i + " of " + element.className);
			}
		}

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
			var fullPath = scriptPath;

			// Busca el script en mod activo, luego en assets
			if (!scriptPath.startsWith('assets/') && !scriptPath.startsWith('mods/'))
			{
				final modScriptPath = mods.ModManager.resolveInMod('stages/${curStage}/scripts/$scriptPath');
				fullPath = modScriptPath ?? 'assets/stages/${curStage}/scripts/$scriptPath';
			}

			ScriptHandler.loadScript(fullPath, "stage");
		}

		scriptsLoaded = true;

		ScriptHandler.setOnStageScripts('stage', this);
		ScriptHandler.setOnStageScripts('currentStage', this);

		ScriptHandler.callOnStageScripts('onStageCreate', []);

		trace('[Stage] Scripts cargados: ${scripts.length}');
	}

	/**
	 * Crea una instancia de una clase personalizada
	 */
	function createCustomClassInstance(className:String, x:Float, y:Float, ?customProps:Dynamic):FlxSprite
	{
		var sprite:FlxSprite = null;

		try
		{
			switch (className)
			{
				case "BackgroundGirls":
					var bgClass = funkin.gameplay.objects.stages.BackgroundGirls;
					if (bgClass != null)
					{
						sprite = Type.createInstance(bgClass, [x, y]);
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
		defaultCamZoom = 0.9;
		isPixelStage = false;

		var bg:FlxSprite = new FlxSprite(-600, -200).loadGraphic(Paths.imageStage('stageback'));
		bg.antialiasing = FlxG.save.data.antialiasing;
		bg.scrollFactor.set(0.9, 0.9);
		bg.active = false;
		add(bg);

		var stageFront:FlxSprite = new FlxSprite(-650, 600).loadGraphic(Paths.imageStage('stagefront'));
		stageFront.setGraphicSize(Std.int(stageFront.width * 1.1));
		stageFront.updateHitbox();
		stageFront.antialiasing = FlxG.save.data.antialiasing;
		stageFront.scrollFactor.set(0.9, 0.9);
		stageFront.active = false;
		add(stageFront);

		var stageCurtains:FlxSprite = new FlxSprite(-500, -300).loadGraphic(Paths.imageStage('stagecurtains'));
		stageCurtains.setGraphicSize(Std.int(stageCurtains.width * 0.9));
		stageCurtains.updateHitbox();
		stageCurtains.antialiasing = FlxG.save.data.antialiasing;
		stageCurtains.scrollFactor.set(1.3, 1.3);
		stageCurtains.active = false;
		add(stageCurtains);
	}

	// ── Helper getters ────────────────────────────────────────────────────────

	public function getElement(name:String):FlxSprite
		return elements.get(name);

	public function getGroup(name:String):FlxTypedGroup<FlxSprite>
	{
		if (groups.exists(name))
			return groups.get(name);
		return customClassGroups.get(name);
	}

	public function getCustomClass(name:String):FlxSprite
		return customClasses.get(name);

	public function getCustomClassGroup(name:String):FlxTypedGroup<FlxSprite>
		return customClassGroups.get(name);

	public function getSound(name:String):FlxSound
		return sounds.get(name);

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
					Reflect.callMethod(sprite, method, args);
			}
		}
	}

	// ── Callbacks ─────────────────────────────────────────────────────────────

	public function beatHit(curBeat:Int):Void
	{
		if (scriptsLoaded)
			ScriptHandler.callOnStageScripts('onBeatHit', [curBeat]);

		if (onBeatHit != null)
			onBeatHit();

		for (name => sprite in customClasses)
		{
			if (Reflect.hasField(sprite, "dance"))
				Reflect.callMethod(sprite, Reflect.field(sprite, "dance"), []);
		}

		for (name => group in customClassGroups)
		{
			for (sprite in group.members)
			{
				if (sprite != null && Reflect.hasField(sprite, "dance"))
					Reflect.callMethod(sprite, Reflect.field(sprite, "dance"), []);
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
