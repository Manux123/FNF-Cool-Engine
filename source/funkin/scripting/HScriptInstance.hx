package funkin.scripting;

import haxe.Exception;
#if HSCRIPT_ALLOWED
import hscript.Interp;
import hscript.Expr;
#end

/**
 * Una instancia de script HScript individual.
 * 
 * Compartida por ScriptHandler y StateScriptHandler para evitar duplicación.
 * Gestiona su propio intérprete, variables, lifecycle y manejo de errores.
 */
class HScriptInstance
{
	public var name:String;
	public var path:String;
	public var active:Bool = true;
	public var priority:Int = 0; // Mayor número = ejecuta primero (usado por StateScriptHandler)

	#if HSCRIPT_ALLOWED
	public var interp:Interp;
	public var program:Expr;
	#end

	public function new(name:String, path:String, priority:Int = 0)
	{
		this.name = name;
		this.path = path;
		this.priority = priority;
	}

	// ─── Llamadas ─────────────────────────────────────────────────────────────

	/**
	 * Llama a una función del script y devuelve su resultado.
	 * Devuelve `null` si la función no existe o el script no está activo.
	 */
	public function call(funcName:String, args:Array<Dynamic> = null):Dynamic
	{
		if (!active)
			return null;

		#if HSCRIPT_ALLOWED
		if (interp == null)
			return null;

		if (args == null)
			args = [];

		try
		{
			final func = interp.variables.get(funcName);
			if (func != null && Reflect.isFunction(func))
				return Reflect.callMethod(null, func, args);
		}
		catch (e:Dynamic)
		{
			trace('[$name] Error in "$funcName": ${e.message}');
		}
		#end

		return null;
	}

	/**
	 * Llama a una función que puede devolver `Bool`.
	 * Conveniente para callbacks cancelables (return true = cancelar).
	 */
	public inline function callBool(funcName:String, args:Array<Dynamic> = null):Bool
		return call(funcName, args) == true;

	// ─── Variables ────────────────────────────────────────────────────────────

	/** Establece una variable en el scope del script. */
	public function set(varName:String, value:Dynamic):Void
	{
		#if HSCRIPT_ALLOWED
		interp?.variables.set(varName, value);
		#end
	}

	/** Lee una variable del scope del script. */
	public function get(varName:String):Dynamic
	{
		#if HSCRIPT_ALLOWED
		return interp?.variables.get(varName);
		#end
		return null;
	}

	/** Comprueba si el script tiene definida una función o variable. */
	public function exists(varName:String):Bool
	{
		#if HSCRIPT_ALLOWED
		return interp != null && interp.variables.exists(varName);
		#end
		return false;
	}

	// ─── Lifecycle ────────────────────────────────────────────────────────────

	/** Destruye el script: llama `onDestroy`, limpia variables y libera memoria. */
	public function destroy():Void
	{
		call('onDestroy');
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

	// ─── Util ─────────────────────────────────────────────────────────────────

	public function toString():String
		return 'Script[$name @ $path | active=$active, priority=$priority]';
}
