package funkin.scripting;

import haxe.Exception;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

#if HSCRIPT_ALLOWED
import hscript.Parser;
import hscript.Interp;
#end

using StringTools;

/**
 * ScriptHandler v3 — sistema central de scripts para gameplay y mods.
 *
 * ─── Capas de script ─────────────────────────────────────────────────────────
 *
 *   global   → siempre activos (toda la sesión de juego)
 *   stage    → activos durante el stage actual
 *   song     → activos durante la canción actual
 *   ui       → scripts del HUD / UIScriptedManager
 *   menu     → scripts de estados y menús (FreeplayState, TitleState, etc.)
 *   char     → scripts de personaje específico
 *
 * ─── Estructura de carpetas MÁS COMPLETA ────────────────────────────────────
 *
 *   BASE GAME:
 *   assets/data/scripts/global/          → scripts globales base
 *   assets/data/scripts/events/          → handlers de eventos personalizados
 *   assets/songs/{song}/scripts/         → scripts de canción
 *   assets/songs/{song}/events/          → eventos custom de canción
 *   assets/stages/{stage}/scripts/       → scripts de stage
 *   assets/characters/{char}/scripts/    → scripts de personaje
 *   assets/states/{state}/              → scripts de estado / menú
 *
 *   MODS:
 *   mods/{mod}/scripts/global/           → equivalente base
 *   mods/{mod}/scripts/events/
 *   mods/{mod}/songs/{song}/scripts/
 *   mods/{mod}/songs/{song}/events/
 *   mods/{mod}/stages/{stage}/scripts/
 *   mods/{mod}/characters/{char}/scripts/
 *   mods/{mod}/states/{state}/
 *   mods/{mod}/data/scripts/             → alias adicional
 *
 *   PSYCH-COMPAT (rutas adicionales reconocidas):
 *   mods/{mod}/custom_events/{event}.hx
 *   mods/{mod}/custom_notetypes/{type}.hx
 *
 * ─── Compatibilidad de librerías ─────────────────────────────────────────────
 *  hscript 2.4.x y 2.5.x — mismo Parser/Interp API
 *  hscript anterior a allowMetadata: compilación condicional
 *
 * @author Cool Engine Team
 * @version 3.0.0
 */
class ScriptHandler
{
	// ── Almacenamiento de scripts por capa ────────────────────────────────────

	public static var globalScripts : Map<String, HScriptInstance> = [];
	public static var stageScripts  : Map<String, HScriptInstance> = [];
	public static var songScripts   : Map<String, HScriptInstance> = [];
	public static var uiScripts     : Map<String, HScriptInstance> = [];
	public static var menuScripts   : Map<String, HScriptInstance> = [];
	public static var charScripts   : Map<String, HScriptInstance> = [];

	// ── Arrays reutilizables para el hot-path (evitan new Array cada frame) ──
	// Cada función de callback del gameplay (onUpdate, onBeatHit, onStepHit,
	// onNoteHit, onMiss…) pasa sus args a través de estos arrays estáticos en
	// lugar de crear un new Array<Dynamic> en cada llamada.
	// IMPORTANTE: Estos arrays son de uso temporal — solo válidos durante la
	// llamada a callOnScripts. No guardarlos por referencia en los scripts.

	/** Para onUpdate(elapsed:Float) */
	public static final _argsUpdate   : Array<Dynamic> = [0.0];
	/** Para onUpdatePost(elapsed:Float) */
	public static final _argsUpdatePost: Array<Dynamic> = [0.0];
	/** Para onBeatHit(beat:Int) */
	public static final _argsBeat     : Array<Dynamic> = [0];
	/** Para onStepHit(step:Int) */
	public static final _argsStep     : Array<Dynamic> = [0];
	/** Para onNoteHit / onMiss — [note, extra] */
	public static final _argsNote     : Array<Dynamic> = [null, null];
	/** Para eventos con un solo arg genérico */
	public static final _argsOne      : Array<Dynamic> = [null];
	/** Array vacío reutilizable — para callbacks sin argumentos */
	public static final _argsEmpty    : Array<Dynamic> = [];

	// ── Parser compartido ─────────────────────────────────────────────────────

	#if HSCRIPT_ALLOWED
	static var _parser:Parser = null;

	public static var parser(get, null):Parser;
	static function get_parser():Parser
	{
		if (_parser == null)
		{
			_parser = new Parser();
			_parser.allowTypes = true;
			_parser.allowJSON  = true;
			// allowMetadata fue añadido en hscript 2.5. Guard seguro:
			try { Reflect.setField(_parser, 'allowMetadata', true); } catch(_) {}
		}
		return _parser;
	}
	#end

	// ── Init ──────────────────────────────────────────────────────────────────

	public static function init():Void
	{
		loadGlobalScripts();
		trace('[ScriptHandler v3] Listo.');
	}

	/**
	 * Carga todos los scripts globales: base + mods + custom_events (Psych compat).
	 */
	public static function loadGlobalScripts():Void
	{
		// Limpiar scripts globales anteriores para evitar duplicados en la 2ª partida
		_destroyLayer(globalScripts);
		globalScripts.clear();

		#if sys
		if (mods.ModManager.isActive())
		{
			final r = mods.ModManager.modRoot();
			// Rutas estándar del mod
			_loadFolder('$r/scripts/global',   'global');
			_loadFolder('$r/scripts/events',   'global');
			_loadFolder('$r/data/scripts',     'global');
			// Rutas Psych-compat
			_loadFolder('$r/custom_events',    'global');
			_loadFolder('$r/custom_notetypes', 'global');
		}
		#end
		_loadFolder('assets/data/scripts/global', 'global');
		_loadFolder('assets/data/scripts/events', 'global');
		trace('[ScriptHandler v3] Scripts globales cargados.');
	}

	// ── Carga por contexto ────────────────────────────────────────────────────

	/** Carga scripts de la canción `songName` desde base + mod. */
	public static function loadSongScripts(songName:String):Void
	{
		#if sys
		if (mods.ModManager.isActive())
		{
			final r = mods.ModManager.modRoot();
			_loadFolder('$r/songs/$songName/scripts', 'song');
			_loadFolder('$r/songs/$songName/events',  'song');
		}
		#end
		_loadFolder('assets/songs/$songName/scripts', 'song');
		_loadFolder('assets/songs/$songName/events',  'song');
	}

	/** Carga scripts del stage `stageName` desde base + mod. */
	public static function loadStageScripts(stageName:String):Void
	{
		final sn = stageName.toLowerCase();
		#if sys
		if (mods.ModManager.isActive())
		{
			final r = mods.ModManager.modRoot();
			_loadFolder('$r/stages/$sn/scripts',        'stage');
			_loadFolder('$r/assets/stages/$sn/scripts', 'stage');
		}
		#end
		_loadFolder('assets/stages/$sn/scripts',       'stage');
		_loadFolder('assets/data/stages/$sn/scripts',  'stage');
	}

	/** Carga scripts de personaje `charName` desde base + mod. */
	public static function loadCharacterScripts(charName:String):Void
	{
		#if sys
		if (mods.ModManager.isActive())
		{
			final r = mods.ModManager.modRoot();
			_loadFolder('$r/characters/$charName/scripts', 'char');
			_loadFolder('$r/characters/$charName',         'char'); // script directamente en la carpeta
		}
		#end
		_loadFolder('assets/characters/$charName/scripts', 'char');
	}

	/**
	 * Carga scripts de un estado/menú `stateName`.
	 * Busca en `assets/states/{stateName}/` y `mods/{mod}/states/{stateName}/`.
	 */
	public static function loadStateScripts(stateName:String):Void
	{
		#if sys
		if (mods.ModManager.isActive())
		{
			final r = mods.ModManager.modRoot();
			_loadFolder('$r/states/$stateName', 'menu');
		}
		#end
		_loadFolder('assets/states/$stateName', 'menu');
	}

	// ── Carga de un script individual ─────────────────────────────────────────

	/**
	 * Carga un script desde `scriptPath`.
	 * Soporta .hx / .hscript nativos y .lua (transpilación Psych-compat).
	 *
	 * @param presetVars  Variables inyectadas ANTES de execute() (top-level code las ve).
	 * @param stage       Stage reference para el API shim de Psych Lua.
	 */
	public static function loadScript(scriptPath:String, scriptType:String = 'song',
		?presetVars:Map<String, Dynamic>,
		?stage:funkin.gameplay.objects.stages.Stage):Null<HScriptInstance>
	{
		#if HSCRIPT_ALLOWED

		#if sys
		if (!FileSystem.exists(scriptPath))
		{
			trace('[ScriptHandler] No encontrado: $scriptPath');
			return null;
		}
		#end

		final isLua      = scriptPath.endsWith('.lua');
		final rawContent = #if sys File.getContent(scriptPath) #else '' #end;

		final content = isLua
			? mods.compat.LuaStageConverter.convert(rawContent, _extractName(scriptPath))
			: rawContent;

		if (isLua) trace('[ScriptHandler] Transpilando Lua: $scriptPath');

		final scriptName = _extractName(scriptPath);
		final script     = new HScriptInstance(scriptName, scriptPath);

		try
		{
			script.program = parser.parseString(content, scriptPath);
			script.interp  = new Interp();

			ScriptAPI.expose(script.interp);

			if (presetVars != null)
				for (k => v in presetVars)
					script.interp.variables.set(k, v);

			if (isLua && stage != null)
				mods.compat.PsychLuaStageAPI.expose(script.interp, stage);

			script.interp.execute(script.program);
			script.call('onCreate');
			script.call('postCreate');

			_registerScript(script, scriptType);
			trace('[ScriptHandler] Cargado [$scriptType]: $scriptName${isLua ? " (Lua)" : ""}');
			return script;
		}
		catch (e:Dynamic)
		{
			trace('[ScriptHandler] ¡Error en "$scriptName"!');
			trace('  → ${Std.string(e)}');
			if (isLua) trace('[ScriptHandler] Código transpilado:\n$content');
			return null;
		}

		#else
		trace('[ScriptHandler] HSCRIPT_ALLOWED no definido en Project.xml — scripts desactivados.');
		return null;
		#end
	}

	/**
	 * Igual que loadScript() pero NO llama onCreate/postCreate automáticamente.
	 * Usar cuando el llamador necesita inyectar APIs adicionales ANTES del primer onCreate.
	 * El script queda parseado, con ScriptAPI expuesto y el programa ejecutado (funciones definidas).
	 * El llamador es responsable de llamar script.call('onCreate') cuando esté listo.
	 */
	public static function loadScriptNoInit(scriptPath:String, scriptType:String = 'song',
		?presetVars:Map<String, Dynamic>):Null<HScriptInstance>
	{
		#if HSCRIPT_ALLOWED

		#if sys
		if (!FileSystem.exists(scriptPath))
		{
			trace('[ScriptHandler] No encontrado: $scriptPath');
			return null;
		}
		#end

		final rawContent = #if sys File.getContent(scriptPath) #else '' #end;
		final scriptName = _extractName(scriptPath);
		final script     = new HScriptInstance(scriptName, scriptPath);

		try
		{
			script.program = parser.parseString(rawContent, scriptPath);
			script.interp  = new Interp();

			ScriptAPI.expose(script.interp);

			if (presetVars != null)
				for (k => v in presetVars)
					script.interp.variables.set(k, v);

			// Ejecutar el programa define funciones en interp.variables — sin llamar onCreate aún.
			script.interp.execute(script.program);

			_registerScript(script, scriptType);
			trace('[ScriptHandler] Cargado sin init [$scriptType]: $scriptName');
			return script;
		}
		catch (e:Dynamic)
		{
			trace('[ScriptHandler] ¡Error parseando "$scriptName"!');
			trace('  → ${Std.string(e)}');
			return null;
		}

		#else
		trace('[ScriptHandler] HSCRIPT_ALLOWED no definido — scripts desactivados.');
		return null;
		#end
	}

	/** Carga todos los `.hx` / `.hscript` / `.lua` de una carpeta. */
	public static function loadScriptsFromFolder(folderPath:String, scriptType:String = 'song'):Array<HScriptInstance>
	{
		return _loadFolder(folderPath, scriptType);
	}

	/** Carga scripts desde una lista explícita de paths. */
	public static function loadScriptsFromArray(paths:Array<String>, scriptType:String = 'stage'):Array<HScriptInstance>
	{
		final out:Array<HScriptInstance> = [];
		for (p in paths)
		{
			final s = loadScript(p, scriptType);
			if (s != null) out.push(s);
		}
		return out;
	}

	// ── Llamadas ──────────────────────────────────────────────────────────────

	/**
	 * Llama `funcName(args)` en TODOS los scripts de TODAS las capas.
	 * El orden es: global → stage → song → ui → menu → char.
	 */
	public static function callOnScripts(funcName:String, args:Array<Dynamic> = null):Void
	{
		if (args == null) args = [];
		_callLayer(globalScripts, funcName, args);
		_callLayer(stageScripts,  funcName, args);
		_callLayer(songScripts,   funcName, args);
		_callLayer(uiScripts,     funcName, args);
		_callLayer(menuScripts,   funcName, args);
		_callLayer(charScripts,   funcName, args);
	}

	/**
	 * Como callOnScripts pero devuelve el primer valor no-nulo / no-defaultValue.
	 * Si algún script devuelve `true` (cancelar), se detiene la propagación.
	 * Sin alloc de array intermedio — itera las capas directamente.
	 */
	public static function callOnScriptsReturn(funcName:String, args:Array<Dynamic> = null, defaultValue:Dynamic = null):Dynamic
	{
		if (args == null) args = _argsEmpty;
		// Iterar capas directamente sin crear Array "layers" cada llamada
		#if HSCRIPT_ALLOWED
		function _checkLayer(layer:Map<String, HScriptInstance>):Dynamic {
			for (script in layer) {
				if (!script.active) continue;
				final r = script.call(funcName, args);
				if (r != null && r != defaultValue) return r;
			}
			return null;
		}
		var r:Dynamic;
		r = _checkLayer(globalScripts); if (r != null) return r;
		r = _checkLayer(stageScripts);  if (r != null) return r;
		r = _checkLayer(songScripts);   if (r != null) return r;
		r = _checkLayer(uiScripts);     if (r != null) return r;
		r = _checkLayer(menuScripts);   if (r != null) return r;
		r = _checkLayer(charScripts);   if (r != null) return r;
		#end
		return defaultValue;
	}

	/** Inyecta una variable en todos los scripts activos. */
	public static function setOnScripts(varName:String, value:Dynamic):Void
	{
		// Sin Array "layers" intermedio
		inline function _setLayer(layer:Map<String, HScriptInstance>):Void
			for (script in layer) if (script.active) script.set(varName, value);
		_setLayer(globalScripts);
		_setLayer(stageScripts);
		_setLayer(songScripts);
		_setLayer(uiScripts);
		_setLayer(menuScripts);
		_setLayer(charScripts);
	}

	/** Inyecta una variable solo en los scripts de stage. */
	public static function setOnStageScripts(varName:String, value:Dynamic):Void
	{
		for (script in stageScripts)
			if (script.active) script.set(varName, value);
	}

	/** Llama una función solo en los scripts de stage. */
	public static function callOnStageScripts(funcName:String, args:Array<Dynamic> = null):Void
	{
		if (args == null) args = [];
		_callLayer(stageScripts, funcName, args);
	}

	/** Obtiene el valor de una variable de los scripts activos (primer resultado no-nulo). */
	public static function getFromScripts(varName:String, defaultValue:Dynamic = null):Dynamic
	{
		final layers = [globalScripts, stageScripts, songScripts, uiScripts, menuScripts, charScripts];
		for (layer in layers)
			for (script in layer)
				if (script.active) {
					final v = script.get(varName);
					if (v != null) return v;
				}
		return defaultValue;
	}

	// ── Limpieza ──────────────────────────────────────────────────────────────

	public static function clearSongScripts():Void
	{
		_destroyLayer(songScripts);
		_destroyLayer(uiScripts);
		songScripts.clear();
		uiScripts.clear();
	}

	public static function clearStageScripts():Void
	{
		_destroyLayer(stageScripts);
		stageScripts.clear();
	}

	public static function clearCharScripts():Void
	{
		_destroyLayer(charScripts);
		charScripts.clear();
	}

	public static function clearMenuScripts():Void
	{
		_destroyLayer(menuScripts);
		menuScripts.clear();
	}

	public static function clearAll():Void
	{
		clearSongScripts();
		clearStageScripts();
		clearCharScripts();
		clearMenuScripts();
		_destroyLayer(globalScripts);
		globalScripts.clear();
	}

	// ── Hot-reload ────────────────────────────────────────────────────────────

	/** Recarga un script por nombre (sin reiniciar el intérprete). */
	public static function hotReload(name:String):Bool
	{
		final layers = [globalScripts, stageScripts, songScripts, uiScripts, menuScripts, charScripts];
		for (layer in layers)
		{
			if (layer.exists(name))
			{
				layer.get(name).hotReload();
				trace('[ScriptHandler] Hot-reload: $name');
				return true;
			}
		}
		trace('[ScriptHandler] hotReload: "$name" no encontrado.');
		return false;
	}

	/** Recarga todos los scripts de todas las capas. */
	public static function hotReloadAll():Void
	{
		final layers = [globalScripts, stageScripts, songScripts, uiScripts, menuScripts, charScripts];
		for (layer in layers) for (s in layer) s.hotReload();
		trace('[ScriptHandler] Hot-reload completo.');
	}

	// ── Internals ─────────────────────────────────────────────────────────────

	static function _loadFolder(folderPath:String, scriptType:String):Array<HScriptInstance>
	{
		final out:Array<HScriptInstance> = [];
		#if sys
		if (!FileSystem.exists(folderPath) || !FileSystem.isDirectory(folderPath))
			return out;
		for (file in FileSystem.readDirectory(folderPath))
		{
			if (!file.endsWith('.hx') && !file.endsWith('.hscript') && !file.endsWith('.lua'))
				continue;
			final s = loadScript('$folderPath/$file', scriptType);
			if (s != null) out.push(s);
		}
		#end
		return out;
	}

	static function _registerScript(script:HScriptInstance, scriptType:String):Void
	{
		final target = switch (scriptType.toLowerCase())
		{
			case 'global': globalScripts;
			case 'stage':  stageScripts;
			case 'ui':     uiScripts;
			case 'menu':   menuScripts;
			case 'char':   charScripts;
			default:       songScripts;
		};
		// Nombres duplicados → sufijo numérico
		var name = script.name;
		var i    = 1;
		while (target.exists(name)) name = '${script.name}_${i++}';
		script.name = name;
		target.set(name, script);
	}

	static function _callLayer(layer:Map<String, HScriptInstance>, func:String, args:Array<Dynamic>):Void
	{
		for (script in layer)
		{
			if (script.active)
			{
				#if HSCRIPT_ALLOWED
				script.call(func, args);
				#end
			}
		}
	}

	static function _destroyLayer(layer:Map<String, HScriptInstance>):Void
	{
		for (script in layer)
		{
			#if HSCRIPT_ALLOWED
			script.call('onDestroy');
			#end
		}
	}

	/** Alias público de _extractName para compatibilidad. */
	public static inline function extractName(path:String):String
		return _extractName(path);

	static inline function _extractName(path:String):String
	{
		var name = path.split('/').pop() ?? path;
		name = name.split('\\').pop();
		if (StringTools.contains(name, '.')) name = name.substring(0, name.lastIndexOf('.'));
		return name;
	}
}
