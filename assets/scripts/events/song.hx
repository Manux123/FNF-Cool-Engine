// assets/scripts/events/song.hx
// Eventos relacionados con la canción y el Conductor.

// ── BPM Change ────────────────────────────────────────────────
// value1 = nuevo BPM (float, ej "150")
registerEvent("BPM Change", function(v1, v2, time) {
	var bpm = Std.parseFloat(v1);
	if (Math.isNaN(bpm) || bpm <= 0) {
		trace('[Event] BPM Change: valor inválido "' + v1 + '"');
		return false;
	}
	Conductor.changeBPM(bpm);
	trace('[Event] BPM → ' + bpm);
	return false;
});
