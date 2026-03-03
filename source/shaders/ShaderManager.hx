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
 * Sistema de gestión de shaders — reescrito siguiendo el patrón de Codename Engine.
 *
 * CAMBIO CLAVE:
 *   Antes: applyShader() añadía un ShaderFilter a cam._filters.
 *          setShaderParam() iteraba un Map<FlxSprite, ...> → crash al destruirse el estado.
 *
 *   Ahora: applyShader() crea una FlxShader propia por sprite y la asigna con sprite.shader.
 *          setShaderParam() actualiza SOLO la instancia FlxShader (sin tocar el sprite nunca).
 *          Map<String, Array<FlxShader>> → las instancias de shader sobreviven a la destrucción
 *          de sprites porque son objetos Haxe independientes.
 */
class ShaderManager
{
	public static var shaders:Map<String, CustomShader> = new Map();
	public static var shaderPaths:Map<String, String> = new Map();

	/**
	 * Instancias vivas de FlxShader por nombre de shader.
	 * Se actualiza en setShaderParam sin necesidad de referencias a sprites.
	 */
	static var _liveInstances:Map<String, Array<FlxShader>> = new Map();

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
				catch (e:Exception) { trace('[ShaderManager] Error al crear carpeta: ${e.message}'); }
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
		catch (e:Exception)
		{
			trace('[ShaderManager] Error al cargar shader "$shaderName": ${e.message}');
			return null;
		}
	}

	public static function getShader(shaderName:String):CustomShader
	{
		return shaders.exists(shaderName) ? shaders.get(shaderName) : loadShader(shaderName);
	}

	// ─── Aplicar / Quitar ─────────────────────────────────────────────────────

	/**
	 * Aplica un shader DIRECTAMENTE al sprite (sprite.shader = instance).
	 *
	 * Cada sprite recibe su propia FlxShader para no compartir estado.
	 * La instancia se registra en _liveInstances[shaderName] para que
	 * setShaderParam pueda actualizarla sin necesidad de tocar el sprite.
	 */
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

		// Quitar instancia anterior del registro si el sprite ya tenía un shader
		removeShader(sprite);

		// BUGFIX: glFragmentSource DEBE establecerse ANTES de super() en FlxShader.
		// Asignarlo DESPUÉS de new FlxShader() no recompila — la GPU ya recibió el fuente vacío.
		// RuntimeShader pasa el fragmento en su propio constructor correctamente.
		final instance = new RuntimeShader(customShader.fragmentCode);

		// Asignar directo al sprite — sin tocar cámaras ni filtros
		sprite.shader = instance;

		// Registrar la instancia por nombre para poder actualizar uniforms
		if (!_liveInstances.exists(shaderName))
			_liveInstances.set(shaderName, []);
		_liveInstances.get(shaderName).push(instance);

		// Guardar qué instancia tiene este sprite (para removeShader)
		_spriteToInstance.set(sprite, {name: shaderName, instance: instance});

		trace('[ShaderManager] Shader "$shaderName" aplicado directo a sprite');
		return true;
	}

	/** Mapa auxiliar sprite→instancia solo para removeShader. Solo se lee en remove, nunca en update. */
	static var _spriteToInstance:Map<FlxSprite, {name:String, instance:FlxShader}> = new Map();

	/**
	 * Quita el shader de un sprite y elimina su instancia del registro.
	 */
	public static function removeShader(sprite:FlxSprite):Void
	{
		if (sprite == null) return;
		try
		{
			final entry = _spriteToInstance.get(sprite);
			if (entry == null) return;

			// Quitar la instancia del array de instancias vivas
			final arr = _liveInstances.get(entry.name);
			if (arr != null) arr.remove(entry.instance);

			// Quitar shader del sprite
			sprite.shader = null;

			_spriteToInstance.remove(sprite);
		}
		catch(_) { _spriteToInstance.remove(sprite); }
	}

	// ─── Parámetros ───────────────────────────────────────────────────────────

	/**
	 * Actualiza un uniform en TODAS las instancias vivas de ese shader.
	 * Solo accede a objetos FlxShader — nunca toca sprites ni cámaras.
	 * Los FlxShader son objetos Haxe puros, no se destruyen con los sprites.
	 */
	public static function setShaderParam(shaderName:String, paramName:String, value:Dynamic):Bool
	{
		var updated = false;
		try
		{
			final arr = _liveInstances.get(shaderName);
			if (arr != null)
			{
				for (instance in arr)
				{
					try
					{
						if (instance == null) continue;
						// FIX: Reflect.getProperty() busca getters/setters explícitos.
					// Los uniforms de OpenFL ShaderData son campos dinámicos (@:data),
					// por eso getProperty devuelve null. Reflect.field() los encuentra.
					final param = Reflect.field(instance.data, paramName);
						if (param != null && Std.isOfType(param, ShaderParameter))
						{
							cast(param, ShaderParameter<Dynamic>).value = value;
							updated = true;
						}
					}
					catch(_) {}
				}
			}
		}
		catch(_) {}

		// También actualizar la instancia maestra por compatibilidad
		try
		{
			final master = getShader(shaderName);
			if (master != null) master.setParam(paramName, value);
		}
		catch(_) {}

		return updated;
	}

	/**
	 * Limpia todas las instancias registradas (llamar en onDestroy del estado).
	 * NO toca sprites — solo limpia los arrays internos.
	 */
	public static function clearSpriteShaders():Void
	{
		_liveInstances.clear();
		_spriteToInstance.clear();
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
		for (shader in shaders) shader.destroy();
		shaders.clear();
		shaderPaths.clear();
		_liveInstances.clear();
		_spriteToInstance.clear();
		trace('[ShaderManager] Shaders limpiados');
	}

	// ─── Compatibilidad: _ensureCameras ───────────────────────────────────────

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
	public var shader:FlxShader;
	public var fragmentCode:String;

	public function new(name:String, fragmentCode:String)
	{
		this.name         = name;
		this.fragmentCode = fragmentCode;

		try
		{
			// BUGFIX: RuntimeShader establece glFragmentSource ANTES de super() —
			// única forma correcta de compilar un GLSL dinámico en OpenFL/HaxeFlixel.
			shader = new RuntimeShader(fragmentCode);
			trace('[CustomShader] Shader "$name" compilado');
		}
		catch (e:Exception)
		{
			trace('[CustomShader] Error al compilar shader "$name": ${e.message}');
			shader = null;
		}
	}

	public function setParam(paramName:String, value:Dynamic):Bool
	{
		if (shader == null) return false;
		try
		{
			// FIX: Reflect.field() para campos dinámicos (@:data) de ShaderData
			final param = Reflect.field(shader.data, paramName);
			if (param == null) return false;
			if (Std.isOfType(param, ShaderParameter))
				cast(param, ShaderParameter<Dynamic>).value = value;
			else
				Reflect.setField(shader.data, paramName, value);
			return true;
		}
		catch (e:Exception)
		{
			trace('[CustomShader] Error al establecer parámetro "$paramName": ${e.message}');
			return false;
		}
	}

	public function getParam(paramName:String):Dynamic
	{
		if (shader == null) return null;
		try
		{
			// FIX: Reflect.field() para campos dinámicos de ShaderData
			final param = Reflect.field(shader.data, paramName);
			if (param != null && Std.isOfType(param, ShaderParameter))
				return cast(param, ShaderParameter<Dynamic>).value;
			return param;
		}
		catch (e:Exception) { return null; }
	}

	public function destroy():Void
	{
		shader       = null;
		fragmentCode = null;
	}
}

// ─── RuntimeShader ────────────────────────────────────────────────────────────
//
// RAZÓN DE EXISTENCIA:
//   En OpenFL/HaxeFlixel, FlxShader compila el GLSL en __init() que se llama
//   automáticamente en super(). Para cargar código dinámico el fragmento DEBE
//   estar asignado ANTES de que se llame a super() — de lo contrario la GPU
//   recibe el shader vacío/por defecto y asignarlo después NO lo recompila.
//
//   Patrón incorrecto (causa crash / shader ignorado):
//     var s = new FlxShader();
//     s.glFragmentSource = myCode;   ← demasiado tarde, ya compiló vacío
//
//   Patrón correcto (este helper):
//     var s = new RuntimeShader(myCode);
//     // glFragmentSource está seteado antes de super() → se compila bien

class RuntimeShader extends FlxShader
{
	public function new(fragmentCode:String)
	{
		// Asignar fuente ANTES de super() para que __init() lo compile correctamente
		glFragmentSource = fragmentCode;
		super();
	}
}
