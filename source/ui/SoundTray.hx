package ui;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.tweens.FlxTween;
import flixel.util.FlxTimer;

class SoundTray extends FlxTypedGroup<FlxSprite>
{
    private var volumeBox:FlxSprite;
    private var volumeBar:FlxSprite;
    
    private var volumeUpSound:String = "assets/sounds/soundtray/Volup.ogg";
    private var volumeDownSound:String = "assets/sounds/soundtray/Voldown.ogg";
    private var volumeMaxSound:String = "assets/sounds/soundtray/VolMAX.ogg";
    
    private var hideTimer:FlxTimer;
    private var currentTween:FlxTween;
    
    private var isShowing:Bool = false;
    private var isMuted:Bool = false;
    private var volumeBeforeMute:Float = 1.0;
    
    public function new()
    {
        super();
        
        // Cargar volumen guardado
        loadVolume();
        
        // Crear el contenedor del volumen
        volumeBox = new FlxSprite(0, 0);
        volumeBox.loadGraphic("assets/images/soundtray/volumebox.png");
        volumeBox.scale.set(0.7,0.7);
        volumeBox.updateHitbox();
        volumeBox.screenCenter(X);
        volumeBox.scrollFactor.set();
        add(volumeBox);
        
        // Crear las barras de volumen
        volumeBar = new FlxSprite(volumeBox.x, volumeBox.y);
        volumeBar.loadGraphic("assets/images/soundtray/bars_10.png");
        volumeBar.scale.set(0.7,0.7);
        volumeBar.updateHitbox();
        volumeBar.scrollFactor.set();
        add(volumeBar);
        
        // Calcular altura total y esconder completamente fuera de pantalla
        var totalHeight = Math.max(volumeBox.height, volumeBar.height);
        var hiddenY = -(totalHeight + 40); // +40 píxeles extra para asegurar que esté oculto
        
        volumeBox.y = hiddenY;
        volumeBar.y = hiddenY;
        
        // Timer para ocultar
        hideTimer = new FlxTimer();
        
        updateVolumeBar();
    }
    
    public function show():Void
    {
        if (currentTween != null)
            currentTween.cancel();
        
        // Cancelar timer anterior
        hideTimer.cancel();
        
        // Animar entrada
        currentTween = FlxTween.tween(volumeBox, {y: 10}, 0.3, {
            onComplete: function(twn:FlxTween) {
                // Iniciar timer para ocultar después de 1 segundo
                hideTimer.start(1.0, function(tmr:FlxTimer) {
                    hide();
                });
            }
        });
        
        // Mover también las barras
        FlxTween.tween(volumeBar, {y: 10}, 0.3);
        
        isShowing = true;
    }
    
    public function hide():Void
    {
        if (currentTween != null)
            currentTween.cancel();
        
        // Calcular posición para esconder completamente
        var totalHeight = Math.max(volumeBox.height, volumeBar.height);
        var hiddenY = -(totalHeight + 40); // +40 píxeles extra
        
        // Animar salida - ambos sprites a la misma posición
        currentTween = FlxTween.tween(volumeBox, {y: hiddenY}, 0.3);
        FlxTween.tween(volumeBar, {y: hiddenY}, 0.3);
        
        isShowing = false;
    }
    
    public function volumeUp():Void
    {
        // Si está muteado, desactivar mute primero
        if (isMuted)
        {
            isMuted = false;
            FlxG.sound.volume = volumeBeforeMute;
        }
        
        var newVolume:Float = FlxG.sound.volume + 0.1;
        
        if (newVolume > 1.0)
        {
            newVolume = 1.0;
            FlxG.sound.play(volumeMaxSound);
        }
        else
        {
            FlxG.sound.play(volumeUpSound);
        }
        
        FlxG.sound.volume = newVolume;
        saveVolume(); // Guardar volumen
        updateVolumeBar();
        show();
    }
    
    public function volumeDown():Void
    {
        // Si está muteado, desactivar mute primero
        if (isMuted)
        {
            isMuted = false;
            FlxG.sound.volume = volumeBeforeMute;
        }
        
        var newVolume:Float = FlxG.sound.volume - 0.1;
        
        if (newVolume < 0.0)
            newVolume = 0.0;
        
        FlxG.sound.play(volumeDownSound);
        FlxG.sound.volume = newVolume;
        saveVolume(); // Guardar volumen
        updateVolumeBar();
        show();
    }
    
    private function updateVolumeBar():Void
    {
        // Convertir volumen (0.0 - 1.0) a nivel de barras (1-10)
        var barLevel:Int = Math.floor(FlxG.sound.volume * 10);
        
        if (barLevel < 1)
            barLevel = 1;
        if (barLevel > 10)
            barLevel = 10;
        
        // Cargar la imagen correspondiente
        volumeBar.loadGraphic("assets/images/soundtray/bars_" + barLevel + ".png");
        
        // Centrar horizontalmente las barras con respecto al volumeBox
        volumeBar.x = volumeBox.x + (volumeBox.width - volumeBar.width) / 2 + 35;
        volumeBar.y = volumeBox.y + 50;
    }
    
    // Guardar volumen en FlxG.save
    private function saveVolume():Void
    {
        FlxG.save.data.volume = FlxG.sound.volume;
        FlxG.save.data.muted = isMuted;
        FlxG.save.flush();
    }
    
    // Cargar volumen desde FlxG.save
    private function loadVolume():Void
    {
        if (FlxG.save.data.volume != null)
        {
            FlxG.sound.volume = FlxG.save.data.volume;
        }
        else
        {
            FlxG.sound.volume = 1.0; // Volumen por defecto
        }
        
        if (FlxG.save.data.muted != null)
        {
            isMuted = FlxG.save.data.muted;
            if (isMuted)
            {
                volumeBeforeMute = FlxG.sound.volume;
                FlxG.sound.volume = 0;
            }
        }
    }
    
    // Función de mute/unmute
    public function toggleMute():Void
    {
        if (isMuted)
        {
            // Unmute
            isMuted = false;
            FlxG.sound.volume = volumeBeforeMute;
            FlxG.sound.play(volumeUpSound);
        }
        else
        {
            // Mute
            isMuted = true;
            volumeBeforeMute = FlxG.sound.volume;
            FlxG.sound.volume = 0;
            FlxG.sound.play(volumeDownSound);
        }
        
        updateVolumeBar();
        saveVolume();
        show();
    }
    
    override public function update(elapsed:Float):Void
    {
        super.update(elapsed);
        
        // Detectar tecla 0 para mute
        if (FlxG.keys.justPressed.ZERO || FlxG.keys.justPressed.NUMPADZERO)
        {
            toggleMute();
        }
        
        // Detectar teclas de volumen
        if (FlxG.keys.justPressed.PLUS || FlxG.keys.justPressed.NUMPADPLUS)
        {
            volumeUp();
        }
        
        if (FlxG.keys.justPressed.MINUS || FlxG.keys.justPressed.NUMPADMINUS)
        {
            volumeDown();
        }
    }
    
    override public function destroy():Void
    {
        // IMPORTANTE: NO destruir el SoundTray para que persista entre estados
        // Solo limpiamos timers y tweens activos para evitar problemas
        
        if (hideTimer != null)
        {
            hideTimer.cancel();
            hideTimer = null;
        }
        
        if (currentTween != null)
        {
            currentTween.cancel();
            currentTween = null;
        }
        
        // Recrear el timer para el próximo estado
        hideTimer = new FlxTimer();
        
        // NO llamar a super.destroy() - esto mantiene los sprites vivos
    }
}
