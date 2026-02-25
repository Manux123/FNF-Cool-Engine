package funkin.scripting;

import flixel.FlxG;
import flixel.FlxSprite;
import shaders.ShaderManager;
import funkin.transitions.StateTransition;
import funkin.transitions.StateTransition.TransitionType;
import funkin.transitions.StickerTransition;
import funkin.system.WindowManager;
import lime.app.Application;
#if HSCRIPT_ALLOWED
import hscript.Interp;
#end

using StringTools;

/**
 * ScriptAPI — API global expuesta a todos los scripts HScript.
 *
 * ─── Categorías (v2) ─────────────────────────────────────────────────────────
 *   • Flixel core          — FlxG, FlxSprite, FlxText, FlxCamera, etc.
 *   • Tweens / timers      — FlxTween, FlxEase, FlxTimer
 *   • Color helpers        — FlxColor (abstract → objeto con helpers)
 *   • Gameplay             — PlayState, Conductor, EventManager, Character, Stage
 *   • Shaders              — ShaderManager + objeto `shaders` de conveniencia
 *   • Ventana              — NUEVO: objeto `window` con hide/show/opacity/spotlight
 *   • Visibilidad          — NUEVO: objeto `visibility` con spotlight/layer control
 *   • Utilidades           — Math, Std, StringTools, Paths, Json, Type, Reflect
 *   • Debug                — trace(), debugLog(), warn()
 *   • Eventos              — registerEvent(), fireEvent()
 *   • Autocompletado       — NUEVO: objeto `__api` con docs de toda la API
 *
 * ─── Autocompletado en editores ─────────────────────────────────────────────
 * La función `__api.help()` imprime por consola todas las variables y métodos
 * disponibles. Complementar con el archivo `funkin_api.d.hx` que genera
 * `ScriptAPI.generateTypeDefinitions()` para IDEs compatibles con HScript.
 */
class ScriptAPI
{
	/**
	 * Expone el set completo de variables globales a un intérprete.
	 * Llamar una vez después de crear el `Interp`, antes de `execute()`.
	 */
	public static function expose(#if HSCRIPT_ALLOWED interp:Interp #else _:Dynamic #end):Void
	{
		#if HSCRIPT_ALLOWED
		exposeFlixel(interp);
		exposeGameplay(interp);
		exposeShaders(interp);
		exposeWindow(interp);
		exposeVisibility(interp);
		exposeUtils(interp);
		exposeEvents(interp);
		exposeDebug(interp);
		exposeAutoComplete(interp);
		#end
	}

	// ─── Flixel ───────────────────────────────────────────────────────────────
	#if HSCRIPT_ALLOWED
	static function exposeFlixel(interp:Interp):Void
	{
		interp.variables.set('FlxG', FlxG);
		interp.variables.set('FlxSprite', flixel.FlxSprite);
		interp.variables.set('FlxText', flixel.text.FlxText);
		interp.variables.set('FlxSound', flixel.sound.FlxSound);
		interp.variables.set('FlxTween', flixel.tweens.FlxTween);
		interp.variables.set('FlxEase', flixel.tweens.FlxEase);
		interp.variables.set('FlxTimer', flixel.util.FlxTimer);
		interp.variables.set('FlxCamera', flixel.FlxCamera);
		interp.variables.set('FlxGroup', flixel.group.FlxGroup);
		interp.variables.set('FlxSpriteGroup', flixel.group.FlxSpriteGroup);
		interp.variables.set('FlxTrail', flixel.addons.effects.FlxTrail);
		interp.variables.set('FlxAnimate', flxanimate.FlxAnimate);
		interp.variables.set('FlxMath', flixel.math.FlxMath);
		interp.variables.set('FlxPoint',      buildPointObject());
		interp.variables.set('FlxRect',       buildRectObject());
		interp.variables.set('FlxAxes',       buildAxesObject());
		interp.variables.set('FlxStringUtil', flixel.util.FlxStringUtil);
		interp.variables.set('FunkinSprite', animationdata.FunkinSprite);

		// FlxColor como objeto con helpers (el abstract no funciona directamente en HScript)
		interp.variables.set('FlxColor', buildColorObject());
	}

	/**
	 * Construye el objeto FlxColor accesible desde HScript.
	 */
	static function buildColorObject():Dynamic
	{
		return {
			WHITE: 0xFFFFFFFF,
			BLACK: 0xFF000000,
			RED: 0xFFFF0000,
			GREEN: 0xFF00FF00,
			BLUE: 0xFF0000FF,
			YELLOW: 0xFFFFFF00,
			CYAN: 0xFF00FFFF,
			MAGENTA: 0xFFFF00FF,
			LIME: 0xFF00FF00,
			PINK: 0xFFFFC0CB,
			ORANGE: 0xFFFFA500,
			PURPLE: 0xFF800080,
			BROWN: 0xFFA52A2A,
			GRAY: 0xFF808080,
			TRANSPARENT: 0x00000000,
			// fromRGB(r, g, b, a=255) → Int
			fromRGB: function(r:Int, g:Int, b:Int, a:Int = 255):Int return (a << 24) | (r << 16) | (g << 8) | b,
			// fromHex('#RRGGBB' o 'RRGGBB') → Int
			fromHex: function(hex:String):Int
			{
				if (hex.charCodeAt(0) == '#'.code)
					hex = hex.substr(1);
				if (hex.startsWith('0x') || hex.startsWith('0X'))
					hex = hex.substr(2);
				return Std.parseInt('0xFF' + hex);
			},
			// toRGB(color) → {r, g, b, a}
			toRGB: function(color:Int):Dynamic
			{
				return {
					r: (color >> 16) & 0xFF,
					g: (color >> 8) & 0xFF,
					b: color & 0xFF,
					a: (color >> 24) & 0xFF
				};
			},
			// interpolate(from, to, t) → Int
			interpolate: function(from:Int, to:Int, t:Float):Int
			{
				var r1 = (from >> 16) & 0xFF;
				var r2 = (to >> 16) & 0xFF;
				var g1 = (from >> 8) & 0xFF;
				var g2 = (to >> 8) & 0xFF;
				var b1 = from & 0xFF;
				var b2 = to & 0xFF;
				var a1 = (from >> 24) & 0xFF;
				var a2 = (to >> 24) & 0xFF;
				return (Std.int(a1 + (a2 - a1) * t) << 24) | (Std.int(r1 + (r2 - r1) * t) << 16) | (Std.int(g1 + (g2 - g1) * t) << 8) | Std.int(b1
					+ (b2 - b1) * t);
			}
		};
	}

	// ─── FlxPoint ─────────────────────────────────────────────────────────────

	/**
	 * Wrapper de FlxPoint para HScript.
	 * Uso en scripts:
	 *   var p = FlxPoint.get(100, 200);
	 *   var w = FlxPoint.weak(0, 0);
	 */
	static function buildPointObject():Dynamic
	{
		return {
			get:  function(x:Float = 0, y:Float = 0):flixel.math.FlxPoint
				return flixel.math.FlxPoint.get(x, y),
			weak: function(x:Float = 0, y:Float = 0):flixel.math.FlxPoint
				return flixel.math.FlxPoint.weak(x, y)
		};
	}

	// ─── FlxRect ──────────────────────────────────────────────────────────────

	/**
	 * Wrapper de FlxRect para HScript.
	 * Uso en scripts:
	 *   var r = FlxRect.get(0, 0, 100, 50);
	 */
	static function buildRectObject():Dynamic
	{
		return {
			get: function(x:Float = 0, y:Float = 0, width:Float = 0, height:Float = 0):flixel.math.FlxRect
				return flixel.math.FlxRect.get(x, y, width, height)
		};
	}

	// ─── FlxAxes ──────────────────────────────────────────────────────────────

	/**
	 * Wrapper de FlxAxes para HScript.
	 * Uso en scripts:
	 *   sprite.drag.set(100, 0);
	 *   FlxAxes.X / FlxAxes.Y / FlxAxes.XY / FlxAxes.NONE
	 */
	static function buildAxesObject():Dynamic
	{
		return {
			X:    flixel.util.FlxAxes.X,
			Y:    flixel.util.FlxAxes.Y,
			XY:   flixel.util.FlxAxes.XY,
			NONE: flixel.util.FlxAxes.NONE
		};
	}

	// ─── Gameplay ─────────────────────────────────────────────────────────────

	static function exposeGameplay(interp:Interp):Void
	{
		interp.variables.set('PlayState', funkin.gameplay.PlayState);
		interp.variables.set('game', funkin.gameplay.PlayState.instance);
		interp.variables.set('Conductor', funkin.data.Conductor);
		interp.variables.set('EventManager', funkin.scripting.EventManager);
		interp.variables.set('MetaData', funkin.data.MetaData);
		interp.variables.set('GlobalConfig', funkin.data.GlobalConfig);
		interp.variables.set('Song', funkin.data.Song);
		interp.variables.set('HealthIcon', funkin.gameplay.objects.character.HealthIcon);
		interp.variables.set('ScoreManager', funkin.gameplay.objects.hud.ScoreManager);
		interp.variables.set('UIScriptedManager', funkin.gameplay.UIScriptedManager);
		interp.variables.set('ModManager', mods.ModManager);
		interp.variables.set('ModPaths', mods.ModPaths);
		interp.variables.set('Alphabet', ui.Alphabet);
		interp.variables.set('save', FlxG.save.data);
		interp.variables.set('VideoManager', funkin.cutscenes.VideoManager);

		// ── Personajes y escenarios ───────────────────────────────────────────
		interp.variables.set('Character', funkin.gameplay.objects.character.Character);
		interp.variables.set('CharacterList', funkin.gameplay.objects.character.CharacterList);
		interp.variables.set('Stage', funkin.gameplay.objects.stages.Stage);
		interp.variables.set('CharacterController', funkin.gameplay.CharacterController);
		interp.variables.set('CameraController', funkin.gameplay.CameraController);
		interp.variables.set('NoteManager', funkin.gameplay.NoteManager);
		interp.variables.set('CameraUtil', funkin.data.CameraUtil);
		interp.variables.set('PathsCache', funkin.cache.PathsCache);

		// ── Ranking / scoring ────────────────────────────────────────────────
		interp.variables.set('Ranking', funkin.data.Ranking);

		// ── Transiciones ──────────────────────────────────────────────────────
		interp.variables.set('StateTransition', StateTransition);
		interp.variables.set('TransitionType', {
			FADE: TransitionType.FADE,
			FADE_WHITE: TransitionType.FADE_WHITE,
			SLIDE_LEFT: TransitionType.SLIDE_LEFT,
			SLIDE_RIGHT: TransitionType.SLIDE_RIGHT,
			SLIDE_UP: TransitionType.SLIDE_UP,
			SLIDE_DOWN: TransitionType.SLIDE_DOWN,
			CIRCLE_WIPE: TransitionType.CIRCLE_WIPE,
			NONE: TransitionType.NONE,
			CUSTOM: TransitionType.CUSTOM
		});
		interp.variables.set('StickerTransition', StickerTransition);
	}

	// ─── Shaders ──────────────────────────────────────────────────────────────

	static function exposeShaders(interp:Interp):Void
	{
		interp.variables.set('ShaderManager', ShaderManager);

		interp.variables.set('shaders', {
			get: (name:String) -> ShaderManager.getShader(name),
			apply: (sprite:FlxSprite, name:String) -> ShaderManager.applyShader(sprite, name),
			remove: (sprite:FlxSprite) -> ShaderManager.removeShader(sprite),
			setParam: (name:String, param:String, val:Dynamic) -> ShaderManager.setShaderParam(name, param, val),
			list: () -> ShaderManager.getAvailableShaders(),
			reload: (name:String) -> ShaderManager.reloadShader(name)
		});
	}

	// ─── NUEVO: Ventana ────────────────────────────────────────────────────────

	/**
	 * Expone el objeto `window` — control de la ventana del juego.
	 *
	 * ─── Uso en scripts ────────────────────────────────────────────────────────
	 *
	 *   window.hide();                // Oculta la ventana (el proceso sigue)
	 *   window.show();                // Muestra la ventana
	 *   window.setVisible(false);     // Alias de hide/show
	 *   window.setOpacity(0.5);       // Opacidad de ventana OS (0.0-1.0)
	 *   window.setGameAlpha(0.0);     // Fade del contenido del juego (portable)
	 *   window.toggleFullscreen();    // Alternar pantalla completa
	 *   window.setFullscreen(true);   // Establecer pantalla completa
	 *   window.minimize();            // Minimizar
	 *   window.restore();             // Restaurar
	 *   window.center();              // Centrar en pantalla
	 *   window.setSize(w, h);         // Cambiar tamaño
	 *   window.setPosition(x, y);     // Mover ventana
	 *   window.setBounds(x,y,w,h);    // Mover y redimensionar
	 *   window.setTitle('Mi Mod');    // Cambiar título
	 *   window.width                  // Ancho actual
	 *   window.height                 // Alto actual
	 *   window.isFullscreen           // ¿Pantalla completa?
	 *   window.isVisible              // ¿Visible?
	 *   window.aspectRatio            // Relación de aspecto
	 */
	static function exposeWindow(interp:Interp):Void
	{
		interp.variables.set('WindowManager', WindowManager);

		interp.variables.set('window', {
			// ── Visibilidad ────────────────────────────────────────────────────
			hide: () -> WindowManager.hide(),
			show: () -> WindowManager.show(),
			setVisible: (v:Bool) -> WindowManager.setWindowVisible(v),
			// ── Opacidad ──────────────────────────────────────────────────────
			setOpacity: (a:Float) -> WindowManager.setWindowOpacity(a),
			setGameAlpha: (a:Float) -> WindowManager.setGameAlpha(a),
			// ── Fullscreen ────────────────────────────────────────────────────
			toggleFullscreen: () -> WindowManager.toggleFullscreen(),
			setFullscreen: (v:Bool) ->
			{
				FlxG.fullscreen = v;
			},
			// ── Ventana ───────────────────────────────────────────────────────
			minimize: () -> WindowManager.minimize(),
			restore: () -> WindowManager.restore(),
			center: () -> WindowManager.centerOnScreen(),
			setSize: (w:Int, h:Int) -> {
				#if !html5
				if (Application.current?.window != null)
					Application.current.window.resize(w, h);
				#end
			},
			setPosition: (x:Int, y:Int) -> {
				#if !html5
				if (Application.current?.window != null)
					Application.current.window.move(x, y);
				#end
			},
			setBounds: (x:Int, y:Int, w:Int, h:Int) -> WindowManager.setWindowBounds(x, y, w, h),
			setTitle: (t:String) -> {
				#if !html5
				if (Application.current?.window != null)
					Application.current.window.title = t;
				#end
			},
			// ── Propiedades (read-only) ────────────────────────────────────────
			// Nota: los objetos anónimos de Haxe no soportan getters,
			// así que se exponen como funciones. En scripts: window.width()
			width:        () -> WindowManager.windowWidth,
			height:       () -> WindowManager.windowHeight,
			isFullscreen: () -> WindowManager.isFullscreen,
			isVisible:    () -> WindowManager.isWindowVisible,
			aspectRatio:  () -> WindowManager.aspectRatio
		});
	}

	// ─── NUEVO: Visibilidad de sprites ─────────────────────────────────────────

	/**
	 * Expone el objeto `visibility` — control de visibilidad de sprites y cámaras.
	 *
	 * ─── Uso en scripts ────────────────────────────────────────────────────────
	 *
	 *   // Spotlight: sólo bf visible, fondo negro semitransparente
	 *   visibility.beginSpotlight([bf], true, 0.85);
	 *
	 *   // Cambiar qué sprite está en el spotlight sin reiniciarlo
	 *   visibility.updateSpotlight([dad]);
	 *
	 *   // Añadir un sprite al spotlight activo
	 *   visibility.addToSpotlight(dialogBox);
	 *
	 *   // Terminar spotlight (restaura todas las visibilidades)
	 *   visibility.endSpotlight();
	 *
	 *   // ¿Spotlight activo?
	 *   if (visibility.spotlightActive) { ... }
	 *
	 *   // Ocultar/mostrar todos los sprites de una cámara
	 *   visibility.setCameraVisible(FlxG.camera, false); // ocultar HUD
	 *   visibility.setCameraVisible(FlxG.camera, true);  // mostrar HUD
	 *
	 *   // Ocultar todas las cámaras excepto una
	 *   visibility.setOtherCamerasVisible(myCam, false);
	 *
	 *   // Ocultar un sprite individual
	 *   visibility.hide(sprite);
	 *   visibility.show(sprite);
	 *   visibility.toggle(sprite);
	 *
	 *   // Fade in/out de un sprite (usa FlxTween)
	 *   visibility.fadeOut(sprite, 0.5);   // fadeOut en 0.5s
	 *   visibility.fadeIn(sprite, 0.5);    // fadeIn en 0.5s
	 */
	static function exposeVisibility(interp:Interp):Void
	{
		interp.variables.set('visibility', {
			// ── Spotlight ─────────────────────────────────────────────────────
			beginSpotlight: (sprites:Array<Dynamic>, blackBg:Bool = false, bgAlpha:Float = 0.85) ->
			{
				var casted:Array<FlxSprite> = [for (s in sprites) Std.downcast(s, FlxSprite)].filter(s -> s != null);
				WindowManager.beginSpotlight(casted, blackBg, bgAlpha);
			},
			updateSpotlight: (sprites:Array<Dynamic>) ->
			{
				var casted:Array<FlxSprite> = [for (s in sprites) Std.downcast(s, FlxSprite)].filter(s -> s != null);
				WindowManager.updateSpotlight(casted);
			},
			addToSpotlight: (sprite:FlxSprite) -> WindowManager.addToSpotlight(sprite),
			removeFromSpotlight: (sprite:FlxSprite) -> WindowManager.removeFromSpotlight(sprite),
			endSpotlight: () -> WindowManager.endSpotlight(),
			spotlightActive: () -> WindowManager.spotlightActive,

			// ── Por cámara ────────────────────────────────────────────────────
			setCameraVisible: (cam:flixel.FlxCamera, v:Bool) -> WindowManager.setCameraLayerVisible(cam, v),
			setOtherCamerasVisible: (exceptCam:flixel.FlxCamera, v:Bool) -> WindowManager.setOtherCamerasVisible(exceptCam, v),

			// ── Sprite individual ─────────────────────────────────────────────
			hide: (sprite:FlxSprite) ->
			{
				if (sprite != null)
					sprite.visible = false;
			},
			show: (sprite:FlxSprite) ->
			{
				if (sprite != null)
					sprite.visible = true;
			},
			toggle: (sprite:FlxSprite) ->
			{
				if (sprite != null)
					sprite.visible = !sprite.visible;
			},

			// ── Fade ──────────────────────────────────────────────────────────
			fadeOut: (sprite:FlxSprite, duration:Float = 1.0, ?onComplete:Void->Void) ->
			{
				if (sprite == null)
					return;
				flixel.tweens.FlxTween.tween(sprite, {alpha: 0.0}, duration, {
					onComplete: function(_)
					{
						sprite.visible = false;
						if (onComplete != null)
							onComplete();
					}
				});
			},
			fadeIn: (sprite:FlxSprite, duration:Float = 1.0, ?onComplete:Void->Void) ->
			{
				if (sprite == null)
					return;
				sprite.visible = true;
				sprite.alpha = 0.0;
				flixel.tweens.FlxTween.tween(sprite, {alpha: 1.0}, duration, {
					onComplete: function(_)
					{
						if (onComplete != null)
							onComplete();
					}
				});
			},

			// ── Ocultar todo excepto lista ─────────────────────────────────────
			hideAllExcept: (sprites:Array<Dynamic>) ->
			{
				if (FlxG.state == null)
					return;
				final casted:Array<FlxSprite> = [for (s in sprites) Std.downcast(s, FlxSprite)].filter(s -> s != null);
				for (obj in FlxG.state.members)
				{
					if (obj == null)
						continue;
					final spr = Std.downcast(obj, FlxSprite);
					if (spr != null)
						spr.visible = casted.contains(spr);
				}
			},

			// ── Mostrar todos ─────────────────────────────────────────────────
			showAll: () ->
			{
				if (FlxG.state == null)
					return;
				for (obj in FlxG.state.members)
					if (obj != null)
						obj.visible = true;
			}
		});
	}

	// ─── Utilidades ───────────────────────────────────────────────────────────

	static function exposeUtils(interp:Interp):Void
	{
		interp.variables.set('Math', Math);
		interp.variables.set('Std', Std);
		interp.variables.set('StringTools', StringTools);
		interp.variables.set('Paths', Paths);
		interp.variables.set('Json', haxe.Json);
		interp.variables.set('Type', Type);
		interp.variables.set('Reflect', Reflect);
		interp.variables.set('Array', Array);

		// ── Helpers de tiempo ────────────────────────────────────────────────
		interp.variables.set('haxe', {
			Timer: haxe.Timer,
			Json: haxe.Json
		});

		// ── CoolUtil / helpers del engine ────────────────────────────────────
		interp.variables.set('CoolUtil', extensions.CoolUtil);
		interp.variables.set('Mathf', extensions.Mathf);
	}

	// ─── Eventos ──────────────────────────────────────────────────────────────

	static function exposeEvents(interp:Interp):Void
	{
		// registerEvent('NombreEvento', function(v1, v2, time) { ... })
		interp.variables.set('registerEvent', function(name:String, handler:Dynamic):Void
		{
			funkin.scripting.EventManager.registerCustomEvent(name, function(evts:Array<funkin.scripting.EventManager.EventData>):Bool
			{
				final e = evts[0];
				return handler(e.value1, e.value2, e.time) == true;
			});
			trace('[Script] Evento registrado: "$name"');
		});

		// fireEvent('NombreEvento', v1, v2)
		interp.variables.set('fireEvent', function(name:String, v1:String = '', v2:String = ''):Void funkin.scripting.EventManager.fireEvent(name, v1, v2));
	}

	// ─── Debug ────────────────────────────────────────────────────────────────

	static function exposeDebug(interp:Interp):Void
	{
		interp.variables.set('trace', (v:Dynamic) -> trace('[Script] $v'));
		interp.variables.set('debugLog', (v:Dynamic) -> trace('[DEBUG]  $v'));
		interp.variables.set('warn', (v:Dynamic) -> trace('[WARN]   $v'));
		interp.variables.set('error', (v:Dynamic) -> trace('[ERROR]  $v'));

		// print() — alias amigable de trace (familiaridad con Lua)
		interp.variables.set('print', (v:Dynamic) -> trace('[Script] $v'));
	}

	// ─── NUEVO: Autocompletado ────────────────────────────────────────────────

	/**
	 * Expone el objeto `__api` con documentación de toda la API en tiempo de ejecución.
	 *
	 * ─── Uso en scripts ────────────────────────────────────────────────────────
	 *   __api.help();           // Imprime todas las categorías y variables
	 *   __api.help('window');   // Imprime métodos del objeto 'window'
	 *   __api.list();           // Devuelve array de todas las variables
	 */
	static function exposeAutoComplete(interp:Interp):Void
	{
		final allVars = interp.variables;

		interp.variables.set('__api', {
			// ── help([category]) ──────────────────────────────────────────────
			help: function(?category:String):Void
			{
				if (category == null)
				{
					trace('=== Cool Engine Script API ===');
					trace('');
					trace('FLIXEL CORE:');
					trace('  FlxG         — Motor principal de Flixel (cámaras, sonido, estado, mouse, teclado)');
					trace('  FlxSprite    — Sprite básico con animaciones');
					trace('  FlxText      — Texto con formato');
					trace('  FlxSound     — Sonido/música');
					trace('  FlxCamera    — Cámara (zoom, pos, shake, filtros)');
					trace('  FlxTween     — Tweens de propiedades');
					trace('  FlxEase      — Funciones de easing');
					trace('  FlxTimer     — Temporizadores');
					trace('  FlxMath      — Utilidades matemáticas');
					trace('  FlxPoint     — Vector 2D');
					trace('  FunkinSprite — Sprite unificado (sparrow/atlas/packer)');
					trace('');
					trace('GAMEPLAY:');
					trace('  game         — PlayState.instance (estado de juego actual)');
					trace('  PlayState    — Clase del estado de juego');
					trace('  Conductor    — BPM, beats, steps, tiempo de canción');
					trace('  Character    — Clase de personaje');
					trace('  Stage        — Clase de escenario');
					trace('  Song         — Datos de la canción');
					trace('  NoteManager  — Gestión de notas');
					trace('  ScoreManager — Puntuación, rating, FC');
					trace('  EventManager — Eventos del chart');
					trace('');
					trace('VENTANA (objeto `window`):');
					trace('  window.hide()            — Ocultar ventana');
					trace('  window.show()            — Mostrar ventana');
					trace('  window.setOpacity(0.5)   — Opacidad OS (0.0-1.0)');
					trace('  window.setGameAlpha(0.0) — Alpha del contenido del juego');
					trace('  window.toggleFullscreen() — Alternar pantalla completa');
					trace('  window.minimize()         — Minimizar');
					trace('  window.center()           — Centrar en pantalla');
					trace('  window.setTitle("Texto") — Cambiar título');
					trace('  window.width / .height   — Tamaño actual');
					trace('');
					trace('VISIBILIDAD (objeto `visibility`):');
					trace('  visibility.beginSpotlight([sprite1, sprite2], blackBg, alpha)');
					trace('            — Sólo los sprites dados son visibles');
					trace('  visibility.updateSpotlight([otroSprite])');
					trace('            — Cambiar sprites del spotlight activo');
					trace('  visibility.addToSpotlight(sprite)  — Añadir al spotlight');
					trace('  visibility.endSpotlight()          — Restaurar todo');
					trace('  visibility.fadeOut(sprite, secs)   — Fade out con tween');
					trace('  visibility.fadeIn(sprite, secs)    — Fade in con tween');
					trace('  visibility.hideAllExcept([sprites]) — Ocultar todo excepto lista');
					trace('  visibility.showAll()               — Mostrar todos');
					trace('  visibility.setCameraVisible(cam, bool)');
					trace('');
					trace('SHADERS (objeto `shaders`):');
					trace('  shaders.apply(sprite, "shaderName") — Aplicar shader');
					trace('  shaders.remove(sprite)              — Quitar shader');
					trace('  shaders.setParam("name","param",v)  — Cambiar parámetro');
					trace('  shaders.list()                      — Shaders disponibles');
					trace('');
					trace('UTILIDADES:');
					trace('  Math / Std / StringTools / Paths / Json / Type / Reflect');
					trace('  CoolUtil / Mathf');
					trace('');
					trace('EVENTOS:');
					trace('  registerEvent("nombre", fn(v1,v2,time)) — Registrar evento del chart');
					trace('  fireEvent("nombre", v1, v2)             — Disparar evento manualmente');
					trace('');
					trace('DEBUG:');
					trace('  trace(v) / print(v) / debugLog(v) / warn(v) / error(v)');
					trace('');
					trace('AUTOCOMPLETADO:');
					trace('  __api.help()           — Esta ayuda');
					trace('  __api.help("window")   — Ayuda detallada de ventana');
					trace('  __api.list()           — Lista de todas las variables');
					trace('==============================');
				}
				else
				{
					switch (category.toLowerCase())
					{
						case 'window':
							trace('=== window ===');
							trace('  .hide()                  — Ocultar ventana del OS');
							trace('  .show()                  — Mostrar ventana del OS');
							trace('  .setVisible(bool)        — Alias hide/show');
							trace('  .setOpacity(float)       — 0.0-1.0 (requiere CppAPI en Windows)');
							trace('  .setGameAlpha(float)     — 0.0-1.0 (portable, afecta contenido)');
							trace('  .toggleFullscreen()      — Alternar pantalla completa');
							trace('  .setFullscreen(bool)     — Establecer pantalla completa');
							trace('  .minimize()              — Minimizar ventana');
							trace('  .restore()               — Restaurar ventana minimizada');
							trace('  .center()                — Centrar en monitor principal');
							trace('  .setSize(w, h)           — Cambiar tamaño (respeta min)');
							trace('  .setPosition(x, y)       — Mover ventana');
							trace('  .setBounds(x,y,w,h)      — Mover y redimensionar');
							trace('  .setTitle(str)           — Cambiar título de la ventana');
							trace('  .width (get)             — Ancho actual en px');
							trace('  .height (get)            — Alto actual en px');
							trace('  .isFullscreen (get)      — ¿Pantalla completa?');
							trace('  .isVisible (get)         — ¿Ventana visible?');
							trace('  .aspectRatio (get)       — width/height');

						case 'visibility':
							trace('=== visibility ===');
							trace('  .beginSpotlight(sprites, [blackBg=false], [bgAlpha=0.85])');
							trace('       Oculta todo excepto `sprites`. blackBg añade overlay negro.');
							trace('  .updateSpotlight(sprites)');
							trace('       Cambia qué sprites están en el spotlight sin reiniciarlo.');
							trace('  .addToSpotlight(sprite)    — Añadir sprite al spotlight activo');
							trace('  .removeFromSpotlight(spr)  — Quitar sprite del spotlight');
							trace('  .endSpotlight()            — Restaurar visibilidades originales');
							trace('  .spotlightActive (get)     — ¿Spotlight activo?');
							trace('  .setCameraVisible(cam, v)  — Ocultar/mostrar capa de cámara');
							trace('  .setOtherCamerasVisible(cam, v) — Afectar todas excepto una');
							trace('  .hide(sprite)              — sprite.visible = false');
							trace('  .show(sprite)              — sprite.visible = true');
							trace('  .toggle(sprite)            — Alternar visibilidad');
							trace('  .fadeOut(sprite, secs, [cb]) — Tween alpha 1→0, luego visible=false');
							trace('  .fadeIn(sprite, secs, [cb])  — visible=true, tween alpha 0→1');
							trace('  .hideAllExcept(sprites)    — Ocultar todo excepto lista');
							trace('  .showAll()                 — Mostrar todos los sprites del state');

						default:
							trace('Categorías disponibles: window, visibility');
							trace('O llama __api.help() sin argumentos para la ayuda completa.');
					}
				}
			},

			// ── list() ────────────────────────────────────────────────────────
			list: function():Array<String>
			{
				var result:Array<String> = [];
				for (key in allVars.keys())
					result.push(key);
				result.sort((a, b) -> a < b ? -1 : a > b ? 1 : 0);
				return result;
			},

			// ── exists(name) ──────────────────────────────────────────────────
			exists: function(name:String):Bool return allVars.exists(name),

			// ── version ───────────────────────────────────────────────────────
			version: '2.0.0',
			engine: 'Cool Engine'
		});
	}
	#end
}