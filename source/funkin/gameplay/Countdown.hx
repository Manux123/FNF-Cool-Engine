package funkin.gameplay;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxTimer;
import flixel.system.FlxSound;
import funkin.data.Conductor;
import funkin.gameplay.PlayStateConfig;
import funkin.scripting.ScriptHandler;

// ─── Configuración de un skin de countdown ────────────────────────────────────
// Todos los valores son soft-coded; se puede cambiar desde scripts/JSON sin
// recompilar. Instancia la struct con valores por defecto y sobreescribe lo
// que necesites.
typedef CountdownSkin = {
	/** Paths de los sprites (en orden ready, set, go). */
	var sprPaths:Array<String>;

	/** Paths de los sonidos (en orden intro3, intro2, intro1, introGo). */
	var sndPaths:Array<String>;

	/** Factor de escala base para sprites HD. */
	var hdScale:Float;

	/** Factor de escala base para sprites pixel. */
	var pixelScale:Float;

	/** Volumen de los sonidos de countdown (0.0 – 1.0). */
	var soundVolume:Float;

	// ── Animación de ENTRADA ────────────────────────────────────────────────
	/** Escala inicial (punch de entrada). */
	var enterStartScale:Float;
	/** Fracción del crochet para el fade-in de alpha. */
	var enterAlphaDur:Float;
	/** Fracción del crochet para el scale punch. */
	var enterScaleDur:Float;

	// ── Micro-pulse ──────────────────────────────────────────────────────────
	/** Delta de escala del micro-pulse (sube y baja). */
	var pulseDelta:Float;
	/** Inicio del pulse (fracción del crochet). */
	var pulseDelay:Float;
	/** Duración del pulse hacia arriba (fracción). */
	var pulseUpDur:Float;
	/** Duración del pulse hacia abajo (fracción). */
	var pulseDownDur:Float;

	// ── Animación de SALIDA ──────────────────────────────────────────────────
	/** Retraso antes de salir (fracción del crochet). */
	var exitDelay:Float;
	/** Duración del fade-out (fracción del crochet). */
	var exitDur:Float;
	/** Cuántos píxeles sube el sprite al salir. */
	var exitRisePixels:Float;

	// ── Rotación aleatoria (solo HD) ─────────────────────────────────────────
	/** Ángulo mínimo de jitter. */
	var rotMin:Float;
	/** Ángulo máximo de jitter. */
	var rotMax:Float;
}

// ─── Datos de un paso del countdown ──────────────────────────────────────────
typedef CountdownStep = {
	var index:Int;          // 0-3  (0 = blank beat, 1=ready, 2=set, 3=go)
	var sprPath:Null<String>;
	var sndPath:String;
}

// ─── Clase principal ──────────────────────────────────────────────────────────
/**
 * Countdown desacoplado de PlayState.
 *
 * Uso básico en PlayState:
 *   countdown = new Countdown(this, camCountdown, isPixelStage);
 *   countdown.preload();
 *   countdown.start(onFinished);
 *
 * Para cambiar el skin desde un script:
 *   countdown.skin.soundVolume = 0.9;
 *   countdown.skin.exitRisePixels = 50;
 */
class Countdown {
	// ─── Skins predeterminados ────────────────────────────────────────────────

	/** Skin para stages normales (HD). */
	public static final SKIN_NORMAL:CountdownSkin = {
		sprPaths:        ["UI/normal/ready", "UI/normal/set", "UI/normal/go"],
		sndPaths:        ["intro3", "intro2", "intro1", "introGo"],
		hdScale:         0.7,
		pixelScale:      PlayStateConfig.PIXEL_ZOOM,
		soundVolume:     0.6,
		// entrada
		enterStartScale: 1.3,
		enterAlphaDur:   0.20,
		enterScaleDur:   0.36,
		// pulse
		pulseDelta:      0.06,
		pulseDelay:      0.30,
		pulseUpDur:      0.12,
		pulseDownDur:    0.08,
		// salida
		exitDelay:       0.52,
		exitDur:         0.48,
		exitRisePixels:  32,
		// rotación
		rotMin:          -4,
		rotMax:          4
	};

	/** Skin para stages pixel (school). */
	public static final SKIN_PIXEL:CountdownSkin = {
		sprPaths:        ["UI/pixelUI/ready-pixel", "UI/pixelUI/set-pixel", "UI/pixelUI/date-pixel"],
		sndPaths:        ["intro3-pixel", "intro2-pixel", "intro1-pixel", "introGo-pixel"],
		hdScale:         0.7,
		pixelScale:      PlayStateConfig.PIXEL_ZOOM,
		soundVolume:     0.6,
		// entrada
		enterStartScale: 1.3,
		enterAlphaDur:   0.20,
		enterScaleDur:   0.36,
		// pulse (desactivado en pixel, deltas a 0)
		pulseDelta:      0.0,
		pulseDelay:      0.30,
		pulseUpDur:      0.12,
		pulseDownDur:    0.08,
		// salida
		exitDelay:       0.52,
		exitDur:         0.48,
		exitRisePixels:  24,
		// sin rotación en pixel
		rotMin:          0,
		rotMax:          0
	};

	// ─── Estado interno ────────────────────────────────────────────────────────

	/** Skin activo. Modificable en cualquier momento antes de start(). */
	public var skin:CountdownSkin;

	/** ¿Estamos en un stage pixel? Determina el skin por defecto. */
	public var isPixel(default, set):Bool;

	/** Pasos personalizados. Si null, se usan los 4 pasos estándar del skin. */
	public var customSteps:Null<Array<CountdownStep>> = null;

	/** ¿El countdown ya terminó? */
	public var finished(default, null):Bool = false;

	/** ¿Está corriendo ahora mismo? */
	public var running(default, null):Bool = false;

	// privadas
	var _state:PlayState;
	var _camera:flixel.FlxCamera;
	var _sprites:Array<FlxSprite> = [];
	var _loaded:Bool = false;
	var _timer:FlxTimer = null;
	var _onComplete:Void->Void = null;
	var _swag:Int = 0;

	// ─── Constructor ──────────────────────────────────────────────────────────

	/**
	 * @param state     Referencia al PlayState (para add/scripts).
	 * @param camera    Cámara dedicada al countdown.
	 * @param pixel     true si el stage es pixel.
	 */
	public function new(state:PlayState, camera:flixel.FlxCamera, pixel:Bool = false) {
		_state   = state;
		_camera  = camera;
		isPixel  = pixel;          // setter asigna skin
	}

	// ─── API pública ──────────────────────────────────────────────────────────

	/**
	 * Pre-carga los sprites en memoria para evitar lag en el primer frame.
	 * Llamar antes de start().
	 */
	public function preload():Void {
		if (_loaded) return;

		_sprites = [];
		final isPixelLocal = isPixel;

		for (path in skin.sprPaths) {
			var spr = new FlxSprite();
			spr.loadGraphic(Paths.image(path));
			spr.cameras     = [_camera];
			spr.scrollFactor.set();

			if (isPixelLocal)
				spr.setGraphicSize(Std.int(spr.width * skin.pixelScale));
			else {
				spr.setGraphicSize(Std.int(spr.width * skin.hdScale));
				spr.antialiasing = FlxG.save.data.antialiasing;
			}

			spr.updateHitbox();
			spr.alpha   = 0;
			spr.visible = false;
			spr.active  = false;
			_state.add(spr);
			_sprites.push(spr);
		}

		_loaded = true;
	}

	/**
	 * Arranca el countdown. Llama a preload() si no se hizo antes.
	 * @param onComplete  Callback cuando el countdown termina (beat 4 = "go").
	 */
	public function start(?onComplete:Void->Void):Void {
		if (running) return;

		if (!_loaded) preload();

		_onComplete = onComplete;
		_swag       = 0;
		finished    = false;
		running     = true;

		_fireScriptHook("onCountdownStart");

		_timer = new FlxTimer().start(Conductor.crochet / 1000.0, _onTick, 4);
	}

	/**
	 * Cancela el countdown en curso (sin disparar onComplete).
	 */
	public function cancel():Void {
		if (_timer != null) {
			_timer.cancel();
			_timer = null;
		}
		running  = false;
		finished = false;
	}

	/**
	 * Destruye y libera todos los recursos. Llamar en PlayState.destroy().
	 */
	public function destroy():Void {
		cancel();
		for (spr in _sprites) {
			FlxTween.cancelTweensOf(spr);
			FlxTween.cancelTweensOf(spr.scale);
			spr.destroy();
		}
		_sprites = [];
		_loaded  = false;
	}

	// ─── Internos ─────────────────────────────────────────────────────────────

	/** Setter: cambia el skin cuando se cambia isPixel. */
	function set_isPixel(v:Bool):Bool {
		isPixel = v;
		skin    = v ? _cloneSkin(SKIN_PIXEL) : _cloneSkin(SKIN_NORMAL);
		return v;
	}

	/** Clona un skin para que sea modificable de forma segura. */
	static function _cloneSkin(s:CountdownSkin):CountdownSkin {
		return {
			sprPaths:        s.sprPaths.copy(),
			sndPaths:        s.sndPaths.copy(),
			hdScale:         s.hdScale,
			pixelScale:      s.pixelScale,
			soundVolume:     s.soundVolume,
			enterStartScale: s.enterStartScale,
			enterAlphaDur:   s.enterAlphaDur,
			enterScaleDur:   s.enterScaleDur,
			pulseDelta:      s.pulseDelta,
			pulseDelay:      s.pulseDelay,
			pulseUpDur:      s.pulseUpDur,
			pulseDownDur:    s.pulseDownDur,
			exitDelay:       s.exitDelay,
			exitDur:         s.exitDur,
			exitRisePixels:  s.exitRisePixels,
			rotMin:          s.rotMin,
			rotMax:          s.rotMax
		};
	}

	/** Construye los pasos del countdown a partir del skin activo. */
	function _buildSteps():Array<CountdownStep> {
		if (customSteps != null) return customSteps;

		return [
			// Paso 0: beat vacío (solo sonido intro3)
			{ index: 0, sprPath: null,             sndPath: skin.sndPaths[0] },
			{ index: 1, sprPath: skin.sprPaths[0], sndPath: skin.sndPaths[1] }, // ready
			{ index: 2, sprPath: skin.sprPaths[1], sndPath: skin.sndPaths[2] }, // set
			{ index: 3, sprPath: skin.sprPaths[2], sndPath: skin.sndPaths[3] }, // go
		];
	}

	/** Callback interno del FlxTimer. */
	function _onTick(tmr:FlxTimer):Void {
		final steps = _buildSteps();
		final step  = steps[_swag];

		// Hook de script por paso
		_fireScriptHookWithArgs("onCountdownTick", [_swag, step]);

		// Baile de personajes en cada beat
		_state.characterController.danceOnBeat(Std.int(Conductor.songPosition / Conductor.crochet));

		// Sonido
		if (step.sndPath != null && step.sndPath.length > 0)
			FlxG.sound.play(Paths.sound(step.sndPath), skin.soundVolume);

		// Sprite (solo si hay path y sprite cargado)
		if (step.sprPath != null)
			_showSprite(step.sprPath);

		_swag++;

		// Fin del countdown
		if (_swag >= steps.length) {
			running  = false;
			finished = true;
			_fireScriptHook("onCountdownEnd");
			if (_onComplete != null) _onComplete();
		}
	}

	/** Muestra y anima el sprite correspondiente al path. */
	function _showSprite(path:String):Void {
		// Buscar sprite pre-cargado
		final idx = skin.sprPaths.indexOf(path);

		// Si no está en el pool (custom), crear uno on-the-fly
		if (idx < 0 || idx >= _sprites.length) {
			_showSpriteFallback(path);
			return;
		}

		final spr = _sprites[idx];
		final dur = Conductor.crochet / 1000.0;
		final sk  = skin;

		// Cancelar tweens anteriores
		FlxTween.cancelTweensOf(spr);
		FlxTween.cancelTweensOf(spr.scale);

		// Reset de estado
		spr.screenCenter();
		spr.visible = true;
		spr.active  = true;
		spr.alpha   = 0;
		spr.scale.set(sk.enterStartScale, sk.enterStartScale);
		spr.angle   = (sk.rotMin != sk.rotMax) ? FlxG.random.float(sk.rotMin, sk.rotMax) : 0;

		// ── ENTRADA ────────────────────────────────────────────────────────────
		FlxTween.tween(spr, {alpha: 1.0},
			dur * sk.enterAlphaDur,
			{ease: FlxEase.quadOut}
		);
		FlxTween.tween(spr.scale, {x: 1.0, y: 1.0},
			dur * sk.enterScaleDur,
			{ease: FlxEase.elasticOut}
		);

		// ── MICRO-PULSE (solo si pulseDelta > 0) ─────────────────────────────
		if (sk.pulseDelta > 0) {
			FlxTween.tween(spr.scale,
				{x: 1.0 + sk.pulseDelta, y: 1.0 + sk.pulseDelta},
				dur * sk.pulseUpDur,
				{
					ease: FlxEase.sineOut,
					startDelay: dur * sk.pulseDelay,
					onComplete: function(_) {
						if (spr.alive)
							FlxTween.tween(spr.scale,
								{x: 1.0, y: 1.0},
								dur * sk.pulseDownDur,
								{ease: FlxEase.sineIn}
							);
					}
				}
			);
		}

		// ── SALIDA ─────────────────────────────────────────────────────────────
		final startY = spr.y;
		FlxTween.tween(spr,
			{alpha: 0, y: startY - sk.exitRisePixels},
			dur * sk.exitDur,
			{
				ease: FlxEase.quadIn,
				startDelay: dur * sk.exitDelay,
				onComplete: function(_) {
					spr.visible = false;
					spr.active  = false;
					spr.angle   = 0;
					spr.scale.set(1, 1);
				}
			}
		);
	}

	/** Fallback para sprites no pre-cargados (e.g. paths personalizados). */
	function _showSpriteFallback(path:String):Void {
		final dur = Conductor.crochet / 1000.0;
		final sk  = skin;

		var spr = new FlxSprite().loadGraphic(Paths.image(path));
		spr.cameras = [_camera];
		spr.scrollFactor.set();

		if (isPixel)
			spr.setGraphicSize(Std.int(spr.width * sk.pixelScale));
		else {
			spr.setGraphicSize(Std.int(spr.width * sk.hdScale));
			spr.antialiasing = FlxG.save.data.antialiasing;
		}

		spr.updateHitbox();
		spr.screenCenter();
		_state.add(spr);

		FlxTween.tween(spr,
			{alpha: 0, y: spr.y - sk.exitRisePixels},
			dur,
			{
				ease: FlxEase.cubeInOut,
				onComplete: function(_) { spr.destroy(); }
			}
		);
	}

	// ─── Script hooks (no-op si scripts deshabilitados) ───────────────────────

	inline function _fireScriptHook(name:String):Void {
		if (_state.scriptsEnabled)
			ScriptHandler.callOnScripts(name, ScriptHandler._argsEmpty);
	}

	inline function _fireScriptHookWithArgs(name:String, args:Array<Dynamic>):Void {
		if (_state.scriptsEnabled)
			ScriptHandler.callOnScripts(name, args);
	}
}
