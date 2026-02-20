package funkin.cutscenes.dialogue;

import haxe.Json;
import sys.io.File;
import sys.FileSystem;

/**
 * Tipos de estilos de diálogo
 */
enum DialogueStyle {
    PIXEL;
    NORMAL;
    CUSTOM;
}

/**
 * Tipos de burbujas de diálogo
 */
enum BubbleType {
    NORMAL;
    LOUD;
    ANGRY;
    EVIL;
    CUSTOM;
}

/**
 * Configuración de un portrait personalizado
 */
typedef PortraitConfig = {
    var name:String;              // Nombre del portrait
    var fileName:String;          // Nombre del archivo (sin ruta)
    var ?x:Float;                 // Posición X
    var ?y:Float;                 // Posición Y
    var ?scaleX:Float;            // Escala X
    var ?scaleY:Float;            // Escala Y
    var ?flipX:Bool;              // Voltear horizontalmente
    var ?animation:String;        // Nombre de la animación
}

/**
 * Configuración de una caja de diálogo personalizada
 */
typedef BoxConfig = {
    var name:String;              // Nombre de la caja
    var fileName:String;          // Nombre del archivo (sin ruta)
    var ?x:Float;                 // Posición X
    var ?y:Float;                 // Posición Y
    var ?width:Int;               // Ancho
    var ?height:Int;              // Alto
    var ?scaleX:Float;            // Escala X
    var ?scaleY:Float;            // Escala Y
    var ?animation:String;        // Animación a usar
}

/**
 * Configuración de posición del texto
 */
typedef TextConfig = {
    var ?x:Float;                 // Posición X del texto
    var ?y:Float;                 // Posición Y del texto
    var ?width:Int;               // Ancho del área de texto
    var ?size:Int;                // Tamaño de fuente
    var ?font:String;             // Fuente
    var ?color:String;            // Color del texto (hex)
}

/**
 * Configuración completa de una skin de diálogo
 */
typedef DialogueSkin = {
    var name:String;                              // Nombre de la skin
    var style:String;                             // 'pixel' o 'normal' o 'custom'
    var ?backgroundColor:String;                  // Color de fondo (hex)
    var ?fadeTime:Float;                          // Tiempo de fade (default: 0.83)
    var portraits:Map<String, PortraitConfig>;    // Portraits de la skin
    var boxes:Map<String, BoxConfig>;             // Cajas de la skin
    var ?textConfig:TextConfig;                   // Configuración del texto
}

/**
 * Datos de un mensaje individual de diálogo
 */
typedef DialogueMessage = {
    var character:String;           // 'dad' o 'bf' o nombre personalizado
    var text:String;               // Texto del diálogo
    var ?bubbleType:String;        // 'normal', 'loud', 'angry', 'evil'
    var ?speed:Float;              // Velocidad del texto (default: 0.04)
    var ?portrait:String;          // Nombre del portrait a usar
    var ?boxSprite:String;         // Nombre de la caja a usar
    var ?music:String;             // Música de fondo (opcional)
    var ?sound:String;             // Sonido del texto (opcional)
}

/**
 * Datos de una conversación (solo mensajes + referencia a skin)
 */
typedef DialogueConversation = {
    var name:String;                // Nombre de la conversación
    var skinName:String;            // Nombre de la skin a usar
    var messages:Array<DialogueMessage>;
}

/**
 * Clase para manejar datos de diálogos y skins
 */
class DialogueData {
    /**
     * Obtener ruta base de las skins
     */
    public static function getSkinsBasePath():String {
        return 'cutscenes/dialogue/';
    }
    
    /**
     * Obtener ruta de una skin específica
     */
    public static function getSkinPath(skinName:String):String {
        return getSkinsBasePath() + skinName + '/';
    }
    
    /**
     * Obtener ruta del archivo de configuración de una skin
     */
    public static function getSkinConfigPath(skinName:String):String {
        return getSkinPath(skinName) + 'config.json';
    }
    
    /**
     * Obtener ruta de la carpeta de portraits de una skin
     */
    public static function getSkinPortraitsPath(skinName:String):String {
        return getSkinPath(skinName) + 'portraits/';
    }
    
    /**
     * Obtener ruta de la carpeta de cajas de una skin
     */
    public static function getSkinBoxesPath(skinName:String):String {
        return getSkinPath(skinName) + 'boxes/';
    }
    
    /**
     * Obtener ruta de un diálogo de una canción
     * @param songName Nombre de la canción
     * @param dialogueType Tipo de diálogo: 'intro' o 'outro' (default: 'intro')
     */
    public static function getSongDialoguePath(songName:String, ?dialogueType:String = 'intro'):String {
        return 'assets/songs/${songName.toLowerCase()}/${dialogueType}.json';
    }
    
    /**
     * Crear directorios para una nueva skin
     */
    public static function createSkinDirectories(skinName:String):Bool {
        #if sys
        try {
            var skinPath = getSkinPath(skinName);
            var portraitsPath = getSkinPortraitsPath(skinName);
            var boxesPath = getSkinBoxesPath(skinName);
            
            if (!FileSystem.exists(skinPath))
                FileSystem.createDirectory(skinPath);
            if (!FileSystem.exists(portraitsPath))
                FileSystem.createDirectory(portraitsPath);
            if (!FileSystem.exists(boxesPath))
                FileSystem.createDirectory(boxesPath);
            
            return true;
        } catch(e:Dynamic) {
            trace('Error creating skin directories: $e');
            return false;
        }
        #else
        return false;
        #end
    }
    
    /**
     * Cargar configuración de una skin
     */
    public static function loadSkin(skinName:String):DialogueSkin {
        var path = getSkinConfigPath(skinName);
        var jsonContent:String = '';
        
        #if sys
        try {
            if (!FileSystem.exists(path)) {
                trace('Skin config not found: $path');
                return null;
            }
            jsonContent = File.getContent(path);
        } catch(e:Dynamic) {
            trace('Error loading skin: $e');
            return null;
        }
        #else
        jsonContent = openfl.Assets.getText(path);
        #end
        
        if (jsonContent == null || jsonContent == '') {
            trace('Skin config is empty: $path');
            return null;
        }
        
        try {
            // Parsear JSON a objeto dinámico primero
            var jsonData:Dynamic = Json.parse(jsonContent);
            
            // Convertir objetos JSON a Maps
            var portraitsMap = new Map<String, PortraitConfig>();
            if (jsonData.portraits != null) {
                var portraitsObj:Dynamic = jsonData.portraits;
                for (key in Reflect.fields(portraitsObj)) {
                    var config:PortraitConfig = Reflect.field(portraitsObj, key);
                    portraitsMap.set(key, config);
                }
            }
            
            var boxesMap = new Map<String, BoxConfig>();
            if (jsonData.boxes != null) {
                var boxesObj:Dynamic = jsonData.boxes;
                for (key in Reflect.fields(boxesObj)) {
                    var config:BoxConfig = Reflect.field(boxesObj, key);
                    boxesMap.set(key, config);
                }
            }
            
            // Construir DialogueSkin con Maps convertidos
            var data:DialogueSkin = {
                name: jsonData.name,
                style: jsonData.style,
                backgroundColor: jsonData.backgroundColor,
                fadeTime: jsonData.fadeTime,
                portraits: portraitsMap,
                boxes: boxesMap,
                textConfig: jsonData.textConfig
            };
            
            return data;
        } catch(e:Dynamic) {
            trace('Error parsing skin JSON: $e');
            return null;
        }
    }
    
    /**
     * Guardar configuración de una skin
     */
    public static function saveSkin(skinName:String, skin:DialogueSkin):Bool {
        #if sys
        try {
            // Crear directorios si no existen
            createSkinDirectories(skinName);
            
            // Convertir Maps a objetos para JSON
            var portraitsObj:Dynamic = {};
            if (skin.portraits != null) {
                for (key in skin.portraits.keys()) {
                    Reflect.setField(portraitsObj, key, skin.portraits.get(key));
                }
            }
            
            var boxesObj:Dynamic = {};
            if (skin.boxes != null) {
                for (key in skin.boxes.keys()) {
                    Reflect.setField(boxesObj, key, skin.boxes.get(key));
                }
            }
            
            // Crear objeto serializable
            var skinObj:Dynamic = {
                name: skin.name,
                style: skin.style,
                backgroundColor: skin.backgroundColor,
                fadeTime: skin.fadeTime,
                portraits: portraitsObj,
                boxes: boxesObj,
                textConfig: skin.textConfig
            };
            
            var path = getSkinConfigPath(skinName);
            var jsonString = Json.stringify(skinObj, null, '  ');
            File.saveContent(path, jsonString);
            return true;
        } catch(e:Dynamic) {
            trace('Error saving skin: $e');
            return false;
        }
        #else
        trace('Save not supported on this platform');
        return false;
        #end
    }
    
    /**
     * Cargar conversación de diálogo
     * @param songName Nombre de la canción
     * @param dialogueType Tipo de diálogo: 'intro' o 'outro' (default: 'intro')
     */
    public static function loadConversation(songName:String, ?dialogueType:String = 'intro'):DialogueConversation {
        var path = getSongDialoguePath(songName, dialogueType);
        var jsonContent:String = '';
        
        #if sys
        try {
            if (!FileSystem.exists(path)) {
                trace('Dialogue not found: $path');
                return null;
            }
            jsonContent = File.getContent(path);
        } catch(e:Dynamic) {
            trace('Error loading dialogue: $e');
            return null;
        }
        #else
        jsonContent = openfl.Assets.getText(path);
        #end
        
        if (jsonContent == null || jsonContent == '') {
            trace('Dialogue file is empty: $path');
            return null;
        }
        
        try {
            var data:DialogueConversation = Json.parse(jsonContent);
            
            // Validar mensajes
            if (data.messages == null || data.messages.length == 0) {
                trace('No messages found in dialogue');
                return null;
            }
            
            // Aplicar defaults
            for (msg in data.messages) {
                if (msg.bubbleType == null)
                    msg.bubbleType = 'normal';
                if (msg.speed == null)
                    msg.speed = 0.04;
            }
            
            return data;
        } catch(e:Dynamic) {
            trace('Error parsing dialogue JSON: $e');
            return null;
        }
    }
    
    /**
     * Guardar conversación de diálogo
     * @param songName Nombre de la canción
     * @param conversation Datos de la conversación
     * @param dialogueType Tipo de diálogo: 'intro' o 'outro' (default: 'intro')
     */
    public static function saveConversation(songName:String, conversation:DialogueConversation, ?dialogueType:String = 'intro'):Bool {
        #if sys
        try {
            var path = getSongDialoguePath(songName, dialogueType);
            
            // Crear directorio de la canción si no existe
            var songDir = 'assets/songs/${songName.toLowerCase()}/';
            if (!FileSystem.exists(songDir))
                FileSystem.createDirectory(songDir);
            
            var jsonString = Json.stringify(conversation, null, '  ');
            File.saveContent(path, jsonString);
            return true;
        } catch(e:Dynamic) {
            trace('Error saving dialogue: $e');
            return false;
        }
        #else
        trace('Save not supported on this platform');
        return false;
        #end
    }
    
    /**
     * Copiar archivo a la carpeta de portraits de una skin
     */
    public static function copyPortraitToSkin(sourcePath:String, skinName:String, fileName:String):Bool {
        #if sys
        try {
            var destPath = getSkinPortraitsPath(skinName) + fileName;
            
            // Crear directorios si no existen
            createSkinDirectories(skinName);
            
            // Copiar archivo
            File.copy(sourcePath, destPath);
            trace('Portrait copied to: $destPath');
            return true;
        } catch(e:Dynamic) {
            trace('Error copying portrait: $e');
            return false;
        }
        #else
        return false;
        #end
    }
    
    /**
     * Copiar archivo a la carpeta de cajas de una skin
     */
    public static function copyBoxToSkin(sourcePath:String, skinName:String, fileName:String):Bool {
        #if sys
        try {
            var destPath = getSkinBoxesPath(skinName) + fileName;
            
            // Crear directorios si no existen
            createSkinDirectories(skinName);
            
            // Copiar archivo
            File.copy(sourcePath, destPath);
            trace('Box copied to: $destPath');
            return true;
        } catch(e:Dynamic) {
            trace('Error copying box: $e');
            return false;
        }
        #else
        return false;
        #end
    }
    
    /**
     * Listar todas las skins disponibles
     */
    public static function listSkins():Array<String> {
        #if sys
        try {
            var basePath = getSkinsBasePath();
            if (!FileSystem.exists(basePath))
                return [];
            
            var skins:Array<String> = [];
            for (item in FileSystem.readDirectory(basePath)) {
                var itemPath = basePath + item;
                if (FileSystem.isDirectory(itemPath)) {
                    var configPath = itemPath + '/config.json';
                    if (FileSystem.exists(configPath)) {
                        skins.push(item);
                    }
                }
            }
            return skins;
        } catch(e:Dynamic) {
            trace('Error listing skins: $e');
            return [];
        }
        #else
        return [];
        #end
    }
    
    /**
     * Crear una skin vacía
     */
    public static function createEmptySkin(skinName:String, style:String = 'pixel'):DialogueSkin {
        return {
            name: skinName,
            style: style,
            backgroundColor: getDefaultBackgroundColor(style),
            fadeTime: 0.83,
            portraits: new Map<String, PortraitConfig>(),
            boxes: new Map<String, BoxConfig>(),
            textConfig: {
                x: 240,
                y: 500,
                width: 800,
                size: 32,
                font: "Pixel Arial 11 Bold",
                color: "#3F2021"
            }
        };
    }
    
    /**
     * Crear conversación vacía
     */
    public static function createEmptyConversation(name:String, skinName:String):DialogueConversation {
        return {
            name: name,
            skinName: skinName,
            messages: []
        };
    }
    
    /**
     * Obtener color de fondo por defecto según el estilo
     */
    public static function getDefaultBackgroundColor(style:String):String {
        return switch(style.toLowerCase()) {
            case 'pixel': '#B3DFD8';
            case 'normal': '#2C1B3D';
            default: '#000000';
        }
    }
    
    /**
     * Crear configuración de portrait
     */
    public static function createPortraitConfig(name:String, fileName:String):PortraitConfig {
        return {
            name: name,
            fileName: fileName,
            x: 0,
            y: 0,
            scaleX: 1.0,
            scaleY: 1.0,
            flipX: false,
            animation: "idle"
        };
    }
    
    /**
     * Crear configuración de caja
     */
    public static function createBoxConfig(name:String, fileName:String):BoxConfig {
        return {
            name: name,
            fileName: fileName,
            x: 0,
            y: 0,
            width: 640,
            height: 200,
            scaleX: 1.0,
            scaleY: 1.0,
            animation: "normal"
        };
    }
    
    /**
     * Obtener ruta completa de un portrait en una skin
     */
    public static function getPortraitAssetPath(skinName:String, fileName:String):String {
        return getSkinPortraitsPath(skinName) + fileName;
    }
    
    /**
     * Obtener ruta completa de una caja en una skin
     */
    public static function getBoxAssetPath(skinName:String, fileName:String):String {
        return getSkinBoxesPath(skinName) + fileName;
    }
}
