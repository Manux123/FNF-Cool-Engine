// ══════════════════════════════════════════════════════════════════════════
//  assets/ui/default/script.hx
//  Port 1:1 de UIManager.hx
// ══════════════════════════════════════════════════════════════════════════

// ── Variables de estado ──────────────────────────────────────────────────
var healthBarBG;
var healthBar;
var iconP1;
var iconP2;
var scoreTxt;
var scoreManager;

var curStage    = '';
var iconP1Name  = 'bf';
var iconP2Name  = 'dad';

var lastScore    = -1;
var lastMisses   = -1;
var lastAccuracy = -1.0;

// ── Pools (mismos 3 del original) ─────────────────────────────────────────
var ratingPool = [];
var numberPool = [];
var comboPool  = [];

// ══════════════════════════════════════════════════════════════════════════
//  onCreate  ─ replica new UIManager() + createHealthBar() + createScoreText()
// ══════════════════════════════════════════════════════════════════════════
function onCreate()
{
    scoreManager = new ScoreManager();
    _createHealthBar();
    _createScoreText();
}

function _createHealthBar()
{
    var healthBarY = FlxG.save.data.downscroll
        ? FlxG.height * 0.1
        : FlxG.height * 0.9;

    healthBarBG = makeSprite(0, healthBarY);
    healthBarBG.loadGraphic(Paths.image('UI/healthBar'));
    screenCenterX(healthBarBG);
    uiAdd(healthBarBG);

    // makeBar ya configura RIGHT_TO_LEFT, scrollFactor y camHUD
    healthBar = makeBar(
        healthBarBG.x + 4,
        healthBarBG.y + 4,
        Std.int(healthBarBG.width  - 8),
        Std.int(healthBarBG.height - 8),
        gameState, 'health', 0, 2
    );
    healthBar.createFilledBar(0xFFFF0000, 0xFF66FF33);
    uiAdd(healthBar);

    // HealthIcon está expuesto desde UIScriptedManager
    iconP1 = new HealthIcon(iconP1Name, true);
    iconP1.y = healthBar.y - (iconP1.height / 2);
    uiAdd(iconP1);

    iconP2 = new HealthIcon(iconP2Name, false);
    iconP2.y = healthBar.y - (iconP2.height / 2);
    uiAdd(iconP2);
}

function _createScoreText()
{
    scoreTxt = makeText(45, FlxG.height * 0.9, '', 32);
    setTextBorder(scoreTxt, 'outline', 0xFF000000, 4, 1);
    scoreTxt.color = 0xFFFFFFFF;
    scoreTxt.size  = 22;
    scoreTxt.y    -= 350;
    uiAdd(scoreTxt);
}

// ══════════════════════════════════════════════════════════════════════════
//  onUpdate  ─ replica UIManager.update()
// ══════════════════════════════════════════════════════════════════════════
function onUpdate(elapsed)
{
    if (lastScore    != gameState.score
     || lastMisses   != gameState.misses
     || lastAccuracy != gameState.accuracy)
    {
        _updateScoreText();
        lastScore    = gameState.score;
        lastMisses   = gameState.misses;
        lastAccuracy = gameState.accuracy;
    }

    _updateIcons();
}

function _updateScoreText()
{
    if (FlxG.save.data.accuracyDisplay)
        scoreTxt.text = scoreManager.getHUDText(gameState);
    else
        scoreTxt.text = 'Score: ' + gameState.score + '\nMisses: ' + gameState.misses;
}

function _updateIcons()
{
    var healthPercent = FlxMath.remapToRange(gameState.health, 0, 2, 0, 100);

    iconP1.setGraphicSize(Std.int(FlxMath.lerp(150, iconP1.width, 0.50)));
    iconP2.setGraphicSize(Std.int(FlxMath.lerp(150, iconP2.width, 0.50)));
    iconP1.updateHitbox();
    iconP2.updateHitbox();

    iconP1.x = healthBar.x + (healthBar.width * (FlxMath.remapToRange(healthPercent, 0, 100, 100, 0) * 0.01) - 26);
    iconP2.x = healthBar.x + (healthBar.width * (FlxMath.remapToRange(healthPercent, 0, 100, 100, 0) * 0.01)) - (iconP2.width - 26);

    var p1Anim = 'normal';
    if (healthPercent < 20)       p1Anim = 'losing';
    else if (healthPercent > 80)  p1Anim = 'winning';

    var p2Anim = 'normal';
    if (healthPercent > 80)       p2Anim = 'losing';
    else if (healthPercent < 20)  p2Anim = 'winning';

    _changeIconAnim(iconP1, p1Anim);
    _changeIconAnim(iconP2, p2Anim);
}

function _changeIconAnim(icon, anim)
{
    if (icon.animation.curAnim != null && icon.animation.curAnim.name != anim)
        icon.animation.play(anim);
}

// ══════════════════════════════════════════════════════════════════════════
//  onBeatHit  ─ replica bumpIcons()
// ══════════════════════════════════════════════════════════════════════════
function onBeatHit(beat)
{
    if (iconP1 != null) { iconP1.scale.set(1.2, 1.2); iconP1.updateHitbox(); }
    if (iconP2 != null) { iconP2.scale.set(1.2, 1.2); iconP2.updateHitbox(); }
}

// ══════════════════════════════════════════════════════════════════════════
//  onRatingPopup  ─ replica showRatingPopup()
// ══════════════════════════════════════════════════════════════════════════
function onRatingPopup(ratingName, combo)
{
    var pixelPart1 = 'normal/score/';
    var pixelPart2 = '';

    if (StringTools.startsWith(curStage, 'school'))
    {
        pixelPart1 = 'pixelUI/score/';
        pixelPart2 = '-pixel';
    }

    var ratingSprite = _getFromPool(ratingPool);
    ratingSprite.alpha = 1;
    ratingSprite.visible = true;
    ratingSprite.acceleration.y = 0;
    ratingSprite.velocity.set(0, 0);

    ratingSprite.loadGraphic(Paths.image('UI/' + pixelPart1 + ratingName + pixelPart2));

    ratingSprite.x = FlxG.width  * 0.55 - 40;
    ratingSprite.y = FlxG.height * 0.5  - 90;
    ratingSprite.acceleration.y = 550;
    ratingSprite.velocity.y = -FlxG.random.int(140, 175);
    ratingSprite.velocity.x = -FlxG.random.int(0, 10);

    if (!StringTools.startsWith(curStage, 'school'))
    {
        ratingSprite.setGraphicSize(Std.int(ratingSprite.width * 0.7));
        ratingSprite.antialiasing = FlxG.save.data.antialiasing;
    }
    else
    {
        ratingSprite.setGraphicSize(Std.int(ratingSprite.width * PIXEL_ZOOM * 0.7));
        ratingSprite.antialiasing = false;
    }
    ratingSprite.updateHitbox();

    FlxTween.tween(ratingSprite, {alpha: 0}, 0.2, {
        startDelay: Conductor.crochet * 0.001,
        onComplete: function(tween) { ratingSprite.kill(); }
    });

    if (combo >= 10)
        _showComboNumbers(combo, pixelPart1, pixelPart2);
}

// ══════════════════════════════════════════════════════════════════════════
//  _showComboNumbers  ─ replica showComboNumbers()
// ══════════════════════════════════════════════════════════════════════════
function _showComboNumbers(combo, pixelPart1, pixelPart2)
{
    var comboStr = Std.string(combo);
    var separatedScore = [];

    for (i in 0...comboStr.length)
        separatedScore.push(Std.parseInt(comboStr.charAt(i)));

    var daLoop = 0;
    for (i in separatedScore)
    {
        var numScore = _getFromPool(numberPool);
        numScore.alpha = 1;
        numScore.visible = true;
        numScore.acceleration.y = 0;
        numScore.velocity.set(0, 0);

        numScore.loadGraphic(Paths.image('UI/' + pixelPart1 + 'nums/num' + Std.int(i) + pixelPart2));

        numScore.x = FlxG.width  * 0.55 + (43 * daLoop) - 90 + 140;
        numScore.y = FlxG.height * 0.5  + 20;
        numScore.acceleration.y = FlxG.random.int(200, 300);
        numScore.velocity.y = -FlxG.random.int(140, 160);
        numScore.velocity.x = FlxG.random.float(-5, 5);

        if (!StringTools.startsWith(curStage, 'school'))
        {
            numScore.antialiasing = FlxG.save.data.antialiasing;
            numScore.setGraphicSize(Std.int(numScore.width * 0.5));
        }
        else
        {
            numScore.setGraphicSize(Std.int(numScore.width * 6));
        }
        numScore.updateHitbox();

        FlxTween.tween(numScore, {alpha: 0}, 0.2, {
            startDelay: Conductor.crochet * 0.002,
            onComplete: function(tween) { numScore.kill(); }
        });

        daLoop++;
    }
}

// ══════════════════════════════════════════════════════════════════════════
//  onMissPopup  ─ replica showMissPopup()
//  El original crea un sprite fresco y lo destruye al terminar (sin pool).
//  Replicamos ese comportamiento exacto con uiAdd / uiRemove / destroy.
// ══════════════════════════════════════════════════════════════════════════
function onMissPopup()
{
    var rating = makeSprite();
    rating.loadGraphic(Paths.image('UI/normal/score/miss'));

    rating.x = FlxG.width  * 0.55 - 40;
    rating.y = FlxG.height * 0.5  - 90;
    rating.acceleration.y = 550;
    rating.velocity.y = -FlxG.random.int(140, 175);
    rating.velocity.x = -FlxG.random.int(0, 10);

    if (!StringTools.startsWith(curStage, 'school'))
    {
        rating.setGraphicSize(Std.int(rating.width * 0.7));
        rating.antialiasing = FlxG.save.data.antialiasing;
    }
    rating.updateHitbox();

    uiAdd(rating);

    FlxTween.tween(rating, {alpha: 0}, 0.2, {
        startDelay: Conductor.crochet * 0.001,
        onComplete: function(tween)
        {
            uiRemove(rating);
            rating.destroy();
        }
    });
}

// ══════════════════════════════════════════════════════════════════════════
//  onIconsSet  ─ replica setIcons()
// ══════════════════════════════════════════════════════════════════════════
function onIconsSet(p1, p2)
{
    iconP1Name = p1;
    iconP2Name = p2;
    if (iconP1 != null) iconP1.updateIcon(p1);
    if (iconP2 != null) iconP2.updateIcon(p2);
}

// ══════════════════════════════════════════════════════════════════════════
//  onStageSet  ─ replica setStage()
// ══════════════════════════════════════════════════════════════════════════
function onStageSet(stage)
{
    curStage = stage;
}

// ══════════════════════════════════════════════════════════════════════════
//  onDestroy  ─ replica UIManager.destroy()
// ══════════════════════════════════════════════════════════════════════════
function onDestroy()
{
    ratingPool = [];
    comboPool  = [];
    numberPool = [];
}

// ══════════════════════════════════════════════════════════════════════════
//  _getFromPool  ─ replica exacta de UIManager.getFromPool()
//  Diferencia: usa makeSprite() + uiAdd() en lugar de new FlxSprite() + add()
//  El resultado es idéntico — el sprite queda en el grupo desde la primera vez.
// ══════════════════════════════════════════════════════════════════════════
function _getFromPool(pool)
{
    for (sprite in pool)
    {
        if (!sprite.exists)
        {
            sprite.revive();
            return sprite;
        }
    }

    var newSprite = makeSprite();
    pool.push(newSprite);
    uiAdd(newSprite);
    return newSprite;
}
