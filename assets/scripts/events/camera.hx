// assets/scripts/events/camera.hx
// Eventos de cámara built-in portados a HScript.
// Se cargan globalmente — funcionan en cualquier canción.

// ── Camera Follow ─────────────────────────────────────────────
// value1 = target: player | opponent | gf  (aliases: bf, dad, girlfriend)
// value2 = (opcional) lerp speed, ej "0.04"
registerEvent("Camera Follow", function(v1, v2, time) {
	var g = PlayState.instance;
	if (g == null || v1 == null || StringTools.trim(v1) == '') return false;

	var target = StringTools.trim(v1);
	g.cameraController.setTarget(target);

	if (v2 != null && StringTools.trim(v2) != '') {
		var lerp = Std.parseFloat(StringTools.trim(v2));
		if (!Math.isNaN(lerp))
			g.cameraController.setFollowLerp(lerp);
	}

	return false;
});

// ── Camera Zoom ───────────────────────────────────────────────
// value1 = cantidad a sumar al zoom actual (ej "0.05")
// value2 = duración del tween en segundos (0 o vacío = instantáneo)
registerEvent("Camera Zoom", function(v1, v2, time) {
	var g = PlayState.instance;
	if (g == null) return false;

	var amount   = Std.parseFloat(v1);
	var duration = Std.parseFloat(v2);
	if (Math.isNaN(amount))   amount   = 0.05;
	if (Math.isNaN(duration)) duration = 0;

	if (duration > 0)
		FlxTween.tween(g.camGame, {zoom: g.camGame.zoom + amount}, duration, {ease: FlxEase.sineOut});
	else
		g.camGame.zoom += amount;

	return false;
});

// ── Camera Flash ──────────────────────────────────────────────
// value1 = duración en segundos
// value2 = color hex sin # (vacío = blanco)
registerEvent("Camera Flash", function(v1, v2, time) {
	var g = PlayState.instance;
	if (g == null) return false;

	var duration = Std.parseFloat(v1);
	if (Math.isNaN(duration)) duration = 1;

	var color = FlxColor.WHITE;
	if (v2 != null && StringTools.trim(v2) != '')
		color = FlxColor.fromString('#' + StringTools.replace(StringTools.trim(v2), '#', ''));

	g.camHUD.flash(color, duration);
	return false;
});

// ── Camera Fade ───────────────────────────────────────────────
// value1 = duración en segundos
// value2 = color hex sin # (vacío = negro)
registerEvent("Camera Fade", function(v1, v2, time) {
	var g = PlayState.instance;
	if (g == null) return false;

	var duration = Std.parseFloat(v1);
	if (Math.isNaN(duration)) duration = 1;

	var color = FlxColor.BLACK;
	if (v2 != null && StringTools.trim(v2) != '')
		color = FlxColor.fromString('#' + StringTools.replace(StringTools.trim(v2), '#', ''));

	g.camHUD.fade(color, duration);
	return false;
});

// ── Screen Shake ──────────────────────────────────────────────
// value1 = intensidad (ej "0.05")
// value2 = duración en segundos (ej "0.5")
registerEvent("Screen Shake", function(v1, v2, time) {
	var g = PlayState.instance;
	if (g == null) return false;

	var intensity = Std.parseFloat(v1);
	var duration  = Std.parseFloat(v2);
	if (Math.isNaN(intensity)) intensity = 0.05;
	if (Math.isNaN(duration))  duration  = 0.5;

	g.camGame.shake(intensity, duration);
	return false;
});
