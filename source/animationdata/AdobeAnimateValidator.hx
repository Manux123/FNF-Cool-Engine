package animationdata;

import haxe.Json;
import lime.utils.Assets;

using StringTools;

/**
 * Validador para archivos de Adobe Animate
 * Verifica que los archivos tengan el formato correcto antes de procesarlos
 */
class AdobeAnimateValidator
{
	/**
	 * Resultado de validación
	 */
	public static var lastError:String = "";
	
	/**
	 * Valida un archivo de atlas de Adobe Animate
	 */
	public static function validate(jsonPath:String,animationPath:String)
	{
		validateAtlas(jsonPath);
		validateAnimation(jsonPath);
		validateCompatibility(jsonPath,animationPath);
		getReferencedSprites(animationPath);
		printAtlasReport(jsonPath);
		printAnimationReport(animationPath);
	}

	public static function validateAtlas(jsonPath:String):Bool
	{
		lastError = "";
		
		try
		{
			if (!Assets.exists(jsonPath))
			{
				lastError = "El archivo no existe: " + jsonPath;
				return false;
			}
			
			var jsonContent:String = Assets.getText(jsonPath);
			
			// Quitar BOM si existe
			if (jsonContent.length > 0 && jsonContent.charCodeAt(0) == 65279)
				jsonContent = jsonContent.substr(1);
			
			var atlasData:Dynamic = Json.parse(jsonContent);
			
			// Verificar estructura ATLAS
			if (atlasData.ATLAS == null)
			{
				lastError = "Falta la estructura ATLAS en el JSON";
				return false;
			}
			
			// Verificar SPRITES
			if (atlasData.ATLAS.SPRITES == null)
			{
				lastError = "Falta ATLAS.SPRITES en el JSON";
				return false;
			}
			
			var sprites:Array<Dynamic> = atlasData.ATLAS.SPRITES;
			if (sprites.length == 0)
			{
				lastError = "No hay sprites definidos en el atlas";
				return false;
			}
			
			// Verificar metadata
			if (atlasData.meta == null)
			{
				lastError = "Falta metadata en el atlas";
				return false;
			}
			
			if (atlasData.meta.image == null || atlasData.meta.image == "")
			{
				lastError = "No se especificó la imagen del atlas en meta.image";
				return false;
			}
			
			// Verificar estructura de sprites
			var validSprites = 0;
			for (i in 0...sprites.length)
			{
				var spriteData = sprites[i];
				
				if (spriteData.SPRITE == null)
				{
					trace("Advertencia: Sprite " + i + " sin datos SPRITE");
					continue;
				}
				
				var sprite = spriteData.SPRITE;
				
				if (sprite.name == null || sprite.name == "")
				{
					trace("Advertencia: Sprite " + i + " sin nombre");
					continue;
				}
				
				if (sprite.x == null || sprite.y == null || sprite.w == null || sprite.h == null)
				{
					trace("Advertencia: Sprite " + sprite.name + " con datos incompletos");
					continue;
				}
				
				validSprites++;
			}
			
			if (validSprites == 0)
			{
				lastError = "No hay sprites válidos en el atlas";
				return false;
			}
			
			trace("Atlas validado: " + validSprites + " sprites válidos de " + sprites.length + " totales");
			return true;
		}
		catch (e:Dynamic)
		{
			lastError = "Error al validar atlas: " + e;
			return false;
		}
	}
	
	/**
	 * Valida un archivo de animaciones de Adobe Animate
	 */
	public static function validateAnimation(jsonPath:String):Bool
	{
		lastError = "";
		
		try
		{
			if (!Assets.exists(jsonPath))
			{
				lastError = "El archivo no existe: " + jsonPath;
				return false;
			}
			
			var jsonContent:String = Assets.getText(jsonPath);
			
			// Quitar BOM si existe
			if (jsonContent.length > 0 && jsonContent.charCodeAt(0) == 65279)
				jsonContent = jsonContent.substr(1);
			
			var animData:Dynamic = Json.parse(jsonContent);
			
			// Verificar metadata
			if (animData.MD == null)
			{
				lastError = "Falta metadata (MD) en el archivo de animación";
				return false;
			}
			
			if (animData.MD.FRT == null)
			{
				trace("Advertencia: No se especificó framerate, usando 24 por defecto");
			}
			
			// Verificar estructura de animación
			var hasAN = animData.AN != null;
			var hasSD = animData.SD != null;
			
			if (!hasAN && !hasSD)
			{
				lastError = "El archivo no contiene animaciones (AN) ni definiciones de símbolos (SD)";
				return false;
			}
			
			// Validar AN si existe
			if (hasAN)
			{
				if (animData.AN.TL == null || animData.AN.TL.L == null)
				{
					trace("Advertencia: AN sin timeline o capas");
				}
				else
				{
					var layers:Array<Dynamic> = animData.AN.TL.L;
					trace("AN contiene " + layers.length + " capas");
				}
			}
			
			// Validar SD si existe
			if (hasSD)
			{
				if (animData.SD.S == null)
				{
					trace("Advertencia: SD sin símbolos");
				}
				else
				{
					var symbols:Array<Dynamic> = animData.SD.S;
					trace("SD contiene " + symbols.length + " símbolos");
					
					// Validar que cada símbolo tenga nombre
					var validSymbols = 0;
					for (symbol in symbols)
					{
						if (symbol.SN != null && symbol.SN != "")
							validSymbols++;
					}
					
					if (validSymbols == 0)
					{
						lastError = "No hay símbolos válidos en SD";
						return false;
					}
					
					trace("Símbolos válidos: " + validSymbols);
				}
			}
			
			return true;
		}
		catch (e:Dynamic)
		{
			lastError = "Error al validar animación: " + e;
			return false;
		}
	}
	
	/**
	 * Valida que el atlas y las animaciones sean compatibles
	 */
	public static function validateCompatibility(atlasPath:String, animationPath:String):Bool
	{
		lastError = "";
		
		try
		{
			// Validar ambos archivos individualmente primero
			if (!validateAtlas(atlasPath))
			{
				return false;
			}
			
			if (!validateAnimation(animationPath))
			{
				return false;
			}
			
			// Obtener sprites del atlas
			var atlasSprites = AdobeAnimateAtlasParser.listSprites(atlasPath);
			var atlasSet = new Map<String, Bool>();
			for (sprite in atlasSprites)
				atlasSet.set(sprite, true);
			
			// Obtener sprites referenciados en animaciones
			var animSprites = getReferencedSprites(animationPath);
			
			// Verificar que todos los sprites referenciados existan en el atlas
			var missingSprites:Array<String> = [];
			for (sprite in animSprites)
			{
				if (!atlasSet.exists(sprite))
					missingSprites.push(sprite);
			}
			
			if (missingSprites.length > 0)
			{
				trace("Advertencia: Algunos sprites referenciados no están en el atlas:");
				for (sprite in missingSprites)
					trace("  - " + sprite);
				
				// No es error fatal, pueden ser símbolos
				trace("Estos pueden ser símbolos definidos internamente");
			}
			
			trace("Validación de compatibilidad completada");
			return true;
		}
		catch (e:Dynamic)
		{
			lastError = "Error validando compatibilidad: " + e;
			return false;
		}
	}
	
	/**
	 * Obtiene lista de sprites referenciados en el archivo de animaciones
	 */
	private static function getReferencedSprites(animationPath:String):Array<String>
	{
		var sprites:Array<String> = [];
		var spriteSet = new Map<String, Bool>();
		
		try
		{
			var jsonContent:String = Assets.getText(animationPath);
			
			// Quitar BOM si existe
			if (jsonContent.length > 0 && jsonContent.charCodeAt(0) == 65279)
				jsonContent = jsonContent.substr(1);
			
			var animData:Dynamic = Json.parse(jsonContent);
			
			// Buscar referencias ASI (Atlas Sprite Instance)
			function scanForASI(obj:Dynamic):Void
			{
				if (obj == null)
					return;
				
				if (Std.isOfType(obj, Array))
				{
					var arr:Array<Dynamic> = cast obj;
					for (item in arr)
						scanForASI(item);
				}
				else if (Reflect.isObject(obj))
				{
					// Verificar si es una instancia ASI
					if (Reflect.hasField(obj, "ASI") && Reflect.hasField(Reflect.field(obj, "ASI"), "N"))
					{
						var spriteName:String = Reflect.field(Reflect.field(obj, "ASI"), "N");
						if (!spriteSet.exists(spriteName))
						{
							spriteSet.set(spriteName, true);
							sprites.push(spriteName);
						}
					}
					
					// Escanear campos recursivamente
					for (field in Reflect.fields(obj))
					{
						scanForASI(Reflect.field(obj, field));
					}
				}
			}
			
			scanForASI(animData);
		}
		catch (e:Dynamic)
		{
			trace("Error obteniendo sprites referenciados: " + e);
		}
		
		return sprites;
	}
	
	/**
	 * Imprime un reporte detallado del atlas
	 */
	public static function printAtlasReport(atlasPath:String):Void
	{
		trace("=== REPORTE DE ATLAS ===");
		trace("Archivo: " + atlasPath);
		
		try
		{
			var jsonContent:String = Assets.getText(atlasPath);
			
			// Quitar BOM si existe
			if (jsonContent.length > 0 && jsonContent.charCodeAt(0) == 65279)
				jsonContent = jsonContent.substr(1);
			
			var atlasData:Dynamic = Json.parse(jsonContent);
			
			if (atlasData.meta != null)
			{
				trace("Imagen: " + (atlasData.meta.image != null ? atlasData.meta.image : "No especificada"));
				trace("Formato: " + (atlasData.meta.format != null ? atlasData.meta.format : "No especificado"));
				
				if (atlasData.meta.size != null)
				{
					trace("Tamaño: " + atlasData.meta.size.w + "x" + atlasData.meta.size.h);
				}
			}
			
			if (atlasData.ATLAS != null && atlasData.ATLAS.SPRITES != null)
			{
				var sprites:Array<Dynamic> = atlasData.ATLAS.SPRITES;
				trace("Total de sprites: " + sprites.length);
				
				trace("\nPrimeros 10 sprites:");
				for (i in 0...Std.int(Math.min(10, sprites.length)))
				{
					if (sprites[i].SPRITE != null)
					{
						var sprite = sprites[i].SPRITE;
						trace("  " + (i + 1) + ". " + sprite.name + " (" + sprite.w + "x" + sprite.h + ")");
					}
				}
			}
		}
		catch (e:Dynamic)
		{
			trace("Error generando reporte: " + e);
		}
		
		trace("========================");
	}
	
	/**
	 * Imprime un reporte detallado de las animaciones
	 */
	public static function printAnimationReport(animationPath:String):Void
	{
		trace("=== REPORTE DE ANIMACIONES ===");
		trace("Archivo: " + animationPath);
		
		try
		{
			var animations = AdobeAnimateAnimationParser.listAnimations(animationPath);
			trace("Total de animaciones: " + animations.length);
			
			trace("\nAnimaciones encontradas:");
			for (i in 0...animations.length)
			{
				trace("  " + (i + 1) + ". " + animations[i]);
			}
		}
		catch (e:Dynamic)
		{
			trace("Error generando reporte: " + e);
		}
		
		trace("==============================");
	}
}