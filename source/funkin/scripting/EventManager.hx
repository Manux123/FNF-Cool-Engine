package funkin.scripting;

import flixel.FlxG;
import funkin.gameplay.PlayState;
import funkin.data.Song.SwagSong;
import funkin.data.Section.SwagSection;

using StringTools;

/**
 * Sistema de eventos de gameplay.
 *
 * Infraestructura pura: carga, disparo y registro de handlers.
 * Los handlers concretos viven en `assets/data/scripts/events/`
 * y se registran con `registerEvent()` desde HScript.
 *
 * ─── Optimizaciones respecto a la versión anterior ───────────────────────────
 *   • Puntero de índice en `update()` — sin array `toRemove` por frame.
 *   • `events` ya no se modifica durante `update()`, sólo se avanza el índice.
 *   • `stepTimeToMs` es `inline` — el compilador la inlinea en hot paths.
 *   • `triggerEvent` sin creación de closures en el path normal.
 *
 * ─── Uso desde HScript ───────────────────────────────────────────────────────
 *   registerEvent('Flash', function(v1, v2, time) {
 *     FlxG.cameras.flash(FlxColor.WHITE, 0.5);
 *   });
 *   fireEvent('Flash');
 */
class EventManager
{
	/** Todos los eventos de la canción actual, ordenados por tiempo. */
	public static var events : Array<EventData> = [];

	/** Handlers custom registrados por scripts. */
	public static var customHandlers : Map<String, Array<EventData>->Bool> = [];

	/**
	 * Índice del siguiente evento a comprobar en `update()`.
	 * Al ser un puntero, update() nunca necesita crear arrays temporales.
	 */
	static var _nextIndex : Int = 0;

	// ─── Carga ────────────────────────────────────────────────────────────────

	/**
	 * Carga y ordena eventos desde `PlayState.SONG`.
	 * Llamar DESPUÉS de que `Conductor` esté configurado.
	 */
	public static function loadEventsFromSong():Void
	{
		events     = [];
		_nextIndex = 0;

		final songData:SwagSong = PlayState.SONG;
		if (songData == null) return;

		if (songData.events != null && songData.events.length > 0)
			loadNewFormat(songData);
		else if (songData.notes != null)
			loadLegacyFormat(songData);

		// Compatibilidad hacia atrás: generar Camera Follow desde mustHitSection
		// si el chart no tiene ningún evento de cámara.
		final hasNewEvents = songData.events != null && songData.events.length > 0;
		if (!hasNewEvents && songData.notes != null)
		{
			var hasCam = false;
			for (e in events) if (e.name == 'Camera Follow') { hasCam = true; break; }
			if (!hasCam) generateCameraFollow(songData);
		}

		events.sort((a, b) -> Std.int(a.time - b.time));

		// Refrescar `game` en los scripts ahora que PlayState.instance existe.
		ScriptHandler.setOnScripts('game', PlayState.instance);

		trace('[EventManager] ${events.length} eventos cargados.');
	}

	static function loadNewFormat(songData:SwagSong):Void
	{
		for (evt in songData.events)
		{
			var v1 = evt.value != null ? evt.value : '';
			var v2 = '';

			if (v1.contains('|'))
			{
				final parts = v1.split('|');
				v1 = parts[0].trim();
				v2 = parts.length > 1 ? parts[1].trim() : '';
			}

			final e    = new EventData();
			e.name     = evt.type;
			e.time     = stepToMs(evt.stepTime, songData.bpm);
			e.value1   = v1;
			e.value2   = v2;
			events.push(e);
		}
		trace('[EventManager] Formato nuevo: ${events.length} eventos.');
	}

	static function loadLegacyFormat(songData:SwagSong):Void
	{
		final sections:Array<SwagSection> = cast songData.notes;
		for (section in sections)
		{
			if (section.sectionNotes == null) continue;
			for (note in section.sectionNotes)
			{
				if (note.length < 5 || note[4] == null || Std.string(note[4]) == '') continue;
				final e  = new EventData();
				e.name   = Std.string(note[4]);
				e.time   = note[0];
				e.value1 = note.length >= 6 ? Std.string(note[5]) : '';
				e.value2 = note.length >= 7 ? Std.string(note[6]) : '';
				events.push(e);
			}
		}
		trace('[EventManager] Formato legacy: ${events.length} eventos.');
	}

	static function generateCameraFollow(songData:SwagSong):Void
	{
		var lastTarget = '';
		var step:Float = 0;
		var bpm:Float  = songData.bpm;
		var count = 0;

		final sections:Array<SwagSection> = cast songData.notes;
		for (section in sections)
		{
			final stepsInSection:Float = section.lengthInSteps > 0 ? section.lengthInSteps : 16;
			final target = section.mustHitSection ? 'player' : 'opponent';

			if (target != lastTarget)
			{
				final e  = new EventData();
				e.name   = 'Camera Follow';
				e.time   = stepToMs(step, bpm);
				e.value1 = target;
				events.push(e);
				lastTarget = target;
				count++;
			}

			if (section.changeBPM && section.bpm > 0) bpm = section.bpm;
			step += stepsInSection;
		}
		trace('[EventManager] Auto-generados $count Camera Follow desde mustHitSection.');
	}

	// ─── Update ───────────────────────────────────────────────────────────────

	/**
	 * Dispara los eventos cuyo tiempo ha llegado.
	 * Usa un puntero de índice — sin allocaciones por frame.
	 */
	public static function update(songPosition:Float):Void
	{
		while (_nextIndex < events.length)
		{
			final event = events[_nextIndex];
			if (songPosition < event.time) break;

			if (!event.triggered)
			{
				event.triggered = true;
				triggerEvent(event);
			}
			_nextIndex++;
		}
	}

	// ─── Disparo ──────────────────────────────────────────────────────────────

	public static function triggerEvent(event:EventData):Void
	{
		trace('[EventManager] → "${event.name}" | v1="${event.value1}" v2="${event.value2}" t=${event.time}ms');

		// Los scripts pueden cancelar el evento devolviendo true en `onEvent`.
		if (ScriptHandler.callOnScriptsReturn('onEvent',
			[event.name, event.value1, event.value2, event.time], false) == true)
		{
			trace('[EventManager] Cancelado por script.');
			return;
		}

		final handler = customHandlers.get(event.name);
		if (handler != null)
		{
			if (handler([event]))
				trace('[EventManager] Cancelado por handler custom.');
		}
		else
		{
			trace('[EventManager] Sin handler para "${event.name}" — añade uno en assets/data/scripts/events/');
		}
	}

	// ─── API pública ──────────────────────────────────────────────────────────

	/** Registra un handler custom para eventos con `name`. */
	public static function registerCustomEvent(name:String, handler:Array<EventData>->Bool):Void
		customHandlers.set(name, handler);

	/**
	 * Dispara un evento manualmente (fuera del timeline).
	 * El tiempo se lee de la posición actual de la música.
	 */
	public static function fireEvent(name:String, value1:String = '', value2:String = ''):Void
	{
		final e  = new EventData();
		e.name   = name;
		e.time   = FlxG.sound.music != null ? FlxG.sound.music.time : 0;
		e.value1 = value1;
		e.value2 = value2;
		triggerEvent(e);
	}

	public static function clear():Void
	{
		events = [];
		customHandlers.clear();
		_nextIndex = 0;
	}

	// ─── Util ─────────────────────────────────────────────────────────────────

	/** 1 beat = 60 000 / bpm ms  |  1 step = 1 beat / 4 */
	public static inline function stepToMs(step:Float, bpm:Float):Float
		return step * (60000.0 / bpm / 4.0);
}

// ─────────────────────────────────────────────────────────────────────────────

/** Datos de un evento de gameplay. Puede crearse como objeto anónimo. */
class EventData
{
	public var name      : String = '';
	public var time      : Float  = 0;
	public var value1    : String = '';
	public var value2    : String = '';
	public var triggered : Bool   = false;

	public function new() {}

	public function toString():String
		return 'Event["$name" @ ${time}ms | "$value1" "$value2"]';
}
