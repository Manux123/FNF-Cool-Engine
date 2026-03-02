package funkin.scripting;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.FlxObject;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.sound.FlxSound;
import funkin.transitions.StateTransition;
import funkin.transitions.StickerTransition;
import funkin.scripting.ScriptableState.ScriptableSubState;

#if HSCRIPT_ALLOWED
import hscript.Interp;
#end

/**
 * ScriptAPI v6 — API COMPLETA expuesta a los scripts HScript.
 *
 * ─── Nuevas categorías en v6 ─────────────────────────────────────────────────
 *  `Mathf`         — proxy de funkin.data.Mathf (todas las funciones matemáticas)
 *  `CoolUtil`      — utilidades generales (texto, arrays, dificultad)
 *  `CameraUtil`    — control avanzado de cámaras y filtros/shaders en cámara
 *  `add` / `remove`— añadir/quitar sprites del juego directamente
 *  `stage`         — acceso completo al stage actual (elementos, grupos, sonidos)
 *  `noteManager`   — acceso al NoteManager del PlayState
 *  `input`         — acceso al InputHandler (teclas presionadas, held, etc.)
 *  `VideoManager`  — reproducción de vídeos/cutscenes desde script
 *  `Highscore`     — guardar y leer scores desde script
 *  `Ranking`       — letra de ranking del run actual
 *  `CharacterList` — listas de personajes y stages disponibles
 *  `PlayStateConfig` — constantes de timing, zoom, health, etc.
 *  `FlxAnimate`    — soporte de Texture Atlas animados
 *  `FlxSound`      — clase de sonido de Flixel
 *  `FlxCamera`     — clase de cámara de Flixel
 *  `FlxObject`     — objeto base de Flixel
 *  `FlxBackdrop`   — fondo de scroll infinito
 *  `transition`    — control de transiciones de pantalla
 *  `MetaData`      — metadatos de la canción actual
 *  `GlobalConfig`  — configuración global del engine
 *  `ScriptHandler` — acceso a scripts desde scripts (callOnScripts, etc.)
 *  `EventManager`  — sistema de eventos del chart
 *  `CharacterController` — controller de personajes del PlayState
 *  `CameraController`    — controller de cámara del PlayState
 *
 * ─── Compatibilidad total con v4/v5 ──────────────────────────────────────────
 *  Todos los objetos y funciones previos siguen disponibles sin cambios.
 *
 * @author Cool Engine Team
 * @version 6.0.0
 */
class ScriptAPI
{
	#if HSCRIPT_ALLOWED

	public static function expose(interp:Interp):Void
	{
		// ── v1-v5 (sin cambios de interfaz) ───────────────────────────────────
		exposeFlixel(interp);
		exposeGameplay(interp);
		exposeScoring(interp);
		exposeNoteTypes(interp);
		exposeStates(interp);
		exposeSignals(interp);
		exposeStorage(interp);
		exposeImport(interp);
		exposeMath(interp);
		exposeArray(interp);
		exposeShaders(interp);
		exposeWindow(interp);
		exposeVisibility(interp);
		exposeUtils(interp);
		exposeEvents(interp);
		exposeDebug(interp);
		exposeMod(interp);
		exposeCharacters(interp);
		exposeCamera(interp);
		exposeHUD(interp);
		exposeStrums(interp);
		exposeModChart(interp);
		// ── NUEVO v6 ──────────────────────────────────────────────────────────
		exposeMathf(interp);          // proxy completo de funkin.data.Mathf
		exposeCoolUtil(interp);       // utilidades generales
		exposeCameraUtil(interp);     // control avanzado de cámaras
		exposeAddRemove(interp);      // add() / remove() directos
		exposeStageAccess(interp);    // stage.getElement(), stage.getGroup(), etc.
		exposeNoteManagerAccess(interp); // noteManager completo
		exposeInputAccess(interp);    // input.held[], input.pressed[], etc.
		exposeVideoManager(interp);   // VideoManager cutscenes
		exposeHighscore(interp);      // Highscore.saveScore(), etc.
		exposeRanking(interp);        // Ranking.generateLetterRank()
		exposeCharacterList(interp);  // CharacterList.boyfriends, etc.
		exposePlayStateConfig(interp); // constantes de timing/zoom/health
		exposeTransition(interp);     // control de transiciones
		exposeControllers(interp);    // CharacterController y CameraController
		exposeMetaData(interp);       // MetaData de la canción
		exposeGlobalConfig(interp);   // GlobalConfig del engine
		exposeScriptHandler(interp);  // ScriptHandler (callOnScripts, etc.)
		exposeCountdown(interp);      // Countdown del PlayState
		exposeModPaths(interp);       // ModPaths completo
	}

	// ─── Flixel core ──────────────────────────────────────────────────────────

	static function exposeFlixel(interp:Interp):Void
	{
		interp.variables.set('FlxG',           FlxG);
		interp.variables.set('FlxSprite',      FlxSprite);
		interp.variables.set('FlxTween',       FlxTween);
		interp.variables.set('FlxEase',        _flxEaseProxy());
		interp.variables.set('FlxColor',       _flxColorProxy());
		interp.variables.set('FlxTimer',       FlxTimer);
		interp.variables.set('FlxSound',       FlxSound);
		interp.variables.set('FlxCamera',      FlxCamera);
		interp.variables.set('FlxObject',      FlxObject);
		interp.variables.set('FunkinSprite',   animationdata.FunkinSprite);

		// Tipos adicionales
		interp.variables.set('FlxText',          flixel.text.FlxText);
		interp.variables.set('FlxGroup',         flixel.group.FlxGroup);
		interp.variables.set('FlxSpriteGroup',   flixel.group.FlxSpriteGroup);
		interp.variables.set('FlxTypedGroup',    flixel.group.FlxGroup.FlxTypedGroup);

		// FlxAnimate (Texture Atlas)
		try {
			final flxAnimate = Type.resolveClass('flxanimate.FlxAnimate');
			if (flxAnimate != null) interp.variables.set('FlxAnimate', flxAnimate);
		} catch(_) {}

		// FlxBackdrop (fondo de scroll infinito) — en flixel-addons si existe
		try {
			final backdrop = Type.resolveClass('flixel.addons.display.FlxBackdrop');
			if (backdrop != null) interp.variables.set('FlxBackdrop', backdrop);
		} catch(_) {}

		// FlxTrail — en flixel-addons si el proyecto lo incluye
		try {
			final trail = Type.resolveClass('flixel.addons.effects.FlxTrail');
			if (trail != null) interp.variables.set('FlxTrail', trail);
		} catch(_) {}

		// BUGFIX inline: proxy de FlxMath para evitar "Null Function Pointer"
		interp.variables.set('FlxMath', {
			lerp          : function(a:Float, b:Float, ratio:Float):Float return a + (b - a) * ratio,
			fastSin       : function(angle:Float):Float return Math.sin(angle),
			fastCos       : function(angle:Float):Float return Math.cos(angle),
			remapToRange  : flixel.math.FlxMath.remapToRange,
			bound         : flixel.math.FlxMath.bound,
			roundDecimal  : flixel.math.FlxMath.roundDecimal,
			isOdd         : flixel.math.FlxMath.isOdd,
			isEven        : flixel.math.FlxMath.isEven,
			dotProduct    : flixel.math.FlxMath.dotProduct,
			vectorLength  : flixel.math.FlxMath.vectorLength,
			MIN_VALUE_INT  : flixel.math.FlxMath.MIN_VALUE_INT,
			MAX_VALUE_INT  : flixel.math.FlxMath.MAX_VALUE_INT,
			MIN_VALUE_FLOAT: flixel.math.FlxMath.MIN_VALUE_FLOAT,
			MAX_VALUE_FLOAT: flixel.math.FlxMath.MAX_VALUE_FLOAT
		});

		interp.variables.set('FlxPoint',   _flxPointProxy());
		interp.variables.set('FlxRect',    _flxRectProxy());
		interp.variables.set('FlxAngle',   flixel.math.FlxAngle);

		// OpenFL
		interp.variables.set('BitmapData', openfl.display.BitmapData);
		interp.variables.set('Sound',      openfl.media.Sound);
	}

	// ─── Gameplay ─────────────────────────────────────────────────────────────

	static function exposeGameplay(interp:Interp):Void
	{
		interp.variables.set('PlayState',       funkin.gameplay.PlayState);
		interp.variables.set('game',            funkin.gameplay.PlayState.instance);
		interp.variables.set('Conductor',       funkin.data.Conductor);
		interp.variables.set('Paths',           Paths);
		interp.variables.set('MetaData',        funkin.data.MetaData);
		interp.variables.set('GlobalConfig',    funkin.data.GlobalConfig);
		interp.variables.set('Song',            funkin.data.Song);
		interp.variables.set('Note',            funkin.gameplay.notes.Note);
		interp.variables.set('NoteSkinSystem',  funkin.gameplay.notes.NoteSkinSystem);
		interp.variables.set('NotePool',        funkin.gameplay.notes.NotePool);
		interp.variables.set('NoteTypeManager', funkin.gameplay.notes.NoteTypeManager);
		interp.variables.set('ModManager',      mods.ModManager);
		interp.variables.set('ModPaths',        mods.ModPaths);
		interp.variables.set('ShaderManager',   _shaderManagerProxy());
		interp.variables.set('ModChartManager', funkin.gameplay.modchart.ModChartManager);
		interp.variables.set('ModChartHelpers', funkin.gameplay.modchart.ModChartEvent.ModChartHelpers);

		interp.variables.set('ModEventType', {
			MOVE_X   : "moveX",   MOVE_Y   : "moveY",
			ANGLE    : "angle",   ALPHA    : "alpha",
			SCALE    : "scale",   SCALE_X  : "scaleX",    SCALE_Y  : "scaleY",
			SPIN     : "spin",    RESET    : "reset",
			SET_ABS_X: "setAbsX", SET_ABS_Y: "setAbsY",
			VISIBLE  : "visible"
		});
		interp.variables.set('ModEase', {
			LINEAR    : "linear",
			QUAD_IN   : "quadIn",    QUAD_OUT   : "quadOut",    QUAD_IN_OUT  : "quadInOut",
			CUBE_IN   : "cubeIn",    CUBE_OUT   : "cubeOut",    CUBE_IN_OUT  : "cubeInOut",
			SINE_IN   : "sineIn",    SINE_OUT   : "sineOut",    SINE_IN_OUT  : "sineInOut",
			ELASTIC_IN: "elasticIn", ELASTIC_OUT: "elasticOut",
			BOUNCE_OUT: "bounceOut",
			BACK_IN   : "backIn",    BACK_OUT   : "backOut",
			INSTANT   : "instant"
		});
	}

	// ─── Scoring custom ───────────────────────────────────────────────────────

	static function exposeScoring(interp:Interp):Void
	{
		interp.variables.set('score', {
			setWindow: function(rating:String, ms:Float) {
				final sm = funkin.gameplay.objects.hud.ScoreManager;
				switch (rating.toLowerCase()) {
					case 'sick':  Reflect.setField(sm, 'SICK_WINDOW',  ms);
					case 'good':  Reflect.setField(sm, 'GOOD_WINDOW',  ms);
					case 'bad':   Reflect.setField(sm, 'BAD_WINDOW',   ms);
					case 'shit':  Reflect.setField(sm, 'SHIT_WINDOW',  ms);
				}
			},
			setPoints: function(rating:String, pts:Int) {
				final sm = funkin.gameplay.objects.hud.ScoreManager;
				switch (rating.toLowerCase()) {
					case 'sick':  Reflect.setField(sm, 'SICK_SCORE',  pts);
					case 'good':  Reflect.setField(sm, 'GOOD_SCORE',  pts);
					case 'bad':   Reflect.setField(sm, 'BAD_SCORE',   pts);
					case 'shit':  Reflect.setField(sm, 'SHIT_SCORE',  pts);
				}
			},
			setMissPenalty: function(penalty:Int) {
				Reflect.setField(funkin.gameplay.objects.hud.ScoreManager, 'MISS_PENALTY', penalty);
			},
			getAccuracy:  function():Float {
				final i = funkin.gameplay.PlayState.instance;
				return i != null ? i.scoreManager.accuracy : 0.0;
			},
			getCombo: function():Int {
				final i = funkin.gameplay.PlayState.instance;
				return i != null ? i.scoreManager.combo : 0;
			},
			getScore: function():Int {
				final i = funkin.gameplay.PlayState.instance;
				return i != null ? i.scoreManager.score : 0;
			},
			getMisses: function():Int {
				final i = funkin.gameplay.PlayState.instance;
				return i != null ? i.scoreManager.misses : 0;
			},
			getSicks: function():Int {
				final i = funkin.gameplay.PlayState.instance;
				return i != null ? i.scoreManager.sicks : 0;
			},
			addScore: function(n:Int) {
				final i = funkin.gameplay.PlayState.instance;
				if (i != null) i.scoreManager.score += n;
			},
			resetCombo: function() {
				final i = funkin.gameplay.PlayState.instance;
				if (i != null) { i.scoreManager.combo = 0; i.scoreManager.fullCombo = false; }
			},
			isFullCombo: function():Bool {
				final i = funkin.gameplay.PlayState.instance;
				return i != null ? i.scoreManager.fullCombo : false;
			},
			isSickCombo: function():Bool {
				final i = funkin.gameplay.PlayState.instance;
				return i != null ? i.scoreManager.sickCombo : false;
			},
			onNoteHit: null,
			onMiss:    null
		});
	}

	// ─── NoteTypes ────────────────────────────────────────────────────────────

	static function exposeNoteTypes(interp:Interp):Void
	{
		interp.variables.set('noteTypes', {
			register:   function(name:String, cfg:Dynamic) {
				funkin.gameplay.notes.NoteTypeManager.register(name, cfg);
			},
			unregister: function(name:String) {
				funkin.gameplay.notes.NoteTypeManager.unregister(name);
			},
			exists: function(name:String):Bool {
				return funkin.gameplay.notes.NoteTypeManager.exists(name);
			},
			list: function():Array<String> {
				return funkin.gameplay.notes.NoteTypeManager.getAll();
			}
		});
	}

	// ─── States ───────────────────────────────────────────────────────────────

	static function exposeStates(interp:Interp):Void
	{
		interp.variables.set('states', {
			goto:               function(name:String) { ScriptBridge.switchStateByName(name); },
			open:               function(state:flixel.FlxState) { StateTransition.switchState(state); },
			sticker:            function(state:flixel.FlxState) {
				StickerTransition.start(function() StateTransition.switchState(state));
			},
			load:               function(state:flixel.FlxState) {
				funkin.states.LoadingState.loadAndSwitchState(state);
			},
			openSubState: function(name:String) {
				final ss = new ScriptableSubState(name);
				if (FlxG.state != null) FlxG.state.openSubState(ss);
			},
			openSubStateInstance: function(ss:flixel.FlxSubState) {
				if (FlxG.state != null) FlxG.state.openSubState(ss);
			},
			close: function() { if (FlxG.state != null) FlxG.state.closeSubState(); },
			scripted: function(name:String) {
				final ss = new ScriptableSubState(name);
				if (FlxG.state != null) FlxG.state.openSubState(ss);
			},
			current: function():flixel.FlxState { return FlxG.state; }
		});
	}

	// ─── Signal bus ───────────────────────────────────────────────────────────

	static var _signals    : Map<String, Array<Dynamic>> = [];
	static var _signalsOnce: Map<String, Array<Dynamic>> = [];

	static function exposeSignals(interp:Interp):Void
	{
		interp.variables.set('signal', {
			on:   function(event:String, cb:Dynamic) {
				if (!_signals.exists(event)) _signals.set(event, []);
				_signals.get(event).push(cb);
			},
			once: function(event:String, cb:Dynamic) {
				if (!_signalsOnce.exists(event)) _signalsOnce.set(event, []);
				_signalsOnce.get(event).push(cb);
			},
			off: function(event:String, cb:Dynamic) {
				final arr = _signals.get(event);
				if (arr != null) arr.remove(cb);
			},
			emit: function(event:String, ?data:Dynamic) {
				final arr = _signals.get(event);
				if (arr != null)
					for (cb in arr.copy()) try { Reflect.callMethod(null, cb, [data]); } catch(_) {}
				final once = _signalsOnce.get(event);
				if (once != null) {
					for (cb in once.copy()) try { Reflect.callMethod(null, cb, [data]); } catch(_) {}
					once.resize(0);
				}
			},
			clear:    function(event:String) { _signals.remove(event); _signalsOnce.remove(event); },
			clearAll: function() { _signals.clear(); _signalsOnce.clear(); }
		});
	}

	// ─── Storage ──────────────────────────────────────────────────────────────

	static function exposeStorage(interp:Interp):Void
	{
		interp.variables.set('data', {
			set:    function(key:String, value:Dynamic) { Reflect.setField(FlxG.save.data, key, value); },
			get:    function(key:String, ?fallback:Dynamic):Dynamic {
				final v = Reflect.field(FlxG.save.data, key);
				return v != null ? v : fallback;
			},
			delete: function(key:String) { Reflect.deleteField(FlxG.save.data, key); },
			has:    function(key:String):Bool { return Reflect.hasField(FlxG.save.data, key); },
			save:   function() { FlxG.save.flush(); },
			dump:   function():Dynamic { return FlxG.save.data; }
		});
	}

	// ─── Import dinámico ──────────────────────────────────────────────────────

	static function exposeImport(interp:Interp):Void
	{
		final _flxMathProxy:Dynamic = interp.variables.get('FlxMath');

		final _classRegistry:Map<String, Dynamic> = [
			// Flixel core
			'FlxSprite'         => FlxSprite,
			'FlxText'           => flixel.text.FlxText,
			'FlxG'              => FlxG,
			'FlxTween'          => FlxTween,
			'FlxEase'           => _flxEaseProxy(),
			'FlxColor'          => _flxColorProxy(),
			'FlxTimer'          => FlxTimer,
			'FlxSound'          => FlxSound,
			'FlxCamera'         => FlxCamera,
			'FlxObject'         => FlxObject,
			'FlxMath'           => _flxMathProxy,
			'FlxPoint'          => _flxPointProxy(),
			'FlxRect'           => _flxRectProxy(),
			'FlxSpriteGroup'    => flixel.group.FlxSpriteGroup,
			'FlxGroup'          => flixel.group.FlxGroup,
			'FlxAngle'          => flixel.math.FlxAngle,
			// Extensions del engine
			'FlxAtlasFramesExt' => extensions.FlxAtlasFramesExt,
			'CppAPI'            => extensions.CppAPI,
			// Shaders
			'ShaderManager'     => _shaderManagerProxy(),
			'WaveEffect'        => shaders.WaveEffect,
			'WiggleEffect'      => shaders.WiggleEffect,
			'BlendModeEffect'   => shaders.BlendModeEffect,
			'OverlayShader'     => shaders.OverlayShader,
			// Funkin gameplay
			'PlayState'         => funkin.gameplay.PlayState,
			'Countdown'         => funkin.gameplay.Countdown,
			'GameState'         => funkin.gameplay.GameState,
			'CharacterController' => funkin.gameplay.CharacterController,
			'CameraController'    => funkin.gameplay.CameraController,
			'Conductor'         => funkin.data.Conductor,
			'Note'              => funkin.gameplay.notes.Note,
			'NotePool'          => funkin.gameplay.notes.NotePool,
			'NoteSkinSystem'    => funkin.gameplay.notes.NoteSkinSystem,
			'NoteTypeManager'   => funkin.gameplay.notes.NoteTypeManager,
			'Song'              => funkin.data.Song,
			'MetaData'          => funkin.data.MetaData,
			'GlobalConfig'      => funkin.data.GlobalConfig,
			'CoolUtil'          => funkin.data.CoolUtil,
			'CameraUtil'        => funkin.data.CameraUtil,
			'PlayStateConfig'   => funkin.gameplay.PlayStateConfig,
			'CharacterList'     => funkin.gameplay.objects.character.CharacterList,
			'Highscore'         => funkin.gameplay.objects.hud.Highscore,
			'ModManager'        => mods.ModManager,
			'ModPaths'          => mods.ModPaths,
			'ModChartManager'   => funkin.gameplay.modchart.ModChartManager,
			'FunkinSprite'      => animationdata.FunkinSprite,
			// Transitions
			'StateTransition'   => funkin.transitions.StateTransition,
			'StickerTransition' => funkin.transitions.StickerTransition,
			// Video
			'VideoManager'      => funkin.cutscenes.VideoManager,
			// Scripting
			'ScriptHandler'     => funkin.scripting.ScriptHandler,
			'EventManager'      => funkin.scripting.EventManager,
			// OpenFL
			'BitmapData'        => openfl.display.BitmapData,
			'Sound'             => openfl.media.Sound,
		];

		// Registrar clases opcionales (solo si están en el build)
		try {
			final flxAnimate = Type.resolveClass('flxanimate.FlxAnimate');
			if (flxAnimate != null) _classRegistry.set('FlxAnimate', flxAnimate);
		} catch(_) {}
		try {
			final backdrop = Type.resolveClass('flixel.addons.display.FlxBackdrop');
			if (backdrop != null) _classRegistry.set('FlxBackdrop', backdrop);
		} catch(_) {}
		try {
			final trail = Type.resolveClass('flixel.addons.effects.FlxTrail');
			if (trail != null) _classRegistry.set('FlxTrail', trail);
		} catch(_) {}

		interp.variables.set('importClass', function(className:String):Dynamic {
			if (_classRegistry.exists(className)) return _classRegistry.get(className);
			final resolved = Type.resolveClass(className);
			if (resolved != null) return resolved;
			trace('[ScriptAPI] importClass: "$className" no encontrada.');
			return null;
		});

		interp.variables.set('createInstance', function(className:String, args:Array<Dynamic>):Dynamic {
			final cls = Type.resolveClass(className);
			if (cls == null) { trace('[ScriptAPI] createInstance: "$className" no encontrada.'); return null; }
			return Type.createInstance(cls, args ?? []);
		});
	}

	// ─── Math extendido ───────────────────────────────────────────────────────

	static function exposeMath(interp:Interp):Void
	{
		interp.variables.set('math', {
			// Interpolación
			lerp:       function(a:Float, b:Float, t:Float):Float return a + (b - a) * t,
			lerpSnap:   function(a:Float, b:Float, t:Float, snap:Float):Float {
				final r = a + (b - a) * t;
				return Math.abs(r - b) < snap ? b : r;
			},
			// Rango
			clamp:   function(v:Float, min:Float, max:Float):Float return Math.min(Math.max(v, min), max),
			clampInt: function(v:Int, min:Int, max:Int):Int {
				if (v < min) return min;
				if (v > max) return max;
				return v;
			},
			map:     function(v:Float, i0:Float, i1:Float, o0:Float, o1:Float):Float {
				return o0 + (v - i0) / (i1 - i0) * (o1 - o0);
			},
			norm:    function(v:Float, min:Float, max:Float):Float return (v - min) / (max - min),
			snap:    function(v:Float, step:Float):Float return Math.round(v / step) * step,
			pingpong: function(v:Float, len:Float):Float {
				final t = v % (len * 2);
				return t < len ? t : len * 2 - t;
			},
			sign:    function(v:Float):Int return v > 0 ? 1 : (v < 0 ? -1 : 0),
			// Seno/coseno con acumulador (sin estado global compartido)
			sine:    function(acc:Float, speed:Float = 1.0):Float return Math.sin(acc * speed),
			cosine:  function(acc:Float, speed:Float = 1.0):Float return Math.cos(acc * speed),
			// Random
			rnd:     function(min:Int, max:Int):Int return FlxG.random.int(min, max),
			rndf:    function(min:Float, max:Float):Float return FlxG.random.float(min, max),
			chance:  function(pct:Float):Bool return FlxG.random.float() < pct,
			// Geometría
			dist:    function(x1:Float, y1:Float, x2:Float, y2:Float):Float {
				final dx = x2 - x1; final dy = y2 - y1;
				return Math.sqrt(dx * dx + dy * dy);
			},
			angle:   function(x1:Float, y1:Float, x2:Float, y2:Float):Float {
				return Math.atan2(y2 - y1, x2 - x1) * (180 / Math.PI);
			},
			// Bézier
			bezier:     function(t:Float, p0:Float, p1:Float, p2:Float, p3:Float):Float {
				final u = 1 - t;
				return u*u*u*p0 + 3*u*u*t*p1 + 3*u*t*t*p2 + t*t*t*p3;
			},
			quadBezier: function(t:Float, p0:Float, p1:Float, p2:Float):Float {
				final u = 1 - t;
				return u*u*p0 + 2*u*t*p1 + t*t*p2;
			},
			// Trig en grados
			sin:     function(d:Float):Float return Math.sin(d * Math.PI / 180),
			cos:     function(d:Float):Float return Math.cos(d * Math.PI / 180),
			tan:     function(d:Float):Float return Math.tan(d * Math.PI / 180),
			// Constantes
			PI: Math.PI, TAU: Math.PI * 2,
			E: Math.exp(1.0), SQRT2: Math.sqrt(2.0),
			INF: Math.POSITIVE_INFINITY
		});
	}

	// ─── Array helpers ────────────────────────────────────────────────────────

	static function exposeArray(interp:Interp):Void
	{
		interp.variables.set('arr', {
			find:    function(a:Array<Dynamic>, fn:Dynamic):Dynamic {
				for (x in a) if (Reflect.callMethod(null, fn, [x])) return x;
				return null;
			},
			filter:  function(a:Array<Dynamic>, fn:Dynamic):Array<Dynamic> {
				return a.filter(function(x) return Reflect.callMethod(null, fn, [x]));
			},
			map:     function(a:Array<Dynamic>, fn:Dynamic):Array<Dynamic> {
				return a.map(function(x) return Reflect.callMethod(null, fn, [x]));
			},
			some:    function(a:Array<Dynamic>, fn:Dynamic):Bool {
				for (x in a) if (Reflect.callMethod(null, fn, [x])) return true;
				return false;
			},
			every:   function(a:Array<Dynamic>, fn:Dynamic):Bool {
				for (x in a) if (!Reflect.callMethod(null, fn, [x])) return false;
				return true;
			},
			shuffle: function(a:Array<Dynamic>):Array<Dynamic> {
				final r = a.copy();
				for (i in 0...r.length) {
					final j = FlxG.random.int(0, r.length - 1);
					final tmp = r[i]; r[i] = r[j]; r[j] = tmp;
				}
				return r;
			},
			pick:    function(a:Array<Dynamic>):Dynamic {
				return a.length > 0 ? a[FlxG.random.int(0, a.length - 1)] : null;
			},
			unique:  function(a:Array<Dynamic>):Array<Dynamic> {
				final r:Array<Dynamic> = [];
				for (x in a) if (!r.contains(x)) r.push(x);
				return r;
			},
			flatten: function(a:Array<Array<Dynamic>>):Array<Dynamic> {
				final r:Array<Dynamic> = [];
				for (sub in a) for (x in sub) r.push(x);
				return r;
			},
			sum:     function(a:Array<Float>):Float { var s = 0.0; for (x in a) s += x; return s; },
			max:     function(a:Array<Float>):Float { var m = Math.NEGATIVE_INFINITY; for (x in a) if (x > m) m = x; return m; },
			min:     function(a:Array<Float>):Float { var m = Math.POSITIVE_INFINITY; for (x in a) if (x < m) m = x; return m; },
			sortBy:  function(a:Array<Dynamic>, key:String):Array<Dynamic> {
				final r = a.copy();
				r.sort(function(x, y) {
					final vx = Reflect.field(x, key); final vy = Reflect.field(y, key);
					if (vx < vy) return -1; if (vx > vy) return 1; return 0;
				});
				return r;
			},
			range:   function(from:Int, to:Int, ?step:Int):Array<Int> {
				if (step == null) step = 1;
				final r:Array<Int> = [];
				var i = from;
				while (step > 0 ? i < to : i > to) { r.push(i); i += step; }
				return r;
			},
			zip:     function(a:Array<Dynamic>, b:Array<Dynamic>):Array<Array<Dynamic>> {
				final len = Std.int(Math.min(a.length, b.length));
				return [for (i in 0...len) [a[i], b[i]]];
			}
		});
	}

	// ─── Mod info ─────────────────────────────────────────────────────────────

	static function exposeMod(interp:Interp):Void
	{
		interp.variables.set('mod', {
			isActive: function():Bool   return mods.ModManager.isActive(),
			name:     function():String return mods.ModManager.activeMod ?? 'base',
			root:     function():String return mods.ModManager.isActive() ? mods.ModManager.modRoot() : 'assets',
			path:     function(rel:String):String {
				if (mods.ModManager.isActive()) return '${mods.ModManager.modRoot()}/$rel';
				return 'assets/$rel';
			},
			exists:   function(rel:String):Bool {
				#if sys
				if (mods.ModManager.isActive()) {
					if (sys.FileSystem.exists('${mods.ModManager.modRoot()}/$rel')) return true;
				}
				return sys.FileSystem.exists('assets/$rel');
				#else
				return false;
				#end
			},
			list:     function():Array<String> { return [for (m in mods.ModManager.installedMods) m.id]; },
			info:     function():Dynamic {
				final id = mods.ModManager.activeMod;
				if (id == null) return null;
				for (m in mods.ModManager.installedMods) if (m.id == id) return m;
				return null;
			},
			getImage:  function(name:String):Dynamic { return Paths.image(name); },
			getSound:  function(name:String):Dynamic { return Paths.sound(name); },
			getMusic:  function(name:String):Dynamic { return Paths.music(name); },
			setActive: function(id:String) { mods.ModManager.setActive(id); },
			deactivate: function() { mods.ModManager.deactivate(); }
		});
	}

	// ─── Characters ───────────────────────────────────────────────────────────

	static function exposeCharacters(interp:Interp):Void
	{
		interp.variables.set('chars', {
			bf:  function():Dynamic {
				final ps = funkin.gameplay.PlayState.instance;
				return ps != null ? ps.boyfriend : null;
			},
			dad: function():Dynamic {
				final ps = funkin.gameplay.PlayState.instance;
				return ps != null ? ps.dad : null;
			},
			gf:  function():Dynamic {
				final ps = funkin.gameplay.PlayState.instance;
				return ps != null ? ps.gf : null;
			},
			get: function(idx:Int):Dynamic {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps == null) return null;
				final cc = Reflect.field(ps, 'characterController');
				return (cc != null) ? cc.getCharacter(idx) : null;
			},
			getSlot: function(idx:Int):Dynamic {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps == null) return null;
				final cc = Reflect.field(ps, 'characterController');
				return (cc != null) ? cc.getSlot(idx) : null;
			},
			count: function():Int {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps == null) return 0;
				final cc = Reflect.field(ps, 'characterController');
				return (cc != null) ? cc.getCharacterCount() : 0;
			},
			playAnim:    function(char:Dynamic, anim:String, ?force:Bool) {
				if (char != null) char.playAnim(anim, force != null ? force : true);
			},
			dance:       function(char:Dynamic) { if (char != null) char.dance(); },
			setVisible:  function(char:Dynamic, v:Bool) { if (char != null) char.visible = v; },
			setPosition: function(char:Dynamic, x:Float, y:Float) {
				if (char != null) { char.x = x; char.y = y; }
			},
			getAnim: function(char:Dynamic):String {
				if (char == null || char.animation == null) return '';
				final cur = char.animation.curAnim;
				return cur != null ? cur.name : '';
			},
			hasAnim: function(char:Dynamic, name:String):Bool {
				if (char == null) return false;
				return char.hasAnimation(name);
			},
			getAnimList: function(char:Dynamic):Array<String> {
				if (char == null) return [];
				return char.getAnimationList();
			},
			setActive: function(idx:Int, active:Bool) {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps == null) return;
				final cc = Reflect.field(ps, 'characterController');
				if (cc != null) cc.setCharacterActive(idx, active);
			},
			singByIndex: function(charIdx:Int, noteData:Int, ?altAnim:String) {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps == null) return;
				final cc = Reflect.field(ps, 'characterController');
				if (cc != null) cc.singByIndex(charIdx, noteData, altAnim);
			}
		});
	}

	// ─── Camera ───────────────────────────────────────────────────────────────

	static function exposeCamera(interp:Interp):Void
	{
		interp.variables.set('camera', {
			game:    function():Dynamic {
				final ps = funkin.gameplay.PlayState.instance;
				return ps != null ? Reflect.field(ps, 'camGame') : FlxG.camera;
			},
			hud:     function():Dynamic {
				final ps = funkin.gameplay.PlayState.instance;
				return ps != null ? Reflect.field(ps, 'camHUD') : null;
			},
			other:   function():Dynamic {
				final ps = funkin.gameplay.PlayState.instance;
				return ps != null ? Reflect.field(ps, 'camOther') : null;
			},
			setZoom: function(v:Float) {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps != null) { final cg = Reflect.field(ps, 'camGame'); if (cg != null) cg.zoom = v; }
			},
			getZoom: function():Float {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps == null) return 1.0;
				final cg = Reflect.field(ps, 'camGame');
				return cg != null ? cg.zoom : 1.0;
			},
			tweenZoom: function(targetZoom:Float, duration:Float, ?ease:Dynamic) {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps == null) return;
				final cg = Reflect.field(ps, 'camGame');
				if (cg != null) FlxTween.tween(cg, {zoom: targetZoom}, duration,
					ease != null ? {ease: ease} : null);
			},
			shake:   function(?intensity:Float, ?duration:Float, ?target:Dynamic) {
				final cam = target ?? FlxG.camera;
				cam.shake(intensity ?? 0.03, duration ?? 0.2);
			},
			flash:   function(?color:Int, ?duration:Float, ?target:Dynamic) {
				final cam = target ?? FlxG.camera;
				cam.flash(color ?? FlxColor.WHITE, duration ?? 0.3);
			},
			fade:    function(?color:Int, ?duration:Float, ?inward:Bool, ?target:Dynamic) {
				final cam = target ?? FlxG.camera;
				if (inward ?? false) cam.fade(color ?? FlxColor.BLACK, duration ?? 0.5, true);
				else                 cam.fade(color ?? FlxColor.BLACK, duration ?? 0.5);
			},
			focusBf:  function() {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps != null && ps.cameraController != null) ps.cameraController.setTarget('bf');
			},
			focusDad: function() {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps != null && ps.cameraController != null) ps.cameraController.setTarget('opponent');
			},
			setFollowLerp: function(lerp:Float) {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps != null && ps.cameraController != null) ps.cameraController.setFollowLerp(lerp);
			},
			bumpZoom: function() {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps != null && ps.cameraController != null) ps.cameraController.bumpZoom();
			},
			// Añadir shader a una cámara específica
			addShader: function(shaderName:String, ?camTarget:Dynamic) {
				final ps = funkin.gameplay.PlayState.instance;
				final cam:FlxCamera = camTarget ?? (ps != null ? Reflect.field(ps, 'camGame') : FlxG.camera);
				if (cam == null) return;
				final sh = shaders.ShaderManager.loadShader(shaderName);
				if (sh != null) funkin.data.CameraUtil.addShader(sh.shader, cam);
			},
			clearShaders: function(?camTarget:Dynamic) {
				final ps = funkin.gameplay.PlayState.instance;
				final cam:FlxCamera = camTarget ?? (ps != null ? Reflect.field(ps, 'camGame') : FlxG.camera);
				if (cam != null) funkin.data.CameraUtil.clearFilters(cam);
			}
		});
	}

	// ─── HUD ──────────────────────────────────────────────────────────────────

	static function exposeHUD(interp:Interp):Void
	{
		interp.variables.set('hud', {
			get: function():Dynamic {
				final ps = funkin.gameplay.PlayState.instance;
				return (ps != null) ? ps.uiManager : null;
			},
			camera: function():Dynamic {
				final ps = funkin.gameplay.PlayState.instance;
				return (ps != null) ? ps.camHUD : null;
			},
			setVisible: function(v:Bool) {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps != null && ps.uiManager != null) ps.uiManager.visible = v;
			},
			setHealth: function(v:Float) {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps != null && ps.gameState != null) ps.gameState.health = v;
			},
			getHealth: function():Float {
				final ps = funkin.gameplay.PlayState.instance;
				return (ps != null && ps.gameState != null) ? ps.gameState.health : 1.0;
			},
			addHealth: function(v:Float) {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps != null && ps.gameState != null) ps.gameState.modifyHealth(v);
			},
			iconP1: function():Dynamic {
				final ps = funkin.gameplay.PlayState.instance;
				return (ps != null && ps.uiManager != null) ? ps.uiManager.iconP1 : null;
			},
			iconP2: function():Dynamic {
				final ps = funkin.gameplay.PlayState.instance;
				return (ps != null && ps.uiManager != null) ? ps.uiManager.iconP2 : null;
			},
			setScoreVisible: function(v:Bool) {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps != null && ps.uiManager != null) {
					final txt = Reflect.field(ps.uiManager, 'scoreText');
					if (txt != null) txt.visible = v;
				}
			},
			showRating: function(rating:String, ?combo:Int) {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps != null && ps.uiManager != null)
					ps.uiManager.showRatingPopup(rating, combo ?? ps.scoreManager.combo);
			},
			tweenTo: function(obj:Dynamic, props:Dynamic, dur:Float, ?ease:Dynamic) {
				if (obj == null) return null;
				return FlxTween.tween(obj, props, dur, ease != null ? {ease: ease} : null);
			}
		});
	}

	// ─── Shaders ──────────────────────────────────────────────────────────────

	static function exposeShaders(interp:Interp):Void
	{
		interp.variables.set('ShaderManager', _shaderManagerProxy());
		interp.variables.set('WaveEffect',    shaders.WaveEffect);
		interp.variables.set('WiggleEffect',  shaders.WiggleEffect);
		interp.variables.set('BlendModeEffect', shaders.BlendModeEffect);
		interp.variables.set('OverlayShader',   shaders.OverlayShader);

		// WiggleEffect — object wrapper para usar en scripts fácilmente
		// Uso: var wiggle = wiggleEffect.create(); wiggle.effectType = ...
		interp.variables.set('wiggleEffect', {
			create: function():shaders.WiggleEffect { return new shaders.WiggleEffect(); },
			// Constantes de tipo
			DREAMY:     'DREAMY',
			WAVY:       'WAVY',
			HEAT_WAVE:  'HEAT_WAVE',
			FLAG:       'FLAG',
			CUSTOM:     'CUSTOM'
		});
	}

	// ─── Window + CppAPI (Windows DWM / dark mode) ────────────────────────────

	static function exposeWindow(interp:Interp):Void
	{
		interp.variables.set('Window', {
			setTitle:  function(t:String) { try { openfl.Lib.application.window.title = t; } catch(_) {} },
			getTitle:  function():String  { try { return openfl.Lib.application.window.title; } catch(_) { return ''; } },
			setFPS:    function(fps:Int)  { FlxG.updateFramerate = fps; FlxG.drawFramerate = fps; },
			getFPS:    function():Int     { return FlxG.updateFramerate; },
			getWidth:  function():Int     { return FlxG.width; },
			getHeight: function():Int     { return FlxG.height; }
		});

		// CppAPI — control de la ventana a nivel OS (Windows only, no-op en otros)
		interp.variables.set('CppAPI', extensions.CppAPI);
		interp.variables.set('nativeWindow', {
			// Colores de la barra de título (Windows 11 DWM)
			setBorderColor:  function(r:Int, g:Int, b:Int) { extensions.CppAPI.changeColor(r, g, b); },
			setCaptionColor: function(r:Int, g:Int, b:Int) { extensions.CppAPI.changeCaptionColor(r, g, b); },
			// Dark mode (Windows 10 1809+)
			enableDarkMode:  function() { extensions.CppAPI.enableDarkMode(); },
			disableDarkMode: function() { extensions.CppAPI.disableDarkMode(); },
			// DPI awareness
			setDPIAware:     function() { extensions.CppAPI.registerDPIAware(); },
			// Opacidad de la ventana
			setOpacity:      function(alpha:Float) { extensions.CppAPI.setWindowOpacity(alpha); },
			// Título (alias de Window.setTitle)
			setTitle:        function(t:String) { extensions.CppAPI.setWindowTitle(t); },
			getTitle:        function():String  { return extensions.CppAPI.windowTitle; }
		});
	}

	// ─── Visibility ───────────────────────────────────────────────────────────

	static function exposeVisibility(interp:Interp):Void
	{
		interp.variables.set('show', function(spr:Dynamic) {
			if (spr != null) { spr.visible = true; spr.active = true; }
		});
		interp.variables.set('hide', function(spr:Dynamic) {
			if (spr != null) { spr.visible = false; spr.active = false; }
		});
	}

	// ─── Utils ────────────────────────────────────────────────────────────────

	static function exposeUtils(interp:Interp):Void
	{
		interp.variables.set('StringTools', StringTools);
		interp.variables.set('Std',         Std);
		interp.variables.set('Math',        Math);
		interp.variables.set('Json',        haxe.Json);
		interp.variables.set('Reflect',     Reflect);
		interp.variables.set('Type',        Type);
		interp.variables.set('trace', function(v:Dynamic) trace('[Script] $v'));
		interp.variables.set('print', function(v:Dynamic) trace('[Script] $v'));

		// FlxAtlasFramesExt — crear atlas desde grid (sin XML/JSON)
		interp.variables.set('FlxAtlasFramesExt', extensions.FlxAtlasFramesExt);
		interp.variables.set('atlasFrames', {
			// Crea frames de un tileset por grid: fromGraphic(graphic, 64, 64)
			fromGraphic: function(graphic:Dynamic, frameWidth:Int, frameHeight:Int, ?name:String):Dynamic {
				return extensions.FlxAtlasFramesExt.fromGraphic(graphic, frameWidth, frameHeight, name);
			},
			// Sparrow Atlas desde XML (wrapper de FlxAtlasFrames)
			fromSparrow: function(source:Dynamic, desc:Dynamic):Dynamic {
				return flixel.graphics.frames.FlxAtlasFrames.fromSparrow(source, desc);
			},
			// Packer Atlas desde TXT
			fromPacker: function(source:Dynamic, desc:Dynamic):Dynamic {
				return flixel.graphics.frames.FlxAtlasFrames.fromTexturePackerJson(source, desc);
			}
		});

		// Acceso al sistema de archivos (solo en targets sys como Windows/Linux/Mac)
		#if sys
		interp.variables.set('FileSystem', sys.FileSystem);
		interp.variables.set('File', {
			read:         function(path:String):String {
				try { return sys.io.File.getContent(path); } catch(_) { return null; }
			},
			readBytes:    function(path:String):Dynamic {
				try { return sys.io.File.getBytes(path); } catch(_) { return null; }
			},
			write:        function(path:String, content:String) {
				try { sys.io.File.saveContent(path, content); } catch(_) {}
			},
			exists:       function(path:String):Bool { return sys.FileSystem.exists(path); },
			isDirectory:  function(path:String):Bool {
				return sys.FileSystem.exists(path) && sys.FileSystem.isDirectory(path);
			},
			listDir:      function(path:String):Array<String> {
				try { return sys.FileSystem.readDirectory(path); } catch(_) { return []; }
			},
			createDir:    function(path:String) {
				try { sys.FileSystem.createDirectory(path); } catch(_) {}
			},
			deleteFile:   function(path:String) {
				try { sys.FileSystem.deleteFile(path); } catch(_) {}
			}
		});
		#end

		// Haxe utils útiles
		interp.variables.set('Xml',  Xml);
		interp.variables.set('EReg', EReg);
	}

	// ─── Events ───────────────────────────────────────────────────────────────

	static function exposeEvents(interp:Interp):Void
	{
		interp.variables.set('EventManager', funkin.scripting.EventManager);
	}

	// ─── Debug ────────────────────────────────────────────────────────────────

	static function exposeDebug(interp:Interp):Void
	{
		interp.variables.set('debug', {
			log:    function(msg:Dynamic) trace('[ScriptDebug] $msg'),
			warn:   function(msg:Dynamic) trace('[ScriptWARN] $msg'),
			error:  function(msg:Dynamic) trace('[ScriptERROR] $msg'),
			assert: function(cond:Bool, msg:String) { if (!cond) trace('[ScriptASSERT FAIL] $msg'); },
			drawBox: function(x:Float, y:Float, w:Float, h:Float, ?color:Int) {
				#if FLX_DEBUG
				var gfx = FlxG.camera.debugLayer.graphics;
				gfx.lineStyle(1, color ?? 0xFFFF0000, 1.0);
				gfx.drawRect(x, y, w, h);
				#end
			}
		});
	}

	// ─── Strums ───────────────────────────────────────────────────────────────

	static function exposeStrums(interp:Interp):Void
	{
		interp.variables.set('strum', {
			getGroup: function(id:String):Dynamic {
				final ps = funkin.gameplay.PlayState.instance;
				return ps != null ? ps.strumsGroupMap.get(id) : null;
			},
			getPlayer: function():Dynamic {
				final ps = funkin.gameplay.PlayState.instance;
				return (ps != null) ? ps.playerStrumsGroup : null;
			},
			getCpu: function():Dynamic {
				final ps = funkin.gameplay.PlayState.instance;
				return (ps != null) ? ps.cpuStrumsGroup : null;
			},
			getAll: function():Dynamic {
				final ps = funkin.gameplay.PlayState.instance;
				return (ps != null) ? ps.strumsGroups : [];
			},
			getStrum: function(groupId:String, idx:Int):Dynamic {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps == null) return null;
				final g = ps.strumsGroupMap.get(groupId);
				return (g != null) ? g.getStrum(idx) : null;
			},
			getPlayerStrum: function(idx:Int):Dynamic {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps == null || ps.playerStrumsGroup == null) return null;
				return ps.playerStrumsGroup.getStrum(idx);
			},
			getCpuStrum: function(idx:Int):Dynamic {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps == null || ps.cpuStrumsGroup == null) return null;
				return ps.cpuStrumsGroup.getStrum(idx);
			},
			setX: function(groupId:String, idx:Int, v:Float) {
				final ps = funkin.gameplay.PlayState.instance; if (ps == null) return;
				final s = ps.strumsGroupMap.get(groupId)?.getStrum(idx);
				if (s != null) s.x = v;
			},
			setY: function(groupId:String, idx:Int, v:Float) {
				final ps = funkin.gameplay.PlayState.instance; if (ps == null) return;
				final s = ps.strumsGroupMap.get(groupId)?.getStrum(idx);
				if (s != null) s.y = v;
			},
			setAlpha: function(groupId:String, idx:Int, v:Float) {
				final ps = funkin.gameplay.PlayState.instance; if (ps == null) return;
				final s = ps.strumsGroupMap.get(groupId)?.getStrum(idx);
				if (s != null) s.alpha = v;
			},
			setAngle: function(groupId:String, idx:Int, v:Float) {
				final ps = funkin.gameplay.PlayState.instance; if (ps == null) return;
				final s = ps.strumsGroupMap.get(groupId)?.getStrum(idx);
				if (s != null) s.angle = v;
			},
			setVisible: function(groupId:String, idx:Int, v:Bool) {
				final ps = funkin.gameplay.PlayState.instance; if (ps == null) return;
				final s = ps.strumsGroupMap.get(groupId)?.getStrum(idx);
				if (s != null) s.visible = v;
			},
			setScale: function(groupId:String, idx:Int, sx:Float, ?sy:Float) {
				final ps = funkin.gameplay.PlayState.instance; if (ps == null) return;
				final s = ps.strumsGroupMap.get(groupId)?.getStrum(idx);
				if (s != null) s.scale.set(sx, sy ?? sx);
			},
			setGroupVisible: function(groupId:String, v:Bool) {
				final ps = funkin.gameplay.PlayState.instance; if (ps == null) return;
				final g = ps.strumsGroupMap.get(groupId);
				if (g != null) g.setVisible(v);
			},
			setGroupPosition: function(groupId:String, x:Float, y:Float) {
				final ps = funkin.gameplay.PlayState.instance; if (ps == null) return;
				final g = ps.strumsGroupMap.get(groupId);
				if (g != null) g.setPosition(x, y);
			},
			setGroupSpacing: function(groupId:String, spacing:Float) {
				final ps = funkin.gameplay.PlayState.instance; if (ps == null) return;
				final g = ps.strumsGroupMap.get(groupId);
				if (g != null) g.setSpacing(spacing);
			}
		});
	}

	// ─── ModChart ─────────────────────────────────────────────────────────────

	static function exposeModChart(interp:Interp):Void
	{
		interp.variables.set('modchart', {
			add: function(beat:Float, target:String, strumIdx:Int, type:String, value:Float,
			              ?duration:Float, ?ease:String) {
				final mc = funkin.gameplay.modchart.ModChartManager.instance;
				if (mc == null) return;
				mc.addEventSimple(beat, target, strumIdx, type, value, duration ?? 0.0, ease ?? "linear");
			},
			addNow: function(target:String, strumIdx:Int, type:String, value:Float,
			                 ?duration:Float, ?ease:String) {
				final mc = funkin.gameplay.modchart.ModChartManager.instance;
				if (mc == null) return;
				final beat = funkin.data.Conductor.crochet > 0
					? funkin.data.Conductor.songPosition / funkin.data.Conductor.crochet : 0.0;
				mc.addEventSimple(beat, target, strumIdx, type, value, duration ?? 0.0, ease ?? "linear");
			},
			clear:     function() { final mc = funkin.gameplay.modchart.ModChartManager.instance; if (mc != null) mc.clearEvents(); },
			reset:     function() { final mc = funkin.gameplay.modchart.ModChartManager.instance; if (mc != null) mc.resetToStart(); },
			enable:    function() { final mc = funkin.gameplay.modchart.ModChartManager.instance; if (mc != null) mc.enabled = true; },
			disable:   function() { final mc = funkin.gameplay.modchart.ModChartManager.instance; if (mc != null) mc.enabled = false; },
			isEnabled: function():Bool { final mc = funkin.gameplay.modchart.ModChartManager.instance; return mc != null ? mc.enabled : false; },
			manager:   function():Dynamic { return funkin.gameplay.modchart.ModChartManager.instance; },
			seek:      function(beat:Float) { final mc = funkin.gameplay.modchart.ModChartManager.instance; if (mc != null) mc.seekToBeat(beat); }
		});
	}

	// ═══════════════════════════════════════════════════════════════════════════
	//  NUEVO v6
	// ═══════════════════════════════════════════════════════════════════════════

	// ─── Mathf proxy completo ─────────────────────────────────────────────────
	// Todas las funciones de funkin.data.Mathf + las de extensions.Mathf,
	// expuestas como lambdas porque la mayoría son static inline (invisibles
	// por reflexión en targets compilados).
	static function exposeMathf(interp:Interp):Void
	{
		interp.variables.set('Mathf', {
			// ── funkin.data.Mathf ──────────────────────────────────────────────
			roundTo:      function(n:Float, dec:Float):Float {
				final f = Math.pow(10, dec);
				return Math.round(n * f) / f;
			},
			percent:      function(value:Float, total:Float):Float {
				return total == 0 ? 0 : Math.round(value / total * 100);
			},
			clamp:        function(v:Float, min:Float, max:Float):Float {
				if (v < min) return min; if (v > max) return max; return v;
			},
			clampInt:     function(v:Int, min:Int, max:Int):Int {
				if (v < min) return min; if (v > max) return max; return v;
			},
			remap:        function(v:Float, i0:Float, i1:Float, o0:Float, o1:Float):Float {
				return o0 + (v - i0) * (o1 - o0) / (i1 - i0);
			},
			toRadians:    function(deg:Float):Float return deg * (Math.PI / 180.0),
			toDegrees:    function(rad:Float):Float return rad * (180.0 / Math.PI),
			floorInt:     function(v:Float):Int return Std.int(Math.floor(v)),
			ceilInt:      function(v:Float):Int  return Std.int(Math.ceil(v)),
			absInt:       function(v:Int):Int    return v < 0 ? -v : v,
			lerp:         function(a:Float, b:Float, t:Float):Float return a + (b - a) * t,
			// sine() con acumulador externo — SIN estado global compartido.
			// Uso: sineAcc += elapsed; sprite.y += Mathf.sine(sineAcc, 2.0) * 5;
			sine:         function(acc:Float, speed:Float = 1.0):Float return Math.sin(acc * speed),
			// ── extensions.Mathf ──────────────────────────────────────────────
			// Equivalente a sineByTime pero sin la static var compartida.
			// Mantén tu propio acumulador en el script:
			//   var t = 0.0; // en onUpdate: t += elapsed; sprite.y += Mathf.sineAcc(t);
			sineAcc:      function(acc:Float, ?multi:Float):Float {
				return Math.sin(Math.abs(acc * (multi != null ? multi : 1.0)));
			},
			radiants2degrees: function(v:Float):Float return v * (180 / Math.PI),
			degrees2radiants: function(v:Float):Float return v * (Math.PI / 180),
			getPercentage:    function(number:Float, toGet:Float):Float {
				var num = number;
				num = num * Math.pow(10, toGet);
				num = Math.round(num) / Math.pow(10, toGet);
				return num;
			},
			floor2int: function(v:Float):Int return Std.int(Math.floor(Math.abs(v))),
			// ── Constantes ────────────────────────────────────────────────────
			DEG_TO_RAD: Math.PI / 180.0,
			RAD_TO_DEG: 180.0 / Math.PI
		});
	}

	// ─── CoolUtil proxy ───────────────────────────────────────────────────────

	static function exposeCoolUtil(interp:Interp):Void
	{
		interp.variables.set('CoolUtil', {
			// Nombre de la dificultad actual
			difficultyString: function():String return funkin.data.CoolUtil.difficultyString(),
			// Leer un archivo de texto y dividir en líneas
			coolTextFile:     function(path:String):Array<String> {
				return funkin.data.CoolUtil.coolTextFile(path);
			},
			// Dividir un string en líneas
			coolStringFile:   function(content:String):Array<String> {
				return funkin.data.CoolUtil.coolStringFile(content);
			},
			// Array de enteros [min..max)
			numberArray:      function(max:Int, ?min:Int):Array<Int> {
				return funkin.data.CoolUtil.numberArray(max, min != null ? min : 0);
			},
			capitalize:       function(s:String):String return funkin.data.CoolUtil.capitalize(s),
			truncate:         function(s:String, maxLen:Int):String return funkin.data.CoolUtil.truncate(s, maxLen),
			// Arrays de dificultad
			difficultyArray:  funkin.data.CoolUtil.difficultyArray,
			difficultyPath:   funkin.data.CoolUtil.difficultyPath
		});
	}

	// ─── CameraUtil proxy ─────────────────────────────────────────────────────

	static function exposeCameraUtil(interp:Interp):Void
	{
		interp.variables.set('CameraUtil', {
			create:        function(?addToStack:Bool):FlxCamera {
				return funkin.data.CameraUtil.create(addToStack != null ? addToStack : true);
			},
			addShader:     function(shader:Dynamic, ?cam:FlxCamera):Dynamic {
				return funkin.data.CameraUtil.addShader(shader, cam);
			},
			removeFilter:  function(filter:Dynamic, ?cam:FlxCamera):Bool {
				return funkin.data.CameraUtil.removeFilter(filter, cam);
			},
			clearFilters:  function(?cam:FlxCamera) { funkin.data.CameraUtil.clearFilters(cam); },
			getFilters:    function(?cam:FlxCamera):Array<Dynamic> {
				return funkin.data.CameraUtil.getFilters(cam ?? FlxG.camera);
			},
			optimizeForGameplay: function(cam:FlxCamera) {
				funkin.data.CameraUtil.optimizeForGameplay(cam);
			},
			lastCamera:    function():FlxCamera { return funkin.data.CameraUtil.lastCamera; }
		});
	}

	// ─── add / remove directos ────────────────────────────────────────────────

	static function exposeAddRemove(interp:Interp):Void
	{
		// add(sprite) → game.add(sprite) si estamos en PlayState, si no FlxG.state.add()
		interp.variables.set('add', function(obj:Dynamic):Dynamic {
			final ps = funkin.gameplay.PlayState.instance;
			if (ps != null) return ps.add(obj);
			if (FlxG.state != null) return FlxG.state.add(obj);
			return null;
		});
		interp.variables.set('remove', function(obj:Dynamic, ?splice:Bool):Dynamic {
			final ps = funkin.gameplay.PlayState.instance;
			if (ps != null) return ps.remove(obj, splice ?? false);
			if (FlxG.state != null) return FlxG.state.remove(obj, splice ?? false);
			return null;
		});
		// addToHUD(sprite) → añade a camHUD
		interp.variables.set('addToHUD', function(obj:Dynamic) {
			final ps = funkin.gameplay.PlayState.instance;
			if (ps == null || obj == null) return;
			if (Reflect.hasField(obj, 'cameras')) {
				final camHUD = Reflect.field(ps, 'camHUD');
				if (camHUD != null) obj.cameras = [camHUD];
			}
			ps.add(obj);
		});
	}

	// ─── Stage access ─────────────────────────────────────────────────────────

	static function exposeStageAccess(interp:Interp):Void
	{
		interp.variables.set('stage', {
			// Referencia directa al Stage actual
			get:          function():Dynamic {
				final ps = funkin.gameplay.PlayState.instance;
				return ps != null ? Reflect.field(ps, 'currentStage') : null;
			},
			// Obtener un elemento del stage por nombre
			getElement:   function(name:String):Dynamic {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps == null) return null;
				final st = Reflect.field(ps, 'currentStage');
				return st != null ? st.getElement(name) : null;
			},
			// Obtener un grupo del stage por nombre
			getGroup:     function(name:String):Dynamic {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps == null) return null;
				final st = Reflect.field(ps, 'currentStage');
				return st != null ? st.getGroup(name) : null;
			},
			// Obtener un sonido del stage por nombre
			getSound:     function(name:String):Dynamic {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps == null) return null;
				final st = Reflect.field(ps, 'currentStage');
				return st != null ? st.getSound(name) : null;
			},
			// Obtener una custom class del stage por nombre
			getCustomClass: function(name:String):Dynamic {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps == null) return null;
				final st = Reflect.field(ps, 'currentStage');
				return st != null ? st.getCustomClass(name) : null;
			},
			// Nombre del stage actual
			name:         function():String {
				final ps = funkin.gameplay.PlayState.instance;
				return ps != null ? Reflect.field(ps, 'curStage') : '';
			},
			// Posiciones de referencia del stage
			bfPos:        function():Dynamic {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps == null) return null;
				final st = Reflect.field(ps, 'currentStage');
				return st != null ? st.boyfriendPosition : null;
			},
			dadPos:       function():Dynamic {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps == null) return null;
				final st = Reflect.field(ps, 'currentStage');
				return st != null ? st.dadPosition : null;
			},
			gfPos:        function():Dynamic {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps == null) return null;
				final st = Reflect.field(ps, 'currentStage');
				return st != null ? st.gfPosition : null;
			},
			// Default camera zoom del stage
			defaultZoom:  function():Float {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps == null) return 1.05;
				final st = Reflect.field(ps, 'currentStage');
				return st != null ? st.defaultCamZoom : 1.05;
			},
			isPixel:      function():Bool {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps == null) return false;
				final st = Reflect.field(ps, 'currentStage');
				return st != null ? st.isPixelStage : false;
			}
		});
	}

	// ─── NoteManager access ───────────────────────────────────────────────────

	static function exposeNoteManagerAccess(interp:Interp):Void
	{
		interp.variables.set('noteManager', {
			get:             function():Dynamic {
				final ps = funkin.gameplay.PlayState.instance;
				return ps != null ? ps.noteManager : null;
			},
			setDownscroll:   function(v:Bool) {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps != null && ps.noteManager != null) ps.noteManager.downscroll = v;
			},
			setMiddlescroll: function(v:Bool) {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps != null && ps.noteManager != null) ps.noteManager.middlescroll = v;
			},
			setStrumLineY:   function(v:Float) {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps != null && ps.noteManager != null) ps.noteManager.strumLineY = v;
			},
			getStats:        function():String {
				final ps = funkin.gameplay.PlayState.instance;
				return (ps != null && ps.noteManager != null) ? ps.noteManager.getPoolStats() : '';
			},
			toggleBatching:  function() {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps != null && ps.noteManager != null) ps.noteManager.toggleBatching();
			}
		});
	}

	// ─── Input access ─────────────────────────────────────────────────────────

	static function exposeInputAccess(interp:Interp):Void
	{
		interp.variables.set('input', {
			// Arrays de estado de teclas — acceso directo
			held:     function():Array<Bool> {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps == null) return [false,false,false,false];
				final ih = Reflect.field(ps, 'inputHandler');
				return ih != null ? ih.held : [false,false,false,false];
			},
			pressed:  function():Array<Bool> {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps == null) return [false,false,false,false];
				final ih = Reflect.field(ps, 'inputHandler');
				return ih != null ? ih.pressed : [false,false,false,false];
			},
			released: function():Array<Bool> {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps == null) return [false,false,false,false];
				final ih = Reflect.field(ps, 'inputHandler');
				return ih != null ? ih.released : [false,false,false,false];
			},
			isHeld:    function(dir:Int):Bool {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps == null) return false;
				final ih = Reflect.field(ps, 'inputHandler');
				return ih != null ? ih.held[dir] : false;
			},
			isPressed: function(dir:Int):Bool {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps == null) return false;
				final ih = Reflect.field(ps, 'inputHandler');
				return ih != null ? ih.pressed[dir] : false;
			},
			setGhostTapping: function(v:Bool) {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps == null) return;
				final ih = Reflect.field(ps, 'inputHandler');
				if (ih != null) ih.ghostTapping = v;
			},
			// Acceso al FlxKey — útil para binds personalizados
			isKeyDown:  function(keyName:String):Bool {
				try {
					final key = flixel.input.keyboard.FlxKey.fromString(keyName);
					return FlxG.keys.checkStatus(key, flixel.input.FlxInput.FlxInputState.PRESSED);
				} catch(_) { return false; }
			},
			isKeyJustPressed: function(keyName:String):Bool {
				try {
					final key = flixel.input.keyboard.FlxKey.fromString(keyName);
					return FlxG.keys.checkStatus(key, flixel.input.FlxInput.FlxInputState.JUST_PRESSED);
				} catch(_) { return false; }
			}
		});
	}

	// ─── VideoManager ─────────────────────────────────────────────────────────

	static function exposeVideoManager(interp:Interp):Void
	{
		interp.variables.set('VideoManager', funkin.cutscenes.VideoManager);
		interp.variables.set('video', {
			play:       function(key:String, ?onComplete:Dynamic) {
				funkin.cutscenes.VideoManager.playCutscene(key, onComplete);
			},
			playMidSong: function(key:String, ?onComplete:Dynamic) {
				funkin.cutscenes.VideoManager.playMidSong(key, onComplete);
			},
			stop:       function() { funkin.cutscenes.VideoManager.stop(); },
			pause:      function() { funkin.cutscenes.VideoManager.pause(); },
			isPlaying:  function():Bool { return funkin.cutscenes.VideoManager.isPlaying; },
			onSprite:   function(key:String, sprite:Dynamic, ?onComplete:Dynamic) {
				funkin.cutscenes.VideoManager.playOnSprite(key, sprite, onComplete);
			}
		});
	}

	// ─── Highscore ────────────────────────────────────────────────────────────

	static function exposeHighscore(interp:Interp):Void
	{
		interp.variables.set('Highscore', funkin.gameplay.objects.hud.Highscore);
		interp.variables.set('highscore', {
			saveScore:  function(song:String, score:Int, ?diff:Int) {
				funkin.gameplay.objects.hud.Highscore.saveScore(song, score, diff != null ? diff : 0);
			},
			getScore:   function(song:String, diff:Int):Int {
				return funkin.gameplay.objects.hud.Highscore.getScore(song, diff);
			},
			getRating:  function(song:String, diff:Int):Float {
				return funkin.gameplay.objects.hud.Highscore.getRating(song, diff);
			},
			saveWeek:   function(week:Int, score:Int, ?diff:Int) {
				funkin.gameplay.objects.hud.Highscore.saveWeekScore(week, score, diff != null ? diff : 0);
			},
			getWeek:    function(week:Int, diff:Int):Int {
				return funkin.gameplay.objects.hud.Highscore.getWeekScore(week, diff);
			},
			format:     function(song:String, diff:Int):String {
				return funkin.gameplay.objects.hud.Highscore.formatSong(song, diff);
			},
			load:       function() { funkin.gameplay.objects.hud.Highscore.load(); }
		});
	}

	// ─── Ranking ──────────────────────────────────────────────────────────────

	static function exposeRanking(interp:Interp):Void
	{
		interp.variables.set('Ranking', funkin.data.Ranking);
		interp.variables.set('ranking', {
			getLetterRank: function():String { return funkin.data.Ranking.generateLetterRank(); }
		});
	}

	// ─── CharacterList ────────────────────────────────────────────────────────

	static function exposeCharacterList(interp:Interp):Void
	{
		interp.variables.set('CharacterList', funkin.gameplay.objects.character.CharacterList);
		interp.variables.set('charList', {
			boyfriends:  function():Array<String> { return funkin.gameplay.objects.character.CharacterList.boyfriends; },
			opponents:   function():Array<String> { return funkin.gameplay.objects.character.CharacterList.opponents; },
			girlfriends: function():Array<String> { return funkin.gameplay.objects.character.CharacterList.girlfriends; },
			stages:      function():Array<String> { return funkin.gameplay.objects.character.CharacterList.stages; },
			getName:     function(char:String):String {
				return funkin.gameplay.objects.character.CharacterList.getCharacterName(char);
			},
			getStageName: function(stage:String):String {
				return funkin.gameplay.objects.character.CharacterList.getStageName(stage);
			},
			getDefaultStage: function(song:String):String {
				return funkin.gameplay.objects.character.CharacterList.getDefaultStageForSong(song);
			}
		});
	}

	// ─── PlayStateConfig ──────────────────────────────────────────────────────

	static function exposePlayStateConfig(interp:Interp):Void
	{
		interp.variables.set('PlayStateConfig', funkin.gameplay.PlayStateConfig);
		// Constantes inline — hay que leerlas en tiempo de compilación
		interp.variables.set('PSC', {
			DEFAULT_ZOOM     : 1.05,
			PIXEL_ZOOM       : 6.0,
			STRUM_LINE_Y     : 50.0,
			NOTE_SPAWN_TIME  : 3000.0,
			SICK_WINDOW      : 45.0,
			GOOD_WINDOW      : 90.0,
			BAD_WINDOW       : 135.0,
			SHIT_WINDOW      : 166.0,
			SICK_SCORE       : 350,
			GOOD_SCORE       : 200,
			BAD_SCORE        : 100,
			SHIT_SCORE       : 50,
			SICK_HEALTH      : 0.1,
			GOOD_HEALTH      : 0.05,
			BAD_HEALTH       : -0.03,
			SHIT_HEALTH      : -0.03,
			MISS_HEALTH      : -0.04,
			CAM_LERP_SPEED   : 2.4,
			CAM_ZOOM_AMOUNT  : 0.015,
			CAM_HUD_ZOOM_AMOUNT: 0.03
		});
	}

	// ─── Transition ───────────────────────────────────────────────────────────

	static function exposeTransition(interp:Interp):Void
	{
		interp.variables.set('StateTransition', funkin.transitions.StateTransition);
		interp.variables.set('StickerTransition', funkin.transitions.StickerTransition);
		interp.variables.set('transition', {
			setNext:    function(?type:Dynamic, ?duration:Float, ?color:Int) {
				funkin.transitions.StateTransition.setNext(type, duration, color);
			},
			setGlobal:  function(?type:Dynamic, ?duration:Float, ?color:Int) {
				funkin.transitions.StateTransition.setGlobal(type, duration, color);
			},
			enable:     function() { funkin.transitions.StateTransition.enabled = true; },
			disable:    function() { funkin.transitions.StateTransition.enabled = false; },
			sticker:    function(?callback:Dynamic) {
				funkin.transitions.StickerTransition.start(callback);
			},
			clearStickers: function(?onDone:Dynamic) {
				funkin.transitions.StickerTransition.clearStickers(onDone);
			},
			stickerActive: function():Bool { return funkin.transitions.StickerTransition.isActive(); }
		});

		// ── Auto-resize: mantener la transición cubriendo toda la ventana ─────────
		// FlxG.width/height son las dimensiones VIRTUALES del juego (p.ej. 1280x720).
		// Cuando el usuario redimensiona la ventana, el stage de OpenFL escala el
		// contenido, pero cualquier overlay que haya creado StateTransition con
		// makeGraphic(FlxG.width, FlxG.height) queda más pequeño que la pantalla real.
		// Solución: escuchar el evento RESIZE del stage y pedir a StateTransition
		// que actualice su tamaño usando las dimensiones reales de la ventana.
		try {
			var stage = openfl.Lib.current.stage;
			if (stage != null) {
				stage.addEventListener(openfl.events.Event.RESIZE, function(_) {
					_fitTransitionToStage();
				});
			}
		} catch(_) {}
	}

	/**
	 * Escala el overlay de StateTransition para que tape toda la ventana real,
	 * independientemente del zoom/resolución virtual del juego.
	 *
	 * StateTransition suele tener un FlxSprite u overlay como campo estático.
	 * Usamos Reflect para accederlo sin depender de la API interna.
	 */
	static function _fitTransitionToStage():Void
	{
		try {
			var stage    = openfl.Lib.current.stage;
			var stageW   = stage.stageWidth;
			var stageH   = stage.stageHeight;

			// Ratio entre la ventana real y el espacio virtual del juego
			var ratioX   = stageW / FlxG.width;
			var ratioY   = stageH / FlxG.height;

			// Intentar con el nombre de campo más común: 'overlay', 'bg', 'transition'
			for (fieldName in ['overlay', 'bg', 'background', 'transitionSprite', 'blackOverlay']) {
				var overlay:Dynamic = Reflect.field(funkin.transitions.StateTransition, fieldName);
				if (overlay == null) continue;

				// Si el sprite fue creado con makeGraphic, la manera más limpia de
				// cubrirlo todo es a través de scale, no recreando el bitmap.
				overlay.scale.x = ratioX;
				overlay.scale.y = ratioY;
				overlay.updateHitbox();
				overlay.screenCenter();
			}

			// También llamar a un posible método resize() si existe
			var resizeFn:Dynamic = Reflect.field(funkin.transitions.StateTransition, 'resize');
			if (resizeFn != null)
				Reflect.callMethod(null, resizeFn, [stageW, stageH]);

		} catch(_) {}
	}

	// ─── CharacterController y CameraController ───────────────────────────────

	static function exposeControllers(interp:Interp):Void
	{
		interp.variables.set('charController', {
			get: function():Dynamic {
				final ps = funkin.gameplay.PlayState.instance;
				return ps != null ? Reflect.field(ps, 'characterController') : null;
			},
			sing: function(charIdx:Int, noteData:Int, ?altAnim:String) {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps == null) return;
				final cc = Reflect.field(ps, 'characterController');
				if (cc != null) cc.singByIndex(charIdx, noteData, altAnim);
			},
			miss: function(charIdx:Int, noteData:Int) {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps == null) return;
				final cc = Reflect.field(ps, 'characterController');
				if (cc != null) cc.missByIndex(charIdx, noteData);
			},
			playSpecialAnim: function(charIdx:Int, animName:String) {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps == null) return;
				final cc = Reflect.field(ps, 'characterController');
				if (cc != null) cc.playSpecialAnimByIndex(charIdx, animName);
			},
			forceIdle: function() {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps == null) return;
				final cc = Reflect.field(ps, 'characterController');
				if (cc != null) cc.forceIdleAll();
			},
			setActive: function(idx:Int, active:Bool) {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps == null) return;
				final cc = Reflect.field(ps, 'characterController');
				if (cc != null) cc.setCharacterActive(idx, active);
			},
			count: function():Int {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps == null) return 0;
				final cc = Reflect.field(ps, 'characterController');
				return cc != null ? cc.getCharacterCount() : 0;
			}
		});

		interp.variables.set('camController', {
			get: function():Dynamic {
				final ps = funkin.gameplay.PlayState.instance;
				return ps != null ? ps.cameraController : null;
			},
			setTarget:      function(target:String, ?snap:Bool) {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps != null && ps.cameraController != null)
					ps.cameraController.setTarget(target, snap ?? false);
			},
			setFollowLerp:  function(lerp:Float) {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps != null && ps.cameraController != null)
					ps.cameraController.setFollowLerp(lerp);
			},
			bumpZoom:       function() {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps != null && ps.cameraController != null) ps.cameraController.bumpZoom();
			},
			tweenZoomIn:    function() {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps != null && ps.cameraController != null) ps.cameraController.tweenZoomIn();
			},
			shake:          function(?intensity:Float, ?duration:Float) {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps != null && ps.cameraController != null)
					ps.cameraController.shake(intensity ?? 0.05, duration ?? 0.1);
			},
			flash:          function(?duration:Float, ?color:Int) {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps != null && ps.cameraController != null)
					ps.cameraController.flash(duration ?? 0.5, color ?? 0xFFFFFFFF);
			},
			setZoomEnabled: function(v:Bool) {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps != null && ps.cameraController != null) ps.cameraController.zoomEnabled = v;
			},
			getTarget:      function():String {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps == null || ps.cameraController == null) return '';
				return ps.cameraController.currentTarget;
			}
		});
	}

	// ─── MetaData ─────────────────────────────────────────────────────────────

	static function exposeMetaData(interp:Interp):Void
	{
		interp.variables.set('songMeta', {
			get:           function():Dynamic {
				final ps = funkin.gameplay.PlayState.instance;
				return ps != null ? Reflect.field(ps, 'metaData') : null;
			},
			noteSkin:      function():String {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps == null) return 'default';
				final md = Reflect.field(ps, 'metaData');
				return md != null ? md.noteSkin : 'default';
			},
			hudVisible:    function():Bool {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps == null) return true;
				final md = Reflect.field(ps, 'metaData');
				return md != null ? md.hudVisible : true;
			},
			hideCombo:     function():Bool {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps == null) return false;
				final md = Reflect.field(ps, 'metaData');
				return md != null ? md.hideCombo : false;
			},
			hideRatings:   function():Bool {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps == null) return false;
				final md = Reflect.field(ps, 'metaData');
				return md != null ? md.hideRatings : false;
			},
			load:          function(songName:String):Dynamic {
				return funkin.data.MetaData.load(songName);
			}
		});
	}

	// ─── GlobalConfig ─────────────────────────────────────────────────────────

	static function exposeGlobalConfig(interp:Interp):Void
	{
		interp.variables.set('GlobalConfig', funkin.data.GlobalConfig);
		interp.variables.set('config', {
			get:       function():Dynamic { return funkin.data.GlobalConfig.instance; },
			ui:        function():String  { return funkin.data.GlobalConfig.instance.ui; },
			noteSkin:  function():String  { return funkin.data.GlobalConfig.instance.noteSkin; },
			noteSplash: function():String { return funkin.data.GlobalConfig.instance.noteSplash; },
			reload:    function() { funkin.data.GlobalConfig.reload(); },
			save:      function() { funkin.data.GlobalConfig.instance.save(); }
		});
	}

	// ─── ScriptHandler ────────────────────────────────────────────────────────

	static function exposeScriptHandler(interp:Interp):Void
	{
		interp.variables.set('ScriptHandler', funkin.scripting.ScriptHandler);
		interp.variables.set('scripts', {
			// Llamar a una función en TODOS los scripts activos
			call:     function(funcName:String, ?args:Array<Dynamic>) {
				funkin.scripting.ScriptHandler.callOnScripts(funcName, args ?? []);
			},
			// Setear una variable en todos los scripts
			setVar:   function(name:String, value:Dynamic) {
				funkin.scripting.ScriptHandler.setOnScripts(name, value);
			},
			// Obtener un script específico por nombre
			getStage: function(name:String):Dynamic {
				return funkin.scripting.ScriptHandler.stageScripts.get(name);
			},
			getSong:  function(name:String):Dynamic {
				return funkin.scripting.ScriptHandler.songScripts.get(name);
			},
			getGlobal: function(name:String):Dynamic {
				return funkin.scripting.ScriptHandler.globalScripts.get(name);
			}
		});
	}

	// ─── Countdown ────────────────────────────────────────────────────────────

	static function exposeCountdown(interp:Interp):Void
	{
		interp.variables.set('Countdown', funkin.gameplay.Countdown);
		interp.variables.set('countdown', {
			// Referencia al countdown activo del PlayState
			get:     function():Dynamic {
				final ps = funkin.gameplay.PlayState.instance;
				return ps != null ? Reflect.field(ps, 'countdown') : null;
			},
			// Cancelar el countdown actual
			cancel:  function() {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps == null) return;
				final cd = Reflect.field(ps, 'countdown');
				if (cd != null) cd.cancel();
			},
			// Si el countdown terminó
			finished: function():Bool {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps == null) return false;
				final cd = Reflect.field(ps, 'countdown');
				return cd != null ? cd.finished : false;
			},
			running:  function():Bool {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps == null) return false;
				final cd = Reflect.field(ps, 'countdown');
				return cd != null ? cd.running : false;
			},
			// Skins predefinidas
			SKIN_NORMAL: funkin.gameplay.Countdown.SKIN_NORMAL,
			SKIN_PIXEL:  funkin.gameplay.Countdown.SKIN_PIXEL
		});
	}

	// ─── ModPaths completo ────────────────────────────────────────────────────

	static function exposeModPaths(interp:Interp):Void
	{
		interp.variables.set('ModPaths', mods.ModPaths);
		// Alias conveniente — todas las funciones de ModPaths como lambdas
		// (ModPaths tiene funciones static inline que no son accesibles por reflexión)
		interp.variables.set('modpaths', {
			resolve:        function(file:String, ?mod:String):String {
				return mods.ModPaths.resolve(file, mod);
			},
			txt:            function(key:String, ?mod:String):String { return mods.ModPaths.txt(key, mod); },
			xml:            function(key:String, ?mod:String):String { return mods.ModPaths.xml(key, mod); },
			json:           function(key:String, ?mod:String):String { return mods.ModPaths.json(key, mod); },
			songJson:       function(song:String, ?diff:String, ?mod:String):String {
				return mods.ModPaths.songJson(song, diff != null ? diff : 'Hard', mod);
			},
			inst:           function(song:String, ?mod:String):String { return mods.ModPaths.inst(song, mod); },
			voices:         function(song:String, ?mod:String):String { return mods.ModPaths.voices(song, mod); },
			characterJSON:  function(key:String, ?mod:String):String { return mods.ModPaths.characterJSON(key, mod); },
			characterImage: function(key:String, ?mod:String):String { return mods.ModPaths.characterImage(key, mod); },
			stageJSON:      function(key:String, ?mod:String):String { return mods.ModPaths.stageJSON(key, mod); },
			image:          function(key:String, ?mod:String):String { return mods.ModPaths.image(key, mod); },
			bgImage:        function(key:String, ?mod:String):String { return mods.ModPaths.bgImage(key, mod); },
			iconImage:      function(key:String, ?mod:String):String { return mods.ModPaths.iconImage(key, mod); },
			shader:         function(key:String, ?mod:String):String { return mods.ModPaths.shader(key, mod); }
		});
	}

	#end // HSCRIPT_ALLOWED

	// ═══════════════════════════════════════════════════════════════════════════
	//  PROXIES (disponibles incluso sin HSCRIPT_ALLOWED, usados por exposeImport)
	// ═══════════════════════════════════════════════════════════════════════════

	/**
	 * Proxy para ShaderManager como objeto anonimo.
	 * En targets C++ los metodos estaticos no son reflectables directamente,
	 * por lo que pasar la clase raw hace que HScript devuelva null al llamarlos.
	 * Este wrapper funciona igual que los proxies de FlxEase y FlxColor.
	 */
	static function _shaderManagerProxy():Dynamic
	{
		return {
			applyShader         : shaders.ShaderManager.applyShader,
			removeShader        : shaders.ShaderManager.removeShader,
			setShaderParam      : shaders.ShaderManager.setShaderParam,
			clearSpriteShaders  : shaders.ShaderManager.clearSpriteShaders,
			loadShader          : shaders.ShaderManager.loadShader,
			getShader           : shaders.ShaderManager.getShader,
			getAvailableShaders : shaders.ShaderManager.getAvailableShaders,
			scanShaders         : shaders.ShaderManager.scanShaders,
			reloadShader        : shaders.ShaderManager.reloadShader,
			reloadAllShaders    : shaders.ShaderManager.reloadAllShaders,
			clear               : shaders.ShaderManager.clear,
		};
	}

	static function _flxColorProxy():Dynamic
	{
		return {
			TRANSPARENT : (flixel.util.FlxColor.TRANSPARENT : Int),
			WHITE       : (flixel.util.FlxColor.WHITE        : Int),
			BLACK       : (flixel.util.FlxColor.BLACK        : Int),
			RED         : (flixel.util.FlxColor.RED          : Int),
			GREEN       : (flixel.util.FlxColor.GREEN        : Int),
			BLUE        : (flixel.util.FlxColor.BLUE         : Int),
			YELLOW      : (flixel.util.FlxColor.YELLOW       : Int),
			ORANGE      : (flixel.util.FlxColor.ORANGE       : Int),
			CYAN        : (flixel.util.FlxColor.CYAN         : Int),
			MAGENTA     : (flixel.util.FlxColor.MAGENTA      : Int),
			PURPLE      : (flixel.util.FlxColor.PURPLE       : Int),
			PINK        : (flixel.util.FlxColor.PINK         : Int),
			BROWN       : (flixel.util.FlxColor.BROWN        : Int),
			GRAY        : (flixel.util.FlxColor.GRAY         : Int),
			LIME        : (flixel.util.FlxColor.LIME         : Int),
			fromRGB     : function(r:Int, g:Int, b:Int, ?a:Int):Int {
				return (flixel.util.FlxColor.fromRGB(r, g, b, a == null ? 255 : a) : Int);
			},
			fromHSB     : function(h:Float, s:Float, b:Float, ?a:Float):Int {
				return (flixel.util.FlxColor.fromHSB(h, s, b, a == null ? 1.0 : a) : Int);
			},
			fromHSL     : function(h:Float, s:Float, l:Float, ?a:Float):Int {
				return (flixel.util.FlxColor.fromHSL(h, s, l, a == null ? 1.0 : a) : Int);
			},
			fromString  : function(s:String):Int { return (flixel.util.FlxColor.fromString(s) : Int); },
			fromInt     : function(v:Int):Int return v,
			toString    : function(c:Int):String { return (c : flixel.util.FlxColor).toHexString(true); },
			interpolate : function(a:Int, b:Int, t:Float):Int {
				return (flixel.util.FlxColor.interpolate(
					(a : flixel.util.FlxColor), (b : flixel.util.FlxColor), t) : Int);
			}
		};
	}

	static function _flxEaseProxy():Dynamic
	{
		return {
			linear      : FlxEase.linear,
			quadIn      : FlxEase.quadIn,      quadOut     : FlxEase.quadOut,      quadInOut   : FlxEase.quadInOut,
			cubeIn      : FlxEase.cubeIn,      cubeOut     : FlxEase.cubeOut,      cubeInOut   : FlxEase.cubeInOut,
			quartIn     : FlxEase.quartIn,     quartOut    : FlxEase.quartOut,     quartInOut  : FlxEase.quartInOut,
			quintIn     : FlxEase.quintIn,     quintOut    : FlxEase.quintOut,     quintInOut  : FlxEase.quintInOut,
			sineIn      : FlxEase.sineIn,      sineOut     : FlxEase.sineOut,      sineInOut   : FlxEase.sineInOut,
			bounceIn    : FlxEase.bounceIn,    bounceOut   : FlxEase.bounceOut,    bounceInOut : FlxEase.bounceInOut,
			circIn      : FlxEase.circIn,      circOut     : FlxEase.circOut,      circInOut   : FlxEase.circInOut,
			expoIn      : FlxEase.expoIn,      expoOut     : FlxEase.expoOut,      expoInOut   : FlxEase.expoInOut,
			backIn      : FlxEase.backIn,      backOut     : FlxEase.backOut,      backInOut   : FlxEase.backInOut,
			elasticIn   : FlxEase.elasticIn,   elasticOut  : FlxEase.elasticOut,   elasticInOut: FlxEase.elasticInOut,
			smoothStepIn: FlxEase.smoothStepIn, smoothStepOut: FlxEase.smoothStepOut,
			smootherStepIn: FlxEase.smootherStepIn, smootherStepOut: FlxEase.smootherStepOut
		};
	}

	static function _flxPointProxy():Dynamic
	{
		return {
			get   : function(x:Float = 0, y:Float = 0):flixel.math.FlxPoint return flixel.math.FlxPoint.get(x, y),
			weak  : function(x:Float = 0, y:Float = 0):flixel.math.FlxPoint return flixel.math.FlxPoint.weak(x, y),
			floor : function(p:flixel.math.FlxPoint):flixel.math.FlxPoint return p.floor(),
			ceil  : function(p:flixel.math.FlxPoint):flixel.math.FlxPoint return p.ceil(),
			round : function(p:flixel.math.FlxPoint):flixel.math.FlxPoint return p.round()
		};
	}

	static function _flxRectProxy():Dynamic
	{
		return {
			get : function(x:Float = 0, y:Float = 0, w:Float = 0, h:Float = 0):flixel.math.FlxRect
				return flixel.math.FlxRect.get(x, y, w, h),
			weak: function(x:Float = 0, y:Float = 0, w:Float = 0, h:Float = 0):flixel.math.FlxRect
				return flixel.math.FlxRect.weak(x, y, w, h)
		};
	}
}
