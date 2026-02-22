// Mine Note — daña al jugador si la toca
function onSpawn(note) {
    // Colorear la nota de rojo
    note.color = 0xFFFF3333;
}

// Devuelve true para CANCELAR la lógica normal (no dar puntos ni salud)
function onPlayerHit(note, game) {
    // Restar salud al tocar
    game.gameState.modifyHealth(-0.35);
    game.gameState.processMiss(); // contar como miss
    FlxG.sound.play(Paths.soundRandom('missnote', 1, 3), 0.3);
    return true; // cancelar lógica normal de hit
}

// No penalizar si el jugador NO la toca (las mines NO se deben tocar)
function onMiss(note, game) {
    return true; // cancelar penalización de miss — ¡es correcto no tocarla!
}

function onCPUHit(note, game) {
    // El CPU tampoco la "activa"
}
