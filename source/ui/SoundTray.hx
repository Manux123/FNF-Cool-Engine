package ui;

import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.tweens.FlxTween;
import flixel.util.FlxTimer;

/**
 * SoundTray — misma base de imágenes del original, con dos mejoras:
 *
 *  1. "Barras fantasma": bars_10.png siempre visible a alpha bajo,
 *     para que los huecos de volumen no desaparezcan, solo se atenúen.
 *
 *  2. Las barras siguen al volumeBox directamente en update() —
 *     sin tween propio para las barras, todo se mueve junto.
 *
 * Registrar UNA vez en Main.hx:
 *     FlxG.plugins.add(new SoundTray());
 */
class SoundTray extends FlxBasic
{
    private var volumeBox:FlxSprite;      // fondo: volumebox.png
    private var volumeBarBg:FlxSprite;   // barras fantasma: bars_10.png alpha bajo
    private var volumeBar:FlxSprite;     // barras activas: bars_N.png

    private var volumeUpSound:String   = "assets/sounds/soundtray/Volup.ogg";
    private var volumeDownSound:String = "assets/sounds/soundtray/Voldown.ogg";
    private var volumeMaxSound:String  = "assets/sounds/soundtray/VolMAX.ogg";

    private var hideTimer:FlxTimer;
    private var currentTween:FlxTween;

    private var isShowing:Bool  = false;
    private var isMuted:Bool    = false;
    private var volumeBeforeMute:Float = 1.0;

    private var trayCam:FlxCamera;

    // Y objetivo cuando el tray está visible
    private static inline var SHOWN_Y:Float = 10;

    public function new()
    {
        super();

        loadVolume();

        // ── Fondo ────────────────────────────────────────────────────────────
        volumeBox = new FlxSprite(0, 0);
        volumeBox.loadGraphic("assets/images/soundtray/volumebox.png");
        volumeBox.scale.set(0.6, 0.6);
        volumeBox.updateHitbox();
        volumeBox.screenCenter(X);
        volumeBox.scrollFactor.set(0, 0);

        // ── Barras fantasma (siempre 10, alpha bajo) ──────────────────────
        volumeBarBg = new FlxSprite(0, 0);
        volumeBarBg.loadGraphic("assets/images/soundtray/bars_10.png");
        volumeBarBg.scale.set(0.6, 0.6);
        volumeBarBg.updateHitbox();
        volumeBarBg.scrollFactor.set(0, 0);
        volumeBarBg.alpha = 0.35; // visibles pero atenuadas

        // ── Barras activas (bars_N.png encima) ───────────────────────────
        volumeBar = new FlxSprite(0, 0);
        volumeBar.loadGraphic("assets/images/soundtray/bars_10.png");
        volumeBar.scale.set(0.6, 0.6);
        volumeBar.updateHitbox();
        volumeBar.scrollFactor.set(0, 0);

        // Esconder fuera de pantalla
        var hiddenY:Float = -(volumeBox.height + 20);
        volumeBox.y = hiddenY;

        hideTimer = new FlxTimer();

        updateVolumeBar();
        ensureCamera();
    }

    // ── Cámara dedicada ───────────────────────────────────────────────────────

    private function ensureCamera():Void
    {
        if (trayCam != null && FlxG.cameras.list.contains(trayCam))
            return;

        trayCam = new FlxCamera();
        trayCam.bgColor = 0x00000000;
        FlxG.cameras.add(trayCam, false);
    }

    // ── Plugin lifecycle ──────────────────────────────────────────────────────

    override public function update(elapsed:Float):Void
    {
        super.update(elapsed);

        volumeBox.update(elapsed);

        // Las barras se pegan al box — sin tween propio
        syncBarsToBox();

        volumeBarBg.update(elapsed);
        volumeBar.update(elapsed);

        // ✅ FIX: No procesar teclas de volumen si hay un campo de texto activo
        // Esto evita que al escribir +/- en editores se cambie el volumen
        var hasActiveTextField:Bool = false;
        #if flash
        if (flash.text.TextField.focus != null)
            hasActiveTextField = true;
        #end
        
        if (!hasActiveTextField)
        {
            // Teclas de volumen
            if (FlxG.keys.justPressed.ZERO || FlxG.keys.justPressed.NUMPADZERO)
                toggleMute();
            if (FlxG.keys.justPressed.PLUS || FlxG.keys.justPressed.NUMPADPLUS)
                volumeUp();
            if (FlxG.keys.justPressed.MINUS || FlxG.keys.justPressed.NUMPADMINUS)
                volumeDown();
        }
    }

    override public function draw():Void
    {
        ensureCamera();

        volumeBox.cameras    = [trayCam];
        volumeBarBg.cameras  = [trayCam];
        volumeBar.cameras    = [trayCam];

        volumeBox.draw();
        volumeBarBg.draw();  // fantasma debajo
        volumeBar.draw();    // activas encima
    }

    // ── Mostrar / Ocultar — SOLO el box tiene tween ───────────────────────────

    public function show():Void
    {
        if (currentTween != null) currentTween.cancel();
        if (hideTimer != null) hideTimer.cancel();

        currentTween = FlxTween.tween(volumeBox, {y: SHOWN_Y}, 0.3, {
            onComplete: function(_) {
                if (hideTimer != null) // ✅ FIX: Verificar null antes de usar
                    hideTimer.start(1.0, function(_) { hide(); });
            }
        });

        isShowing = true;
    }

    public function hide():Void
    {
        if (currentTween != null) currentTween.cancel();
        if (hideTimer != null) hideTimer.cancel(); // ✅ FIX: Verificar null antes de cancelar

        var hiddenY:Float = -(volumeBox.height + 20);
        currentTween = FlxTween.tween(volumeBox, {y: hiddenY}, 0.3);

        isShowing = false;
    }

    /**
     * ✅ FIX: Fuerza el ocultamiento inmediato del SoundTray
     * Útil al cambiar de estado para evitar que el tray se quede visible
     */
    public function forceHide():Void
    {
        if (currentTween != null) currentTween.cancel();
        if (hideTimer != null) hideTimer.cancel(); // ✅ FIX: Verificar null antes de cancelar
        
        var hiddenY:Float = -(volumeBox.height + 20);
        volumeBox.y = hiddenY; // Ocultar inmediatamente sin animación
        
        isShowing = false;
    }

    // ── Control de volumen ────────────────────────────────────────────────────

    public function volumeUp():Void
    {
        if (isMuted) { isMuted = false; FlxG.sound.volume = volumeBeforeMute; }

        var v = FlxG.sound.volume + 0.1;
        if (v >= 1.0) { v = 1.0; FlxG.sound.play(volumeMaxSound); }
        else            FlxG.sound.play(volumeUpSound);

        FlxG.sound.volume = v;
        saveVolume();
        updateVolumeBar();
        show();
    }

    public function volumeDown():Void
    {
        if (isMuted) { isMuted = false; FlxG.sound.volume = volumeBeforeMute; }

        var v = FlxG.sound.volume - 0.1;
        if (v < 0.0) v = 0.0;

        FlxG.sound.play(volumeDownSound);
        FlxG.sound.volume = v;
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

    // ── Helpers internos ──────────────────────────────────────────────────────

    private function syncBarsToBox():Void
    {
        // Las barras se colocan siempre centradas sobre el box — sin tween propio
        volumeBarBg.x = volumeBox.x + (volumeBox.width  - volumeBarBg.width)  / 2;
        volumeBarBg.y = volumeBox.y + (volumeBox.height - volumeBarBg.height) / 2 - 20;

        volumeBar.x = volumeBarBg.x;
        volumeBar.y = volumeBarBg.y;
    }

    private function updateVolumeBar():Void
    {
        var barLevel:Int = isMuted ? 0 : Math.floor(FlxG.sound.volume * 10);
        if (barLevel < 0)  barLevel = 0;
        if (barLevel > 10) barLevel = 10;

        // bars_0 no existe — mostrar barras activas con alpha 0 cuando muted/vol=0
        if (barLevel == 0)
        {
            volumeBar.alpha = 0;
        }
        else
        {
            volumeBar.loadGraphic("assets/images/soundtray/bars_" + barLevel + ".png");
            volumeBar.scale.set(0.6, 0.6);
            volumeBar.updateHitbox();
            volumeBar.alpha = 1.0;
        }

        syncBarsToBox();
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
            if (isMuted) { volumeBeforeMute = FlxG.sound.volume; FlxG.sound.volume = 0; }
        }
    }
    // destroy() NO se sobreescribe — el plugin vive para siempre con FlxG
}