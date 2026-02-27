package funkin.gameplay.notes;

#if sys
import sys.FileSystem;
import sys.io.File;
#end
import flixel.graphics.frames.FlxAtlasFrames;
import funkin.scripting.HScriptInstance;
import funkin.scripting.ScriptHandler;

/**
 * NoteTypeManager — Sistema de tipos de nota personalizados.
 *
 * ─── Estructura de carpetas ────────────────────────────────────────────────
 *
 *   assets/noteType/{typeName}/
 *     {typeName}.hx        ← script HScript (el nombre puede ser cualquiera)
 *     {typeName}.png       ← textura propia (opcional; con .xml para atlas)
 *     {typeName}.xml       ← atlas Sparrow (opcional)
 *
 *   mods/{mod}/noteType/{typeName}/   ← igual que assets, prioridad sobre base
 *
 * ─── API del script de un noteType ────────────────────────────────────────
 *
 *   // Llamado al spawnear la nota. Podés cambiar color, escala, etc.
 *   function onSpawn(note:Note) { note.color = 0xFFFF0000; }
 *
 *   // Jugador golpea la nota. Devuelve true para CANCELAR la lógica normal.
 *   function onPlayerHit(note:Note, game:Dynamic):Bool { ... }
 *
 *   // Siempre llamado después del hit, aunque se haya cancelado.
 *   function onPlayerHitPost(note:Note, game:Dynamic) { }
 *
 *   // CPU golpea la nota.
 *   function onCPUHit(note:Note, game:Dynamic) { }
 *
 *   // El jugador falla. Devuelve true para CANCELAR la lógica normal de miss.
 *   function onMiss(note:Note, game:Dynamic):Bool { return true; }
 *
 * ─── Ejemplo de noteType "mine" ───────────────────────────────────────────
 *
 *   // assets/noteType/mine/mine.hx
 *   function onSpawn(note) { note.color = 0xFFFF0000; }
 *   function onPlayerHit(note, game) {
 *     game.gameState.modifyHealth(-0.5);
 *     return true; // cancelar lógica normal
 *   }
 *   function onMiss(note, game) { return true; } // no penalizar miss
 */
class NoteTypeManager
{
	/** Tipos descubiertos (sin "normal"). null = no escaneado. */
	static var _types:Null<Array<String>> = null;

	/** Scripts cacheados por nombre de tipo. */
	static var _scripts:Map<String, Null<HScriptInstance>> = [];

	/** Frames de atlas cacheados por nombre de tipo. */
	static var _frames:Map<String, Null<FlxAtlasFrames>> = [];

	// ─── DISCOVERY ───────────────────────────────────────────────────────────

	/** Runtime registry for script-registered note types (ScriptAPI compat). */
	static var _runtimeTypes:Map<String, Dynamic> = [];

	/** Registers a note type at runtime from a script. */
	public static function register(name:String, cfg:Dynamic):Void
	{
		_runtimeTypes.set(name, cfg);
		_types = null;
		trace('[NoteTypeManager] Tipo "$name" registrado en runtime.');
	}

	/** Removes a runtime-registered note type. */
	public static function unregister(name:String):Void
	{
		_runtimeTypes.remove(name);
		_types = null;
	}

	/** Returns true if the type exists (built-in or runtime). */
	public static function exists(name:String):Bool
	{
		if (_runtimeTypes.exists(name)) return true;
		return getTypes().indexOf(name) >= 0;
	}

	/** Returns all available note types (built-in + runtime). */
	public static function getAll():Array<String>
	{
		final base = getTypes().copy();
		for (k in _runtimeTypes.keys())
			if (base.indexOf(k) < 0) base.push(k);
		return base;
	}

	/** Devuelve los nombres de todos los tipos disponibles (sin "normal"). */
	public static function getTypes():Array<String>
	{
		if (_types != null)
			return _types;

		_types = [];

		#if sys
		if (mods.ModManager.isActive())
		{
			final dir = '${mods.ModManager.modRoot()}/noteType';
			if (FileSystem.exists(dir) && FileSystem.isDirectory(dir))
				for (e in FileSystem.readDirectory(dir))
					if (FileSystem.isDirectory('$dir/$e') && _types.indexOf(e) == -1)
						_types.push(e);
		}

		final base = 'assets/noteType';
		if (FileSystem.exists(base) && FileSystem.isDirectory(base))
			for (e in FileSystem.readDirectory(base))
				if (FileSystem.isDirectory('$base/$e') && _types.indexOf(e) == -1)
					_types.push(e);
		#end

		_types.sort((a, b) -> a < b ? -1 : (a > b ? 1 : 0));
		return _types;
	}

	/** Invalida el caché. Llamar al cambiar de mod. */
	public static function clearCache():Void
	{
		_types  = null;
		_scripts.clear();
		_frames.clear();
	}

	// ─── SCRIPTS ─────────────────────────────────────────────────────────────

	public static function getScript(typeName:String):Null<HScriptInstance>
	{
		if (!isCustomType(typeName)) return null;

		if (_scripts.exists(typeName))
			return _scripts.get(typeName);

		final path = _findScriptPath(typeName);
		var inst:Null<HScriptInstance> = null;

		if (path != null)
		{
			inst = ScriptHandler.loadScript(path, 'song');
			if (inst != null)
			{
				inst.set('NoteTypeManager', NoteTypeManager);
				inst.set('typeName', typeName);
			}
		}

		_scripts.set(typeName, inst);
		return inst;
	}

	static function _findScriptPath(typeName:String):Null<String>
	{
		#if sys
		final exts = ['.hx', '.hscript'];

		if (mods.ModManager.isActive())
		{
			final d = '${mods.ModManager.modRoot()}/noteType/$typeName';
			for (ext in exts)
				for (name in [typeName, 'script', 'noteType'])
					if (FileSystem.exists('$d/$name$ext')) return '$d/$name$ext';
		}

		final d = 'assets/noteType/$typeName';
		for (ext in exts)
			for (name in [typeName, 'script', 'noteType'])
				if (FileSystem.exists('$d/$name$ext')) return '$d/$name$ext';
		#end
		return null;
	}

	// ─── FRAMES / TEXTURA ────────────────────────────────────────────────────

	public static function getFrames(typeName:String):Null<FlxAtlasFrames>
	{
		if (!isCustomType(typeName)) return null;

		if (_frames.exists(typeName))
			return _frames.get(typeName);

		final f = _loadFrames(typeName);
		_frames.set(typeName, f);
		return f;
	}

	static function _loadFrames(typeName:String):Null<FlxAtlasFrames>
	{
		#if sys
		final pairs:Array<{png:String, xml:String}> = [];

		if (mods.ModManager.isActive())
		{
			final d = '${mods.ModManager.modRoot()}/noteType/$typeName';
			pairs.push({png: '$d/$typeName.png', xml: '$d/$typeName.xml'});
			pairs.push({png: '$d/note.png',      xml: '$d/note.xml'});
		}

		final d = 'assets/noteType/$typeName';
		pairs.push({png: '$d/$typeName.png', xml: '$d/$typeName.xml'});
		pairs.push({png: '$d/note.png',      xml: '$d/note.xml'});

		for (p in pairs)
		{
			if (!FileSystem.exists(p.png) || !FileSystem.exists(p.xml)) continue;
			try
			{
				final img  = lime.graphics.Image.fromBytes(sys.io.File.getBytes(p.png));
				final bmp  = openfl.display.BitmapData.fromImage(img);
				final xml  = sys.io.File.getContent(p.xml);
				return FlxAtlasFrames.fromSparrow(bmp, xml);
			}
			catch (e:Dynamic) { trace('[NoteTypeManager] Atlas load error ($typeName): $e'); }
		}
		#end
		return null;
	}

	// ─── HELPERS ─────────────────────────────────────────────────────────────

	/** true si el tipo es un tipo personalizado (no vacío y no "normal"). */
	public static inline function isCustomType(t:String):Bool
		return t != null && t != '' && t != 'normal';

	// ─── CALLBACKS ───────────────────────────────────────────────────────────

	/**
	 * Llamado al spawnear la nota. Aplica el atlas propio si existe.
	 */
	public static function onNoteSpawn(note:Note):Void
	{
		if (!isCustomType(note.noteType)) return;

		final frames = getFrames(note.noteType);
		if (frames != null)
		{
			note.frames = frames;
			note.setupTypeAnimations();
		}

		final s = getScript(note.noteType);
		if (s != null) s.call('onSpawn', [note]);
	}

	/**
	 * Jugador golpea la nota.
	 * @return true = cancelar lógica normal de hit
	 */
	public static function onPlayerHit(note:Note, game:Dynamic):Bool
	{
		if (!isCustomType(note.noteType)) return false;
		final s = getScript(note.noteType);
		return s != null && s.call('onPlayerHit', [note, game]) == true;
	}

	/** Siempre llamado después del hit (aunque se haya cancelado). */
	public static function onPlayerHitPost(note:Note, game:Dynamic):Void
	{
		if (!isCustomType(note.noteType)) return;
		final s = getScript(note.noteType);
		if (s != null) s.call('onPlayerHitPost', [note, game]);
	}

	/** CPU golpea la nota. */
	public static function onCPUHit(note:Note, game:Dynamic):Void
	{
		if (!isCustomType(note.noteType)) return;
		final s = getScript(note.noteType);
		if (s != null) s.call('onCPUHit', [note, game]);
	}

	/**
	 * El jugador falla la nota.
	 * @return true = cancelar lógica normal de miss
	 */
	public static function onMiss(note:Note, game:Dynamic):Bool
	{
		if (!isCustomType(note.noteType)) return false;
		final s = getScript(note.noteType);
		return s != null && s.call('onMiss', [note, game]) == true;
	}
}
