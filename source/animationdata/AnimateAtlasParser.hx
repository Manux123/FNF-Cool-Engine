package animationdata;

import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.FlxGraphic;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import openfl.display.BitmapData;
import openfl.geom.Matrix;
import openfl.geom.Rectangle;
import openfl.geom.Point;
import haxe.Json;
import lime.utils.Assets;

import animationdata.AdobeAnimateAnimationParser;
import animationdata.AdobeAnimateAtlasParser;

using StringTools;

/**
 * AnimateAtlas - Versión mejorada con correcciones para sprites faltantes y transformaciones
 */
class AnimateAtlasParser
{
	/**
	 * Parsea Adobe Animate y crea frames compuestos para cada símbolo
	 * @return FlxAtlasFrames con todos los símbolos como frames individuales
	 */
	public static function parseAnimateAtlas(
		animationJsonPath:String,
		atlasJsonPath:String,
		frameWidth:Int = 500,
		frameHeight:Int = 500
	):FlxAtlasFrames
	{
		try
		{
			trace("Parseando AnimateAtlas...");
			
			// Cargar atlas de sprites
			var atlasFrames = AdobeAnimateAtlasParser.parse(atlasJsonPath);
			if (atlasFrames == null)
			{
				trace("Error: No se pudo cargar atlas");
				return null;
			}
			
			// Cargar datos de animación
			var animData = AdobeAnimateAnimationParser.parse(animationJsonPath);
			if (animData == null)
			{
				trace("Error: No se pudieron cargar animaciones");
				return null;
			}
			
			trace("Símbolos encontrados: " + Lambda.count(animData));
			
			// Calcular total de frames para dimensionar el spritesheet
			var totalFrames = 0;
			for (symbol in animData)
			{
				var frames:Array<Dynamic> = cast symbol.frames;
				var uniqueFrames = new Map<Int, Bool>();
				for (frame in frames)
					uniqueFrames.set(frame.frameIndex, true);
				totalFrames += Lambda.count(uniqueFrames);
			}
			
			// Crear spritesheet con grid
			var cols = Math.ceil(Math.sqrt(totalFrames));
			var rows = Math.ceil(totalFrames / cols);
			var sheetWidth = Std.int(cols * frameWidth);
			var sheetHeight = Std.int(rows * frameHeight);
			
			trace("Creando spritesheet: " + sheetWidth + "x" + sheetHeight + " (cols: " + cols + ", rows: " + rows + ")");
			
			var spritesheet = new BitmapData(sheetWidth, sheetHeight, true, 0x00000000);
			var composedGraphic = FlxGraphic.fromBitmapData(spritesheet, false, "animateatlas");
			var composedFrames = new FlxAtlasFrames(composedGraphic);
			
			var globalFrameIndex = 0;
			
			// Procesar cada símbolo (animación)
			for (symbolName in animData.keys())
			{
				var symbol = animData.get(symbolName);
				var frames:Array<Dynamic> = cast symbol.frames;
				
				// Agrupar frames por índice
				var frameGroups = new Map<Int, Array<Dynamic>>();
				for (frame in frames)
				{
					if (!frameGroups.exists(frame.frameIndex))
						frameGroups.set(frame.frameIndex, []);
					frameGroups.get(frame.frameIndex).push(frame);
				}
				
				// Ordenar índices de frames
				var sortedIndices:Array<Int> = [];
				for (idx in frameGroups.keys())
					sortedIndices.push(idx);
				sortedIndices.sort(function(a, b) return a - b);
				
				// Componer cada frame del símbolo
				for (frameIdx in sortedIndices)
				{
					var sprites = frameGroups.get(frameIdx);
					
					// Ordenar por profundidad (fondo primero)
					sprites.sort(function(a, b) {
						var depthA = a.layerDepth != null ? a.layerDepth : 0;
						var depthB = b.layerDepth != null ? b.layerDepth : 0;
						return depthA - depthB;
					});
					
					// Calcular posición en spritesheet
					var col = globalFrameIndex % cols;
					var row = Math.floor(globalFrameIndex / cols);
					var sheetX = col * frameWidth;
					var sheetY = row * frameHeight;
					
					// Crear bitmap del frame
					var frameBitmap = new BitmapData(frameWidth, frameHeight, true, 0x00000000);
					
					// MEJORA: Validar que todos los sprites existan antes de renderizar
					var allSpritesValid = true;
					for (sprite in sprites)
					{
						if (sprite.spriteName != null)
						{
							var atlasFrame = atlasFrames.getByName(sprite.spriteName);
							if (atlasFrame == null)
							{
								trace("Advertencia: Sprite no encontrado para frame " + frameIdx + " de " + symbolName + ": " + sprite.spriteName);
								allSpritesValid = false;
							}
						}
					}
					
					// Renderizar todos los sprites del frame (incluso si faltan algunos)
					var renderedCount = 0;
					for (sprite in sprites)
					{
						if (renderSprite(frameBitmap, sprite, atlasFrames, frameWidth, frameHeight))
							renderedCount++;
					}
					
					if (renderedCount == 0 && sprites.length > 0)
					{
						trace("Advertencia: No se renderizó ningún sprite para frame " + frameIdx + " de " + symbolName);
					}
					
					// Copiar al spritesheet
					spritesheet.copyPixels(
						frameBitmap,
						frameBitmap.rect,
						new Point(sheetX, sheetY),
						null,
						null,
						true
					);
					
					// Agregar frame con nombre: "SymbolName####"
					// Formato similar a Sparrow Atlas
					var frameName = symbolName + StringTools.lpad(Std.string(frameIdx), "0", 4);
					composedFrames.addAtlasFrame(
						FlxRect.get(sheetX, sheetY, frameWidth, frameHeight),
						FlxPoint.get(frameWidth, frameHeight),
						FlxPoint.get(0, 0),
						frameName
					);
					
					frameBitmap.dispose();
					globalFrameIndex++;
				}
				
				trace("Símbolo compuesto: " + symbolName + " (" + sortedIndices.length + " frames)");
			}
			
			trace("AnimateAtlas parseado exitosamente: " + globalFrameIndex + " frames totales");
			return composedFrames;
		}
		catch (e:Dynamic)
		{
			trace("Error parseando AnimateAtlas: " + e);
			#if debug
			trace(haxe.CallStack.toString(haxe.CallStack.exceptionStack()));
			#end
			return null;
		}
	}
	
	/**
	 * Renderiza un sprite individual en el frame
	 * @return true si se renderizó exitosamente, false si hubo error
	 */
	private static function renderSprite(
		target:BitmapData,
		sprite:Dynamic,
		atlasFrames:FlxAtlasFrames,
		canvasWidth:Int,
		canvasHeight:Int
	):Bool
	{
		// MEJORA: Validar que el sprite tenga nombre
		if (sprite.spriteName == null)
		{
			trace("Advertencia: Sprite sin nombre");
			return false;
		}
		
		var atlasFrame = atlasFrames.getByName(sprite.spriteName);
		if (atlasFrame == null)
		{
			// Ya no trazamos aquí porque se hace antes
			return false;
		}
		
		// MEJORA: Validar dimensiones del frame
		if (atlasFrame.frame.width <= 0 || atlasFrame.frame.height <= 0)
		{
			trace("Advertencia: Frame con dimensiones inválidas: " + sprite.spriteName);
			return false;
		}
		
		// Extraer bitmap del sprite
		var spriteRect = new Rectangle(
			atlasFrame.frame.x,
			atlasFrame.frame.y,
			atlasFrame.frame.width,
			atlasFrame.frame.height
		);
		
		var spriteBitmap = new BitmapData(
			Std.int(atlasFrame.frame.width),
			Std.int(atlasFrame.frame.height),
			true,
			0x00000000
		);
		
		try
		{
			spriteBitmap.copyPixels(
				atlasFrames.parent.bitmap,
				spriteRect,
				new Point(0, 0),
				null,
				null,
				true
			);
		}
		catch (e:Dynamic)
		{
			trace("Error copiando pixels de " + sprite.spriteName + ": " + e);
			spriteBitmap.dispose();
			return false;
		}
		
		// MEJORA: Aplicar transformaciones con validación
		var matrix = new Matrix();
		
		// Extraer valores con defaults seguros
		var x:Float = sprite.x != null ? sprite.x : 0;
		var y:Float = sprite.y != null ? sprite.y : 0;
		var scaleX:Float = sprite.scaleX != null ? sprite.scaleX : 1.0;
		var scaleY:Float = sprite.scaleY != null ? sprite.scaleY : 1.0;
		var rotation:Float = sprite.rotation != null ? sprite.rotation : 0;
		
		// MEJORA: Validar escalas para evitar valores extremos que hagan desaparecer sprites
		if (Math.abs(scaleX) < 0.001) scaleX = 0.001;
		if (Math.abs(scaleY) < 0.001) scaleY = 0.001;
		if (Math.abs(scaleX) > 100) scaleX = 100;
		if (Math.abs(scaleY) > 100) scaleY = 100;
		
		// Aplicar escala
		if (scaleX != 1.0 || scaleY != 1.0)
			matrix.scale(scaleX, scaleY);
		
		// Aplicar rotación
		if (rotation != 0)
			matrix.rotate(rotation * Math.PI / 180);
		
		// MEJORA: Calcular centro del canvas de forma más precisa
		var centerX = canvasWidth / 2;
		var centerY = canvasHeight / 2;
		
		// Aplicar traslación
		matrix.translate(x + centerX, y + centerY);
		
		// MEJORA: Usar un try-catch para el draw por si la transformación causa problemas
		try
		{
			target.draw(spriteBitmap, matrix, null, null, null, true);
		}
		catch (e:Dynamic)
		{
			trace("Error dibujando sprite " + sprite.spriteName + ": " + e);
			spriteBitmap.dispose();
			return false;
		}
		
		spriteBitmap.dispose();
		return true;
	}
	
	/**
	 * NUEVA FUNCIÓN: Verificar integridad de sprites antes de parsear
	 */
	public static function validateSprites(
		animationJsonPath:String,
		atlasJsonPath:String
	):Map<String, Array<String>>
	{
		var missingSprites = new Map<String, Array<String>>();
		
		try
		{
			var atlasFrames = AdobeAnimateAtlasParser.parse(atlasJsonPath);
			if (atlasFrames == null) return missingSprites;
			
			var animData = AdobeAnimateAnimationParser.parse(animationJsonPath);
			if (animData == null) return missingSprites;
			
			for (symbolName in animData.keys())
			{
				var symbol = animData.get(symbolName);
				var frames:Array<Dynamic> = cast symbol.frames;
				var missing:Array<String> = [];
				
				for (frame in frames)
				{
					if (frame.spriteName != null)
					{
						var atlasFrame = atlasFrames.getByName(frame.spriteName);
						if (atlasFrame == null && missing.indexOf(frame.spriteName) == -1)
						{
							missing.push(frame.spriteName);
						}
					}
				}
				
				if (missing.length > 0)
				{
					missingSprites.set(symbolName, missing);
				}
			}
		}
		catch (e:Dynamic)
		{
			trace("Error validando sprites: " + e);
		}
		
		return missingSprites;
	}
}