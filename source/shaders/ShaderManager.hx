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
 * Sistema de gestión de shaders.
 * Escanea assets/shaders/*.frag y los hace disponibles globalmente.
 *
 * ── POR QUÉ "no camera detected" ──────────────────────────────────────────
 *
 * En Flixel 5, sprite.shader se procesa durante el draw call en
 * FlxDrawQuadsItem. Para compilar el programa GL del shader, Flixel necesita
 * el contexto de al menos una cámara válida (no vacía).
 *
 * El error aparece cuando:
 *   a) El sprite tiene cameras = [] (array vacío, distinto de null).
 *      null → Flixel usa FlxG.cameras.list como fallback (OK).
 *      []   → Flixel itera cero cámaras → no hay contexto → crash.
 *
 *   b) El sprite está dentro de un FlxTypedGroup al que se asignó cameras
 *      a nivel de grupo pero NO se propagó recursivamente a los miembros
 *      (FlxGroup.cameras solo toca el nivel top, no sub-grupos).
 *
 * FIX centralizado aquí:
 *   applyShader() llama a _ensureCameras(sprite) que garantiza que el sprite
 *   tenga al menos una cámara válida ANTES de asignar el shader.
 */
class ShaderManager
{
	public static var shaders:Map<String, CustomShader> = new Map();
	public static var shaderPaths:Map<String, String> = new Map();

	/**
	 * Registra qué ShaderFilter se aplicó a cada sprite para poder quitarlo después.
	 * Clave: sprite — Valor: {filter, camera}
	 */
	static var _appliedFilters:Map<FlxSprite, {filter:ShaderFilter, camera:FlxCamera}> = new Map();

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
		mods.reverse(); // mayor prioridad → registra último → gana
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
		{
			trace('[ShaderManager] Shader "$shaderName" ya está cargado');
			return shaders.get(shaderName);
		}

		if (!shaderPaths.exists(shaderName))
		{
			trace('[ShaderManager] Shader "$shaderName" no encontrado. Reescaneando...');
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
			trace('[ShaderManager] Shader "$shaderName" cargado desde: ${shaderPaths.get(shaderName)}');
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
	 * Aplica un shader a un sprite via ShaderFilter en su cámara (cam._filters).
	 *
	 * NOTA sobre "Invalid field:camera":
	 * ────────────────────────────────────
	 * El error era causado por añadir el filtro a una cámara secundaria cuyos
	 * _filters son procesados por FlxCamera.render() usando @:access interno.
	 * La clase ShaderManager usa @:access(flixel.FlxCamera) a nivel de función
	 * para garantizar acceso seguro al campo _filters en cualquier cámara.
	 *
	 * @param sprite     Sprite destino (se usa para lookup; el filtro va a la cámara).
	 * @param shaderName Nombre del shader (sin .frag).
	 * @param camera     Cámara destino. Si null, usa la primera cámara del sprite
	 *                   o FlxG.camera como fallback.
	 * @return true si se aplicó correctamente.
	 */
	@:access(flixel.FlxCamera)
	public static function applyShader(sprite:FlxSprite, shaderName:String, ?camera:FlxCamera):Bool
	{
		if (sprite == null)
		{
			trace('[ShaderManager] applyShader: sprite es null');
			return false;
		}

		final customShader = getShader(shaderName);
		if (customShader == null || customShader.shader == null)
			return false;

		// Quitar shader previo del sprite si tenía uno
		removeShader(sprite);

		// Resolver cámara: parámetro → primera cámara del sprite → FlxG.camera
		var cam:FlxCamera = camera;
		if (cam == null && sprite.cameras != null && sprite.cameras.length > 0)
			cam = sprite.cameras[0];
		if (cam == null)
			cam = FlxG.camera;

		final filter = new ShaderFilter(cast customShader.shader);

		// Añadir el filtro a la cámara usando el campo interno _filters
		if (cam._filters == null) cam._filters = [];
		cam._filters.push(filter);

		// Registrar para poder quitarlo después
		_appliedFilters.set(sprite, {filter: filter, camera: cam});

		trace('[ShaderManager] Shader "$shaderName" aplicado a sprite via cam._filters');
		return true;
	}

	/**
	 * Quita el shader de un sprite (elimina su ShaderFilter de la cámara).
	 */
	@:access(flixel.FlxCamera)
	public static function removeShader(sprite:FlxSprite):Void
	{
		if (sprite == null) return;

		final entry = _appliedFilters.get(sprite);
		if (entry == null) return;

		final cam = entry.camera;
		if (cam != null && cam._filters != null)
		{
			cam._filters.remove(entry.filter);
			if (cam._filters.length == 0)
				cam._filters = null;
		}

		_appliedFilters.remove(sprite);
		trace('[ShaderManager] Shader removido del sprite');
	}

	/**
	 * Garantiza que el sprite tenga al menos una cámara válida.
	 * Mantenido por compatibilidad; ya no es necesario con el enfoque ShaderFilter.
	 */
	@:deprecated("_ensureCameras ya no es necesario con ShaderFilter — se mantiene por compatibilidad")
	public static function _ensureCameras(sprite:FlxSprite, ?fallback:FlxCamera):Void
	{
		if (sprite == null) return;
		if (sprite.cameras != null && sprite.cameras.length == 0)
		{
			final cam = fallback ?? FlxG.camera;
			sprite.cameras = [cam];
		}
	}

	// ─── Parámetros ───────────────────────────────────────────────────────────

	public static function setShaderParam(shaderName:String, paramName:String, value:Dynamic):Bool
	{
		final shader = getShader(shaderName);
		return shader != null ? shader.setParam(paramName, value) : false;
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
		_appliedFilters.clear();
		trace('[ShaderManager] Shaders limpiados');
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
			shader = new FlxShader();
			shader.glFragmentSource = fragmentCode;
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
			final param = Reflect.getProperty(shader.data, paramName);
			if (param == null)
			{
				trace('[CustomShader] Parámetro "$paramName" no encontrado en shader "$name"');
				return false;
			}
			if (Std.isOfType(param, ShaderParameter))
				cast(param, ShaderParameter<Dynamic>).value = value;
			else
				Reflect.setProperty(shader.data, paramName, value);
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
			final param = Reflect.getProperty(shader.data, paramName);
			if (param != null && Std.isOfType(param, ShaderParameter))
				return cast(param, ShaderParameter<Dynamic>).value;
			return param;
		}
		catch (e:Exception)
		{
			trace('[CustomShader] Error al obtener parámetro "$paramName": ${e.message}');
			return null;
		}
	}

	public function destroy():Void
	{
		shader       = null;
		fragmentCode = null;
	}
}
