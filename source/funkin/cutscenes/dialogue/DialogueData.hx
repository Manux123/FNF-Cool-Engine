package funkin.cutscenes.dialogue;

import haxe.Json;
import sys.io.File;

/**
 * Tipos de estilos de diálogo
 */
enum DialogueStyle {
    PIXEL;
    NORMAL;
}

/**
 * Tipos de burbujas de diálogo
 */
enum BubbleType {
    NORMAL;
    LOUD;
    ANGRY;
    EVIL;
}

/**
 * Datos de un mensaje individual de diálogo
 */
typedef DialogueMessage = {
    var character:String;           // 'dad' o 'bf'
    var text:String;               // Texto del diálogo
    var ?bubbleType:String;        // 'normal', 'loud', 'angry', 'evil'
    var ?speed:Float;              // Velocidad del texto (default: 0.04)
    var ?portrait:String;          // Ruta personalizada del portrait
    var ?boxSprite:String;         // Ruta personalizada de la caja
    var ?music:String;             // Música de fondo (opcional)
    var ?sound:String;             // Sonido del texto (opcional)
}

/**
 * Datos completos de una conversación
 */
typedef DialogueConversation = {
    var name:String;               // Nombre de la conversación
    var style:String;              // 'pixel' o 'normal'
    var ?backgroundColor:String;   // Color de fondo (hex)
    var ?fadeTime:Float;           // Tiempo de fade (default: 0.83)
    var messages:Array<DialogueMessage>;
}

/**
 * Clase para manejar datos de diálogos desde JSON
 */
class DialogueData {
    public static function loadDialogue(path:String):DialogueConversation {
        var jsonContent:String = '';
        
        #if sys
        try {
            jsonContent = File.getContent(path);
        } catch(e:Dynamic) {
            trace('Error loading dialogue: $e');
            return null;
        }
        #else
        // Para web u otras plataformas
        jsonContent = openfl.Assets.getText(path);
        #end
        
        if (jsonContent == null || jsonContent == '') {
            trace('Dialogue file is empty or not found: $path');
            return null;
        }
        
        try {
            var data:DialogueConversation = Json.parse(jsonContent);
            
            // Validar y aplicar valores por defecto
            if (data.messages == null || data.messages.length == 0) {
                trace('No messages found in dialogue');
                return null;
            }
            
            // Aplicar defaults a cada mensaje
            for (msg in data.messages) {
                if (msg.bubbleType == null)
                    msg.bubbleType = 'normal';
                if (msg.speed == null)
                    msg.speed = 0.04;
            }
            
            return data;
        } catch(e:Dynamic) {
            trace('Error parsing JSON: $e');
            return null;
        }
    }
    
    /**
     * Guardar diálogo a JSON
     */
    public static function saveDialogue(path:String, data:DialogueConversation):Bool {
        #if sys
        try {
            var jsonString = Json.stringify(data, null, '  ');
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
     * Crear un diálogo de ejemplo
     */
    public static function createExample():DialogueConversation {
        return {
            name: "example_dialogue",
            style: "pixel",
            backgroundColor: "#B3DFD8",
            fadeTime: 0.83,
            messages: [
                {
                    character: "dad",
                    text: "Hey there!",
                    bubbleType: "normal",
                    speed: 0.04
                },
                {
                    character: "bf",
                    text: "Beep bop!",
                    bubbleType: "normal",
                    speed: 0.04
                },
                {
                    character: "dad",
                    text: "Let's have a rap battle!",
                    bubbleType: "loud",
                    speed: 0.03
                }
            ]
        };
    }
}
