package mods;

#if sys
import sys.FileSystem;
import sys.io.File;
#end
import haxe.Json;

/**
 * ModManager — Manages installed mods, activation, and previews.
 *
 * ─── Expected structure of a mod ───────────────────────────────────────────
 *
 *   mods/
 *   └── my-mod/
 *       ├── mod.json          ← metadatos (name, author, version, priority…)
 *       ├── preview.mp4       ← preview video in the selector  (opcional)
 *       ├── preview.png       ← preview image if there is no video (opcional)
 *       ├── icon.png          ← icon square of mod            (opcional)
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
 * ─── mod.json fields extras ──────────────────────────────────────────────────
 *   {
 *     "name":        "My Mod",
 *     "description": "Description of mod",
 *     "author":      "NameAuthor",
 *     "version":     "1.0.0",
 *     "priority":    0,          ← order in the list (largest = first)
 *     "color":       "FF5599",   ← accent color RRGGBB (without #)
 *     "website":     "https://…",
 *     "enabled":     true        ← You can set it to false to disable it without deleting it
 *   }
 */
class ModManager
{
	/** Mod actualmente cargado. `null` = modo base (solo assets/). */
	public static var activeMod(default, null):String = null;

	/** Lista de mods instalados, ordenada por priority desc. */
	public static var installedMods(default, null):Array<ModInfo> = [];

	/** Callback que se llama cuando cambia el mod activo. */
	public static var onModChanged:Null<String->Void> = null;

	/** Carpeta raíz donde viven los mods. */
	public static inline var MODS_FOLDER = 'mods';

	// Cache de estado enabled/disabled (persiste entre llamadas a init)
	private static var _enabledMap:Map<String, Bool> = new Map();

	// ─── Init ─────────────────────────────────────────────────────────────────

	/**
	 * Escanea `mods/` y llena `installedMods`.
	 * Llamar una vez al inicio. Es seguro llamarlo varias veces (recarga).
	 */
	public static function init():Void
	{
		installedMods = [];

		#if sys
		if (!FileSystem.exists(MODS_FOLDER) || !FileSystem.isDirectory(MODS_FOLDER))
		{
			trace('[ModManager] Carpeta "mods/" no encontrada — modo base activo.');
			return;
		}

		// ── Extraer mods comprimidos (.zip / .rar) ANTES de escanear carpetas ──
		// Permite cargar mods directamente desde archives sin descomprimirlos
		// manualmente. Si ya fueron extraídos y el archivo no cambió, es un no-op.
		final extracted = ModExtractor.extractAll();
		if (extracted.length > 0)
			trace('[ModManager] Mods extraídos de archivo: ' + extracted.join(', '));

		// Leer lista de mods desactivados persistida
		_loadEnabledState();

		for (entry in FileSystem.readDirectory(MODS_FOLDER))
		{
			final modPath = '$MODS_FOLDER/$entry';
			if (!FileSystem.isDirectory(modPath)) continue;

			final info = _loadModInfo(entry, modPath);
			if (info != null)
			{
				installedMods.push(info);
				trace('[ModManager] Mod encontrado: ${info.id} (${info.name}) priority=${info.priority} enabled=${info.enabled}');
			}
		}

		// Ordenar por priority descendente, luego alfabético
		installedMods.sort((a, b) ->
		{
			if (b.priority != a.priority)
				return b.priority - a.priority;
			return a.name < b.name ? -1 : 1;
		});
		#end

		trace('[ModManager] ${installedMods.length} mods instalados.');
	}

	// ─── Activación ───────────────────────────────────────────────────────────

	/**
	 * Activa un mod por su ID. Pasa `null` para volver al modo base.
	 * Si el mod está desactivado, se activa igual (el enabled es solo para
	 * el selector; el override explícito siempre funciona).
	 */
	public static function setActive(modId:Null<String>):Void
	{
		if (modId == null)
		{
			activeMod = null;
			trace('[ModManager] Mod desactivado — modo base.');
			if (onModChanged != null) onModChanged(null);
			return;
		}

		#if sys
		if (!isInstalled(modId))
		{
			trace('[ModManager] Mod "$modId" no encontrado. Se mantiene el mod actual.');
			return;
		}
		#end

		activeMod = modId;
		trace('[ModManager] Mod activo: "$activeMod"');
		if (onModChanged != null) onModChanged(activeMod);
	}

	/** Desactiva el mod activo. */
	public static inline function deactivate():Void
		setActive(null);

	/** ¿Hay algún mod activo? */
	public static inline function isActive():Bool
		return activeMod != null;

	/** ¿Está instalado `modId`? */
	public static function isInstalled(modId:String):Bool
	{
		#if sys
		return FileSystem.exists('$MODS_FOLDER/$modId')
		    && FileSystem.isDirectory('$MODS_FOLDER/$modId');
		#else
		for (m in installedMods)
			if (m.id == modId) return true;
		return false;
		#end
	}

	// ─── Enable / Disable ─────────────────────────────────────────────────────

	/** Activa o desactiva un mod en el selector (no lo borra). */
	public static function setEnabled(modId:String, enabled:Bool):Void
	{
		_enabledMap.set(modId, enabled);

		// Actualizar el objeto ModInfo
		for (m in installedMods)
			if (m.id == modId) { m.enabled = enabled; break; }

		// Si desactivamos el mod activo, desactivar también
		if (!enabled && activeMod == modId)
			deactivate();

		_saveEnabledState();
	}

	/** Alterna el estado enabled del mod. */
	public static function toggleEnabled(modId:String):Bool
	{
		final cur = isEnabled(modId);
		setEnabled(modId, !cur);
		return !cur;
	}

	/** ¿Está este mod habilitado en el selector? */
	public static function isEnabled(modId:String):Bool
	{
		if (_enabledMap.exists(modId))
			return _enabledMap.get(modId);
		// Por defecto enabled
		for (m in installedMods)
			if (m.id == modId) return m.enabled;
		return true;
	}

	// ─── Resolución de paths ──────────────────────────────────────────────────

	/**
	 * Intenta encontrar `file` en el mod activo.
	 * Devuelve `null` si no existe o no hay mod activo.
	 */
	public static function resolveInMod(file:String):Null<String>
	{
		if (activeMod == null) return null;
		final path = '$MODS_FOLDER/$activeMod/$file';
		#if sys
		return FileSystem.exists(path) ? path : null;
		#else
		return openfl.utils.Assets.exists(path) ? path : null;
		#end
	}

	/**
	 * Resuelve `file` en un mod específico sin cambiar el activo.
	 */
	public static function resolveInSpecific(modId:Null<String>, file:String):Null<String>
	{
		if (modId == null) return null;
		final path = '$MODS_FOLDER/$modId/$file';
		#if sys
		return FileSystem.exists(path) ? path : null;
		#else
		return openfl.utils.Assets.exists(path) ? path : null;
		#end
	}

	/** Ruta a la carpeta del mod activo. `null` si no hay mod. */
	public static inline function modRoot():Null<String>
		return activeMod != null ? '$MODS_FOLDER/$activeMod' : null;

	// ─── Preview ──────────────────────────────────────────────────────────────

	/**
	 * Devuelve la ruta al vídeo de preview del mod, o `null` si no existe.
	 * Busca: `mods/{id}/preview.mp4`
	 */
	public static function previewVideo(modId:String):Null<String>
	{
		final path = '$MODS_FOLDER/$modId/preview.mp4';
		#if sys
		return FileSystem.exists(path) ? path : null;
		#else
		return null;
		#end
	}

	/**
	 * Devuelve la ruta a la imagen de preview del mod, o `null` si no existe.
	 * Busca: `mods/{id}/preview.png`, luego `preview.jpg`
	 */
	public static function previewImage(modId:String):Null<String>
	{
		#if sys
		for (ext in ['png', 'jpg', 'jpeg'])
		{
			final path = '$MODS_FOLDER/$modId/preview.$ext';
			if (FileSystem.exists(path)) return path;
		}
		return null;
		#else
		return null;
		#end
	}

	/**
	 * Devuelve la ruta al icono del mod, o `null` si no existe.
	 * Busca: `mods/{id}/icon.png`
	 */
	public static function iconPath(modId:String):Null<String>
	{
		final path = '$MODS_FOLDER/$modId/icon.png';
		#if sys
		return FileSystem.exists(path) ? path : null;
		#else
		return null;
		#end
	}

	/**
	 * Tipo de preview disponible para un mod.
	 */
	public static function previewType(modId:String):ModPreviewType
	{
		if (previewVideo(modId) != null) return VIDEO;
		if (previewImage(modId) != null) return IMAGE;
		return NONE;
	}

	// ─── Info del mod ─────────────────────────────────────────────────────────

	/** Devuelve la info del mod activo, o `null` si no hay mod. */
	public static function activeInfo():Null<ModInfo>
	{
		if (activeMod == null) return null;
		for (m in installedMods)
			if (m.id == activeMod) return m;
		return null;
	}

	/** Devuelve la info de un mod por ID. */
	public static function getInfo(modId:String):Null<ModInfo>
	{
		for (m in installedMods)
			if (m.id == modId) return m;
		return null;
	}

	// ─── Helpers internos ─────────────────────────────────────────────────────

	#if sys
	static function _loadModInfo(id:String, path:String):Null<ModInfo>
	{
		final jsonPath = '$path/mod.json';
		var name = id;
		var desc = '';
		var author = '';
		var version = '1.0.0';
		var priority = 0;
		var color = 0xFF9900; // naranja por defecto
		var website = '';
		var enabledDefault = true;

		if (FileSystem.exists(jsonPath))
		{
			try
			{
				final data:Dynamic = Json.parse(File.getContent(jsonPath));
				name          = data.name        ?? id;
				desc          = data.description ?? '';
				author        = data.author      ?? '';
				version       = data.version     ?? '1.0.0';
				priority      = Std.int(data.priority ?? 0);
				website       = data.website     ?? '';
				enabledDefault = data.enabled    ?? true;

				// Parsear color hex (ej: "FF5599" → 0xFFFF5599)
				if (data.color != null)
				{
					try {
						var hex:String = Std.string(data.color);
						if (StringTools.startsWith(hex, '#')) hex = hex.substr(1);
						color = 0xFF000000 | Std.parseInt('0x$hex');
					} catch(_) {}
				}
			}
			catch (e:Dynamic)
			{
				trace('[ModManager] Error leyendo mod.json de "$id": $e');
			}
		}

		// El estado enabled del mapa tiene prioridad sobre mod.json
		final enabled = _enabledMap.exists(id) ? _enabledMap.get(id) : enabledDefault;

		return {
			id:          id,
			name:        name,
			description: desc,
			author:      author,
			version:     version,
			priority:    priority,
			color:       color,
			website:     website,
			enabled:     enabled,
			folder:      path
		};
	}

	/** Persiste el estado enabled/disabled de los mods en un JSON. */
	static function _saveEnabledState():Void
	{
		try
		{
			final obj:Dynamic = {};
			for (id => val in _enabledMap)
				Reflect.setField(obj, id, val);
			File.saveContent('$MODS_FOLDER/.enabled_state.json', Json.stringify(obj));
		}
		catch (e:Dynamic) { trace('[ModManager] No se pudo guardar enabled state: $e'); }
	}

	/** Carga el estado enabled/disabled persistido. */
	static function _loadEnabledState():Void
	{
		final path = '$MODS_FOLDER/.enabled_state.json';
		if (!FileSystem.exists(path)) return;
		try
		{
			final data:Dynamic = Json.parse(File.getContent(path));
			final fields = Reflect.fields(data);
			for (f in fields)
				_enabledMap.set(f, Reflect.field(data, f) == true);
		}
		catch (e:Dynamic) { trace('[ModManager] Error cargando enabled state: $e'); }
	}
	#end
}

// ─────────────────────────────────────────────────────────────────────────────

/** Metadatos completos de un mod. */
typedef ModInfo =
{
	var id          : String;
	var name        : String;
	var description : String;
	var author      : String;
	var version     : String;
	var priority    : Int;
	var color       : Int;      // ARGB
	var website     : String;
	var enabled     : Bool;
	var folder      : String;
}

enum ModPreviewType
{
	VIDEO;
	IMAGE;
	NONE;
}
