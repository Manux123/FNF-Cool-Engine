
// ── Constantes de posición base ──────────────────────────────
var BASE_PLAYER_X = 740;
var BASE_CPU_X    = 100;
var BASE_Y        = 50;
var SCREEN_W      = 1280;
var SCREEN_H      = 720;

// ── Estado interno ────────────────────────────────────────────
var inChaosMode   = false;
var swapActive    = false;
var beatCount     = 0;

// ── Helpers de matemática ─────────────────────────────────────
function sin(deg) { return Math.sin(deg * Math.PI / 180); }
function cos(deg) { return Math.cos(deg * Math.PI / 180); }
function rand(min, max) { return min + Math.random() * (max - min); }

// ─────────────────────────────────────────────────────────────
//  onCreate — pre-generar todos los eventos estáticos
// ─────────────────────────────────────────────────────────────
function onCreate() {

    // ╔════════════════════════════════════════╗
    // ║  FASE 1 (beat 32-64): INTRO SUAVE      ║
    // ║  Pulso de escala en cada 4 beats        ║
    // ╚════════════════════════════════════════╝

    for (b in 0...8) {
        var beat = 32 + b * 4;
        // Pump sutil en todos los strums
        modChart.addEventSimple(beat,       "all", -1, SCALE, 1.08, 0.15, QUAD_OUT);
        modChart.addEventSimple(beat + 0.3, "all", -1, SCALE, 0.7,  0.25, ELASTIC_OUT);
    }

    // ╔════════════════════════════════════════╗
    // ║  FASE 2 (beat 64-96): SWING LATERAL    ║
    // ║  Player oscila izquierda-derecha        ║
    // ╚════════════════════════════════════════╝

    for (b in 0...8) {
        var beat  = 64 + b * 4;
        var dir   = (b % 2 == 0) ? 1 : -1;
        var dist  = 60 * dir;
        modChart.addEventSimple(beat,       "player", -1, MOVE_X, dist,  1.5, SINE_IN_OUT);
        modChart.addEventSimple(beat + 2.0, "player", -1, MOVE_X, 0,     1.5, SINE_IN_OUT);

        // CPU se balancea al lado contrario
        modChart.addEventSimple(beat,       "cpu",    -1, MOVE_X, -dist * 0.5, 1.5, SINE_IN_OUT);
        modChart.addEventSimple(beat + 2.0, "cpu",    -1, MOVE_X, 0,    1.5, SINE_IN_OUT);
    }

    // ╔════════════════════════════════════════╗
    // ║  FASE 3 (beat 96-128): DROP 8K         ║
    // ║  Secci0n con notas de 8 keys           ║
    // ║  Toda la pantalla palpita              ║
    // ╚════════════════════════════════════════╝

    // Beat 96: resetear posiciones
    modChart.addEventSimple(96, "all", -1, RESET, 0, 0, INSTANT);

    // Caída dramática
    modChart.addEventSimple(96,    "all", -1, MOVE_Y,  -300, 0, INSTANT);
    modChart.addEventSimple(96,    "all", -1, MOVE_Y,   0,   1.0, BOUNCE_OUT);

    // Pulso agresivo cada 2 beats
    for (b in 0...16) {
        var beat = 96 + b * 2;
        modChart.addEventSimple(beat,       "all", -1, SCALE, 1.15, 0.1, QUAD_OUT);
        modChart.addEventSimple(beat + 0.2, "all", -1, SCALE, 0.7,  0.3, QUAD_IN);
    }

    // Spin lento en strums del CPU durante 8 beats
    modChart.addEventSimple(100, "cpu", -1, SPIN,  45, 0, INSTANT);
    modChart.addEventSimple(108, "cpu", -1, SPIN,   0, 0, INSTANT);
    modChart.addEventSimple(108, "cpu", -1, ANGLE,  0, 0.5, ELASTIC_OUT);

    // ╔════════════════════════════════════════╗
    // ║  FASE 4 (beat 128-160): TWIST          ║
    // ║  Strums rotan y se intercambian        ║
    // ╚════════════════════════════════════════╝

    modChart.addEventSimple(128, "all", -1, RESET, 0, 0, INSTANT);

    // Rotación individual de cada strum del player
    for (i in 0...4) {
        var delay = i * 0.3;
        modChart.addEventSimple(128 + delay, "player", i, ANGLE, 360, 2.0, SINE_IN_OUT);
        modChart.addEventSimple(130 + delay, "player", i, ANGLE, 0,   0.5, INSTANT);
    }

    // CPU hace lo mismo pero al revés
    for (i in 0...4) {
        var delay = (3 - i) * 0.3;
        modChart.addEventSimple(128 + delay, "cpu", i, ANGLE, -360, 2.0, SINE_IN_OUT);
        modChart.addEventSimple(130 + delay, "cpu", i, ANGLE,  0,   0.5, INSTANT);
    }

    // Swap de posiciones: player va a la izquierda, cpu a la derecha
    modChart.addEventSimple(132, "player", -1, SET_ABS_X, BASE_CPU_X,    2.0, QUAD_IN_OUT);
    modChart.addEventSimple(132, "cpu",    -1, SET_ABS_X, BASE_PLAYER_X, 2.0, QUAD_IN_OUT);

    // Volver a posición original
    modChart.addEventSimple(140, "player", -1, SET_ABS_X, BASE_PLAYER_X, 2.0, BACK_IN);
    modChart.addEventSimple(140, "cpu",    -1, SET_ABS_X, BASE_CPU_X,    2.0, BACK_IN);

    // Alpha flash durante el swap
    modChart.addEventSimple(132, "all", -1, ALPHA, 0.3, 0.5, QUAD_IN);
    modChart.addEventSimple(133, "all", -1, ALPHA, 1.0, 1.0, QUAD_OUT);

    // ╔════════════════════════════════════════╗
    // ║  FASE 5 (beat 160-192): RAIN OF SPINS  ║
    // ║  Cada strum individual gira           ║
    // ╚════════════════════════════════════════╝

    modChart.addEventSimple(160, "all", -1, RESET, 0, 0, INSTANT);

    // Cada beat, un strum diferente hace 360 + scale punch
    var spinOrder = [0, 3, 1, 2, 3, 0, 2, 1, 0, 1, 2, 3, 2, 1, 3, 0];
    for (i in 0...16) {
        var beat  = 160 + i;
        var sIdx  = spinOrder[i];
        var grp   = (i % 4 < 2) ? "player" : "cpu";
        modChart.addEventSimple(beat,       grp, sIdx, ANGLE, 360, 0.8, QUAD_IN_OUT);
        modChart.addEventSimple(beat + 0.9, grp, sIdx, ANGLE, 0,   0.1, INSTANT);
        modChart.addEventSimple(beat,       grp, sIdx, SCALE, 1.3, 0.2, ELASTIC_OUT);
        modChart.addEventSimple(beat + 0.3, grp, sIdx, SCALE, 0.7, 0.4, QUAD_IN);
    }

    // Ola vertical: strums suben y bajan en cascada
    for (i in 0...4) {
        for (rep in 0...4) {
            var beat = 168 + rep * 2 + i * 0.5;
            modChart.addEventSimple(beat,       "player", i, MOVE_Y, -50, 0.4, SINE_OUT);
            modChart.addEventSimple(beat + 0.5, "player", i, MOVE_Y,   0, 0.5, BOUNCE_OUT);
        }
    }

    // ╔════════════════════════════════════════╗
    // ║  FASE 6 (beat 192-224): CHAOS MODE     ║
    // ║  Movimiento aleatorio pre-calculado    ║
    // ╚════════════════════════════════════════╝

    modChart.addEventSimple(192, "all", -1, RESET, 0, 0, INSTANT);

    // Posiciones "caóticas" pre-calculadas para los 4 strums del player
    var chaosMoves = [
        [-120, 80], [60, -40], [-80, 120], [100, -60],
        [40, -100], [-100, 30], [80, 70], [-60, -90],
        [110, -80], [-30, 110], [-90, -50], [70, 90],
        [-50, -110], [90, 60], [-110, 40], [50, -70]
    ];

    for (i in 0...16) {
        var beat  = 192 + i;
        var sIdx  = i % 4;
        var mx    = chaosMoves[i][0];
        var my    = chaosMoves[i][1];
        var ease  = (i % 3 == 0) ? ELASTIC_OUT : ((i % 3 == 1) ? BOUNCE_OUT : BACK_OUT);
        modChart.addEventSimple(beat, "player", sIdx, MOVE_X, mx, 0.7, ease);
        modChart.addEventSimple(beat, "player", sIdx, MOVE_Y, my, 0.7, ease);
    }

    // CPU gira como un molino
    modChart.addEventSimple(192, "cpu", -1, SPIN, 90, 0, INSTANT);
    modChart.addEventSimple(208, "cpu", -1, SPIN,  0, 0, INSTANT);
    modChart.addEventSimple(208, "cpu", -1, ANGLE, 0, 1.0, ELASTIC_OUT);

    // Parpadeo del CPU
    for (b in 0...8) {
        var beat = 196 + b * 2;
        modChart.addEventSimple(beat,       "cpu", -1, ALPHA, 0.1, 0.2, QUAD_IN);
        modChart.addEventSimple(beat + 0.5, "cpu", -1, ALPHA, 1.0, 0.3, QUAD_OUT);
    }

    // ╔════════════════════════════════════════╗
    // ║  FASE 7 (beat 224-240): CONVERGENCIA   ║
    // ║  Todo se acumula en el centro          ║
    // ╚════════════════════════════════════════╝

    modChart.addEventSimple(224, "all", -1, RESET, 0, 0, INSTANT);

    // Convergencia al centro
    var centerX = SCREEN_W / 2 - BASE_PLAYER_X;
    modChart.addEventSimple(224, "player", -1, MOVE_X, centerX - 380, 3.0, QUAD_IN_OUT);
    modChart.addEventSimple(224, "cpu",    -1, MOVE_X, centerX - 10,  3.0, QUAD_IN_OUT);

    // Y-offset para separar visualmente (player arriba, cpu abajo)
    modChart.addEventSimple(224, "player", -1, MOVE_Y, -80, 2.0, SINE_IN_OUT);
    modChart.addEventSimple(224, "cpu",    -1, MOVE_Y,  80, 2.0, SINE_IN_OUT);

    // Scale up gradual
    modChart.addEventSimple(224, "all", -1, SCALE, 1.3, 4.0, SINE_IN_OUT);

    // Separación dramática en beat 230
    modChart.addEventSimple(230, "player", -1, MOVE_X,   300, 2.0, BACK_OUT);
    modChart.addEventSimple(230, "cpu",    -1, MOVE_X,  -300, 2.0, BACK_OUT);
    modChart.addEventSimple(230, "all",    -1, SCALE, 0.7, 2.0, ELASTIC_OUT);
    modChart.addEventSimple(230, "all",    -1, MOVE_Y, 0, 1.5, BOUNCE_OUT);

    // ╔════════════════════════════════════════╗
    // ║  FASE 8 (beat 240-255): GRAND FINALE   ║
    // ╚════════════════════════════════════════╝

    modChart.addEventSimple(240, "all", -1, RESET, 0, 0, INSTANT);

    // Spin total on both groups
    modChart.addEventSimple(240, "player", -1, SPIN,  120, 0, INSTANT);
    modChart.addEventSimple(240, "cpu",    -1, SPIN, -120, 0, INSTANT);

    // Crecer dramáticamente
    modChart.addEventSimple(240, "all", -1, SCALE, 0.7, 0, INSTANT);
    modChart.addEventSimple(244, "all", -1, SCALE, 1.5, 4.0, SINE_IN_OUT);

    // Ultimo alpha flash
    for (b in 0...6) {
        var beat = 244 + b;
        var a    = b < 3 ? 0.5 : 0.2;
        modChart.addEventSimple(beat,       "all", -1, ALPHA, a,   0.2, QUAD_IN);
        modChart.addEventSimple(beat + 0.4, "all", -1, ALPHA, 1.0, 0.3, QUAD_OUT);
    }

    // Parar spin y reset en los últimos beats
    modChart.addEventSimple(252, "all", -1, SPIN,  0,   0, INSTANT);
    modChart.addEventSimple(252, "all", -1, RESET, 0, 2.0, SINE_IN_OUT);
}

// ─────────────────────────────────────────────────────────────
//  onBeatHit — efectos dinámicos por beat
// ─────────────────────────────────────────────────────────────
function onBeatHit(beat) {
    beatCount = beat;

    // ── Pulso de escala universal (toda la canción) ──────────
    if (beat >= 32) {
        var intense = (beat >= 192) ? 1.12 : ((beat >= 128) ? 1.07 : 1.04);
        modChart.addEventSimple(beat,       "all", -1, SCALE, intense, 0.08, QUAD_OUT);
        modChart.addEventSimple(beat + 0.2, "all", -1, SCALE, 0.7,    0.25, QUAD_IN);
    }

    // ── Kick cada 4 beats (a partir del beat 64) ─────────────
    if (beat >= 64 && beat % 4 == 0) {
        modChart.addEventSimple(beat,       "all", -1, MOVE_Y,  -20, 0.1, QUAD_OUT);
        modChart.addEventSimple(beat + 0.15,"all", -1, MOVE_Y,    0, 0.35, BOUNCE_OUT);
    }

    // ── Strum highlight: el strum "activo" del beat se escala ─
    if (beat >= 64 && beat < 192) {
        var strum = beat % 4;
        modChart.addEventSimple(beat,       "player", strum, SCALE, 1.25, 0.1, ELASTIC_OUT);
        modChart.addEventSimple(beat + 0.3, "player", strum, SCALE, 0.7,  0.3, QUAD_IN);
    }

    // ── Snare visual cada 2 beats (fase intensa) ─────────────
    if (beat >= 128 && beat % 2 == 0) {
        var cpuStrum = (beat / 2) % 4;
        modChart.addEventSimple(beat,       "cpu", Std.int(cpuStrum), ANGLE, 15,  0.1, QUAD_OUT);
        modChart.addEventSimple(beat + 0.2, "cpu", Std.int(cpuStrum), ANGLE, -15, 0.2, SINE_IN_OUT);
        modChart.addEventSimple(beat + 0.4, "cpu", Std.int(cpuStrum), ANGLE,  0,  0.2, ELASTIC_OUT);
    }

    // ── Ola sinusoidal de X en fase caos ─────────────────────
    if (beat >= 192 && beat < 224) {
        for (i in 0...4) {
            var phase = i * 90;
            var offsetX = sin(beat * 45 + phase) * 40;
            modChart.addEventSimple(beat, "player", i, MOVE_X, offsetX, 0.5, SINE_IN_OUT);
        }
    }

    // ── Finale: todo tiembla ─────────────────────────────────
    if (beat >= 244 && beat < 252) {
        for (i in 0...4) {
            var jitter = (beat % 2 == 0) ? 8 : -8;
            modChart.addEventSimple(beat,       "all", i, MOVE_X, jitter,  0.05, INSTANT);
            modChart.addEventSimple(beat + 0.1, "all", i, MOVE_X, -jitter, 0.05, INSTANT);
            modChart.addEventSimple(beat + 0.2, "all", i, MOVE_X, 0,       0.1, QUAD_OUT);
        }
    }
}

// ─────────────────────────────────────────────────────────────
//  onStepHit — efectos más finos por step
// ─────────────────────────────────────────────────────────────
function onStepHit(step) {
    // ── Ola de Y en la sección de 8 keys (step 384-512 = beat 96-128) ──
    if (step >= 384 && step < 512) {
        var strumIdx = step % 4;
        var waveY    = sin(step * 30) * 25;
        modChart.addEventSimple(step / 4.0, "all", strumIdx, MOVE_Y, waveY, 0.2, SINE_IN_OUT);
    }

    // ── Mini-shakes en la fase de spin (step 640-768 = beat 160-192) ──
    if (step >= 640 && step < 768 && step % 3 == 0) {
        var s = (step / 3) % 4;
        modChart.addEventSimple(step / 4.0, "player", Std.int(s), MOVE_Y, -12, 0.1, QUAD_OUT);
        modChart.addEventSimple(step / 4.0 + 0.1, "player", Std.int(s), MOVE_Y, 0, 0.2, BOUNCE_OUT);
    }
}

// ─────────────────────────────────────────────────────────────
//  onUpdate — lógica continua (solo para cosas que DEBEN ser
//  frame-by-frame; mantener ligero para no causar lag)
// ─────────────────────────────────────────────────────────────
function onUpdate(songPosition) {
    // Nada por frame — todo fue pre-calculado en onCreate/onBeatHit
    // Si necesitas efectos sinusoidales continuos, ponlos aquí:
    // (Comentado porque puede causar lag en CPUs lentos)

    // // Breathing effect en fase intro (suave, solo pos Y)
    // if (songPosition >= 12800 && songPosition < 51200) {
    //     var t = songPosition / 1000.0;
    //     modChart.addEventSimple(t * (150/60.0), "player", -1, MOVE_Y, sin(t * 180) * 5, 0.1, SINE_IN_OUT);
    // }
}
