package funkin.scripting;

import funkin.gameplay.PlayState;
import funkin.gameplay.notes.Note;

/**
 * Plantilla base para scripts de gameplay (canción, stage).
 *
 * Extiende esta clase en tus scripts HScript para obtener autocompletado
 * y documentación de todos los callbacks disponibles.
 *
 * ─── Ejemplo de uso ──────────────────────────────────────────────────────────
 *
 *   class MiScript extends ModuleScript {
 *     override function onCreate() {
 *       name = 'MiScript';
 *       trace('Listo!');
 *     }
 *     override function onBeatHit(beat) {
 *       if (beat % 2 == 0) game.boyfriend.playAnim('hey');
 *     }
 *   }
 *
 * ─── Callbacks disponibles ───────────────────────────────────────────────────
 *   Lifecycle      onCreate, postCreate, onUpdate, onUpdatePost, onDestroy
 *   Canción        onCountdownStarted, onCountdownTick, onSongStart, onSongEnd
 *   Ritmo          onBeatHit, onStepHit, onSectionHit
 *   Notas          onNoteSpawn, onPlayerNoteHit, onPlayerNoteHitPost,
 *                  onPlayerNoteMiss, onPlayerNoteMissPost, onOpponentNoteHit
 *   Eventos        onEvent (return true = cancelar), onEventPost
 *   Cámara         onCameraMove, onCameraZoom (return nuevo zoom)
 *   UI             onScoreUpdate, onHealthUpdate
 *   Gameplay       onPause (true=cancelar), onResume, onGameOver (true=cancelar), onRestart
 *   Stage          onStageCreate, onStageUpdate
 *   Personajes     onCharacterSing, onCharacterDance
 */
class ModuleScript
{
	// ─── Metadata ─────────────────────────────────────────────────────────────
	public var name        : String = 'Module';
	public var description : String = '';
	public var author      : String = '';
	public var version     : String = '1.0.0';
	public var active      : Bool   = true;

	/** Referencia al PlayState. Asignada automáticamente al cargar. */
	public var playState   : PlayState;

	public function new()
		playState = PlayState.instance;

	// ─── Lifecycle ────────────────────────────────────────────────────────────

	/** Llamado al cargar el script. Ideal para inicializar variables. */
	public function onCreate():Void {}

	/** Llamado después del `create()` del PlayState. */
	public function postCreate():Void {}

	/** Llamado cada frame. */
	public function onUpdate(elapsed:Float):Void {}

	/** Llamado después del `update()` del PlayState. */
	public function onUpdatePost(elapsed:Float):Void {}

	/** Llamado al destruir el script. */
	public function onDestroy():Void {}

	// ─── Canción ──────────────────────────────────────────────────────────────

	public function onCountdownStarted():Void {}
	public function onCountdownTick(tick:Int):Void {}
	public function onSongStart():Void {}
	public function onSongEnd():Void {}

	// ─── Ritmo ────────────────────────────────────────────────────────────────

	public function onBeatHit(beat:Int):Void {}
	public function onStepHit(step:Int):Void {}
	public function onSectionHit(section:Int):Void {}

	// ─── Notas ────────────────────────────────────────────────────────────────

	public function onNoteSpawn(note:Note):Void {}

	/** @return true para cancelar el comportamiento por defecto. */
	public function onPlayerNoteHit(note:Note, rating:String):Bool   return false;
	public function onPlayerNoteHitPost(note:Note, rating:String):Void {}

	/** @return true para cancelar el comportamiento por defecto. */
	public function onPlayerNoteMiss(note:Note):Bool                  return false;
	public function onPlayerNoteMissPost(note:Note):Void {}

	public function onOpponentNoteHit(note:Note):Void {}

	// ─── Eventos ──────────────────────────────────────────────────────────────

	/** @return true para cancelar el evento. */
	public function onEvent(name:String, value1:String, value2:String, time:Float):Bool return false;
	public function onEventPost(name:String, value1:String, value2:String):Void {}

	// ─── Cámara ───────────────────────────────────────────────────────────────

	public function onCameraMove(target:String):Void {}

	/** @return El zoom final a aplicar (modifícalo para personalizar). */
	public function onCameraZoom(zoom:Float):Float return zoom;

	// ─── UI ───────────────────────────────────────────────────────────────────

	public function onScoreUpdate(score:Int, misses:Int, accuracy:Float):Void {}
	public function onHealthUpdate(health:Float):Void {}

	// ─── Gameplay ─────────────────────────────────────────────────────────────

	/** @return true para cancelar la pausa. */
	public function onPause():Bool    return false;
	public function onResume():Void {}

	/** @return true para cancelar el game over. */
	public function onGameOver():Bool return false;
	public function onRestart():Void {}

	// ─── Stage ────────────────────────────────────────────────────────────────

	public function onStageCreate():Void {}
	public function onStageUpdate(elapsed:Float):Void {}

	// ─── Personajes ───────────────────────────────────────────────────────────

	public function onCharacterSing(character:String, direction:Int):Void {}
	public function onCharacterDance(character:String):Void {}

	// ─── Utilidades ───────────────────────────────────────────────────────────

	/** Lee una propiedad del PlayState por nombre. */
	public inline function getVar(name:String):Dynamic
		return Reflect.getProperty(playState, name);

	/** Establece una propiedad del PlayState por nombre. */
	public inline function setVar(name:String, value:Dynamic):Void
		Reflect.setProperty(playState, name, value);

	/** Log con prefijo del módulo. */
	public inline function log(msg:Dynamic):Void
		trace('[$name] $msg');
}
