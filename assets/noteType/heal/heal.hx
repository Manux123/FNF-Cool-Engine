function onSpawn(note) {
    // Verde brillante
    note.color = 0xFF00FF66;
}

function onPlayerHit(note, game) {
    // Dar salud extra al tocarla
    game.gameState.modifyHealth(0.4);
    // Dejar que la lógica normal también corra (no cancelar)
    return false;
}
