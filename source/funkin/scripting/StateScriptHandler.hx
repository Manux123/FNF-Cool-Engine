package funkin.scripting;

import flixel.FlxG;
import flixel.FlxState;
import haxe.Exception;
import sys.FileSystem;
import sys.io.File;

#if HSCRIPT_ALLOWED
import hscript.Interp;
#end

using StringTools;

/**
 * Sistema de scripts HScript para FlxStates (menús, opciones, freeplay…).
 *
 * Diferencias respecto a ScriptHandler:
 *   • Los scripts tienen `priority`: el de mayor número ejecuta primero.
 *   • Soporta `overrideFunction()` para reemplazar una función completamente.
 *   • `callOnScripts()` devuelve `Bool` — si algún script devuelve `true`, cancela.
 *
 * ─── Uso básico ──────────────────────────────────────────────────────────────
 *   StateScriptHandler.init();
 *   StateScriptHandler.loadStateScripts('MainMenuState', this);
 *   final cancelled = StateScriptHandler.callOnScripts('onBack', []);
 *   StateScriptHandler.clearStateScripts();
 *
 * ─── Estructura de carpetas esperada ─────────────────────────────────────────
 *   assets/states/{statename}/  ← archivos .hx / .hscript
 *
 * ─── API expuesta a los scripts ──────────────────────────────────────────────
 *   (todo lo de ScriptAPI, más:)
 *   state                → FlxState actual
 *   cancelEvent()        → devuelve true (para cancelar desde el script)
 *   continueEvent()      → devuelve false
 *   setPriority(n)       → cambia la prioridad de este script
 *   overrideFunction(name, fn)  → reemplaza una función completamente
 *   removeOverride(name)
 *   toggleOverride(name, enabled)
 *   hasOverride(name)
 *   createOption(name, getValue, onPress)  → helper para opciones custom
 */
class StateScriptHandler
{
	public static var scripts         : Map<String, HScriptInstance> = [];
	public static var overrides       : Map<String, FunctionOverride> = [];

	/** Lista ordenada por prioridad — se recalcula al añadir/quitar scripts. */
	static var _sortedCache : Array<HScriptInstance> = [];
	static var _cacheDirty  : Bool = true;

	// ─── Init ─────────────────────────────────────────────────────────────────

	public static function init():Void
		trace('[StateScriptHandler] Listo.');

	// ─── Carga ────────────────────────────────────────────────────────────────

	/**
	 * Limpia y carga todos los scripts para `stateName`.
	 * Busca en `assets/states/{statename}/`.
	 */
	public static function loadStateScripts(stateName:String, state:FlxState):Array<HScriptInstance>
	{
		clearStateScripts();
		final loaded = loadScriptsFromFolder('assets/states/${stateName.toLowerCase()}', state);
		trace('[StateScriptHandler] ${loaded.length} scripts cargados para $stateName.');
		return loaded;
	}

	public static function loadScript(scriptPath:String, state:FlxState, priority:Int = 0):HScriptInstance
	{
		#if HSCRIPT_ALLOWED
		if (!FileSystem.exists(scriptPath))
		{
			trace('[StateScriptHandler] No encontrado: $scriptPath');
			return null;
		}

		final name    = ScriptHandler.extractName(scriptPath);
		final content = File.getContent(scriptPath);
		final script  = new HScriptInstance(name, scriptPath, priority);

		try
		{
			script.program = ScriptHandler.parser.parseString(content, scriptPath);
			script.interp  = new Interp();

			ScriptAPI.expose(script.interp);
			exposeStateAPI(script.interp, state, script);

			script.interp.execute(script.program);
			script.call('onCreate');

			scripts.set(name, script);
			_cacheDirty = true;

			trace('[StateScriptHandler] Cargado: $name (prioridad $priority)');
			return script;
		}
		catch (e:Exception)
		{
			trace('[StateScriptHandler] Error en "$name": ${e.message}');
			return null;
		}
		#else
		trace('[StateScriptHandler] HSCRIPT_ALLOWED no definido en Project.xml.');
		return null;
		#end
	}

	public static function loadScriptsFromFolder(folderPath:String, state:FlxState):Array<HScriptInstance>
	{
		final loaded:Array<HScriptInstance> = [];

		if (!FileSystem.exists(folderPath) || !FileSystem.isDirectory(folderPath))
		{
			trace('[StateScriptHandler] Carpeta no encontrada: $folderPath');
			return loaded;
		}

		for (file in FileSystem.readDirectory(folderPath))
		{
			if (!file.endsWith('.hx') && !file.endsWith('.hscript')) continue;
			final s = loadScript('$folderPath/$file', state);
			if (s != null) loaded.push(s);
		}

		return loaded;
	}

	// ─── Llamadas ─────────────────────────────────────────────────────────────

	/**
	 * Llama `funcName` en todos los scripts (orden: mayor prioridad primero).
	 * Si algún script devuelve `true`, para y devuelve `true` (evento cancelado).
	 */
	public static function callOnScripts(funcName:String, args:Array<Dynamic> = null):Bool
	{
		if (args == null) args = [];

		// Si hay un override activo, úsalo y cancela la ejecución original.
		final ovr = overrides.get(funcName);
		if (ovr != null && ovr.enabled)
		{
			ovr.call(args);
			return true;
		}

		for (script in getSorted())
		{
			if (script.callBool(funcName, args))
			{
				trace('[StateScriptHandler] "$funcName" cancelado por ${script.name}');
				return true;
			}
		}

		return false;
	}

	/** Igual que `callOnScripts` pero devuelve el primer resultado no-null. */
	public static function callOnScriptsReturn(funcName:String, args:Array<Dynamic> = null, defaultValue:Dynamic = null):Dynamic
	{
		if (args == null) args = [];

		final ovr = overrides.get(funcName);
		if (ovr != null && ovr.enabled)
			return ovr.call(args);

		for (script in getSorted())
		{
			final r = script.call(funcName, args);
			if (r != null) return r;
		}

		return defaultValue;
	}

	// ─── Variables ────────────────────────────────────────────────────────────

	public static function setOnScripts(varName:String, value:Dynamic):Void
	{
		for (s in scripts) s.set(varName, value);
	}

	// ─── Overrides ────────────────────────────────────────────────────────────

	public static function registerOverride(funcName:String, script:HScriptInstance, func:Dynamic):Void
	{
		overrides.set(funcName, new FunctionOverride(funcName, script, func));
		trace('[StateScriptHandler] Override "$funcName" registrado por ${script.name}');
	}

	public static function unregisterOverride(funcName:String):Void
	{
		if (overrides.remove(funcName))
			trace('[StateScriptHandler] Override "$funcName" removido.');
	}

	public static function toggleOverride(funcName:String, enabled:Bool):Void
	{
		final ovr = overrides.get(funcName);
		if (ovr != null) ovr.enabled = enabled;
	}

	public static function hasOverride(funcName:String):Bool
	{
		final ovr = overrides.get(funcName);
		return ovr != null && ovr.enabled;
	}

	// ─── Colecciones de datos ─────────────────────────────────────────────────

	/** Reúne los arrays devueltos por `funcName` de todos los scripts. */
	public static function collectArrays(funcName:String):Array<Dynamic>
	{
		final all:Array<Dynamic> = [];
		for (script in scripts)
		{
			final result = script.call(funcName);
			if (result != null && Std.isOfType(result, Array))
			{
				final arr:Array<Dynamic> = cast result;
				for (item in arr) all.push(item);
			}
		}
		return all;
	}

	/** Igual que `collectArrays` pero elimina duplicados (para strings). */
	public static function collectUniqueStrings(funcName:String):Array<String>
	{
		final all:Array<String> = [];
		for (script in scripts)
		{
			final result = script.call(funcName);
			if (result == null || !Std.isOfType(result, Array)) continue;
			final arr:Array<String> = cast result;
			for (s in arr)
				if (!all.contains(s)) all.push(s);
		}
		return all;
	}

	// ─── Compatibilidad con OptionsMenuState ─────────────────────────────────

	/** Reúne opciones custom de todos los scripts (compatibilidad con OptionsMenuState). */
	public static function getCustomOptions():Array<Dynamic>
		return collectArrays('getCustomOptions');

	/** Reúne categorías custom únicas de todos los scripts (compatibilidad con OptionsMenuState). */
	public static function getCustomCategories():Array<String>
		return collectUniqueStrings('getCustomCategories');

	// ─── Limpiar ──────────────────────────────────────────────────────────────

	public static function clearStateScripts():Void
	{
		for (s in scripts) s.destroy();
		scripts.clear();
		overrides.clear();
		_sortedCache = [];
		_cacheDirty  = false;
	}

	// ─── Helpers internos ─────────────────────────────────────────────────────

	/** Devuelve los scripts ordenados por prioridad descendente. Usa caché. */
	static function getSorted():Array<HScriptInstance>
	{
		if (_cacheDirty)
		{
			_sortedCache = [for (s in scripts) s];
			_sortedCache.sort((a, b) -> b.priority - a.priority);
			_cacheDirty = false;
		}
		return _sortedCache;
	}

	#if HSCRIPT_ALLOWED
	/** API adicional específica para state scripts (además de ScriptAPI). */
	static function exposeStateAPI(interp:Interp, state:FlxState, script:HScriptInstance):Void
	{
		interp.variables.set('state', state);
		interp.variables.set('save',  FlxG.save.data);

		// Control de cancelación en callbacks
		interp.variables.set('cancelEvent',   () -> true);
		interp.variables.set('continueEvent', () -> false);

		// Prioridad dinámica
		interp.variables.set('setPriority', (p:Int) -> {
			script.priority = p;
			_cacheDirty = true;
			trace('[${script.name}] Prioridad → $p');
		});

		// Sistema de overrides
		interp.variables.set('overrideFunction', (name:String, fn:Dynamic) ->
			registerOverride(name, script, fn));
		interp.variables.set('removeOverride',   (name:String) ->
			unregisterOverride(name));
		interp.variables.set('toggleOverride',   (name:String, en:Bool) ->
			toggleOverride(name, en));
		interp.variables.set('hasOverride',      (name:String) ->
			hasOverride(name));

		// Helper para crear opciones del menú de opciones
		interp.variables.set('createOption',
			(name:String, getValue:Void->String, onPress:Void->Bool) -> ({
				name:     name,
				getValue: getValue,
				onPress:  onPress
			})
		);
	}
	#end
}

// ─────────────────────────────────────────────────────────────────────────────

/** Override de función: reemplaza completamente el comportamiento de un callback. */
class FunctionOverride
{
	public var funcName : String;
	public var script   : HScriptInstance;
	public var func     : Dynamic;
	public var enabled  : Bool = true;

	public function new(funcName:String, script:HScriptInstance, func:Dynamic)
	{
		this.funcName = funcName;
		this.script   = script;
		this.func     = func;
	}

	public function call(args:Array<Dynamic>):Dynamic
	{
		if (!enabled || !script.active) return null;

		try
		{
			if (Reflect.isFunction(func))
				return Reflect.callMethod(null, func, args);
		}
		catch (e:Exception)
		{
			trace('[FunctionOverride] Error en "$funcName": ${e.message}');
		}

		return null;
	}
}
