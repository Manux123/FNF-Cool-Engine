/**
 * ChangeCharacter.hx
 * Evento: "Change Character" / "Swap Character"
 *
 * v1 = slot  →  "bf" / "boyfriend" / "player"
 *               "dad" / "opponent"
 *               "gf" / "girlfriend"
 * v2 = nombre del nuevo personaje (debe existir en assets/characters/)
 *
 * FIXES aplicados respecto a la versión original:
 *   1. Reemplazado target.loadCharacterSparrow() (solo recargaba el spritesheet)
 *      por target.reloadCharacter() — recarga datos JSON + spritesheet + anims + offsets.
 *   2. Reemplazado game.uiManager.updatePlayerIcon() / updateOpponentIcon()
 *      (métodos inexistentes → Null Function Pointer) por game.uiManager.setIcons()
 *      que es la API real de UIScriptedManager en Cool Engine.
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

	// FIX 1: reloadCharacter() recarga TODO (JSON + spritesheet + anims + offsets)
	// y preserva internamente la posición e isPlayer, así que no hace falta
	// guardarlos nosotros salvo para actualizar la referencia en PlayState.
	var oldX = target.x;
	var oldY = target.y;

	target.reloadCharacter(newCharName);

	// Actualizamos la referencia en PlayState (el objeto sigue siendo el mismo,
	// solo recargado con nuevos datos visuales).
	if (slotLow == 'bf' || slotLow == 'boyfriend' || slotLow == 'player')
		game.boyfriend = target;
	else if (slotLow == 'dad' || slotLow == 'opponent')
		game.dad = target;
	else if (slotLow == 'gf' || slotLow == 'girlfriend')
		game.gf = target;

	// FIX 2: setIcons(p1, p2) es la API correcta de UIScriptedManager.
	// updatePlayerIcon() / updateOpponentIcon() no existen y causaban Null Function Pointer.
	if (game.uiManager != null && game.boyfriend != null && game.dad != null)
		game.uiManager.setIcons(game.boyfriend.healthIcon, game.dad.healthIcon);

	trace('ChangeCharacter: ' + slot + ' → ' + newCharName);
}
