// SPOOKY STAGE SCRIPT
// Ubication: assets/stages/spooky/scripts/spooky.hx
// Or: assets/songs/south/scripts/spooky_stage.hx (for song specific)

var halloweenBG = null;

var lightningStrikeBeat:Int = 0;
var lightningOffset:Int = 8;

function onCreate()
{
	trace('[Spooky Stage] Script cargado');
}

function onStageCreate()
{
	trace('[Spooky Stage] Stage creado, obteniendo elementos...');
	
	// Obtener elementos del stage
	if (stage != null)
	{
		halloweenBG = stage.getElement('halloweenBG');
		
		trace('[Spooky Stage] Elementos inicializados:');
		trace('  - halloweenBG: ' + (halloweenBG != null));
	}
}

// ==========================================
// BEAT HIT - LIGHTNING
// ==========================================

function onBeatHit(beat)
{
	// 10% de probabilidad de rayo, pero debe haber pasado suficiente tiempo
	if (FlxG.random.bool(10) && beat > lightningStrikeBeat + lightningOffset)
	{
		triggerLightning();
	}
}

// ==========================================
// FUNCIONES DEL RAYO
// ==========================================

function triggerLightning()
{
	trace('[Spooky Stage] ¡Rayo!');
	
	// Reproducir sonido de trueno (aleatorio entre thunder_1 y thunder_2)
	var thunderNum = FlxG.random.int(1, 2);
	FlxG.sound.play(Paths.soundRandom('thunder_', 1, 2));
	
	// Animar el background
	if (halloweenBG != null && halloweenBG.animation != null)
	{
		halloweenBG.animation.play('lightning');
	}
	
	// Asustar a los personajes
	if (boyfriend != null)
		boyfriend.playAnim('scared', true);
	
	if (gf != null)
		gf.playAnim('scared', true);
	
	// Actualizar timing del próximo rayo
	lightningStrikeBeat = playState.curBeat;
	lightningOffset = FlxG.random.int(8, 24);
	
	// Flash en la cámara para efecto extra
	camGame.flash(FlxColor.WHITE, 0.15, null, true);
}

// ==========================================
// EVENTOS PERSONALIZADOS
// ==========================================

function onEvent(name, value1, value2, time)
{
	switch(name.toLowerCase())
	{
		case 'lightning strike':
			// Permitir forzar un rayo desde eventos
			triggerLightning();
		
		case 'set lightning chance':
			// Cambiar la probabilidad del rayo
			// Nota: Esto requeriría modificar el código del onBeatHit
			// para usar una variable en lugar de un valor fijo
			trace('[Spooky Stage] Evento: cambiar probabilidad de rayo a ' + value1 + '%');
	}
	
	return false;
}

// ==========================================
// CLEANUP
// ==========================================

function onDestroy()
{
	trace('[Spooky Stage] Limpiando...');
}
