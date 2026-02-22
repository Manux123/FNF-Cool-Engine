/**
 * HudVisible.hx
 * Evento: "HUD Visible" / "Toggle HUD"
 *
 * v1 = "true" / "1"   →  muestra el HUD
 *      "false" / "0"  →  oculta el HUD
 *
 * El evento built-in ya hace game.uiManager.visible = ..., pero este
 * script añade un tween de fade para que no sea un corte brusco.
 *
 * Si prefieres el corte instantáneo del built-in, borra la función
 * onEvent y usa el evento tal cual desde el chart sin ningún script.
 *
 * Colocar en: assets/songs/{song}/events/
 *         o   assets/data/scripts/events/   (para todas las canciones)
 */

var HUD_FADE_TIME = 0.35;   // segundos del fade

function onEvent(name, v1, v2, time)
{
    if (name != 'HUD Visible' && name != 'Toggle HUD') return null;

    if (game == null || game.uiManager == null) return null;

    var show = (v1.toLowerCase() != 'false' && v1 != '0');

    // Fade con FlxTween en lugar de visibilidad instantánea
    FlxTween.tween(game.uiManager, { alpha: show ? 1.0 : 0.0 }, HUD_FADE_TIME, {
        ease: FlxEase.quartOut,
        onComplete: function(t) {
            // Solo ocultamos el objeto cuando el fade termina, para evitar
            // que quede "invisible pero aún recibiendo clics / updates"
            game.uiManager.visible = show;
            if (show) game.uiManager.alpha = 1.0;
        }
    });

    // Aseguramos que sea visible durante el fade de aparición
    if (show) game.uiManager.visible = true;

    trace('HudVisible: ' + (show ? 'mostrando' : 'ocultando') + ' HUD');

    return true;   // cancelamos el built-in (nosotros ya lo manejamos)
}
