package shaders;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.system.FlxAssets.FlxShader;
import haxe.Exception;
import mods.ModManager;
import openfl.display.ShaderParameter;
import sys.FileSystem;
import sys.io.File;

using StringTools;

/**
 * Sistema de gestión de shaders
 * Escanea assets/shaders/*.frag y los hace disponibles globalmente
 */
class ShaderManager
{
	public static var shaders:Map<String, CustomShader> = new Map();
	public static var shaderPaths:Map<String, String> = new Map();
	
	/**
	 * Inicializar el sistema de shaders.
	 * Registra un callback en ModManager para re-escanear cuando cambie el mod activo.
	 */
	public static function init():Void
	{
		trace('[ShaderManager] Inicializando sistema de shaders...');
		scanShaders();

		// Re-escanear shaders cada vez que se activa/desactiva un mod
		final prevCallback = ModManager.onModChanged;
		ModManager.onModChanged = function(modId:String)
		{
			if (prevCallback != null) prevCallback(modId);
			trace('[ShaderManager] Mod cambiado a "$modId", re-escaneando shaders...');
			reloadAllShaders();
		};
	}
	
	/**
	 * Escanea la carpeta base de shaders y, después, las carpetas `shaders/`
	 * de todos los mods habilitados (en orden de prioridad, de menor a mayor).
	 * Los shaders de mods sobreescriben a los base si tienen el mismo nombre.
	 */
	public static function scanShaders():Void
	{
		shaderPaths.clear();

		// ── 1. Shaders base ───────────────────────────────────────────────────
		_scanFolder('assets/shaders', null);

		// ── 2. Shaders de mods (prioridad: mayor priority = se registra último = gana) ──
		#if sys
		final mods = ModManager.installedMods.copy();
		// installedMods ya viene ordenado priority DESC; invertimos para que el
		// de mayor prioridad sobreescriba al de menor prioridad.
		mods.reverse();
		for (mod in mods)
		{
			if (!ModManager.isEnabled(mod.id)) continue;
			final modShadersPath = '${ModManager.MODS_FOLDER}/${mod.id}/shaders';
			_scanFolder(modShadersPath, mod.id);
		}
		#end
	}

	/**
	 * Escanea una carpeta de shaders y registra los .frag encontrados.
	 * @param folderPath  Ruta de la carpeta a escanear
	 * @param modId       ID del mod al que pertenece, o null si es base
	 */
	private static function _scanFolder(folderPath:String, modId:Null<String>):Void
	{
		#if sys
		if (!FileSystem.exists(folderPath) || !FileSystem.isDirectory(folderPath))
		{
			if (modId == null) // Solo crear la carpeta base, no las de mods
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
			final fullPath   = '$folderPath/$file';
			shaderPaths.set(shaderName, fullPath);
			trace('[ShaderManager] Shader registrado ${prefix}$shaderName');
		}
		#end
	}
	
	/**
	 * Cargar un shader por nombre
	 * @param shaderName Nombre del shader (sin extensión .frag)
	 * @return CustomShader instance o null si falla
	 */
	public static function loadShader(shaderName:String):CustomShader
	{
		// Si ya está cargado, retornar la instancia existente
		if (shaders.exists(shaderName))
		{
			trace('[ShaderManager] Shader "$shaderName" ya está cargado');
			return shaders.get(shaderName);
		}
		
		// Verificar si el path existe
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
		
		var path = shaderPaths.get(shaderName);
		
		try
		{
			// Leer el código del shader
			var fragCode = File.getContent(path);
			
			// Crear el shader
			var shader = new CustomShader(shaderName, fragCode);
			
			// Guardar en el mapa
			shaders.set(shaderName, shader);
			
			trace('[ShaderManager] Shader "$shaderName" cargado desde: $path');
			return shader;
		}
		catch (e:Exception)
		{
			trace('[ShaderManager] Error al cargar shader "$shaderName": ${e.message}');
			return null;
		}
	}
	
	/**
	 * Obtener un shader (cargándolo si es necesario)
	 */
	public static function getShader(shaderName:String):CustomShader
	{
		if (shaders.exists(shaderName))
			return shaders.get(shaderName);
		
		return loadShader(shaderName);
	}
	
	/**
	 * Aplicar shader a un sprite
	 * @param sprite Sprite al que aplicar el shader
	 * @param shaderName Nombre del shader
	 * @return true si se aplicó correctamente
	 */
	public static function applyShader(sprite:FlxSprite, shaderName:String):Bool
	{
		if (sprite == null)
		{
			trace('[ShaderManager] Sprite es null');
			return false;
		}
		
		var shader = getShader(shaderName);
		if (shader == null)
			return false;
		
		sprite.shader = shader.shader;
		trace('[ShaderManager] Shader "$shaderName" aplicado a sprite');
		return true;
	}
	
	/**
	 * Remover shader de un sprite
	 */
	public static function removeShader(sprite:FlxSprite):Void
	{
		if (sprite != null)
		{
			sprite.shader = null;
			trace('[ShaderManager] Shader removido del sprite');
		}
	}
	
	/**
	 * Establecer parámetro de un shader
	 * @param shaderName Nombre del shader
	 * @param paramName Nombre del parámetro
	 * @param value Valor (puede ser Float, Array<Float>, etc)
	 */
	public static function setShaderParam(shaderName:String, paramName:String, value:Dynamic):Bool
	{
		var shader = getShader(shaderName);
		if (shader == null)
			return false;
		
		return shader.setParam(paramName, value);
	}
	
	/**
	 * Obtener lista de shaders disponibles
	 */
	public static function getAvailableShaders():Array<String>
	{
		var list:Array<String> = [];
		for (name in shaderPaths.keys())
			list.push(name);
		list.sort((a, b) -> a < b ? -1 : 1);
		return list;
	}
	
	/**
	 * Recargar un shader específico
	 */
	public static function reloadShader(shaderName:String):Bool
	{
		if (shaders.exists(shaderName))
		{
			shaders.remove(shaderName);
			trace('[ShaderManager] Shader "$shaderName" descargado, recargando...');
		}
		
		return loadShader(shaderName) != null;
	}
	
	/**
	 * Recargar todos los shaders
	 */
	public static function reloadAllShaders():Void
	{
		trace('[ShaderManager] Recargando todos los shaders...');
		shaders.clear();
		scanShaders();
		trace('[ShaderManager] ${Lambda.count(shaderPaths)} shaders disponibles tras recarga');
	}
	
	/**
	 * Limpiar todos los shaders
	 */
	public static function clear():Void
	{
		for (shader in shaders)
			shader.destroy();
		
		shaders.clear();
		shaderPaths.clear();
		trace('[ShaderManager] Shaders limpiados');
	}
}

/**
 * Wrapper para un shader personalizado
 */
class CustomShader
{
	public var name:String;
	public var shader:FlxShader;
	public var fragmentCode:String;
	
	public function new(name:String, fragmentCode:String)
	{
		this.name = name;
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
	
	/**
	 * Establecer parámetro del shader
	 */
	public function setParam(paramName:String, value:Dynamic):Bool
	{
		if (shader == null)
			return false;
		
		try
		{
			// Acceder a los uniforms del shader
			var param = Reflect.getProperty(shader.data, paramName);
			
			if (param != null)
			{
				if (Std.isOfType(param, ShaderParameter))
				{
					var shaderParam:ShaderParameter<Dynamic> = cast param;
					shaderParam.value = value;
					trace('[CustomShader] Parámetro "$paramName" establecido en shader "$name"');
					return true;
				}
				else
				{
					// Intentar establecer directamente
					Reflect.setProperty(shader.data, paramName, value);
					trace('[CustomShader] Propiedad "$paramName" establecida en shader "$name"');
					return true;
				}
			}
			else
			{
				trace('[CustomShader] Parámetro "$paramName" no encontrado en shader "$name"');
				return false;
			}
		}
		catch (e:Exception)
		{
			trace('[CustomShader] Error al establecer parámetro "$paramName": ${e.message}');
			return false;
		}
	}
	
	/**
	 * Obtener parámetro del shader
	 */
	public function getParam(paramName:String):Dynamic
	{
		if (shader == null)
			return null;
		
		try
		{
			var param = Reflect.getProperty(shader.data, paramName);
			
			if (param != null && Std.isOfType(param, ShaderParameter))
			{
				var shaderParam:ShaderParameter<Dynamic> = cast param;
				return shaderParam.value;
			}
			
			return param;
		}
		catch (e:Exception)
		{
			trace('[CustomShader] Error al obtener parámetro "$paramName": ${e.message}');
			return null;
		}
	}
	
	/**
	 * Destruir shader
	 */
	public function destroy():Void
	{
		shader = null;
		fragmentCode = null;
	}
}
