package funkin.scripting;

import flixel.FlxG;
import funkin.gameplay.PlayState;
import funkin.data.Song.SwagSong;
import funkin.data.Section.SwagSection;

using StringTools;

/**
 * Sistema de eventos para PlayState.
 * 
 * Solo contiene infraestructura: carga, trigger y registro.
 * Los handlers de eventos están en assets/scripts/events/
 * y se registran con registerEvent() desde HScript.
 */
class EventManager
{
	public static var events:Array<EventData> = [];
	public static var customEventHandlers:Map<String, Array<EventData>->Bool> = new Map();

	// ─────────────────────────────────────────────────────────────
	//  CARGA
	// ─────────────────────────────────────────────────────────────

	/**
	 * Carga eventos desde _song.events (formato nuevo del sidebar visual).
	 * Convierte stepTime → ms con el BPM base de la canción.
	 * Llamar DESPUÉS de que Conductor esté configurado.
	 */
	public static function loadEventsFromSong():Void
	{
		events = [];
		var songData:SwagSong = PlayState.SONG;
		if (songData == null) return;

		// ── Formato NUEVO: _song.events ──────────────────────────
		if (songData.events != null && songData.events.length > 0)
		{
			for (evt in songData.events)
			{
				var timeMs = stepTimeToMs(evt.stepTime, songData.bpm);

				var v1 = evt.value != null ? evt.value : '';
				var v2 = '';
				if (v1.contains('|'))
				{
					var parts = v1.split('|');
					v1 = parts[0].trim();
					v2 = parts.length > 1 ? parts[1].trim() : '';
				}

				var event    = new EventData();
				event.time   = timeMs;
				event.name   = evt.type;
				event.value1 = v1;
				event.value2 = v2;
				events.push(event);
			}
			trace('[EventManager] ${events.length} eventos cargados desde _song.events');
		}
		else if (songData.notes != null)
		{
			// ── Formato LEGACY: notas especiales en sectionNotes ──
			var sections:Array<SwagSection> = cast songData.notes;
			for (section in sections)
			{
				if (section.sectionNotes == null) continue;
				for (note in section.sectionNotes)
				{
					if (note.length >= 5 && note[4] != null && Std.string(note[4]) != '')
					{
						var event    = new EventData();
						event.time   = note[0];
						event.name   = Std.string(note[4]);
						event.value1 = note.length >= 6 ? Std.string(note[5]) : '';
						event.value2 = note.length >= 7 ? Std.string(note[6]) : '';
						events.push(event);
					}
				}
			}
			trace('[EventManager] ${events.length} eventos cargados desde formato legacy');
		}

		// ── Compatibilidad hacia atrás ──────────────────────────
		// Si el chart no tiene ningún evento de cámara, generar Camera Follow
		// automáticamente desde mustHitSection para que los charts viejos
		// funcionen sin necesidad de portearlos.
		var hasCameraEvents = false;
		for (e in events)
			if (e.name == 'Camera Follow') { hasCameraEvents = true; break; }

		if (!hasCameraEvents && songData.notes != null)
			generateCameraFollowFromSections(songData);

		events.sort((a, b) -> Std.int(a.time - b.time));

		// Exponer API de eventos en scripts
		setupEventScriptAPI();
	}

	/**
	 * Genera Camera Follow automáticamente desde mustHitSection.
	 * Backwards-compat: los charts viejos no necesitan portearse.
	 */
	private static function generateCameraFollowFromSections(songData:SwagSong):Void
	{
		var lastTarget = '';
		var step:Float = 0;
		var bpm:Float  = songData.bpm;

		var sections:Array<SwagSection> = cast songData.notes;
		for (section in sections)
		{
			var stepsInSection:Float = section.lengthInSteps > 0 ? section.lengthInSteps : 16;
			var target = (section.mustHitSection == true) ? 'player' : 'opponent';
			var timeMs = stepTimeToMs(step, bpm);

			if (target != lastTarget)
			{
				var ev    = new EventData();
				ev.time   = timeMs;
				ev.name   = 'Camera Follow';
				ev.value1 = target;
				ev.value2 = '';
				events.push(ev);
				lastTarget = target;
			}

			if (section.changeBPM == true && section.bpm > 0)
				bpm = section.bpm;

			step += stepsInSection;
		}

		trace('[EventManager] Auto-generados ${events.length} Camera Follow desde mustHitSection');
	}

	/**
	 * Actualiza la referencia a `game` en todos los scripts activos
	 * para que apunte al PlayState actual (se llama después de crear la instancia).
	 */
	private static function setupEventScriptAPI():Void
	{
		// game = PlayState.instance puede ser null cuando los scripts globales cargan,
		// así que lo refrescamos aquí cuando ya existe la instancia.
		ScriptHandler.setOnScripts('game', PlayState.instance);
	}

	static function stepTimeToMs(step:Float, bpm:Float):Float
	{
		// 1 beat = 60 000 / bpm ms | 1 step = 1 beat / 4
		return step * ((60000.0 / bpm) / 4.0);
	}

	// ─────────────────────────────────────────────────────────────
	//  UPDATE
	// ─────────────────────────────────────────────────────────────

	public static function update(songPosition:Float):Void
	{
		var toRemove:Array<EventData> = [];

		for (event in events)
		{
			if (!event.triggered && songPosition >= event.time)
			{
				triggerEvent(event);
				event.triggered = true;
				toRemove.push(event);
			}
		}

		for (event in toRemove)
			events.remove(event);
	}

	// ─────────────────────────────────────────────────────────────
	//  TRIGGER
	// ─────────────────────────────────────────────────────────────

	public static function triggerEvent(event:EventData):Void
	{
		trace('[EventManager] → "${event.name}" | v1="${event.value1}" v2="${event.value2}" t=${event.time}ms');

		// 1. onEvent en scripts — retornar true cancela todo
		if (ScriptHandler.callOnScriptsReturn('onEvent',
			[event.name, event.value1, event.value2, event.time], false) == true)
		{
			trace('[EventManager] Cancelado por script (onEvent)');
			return;
		}

		// 2. Handler registrado con registerEvent() — el script devuelve true para cancelar
		if (customEventHandlers.exists(event.name))
		{
			if (customEventHandlers.get(event.name)([event]))
			{
				trace('[EventManager] Cancelado por handler');
				return;
			}
		}
		else
		{
			trace('[EventManager] Sin handler para "${event.name}" — añade uno en assets/data/scripts/events/');
		}
	}

	// ─────────────────────────────────────────────────────────────
	//  API PÚBLICA
	// ─────────────────────────────────────────────────────────────

	public static function registerCustomEvent(eventName:String, handler:Array<EventData>->Bool):Void
	{
		customEventHandlers.set(eventName, handler);
	}

	public static function fireEvent(eventName:String, value1:String = '', value2:String = ''):Void
	{
		var event    = new EventData();
		event.name   = eventName;
		event.value1 = value1;
		event.value2 = value2;
		event.time   = FlxG.sound.music != null ? FlxG.sound.music.time : 0;
		triggerEvent(event);
	}

	public static function clear():Void
	{
		events = [];
		customEventHandlers.clear();
	}
}

// ─────────────────────────────────────────────────────────────────

class EventData
{
	public var name:String    = '';
	public var time:Float     = 0;
	public var value1:String  = '';
	public var value2:String  = '';
	public var triggered:Bool = false;

	public function new() {}

	public function toString():String
		return 'Event["$name" @ ${time}ms | "$value1" "$value2"]';
}
