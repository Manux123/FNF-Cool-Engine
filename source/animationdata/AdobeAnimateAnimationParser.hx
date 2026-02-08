package animationdata;

import haxe.Json;
import lime.utils.Assets;

using StringTools;

/**
 * Estructura de datos para una animación de Adobe Animate
 */
typedef AdobeAnimateAnimation = 
{
	var name:String;
	var frames:Array<AdobeAnimateFrame>;
	var framerate:Float;
	var looped:Bool;
}

/**
 * Estructura de frame con información de sprite y transformación
 */
typedef AdobeAnimateFrame = 
{
	var frameIndex:Int;
	var spriteName:String;
	var duration:Int;
	@:optional var x:Float;
	@:optional var y:Float;
	@:optional var scaleX:Float;
	@:optional var scaleY:Float;
	@:optional var rotation:Float;
	@:optional var layerDepth:Int; // Para ordenar las piezas correctamente
}

/**
 * Definición de símbolo con sus capas
 */
typedef SymbolDefinition = 
{
	var name:String;
	var layers:Array<LayerData>;
}

/**
 * Datos de una capa
 */
typedef LayerData = 
{
	var name:String;
	var frames:Array<Dynamic>;
}

/**
 * Parser optimizado para animaciones de Adobe Animate
 * Lee el formato JSON exportado por Adobe Animate (Animation.json)
 * Soporta símbolos anidados y múltiples capas
 */
class AdobeAnimateAnimationParser
{
	// Cache de definiciones de símbolos
	private static var symbolCache:Map<String, SymbolDefinition>;
	
	/**
	 * Parsea un archivo de animaciones de Adobe Animate
	 * @param jsonPath Ruta al archivo Animation.json
	 * @return Map<String, AdobeAnimateAnimation> con todas las animaciones encontradas
	 */
	public static function parse(jsonPath:String):Map<String, AdobeAnimateAnimation>
	{
		var animations = new Map<String, AdobeAnimateAnimation>();
		symbolCache = new Map<String, SymbolDefinition>();
		
		try
		{
			var jsonContent:String = Assets.getText(jsonPath);
			// Quitar BOM si existe
			if (jsonContent.length > 0 && jsonContent.charCodeAt(0) == 65279)
				jsonContent = jsonContent.substr(1);
			
			var animData:Dynamic = Json.parse(jsonContent);
			
			// Obtener framerate global
			var framerate:Float = 24.0; // Default
			if (animData.MD != null && animData.MD.FRT != null)
				framerate = animData.MD.FRT;
			
			// PASO 1: Parsear definiciones de símbolos (SD)
			if (animData.SD != null && animData.SD.S != null)
			{
				parseSymbolDefinitions(animData.SD.S);
			}
			
			// PASO 2: Parsear animación principal (AN)
			if (animData.AN != null)
			{
				var mainAnims = parseMainAnimation(animData.AN, framerate);
				for (anim in mainAnims)
					animations.set(anim.name, anim);
			}
			
			trace("Animaciones parseadas: " + Lambda.count(animations));
			
			return animations;
		}
		catch (e:Dynamic)
		{
			trace("Error parseando animaciones de Adobe Animate: " + e);
			return animations;
		}
	}
	
	/**
	 * Parsea las definiciones de símbolos
	 */
	private static function parseSymbolDefinitions(symbols:Array<Dynamic>):Void
	{
		for (symbolData in symbols)
		{
			if (symbolData.SN == null)
				continue;
			
			var symbolName:String = symbolData.SN;
			var layers:Array<LayerData> = [];
			
			if (symbolData.TL != null && symbolData.TL.L != null)
			{
				var layersArray:Array<Dynamic> = symbolData.TL.L;
				
				for (layer in layersArray)
				{
					var layerName:String = layer.LN != null ? layer.LN : "";
					var frames:Array<Dynamic> = layer.FR != null ? layer.FR : [];
					
					layers.push({
						name: layerName,
						frames: frames
					});
				}
			}
			
			symbolCache.set(symbolName, {
				name: symbolName,
				layers: layers
			});
		}
		
		trace("Símbolos cacheados: " + Lambda.count(symbolCache));
	}
	
	/**
	 * Parsea la animación principal que contiene referencias a símbolos
	 */
	private static function parseMainAnimation(mainAnim:Dynamic, framerate:Float):Array<AdobeAnimateAnimation>
	{
		var animations:Array<AdobeAnimateAnimation> = [];
		
		if (mainAnim.TL == null || mainAnim.TL.L == null)
			return animations;
		
		var layers:Array<Dynamic> = mainAnim.TL.L;
		
		// La animación principal típicamente tiene una capa con múltiples símbolos
		// Cada símbolo representa una animación diferente
		for (layer in layers)
		{
			if (layer.FR == null)
				continue;
			
			var frames:Array<Dynamic> = layer.FR;
			
			for (frameData in frames)
			{
				if (frameData.E == null)
					continue;
				
				var elements:Array<Dynamic> = frameData.E;
				
				for (element in elements)
				{
					// Buscar referencias a símbolos (SI)
					if (element.SI != null && element.SI.SN != null)
					{
						var symbolName:String = element.SI.SN;
						
						// Expandir el símbolo a una animación completa
						var anim = expandSymbolToAnimation(symbolName, framerate, element.SI.M3D);
						
						if (anim != null)
							animations.push(anim);
					}
				}
			}
		}
		
		return animations;
	}
	
	/**
	 * Expande un símbolo a una animación completa
	 */
	private static function expandSymbolToAnimation(symbolName:String, framerate:Float, ?rootTransform:Array<Float>):AdobeAnimateAnimation
	{
		if (!symbolCache.exists(symbolName))
		{
			trace("Advertencia: Símbolo no encontrado: " + symbolName);
			return null;
		}
		
		var symbolDef = symbolCache.get(symbolName);
		var allFrames:Array<AdobeAnimateFrame> = [];
		var maxFrameIndex:Int = 0;
		
		// Procesar cada capa del símbolo
		var layerDepth:Int = symbolDef.layers.length;
		
		for (layer in symbolDef.layers)
		{
			var currentFrameIndex:Int = 0;
			
			for (frameData in layer.frames)
			{
				var frameIndex:Int = frameData.I != null ? frameData.I : currentFrameIndex;
				var duration:Int = frameData.DU != null ? frameData.DU : 1;
				
				if (frameData.E != null)
				{
					var elements:Array<Dynamic> = frameData.E;
					
					for (element in elements)
					{
						var animFrame:AdobeAnimateFrame = null;
						
						// Manejar Symbol Instance (SI) - sub-símbolos o movieclips
						if (element.SI != null)
						{
							var subSymbolName:String = element.SI.SN;
							var transform:Dynamic = element.SI.M3D;
							var firstFrame:Int = element.SI.FF != null ? element.SI.FF : 0;
							
							// Si es un sub-símbolo definido, expandirlo recursivamente
							if (symbolCache.exists(subSymbolName))
							{
								// Expandir sub-símbolo (simplificado - tomar primer frame)
								var subFrames = expandSymbolFrames(subSymbolName, firstFrame);
								
								for (subFrame in subFrames)
								{
									var combinedFrame:AdobeAnimateFrame = {
										frameIndex: frameIndex,
										spriteName: subFrame.spriteName,
										duration: duration,
										layerDepth: layerDepth
									};
									
									// Combinar transformaciones
									if (transform != null)
									{
										var matrix:Array<Float> = cast transform;
										if (matrix.length >= 16)
										{
											combinedFrame.x = matrix[12] + (subFrame.x != null ? subFrame.x : 0);
											combinedFrame.y = matrix[13] + (subFrame.y != null ? subFrame.y : 0);
											combinedFrame.scaleX = matrix[0] * (subFrame.scaleX != null ? subFrame.scaleX : 1.0);
											combinedFrame.scaleY = matrix[5] * (subFrame.scaleY != null ? subFrame.scaleY : 1.0);
										}
									}
									
									allFrames.push(combinedFrame);
								}
							}
							else
							{
								// Es un símbolo no definido, usar el nombre como sprite
								animFrame = {
									frameIndex: frameIndex,
									spriteName: subSymbolName,
									duration: duration,
									layerDepth: layerDepth
								};
								
								if (transform != null)
								{
									var matrix:Array<Float> = cast transform;
									if (matrix.length >= 16)
									{
										animFrame.x = matrix[12];
										animFrame.y = matrix[13];
										animFrame.scaleX = matrix[0];
										animFrame.scaleY = matrix[5];
									}
								}
								
								allFrames.push(animFrame);
							}
						}
						// Manejar Atlas Sprite Instance (ASI) - sprites directos del atlas
						else if (element.ASI != null)
						{
							var spriteName:String = element.ASI.N;
							var transform:Dynamic = element.ASI.M3D;
							
							animFrame = {
								frameIndex: frameIndex,
								spriteName: spriteName,
								duration: duration,
								layerDepth: layerDepth
							};
							
							if (transform != null)
							{
								var matrix:Array<Float> = cast transform;
								if (matrix.length >= 16)
								{
									animFrame.x = matrix[12];
									animFrame.y = matrix[13];
									animFrame.scaleX = matrix[0];
									animFrame.scaleY = matrix[5];
								}
							}
							
							allFrames.push(animFrame);
						}
					}
				}
				
				currentFrameIndex = frameIndex + duration;
				if (currentFrameIndex > maxFrameIndex)
					maxFrameIndex = currentFrameIndex;
			}
			
			layerDepth--; // Capas superiores tienen menor depth
		}
		
		if (allFrames.length == 0)
			return null;
		
		// Ordenar frames por índice y depth (capas de fondo primero)
		allFrames.sort(function(a, b):Int {
			if (a.frameIndex != b.frameIndex)
				return a.frameIndex - b.frameIndex;
			return b.layerDepth - a.layerDepth; // Mayor depth = más adelante
		});
		
		return {
			name: symbolName,
			frames: allFrames,
			framerate: framerate,
			looped: true
		};
	}
	
	/**
	 * Expande los frames de un símbolo (versión simplificada para sub-símbolos)
	 */
	private static function expandSymbolFrames(symbolName:String, startFrame:Int = 0):Array<AdobeAnimateFrame>
	{
		var frames:Array<AdobeAnimateFrame> = [];
		
		if (!symbolCache.exists(symbolName))
			return frames;
		
		var symbolDef = symbolCache.get(symbolName);
		
		// Tomar solo el frame especificado de la primera capa que tenga elementos
		for (layer in symbolDef.layers)
		{
			for (frameData in layer.frames)
			{
				var frameIndex:Int = frameData.I != null ? frameData.I : 0;
				
				if (frameIndex != startFrame)
					continue;
				
				if (frameData.E != null)
				{
					var elements:Array<Dynamic> = frameData.E;
					
					for (element in elements)
					{
						if (element.ASI != null)
						{
							var spriteName:String = element.ASI.N;
							var transform:Dynamic = element.ASI.M3D;
							
							var frame:AdobeAnimateFrame = {
								frameIndex: 0,
								spriteName: spriteName,
								duration: 1
							};
							
							if (transform != null)
							{
								var matrix:Array<Float> = cast transform;
								if (matrix.length >= 16)
								{
									frame.x = matrix[12];
									frame.y = matrix[13];
									frame.scaleX = matrix[0];
									frame.scaleY = matrix[5];
								}
							}
							
							frames.push(frame);
						}
					}
					
					if (frames.length > 0)
						break;
				}
			}
			
			if (frames.length > 0)
				break;
		}
		
		return frames;
	}
	
	/**
	 * Obtiene una animación específica por nombre
	 */
	public static function getAnimation(jsonPath:String, animName:String):AdobeAnimateAnimation
	{
		var animations = parse(jsonPath);
		return animations.get(animName);
	}
	
	/**
	 * Lista todas las animaciones disponibles
	 */
	public static function listAnimations(jsonPath:String):Array<String>
	{
		var animations = parse(jsonPath);
		var names:Array<String> = [];
		
		for (name in animations.keys())
			names.push(name);
		
		return names;
	}
	
	/**
	 * Convierte una animación de Adobe Animate a índices de frames para FlxAnimation
	 * Ahora maneja múltiples sprites por frame (para capas)
	 */
	public static function getFrameIndices(animation:AdobeAnimateAnimation, spriteMap:Map<String, Int>):Array<Int>
	{
		var indices:Array<Int> = [];
		
		// Agrupar frames por frameIndex
		var frameGroups = new Map<Int, Array<AdobeAnimateFrame>>();
		
		for (frame in animation.frames)
		{
			if (!frameGroups.exists(frame.frameIndex))
				frameGroups.set(frame.frameIndex, []);
			
			frameGroups.get(frame.frameIndex).push(frame);
		}
		
		// Procesar cada grupo de frames
		var sortedIndices:Array<Int> = [];
		for (idx in frameGroups.keys())
			sortedIndices.push(idx);
		
		sortedIndices.sort(function(a, b) return a - b);
		
		for (frameIdx in sortedIndices)
		{
			var group = frameGroups.get(frameIdx);
			
			// Tomar el sprite de la capa más alta (mayor layerDepth)
			group.sort(function(a, b) {
				var depthA = a.layerDepth != null ? a.layerDepth : 0;
				var depthB = b.layerDepth != null ? b.layerDepth : 0;
				return depthB - depthA;
			});
			
			var mainFrame = group[0];
			
			if (spriteMap.exists(mainFrame.spriteName))
			{
				var index = spriteMap.get(mainFrame.spriteName);
				
				// Repetir el frame según su duración
				for (i in 0...mainFrame.duration)
					indices.push(index);
			}
			else
			{
				trace("Advertencia: Sprite no encontrado en mapa: " + mainFrame.spriteName);
			}
		}
		
		return indices;
	}
	
	/**
	 * Crea un mapa de nombres de sprites a índices
	 */
	public static function createSpriteIndexMap(atlasJsonPath:String):Map<String, Int>
	{
		var map = new Map<String, Int>();
		
		try
		{
			var jsonContent:String = Assets.getText(atlasJsonPath);
			// Quitar BOM si existe
			if (jsonContent.length > 0 && jsonContent.charCodeAt(0) == 65279)
				jsonContent = jsonContent.substr(1);
			
			var atlasData:Dynamic = Json.parse(jsonContent);
			
			if (atlasData.ATLAS != null && atlasData.ATLAS.SPRITES != null)
			{
				var sprites:Array<Dynamic> = atlasData.ATLAS.SPRITES;
				var index:Int = 0;
				
				for (spriteData in sprites)
				{
					if (spriteData.SPRITE != null && spriteData.SPRITE.name != null)
					{
						map.set(spriteData.SPRITE.name, index);
						index++;
					}
				}
			}
		}
		catch (e:Dynamic)
		{
			trace("Error creando mapa de índices: " + e);
		}
		
		return map;
	}
}