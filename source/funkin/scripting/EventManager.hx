package funkin.scripting;

import flixel.FlxG;
import funkin.gameplay.PlayState;

using StringTools;

/**
 * Sistema de eventos para PlayState
 * Compatible con editor visual de eventos
 * Soporta cancelación desde scripts
 */
class EventManager
{
	public static var events:Array<EventData> = [];
	public static var customEventHandlers:Map<String, Array<EventData>->Bool> = new Map();
	
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
		
		// === SISTEMA DE CANCELACIÓN ===
		// Los scripts pueden cancelar eventos retornando true
		
		// 1. Primero llamar scripts con onEvent
		var cancelled = StateScriptHandler.callOnScripts('onEvent', [event.name, event.value1, event.value2, event.time]);
		if (cancelled)
		{
			trace('[EventManager] Evento ${event.name} cancelado por script');
			return;
		}
		
		// 2. Luego handlers personalizados (también pueden cancelar)
		if (customEventHandlers.exists(event.name))
		{
			var handler = customEventHandlers.get(event.name);
			cancelled = handler([event]);
			if (cancelled)
			{
				trace('[EventManager] Evento ${event.name} cancelado por handler personalizado');
				return;
			}
		}
		
		// 3. Si no fue cancelado, ejecutar evento built-in
		if (!cancelled)
		{
			handleBuiltInEvent(event);
		}
	}
	
	/**
	 * Manejar eventos integrados
	 * @return true si el evento fue cancelado
	 */
	private static function handleBuiltInEvent(event:EventData):Bool
	{
		var playState = PlayState.instance;
		if (playState == null)
			return false;
		
		// Llamar script específico para cada evento
		// El script puede cancelar el evento retornando true
		var eventFuncName = 'on${event.name.replace(' ', '')}';
		var cancelled = StateScriptHandler.callOnScripts(eventFuncName, [event.value1, event.value2, event.time]);
		
		if (cancelled)
		{
			trace('[EventManager] Evento built-in ${event.name} cancelado por script');
			return true;
		}
		
		switch (event.name.toLowerCase())
		{
			case 'hey!':
				return handleHeyEvent(event);
			
			case 'set gf speed':
				return handleGFSpeedEvent(event);
			
			case 'camera zoom':
				return handleCameraZoomEvent(event);
			
			case 'camera flash':
				return handleCameraFlashEvent(event);
			
			case 'camera fade':
				return handleCameraFadeEvent(event);
			
			case 'change character':
				return handleChangeCharacterEvent(event);
			
			case 'play animation':
				return handlePlayAnimationEvent(event);
			
			case 'screen shake':
				return handleScreenShakeEvent(event);
			
			default:
				trace('[EventManager] Evento desconocido: ${event.name}');
				return false;
		}
	}
	
	/**
	 * Evento: Hey!
	 * @return true si fue cancelado
	 */
	private static function handleHeyEvent(event:EventData):Bool
	{
		var playState = PlayState.instance;
		var target = event.value1.toLowerCase();
		
		// Permitir cancelación desde scripts
		var cancelled = StateScriptHandler.callOnScripts('onHeyEvent', [target]);
		if (cancelled) return true;
		
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
		
		return false;
	}
	
	/**
	 * Evento: Set GF Speed
	 */
	private static function handleGFSpeedEvent(event:EventData):Bool
	{
		var speed = Std.parseInt(event.value1);
		if (speed == null) speed = 1;
		
		var cancelled = StateScriptHandler.callOnScripts('onSetGFSpeed', [speed]);
		if (cancelled) return true;
		
		// Necesitarías exponer gfSpeed en PlayState
		// playState.gfSpeed = speed;
		
		return false;
	}
	
	/**
	 * Evento: Camera Zoom
	 */
	private static function handleCameraZoomEvent(event:EventData):Bool
	{
		var playState = PlayState.instance;
		var amount = Std.parseFloat(event.value1);
		var duration = Std.parseFloat(event.value2);
		
		if (Math.isNaN(amount)) amount = 0.05;
		if (Math.isNaN(duration)) duration = 0;
		
		var cancelled = StateScriptHandler.callOnScripts('onCameraZoom', [amount, duration]);
		if (cancelled) return true;
		
		if (duration > 0)
		{
			flixel.tweens.FlxTween.tween(playState.camGame, {zoom: playState.camGame.zoom + amount}, duration);
		}
		else
		{
			playState.camGame.zoom += amount;
		}
		
		return false;
	}
	
	/**
	 * Evento: Camera Flash
	 */
	private static function handleCameraFlashEvent(event:EventData):Bool
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
		
		var cancelled = StateScriptHandler.callOnScripts('onCameraFlash', [duration, color]);
		if (cancelled) return true;
		
		playState.camHUD.flash(color, duration);
		
		return false;
	}
	
	/**
	 * Evento: Camera Fade
	 */
	private static function handleCameraFadeEvent(event:EventData):Bool
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
		
		var cancelled = StateScriptHandler.callOnScripts('onCameraFade', [duration, color]);
		if (cancelled) return true;
		
		playState.camHUD.fade(color, duration);
		
		return false;
	}
	
	/**
	 * Evento: Change Character
	 */
	private static function handleChangeCharacterEvent(event:EventData):Bool
	{
		var playState = PlayState.instance;
		var target = event.value1.toLowerCase();
		var newChar = event.value2;
		
		if (newChar == null || newChar == '')
			return false;
		
		var cancelled = StateScriptHandler.callOnScripts('onChangeCharacter', [target, newChar]);
		if (cancelled) return true;
		
		// Implementar cambio de personaje
		// Necesitarías un método changeCharacter en PlayState
		
		return false;
	}
	
	/**
	 * Evento: Play Animation
	 */
	private static function handlePlayAnimationEvent(event:EventData):Bool
	{
		var playState = PlayState.instance;
		var target = event.value1.toLowerCase();
		var anim = event.value2;
		
		if (anim == null || anim == '')
			return false;
		
		var cancelled = StateScriptHandler.callOnScripts('onPlayAnimation', [target, anim]);
		if (cancelled) return true;
		
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
		
		return false;
	}
	
	/**
	 * Evento: Screen Shake
	 */
	private static function handleScreenShakeEvent(event:EventData):Bool
	{
		var playState = PlayState.instance;
		var intensity = Std.parseFloat(event.value1);
		var duration = Std.parseFloat(event.value2);
		
		if (Math.isNaN(intensity)) intensity = 0.05;
		if (Math.isNaN(duration)) duration = 0.5;
		
		var cancelled = StateScriptHandler.callOnScripts('onScreenShake', [intensity, duration]);
		if (cancelled) return true;
		
		playState.camGame.shake(intensity, duration);
		
		return false;
	}
	
	/**
	 * Registrar handler personalizado
	 * @param handler Función que retorna true para cancelar el evento
	 */
	public static function registerCustomEvent(eventName:String, handler:Array<EventData>->Bool):Void
	{
		customEventHandlers.set(eventName, handler);
		trace('[EventManager] Evento personalizado registrado: $eventName');
	}
	
	/**
	 * Disparar un evento manualmente desde código o script
	 */
	public static function fireEvent(eventName:String, value1:String = '', value2:String = ''):Void
	{
		var event = new EventData();
		event.name = eventName;
		event.value1 = value1;
		event.value2 = value2;
		event.time = FlxG.sound.music != null ? FlxG.sound.music.time : 0;
		
		triggerEvent(event);
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
	public var cancelled:Bool = false; // Nuevo: si fue cancelado
	
	public function new() {}
	
	public function toString():String
	{
		return 'Event[$name @ ${time}ms: $value1, $value2]';
	}
}
