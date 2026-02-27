package ui;

import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxTimer;

/**
 * SoundTray — persiste entre cambios de state igual que los stickers.
 *
 * SISTEMA: Mismo patrón que StickerTransition/StickerTransitionContainer:
 *  - SoundTrayContainer extiende openfl.display.Sprite
 *  - La FlxCamera es hijo del Sprite de OpenFL (NO de FlxG.cameras.list)
 *    → nunca se destruye cuando Flixel resetea las cámaras al cambiar state
 *  - Update via FlxG.signals.preUpdate (sobrevive cambios de state)
 *  - Insertado via FlxG.addChildBelowMouse con z muy alto (encima de stickers)
 *
 * FIXES adicionales:
 *  1. Sin doble volumen: limpia volumeUpKeys/volumeDownKeys/muteKeys de Flixel.
 *  2. Barras correctas: Math.round en vez de Math.floor (fix float 0.5999...).
 *  3. Fade in/out al mostrar/ocultar.
 */
class SoundTray extends FlxBasic
{
    // ── Contenedor OpenFL persistente ─────────────────────────────────────────
    private static var _container:SoundTrayContainer;

    // ── Sprites ───────────────────────────────────────────────────────────────
    private var volumeBox:FlxSprite;
    private var volumeBarBg:FlxSprite;
    private var volumeBar:FlxSprite;

    // ── Sonidos ───────────────────────────────────────────────────────────────
    private var volumeUpSound:String   = "assets/sounds/soundtray/Volup.ogg";
    private var volumeDownSound:String = "assets/sounds/soundtray/Voldown.ogg";
    private var volumeMaxSound:String  = "assets/sounds/soundtray/VolMAX.ogg";

    // ── Estado ────────────────────────────────────────────────────────────────
    private var hideTimer:FlxTimer;
    private var currentTween:FlxTween;
    private var alphaTween:FlxTween;

    private var isShowing:Bool  = false;
    private var isMuted:Bool    = false;
    private var volumeBeforeMute:Float = 1.0;

    // Indica si la barra activa debe mostrarse (false solo cuando vol=0/muted).
    // Separado de volumeBar.alpha para que _setAlpha no confunda "oculto por fade"
    // con "oculto porque no hay volumen" — sin esto, tras un hide la barra no
    // volvía a aparecer en el primer press porque alpha=0 bloqueaba el fade-in.
    private var _barVisible:Bool = false;

    private static inline var SHOWN_Y:Float   = 10;
    private static inline var TWEEN_TIME:Float = 0.3;

    public function new()
    {
        super();

        loadVolume();

        // ── FIX: desactivar teclas de volumen nativas de Flixel ───────────────
        // Sin esto, PLUS/MINUS lo procesa Flixel (+0.1) Y SoundTray (+0.1)
        // → el volumen sube 0.2 de golpe = 2 barras por pulsación.
        FlxG.sound.volumeUpKeys   = [];
        FlxG.sound.volumeDownKeys = [];
        FlxG.sound.muteKeys       = [];

        // ── Sprites ───────────────────────────────────────────────────────────
        volumeBox = new FlxSprite(0, 0);
        volumeBox.loadGraphic("assets/images/soundtray/volumebox.png");
        volumeBox.scale.set(0.6, 0.6);
        volumeBox.updateHitbox();
        volumeBox.screenCenter(X);
        volumeBox.scrollFactor.set(0, 0);

        volumeBarBg = new FlxSprite(0, 0);
        volumeBarBg.loadGraphic("assets/images/soundtray/bars_10.png");
        volumeBarBg.scale.set(0.6, 0.6);
        volumeBarBg.updateHitbox();
        volumeBarBg.scrollFactor.set(0, 0);
        volumeBarBg.alpha = 0.35;

        volumeBar = new FlxSprite(0, 0);
        volumeBar.loadGraphic("assets/images/soundtray/bars_10.png");
        volumeBar.scale.set(0.6, 0.6);
        volumeBar.updateHitbox();
        volumeBar.scrollFactor.set(0, 0);

        // Empezar oculto y transparente
        var hiddenY:Float = -(volumeBox.height + 20);
        volumeBox.y = hiddenY;
        _setAlpha(0);

        // ── CRÍTICO: globalManager → sobrevive cambios de state ──────────────
        hideTimer = new FlxTimer(FlxTimer.globalManager);

        updateVolumeBar();

        // ── Crear/reusar el contenedor OpenFL persistente ─────────────────────
        if (_container == null)
            _container = new SoundTrayContainer();

        _container.attachSprites(volumeBox, volumeBarBg, volumeBar);
        _container.insert();
    }

    // ── Plugin lifecycle ──────────────────────────────────────────────────────
    // El update de los sprites lo hace SoundTrayContainer via preUpdate signal.
    // Aquí solo manejamos input.

    override public function update(elapsed:Float):Void
    {
        super.update(elapsed);

        var hasActiveTextField:Bool = false;
        #if flash
        if (flash.text.TextField.focus != null)
            hasActiveTextField = true;
        #end

        if (!hasActiveTextField)
        {
            if (FlxG.keys.justPressed.ZERO || FlxG.keys.justPressed.NUMPADZERO)
                toggleMute();
            if (FlxG.keys.justPressed.PLUS || FlxG.keys.justPressed.NUMPADPLUS)
                volumeUp();
            if (FlxG.keys.justPressed.MINUS || FlxG.keys.justPressed.NUMPADMINUS)
                volumeDown();
        }
    }

    // El render lo maneja SoundTrayContainer — nada que hacer aquí.
    override public function draw():Void {}

    // ── Mostrar / Ocultar ─────────────────────────────────────────────────────

    public function show():Void
    {
        if (currentTween != null) currentTween.cancel();
        if (alphaTween   != null) alphaTween.cancel();
        if (hideTimer    != null) hideTimer.cancel();

        // globalManager → el tween no se destruye al cambiar de state
        currentTween = FlxTween.globalManager.tween(volumeBox, {y: SHOWN_Y}, TWEEN_TIME,
            {ease: FlxEase.quartOut});

        alphaTween = FlxTween.globalManager.num(volumeBox.alpha, 1.0, TWEEN_TIME,
            {ease: FlxEase.quartOut}, function(v) { _setAlpha(v); });

        isShowing = true;

        hideTimer.start(1.5, function(_) { hide(); });
    }

    public function hide():Void
    {
        if (currentTween != null) currentTween.cancel();
        if (alphaTween   != null) alphaTween.cancel();
        if (hideTimer    != null) hideTimer.cancel();

        var hiddenY:Float = -(volumeBox.height + 20);

        currentTween = FlxTween.globalManager.tween(volumeBox, {y: hiddenY}, TWEEN_TIME,
            {ease: FlxEase.quartIn});

        alphaTween = FlxTween.globalManager.num(volumeBox.alpha, 0.0, TWEEN_TIME,
            {ease: FlxEase.quartIn}, function(v) { _setAlpha(v); });

        isShowing = false;
    }

    public function forceHide():Void
    {
        if (currentTween != null) currentTween.cancel();
        if (alphaTween   != null) alphaTween.cancel();
        if (hideTimer    != null) hideTimer.cancel();

        var hiddenY:Float = -(volumeBox.height + 20);
        volumeBox.y = hiddenY;
        _setAlpha(0);

        isShowing = false;
    }

    // ── Control de volumen ────────────────────────────────────────────────────

    public function volumeUp():Void
    {
        if (isMuted) { isMuted = false; FlxG.sound.volume = volumeBeforeMute; }

        var v = _roundVol(FlxG.sound.volume + 0.1);
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

        var v = _roundVol(FlxG.sound.volume - 0.1);
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

    private inline function _setAlpha(a:Float):Void
    {
        volumeBox.alpha   = a;
        volumeBarBg.alpha = a * 0.35;
        volumeBar.alpha   = _barVisible ? a : 0;
    }

    private inline function _roundVol(v:Float):Float
        return Math.round(v * 10) / 10;

    private function syncBarsToBox():Void
    {
        volumeBarBg.x = volumeBox.x + (volumeBox.width  - volumeBarBg.width)  / 2;
        volumeBarBg.y = volumeBox.y + (volumeBox.height - volumeBarBg.height) / 2 - 20;
        volumeBar.x   = volumeBarBg.x;
        volumeBar.y   = volumeBarBg.y;
    }

    private function updateVolumeBar():Void
    {
        var barLevel:Int = isMuted ? 0 : Math.round(FlxG.sound.volume * 10);
        barLevel = Std.int(Math.max(0, Math.min(10, barLevel)));

        if (barLevel == 0)
        {
            _barVisible = false;
            volumeBar.alpha = 0;
        }
        else
        {
            _barVisible = true;
            volumeBar.loadGraphic("assets/images/soundtray/bars_" + barLevel + ".png");
            volumeBar.scale.set(0.6, 0.6);
            volumeBar.updateHitbox();
            volumeBar.alpha = volumeBox.alpha;
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
}

// ─────────────────────────────────────────────────────────────────────────────

/**
 * SoundTrayContainer — OpenFL Sprite persistente entre cambios de state.
 *
 * La clave: la FlxCamera es addChild() del Sprite (igual que StickerTransitionContainer),
 * NO está en FlxG.cameras.list. Flixel solo destruye las cámaras que están en
 * esa lista cuando cambia de state → la nuestra sobrevive siempre.
 *
 * Z-index 99999 → por encima de stickers (9999) y de cualquier state.
 */
@:access(flixel.FlxCamera)
class SoundTrayContainer extends openfl.display.Sprite
{
    private var trayCamera:FlxCamera;

    private var sprBox:FlxSprite;
    private var sprBg:FlxSprite;
    private var sprBar:FlxSprite;

    private var _updateConnected:Bool = false;

    public function new():Void
    {
        super();
        visible = false;

        trayCamera = new FlxCamera();
        trayCamera.bgColor = 0x00000000;
        addChild(trayCamera.flashSprite);

        FlxG.signals.gameResized.add((_, _) -> onResize());
        scrollRect = new openfl.geom.Rectangle();
        onResize();
    }

    /** Asigna los tres sprites del tray y los apunta a nuestra cámara. */
    public function attachSprites(box:FlxSprite, bg:FlxSprite, bar:FlxSprite):Void
    {
        sprBox = box;
        sprBg  = bg;
        sprBar = bar;

        sprBox.cameras = [trayCamera];
        sprBg.cameras  = [trayCamera];
        sprBar.cameras = [trayCamera];
    }

    /**
     * Inserta el container en OpenFL por encima de todo.
     * Usa remove() antes de add() para evitar conectar el signal dos veces.
     */
    public function insert():Void
    {
        // Z 99999 → encima de stickers (9999) y de cualquier otra capa
        FlxG.addChildBelowMouse(this, 99999);
        visible = true;
        onResize();

        if (!_updateConnected)
        {
            FlxG.signals.preUpdate.add(_manualUpdate);
            _updateConnected = true;
        }
    }

    // ── Update manual (via signal → sobrevive state switch) ───────────────────

    private function _manualUpdate():Void
    {
        if (!visible || sprBox == null) return;

        var elapsed = FlxG.elapsed;

        // Sincronizar barras a la posición del box (el tween mueve box.y)
        _syncBars();

        sprBox.update(elapsed);
        sprBg.update(elapsed);
        sprBar.update(elapsed);

        trayCamera.update(elapsed);
        trayCamera.clearDrawStack();
        trayCamera.canvas.graphics.clear();

        sprBox.draw();
        sprBg.draw();
        sprBar.draw();

        trayCamera.render();
    }

    private function _syncBars():Void
    {
        if (sprBox == null || sprBg == null || sprBar == null) return;
        sprBg.x  = sprBox.x + (sprBox.width  - sprBg.width)  / 2;
        sprBg.y  = sprBox.y + (sprBox.height - sprBg.height) / 2 - 20;
        sprBar.x = sprBg.x;
        sprBar.y = sprBg.y;
    }

    // ── Resize ────────────────────────────────────────────────────────────────

    public function onResize():Void
    {
        x = y = 0;
        scaleX = scaleY = 1;

        __scrollRect.setTo(
            0, 0,
            FlxG.camera._scrollRect.scrollRect.width,
            FlxG.camera._scrollRect.scrollRect.height
        );

        trayCamera.onResize();
        trayCamera._scrollRect.scrollRect = scrollRect;
    }
}
