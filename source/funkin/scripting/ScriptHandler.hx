package funkin.scripting;

import haxe.Exception;
import sys.FileSystem;
import sys.io.File;
#if HSCRIPT_ALLOWED
import hscript.Parser;
import hscript.Interp;
#end

using StringTools;

/**
 * Sistema central de scripts HScript para gameplay.
 *
 * Gestiona tres capas de scripts, en orden de ejecución:
 *   global  → activos durante toda la sesión
 *   stage   → activos durante el stage actual
 *   song    → activos durante la canción actual
 *   ui      → activos durante el UI de la canción
 *
 * ─── Uso básico ──────────────────────────────────────────────────────────────
 *   ScriptHandler.init();
 *   ScriptHandler.loadSongScripts('bopeebo');
 *   ScriptHandler.callOnScripts('onBeatHit', [beat]);
 *   ScriptHandler.setOnScripts('game', PlayState.instance);
 *   ScriptHandler.clearSongScripts();
 *
 * ─── Estructura de carpetas esperada ─────────────────────────────────────────
 *   assets/data/scripts/global/     ← siempre activos
 *   assets/data/scripts/events/     ← handlers de eventos personalizados
 *   assets/songs/{song}/scripts/    ← scripts de la canción
 *   assets/songs/{song}/events/     ← eventos custom de la canción
 *   assets/stages/{stage}/scripts/  ← scripts del stage
 */
class ScriptHandler
{
	public static var globalScripts:Map<String, HScriptInstance> = [];
	public static var stageScripts:Map<String, HScriptInstance> = [];
	public static var songScripts:Map<String, HScriptInstance> = [];
	public static var uiScripts:Map<String, HScriptInstance> = [];

	#if HSCRIPT_ALLOWED
	/** Parser compartido — se inicializa una sola vez. */
	static var _parser:Parser = null;

	public static var parser(get, null):Parser;

	static function get_parser():Parser
	{
		if (_parser == null)
		{
			_parser = new Parser();
			_parser.allowTypes = true;
			_parser.allowJSON = true;
			_parser.allowMetadata = true;
		}
		return _parser;
	}
	#end

	// ─── Init ─────────────────────────────────────────────────────────────────

	public static function init():Void
	{
		loadGlobalScripts();
		trace('[ScriptHandler] Listo.');
	}

	public static function loadGlobalScripts():Void
	{
		// Mod activo primero, luego assets base
		#if sys
		if (mods.ModManager.isActive())
		{
			final modRoot = mods.ModManager.modRoot();
			loadScriptsFromFolder('$modRoot/data/scripts/global', 'global');
			loadScriptsFromFolder('$modRoot/data/scripts/events', 'global');
			loadScriptsFromFolder('$modRoot/scripts/global',      'global');
			loadScriptsFromFolder('$modRoot/scripts/events',      'global');
		}
		#end
		loadScriptsFromFolder('assets/data/scripts/global', 'global');
		loadScriptsFromFolder('assets/data/scripts/events', 'global');
		trace('[ScriptHandler] Scripts globales cargados.');
	}

	// ─── Carga ────────────────────────────────────────────────────────────────

	/**
	 * Carga un script desde `scriptPath` y lo registra bajo `scriptType`.
	 * Tipos válidos: `"global"`, `"stage"`, `"song"`, `"ui"`.
	 * Devuelve `null` si el archivo no existe o hay un error de parse.
	 */
	/**
	 * Loads and executes a script file.
	 * Supports .hx / .hscript natively, and .lua via LuaStageConverter transpilation.
	 *
	 * @param presetVars  Optional vars injected BEFORE execute() so top-level Lua code sees them.
	 * @param stage       Optional Stage reference — enables the Psych Lua API shim.
	 */
	public static function loadScript(scriptPath:String, scriptType:String = 'song',
		?presetVars:Map<String, Dynamic>,
		?stage:funkin.gameplay.objects.stages.Stage):HScriptInstance
	{
		#if HSCRIPT_ALLOWED
		if (!FileSystem.exists(scriptPath))
		{
			trace('[ScriptHandler] No encontrado: $scriptPath');
			return null;
		}

		final isLua      = scriptPath.endsWith('.lua');
		final rawContent = File.getContent(scriptPath);

		// Transpile Lua -> HScript if needed
		final content = isLua
			? mods.compat.LuaStageConverter.convert(rawContent, extractName(scriptPath))
			: rawContent;

		if (isLua)
			trace('[ScriptHandler] Transpiling Lua stage script: $scriptPath');

		final scriptName = extractName(scriptPath);
		final script     = new HScriptInstance(scriptName, scriptPath);

		try
		{
			script.program = parser.parseString(content, scriptPath);
			script.interp  = new Interp();

			ScriptAPI.expose(script.interp);

			// Inject preset variables BEFORE execute() so top-level code sees them
			if (presetVars != null)
				for (k => v in presetVars)
					script.interp.variables.set(k, v);

			// For Lua stage scripts, inject the full Psych Lua API shim
			if (isLua && stage != null)
				mods.compat.PsychLuaStageAPI.expose(script.interp, stage);

			script.interp.execute(script.program);
			script.call('onCreate');
			script.call('postCreate');

			registerScript(script, scriptType);

			trace('[ScriptHandler] Cargado [$scriptType]: $scriptName' + (isLua ? ' (from Lua)' : ''));
			return script;
		}
		catch (e:Dynamic)
		{
			trace('[ScriptHandler] Error parseando "$scriptName": ' + Std.string(e));
			if (isLua)
				trace('[ScriptHandler] Transpiled code:\n$content');
			return null;
		}
		#else
		trace('[ScriptHandler] HSCRIPT_ALLOWED no definido en Project.xml.');
		return null;
		#end
	}

	/** Carga todos los `.hx` / `.hscript` de una carpeta. */
	public static function loadScriptsFromFolder(folderPath:String, scriptType:String = 'song'):Array<HScriptInstance>
	{
		final scripts:Array<HScriptInstance> = [];

		if (!FileSystem.exists(folderPath) || !FileSystem.isDirectory(folderPath))
			return scripts;

		for (file in FileSystem.readDirectory(folderPath))
		{
			// Accept .hx, .hscript (native) and .lua (transpiled Psych stage scripts)
			final isScript = file.endsWith('.hx') || file.endsWith('.hscript') || file.endsWith('.lua');
			if (!isScript)
				continue;
			final script = loadScript('$folderPath/$file', scriptType);
			if (script != null)
				scripts.push(script);
		}

		return scripts;
	}

	/** Carga scripts desde una lista explícita de paths. */
	public static function loadScriptsFromArray(paths:Array<String>, scriptType:String = 'stage'):Array<HScriptInstance>
	{
		final scripts:Array<HScriptInstance> = [];
		for (path in paths)
		{
			final s = loadScript(path, scriptType);
			if (s != null)
				scripts.push(s);
		}
		return scripts;
	}

	/** Carga scripts para la canción `songName`. */
	public static function loadSongScripts(songName:String):Void
	{
		clearSongScripts();

		// Resolver carpeta real de la canción (cubre espacios vs guiones en mods)
		#if sys
		final resolvedFolder = _resolveSongFolder(songName);
		loadScriptsFromFolder('$resolvedFolder/scripts', 'song');
		loadScriptsFromFolder('$resolvedFolder/events',  'song');
		#else
		final base = 'assets/songs/${songName.toLowerCase()}';
		loadScriptsFromFolder('$base/scripts', 'song');
		loadScriptsFromFolder('$base/events', 'song');
		#end

		trace('[ScriptHandler] Scripts de "$songName" cargados.');
	}

	/** Resuelve la carpeta real de una canción (mismo algoritmo que Paths._resolveSongFolder). */
	static function _resolveSongFolder(song:String):String
	{
		#if sys
		final s = song.toLowerCase();
		final variants:Array<String> = [];
		function addV(v:String) { v = v.trim(); if (v != '' && variants.indexOf(v) == -1) variants.push(v); }
		addV(s); addV(s.replace(' ', '-')); addV(s.replace('-', ' '));
		addV(s.replace('!', '')); addV(s.replace(' ', '-').replace('!', '')); addV(s.replace('-', ' ').replace('!', ''));

		if (mods.ModManager.isActive())
		{
			final modRoot = mods.ModManager.modRoot();
			for (v in variants)
				for (base in ['$modRoot/songs', '$modRoot/assets/songs'])
					if (sys.FileSystem.isDirectory('$base/$v'))
						return '$base/$v';
		}
		for (v in variants)
			if (sys.FileSystem.isDirectory('assets/songs/$v'))
				return 'assets/songs/$v';
		return 'assets/songs/$s';
		#else
		return 'assets/songs/${song.toLowerCase()}';
		#end
	}

	/** Carga scripts para el stage `stageName`. */
	public static function loadStageScripts(stageName:String):Void
	{
		clearStageScripts();
		#if sys
		if (mods.ModManager.isActive())
		{
			final modRoot = mods.ModManager.modRoot();
			final sn = stageName.toLowerCase();
			loadScriptsFromFolder('$modRoot/stages/$sn/scripts', 'stage');
			loadScriptsFromFolder('$modRoot/assets/stages/$sn/scripts', 'stage');
		}
		#end
		loadScriptsFromFolder('assets/stages/${stageName.toLowerCase()}/scripts', 'stage');
		trace('[ScriptHandler] Scripts de stage "$stageName" cargados.');
	}

	// ─── Llamadas ─────────────────────────────────────────────────────────────

	/**
	 * Llama `funcName` en todos los scripts activos (global → stage → song).
	 */
	public static function callOnScripts(funcName:String, args:Array<Dynamic> = null):Void
	{
		if (args == null)
			args = [];
		callMap(globalScripts, funcName, args);
		callMap(stageScripts, funcName, args);
		callMap(songScripts, funcName, args);
	}

	/** Llama sólo en los scripts de stage. */
	public static function callOnStageScripts(funcName:String, args:Array<Dynamic> = null):Void
		callMap(stageScripts, funcName, args ?? []);

	/**
	 * Llama `funcName` y devuelve el primer resultado no-null.
	 * Prioridad: song → stage → global.
	 */
	public static function callOnScriptsReturn(funcName:String, args:Array<Dynamic> = null, defaultValue:Dynamic = null):Dynamic
	{
		if (args == null)
			args = [];
		var r = firstReturn(songScripts, funcName, args);
		if (r != null)
			return r;
		r = firstReturn(stageScripts, funcName, args);
		if (r != null)
			return r;
		r = firstReturn(globalScripts, funcName, args);
		if (r != null)
			return r;
		return defaultValue;
	}

	// ─── Variables ────────────────────────────────────────────────────────────

	/** Establece `varName = value` en TODOS los scripts. */
	public static function setOnScripts(varName:String, value:Dynamic):Void
	{
		for (s in globalScripts)
			s.set(varName, value);
		for (s in stageScripts)
			s.set(varName, value);
		for (s in songScripts)
			s.set(varName, value);
	}

	/**
	 * Obtiene el valor de una variable de los scripts activos.
	 * Busca en orden: song -> stage -> global. Devuelve null si no existe.
	 */
	public static function getFromScripts(varName:String):Dynamic
	{
		for (s in songScripts)
		{
			#if HSCRIPT_ALLOWED
			if (s.interp != null && s.interp.variables.exists(varName))
				return s.interp.variables.get(varName);
			#end
		}
		for (s in stageScripts)
		{
			#if HSCRIPT_ALLOWED
			if (s.interp != null && s.interp.variables.exists(varName))
				return s.interp.variables.get(varName);
			#end
		}
		for (s in globalScripts)
		{
			#if HSCRIPT_ALLOWED
			if (s.interp != null && s.interp.variables.exists(varName))
				return s.interp.variables.get(varName);
			#end
		}
		return null;
	}

	/** Establece una variable sólo en scripts de stage. */
	public static function setOnStageScripts(varName:String, value:Dynamic):Void
	{
		for (s in stageScripts)
			s.set(varName, value);
	}

	// ─── Limpiar ──────────────────────────────────────────────────────────────

	public static function clearSongScripts():Void
		destroyMap(songScripts);

	public static function clearStageScripts():Void
		destroyMap(stageScripts);

	public static function clearUIScripts():Void
		destroyMap(uiScripts);

	public static function clearAllScripts():Void
	{
		clearSongScripts();
		clearStageScripts();
		clearUIScripts();
		destroyMap(globalScripts);
	}

	// ─── Helpers internos ─────────────────────────────────────────────────────

	static function registerScript(script:HScriptInstance, type:String):Void
	{
		final map = switch (type.toLowerCase())
		{
			case 'global': globalScripts;
			case 'stage': stageScripts;
			case 'ui': uiScripts;
			default: songScripts;
		};
		map.set(script.name, script);
	}

	static inline function callMap(map:Map<String, HScriptInstance>, fn:String, args:Array<Dynamic>):Void
	{
		for (s in map)
			s.call(fn, args);
	}

	static function firstReturn(map:Map<String, HScriptInstance>, fn:String, args:Array<Dynamic>):Dynamic
	{
		for (s in map)
		{
			final r = s.call(fn, args);
			if (r != null)
				return r;
		}
		return null;
	}

	static function destroyMap(map:Map<String, HScriptInstance>):Void
	{
		for (s in map)
			s.destroy();
		map.clear();
	}

	/** Extrae el nombre de archivo sin extensión de un path. */
	public static function extractName(path:String):String
	{
		var name = path.split('/').pop();
		if (name.endsWith('.hscript'))
			return name.substr(0, name.length - 8);
		if (name.endsWith('.hx'))
			return name.substr(0, name.length - 3);
		return name;
	}
}
