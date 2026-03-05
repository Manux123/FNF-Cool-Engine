package mods.compat;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextBorderStyle;
import flixel.text.FlxText.FlxTextAlign;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxAxes;
import flixel.util.FlxColor;
import flixel.graphics.frames.FlxAtlasFrames;
import funkin.scripting.HScriptInstance;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

#if HSCRIPT_ALLOWED
import hscript.Interp;
#end

using StringTools;

/**
 * PsychLuaGameplayAPI
 * ─────────────────────────────────────────────────────────────────────────────
 * Exposes the Psych Engine 1.0.x GAMEPLAY Lua API to HScript song scripts.
 *
 * This is the counterpart to PsychLuaStageAPI: while that handles stage
 * scripts (onCreate/sprite creation/tweens only), this handles the full
 * gameplay API used by song scripts in `data/{songName}/`.
 *
 * ── API covered ──────────────────────────────────────────────────────────────
 *  getProperty / setProperty           — reflection on PlayState dot-paths
 *  getPropertyFromGroup / setPropertyFromGroup — reflection on group members
 *  callMethod                          — call a method via string path
 *
 *  makeLuaText / addLuaText            — create FlxText objects on the HUD
 *  removeLuaText
 *  setTextSize / setTextFont / setTextColor / setTextBorder / setTextAlignment
 *  setTextString / getTextString
 *
 *  makeLuaSprite / makeAnimatedLuaSprite / addLuaSprite / removeLuaSprite
 *  getLuaObject
 *
 *  scaleObject / setScrollFactor / setObjectCamera / screenCenter / objectExists
 *  setVisible / setAlpha / setAngle / setX / setY
 *  playAnim / getAnimationName
 *  addAnimationByPrefix / addAnimationByIndices
 *
 *  doTweenX / doTweenY / doTweenAlpha / doTweenAngle / doTweenColor
 *  cancelTween
 *
 *  stringStartsWith / stringEndsWith / stringSplit / stringTrim
 *  debugPrint
 *
 *  playerStrums / opponentStrums       — aliases for playerStrumsGroup/cpuStrumsGroup
 *  iconP1 / iconP2 / healthBar         — HUD element shortcuts
 *
 *  playSound / playMusic / shakeCamera / flashCamera
 *
 * ── Callback aliases (set up AFTER execute(), via setupCallbackAliases()) ───
 *  goodNoteHit(i,d,t,s) → onNoteHit(note)
 *  opponentNoteHit(i,d,t,s) → onOpponentNoteHit(note)
 *  missNote/noteMiss/onMissNote(d) → onNoteMiss(note)
 *  onCreatePost → postCreate
 *  onBeatHit() → onBeatHit(curBeat:Int)  (arg already injected by LuaStageConverter)
 *
 * ── Usage ────────────────────────────────────────────────────────────────────
 *  In ScriptHandler.loadScript(), BEFORE execute():
 *    if (isLua) mods.compat.PsychLuaGameplayAPI.expose(script.interp);
 *  After execute():
 *    if (isLua) mods.compat.PsychLuaGameplayAPI.setupCallbackAliases(script);
 */
class PsychLuaGameplayAPI
{
	// ─── Public API ───────────────────────────────────────────────────────────

	#if HSCRIPT_ALLOWED

	/**
	 * Injects all Psych gameplay Lua API functions into an HScript interpreter.
	 * Call this BEFORE script.interp.execute() so top-level code can see them.
	 *
	 * @param interp  The HScript Interp of the song script.
	 */
	public static function expose(interp:Interp):Void
	{
		// Per-script state: sprites and texts created by this script instance.
		// Captured by closures — each script gets its own registry.
		final sprites : Map<String, FlxSprite> = new Map();
		final texts   : Map<String, FlxText>   = new Map();
		final tweens  : Map<String, FlxTween>  = new Map();

		// ── Psych-style alias globals (Psych uses different names) ────────────

		// playerStrums / opponentStrums → Cool Engine uses playerStrumsGroup / cpuStrumsGroup
		// These are already set by PlayState.setOnScripts() but with different names.
		// We add Psych-style aliases here so scripts that reference them before
		// PlayState.setOnScripts() still compile.
		interp.variables.set('playerStrums', null);   // will be set by PlayState
		interp.variables.set('opponentStrums', null); // same

		// ── getProperty / setProperty ─────────────────────────────────────────
		// Psych uses flat reflection: getProperty('boyfriend.x') walks through
		// PlayState fields by dot-path. Also handles array notation: 'members[2]'.
		// BUG FIX: also look in local sprites/texts map FIRST before PlayState
		// reflection, so properties of lua-created sprites are found correctly.

		interp.variables.set('getProperty', function(path:String):Dynamic
		{
			final dotIdx = path.indexOf('.');
			if (dotIdx >= 0) {
				final spriteName = path.substr(0, dotIdx);
				final field = path.substr(dotIdx + 1);
				final spr = sprites.get(spriteName);
				if (spr != null) return _walkPath(spr, field);
				final txt = texts.get(spriteName);
				if (txt != null) return _walkPath(txt, field);
			} else {
				if (sprites.exists(path)) return sprites.get(path);
				if (texts.exists(path))   return texts.get(path);
			}
			return _getReflect(path, interp);
		});

		interp.variables.set('setProperty', function(path:String, value:Dynamic):Void
		{
			final dotIdx = path.indexOf('.');
			if (dotIdx >= 0) {
				final spriteName = path.substr(0, dotIdx);
				final field = path.substr(dotIdx + 1);
				final spr = sprites.get(spriteName);
				if (spr != null) { _setPath(spr, field, value); return; }
				final txt = texts.get(spriteName);
				if (txt != null) { _setPath(txt, field, value); return; }
			}
			_setReflect(path, value, interp);
		});

		// ── getPropertyFromGroup / setPropertyFromGroup ───────────────────────
		// getPropertyFromGroup('unspawnNotes', i, 'isSustainNote')
		// getPropertyFromGroup('playerStrums.members', i, 'animation.curAnim.name')

		interp.variables.set('getPropertyFromGroup', function(group:String, idx:Int, prop:String):Dynamic
		{
			final grp = _getReflect(group, interp);
			if (grp == null) return null;
			final member = _getMember(grp, idx);
			if (member == null) return null;
			return _walkPath(member, prop);
		});

		interp.variables.set('setPropertyFromGroup', function(group:String, idx:Int, prop:String, value:Dynamic):Void
		{
			final grp = _getReflect(group, interp);
			if (grp == null) return;
			final member = _getMember(grp, idx);
			if (member == null) return;
			_setPath(member, prop, value);
		});

		// ── callMethod ────────────────────────────────────────────────────────
		// callMethod('playerStrums.members[0].playAnim', ['static', true])
		// The path's last segment is the method name; everything before is the object.

		interp.variables.set('callMethod', function(objPath:String, args:Dynamic):Dynamic
		{
			if (objPath == null) return null;
			final safeArgs:Array<Dynamic> = (args != null && Std.isOfType(args, Array))
				? cast args : (args != null ? [args] : []);

			final dotIdx = objPath.lastIndexOf('.');
			if (dotIdx < 0)
			{
				// Top-level function in interpreter scope
				final fn = interp.variables.get(objPath);
				if (fn != null && Reflect.isFunction(fn))
					try { return Reflect.callMethod(null, fn, safeArgs); } catch(_) {}
				return null;
			}

			final parentPath = objPath.substr(0, dotIdx);
			final methodName = objPath.substr(dotIdx + 1);
			final obj = _getReflect(parentPath, interp);
			if (obj == null) return null;
			final method = Reflect.field(obj, methodName);
			if (method == null || !Reflect.isFunction(method)) return null;
			try { return Reflect.callMethod(obj, method, safeArgs); } catch(_) { return null; }
		});

		// ── Text: makeLuaText ─────────────────────────────────────────────────

		interp.variables.set('makeLuaText', function(name:String, text:String, width:Int, x:Float, y:Float):Void
		{
			if (texts.exists(name)) return; // already created
			final t = new FlxText(x, y, width, text ?? '');
			t.scrollFactor.set(0, 0);
			texts.set(name, t);
		});

		interp.variables.set('addLuaText', function(name:String):Void
		{
			final ps = funkin.gameplay.PlayState.instance;
			if (ps == null) return;
			final t = texts.get(name);
			if (t == null) return;
			t.cameras = [ps.camHUD];
			ps.add(t);
		});

		interp.variables.set('removeLuaText', function(name:String):Void
		{
			final ps = funkin.gameplay.PlayState.instance;
			if (ps == null) return;
			final t = texts.get(name);
			if (t != null) { ps.remove(t, true); texts.remove(name); }
		});

		interp.variables.set('setTextSize', function(name:String, size:Int):Void
		{
			final t = texts.get(name);
			if (t != null) t.size = size;
		});

		interp.variables.set('setTextFont', function(name:String, font:String):Void
		{
			final t = texts.get(name);
			if (t == null) return;
			// Try to resolve font from mod, fall back to raw string
			final fontPath = mods.ModPaths.font(font);
			t.font = (fontPath != null && fontPath.length > 0) ? fontPath : font;
		});

		interp.variables.set('setTextColor', function(name:String, color:String):Void
		{
			final t = texts.get(name);
			if (t != null) t.color = FlxColor.fromString('#$color');
		});

		// setTextBorder(name, borderSize, borderColor)
		interp.variables.set('setTextBorder', function(name:String, size:Float, color:String):Void
		{
			final t = texts.get(name);
			if (t == null) return;
			t.borderStyle = FlxTextBorderStyle.OUTLINE;  // FIX: was FlxText.FlxTextBorderStyle
			t.borderColor = FlxColor.fromString('#$color');
			t.borderSize  = size;
		});

		interp.variables.set('setTextAlignment', function(name:String, align:String):Void
		{
			final t = texts.get(name);
			if (t == null) return;
			t.alignment = switch (align.toLowerCase()) {  // FIX: was FlxText.FlxTextAlign.*
				case 'center': FlxTextAlign.CENTER;
				case 'right':  FlxTextAlign.RIGHT;
				default:       FlxTextAlign.LEFT;
			};
		});

		interp.variables.set('setTextString', function(name:String, text:String):Void
		{
			final t = texts.get(name);
			if (t != null) t.text = text;
		});

		interp.variables.set('getTextString', function(name:String):String
		{
			final t = texts.get(name);
			return t != null ? t.text : '';
		});

		// ── Sprites ───────────────────────────────────────────────────────────

		interp.variables.set('makeLuaSprite', function(name:String, ?image:String, ?x:Float, ?y:Float):Void
		{
			if (sprites.exists(name)) return;
			final spr = new FlxSprite(x ?? 0, y ?? 0);
			if (image != null && image.trim() != '')
			{
				final imgPath = mods.ModPaths.image(image);
				// BUG FIX: use disk-loading so mod files (not in asset registry) are found
				if (imgPath != null) _loadBitmapFromDisk(spr, imgPath);
			}
			sprites.set(name, spr);
		});

		interp.variables.set('makeAnimatedLuaSprite', function(name:String, ?image:String, ?x:Float, ?y:Float):Void
		{
			if (sprites.exists(name)) return;
			final spr = new animationdata.FunkinSprite(x ?? 0, y ?? 0);
			if (image != null && image.trim() != '')
			{
				final imgPath = mods.ModPaths.image(image);
				if (imgPath != null)
				{
					final xmlPath = mods.ModPaths.resolve('images/$image.xml');
					// BUG FIX: load bitmap from disk, read XML as text, avoids asset-registry errors
					try {
						#if sys
						final bd = _bitmapFromDisk(imgPath);
						if (bd != null && sys.FileSystem.exists(xmlPath))
						{
							spr.frames = FlxAtlasFrames.fromSparrow(bd, sys.io.File.getContent(xmlPath));
						}
						else if (bd != null)
						{
							spr.loadGraphic(bd);
						}
						else
						{
							spr.frames = FlxAtlasFrames.fromSparrow(imgPath, xmlPath);
						}
						#else
						spr.frames = FlxAtlasFrames.fromSparrow(imgPath, xmlPath);
						#end
					}
					catch(_) { _loadBitmapFromDisk(spr, imgPath); }
				}
			}
			sprites.set(name, cast spr);
		});

		interp.variables.set('makeGraphic', function(name:String, width:Int, height:Int, color:String, ?x:Float, ?y:Float):Void
		{
			if (sprites.exists(name)) return;
			final spr = new FlxSprite(x ?? 0, y ?? 0);
			spr.makeGraphic(width, height, FlxColor.fromString('#$color'));
			sprites.set(name, spr);
		});

		interp.variables.set('addLuaSprite', function(name:String, ?front:Bool):Void
		{
			final ps = funkin.gameplay.PlayState.instance;
			if (ps == null) return;
			final spr = sprites.get(name);
			if (spr == null) return;
			ps.add(spr);
		});

		interp.variables.set('removeLuaSprite', function(name:String):Void
		{
			final ps = funkin.gameplay.PlayState.instance;
			if (ps == null) return;
			final spr = sprites.get(name);
			if (spr != null) { ps.remove(spr, true); sprites.remove(name); }
		});

		interp.variables.set('getLuaObject', function(name:String):Dynamic
		{
			if (sprites.exists(name)) return sprites.get(name);
			if (texts.exists(name))   return texts.get(name);
			return null;
		});

		// ── Object manipulation ───────────────────────────────────────────────

		interp.variables.set('scaleObject', function(name:String, x:Float, y:Float):Void
		{
			final obj = _obj(name, sprites, texts, interp);
			if (obj != null) obj.scale.set(x, y);
		});

		interp.variables.set('setScrollFactor', function(name:String, x:Float, y:Float):Void
		{
			final obj = _obj(name, sprites, texts, interp);
			if (obj != null) obj.scrollFactor.set(x, y);
		});

		interp.variables.set('setObjectCamera', function(name:String, cam:String):Void
		{
			final ps = funkin.gameplay.PlayState.instance;
			if (ps == null) return;
			final obj = _obj(name, sprites, texts, interp);
			if (obj == null) return;
			final camera = switch ((cam ?? 'hud').toLowerCase()) {
				case 'camgame', 'game': ps.camGame;
				default:                ps.camHUD;
			};
			obj.cameras = [camera];
		});

		interp.variables.set('screenCenter', function(name:String, ?axis:String):Void
		{
			final obj = _obj(name, sprites, texts, interp);
			if (obj == null) return;
			switch ((axis ?? 'xy').toLowerCase()) {
				case 'x':  obj.screenCenter(FlxAxes.X);   // FIX: screenCenter() requires FlxAxes arg
				case 'y':  obj.screenCenter(FlxAxes.Y);
				default:   obj.screenCenter(FlxAxes.XY);
			}
		});

		interp.variables.set('objectExists', function(name:String):Bool
			return sprites.exists(name) || texts.exists(name));

		interp.variables.set('setVisible', function(name:String, v:Bool):Void
		{
			final obj = _obj(name, sprites, texts, interp);
			if (obj != null) obj.visible = v;
		});

		interp.variables.set('setAlpha', function(name:String, v:Float):Void
		{
			final obj = _obj(name, sprites, texts, interp);
			if (obj != null) obj.alpha = v;
		});

		interp.variables.set('setAngle', function(name:String, v:Float):Void
		{
			final obj = _obj(name, sprites, texts, interp);
			if (obj != null) obj.angle = v;
		});

		interp.variables.set('setX', function(name:String, v:Float):Void
		{
			final obj = _obj(name, sprites, texts, interp);
			if (obj != null) obj.x = v;
		});

		interp.variables.set('setY', function(name:String, v:Float):Void
		{
			final obj = _obj(name, sprites, texts, interp);
			if (obj != null) obj.y = v;
		});

		// ── Animations ────────────────────────────────────────────────────────

		interp.variables.set('playAnim', function(name:String, anim:String, ?force:Bool):Void
		{
			final obj = _obj(name, sprites, texts, interp);
			if (obj == null) return;
			try { obj.animation.play(anim, force ?? false); } catch(_) {}
		});

		// BUG FIX: Psych uses objectPlayAnimation(), not playAnim() — was missing entirely
		interp.variables.set('objectPlayAnimation', function(name:String, anim:String, ?force:Bool):Void
		{
			final obj = _obj(name, sprites, texts, interp);
			if (obj == null) return;
			try { obj.animation.play(anim, force ?? false); } catch(_) {}
		});

		interp.variables.set('getAnimationName', function(name:String):String
		{
			final obj = _obj(name, sprites, texts, interp);
			if (obj == null) return '';
			try {
				final curAnim = obj.animation?.curAnim;
				return curAnim != null ? (curAnim.name ?? '') : '';
			} catch(_) { return ''; }
		});

		interp.variables.set('addAnimationByPrefix', function(name:String, animName:String, prefix:String, ?fps:Float, ?loop:Bool):Void
		{
			final obj = _obj(name, sprites, texts, interp);
			if (obj == null) return;
			try { obj.animation.addByPrefix(animName, prefix, fps ?? 24, loop ?? false); } catch(_) {}
		});

		interp.variables.set('addAnimationByIndices', function(name:String, animName:String, prefix:String, indices:Array<Int>, ?fps:Float, ?loop:Bool):Void
		{
			final obj = _obj(name, sprites, texts, interp);
			if (obj == null) return;
			try { obj.animation.addByIndices(animName, prefix, indices, '', fps ?? 24, loop ?? false); } catch(_) {}
		});

		// ── Tweens ────────────────────────────────────────────────────────────

		interp.variables.set('doTweenX', function(tag:String, name:String, to:Float, time:Float, ?ease:String):Void
		{
			final obj = _obj(name, sprites, texts, interp);
			if (obj == null) return;
			_cancelTween(tag, tweens);
			tweens.set(tag, FlxTween.tween(obj, {x: to}, time,
				{ease: _ease(ease), onComplete: function(_) tweens.remove(tag)}));
		});

		interp.variables.set('doTweenY', function(tag:String, name:String, to:Float, time:Float, ?ease:String):Void
		{
			final obj = _obj(name, sprites, texts, interp);
			if (obj == null) return;
			_cancelTween(tag, tweens);
			tweens.set(tag, FlxTween.tween(obj, {y: to}, time,
				{ease: _ease(ease), onComplete: function(_) tweens.remove(tag)}));
		});

		interp.variables.set('doTweenAlpha', function(tag:String, name:String, to:Float, time:Float, ?ease:String):Void
		{
			final obj = _obj(name, sprites, texts, interp);
			if (obj == null) return;
			_cancelTween(tag, tweens);
			tweens.set(tag, FlxTween.tween(obj, {alpha: to}, time,
				{ease: _ease(ease), onComplete: function(_) tweens.remove(tag)}));
		});

		interp.variables.set('doTweenAngle', function(tag:String, name:String, to:Float, time:Float, ?ease:String):Void
		{
			final obj = _obj(name, sprites, texts, interp);
			if (obj == null) return;
			_cancelTween(tag, tweens);
			tweens.set(tag, FlxTween.tween(obj, {angle: to}, time,
				{ease: _ease(ease), onComplete: function(_) tweens.remove(tag)}));
		});

		// doTweenColor(tag, obj, time, fromColor, toColor, ease)  — Psych order
		interp.variables.set('doTweenColor', function(tag:String, name:String, time:Float, fromColor:String, toColor:String, ?ease:String):Void
		{
			final obj = _obj(name, sprites, texts, interp);
			if (obj == null) return;
			_cancelTween(tag, tweens);
			final fromC = FlxColor.fromString('#$fromColor');
			final toC   = FlxColor.fromString('#$toColor');
			tweens.set(tag, FlxTween.color(obj, time, fromC, toC,
				{ease: _ease(ease), onComplete: function(_) tweens.remove(tag)}));
		});

		interp.variables.set('cancelTween', function(tag:String):Void
			_cancelTween(tag, tweens));

		// ── Sound / music ─────────────────────────────────────────────────────

		interp.variables.set('playSound', function(sound:String, ?volume:Float):Void
		{
			final path = mods.ModPaths.sound(sound) ?? sound;
			FlxG.sound.play(path, volume ?? 1.0);
		});

		interp.variables.set('playMusic', function(music:String, ?volume:Float, ?loop:Bool):Void
		{
			final path = mods.ModPaths.music(music) ?? music;
			FlxG.sound.playMusic(path, volume ?? 1.0, loop ?? true);
		});

		// ── Camera ────────────────────────────────────────────────────────────

		interp.variables.set('shakeCamera', function(?cam:String, ?intensity:Float, ?duration:Float):Void
		{
			final c = _camera(cam);
			if (c != null) c.shake(intensity ?? 0.01, duration ?? 0.3);
		});

		interp.variables.set('flashCamera', function(?cam:String, ?duration:Float, ?color:String, ?force:Bool):Void
		{
			final c = _camera(cam);
			if (c != null)
				c.flash(color != null ? FlxColor.fromString('#$color') : FlxColor.WHITE,
				        duration ?? 0.3, null, force ?? false);
		});

		// ── String helpers (Psych compat) ─────────────────────────────────────

		interp.variables.set('stringStartsWith', function(s:String, prefix:String):Bool
			return s != null && prefix != null && s.startsWith(prefix));

		interp.variables.set('stringEndsWith', function(s:String, suffix:String):Bool
			return s != null && suffix != null && s.endsWith(suffix));

		interp.variables.set('stringSplit', function(s:String, delim:String):Array<String>
			return s != null ? s.split(delim) : []);

		interp.variables.set('stringTrim', function(s:String):String
			return s != null ? s.trim() : '');

		// ── Debug ─────────────────────────────────────────────────────────────

		interp.variables.set('debugPrint', function(v:Dynamic, ?color:Dynamic):Void
			trace('[PsychLua] ${Std.string(v)}'));

		interp.variables.set('luaDebugMode', false);

		// ── Psych convenience shortcuts (read-only via closures) ──────────────
		// These shadow the same-named globals set later by PlayState.setOnScripts()
		// only if needed for early top-level code. After PlayState init the real
		// objects are set via setOnScripts and accessible directly as plain vars.

		interp.variables.set('iconP1', function():Dynamic {
			final ps = funkin.gameplay.PlayState.instance;
			return (ps?.uiManager != null) ? ps.uiManager.iconP1 : null;
		});

		interp.variables.set('iconP2', function():Dynamic {
			final ps = funkin.gameplay.PlayState.instance;
			return (ps?.uiManager != null) ? ps.uiManager.iconP2 : null;
		});

		interp.variables.set('healthBar', function():Dynamic {
			final ps = funkin.gameplay.PlayState.instance;
			if (ps?.uiManager == null) return null;
			return Reflect.field(ps.uiManager, 'healthBar');
		});
	}

	/**
	 * Sets up callback aliases after the script has been executed (functions defined).
	 *
	 * Must be called AFTER script.interp.execute(script.program) and BEFORE
	 * the first script.call('onCreate').
	 *
	 * Aliases created:
	 *   goodNoteHit(i,d,t,s) → callable as onNoteHit(note)
	 *   opponentNoteHit(i,d,t,s) → callable as onOpponentNoteHit(note)
	 *   missNote / noteMiss / onMissNote(d) → callable as onNoteMiss(note)
	 *   onCreatePost → callable as postCreate
	 *   playerStrumsGroup → also accessible as playerStrums
	 *   cpuStrumsGroup    → also accessible as opponentStrums
	 */
	public static function setupCallbackAliases(script:HScriptInstance):Void
	{
		#if HSCRIPT_ALLOWED
		if (script?.interp == null) return;
		final v = script.interp.variables;

		// ── onCreatePost → postCreate ─────────────────────────────────────────
		if (v.exists('onCreatePost') && !v.exists('postCreate'))
			v.set('postCreate', v.get('onCreatePost'));

		// ── onBeatHit (no-arg Psych style) ────────────────────────────────────
		// If the script defined onBeatHit() with no args, wrap it so curBeat
		// is available from Conductor when the engine calls onBeatHit(curBeat).
		if (v.exists('onBeatHit') && Reflect.isFunction(v.get('onBeatHit')))
		{
			final orig = v.get('onBeatHit');
			// Peek at arity: if the function expects 0 args, wrap it
			v.set('onBeatHit', function(curBeat:Int):Void {
				try { Reflect.callMethod(null, orig, [curBeat]); } catch(_) {
					try { Reflect.callMethod(null, orig, []); } catch(_) {}
				}
			});
		}

		// ── goodNoteHit → onNoteHit ───────────────────────────────────────────
		if (v.exists('goodNoteHit') && Reflect.isFunction(v.get('goodNoteHit')))
		{
			final gnh = v.get('goodNoteHit');
			if (!v.exists('onNoteHit'))
			{
				v.set('onNoteHit', function(note:Dynamic):Void {
					try {
						final idx:Int     = Reflect.field(note, '_id')           ?? 0;
						final dir:Int     = Reflect.field(note, 'noteData')      ?? 0;
						final type:String = Reflect.field(note, 'noteType')      ?? '';
						final sus:Bool    = Reflect.field(note, 'isSustainNote') ?? false;
						Reflect.callMethod(null, gnh, [idx, dir, type, sus]);
					} catch(_) {}
				});
			}
		}

		// ── opponentNoteHit → onOpponentNoteHit ──────────────────────────────
		if (v.exists('opponentNoteHit') && Reflect.isFunction(v.get('opponentNoteHit')))
		{
			final onh = v.get('opponentNoteHit');
			if (!v.exists('onOpponentNoteHit'))
			{
				v.set('onOpponentNoteHit', function(note:Dynamic):Void {
					try {
						final idx:Int     = Reflect.field(note, '_id')           ?? 0;
						final dir:Int     = Reflect.field(note, 'noteData')      ?? 0;
						final type:String = Reflect.field(note, 'noteType')      ?? '';
						final sus:Bool    = Reflect.field(note, 'isSustainNote') ?? false;
						Reflect.callMethod(null, onh, [idx, dir, type, sus]);
					} catch(_) {}
				});
			}
		}

		// ── missNote / noteMiss / onMissNote → onNoteMiss ────────────────────
		for (name in ['missNote', 'noteMiss', 'onMissNote'])
		{
			if (v.exists(name) && Reflect.isFunction(v.get(name)))
			{
				if (!v.exists('onNoteMiss'))
				{
					final fn = v.get(name);
					v.set('onNoteMiss', function(note:Dynamic):Void {
						try {
							final dir:Int = Reflect.field(note, 'noteData') ?? 0;
							Reflect.callMethod(null, fn, [dir]);
						} catch(_) {}
					});
				}
				break;
			}
		}

		// ── Strums aliases ────────────────────────────────────────────────────
		// PlayState.setOnScripts() sets playerStrumsGroup / cpuStrumsGroup.
		// If they're already set at this point, create Psych-style aliases.
		if (v.exists('playerStrumsGroup') && v.get('playerStrumsGroup') != null)
			v.set('playerStrums', v.get('playerStrumsGroup'));
		if (v.exists('cpuStrumsGroup') && v.get('cpuStrumsGroup') != null)
			v.set('opponentStrums', v.get('cpuStrumsGroup'));

		#end
	}

	// ─── Private helpers ─────────────────────────────────────────────────────

	/**
	 * Resolves a dot-path (with optional [n] array notation) starting from
	 * PlayState, then falling back to script interpreter variables.
	 *
	 * Examples:
	 *   'boyfriend'                     → PlayState.instance.boyfriend
	 *   'boyfriend.holdTimer'           → PlayState.instance.boyfriend.holdTimer
	 *   'playerStrums.members[2]'       → PlayState.instance.playerStrumsGroup.members[2]
	 *   'unspawnNotes.length'           → PlayState.instance.unspawnNotes.length
	 */
	static function _getReflect(path:String, interp:Interp):Dynamic
	{
		if (path == null) return null;
		final ps = funkin.gameplay.PlayState.instance;

		// Special aliases: Psych uses different field names for some objects
		final resolved = _psychAlias(path);

		// Start from PlayState, or fall back to interpreter scope for the root segment
		final dotIdx = resolved.indexOf('.');
		final rootName = dotIdx >= 0 ? resolved.substr(0, dotIdx) : resolved;

		// Try PlayState field first, then interpreter variable, then uiManager
		var root:Dynamic = null;
		if (ps != null)
		{
			root = Reflect.field(ps, rootName);
			if (root == null && ps.uiManager != null)
				root = Reflect.field(ps.uiManager, rootName);
		}
		if (root == null) root = interp?.variables?.get(rootName);
		if (root == null) return null;

		if (dotIdx < 0) return root;
		return _walkPath(root, resolved.substr(dotIdx + 1));
	}

	static function _setReflect(path:String, value:Dynamic, interp:Interp):Void
	{
		final resolved = _psychAlias(path);
		final dotIdx   = resolved.lastIndexOf('.');
		if (dotIdx < 0)
		{
			// Top-level field on PlayState
			final ps = funkin.gameplay.PlayState.instance;
			if (ps != null) try { Reflect.setField(ps, resolved, value); return; } catch(_) {}
			// Fallback: interpreter variable
			interp?.variables?.set(resolved, value);
			return;
		}
		final parentPath = resolved.substr(0, dotIdx);
		final fieldName  = resolved.substr(dotIdx + 1);
		final parent     = _getReflect(parentPath, interp);
		if (parent == null) return;
		try { Reflect.setField(parent, fieldName, value); } catch(_) {}
	}

	/**
	 * Walks a dot-path (may contain [n] brackets) from a given root object.
	 * Returns null safely on any error.
	 */
	static function _walkPath(root:Dynamic, path:String):Dynamic
	{
		if (root == null || path == null || path == '') return root;
		var obj:Dynamic = root;
		for (seg in path.split('.'))
		{
			if (obj == null) return null;
			final bk = seg.indexOf('[');
			if (bk >= 0)
			{
				// e.g. "members[2]"
				final field   = seg.substr(0, bk);
				final closeB  = seg.indexOf(']');
				final idxStr  = seg.substr(bk + 1, closeB - bk - 1);
				final idx     = Std.parseInt(idxStr);
				if (field.length > 0)
					try { obj = Reflect.field(obj, field); } catch(_) { return null; }
				if (obj == null) return null;
				obj = _getIdx(obj, idx ?? 0);
			}
			else
			{
				try { obj = Reflect.field(obj, seg); } catch(_) { return null; }
			}
		}
		return obj;
	}

	static function _setPath(root:Dynamic, path:String, value:Dynamic):Void
	{
		final dotIdx = path.lastIndexOf('.');
		if (dotIdx < 0)
		{
			try { Reflect.setField(root, path, value); } catch(_) {}
			return;
		}
		final parent = _walkPath(root, path.substr(0, dotIdx));
		if (parent == null) return;
		try { Reflect.setField(parent, path.substr(dotIdx + 1), value); } catch(_) {}
	}

	/** Returns element at index `idx` of a FlxGroup, Array, or object with .members. */
	static function _getIdx(obj:Dynamic, idx:Int):Dynamic
	{
		if (Std.isOfType(obj, Array))
			return (cast obj:Array<Dynamic>)[idx];
		final members = try Reflect.field(obj, 'members') catch(_) null;
		if (members != null && Std.isOfType(members, Array))
			return (cast members:Array<Dynamic>)[idx];
		return null;
	}

	/** Returns the `idx`-th member of a group/array obtained via path. */
	static function _getMember(grp:Dynamic, idx:Int):Dynamic
	{
		if (Std.isOfType(grp, Array)) return (cast grp:Array<Dynamic>)[idx];
		final members = try Reflect.field(grp, 'members') catch(_) null;
		if (members != null && Std.isOfType(members, Array))
			return (cast members:Array<Dynamic>)[idx];
		return null;
	}

	/** Translates Psych field name aliases to Cool Engine equivalents. */
	static function _psychAlias(path:String):String
	{
		// Only rename the ROOT segment (before the first dot/bracket)
		final dotIdx = path.indexOf('.');
		final bkIdx  = path.indexOf('[');
		final end    = (dotIdx >= 0 && bkIdx >= 0) ? Std.int(Math.min(dotIdx, bkIdx))
		             : (dotIdx >= 0) ? dotIdx
		             : (bkIdx  >= 0) ? bkIdx : path.length;
		final root   = path.substr(0, end);
		final rest   = path.substr(end);
		final alias  = switch (root) {
			case 'playerStrums':   'playerStrumsGroup';
			case 'opponentStrums': 'cpuStrumsGroup';
			default: root;
		};
		return alias + rest;
	}

	/**
	 * Gets a local sprite/text by name; if not found, tries reflection on
	 * PlayState (for e.g. 'boyfriend', 'iconP1', 'healthBar' paths).
	 */
	static function _obj(name:String,
	                      sprites:Map<String, FlxSprite>,
	                      texts:Map<String, FlxText>,
	                      interp:Interp):Dynamic
	{
		if (sprites.exists(name)) return sprites.get(name);
		if (texts.exists(name))   return texts.get(name);
		return _getReflect(name, interp);
	}

	static function _camera(?cam:String):flixel.FlxCamera
	{
		final ps = funkin.gameplay.PlayState.instance;
		if (ps == null) return null;
		return switch ((cam ?? 'game').toLowerCase()) {
			case 'camhud', 'hud': ps.camHUD;
			default:              ps.camGame;
		};
	}

	static function _ease(?ease:String):Dynamic
	{
		if (ease == null) return FlxEase.linear;
		return switch (ease.toLowerCase()) {
			case 'linear':                    FlxEase.linear;
			case 'quadin',  'quad':           FlxEase.quadIn;
			case 'quadout':                   FlxEase.quadOut;
			case 'quadinout':                 FlxEase.quadInOut;
			case 'cubein',  'cube':           FlxEase.cubeIn;
			case 'cubeout':                   FlxEase.cubeOut;
			case 'cubeinout':                 FlxEase.cubeInOut;
			case 'elasticin', 'elastic':      FlxEase.elasticIn;
			case 'elasticout':                FlxEase.elasticOut;
			case 'sinein', 'sine':            FlxEase.sineIn;
			case 'sineout':                   FlxEase.sineOut;
			case 'sineinout':                 FlxEase.sineInOut;
			case 'bounceout', 'bounce':       FlxEase.bounceOut;
			case 'bouncein':                  FlxEase.bounceIn;
			case 'backout', 'back':           FlxEase.backOut;
			case 'backin':                    FlxEase.backIn;
			default:                          FlxEase.linear;
		};
	}

	static inline function _cancelTween(tag:String, tweens:Map<String, FlxTween>):Void
	{
		final t = tweens.get(tag);
		if (t != null) { t.cancel(); tweens.remove(tag); }
	}

	/**
	 * BUG FIX: Loads a BitmapData directly from disk using Lime, bypassing
	 * OpenFL's asset registry (which doesn't know about mod files).
	 * Returns null if file doesn't exist or load fails.
	 */
	static function _bitmapFromDisk(path:String):Null<openfl.display.BitmapData>
	{
		#if sys
		if (!sys.FileSystem.exists(path)) return null;
		try {
			final limeImg = lime.graphics.Image.fromFile(path);
			if (limeImg != null) return openfl.display.BitmapData.fromImage(limeImg);
		} catch (_) {}
		#end
		return null;
	}

	/**
	 * Loads a static graphic onto a sprite from disk, falling back to
	 * Flixel's asset system if disk loading fails.
	 */
	static function _loadBitmapFromDisk(spr:FlxSprite, path:String):Void
	{
		final bd = _bitmapFromDisk(path);
		if (bd != null) { spr.loadGraphic(bd); return; }
		// Fallback — may still error but surfaces the problem in logs
		try { spr.loadGraphic(path); } catch (e:Dynamic)
			trace('[PsychLuaGameplayAPI] Could not load image "$path": $e');
	}

	#end // HSCRIPT_ALLOWED
}
