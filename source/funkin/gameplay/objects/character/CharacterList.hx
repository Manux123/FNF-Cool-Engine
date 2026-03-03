package funkin.gameplay.objects.character;

import haxe.Json;
import lime.utils.Assets;
#if sys
import sys.FileSystem;
import sys.io.File;
#end
import mods.compat.ModFormat.ModFormatDetector;
import mods.compat.ModFormat;

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
     * Detecta todos los personajes en assets/characters/ y en el mod activo
     */
    private static function discoverCharacters():Void
    {
        // Rutas a escanear: primero base, luego todas las posibles del mod activo
        var charPaths:Array<String> = [Paths.resolve("characters")];

        #if sys
        final activeMod = mods.ModManager.activeMod;
        if (activeMod != null)
        {
            final modBase = '${mods.ModManager.MODS_FOLDER}/$activeMod';
            // Psych / Cool layout
            charPaths.push('$modBase/characters');
            // Codename layout
            charPaths.push('$modBase/data/characters');
        }

        for (charactersPath in charPaths)
        {
            if (!FileSystem.exists(charactersPath) || !FileSystem.isDirectory(charactersPath))
                continue;

            for (file in FileSystem.readDirectory(charactersPath))
            {
                if (!file.endsWith(".json")) continue;
                var charName:String = file.replace(".json", "");
                // Don't add duplicates already found in a previous path
                if (characterNames.exists(charName)) continue;

                var fullPath:String = '$charactersPath/$file';
                try
                {
                    var jsonContent:String = File.getContent(fullPath);
                    var charData:Dynamic = Json.parse(jsonContent);

                    // Detect format and convert if needed so we can read the type field
                    var normalised:Dynamic = charData;
                    try {
                        final fmt = ModFormatDetector.detectFromCharJson(jsonContent);
                        if (fmt == ModFormat.PSYCH_ENGINE)
                            normalised = mods.compat.PsychConverter.convertCharacter(jsonContent, charName);
                    } catch (_:Dynamic) {}

                    addCharacterToList(charName, normalised);

                    if (normalised.name != null)
                        characterNames.set(charName, normalised.name);
                    else if (charData.name != null)
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
        #else
        // En HTML5/web, usar Assets
        var allAssets:Array<String> = Assets.list();
        for (asset in allAssets)
        {
            if (asset.contains("characters/") && asset.endsWith(".json"))
            {
                var charName:String = asset.split("/").pop().replace(".json", "");
                if (characterNames.exists(charName)) continue;

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
     * Detecta todos los stages en assets/stages/ y en el mod activo
     */
    private static function discoverStages():Void
    {
        var stagePaths:Array<String> = [Paths.resolve("stages")];

        #if sys
        final activeMod = mods.ModManager.activeMod;
        if (activeMod != null)
        {
            final modBase = '${mods.ModManager.MODS_FOLDER}/$activeMod';
            stagePaths.push('$modBase/stages');
            stagePaths.push('$modBase/data/stages');
        }

        for (stagesPath in stagePaths)
        {
            if (!FileSystem.exists(stagesPath) || !FileSystem.isDirectory(stagesPath))
                continue;

            for (file in FileSystem.readDirectory(stagesPath))
            {
                if (!file.endsWith(".json")) continue;
                var stageName:String = file.replace(".json", "");
                if (stages.contains(stageName)) continue;

                var fullPath:String = '$stagesPath/$file';
                try
                {
                    var jsonContent:String = File.getContent(fullPath);
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
        #else
        // En HTML5/web, usar Assets
        var allAssets:Array<String> = Assets.list();
        for (asset in allAssets)
        {
            if (asset.contains("stages/") && asset.endsWith(".json"))
            {
                var stageName:String = asset.split("/").pop().replace(".json", "");
                if (stages.contains(stageName)) continue;

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

        // El stage correcto debe venir del metadata del chart (campo "stage"
        // en el JSON de la canción). Este método es solo el último recurso
        // cuando ningún sistema ya lo resolvió.
        // El antiguo mapa hardcodeado (bopeebo→stage_week1, senpai→school…)
        // fue eliminado: era frágil frente a mods con canciones del mismo nombre.

        // Intentar leer stage desde el stage JSON de la canción si existe
        #if sys
        final key = songName.toLowerCase();
        for (modBase in _getModBases())
        {
            for (metaName in ['$key-metadata.json', '$key-metadata-default.json', '$key-metadata-erect.json'])
            {
                final path = '$modBase/songs/$key/$metaName';
                if (sys.FileSystem.exists(path))
                {
                    try
                    {
                        final raw:Dynamic = haxe.Json.parse(sys.io.File.getContent(path));
                        final stage:String = raw?.playData?.stage ?? raw?.stage ?? null;
                        if (stage != null && stage != '') return stage;
                    }
                    catch(_) {}
                }
            }
        }
        #end

        // Fallback: primer stage disponible
        if (stages.length > 0) return stages[0];
        return 'stage_week1';
    }

    /**
     * Obtiene la GF por defecto para un stage.
     * Lee el campo "gfVersion" del JSON del stage si existe.
     * El antiguo mapeo hardcodeado (limo→gf-car, school→gf-pixel…) fue eliminado.
     */
    public static function getDefaultGFForStage(stage:String):String
    {
        if (!initialized) init();

        #if sys
        // Leer gfVersion desde el stage JSON
        final gf = _readGFFromStageJSON(stage);
        if (gf != null && gf != '') return gf;
        #end

        if (girlfriends.length > 0) return girlfriends[0];
        return 'gf';
    }

    #if sys
    /** Devuelve las bases de rutas a buscar (mod activo primero, luego assets). */
    private static function _getModBases():Array<String>
    {
        final bases:Array<String> = [];
        final activeMod = mods.ModManager.activeMod;
        if (activeMod != null)
            bases.push('${mods.ModManager.MODS_FOLDER}/$activeMod');
        bases.push('assets');
        return bases;
    }

    /** Lee el campo gfVersion del stage JSON sin construir el Stage entero. */
    private static function _readGFFromStageJSON(stageName:String):Null<String>
    {
        try
        {
            for (base in _getModBases())
            {
                for (sub in ['stages', 'data/stages'])
                {
                    final path = '$base/$sub/$stageName.json';
                    if (sys.FileSystem.exists(path))
                    {
                        final raw:Dynamic = haxe.Json.parse(sys.io.File.getContent(path));
                        final gf:String = raw?.gfVersion ?? raw?.girlfriend ?? null;
                        if (gf != null && gf != '') return gf;
                        return null; // archivo existe pero no define gf
                    }
                }
            }
        }
        catch(_) {}
        return null;
    }
    #end
    
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
