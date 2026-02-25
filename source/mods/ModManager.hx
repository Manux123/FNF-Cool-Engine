package mods;

#if sys
import sys.FileSystem;
import sys.io.File;
#end
import haxe.Json;

/**
 * ModManager — Gestiona mods instalados, activación y previews.
 *
 * ─── Estructura esperada de un mod ─────────────────────────────────────────
 *
 *   mods/
 *   └── my-mod/
 *       ├── mod.json          ← metadatos (name, author, version, priority…)
 *       ├── preview.mp4       ← preview video en el selector  (opcional)
 *       ├── preview.png       ← preview imagen si no hay video (opcional)
 *       ├── icon.png          ← icono cuadrado del mod         (opcional)
 *       ├── songs/
 *       ├── characters/
 *       ├── stages/
 *       ├── images/
 *       ├── sounds/
 *       ├── music/
 *       ├── data/
 *       ├── scripts/
 *       └── videos/
 *
 * ─── Campos de mod.json ──────────────────────────────────────────────────────
 *   {
 *     "name":           "My Mod",
 *     "description":    "Descripción del mod",
 *     "author":         "NombreAutor",
 *     "version":        "1.0.0",
 *     "priority":       0,
 *     "color":          "FF5599",
 *     "website":        "https://…",
 *     "enabled":        true,
 *     "startupDefault": false    ← true = arranca siempre con este mod
 *   }
 */
class ModManager
{
	/** Mod actualmente cargado. null = modo base. */
	public static var activeMod(default, null):String = null;

	/**
	 * Mod que arranca por defecto aunque no haya sesión guardada.
	 * Se detecta desde mod.json startupDefault:true (mayor priority gana).
	 */
	public static var startupMod(default, null):Null<String> = null;

	/** Lista de mods instalados, ordenada por priority desc. */
	public static var installedMods(default, null):Array<ModInfo> = [];

	/** Callback que se llama cuando cambia el mod activo. */
	public static var onModChanged:Null<String->Void> = null;

	/** Carpeta raíz donde viven los mods. */
	public static inline var MODS_FOLDER = 'mods';

	/** Sub-carpetas estándar que se crean al crear un mod nuevo. */
	static var STD_FOLDERS = [
		'characters', 'cutscenes', 'data', 'fonts', 'images',
		'music', 'noteType', 'shaders', 'skins', 'songs',
		'sounds', 'splashes', 'stages', 'states'
	];

	private static var _enabledMap:Map<String, Bool> = new Map();

	// ─── Init ─────────────────────────────────────────────────────────────────

	public static function init():Void
	{
		installedMods = [];
		startupMod    = null;

		#if sys
		if (!FileSystem.exists(MODS_FOLDER) || !FileSystem.isDirectory(MODS_FOLDER))
		{
			trace('[ModManager] Carpeta "mods/" no encontrada — modo base activo.');
			return;
		}

		final extracted = ModExtractor.extractAll();
		if (extracted.length > 0)
			trace('[ModManager] Mods extraídos de archivo: ' + extracted.join(', '));

		_loadEnabledState();

		for (entry in FileSystem.readDirectory(MODS_FOLDER))
		{
			final modPath = '$MODS_FOLDER/$entry';
			if (!FileSystem.isDirectory(modPath)) continue;

			final info = _loadModInfo(entry, modPath);
			if (info != null)
			{
				installedMods.push(info);
				trace('[ModManager] Mod: ${info.id} (${info.name}) prio=${info.priority} enabled=${info.enabled} startup=${info.startupDefault}');
			}
		}

		installedMods.sort((a, b) ->
		{
			if (b.priority != a.priority) return b.priority - a.priority;
			return a.name < b.name ? -1 : 1;
		});

		// Detectar startup mod (primer habilitado con startupDefault=true por priority)
		for (m in installedMods)
			if (m.startupDefault && m.enabled) { startupMod = m.id; break; }

		if (startupMod != null)
			trace('[ModManager] Startup mod: "$startupMod"');
		#end

		trace('[ModManager] ${installedMods.length} mods instalados.');
		#if sys
		loadActiveState();
		#end
	}

	// ─── Activación ───────────────────────────────────────────────────────────

	public static function setActive(modId:Null<String>):Void
	{
		if (modId == null)
		{
			activeMod = null;
			trace('[ModManager] Mod desactivado — modo base.');
			_saveActiveState();
			if (onModChanged != null) onModChanged(null);
			return;
		}
		#if sys
		if (!isInstalled(modId)) { trace('[ModManager] Mod "$modId" no encontrado.'); return; }
		#end
		activeMod = modId;
		trace('[ModManager] Mod activo: "$activeMod"');
		_saveActiveState();
		if (onModChanged != null) onModChanged(activeMod);
	}

	public static inline function deactivate():Void setActive(null);
	public static inline function isActive():Bool return activeMod != null;

	public static function isInstalled(modId:String):Bool
	{
		#if sys
		return FileSystem.exists('$MODS_FOLDER/$modId') && FileSystem.isDirectory('$MODS_FOLDER/$modId');
		#else
		for (m in installedMods) if (m.id == modId) return true;
		return false;
		#end
	}

	// ─── Enable / Disable ─────────────────────────────────────────────────────

	public static function setEnabled(modId:String, enabled:Bool):Void
	{
		_enabledMap.set(modId, enabled);
		for (m in installedMods) if (m.id == modId) { m.enabled = enabled; break; }
		if (!enabled && activeMod == modId) deactivate();
		_saveEnabledState();
	}

	public static function toggleEnabled(modId:String):Bool
	{
		final cur = isEnabled(modId); setEnabled(modId, !cur); return !cur;
	}

	public static function isEnabled(modId:String):Bool
	{
		if (_enabledMap.exists(modId)) return _enabledMap.get(modId);
		for (m in installedMods) if (m.id == modId) return m.enabled;
		return true;
	}

	// ─── Startup Mod ──────────────────────────────────────────────────────────

	/**
	 * Establece `modId` como startup mod (arranca siempre con él).
	 * Pasa null para limpiar el startup mod actual.
	 * Persiste el cambio en el mod.json correspondiente.
	 */
	public static function setStartupMod(modId:Null<String>):Void
	{
		#if sys
		// Quitar flag del anterior startup mod
		if (startupMod != null && startupMod != modId)
		{
			final prev = getInfo(startupMod);
			if (prev != null) { prev.startupDefault = false; _writeModJson(prev); }
		}
		startupMod = modId;
		if (modId != null)
		{
			final info = getInfo(modId);
			if (info != null)
			{
				info.startupDefault = true;
				_writeModJson(info);
				trace('[ModManager] Startup mod = "$modId"');
			}
		}
		else trace('[ModManager] Startup mod limpiado.');
		#end
	}

	/**
	 * Aplica el startup mod si no hay sesión guardada.
	 * Llamar tras init() en el arranque del juego.
	 */
	public static function applyStartupMod():Void
	{
		if (activeMod != null) return;
		if (startupMod != null)
		{
			trace('[ModManager] Aplicando startup mod: "$startupMod"');
			activeMod = startupMod;
			if (onModChanged != null) onModChanged(activeMod);
		}
	}

	// ─── Creación / Edición de mods ───────────────────────────────────────────

	/**
	 * Crea un nuevo mod con la estructura de carpetas estándar.
	 * @param id    Identificador/carpeta (ej: "my-cool-mod")
	 * @param info  Campos del mod.json
	 * @return El ModInfo creado o null si hubo error
	 */
	public static function createMod(id:String, info:ModInfo):Null<ModInfo>
	{
		#if sys
		final modPath = '$MODS_FOLDER/$id';
		if (FileSystem.exists(modPath))
		{
			trace('[ModManager] createMod: la carpeta "$modPath" ya existe.');
			return null;
		}
		try
		{
			FileSystem.createDirectory(modPath);
			for (sub in STD_FOLDERS) FileSystem.createDirectory('$modPath/$sub');
			info.id     = id;
			info.folder = modPath;
			_writeModJson(info);
			installedMods.push(info);
			installedMods.sort((a, b) ->
			{
				if (b.priority != a.priority) return b.priority - a.priority;
				return a.name < b.name ? -1 : 1;
			});
			trace('[ModManager] Mod creado: "$id"');
			return info;
		}
		catch (e:Dynamic) { trace('[ModManager] Error creando mod "$id": $e'); return null; }
		#else
		return null;
		#end
	}

	/**
	 * Guarda los cambios de un ModInfo existente en disco.
	 */
	public static function saveModInfo(info:ModInfo):Void
	{
		#if sys
		for (i in 0...installedMods.length)
			if (installedMods[i].id == info.id) { installedMods[i] = info; break; }
		_writeModJson(info);
		trace('[ModManager] mod.json actualizado: ${info.id}');
		#end
	}

	// ─── Resolución de paths ──────────────────────────────────────────────────

	public static function resolveInMod(file:String):Null<String>
	{
		if (activeMod == null) return null;
		final path = '$MODS_FOLDER/$activeMod/$file';
		#if sys return FileSystem.exists(path) ? path : null;
		#else return openfl.utils.Assets.exists(path) ? path : null; #end
	}

	public static function resolveInSpecific(modId:Null<String>, file:String):Null<String>
	{
		if (modId == null) return null;
		final path = '$MODS_FOLDER/$modId/$file';
		#if sys return FileSystem.exists(path) ? path : null;
		#else return openfl.utils.Assets.exists(path) ? path : null; #end
	}

	public static inline function modRoot():Null<String>
		return activeMod != null ? '$MODS_FOLDER/$activeMod' : null;

	// ─── Preview ──────────────────────────────────────────────────────────────

	public static function previewVideo(modId:String):Null<String>
	{
		final p = '$MODS_FOLDER/$modId/preview.mp4';
		#if sys return FileSystem.exists(p) ? p : null; #else return null; #end
	}

	public static function previewImage(modId:String):Null<String>
	{
		#if sys
		for (ext in ['png', 'jpg', 'jpeg'])
		{
			final p = '$MODS_FOLDER/$modId/preview.$ext';
			if (FileSystem.exists(p)) return p;
		}
		return null;
		#else return null; #end
	}

	public static function iconPath(modId:String):Null<String>
	{
		final p = '$MODS_FOLDER/$modId/icon.png';
		#if sys return FileSystem.exists(p) ? p : null; #else return null; #end
	}

	public static function previewType(modId:String):ModPreviewType
	{
		if (previewVideo(modId) != null) return VIDEO;
		if (previewImage(modId) != null) return IMAGE;
		return NONE;
	}

	// ─── Info del mod ─────────────────────────────────────────────────────────

	public static function activeInfo():Null<ModInfo>
	{
		if (activeMod == null) return null;
		for (m in installedMods) if (m.id == activeMod) return m;
		return null;
	}

	public static function getInfo(modId:String):Null<ModInfo>
	{
		for (m in installedMods) if (m.id == modId) return m;
		return null;
	}

	// ─── Helpers internos ─────────────────────────────────────────────────────
	#if sys
	static function _loadModInfo(id:String, path:String):Null<ModInfo>
	{
		final jsonPath = '$path/mod.json';
		var name           = id;
		var desc           = '';
		var author         = '';
		var version        = '1.0.0';
		var priority       = 0;
		var color          = 0xFF9900;
		var website        = '';
		var enabledDef     = true;
		var startupDef     = false;

		if (FileSystem.exists(jsonPath))
		{
			try
			{
				final d:Dynamic = Json.parse(File.getContent(jsonPath));
				name       = d.name           ?? id;
				desc       = d.description    ?? '';
				author     = d.author         ?? '';
				version    = d.version        ?? '1.0.0';
				priority   = Std.int(d.priority ?? 0);
				website    = d.website        ?? '';
				enabledDef = d.enabled        ?? true;
				startupDef = d.startupDefault ?? false;
				if (d.color != null)
				{
					try
					{
						var hex:String = Std.string(d.color);
						if (StringTools.startsWith(hex, '#')) hex = hex.substr(1);
						color = 0xFF000000 | Std.parseInt('0x$hex');
					}
					catch (_) {}
				}
			}
			catch (e:Dynamic) { trace('[ModManager] Error mod.json "$id": $e'); }
		}

		final enabled = _enabledMap.exists(id) ? _enabledMap.get(id) : enabledDef;
		return {
			id: id, name: name, description: desc, author: author,
			version: version, priority: priority, color: color,
			website: website, enabled: enabled, startupDefault: startupDef, folder: path
		};
	}

	static function _writeModJson(info:ModInfo):Void
	{
		try
		{
			final obj:Dynamic = {
				name:           info.name,
				description:    info.description,
				author:         info.author,
				version:        info.version,
				priority:       info.priority,
				color:          StringTools.hex(info.color & 0xFFFFFF, 6),
				website:        info.website,
				enabled:        info.enabled,
				startupDefault: info.startupDefault
			};
			File.saveContent('${info.folder}/mod.json', Json.stringify(obj, null, '\t'));
		}
		catch (e:Dynamic) { trace('[ModManager] Error escribiendo mod.json "${info.id}": $e'); }
	}

	static function _saveActiveState():Void
	{
		try { File.saveContent('$MODS_FOLDER/.active_mod.json', Json.stringify({active: activeMod})); }
		catch (e:Dynamic) { trace('[ModManager] No se pudo guardar active mod: $e'); }
	}

	public static function loadActiveState():Void
	{
		final path = '$MODS_FOLDER/.active_mod.json';
		if (!FileSystem.exists(path)) return;
		try
		{
			final data:Dynamic = Json.parse(File.getContent(path));
			final savedId:String = Reflect.field(data, 'active');
			if (savedId != null && isInstalled(savedId))
			{
				activeMod = savedId;
				trace('[ModManager] Mod activo restaurado: "$activeMod"');
			}
		}
		catch (e:Dynamic) { trace('[ModManager] Error restaurando active mod: $e'); }
	}

	static function _saveEnabledState():Void
	{
		try
		{
			final obj:Dynamic = {};
			for (id => val in _enabledMap) Reflect.setField(obj, id, val);
			File.saveContent('$MODS_FOLDER/.enabled_state.json', Json.stringify(obj));
		}
		catch (e:Dynamic) { trace('[ModManager] No se pudo guardar enabled state: $e'); }
	}

	static function _loadEnabledState():Void
	{
		final path = '$MODS_FOLDER/.enabled_state.json';
		if (!FileSystem.exists(path)) return;
		try
		{
			final data:Dynamic = Json.parse(File.getContent(path));
			for (f in Reflect.fields(data)) _enabledMap.set(f, Reflect.field(data, f) == true);
		}
		catch (e:Dynamic) { trace('[ModManager] Error cargando enabled state: $e'); }
	}
	#end
}

// ─────────────────────────────────────────────────────────────────────────────

typedef ModInfo =
{
	var id:String;
	var name:String;
	var description:String;
	var author:String;
	var version:String;
	var priority:Int;
	var color:Int;
	var website:String;
	var enabled:Bool;
	var startupDefault:Bool;
	var folder:String;
}

enum ModPreviewType { VIDEO; IMAGE; NONE; }
