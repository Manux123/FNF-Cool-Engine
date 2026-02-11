var trainSound = null;
var phillyCityLights = null;
var train = null;
var curLight:Int = 0;
var trainMoving:Bool = false;
var trainCooldown:Int = 0;

// ==========================================
// INICIALIZACIÓN
// ==========================================

function onCreate()
{
	trace('[Philly Stage] Script cargado');

	// Esperar a que el stage esté listo
	// Se llamará onStageCreate cuando esté disponible
}

function onStageCreate()
{
	trace('[Philly Stage] Stage creado, obteniendo elementos...');

	// Obtener elementos del stage
	if (stage != null)
	{
		trainSound = stage.getSound('trainSound');
		phillyCityLights = stage.getGroup('phillyCityLights');
		train = stage.getElement('train');

		trace('[Philly Stage] Elementos inicializados:');
		trace('  - trainSound: ' + (trainSound != null));
		trace('  - phillyCityLights: ' + (phillyCityLights != null));
		trace('  - train: ' + (train != null));
	}
}

// ==========================================
// BEAT HIT - LUCES Y TREN
// ==========================================

function onBeatHit(beat)
{
	if (!trainMoving)
		trainCooldown += 1;

	if (beat % 4 == 0 && phillyCityLights != null)
	{
		phillyCityLights.forEach(function(light:FlxSprite)
		{
			light.visible = false;
		});

		curLight = FlxG.random.int(0, phillyCityLights.length - 1);
		phillyCityLights.members[curLight].visible = true;
	}

	if (beat % 8 == 4 && FlxG.random.bool(30) && !trainMoving && trainCooldown > 8)
	{
		trainCooldown = FlxG.random.int(-4, 0);
		trainMoving = true;
		if (trainSound != null)
			trainSound.play(true);
	}
}

// ==========================================
// FUNCIONES DEL TREN
// ==========================================

// ==========================================
// UPDATE - MOVIMIENTO DEL TREN
// ==========================================

function onUpdate(elapsed)
{
	if (trainMoving && train != null)
	{
		train.x -= 150;
		train.visible = false;

		if (train.x < -4000)
		{
			train.visible = true;
			new FlxTimer().start(2, function(tmr:FlxTimer)
			{
				FlxTween.tween(train, {x: 2000}, 3, {type: FlxTweenType.ONESHOT});
				trainMoving = false;
			});
		}
	}
}

// ==========================================
// CLEANUP
// ==========================================

function onDestroy()
{
	trace('[Philly Stage] Limpiando...');

	// Detener sonido si está reproduciendo
	if (trainSound != null && trainSound.playing)
		trainSound.stop();
}