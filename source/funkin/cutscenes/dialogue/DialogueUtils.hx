package funkin.cutscenes.dialogue;

import flixel.util.FlxColor;
import funkin.cutscenes.DialogueData;

/**
 * Utilidades y helpers para el sistema de diálogos
 */
class DialogueUtils {
    /**
     * Convertir diálogo legacy a formato JSON
     */
    public static function convertLegacyToJSON(
        dialogueList:Array<String>, 
        name:String, 
        style:String = 'pixel'
    ):DialogueConversation {
        var messages:Array<DialogueMessage> = [];
        
        for (line in dialogueList) {
            var parts = line.split(':');
            if (parts.length < 2) continue;
            
            var character = parts[1].toLowerCase().trim();
            var text = line.substr(parts[0].length + parts[1].length + 2).trim();
            
            messages.push({
                character: character,
                text: text,
                bubbleType: 'normal',
                speed: 0.04
            });
        }
        
        return {
            name: name,
            style: style,
            backgroundColor: getDefaultBackgroundColor(style),
            fadeTime: 0.83,
            messages: messages
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
     * Validar estructura de diálogo
     */
    public static function validateDialogue(dialogue:DialogueConversation):Array<String> {
        var errors:Array<String> = [];
        
        if (dialogue == null) {
            errors.push('Dialogue is null');
            return errors;
        }
        
        if (dialogue.name == null || dialogue.name == '') {
            errors.push('Dialogue name is empty');
        }
        
        if (dialogue.style == null || (dialogue.style != 'pixel' && dialogue.style != 'normal')) {
            errors.push('Invalid style: must be "pixel" or "normal"');
        }
        
        if (dialogue.messages == null || dialogue.messages.length == 0) {
            errors.push('No messages in dialogue');
        } else {
            for (i in 0...dialogue.messages.length) {
                var msg = dialogue.messages[i];
                
                if (msg.character == null || msg.character == '') {
                    errors.push('Message $i: character is empty');
                }
                
                if (msg.text == null || msg.text == '') {
                    errors.push('Message $i: text is empty');
                }
                
                if (msg.speed != null && (msg.speed < 0.01 || msg.speed > 0.2)) {
                    errors.push('Message $i: speed out of range (0.01-0.2)');
                }
            }
        }
        
        return errors;
    }
    
    /**
     * Previsualizar un mensaje específico (para debug)
     */
    public static function previewMessage(msg:DialogueMessage):String {
        return '${msg.character}: ${msg.text.substr(0, 50)}${msg.text.length > 50 ? "..." : ""}';
    }
    
    /**
     * Obtener duración estimada del diálogo (en segundos)
     */
    public static function getEstimatedDuration(dialogue:DialogueConversation):Float {
        var totalTime:Float = 0;
        
        for (msg in dialogue.messages) {
            var speed = msg.speed ?? 0.04;
            var charTime = msg.text.length * speed;
            var readTime = 1.0; // Tiempo para leer después de escribir
            totalTime += charTime + readTime;
        }
        
        return totalTime;
    }
    
    /**
     * Formatear tiempo en formato legible
     */
    public static function formatDuration(seconds:Float):String {
        var mins = Math.floor(seconds / 60);
        var secs = Math.floor(seconds % 60);
        return '${mins}m ${secs}s';
    }
    
    /**
     * Crear diálogo vacío
     */
    public static function createEmpty(name:String, style:String = 'pixel'):DialogueConversation {
        return {
            name: name,
            style: style,
            backgroundColor: getDefaultBackgroundColor(style),
            fadeTime: 0.83,
            messages: []
        };
    }
    
    /**
     * Duplicar un mensaje
     */
    public static function duplicateMessage(msg:DialogueMessage):DialogueMessage {
        return {
            character: msg.character,
            text: msg.text,
            bubbleType: msg.bubbleType,
            speed: msg.speed,
            portrait: msg.portrait,
            boxSprite: msg.boxSprite,
            music: msg.music,
            sound: msg.sound
        };
    }
    
    /**
     * Agregar mensaje simple
     */
    public static function addSimpleMessage(
        dialogue:DialogueConversation,
        character:String,
        text:String
    ):Void {
        dialogue.messages.push({
            character: character,
            text: text,
            bubbleType: 'normal',
            speed: 0.04
        });
    }
    
    /**
     * Intercambiar dos mensajes de posición
     */
    public static function swapMessages(
        dialogue:DialogueConversation,
        index1:Int,
        index2:Int
    ):Bool {
        if (index1 < 0 || index1 >= dialogue.messages.length)
            return false;
        if (index2 < 0 || index2 >= dialogue.messages.length)
            return false;
            
        var temp = dialogue.messages[index1];
        dialogue.messages[index1] = dialogue.messages[index2];
        dialogue.messages[index2] = temp;
        
        return true;
    }
    
    /**
     * Buscar mensajes por personaje
     */
    public static function findMessagesByCharacter(
        dialogue:DialogueConversation,
        character:String
    ):Array<Int> {
        var indices:Array<Int> = [];
        
        for (i in 0...dialogue.messages.length) {
            if (dialogue.messages[i].character.toLowerCase() == character.toLowerCase()) {
                indices.push(i);
            }
        }
        
        return indices;
    }
    
    /**
     * Reemplazar texto en todos los mensajes
     */
    public static function replaceTextInAll(
        dialogue:DialogueConversation,
        find:String,
        replace:String
    ):Int {
        var count = 0;
        
        for (msg in dialogue.messages) {
            var before = msg.text;
            msg.text = StringTools.replace(msg.text, find, replace);
            if (msg.text != before)
                count++;
        }
        
        return count;
    }
    
    /**
     * Obtener estadísticas del diálogo
     */
    public static function getStats(dialogue:DialogueConversation):String {
        var totalMessages = dialogue.messages.length;
        var totalChars = 0;
        var totalWords = 0;
        var dadMessages = 0;
        var bfMessages = 0;
        
        for (msg in dialogue.messages) {
            totalChars += msg.text.length;
            totalWords += msg.text.split(' ').length;
            
            if (msg.character.toLowerCase() == 'dad')
                dadMessages++;
            else if (msg.character.toLowerCase() == 'bf')
                bfMessages++;
        }
        
        var duration = getEstimatedDuration(dialogue);
        
        return 
            'Messages: $totalMessages\n' +
            'Characters: $totalChars\n' +
            'Words: $totalWords\n' +
            'Dad: $dadMessages\n' +
            'BF: $bfMessages\n' +
            'Duration: ${formatDuration(duration)}';
    }
    
    /**
     * Exportar a CSV (para traducción)
     */
    public static function exportToCSV(dialogue:DialogueConversation):String {
        var csv = 'Index,Character,Text,BubbleType,Speed\n';
        
        for (i in 0...dialogue.messages.length) {
            var msg = dialogue.messages[i];
            var text = StringTools.replace(msg.text, '"', '""'); // Escape quotes
            csv += '$i,${msg.character},"$text",${msg.bubbleType},${msg.speed}\n';
        }
        
        return csv;
    }
    
    /**
     * Crear template para nuevo estilo
     */
    public static function createStyleTemplate(styleName:String):DialogueConversation {
        return {
            name: 'template_$styleName',
            style: styleName,
            backgroundColor: '#000000',
            fadeTime: 0.83,
            messages: [
                {
                    character: 'dad',
                    text: 'Sample opponent dialogue',
                    bubbleType: 'normal',
                    speed: 0.04
                },
                {
                    character: 'bf',
                    text: 'Sample boyfriend response',
                    bubbleType: 'normal',
                    speed: 0.04
                }
            ]
        };
    }
}
