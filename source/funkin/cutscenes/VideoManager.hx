package funkin.cutscenes;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import openfl.events.Event;
import funkin.states.LoadingState;

using StringTools;

// ─────────────────────────────────────────────────────────────────────────────
// VideoManager
// ─────────────────────────────────────────────────────────────────────────────
// Sistema centralizado de reproducción de video.
//
// Modos de uso:
//
//   1. CUTSCENE COMPLETA  (toma toda la pantalla, hace fade cuando termina)
//      VideoManager.playCutscene('intro', function() { startCountdown(); });
//
//   2. MID-SONG          (pausa música, reproduce video, reanuda)
//      VideoManager.playMidSong('explosion', playState, function() { resumeGame(); });
//
//   3. FONDO (loop)      (video en loop como background de un state)
//      VideoManager.playBackground('menuBG', mySprite);
//
//   4. EN SPRITE         (render de video dentro de un FlxSprite)
//      VideoManager.playOnSprite('logo', mySprite);
//
// ── Rutas de búsqueda ────────────────────────────────────────────────────────
//   mods/{activeMod}/videos/{key}.mp4
//   mods/{activeMod}/cutscenes/videos/{key}.mp4
//   assets/videos/{key}.mp4                       ← alias rápido
//   assets/cutscenes/videos/{key}.mp4             ← ruta canónica
//
// ── Skip ─────────────────────────────────────────────────────────────────────
//   Por defecto: ENTER o SPACE saltan el video.
//   VideoManager.skippable = false  lo deshabilita.
// ─────────────────────────────────────────────────────────────────────────────

class VideoManager
{
	// ── Opciones globales ─────────────────────────────────────────────────────
	/** Si true, ENTER/SPACE saltan cualquier video. */
	public static var skippable:Bool = true;

	/** Si true, se hace un fade a negro de 0.3s antes de llamar el callback. */
	public static var fadeOnComplete:Bool = true;

	// ── Estado interno ────────────────────────────────────────────────────────
	/** Handler VLC activo. `null` si no hay video reproduciendo. */
	public static var current:Null<MP4Handler> = null;

	/** ¿Hay un video reproduciendo ahora mismo? */
	public static var isPlaying(get, never):Bool;
	static function get_isPlaying():Bool return current != null;

	// Callback almacenado para poder cancelarlo con stop()
	static var _onComplete:Null<Void->Void> = null;
	// Listener de teclado para skip
	static var _skipListener:Null<Event->Void> = null;

	// ─────────────────────────────────────────────────────────────────────────
	// API pública
	// ─────────────────────────────────────────────────────────────────────────

	/**
	 * Reproduce un video como cutscene completa (pantalla llena, pausa música).
	 *
	 * @param key           Nombre del archivo sin extensión (ej: "intro").
	 * @param onComplete    Callback al terminar (o saltar). Puede ser null.
	 * @param skipAllowed   Sobreescribe `skippable` para este video en concreto.
	 */
	public static function playCutscene(key:String, ?onComplete:Void->Void, ?skipAllowed:Bool):Void
	{
		final path = _resolvePath(key);
		if (path == null)
		{
			trace('[VideoManager] playCutscene: "$key" not found — skipping.');
			if (onComplete != null) onComplete();
			return;
		}

		_stopCurrent();
		_onComplete = onComplete;

		// Pausar música del juego
		if (FlxG.sound.music != null && FlxG.sound.music.playing)
			FlxG.sound.music.pause();

		#if (cpp && !mobile)
		final handler = new MP4Handler();
		current = handler;

		handler.playMP4(path, false, false, null, false, true);
		handler.finishCallback = _buildFinish(false);

		_installSkip(skipAllowed ?? skippable);
		#else
		trace('[VideoManager] Video playback not supported on this platform.');
		if (onComplete != null) onComplete();
		#end
	}

	/**
	 * Reproduce un video mid-song: pausa música+vocales, reproduce, luego resume.
	 * Ideal para cutscenes durante gameplay activadas por evento de chart.
	 *
	 * @param key         Nombre del video.
	 * @param state       PlayState (para pausar/resumir música+vocales).
	 * @param onComplete  Callback cuando el video termina.
	 * @param skipAllowed Si false, no se puede saltear.
	 */
	public static function playMidSong(key:String,
	                                   ?state:funkin.gameplay.PlayState,
	                                   ?onComplete:Void->Void,
	                                   ?skipAllowed:Bool):Void
	{
		final path = _resolvePath(key);
		if (path == null)
		{
			trace('[VideoManager] playMidSong: "$key" not found — skipping.');
			if (onComplete != null) onComplete();
			return;
		}

		_stopCurrent();
		_onComplete = onComplete;

		// Pausar gameplay
		if (state != null)
		{
			state.paused     = true;
			state.canPause   = false;
			state.inCutscene = true;
		}

		if (FlxG.sound.music != null) FlxG.sound.music.pause();

		#if (cpp && !mobile)
		final handler = new MP4Handler();
		current = handler;

		// mid-song = no detiene música (ya la pausamos nosotros)
		handler.playMP4(path, true, false, null, false, true);
		handler.finishCallback = function()
		{
			// Reanudar gameplay
			if (state != null)
			{
				state.paused     = false;
				state.canPause   = true;
				state.inCutscene = false;
			}
			_buildFinish(false)();
		};

		_installSkip(skipAllowed ?? skippable);
		#else
		if (state != null)
		{
			state.paused     = false;
			state.canPause   = true;
			state.inCutscene = false;
		}
		if (onComplete != null) onComplete();
		#end
	}

	/**
	 * Reproduce un video en loop dentro de un FlxSprite (fondo animado).
	 * No bloquea el juego — el sprite sigue siendo un sprite normal de Flixel.
	 *
	 * @param key     Nombre del video.
	 * @param sprite  Sprite que recibirá el bitmap del video.
	 */
	public static function playBackground(key:String, sprite:FlxSprite):Void
	{
		final path = _resolvePath(key);
		if (path == null)
		{
			trace('[VideoManager] playBackground: "$key" not found.');
			return;
		}

		#if (cpp && !mobile)
		_stopCurrent();

		final handler = new MP4Handler();
		current = handler;

		// repeat=-1 → loop infinito, sin fullscreen, sin bloqueo
		handler.playMP4(path, true, true, sprite, false, false);
		// Sin finishCallback — el loop no termina hasta que se llame stop()
		#else
		trace('[VideoManager] Background video not supported on this platform.');
		#end
	}

	/**
	 * Reproduce un video renderizado dentro de un FlxSprite (sin loop, sin bloqueo).
	 * Útil para pantallas de título, logos animados, etc.
	 *
	 * @param key        Nombre del video.
	 * @param sprite     Sprite destino.
	 * @param onComplete Callback al terminar.
	 */
	public static function playOnSprite(key:String, sprite:FlxSprite, ?onComplete:Void->Void):Void
	{
		final path = _resolvePath(key);
		if (path == null)
		{
			trace('[VideoManager] playOnSprite: "$key" not found.');
			if (onComplete != null) onComplete();
			return;
		}

		#if (cpp && !mobile)
		_stopCurrent();
		_onComplete = onComplete;

		final handler = new MP4Handler();
		current = handler;

		handler.playMP4(path, true, false, sprite, false, false);
		handler.finishCallback = _buildFinish(false);
		#else
		if (onComplete != null) onComplete();
		#end
	}

	/**
	 * Detiene el video actual inmediatamente y llama al callback si existe.
	 */
	public static function stop():Void
	{
		if (current == null) return;
		_removeSkipListener();
		current.kill();
		_cleanup();
	}

	/**
	 * Detiene el video SIN llamar al callback (para limpiar al salir de un state).
	 */
	public static function stopSilent():Void
	{
		if (current == null) return;
		_removeSkipListener();
		_onComplete = null;
		current.kill();
		current = null;
	}

	// ─────────────────────────────────────────────────────────────────────────
	// Helpers internos
	// ─────────────────────────────────────────────────────────────────────────

	/**
	 * Resuelve la ruta del video buscando en el mod activo primero,
	 * luego en assets. Devuelve null si no existe.
	 */
	public static function _resolvePath(key:String):Null<String>
	{
		// Normalizar: quitar .mp4 si ya lo lleva
		final k = key.endsWith('.mp4') ? key.substr(0, key.length - 4) : key;

		// Candidatos en orden de prioridad
		final candidates:Array<String> = [];

		// 1. Mod activo
		final mod = mods.ModManager.activeMod;
		if (mod != null)
		{
			final base = '${mods.ModManager.MODS_FOLDER}/$mod';
			candidates.push('$base/videos/$k.mp4');
			candidates.push('$base/cutscenes/videos/$k.mp4');
			candidates.push('$base/songs/${funkin.gameplay.PlayState.SONG?.song?.toLowerCase() ?? ""}/$k.mp4');
		}

		// 2. Assets base
		candidates.push('assets/videos/$k.mp4');
		candidates.push('assets/cutscenes/videos/$k.mp4');

		// 3. Path relativo a la canción actual (si PlayState está activo)
		final songName = funkin.gameplay.PlayState.SONG?.song?.toLowerCase();
		if (songName != null)
			candidates.push('assets/songs/$songName/$k.mp4');

		#if sys
		for (c in candidates)
			if (sys.FileSystem.exists(c)) return c;
		#else
		for (c in candidates)
			if (openfl.utils.Assets.exists(c)) return c;
		#end

		return null;
	}

	/** Para el handler actual sin llamar callbacks. */
	static function _stopCurrent():Void
	{
		if (current == null) return;
		_removeSkipListener();
		_onComplete = null;
		current.kill();
		current = null;
	}

	/** Construye la función de finalización con fade opcional. */
	static function _buildFinish(doFade:Bool):Void->Void
	{
		return function()
		{
			_removeSkipListener();
			final cb = _onComplete;
			_cleanup();

			if (doFade && fadeOnComplete)
			{
				FlxG.camera.fade(FlxColor.BLACK, 0.3, false, function()
				{
					if (cb != null) cb();
				});
			}
			else
			{
				if (cb != null) cb();
			}
		};
	}

	/** Limpia el estado interno sin tocar el handler (el handler se limpió solo). */
	static function _cleanup():Void
	{
		current     = null;
		_onComplete = null;
	}

	/** Instala el listener de teclado para skip. */
	static function _installSkip(allowed:Bool):Void
	{
		if (!allowed) return;
		_removeSkipListener(); // no duplicar

		_skipListener = function(e:Event)
		{
			if (FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE
			 || FlxG.keys.justPressed.ESCAPE)
			{
				if (current != null)
					current.onVLCComplete();
			}
		};
		FlxG.stage.addEventListener(Event.ENTER_FRAME, _skipListener);
	}

	/** Elimina el listener de skip si existe. */
	static function _removeSkipListener():Void
	{
		if (_skipListener == null) return;
		try { FlxG.stage.removeEventListener(Event.ENTER_FRAME, _skipListener); }
		catch (_:Dynamic) {}
		_skipListener = null;
	}
}
