package funkin.scripting;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import funkin.transitions.StateTransition;
import funkin.transitions.StickerTransition;
import funkin.scripting.ScriptableState.ScriptableSubState;

#if HSCRIPT_ALLOWED
import hscript.Interp;
#end

/**
 * ScriptAPI v4 — API completa expuesta a los scripts HScript.
 *
 * ─── Nuevas categorías en v4 ─────────────────────────────────────────────────
 *
 *  `mod`    — información del mod activo, rutas, assets, manifest
 *  `char`   — acceso directo a personajes de PlayState (bf, dad, gf)
 *  `camera` — control de cámaras sin acceder a PlayState directamente
 *  `hud`    — control del HUD (healthbar, score text, visibilidad)
 *
 * ─── Compatibilidad garantizada ──────────────────────────────────────────────
 *  Funciona con o sin FlxSignal (no es requisito).
 *  `importClass` usa Reflect: funciona con cualquier versión de OpenFL/Flixel.
 *  El objeto `states` usa null-checks en todos sus accesos a FlxG.state.
 *
 * @author Cool Engine Team
 * @version 4.0.0
 */
class ScriptAPI
{
	#if HSCRIPT_ALLOWED

	public static function expose(interp:Interp):Void
	{
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
		exposeMod(interp);          // NUEVO v4
		exposeCharacters(interp);   // NUEVO v4
		exposeCamera(interp);       // NUEVO v4
		exposeHUD(interp);          // NUEVO v4
	}

	// ─── Flixel core ──────────────────────────────────────────────────────────

	static function exposeFlixel(interp:Interp):Void
	{
		interp.variables.set('FlxG',       FlxG);
		interp.variables.set('FlxSprite',  FlxSprite);
		interp.variables.set('FlxTween',   FlxTween);
		interp.variables.set('FlxEase',    _flxEaseProxy());
		interp.variables.set('FlxColor',   _flxColorProxy());
		interp.variables.set('FlxTimer',   FlxTimer);
		interp.variables.set('FunkinSprite', animationdata.FunkinSprite);

		// Tipos adicionales útiles
		interp.variables.set('FlxText',       flixel.text.FlxText);
		interp.variables.set('FlxGroup',      flixel.group.FlxGroup);
		interp.variables.set('FlxSpriteGroup', flixel.group.FlxSpriteGroup);
		// BUGFIX: FlxMath.lerp (y otros) son `static inline` en HaxeFlixel.
		// Las funciones inline se eliminan en tiempo de compilación (C++/HL) y devuelven
		// null cuando se accede a ellas por reflexión — HScript llama null → "Null Function Pointer".
		// Solución: exponer un proxy con lambdas equivalentes para las funciones inline.
		// BUGFIX: FlxMath.lerp y compañía son `static inline` en HaxeFlixel.
		// Las funciones inline se eliminan en compilación (C++/HL) → reflexión devuelve null
		// → HScript lanza "Null Function Pointer" en cada frame de onUpdate.
		// Solución: proxy con lambdas equivalentes para todas las funciones inline,
		// y referencias directas solo para las que son accesibles por reflexión.
		// NOTA: numDigits, getDistance, getDegreesFromRadians, getRadiansFromDegrees
		// NO existen en la versión de FlxMath de este proyecto — los omitimos.
		interp.variables.set('FlxMath', {
			// ── Inline wrappers ───────────────────────────────────────────────────
			lerp          : function(a:Float, b:Float, ratio:Float):Float return a + (b - a) * ratio,
			fastSin       : function(angle:Float):Float return Math.sin(angle),
			fastCos       : function(angle:Float):Float return Math.cos(angle),
			// ── Non-inline: solo los que existen en esta versión de FlxMath ──────
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
		interp.variables.set('FlxPoint',      _flxPointProxy());
		interp.variables.set('FlxRect',       _flxRectProxy());
		interp.variables.set('FlxAngle',      flixel.math.FlxAngle);

		// OpenFL
		interp.variables.set('BitmapData',    openfl.display.BitmapData);
		interp.variables.set('Sound',         openfl.media.Sound);
	}

	// ─── Gameplay ─────────────────────────────────────────────────────────────

	static function exposeGameplay(interp:Interp):Void
	{
		interp.variables.set('PlayState',          funkin.gameplay.PlayState);
		interp.variables.set('game',               funkin.gameplay.PlayState.instance);
		interp.variables.set('Conductor',          funkin.data.Conductor);
		interp.variables.set('Paths',              Paths);
		interp.variables.set('MetaData',           funkin.data.MetaData);
		interp.variables.set('GlobalConfig',       funkin.data.GlobalConfig);
		interp.variables.set('Song',               funkin.data.Song);
		interp.variables.set('Note',               funkin.gameplay.notes.Note);
		interp.variables.set('NoteSkinSystem',     funkin.gameplay.notes.NoteSkinSystem);
		interp.variables.set('NotePool',           funkin.gameplay.notes.NotePool);
		interp.variables.set('NoteTypeManager',    funkin.gameplay.notes.NoteTypeManager);
		interp.variables.set('ModManager',         mods.ModManager);
		interp.variables.set('ModPaths',           mods.ModPaths);
	}

	// ─── Scoring custom ───────────────────────────────────────────────────────

	static function exposeScoring(interp:Interp):Void
	{
		interp.variables.set('score', {
			setWindow: function(rating:String, ms:Float) {
				final sm = funkin.gameplay.objects.hud.ScoreManager;
				switch (rating.toLowerCase())
				{
					case 'sick':  Reflect.setField(sm, 'SICK_WINDOW',  ms);
					case 'good':  Reflect.setField(sm, 'GOOD_WINDOW',  ms);
					case 'bad':   Reflect.setField(sm, 'BAD_WINDOW',   ms);
					case 'shit':  Reflect.setField(sm, 'SHIT_WINDOW',  ms);
				}
			},
			setPoints: function(rating:String, pts:Int) {
				final sm = funkin.gameplay.objects.hud.ScoreManager;
				switch (rating.toLowerCase())
				{
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
			getCombo:     function():Int {
				final i = funkin.gameplay.PlayState.instance;
				return i != null ? i.scoreManager.combo : 0;
			},
			getScore:     function():Int {
				final i = funkin.gameplay.PlayState.instance;
				return i != null ? i.scoreManager.score : 0;
			},
			addScore:     function(n:Int) {
				final i = funkin.gameplay.PlayState.instance;
				if (i != null) i.scoreManager.score += n;
			},
			resetCombo:   function() {
				final i = funkin.gameplay.PlayState.instance;
				if (i != null) { i.scoreManager.combo = 0; i.scoreManager.fullCombo = false; }
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
			exists:     function(name:String):Bool {
				return funkin.gameplay.notes.NoteTypeManager.exists(name);
			},
			list:       function():Array<String> {
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
			openSubState:       function(name:String) {
				final ss = new ScriptableSubState(name);
				if (FlxG.state != null) FlxG.state.openSubState(ss);
			},
			openSubStateInstance: function(ss:flixel.FlxSubState) {
				if (FlxG.state != null) FlxG.state.openSubState(ss);
			},
			close:              function() { if (FlxG.state != null) FlxG.state.closeSubState(); },
			scripted:           function(name:String) {
				final ss = new ScriptableSubState(name);
				if (FlxG.state != null) FlxG.state.openSubState(ss);
			},
			current:            function():flixel.FlxState { return FlxG.state; }
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
			off:  function(event:String, cb:Dynamic) {
				final arr = _signals.get(event);
				if (arr != null) arr.remove(cb);
			},
			emit: function(event:String, ?data:Dynamic) {
				final arr  = _signals.get(event);
				if (arr != null)
					for (cb in arr.copy()) try { Reflect.callMethod(null, cb, [data]); } catch(_) {}
				final once = _signalsOnce.get(event);
				if (once != null)
				{
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
			set:    function(key:String, value:Dynamic) {
				Reflect.setField(FlxG.save.data, key, value);
			},
			get:    function(key:String, ?fallback:Dynamic):Dynamic {
				final v = Reflect.field(FlxG.save.data, key);
				return v != null ? v : fallback;
			},
			delete: function(key:String) {
				Reflect.deleteField(FlxG.save.data, key);
			},
			has:    function(key:String):Bool {
				return Reflect.hasField(FlxG.save.data, key);
			},
			save:   function() { FlxG.save.flush(); },
			dump:   function():Dynamic { return FlxG.save.data; }
		});
	}

	// ─── Import dinámico ──────────────────────────────────────────────────────

	static function exposeImport(interp:Interp):Void
	{
		// BUGFIX: mismo proxy que en expose() para que import('FlxMath') tampoco devuelva
		// lerp=null por ser inline. Ver comentario detallado más arriba.
		final _flxMathProxy:Dynamic = interp.variables.get('FlxMath');

		// Mapa de clases permitidas para importación dinámica.
		// NOTA: era una expresión suelta `[...]` sin asignar → "_classRegistry" Unknown identifier.
		final _classRegistry:Map<String, Dynamic> = [
			// Flixel
			'FlxSprite'       => FlxSprite,
			'FlxText'         => flixel.text.FlxText,
			'FlxG'            => FlxG,
			'FlxTween'        => FlxTween,
			'FlxEase'         => _flxEaseProxy(),
			'FlxColor'        => _flxColorProxy(),
			'FlxTimer'        => FlxTimer,
			'FlxMath'         => _flxMathProxy,   // BUGFIX: proxy sin inline, no la clase directa
			'FlxPoint'        => _flxPointProxy(),
			'FlxSpriteGroup'  => flixel.group.FlxSpriteGroup,
			'FlxGroup'        => flixel.group.FlxGroup,
			// Funkin
			'PlayState'       => funkin.gameplay.PlayState,
			'Conductor'       => funkin.data.Conductor,
			'Paths'           => Paths,
			'Note'            => funkin.gameplay.notes.Note,
			'NotePool'        => funkin.gameplay.notes.NotePool,
			'ModManager'      => mods.ModManager,
			'ModPaths'        => mods.ModPaths,
			// OpenFL
			'BitmapData'      => openfl.display.BitmapData,
			'Sound'           => openfl.media.Sound,
		];

		interp.variables.set('importClass', function(className:String):Dynamic {
			if (_classRegistry.exists(className)) return _classRegistry.get(className);
			// Fallback: Type.resolveClass (requiere que el tipo esté en el build)
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
			clamp:      function(v:Float, min:Float, max:Float):Float return Math.min(Math.max(v, min), max),
			map:        function(v:Float, i0:Float, i1:Float, o0:Float, o1:Float):Float {
				return o0 + (v - i0) / (i1 - i0) * (o1 - o0);
			},
			norm:       function(v:Float, min:Float, max:Float):Float return (v - min) / (max - min),
			snap:       function(v:Float, step:Float):Float return Math.round(v / step) * step,
			pingpong:   function(v:Float, len:Float):Float {
				final t = v % (len * 2);
				return t < len ? t : len * 2 - t;
			},
			sign:       function(v:Float):Int return v > 0 ? 1 : (v < 0 ? -1 : 0),
			// Random
			rnd:        function(min:Int, max:Int):Int return FlxG.random.int(min, max),
			rndf:       function(min:Float, max:Float):Float return FlxG.random.float(min, max),
			chance:     function(pct:Float):Bool return FlxG.random.float() < pct,
			// Geometría
			dist:       function(x1:Float, y1:Float, x2:Float, y2:Float):Float {
				final dx = x2 - x1; final dy = y2 - y1;
				return Math.sqrt(dx * dx + dy * dy);
			},
			angle:      function(x1:Float, y1:Float, x2:Float, y2:Float):Float {
				return Math.atan2(y2 - y1, x2 - x1) * (180 / Math.PI);
			},
			// Curvas de Bézier
			bezier:     function(t:Float, p0:Float, p1:Float, p2:Float, p3:Float):Float {
				final u = 1 - t;
				return u*u*u*p0 + 3*u*u*t*p1 + 3*u*t*t*p2 + t*t*t*p3;
			},
			quadBezier: function(t:Float, p0:Float, p1:Float, p2:Float):Float {
				final u = 1 - t;
				return u*u*p0 + 2*u*t*p1 + t*t*p2;
			},
			// Trig en grados
			sin:        function(d:Float):Float return Math.sin(d * Math.PI / 180),
			cos:        function(d:Float):Float return Math.cos(d * Math.PI / 180),
			tan:        function(d:Float):Float return Math.tan(d * Math.PI / 180),
			// Constantes
			PI:   Math.PI,
			TAU:  Math.PI * 2,
			E:    Math.exp(1.0),
			SQRT2: Math.sqrt(2.0),
			INF:  Math.POSITIVE_INFINITY
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
				for (i in 0...r.length)
				{
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
			sum:     function(a:Array<Float>):Float {
				var s = 0.0; for (x in a) s += x; return s;
			},
			max:     function(a:Array<Float>):Float {
				var m = Math.NEGATIVE_INFINITY; for (x in a) if (x > m) m = x; return m;
			},
			min:     function(a:Array<Float>):Float {
				var m = Math.POSITIVE_INFINITY; for (x in a) if (x < m) m = x; return m;
			},
			sortBy:  function(a:Array<Dynamic>, key:String):Array<Dynamic> {
				final r = a.copy();
				r.sort(function(x, y) {
					final vx = Reflect.field(x, key);
					final vy = Reflect.field(y, key);
					if (vx < vy) return -1;
					if (vx > vy) return  1;
					return 0;
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

	// ─── NUEVO v4: Mod info ────────────────────────────────────────────────────

	/**
	 * Objeto `mod` — información y utilidades del mod activo.
	 *
	 *   mod.isActive()           → true si hay un mod cargado
	 *   mod.name()               → nombre del mod activo
	 *   mod.root()               → ruta raíz del mod (string)
	 *   mod.path('images/bg')    → ruta completa en el mod
	 *   mod.exists('images/bg')  → true si el asset existe en el mod
	 *   mod.list()               → Array de mods instalados
	 *   mod.info()               → ModInfo del mod activo
	 */
	static function exposeMod(interp:Interp):Void
	{
		interp.variables.set('mod', {
			isActive: function():Bool   return mods.ModManager.isActive(),
			name:     function():String return mods.ModManager.activeMod ?? 'base',
			root:     function():String return mods.ModManager.isActive() ? mods.ModManager.modRoot() : 'assets',
			path:     function(rel:String):String {
				if (mods.ModManager.isActive())
					return '${mods.ModManager.modRoot()}/$rel';
				return 'assets/$rel';
			},
			exists:   function(rel:String):Bool {
				#if sys
				if (mods.ModManager.isActive())
				{
					final p = '${mods.ModManager.modRoot()}/$rel';
					if (sys.FileSystem.exists(p)) return true;
				}
				return sys.FileSystem.exists('assets/$rel');
				#else
				return false;
				#end
			},
			list:     function():Array<String> {
				return [for (m in mods.ModManager.installedMods) m.id];
			},
			info:     function():Dynamic {
				final id = mods.ModManager.activeMod;
				if (id == null) return null;
				for (m in mods.ModManager.installedMods)
					if (m.id == id) return m;
				return null;
			},
			// Cargar imagen desde el mod con fallback a base
			getImage:  function(name:String):Dynamic {
				return Paths.image(name);
			},
			// Cargar sonido desde el mod con fallback a base
			getSound:  function(name:String):Dynamic {
				return Paths.sound(name);
			},
			// Cargar música desde el mod con fallback a base
			getMusic:  function(name:String):Dynamic {
				return Paths.music(name);
			}
		});
	}

	// ─── NUEVO v4: Characters ─────────────────────────────────────────────────

	/**
	 * Objeto `chars` — acceso directo a los personajes del PlayState.
	 *
	 *   chars.bf()           → Character del jugador
	 *   chars.dad()          → Character del oponente
	 *   chars.gf()           → Character del GF/espectador
	 *   chars.get(index)     → Character por índice
	 *   chars.playAnim(c, a) → c.playAnim(a, true)
	 *   chars.setVisible(c, b)
	 */
	static function exposeCharacters(interp:Interp):Void
	{
		interp.variables.set('chars', {
			bf:          function():Dynamic {
				final ps = funkin.gameplay.PlayState.instance;
				return ps != null ? ps.boyfriend : null;
			},
			dad:         function():Dynamic {
				final ps = funkin.gameplay.PlayState.instance;
				return ps != null ? ps.dad : null;
			},
			gf:          function():Dynamic {
				final ps = funkin.gameplay.PlayState.instance;
				return ps != null ? ps.gf : null;
			},
			get:         function(idx:Int):Dynamic {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps == null) return null;
				final cc = Reflect.field(ps, 'characterController');
				final c = (cc != null) ? cc.getCharacter(idx) : null;
				return c;
			},
			playAnim:    function(char:Dynamic, anim:String) {
				if (char != null) char.playAnim(anim, true);
			},
			setVisible:  function(char:Dynamic, v:Bool) {
				if (char != null) char.visible = v;
			},
			setPosition: function(char:Dynamic, x:Float, y:Float) {
				if (char != null) { char.x = x; char.y = y; }
			},
			getAnim:     function(char:Dynamic):String {
				if (char == null || char.animation == null) return '';
				final cur = char.animation.curAnim;
				return cur != null ? cur.name : '';
			}
		});
	}

	// ─── NUEVO v4: Camera ─────────────────────────────────────────────────────

	/**
	 * Objeto `camera` — control de cámaras desde script.
	 *
	 *   camera.game     → camGame (FlxCamera)
	 *   camera.hud      → camHUD  (FlxCamera)
	 *   camera.other    → camOther
	 *   camera.zoom(v)  → camGame.zoom = v
	 *   camera.shake()  → efecto de shake
	 *   camera.flash()  → efecto de flash
	 *   camera.fade()   → efecto de fade
	 *   camera.focusBf()
	 *   camera.focusDad()
	 */
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
			focusBf: function() {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps != null && ps.cameraController != null) ps.cameraController.setTarget('bf');
			},
			focusDad: function() {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps != null && ps.cameraController != null) ps.cameraController.setTarget('opponent');
			}
		});
	}

	// ─── NUEVO v4: HUD ────────────────────────────────────────────────────────

	/**
	 * Objeto `hud` — control del HUD del PlayState.
	 *
	 *   hud.setVisible(b)      → mostrar/ocultar HUD completo
	 *   hud.setHealth(v)       → health 0.0-2.0
	 *   hud.setScoreVisible(b)
	 *   hud.showRating(r)      → mostrar rating popup
	 */
	static function exposeHUD(interp:Interp):Void
	{
		interp.variables.set('hud', {
			setVisible: function(v:Bool) {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps != null && ps.uiManager != null)
					Reflect.setField(ps.uiManager, 'visible', v);
			},
			setHealth: function(v:Float) {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps != null && ps.gameState != null) ps.gameState.health = v;
			},
			getHealth: function():Float {
				final ps = funkin.gameplay.PlayState.instance;
				return (ps != null && ps.gameState != null) ? ps.gameState.health : 1.0;
			},
			setScoreVisible: function(v:Bool) {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps != null && ps.uiManager != null)
				{
					final txt = Reflect.field(ps.uiManager, 'scoreText');
					if (txt != null) txt.visible = v;
				}
			},
			showRating: function(rating:String, ?combo:Int) {
				final ps = funkin.gameplay.PlayState.instance;
				if (ps != null && ps.uiManager != null)
					ps.uiManager.showRatingPopup(rating, combo ?? ps.scoreManager.combo);
			}
		});
	}

	// ─── Shaders ──────────────────────────────────────────────────────────────

	static function exposeShaders(interp:Interp):Void
	{
		interp.variables.set('ShaderManager', shaders.ShaderManager);
		interp.variables.set('WaveEffect',    shaders.WaveEffect);
		interp.variables.set('WiggleEffect',  shaders.WiggleEffect);
	}

	// ─── Window ───────────────────────────────────────────────────────────────

	static function exposeWindow(interp:Interp):Void
	{
		interp.variables.set('Window', {
			setTitle:  function(t:String) { try { openfl.Lib.application.window.title = t; } catch(_) {} },
			getTitle:  function():String  { try { return openfl.Lib.application.window.title; } catch(_) { return ''; } },
			setFPS:    function(fps:Int)  { FlxG.updateFramerate = fps; FlxG.drawFramerate = fps; },
			getFPS:    function():Int     { return FlxG.updateFramerate; }
		});
	}

	// ─── Visibility ───────────────────────────────────────────────────────────

	static function exposeVisibility(interp:Interp):Void
	{
		interp.variables.set('show', function(spr:Dynamic) { if (spr != null) { spr.visible = true;  spr.active = true; }});
		interp.variables.set('hide', function(spr:Dynamic) { if (spr != null) { spr.visible = false; spr.active = false; }});
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
		interp.variables.set('trace',       function(v:Dynamic) trace('[Script] $v'));
		interp.variables.set('print',       function(v:Dynamic) trace('[Script] $v'));
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
		});
	}

	#end // HSCRIPT_ALLOWED
	// ── FlxColor proxy ───────────────────────────────────────────────────────
	// FlxColor is an abstract(Int) so it cannot be passed as a plain value to
	// HScript. We expose a Dynamic object with all constants + factory methods.
	static function _flxColorProxy():Dynamic
	{
		return {
			// Constants
			TRANSPARENT : (flixel.util.FlxColor.TRANSPARENT  : Int),
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
			// Factory methods
			fromRGB     : function(r:Int, g:Int, b:Int, ?a:Int):Int {
				var c = flixel.util.FlxColor.fromRGB(r, g, b, a == null ? 255 : a);
				return (c : Int);
			},
			fromHSB     : function(h:Float, s:Float, b:Float, ?a:Float):Int {
				var c = flixel.util.FlxColor.fromHSB(h, s, b, a == null ? 1.0 : a);
				return (c : Int);
			},
			fromHSL     : function(h:Float, s:Float, l:Float, ?a:Float):Int {
				var c = flixel.util.FlxColor.fromHSL(h, s, l, a == null ? 1.0 : a);
				return (c : Int);
			},
			fromString  : function(s:String):Int {
				var c = flixel.util.FlxColor.fromString(s);
				return (c : Int);
			},
			fromInt     : function(v:Int):Int return v,
			toString    : function(c:Int):String {
				return (c : flixel.util.FlxColor).toHexString(true);
			},
			interpolate : function(a:Int, b:Int, t:Float):Int {
				var c = flixel.util.FlxColor.interpolate((a:flixel.util.FlxColor), (b:flixel.util.FlxColor), t);
				return (c : Int);
			}
		};
	}

	// ── FlxEase proxy ────────────────────────────────────────────────────────
	static function _flxEaseProxy():Dynamic
	{
		return {
			linear     : FlxEase.linear,
			quadIn     : FlxEase.quadIn,     quadOut    : FlxEase.quadOut,    quadInOut  : FlxEase.quadInOut,
			cubeIn     : FlxEase.cubeIn,     cubeOut    : FlxEase.cubeOut,    cubeInOut  : FlxEase.cubeInOut,
			quartIn    : FlxEase.quartIn,    quartOut   : FlxEase.quartOut,   quartInOut : FlxEase.quartInOut,
			quintIn    : FlxEase.quintIn,    quintOut   : FlxEase.quintOut,   quintInOut : FlxEase.quintInOut,
			sineIn     : FlxEase.sineIn,     sineOut    : FlxEase.sineOut,    sineInOut  : FlxEase.sineInOut,
			bounceIn   : FlxEase.bounceIn,   bounceOut  : FlxEase.bounceOut,  bounceInOut: FlxEase.bounceInOut,
			circIn     : FlxEase.circIn,     circOut    : FlxEase.circOut,    circInOut  : FlxEase.circInOut,
			expoIn     : FlxEase.expoIn,     expoOut    : FlxEase.expoOut,    expoInOut  : FlxEase.expoInOut,
			backIn     : FlxEase.backIn,     backOut    : FlxEase.backOut,    backInOut  : FlxEase.backInOut,
			elasticIn  : FlxEase.elasticIn,  elasticOut : FlxEase.elasticOut, elasticInOut: FlxEase.elasticInOut,
			smoothStepIn: FlxEase.smoothStepIn, smoothStepOut: FlxEase.smoothStepOut, smootherStepIn: FlxEase.smootherStepIn, smootherStepOut: FlxEase.smootherStepOut
		};
	}

	// ── FlxPoint proxy ────────────────────────────────────────────────────────
	static function _flxPointProxy():Dynamic
	{
		return {
			get     : function(x:Float = 0, y:Float = 0):flixel.math.FlxPoint return flixel.math.FlxPoint.get(x, y),
			weak    : function(x:Float = 0, y:Float = 0):flixel.math.FlxPoint return flixel.math.FlxPoint.weak(x, y),
			floor   : function(p:flixel.math.FlxPoint):flixel.math.FlxPoint   return p.floor(),
			ceil    : function(p:flixel.math.FlxPoint):flixel.math.FlxPoint    return p.ceil(),
			round   : function(p:flixel.math.FlxPoint):flixel.math.FlxPoint   return p.round()
		};
	}

	// ── FlxRect proxy ────────────────────────────────────────────────────────
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
