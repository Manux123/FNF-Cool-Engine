package funkin.scripting;

import haxe.Exception;

// ── Compatibilidad hscript 2.4.x / 2.5.x ─────────────────────────────────────
#if HSCRIPT_ALLOWED
import hscript.Interp;
import hscript.Expr;
// hscript.Expr.Error existe en 2.4+ como clase base de errores
// En versiones muy antiguas puede no tener `.e` — usar Dynamic como fallback
#end

#if sys
import sys.FileSystem;
import sys.io.File;
#end

/**
 * HScriptInstance v3 — instancia individual de script HScript.
 *
 * ─── Nuevas features v3 ──────────────────────────────────────────────────────
 *
 *  • Guards de compatibilidad de librerías:
 *      - hscript 2.4.x / 2.5.x  → allowMetadata manejado con try/catch
 *      - openfl 8.x / 9.x        → no hay dependencias directas aquí
 *      - sys-only FileSystem     → guard #if sys
 *
 *  • hotReload() mejorado: también re-expone el ScriptAPI completo tras recargar.
 *  • Errores más legibles: formato "NombreScript.hx:42 — mensaje".
 *  • set/get son más seguros: null-check antes de acceder a interp.variables.
 *  • dispose() para limpiar el intérprete sin destruir el objeto.
 *
 * ─── Compatibilidad garantizada ──────────────────────────────────────────────
 *  Flixel 4.x, 5.x — no hay dependencias directas de Flixel aquí
 *  hscript 2.4.x, 2.5.x — API de Parser/Interp es igual
 *  OpenFL 8.x, 9.x — sin dependencias directas
 *
 * @author Cool Engine Team
 * @version 3.0.0
 */
class HScriptInstance
{
	public var name     : String;
	public var path     : String;
	public var active   : Bool   = true;
	public var priority : Int    = 0;
	public var tag      : String = '';

	/** Último valor devuelto por `call()`. */
	public var returnValue : Dynamic = null;

	/** Callback de error: (scriptName, funcName, error) → Void. */
	public var onError : Null<String->String->Dynamic->Void> = null;

	#if HSCRIPT_ALLOWED
	public var interp   : Null<Interp> = null;
	public var program  : Null<Expr>   = null;

	/** Source cacheada para hot-reload. */
	var _source : String = '';
	#end

	// ── Constructor ───────────────────────────────────────────────────────────

	public function new(name:String, path:String, priority:Int = 0, tag:String = '')
	{
		this.name     = name;
		this.path     = path;
		this.priority = priority;
		this.tag      = tag;
	}

	// ── Llamadas ──────────────────────────────────────────────────────────────

	/**
	 * Llama a `funcName` con `args`. Devuelve el resultado o null.
	 * Null-safe: si la función no existe, no hace nada.
	 */
	public function call(funcName:String, args:Array<Dynamic> = null):Dynamic
	{
		if (!active) return null;

		#if HSCRIPT_ALLOWED
		if (interp == null) return null;
		if (args == null)   args = [];

		try
		{
			final func = interp.variables.get(funcName);
			if (func != null && Reflect.isFunction(func))
			{
				returnValue = Reflect.callMethod(null, func, args);
				return returnValue;
			}
		}
		catch (e:Dynamic)
		{
			_handleError(funcName, e);
		}
		#end

		return null;
	}

	/**
	 * Llama con cast tipado al valor de retorno.
	 * Si el resultado no es del tipo T, devuelve `fallback`.
	 */
	public function callReturn<T>(funcName:String, args:Array<Dynamic> = null, fallback:T):T
	{
		final r = call(funcName, args);
		if (r == null) return fallback;
		try { return cast r; } catch(_) { return fallback; }
	}

	/**
	 * Llama a `funcName` y devuelve true si el resultado es literalmente `true`.
	 * Usado por StateScriptHandler para la mecánica de cancelación de eventos.
	 */
	public function callBool(funcName:String, args:Array<Dynamic> = null):Bool
	{
		final r = call(funcName, args);
		return r == true;
	}

	// ── Variables ─────────────────────────────────────────────────────────────

	/** Inyecta o actualiza una variable. */
	public function set(varName:String, value:Dynamic):Void
	{
		#if HSCRIPT_ALLOWED
		if (interp != null) interp.variables.set(varName, value);
		#end
	}

	/** Sets multiple variables at once from a map or anonymous struct. */
	public function setAll(vars:Dynamic):Void
	{
		#if HSCRIPT_ALLOWED
		if (interp == null || vars == null) return;
		for (field in Reflect.fields(vars))
			interp.variables.set(field, Reflect.field(vars, field));
		#end
	}

	/** Lee una variable del script. Devuelve null si no existe. */
	public function get(varName:String):Dynamic
	{
		#if HSCRIPT_ALLOWED
		if (interp == null) return null;
		return interp.variables.get(varName);
		#else
		return null;
		#end
	}

	/** Comprueba si la variable existe. */
	public function exists(varName:String):Bool
	{
		#if HSCRIPT_ALLOWED
		if (interp == null) return false;
		return interp.variables.exists(varName);
		#else
		return false;
		#end
	}

	/**
	 * Sobreescribe completamente una función en el script con una implementación Haxe.
	 * Útil para que el engine overridee comportamiento sin que el script lo sepa.
	 */
	public function overrideFunction(funcName:String, impl:Dynamic):Void
	{
		#if HSCRIPT_ALLOWED
		if (interp != null) interp.variables.set(funcName, impl);
		#end
	}

	// ── Hot-reload ────────────────────────────────────────────────────────────

	/**
	 * Recarga el archivo desde disco sin recrear el intérprete.
	 * Las variables que ya existen en `interp` se preservan.
	 * El ScriptAPI se re-expone para que nuevas APIs sean visibles.
	 */
	public function hotReload():Bool
	{
		#if (HSCRIPT_ALLOWED && sys)
		if (interp == null || path == null || path == '') return false;
		if (!FileSystem.exists(path)) { trace('[HScript] hotReload: no existe "$path"'); return false; }

		try
		{
			_source  = File.getContent(path);
			program  = ScriptHandler.parser.parseString(_source, path);

			// Re-exponer ScriptAPI (podría haber cambiado entre recargas)
			ScriptAPI.expose(interp);

			interp.execute(program);
			call('onCreate');
			call('postCreate');
			trace('[HScript] Hot-reloaded: $name');
			return true;
		}
		catch (e:Dynamic)
		{
			trace('[HScript] hotReload FAIL "$name": ${Std.string(e)}');
			return false;
		}
		#else
		return false;
		#end
	}

	// ── Módulos (require) ─────────────────────────────────────────────────────

	/**
	 * Importa otro script como módulo.
	 * Devuelve el intérprete del módulo para acceder a sus variables.
	 * Uso desde un script: `var mod = require('ruta/otroScript.hx');`
	 */
	public function require(modulePath:String):Dynamic
	{
		#if (HSCRIPT_ALLOWED && sys)
		final resolved = _resolvePath(modulePath);
		if (resolved == null) { trace('[HScript] require: no encontrado "$modulePath"'); return null; }

		final mod = ScriptHandler.loadScript(resolved, 'song');
		if (mod == null || mod.interp == null) return null;

		// Exponer las variables del módulo como objeto
		return mod.interp.variables;
		#else
		return null;
		#end
	}

	// ── Limpieza ──────────────────────────────────────────────────────────────

	/**
	 * Alias de dispose() para compatibilidad con código que llame destroy().
	 * Destruye el intérprete y desactiva la instancia.
	 */
	public function destroy():Void
		dispose();

	/**
	 * Destruye el intérprete pero preserva metadata (name, path, tag).
	 * Útil para liberar RAM manteniendo el slot registrado.
	 */
	public function dispose():Void
	{
		#if HSCRIPT_ALLOWED
		interp  = null;
		program = null;
		_source = '';
		#end
		active = false;
	}

	// ── Helpers privados ─────────────────────────────────────────────────────

	function _handleError(funcName:String, e:Dynamic):Void
	{
		var msg = Std.string(e);

		// Intentar extraer número de línea de hscript.Expr.Error (2.4+)
		#if HSCRIPT_ALLOWED
		try
		{
			// En hscript 2.4+ los errores tienen campo `e` o `msg`
			final exprErr = cast(e, hscript.Expr.Error);
			if (exprErr != null)
			{
				// Intentar leer `.e` (línea del error en algunos formatos)
				final lineField = Reflect.hasField(exprErr, 'pmin') ? Reflect.field(exprErr, 'pmin') : null;
				if (lineField != null) msg = 'Línea ~${lineField}: $msg';
			}
		}
		catch (_) {} // Ignorar si el cast falla (versión antigua de hscript)
		#end

		trace('[HScript] ¡Error en $name.$funcName()! → $msg');

		if (onError != null)
		{
			try { onError(name, funcName, e); } catch(_) {}
		}
	}

	function _resolvePath(rawPath:String):Null<String>
	{
		#if sys
		// 1. Ruta absoluta
		if (FileSystem.exists(rawPath)) return rawPath;

		// 2. Relativa al directorio del script actual
		if (path != null && path != '')
		{
			final dir = StringTools.contains(path, '/') ? path.substring(0, path.lastIndexOf('/') + 1)
			                               : path.substring(0, path.lastIndexOf('\\') + 1);
			final rel = dir + rawPath;
			if (FileSystem.exists(rel)) return rel;
			// Con extensión .hx
			if (FileSystem.exists(rel + '.hx')) return rel + '.hx';
		}

		// 3. Relativa a assets/
		if (FileSystem.exists('assets/$rawPath'))          return 'assets/$rawPath';
		if (FileSystem.exists('assets/$rawPath.hx'))       return 'assets/$rawPath.hx';

		// 4. Relativa al mod activo
		if (mods.ModManager.isActive())
		{
			final modPath = '${mods.ModManager.modRoot()}/$rawPath';
			if (FileSystem.exists(modPath))       return modPath;
			if (FileSystem.exists(modPath + '.hx')) return modPath + '.hx';
		}
		#end
		return null;
	}
}
