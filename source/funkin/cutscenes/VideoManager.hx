package funkin.cutscenes;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import funkin.states.LoadingState;

using StringTools;

// ─────────────────────────────────────────────────────────────────────────────
// VideoManager — sistema centralizado de reproducción de video
//
// SKIP: Los videos SOLO se pueden saltear desde PauseSubState → "Skip Cutscene".
//       No hay listeners de teclado aquí. Esto evita el conflicto donde ENTER
//       disparaba el skip Y el menú de pausa al mismo tiempo.
//
// Modos de uso:
//   1. CUTSCENE:   VideoManager.playCutscene('intro', function() { startCountdown(); });
//   2. MID-SONG:   VideoManager.playMidSong('explosion', playState, callback);
//   3. FONDO LOOP: VideoManager.playBackground('menuBG', mySprite);
//   4. EN SPRITE:  VideoManager.playOnSprite('logo', mySprite, callback);
// ─────────────────────────────────────────────────────────────────────────────

class VideoManager
{
	// ── Opciones globales ─────────────────────────────────────────────────────

	/** Si true, se hace un fade a negro de 0.3s antes de llamar el callback. */
	public static var fadeOnComplete:Bool = true;

	// ── Estado interno ────────────────────────────────────────────────────────

	/** Handler VLC activo. `null` si no hay video reproduciendo. */
	public static var current:Null<MP4Handler> = null;

	/** ¿Hay un video reproduciendo ahora mismo? */
	public static var isPlaying(get, never):Bool;
	static function get_isPlaying():Bool return current != null;

	// Callback almacenado para cancelación con stop()
	static var _onComplete:Null<Void->Void> = null;

	// ─────────────────────────────────────────────────────────────────────────
	// API pública
	// ─────────────────────────────────────────────────────────────────────────

	/**
	 * Reproduce un video como cutscene completa (pantalla llena, pausa música).
	 */
	public static function playCutscene(key:String, ?onComplete:Void->Void):Void
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

		// midSong=true: evitamos que playMP4 llame FlxG.sound.music.stop() — stop()
		// deja el FlxSound streaming invalido en CPP. La musica ya fue pausada arriba.
		handler.playMP4(path, true, false, null, false, true);
		handler.finishCallback = _buildFinish();
		#else
		trace('[VideoManager] Video playback not supported on this platform.');
		if (onComplete != null) onComplete();
		#end
	}

	/**
	 * Reproduce un video mid-song: pausa música+vocales, reproduce, luego resume.
	 */
	public static function playMidSong(key:String,
	                                   ?state:funkin.gameplay.PlayState,
	                                   ?onComplete:Void->Void):Void
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
			_buildFinish()();
		};
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

		handler.playMP4(path, true, true, sprite, false, false);
		#else
		trace('[VideoManager] Background video not supported on this platform.');
		#end
	}

	/**
	 * Reproduce un video renderizado dentro de un FlxSprite.
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
		handler.finishCallback = _buildFinish();
		#else
		if (onComplete != null) onComplete();
		#end
	}

	/**
	 * Detiene el video actual (llamado desde PauseSubState "Skip Cutscene").
	 * Llama al callback del video si existe.
	 */
	public static function stop():Void
	{
		if (current == null) return;
		current.kill();
		_cleanup();
	}

	/**
	 * Pausa el video activo y lo oculta.
	 * Llamado al abrir el menú de pausa para que quede visible encima del video.
	 */
	public static function pause():Void
	{
		if (current == null) return;
		current.pause();
	}

	/**
	 * Reanuda el video activo y lo muestra de nuevo.
	 * Llamado al cerrar el menú de pausa.
	 */
	public static function resume():Void
	{
		if (current == null) return;
		current.resume();
	}

	/**
	 * Detiene el video SIN llamar al callback (para limpiar al salir de un state).
	 */
	public static function stopSilent():Void
	{
		if (current == null) return;
		_onComplete = null;
		current.finishCallback = null;
		current.kill();
		current = null;
	}

	// ─────────────────────────────────────────────────────────────────────────
	// Helpers internos
	// ─────────────────────────────────────────────────────────────────────────

	/**
	 * Resuelve la ruta del video buscando en el mod activo primero, luego en assets.
	 * Devuelve null si no existe.
	 */
	public static function _resolvePath(key:String):Null<String>
	{
		final k = key.endsWith('.mp4') ? key.substr(0, key.length - 4) : key;

		final candidates:Array<String> = [];

		final mod = mods.ModManager.activeMod;
		if (mod != null)
		{
			final base = '${mods.ModManager.MODS_FOLDER}/$mod';
			candidates.push('$base/videos/$k.mp4');
			candidates.push('$base/cutscenes/videos/$k.mp4');
			candidates.push('$base/songs/${funkin.gameplay.PlayState.SONG?.song?.toLowerCase() ?? ""}/$k.mp4');
		}

		candidates.push('assets/videos/$k.mp4');
		candidates.push('assets/cutscenes/videos/$k.mp4');

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
		_onComplete = null;
		current.finishCallback = null;
		current.kill();
		current = null;
	}

	/** Construye la función de finalización. */
	static function _buildFinish():Void->Void
	{
		return function()
		{
			final cb = _onComplete;
			_cleanup();

			if (cb != null) cb();
		};
	}

	/** Limpia el estado interno. */
	static function _cleanup():Void
	{
		current     = null;
		_onComplete = null;
	}
}
