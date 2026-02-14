package funkin.gameplay;

import flixel.FlxG;

/**
 * GameState - Gestión centralizada del estado del juego
 * Maneja: Score, Health, Combo, Accuracy, Stats
 */
class GameState
{
	// === SINGLETON ===
	private static var _instance:GameState;
	
	public static function get():GameState
	{
		if (_instance == null)
			_instance = new GameState();
		return _instance;
	}
	
	// === STATS ===
	public var score:Int = 0;
	public var combo:Int = 0;
	public var health:Float = 1.0;
	public var accuracy:Float = 0.00;
	
	// === COUNTERS ===
	public var sicks:Int = 0;
	public var goods:Int = 0;
	public var bads:Int = 0;
	public var shits:Int = 0;
	public var misses:Int = 0;
	
	// === INTERNAL ===
	private var totalNotesHit:Float = 0;
	private var totalNotesPlayed:Int = 0;
	
	// === CONSTANTS ===
	private static inline var MAX_HEALTH:Float = 2.0;
	private static inline var MIN_HEALTH:Float = 0.0;

	public static var listAuthor:String = 'KawaiSprite';

	public static var deathCounter:Int = 0;
	
	public function new() 
	{
		reset();
	}
	
	/**
	 * Resetear todo el estado
	 */
	public function reset():Void
	{
		score = 0;
		combo = 0;
		health = 1.0;
		accuracy = 0.0;
		sicks = 0;
		goods = 0;
		bads = 0;
		shits = 0;
		misses = 0;
		totalNotesHit = 0;
		totalNotesPlayed = 0;
	}
	
	/**
	 * Procesar hit de nota
	 */
	public function processNoteHit(noteDiff:Float, isSustain:Bool):String
	{
		if (isSustain)
		{
			totalNotesHit += 1.0;
			totalNotesPlayed++;
			updateAccuracy();
			//thanks juanen
			updateScore('shit');
			return "sick";	
		}
		
		var rating:String = getRating(noteDiff);
		
		// Actualizar counters
		switch (rating)
		{
			case 'sick':
				sicks++;
				totalNotesHit += 1.0;
				combo++;
			case 'good':
				goods++;
				totalNotesHit += 0.75;
				combo++;
			case 'bad':
				bads++;
				totalNotesHit += 0.5;
				combo++;
			case 'shit':
				shits++;
				totalNotesHit += 0.25;
				combo = 0;
		}
		
		totalNotesPlayed++;
		updateAccuracy();
		updateScore(rating);
		
		return rating;
	}
	
	/**
	 * Procesar miss
	 */
	public function processMiss():Void
	{
		misses++;
		combo = 0;
		totalNotesPlayed++;
		updateAccuracy();
	}
	
	/**
	 * Obtener rating según diferencia de tiempo
	 */
	private function getRating(noteDiff:Float):String
	{
		if (noteDiff <= 45)
			return 'sick';
		else if (noteDiff <= 90)
			return 'good';
		else if (noteDiff <= 135)
			return 'bad';
		else
			return 'shit';
	}
	
	/**
	 * Actualizar accuracy
	 */
	private function updateAccuracy():Void
	{
		if (totalNotesPlayed > 0)
			accuracy = (totalNotesHit / totalNotesPlayed) * 100;
		else
			accuracy = 0;

		accuracy = Math.fround(accuracy * 100) / 100;
	}
	
	/**
	 * Actualizar score
	 */
	private function updateScore(rating:String):Void
	{
		switch (rating)
		{
			case 'sick':
				score += 350;
			case 'good':
				score += 200;
			case 'bad':
				score += 100;
			case 'shit':
				score += 50;
		}
	}
	
	/**
	 * Modificar health (con límites)
	 */
	public function modifyHealth(amount:Float):Void
	{
		health += amount;
		health = Math.max(MIN_HEALTH, Math.min(MAX_HEALTH, health));
	}
	
	/**
	 * Verificar si está muerto
	 */
	public function isDead():Bool
	{
		return health <= MIN_HEALTH;
	}
	
	/**
	 * Obtener porcentaje de accuracy formateado
	 */
	public function getAccuracyString():String
	{
		return Std.string(Math.floor(accuracy * 100) / 100) + '%';
	}
	
	/**
	 * Verificar si es Full Combo
	 */
	public function isFullCombo():Bool
	{
		return misses == 0 && bads == 0 && shits == 0;
	}
	
	/**
	 * Verificar si es Sick Mode (solo sicks)
	 */
	public function isSickMode():Bool
	{
		return goods == 0 && bads == 0 && shits == 0 && misses == 0;
	}
	
	/**
	 * Destruir singleton
	 */
	public static function destroy():Void
	{
		if (_instance != null)
		{
			_instance = null;
		}
	}
}
