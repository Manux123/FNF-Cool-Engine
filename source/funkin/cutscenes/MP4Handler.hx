package funkin.cutscenes;

import funkin.states.LoadingState;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import openfl.events.Event;

using StringTools;
// ────────────────────────────────────────────────────────────────────────────
// MP4Handler — VLC-backed MP4 playback
//
// NOTA IMPORTANTE: El skip de videos SOLO ocurre desde el menú de pausa
// (PauseSubState → "Skip Cutscene"). No se capturan teclas aquí para
// evitar que ENTER dispare el skip Y el menú de pausa simultáneamente.
// ────────────────────────────────────────────────────────────────────────────

#if (cpp && !mobile)
import vlc.VlcBitmap;

class MP4Handler
{
	public var finishCallback:Void->Void;
	public var stateCallback:FlxState;

	public var bitmap:VlcBitmap;
	public var sprite:FlxSprite;

	// Evita que onVLCComplete se dispare después de kill()
	var _killed:Bool = false;

	public function new() {}

	public function playMP4(path:String, ?midSong:Bool = false, ?repeat:Bool = false,
		?outputTo:FlxSprite = null, ?isWindow:Bool = false, ?isFullscreen:Bool = false):Void
	{
		_killed = false;

		if (!midSong)
		{
			if (FlxG.sound.music != null)
				FlxG.sound.music.stop();
		}

		bitmap = new VlcBitmap();

		var targetRatio:Float = 16 / 9;
		var screenWidth:Float  = FlxG.stage.stageWidth;
		var screenHeight:Float = FlxG.stage.stageHeight;
		var screenRatio:Float  = screenWidth / screenHeight;

		if (screenRatio > targetRatio)
		{
			bitmap.width  = screenHeight * targetRatio;
			bitmap.height = screenHeight;
		}
		else
		{
			bitmap.width  = screenWidth;
			bitmap.height = screenWidth / targetRatio;
		}

		bitmap.x = (screenWidth  - bitmap.width)  / 2;
		bitmap.y = (screenHeight - bitmap.height) / 2;

		bitmap.onVideoReady = onVLCVideoReady;
		bitmap.onComplete   = onVLCComplete;
		bitmap.onError      = onVLCError;

		FlxG.stage.addEventListener(Event.ENTER_FRAME, _update);

		bitmap.repeat     = repeat ? -1 : 0;
		bitmap.inWindow   = isWindow;
		bitmap.fullscreen = isFullscreen;

		FlxG.addChildBelowMouse(bitmap);
		bitmap.play(normalisePath(path));

		if (outputTo != null)
		{
			bitmap.alpha = 0;
			sprite = outputTo;
		}
	}

	function normalisePath(fileName:String):String
	{
		if (fileName.indexOf("file://") != -1 || fileName.indexOf("http") == 0)
			return fileName;

		#if windows
		if (fileName.indexOf(":") != -1)
			return "file:///" + fileName.split("\\").join("/");
		#end

		var cwd = Sys.getCwd().split("\\").join("/");
		if (!cwd.endsWith("/")) cwd += "/";

		#if (mac || linux)
		return "file://" + cwd + fileName;
		#else
		return "file:///" + cwd + fileName;
		#end
	}

	/////////////////////////////////////////////////////////////////////////////////////

	function onVLCVideoReady():Void
	{
		trace("MP4Handler: video loaded!");
		if (sprite != null)
			sprite.loadGraphic(bitmap.bitmapData);
	}

	public function onVLCComplete():Void
	{
		if (_killed) return; // kill() ya lo manejó, no disparar doble

		_killed = true;
		FlxG.stage.removeEventListener(Event.ENTER_FRAME, _update);
		bitmap.stop();

		// 1. Primero sacar el bitmap del stage para que desaparezca visualmente
		_removeBitmapFromStage();

		FlxG.camera.fade(FlxColor.BLACK, 0, false);

		new FlxTimer().start(0.3, function(tmr:FlxTimer)
		{
			// 2. Liberar memoria nativa VLC
			_disposeBitmapObject();

			// 3. Ahora ejecutar el callback (puede cambiar de estado)
			if (finishCallback != null)
			{
				var cb = finishCallback;
				finishCallback = null;
				cb();
			}
			else if (stateCallback != null)
				LoadingState.loadAndSwitchState(stateCallback);
		});
	}

	/**
	 * Para el video inmediatamente y limpia todo.
	 * Llamado por VideoManager.stop() cuando el jugador usa "Skip Cutscene" del menú de pausa.
	 */
	public function kill():Void
	{
		if (_killed) return;
		_killed = true;

		if (bitmap == null) return;

		FlxG.stage.removeEventListener(Event.ENTER_FRAME, _update);
		bitmap.stop();

		// Sacar del stage primero
		_removeBitmapFromStage();

		// Llamar callback antes de liberar memoria
		if (finishCallback != null)
		{
			var cb = finishCallback;
			finishCallback = null;
			cb();
		}

		// Liberar memoria nativa
		_disposeBitmapObject();
	}

	/**
	 * Pausa la reproducción SIN ocultar el bitmap.
	 * Baja el bitmap por debajo del canvas de Flixel (donde renderizan las cámaras)
	 * para que el PauseSubState quede VISIBLE encima del video en pausa.
	 */
	public function pause():Void
	{
		if (bitmap == null) return;
		bitmap.pause();
		// El bitmap fue añadido con FlxG.addChildBelowMouse → está en FlxG.game.
		// Al moverlo al índice 0, el canvas de Flixel queda por encima → PauseSubState visible.
		try { FlxG.game.setChildIndex(bitmap, 0); } catch (_:Dynamic) {}
	}

	/**
	 * Reanuda la reproducción y devuelve el bitmap a la cima del display list
	 * para que el video tape el gameplay de nuevo.
	 */
	public function resume():Void
	{
		if (bitmap == null) return;
		// Devolver a la cima para tapar el canvas de Flixel.
		try { FlxG.game.setChildIndex(bitmap, FlxG.game.numChildren - 1); } catch (_:Dynamic) {}
		bitmap.resume();
	}

	function _removeBitmapFromStage():Void
	{
		if (bitmap == null) return;
		// El bitmap fue añadido con FlxG.addChildBelowMouse → está en FlxG.game, NO en FlxG.stage.
		// FlxG.stage.removeChild() lanza excepción silenciosa porque no es hijo directo.
		// La forma correcta es FlxG.removeChild(), igual que StateTransition.detach().
		try { FlxG.removeChild(bitmap); } catch (_:Dynamic) {}
	}

	function _disposeBitmapObject():Void
	{
		if (bitmap == null) return;
		try { bitmap.dispose(); } catch (_:Dynamic) {}
		bitmap = null;
	}

	function onVLCError():Void
	{
		trace("MP4Handler: VLC error — file not found or codec issue.");
		if (_killed) return;
		_killed = true;

		FlxG.stage.removeEventListener(Event.ENTER_FRAME, _update);
		_removeBitmapFromStage();
		_disposeBitmapObject();

		if (finishCallback != null)
		{
			var cb = finishCallback;
			finishCallback = null;
			cb();
		}
		else if (stateCallback != null)
			LoadingState.loadAndSwitchState(stateCallback);
	}

	function _update(e:Event):Void
	{
		// NO se maneja skip con teclado aquí.
		// El único skip válido es desde PauseSubState → "Skip Cutscene".

		if (bitmap != null)
		{
			bitmap.volume = FlxG.sound.volume + 0.000005;
			if (FlxG.sound.volume <= 0.1)
				bitmap.volume = 0;
		}
	}
}

#else

// ── Stub para plataformas sin soporte (mobile, html5) ────────────────────────
class MP4Handler
{
	public var finishCallback:Void->Void;
	public var stateCallback:flixel.FlxState;
	public var bitmap:Dynamic  = null;
	public var sprite:Dynamic  = null;

	public function new() {}

	public function playMP4(path:String, ?midSong:Bool = false, ?repeat:Bool = false,
		?outputTo:Dynamic = null, ?isWindow:Bool = false, ?isFullscreen:Bool = false):Void
	{
		trace("MP4Handler: no soportado en esta plataforma. Skipping.");
		_skip();
	}

	public function onVLCComplete():Void { _skip(); }
	public function kill():Void         { _skip(); }
	public function pause():Void        {}
	public function resume():Void       {}

	inline function _skip():Void
	{
		if (finishCallback != null)
		{
			var cb = finishCallback;
			finishCallback = null;
			cb();
		}
		else if (stateCallback != null)
			funkin.states.LoadingState.loadAndSwitchState(stateCallback);
	}
}

#end
