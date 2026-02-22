/**
 * AltAnim.hx
 * Evento: "Alt Anim" / "Alt Idle Animation"
 *
 * v1 = target  →  "bf" / "dad" / "gf"  (vacío = bf por defecto)
 * v2 = estado  →  "true" / "1"  activa modo alt
 *                 "false" / "0" desactiva
 *
 * Cuando está activo, el personaje usa animaciones con sufijo "-alt"
 * (ej: "singLEFT-alt") si existen, o sigue con las normales.
 *
 * Colocar en: assets/data/scripts/events/
 *         o   assets/songs/{song}/events/
 */

// Mapa de qué personajes tienen el modo alt activo
var altAnimStates = {};   // { 'bf': false, 'dad': false, 'gf': false }

function onCreate()
{
    altAnimStates = { bf: false, dad: false, gf: false };
}

// Callback lanzado por EventManager cuando llega un evento "Alt Anim"
function onAltAnim(target, value)
{
    var tgt    = (target == null || target == '') ? 'bf' : target.toLowerCase();
    var enable = (value.toLowerCase() != 'false' && value != '0');

    // Guardamos el estado para que sing() lo consulte
    if      (tgt == 'bf'  || tgt == 'boyfriend' || tgt == 'player')   altAnimStates.bf  = enable;
    else if (tgt == 'dad' || tgt == 'opponent')                        altAnimStates.dad = enable;
    else if (tgt == 'gf'  || tgt == 'girlfriend')                      altAnimStates.gf  = enable;

    trace('AltAnim: ' + tgt + ' → ' + enable);
}

// Interceptamos las animaciones de canto para añadir el sufijo "-alt" si toca
function onSingAnim(char, animName, force)
{
    if (char == null) return null;   // null = no modificar

    var slot = '';
    if      (game != null && char == game.boyfriend) slot = 'bf';
    else if (game != null && char == game.dad)        slot = 'dad';
    else if (game != null && char == game.gf)         slot = 'gf';

    if (slot == '') return null;

    var isAlt = (slot == 'bf'  && altAnimStates.bf)
             || (slot == 'dad' && altAnimStates.dad)
             || (slot == 'gf'  && altAnimStates.gf);

    if (!isAlt) return null;   // sin cambios

    var altName = animName + '-alt';
    // Solo usamos el sufijo si la animación alt realmente existe
    if (char.animOffsets.exists(altName))
        return altName;        // devolver un string reemplaza el animName original

    return null;
}
