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
import funkin.transitions.StateTransition;
import flixel.group.FlxSpriteGroup;
import flixel.effects.particles.FlxParticle;
import funkin.scripting.StateScriptHandler;
import funkin.transitions.StickerTransition;
import funkin.states.LoadingState;
import flixel.math.FlxMath;
import flixel.util.FlxGradient;

class RatingState extends FlxSubState
{
	var comboText:FlxText;
	var bf:FlxSprite;
	var bg:FlxSprite;
	var bgGradient:FlxSprite;
	var bgPattern:FlxSprite;

	// Elementos visuales mejorados
	var scoreDisplay:FlxTypedGroup<FlxText>;
	var rankSprite:FlxSprite;
	var fcBadge:FlxSprite;
	var accuracyText:FlxText;
	var ratingText:FlxText;
	var glowOverlay:FlxSprite;
	var particles:FlxEmitter;
	var confetti:FlxEmitter;

	// Barras de estadísticas
	var statBars:FlxTypedGroup<StatBar>;

	// Variables para animaciones
	var canExit:Bool = false;
	var isExiting:Bool = false;
	var introComplete:Bool = false;
	var beatTimer:Float = 0;
	var currentRank:String;

	// Efectos de pulso
	var pulseElements:Array<FlxSprite> = [];

	override public function create()
	{
		#if HSCRIPT_ALLOWED
		StateScriptHandler.init();
		StateScriptHandler.loadStateScripts('RatingState', this);
		StateScriptHandler.callOnScripts('onCreate', []);
		#end

		super.create();

		currentRank = funkin.data.Ranking.generateLetterRank();

		// === FONDO CON MÚLTIPLES CAPAS ===
		createBackgrounds();

		// === SISTEMA DE PARTÍCULAS ===
		createParticleSystems();

		// === BF ANIMADO ===
		createBFCharacter();

		// === DISPLAY DE RANK CON EFECTOS ===
		createRankDisplay();

		// === ESTADÍSTICAS VISUALES ===
		createStatsDisplay();

		// === BARRAS DE PROGRESO ===
		createStatBars();

		// === TEXTO DE PRECISIÓN Y RATING ===
		createAccuracyDisplay();

		// === OVERLAY DE GLOW ===
		glowOverlay = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.WHITE);
		glowOverlay.alpha = 0;
		glowOverlay.blend = ADD;
		add(glowOverlay);

		// === TEXTO DE AYUDA ===
		createHelpText();

		// === INICIAR MÚSICA CON INTRO ===
		startMusicWithIntro();

		// === ANIMACIÓN DE ENTRADA ÉPICA ===
		playIntroAnimation();

		StateTransition.onStateCreated();
	}

	function createBackgrounds():Void
	{
		// Fondo base con color según rank
		bg = new FlxSprite().loadGraphic(Paths.image('menu/menuBGBlue'));
		bg.alpha = 0;
		bg.scrollFactor.set(0.1, 0.1);
		add(bg);

		// Aplicar color según el rank
		switch (currentRank)
		{
			case 'S' | 'SS':
				bg.color = FlxColor.fromRGB(255, 215, 0); // Dorado
			case 'A':
				bg.color = FlxColor.fromRGB(100, 255, 100); // Verde brillante
			case 'B':
				bg.color = FlxColor.fromRGB(100, 200, 255); // Azul cielo
			case 'C' | 'D':
				bg.color = FlxColor.fromRGB(255, 150, 100); // Naranja
			case 'F':
				bg.color = FlxColor.fromRGB(200, 100, 100); // Rojo suave
		}

		// Degradado overlay
		bgGradient = FlxGradient.createGradientFlxSprite(FlxG.width, FlxG.height, [FlxColor.TRANSPARENT, 0x88000000]);
		bgGradient.alpha = 0;
		add(bgGradient);

		// Patrón de líneas
		bgPattern = new FlxSprite().loadGraphic(Paths.image('menu/blackslines_finalrating'));
		bgPattern.alpha = 0;
		bgPattern.blend = MULTIPLY;
		add(bgPattern);
	}

	function createParticleSystems():Void
	{
		// Partículas de fondo
		particles = new FlxEmitter(0, 0, 100);
		particles.makeParticles(4, 4, FlxColor.WHITE, 100);
		particles.launchMode = FlxEmitterMode.SQUARE;
		particles.velocity.set(-100, -200, 100, -400);
		particles.lifespan.set(3, 6);
		particles.alpha.set(0.3, 0.6, 0, 0);
		particles.scale.set(1, 1.5, 0.2, 0.5);
		particles.width = FlxG.width;
		particles.height = 100;
		particles.y = FlxG.height;
		add(particles);

		// Confetti para ranks altos
		if (currentRank == 'S' || currentRank == 'SS')
		{
			confetti = new FlxEmitter(FlxG.width / 2, -50, 150);
			confetti.makeParticles(6, 6, FlxColor.WHITE, 150);

			var colors:Array<FlxColor> = [
				FlxColor.fromRGB(255, 215, 0),
				FlxColor.fromRGB(255, 100, 255),
				FlxColor.fromRGB(100, 255, 255),
				FlxColor.fromRGB(100, 255, 100)
			];

			confetti.forEachAlive(function(p)
			{
				p.color = colors[FlxG.random.int(0, colors.length - 1)];
			});
			confetti.launchMode = FlxEmitterMode.SQUARE;
			confetti.velocity.set(-200, 100, 200, 300);
			confetti.angularVelocity.set(-180, 180);
			confetti.lifespan.set(4, 8);
			confetti.alpha.set(0.8, 1, 0, 0);
			confetti.width = FlxG.width;
			add(confetti);
		}
	}

	function createBFCharacter():Void
	{
		var bfTex = Paths.characterSprite('BOYFRIEND');
		bf = new FlxSprite(-100, FlxG.height + 100); // Fuera de pantalla
		bf.frames = bfTex;
		bf.animation.addByPrefix('idle', 'BF idle dance', 24, false);
		bf.animation.addByPrefix('hey', 'BF HEY!!', 24, false);
		bf.animation.play('idle', true);
		bf.antialiasing = true;
		bf.scale.set(1.2, 1.2);
		add(bf);

		pulseElements.push(bf);
	}

	function createRankDisplay():Void
	{
		// Logo del juego
		var daLogo:FlxSprite = new FlxSprite(FlxG.width / 2 + 100, -200);
		daLogo.loadGraphic(Paths.image('titlestate/daLogo'));
		daLogo.scale.set(0.6, 0.6);
		daLogo.alpha = 0;
		daLogo.updateHitbox();
		add(daLogo);

		// Sprite del Rank
		var rankDisplayY:Float = currentRank == 'S' ? 80 : 120;
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

		// Badge de FC si aplica
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
		}

		// Animaciones de entrada
		FlxTween.tween(daLogo, {y: 40, alpha: 1}, 0.8, {
			ease: FlxEase.elasticOut,
			startDelay: 0.3
		});

		FlxTween.tween(rankSprite, {y: rankDisplayY, alpha: 1}, 1, {
			ease: FlxEase.elasticOut,
			startDelay: 0.5,
			onComplete: function(twn:FlxTween)
			{
				// Efecto de impacto
				FlxG.camera.shake(0.01, 0.2);
				glowOverlay.alpha = 0.3;
				FlxTween.tween(glowOverlay, {alpha: 0}, 0.5);

				if (confetti != null)
					confetti.start(false, 0.05, 0);
			}
		});

		if (fcBadge != null)
		{
			FlxTween.tween(fcBadge, {alpha: 1}, 0.6, {
				ease: FlxEase.quadOut,
				startDelay: 1.2
			});
		}
	}

	function createStatsDisplay():Void
	{
		scoreDisplay = new FlxTypedGroup<FlxText>();
		add(scoreDisplay);

		var statsData = [
			{label: "SCORE", value: '${PlayState.songScore}', color: FlxColor.YELLOW},
			{label: "SICKS", value: '${PlayState.sicks}', color: FlxColor.CYAN},
			{label: "GOODS", value: '${PlayState.goods}', color: FlxColor.LIME},
			{label: "BADS", value: '${PlayState.bads}', color: FlxColor.ORANGE},
			{label: "SHITS", value: '${PlayState.shits}', color: FlxColor.fromRGB(139, 69, 19)},
			{label: "MISSES", value: '${PlayState.misses}', color: FlxColor.RED}
		];

		var startX:Float = 50;
		var startY:Float = 30;
		var spacing:Float = 60;

		for (i in 0...statsData.length)
		{
			var stat = statsData[i];

			// Label
			var label:FlxText = new FlxText(startX, startY + (i * spacing), 150, stat.label, 24);
			label.setFormat(Paths.font("vcr.ttf"), 24, stat.color, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			label.borderSize = 2;
			label.alpha = 0;
			label.x = startX - 100;
			scoreDisplay.add(label);

			// Value
			var value:FlxText = new FlxText(startX + 160, startY + (i * spacing), 200, stat.value, 32);
			value.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			value.borderSize = 2;
			value.alpha = 0;
			value.x = startX + 60;
			scoreDisplay.add(value);

			// Animación escalonada
			FlxTween.tween(label, {x: startX, alpha: 1}, 0.5, {
				ease: FlxEase.backOut,
				startDelay: 0.8 + (i * 0.1)
			});

			FlxTween.tween(value, {x: startX + 160, alpha: 1}, 0.5, {
				ease: FlxEase.backOut,
				startDelay: 0.85 + (i * 0.1)
			});
		}
	}

	function createStatBars():Void
	{
		statBars = new FlxTypedGroup<StatBar>();
		add(statBars);

		var totalNotes:Int = PlayState.sicks + PlayState.goods + PlayState.bads + PlayState.shits + PlayState.misses;
		if (totalNotes == 0)
			totalNotes = 1; // Evitar división por 0

		var barData = [
			{notes: PlayState.sicks, color: FlxColor.CYAN, yOffset: 0},
			{notes: PlayState.goods, color: FlxColor.LIME, yOffset: 1},
			{notes: PlayState.bads, color: FlxColor.ORANGE, yOffset: 2},
			{notes: PlayState.shits, color: FlxColor.fromRGB(139, 69, 19), yOffset: 3},
			{notes: PlayState.misses, color: FlxColor.RED, yOffset: 4}
		];

		var startY:Float = 95;
		var spacing:Float = 60;

		for (i in 0...barData.length)
		{
			var data = barData[i];
			var percentage:Float = (data.notes / totalNotes);

			var bar:StatBar = new StatBar(500, startY + (data.yOffset * spacing), percentage, data.color);
			statBars.add(bar);

			// Animar entrada
			FlxTween.tween(bar, {alpha: 1}, 0.3, {
				startDelay: 1.2 + (i * 0.08),
				onComplete: function(twn:FlxTween)
				{
					bar.animateBar();
				}
			});
		}
	}

	function createAccuracyDisplay():Void
	{
		var accuracy:Float = PlayState.accuracy;

		// Texto de precisión grande
		accuracyText = new FlxText(0, FlxG.height - 180, FlxG.width, Std.int(accuracy) + "%", 72);
		accuracyText.setFormat(Paths.font("vcr.ttf"), 72, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		accuracyText.borderSize = 4;
		accuracyText.alpha = 0;
		accuracyText.y = FlxG.height;
		add(accuracyText);

		// Texto de rating
		ratingText = new FlxText(0, FlxG.height - 110, FlxG.width, getRatingText(accuracy), 32);
		ratingText.setFormat(Paths.font("vcr.ttf"), 32, getRatingColor(accuracy), CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		ratingText.borderSize = 2;
		ratingText.alpha = 0;
		ratingText.y = FlxG.height;
		add(ratingText);

		// Animar entrada
		FlxTween.tween(accuracyText, {y: FlxG.height - 180, alpha: 1}, 0.8, {
			ease: FlxEase.backOut,
			startDelay: 1.4
		});

		FlxTween.tween(ratingText, {y: FlxG.height - 110, alpha: 1}, 0.8, {
			ease: FlxEase.backOut,
			startDelay: 1.5
		});

		pulseElements.push(cast accuracyText);
	}

	function createHelpText():Void
	{
		var helpText:FlxText = new FlxText(0, FlxG.height - 50, FlxG.width, '[ENTER] Continue  •  [R] Retry', 24);
		helpText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		helpText.borderSize = 2;
		helpText.alpha = 0;
		add(helpText);

		// Parpadeo suave
		FlxTween.tween(helpText, {alpha: 1}, 0.5, {
			ease: FlxEase.quadInOut,
			startDelay: 2,
			type: PINGPONG
		});
	}

	override function destroy()
	{
		#if HSCRIPT_ALLOWED
		StateScriptHandler.callOnScripts('onDestroy', []);
		StateScriptHandler.clearStateScripts();
		#end
		super.destroy();
	}

	function startMusicWithIntro():Void
	{
		var rankMusic:String = currentRank;
		if (currentRank == 'C' || currentRank == 'D')
			rankMusic = 'B';

		FlxG.sound.playMusic(Paths.music('results$rankMusic/results$rankMusic'), 0);

		// Fade in musical suave
		FlxTween.tween(FlxG.sound.music, {volume: 0.7}, 2, {
			ease: FlxEase.quadOut,
			onComplete: function(twn:FlxTween)
			{
				introComplete = true;
			}
		});
	}

	function playIntroAnimation():Void
	{
		// Fade in de cámara
		FlxG.camera.fade(FlxColor.BLACK, 1, true);

		// Animar backgrounds
		FlxTween.tween(bg, {alpha: 0.4}, 1.2, {ease: FlxEase.quadOut});
		FlxTween.tween(bgGradient, {alpha: 0.7}, 1.5, {ease: FlxEase.quadOut});
		FlxTween.tween(bgPattern, {alpha: 0.3}, 1.8, {ease: FlxEase.quadOut});

		// Animar BF entrando
		FlxTween.tween(bf, {x: 120, y: 320}, 1.2, {
			ease: FlxEase.expoOut,
			startDelay: 0.4
		});

		// Iniciar partículas
		new FlxTimer().start(0.8, function(tmr:FlxTimer)
		{
			particles.start(false, 0.08, 0);
			canExit = true;
		});
	}

	function getRatingText(accuracy:Float):String
	{
		if (accuracy == 100)
			return "PERFECT!!";
		if (accuracy >= 95)
			return "AMAZING!";
		if (accuracy >= 90)
			return "EXCELLENT!";
		if (accuracy >= 85)
			return "GREAT!";
		if (accuracy >= 80)
			return "GOOD!";
		if (accuracy >= 70)
			return "NICE!";
		if (accuracy >= 60)
			return "OK";
		return "KEEP TRYING";
	}

	function getRatingColor(accuracy:Float):Int
	{
		if (accuracy == 100)
			return FlxColor.fromRGB(255, 215, 0); // Dorado
		if (accuracy >= 95)
			return FlxColor.fromRGB(100, 255, 100);
		if (accuracy >= 85)
			return FlxColor.CYAN;
		if (accuracy >= 70)
			return FlxColor.YELLOW;
		if (accuracy >= 60)
			return FlxColor.ORANGE;
		return FlxColor.RED;
	}

	override function update(elapsed:Float)
	{
		#if HSCRIPT_ALLOWED
		StateScriptHandler.callOnScripts('onUpdate', [elapsed]);
		#end

		super.update(elapsed);

		// Actualizar beat timer para efectos de pulso
		if (FlxG.sound.music != null && FlxG.sound.music.playing)
		{
			beatTimer += elapsed * 1000;
			var bpm:Float = 120; // BPM de la música de resultados
			var beatInterval:Float = (60 / bpm) * 1000;

			if (beatTimer >= beatInterval)
			{
				beatTimer = 0;
				onBeat();
			}
		}

		// Rotación sutil del pattern
		if (bgPattern != null)
			bgPattern.angle += elapsed * 2;

		// Animación idle de BF
		if (bf.animation.finished || bf.animation.curAnim.name == 'idle')
			bf.animation.play('idle', true);

		var pressedEnter:Bool = FlxG.keys.justPressed.ENTER;
		var pressedRetry:Bool = FlxG.keys.justPressed.R;

		#if mobile
		for (touch in FlxG.touches.list)
		{
			if (touch.justPressed)
			{
				pressedEnter = true;
			}
		}
		#end

		if (pressedEnter && canExit && !isExiting)
		{
			exitState(false);
		}

		if (pressedRetry && canExit && !isExiting)
		{
			exitState(true);
		}

		#if HSCRIPT_ALLOWED
		StateScriptHandler.callOnScripts('onUpdatePost', [elapsed]);
		#end
	}

	function onBeat():Void
	{
		#if HSCRIPT_ALLOWED
		StateScriptHandler.callOnScripts('onBeatHit', [beatTimer]);
		#end

		// Efecto de pulso en elementos clave
		for (element in pulseElements)
		{
			if (element != null)
			{
				FlxTween.cancelTweensOf(element.scale);
				element.scale.set(element.scale.x * 1.05, element.scale.y * 1.05);
				FlxTween.tween(element.scale, {x: element.scale.x / 1.05, y: element.scale.y / 1.05}, 0.3, {
					ease: FlxEase.quadOut
				});
			}
		}

		// Bump sutil de cámara
		FlxG.camera.zoom = 1.01;
		FlxTween.tween(FlxG.camera, {zoom: 1}, 0.3, {ease: FlxEase.quadOut});
	}

	function exitState(retry:Bool = false):Void
	{
		isExiting = true;
		bf.animation.play('hey', true);

		// Efectos de salida
		if (FlxG.save.data.flashing)
			FlxG.camera.flash(FlxColor.WHITE, 0.5);
		FlxG.camera.shake(0.005, 0.3);

		// Fade out de música
		FlxTween.tween(FlxG.sound.music, {volume: 0}, 0.8, {ease: FlxEase.quadIn});

		// Animar elementos saliendo
		FlxTween.tween(rankSprite, {y: rankSprite.y - 100, alpha: 0}, 0.6, {
			ease: FlxEase.backIn
		});

		FlxTween.tween(bf, {x: -200, alpha: 0}, 0.8, {
			ease: FlxEase.expoIn
		});

		for (text in scoreDisplay)
		{
			FlxTween.tween(text, {x: text.x - 150, alpha: 0}, 0.5, {
				ease: FlxEase.quadIn
			});
		}

		if (accuracyText != null)
		{
			FlxTween.tween(accuracyText, {y: FlxG.height + 100, alpha: 0}, 0.7, {
				ease: FlxEase.backIn
			});
		}

		// Fade out general
		FlxG.camera.fade(FlxColor.BLACK, 1.2, false);

		new FlxTimer().start(1.2, function(tmr:FlxTimer)
		{
			FlxG.sound.music.stop();

			if (retry && PlayState.SONG.song != null)
			{
				FlxG.sound.play(Paths.sound('menus/confirmMenu'), 0.6);
				PlayState.startFromTime = null; // ✨ Empezar desde el inicio

				// Pequeño delay para que el usuario vea el mensaje
				new FlxTimer().start(0.3, function(tmr:FlxTimer)
				{
					FlxG.mouse.visible = false;
					LoadingState.loadAndSwitchState(new PlayState());
				});
			}
			else
			{
				// Volver al menú correspondiente
				if (PlayState.isStoryMode)
				{
					StateTransition.switchState(new funkin.menus.StoryMenuState());
				}
				else
				{
					StickerTransition.start(function()
					{
						StateTransition.switchState(new funkin.menus.FreeplayState());
					});
				}
			}
		});
	}
}

// === CLASE PARA BARRAS DE ESTADÍSTICAS ===
class StatBar extends FlxSpriteGroup
{
	var targetWidth:Float;
	var maxWidth:Float = 400;
	var barColor:Int;
	var bgBar:FlxSprite;
	var fillBar:FlxSprite;

	public function new(x:Float, y:Float, percentage:Float, color:Int)
	{
		super(x, y);

		barColor = color;
		targetWidth = maxWidth * percentage;

		// Barra de fondo (gris oscuro)
		bgBar = new FlxSprite(x, y);
		bgBar.makeGraphic(Std.int(maxWidth), 30, FlxColor.fromRGB(40, 40, 40));
		bgBar.alpha = 0.6;

		// Barra de relleno (color)
		fillBar = new FlxSprite(x, y);
		fillBar.makeGraphic(1, 30, color);
		fillBar.scale.x = 0;

		alpha = 0;
	}

	public function animateBar():Void
	{
		// Animar el llenado de la barra
		FlxTween.tween(fillBar.scale, {x: targetWidth}, 0.8, {
			ease: FlxEase.expoOut
		});

		// Efecto de brillo
		FlxTween.tween(fillBar, {alpha: 1}, 0.2, {
			type: PINGPONG,
			loopDelay: 0.3
		});
	}

	override function draw():Void
	{
		if (bgBar != null)
			bgBar.draw();
		if (fillBar != null)
			fillBar.draw();
		super.draw();
	}

	override function destroy():Void
	{
		if (bgBar != null)
			bgBar.destroy();
		if (fillBar != null)
			fillBar.destroy();
		super.destroy();
	}
}
