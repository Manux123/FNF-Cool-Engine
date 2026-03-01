/**
 * PlayAnim.hx
 * Evento built-in: "Play Anim" / "Play Animation"
 *
 * ── Formato del valor ────────────────────────────────────────────────────────
 *   "target:anim"   →  v1 contiene "bf:hey"  (campo único, formato compacto)
 *   v1=target  v2=anim  →  campo target y campo animación separados
 *
 * ── Targets soportados ───────────────────────────────────────────────────────
 *   "bf" / "boyfriend" / "player" / "player1"   → Boyfriend
 *   "dad" / "opponent" / "player2"               → Dad
 *   "gf" / "girlfriend" / "player3"              → Girlfriend
 *   "0" / "1" / "2"  (índice de slot)            → Slot directo
 *   Nombre exacto del personaje: "bf-pixel-enemy", "pico", etc.
 *
 * ── Ejemplos ─────────────────────────────────────────────────────────────────
 *   v1="bf:hey"                → bf hace "hey"
 *   v1="dad" v2="cheer"        → dad hace "cheer"
 *   v1="bf-pixel-enemy:singUP" → el personaje pixel hace singUP
 *   v1="gf" v2="sad"           → gf hace "sad"
 *   v1="0:scared"              → slot 0 (GF) hace "scared"
 */

function onEvent(name, v1, v2, time)
{
    if (name != 'Play Anim' && name != 'play anim' && name != 'play animation')
        return null;  // dejar pasar todo lo demás

    // ── Parseo del target y animación ─────────────────────────────────────
    var target = v1 != null ? v1 : '';
    var anim   = v2 != null ? v2 : '';

    // Soporte para formato compacto "target:anim" en v1
    if (target.indexOf(':') != -1)
    {
        var parts = target.split(':');
        target = parts[0].trim();
        if (anim == '' && parts.length > 1)
            anim = parts[1].trim();
    }

    if (game == null)
    {
        trace('[PlayAnim] ERROR: game es null');
        return null;
    }

    if (anim == '')
    {
        trace('[PlayAnim] ERROR: nombre de animación vacío (target="${target}")');
        return null;
    }

    // ── Resolver personaje con el nuevo helper de PlayState ───────────────
    // game.getCharacterByName soporta: alias, índice de slot, nombre exacto
    var ch = game.getCharacterByName(target);

    if (ch == null)
    {
        trace('[PlayAnim] ERROR: no se encontró el personaje "${target}"');
        return null;
    }

    // ── Reproducir la animación ───────────────────────────────────────────
    // force=true para interrumpir la animación actual
    if (!ch.animation.exists(anim))
    {
        trace('[PlayAnim] WARN: el personaje "${ch.curCharacter}" no tiene la anim "${anim}"');
        // No devolver null — intentar reproducirla de todas formas
        // (algunos personajes la tienen registrada con otro nombre)
    }

    ch.playAnim(anim, true);
    trace('[PlayAnim] ${ch.curCharacter} → "${anim}" ✓');

    return true;  // cancela el handler built-in (ya lo ejecutamos nosotros)
}
