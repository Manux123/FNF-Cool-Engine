/**
 * ChangeCharacter.hx
 * Evento: "Change Character" / "Swap Character"
 *
 * v1 = slot  →  "bf" / "boyfriend" / "player"
 *               "dad" / "opponent"
 *               "gf" / "girlfriend"
 * v2 = nombre del nuevo personaje (debe existir en assets/characters/)
 */
function onCharacterChange(slot, newCharName)
{
	if (game == null || newCharName == null || newCharName == '')
		return;

	// Resolvemos qué Character hay que reemplazar
	var target = null;
	var slotLow = slot.toLowerCase();

	if (slotLow == 'bf' || slotLow == 'boyfriend' || slotLow == 'player')
		target = game.boyfriend;
	else if (slotLow == 'dad' || slotLow == 'opponent')
		target = game.dad;
	else if (slotLow == 'gf' || slotLow == 'girlfriend')
		target = game.gf;

	if (target == null)
	{
		trace('ChangeCharacter: slot "' + slot + '" no reconocido.');
		return;
	}

	// Cargamos los datos del nuevo personaje reutilizando la posición actual
	var oldX = target.x;
	var oldY = target.y;
	var wasPlayer = target.isPlayer;

	target.loadCharacterSparrow(newCharName); // recarga spritesheet
	target.curCharacter = newCharName;
	target.isPlayer = wasPlayer;
	target.setPosition(oldX, oldY);

	// Actualizamos la referencia en los scripts para que 'boyfriend' / 'dad' / 'gf'
	// apunten al objeto correcto (sigue siendo el mismo, solo recargado)
	if (slotLow == 'bf' || slotLow == 'boyfriend' || slotLow == 'player')
	{
		game.boyfriend = target;
		// Actualiza el icono de salud si el HUD lo soporta
		if (game.uiManager != null)
			game.uiManager.updatePlayerIcon(target.healthIcon, target.healthBarColor);
	}
	else if (slotLow == 'dad' || slotLow == 'opponent')
	{
		game.dad = target;
		if (game.uiManager != null)
			game.uiManager.updateOpponentIcon(target.healthIcon, target.healthBarColor);
	}
	else if (slotLow == 'gf' || slotLow == 'girlfriend')
	{
		game.gf = target;
	}

	trace('ChangeCharacter: ' + slot + ' → ' + newCharName);
}
