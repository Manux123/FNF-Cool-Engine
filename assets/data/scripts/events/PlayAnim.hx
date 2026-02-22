/**
 * PlayAnim.hx
 * Evento built-in: "Play Anim" / "Play Animation"
 *
 * Ya está implementado en EventManager._handleBuiltin(), este script
 * muestra cómo EXTENDERLO o SOBREESCRIBIRLO desde HScript si hace falta.
 *
 * ── Uso en el chart ──────────────────────────────────────────────────────────
 *   Nombre del evento : Play Anim
 *   Valor 1           : target    → "bf", "dad", "gf"
 *                                    o  "bf:hey"  (target:anim en un solo campo)
 *   Valor 2           : animación → "hey", "cheer", "scared", "firstDeath", ...
 *
 * ── Ejemplos ─────────────────────────────────────────────────────────────────
 *   v1="bf"   v2="hey"       → bf hace "hey"
 *   v1="dad"  v2="cheer"     → dad hace "cheer"
 *   v1="bf:scared"  v2=""    → bf hace "scared" (formato compacto)
 */

// ── Extensión: añadir una animación extra después de "hey" ───────────────────
//
// Devolver true en onEvent cancela el handler built-in y corre ESTE código.
// Si no quieres cancelarlo, no pongas onEvent (o devuelve null / false).

function onEvent(name, v1, v2, time)
{
    if (name != 'Play Anim') return null;   // dejar pasar todo lo demás

    // Parseo manual del target (igual que el built-in)
    var target = v1;
    var anim   = v2;

    if (v1.indexOf(':') != -1)
    {
        var parts = v1.split(':');
        target = parts[0];
        anim   = parts[1];
    }

    if (game == null || anim == '') return null;

    // Resolvemos el personaje
    var ch = null;
    var tg = target.toLowerCase();
    if      (tg == 'bf'  || tg == 'boyfriend' || tg == 'player')  ch = game.boyfriend;
    else if (tg == 'dad' || tg == 'opponent')                       ch = game.dad;
    else if (tg == 'gf'  || tg == 'girlfriend')                     ch = game.gf;

    if (ch == null) return null;

    ch.playAnim(anim, true);

    return true;   // cancela el built-in (ya lo ejecutamos nosotros)
}
