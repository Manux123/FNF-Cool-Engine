package funkin.optimization;

import flixel.FlxG;
import funkin.gameplay.notes.NotePool;
import funkin.optimization.GPURenderer;
import funkin.gameplay.notes.Note;

/**
 * OptimizationManager - Administrador central de optimizaciones
 * 
 * FUNCIONES:
 * - Coordina todos los sistemas de optimización
 * - Ajusta automáticamente según FPS
 * - Provee estadísticas en tiempo real
 * - Sistema de calidad adaptativa
 * 
 * USO:
 * En PlayState.create():
 *   optimizationManager = new OptimizationManager();
 *   optimizationManager.init();
 * 
 * En PlayState.update():
 *   optimizationManager.update(elapsed);
 * 
 * En PlayState.draw():
 *   optimizationManager.render();
 */
class OptimizationManager
{
    // === SYSTEMS ===
    public var gpuRenderer:GPURenderer;
    private var initialized:Bool = false;
    
    // === QUALITY SETTINGS ===
    public var qualityLevel:QualityLevel = QualityLevel.HIGH;
    
    // === ADAPTIVE QUALITY ===
    public var enableAdaptiveQuality:Bool = true;
    private var targetFPS:Int = 60;
    private var lowFPSFrames:Int = 0;
    private var highFPSFrames:Int = 0;
    private static inline var FPS_CHECK_THRESHOLD:Int = 120; // Frames antes de ajustar
    
    // === STATS ===
    private var totalNotesSpawned:Int = 0;
    private var totalNotesPooled:Int = 0;
    
    // === PERFORMANCE TRACKING ===
    private var updateTime:Float = 0;
    private var renderTime:Float = 0;
    private var frameTime:Float = 0;
    
    public function new()
    {
        trace('[OptimizationManager] Creado');
    }
    
    /**
     * Inicializar todos los sistemas
     */
    public function init():Void
    {
        if (initialized) return;
        
        trace('[OptimizationManager] Inicializando sistemas...');
        
        // Inicializar NotePool
        NotePool.init();
        
        // Crear GPU Renderer
        gpuRenderer = new GPURenderer(FlxG.camera);
        
        // Aplicar calidad inicial
        applyQualitySettings();
        
        initialized = true;
        
        trace('[OptimizationManager] Sistemas inicializados');
        trace('[OptimizationManager] Calidad: $qualityLevel');
        trace('[OptimizationManager] Adaptive Quality: $enableAdaptiveQuality');
    }
    
    /**
     * Update - Monitoreo adaptativo de FPS
     */
    public function update(elapsed:Float):Void
    {
        if (!initialized) return;
        
        var startTime = haxe.Timer.stamp();
        
        // Adaptive Quality basado en FPS
        if (enableAdaptiveQuality)
        {
            checkAndAdaptQuality();
        }
        
        updateTime = haxe.Timer.stamp() - startTime;
    }
    
    /**
     * Renderizar con GPU Renderer
     */
    public function render():Void
    {
        if (!initialized || gpuRenderer == null) return;
        
        var startTime = haxe.Timer.stamp();
        
        gpuRenderer.render();
        
        renderTime = haxe.Timer.stamp() - startTime;
        frameTime = updateTime + renderTime;
    }
    
    /**
     * Spawnear nota con pooling automático
     */
    public function spawnNote(strumTime:Float, noteData:Int, ?prevNote:Note, ?sustainNote:Bool = false, ?mustHitNote:Bool = false):Note
    {
        totalNotesSpawned++;
        
        // Usar pooling
        var note = NotePool.get(strumTime, noteData, prevNote, sustainNote, mustHitNote);
        totalNotesPooled++;
        
        return note;
    }
    
    /**
     * Reciclar nota al pool
     */
    public function recycleNote(note:Note):Void
    {
        if (note == null) return;
        NotePool.put(note);
    }
    
    /**
     * Agregar sprite al GPU renderer
     */
    public function addSpriteToRenderer(sprite:flixel.FlxSprite):Void
    {
        if (gpuRenderer != null && gpuRenderer.enabled)
        {
            gpuRenderer.addSprite(sprite);
        }
    }
    
    /**
     * Verificar FPS y adaptar calidad automáticamente
     */
    private function checkAndAdaptQuality():Void
    {
        var currentFPS = Std.int(1.0 / FlxG.elapsed);
        
        if (currentFPS < targetFPS - 10) // FPS bajo
        {
            lowFPSFrames++;
            highFPSFrames = 0;
            
            // Si sostenidamente bajo, reducir calidad
            if (lowFPSFrames > FPS_CHECK_THRESHOLD)
            {
                lowerQuality();
                lowFPSFrames = 0;
            }
        }
        else if (currentFPS > targetFPS + 10) // FPS alto
        {
            highFPSFrames++;
            lowFPSFrames = 0;
            
            // Si sostenidamente alto, aumentar calidad
            if (highFPSFrames > FPS_CHECK_THRESHOLD * 2) // Más conservador
            {
                raiseQuality();
                highFPSFrames = 0;
            }
        }
        else
        {
            // FPS estable, resetear contadores
            lowFPSFrames = 0;
            highFPSFrames = 0;
        }
    }
    
    /**
     * Reducir calidad
     */
    private function lowerQuality():Void
    {
        switch (qualityLevel)
        {
            case QualityLevel.ULTRA:
                setQuality(QualityLevel.HIGH);
            case QualityLevel.HIGH:
                setQuality(QualityLevel.MEDIUM);
            case QualityLevel.MEDIUM:
                setQuality(QualityLevel.LOW);
            case QualityLevel.LOW:
                trace('[OptimizationManager] Ya en calidad mínima');
        }
    }
    
    /**
     * Aumentar calidad
     */
    private function raiseQuality():Void
    {
        switch (qualityLevel)
        {
            case QualityLevel.LOW:
                setQuality(QualityLevel.MEDIUM);
            case QualityLevel.MEDIUM:
                setQuality(QualityLevel.HIGH);
            case QualityLevel.HIGH:
                setQuality(QualityLevel.ULTRA);
            case QualityLevel.ULTRA:
                trace('[OptimizationManager] Ya en calidad máxima');
        }
    }
    
    /**
     * Establecer nivel de calidad
     */
    public function setQuality(level:QualityLevel):Void
    {
        if (qualityLevel == level) return;
        
        qualityLevel = level;
        applyQualitySettings();
        
        trace('[OptimizationManager] Calidad cambiada a: $qualityLevel');
    }
    
    /**
     * Aplicar configuración según calidad
     */
    private function applyQualitySettings():Void
    {
        if (gpuRenderer == null) return;
        
        switch (qualityLevel)
        {
            case QualityLevel.ULTRA:
                gpuRenderer.enabled = true;
                gpuRenderer.enableCulling = true;
                gpuRenderer.enableZSorting = true;
                
            case QualityLevel.HIGH:
                gpuRenderer.enabled = true;
                gpuRenderer.enableCulling = true;
                gpuRenderer.enableZSorting = true;
                
            case QualityLevel.MEDIUM:
                gpuRenderer.enabled = true;
                gpuRenderer.enableCulling = true;
                gpuRenderer.enableZSorting = false; // Desactivar Z-sorting
                
            case QualityLevel.LOW:
                gpuRenderer.enabled = true;
                gpuRenderer.enableCulling = true;
                gpuRenderer.enableZSorting = false;
        }
    }
    
    /**
     * Obtener estadísticas completas
     */
    public function getFullStats():String
    {
        var stats = '=== OPTIMIZATION STATS ===\n';
        stats += 'Quality Level: $qualityLevel\n';
        stats += 'Current FPS: ${Std.int(1.0 / FlxG.elapsed)}\n';
        stats += 'Frame Time: ${Math.round(frameTime * 10000) / 10}μs\n';
        stats += '  - Update: ${Math.round(updateTime * 10000) / 10}μs\n';
        stats += '  - Render: ${Math.round(renderTime * 10000) / 10}μs\n';
        stats += '\n';
        
        // Stats de NotePool
        stats += NotePool.getStats() + '\n';
        
        // Stats de GPU Renderer
        if (gpuRenderer != null)
            stats += gpuRenderer.getStats();
        
        return stats;
    }
    
    /**
     * Limpiar entre canciones
     */
    public function clear():Void
    {
        if (!initialized) return;
        
        trace('[OptimizationManager] Limpiando...');
        
        NotePool.clear();
        
        if (gpuRenderer != null)
            gpuRenderer.clear();
        
        totalNotesSpawned = 0;
        totalNotesPooled = 0;
    }
    
    /**
     * Destruir completamente
     */
    public function destroy():Void
    {
        if (!initialized) return;
        
        trace('[OptimizationManager] Destruyendo...');
        
        NotePool.destroy();
        
        if (gpuRenderer != null)
        {
            gpuRenderer.destroy();
            gpuRenderer = null;
        }
        
        initialized = false;
    }
}

/**
 * Niveles de calidad
 */
enum QualityLevel
{
    ULTRA;   // Todas las optimizaciones + efectos máximos
    HIGH;    // Todas las optimizaciones
    MEDIUM;  // Optimizaciones básicas, sin Z-sorting
    LOW;     // Solo culling y pooling
}