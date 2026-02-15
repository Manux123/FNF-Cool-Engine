package shaders;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.system.FlxAssets.FlxShader;
import haxe.Exception;
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
	 * Inicializar el sistema de shaders
	 */
	public static function init():Void
	{
		trace('[ShaderManager] Inicializando sistema de shaders...');
		scanShaders();
	}
	
	/**
	 * Escanear la carpeta de shaders y cargar todos los .frag
	 */
	public static function scanShaders():Void
	{
		var shadersPath = 'assets/shaders';
		
		if (!FileSystem.exists(shadersPath) || !FileSystem.isDirectory(shadersPath))
		{
			trace('[ShaderManager] Carpeta assets/shaders no encontrada. Creando...');
			try
			{
				FileSystem.createDirectory(shadersPath);
				trace('[ShaderManager] Carpeta creada: $shadersPath');
			}
			catch (e:Exception)
			{
				trace('[ShaderManager] Error al crear carpeta: ${e.message}');
			}
			return;
		}
		
		var count = 0;
		
		for (file in FileSystem.readDirectory(shadersPath))
		{
			if (file.endsWith('.frag'))
			{
				var shaderName = file.substr(0, file.length - 5); // Remover .frag
				var fullPath = '$shadersPath/$file';
				
				shaderPaths.set(shaderName, fullPath);
				trace('[ShaderManager] Shader registrado: $shaderName');
				count++;
			}
		}
		
		trace('[ShaderManager] $count shaders encontrados');
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
			
			trace('[ShaderManager] Shader "$shaderName" cargado exitosamente');
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
