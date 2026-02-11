package ui;

import openfl.display.Sprite;
import openfl.display.Shape;
import openfl.text.TextField;
import openfl.text.TextFormat;
import ui.FPSCount;
import flixel.FlxG;

class DataInfoUI extends Sprite
{
    public var fps:FPSCount;
    public var dataText:FPSCount.DataText;
    public var gpuStats:GPUStatsText;

    public static var saveData:Dynamic = '';

    public static var gpuEnabled:Bool = false;

    public function new(x:Float, y:Float)
    {
        super();

        saveData = GPUStatsText.getSaveData();
        gpuEnabled = (saveData != null && saveData.gpuRendering != null) ? saveData.gpuRendering : true;
        
        // Fondo más grande para incluir GPU stats
        var bg:Shape = new Shape();
        bg.graphics.beginFill(0x000000, 0.6);
        bg.graphics.drawRect(x, y, 180, 70); // Aumentado de 70 a 110
        bg.graphics.endFill();
        addChild(bg);
        /*
        if (gpuEnabled)
            bg.height = 110;*/

        fps = new FPSCount(x, y, 0xFFFFFF);
        dataText = new DataText(x, y + 15);
        gpuStats = new GPUStatsText(x, y + 45); // Nueva sección de GPU stats

        addChild(fps);
        addChild(dataText);
        addChild(gpuStats);

        this.visible = true;
        fps.visible = true;
        dataText.visible = true;
        
        // Acceso seguro a FlxG.save.data
        var showStats = false;
        if (FlxG.save != null && FlxG.save.data != null && FlxG.save.data.showStats != null)
            showStats = FlxG.save.data.showStats;
        gpuStats.visible = showStats;
    }
    
    /**
     * Toggle visibilidad de stats GPU
     */
    public function toggleGPUStats():Void
    {
        gpuStats.visible = !gpuStats.visible;
        if (FlxG.save.data != null)
        {
            FlxG.save.data.showStats = gpuStats.visible;
        }
    }
}

/**
 * GPUStatsText - Muestra estadísticas de GPU y renderizado
 */
class GPUStatsText extends TextField
{
    private var updateTimer:Float = 0;
    private var updateInterval:Float = 0.5; // Actualizar cada 0.5 segundos
    
    /**
     * Helper para acceder de forma segura a FlxG.save.data
     */
    public static function getSaveData():Dynamic
    {
        if (FlxG.save != null && FlxG.save.data != null)
            return FlxG.save.data;
        return null;
    }
    
    public function new(x:Float, y:Float)
    {
        super();
        
        this.x = x + 5;
        this.y = y;
        this.width = 170;
        this.height = 65;
        this.selectable = false;
        this.mouseEnabled = false;
        
        var format:TextFormat = new TextFormat("_sans", 10, 0x00FF00);
        format.align = openfl.text.TextFormatAlign.LEFT;
        this.defaultTextFormat = format;
        
        // Inicializar con texto vacío, se actualizará después
        this.text = "GPU: ...\nQuality: ...\nDraw Calls: 0\nSprites: 0\nCache: ...";
    }
    
    /**
     * Actualizar estadísticas
     */
    public function updateStats():Void
    {
        var stats = "";
        stats += "GPU: " + (DataInfoUI.gpuEnabled ? "ON" : "OFF") + "\n";
        
        // === QUALITY LEVEL ===
        var qualityLevel = (DataInfoUI.saveData != null && DataInfoUI.saveData.qualityLevel != null) ? DataInfoUI.saveData.qualityLevel : 2;
        var qualityName = switch(qualityLevel)
        {
            case 0: "LOW";
            case 1: "MED";
            case 2: "HIGH";
            case 3: "ULTRA";
            default: "HIGH";
        };
        stats += "Quality: " + qualityName + "\n";
        
        // === DRAW CALLS (simulado - se actualizará en PlayState) ===
        var drawCalls = getDrawCalls();
        stats += "Draw Calls: " + drawCalls + "\n";
        
        // === SPRITES RENDERED ===
        var spritesRendered = getSpritesRendered();
        stats += "Sprites: " + spritesRendered + "\n";
        
        // === CACHE STATS ===
        var cacheEnabled = (DataInfoUI.saveData != null && DataInfoUI.saveData.textureCache != null) ? DataInfoUI.saveData.textureCache : true;
        stats += "Cache: " + (cacheEnabled ? "ON" : "OFF");
        
        this.text = stats;
    }
    
    /**
     * Obtener draw calls desde OptimizationManager (si existe)
     */
    private function getDrawCalls():Int
    {
        // Verificar que FlxG y FlxG.state estén disponibles
        if (FlxG.state == null)
            return 0;
            
        // Intentar obtener desde PlayState si está disponible
        try
        {
            var playState = cast(FlxG.state, funkin.gameplay.PlayState);
            if (playState != null && playState.optimizationManager != null && playState.optimizationManager.gpuRenderer != null)
            {
                return playState.optimizationManager.gpuRenderer.drawCalls;
            }
        }
        catch (e:Dynamic) {}
        
        return 0;
    }
    
    /**
     * Obtener sprites renderizados desde OptimizationManager (si existe)
     */
    private function getSpritesRendered():Int
    {
        // Verificar que FlxG y FlxG.state estén disponibles
        if (FlxG.state == null)
            return 0;
            
        try
        {
            var playState = cast(FlxG.state, funkin.gameplay.PlayState);
            if (playState != null && playState.optimizationManager != null && playState.optimizationManager.gpuRenderer != null)
            {
                return playState.optimizationManager.gpuRenderer.spritesRendered;
            }
        }
        catch (e:Dynamic) {}
        
        return 0;
    }
}