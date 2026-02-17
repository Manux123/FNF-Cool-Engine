package funkin.scripting;

import flixel.FlxG;
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
 * Sistema de scripts dinámicos - Similar a Psych Engine
 * ACTUALIZADO: Ahora soporta scripts de Stage
 */
class ScriptHandler
{
	public static var globalScripts:Map<String, ScriptInstance> = new Map();
	public static var songScripts:Map<String, ScriptInstance> = new Map();
	public static var stageScripts:Map<String, ScriptInstance> = new Map(); // NUEVO
	
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

		// Cargar scripts globales que siempre están activos
		loadGlobalScripts();

		trace('[ScriptHandler] Sistema de scripts inicializado');
	}

	/**
	 * Carga scripts globales desde:
	 *   assets/scripts/global/   → activos en todo el juego
	 *   assets/scripts/events/   → registran handlers de eventos custom
	 */
	public static function loadGlobalScripts():Void
	{
		loadScriptsFromFolder('assets/scripts/global', 'global');
		loadScriptsFromFolder('assets/scripts/events', 'global');
		trace('[ScriptHandler] Scripts globales cargados');
	}
	
	/**
	 * Cargar un script desde archivo
	 */
	public static function loadScript(scriptPath:String, ?scriptType:String = "song"):ScriptInstance
	{
		#if HSCRIPT_ALLOWED
		if (!FileSystem.exists(scriptPath))
		{
			trace('[ScriptHandler] Script no encontrado: $scriptPath');
			return null;
		}
		
		var scriptName = getScriptName(scriptPath);
		var content = File.getContent(scriptPath);
		
		var script = new ScriptInstance(scriptName, scriptPath);
		
		try
		{
			var program = parser.parseString(content, scriptPath);
			script.program = program;
			script.interp = new Interp();
			
			// Exponer variables globales al script
			exposeGlobals(script.interp);
			
			// Ejecutar el script
			script.interp.execute(program);
			
			// Llamar onCreate si existe
			script.call('onCreate', []);
			script.call('postCreate', []);
			
			// Guardar script según el tipo
			switch (scriptType.toLowerCase())
			{
				case "global":
					globalScripts.set(scriptName, script);
				case "stage":
					stageScripts.set(scriptName, script);
				default: // "song"
					songScripts.set(scriptName, script);
			}
			
			trace('[ScriptHandler] Script cargado [$scriptType]: $scriptName');
			return script;
		}
		catch (e:Exception)
		{
			trace('[ScriptHandler] Error al cargar script $scriptName: ${e.message}');
			return null;
		}
		#else
		trace('[ScriptHandler] HScript no está habilitado. Define HSCRIPT_ALLOWED en Project.xml');
		return null;
		#end
	}
	
	/**
	 * Cargar todos los scripts de una carpeta
	 */
	public static function loadScriptsFromFolder(folderPath:String, ?scriptType:String = "song"):Array<ScriptInstance>
	{
		var scripts:Array<ScriptInstance> = [];
		
		if (!FileSystem.exists(folderPath) || !FileSystem.isDirectory(folderPath))
			return scripts;
		
		for (file in FileSystem.readDirectory(folderPath))
		{
			if (file.endsWith('.hx') || file.endsWith('.hscript'))
			{
				var fullPath = '$folderPath/$file';
				var script = loadScript(fullPath, scriptType);
				if (script != null)
					scripts.push(script);
			}
		}
		
		return scripts;
	}
	
	/**
	 * Cargar scripts de una canción específica.
	 * Carpetas buscadas (en orden):
	 *   assets/songs/{song}/scripts/  → lógica general
	 *   assets/songs/{song}/events/   → handlers de eventos custom
	 */
	public static function loadSongScripts(songName:String):Void
	{
		clearSongScripts();

		var base = 'assets/songs/${songName.toLowerCase()}';
		loadScriptsFromFolder('$base/scripts', 'song');
		loadScriptsFromFolder('$base/events',  'song');

		trace('[ScriptHandler] Scripts de "${songName}" cargados');
	}
	
	/**
	 * NUEVO: Cargar scripts de un stage específico
	 */
	public static function loadStageScripts(stageName:String):Void
	{
		clearStageScripts();
		
		// Buscar en assets/stages/[stageName]/scripts/
		var scriptsPath = 'assets/stages/${stageName.toLowerCase()}/scripts';
		loadScriptsFromFolder(scriptsPath, "stage");
		
		trace('[ScriptHandler] Scripts de stage "${stageName}" cargados');
	}
	
	/**
	 * NUEVO: Cargar scripts desde array de paths (para Stage.hx)
	 */
	public static function loadScriptsFromArray(scriptPaths:Array<String>, ?scriptType:String = "stage"):Array<ScriptInstance>
	{
		var scripts:Array<ScriptInstance> = [];
		
		for (path in scriptPaths)
		{
			var script = loadScript(path, scriptType);
			if (script != null)
				scripts.push(script);
		}
		
		return scripts;
	}
	
	/**
	 * Llamar función en todos los scripts
	 */
	public static function callOnScripts(funcName:String, ?args:Array<Dynamic>):Void
	{
		if (args == null) args = [];
		
		// Llamar en scripts globales
		for (script in globalScripts)
			script.call(funcName, args);
		
		// Llamar en scripts de stage
		for (script in stageScripts)
			script.call(funcName, args);
		
		// Llamar en scripts de canción
		for (script in songScripts)
			script.call(funcName, args);
	}
	
	/**
	 * NUEVO: Llamar solo en scripts de stage
	 */
	public static function callOnStageScripts(funcName:String, ?args:Array<Dynamic>):Void
	{
		if (args == null) args = [];
		
		for (script in stageScripts)
			script.call(funcName, args);
	}
	
	/**
	 * Llamar función y obtener resultado (el primer script que retorne algo)
	 */
	public static function callOnScriptsReturn(funcName:String, ?args:Array<Dynamic>, ?defaultValue:Dynamic = null):Dynamic
	{
		if (args == null) args = [];
		
		// Intentar en scripts de canción primero
		for (script in songScripts)
		{
			var result = script.call(funcName, args);
			if (result != null)
				return result;
		}
		
		// Luego en scripts de stage
		for (script in stageScripts)
		{
			var result = script.call(funcName, args);
			if (result != null)
				return result;
		}
		
		// Finalmente en scripts globales
		for (script in globalScripts)
		{
			var result = script.call(funcName, args);
			if (result != null)
				return result;
		}
		
		return defaultValue;
	}
	
	/**
	 * Establecer variable en todos los scripts
	 */
	public static function setOnScripts(varName:String, value:Dynamic):Void
	{
		for (script in globalScripts)
			script.set(varName, value);
		
		for (script in stageScripts)
			script.set(varName, value);
		
		for (script in songScripts)
			script.set(varName, value);
	}
	
	/**
	 * NUEVO: Establecer variable solo en scripts de stage
	 */
	public static function setOnStageScripts(varName:String, value:Dynamic):Void
	{
		for (script in stageScripts)
			script.set(varName, value);
	}
	
	/**
	 * Limpiar scripts de canción
	 */
	public static function clearSongScripts():Void
	{
		for (script in songScripts)
			script.destroy();
		
		songScripts.clear();
	}
	
	/**
	 * NUEVO: Limpiar scripts de stage
	 */
	public static function clearStageScripts():Void
	{
		for (script in stageScripts)
			script.destroy();
		
		stageScripts.clear();
	}
	
	/**
	 * Limpiar todos los scripts
	 */
	public static function clearAllScripts():Void
	{
		clearSongScripts();
		clearStageScripts();
		
		for (script in globalScripts)
			script.destroy();
		
		globalScripts.clear();
	}
	
	/**
	 * Exponer variables y funciones globales al script
	 */
	private static function exposeGlobals(interp:Interp):Void
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
		interp.variables.set('FlxColor', {
			BLACK: 0xFF000000,
			WHITE: 0xFFFFFFFF,
			RED: 0xFFFF0000,
			fromRGB: flixel.util.FlxColor.fromRGB
		});
		interp.variables.set('FlxCamera', flixel.FlxCamera);
		
		// PlayState y EventManager
		interp.variables.set('PlayState', funkin.gameplay.PlayState);
		interp.variables.set('EventManager', funkin.scripting.EventManager);
		interp.variables.set('game', funkin.gameplay.PlayState.instance);

		// Conductor (para BPM Change y tiempo de canción)
		interp.variables.set('Conductor', funkin.data.Conductor);

		// API de eventos — disponible desde el momento en que cualquier script carga,
		// incluyendo los scripts globales de assets/scripts/events/
		interp.variables.set('registerEvent', function(name:String, handler:Dynamic)
		{
			funkin.scripting.EventManager.registerCustomEvent(name,
				function(evts:Array<funkin.scripting.EventManager.EventData>):Bool
				{
					var result = handler(evts[0].value1, evts[0].value2, evts[0].time);
					return result == true;
				});
			trace('[Script] Evento registrado: "$name"');
		});

		interp.variables.set('fireEvent',
			function(name:String, ?v1:String = '', ?v2:String = '')
				funkin.scripting.EventManager.fireEvent(name, v1, v2));
		
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
		
		// Funciones de debug
		interp.variables.set('trace', function(v:Dynamic) { trace('[Script] $v'); });
		interp.variables.set('debugLog', function(v:Dynamic) { trace('[DEBUG] $v'); });
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
 * Instancia de un script individual
 */
class ScriptInstance
{
	public var name:String;
	public var path:String;
	public var active:Bool = true;
	
	#if HSCRIPT_ALLOWED
	public var interp:Interp;
	public var program:Expr;
	#end
	
	public function new(name:String, path:String)
	{
		this.name = name;
		this.path = path;
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
			trace('[Script $name] Error en $funcName: ${e.message}');
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