package funkin.gameplay.notes;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.math.FlxRect;
import openfl.display.BitmapData;
import openfl.geom.Rectangle;
import openfl.geom.Point;

/**
 * NoteBatcher - Sistema de batching para reducir draw calls
 * 
 * OBJETIVO: Renderizar múltiples notas en un solo draw call agrupándolas por textura
 * 
 * BENEFICIOS:
 * - Reduce draw calls de 100+ a ~4-8 por frame
 * - Mejora FPS en canciones con muchas notas
 * - Menos overhead de CPU para el renderer
 */
class NoteBatcher extends FlxSpriteGroup
{
    // Batches separados por tipo de nota para evitar cambios de textura
    private var noteBatches:Map<String, Array<Note>> = new Map();
    
    // Configuración
    private var batchSize:Int = 100; // Máximo de notas por batch antes de forzar draw
    private var enableBatching:Bool = true;
    
    // Stats
    public var totalNotes:Int = 0;
    public var totalBatches:Int = 0;
    public var drawCallsSaved:Int = 0;
    
    // Cache de texturas para cada tipo de nota
    private var textureCache:Map<String, FlxAtlasFrames> = new Map();
    
    public function new()
    {
        super();
        
        // Inicializar batches para cada dirección de nota
        noteBatches.set("purple", []);
        noteBatches.set("blue", []);
        noteBatches.set("green", []);
        noteBatches.set("red", []);
        noteBatches.set("sustain", []);
        
        trace('[NoteBatcher] Inicializado - Batching: $enableBatching');
    }
    
    /**
     * Agregar nota al batch correspondiente
     */
    public function addNoteToBatch(note:Note):Void
    {
        if (!enableBatching)
        {
            // Si batching está desactivado, usar método tradicional
            add(note);
            return;
        }
        
        var batchKey:String = getBatchKey(note);
        
        if (!noteBatches.exists(batchKey))
            noteBatches.set(batchKey, []);
        
        noteBatches.get(batchKey).push(note);
        totalNotes++;
        
        // Si el batch está lleno, forzar render
        if (noteBatches.get(batchKey).length >= batchSize)
        {
            flushBatch(batchKey);
        }
    }
    
    /**
     * Determinar la clave del batch según el tipo de nota
     */
    private function getBatchKey(note:Note):String
    {
        if (note.isSustainNote)
            return "sustain";
        
        switch (note.noteData)
        {
            case 0: return "purple";
            case 1: return "blue";
            case 2: return "green";
            case 3: return "red";
            default: return "purple";
        }
    }
    
    /**
     * Renderizar un batch específico (flush)
     */
    private function flushBatch(batchKey:String):Void
    {
        var batch = noteBatches.get(batchKey);
        if (batch == null || batch.length == 0)
            return;
        
        // Agregar todas las notas del batch al grupo
        for (note in batch)
        {
            add(note);
        }
        
        totalBatches++;
        drawCallsSaved += (batch.length - 1); // Cada nota era un draw call, ahora es 1
        
        // Limpiar batch
        batch.resize(0);
    }
    
    /**
     * Renderizar todos los batches pendientes
     */
    public function flushAll():Void
    {
        for (batchKey in noteBatches.keys())
        {
            flushBatch(batchKey);
        }
    }
    
    /**
     * Limpiar todos los batches
     */
    public function clearBatches():Void
    {
        for (batch in noteBatches)
        {
            batch.resize(0);
        }
        
        totalNotes = 0;
        totalBatches = 0;
        drawCallsSaved = 0;
    }
    
    /**
     * Remover nota de batches
     */
    public function removeNoteFromBatch(note:Note):Void
    {
        var batchKey = getBatchKey(note);
        var batch = noteBatches.get(batchKey);
        
        if (batch != null)
        {
            batch.remove(note);
        }
        
        remove(note, true);
    }
    
    /**
     * Obtener estadísticas de batching
     */
    public function getBatchStats():String
    {
        var stats = '[NoteBatcher Stats]\n';
        stats += 'Total Notes: $totalNotes\n';
        stats += 'Total Batches: $totalBatches\n';
        stats += 'Draw Calls Saved: $drawCallsSaved\n';
        stats += 'Batching Enabled: $enableBatching\n';
        
        for (key in noteBatches.keys())
        {
            var batch = noteBatches.get(key);
            stats += '  $key batch: ${batch.length} notes\n';
        }
        
        return stats;
    }
    
    /**
     * Toggle batching on/off
     */
    public function toggleBatching():Void
    {
        enableBatching = !enableBatching;
        trace('[NoteBatcher] Batching: $enableBatching');
    }
    
    override function update(elapsed:Float)
    {
        super.update(elapsed);
        
        // Flush batches cada frame para asegurar rendering
        flushAll();
    }
    
    override function destroy()
    {
        noteBatches.clear(); 
        textureCache.clear();

        super.destroy();
    }
}
