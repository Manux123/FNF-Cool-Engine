package animationdata;

import haxe.Json;
import sys.io.File;
import haxe.xml.Access;

/**
 * Herramienta de diagnóstico para identificar problemas entre Animation.json y atlas de sprites
 */
class AtlasDiagnostic
{
    /**
     * Compara Animation.json con spritemap1.json y reporta diferencias
     */
    public static function diagnoseSpritemap(animJsonPath:String, spritemapJsonPath:String):Void
    {
        trace("=== DIAGNÓSTICO DE SPRITEMAP ===\n");
        
        try
        {
            // Cargar Animation.json
            var animContent = File.getContent(animJsonPath);
            var animData:Dynamic = Json.parse(animContent);
            
            // Cargar spritemap1.json
            var spritemapContent = File.getContent(spritemapJsonPath);
            var spritemapData:Dynamic = Json.parse(spritemapContent);
            
            // Obtener lista de sprites en el atlas
            var atlasSprites = new Map<String, Bool>();
            if (spritemapData.ATLAS != null && spritemapData.ATLAS.SPRITES != null)
            {
                var sprites:Array<Dynamic> = spritemapData.ATLAS.SPRITES;
                for (sprite in sprites)
                {
                    if (sprite.SPRITE != null && sprite.SPRITE.name != null)
                    {
                        atlasSprites.set(sprite.SPRITE.name, true);
                    }
                }
            }
            
            trace("Sprites encontrados en spritemap1.json: " + Lambda.count(atlasSprites));
            trace("Nombres de sprites en atlas:");
            var names:Array<String> = [];
            for (name in atlasSprites.keys())
                names.push(name);
            names.sort(function(a, b) return Std.parseInt(a) - Std.parseInt(b));
            
            var sampleCount = names.length > 10 ? 10 : names.length;
            for (i in 0...sampleCount)
            {
                trace("  - " + names[i]);
            }
            if (names.length > 10)
                trace("  ... y " + (names.length - 10) + " más\n");
            else
                trace("");
            
            // Buscar referencias de sprites en Animation.json
            var referencedSprites = new Map<String, Int>();
            var symbolCount = 0;
            
            if (animData.AN != null && animData.AN.SD != null && animData.AN.SD.S != null)
            {
                var symbols:Array<Dynamic> = animData.AN.SD.S;
                symbolCount = symbols.length;
                
                for (symbol in symbols)
                {
                    if (symbol.TL != null && symbol.TL.L != null)
                    {
                        var layers:Array<Dynamic> = symbol.TL.L;
                        for (layer in layers)
                        {
                            if (layer.FR != null)
                            {
                                var frames:Array<Dynamic> = layer.FR;
                                for (frame in frames)
                                {
                                    if (frame.E != null)
                                    {
                                        var elements:Array<Dynamic> = frame.E;
                                        for (element in elements)
                                        {
                                            // Buscar referencias ASI (Atlas Sprite Instance)
                                            if (element.ASI != null && element.ASI.N != null)
                                            {
                                                var spriteName:String = element.ASI.N;
                                                if (!referencedSprites.exists(spriteName))
                                                    referencedSprites.set(spriteName, 0);
                                                referencedSprites.set(spriteName, referencedSprites.get(spriteName) + 1);
                                            }
                                            
                                            // Buscar referencias SI (Symbol Instance)
                                            if (element.SI != null && element.SI.SN != null)
                                            {
                                                var symbolName:String = element.SI.SN;
                                                // Estos son símbolos, no sprites del atlas
                                                // Los registramos separadamente
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            trace("Símbolos encontrados en Animation.json: " + symbolCount);
            trace("Referencias a sprites del atlas: " + Lambda.count(referencedSprites));
            
            if (Lambda.count(referencedSprites) > 0)
            {
                trace("\nSprites referenciados en Animation.json:");
                var refNames:Array<String> = [];
                for (name in referencedSprites.keys())
                    refNames.push(name);
                refNames.sort(Reflect.compare);
                
                for (name in refNames)
                {
                    var count = referencedSprites.get(name);
                    var exists = atlasSprites.exists(name) ? "✓" : "✗ FALTA";
                    trace("  " + exists + " " + name + " (usado " + count + " veces)");
                }
            }
            
            // Encontrar sprites faltantes
            trace("\n=== SPRITES FALTANTES ===");
            var missingCount = 0;
            for (name in referencedSprites.keys())
            {
                if (!atlasSprites.exists(name))
                {
                    trace("  - " + name + " (usado " + referencedSprites.get(name) + " veces)");
                    missingCount++;
                }
            }
            
            if (missingCount == 0)
            {
                trace("  ¡Ninguno! Todos los sprites están presentes.");
            }
            else
            {
                trace("\nTOTAL FALTANTES: " + missingCount);
            }
            
            // Encontrar sprites no usados
            trace("\n=== SPRITES NO USADOS ===");
            var unusedCount = 0;
            for (name in atlasSprites.keys())
            {
                if (!referencedSprites.exists(name))
                {
                    if (unusedCount < 20) // Limitar salida
                        trace("  - " + name);
                    unusedCount++;
                }
            }
            
            if (unusedCount == 0)
            {
                trace("  Ninguno. Todos los sprites del atlas se usan.");
            }
            else
            {
                if (unusedCount > 20)
                    trace("  ... y " + (unusedCount - 20) + " más");
                trace("\nTOTAL NO USADOS: " + unusedCount);
            }
        }
        catch (e:Dynamic)
        {
            trace("ERROR: " + e);
            trace(haxe.CallStack.toString(haxe.CallStack.exceptionStack()));
        }
    }
    
    /**
     * Compara Animation.json con GF_assets.xml y reporta diferencias
     */
    public static function diagnoseSparrowXML(animJsonPath:String, xmlPath:String):Void
    {
        trace("=== DIAGNÓSTICO DE SPARROW XML ===\n");
        
        try
        {
            // Cargar Animation.json
            var animContent = File.getContent(animJsonPath);
            var animData:Dynamic = Json.parse(animContent);
            
            // Cargar XML
            var xmlContent = File.getContent(xmlPath);
            var xml = Xml.parse(xmlContent);
            var fast = new Access(xml.firstElement());
            
            // Obtener lista de sprites en el XML
            var atlasSprites = new Map<String, Bool>();
            for (subtexture in fast.nodes.SubTexture)
            {
                var name = subtexture.att.name;
                atlasSprites.set(name, true);
            }
            
            trace("Sprites encontrados en XML: " + Lambda.count(atlasSprites));
            trace("Nombres de sprites en XML (muestra):");
            var xmlNames:Array<String> = [];
            for (name in atlasSprites.keys())
                xmlNames.push(name);
            xmlNames.sort(Reflect.compare);
            
            for (i in 0...10)
            {
                if (i < xmlNames.length)
                    trace("  - " + xmlNames[i]);
            }
            if (xmlNames.length > 10)
                trace("  ... y " + (xmlNames.length - 10) + " más\n");
            else
                trace("");
            
            // Buscar qué tipo de nombres usa Animation.json
            var usesNumericSprites = false;
            var usesNamedSymbols = false;
            
            if (animData.AN != null && animData.AN.SD != null && animData.AN.SD.S != null)
            {
                var symbols:Array<Dynamic> = animData.AN.SD.S;
                
                for (symbol in symbols)
                {
                    if (symbol.TL != null && symbol.TL.L != null)
                    {
                        var layers:Array<Dynamic> = symbol.TL.L;
                        for (layer in layers)
                        {
                            if (layer.FR != null)
                            {
                                var frames:Array<Dynamic> = layer.FR;
                                for (frame in frames)
                                {
                                    if (frame.E != null)
                                    {
                                        var elements:Array<Dynamic> = frame.E;
                                        for (element in elements)
                                        {
                                            if (element.ASI != null) usesNumericSprites = true;
                                            if (element.SI != null) usesNamedSymbols = true;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            trace("Animation.json usa:");
            trace("  - Sprites numéricos (ASI): " + (usesNumericSprites ? "SÍ" : "NO"));
            trace("  - Símbolos nombrados (SI): " + (usesNamedSymbols ? "SÍ" : "NO"));
            
            if (usesNamedSymbols && !usesNumericSprites)
            {
                trace("\n⚠ IMPORTANTE: Animation.json usa símbolos nombrados, no sprites directos.");
                trace("Esto significa que necesitas los símbolos internos, no solo el atlas.");
                trace("Los símbolos referencian otros símbolos que a su vez referencian sprites.");
            }
        }
        catch (e:Dynamic)
        {
            trace("ERROR: " + e);
            trace(haxe.CallStack.toString(haxe.CallStack.exceptionStack()));
        }
    }
    
    public static function main():Void
    {
        // Ejemplo de uso
        trace("HERRAMIENTA DE DIAGNÓSTICO DE ATLAS\n");
        trace("Uso:");
        trace("  AtlasDiagnostic.diagnoseSpritemap('Animation.json', 'spritemap1.json')");
        trace("  AtlasDiagnostic.diagnoseSparrowXML('Animation.json', 'GF_assets.xml')");
    }
}
