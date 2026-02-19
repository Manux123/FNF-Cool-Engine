package funkin.scripting;

import flixel.FlxG;
import flixel.FlxState;
import haxe.Exception;
import sys.FileSystem;
import sys.io.File;

#if HSCRIPT_ALLOWED
import hscript.Parser;
import hscript.Interp;
import hscript.Expr;
#end

import shaders.ShaderManager;

using StringTools;

/**
 * Sistema de scripts para States con soporte para:
 * - Cancelación de eventos
 * - Override de funciones
 * - Prioridades de scripts
 */
class StateScriptHandler
{
	public static var stateScripts:Map<String, StateScriptInstance> = new Map();
	
	// Sistema de overrides - permite sobrescribir funciones completamente
	public static var functionOverrides:Map<String, FunctionOverride> = new Map();
	
	#if HSCRIPT_ALLOWED
	private static var parser:Parser;
	#end
	
	/**
	 * Inicializar el sistema de scripts
	 */
	public static function init():Void
	{
		#if HSCRIPT_ALLOWED
		parser = new Parser();
		parser.allowTypes = true;
		parser.allowJSON = true;
		parser.allowMetadata = true;
		#end
		
		trace('[StateScriptHandler] Sistema de scripts de states inicializado');
	}
	
	/**
	 * Cargar scripts para un state específico
	 */
	public static function loadStateScripts(stateName:String, state:FlxState):Array<StateScriptInstance>
	{
		clearStateScripts();
		
		var scriptsPath = 'assets/states/${stateName.toLowerCase()}';
		var scripts = loadScriptsFromFolder(scriptsPath, state);
		
		trace('[StateScriptHandler] ${scripts.length} scripts cargados para $stateName');
		return scripts;
	}
	
	/**
	 * Cargar un script desde archivo
	 */
	public static function loadScript(scriptPath:String, state:FlxState, ?priority:Int = 0):StateScriptInstance
	{
		#if HSCRIPT_ALLOWED
		if (!FileSystem.exists(scriptPath))
		{
			trace('[StateScriptHandler] Script no encontrado: $scriptPath');
			return null;
		}
		
		var scriptName = getScriptName(scriptPath);
		var content = File.getContent(scriptPath);
		
		var script = new StateScriptInstance(scriptName, scriptPath, priority);
		script.state = state;
		
		try
		{
			var program = parser.parseString(content, scriptPath);
			script.program = program;
			script.interp = new Interp();
			
			// Exponer variables globales al script
			exposeGlobals(script.interp, state, script);
			
			// Ejecutar el script
			script.interp.execute(program);
			
			// Llamar onCreate si existe
			script.call('onCreate', []);
			
			// Guardar script
			stateScripts.set(scriptName, script);
			
			trace('[StateScriptHandler] Script cargado: $scriptName (prioridad: $priority)');
			return script;
		}
		catch (e:Exception)
		{
			trace('[StateScriptHandler] Error al cargar script $scriptName: ${e.message}');
			trace('Stack: ${e.stack}');
			return null;
		}
		#else
		trace('[StateScriptHandler] HScript no está habilitado. Define HSCRIPT_ALLOWED en Project.xml');
		return null;
		#end
	}
	
	/**
	 * Cargar todos los scripts de una carpeta
	 */
	public static function loadScriptsFromFolder(folderPath:String, state:FlxState):Array<StateScriptInstance>
	{
		var scripts:Array<StateScriptInstance> = [];
		
		if (!FileSystem.exists(folderPath) || !FileSystem.isDirectory(folderPath))
		{
			trace('[StateScriptHandler] Carpeta no encontrada: $folderPath');
			return scripts;
		}
		
		for (file in FileSystem.readDirectory(folderPath))
		{
			if (file.endsWith('.hx') || file.endsWith('.hscript'))
			{
				var fullPath = '$folderPath/$file';
				var script = loadScript(fullPath, state);
				if (script != null)
					scripts.push(script);
			}
		}
		
		return scripts;
	}
	
	/**
	 * Llamar función en todos los scripts
	 * Si algún script retorna true, se cancela la ejecución
	 * @return true si el evento fue cancelado
	 */
	public static function callOnScripts(funcName:String, ?args:Array<Dynamic>):Bool
	{
		if (args == null) args = [];
		
		// Primero verificar si hay un override
		if (functionOverrides.exists(funcName))
		{
			var funcOverride = functionOverrides.get(funcName);
			if (funcOverride.enabled)
			{
				trace('[StateScriptHandler] Usando override para $funcName');
				funcOverride.call(args);
				return true; // El override cancela la ejecución original
			}
		}
		
		// Ordenar scripts por prioridad (mayor prioridad primero)
		var sortedScripts = getSortedScripts();
		
		for (script in sortedScripts)
		{
			var result = script.call(funcName, args);
			
			// Si el script retorna true, cancela el evento
			if (result == true)
			{
				trace('[StateScriptHandler] Evento $funcName cancelado por script ${script.name}');
				return true;
			}
		}
		
		return false; // No se canceló
	}
	
	/**
	 * Llamar función y obtener resultado (el primer script que retorne algo no-null)
	 */
	public static function callOnScriptsReturn(funcName:String, ?args:Array<Dynamic>, ?defaultValue:Dynamic = null):Dynamic
	{
		if (args == null) args = [];
		
		// Verificar override primero
		if (functionOverrides.exists(funcName))
		{
			var funcOverride = functionOverrides.get(funcName);
			if (funcOverride.enabled)
			{
				return funcOverride.call(args);
			}
		}
		
		var sortedScripts = getSortedScripts();
		
		for (script in sortedScripts)
		{
			var result = script.call(funcName, args);
			if (result != null)
				return result;
		}
		
		return defaultValue;
	}
	
	/**
	 * Registrar un override de función
	 * Permite sobrescribir completamente el comportamiento de una función
	 */
	public static function registerOverride(funcName:String, script:StateScriptInstance, func:Dynamic):Void
	{
		var funcOverride = new FunctionOverride(funcName, script, func);
		functionOverrides.set(funcName, funcOverride);
		
		trace('[StateScriptHandler] Override registrado para $funcName por script ${script.name}');
	}
	
	/**
	 * Desregistrar un override
	 */
	public static function unregisterOverride(funcName:String):Void
	{
		if (functionOverrides.exists(funcName))
		{
			functionOverrides.remove(funcName);
			trace('[StateScriptHandler] Override removido para $funcName');
		}
	}
	
	/**
	 * Habilitar/deshabilitar un override sin eliminarlo
	 */
	public static function toggleOverride(funcName:String, enabled:Bool):Void
	{
		if (functionOverrides.exists(funcName))
		{
			functionOverrides.get(funcName).enabled = enabled;
			trace('[StateScriptHandler] Override $funcName ${enabled ? "habilitado" : "deshabilitado"}');
		}
	}
	
	/**
	 * Verificar si una función tiene override
	 */
	public static function hasOverride(funcName:String):Bool
	{
		return functionOverrides.exists(funcName) && functionOverrides.get(funcName).enabled;
	}
	
	/**
	 * Obtener scripts ordenados por prioridad
	 */
	private static function getSortedScripts():Array<StateScriptInstance>
	{
		var scripts:Array<StateScriptInstance> = [];
		for (script in stateScripts)
			scripts.push(script);
		
		// Ordenar por prioridad (mayor primero)
		scripts.sort((a, b) -> b.priority - a.priority);
		
		return scripts;
	}
	
	/**
	 * Obtener todas las opciones custom de los scripts
	 */
	public static function getCustomOptions():Array<Dynamic>
	{
		var allOptions:Array<Dynamic> = [];
		
		for (script in stateScripts)
		{
			var options = script.call('getCustomOptions', []);
			if (options != null && Std.isOfType(options, Array))
			{
				var optionsArray:Array<Dynamic> = cast options;
				for (opt in optionsArray)
					allOptions.push(opt);
			}
		}
		
		return allOptions;
	}
	
	/**
	 * Obtener todas las categorías custom de los scripts
	 */
	public static function getCustomCategories():Array<String>
	{
		var allCategories:Array<String> = [];
		
		for (script in stateScripts)
		{
			var categories = script.call('getCustomCategories', []);
			if (categories != null && Std.isOfType(categories, Array))
			{
				var categoriesArray:Array<String> = cast categories;
				for (cat in categoriesArray)
				{
					if (!allCategories.contains(cat))
						allCategories.push(cat);
				}
			}
		}
		
		return allCategories;
	}
	
	/**
	 * Establecer variable en todos los scripts
	 */
	public static function setOnScripts(varName:String, value:Dynamic):Void
	{
		for (script in stateScripts)
			script.set(varName, value);
	}
	
	/**
	 * Limpiar todos los scripts
	 */
	public static function clearStateScripts():Void
	{
		for (script in stateScripts)
			script.destroy();
		
		stateScripts.clear();
		functionOverrides.clear();
	}
	
	/**
	 * Exponer variables y funciones globales al script
	 */
	private static function exposeGlobals(interp:Interp, state:FlxState, script:StateScriptInstance):Void
	{
		#if HSCRIPT_ALLOWED
		// Clases de Flixel
		interp.variables.set('FlxG', FlxG);
		interp.variables.set('FlxSprite', flixel.FlxSprite);
		interp.variables.set('FlxText', flixel.text.FlxText);
		interp.variables.set('FlxSound', flixel.sound.FlxSound);
		interp.variables.set('FlxTween', flixel.tweens.FlxTween);
		interp.variables.set('FlxEase', flixel.tweens.FlxEase);
		interp.variables.set('FlxTimer', flixel.util.FlxTimer);
		interp.variables.set('FunkinSprite', animationdata.FunkinSprite);
		interp.variables.set('FlxAnimate',        flxanimate.FlxAnimate);
		interp.variables.set('FlxSpriteGroup', flixel.group.FlxSpriteGroup);
		interp.variables.set('FlxTrail', flixel.addons.effects.FlxTrail);
		interp.variables.set('Song', funkin.data.Song);
		// FlxColor es un abstract, así que exponemos un objeto con los colores comunes
		interp.variables.set('FlxColor', {
			WHITE: 0xFFFFFFFF,
			BLACK: 0xFF000000,
			RED: 0xFFFF0000,
			GREEN: 0xFF00FF00,
			BLUE: 0xFF0000FF,
			YELLOW: 0xFFFFFF00,
			CYAN: 0xFF00FFFF,
			MAGENTA: 0xFFFF00FF,
			LIME: 0xFF00FF00,
			PINK: 0xFFFFC0CB,
			ORANGE: 0xFFFFA500,
			PURPLE: 0xFF800080,
			BROWN: 0xFFA52A2A,
			GRAY: 0xFF808080,
			TRANSPARENT: 0x00000000,
			// Helper function para crear colores RGB
			fromRGB: function(r:Int, g:Int, b:Int, a:Int = 255):Int {
				return (a << 24) | (r << 16) | (g << 8) | b;
			},
			// Helper para crear colores desde string hex
			fromString: function(hex:String):Int {
				if (hex.startsWith('#')) hex = hex.substr(1);
				if (hex.startsWith('0x')) hex = hex.substr(2);
				return Std.parseInt('0xFF' + hex);
			}
		});
		interp.variables.set('FlxCamera', flixel.FlxCamera);
		interp.variables.set('FlxGroup', flixel.group.FlxGroup);
		
		// State actual
		interp.variables.set('state', state);
		
		// Clases de UI
		interp.variables.set('Alphabet', ui.Alphabet);
		
		// Save data
		interp.variables.set('save', FlxG.save.data);
		
		// Utilidades
		interp.variables.set('Math', Math);
		interp.variables.set('Std', Std);
		interp.variables.set('StringTools', StringTools);
		interp.variables.set('Paths', Paths);
		
		// ShaderManager - Sistema de shaders
		interp.variables.set('ShaderManager', ShaderManager);
		interp.variables.set('shaders', {
			// Obtener shader
			get: function(name:String) {
				return ShaderManager.getShader(name);
			},
			// Aplicar shader a sprite
			apply: function(sprite:flixel.FlxSprite, name:String) {
				return ShaderManager.applyShader(sprite, name);
			},
			// Remover shader de sprite
			remove: function(sprite:flixel.FlxSprite) {
				ShaderManager.removeShader(sprite);
			},
			// Establecer parámetro
			setParam: function(name:String, param:String, value:Dynamic) {
				return ShaderManager.setShaderParam(name, param, value);
			},
			// Listar shaders disponibles
			list: function() {
				return ShaderManager.getAvailableShaders();
			},
			// Recargar shader
			reload: function(name:String) {
				return ShaderManager.reloadShader(name);
			}
		});
		
		// === NUEVAS FUNCIONES PARA CONTROL DE EVENTOS ===
		
		// Función para cancelar el evento actual
		// Retornar true en cualquier callback cancela la ejecución
		interp.variables.set('cancelEvent', function() {
			return true;
		});
		
		// Función para continuar con el evento
		interp.variables.set('continueEvent', function() {
			return false;
		});
		
		// Registrar un override de función
		// Ejemplo: overrideFunction('changeWeek', function(change) { trace('Custom week change!'); })
		interp.variables.set('overrideFunction', function(funcName:String, func:Dynamic) {
			StateScriptHandler.registerOverride(funcName, script, func);
		});
		
		// Remover un override
		interp.variables.set('removeOverride', function(funcName:String) {
			StateScriptHandler.unregisterOverride(funcName);
		});
		
		// Habilitar/deshabilitar override temporalmente
		interp.variables.set('toggleOverride', function(funcName:String, enabled:Bool) {
			StateScriptHandler.toggleOverride(funcName, enabled);
		});
		
		// Verificar si hay override
		interp.variables.set('hasOverride', function(funcName:String):Bool {
			return StateScriptHandler.hasOverride(funcName);
		});
		
		// Establecer prioridad del script
		interp.variables.set('setPriority', function(priority:Int) {
			script.priority = priority;
			trace('[${script.name}] Prioridad establecida a $priority');
		});
		
		// Funciones de debug
		interp.variables.set('trace', function(v:Dynamic) { trace('[StateScript] $v'); });
		interp.variables.set('debugLog', function(v:Dynamic) { trace('[DEBUG] $v'); });
		
		// Helper para crear opciones
		interp.variables.set('createOption', function(name:String, getValue:Void->String, onPress:Void->Bool) {
			return {
				name: name,
				getValue: getValue,
				onPress: onPress
			};
		});
		#end
	}
	
	/**
	 * Obtener nombre del script desde su path
	 */
	private static function getScriptName(path:String):String
	{
		var name = path.split('/').pop();
		if (name.endsWith('.hx'))
			name = name.substr(0, name.length - 3);
		else if (name.endsWith('.hscript'))
			name = name.substr(0, name.length - 8);
		return name;
	}
}

/**
 * Instancia de un script de state individual
 */
class StateScriptInstance
{
	public var name:String;
	public var path:String;
	public var active:Bool = true;
	public var state:FlxState;
	public var priority:Int = 0; // Mayor prioridad = se ejecuta primero
	
	#if HSCRIPT_ALLOWED
	public var interp:Interp;
	public var program:Expr;
	#end
	
	public function new(name:String, path:String, ?priority:Int = 0)
	{
		this.name = name;
		this.path = path;
		this.priority = priority;
	}
	
	/**
	 * Llamar función del script
	 */
	public function call(funcName:String, ?args:Array<Dynamic>):Dynamic
	{
		if (!active) return null;
		
		#if HSCRIPT_ALLOWED
		if (args == null) args = [];
		
		try
		{
			var func = interp.variables.get(funcName);
			if (func != null && Reflect.isFunction(func))
			{
				return Reflect.callMethod(null, func, args);
			}
		}
		catch (e:Exception)
		{
			trace('[StateScript $name] Error en $funcName: ${e.message}');
			trace('Stack: ${e.stack}');
		}
		#end
		
		return null;
	}
	
	/**
	 * Establecer variable en el script
	 */
	public function set(varName:String, value:Dynamic):Void
	{
		#if HSCRIPT_ALLOWED
		if (interp != null)
			interp.variables.set(varName, value);
		#end
	}
	
	/**
	 * Obtener variable del script
	 */
	public function get(varName:String):Dynamic
	{
		#if HSCRIPT_ALLOWED
		if (interp != null)
			return interp.variables.get(varName);
		#end
		return null;
	}
	
	/**
	 * Destruir script
	 */
	public function destroy():Void
	{
		call('onDestroy', []);
		active = false;
		
		#if HSCRIPT_ALLOWED
		if (interp != null)
		{
			interp.variables.clear();
			interp = null;
		}
		program = null;
		#end
	}
}

/**
 * Override de función
 * Permite reemplazar completamente el comportamiento de una función
 */
class FunctionOverride
{
	public var funcName:String;
	public var script:StateScriptInstance;
	public var func:Dynamic;
	public var enabled:Bool = true;
	
	public function new(funcName:String, script:StateScriptInstance, func:Dynamic)
	{
		this.funcName = funcName;
		this.script = script;
		this.func = func;
	}
	
	/**
	 * Llamar la función override
	 */
	public function call(args:Array<Dynamic>):Dynamic
	{
		if (!enabled || !script.active)
			return null;
		
		try
		{
			if (Reflect.isFunction(func))
			{
				return Reflect.callMethod(null, func, args);
			}
		}
		catch (e:Exception)
		{
			trace('[FunctionOverride] Error en $funcName: ${e.message}');
		}
		
		return null;
	}
}
