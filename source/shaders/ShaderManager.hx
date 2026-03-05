package shaders;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.display.FlxRuntimeShader;
import flixel.system.FlxAssets.FlxShader;
import mods.ModManager;
import openfl.filters.ShaderFilter;
import sys.FileSystem;
import sys.io.File;

using StringTools;

/**
 * ShaderManager — Sistema centralizado de shaders runtime.
 *
 * USA FlxRuntimeShader directamente, igual que Psych Engine y V-Slice.
 * FlxRuntimeShader expone setFloat/setInt/setBool/setFloatArray que son seguros
 * y NO requieren tocar __data, __paramFloat, __paramBool ni nada interno.
 * Esto elimina los null-object-reference de la versión anterior que intentaba
 * registrar uniforms a mano con _registerParam/__processGLData.
 */
class ShaderManager
{
	public static var shaders:Map<String, CustomShader>          = new Map();
	public static var shaderPaths:Map<String, String>            = new Map();

	static var _liveInstances:Map<String, Array<FlxRuntimeShader>>                           = new Map();
	static var _spriteToInstance:Map<FlxSprite, {name:String, instance:FlxRuntimeShader}>    = new Map();
	static var _pendingParams:Map<String, Map<String, Dynamic>>                              = new Map();

	/**
	 * Caché de todos los parámetros que se han aplicado exitosamente a cualquier instancia
	 * de un shader dado. Cuando `applyShader` o `applyShaderToCamera` crean una instancia
	 * NUEVA (por re-apply), este caché se usa para restaurar los parámetros.
	 *
	 * BUG ANTERIOR: al llamar `applyShader` por segunda vez en el mismo sprite, la nueva
	 * instancia partía desde cero (uniforms en 0) porque `_pendingParams` ya estaba vacío
	 * (los params se habían escrito en la instancia anterior y eliminado del pending).
	 * Resultado: waveX/freqX etc. = 0 → sin efecto visual / fondo negro si params eran
	 * necesarios para que el shader renderizara correctamente.
	 */
	static var _lastAppliedParams:Map<String, Map<String, Dynamic>>                          = new Map();

	// ─── Init ─────────────────────────────────────────────────────────────────

	public static function init():Void
	{
		trace('[ShaderManager] Inicializando...');
		scanShaders();

		final prevCallback = ModManager.onModChanged;
		ModManager.onModChanged = function(modId:String)
		{
			if (prevCallback != null) prevCallback(modId);
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
				try { FileSystem.createDirectory(folderPath); } catch (e:Dynamic) {}
			}
			return;
		}
		final prefix = modId != null ? '[$modId] ' : '[base] ';
		for (file in FileSystem.readDirectory(folderPath))
		{
			if (!file.endsWith('.frag')) continue;
			final shaderName = file.substr(0, file.length - 5);
			shaderPaths.set(shaderName, '$folderPath/$file');
			trace('[ShaderManager] Registrado ${prefix}$shaderName');
		}
		#end
	}

	// ─── Carga ────────────────────────────────────────────────────────────────

	public static function loadShader(shaderName:String):CustomShader
	{
		if (shaders.exists(shaderName)) return shaders.get(shaderName);
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
		return shaders.exists(shaderName) ? shaders.get(shaderName) : loadShader(shaderName);

	// ─── Aplicar / Quitar ─────────────────────────────────────────────────────

	public static function applyShader(sprite:FlxSprite, shaderName:String, ?camera:FlxCamera):Bool
	{
		if (sprite == null) { trace('[ShaderManager] applyShader: sprite es null'); return false; }

		final cs = getShader(shaderName);
		if (cs == null || cs.fragmentCode == null) return false;

		removeShader(sprite);

		var instance:FlxRuntimeShader;
		try
		{
			instance = new FlxRuntimeShader(cs.fragmentCode);
		}
		catch (e:Dynamic)
		{
			trace('[ShaderManager] Error al crear FlxRuntimeShader "$shaderName": $e');
			return false;
		}

		sprite.shader = instance;

		if (!_liveInstances.exists(shaderName)) _liveInstances.set(shaderName, []);
		_liveInstances.get(shaderName).push(instance);
		_spriteToInstance.set(sprite, {name: shaderName, instance: instance});

		// Restaurar params del caché ANTES de flush para que _lastAppliedParams
		// tenga prioridad sobre _pendingParams (que puede estar vacío si el shader
		// ya fue aplicado antes y los params se escribieron en la instancia anterior).
		_restoreLastParams(shaderName, instance);
		_flushPendingForShader(shaderName);
		trace('[ShaderManager] Shader "$shaderName" aplicado');
		return true;
	}

	/**
	 * Aplica un shader como filtro de cámara y lo registra en _liveInstances
	 * para que setShaderParam() pueda actualizarlo cada frame.
	 *
	 * BUG ANTERIOR: ScriptAPI.camera.addShader() creaba la instancia via
	 * CustomShader.get_shader() sin registrarla → setShaderParam no la encontraba
	 * → todos los uniforms (uTime, etc.) se quedaban a 0 → sin efecto visible.
	 *
	 * @param shaderName  Nombre del shader (sin extensión .frag)
	 * @param cam         Cámara destino (default: FlxG.camera)
	 * @return El ShaderFilter creado, o null si falló
	 */
	public static function applyShaderToCamera(shaderName:String, ?cam:FlxCamera):openfl.filters.ShaderFilter
	{
		if (cam == null) cam = FlxG.camera;

		final cs = getShader(shaderName);
		if (cs == null || cs.fragmentCode == null)
		{
			trace('[ShaderManager] applyShaderToCamera: shader "$shaderName" no encontrado');
			return null;
		}

		var instance:FlxRuntimeShader;
		try
		{
			// Crear instancia NUEVA (no reusar CustomShader._shader) para que
			// cada cámara tenga su propio estado de uniforms independiente.
			instance = new FlxRuntimeShader(cs.fragmentCode);
		}
		catch (e:Dynamic)
		{
			trace('[ShaderManager] Error compilando shader "$shaderName" para cámara: $e');
			return null;
		}

		// Registrar en _liveInstances ANTES de flush para que los pending params
		// (defaults del script) se apliquen inmediatamente tras añadir la instancia.
		if (!_liveInstances.exists(shaderName)) _liveInstances.set(shaderName, []);
		_liveInstances.get(shaderName).push(instance);
		// Restaurar caché de params (fix re-apply loss) y luego flush pending.
		_restoreLastParams(shaderName, instance);
		_flushPendingForShader(shaderName);

		final filter = funkin.data.CameraUtil.addShader(instance, cam);
		trace('[ShaderManager] Shader "$shaderName" aplicado a cámara');
		return filter;
	}

	/**
	 * Registra manualmente una instancia de FlxRuntimeShader en _liveInstances.
	 * Útil si la instancia fue creada externamente pero se quiere controlar
	 * sus uniforms via setShaderParam().
	 */
	public static function registerInstance(shaderName:String, instance:FlxRuntimeShader):Void
	{
		if (instance == null) return;
		if (!_liveInstances.exists(shaderName)) _liveInstances.set(shaderName, []);
		final arr = _liveInstances.get(shaderName);
		if (!arr.contains(instance)) arr.push(instance);
		_flushPendingForShader(shaderName);
	}

	/** Elimina una instancia registrada via registerInstance / applyShaderToCamera. */
	public static function unregisterInstance(shaderName:String, instance:FlxRuntimeShader):Void
	{
		final arr = _liveInstances.get(shaderName);
		if (arr != null) arr.remove(instance);
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
		catch (e:Dynamic) { _spriteToInstance.remove(sprite); }
	}

	// ─── Parámetros ───────────────────────────────────────────────────────────

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
				if (_writeParam(instance, paramName, value)) updated = true;
				else _storePending(shaderName, paramName, value);
			}
		}
		if (!hadInstances) _storePending(shaderName, paramName, value);

		// Cachear siempre el valor para que futuras instancias (re-apply) lo reciban.
		_cacheParam(shaderName, paramName, value);

		return updated;
	}

	public static function flushPending():Void
	{
		for (name in _pendingParams.keys()) _flushPendingForShader(name);
	}

	// ─── _writeParam: usa FlxRuntimeShader API, sin tocar __data ─────────────
	//
	// FlxRuntimeShader.setFloat/setInt/setBool/setFloatArray/setIntArray/setBoolArray
	// son los mismos métodos que usa Psych Engine (ShaderFunctions.hx).
	// Internamente FlxRuntimeShader ya maneja el null-check de uniforms.

	static function _writeParam(instance:FlxRuntimeShader, paramName:String, value:Dynamic):Bool
	{
		if (instance == null) return false;
		try
		{
			if (Std.isOfType(value, Array))
			{
				final arr:Array<Dynamic> = cast value;
				if (arr.length == 0) return false;
				final first = arr[0];
				if (Std.isOfType(first, Bool))
					instance.setBoolArray(paramName, cast arr);
				else if (Std.isOfType(first, Int) && !Std.isOfType(first, Float))
					instance.setIntArray(paramName, cast arr);
				else
					instance.setFloatArray(paramName, [for (v in arr) cast(v, Float)]);
			}
			else if (Std.isOfType(value, Bool))
				instance.setBool(paramName, cast value);
			else if (Std.isOfType(value, Int) && !Std.isOfType(value, Float))
				instance.setInt(paramName, cast value);
			else
				instance.setFloat(paramName, cast(value, Float));
			return true;
		}
		catch (e:Dynamic)
		{
			return false; // uniform no registrado aún → pending
		}
	}

	static function _storePending(shaderName:String, paramName:String, value:Dynamic):Void
	{
		if (!_pendingParams.exists(shaderName)) _pendingParams.set(shaderName, new Map());
		_pendingParams.get(shaderName).set(paramName, value);
	}

	/** Guarda el valor en el caché _lastAppliedParams para restaurarlo en instancias futuras. */
	static function _cacheParam(shaderName:String, paramName:String, value:Dynamic):Void
	{
		if (!_lastAppliedParams.exists(shaderName)) _lastAppliedParams.set(shaderName, new Map());
		_lastAppliedParams.get(shaderName).set(paramName, value);
	}

	/**
	 * Escribe todos los params del caché _lastAppliedParams en `instance`.
	 * Se llama justo después de registrar una nueva instancia en _liveInstances,
	 * ANTES de _flushPendingForShader, para recuperar los valores que se perdieron
	 * cuando la instancia anterior fue eliminada por removeShader / re-apply.
	 */
	static function _restoreLastParams(shaderName:String, instance:FlxRuntimeShader):Void
	{
		final cache = _lastAppliedParams.get(shaderName);
		if (cache == null || Lambda.count(cache) == 0) return;
		for (paramName => value in cache)
			_writeParam(instance, paramName, value);
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
				if (instance != null && _writeParam(instance, paramName, value)) ok = true;
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
		_lastAppliedParams.clear();
	}

	public static function getAvailableShaders():Array<String>
	{
		final list = [for (n in shaderPaths.keys()) n];
		list.sort((a, b) -> a < b ? -1 : 1);
		return list;
	}

	public static function reloadShader(shaderName:String):Bool
	{
		if (shaders.exists(shaderName)) { shaders.remove(shaderName); }
		return loadShader(shaderName) != null;
	}

	public static function reloadAllShaders():Void
	{
		shaders.clear();
		scanShaders();
		trace('[ShaderManager] ${Lambda.count(shaderPaths)} shaders disponibles');
	}

	public static function clear():Void
	{
		shaders.clear();
		shaderPaths.clear();
		_liveInstances.clear();
		_spriteToInstance.clear();
		_pendingParams.clear();
		_lastAppliedParams.clear();
	}

	@:deprecated("_ensureCameras ya no es necesario")
	public static function _ensureCameras(sprite:FlxSprite, ?fallback:FlxCamera):Void {}


}

// ─── CustomShader ─────────────────────────────────────────────────────────────

class CustomShader
{
	public var name:String;
	public var fragmentCode:String;

	var _shader:FlxRuntimeShader;
	public var shader(get, never):FlxRuntimeShader;

	function get_shader():FlxRuntimeShader
	{
		if (_shader == null && fragmentCode != null)
		{
			try { _shader = new FlxRuntimeShader(fragmentCode); }
			catch (e:Dynamic) { trace('[CustomShader] Error compilando "$name": $e'); }
		}
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
