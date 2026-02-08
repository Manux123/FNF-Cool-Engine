package notes;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import notes.Note;

/**
 * NoteRenderer SIMPLE - Sin pool, sin complicaciones
 * SOLO actualiza posiciones, todo lo demás lo hace PlayState
 */
class NoteRenderer
{
    // Referencias
    private var playerStrums:FlxTypedGroup<FlxSprite>;
    private var cpuStrums:FlxTypedGroup<FlxSprite>;
    
    // Config
    public var downscroll:Bool = false;
    public var strumLineY:Float = 50;
    public var noteSpeed:Float = 1.0;
    
    // Constructor
    public function new(notes:FlxTypedGroup<Note>, playerStrums:FlxTypedGroup<FlxSprite>, cpuStrums:FlxTypedGroup<FlxSprite>)
    {
        this.playerStrums = playerStrums;
        this.cpuStrums = cpuStrums;
        
        trace('[NoteRenderer] Creado - Simple Mode');
    }
    
    /**
     * Reciclar nota - Versión ULTRA SIMPLE
     * Solo destruye la nota, sin pool ni complicaciones
     */
    public function recycleNote(note:Note):Void
    {
        if (note == null) return;
        
        try
        {
            note.kill();
            note.destroy();
        }
        catch (e:Dynamic)
        {
            trace('[NoteRenderer] Error: ' + e);
        }
    }
    
    /**
     * Destruir - solo limpiar
     */
    public function destroy():Void
    {
        playerStrums = null;
        cpuStrums = null;
    }
}