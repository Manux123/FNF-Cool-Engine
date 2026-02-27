package funkin.menus;

import openfl.display.BitmapData;
import flixel.text.FlxText;
import funkin.gameplay.PlayState;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.util.FlxColor;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.FlxSubState;
import flixel.util.FlxTimer;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.effects.particles.FlxEmitter;
import funkin.scripting.StateScriptHandler;
import funkin.transitions.StateTransition;
import funkin.transitions.StickerTransition;
import funkin.states.LoadingState;
import flixel.math.FlxMath;
import flixel.util.FlxGradient;
import flixel.group.FlxSpriteGroup;
import flixel.effects.particles.FlxParticle;

/**
 * RatingState v2 — pantalla de resultados con scripting completo.
 *
 * ─── Hooks disponibles en scripts ────────────────────────────────────────────
 *
 *   LIFECYCLE
 *     onCreate()                  → al iniciar (antes de crear elementos)
 *     onBackgroundsCreate()       → después de crear fondos
 *     onParticlesCreate()         → después de crear partículas
 *     onBFCreate(bf)              → después de crear el personaje
 *     onRankCreate(rankSprite)    → después de crear el sprite de rank
 *     onFCBadgeCreate(fcBadge)    → si hay badge de FC
 *     onStatsCreate(scoreDisplay) → después de crear las estadísticas
 *     onStatBarsCreate(statBars)  → después de crear las barras
 *     onAccuracyCreate(accText, ratingText) → después de crear textos de precisión
 *     postCreate()                → todo creado
 *     onDestroy()                 → al salir
 *
 *   UPDATE
 *     onUpdate(elapsed)           → cada frame
 *     onUpdatePost(elapsed)       → cada frame (post super.update)
 *     onBeatHit(beat)             → cada beat de la música de resultados
 *
 *   EVENTOS DE ESTADO
 *     onExit(retry)               → al presionar ENTER/R (return false para cancelar)
 *     onExitComplete(retry)       → cuando el fade-out termina
 *     onCanExitChange(canExit)    → cuando canExit cambia
 *     onRankChanged(newRank)      → si un script cambia el rank
 *
 *   PERSONALIZACIÓN
 *     getRatingText(accuracy)     → override del texto de rating (devuelve String)
 *     getRatingColor(accuracy)    → override del color del texto (devuelve Int)
 *     getRankMusic(rank)          → override de la música a usar (devuelve String)
 *     getCustomStats()            → devuelve Array<{label, value, color}> extra
 *     getCustomBgColor(rank)      → override del color de fondo (devuelve Int)
 *
 * ─── Elementos expuestos en scripts ──────────────────────────────────────────
 *
 *   bg, bgGradient, bgPattern     → fondos
 *   bf                            → personaje BF
 *   rankSprite                    → sprite del rank
 *   fcBadge                       → badge de FC (null si no aplica)
 *   accuracyText, ratingText      → textos inferiores
 *   scoreDisplay                  → FlxTypedGroup con textos de estadísticas
 *   statBars                      → FlxTypedGroup de barras de progreso
 *   particles, confetti           → sistemas de partículas
 *   currentRank                   → letra del rank actual (mutable desde script)
 *   canExit                       → si el jugador puede salir
 *
 * ─── Ejemplo de script mínimo ────────────────────────────────────────────────
 *
 *   // assets/states/ratingstate/mymod_results.hx
 *
 *   function onRankCreate(spr) {
 *       spr.color = FlxColor.CYAN;
 *       ui.tween(spr, {angle: 360}, 2.0, {ease: 'linear', type: LOOPING});
 *   }
 *
 *   function getRatingText(accuracy) {
 *       if (accuracy == 100) return 'GOD TIER!!!';
 *       return null; // null = usa el texto por defecto
 *   }
 *
 *   function onExit(retry) {
 *       ui.playSound('mymod/exitSound');
 *       return false; // false = permite salir normalmente
 *   }
 */
class RatingState extends FlxSubState
{
	// ─── Elementos visuales ───────────────────────────────────────────────────

	public var comboText    : FlxText;
	public var bf           : FlxSprite;
	public var bg           : FlxSprite;
	public var bgGradient   : FlxSprite;
	public var bgPattern    : FlxSprite;

	public var scoreDisplay : FlxTypedGroup<FlxText>;
	public var rankSprite   : FlxSprite;
	public var fcBadge      : FlxSprite;
	public var accuracyText : FlxText;
	public var ratingText   : FlxText;
	public var glowOverlay  : FlxSprite;
	public var particles    : FlxEmitter;
	public var confetti     : FlxEmitter;
	public var statBars     : FlxTypedGroup<StatBar>;

	// ─── Estado interno ───────────────────────────────────────────────────────

	public var canExit        : Bool   = false;
	public var isExiting      : Bool   = false;
	public var introComplete  : Bool   = false;
	public var beatTimer      : Float  = 0;
	public var currentRank    : String;

	var pulseElements : Array<FlxSprite> = [];

	// ─── Lifecycle ────────────────────────────────────────────────────────────

	override public function create():Void
	{
		// ── Scripts: carga y expone antes de crear nada ────────────────────
		StateScriptHandler.init();
		StateScriptHandler.loadStateScripts('RatingState', this);
		StateScriptHandler.callOnScripts('onCreate', []);

		super.create();

		currentRank = funkin.data.Ranking.generateLetterRank();

		// Exponer variables de PlayState al script
		_exposePlayStateData();

		// Exponer referencia a `this` y currentRank
		StateScriptHandler.exposeElement('ratingState', this);
		StateScriptHandler.exposeElement('currentRank', currentRank);

		// ── Construcción visual ────────────────────────────────────────────
		createBackgrounds();
		createParticleSystems();
		createBFCharacter();
		createRankDisplay();
		createStatsDisplay();
		createStatBars();
		createAccuracyDisplay();

		// Overlay de glow
		glowOverlay = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.WHITE);
		glowOverlay.alpha = 0;
		glowOverlay.blend = ADD;
		add(glowOverlay);
		StateScriptHandler.exposeElement('glowOverlay', glowOverlay);

		createHelpText();
		startMusicWithIntro();
		playIntroAnimation();

		StateScriptHandler.callOnScripts('postCreate', []);
		StateTransition.onStateCreated();
	}

	override function destroy():Void
	{
		StateScriptHandler.callOnScripts('onDestroy', []);
		StateScriptHandler.clearStateScripts();
		super.destroy();
	}

	override function update(elapsed:Float):Void
	{
		StateScriptHandler.callOnScripts('onUpdate', [elapsed]);

		super.update(elapsed);

		// Beat timer para efectos de pulso
		if (FlxG.sound.music != null && FlxG.sound.music.playing)
		{
			beatTimer += elapsed * 1000;
			final bpm          = 120.0;
			final beatInterval = (60 / bpm) * 1000;

			if (beatTimer >= beatInterval)
			{
				beatTimer = 0;
				onBeat();
			}
		}

		if (bgPattern != null) bgPattern.angle += elapsed * 2;

		// Idle de BF
		if (bf != null && (bf.animation.finished || bf.animation.curAnim.name == 'idle'))
			bf.animation.play('idle', true);

		var pressedEnter : Bool = FlxG.keys.justPressed.ENTER;
		var pressedRetry : Bool = FlxG.keys.justPressed.R;

		#if mobile
		for (touch in FlxG.touches.list)
			if (touch.justPressed) pressedEnter = true;
		#end

		if (pressedEnter && canExit && !isExiting) exitState(false);
		if (pressedRetry && canExit && !isExiting) exitState(true);

		StateScriptHandler.callOnScripts('onUpdatePost', [elapsed]);
	}

	// ─── Creación de elementos ────────────────────────────────────────────────

	function createBackgrounds():Void
	{
		bg = new FlxSprite().loadGraphic(Paths.image('menu/menuBGBlue'));
		bg.alpha = 0;
		bg.scrollFactor.set(0.1, 0.1);
		add(bg);

		// Color por defecto del fondo (overrideable desde script)
		final defaultColor = _getCustomBgColor(currentRank);
		bg.color = defaultColor;

		bgGradient = FlxGradient.createGradientFlxSprite(FlxG.width, FlxG.height,
			[FlxColor.TRANSPARENT, 0x88000000]);
		bgGradient.alpha = 0;
		add(bgGradient);

		bgPattern = new FlxSprite().loadGraphic(Paths.image('menu/blackslines_finalrating'));
		bgPattern.alpha = 0;
		bgPattern.blend = MULTIPLY;
		add(bgPattern);

		StateScriptHandler.exposeAll(['bg' => bg, 'bgGradient' => bgGradient, 'bgPattern' => bgPattern]);
		StateScriptHandler.callOnScripts('onBackgroundsCreate', [bg, bgGradient, bgPattern]);
	}

	function createParticleSystems():Void
	{
		particles = new FlxEmitter(0, 0, 100);
		particles.makeParticles(4, 4, FlxColor.WHITE, 100);
		particles.launchMode     = FlxEmitterMode.SQUARE;
		particles.velocity.set(-100, -200, 100, -400);
		particles.lifespan.set(3, 6);
		particles.alpha.set(0.3, 0.6, 0, 0);
		particles.scale.set(1, 1.5, 0.2, 0.5);
		particles.width  = FlxG.width;
		particles.height = 100;
		particles.y      = FlxG.height;
		add(particles);

		if (currentRank == 'S' || currentRank == 'SS')
		{
			confetti = new FlxEmitter(FlxG.width / 2, -50, 150);
			confetti.makeParticles(6, 6, FlxColor.WHITE, 150);
			confetti.launchMode = FlxEmitterMode.SQUARE;
			confetti.velocity.set(-200, 100, 200, 300);
			confetti.angularVelocity.set(-180, 180);
			confetti.lifespan.set(4, 8);
			confetti.alpha.set(0.8, 1, 0, 0);
			confetti.width = FlxG.width;
			add(confetti);
		}

		StateScriptHandler.exposeAll(['particles' => particles, 'confetti' => confetti]);
		StateScriptHandler.callOnScripts('onParticlesCreate', [particles, confetti]);
	}

	function createBFCharacter():Void
	{
		// Hook: los scripts pueden reemplazar la ruta del personaje
		var bfChar = StateScriptHandler.callOnScriptsReturn('getBFCharacter', [], 'BOYFRIEND');

		bf = new FlxSprite(-100, FlxG.height + 100);
		bf.frames = Paths.characterSprite(bfChar);
		bf.animation.addByPrefix('idle', 'BF idle dance', 24, false);
		bf.animation.addByPrefix('hey',  'BF HEY!!',      24, false);
		bf.animation.play('idle', true);
		bf.antialiasing = true;
		bf.scale.set(1.2, 1.2);
		add(bf);

		pulseElements.push(bf);

		StateScriptHandler.exposeElement('bf', bf);
		StateScriptHandler.callOnScripts('onBFCreate', [bf]);
	}

	function createRankDisplay():Void
	{
		var daLogo:FlxSprite = new FlxSprite(FlxG.width / 2 + 100, -200);
		daLogo.loadGraphic(Paths.image('titlestate/daLogo'));
		daLogo.scale.set(0.6, 0.6);
		daLogo.alpha = 0;
		daLogo.updateHitbox();
		add(daLogo);
		StateScriptHandler.exposeElement('daLogo', daLogo);

		final rankDisplayY:Float = currentRank == 'S' ? 80 : 120;
		rankSprite = new FlxSprite(FlxG.width / 2 + 350, -300);
		rankSprite.loadGraphic(Paths.image('menu/ratings/${currentRank}'));
		rankSprite.scale.set(1.7, 1.7);
		rankSprite.antialiasing = true;
		rankSprite.alpha = 0;
		rankSprite.updateHitbox();
		rankSprite.screenCenter(X);
		rankSprite.x += 100;
		add(rankSprite);
		pulseElements.push(rankSprite);
		StateScriptHandler.exposeElement('rankSprite', rankSprite);

		// FC Badge
		if (PlayState.misses == 0)
		{
			fcBadge = new FlxSprite(rankSprite.x - 100, rankSprite.y + 200);
			fcBadge.loadGraphic(Paths.image('menu/ratings/FC'));
			fcBadge.scale.set(1.2, 1.2);
			fcBadge.antialiasing = true;
			fcBadge.alpha = 0;
			fcBadge.updateHitbox();
			add(fcBadge);
			pulseElements.push(fcBadge);
			StateScriptHandler.exposeElement('fcBadge', fcBadge);
			StateScriptHandler.callOnScripts('onFCBadgeCreate', [fcBadge]);
		}

		// Animar entrada
		FlxTween.tween(daLogo, {y: 40, alpha: 1}, 0.8, {ease: FlxEase.elasticOut, startDelay: 0.3});
		FlxTween.tween(rankSprite, {y: rankDisplayY, alpha: 1}, 1, {
			ease: FlxEase.elasticOut,
			startDelay: 0.5,
			onComplete: function(_)
			{
				FlxG.camera.shake(0.01, 0.2);
				glowOverlay.alpha = 0.3;
				FlxTween.tween(glowOverlay, {alpha: 0}, 0.5);
				if (confetti != null) confetti.start(false, 0.05, 0);
				StateScriptHandler.callOnScripts('onRankLanded', [rankSprite, currentRank]);
			}
		});
		if (fcBadge != null)
			FlxTween.tween(fcBadge, {alpha: 1}, 0.6, {ease: FlxEase.quadOut, startDelay: 1.2});

		StateScriptHandler.callOnScripts('onRankCreate', [rankSprite]);
	}

	function createStatsDisplay():Void
	{
		scoreDisplay = new FlxTypedGroup<FlxText>();
		add(scoreDisplay);

		// Stats base
		var statsData:Array<Dynamic> = [
			{label: 'SCORE',  value: '${PlayState.songScore}', color: FlxColor.YELLOW},
			{label: 'SICKS',  value: '${PlayState.sicks}',     color: FlxColor.CYAN},
			{label: 'GOODS',  value: '${PlayState.goods}',     color: FlxColor.LIME},
			{label: 'BADS',   value: '${PlayState.bads}',      color: FlxColor.ORANGE},
			{label: 'SHITS',  value: '${PlayState.shits}',     color: FlxColor.fromRGB(139, 69, 19)},
			{label: 'MISSES', value: '${PlayState.misses}',    color: FlxColor.RED}
		];

		// Stats adicionales desde scripts
		final customStats = StateScriptHandler.collectArrays('getCustomStats');
		for (cs in customStats) statsData.push(cs);

		final startX = 50.0;
		final startY = 30.0;
		final spacing = 60.0;

		for (i in 0...statsData.length)
		{
			final stat = statsData[i];

			final label:FlxText = new FlxText(startX - 100, startY + (i * spacing), 150, stat.label, 24);
			label.setFormat(Paths.font('vcr.ttf'), 24, stat.color, LEFT,
				FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			label.borderSize = 2;
			label.alpha = 0;
			scoreDisplay.add(label);

			final value:FlxText = new FlxText(startX + 60, startY + (i * spacing), 200, stat.value, 32);
			value.setFormat(Paths.font('vcr.ttf'), 32, FlxColor.WHITE, LEFT,
				FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			value.borderSize = 2;
			value.alpha = 0;
			scoreDisplay.add(value);

			FlxTween.tween(label, {x: startX, alpha: 1},      0.5, {ease: FlxEase.backOut, startDelay: 0.8  + (i * 0.1)});
			FlxTween.tween(value, {x: startX + 160, alpha: 1}, 0.5, {ease: FlxEase.backOut, startDelay: 0.85 + (i * 0.1)});
		}

		StateScriptHandler.exposeElement('scoreDisplay', scoreDisplay);
		StateScriptHandler.callOnScripts('onStatsCreate', [scoreDisplay]);
	}

	function createStatBars():Void
	{
		statBars = new FlxTypedGroup<StatBar>();
		add(statBars);

		var total:Int = PlayState.sicks + PlayState.goods + PlayState.bads + PlayState.shits + PlayState.misses;
		if (total == 0) total = 1;

		final barData = [
			{notes: PlayState.sicks,  color: FlxColor.CYAN,                    yOffset: 0},
			{notes: PlayState.goods,  color: FlxColor.LIME,                    yOffset: 1},
			{notes: PlayState.bads,   color: FlxColor.ORANGE,                  yOffset: 2},
			{notes: PlayState.shits,  color: FlxColor.fromRGB(139, 69, 19),    yOffset: 3},
			{notes: PlayState.misses, color: FlxColor.RED,                     yOffset: 4}
		];

		final startY  = 95.0;
		final spacing = 60.0;

		for (i in 0...barData.length)
		{
			final data   = barData[i];
			final pct    = data.notes / total;
			final bar    = new StatBar(500, startY + (data.yOffset * spacing), pct, data.color);
			statBars.add(bar);

			FlxTween.tween(bar, {alpha: 1}, 0.3, {
				startDelay: 1.2 + (i * 0.08),
				onComplete: function(_) bar.animateBar()
			});
		}

		StateScriptHandler.exposeElement('statBars', statBars);
		StateScriptHandler.callOnScripts('onStatBarsCreate', [statBars]);
	}

	function createAccuracyDisplay():Void
	{
		final accuracy = PlayState.accuracy;

		// Texto de precisión — overrideable desde scripts
		final ratingTxt  = _getRatingText(accuracy);
		final ratingClr  = _getRatingColor(accuracy);

		accuracyText = new FlxText(0, FlxG.height, FlxG.width, Std.int(accuracy) + '%', 72);
		accuracyText.setFormat(Paths.font('vcr.ttf'), 72, FlxColor.WHITE, CENTER,
			FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		accuracyText.borderSize = 4;
		accuracyText.alpha = 0;
		add(accuracyText);

		ratingText = new FlxText(0, FlxG.height, FlxG.width, ratingTxt, 32);
		ratingText.setFormat(Paths.font('vcr.ttf'), 32, ratingClr, CENTER,
			FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		ratingText.borderSize = 2;
		ratingText.alpha = 0;
		add(ratingText);

		FlxTween.tween(accuracyText, {y: FlxG.height - 180, alpha: 1}, 0.8, {ease: FlxEase.backOut, startDelay: 1.4});
		FlxTween.tween(ratingText,   {y: FlxG.height - 110, alpha: 1}, 0.8, {ease: FlxEase.backOut, startDelay: 1.5});

		pulseElements.push(cast accuracyText);

		StateScriptHandler.exposeAll(['accuracyText' => accuracyText, 'ratingText' => ratingText]);
		StateScriptHandler.callOnScripts('onAccuracyCreate', [accuracyText, ratingText]);
	}

	function createHelpText():Void
	{
		// Los scripts pueden personalizar el texto de ayuda
		final helpMsg = StateScriptHandler.callOnScriptsReturn('getHelpText', [],
			'[ENTER] Continue  •  [R] Retry');

		final helpText:FlxText = new FlxText(0, FlxG.height - 50, FlxG.width, helpMsg, 24);
		helpText.setFormat(Paths.font('vcr.ttf'), 24, FlxColor.WHITE, CENTER,
			FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		helpText.borderSize = 2;
		helpText.alpha = 0;
		add(helpText);

		FlxTween.tween(helpText, {alpha: 1}, 0.5, {ease: FlxEase.quadInOut, startDelay: 2, type: PINGPONG});
		StateScriptHandler.exposeElement('helpText', helpText);
	}

	// ─── Música ───────────────────────────────────────────────────────────────

	function startMusicWithIntro():Void
	{
		// Overrideable desde scripts
		final overriddenMusic = StateScriptHandler.callOnScriptsReturn('getRankMusic', [currentRank], null);
		var rankMusic:String;

		if (overriddenMusic != null)
		{
			rankMusic = overriddenMusic;
		}
		else
		{
			rankMusic = currentRank;
			if (currentRank == 'C' || currentRank == 'D') rankMusic = 'B';
		}

		FlxG.sound.playMusic(Paths.music('results$rankMusic/results$rankMusic'), 0);
		FlxTween.tween(FlxG.sound.music, {volume: 0.7}, 2, {
			ease: FlxEase.quadOut,
			onComplete: function(_) { introComplete = true; }
		});
	}

	// ─── Animaciones ──────────────────────────────────────────────────────────

	function playIntroAnimation():Void
	{
		FlxG.camera.fade(FlxColor.BLACK, 1, true);
		FlxTween.tween(bg,         {alpha: 0.4}, 1.2, {ease: FlxEase.quadOut});
		FlxTween.tween(bgGradient, {alpha: 0.7}, 1.5, {ease: FlxEase.quadOut});
		FlxTween.tween(bgPattern,  {alpha: 0.3}, 1.8, {ease: FlxEase.quadOut});
		FlxTween.tween(bf,         {x: 120, y: 320}, 1.2, {ease: FlxEase.expoOut, startDelay: 0.4});

		new FlxTimer().start(0.8, function(_)
		{
			particles.start(false, 0.08, 0);
			canExit = true;
			StateScriptHandler.callOnScripts('onCanExitChange', [true]);
		});

		StateScriptHandler.callOnScripts('onIntroStart', []);
	}

	function onBeat():Void
	{
		StateScriptHandler.callOnScripts('onBeatHit', [beatTimer]);

		for (el in pulseElements)
		{
			if (el == null) continue;
			FlxTween.cancelTweensOf(el.scale);
			el.scale.set(el.scale.x * 1.05, el.scale.y * 1.05);
			FlxTween.tween(el.scale, {x: el.scale.x / 1.05, y: el.scale.y / 1.05}, 0.3, {ease: FlxEase.quadOut});
		}

		FlxG.camera.zoom = 1.01;
		FlxTween.tween(FlxG.camera, {zoom: 1}, 0.3, {ease: FlxEase.quadOut});
	}

	function exitState(retry:Bool = false):Void
	{
		// Los scripts pueden cancelar el exit devolviendo true
		if (StateScriptHandler.callOnScripts('onExit', [retry])) return;

		isExiting = true;
		if (bf != null) bf.animation.play('hey', true);

		if (FlxG.save.data.flashing) FlxG.camera.flash(FlxColor.WHITE, 0.5);
		FlxG.camera.shake(0.005, 0.3);

		FlxTween.tween(FlxG.sound.music, {volume: 0}, 0.8, {ease: FlxEase.quadIn});

		if (rankSprite != null) FlxTween.tween(rankSprite,   {y: rankSprite.y - 100, alpha: 0}, 0.6, {ease: FlxEase.backIn});
		if (bf != null)         FlxTween.tween(bf,           {x: -200, alpha: 0},               0.8, {ease: FlxEase.expoIn});
		if (accuracyText != null) FlxTween.tween(accuracyText, {y: FlxG.height + 100, alpha: 0}, 0.7, {ease: FlxEase.backIn});

		for (text in scoreDisplay)
			FlxTween.tween(text, {x: text.x - 150, alpha: 0}, 0.5, {ease: FlxEase.quadIn});

		FlxG.camera.fade(FlxColor.BLACK, 1.2, false);

		new FlxTimer().start(1.2, function(_)
		{
			FlxG.sound.music.stop();
			StateScriptHandler.callOnScripts('onExitComplete', [retry]);

			if (retry && PlayState.SONG.song != null)
			{
				FlxG.sound.play(Paths.sound('menus/confirmMenu'), 0.6);
				PlayState.startFromTime = null;
				new FlxTimer().start(0.3, function(_)
				{
					FlxG.mouse.visible = false;
					LoadingState.loadAndSwitchState(new PlayState());
				});
			}
			else
			{
				if (PlayState.isStoryMode)
					StateTransition.switchState(new funkin.menus.StoryMenuState());
				else
					StickerTransition.start(function()
						StateTransition.switchState(new funkin.menus.FreeplayState()));
			}
		});
	}

	// ─── Helpers de rating (con override desde script) ─────────────────────────

	function _getRatingText(accuracy:Float):String
	{
		// Dar oportunidad al script de overridear
		final ratingOverride = StateScriptHandler.callOnScriptsReturn('getRatingText', [accuracy], null);
		if (ratingOverride != null) return ratingOverride;

		if (accuracy == 100) return 'PERFECT!!';
		if (accuracy >= 95)  return 'AMAZING!';
		if (accuracy >= 90)  return 'EXCELLENT!';
		if (accuracy >= 85)  return 'GREAT!';
		if (accuracy >= 80)  return 'GOOD!';
		if (accuracy >= 70)  return 'NICE!';
		if (accuracy >= 60)  return 'OK';
		return 'KEEP TRYING';
	}

	function _getRatingColor(accuracy:Float):Int
	{
		final colorOverride = StateScriptHandler.callOnScriptsReturn('getRatingColor', [accuracy], null);
		if (colorOverride != null) return colorOverride;

		if (accuracy == 100) return FlxColor.fromRGB(255, 215, 0);
		if (accuracy >= 95)  return FlxColor.fromRGB(100, 255, 100);
		if (accuracy >= 85)  return FlxColor.CYAN;
		if (accuracy >= 70)  return FlxColor.YELLOW;
		if (accuracy >= 60)  return FlxColor.ORANGE;
		return FlxColor.RED;
	}

	function _getCustomBgColor(rank:String):Int
	{
		final bgcolorOverride = StateScriptHandler.callOnScriptsReturn('getCustomBgColor', [rank], null);
		if (bgcolorOverride != null) return bgcolorOverride;

		return switch (rank)
		{
			case 'S' | 'SS': FlxColor.fromRGB(255, 215, 0);
			case 'A':        FlxColor.fromRGB(100, 255, 100);
			case 'B':        FlxColor.fromRGB(100, 200, 255);
			case 'C' | 'D':  FlxColor.fromRGB(255, 150, 100);
			case 'F':        FlxColor.fromRGB(200, 100, 100);
			default:         FlxColor.fromRGB(100, 100, 200);
		};
	}

	// ─── Exponer datos de PlayState ───────────────────────────────────────────

	function _exposePlayStateData():Void
	{
		StateScriptHandler.exposeAll([
			'songScore'   => PlayState.songScore,
			'accuracy'    => PlayState.accuracy,
			'misses'      => PlayState.misses,
			'sicks'       => PlayState.sicks,
			'goods'       => PlayState.goods,
			'bads'        => PlayState.bads,
			'shits'       => PlayState.shits,
			'maxCombo'    => PlayState.maxCombo,
			'isStoryMode' => PlayState.isStoryMode,
			'songName'    => PlayState.SONG?.song ?? '',
			'difficulty'  => PlayState.storyDifficulty
		]);
	}
}

// ─── StatBar ──────────────────────────────────────────────────────────────────

class StatBar extends FlxSpriteGroup
{
	var targetWidth : Float;
	var maxWidth    : Float = 400;
	var barColor    : Int;
	var bgBar       : FlxSprite;
	var fillBar     : FlxSprite;

	public function new(x:Float, y:Float, percentage:Float, color:Int)
	{
		super(x, y);
		barColor    = color;
		targetWidth = maxWidth * percentage;

		bgBar = new FlxSprite(x, y);
		bgBar.makeGraphic(Std.int(maxWidth), 30, FlxColor.fromRGB(40, 40, 40));
		bgBar.alpha = 0.6;

		fillBar = new FlxSprite(x, y);
		fillBar.makeGraphic(1, 30, color);
		fillBar.scale.x = 0;

		alpha = 0;
	}

	public function animateBar():Void
	{
		FlxTween.tween(fillBar.scale, {x: targetWidth}, 0.8, {ease: FlxEase.expoOut});
		FlxTween.tween(fillBar, {alpha: 1}, 0.2, {type: PINGPONG, loopDelay: 0.3});
	}

	override function draw():Void
	{
		bgBar?.draw();
		fillBar?.draw();
		super.draw();
	}

	override function destroy():Void
	{
		bgBar?.destroy();
		fillBar?.destroy();
		super.destroy();
	}
}
