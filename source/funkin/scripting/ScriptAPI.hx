package funkin.scripting;

import flixel.FlxG;
import shaders.ShaderManager;
import funkin.transitions.StateTransition;
import funkin.transitions.StateTransition.TransitionType;
import funkin.transitions.StickerTransition;

#if HSCRIPT_ALLOWED
import hscript.Interp;
#end

using StringTools;

/**
 * API global expuesta a todos los scripts HScript.
 *
 * Centralizar aquí evita duplicar los ~80 `interp.variables.set(...)` que
 * antes existían por separado en ScriptHandler y StateScriptHandler.
 *
 * ─── Categorías ─────────────────────────────────────────────────────────────
 *   • Flixel core          — FlxG, FlxSprite, FlxText, FlxCamera, etc.
 *   • Tweens / timers      — FlxTween, FlxEase, FlxTimer
 *   • Color helpers        — FlxColor (abstract → objeto con helpers)
 *   • Gameplay             — PlayState, Conductor, EventManager
 *   • Shaders              — ShaderManager + objeto `shaders` de conveniencia
 *   • Utilidades           — Math, Std, StringTools, Paths
 *   • Debug                — trace(), debugLog()
 *   • Eventos              — registerEvent(), fireEvent()
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
		exposeUtils(interp);
		exposeEvents(interp);
		exposeDebug(interp);
		#end
	}

	// ─── Flixel ───────────────────────────────────────────────────────────────

	#if HSCRIPT_ALLOWED
	static function exposeFlixel(interp:Interp):Void
	{
		interp.variables.set('FlxG',             FlxG);
		interp.variables.set('FlxSprite',         flixel.FlxSprite);
		interp.variables.set('FlxText',           flixel.text.FlxText);
		interp.variables.set('FlxSound',          flixel.sound.FlxSound);
		interp.variables.set('FlxTween',          flixel.tweens.FlxTween);
		interp.variables.set('FlxEase',           flixel.tweens.FlxEase);
		interp.variables.set('FlxTimer',          flixel.util.FlxTimer);
		interp.variables.set('FlxCamera',         flixel.FlxCamera);
		interp.variables.set('FlxGroup',          flixel.group.FlxGroup);
		interp.variables.set('FlxSpriteGroup',    flixel.group.FlxSpriteGroup);
		interp.variables.set('FlxTrail',          flixel.addons.effects.FlxTrail);
		interp.variables.set('FlxAnimate',        flxanimate.FlxAnimate);
		interp.variables.set('FlxMath',           flixel.math.FlxMath);
		interp.variables.set('FunkinSprite',      animationdata.FunkinSprite);

		// FlxColor es un abstract — se expone como objeto con helpers.
		interp.variables.set('FlxColor', buildColorObject());
	}

	/**
	 * Construye el objeto FlxColor accesible desde HScript.
	 * No se puede pasar el abstract directamente porque HScript lo trata como Int.
	 */
	static function buildColorObject():Dynamic
	{
		return {
			WHITE:       0xFFFFFFFF,
			BLACK:       0xFF000000,
			RED:         0xFFFF0000,
			GREEN:       0xFF00FF00,
			BLUE:        0xFF0000FF,
			YELLOW:      0xFFFFFF00,
			CYAN:        0xFF00FFFF,
			MAGENTA:     0xFFFF00FF,
			LIME:        0xFF00FF00,
			PINK:        0xFFFFC0CB,
			ORANGE:      0xFFFFA500,
			PURPLE:      0xFF800080,
			BROWN:       0xFFA52A2A,
			GRAY:        0xFF808080,
			TRANSPARENT: 0x00000000,
			// fromRGB(r, g, b, a=255) → Int
			fromRGB: function(r:Int, g:Int, b:Int, a:Int = 255):Int
				return (a << 24) | (r << 16) | (g << 8) | b,
			// fromHex('#RRGGBB') o 'RRGGBB' → Int
			fromHex: function(hex:String):Int {
				if (hex.charCodeAt(0) == '#'.code) hex = hex.substr(1);
				if (hex.startsWith('0x') || hex.startsWith('0X')) hex = hex.substr(2);
				return Std.parseInt('0xFF' + hex);
			}
		};
	}

	// ─── Gameplay ─────────────────────────────────────────────────────────────

	static function exposeGameplay(interp:Interp):Void
	{
		interp.variables.set('PlayState',       funkin.gameplay.PlayState);
		interp.variables.set('game',            funkin.gameplay.PlayState.instance);
		interp.variables.set('Conductor',       funkin.data.Conductor);
		interp.variables.set('EventManager',    funkin.scripting.EventManager);
		interp.variables.set('MetaData',        funkin.data.MetaData);
		interp.variables.set('GlobalConfig',    funkin.data.GlobalConfig);
		interp.variables.set('Song',            funkin.data.Song);
		interp.variables.set('HealthIcon',      funkin.gameplay.objects.character.HealthIcon);
		interp.variables.set('ScoreManager',    funkin.gameplay.objects.hud.ScoreManager);
		interp.variables.set('UIScriptedManager', funkin.gameplay.UIScriptedManager);
		// Mod API — scripts pueden saber en qué mod están y resolver paths
		interp.variables.set('ModManager', mods.ModManager);
		interp.variables.set('ModPaths',   mods.ModPaths);
		interp.variables.set('Alphabet',        ui.Alphabet);
		interp.variables.set('save',            FlxG.save.data);

		// ── Transiciones ──────────────────────────────────────────────────────
		// StateTransition: transiciones suaves entre states (fade, slide, etc.)
		interp.variables.set('StateTransition', StateTransition);

		// Tipos de transición accesibles como strings o como enum
		interp.variables.set('TransitionType', {
			FADE:        TransitionType.FADE,
			FADE_WHITE:  TransitionType.FADE_WHITE,
			SLIDE_LEFT:  TransitionType.SLIDE_LEFT,
			SLIDE_RIGHT: TransitionType.SLIDE_RIGHT,
			SLIDE_UP:    TransitionType.SLIDE_UP,
			SLIDE_DOWN:  TransitionType.SLIDE_DOWN,
			CIRCLE_WIPE: TransitionType.CIRCLE_WIPE,
			NONE:        TransitionType.NONE,
			CUSTOM:      TransitionType.CUSTOM
		});

		// StickerTransition: transiciones de stickers (existente)
		interp.variables.set('StickerTransition', StickerTransition);
	}

	// ─── Shaders ──────────────────────────────────────────────────────────────

	static function exposeShaders(interp:Interp):Void
	{
		interp.variables.set('ShaderManager', ShaderManager);

		// Objeto `shaders` de conveniencia — API más corta para scripts.
		interp.variables.set('shaders', {
			get:      (name:String)                            -> ShaderManager.getShader(name),
			apply:    (sprite:flixel.FlxSprite, name:String)  -> ShaderManager.applyShader(sprite, name),
			remove:   (sprite:flixel.FlxSprite)               -> ShaderManager.removeShader(sprite),
			setParam: (name:String, param:String, val:Dynamic) -> ShaderManager.setShaderParam(name, param, val),
			list:     ()                                       -> ShaderManager.getAvailableShaders(),
			reload:   (name:String)                            -> ShaderManager.reloadShader(name)
		});
	}

	// ─── Utilidades ───────────────────────────────────────────────────────────

	static function exposeUtils(interp:Interp):Void
	{
		interp.variables.set('Math',        Math);
		interp.variables.set('Std',         Std);
		interp.variables.set('StringTools', StringTools);
		interp.variables.set('Paths',       Paths);
	}

	// ─── Eventos ──────────────────────────────────────────────────────────────

	static function exposeEvents(interp:Interp):Void
	{
		// registerEvent('NombreEvento', function(v1, v2, time) { ... })
		interp.variables.set('registerEvent', function(name:String, handler:Dynamic):Void
		{
			funkin.scripting.EventManager.registerCustomEvent(name,
				function(evts:Array<funkin.scripting.EventManager.EventData>):Bool
				{
					final e = evts[0];
					return handler(e.value1, e.value2, e.time) == true;
				}
			);
			trace('[Script] Evento registrado: "$name"');
		});

		// fireEvent('NombreEvento', v1, v2)
		interp.variables.set('fireEvent',
			function(name:String, v1:String = '', v2:String = ''):Void
				funkin.scripting.EventManager.fireEvent(name, v1, v2));
	}

	// ─── Debug ────────────────────────────────────────────────────────────────

	static function exposeDebug(interp:Interp):Void
	{
		interp.variables.set('trace',    (v:Dynamic) -> trace('[Script] $v'));
		interp.variables.set('debugLog', (v:Dynamic) -> trace('[DEBUG]  $v'));
	}
	#end
}
