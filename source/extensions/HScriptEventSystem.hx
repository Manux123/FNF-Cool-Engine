package extensions;

import flixel.FlxG;
import haxe.ds.StringMap;
#if hscript
import hscript.Parser;
import hscript.Interp;
#end

/**
 * Sistema de eventos con HScript - Editable en tiempo real
 * Los eventos se escriben en archivos .hx/.hscript que se pueden editar sin recompilar
 * Diseñado para ser usado con un PlayStateEditor
 */
class HScriptEventSystem
{
	// ========================================
	// HSCRIPT CORE
	// ========================================
	#if hscript
	private var parser:Parser;
	private var interp:Interp;
	#end

	// ========================================
	// EVENTOS CARGADOS
	// ========================================
	// Eventos por beat: Map<beatNumber, Array<función>>
	public var beatEvents:Map<Int, Array<Void->Void>> = new Map();

	// Eventos por step: Map<stepNumber, Array<función>>
	public var stepEvents:Map<Int, Array<Void->Void>> = new Map();

	// Eventos por actualización (cada frame)
	public var updateEvents:Array<Float->Void> = [];

	// Eventos condicionales: función que retorna bool + callback
	public var conditionalEvents:Array<ConditionalEvent> = [];

	// Scripts cargados (para hot-reload)
	private var loadedScripts:Map<String, String> = new Map();

	// Eventos ejecutados una sola vez (para executeOnce)
	private var executedOnce:Map<String, Bool> = new Map();

	// ========================================
	// CONFIGURACIÓN
	// ========================================
	// Referencia al PlayState para poder acceder a sus propiedades
	public var playState:Dynamic = null;

	// Modo debug para logging
	public var debugMode:Bool = false;

	// Modo editor: permite hot-reload
	public var editorMode:Bool = false;

	// Callback cuando se recargan eventos (para el editor)
	public var onScriptReloaded:String->Void = null;

	// ========================================
	// CONSTRUCTOR
	// ========================================

	public function new()
	{
		#if hscript
		// Inicializar parser e intérprete de HScript
		parser = new Parser();
		parser.allowTypes = true;
		parser.allowJSON = true;
		parser.allowMetadata = true;

		interp = new Interp();

		// Exponer variables globales útiles
		setupGlobalVariables();
		#else
		trace('[HScriptEventSystem] HScript dont disponible in this compilation');
		#end

		trace('[HScriptEventSystem] Inicialized');
	}

	// ========================================
	// SETUP DE VARIABLES GLOBALES
	// ========================================

	/**
	 * Exponer variables y funciones al intérprete de HScript
	 */
	private function setupGlobalVariables():Void
	{
		#if hscript
		// Clases de Flixel
		interp.variables.set('FlxG', FlxG);
		interp.variables.set('FlxSprite', flixel.FlxSprite);
		interp.variables.set('FlxTween', flixel.tweens.FlxTween);
		interp.variables.set('FlxEase', flixel.tweens.FlxEase);
		interp.variables.set('FlxColor', {
			BLACK: 0xFF000000,
			WHITE: 0xFFFFFFFF,
			RED: 0xFFFF0000,
			GREEN: 0xFF00FF00,
			BLUE: 0xFF0000FF,
			TRANSPARENT: 0x00000000,

			fromRGB: function(r:Int, g:Int, b:Int, a:Int = 255)
			{
				return flixel.util.FlxColor.fromRGB(r, g, b, a);
			}
		});

		interp.variables.set('FlxTimer', flixel.util.FlxTimer);
		interp.variables.set('FlxSound', flixel.sound.FlxSound);
		interp.variables.set('Math', Math);

		// Helpers de registro de eventos
		interp.variables.set('onBeat', registerBeatEvent);
		interp.variables.set('onStep', registerStepEvent);
		interp.variables.set('onUpdate', registerUpdateEvent);
		interp.variables.set('onCondition', registerConditionalEvent);
		interp.variables.set('executeOnce', createOnceWrapper);

		// Helper de logging
		interp.variables.set('trace', function(msg:Dynamic)
		{
			if (debugMode)
				trace('[HScript] $msg');
		});

		// Acceso al PlayState (se actualiza al cargar script)
		interp.variables.set('game', playState);
		#end
	}

	/**
	 * Actualizar referencia al PlayState en el intérprete
	 */
	public function updatePlayStateReference():Void
	{
		#if hscript
		interp.variables.set('game', playState);

		// También exponer propiedades comunes directamente
		if (playState != null)
		{
			interp.variables.set('health', playState.health);
			interp.variables.set('boyfriend', playState.boyfriend);
			interp.variables.set('dad', playState.dad);
			interp.variables.set('gf', playState.gf);
			interp.variables.set('camGame', playState.camGame);
			interp.variables.set('camHUD', playState.camHUD);
			interp.variables.set('curBeat', playState.curBeat);
			interp.variables.set('curStep', playState.curStep);
		}
		#end
	}

	// ========================================
	// CARGA DE SCRIPTS
	// ========================================

	/**
	 * Cargar script de eventos desde archivo
	 * @param songName Nombre de la canción
	 * @param scriptName Nombre del script (opcional, default: "events")
	 */
	public function loadScript(songName:String, ?scriptName:String = "events"):Void
	{
		var path:String = 'assets/data/$songName/$scriptName.hscript';

		#if sys
		if (sys.FileSystem.exists(path))
		{
			var content:String = sys.io.File.getContent(path);
			executeScript(content, '$songName-$scriptName');
			loadedScripts.set('$songName-$scriptName', content);

			if (debugMode)
				trace('[HScriptEventSystem] Script load: $path');
		}
		else
		{
			if (debugMode)
				trace('[HScriptEventSystem] Script dont loaded: $path');
		}
		#else
		// En web/HTML5, usar Assets
		if (openfl.utils.Assets.exists(path))
		{
			var content:String = openfl.utils.Assets.getText(path);
			executeScript(content, '$songName-$scriptName');
			loadedScripts.set('$songName-$scriptName', content);
		}
		#end
	}

	/**
	 * Cargar script desde string (para el editor)
	 */
	public function loadScriptFromString(script:String, scriptId:String):Void
	{
		executeScript(script, scriptId);
		loadedScripts.set(scriptId, script);

		if (onScriptReloaded != null)
			onScriptReloaded(scriptId);
	}

	/**
	 * Recargar un script (hot-reload para el editor)
	 */
	public function reloadScript(scriptId:String):Void
	{
		if (loadedScripts.exists(scriptId))
		{
			// Limpiar eventos anteriores de este script
			clearEventsFromScript(scriptId);

			// Recargar
			var script = loadedScripts.get(scriptId);
			executeScript(script, scriptId);

			if (onScriptReloaded != null)
				onScriptReloaded(scriptId);

			if (debugMode)
				trace('[HScriptEventSystem] Script recargued: $scriptId');
		}
	}

	/**
	 * Ejecutar código HScript
	 */
	private function executeScript(script:String, scriptId:String):Void
	{
		#if hscript
		try
		{
			// Actualizar referencia al PlayState
			updatePlayStateReference();

			// Parsear y ejecutar
			var program = parser.parseString(script, scriptId);
			interp.execute(program);

			if (debugMode)
				trace('[HScriptEventSystem] Script ejecuted: $scriptId');
		}
		catch (e:Dynamic)
		{
			trace('[HScriptEventSystem] ERROR ejecute script $scriptId: $e');
		}
		#end
	}

	// ========================================
	// REGISTRO DE EVENTOS (llamados desde HScript)
	// ========================================

	/**
	 * Registrar evento de beat
	 * Llamado desde HScript: onBeat(16, function() { ... });
	 */
	private function registerBeatEvent(beat:Int, callback:Void->Void):Void
	{
		if (!beatEvents.exists(beat))
			beatEvents.set(beat, []);

		beatEvents.get(beat).push(callback);

		if (debugMode)
			trace('[HScriptEventSystem] Event beat registred: $beat');
	}

	/**
	 * Registrar evento de step
	 * Llamado desde HScript: onStep(128, function() { ... });
	 */
	private function registerStepEvent(step:Int, callback:Void->Void):Void
	{
		if (!stepEvents.exists(step))
			stepEvents.set(step, []);

		stepEvents.get(step).push(callback);

		if (debugMode)
			trace('[HScriptEventSystem] Event step registred: $step');
	}

	/**
	 * Registrar evento de actualización (cada frame)
	 * Llamado desde HScript: onUpdate(function(elapsed) { ... });
	 */
	private function registerUpdateEvent(callback:Float->Void):Void
	{
		updateEvents.push(callback);

		if (debugMode)
			trace('[HScriptEventSystem] Event update registred');
	}

	/**
	 * Registrar evento condicional
	 * Llamado desde HScript: onCondition(function() { return game.health < 0.5; }, function() { ... });
	 */
	private function registerConditionalEvent(condition:Void->Bool, callback:Void->Void):Void
	{
		conditionalEvents.push({
			condition: condition,
			callback: callback
		});

		if (debugMode)
			trace('[HScriptEventSystem] Event conditional registred');
	}

	/**
	 * Wrapper para ejecutar algo una sola vez
	 * Llamado desde HScript: executeOnce("my_event", function() { ... });
	 */
	private function createOnceWrapper(eventId:String, callback:Void->Void):Void->Void
	{
		return function()
		{
			if (!executedOnce.exists(eventId))
			{
				callback();
				executedOnce.set(eventId, true);
			}
		};
	}

	// ========================================
	// EJECUCIÓN DE EVENTOS
	// ========================================

	/**
	 * Ejecutar eventos de beat
	 */
	public function triggerBeatEvents(beat:Int):Void
	{
		if (!beatEvents.exists(beat))
			return;

		var events = beatEvents.get(beat);
		for (callback in events)
		{
			try
			{
				// Actualizar variables antes de ejecutar
				updatePlayStateReference();
				callback();
			}
			catch (e:Dynamic)
			{
				trace('[HScriptEventSystem] ERROR event beat $beat: $e');
			}
		}
	}

	/**
	 * Ejecutar eventos de step
	 */
	public function triggerStepEvents(step:Int):Void
	{
		if (!stepEvents.exists(step))
			return;

		var events = stepEvents.get(step);
		for (callback in events)
		{
			try
			{
				updatePlayStateReference();
				callback();
			}
			catch (e:Dynamic)
			{
				trace('[HScriptEventSystem] ERROR event step $step: $e');
			}
		}
	}

	/**
	 * Ejecutar eventos de actualización (cada frame)
	 */
	public function triggerUpdateEvents(elapsed:Float):Void
	{
		for (callback in updateEvents)
		{
			try
			{
				updatePlayStateReference();
				callback(elapsed);
			}
			catch (e:Dynamic)
			{
				trace('[HScriptEventSystem] ERROR event update: $e');
			}
		}
	}

	/**
	 * Ejecutar eventos condicionales
	 */
	public function triggerConditionalEvents():Void
	{
		for (event in conditionalEvents)
		{
			try
			{
				updatePlayStateReference();
				if (event.condition())
				{
					event.callback();
				}
			}
			catch (e:Dynamic)
			{
				trace('[HScriptEventSystem] ERROR event conditional: $e');
			}
		}
	}

	// ========================================
	// GESTIÓN DE EVENTOS
	// ========================================

	/**
	 * Limpiar eventos de un script específico
	 */
	private function clearEventsFromScript(scriptId:String):Void
	{
		// Por ahora, limpiar todo
		// TODO: trackear qué eventos pertenecen a qué script
		clearAll();
	}

	/**
	 * Limpiar todos los eventos
	 */
	public function clearAll():Void
	{
		beatEvents.clear();
		stepEvents.clear();
		updateEvents = [];
		conditionalEvents = [];
		executedOnce.clear();

		if (debugMode)
			trace('[HScriptEventSystem] All events cleans');
	}

	/**
	 * Obtener todos los scripts cargados
	 */
	public function getLoadedScripts():Array<String>
	{
		var scripts:Array<String> = [];
		for (key in loadedScripts.keys())
		{
			scripts.push(key);
		}
		return scripts;
	}

	/**
	 * Obtener contenido de un script
	 */
	public function getScriptContent(scriptId:String):String
	{
		return loadedScripts.exists(scriptId) ? loadedScripts.get(scriptId) : "";
	}

	/**
	 * Guardar script (para el editor)
	 */
	public function saveScript(scriptId:String, content:String, ?filepath:String):Void
	{
		#if sys
		if (filepath != null)
		{
			sys.io.File.saveContent(filepath, content);
			if (debugMode)
				trace('[HScriptEventSystem] Script saved: $filepath');
		}
		#end

		loadedScripts.set(scriptId, content);
	}

	// ========================================
	// DESTRUCTOR
	// ========================================

	public function destroy():Void
	{
		clearAll();
		loadedScripts.clear();

		#if hscript
		interp = null;
		parser = null;
		#end

		playState = null;
		onScriptReloaded = null;

		trace('[HScriptEventSystem] Destroy');
	}
}

/**
 * Typedef para eventos condicionales
 */
typedef ConditionalEvent =
{
	var condition:Void->Bool;
	var callback:Void->Void;
}
