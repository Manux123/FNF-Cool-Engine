package funkin.data;

import funkin.data.Song.SwagSong;

/**
 * Conductor — gestión de BPM, tiempo y sincronía musical.
 */
class Conductor
{
	public static var bpm         : Float = 100;
	/** Duración de un beat en ms  (60 000 / bpm). */
	public static var crochet     : Float = 600;
	/** Duración de un step en ms  (crochet / 4). */
	public static var stepCrochet : Float = 150;

	public static var songPosition : Float = 0;
	public static var lastSongPos  : Float = 0;
	public static var offset       : Float = 0;

	public static var safeFrames : Int = 10;

	/** Margen en ms — propiedad calculada, sin inicializador estático problemático. */
	public static var safeZoneOffset(get, never) : Float;
	static inline function get_safeZoneOffset():Float return (safeFrames / 60.0) * 1000.0;

	/** Factor de escala del safe zone. */
	public static var timeScale(get, never) : Float;
	static inline function get_timeScale():Float return safeZoneOffset / 166.0;

	public static var bpmChangeMap : Array<BPMChangeEvent> = [];

	// ─── API ──────────────────────────────────────────────────────────────────

	/** Cambia BPM y recalcula crochet/stepCrochet en un solo lugar. */
	public static function changeBPM(newBpm:Float):Void
	{
		bpm          = newBpm;
		crochet      = 60000.0 / bpm;
		stepCrochet  = crochet * 0.25;
	}

	/** Construye el mapa de cambios de BPM desde los datos de la canción. */
	public static function mapBPMChanges(song:SwagSong):Void
	{
		bpmChangeMap = [];
		var curBPM    : Float = song.bpm;
		var totalSteps: Int   = 0;
		var totalPos  : Float = 0;

		for (section in song.notes)
		{
			if (section.changeBPM && section.bpm != curBPM)
			{
				curBPM = section.bpm;
				bpmChangeMap.push({ stepTime: totalSteps, songTime: totalPos, bpm: curBPM });
			}
			final delta = section.lengthInSteps;
			totalSteps += delta;
			totalPos   += (60000.0 / curBPM / 4.0) * delta;
		}
		trace('[Conductor] ${bpmChangeMap.length} cambios de BPM.');
	}

	/** Convierte ms a steps, respetando cambios de BPM. */
	public static function getStepAtTime(time:Float):Float
	{
		var step    : Float = 0;
		var lastBpm : Float = bpm;
		var lastTime: Float = 0;

		for (change in bpmChangeMap)
		{
			if (time < change.songTime) break;
			step    += (change.songTime - lastTime) / (60000.0 / lastBpm / 4.0);
			lastBpm  = change.bpm;
			lastTime = change.songTime;
		}
		step += (time - lastTime) / (60000.0 / lastBpm / 4.0);
		return step;
	}
}

typedef BPMChangeEvent =
{
	var stepTime : Int;
	var songTime : Float;
	var bpm      : Float;
}
