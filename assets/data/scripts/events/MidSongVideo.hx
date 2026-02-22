/**
 * MidSongVideo.hx
 * Evento: "Play Video" / "Video"  (con v2 = "true" para mid-song)
 *
 * v1 = key del video  →  busca en assets/videos/{key}.mp4
 * v2 = "true" / "1"   →  mid-song: pausa la canción, reproduce, luego resume
 *      "false" / ""   →  cutscene normal (usa el estado por defecto del engine)
 *
 * El evento "Stop Video" para el video inmediatamente sin callback.
 *
 * ── Qué hace este script que no hace el built-in ─────────────────────────────
 *   • Oculta el HUD durante el video y lo restaura al terminar.
 *   • Hace un flash negro de entrada/salida para transición suave.
 *   • Llama onVideoStart / onVideoEnd en todos los scripts para
 *     que otros scripts puedan reaccionar (ej: mover personajes).
 *
 * Colocar en: assets/songs/{song}/events/
 *         o   assets/data/scripts/events/  (para todas las canciones)
 */

function onEvent(name, v1, v2, time)
{
    // ── Stop Video ────────────────────────────────────────────────────────────
    if (name == 'Stop Video' || name == 'Kill Video')
    {
        VideoManager.stop();
        _restoreHUD();
        return true;
    }

    if (name != 'Play Video' && name != 'Video') return null;
    if (v1 == null || v1 == '') return null;

    var isMidSong = (v2 != null && (v2.toLowerCase() == 'true' || v2 == '1'));

    // Forzamos mid-song si metaData lo indica (comportamiento del built-in)
    if (game != null && game.metaData != null && game.metaData.midSongVideo == true)
        isMidSong = true;

    if (isMidSong)
        _playMidSong(v1);
    else
        _playCutscene(v1);

    return true;   // tomamos el control, cancelamos el built-in
}

// ── Mid-song: pausa gameplay, reproduce video, luego resume ──────────────────
function _playMidSong(key)
{
    if (game == null) return;

    // Notificamos a otros scripts
    EventManager.fireEvent('_onVideoStart', key, 'midsong');

    // Ocultar HUD
    _hideHUD();

    // Flash negro de entrada
    FlxG.camera.flash(0xFF000000, 0.2, false);

    // Pequeño delay para que el flash termine antes de que arranque el video
    FlxTimer.wait(0.15, function() {
        VideoManager.playMidSong(key, game, function() {
            // Flash negro de salida
            FlxG.camera.flash(0xFF000000, 0.2, false);

            FlxTimer.wait(0.15, function() {
                _restoreHUD();
                EventManager.fireEvent('_onVideoEnd', key, 'midsong');
                trace('MidSongVideo: "' + key + '" terminado, gameplay resumido.');
            });
        });
    });

    trace('MidSongVideo: reproduciendo "' + key + '" (mid-song)');
}

// ── Cutscene: entrega el control al VideoManager normal ──────────────────────
function _playCutscene(key)
{
    EventManager.fireEvent('_onVideoStart', key, 'cutscene');
    _hideHUD();

    VideoManager.playCutscene(key, function() {
        _restoreHUD();
        EventManager.fireEvent('_onVideoEnd', key, 'cutscene');
        trace('MidSongVideo: cutscene "' + key + '" terminada.');
    });

    trace('MidSongVideo: reproduciendo "' + key + '" (cutscene)');
}

// ── Helpers HUD ──────────────────────────────────────────────────────────────
function _hideHUD()
{
    if (game != null && game.uiManager != null)
    {
        FlxTween.tween(game.uiManager, { alpha: 0.0 }, 0.15, {
            onComplete: function(t) { game.uiManager.visible = false; }
        });
    }
}

function _restoreHUD()
{
    if (game != null && game.uiManager != null)
    {
        game.uiManager.visible = true;
        FlxTween.tween(game.uiManager, { alpha: 1.0 }, 0.3, {
            ease: FlxEase.quartOut
        });
    }
}
