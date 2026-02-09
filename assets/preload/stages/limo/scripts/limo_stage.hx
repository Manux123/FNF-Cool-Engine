var fastCar = null;
var fastCarCanDrive:Bool = true;

// ==========================================
// INICIALIZACIÓN
// ==========================================

function onCreate()
{
	trace('[Limo Stage] Script cargado');
}

function onStageCreate()
{
	trace('[Limo Stage] Stage creado, obteniendo elementos...');
	
	// Obtener elementos del stage
	if (stage != null)
	{
		fastCar = stage.getElement('fastCar');
		
		// Inicializar el carro
		if (fastCar != null)
		{
			resetFastCar();
		}
		
		trace('[Limo Stage] Elementos inicializados:');
		trace('  - fastCar: ' + (fastCar != null));
	}
}

// ==========================================
// BEAT HIT - CARRO ALEATORIO
// ==========================================

function onBeatHit(beat)
{
	// 10% de probabilidad de que pase el carro
	if (FlxG.random.bool(10) && fastCarCanDrive)
	{
		fastCarDrive();
	}
}

// ==========================================
// FUNCIONES DEL CARRO
// ==========================================

function resetFastCar()
{
	if (fastCar != null)
			{
				fastCar.x = -12600;
				fastCar.y = FlxG.random.int(140, 250);
				fastCar.velocity.x = 0;
				fastCarCanDrive = true;
			}
	
	trace('[Limo Stage] Fast car reseteado');
}

function fastCarDrive()
{
	if (fastCar == null || !fastCarCanDrive) return;
	
	trace('[Limo Stage] ¡Fast car pasando!');
	
	// Reproducir sonido aleatorio de carro
	var carNum = FlxG.random.int(0, 1);
	FlxG.sound.play(Paths.soundRandom('carPass', 0, 1), 0.7);
	
	// Darle velocidad al carro
	// Velocidad aleatoria entre 170-220, ajustada por elapsed
	var speed = FlxG.random.int(170, 220);
	fastCar.velocity.x = (speed / FlxG.elapsed) * 3;
	
	// Prevenir que otro carro aparezca inmediatamente
	fastCarCanDrive = false;
	
	// Después de 2 segundos, resetear el carro
	new FlxTimer().start(2, function(tmr) {
		resetFastCar();
	});
}

// ==========================================
// UPDATE - VERIFICAR SI EL CARRO SALIÓ
// ==========================================

function onUpdate(elapsed)
{
	// El carro se mueve automáticamente con velocity.x
	// Podríamos verificar si salió de la pantalla para optimizar
	if (fastCar != null && fastCar.velocity.x > 0)
	{
		// Si el carro ya salió muy lejos de la pantalla
		if (fastCar.x > FlxG.width + 1000)
		{
			// Detenerlo para evitar que se siga moviendo innecesariamente
			fastCar.velocity.x = 0;
		}
	}
}

// ==========================================
// EVENTOS PERSONALIZADOS
// ==========================================

function onEvent(name, value1, value2, time)
{
	switch(name.toLowerCase())
	{
		case 'spawn fast car':
			// Forzar que pase el carro
			if (fastCarCanDrive)
				fastCarDrive();
		
		case 'reset fast car':
			// Resetear el carro inmediatamente
			resetFastCar();
	}
	
	return false;
}

// ==========================================
// CLEANUP
// ==========================================

function onDestroy()
{
	trace('[Limo Stage] Limpiando...');
	
	// Detener el carro si está en movimiento
	if (fastCar != null)
	{
		fastCar.velocity.x = 0;
	}
}
