package animationdata;

import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.FlxGraphic;
import flixel.math.FlxRect;
import flixel.math.FlxPoint;
import haxe.Json;
import lime.utils.Assets;

using StringTools;

/**
 * Parser optimizado para Atlas de Adobe Animate
 * Lee el formato JSON exportado por Adobe Animate y crea FlxAtlasFrames
 */
class AdobeAnimateAtlasParser
{
	/**
	 * Parsea un archivo de atlas de Adobe Animate y crea frames
	 * @param jsonPath Ruta al archivo JSON del atlas
	 * @param imagePath Ruta opcional a la imagen (si no se especifica, usa la del JSON)
	 * @return FlxAtlasFrames con todos los sprites del atlas
	 */
	public static function parse(jsonPath:String, ?imagePath:String):FlxAtlasFrames
	{
		try
		{
			trace("Iniciando parse de atlas Adobe Animate: " + jsonPath);
			
			// Cargar y parsear JSON
			var jsonContent:String = Assets.getText(jsonPath);
			
			// Quitar BOM si existe
			if (jsonContent.length > 0 && jsonContent.charCodeAt(0) == 65279) {
				jsonContent = jsonContent.substr(1);
				trace("BOM removido del JSON");
			}

			var atlasData:Dynamic = Json.parse(jsonContent);
			
			// Obtener ruta de la imagen del atlas
			var imageFile:String = imagePath;
			if (imageFile == null && atlasData.meta != null && atlasData.meta.image != null)
			{
				// Extraer directorio del JSON path
				var jsonDir = "";
				var lastSlash = jsonPath.lastIndexOf("/");
				if (lastSlash != -1)
					jsonDir = jsonPath.substring(0, lastSlash + 1);
				
				imageFile = jsonDir + atlasData.meta.image;
				trace("Imagen del atlas: " + imageFile);
			}
			
			if (imageFile == null)
			{
				trace("ERROR: No se pudo determinar la imagen del atlas");
				return null;
			}
			
			// Cargar la imagen
			var graphic:FlxGraphic = FlxGraphic.fromAssetKey(imageFile);
			if (graphic == null)
			{
				trace("ERROR: No se pudo cargar la imagen: " + imageFile);
				return null;
			}
			
			trace("Imagen cargada correctamente: " + graphic.width + "x" + graphic.height);
			
			// Crear el frame collection
			var frames:FlxAtlasFrames = FlxAtlasFrames.findFrame(graphic);
			if (frames != null)
			{
				trace("Atlas ya cargado previamente, reutilizando");
				return frames;
			}
			
			frames = new FlxAtlasFrames(graphic);
			
			// Parsear sprites del atlas
			if (atlasData.ATLAS != null && atlasData.ATLAS.SPRITES != null)
			{
				var sprites:Array<Dynamic> = atlasData.ATLAS.SPRITES;
				trace("Procesando " + sprites.length + " sprites del atlas...");
				
				var successCount:Int = 0;
				
				for (spriteData in sprites)
				{
					if (spriteData.SPRITE == null)
					{
						trace("Advertencia: Entrada de sprite sin datos SPRITE");
						continue;
					}
					
					var sprite = spriteData.SPRITE;
					
					// Validar datos del sprite
					if (sprite.name == null)
					{
						trace("Advertencia: Sprite sin nombre");
						continue;
					}
					
					// Datos del sprite con valores por defecto
					var name:String = sprite.name;
					var x:Float = sprite.x != null ? sprite.x : 0;
					var y:Float = sprite.y != null ? sprite.y : 0;
					var width:Float = sprite.w != null ? sprite.w : 0;
					var height:Float = sprite.h != null ? sprite.h : 0;
					var rotated:Bool = sprite.rotated != null ? sprite.rotated : false;
					
					// Validar dimensiones
					if (width <= 0 || height <= 0)
					{
						trace("Advertencia: Sprite con dimensiones inválidas: " + name);
						continue;
					}
					
					// Crear el frame
					var rect = FlxRect.get(x, y, width, height);
					var frameSize = FlxPoint.get(width, height);
					
					// Si el sprite está rotado, ajustar
					if (rotated)
					{
						// Adobe Animate rota 90 grados en sentido horario
						frameSize.set(height, width);
					}
					
					frames.addAtlasFrame(rect, frameSize, FlxPoint.get(0, 0), name);
					successCount++;
				}
				
				trace("Atlas cargado exitosamente: " + successCount + " sprites desde " + imageFile);
			}
			else
			{
				trace("ERROR: Formato de atlas inválido - falta ATLAS.SPRITES");
				return null;
			}
			
			return frames;
		}
		catch (e:Dynamic)
		{
			trace("ERROR parseando atlas de Adobe Animate: " + e);
			#if debug
			trace(haxe.CallStack.toString(haxe.CallStack.exceptionStack()));
			#end
			return null;
		}
	}
	
	/**
	 * Obtiene información de un sprite específico del atlas
	 * @param jsonPath Ruta al JSON del atlas
	 * @param spriteName Nombre del sprite a buscar
	 * @return Dynamic con los datos del sprite o null si no se encuentra
	 */
	public static function getSpriteInfo(jsonPath:String, spriteName:String):Dynamic
	{
		try
		{
			var jsonContent:String = Assets.getText(jsonPath);
			
			// Quitar BOM si existe
			if (jsonContent.length > 0 && jsonContent.charCodeAt(0) == 65279)
				jsonContent = jsonContent.substr(1);
			
			var atlasData:Dynamic = Json.parse(jsonContent);
			
			if (atlasData.ATLAS != null && atlasData.ATLAS.SPRITES != null)
			{
				var sprites:Array<Dynamic> = atlasData.ATLAS.SPRITES;
				
				for (spriteData in sprites)
				{
					if (spriteData.SPRITE != null && spriteData.SPRITE.name == spriteName)
						return spriteData.SPRITE;
				}
			}
			
			return null;
		}
		catch (e:Dynamic)
		{
			trace("Error obteniendo info del sprite: " + e);
			return null;
		}
	}
	
	/**
	 * Lista todos los nombres de sprites en el atlas
	 * @param jsonPath Ruta al JSON del atlas
	 * @return Array<String> con los nombres de todos los sprites
	 */
	public static function listSprites(jsonPath:String):Array<String>
	{
		var spriteNames:Array<String> = [];
		
		try
		{
			var jsonContent:String = Assets.getText(jsonPath);
			
			// Quitar BOM si existe
			if (jsonContent.length > 0 && jsonContent.charCodeAt(0) == 65279)
				jsonContent = jsonContent.substr(1);
			
			var atlasData:Dynamic = Json.parse(jsonContent);
			
			if (atlasData.ATLAS != null && atlasData.ATLAS.SPRITES != null)
			{
				var sprites:Array<Dynamic> = atlasData.ATLAS.SPRITES;
				
				for (spriteData in sprites)
				{
					if (spriteData.SPRITE != null && spriteData.SPRITE.name != null)
						spriteNames.push(spriteData.SPRITE.name);
				}
			}
			
			trace("Sprites listados: " + spriteNames.length);
		}
		catch (e:Dynamic)
		{
			trace("Error listando sprites: " + e);
		}
		
		return spriteNames;
	}
	
	/**
	 * Valida que un archivo de atlas tenga el formato correcto
	 */
	public static function validate(jsonPath:String):Bool
	{
		try
		{
			var jsonContent:String = Assets.getText(jsonPath);
			
			// Quitar BOM si existe
			if (jsonContent.length > 0 && jsonContent.charCodeAt(0) == 65279)
				jsonContent = jsonContent.substr(1);
			
			var atlasData:Dynamic = Json.parse(jsonContent);
			
			// Verificar estructura básica
			if (atlasData.ATLAS == null)
			{
				trace("Validación fallida: Falta ATLAS");
				return false;
			}
			
			if (atlasData.ATLAS.SPRITES == null)
			{
				trace("Validación fallida: Falta ATLAS.SPRITES");
				return false;
			}
			
			if (atlasData.meta == null || atlasData.meta.image == null)
			{
				trace("Validación fallida: Falta meta.image");
				return false;
			}
			
			// Verificar que haya al menos un sprite
			var sprites:Array<Dynamic> = atlasData.ATLAS.SPRITES;
			if (sprites.length == 0)
			{
				trace("Validación fallida: No hay sprites en el atlas");
				return false;
			}
			
			trace("Validación exitosa: Atlas válido con " + sprites.length + " sprites");
			return true;
		}
		catch (e:Dynamic)
		{
			trace("Error validando atlas: " + e);
			return false;
		}
	}
}