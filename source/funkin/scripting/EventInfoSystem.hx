package funkin.scripting;

import haxe.Json;
import sys.FileSystem;
import sys.io.File;
import mods.ModManager;

using StringTools;

/**
 * Tipo de un parámetro de evento (UI del editor de charts).
 *
 *   PDString              → campo de texto libre
 *   PDBool                → dropdown "true / false"
 *   PDInt(?min, ?max)     → campo numérico entero
 *   PDFloat(?min, ?max)   → campo numérico decimal
 *   PDDropDown(options)   → dropdown con opciones fijas
 *   PDColor               → campo de texto hex (ej "#FFFFFF")
 */
enum EventParamType
{
	PDString;
	PDBool;
	PDInt(?min:Int, ?max:Int);
	PDFloat(?min:Float, ?max:Float);
	PDDropDown(options:Array<String>);
	PDColor;
}

/**
 * Definición de un parámetro de evento para la UI del editor.
 */
typedef EventParamDef =
{
	var name:String;
	var type:EventParamType;
	var defValue:String;
}

/**
 * EventInfoSystem — Carga definiciones de eventos softcodeadas desde JSON.
 *
 * Rutas buscadas (en orden de prioridad):
 *   1. mods/<activeMod>/data/events/         ← eventos del mod activo
 *   2. mods/<activeMod>/data/events/shared/  ← eventos compartidos del mod activo
 *   3. assets/data/events/                   ← eventos del engine / base
 *   4. assets/data/events/shared/            ← eventos compartidos del engine
 *
 * Formato de cada JSON:
 * {
 *   "color": "#88CCFF",          // color en el sidebar (opcional)
 *   "params": [
 *     { "name": "Target",   "type": "DropDown(bf,dad,gf)", "defaultValue": "bf" },
 *     { "name": "Duration", "type": "Float(0,10)",         "defaultValue": "1.0" },
 *     { "name": "Loop",     "type": "Bool",                "defaultValue": "false" }
 *   ]
 * }
 *
 * Tipos de campo soportados en JSON:
 *   "String"              → texto libre
 *   "Bool"                → dropdown true/false
 *   "Int"                 → número entero (sin límites)
 *   "Int(min,max)"        → número entero con rango
 *   "Float"               → número decimal (sin límites)
 *   "Float(min,max)"      → número decimal con rango
 *   "DropDown(a,b,c)"     → dropdown con opciones
 *   "Color"               → texto hex para un color
 */
class EventInfoSystem
{
	/** Lista ordenada de nombres de eventos disponibles. */
	public static var eventList:Array<String> = [];

	/** Mapa nombre → lista de params. */
	public static var eventParams:Map<String, Array<EventParamDef>> = new Map();

	/** Mapa nombre → color (0xAARRGGBB). */
	public static var eventColors:Map<String, Int> = new Map();

	// ── Eventos built-in (siempre presentes, pueden ser sobreescritos por JSON) ──

	static var _builtins:Array<{ name:String, color:Int, params:Array<EventParamDef> }> = [
		{
			name: "Camera Follow",
			color: 0xFF88CCFF,
			params: [
				{ name: "Target",     type: PDDropDown(["bf","dad","gf","player","opponent"]), defValue: "bf"   },
				{ name: "Lerp Speed", type: PDFloat(0.0, 1.0),                                defValue: "0.04" }
			]
		},
		{
			name: "BPM Change",
			color: 0xFFFFAA00,
			params: [
				{ name: "New BPM", type: PDFloat(1.0, 9999.0), defValue: "120" }
			]
		},
		{
			name: "Camera Zoom",
			color: 0xFFCCAAFF,
			params: [
				{ name: "Zoom",  type: PDFloat(0.1, 10.0), defValue: "1.05" },
				{ name: "Speed", type: PDFloat(0.0, 10.0), defValue: "1.0"  }
			]
		},
		{
			name: "Camera Shake",
			color: 0xFFFF8866,
			params: [
				{ name: "Intensity", type: PDFloat(0.0, 1.0),  defValue: "0.005" },
				{ name: "Duration",  type: PDFloat(0.0, 10.0), defValue: "0.25"  }
			]
		},
		{
			name: "Camera Flash",
			color: 0xFFFFFFAA,
			params: [
				{ name: "Color",    type: PDColor,            defValue: "#FFFFFF" },
				{ name: "Duration", type: PDFloat(0.0, 10.0), defValue: "0.5"    }
			]
		},
		{
			name: "Play Anim",
			color: 0xFF88FF88,
			params: [
				{ name: "Target",    type: PDDropDown(["bf","dad","gf"]), defValue: "bf"   },
				{ name: "Animation", type: PDString,                      defValue: "hey"  },
				{ name: "Force",     type: PDBool,                        defValue: "true" }
			]
		},
		{
			name: "Alt Anim",
			color: 0xFFFF88CC,
			params: [
				{ name: "Target",  type: PDDropDown(["bf","dad","gf"]), defValue: "dad"  },
				{ name: "Enabled", type: PDBool,                        defValue: "true" }
			]
		},
		{
			name: "Change Character",
			color: 0xFFFFCC88,
			params: [
				{ name: "Slot",      type: PDDropDown(["bf","dad","gf"]), defValue: "bf"  },
				{ name: "Character", type: PDString,                      defValue: "pico" }
			]
		},
		{
			name: "HUD Visible",
			color: 0xFFAABBCC,
			params: [
				{ name: "Visible", type: PDBool, defValue: "true" }
			]
		},
		{
			name: "Play Video",
			color: 0xFF8888FF,
			params: [
				{ name: "Video Key", type: PDString, defValue: "myVideo" },
				{ name: "Mid-Song",  type: PDBool,   defValue: "true"    }
			]
		},
		{
			name: "Play Sound",
			color: 0xFFAAFF88,
			params: [
				{ name: "Sound",  type: PDString,          defValue: "confirmMenu" },
				{ name: "Volume", type: PDFloat(0.0, 1.0), defValue: "1.0"         }
			]
		},
		{
			name: "Add Health",
			color: 0xFF88FFAA,
			params: [
				{ name: "Amount", type: PDFloat(-2.0, 2.0), defValue: "0.1" }
			]
		},
		{
			name: "Hey!",
			color: 0xFFFFFF88,
			params: [
				{ name: "Target", type: PDDropDown(["bf","gf","both"]), defValue: "both" }
			]
		},
		{
			name: "Run Script",
			color: 0xFFFF88FF,
			params: [
				{ name: "Function Name", type: PDString, defValue: "myFunction" },
				{ name: "Argument",      type: PDString, defValue: ""           }
			]
		},
		{
			name: "End Song",
			color: 0xFFFF4444,
			params: []
		},
	];

	// ── API pública ─────────────────────────────────────────────────────────────

	/**
	 * Recarga todas las definiciones: built-ins + JSONs del engine + del mod activo.
	 * Llamar al abrir el ChartEditor (y al cambiar de mod).
	 */
	public static function reload():Void
	{
		eventList   = [];
		eventParams = new Map();
		eventColors = new Map();

		// 1. Registrar built-ins (base siempre disponible)
		for (ev in _builtins)
			_register(ev.name, ev.color, ev.params);

		// 2. JSONs del engine (assets/data/events/ y assets/data/events/shared/)
		_loadDir('assets/data/events', false);
		_loadDir('assets/data/events/shared', true);

		// 3. JSONs del mod activo (tienen prioridad sobre los del engine)
		if (ModManager.isActive())
		{
			final modRoot = ModManager.modRoot();
			if (modRoot != null)
			{
				_loadDir('$modRoot/data/events', false);
				_loadDir('$modRoot/data/events/shared', true);
			}
		}
	}

	/** Registra un evento manualmente desde código (útil para scripts). */
	public static function registerEvent(name:String, color:Int = 0xFFAAAAAA, ?params:Array<EventParamDef>):Void
		_register(name, color, params != null ? params : []);

	// ── Internals ───────────────────────────────────────────────────────────────

	static function _register(name:String, color:Int, params:Array<EventParamDef>):Void
	{
		if (!eventList.contains(name))
			eventList.push(name);
		eventParams.set(name, params != null ? params : []);
		eventColors.set(name, color);
	}

	/**
	 * Lee todos los .json de una carpeta del sistema de archivos.
	 * `isShared`: si true, no sobreescribe eventos built-in (solo añade nuevos).
	 */
	static function _loadDir(dir:String, isShared:Bool):Void
	{
		#if sys
		if (!FileSystem.exists(dir) || !FileSystem.isDirectory(dir))
			return;

		for (entry in FileSystem.readDirectory(dir))
		{
			if (!entry.endsWith('.json')) continue;

			var eventName = entry.substr(0, entry.length - 5); // quitar .json
			// En carpetas shared, no sobreescribir built-ins
			if (isShared && Lambda.exists(_builtins, function(b) return b.name == eventName))
				continue;

			try
			{
				var txt = File.getContent('$dir/$entry');
				if (txt == null || txt.trim() == '') continue;

				var data:EventInfoJSON = Json.parse(txt);
				if (data == null) continue;

				var color  = data.color != null ? _parseHex(data.color) : 0xFFAAAAAA;
				var params = _parseParams(data.params);
				_register(eventName, color, params);
			}
			catch (e:Dynamic)
			{
				trace('[EventInfoSystem] Error cargando $dir/$entry: $e');
			}
		}
		#end
	}

	static function _parseParams(raw:Array<EventParamJSON>):Array<EventParamDef>
	{
		if (raw == null) return [];
		var result:Array<EventParamDef> = [];
		for (p in raw)
		{
			if (p == null || p.name == null) continue;
			result.push({
				name:     p.name,
				type:     _parseType(p.type),
				defValue: p.defaultValue != null ? Std.string(p.defaultValue) : ""
			});
		}
		return result;
	}

	static function _parseType(raw:String):EventParamType
	{
		if (raw == null) return PDString;
		raw = raw.trim();

		switch (raw.toLowerCase())
		{
			case 'bool':   return PDBool;
			case 'string': return PDString;
			case 'color':  return PDColor;
			case 'int':    return PDInt(null, null);
			case 'float':  return PDFloat(null, null);
		}

		// DropDown(a,b,c)
		if (raw.startsWith('DropDown(') || raw.startsWith('dropdown('))
		{
			var inner = raw.substring(raw.indexOf('(') + 1, raw.lastIndexOf(')'));
			var opts  = inner.split(',').map(s -> s.trim());
			return PDDropDown(opts);
		}

		// Int(min,max)
		if (raw.startsWith('Int(') || raw.startsWith('int('))
		{
			var parts = _extractPair(raw);
			return PDInt(parts[0] != '' ? Std.parseInt(parts[0])  : null,
			             parts[1] != '' ? Std.parseInt(parts[1])  : null);
		}

		// Float(min,max)
		if (raw.startsWith('Float(') || raw.startsWith('float('))
		{
			var parts = _extractPair(raw);
			return PDFloat(parts[0] != '' ? Std.parseFloat(parts[0]) : null,
			               parts[1] != '' ? Std.parseFloat(parts[1]) : null);
		}

		return PDString;
	}

	static function _extractPair(s:String):Array<String>
	{
		var inner = s.substring(s.indexOf('(') + 1, s.lastIndexOf(')'));
		var parts = inner.split(',');
		return [parts.length > 0 ? parts[0].trim() : '', parts.length > 1 ? parts[1].trim() : ''];
	}

	static function _parseHex(s:String):Int
	{
		s = s.replace('#', '').replace('0x', '').replace('0X', '');
		try { return Std.parseInt('0x' + s); }
		catch (_:Dynamic) { return 0xFFAAAAAA; }
	}
}

// ── Typedefs JSON ─────────────────────────────────────────────────────────────

private typedef EventInfoJSON =
{
	@:optional var color:String;
	@:optional var params:Array<EventParamJSON>;
}

private typedef EventParamJSON =
{
	var name:String;
	@:optional var type:String;
	@:optional var defaultValue:Dynamic;
}
