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
 * StateScriptHandler v2 — sistema de scripts para FlxStates y menus.
 *
 * Novedades respecto a v1:
 *   ┌─────────────────────────────────────────────────────────────────────┐
 *   │ ELEMENTOS                                                           │
 *   │  exposeElement(name, obj)  → expone cualquier objeto al script      │
 *   │  getElement(name)          → lee desde fuera                        │
 *   │  exposeAll(map)            → bulk                                   │
 *   ├─────────────────────────────────────────────────────────────────────┤
 *   │ HOOKS CUSTOM                                                        │
 *   │  registerHook(name, fn)    → engancha lógica Haxe nativa           │
 *   │  callHook(name, args)      → llama hook + scripts                  │
 *   │  fireRaw(name, args)       → solo scripts, sin hooks Haxe          │
 *   ├─────────────────────────────────────────────────────────────────────┤
 *   │ DATOS COMPARTIDOS entre scripts del mismo state                    │
 *   │  setShared(key, value)                                              │
 *   │  getShared(key)                                                     │
 *   ├─────────────────────────────────────────────────────────────────────┤
 *   │ BROADCAST (entre TODOS los scripts del engine)                     │
 *   │  broadcast(event, args)    → llama a todos (state + gameplay)      │
 *   ├─────────────────────────────────────────────────────────────────────┤
 *   │ OTROS                                                               │
 *   │  hotReloadAll()            → recarga todos los scripts del state   │
 *   │  getByTag(tag)             → obtiene scripts por tag               │
 *   │  callOnBool(fn, args)      → versión cancelable                    │
 *   └─────────────────────────────────────────────────────────────────────┘
 *
 * ─── Uso básico ──────────────────────────────────────────────────────────────
 *   StateScriptHandler.init();
 *   StateScriptHandler.loadStateScripts('MainMenuState', this);
 *   StateScriptHandler.exposeElement('menuItems', menuItemGroup);
 *   var cancelled = StateScriptHandler.callOnScripts('onBack', []);
 *   StateScriptHandler.clearStateScripts();
 *
 * ─── Estructura de carpetas ──────────────────────────────────────────────────
 *   assets/states/{statename}/       → scripts .hx / .hscript
 *   mods/{mod}/states/{statename}/   → sobrescribe / complementa
 */
class StateScriptHandler
{
	public static var scripts   : Map<String, HScriptInstance> = [];
	public static var overrides : Map<String, FunctionOverride> = [];

	/** Datos compartidos entre scripts del mismo state. */
	public static var sharedData : Map<String, Dynamic> = [];

	/** Hooks Haxe nativos registrados por el state. */
	static var _hooks    : Map<String, Array<Dynamic->Void>> = [];

	static var _sortedCache : Array<HScriptInstance> = [];
	static var _cacheDirty  : Bool = true;

	// ─── Init ─────────────────────────────────────────────────────────────────

	public static function init():Void
	{
		sharedData.clear();
		_hooks.clear();
		trace('[StateScriptHandler] Listo.');
	}

	// ─── Carga ────────────────────────────────────────────────────────────────

	public static function loadStateScripts(stateName:String, state:FlxState,
		?extraVars:Map<String, Dynamic>):Array<HScriptInstance>
	{
		clearStateScripts();

		var loaded:Array<HScriptInstance> = [];

		#if sys
		if (mods.ModManager.isActive())
		{
			final modRoot = mods.ModManager.modRoot();
			final sn = stateName.toLowerCase();
			for (folder in ['$modRoot/states/$sn', '$modRoot/assets/states/$sn'])
				for (s in _loadFolder(folder, state, extraVars))
					loaded.push(s);
		}
		#end

		for (s in _loadFolder('assets/states/${stateName.toLowerCase()}', state, extraVars))
			loaded.push(s);

		trace('[StateScriptHandler] ${loaded.length} scripts para $stateName.');
		return loaded;
	}

	public static function loadScript(scriptPath:String, state:FlxState,
		priority:Int = 0, ?extraVars:Map<String, Dynamic>):HScriptInstance
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

		// Asignar callback de error global
		script.onError = (sn, ctx, err) ->
			trace('[STATE SCRIPT ERROR] $sn::$ctx → ${Std.string(err)}');

		try
		{
			@:privateAccess script._source = content;
			script.program = ScriptHandler.parser.parseString(content, scriptPath);
			script.interp  = new Interp();

			ScriptAPI.expose(script.interp);
			_exposeStateAPI(script.interp, state, script);

			// Variables extra opcionales
			if (extraVars != null)
				script.setAll(extraVars);

			script.interp.execute(script.program);
			script.call('onCreate');

			scripts.set(name, script);
			_cacheDirty = true;

			trace('[StateScriptHandler] Cargado: $name (prio $priority)');
			return script;
		}
		catch (e:Exception)
		{
			trace('[StateScriptHandler] Error en "$name": ${e.message}');
			return null;
		}
		#else
		return null;
		#end
	}

	static function _loadFolder(folderPath:String, state:FlxState,
		?extraVars:Map<String, Dynamic>):Array<HScriptInstance>
	{
		final loaded:Array<HScriptInstance> = [];

		if (!FileSystem.exists(folderPath) || !FileSystem.isDirectory(folderPath))
			return loaded;

		for (file in FileSystem.readDirectory(folderPath))
		{
			if (!file.endsWith('.hx') && !file.endsWith('.hscript')) continue;
			final s = loadScript('$folderPath/$file', state, 0, extraVars);
			if (s != null) loaded.push(s);
		}

		return loaded;
	}

	// ─── Elementos expuestos ──────────────────────────────────────────────────

	/**
	 * Expone un elemento del state a TODOS los scripts activos.
	 *
	 *   StateScriptHandler.exposeElement('rankSprite', rankSprite);
	 *
	 * En el script:
	 *   rankSprite.alpha = 0.5;
	 */
	public static function exposeElement(name:String, value:Dynamic):Void
		setOnScripts(name, value);

	/** Expone varios elementos de una vez. */
	public static function exposeAll(map:Map<String, Dynamic>):Void
	{
		for (k => v in map)
			setOnScripts(k, v);
	}

	// ─── Hooks nativos ────────────────────────────────────────────────────────

	/**
	 * Registra un hook Haxe para `hookName`.
	 * Cuando `callHook(hookName, args)` se llame, primero ejecuta el callback
	 * nativo y luego propaga a los scripts.
	 *
	 *   StateScriptHandler.registerHook('onExit', function(args) {
	 *       // lógica Haxe nativa antes de que los scripts lo vean
	 *   });
	 */
	public static function registerHook(hookName:String, callback:Dynamic->Void):Void
	{
		if (!_hooks.exists(hookName))
			_hooks.set(hookName, []);
		_hooks.get(hookName).push(callback);
		trace('[StateScriptHandler] Hook "$hookName" registrado.');
	}

	/** Elimina todos los hooks nativos para `hookName`. */
	public static function removeHook(hookName:String):Void
	{
		_hooks.remove(hookName);
	}

	/**
	 * Llama hooks nativos + scripts.
	 * @return true si algún script canceló el evento.
	 */
	public static function callHook(hookName:String, args:Array<Dynamic> = null):Bool
	{
		if (args == null) args = [];

		// 1) Hooks Haxe nativos
		final hooks = _hooks.get(hookName);
		if (hooks != null)
			for (h in hooks)
				try { h(args); } catch (e:Dynamic) { trace('[Hook Error] $hookName: $e'); }

		// 2) Scripts
		return callOnScripts(hookName, args);
	}

	/**
	 * Llama solo en scripts (sin hooks nativos), y NO cancela.
	 * Para eventos de "notificación pura".
	 */
	public static function fireRaw(hookName:String, args:Array<Dynamic> = null):Void
	{
		if (args == null) args = [];
		for (script in getSorted())
			script.call(hookName, args);
	}

	// ─── Datos compartidos ────────────────────────────────────────────────────

	public static function setShared(key:String, value:Dynamic):Void
		sharedData.set(key, value);

	public static function getShared(key:String, ?defaultVal:Dynamic):Dynamic
	{
		if (sharedData.exists(key)) return sharedData.get(key);
		return defaultVal;
	}

	public static function deleteShared(key:String):Void
		sharedData.remove(key);

	// ─── Broadcast global ─────────────────────────────────────────────────────

	/**
	 * Lanza un evento a TODOS los sistemas de scripts (state + gameplay).
	 * Útil para comunicación inter-sistema (ej. un menú le dice al gameplay algo).
	 */
	public static function broadcast(eventName:String, args:Array<Dynamic> = null):Void
	{
		if (args == null) args = [];
		callOnScripts(eventName, args);
		ScriptHandler.callOnScripts(eventName, args);
	}

	// ─── Hot-Reload ───────────────────────────────────────────────────────────

	/** Recarga todos los scripts del state sin perder sus variables. */
	public static function hotReloadAll():Void
	{
		for (s in scripts)
			s.hotReload();
	}

	/** Recarga un script concreto por nombre. */
	public static function hotReload(scriptName:String):Bool
	{
		final s = scripts.get(scriptName);
		return s != null && s.hotReload();
	}

	// ─── Llamadas ─────────────────────────────────────────────────────────────

	/**
	 * Llama `funcName` en orden de prioridad.
	 * Si algún script devuelve `true` → cancela (devuelve true).
	 */
	public static function callOnScripts(funcName:String, args:Array<Dynamic> = null):Bool
	{
		if (args == null) args = [];

		final ovr = overrides.get(funcName);
		if (ovr != null && ovr.enabled)
		{
			ovr.call(args);
			return true;
		}

		for (script in getSorted())
			if (script.callBool(funcName, args))
			{
				trace('[StateScriptHandler] "$funcName" cancelado por ${script.name}');
				return true;
			}

		return false;
	}

	/** Devuelve el primer resultado no-null. */
	public static function callOnScriptsReturn(funcName:String, args:Array<Dynamic> = null,
		defaultValue:Dynamic = null):Dynamic
	{
		if (args == null) args = [];

		final ovr = overrides.get(funcName);
		if (ovr != null && ovr.enabled) return ovr.call(args);

		for (script in getSorted())
		{
			final r = script.call(funcName, args);
			if (r != null) return r;
		}

		return defaultValue;
	}

	/** Llama en todos SIN cancelación (siempre continúa). */
	public static function callOnAll(funcName:String, args:Array<Dynamic> = null):Void
	{
		if (args == null) args = [];
		for (s in getSorted()) s.call(funcName, args);
	}

	// ─── Variables ────────────────────────────────────────────────────────────

	public static function setOnScripts(varName:String, value:Dynamic):Void
		for (s in scripts) s.set(varName, value);

	public static function getFromScripts(varName:String):Dynamic
	{
		for (s in getSorted())
			if (s.exists(varName)) return s.get(varName);
		return null;
	}

	// ─── Por tag ──────────────────────────────────────────────────────────────

	/** Obtiene un script por su nombre. */
	public static function getByName(name:String):HScriptInstance
		return scripts.get(name);

	/** Obtiene todos los scripts con un tag dado. */
	public static function getByTag(tag:String):Array<HScriptInstance>
		return [for (s in scripts) if (s.tag == tag) s];

	// ─── Overrides ────────────────────────────────────────────────────────────

	public static function registerOverride(funcName:String, script:HScriptInstance, func:Dynamic):Void
	{
		overrides.set(funcName, new FunctionOverride(funcName, script, func));
		trace('[StateScriptHandler] Override "$funcName" por ${script.name}');
	}

	public static function unregisterOverride(funcName:String):Void
		overrides.remove(funcName);

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

	// ─── Colecciones ──────────────────────────────────────────────────────────

	public static function collectArrays(funcName:String):Array<Dynamic>
	{
		final all:Array<Dynamic> = [];
		for (s in scripts)
		{
			final r = s.call(funcName);
			if (r != null && Std.isOfType(r, Array))
				for (item in (cast r:Array<Dynamic>)) all.push(item);
		}
		return all;
	}

	public static function collectUniqueStrings(funcName:String):Array<String>
	{
		final all:Array<String> = [];
		for (s in scripts)
		{
			final r = s.call(funcName);
			if (r == null || !Std.isOfType(r, Array)) continue;
			for (item in (cast r:Array<String>))
				if (!all.contains(item)) all.push(item);
		}
		return all;
	}

	// ─── Compatibilidad OptionsMenuState ─────────────────────────────────────

	public static function getCustomOptions():Array<Dynamic>     return collectArrays('getCustomOptions');
	public static function getCustomCategories():Array<String>   return collectUniqueStrings('getCustomCategories');

	// ─── Limpiar ──────────────────────────────────────────────────────────────

	public static function clearStateScripts():Void
	{
		for (s in scripts) s.destroy();
		scripts.clear();
		overrides.clear();
		sharedData.clear();
		_hooks.clear();
		_sortedCache = [];
		_cacheDirty  = false;
	}

	// ─── Helpers internos ─────────────────────────────────────────────────────

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
	static function _exposeStateAPI(interp:Interp, state:FlxState, script:HScriptInstance):Void
	{
		// Referencia al state
		interp.variables.set('state',   state);
		interp.variables.set('save',    FlxG.save.data);

		// Control de cancelación
		interp.variables.set('cancelEvent',   () -> true);
		interp.variables.set('continueEvent', () -> false);

		// Prioridad dinámica
		interp.variables.set('setPriority', (p:Int) -> {
			script.priority = p;
			_cacheDirty = true;
		});

		// Tag del script
		interp.variables.set('setTag', (t:String) -> { script.tag = t; });
		interp.variables.set('getTag', () -> script.tag);

		// Overrides de funciones
		interp.variables.set('overrideFunction', (name:String, fn:Dynamic) ->
			registerOverride(name, script, fn));
		interp.variables.set('removeOverride',   (name:String) -> unregisterOverride(name));
		interp.variables.set('toggleOverride',   (name:String, en:Bool) -> toggleOverride(name, en));
		interp.variables.set('hasOverride',       (name:String) -> hasOverride(name));

		// Datos compartidos
		interp.variables.set('setShared',    (k:String, v:Dynamic)           -> setShared(k, v));
		interp.variables.set('getShared',    (k:String, ?def:Dynamic)        -> getShared(k, def));
		interp.variables.set('deleteShared', (k:String)                      -> deleteShared(k));

		// Hooks nativos del state (los scripts pueden "escucharlos")
		interp.variables.set('registerHook', (name:String, fn:Dynamic->Void) ->
			registerHook(name, fn));

		// Broadcast
		interp.variables.set('broadcast', (ev:String, ?args:Array<Dynamic>) ->
			broadcast(ev, args ?? []));

		// Hot-reload propio
		interp.variables.set('hotReload', () -> script.hotReload());

		// Require — importa otro script
		interp.variables.set('require', (path:String) -> script.require(path));

		// Acceso a otros scripts del mismo state
		interp.variables.set('getScript',    (name:String)  -> getByName(name));
		interp.variables.set('getScriptTag', (tag:String)   -> getByTag(tag));

		// Helper crear opciones de menú
		interp.variables.set('createOption',
			(name:String, getValue:Void->String, onPress:Void->Bool) -> ({
				name:     name,
				getValue: getValue,
				onPress:  onPress
			})
		);

		// Builder de elementos UI (acceso a ScriptBridge)
		interp.variables.set('ui', ScriptBridge.buildUIHelper(state));

		// Referencia al propio script
		interp.variables.set('self', script);
	}
	#end
}

// ─────────────────────────────────────────────────────────────────────────────

class FunctionOverride
{
	public var funcName : String;
	public var script   : HScriptInstance;
	public var func     : Dynamic;
	public var enabled  : Bool = true;

	public function new(funcName, script, func)
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
