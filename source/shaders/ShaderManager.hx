package shaders;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.system.FlxAssets.FlxShader;
import haxe.Exception;
import mods.ModManager;
import openfl.display.ShaderParameter;
import openfl.filters.BitmapFilter;
import openfl.filters.ShaderFilter;
import sys.FileSystem;
import sys.io.File;

using StringTools;

/**
 * ShaderManager — Sistema centralizado de shaders runtime.
 *
 * ── RuntimeShader extiende FlxShader ──────────────────────────────────────
 * FlxSprite.shader espera FlxShader. RuntimeShader extiende FlxShader con un
 * passthrough como @:glFragmentSource. Después de super() la fuente real se
 * escribe via @:privateAccess directamente al campo interno __glFragmentSrc,
 * evitando que el setter dispare __init__() sobre el ShaderData viejo.
 * OpenFL recompila en el primer draw; pending-params cubre ese delay de 1 frame.
 *
 * ── Pending Params ──────────────────────────────────────────────────────────
 * Los uniforms (uTime etc.) no existen en data hasta el primer draw call.
 * setShaderParam() guarda valores en _pendingParams cuando no están listos,
 * y los reintenta automáticamente en cada llamada posterior (onUpdate).
 */
class ShaderManager
{
	public static var shaders:Map<String, CustomShader> = new Map();
	public static var shaderPaths:Map<String, String>   = new Map();

	/** Instancias Shader vivas, indexadas por nombre de shader. */
	static var _liveInstances:Map<String, Array<FlxShader>> = new Map();

	/** Mapeo inverso: sprite → {shaderName, instance}. */
	static var _spriteToInstance:Map<FlxSprite, {name:String, instance:FlxShader}> = new Map();

	/**
	 * Params pendientes: shaderName → Map(paramName → value).
	 * Se guardan cuando el uniform no existe aún y se reintenta en el siguiente frame.
	 */
	static var _pendingParams:Map<String, Map<String, Dynamic>> = new Map();

	// ─── Init ─────────────────────────────────────────────────────────────────

	public static function init():Void
	{
		trace('[ShaderManager] Inicializando sistema de shaders...');
		scanShaders();

		final prevCallback = ModManager.onModChanged;
		ModManager.onModChanged = function(modId:String)
		{
			if (prevCallback != null) prevCallback(modId);
			trace('[ShaderManager] Mod cambiado a "$modId", re-escaneando shaders...');
			reloadAllShaders();
		};
	}

	// ─── Escaneo ──────────────────────────────────────────────────────────────

	public static function scanShaders():Void
	{
		shaderPaths.clear();
		_scanFolder('assets/shaders', null);

		#if sys
		final mods = ModManager.installedMods.copy();
		mods.reverse();
		for (mod in mods)
		{
			if (!ModManager.isEnabled(mod.id)) continue;
			_scanFolder('${ModManager.MODS_FOLDER}/${mod.id}/shaders', mod.id);
		}
		#end
	}

	private static function _scanFolder(folderPath:String, modId:Null<String>):Void
	{
		#if sys
		if (!FileSystem.exists(folderPath) || !FileSystem.isDirectory(folderPath))
		{
			if (modId == null)
			{
				trace('[ShaderManager] Carpeta $folderPath no encontrada. Creando...');
				try { FileSystem.createDirectory(folderPath); }
				catch (e:Dynamic) { trace('[ShaderManager] Error al crear carpeta: $e'); }
			}
			return;
		}

		final prefix = modId != null ? '[$modId] ' : '[base] ';
		for (file in FileSystem.readDirectory(folderPath))
		{
			if (!file.endsWith('.frag')) continue;
			final shaderName = file.substr(0, file.length - 5);
			shaderPaths.set(shaderName, '$folderPath/$file');
			trace('[ShaderManager] Shader registrado ${prefix}$shaderName');
		}
		#end
	}

	// ─── Carga ────────────────────────────────────────────────────────────────

	public static function loadShader(shaderName:String):CustomShader
	{
		if (shaders.exists(shaderName))
			return shaders.get(shaderName);

		if (!shaderPaths.exists(shaderName))
		{
			scanShaders();
			if (!shaderPaths.exists(shaderName))
			{
				trace('[ShaderManager] Shader "$shaderName" no existe');
				return null;
			}
		}

		try
		{
			final fragCode = File.getContent(shaderPaths.get(shaderName));
			final shader   = new CustomShader(shaderName, fragCode);
			shaders.set(shaderName, shader);
			trace('[ShaderManager] Shader "$shaderName" cargado');
			return shader;
		}
		catch (e:Dynamic)
		{
			trace('[ShaderManager] Error al cargar shader "$shaderName": $e');
			return null;
		}
	}

	public static function getShader(shaderName:String):CustomShader
	{
		return shaders.exists(shaderName) ? shaders.get(shaderName) : loadShader(shaderName);
	}

	// ─── Aplicar / Quitar ─────────────────────────────────────────────────────

	public static function applyShader(sprite:FlxSprite, shaderName:String, ?camera:FlxCamera):Bool
	{
		if (sprite == null)
		{
			trace('[ShaderManager] applyShader: sprite es null');
			return false;
		}

		final customShader = getShader(shaderName);
		if (customShader == null || customShader.fragmentCode == null)
			return false;

		removeShader(sprite);

				var instance:FlxShader;
		try
		{
			instance = new RuntimeShader(customShader.fragmentCode);
		}
		catch (e:Dynamic)
		{
			trace('[ShaderManager] Error al crear RuntimeShader "$shaderName": $e');
			return false;
		}

		sprite.shader = instance;

		if (!_liveInstances.exists(shaderName))
			_liveInstances.set(shaderName, []);
		_liveInstances.get(shaderName).push(instance);

		_spriteToInstance.set(sprite, {name: shaderName, instance: instance});

		// Los params pendientes se aplicarán en el próximo onUpdate (post primer draw).
		_flushPendingForShader(shaderName);

		trace('[ShaderManager] Shader "$shaderName" aplicado a sprite');
		return true;
	}

	public static function removeShader(sprite:FlxSprite):Void
	{
		if (sprite == null) return;
		try
		{
			final entry = _spriteToInstance.get(sprite);
			if (entry == null) return;

			final arr = _liveInstances.get(entry.name);
			if (arr != null) arr.remove(entry.instance);

			sprite.shader = null;
			_spriteToInstance.remove(sprite);
		}
		catch(e:Dynamic) { _spriteToInstance.remove(sprite); }
	}

	// ─── Parámetros ───────────────────────────────────────────────────────────

	/**
	 * Establece un parámetro uniform en todas las instancias vivas de shaderName.
	 * Si el uniform no está disponible aún (pre-primer draw), el valor se guarda
	 * y se reintenta automáticamente en la siguiente llamada.
	 */
	public static function setShaderParam(shaderName:String, paramName:String, value:Dynamic):Bool
	{
		_flushPendingForShader(shaderName);

		var updated = false;
		var hadInstances = false;

		final arr = _liveInstances.get(shaderName);
		if (arr != null && arr.length > 0)
		{
			hadInstances = true;
			for (instance in arr)
			{
				if (instance == null) continue;
				if (_writeParam(instance, paramName, value))
					updated = true;
				else
					_storePending(shaderName, paramName, value);
			}
		}

		if (!hadInstances)
			_storePending(shaderName, paramName, value);

		return updated;
	}

	public static function flushPending():Void
	{
		for (name in _pendingParams.keys())
			_flushPendingForShader(name);
	}

	// ─── Helpers internos ─────────────────────────────────────────────────────

	/**
	 * Intenta escribir un uniform en una instancia openfl.display.Shader.
	 * Devuelve false (sin lanzar) si el uniform no existe aún.
	 *
	 * openfl.errors.Error("Invalid field:X") es lanzado por ShaderData.__get
	 * cuando el uniform no está registrado todavía (pre-primer draw call).
	 * Ese tipo de excepción ES catcheable con catch(e:Dynamic) en C++.
	 */
	static function _writeParam(instance:FlxShader, paramName:String, value:Dynamic):Bool
	{
		var param:Dynamic = null;

		// ShaderData.__get lanza openfl.errors.Error si el campo no existe.
		try { param = Reflect.field(instance.data, paramName); }
		catch (e:Dynamic) { return false; }

		if (param == null || !Std.isOfType(param, ShaderParameter))
			return false;

		final uploadVal:Array<Dynamic> = Std.isOfType(value, Array) ? cast value : [value];
		try
		{
			// Acceso dinámico en vez de cast para evitar type-mismatch C++ entre
			// ShaderParameter_Float y ShaderParameter<Dynamic>.
			var p:Dynamic = param;
			p.value = uploadVal;
			return true;
		}
		catch (e:Dynamic)
		{
			trace('[ShaderManager] Error al setear "$paramName": $e');
			return false;
		}
	}

	static function _storePending(shaderName:String, paramName:String, value:Dynamic):Void
	{
		if (!_pendingParams.exists(shaderName))
			_pendingParams.set(shaderName, new Map());
		_pendingParams.get(shaderName).set(paramName, value);
	}

	static function _flushPendingForShader(shaderName:String):Void
	{
		final pending = _pendingParams.get(shaderName);
		if (pending == null || Lambda.count(pending) == 0) return;

		final arr = _liveInstances.get(shaderName);
		if (arr == null || arr.length == 0) return;

		final toRemove:Array<String> = [];
		for (paramName => value in pending)
		{
			var ok = false;
			for (instance in arr)
				if (instance != null && _writeParam(instance, paramName, value))
					ok = true;
			if (ok) toRemove.push(paramName);
		}
		for (p in toRemove) pending.remove(p);
		if (Lambda.count(pending) == 0) _pendingParams.remove(shaderName);
	}

	// ─── Limpieza ─────────────────────────────────────────────────────────────

	public static function clearSpriteShaders():Void
	{
		_liveInstances.clear();
		_spriteToInstance.clear();
		_pendingParams.clear();
	}

	// ─── Utilidades ───────────────────────────────────────────────────────────

	public static function getAvailableShaders():Array<String>
	{
		final list = [for (n in shaderPaths.keys()) n];
		list.sort((a, b) -> a < b ? -1 : 1);
		return list;
	}

	public static function reloadShader(shaderName:String):Bool
	{
		if (shaders.exists(shaderName))
		{
			shaders.remove(shaderName);
			trace('[ShaderManager] Shader "$shaderName" descargado, recargando...');
		}
		return loadShader(shaderName) != null;
	}

	public static function reloadAllShaders():Void
	{
		trace('[ShaderManager] Recargando todos los shaders...');
		shaders.clear();
		scanShaders();
		trace('[ShaderManager] ${Lambda.count(shaderPaths)} shaders disponibles tras recarga');
	}

	public static function clear():Void
	{
		shaders.clear();
		shaderPaths.clear();
		_liveInstances.clear();
		_spriteToInstance.clear();
		_pendingParams.clear();
		trace('[ShaderManager] Shaders limpiados');
	}

	@:deprecated("_ensureCameras ya no es necesario — se mantiene por compatibilidad")
	public static function _ensureCameras(sprite:FlxSprite, ?fallback:FlxCamera):Void
	{
		if (sprite == null) return;
		if (sprite.cameras != null && sprite.cameras.length == 0)
			sprite.cameras = [fallback ?? FlxG.camera];
	}
}

// ─── CustomShader ─────────────────────────────────────────────────────────────

class CustomShader
{
	public var name:String;
	public var fragmentCode:String;

	/** Instancia lazy para CameraUtil.addShader() y otras APIs externas.
	 *  Las instancias por-sprite viven en ShaderManager._liveInstances. */
	var _shader:FlxShader;
	public var shader(get, never):FlxShader;
	function get_shader():FlxShader
	{
		if (_shader == null && fragmentCode != null)
			_shader = new RuntimeShader(fragmentCode);
		return _shader;
	}

	public function new(name:String, fragmentCode:String)
	{
		this.name         = name;
		this.fragmentCode = fragmentCode;
	}

	public function destroy():Void
	{
		_shader      = null;
		fragmentCode = null;
	}
}

// ─── RuntimeShader ────────────────────────────────────────────────────────────
// Extends FlxShader so FlxSprite.shader accepts it.
//
// The only reliable cross-version approach:
//  1. @:glFragmentSource compiles a valid passthrough at build time so super()
//     initialises ShaderData without touching any custom uniforms.
//  2. We store the real source in a static var BEFORE calling super(), then
//     in the constructor we call the public glFragmentSource setter.
//     In OpenFL 9+, the setter only sets a dirty flag — it does NOT call
//     __init__() immediately, so no "Invalid field" is thrown.
//     (If a version does call __init__() in the setter, the passthrough ShaderData
//      is already set up, so at worst the custom source gets compiled twice —
//      still no crash.)
//  3. ShaderManager's pending-params retries uniforms after the first draw call,
//     covering any one-frame delay.

@:glFragmentSource('
	#pragma header
	void main() {
		gl_FragColor = flixel_texture2D(bitmap, openfl_TextureCoordv);
	}
')
class RuntimeShader extends FlxShader
{
	public function new(fragmentCode:String)
	{
		super();
		// Assign via the public property AFTER super(). The FlxShader/OpenFL
		// setter marks the shader dirty and schedules a recompile on next draw.
		// We avoid @:privateAccess because internal field names differ across
		// OpenFL versions and cause "Unknown identifier" compile errors.
		glFragmentSource = fragmentCode;
	}
}
