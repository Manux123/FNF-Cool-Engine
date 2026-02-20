package funkin.gameplay.objects.hud;

import flixel.FlxG;
import flixel.text.FlxText;
import flixel.util.FlxColor;

@:keep
/**
 * Gestor de puntuación y estadísticas
 * Maneja todo lo relacionado con scoring, accuracy y rankings
 */
class ScoreManager
{
	// Estadísticas de jugabilidad
	public var score:Int = 0;
	public var combo:Int = 0;
	public var maxCombo:Int = 0;
	public var misses:Int = 0;
	
	// Contadores de rating
	public var sicks:Int = 0;
	public var goods:Int = 0;
	public var bads:Int = 0;
	public var shits:Int = 0;
	
	// Accuracy
	public var accuracy:Float = 0;
	public var totalNotesHit:Float = 0;
	public var totalNotesPlayed:Int = 0;
	
	// Flags de estado
	public var fullCombo:Bool = true;
	public var sickCombo:Bool = true; // Solo sicks
	
	// Configuración de scoring
	public static inline var SICK_SCORE:Int = 350;
	public static inline var GOOD_SCORE:Int = 200;
	public static inline var BAD_SCORE:Int = 100;
	public static inline var SHIT_SCORE:Int = 50;
	public static inline var MISS_PENALTY:Int = -10;
	
	// Timing windows (en ms)
	public static inline var SICK_WINDOW:Float = 45;
	public static inline var GOOD_WINDOW:Float = 90;
	public static inline var BAD_WINDOW:Float = 135;
	public static inline var SHIT_WINDOW:Float = 166;
	
	// Multiplicadores de combo
	private static inline var COMBO_MULTIPLIER_1:Float = 1.0;
	private static inline var COMBO_MULTIPLIER_2:Float = 1.1; // 10 combo
	private static inline var COMBO_MULTIPLIER_3:Float = 1.2; // 25 combo
	private static inline var COMBO_MULTIPLIER_4:Float = 1.3; // 50 combo
	
	public function new()
	{
		reset();
	}
	
	/**
	 * Reinicia todas las estadísticas
	 */
	public function reset():Void
	{
		score = 0;
		combo = 0;
		maxCombo = 0;
		misses = 0;
		
		sicks = 0;
		goods = 0;
		bads = 0;
		shits = 0;
		
		accuracy = 0;
		totalNotesHit = 0;
		totalNotesPlayed = 0;
		
		fullCombo = true;
		sickCombo = true;
	}
	
	/**
	 * Procesa un hit de nota
	 * @param noteDiff Diferencia de tiempo en ms (absolute value)
	 * @return Rating conseguido ('sick', 'good', 'bad', 'shit')
	 */
	public function processNoteHit(noteDiff:Float):String
	{
		var rating:String = getRating(noteDiff);
		var ratingScore:Int = 0;
		
		// Incrementar contador de rating
		switch (rating)
		{
			case 'sick':
				sicks++;
				ratingScore = SICK_SCORE;
				totalNotesHit += 1;
			case 'good':
				goods++;
				ratingScore = GOOD_SCORE;
				totalNotesHit += 0.75;
				sickCombo = false;
			case 'bad':
				bads++;
				ratingScore = BAD_SCORE;
				totalNotesHit += 0.5;
				sickCombo = false;
			case 'shit':
				shits++;
				ratingScore = SHIT_SCORE;
				totalNotesHit += 0.25;
				sickCombo = false;
		}
		
		// Incrementar combo
		combo++;
		if (combo > maxCombo)
			maxCombo = combo;
		
		// Aplicar multiplicador de combo
		var comboMultiplier = getComboMultiplier();
		score += Std.int(ratingScore * comboMultiplier);
		
		totalNotesPlayed++;
		updateAccuracy();
		
		return rating;
	}
	
	/**
	 * Procesa un miss
	 */
	public function processMiss():Void
	{
		misses++;
		combo = 0;
		fullCombo = false;
		sickCombo = false;
		
		score += MISS_PENALTY;
		if (score < 0) score = 0;
		
		totalNotesPlayed++;
		updateAccuracy();
	}
	
	/**
	 * Determina el rating basado en la diferencia de tiempo
	 */
	private function getRating(noteDiff:Float):String
	{
		if (noteDiff <= SICK_WINDOW)
			return 'sick';
		else if (noteDiff <= GOOD_WINDOW)
			return 'good';
		else if (noteDiff <= BAD_WINDOW)
			return 'bad';
		else
			return 'shit';
	}
	
	/**
	 * Calcula el multiplicador de combo actual
	 */
	private function getComboMultiplier():Float
	{
		if (combo >= 50)
			return COMBO_MULTIPLIER_4;
		else if (combo >= 25)
			return COMBO_MULTIPLIER_3;
		else if (combo >= 10)
			return COMBO_MULTIPLIER_2;
		else
			return COMBO_MULTIPLIER_1;
	}
	
	/**
	 * Actualiza el cálculo de accuracy
	 */
	private function updateAccuracy():Void
	{
		if (totalNotesPlayed == 0)
		{
			accuracy = 0;
			return;
		}
		
		accuracy = (totalNotesHit / totalNotesPlayed) * 100;
		
		// Limitar a 2 decimales
		accuracy = Math.fround(accuracy * 100) / 100;
	}
	
	/**
	 * Obtiene el ranking final (S, A, B, C, D, F)
	 */
	public function getRank():String
	{
		if (sickCombo && fullCombo)
			return 'S+'; // Perfect
		else if (fullCombo && accuracy >= 95)
			return 'S';
		else if (accuracy >= 90)
			return 'A';
		else if (accuracy >= 80)
			return 'B';
		else if (accuracy >= 70)
			return 'C';
		else if (accuracy >= 60)
			return 'D';
		else
			return 'F';
	}
	
	/**
	 * Genera texto de estadísticas para mostrar
	 */
	public function getStatsText():String
	{
		var stats = 'Score: $score\n';
		stats += 'Accuracy: ${accuracy}%\n';
		stats += 'Combo: $combo (Max: $maxCombo)\n';
		stats += 'Sicks: $sicks | Goods: $goods\n';
		stats += 'Bads: $bads | Shits: $shits | Misses: $misses\n';
		stats += 'Rank: ${getRank()}';
		
		return stats;
	}
	
	/**
	 * Genera texto compacto para HUD
	 */
	public function getHUDText(gameState:funkin.gameplay.GameState):String
	{
		var fcText = fullCombo ? ' [FC]' : '';
		var scText = sickCombo ? ' [SC]' : '';
		
		return ' Score: \n ${gameState.score}\n\n Accuracy: \n ${gameState.accuracy}%\n\n Misses:\n ${gameState.misses}$fcText$scText';
	}
	
	/**
	 * Calcula el color del texto de accuracy
	 */
	public function getAccuracyColor():FlxColor
	{
		if (accuracy >= 95)
			return FlxColor.CYAN;
		else if (accuracy >= 90)
			return FlxColor.LIME;
		else if (accuracy >= 80)
			return FlxColor.YELLOW;
		else if (accuracy >= 70)
			return FlxColor.ORANGE;
		else
			return FlxColor.RED;
	}
	
	/**
	 * Guarda el highscore
	 */
	public function saveHighscore(songName:String, difficulty:Int):Void
	{
		var key = 'highscore_${songName}_$difficulty';
		var currentHigh = FlxG.save.data.get(key);
		
		if (currentHigh == null || score > currentHigh)
		{
			FlxG.save.data.set(key, score);
			FlxG.save.flush();
		}
	}
	
	/**
	 * Obtiene el highscore guardado
	 */
	public function getHighscore(songName:String, difficulty:Int):Int
	{
		var key = 'highscore_${songName}_$difficulty';
		var highscore = FlxG.save.data.get(key);
		
		return (highscore != null) ? highscore : 0;
	}
}
