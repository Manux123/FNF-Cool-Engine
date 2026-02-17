// assets/scripts/events/characters.hx
// Eventos de personajes built-in portados a HScript.

// ── Hey! ──────────────────────────────────────────────────────
// value1 = target: "bf" | "gf" | (vacío = ambos)
registerEvent("Hey!", function(v1, v2, time) {
	var g      = PlayState.instance;
	if (g == null) return false;
	var target = v1 != null ? StringTools.toLowerCase(StringTools.trim(v1)) : '';

	if (target == 'bf' || target == 'boyfriend' || target == '')
		if (g.boyfriend != null) g.boyfriend.playAnim('hey', true);

	if (target == 'gf' || target == 'girlfriend' || target == '')
		if (g.gf != null) g.gf.playAnim('cheer', true);

	return false;
});

// ── Play Animation ────────────────────────────────────────────
// value1 = target: player | opponent | gf  (aliases: bf, dad, girlfriend)
// value2 = nombre de la animación (ej "singLEFT", "idle")
registerEvent("Play Animation", function(v1, v2, time) {
	var g      = PlayState.instance;
	if (g == null) return false;
	var target = v1 != null ? StringTools.toLowerCase(StringTools.trim(v1)) : '';
	var anim   = v2 != null ? StringTools.trim(v2) : '';
	if (anim == '') return false;

	if (target == 'player' || target == 'bf' || target == 'boyfriend') {
		if (g.boyfriend != null) g.boyfriend.playAnim(anim, true);
	} else if (target == 'opponent' || target == 'dad' || target == 'enemy') {
		if (g.dad != null) g.dad.playAnim(anim, true);
	} else if (target == 'gf' || target == 'girlfriend') {
		if (g.gf != null) g.gf.playAnim(anim, true);
	}

	return false;
});

// ── Change Character ──────────────────────────────────────────
// value1 = slot: player | opponent | gf
// value2 = nombre del personaje (json), ej "pico", "monster"
//
// Requiere que PlayState exponga un método changeCharacter(slot, name).
// Descomentar cuando esté implementado.
registerEvent("Change Character", function(v1, v2, time) {
	var g       = PlayState.instance;
	if (g == null) return false;
	var target  = v1 != null ? StringTools.toLowerCase(StringTools.trim(v1)) : '';
	var newChar = v2 != null ? StringTools.trim(v2) : '';
	if (newChar == '' || target == '') return false;

	// g.changeCharacter(target, newChar);
	trace('[Event] Change Character: ' + target + ' → ' + newChar + ' (implementar en PlayState)');
	return false;
});

// ── Set GF Speed ──────────────────────────────────────────────
// value1 = velocidad de baile (int, mínimo 1)
//
// Requiere que PlayState exponga gfSpeed como campo público.
registerEvent("Set GF Speed", function(v1, v2, time) {
	var g     = PlayState.instance;
	if (g == null) return false;
	var speed = Std.parseInt(v1);
	if (speed == null || speed < 1) speed = 1;

	// g.gfSpeed = speed;
	trace('[Event] Set GF Speed: ' + speed + ' (implementar en PlayState)');
	return false;
});
