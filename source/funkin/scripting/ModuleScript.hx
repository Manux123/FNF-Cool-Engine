package funkin.scripting;

import flixel.FlxG;
import funkin.gameplay.PlayState;
import funkin.gameplay.notes.Note;

/**
 * Clase base para módulos de script
 * Extiende esta clase para crear scripts más organizados
 */
class ModuleScript
{
	public var name:String = 'Module';
	public var description:String = '';
	public var author:String = '';
	public var version:String = '1.0.0';
	
	public var playState:PlayState;
	public var active:Bool = true;
	
	public function new()
	{
		playState = PlayState.instance;
	}
	
	// ===========================
	// LIFECYCLE CALLBACKS
	// ===========================
	
	/**
	 * Llamado cuando el script es cargado
	 */
	public function onCreate():Void
	{
		trace('[Module $name] Created');
	}
	
	/**
	 * Llamado cada frame
	 */
	public function onUpdate(elapsed:Float):Void
	{
	}
	
	/**
	 * Llamado después de update
	 */
	public function onUpdatePost(elapsed:Float):Void
	{
	}
	
	/**
	 * Llamado cuando empieza la cuenta regresiva
	 */
	public function onCountdownStarted():Void
	{
	}
	
	/**
	 * Llamado en cada tick del countdown
	 */
	public function onCountdownTick(tick:Int):Void
	{
	}
	
	/**
	 * Llamado cuando empieza la canción
	 */
	public function onSongStart():Void
	{
	}
	
	/**
	 * Llamado cuando termina la canción
	 */
	public function onSongEnd():Void
	{
	}
	
	/**
	 * Llamado en cada beat
	 */
	public function onBeatHit(beat:Int):Void
	{
	}
	
	/**
	 * Llamado en cada step
	 */
	public function onStepHit(step:Int):Void
	{
	}
	
	/**
	 * Llamado cuando cambia de sección
	 */
	public function onSectionHit(section:Int):Void
	{
	}
	
	// ===========================
	// NOTE CALLBACKS
	// ===========================
	
	/**
	 * Llamado cuando el jugador golpea una nota
	 * @return true para cancelar el comportamiento por defecto
	 */
	public function onPlayerNoteHit(note:Note, rating:String):Bool
	{
		return false;
	}
	
	/**
	 * Llamado después de que el jugador golpea una nota
	 */
	public function onPlayerNoteHitPost(note:Note, rating:String):Void
	{
	}
	
	/**
	 * Llamado cuando el jugador falla una nota
	 * @return true para cancelar el comportamiento por defecto
	 */
	public function onPlayerNoteMiss(note:Note):Bool
	{
		return false;
	}
	
	/**
	 * Llamado después de que el jugador falla una nota
	 */
	public function onPlayerNoteMissPost(note:Note):Void
	{
	}
	
	/**
	 * Llamado cuando el oponente canta una nota
	 */
	public function onOpponentNoteHit(note:Note):Void
	{
	}
	
	/**
	 * Llamado cuando aparece una nota en pantalla
	 */
	public function onNoteSpawn(note:Note):Void
	{
	}
	
	// ===========================
	// EVENT CALLBACKS
	// ===========================
	
	/**
	 * Llamado cuando se dispara un evento
	 * @return true para cancelar el evento
	 */
	public function onEvent(eventName:String, value1:String, value2:String, time:Float):Bool
	{
		return false;
	}
	
	/**
	 * Llamado después de que se ejecuta un evento
	 */
	public function onEventPost(eventName:String, value1:String, value2:String):Void
	{
	}
	
	// ===========================
	// CAMERA CALLBACKS
	// ===========================
	
	/**
	 * Llamado cuando la cámara se mueve
	 */
	public function onCameraMove(target:String):Void
	{
	}
	
	/**
	 * Permite modificar el zoom de la cámara
	 */
	public function onCameraZoom(zoom:Float):Float
	{
		return zoom;
	}
	
	// ===========================
	// UI CALLBACKS
	// ===========================
	
	/**
	 * Llamado cuando se actualiza el score
	 */
	public function onScoreUpdate(score:Int, misses:Int, accuracy:Float):Void
	{
	}
	
	/**
	 * Llamado cuando se actualiza la salud
	 */
	public function onHealthUpdate(health:Float):Void
	{
	}
	
	// ===========================
	// GAMEPLAY CALLBACKS
	// ===========================
	
	/**
	 * Llamado cuando se pausa el juego
	 */
	public function onPause():Bool
	{
		return false; // true para cancelar la pausa
	}
	
	/**
	 * Llamado cuando se reanuda el juego
	 */
	public function onResume():Void
	{
	}
	
	/**
	 * Llamado cuando hay game over
	 */
	public function onGameOver():Bool
	{
		return false; // true para cancelar el game over
	}
	
	/**
	 * Llamado al reiniciar la canción
	 */
	public function onRestart():Void
	{
	}
	
	// ===========================
	// STAGE CALLBACKS
	// ===========================
	
	/**
	 * Llamado cuando se crea el stage
	 */
	public function onStageCreate():Void
	{
	}
	
	/**
	 * Llamado en el update del stage
	 */
	public function onStageUpdate(elapsed:Float):Void
	{
	}
	
	// ===========================
	// CHARACTER CALLBACKS
	// ===========================
	
	/**
	 * Llamado cuando un personaje canta
	 */
	public function onCharacterSing(character:String, direction:Int):Void
	{
	}
	
	/**
	 * Llamado cuando un personaje baila
	 */
	public function onCharacterDance(character:String):Void
	{
	}
	
	// ===========================
	// UTILITIES
	// ===========================
	
	/**
	 * Helper para acceso rápido a variables del PlayState
	 */
	public function getVar(name:String):Dynamic
	{
		return Reflect.getProperty(playState, name);
	}
	
	/**
	 * Helper para establecer variables del PlayState
	 */
	public function setVar(name:String, value:Dynamic):Void
	{
		Reflect.setProperty(playState, name, value);
	}
	
	/**
	 * Llamado cuando se destruye el script
	 */
	public function onDestroy():Void
	{
		trace('[Module $name] Destroyed');
	}
	
	/**
	 * Log con prefijo del módulo
	 */
	public function log(message:Dynamic):Void
	{
		trace('[$name] $message');
	}
}
