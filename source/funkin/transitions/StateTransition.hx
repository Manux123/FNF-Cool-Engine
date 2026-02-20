package funkin.transitions;

import flixel.FlxG;
import flixel.FlxState;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import openfl.display.Sprite;
import openfl.display.Shape;
import openfl.geom.Matrix;

using StringTools;

/**
	* StateTransition — Smooth, scriptable transitions between FlxStates.
	*
	* ─── Features ─────────────────────────────────────────────────────────
	* • Does not interfere with StickerTransition (uses a separate OpenFL layer, lower z-slot).

	* • Configurable via a switch or globally from HScript scripts.

	* • Types: FADE, FADE_WHITE, SLIDE_LEFT, SLIDE_RIGHT, SLIDE_UP, SLIDE_DOWN,

	* CIRCLE_WIPE, NONE, CUSTOM.

	* Fluent API: switchState() + setNext() + setGlobal().

	* The "intro" (discovery) is automatically triggered in MusicBeatState.create().
	* 
	* ─── Use in HScript ──────────────────────────── ───────────────────────────── 
	* StateTransition.setNext("slide_left", 0.4); // next switch 
	* StateTransition.switchState(new MainMenuState()); // switch + transition

	*
	* StateTransition.setGlobal("fade", 0.35, 0xFF000000); // all transitions

	* StateTransition.setCustomIn(function() { ... }); // custom entrance animation

	* StateTransition.setCustomOut(function(done) { done(); }); // custom exit
*/

class StateTransition
{
	// ─── Config global ────────────────────────────────────────────────────────
	public static var globalType:TransitionType = FADE;
	public static var globalDuration:Float = 0.35;
	public static var globalColor:Int = 0xFF000000;
	public static var globalEaseIn:EaseFunction = null; // null = cubeInOut
	public static var globalEaseOut:EaseFunction = null;

	/** Si false, no se hace ninguna transición (útil para debug). */
	public static var enabled:Bool = true;

	// ─── Override para el PRÓXIMO switch (se consume una vez) ─────────────────
	private static var _nextType:Null<TransitionType> = null;
	private static var _nextDuration:Null<Float> = null;
	private static var _nextColor:Null<Int> = null;
	private static var _nextEaseIn:Null<EaseFunction> = null;
	private static var _nextEaseOut:Null<EaseFunction> = null;

	// ─── Custom callbacks (scripts) ───────────────────────────────────────────

	/** Función de salida custom: recibe callback `done` que debe llamarse al terminar. */
	public static var customOut:Null<(Void->Void)->Void> = null;

	/** Función de entrada custom: se llama cuando el nuevo estado ya está creado. */
	public static var customIn:Null<Void->Void> = null;

	// ─── Estado interno ───────────────────────────────────────────────────────
	private static var _overlay:TransitionOverlay = null;
	private static var _pendingIntro:Bool = false;
	private static var _pendingType:TransitionType = FADE;
	private static var _pendingDuration:Float = 0.35;
	private static var _pendingColor:Int = 0xFF000000;
	private static var _pendingEaseIn:EaseFunction = null;
	private static var _pendingEaseOut:EaseFunction = null;

	private static var _active:Bool = false;

	// ═════════════════════════════════════════════════════════════════════════
	//  API PÚBLICA
	// ═════════════════════════════════════════════════════════════════════════

	/**
	 * Configura la transición para el PRÓXIMO switchState solamente.
	 * Se descarta tras usarse (no afecta transiciones posteriores).
	 *
	 * @param type     Tipo de transición (String o TransitionType)
	 * @param duration Duración total en segundos
	 * @param color    Color del overlay (ARGB)
	 */
	public static function setNext(?type:Dynamic, ?duration:Float, ?color:Int, ?easeIn:EaseFunction, ?easeOut:EaseFunction):Void
	{
		_nextType = type != null ? parseType(type) : null;
		_nextDuration = duration != null ? duration : null;
		_nextColor = color != null ? color : null;
		_nextEaseIn = easeIn;
		_nextEaseOut = easeOut;
	}

	/**
	 * Cambia la configuración global (afecta todos los switches siguientes).
	 */
	public static function setGlobal(?type:Dynamic, ?duration:Float, ?color:Int, ?easeIn:EaseFunction, ?easeOut:EaseFunction):Void
	{
		if (type != null)
			globalType = parseType(type);
		if (duration != null)
			globalDuration = duration;
		if (color != null)
			globalColor = color;
		if (easeIn != null)
			globalEaseIn = easeIn;
		if (easeOut != null)
			globalEaseOut = easeOut;
	}

	/**
	 * Registra una función de salida custom para el próximo switch.
	 * La función recibe un callback `done:Void->Void` que DEBE llamarse
	 * cuando la animación de salida termina.
	 *
	 * Ejemplo HScript:
	 *   StateTransition.setCustomOut(function(done) {
	 *     FlxTween.tween(mySprite, {alpha: 0}, 0.4, {onComplete: function(_) done()});
	 *   });
	 */
	public static function setCustomOut(fn:(Void->Void)->Void):Void
	{
		customOut = fn;
		_nextType = CUSTOM;
	}

	/** Registra una función de entrada custom (se llama en el nuevo state). */
	public static function setCustomIn(fn:Void->Void):Void
	{
		customIn = fn;
	}

	/**
	 * Hace un switchState con transición suave.
	 * Compatible con StickerTransition: si los stickers están activos,
	 * simplemente hace el switch sin overlay para no pelear con ellos.
	 */
	public static function switchState(target:FlxState, ?type:Dynamic, ?duration:Float, ?color:Int):Void
	{
		if (type != null || duration != null || color != null)
			setNext(type, duration, color);

		// Si StickerTransition está corriendo, no meter un overlay encima.
		if (StickerTransition.isActive())
		{
			_consumeNext(); // descartar override sin usar
			FlxG.switchState(target);
			return;
		}

		if (!enabled)
		{
			_consumeNext();
			FlxG.switchState(target);
			return;
		}

		_performSwitch(target);
	}

	/**
	 * Llamado automáticamente por MusicBeatState.create() para reproducir
	 * la animación de entrada ("intro") en el nuevo state.
	 * No llamar manualmente salvo en estados custom que no extiendan MusicBeatState.
	 */
	public static function onStateCreated():Void
	{
		if (!_pendingIntro)
			return;

		_pendingIntro = false;

		if (_overlay == null || !_overlay.visible)
			return;

		var easeIn = _pendingEaseIn ?? globalEaseIn ?? FlxEase.cubeInOut;
		var halfDur = _pendingDuration * 0.5;

		if (_pendingType == CUSTOM && customIn != null)
		{
			// Esconder overlay primero, luego correr custom
			_overlay.hideInstant();
			_overlay.detach();
			customIn();
			customIn = null;
			return;
		}

		// Animar salida del overlay (revelar nuevo state)
		_overlay.animateOut(_pendingType, halfDur, easeIn, function()
		{
			_overlay.detach();
			_active = false;
		});
	}

	/** Devuelve true si hay una transición en curso. */
	public static inline function isActive():Bool
		return _active;

	/** Resetea todos los overrides y callbacks custom. */
	public static function reset():Void
	{
		_consumeNext();
		customOut = null;
		customIn = null;
	}

	// ═════════════════════════════════════════════════════════════════════════
	//  INTERNOS
	// ═════════════════════════════════════════════════════════════════════════

	static function _performSwitch(target:FlxState):Void
	{
		// Resolver parámetros (override de próximo switch > global)
		var type = _nextType ?? globalType;
		var duration = _nextDuration ?? globalDuration;
		var color = _nextColor ?? globalColor;
		var easeOut = _nextEaseOut ?? globalEaseOut ?? FlxEase.cubeInOut;
		var easeIn = _nextEaseIn ?? globalEaseIn ?? FlxEase.cubeInOut;
		_consumeNext();

		// Guardar parámetros para el intro del nuevo state
		_pendingType = type;
		_pendingDuration = duration;
		_pendingColor = color;
		_pendingEaseIn = easeIn;
		_pendingEaseOut = easeOut;
		_pendingIntro = true;
		_active = true;

		if (type == NONE)
		{
			_pendingIntro = false;
			_active = false;
			FlxG.switchState(target);
			return;
		}

		// Crear overlay si no existe
		_ensureOverlay();

		var halfDur = duration * 0.5;

		if (type == CUSTOM && customOut != null)
		{
			customOut(function()
			{
				FlxG.switchState(target);
				customOut = null;
			});
			return;
		}

		// Animación de "salida" (cubrir pantalla)
		_overlay.setup(type, color);
		_overlay.attach();
		_overlay.animateOut_reverse(type, halfDur, easeOut, function()
		{
			// Pantalla cubierta — cambiar state
			FlxG.switchState(target);
			// El intro se dispara en MusicBeatState.create()
		});
	}

	static function _ensureOverlay():Void
	{
		if (_overlay == null)
			_overlay = new TransitionOverlay();
	}

	static function _consumeNext():Void
	{
		_nextType = null;
		_nextDuration = null;
		_nextColor = null;
		_nextEaseIn = null;
		_nextEaseOut = null;
	}

	/** Parsea un tipo desde String o TransitionType. */
	static function parseType(v:Dynamic):TransitionType
	{
		if (Std.isOfType(v, String))
		{
			return switch (Std.string(v).toLowerCase().replace('-', '_'))
			{
				case 'fade': FADE;
				case 'fade_white': FADE_WHITE;
				case 'slide_left': SLIDE_LEFT;
				case 'slide_right': SLIDE_RIGHT;
				case 'slide_up': SLIDE_UP;
				case 'slide_down': SLIDE_DOWN;
				case 'circle_wipe': CIRCLE_WIPE;
				case 'none': NONE;
				case 'custom': CUSTOM;
				default: FADE;
			};
		}
		return cast v;
	}
}

// ═════════════════════════════════════════════════════════════════════════════
//  TransitionOverlay — capa OpenFL que dibuja el efecto
// ═════════════════════════════════════════════════════════════════════════════

/**
 * Sprite OpenFL que dibuja el overlay de transición.
 * Z-order: debajo de StickerTransition (que usa 9999), aquí usamos 9998.
 */
class TransitionOverlay extends Sprite
{
	private var _shape:Shape;
	private var _activeTween:FlxTween = null;

	private var _color:Int;
	private var _type:TransitionType;

	public function new()
	{
		super();
		_shape = new Shape();
		addChild(_shape);
		visible = false;
	}

	// ── Setup ─────────────────────────────────────────────────────────────────

	public function setup(type:TransitionType, color:Int):Void
	{
		_type = type;
		_color = color;
		_redraw(type, 0.0);
		alpha = 0;
		visible = true;
	}

	/** Inserta en OpenFL debajo de stickers. */
	public function attach():Void
	{
		// Usar 9998 para estar debajo de StickerTransition (9999)
		FlxG.addChildBelowMouse(this, 9998);
		_resize();
	}

	public function detach():Void
	{
		if (_activeTween != null)
		{
			_activeTween.cancel();
			_activeTween = null;
		}
		FlxG.removeChild(this);
		visible = false;
		alpha = 0;
	}

	public function hideInstant():Void
	{
		alpha = 0;
		visible = false;
	}

	// ── Animaciones ───────────────────────────────────────────────────────────

	/**
	 * Anima cubriendo la pantalla (para la SALIDA del state actual).
	 * Al terminar llama `onDone`.
	 */
	public function animateOut_reverse(type:TransitionType, duration:Float, ease:EaseFunction, onDone:Void->Void):Void
	{
		_cancelTween();

		switch (type)
		{
			case FADE, FADE_WHITE:
				alpha = 0;
				_activeTween = FlxTween.num(0, 1, duration, {
					ease: ease,
					onComplete: function(_)
					{
						alpha = 1;
						onDone();
					}
				}, function(v:Float)
				{
					alpha = v;
				});

			case SLIDE_LEFT:
				x = -_gw();
				alpha = 1;
				_activeTween = FlxTween.num(-_gw(), 0, duration, {
					ease: ease,
					onComplete: function(_)
					{
						x = 0;
						onDone();
					}
				}, function(v:Float)
				{
					x = v;
				});

			case SLIDE_RIGHT:
				x = _gw();
				alpha = 1;
				_activeTween = FlxTween.num(_gw(), 0, duration, {
					ease: ease,
					onComplete: function(_)
					{
						x = 0;
						onDone();
					}
				}, function(v:Float)
				{
					x = v;
				});

			case SLIDE_UP:
				y = -_gh();
				alpha = 1;
				_activeTween = FlxTween.num(-_gh(), 0, duration, {
					ease: ease,
					onComplete: function(_)
					{
						y = 0;
						onDone();
					}
				}, function(v:Float)
				{
					y = v;
				});

			case SLIDE_DOWN:
				y = _gh();
				alpha = 1;
				_activeTween = FlxTween.num(_gh(), 0, duration, {
					ease: ease,
					onComplete: function(_)
					{
						y = 0;
						onDone();
					}
				}, function(v:Float)
				{
					y = v;
				});

			case CIRCLE_WIPE:
				alpha = 1;
				_activeTween = FlxTween.num(0, 1, duration, {
					ease: ease,
					onComplete: function(_)
					{
						_redraw(CIRCLE_WIPE, 1);
						onDone();
					}
				}, function(v:Float)
				{
					_redraw(CIRCLE_WIPE, v);
				});

			default:
				// NONE / CUSTOM — no animar
				alpha = 1;
				onDone();
		}
	}

	/**
	 * Anima descubriendo la pantalla (para la ENTRADA del nuevo state).
	 */
	public function animateOut(type:TransitionType, duration:Float, ease:EaseFunction, onDone:Void->Void):Void
	{
		_cancelTween();

		switch (type)
		{
			case FADE, FADE_WHITE:
				alpha = 1;
				_activeTween = FlxTween.num(1, 0, duration, {
					ease: ease,
					onComplete: function(_)
					{
						onDone();
					}
				}, function(v:Float)
				{
					alpha = v;
				});

			case SLIDE_LEFT:
				x = 0;
				alpha = 1;
				_activeTween = FlxTween.num(0, _gw(), duration, {
					ease: ease,
					onComplete: function(_)
					{
						onDone();
					}
				}, function(v:Float)
				{
					x = v;
				});

			case SLIDE_RIGHT:
				x = 0;
				alpha = 1;
				_activeTween = FlxTween.num(0, -_gw(), duration, {
					ease: ease,
					onComplete: function(_)
					{
						onDone();
					}
				}, function(v:Float)
				{
					x = v;
				});

			case SLIDE_UP:
				y = 0;
				alpha = 1;
				_activeTween = FlxTween.num(0, _gh(), duration, {
					ease: ease,
					onComplete: function(_)
					{
						onDone();
					}
				}, function(v:Float)
				{
					y = v;
				});

			case SLIDE_DOWN:
				y = 0;
				alpha = 1;
				_activeTween = FlxTween.num(0, -_gh(), duration, {
					ease: ease,
					onComplete: function(_)
					{
						onDone();
					}
				}, function(v:Float)
				{
					y = v;
				});

			case CIRCLE_WIPE:
				_activeTween = FlxTween.num(1, 0, duration, {
					ease: ease,
					onComplete: function(_)
					{
						_redraw(CIRCLE_WIPE, 0);
						onDone();
					}
				}, function(v:Float)
				{
					_redraw(CIRCLE_WIPE, v);
				});

			default:
				onDone();
		}
	}

	// ── Helpers ───────────────────────────────────────────────────────────────

	private function _cancelTween():Void
	{
		if (_activeTween != null)
		{
			_activeTween.cancel();
			_activeTween = null;
		}
	}

	private function _gw():Float
		return FlxG.width;

	private function _gh():Float
		return FlxG.height;

	private function _resize():Void
	{
		_shape.x = 0;
		_shape.y = 0;
		_redraw(_type, 1.0);
	}

	/**
	 * Redibujar la Shape según el tipo y progreso (0=vacío, 1=lleno).
	 */
	private function _redraw(type:TransitionType, progress:Float):Void
	{
		var gfx = _shape.graphics;
		gfx.clear();

		gfx.beginFill(_color & 0x00FFFFFF, 1);

		switch (type)
		{
			case CIRCLE_WIPE:
				var cx = _gw() * 0.5;
				var cy = _gh() * 0.5;
				var maxR = Math.sqrt(cx * cx + cy * cy) + 10;
				gfx.drawCircle(cx, cy, maxR * progress);
			default:
				gfx.drawRect(0, 0, _gw() + 2, _gh() + 2);
		}

		gfx.endFill();
	}
}

// ═════════════════════════════════════════════════════════════════════════════
//  Tipos
// ═════════════════════════════════════════════════════════════════════════════

enum TransitionType
{
	FADE;
	FADE_WHITE;
	SLIDE_LEFT;
	SLIDE_RIGHT;
	SLIDE_UP;
	SLIDE_DOWN;
	CIRCLE_WIPE;
	NONE;
	CUSTOM;
}

typedef EaseFunction = Float->Float;
