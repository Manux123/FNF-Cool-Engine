package funkin.scripting;

import flixel.FlxG;
import funkin.gameplay.PlayState;

/**
 * Sistema de eventos para PlayState
 * Compatible con editor visual de eventos
 */
class EventManager
{
	public static var events:Array<EventData> = [];
	public static var customEventHandlers:Map<String, Array<EventData>->Void> = new Map();
	
	/**
	 * Registrar eventos desde la canción
	 */
	public static function loadEventsFromSong():Void
	{
		events = [];
		
		var songData = PlayState.SONG;
		if (songData == null || songData.notes == null)
			return;
		
		// Buscar eventos en las notas
		for (section in songData.notes)
		{
			if (section.sectionNotes == null)
				continue;
			
			for (note in section.sectionNotes)
			{
				// Formato: [time, noteData, sustainLength, ?noteType, ?eventName, ?value1, ?value2]
				if (note.length >= 5 && note[4] != null)
				{
					var event = new EventData();
					event.time = note[0];
					event.name = note[4];
					event.value1 = note.length >= 6 ? Std.string(note[5]) : '';
					event.value2 = note.length >= 7 ? Std.string(note[6]) : '';
					events.push(event);
				}
			}
		}
		
		// Ordenar eventos por tiempo
		events.sort((a, b) -> Std.int(a.time - b.time));
		
		trace('[EventManager] ${events.length} eventos cargados');
	}
	
	/**
	 * Actualizar eventos (llamar en update)
	 */
	public static function update(songPosition:Float):Void
	{
		var eventsToRemove:Array<EventData> = [];
		
		for (event in events)
		{
			if (!event.triggered && songPosition >= event.time)
			{
				triggerEvent(event);
				event.triggered = true;
				eventsToRemove.push(event);
			}
		}
		
		// Remover eventos ya ejecutados
		for (event in eventsToRemove)
			events.remove(event);
	}
	
	/**
	 * Ejecutar un evento
	 */
	public static function triggerEvent(event:EventData):Void
	{
		trace('[EventManager] Evento: ${event.name} (${event.value1}, ${event.value2})');
		
		// Primero intentar llamar scripts
		ScriptHandler.callOnScripts('onEvent', [event.name, event.value1, event.value2, event.time]);
		
		// Luego handlers personalizados
		if (customEventHandlers.exists(event.name))
		{
			var handler = customEventHandlers.get(event.name);
			handler([event]);
		}
		else
		{
			// Eventos built-in
			handleBuiltInEvent(event);
		}
	}
	
	/**
	 * Manejar eventos integrados
	 */
	private static function handleBuiltInEvent(event:EventData):Void
	{
		var playState = PlayState.instance;
		if (playState == null)
			return;
		
		switch (event.name.toLowerCase())
		{
			case 'hey!':
				handleHeyEvent(event);
			
			case 'set gf speed':
				handleGFSpeedEvent(event);
			
			case 'camera zoom':
				handleCameraZoomEvent(event);
			
			case 'camera flash':
				handleCameraFlashEvent(event);
			
			case 'camera fade':
				handleCameraFadeEvent(event);
			
			case 'change character':
				handleChangeCharacterEvent(event);
			
			case 'play animation':
				handlePlayAnimationEvent(event);
			
			case 'screen shake':
				handleScreenShakeEvent(event);
			
			default:
				trace('[EventManager] Evento desconocido: ${event.name}');
		}
	}
	
	/**
	 * Evento: Hey!
	 */
	private static function handleHeyEvent(event:EventData):Void
	{
		var playState = PlayState.instance;
		var target = event.value1.toLowerCase();
		
		if (target == 'bf' || target == 'boyfriend' || target == '')
		{
			if (playState.boyfriend != null)
				playState.boyfriend.playAnim('hey', true);
		}
		
		if (target == 'gf' || target == 'girlfriend' || target == '')
		{
			if (playState.gf != null)
				playState.gf.playAnim('cheer', true);
		}
	}
	
	/**
	 * Evento: Set GF Speed
	 */
	private static function handleGFSpeedEvent(event:EventData):Void
	{
		var speed = Std.parseInt(event.value1);
		if (speed == null) speed = 1;
		
		// Necesitarías exponer gfSpeed en PlayState
		// playState.gfSpeed = speed;
	}
	
	/**
	 * Evento: Camera Zoom
	 */
	private static function handleCameraZoomEvent(event:EventData):Void
	{
		var playState = PlayState.instance;
		var amount = Std.parseFloat(event.value1);
		var duration = Std.parseFloat(event.value2);
		
		if (Math.isNaN(amount)) amount = 0.05;
		if (Math.isNaN(duration)) duration = 0;
		
		if (duration > 0)
		{
			flixel.tweens.FlxTween.tween(playState.camGame, {zoom: playState.camGame.zoom + amount}, duration);
		}
		else
		{
			playState.camGame.zoom += amount;
		}
	}
	
	/**
	 * Evento: Camera Flash
	 */
	private static function handleCameraFlashEvent(event:EventData):Void
	{
		var playState = PlayState.instance;
		var duration = Std.parseFloat(event.value1);
		var colorStr = event.value2;
		
		if (Math.isNaN(duration)) duration = 1;
		
		var color = flixel.util.FlxColor.WHITE;
		if (colorStr != null && colorStr != '')
		{
			color = flixel.util.FlxColor.fromString(colorStr);
		}
		
		playState.camHUD.flash(color, duration);
	}
	
	/**
	 * Evento: Camera Fade
	 */
	private static function handleCameraFadeEvent(event:EventData):Void
	{
		var playState = PlayState.instance;
		var duration = Std.parseFloat(event.value1);
		var colorStr = event.value2;
		
		if (Math.isNaN(duration)) duration = 1;
		
		var color = flixel.util.FlxColor.BLACK;
		if (colorStr != null && colorStr != '')
		{
			color = flixel.util.FlxColor.fromString(colorStr);
		}
		
		playState.camHUD.fade(color, duration);
	}
	
	/**
	 * Evento: Change Character
	 */
	private static function handleChangeCharacterEvent(event:EventData):Void
	{
		var playState = PlayState.instance;
		var target = event.value1.toLowerCase();
		var newChar = event.value2;
		
		if (newChar == null || newChar == '')
			return;
		
		// Implementar cambio de personaje
		// Necesitarías un método changeCharacter en PlayState
	}
	
	/**
	 * Evento: Play Animation
	 */
	private static function handlePlayAnimationEvent(event:EventData):Void
	{
		var playState = PlayState.instance;
		var target = event.value1.toLowerCase();
		var anim = event.value2;
		
		if (anim == null || anim == '')
			return;
		
		switch (target)
		{
			case 'bf' | 'boyfriend':
				if (playState.boyfriend != null)
					playState.boyfriend.playAnim(anim, true);
			
			case 'dad' | 'opponent':
				if (playState.dad != null)
					playState.dad.playAnim(anim, true);
			
			case 'gf' | 'girlfriend':
				if (playState.gf != null)
					playState.gf.playAnim(anim, true);
		}
	}
	
	/**
	 * Evento: Screen Shake
	 */
	private static function handleScreenShakeEvent(event:EventData):Void
	{
		var playState = PlayState.instance;
		var intensity = Std.parseFloat(event.value1);
		var duration = Std.parseFloat(event.value2);
		
		if (Math.isNaN(intensity)) intensity = 0.05;
		if (Math.isNaN(duration)) duration = 0.5;
		
		playState.camGame.shake(intensity, duration);
	}
	
	/**
	 * Registrar handler personalizado
	 */
	public static function registerCustomEvent(eventName:String, handler:Array<EventData>->Void):Void
	{
		customEventHandlers.set(eventName, handler);
		trace('[EventManager] Evento personalizado registrado: $eventName');
	}
	
	/**
	 * Limpiar eventos
	 */
	public static function clear():Void
	{
		events = [];
		customEventHandlers.clear();
	}
}

/**
 * Datos de un evento
 */
class EventData
{
	public var name:String = '';
	public var time:Float = 0;
	public var value1:String = '';
	public var value2:String = '';
	public var triggered:Bool = false;
	
	public function new() {}
	
	public function toString():String
	{
		return 'Event[$name @ ${time}ms: $value1, $value2]';
	}
}
