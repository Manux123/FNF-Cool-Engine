package states;

import flixel.util.FlxTimer;
import lime.utils.Assets;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import openfl.display.BitmapData;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import options.data.KeyBinds;
import flash.display.BitmapData;
import states.TitleState;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

class CacheState extends MusicBeatState
{
    var toBeFinished:Int = 0;
    var finished:Int = 0;
    var loadingBar:FlxSprite;
    var loadingText:FlxText;
    var loadingPercentage:FlxText;
    
    var isLoading:Bool = true;
    var loadingComplete:Bool = false;
    
    // Rutas de carpetas a cachear
    var characterPaths:Array<String> = [];
    var objectPaths:Array<String> = [];
    var soundPaths:Array<String> = [];
    var musicPaths:Array<String> = [];
    
    // Timer para ir al siguiente state
    var waitTimer:FlxTimer;
    
    override function create()
    {
        FlxG.mouse.visible = false;
        FlxG.sound.muteKeys = null;

        Highscore.load();
        KeyBinds.keyCheck();
        PlayerSettings.init();
        PlayerSettings.player1.controls.loadKeyBinds();

        if(FlxG.save.data.FPSCap)
            openfl.Lib.current.stage.frameRate = 120;
        else
            openfl.Lib.current.stage.frameRate = 240;

        // Background
        var bg:FlxSprite = new FlxSprite().loadGraphic(BitmapData.fromFile(Paths.image('menu/menuBG')));
        add(bg);

        // Barra de carga visual
        var barBG:FlxSprite = new FlxSprite(0, 650).makeGraphic(FlxG.width - 100, 30, FlxColor.BLACK);
        barBG.screenCenter(X);
        add(barBG);

        loadingBar = new FlxSprite(barBG.x + 5, barBG.y + 5).makeGraphic(1, 20, FlxColor.LIME);
        add(loadingBar);

        // Texto de carga
        loadingText = new FlxText(0, 600, FlxG.width, "Loading...");
        loadingText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        add(loadingText);

        loadingPercentage = new FlxText(0, 680, FlxG.width, "0%");
        loadingPercentage.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        add(loadingPercentage);

        // NUEVO: Modo simplificado de carga
        // En lugar de cachear todo, solo cargamos lo esencial
        loadEssentialAssets();

        super.create();
    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);

        if (isLoading && !loadingComplete)
        {
            var percentage:Float = toBeFinished > 0 ? (finished / toBeFinished) * 100 : 0;
            loadingPercentage.text = Math.floor(percentage) + "%";
            
            // Actualizar barra de carga
            if (toBeFinished > 0)
            {
                var barWidth:Int = Std.int((FlxG.width - 110) * (finished / toBeFinished));
                loadingBar.makeGraphic(barWidth > 0 ? barWidth : 1, 20, FlxColor.LIME);
            }
            
            // Verificar si terminó
            if (finished >= toBeFinished && toBeFinished > 0)
            {
                completeLoading();
            }
        }
    }

    // NUEVO: Método simplificado que solo carga assets esenciales
    function loadEssentialAssets():Void
    {
        trace("Loading essential assets...");
        
        // Lista manual de assets esenciales
        var essentialSounds:Array<String> = [
            "confirmMenu",
            "cancelMenu",
            "scrollMenu"
        ];
        
        var essentialImages:Array<String> = [
            "menu/menuBG",
            "menu/menuDesat"
        ];
        
        toBeFinished = essentialSounds.length + essentialImages.length;
        finished = 0;
        
        // Cargar sonidos esenciales
        for (sound in essentialSounds)
        {
            try
            {
                var soundPath:String = 'sounds/$sound';
                
                // Verificar si existe antes de intentar cargar
                if (Assets.exists('assets/$soundPath.ogg') || Assets.exists('assets/shared/$soundPath.ogg'))
                {
                    // No usar FlxG.sound.cache() - da problemas
                    // En su lugar, solo verificar que existe
                    trace('Found sound: $soundPath');
                }
                else
                {
                    trace('Warning: Sound not found: $soundPath');
                }
            }
            catch (e:Dynamic)
            {
                trace('Error checking sound: $sound - $e');
            }
            
            finished++;
        }
        
        // Cargar imágenes esenciales
        for (image in essentialImages)
        {
            try
            {
                if (Assets.exists('assets/images/$image.png'))
                {
                    // Precargar imagen - CORREGIDO: sin parámetros opcionales
                    var graphic = FlxG.bitmap.add('assets/images/$image.png');
                    if (graphic != null)
                    {
                        graphic.persist = true;
                        trace('Cached image: $image');
                    }
                }
                else
                {
                    trace('Warning: Image not found: $image');
                }
            }
            catch (e:Dynamic)
            {
                trace('Error caching image: $image - $e');
            }
            
            finished++;
        }
        
        loadingText.text = "Loading complete!";
        
        // Esperar un poco antes de continuar
        new FlxTimer().start(0.5, function(tmr:FlxTimer)
        {
            completeLoading();
        });
    }

    function completeLoading():Void
    {
        if (loadingComplete) return;
        
        loadingComplete = true;
        isLoading = false;
        
        loadingText.text = "Done!";
        loadingPercentage.text = "100%";
        
        trace("Cache loading complete, transitioning to TitleState...");
        
        // Intentar reproducir sonido de confirmación
        try
        {
            FlxG.sound.play(Paths.sound('confirmMenu'), 1, false, null, false, function()
            {
                goToTitle();
            });
        }
        catch (e:Dynamic)
        {
            trace('Could not play confirm sound: $e');
            // Si falla el sonido, ir directo al título
            new FlxTimer().start(0.3, function(tmr:FlxTimer)
            {
                goToTitle();
            });
        }
    }
    
    function goToTitle():Void
    {
        FlxG.autoPause = true;
        LoadingState.loadAndSwitchState(new TitleState(), true);
        FlxG.camera.fade(FlxColor.BLACK, 0.8, false);
    }
}

// CORREGIDO: Image Cache System simplificado
class ImageCache
{
    public static var cache:Map<String, FlxGraphic> = new Map<String, FlxGraphic>();

    public static function add(path:String):Void
    {
        if (cache.exists(path))
            return; // Ya está en caché
        
        try
        {
            #if sys
            if (FileSystem.exists(path))
            {
                var data:FlxGraphic = FlxGraphic.fromBitmapData(BitmapData.fromFile(path));
                if (data != null)
                {
                    data.persist = true;
                    cache.set(path, data);
                }
            }
            #else
            if (Assets.exists(path))
            {
                var data:FlxGraphic = FlxG.bitmap.add(path);
                if (data != null)
                {
                    data.persist = true;
                    cache.set(path, data);
                }
            }
            #end
        }
        catch (e:Dynamic)
        {
            trace('Error adding to cache: $path - $e');
        }
    }

    public static function get(path:String):FlxGraphic
    {
        return cache.get(path);
    }

    public static function exists(path:String):Bool
    {
        return cache.exists(path);
    }

    public static function clear():Void
    {
        for (key in cache.keys())
        {
            var graphic:FlxGraphic = cache.get(key);
            if (graphic != null)
            {
                graphic.persist = false;
                graphic.destroy();
            }
        }
        cache.clear();
    }
}
