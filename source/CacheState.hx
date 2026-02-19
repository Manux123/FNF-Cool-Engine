package;

import flixel.util.FlxTimer;
import lime.utils.Assets;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import openfl.display.BitmapData;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import funkin.data.KeyBinds;
import flash.display.BitmapData;
import funkin.menus.TitleState;
import funkin.gameplay.objects.hud.Highscore;
import data.PlayerSettings;
import funkin.states.LoadingState;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

class CacheState extends funkin.states.MusicBeatState
{
    var toBeFinished:Int = 0;
    var finished:Int = 0;
    var loadingBar:FlxSprite;
    var loadingText:FlxText;
    var loadingPercentage:FlxText;
    var loadingDetails:FlxText;
    
    var isLoading:Bool = true;
    var loadingComplete:Bool = false;
    
    var assetsToCache:Array<AssetInfo> = [];
    var currentAssetIndex:Int = 0;
    
    override function create()
    {
        FlxG.mouse.visible = false;
        
        Highscore.load();
        KeyBinds.keyCheck();
        PlayerSettings.init();
        PlayerSettings.player1.controls.loadKeyBinds();

        if(FlxG.save.data.FPSCap)
            openfl.Lib.current.stage.frameRate = 120;
        else
            openfl.Lib.current.stage.frameRate = 240;
/*
        var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menu/loading/funkay'));
        bg.scale.set(0.8,0.8);
        bg.scrollFactor.set();
        bg.antialiasing = FlxG.save.data.antialiasing;
        bg.updateHitbox();
        bg.screenCenter();
        add(bg);

        var bg2:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menu/loading/chars'));
        bg2.scale.set(0.65,0.65);
        bg2.scrollFactor.set();
        bg2.antialiasing = FlxG.save.data.antialiasing;
        bg2.updateHitbox();
        bg2.screenCenter();
        add(bg2);*/

        var barBG:FlxSprite = new FlxSprite(0, 500).makeGraphic(FlxG.width - 100, 40, 0xFF333333);
        barBG.screenCenter(X);
        add(barBG);

        loadingBar = new FlxSprite(barBG.x + 5, barBG.y + 5).makeGraphic(10, 30, FlxColor.LIME);
        add(loadingBar);

        loadingText = new FlxText(0, 450, FlxG.width, "Scanning assets...");
        loadingText.setFormat(Paths.font("Funkin.otf"), 28, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        add(loadingText);

        loadingPercentage = new FlxText(0, 550, FlxG.width, "0%");
        loadingPercentage.setFormat(Paths.font("Funkin.otf"), 24, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        add(loadingPercentage);
        
        loadingDetails = new FlxText(0, 600, FlxG.width, "");
        loadingDetails.setFormat(Paths.font("Funkin.otf"), 16, FlxColor.GRAY, CENTER, OUTLINE, FlxColor.BLACK);
        add(loadingDetails);

        // Escanear automáticamente
        scanAndPrepareAssets();

        super.create();
    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);

        if (isLoading && !loadingComplete && currentAssetIndex < assetsToCache.length)
        {
            for (i in 0...5)
            {
                if (currentAssetIndex >= assetsToCache.length)
                    break;
                
                cacheAsset(assetsToCache[currentAssetIndex]);
                currentAssetIndex++;
                finished++;
            }
            
            updateLoadingUI();
            
            if (currentAssetIndex >= assetsToCache.length)
            {
                completeLoading();
            }
        }
    }

    /**
     * ESCANEO AUTOMÁTICO DE ASSETS
     * Detecta todos los archivos en las carpetas importantes
     */
    function scanAndPrepareAssets():Void
    {
        trace("=== Auto-scanning assets ===");
        
        #if sys
        // Sistema de archivos disponible - escanear carpetas
        scanSoundsFolder("assets/sounds", "Sounds");
        scanImagesFolder("assets/images", "Images");
        scanStagesFolder("assets/stages");
        #else
        // Web/HTML5 - usar lista mínima fallback
        trace("File system not available - using minimal fallback");
        useFallbackList();
        #end
        
        toBeFinished = assetsToCache.length;
        finished = 0;
        
        trace('Total assets found: $toBeFinished');
        loadingText.text = "Caching assets...";
    }

    /**
     * Escanear carpeta de sonidos recursivamente
     */
    #if sys
    function scanSoundsFolder(directory:String, category:String):Void
    {
        if (!FileSystem.exists(directory) || !FileSystem.isDirectory(directory))
        {
            trace('Directory not found: $directory');
            return;
        }
        
        try
        {
            var files = FileSystem.readDirectory(directory);
            
            for (file in files)
            {
                var fullPath = '$directory/$file';
                
                if (FileSystem.isDirectory(fullPath))
                {
                    // Escanear subdirectorio recursivamente
                    var subCategory = '$category/${file}';
                    scanSoundsFolder(fullPath, subCategory);
                }
                else
                {
                    // Verificar si es archivo de audio
                    if (file.endsWith('.ogg') || file.endsWith('.mp3'))
                    {
                        // Obtener path relativo sin assets/sounds/ y sin extensión
                        var relativePath = fullPath.replace('assets/sounds/', '');
                        relativePath = relativePath.substring(0, relativePath.lastIndexOf('.'));
                        
                        assetsToCache.push({
                            type: SOUND,
                            path: relativePath,
                            category: category,
                            fullPath: Paths.sound(relativePath)
                        });
                        
                        trace('Found sound: $relativePath');
                    }
                }
            }
        }
        catch (e:Dynamic)
        {
            trace('Error scanning sounds folder $directory: $e');
        }
    }
    #end

    /**
     * Escanear carpeta de imágenes recursivamente
     * EXCLUYE: characters (muy pesado), stages (se escanean aparte)
     */
    #if sys
    function scanImagesFolder(directory:String, category:String):Void
    {
        if (!FileSystem.exists(directory) || !FileSystem.isDirectory(directory))
        {
            trace('Directory not found: $directory');
            return;
        }
        
        try
        {
            var files = FileSystem.readDirectory(directory);
            
            for (file in files)
            {
                var fullPath = '$directory/$file';
                
                if (FileSystem.isDirectory(fullPath))
                {
                    // EXCLUIR carpetas pesadas que se cargan dinámicamente
                    if (file == 'characters' || file == 'stages')
                    {
                        trace('Skipping heavy folder: $file');
                        continue;
                    }
                    
                    // Escanear subdirectorio
                    var subCategory = '$category/${file}';
                    scanImagesFolder(fullPath, subCategory);
                }
                else
                {
                    // Solo .png (evitar .xml, .txt, etc)
                    if (file.endsWith('.png'))
                    {
                        var relativePath = fullPath.replace('assets/images/', '');
                        relativePath = relativePath.substring(0, relativePath.lastIndexOf('.'));
                        
                        assetsToCache.push({
                            type: IMAGE,
                            path: relativePath,
                            category: category,
                            fullPath: Paths.image(relativePath)
                        });
                        
                        trace('Found image: $relativePath');
                    }
                }
            }
        }
        catch (e:Dynamic)
        {
            trace('Error scanning images folder $directory: $e');
        }
    }
    #end

    /**
     * Escanear stages (solo stage por defecto para no sobrecargar)
     */
    #if sys
    function scanStagesFolder(directory:String):Void
    {
        if (!FileSystem.exists(directory) || !FileSystem.isDirectory(directory))
        {
            trace('Stages directory not found');
            return;
        }
        
        try
        {
            // Solo cachear el stage por defecto
            var defaultStage = '$directory/stage/images';
            
            if (FileSystem.exists(defaultStage) && FileSystem.isDirectory(defaultStage))
            {
                var files = FileSystem.readDirectory(defaultStage);
                
                for (file in files)
                {
                    if (file.endsWith('.png'))
                    {
                        var imageName = file.substring(0, file.lastIndexOf('.'));
                        var fullPath = 'assets/stages/stage/images/$file';
                        
                        assetsToCache.push({
                            type: IMAGE,
                            path: 'stage/$imageName',
                            category: 'Stage',
                            fullPath: fullPath
                        });
                        
                        trace('Found stage image: $imageName');
                    }
                }
            }
        }
        catch (e:Dynamic)
        {
            trace('Error scanning stages: $e');
        }
    }
    #end

    /**
     * Lista mínima de fallback para cuando no hay sistema de archivos
     * (HTML5, etc)
     */
    function useFallbackList():Void
    {
        var essentialSounds = [
            "menus/confirmMenu", "menus/cancelMenu", "menus/scrollMenu",
            "soundtray/Volup", "soundtray/Voldown", "soundtray/VolMAX"
        ];
        
        var essentialImages = [
            "alphabet", "healthBar",
            "soundtray/volumebox",
            "soundtray/bars_1", "soundtray/bars_2", "soundtray/bars_3",
            "soundtray/bars_4", "soundtray/bars_5", "soundtray/bars_6",
            "soundtray/bars_7", "soundtray/bars_8", "soundtray/bars_9",
            "soundtray/bars_10"
        ];
        
        for (sound in essentialSounds)
        {
            assetsToCache.push({
                type: SOUND,
                path: sound,
                category: "Essential",
                fullPath: Paths.sound(sound)
            });
        }
        
        for (image in essentialImages)
        {
            assetsToCache.push({
                type: IMAGE,
                path: image,
                category: "Essential",
                fullPath: Paths.image(image)
            });
        }
    }

    function cacheAsset(asset:AssetInfo):Void
    {
        try
        {
            switch (asset.type)
            {
                case SOUND:
                    if (Assets.exists(asset.fullPath))
                    {
                        FlxG.sound.load(asset.fullPath, 0.0, false);
                        trace('✓ Cached sound: ${asset.path}');
                    }
                    else
                    {
                        trace('⚠ Sound not found: ${asset.path}');
                    }
                    
                case IMAGE:
                    if (Assets.exists(asset.fullPath))
                    {
                        var graphic = FlxG.bitmap.add(asset.fullPath);
                        if (graphic != null)
                        {
                            // NO marcar como persist - dejar que FlxG.bitmap maneje el caché
                            // Esto previene memory leaks masivos
                            trace('✓ Cached image: ${asset.path}');
                        }
                    }
                    else
                    {
                        trace('⚠ Image not found: ${asset.path}');
                    }
            }
        }
        catch (e:Dynamic)
        {
            trace('Error caching ${asset.path}: $e');
        }
    }

    function updateLoadingUI():Void
    {
        var percentage:Float = toBeFinished > 0 ? (finished / toBeFinished) * 100 : 0;
        loadingPercentage.text = Math.floor(percentage) + "%";
        
        if (toBeFinished > 0)
        {
            var barWidth:Int = Std.int((FlxG.width - 110) * (finished / toBeFinished));
            loadingBar.makeGraphic(barWidth > 0 ? barWidth : 10, 30, FlxColor.LIME);
        }
        
        if (currentAssetIndex < assetsToCache.length)
        {
            var current = assetsToCache[currentAssetIndex];
            loadingDetails.text = '${current.category}: ${current.path}';
        }
    }

    function completeLoading():Void
    {
        if (loadingComplete) return;
        
        loadingComplete = true;
        isLoading = false;
        
        loadingText.text = "Loading Complete!";
        loadingPercentage.text = "100%";
        loadingDetails.text = "Starting game...";
        
        trace("=== Cache loading complete ===");
        trace('Cached $finished assets');
        
        new FlxTimer().start(0.5, function(tmr:FlxTimer)
        {
            try
            {
                FlxG.sound.play(Paths.sound('menus/confirmMenu'), 0.7);
            }
            catch (e:Dynamic)
            {
                trace('Could not play confirm sound: $e');
            }
            
            new FlxTimer().start(0.3, function(tmr:FlxTimer)
            {
                goToTitle();
            });
        });
    }
    
    function goToTitle():Void
    {
        FlxG.autoPause = true;
        LoadingState.loadAndSwitchState(new TitleState(), true);
        FlxG.camera.fade(FlxColor.BLACK, 0.8, false);
    }
}

typedef AssetInfo =
{
    var type:AssetType;
    var path:String;
    var category:String;
    var fullPath:String;
}

enum AssetType
{
    SOUND;
    IMAGE;
}
