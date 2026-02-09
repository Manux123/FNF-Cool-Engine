package funkin.gameplay;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.ui.FlxBar;
import flixel.util.FlxColor;
import funkin.gameplay.objects.character.HealthIcon;
import funkin.gameplay.GameState;
import flixel.math.FlxMath;
import funkin.data.Conductor;
import funkin.gameplay.objects.hud.ScoreManager;

using StringTools;

/**
 * UIManager - Gestión del HUD y elementos UI
 * Popups, ratings, combo, health bar, iconos
 */
class UIManager extends FlxGroup
{
	// === CAMERAS ===
	private var camHUD:FlxCamera;

	// === HEALTH BAR ===
	private var healthBarBG:FlxSprite;
	private var healthBar:FlxBar;

	public var iconP1:HealthIcon;
	public var iconP2:HealthIcon;
	public var scoreManager:ScoreManager;

	// === TEXT ===
	private var scoreTxt:FlxText;
	private var songNameTxt:FlxText;
	private var lastScore:Int = -1;
	private var lastMisses:Int = -1;
	private var lastAccuracy:Float = -1.0;

	// === GAME STATE ===
	private var gameState:GameState;

	// === CONFIG ===
	private var curStage:String = '';
	private var iconP1Name:String = 'bf';
	private var iconP2Name:String = 'dad';

	// === POOLS (para popups) ===
	private var ratingPool:Array<FlxSprite> = [];
	private var comboPool:Array<FlxSprite> = [];
	private var numberPool:Array<FlxSprite> = [];

	public function new(camHUD:FlxCamera, gameState:GameState)
	{
		super();

		this.camHUD = camHUD;
		this.gameState = gameState;
		// Inicializar scoreManager
		scoreManager = new ScoreManager();

		createHealthBar();
		createScoreText();
	}

	/**
	 * Crear health bar
	 */
	private function createHealthBar():Void
	{
		healthBarBG = new FlxSprite(0, FlxG.height * 0.9).loadGraphic(Paths.image('UI/healthBar'));
		healthBarBG.screenCenter(X);
		healthBarBG.scrollFactor.set();
		healthBarBG.cameras = [camHUD];
		add(healthBarBG);

		healthBar = new FlxBar(healthBarBG.x + 4, healthBarBG.y + 4, RIGHT_TO_LEFT, Std.int(healthBarBG.width - 8), Std.int(healthBarBG.height - 8),
			gameState, 'health', 0, 2);
		healthBar.scrollFactor.set();
		healthBar.createFilledBar(0xFFFF0000, 0xFF66FF33);
		healthBar.cameras = [camHUD];
		add(healthBar);

		// Iconos
		iconP1 = new HealthIcon(iconP1Name, true);
		iconP1.y = healthBar.y - (iconP1.height / 2);
		iconP1.cameras = [camHUD];
		add(iconP1);

		iconP2 = new HealthIcon(iconP2Name, false);
		iconP2.y = healthBar.y - (iconP2.height / 2);
		iconP2.cameras = [camHUD];
		add(iconP2);
	}

	/**
	 * Crear score text
	 */
	private function createScoreText():Void
	{
		/*
			scoreTxt = new FlxText(healthBarBG.x + healthBarBG.width / 2 - 150, healthBarBG.y + 50, 0, "", 20);
			scoreTxt.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER);
			scoreTxt.setBorderStyle(OUTLINE, FlxColor.BLACK, 1);
			scoreTxt.scrollFactor.set();
			scoreTxt.cameras = [camHUD];
			add(scoreTxt); */

		scoreTxt = new FlxText(45, healthBarBG.y + 50, 0, "", 32);
		scoreTxt.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 4, 1);
		scoreTxt.color = FlxColor.WHITE;
		scoreTxt.size = 22;
		scoreTxt.y -= 350;
		scoreTxt.scrollFactor.set();
		scoreTxt.cameras = [camHUD];
		add(scoreTxt);
	}

	/**
	 * Update UI cada frame
	 */
	override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		// Actualizar texto de score
		if (lastScore != gameState.score || lastMisses != gameState.misses || lastAccuracy != gameState.accuracy)
		{
			updateScoreText();

			// Guardamos el estado actual para la siguiente comprobación
			lastScore = gameState.score;
			lastMisses = gameState.misses;
			lastAccuracy = gameState.accuracy;
		}

		// Actualizar posición de iconos
		updateIcons();
	}

	/**
	 * Actualizar texto de score
	 */
	private function updateScoreText():Void
	{
		if (FlxG.save.data.accuracyDisplay)
			scoreTxt.text = scoreManager.getHUDText(gameState);
		else
			scoreTxt.text = 'Score: ${gameState.score}\nMisses: ${gameState.misses}';
	}

	/**
	 * Actualizar iconos de health
	 */
	private function updateIcons():Void
	{
		var healthPercent = FlxMath.remapToRange(gameState.health, 0, 2, 0, 100);

		iconP1.setGraphicSize(Std.int(FlxMath.lerp(150, iconP1.width, 0.50)));
		iconP2.setGraphicSize(Std.int(FlxMath.lerp(150, iconP2.width, 0.50)));

		iconP1.updateHitbox();
		iconP2.updateHitbox();

		iconP1.x = healthBar.x + (healthBar.width * (FlxMath.remapToRange(healthPercent, 0, 100, 100, 0) * 0.01) - 26);
		iconP2.x = healthBar.x + (healthBar.width * (FlxMath.remapToRange(healthPercent, 0, 100, 100, 0) * 0.01)) - (iconP2.width - 26);

		// Animaciones de iconos según health

		var p1Anim = 'normal';
		if (healthPercent < 20)
			p1Anim = 'losing';
		else if (healthPercent > 80)
			p1Anim = 'winning';

		var p2Anim = 'normal';
		if (healthPercent > 80)
			p2Anim = 'losing';
		else if (healthPercent < 20)
			p2Anim = 'winning';

		changeIconAnim(iconP1, p1Anim);
		changeIconAnim(iconP2, p2Anim);
	}

	function changeIconAnim(icon:HealthIcon, anim:String)
	{
		if (icon.animation.curAnim != null && icon.animation.curAnim.name != anim)
			icon.animation.play(anim);
	}

	/**
	 * Mostrar popup de rating
	 */
	public function showRatingPopup(ratingName:String, combo:Int):Void
	{
		var pixelShitPart1:String = "normal/score/";
		var pixelShitPart2:String = '';

		if (curStage.startsWith('school'))
		{
			pixelShitPart1 = 'pixelUI/score/';
			pixelShitPart2 = '-pixel';
		}

		// --- USANDO TU RATINGPOOL ---
		var ratingSprite:FlxSprite = getFromPool(ratingPool);

		// Resetear propiedades básicas antes de usar
		ratingSprite.alpha = 1;
		ratingSprite.visible = true;
		ratingSprite.acceleration.y = 0; // Limpiar aceleración previa
		ratingSprite.velocity.set(0, 0);

		ratingSprite.loadGraphic(Paths.image('UI/' + pixelShitPart1 + ratingName + pixelShitPart2));
		ratingSprite.cameras = [camHUD];

		// Posicionamiento
		ratingSprite.x = FlxG.width * 0.55 - 40;
		ratingSprite.y = FlxG.height * 0.5 - 90;
		ratingSprite.acceleration.y = 550;
		ratingSprite.velocity.y = -FlxG.random.int(140, 175);
		ratingSprite.velocity.x = -FlxG.random.int(0, 10);

		if (!curStage.startsWith('school'))
		{
			ratingSprite.setGraphicSize(Std.int(ratingSprite.width * 0.7));
			ratingSprite.antialiasing = true;
		}
		else
		{
			ratingSprite.setGraphicSize(Std.int(ratingSprite.width * PlayStateConfig.PIXEL_ZOOM * 0.7));
			ratingSprite.antialiasing = false;
		}
		ratingSprite.updateHitbox();

		// Tween y "Matar" el objeto en lugar de destruirlo
		FlxTween.tween(ratingSprite, {alpha: 0}, 0.2, {
			startDelay: Conductor.crochet * 0.001,
			onComplete: function(tween:FlxTween)
			{
				ratingSprite.kill(); // Lo marca como disponible para el pool
			}
		});

		if (combo >= 10)
			showComboNumbers(combo, pixelShitPart1, pixelShitPart2);
	}

	/**
	 * Mostrar números de combo
	 */
	private function showComboNumbers(combo:Int, pixelPart1:String, pixelPart2:String):Void
	{
		var comboStr:String = Std.string(combo);
		var seperatedScore:Array<Int> = [];

		// Convertir a array de dígitos
		for (i in 0...comboStr.length)
		{
			seperatedScore.push(Std.parseInt(comboStr.charAt(i)));
		}

		var daLoop:Int = 0;
		for (i in seperatedScore)
		{
			var numScore:FlxSprite = getFromPool(numberPool);

			numScore.alpha = 1;
			numScore.visible = true;
			numScore.acceleration.y = 0; // Limpiar aceleración previa
			numScore.velocity.set(0, 0);

			numScore.loadGraphic(Paths.image('UI/' + pixelPart1 + 'nums/num' + Std.int(i) + pixelPart2));
			numScore.cameras = [camHUD];
			numScore.x = FlxG.width * 0.55 + (43 * daLoop) - 90 + 140;
			numScore.y = FlxG.height * 0.5 + 20;
			numScore.acceleration.y = FlxG.random.int(200, 300);
			numScore.velocity.y = -FlxG.random.int(140, 160);
			numScore.velocity.x = FlxG.random.float(-5, 5);

			if (!curStage.startsWith('school'))
			{
				numScore.antialiasing = true;
				numScore.setGraphicSize(Std.int(numScore.width * 0.5));
			}
			else
			{
				numScore.setGraphicSize(Std.int(numScore.width * 6));
			}

			numScore.updateHitbox();
			

			FlxTween.tween(numScore, {alpha: 0}, 0.2, {
				onComplete: function(tween:FlxTween)
				{
					numScore.kill();
				},
				startDelay: Conductor.crochet * 0.002
			});

			daLoop++;
		}
	}

	private function getFromPool(pool:Array<FlxSprite>):FlxSprite
	{
		for (sprite in pool)
		{
			if (!sprite.exists) // Si el sprite está "muerto", lo reutilizamos
			{
				sprite.revive();
				return sprite;
			}
		}

		// Si no hay ninguno libre, creamos uno nuevo y lo añadimos al pool
		var newSprite:FlxSprite = new FlxSprite();
		pool.push(newSprite);
		add(newSprite); // Lo añadimos al UIManager una sola vez
		return newSprite;
	}

	/**
	 * Mostrar miss popup
	 */
	public function showMissPopup():Void
	{
		var rating:FlxSprite = new FlxSprite();
		rating.loadGraphic(Paths.image('UI/normal/score/miss'));
		rating.cameras = [camHUD];
		rating.x = FlxG.width * 0.55 - 40;
		rating.y = FlxG.height * 0.5 - 90;
		rating.acceleration.y = 550;
		rating.velocity.y = -FlxG.random.int(140, 175);
		rating.velocity.x = -FlxG.random.int(0, 10);

		if (!curStage.startsWith('school'))
		{
			rating.setGraphicSize(Std.int(rating.width * 0.7));
			rating.antialiasing = true;
		}

		rating.updateHitbox();
		add(rating);

		FlxTween.tween(rating, {alpha: 0}, 0.2, {
			startDelay: Conductor.crochet * 0.001,
			onComplete: function(tween:FlxTween)
			{
				remove(rating);
				rating.destroy();
			}
		});
	}

	/**
	 * Set iconos
	 */
	public function setIcons(p1:String, p2:String):Void
	{
		iconP1Name = p1;
		iconP2Name = p2;

		if (iconP1 != null)
			iconP1.updateIcon(p1);
		if (iconP2 != null)
			iconP2.updateIcon(p2);
	}

	/**
	 * Set stage (para cambiar estilo de UI)
	 */
	public function setStage(stage:String):Void
	{
		curStage = stage;
	}

	/**
	 * Bump iconos en beat
	 */
	public function bumpIcons():Void
	{
		if (iconP1 != null)
		{
			iconP1.scale.set(1.2, 1.2);
			iconP1.updateHitbox();
		}

		if (iconP2 != null)
		{
			iconP2.scale.set(1.2, 1.2);
			iconP2.updateHitbox();
		}
	}

	override function destroy():Void
	{
		ratingPool = [];
		comboPool = [];
		numberPool = [];

		super.destroy();
	}
}
