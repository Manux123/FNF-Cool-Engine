package ui;

import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.tweens.FlxTween;
import flixel.util.FlxTimer;

/**
 * SoundTray como FlxBasic plugin — se registra UNA vez en Main.hx y persiste entre states.
 * 
 * En Main.hx (dentro de setupGame o donde inicialices FlxG), agregar:
 *     FlxG.plugins.add(new SoundTray());
 * 
 * Ya NO hace falta agregarlo en ningún state individual.
 */
class SoundTray extends FlxBasic
{
    private var volumeBox:FlxSprite;
    private var volumeBar:FlxSprite;

    private var volumeUpSound:String   = "assets/sounds/soundtray/Volup.ogg";
    private var volumeDownSound:String = "assets/sounds/soundtray/Voldown.ogg";
    private var volumeMaxSound:String  = "assets/sounds/soundtray/VolMAX.ogg";

    private var hideTimer:FlxTimer;
    private var currentTween:FlxTween;

    private var isShowing:Bool  = false;
    private var isMuted:Bool    = false;
    private var volumeBeforeMute:Float = 1.0;

    // Cámara dedicada y transparente — siempre encima de todo.
    // Se re-crea automáticamente si un state transition la destruye.
    private var trayCam:FlxCamera;

    public function new()
    {
        super();

        // Cargar volumen guardado antes de crear los sprites
        loadVolume();

        // --- Sprite del contenedor ---
        volumeBox = new FlxSprite(0, 0);
        volumeBox.loadGraphic("assets/images/soundtray/volumebox.png");
        volumeBox.scale.set(0.7, 0.7);
        volumeBox.updateHitbox();
        volumeBox.screenCenter(X);
        volumeBox.scrollFactor.set(0, 0);

        // --- Sprite de las barras ---
        volumeBar = new FlxSprite(0, 0);
        volumeBar.loadGraphic("assets/images/soundtray/bars_10.png");
        volumeBar.scale.set(0.7, 0.7);
        volumeBar.updateHitbox();
        volumeBar.scrollFactor.set(0, 0);

        // Esconder ambos fuera de pantalla
        var hiddenY:Float = -(Math.max(volumeBox.height, volumeBar.height) + 20);
        volumeBox.y = hiddenY;
        volumeBar.y = hiddenY;

        hideTimer = new FlxTimer();

        updateVolumeBar();
        ensureCamera();
    }

    // -------------------------------------------------------------------------
    // Cámara dedicada
    // -------------------------------------------------------------------------

    /**
     * Crea (o re-crea) la cámara transparente del SoundTray.
     * FlxG.cameras.reset() la destruye en cada state switch, así que
     * la revisamos en draw() y la regeneramos si hace falta.
     */
    private function ensureCamera():Void
    {
        if (trayCam != null && FlxG.cameras.list.contains(trayCam))
            return;

        trayCam = new FlxCamera();
        trayCam.bgColor = 0x00000000; // totalmente transparente
        // false = no establecer como cámara por defecto
        FlxG.cameras.add(trayCam, false);
    }

    // -------------------------------------------------------------------------
    // Plugin lifecycle — update y draw se llaman automáticamente por FlxG
    // -------------------------------------------------------------------------

    override public function update(elapsed:Float):Void
    {
        super.update(elapsed);

        // Actualizar los sprites manualmente (posición, tween, etc.)
        volumeBox.update(elapsed);
        volumeBar.update(elapsed);

        // Teclas de volumen — siempre activas sin importar el state
        if (FlxG.keys.justPressed.ZERO || FlxG.keys.justPressed.NUMPADZERO)
            toggleMute();

        if (FlxG.keys.justPressed.PLUS || FlxG.keys.justPressed.NUMPADPLUS)
            volumeUp();

        if (FlxG.keys.justPressed.MINUS || FlxG.keys.justPressed.NUMPADMINUS)
            volumeDown();
    }

    override public function draw():Void
    {
        // Re-crear la cámara si fue destruida por un state switch
        ensureCamera();

        volumeBox.cameras = [trayCam];
        volumeBar.cameras = [trayCam];

        volumeBox.draw();
        volumeBar.draw();
    }

    // -------------------------------------------------------------------------
    // Mostrar / Ocultar
    // -------------------------------------------------------------------------

    public function show():Void
    {
        if (currentTween != null)
            currentTween.cancel();

        hideTimer.cancel();

        currentTween = FlxTween.tween(volumeBox, {y: 10}, 0.3, {
            onComplete: function(_) {
                hideTimer.start(1.0, function(_) { hide(); });
            }
        });
        FlxTween.tween(volumeBar, {y: 10}, 0.3);

        isShowing = true;
    }

    public function hide():Void
    {
        if (currentTween != null)
            currentTween.cancel();

        var hiddenY:Float = -(Math.max(volumeBox.height, volumeBar.height) + 20);

        currentTween = FlxTween.tween(volumeBox, {y: hiddenY}, 0.3);
        FlxTween.tween(volumeBar, {y: hiddenY}, 0.3);

        isShowing = false;
    }

    // -------------------------------------------------------------------------
    // Control de volumen
    // -------------------------------------------------------------------------

    public function volumeUp():Void
    {
        if (isMuted)
        {
            isMuted = false;
            FlxG.sound.volume = volumeBeforeMute;
        }

        var newVolume:Float = FlxG.sound.volume + 0.1;
        if (newVolume >= 1.0)
        {
            newVolume = 1.0;
            FlxG.sound.play(volumeMaxSound);
        }
        else
        {
            FlxG.sound.play(volumeUpSound);
        }

        FlxG.sound.volume = newVolume;
        saveVolume();
        updateVolumeBar();
        show();
    }

    public function volumeDown():Void
    {
        if (isMuted)
        {
            isMuted = false;
            FlxG.sound.volume = volumeBeforeMute;
        }

        var newVolume:Float = FlxG.sound.volume - 0.1;
        if (newVolume < 0.0) newVolume = 0.0;

        FlxG.sound.play(volumeDownSound);
        FlxG.sound.volume = newVolume;
        saveVolume();
        updateVolumeBar();
        show();
    }

    public function toggleMute():Void
    {
        if (isMuted)
        {
            isMuted = false;
            FlxG.sound.volume = volumeBeforeMute;
            FlxG.sound.play(volumeUpSound);
        }
        else
        {
            isMuted = true;
            volumeBeforeMute = FlxG.sound.volume;
            FlxG.sound.volume = 0;
            FlxG.sound.play(volumeDownSound);
        }

        updateVolumeBar();
        saveVolume();
        show();
    }

    // -------------------------------------------------------------------------
    // Helpers internos
    // -------------------------------------------------------------------------

    private function updateVolumeBar():Void
    {
        var barLevel:Int = Math.floor(FlxG.sound.volume * 10);
        if (barLevel < 1)  barLevel = 1;
        if (barLevel > 10) barLevel = 10;

        volumeBar.loadGraphic("assets/images/soundtray/bars_" + barLevel + ".png");
        volumeBar.scale.set(0.7, 0.7);
        volumeBar.updateHitbox();

        // Centrar barras respecto al volumeBox
        volumeBar.x = volumeBox.x + (volumeBox.width - volumeBar.width) / 2;
        volumeBar.y = volumeBox.y + 50;
    }

    private function saveVolume():Void
    {
        FlxG.save.data.volume = FlxG.sound.volume;
        FlxG.save.data.muted  = isMuted;
        FlxG.save.flush();
    }

    private function loadVolume():Void
    {
        FlxG.sound.volume = (FlxG.save.data.volume != null) ? FlxG.save.data.volume : 1.0;

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
    // destroy() NO se sobreescribe — el plugin vive para siempre con FlxG
}