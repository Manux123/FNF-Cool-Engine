package mods.compat;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;
import funkin.gameplay.objects.stages.Stage;
import animationdata.FunkinSprite;

using StringTools;

/**
 * PsychLuaStageAPI
 * ─────────────────────────────────────────────────────────────────────────────
 * Exposes the Psych Engine Lua stage API as HScript-callable functions.
 *
 * Usage: call `PsychLuaStageAPI.expose(interp, stage)` after creating the
 * HScriptInstance for a transpiled Lua script. The functions are injected
 * directly into the interpreter so transpiled code can call them as globals.
 *
 * Covered API:
 *   makeLuaSprite     setScrollFactor    makeGraphic
 *   scaleObject       addLuaSprite       removeLuaSprite
 *   setProperty       getProperty        objectExists
 *   doTweenAlpha      doTweenX           doTweenY
 *   doTweenColor      cancelTween
 *   setVisible        setAlpha           setAngle
 *   setObjectCamera   screenCenter
 */
class PsychLuaStageAPI
{
	#if HSCRIPT_ALLOWED
	/**
	 * Injects all Psych Lua stage API functions into an HScript interpreter.
	 * @param interp  The HScript Interp of the script instance.
	 * @param stage   The Stage object the script belongs to.
	 */
	public static function expose(interp:hscript.Interp, stage:Stage):Void
	{
		// ── Sprite registry shared by all closures ────────────────────────────
		final sprites:Map<String, FlxSprite> = new Map();
		final tweens:Map<String, FlxTween>   = new Map();

		// ─── Sprite creation ─────────────────────────────────────────────────

		/**
		 * makeLuaSprite(name, imagePath, x, y)
		 * Creates a sprite and registers it under `name`.
		 * imagePath: relative image key (e.g. 'stages/NocturnSky').
		 *   'empty' → create an empty sprite (for makeGraphic).
		 */
		interp.variables.set('makeLuaSprite', function(name:String, imagePath:String, x:Float, y:Float):Void
		{
			final spr = new FlxSprite(x, y);

			if (imagePath != null && imagePath != '' && imagePath != 'empty')
			{
				// Try mod image paths: Psych layout (images/<path>) and Cool (stages/<stage>/images/<name>)
				final pngPath = _resolveImage(imagePath, stage.curStage);
				if (pngPath != null)
					spr.loadGraphic(pngPath);
				else
					trace('[PsychLuaStageAPI] Image not found: $imagePath');
			}

			spr.antialiasing = true;
			sprites.set(name, spr);
		});

		/**
		 * makeGraphic(name, width, height, colorHex)
		 * Fills the sprite with a solid color. colorHex is 6-char hex (RRGGBB).
		 */
		interp.variables.set('makeGraphic', function(name:String, width:Int, height:Int, colorHex:String):Void
		{
			var spr = sprites.get(name);
			if (spr == null)
			{
				spr = new FlxSprite();
				sprites.set(name, spr);
			}
			final col:Int = FlxColor.fromString('#' + colorHex.replace('#', '').replace('0x', ''));
			spr.makeGraphic(width, height, col);
		});

		// ─── Sprite properties ────────────────────────────────────────────────

		interp.variables.set('setScrollFactor', function(name:String, sx:Float, sy:Float):Void
		{
			final spr = sprites.get(name);
			if (spr != null) spr.scrollFactor.set(sx, sy);
		});

		interp.variables.set('scaleObject', function(name:String, sx:Float, sy:Float):Void
		{
			final spr = sprites.get(name);
			if (spr != null) { spr.scale.set(sx, sy); spr.updateHitbox(); }
		});

		interp.variables.set('setVisible', function(name:String, vis:Bool):Void
		{
			final spr = sprites.get(name);
			if (spr != null) spr.visible = vis;
		});

		interp.variables.set('setAlpha', function(name:String, alpha:Float):Void
		{
			final spr = sprites.get(name);
			if (spr != null) spr.alpha = alpha;
		});

		interp.variables.set('setAngle', function(name:String, angle:Float):Void
		{
			final spr = sprites.get(name);
			if (spr != null) spr.angle = angle;
		});

		interp.variables.set('objectExists', function(name:String):Bool
			return sprites.exists(name));

		/**
		 * screenCenter(name, axis)
		 * axis: 'x', 'y', or 'xy' / 'both'
		 */
		interp.variables.set('screenCenter', function(name:String, axis:String = 'xy'):Void
		{
			final spr = sprites.get(name);
			if (spr == null) return;
			final a = axis.toLowerCase();
			if (a == 'x'  || a == 'xy' || a == 'both') spr.screenCenter(flixel.util.FlxAxes.X);
			if (a == 'y'  || a == 'xy' || a == 'both') spr.screenCenter(flixel.util.FlxAxes.Y);
		});

		// ─── Adding to stage ──────────────────────────────────────────────────

		/**
		 * addLuaSprite(name, inFront)
		 * inFront=false → add behind characters (normal stage layer)
		 * inFront=true  → tracked in stage.elements so PlayState can add in front
		 */
		interp.variables.set('addLuaSprite', function(name:String, inFront:Bool = false):Void
		{
			final spr = sprites.get(name);
			if (spr == null) { trace('[PsychLuaStageAPI] addLuaSprite: sprite "$name" not found'); return; }

			if (!inFront)
			{
				stage.add(spr);
			}
			else
			{
				// Store for PlayState to add after character layer
				stage.elements.set('__front_$name', spr);
			}
		});

		interp.variables.set('removeLuaSprite', function(name:String, ?destroy:Bool = true):Void
		{
			final spr = sprites.get(name);
			if (spr == null) return;
			stage.remove(spr, destroy == true);
			sprites.remove(name);
		});

		// ─── setProperty / getProperty ────────────────────────────────────────

		/**
		 * setProperty('spriteName.fieldName', value)
		 * Supports dot-notation: 'e.alpha', 'e.visible', 'e.scrollFactor.x'
		 */
		interp.variables.set('setProperty', function(dotPath:String, value:Dynamic):Void
		{
			_setDotProperty(sprites, dotPath, value);
		});

		interp.variables.set('getProperty', function(dotPath:String):Dynamic
		{
			return _getDotProperty(sprites, dotPath);
		});

		// ─── Tweens ───────────────────────────────────────────────────────────

		/**
		 * doTweenAlpha(tag, objectName, targetAlpha, duration, easeStr)
		 * Psych signature: tag, object, value (target), time (beats or seconds), ease
		 */
		interp.variables.set('doTweenAlpha', function(tag:String, objName:String, targetAlpha:Float, duration:Float, easeStr:String):Void
		{
			final spr = sprites.get(objName);
			if (spr == null) return;
			_cancelTween(tweens, tag);
			tweens.set(tag, FlxTween.tween(spr, {alpha: targetAlpha}, duration, {ease: _getEase(easeStr)}));
		});

		interp.variables.set('doTweenX', function(tag:String, objName:String, targetX:Float, duration:Float, easeStr:String):Void
		{
			final spr = sprites.get(objName);
			if (spr == null) return;
			_cancelTween(tweens, tag);
			tweens.set(tag, FlxTween.tween(spr, {x: targetX}, duration, {ease: _getEase(easeStr)}));
		});

		interp.variables.set('doTweenY', function(tag:String, objName:String, targetY:Float, duration:Float, easeStr:String):Void
		{
			final spr = sprites.get(objName);
			if (spr == null) return;
			_cancelTween(tweens, tag);
			tweens.set(tag, FlxTween.tween(spr, {y: targetY}, duration, {ease: _getEase(easeStr)}));
		});

		interp.variables.set('doTweenAngle', function(tag:String, objName:String, targetAngle:Float, duration:Float, easeStr:String):Void
		{
			final spr = sprites.get(objName);
			if (spr == null) return;
			_cancelTween(tweens, tag);
			tweens.set(tag, FlxTween.tween(spr, {angle: targetAngle}, duration, {ease: _getEase(easeStr)}));
		});

		interp.variables.set('doTweenZoom', function(tag:String, targetZoom:Float, duration:Float, easeStr:String):Void
		{
			_cancelTween(tweens, tag);
			tweens.set(tag, FlxTween.tween(FlxG.camera, {zoom: targetZoom}, duration, {ease: _getEase(easeStr)}));
		});

		interp.variables.set('cancelTween', function(tag:String):Void
			_cancelTween(tweens, tag));

		// ─── Misc Psych API ───────────────────────────────────────────────────

		interp.variables.set('luaTrace', function(msg:Dynamic):Void
			trace('[LuaScript] $msg'));

		// setObjectCamera — Psych lets you assign a sprite to a specific camera
		interp.variables.set('setObjectCamera', function(name:String, camName:String):Void
		{
			final spr = sprites.get(name);
			if (spr == null) return;
			final cam = camName.toLowerCase() == 'hud' ? FlxG.cameras.list[1] : FlxG.camera;
			spr.cameras = [cam];
		});

		trace('[PsychLuaStageAPI] API injected for stage: ${stage.curStage}');
	}
	#end

	// ─── Private helpers ─────────────────────────────────────────────────────

	/** Resolves an image path for Psych mods: tries images/<path> then stages/<stage>/images/<key>. */
	static function _resolveImage(imagePath:String, stageName:String):Null<String>
	{
		final ext  = '.png';
		final mod  = mods.ModManager.activeMod;
		final base = mod != null ? '${mods.ModManager.MODS_FOLDER}/$mod' : null;

		// Psych image paths e.g. 'stages/NocturnSky' → mods/mod/images/stages/NocturnSky.png
		if (base != null)
		{
			final candidates = [
				'$base/images/$imagePath$ext',           // Psych: images/stages/X
				'$base/stages/$stageName/images/${_basename(imagePath)}$ext', // Cool: stages/S/images/X
				'$base/images/${_basename(imagePath)}$ext', // flat
			];
			for (p in candidates)
				if (sys.FileSystem.exists(p)) return p;
		}

		// Assets fallback
		final assetCandidates = [
			'assets/images/$imagePath$ext',
			'assets/stages/$stageName/images/${_basename(imagePath)}$ext',
		];
		for (p in assetCandidates)
			if (sys.FileSystem.exists(p)) return p;

		return null;
	}

	static function _basename(path:String):String
	{
		final parts = path.split('/');
		return parts[parts.length - 1];
	}

	/** Set a property via dot-notation path like 'spriteName.field' or 'spriteName.field.subfield'. */
	static function _setDotProperty(sprites:Map<String, FlxSprite>, dotPath:String, value:Dynamic):Void
	{
		final parts = dotPath.split('.');
		if (parts.length < 2) return;

		final spr = sprites.get(parts[0]);
		if (spr == null) return;

		if (parts.length == 2)
		{
			Reflect.setProperty(spr, parts[1], value);
		}
		else
		{
			// e.g. 'e.scrollFactor.x'
			var obj:Dynamic = spr;
			for (i in 1...parts.length - 1)
				obj = Reflect.getProperty(obj, parts[i]);
			Reflect.setProperty(obj, parts[parts.length - 1], value);
		}
	}

	static function _getDotProperty(sprites:Map<String, FlxSprite>, dotPath:String):Dynamic
	{
		final parts = dotPath.split('.');
		if (parts.length < 2) return null;

		final spr = sprites.get(parts[0]);
		if (spr == null) return null;

		var obj:Dynamic = spr;
		for (i in 1...parts.length)
			obj = Reflect.getProperty(obj, parts[i]);
		return obj;
	}

	static function _cancelTween(tweens:Map<String, FlxTween>, tag:String):Void
	{
		if (tweens.exists(tag))
		{
			final t = tweens.get(tag);
			if (t != null) t.cancel();
			tweens.remove(tag);
		}
	}

	/** Maps Psych ease name strings to FlxEase functions. */
	static function _getEase(name:String):Float->Float
	{
		if (name == null || name == '') return FlxEase.linear;
		return switch (name.toLowerCase())
		{
			case 'linear':        FlxEase.linear;
			case 'quadout':       FlxEase.quadOut;
			case 'quadin':        FlxEase.quadIn;
			case 'quadinout':     FlxEase.quadInOut;
			case 'cubeout':       FlxEase.cubeOut;
			case 'cubein':        FlxEase.cubeIn;
			case 'cubeinout':     FlxEase.cubeInOut;
			case 'quartout':      FlxEase.quartOut;
			case 'quartin':       FlxEase.quartIn;
			case 'quartinout':    FlxEase.quartInOut;
			case 'quintout':      FlxEase.quintOut;
			case 'quintin':       FlxEase.quintIn;
			case 'quintinout':    FlxEase.quintInOut;
			case 'sineout':       FlxEase.sineOut;
			case 'sinein':        FlxEase.sineIn;
			case 'sineinout':     FlxEase.sineInOut;
			case 'bounceout':     FlxEase.bounceOut;
			case 'bouncein':      FlxEase.bounceIn;
			case 'bounceinout':   FlxEase.bounceInOut;
			case 'elasticout':    FlxEase.elasticOut;
			case 'elasticin':     FlxEase.elasticIn;
			case 'elasticinout':  FlxEase.elasticInOut;
			case 'backout':       FlxEase.backOut;
			case 'backin':        FlxEase.backIn;
			case 'backinout':     FlxEase.backInOut;
			case 'expoout':       FlxEase.expoOut;
			case 'expoin':        FlxEase.expoIn;
			case 'expoinout':     FlxEase.expoInOut;
			case 'circout':       FlxEase.circOut;
			case 'circin':        FlxEase.circIn;
			case 'circinout':     FlxEase.circInOut;
			case 'smoothstep':    FlxEase.smoothStepIn;
			case 'smootherstep':  FlxEase.smootherStepIn;
			default:              FlxEase.linear;
		};
	}
}
