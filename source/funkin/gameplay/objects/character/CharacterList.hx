package funkin.gameplay.objects.character;

import haxe.Json;
import lime.utils.Assets;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

/**
 * Lista dinámica de personajes y stages
 * Detecta automáticamente los archivos .json en las carpetas
 */
class CharacterList
{
    // Listas que se llenan automáticamente
    public static var boyfriends:Array<String> = [];
    public static var opponents:Array<String> = [];
    public static var girlfriends:Array<String> = [];
    public static var stages:Array<String> = [];
    
    // Nombres legibles (se llenan desde los JSONs)
    public static var characterNames:Map<String, String> = new Map<String, String>();
    public static var stageNames:Map<String, String> = new Map<String, String>();
    
    // Flag de inicialización
    private static var initialized:Bool = false;
    
    /**
     * Inicializa las listas de personajes y stages
     * Debe llamarse una vez al inicio
     */
    public static function init():Void
    {
        if (initialized) return;
        
        trace("Initializing CharacterList...");
        
        // Detectar personajes
        discoverCharacters();
        
        // Detectar stages
        discoverStages();
        
        // Agregar defaults si no se encontraron
        ensureDefaults();
        
        initialized = true;
        trace('CharacterList initialized:');
        trace('  - Boyfriends: ${boyfriends.length}');
        trace('  - Opponents: ${opponents.length}');
        trace('  - Girlfriends: ${girlfriends.length}');
        trace('  - Stages: ${stages.length}');
    }
    
    /**
     * Detecta todos los personajes en assets/characters/
     */
    private static function discoverCharacters():Void
    {
        var charactersPath:String = "assets/characters";
        
        #if sys
        // En desktop, leer directamente del filesystem
        if (FileSystem.exists(charactersPath) && FileSystem.isDirectory(charactersPath))
        {
            for (file in FileSystem.readDirectory(charactersPath))
            {
                if (file.endsWith(".json"))
                {
                    var charName:String = file.replace(".json", "");
                    var fullPath:String = '$charactersPath/$file';
                    
                    try
                    {
                        var jsonContent:String = File.getContent(fullPath);
                        var charData:Dynamic = Json.parse(jsonContent);
                        
                        // Determinar tipo de personaje
                        addCharacterToList(charName, charData);
                        
                        // Guardar nombre legible si existe
                        if (charData.name != null)
                            characterNames.set(charName, charData.name);
                        else
                            characterNames.set(charName, formatName(charName));
                    }
                    catch (e:Dynamic)
                    {
                        trace('Error loading character $charName: $e');
                        // Agregar de todas formas con nombre formateado
                        characterNames.set(charName, formatName(charName));
                        addCharacterToListByName(charName);
                    }
                }
            }
        }
        #else
        // En HTML5/web, usar Assets
        var allAssets:Array<String> = Assets.list();
        for (asset in allAssets)
        {
            if (asset.contains("characters/") && asset.endsWith(".json"))
            {
                var charName:String = asset.split("/").pop().replace(".json", "");
                
                try
                {
                    var jsonContent:String = Assets.getText(asset);
                    var charData:Dynamic = Json.parse(jsonContent);
                    
                    addCharacterToList(charName, charData);
                    
                    if (charData.name != null)
                        characterNames.set(charName, charData.name);
                    else
                        characterNames.set(charName, formatName(charName));
                }
                catch (e:Dynamic)
                {
                    trace('Error loading character $charName: $e');
                    characterNames.set(charName, formatName(charName));
                    addCharacterToListByName(charName);
                }
            }
        }
        #end
    }
    
    /**
     * Detecta todos los stages en assets/stages/
     */
    private static function discoverStages():Void
    {
        var stagesPath:String = "assets/stages";
        
        #if sys
        // En desktop, leer directamente del filesystem
        if (FileSystem.exists(stagesPath) && FileSystem.isDirectory(stagesPath))
        {
            for (file in FileSystem.readDirectory(stagesPath))
            {
                if (file.endsWith(".json"))
                {
                    var stageName:String = file.replace(".json", "");
                    var fullPath:String = '$stagesPath/$file';
                    
                    try
                    {
                        var jsonContent:String = File.getContent(fullPath);
                        var stageData:Dynamic = Json.parse(jsonContent);
                        
                        stages.push(stageName);
                        
                        // Guardar nombre legible si existe
                        if (stageData.name != null)
                            stageNames.set(stageName, stageData.name);
                        else
                            stageNames.set(stageName, formatName(stageName));
                    }
                    catch (e:Dynamic)
                    {
                        trace('Error loading stage $stageName: $e');
                        stages.push(stageName);
                        stageNames.set(stageName, formatName(stageName));
                    }
                }
            }
        }
        #else
        // En HTML5/web, usar Assets
        var allAssets:Array<String> = Assets.list();
        for (asset in allAssets)
        {
            if (asset.contains("stages/") && asset.endsWith(".json"))
            {
                var stageName:String = asset.split("/").pop().replace(".json", "");
                
                try
                {
                    var jsonContent:String = Assets.getText(asset);
                    var stageData:Dynamic = Json.parse(jsonContent);
                    
                    stages.push(stageName);
                    
                    if (stageData.name != null)
                        stageNames.set(stageName, stageData.name);
                    else
                        stageNames.set(stageName, formatName(stageName));
                }
                catch (e:Dynamic)
                {
                    trace('Error loading stage $stageName: $e');
                    stages.push(stageName);
                    stageNames.set(stageName, formatName(stageName));
                }
            }
        }
        #end
        
        // Si no se encontraron stages, usar detección por nombre de archivo
        if (stages.length == 0)
        {
            trace("No stage JSONs found, using fallback detection...");
            detectStagesByNaming();
        }
    }
    
    /**
     * Agrega un personaje a la lista correcta basándose en su JSON
     */
    private static function addCharacterToList(charName:String, charData:Dynamic):Void
    {
        // Detectar tipo por nombre o por campo en JSON
        var type:String = null;
        
        if (charData.type != null)
            type = charData.type.toLowerCase();
        else
            type = detectCharacterType(charName);
        
        switch (type)
        {
            case "boyfriend" | "bf":
                if (!boyfriends.contains(charName))
                    boyfriends.push(charName);
            case "girlfriend" | "gf":
                if (!girlfriends.contains(charName))
                    girlfriends.push(charName);
            case "opponent" | "dad":
                if (!opponents.contains(charName))
                    opponents.push(charName);
            default:
                // Si no está especificado, usar detección por nombre
                addCharacterToListByName(charName);
        }
    }
    
    /**
     * Agrega un personaje basándose solo en su nombre
     */
    private static function addCharacterToListByName(charName:String):Void
    {
        var lowerName:String = charName.toLowerCase();
        
        if (lowerName.contains("bf") || lowerName.contains("boyfriend"))
        {
            if (!boyfriends.contains(charName))
                boyfriends.push(charName);
        }
        else if (lowerName.contains("gf") || lowerName.contains("girlfriend"))
        {
            if (!girlfriends.contains(charName))
                girlfriends.push(charName);
        }
        else
        {
            // Por defecto, es un oponente
            if (!opponents.contains(charName))
                opponents.push(charName);
        }
    }
    
    /**
     * Detecta el tipo de personaje por su nombre
     */
    private static function detectCharacterType(charName:String):String
    {
        var lowerName:String = charName.toLowerCase();
        
        if (lowerName.contains("bf") || lowerName.contains("boyfriend"))
            return "boyfriend";
        else if (lowerName.contains("gf") || lowerName.contains("girlfriend"))
            return "girlfriend";
        else
            return "opponent";
    }
    
    /**
     * Detecta stages por nombres de archivo comunes (fallback)
     */
    private static function detectStagesByNaming():Void
    {
        var commonStages:Array<String> = [
            'stage',
            'stage_week1',
            'spooky',
            'philly',
            'limo',
            'mall',
            'mallEvil',
            'school',
            'schoolEvil',
            'tank'
        ];
        
        for (stageName in commonStages)
        {
            #if sys
            if (FileSystem.exists('assets/stages/$stageName.json'))
            {
                stages.push(stageName);
                stageNames.set(stageName, formatName(stageName));
            }
            #else
            if (Assets.exists('assets/stages/$stageName.json'))
            {
                stages.push(stageName);
                stageNames.set(stageName, formatName(stageName));
            }
            #end
        }
    }
    
    /**
     * Asegura que existan personajes y stages por defecto
     */
    private static function ensureDefaults():Void
    {
        // Defaults de Boyfriends
        if (boyfriends.length == 0)
        {
            boyfriends = ['bf', 'bf-pixel', 'bf-car', 'bf-christmas'];
            for (bf in boyfriends)
                characterNames.set(bf, formatName(bf));
        }
        
        // Defaults de Opponents
        if (opponents.length == 0)
        {
            opponents = ['dad', 'spooky', 'pico', 'mom', 'monster', 'senpai', 'spirit'];
            for (opp in opponents)
                characterNames.set(opp, formatName(opp));
        }
        
        // Defaults de Girlfriends
        if (girlfriends.length == 0)
        {
            girlfriends = ['gf', 'gf-pixel', 'gf-car', 'gf-christmas'];
            for (gf in girlfriends)
                characterNames.set(gf, formatName(gf));
        }
        
        // Defaults de Stages
        if (stages.length == 0)
        {
            stages = ['stage_week1', 'spooky', 'philly', 'limo', 'mall', 'mallEvil', 'school', 'schoolEvil'];
            for (stage in stages)
                stageNames.set(stage, formatName(stage));
        }
        
        // Ordenar alfabéticamente
        boyfriends.sort((a, b) -> a.toLowerCase() < b.toLowerCase() ? -1 : 1);
        opponents.sort((a, b) -> a.toLowerCase() < b.toLowerCase() ? -1 : 1);
        girlfriends.sort((a, b) -> a.toLowerCase() < b.toLowerCase() ? -1 : 1);
        stages.sort((a, b) -> a.toLowerCase() < b.toLowerCase() ? -1 : 1);
    }
    
    /**
     * Formatea un nombre de archivo a nombre legible
     * Ejemplo: "bf-pixel" -> "Bf Pixel"
     */
    private static function formatName(name:String):String
    {
        // Reemplazar guiones y guiones bajos con espacios
        var formatted:String = name.replace("-", " ").replace("_", " ");
        
        // Capitalizar primera letra de cada palabra
        var words:Array<String> = formatted.split(" ");
        var result:String = "";
        
        for (i in 0...words.length)
        {
            if (words[i].length > 0)
            {
                var word:String = words[i];
                word = word.charAt(0).toUpperCase() + word.substr(1);
                result += (i > 0 ? " " : "") + word;
            }
        }
        
        return result;
    }
    
    /**
     * Obtiene el nombre legible de un personaje
     */
    public static function getCharacterName(char:String):String
    {
        if (!initialized) init();
        
        if (characterNames.exists(char))
            return characterNames.get(char);
        return formatName(char);
    }
    
    /**
     * Obtiene el nombre legible de un stage
     */
    public static function getStageName(stage:String):String
    {
        if (!initialized) init();
        
        if (stageNames.exists(stage))
            return stageNames.get(stage);
        return formatName(stage);
    }
    
    /**
     * Obtiene el stage por defecto para una canción (basado en nombres comunes)
     */
    public static function getDefaultStageForSong(songName:String):String
    {
        if (!initialized) init();
        
        songName = songName.toLowerCase();
        
        // Mapeo conocido de canciones a stages
        var songToStage:Map<String, String> = [
            'bopeebo' => 'stage_week1',
            'fresh' => 'stage_week1',
            'dadbattle' => 'stage_week1',
            'test' => 'stage_week1',
            
            'spookeez' => 'spooky',
            'south' => 'spooky',
            'monster' => 'spooky',
            
            'pico' => 'philly',
            'philly' => 'philly',
            'blammed' => 'philly',
            
            'milf' => 'limo',
            'satin-panties' => 'limo',
            'high' => 'limo',
            
            'cocoa' => 'mall',
            'eggnog' => 'mall',
            
            'winter-horrorland' => 'mallEvil',
            
            'senpai' => 'school',
            'roses' => 'school',
            
            'thorns' => 'schoolEvil'
        ];
        
        if (songToStage.exists(songName))
        {
            var stage = songToStage.get(songName);
            if (stages.contains(stage))
                return stage;
        }
        
        // Fallback al primer stage disponible o 'stage_week1'
        if (stages.length > 0)
            return stages[0];
        return 'stage_week1';
    }
    
    /**
     * Obtiene la GF por defecto para un stage
     */
    public static function getDefaultGFForStage(stage:String):String
    {
        if (!initialized) init();
        
        stage = stage.toLowerCase();
        
        // Mapeo conocido de stages a GFs
        if (stage.contains("limo"))
            return girlfriends.contains('gf-car') ? 'gf-car' : girlfriends[0];
        else if (stage.contains("mall"))
            return girlfriends.contains('gf-christmas') ? 'gf-christmas' : girlfriends[0];
        else if (stage.contains("school"))
            return girlfriends.contains('gf-pixel') ? 'gf-pixel' : girlfriends[0];
        
        // Fallback a primera GF o 'gf'
        if (girlfriends.length > 0)
            return girlfriends[0];
        return 'gf';
    }
    
    /**
     * Devuelve TODOS los personajes (bf + opponents + gf) en una sola lista ordenada.
     * Útil para dropdowns que no distinguen por tipo (ej. AnimationDebug).
     */
    public static function getAllCharacters():Array<String>
    {
        if (!initialized) init();

        var all:Array<String> = [];

        for (c in boyfriends)
            if (!all.contains(c)) all.push(c);
        for (c in opponents)
            if (!all.contains(c)) all.push(c);
        for (c in girlfriends)
            if (!all.contains(c)) all.push(c);

        all.sort((a, b) -> a.toLowerCase() < b.toLowerCase() ? -1 : 1);
        return all;
    }

    /**
     * Recarga las listas (útil si se agregan personajes en runtime)
     */
    public static function reload():Void
    {
        boyfriends = [];
        opponents = [];
        girlfriends = [];
        stages = [];
        characterNames = new Map<String, String>();
        stageNames = new Map<String, String>();
        initialized = false;
        init();
    }
}
