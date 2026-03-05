package funkin.gameplay.objects.hud;

import flixel.FlxG;

class Highscore
{
	#if (haxe >= "4.0.0")
	public static var songScores:Map<String, Int>   = new Map();
	public static var songRating:Map<String, Float> = new Map();
	#else
	public static var songScores:Map<String, Int>   = new Map<String, Int>();
	public static var songRating:Map<String, Float> = new Map<String, Float>();
	#end

	// ─── Guardado ────────────────────────────────────────────────────────────

	/**
	 * Guarda el score de una canción.
	 * @param song    Nombre de la canción (sin sufijo de dificultad).
	 * @param score   Puntuación obtenida.
	 * @param suffix  Sufijo de dificultad (ej: "-erect", "-hard", "").
	 *                Usar CoolUtil.difficultySuffix() desde PlayState.
	 */
	public static function saveScore(song:String, score:Int = 0, suffix:String = ''):Void
	{
		final key = formatSongBySuffix(song, suffix);
		if (!songScores.exists(key) || songScores.get(key) < score)
			_setScore(key, score);
	}

	/**
	 * Guarda el rating (accuracy) de una canción.
	 * @param song    Nombre de la canción.
	 * @param rating  Accuracy (0.0 - 1.0).
	 * @param suffix  Sufijo de dificultad.
	 */
	public static function saveRating(song:String, rating:Float = 0, suffix:String = ''):Void
	{
		final key = formatSongBySuffix(song, suffix);
		if (!songRating.exists(key) || songRating.get(key) < rating)
			_setRating(key, rating);
	}

	public static function saveWeekScore(week:Int = 1, score:Int = 0, suffix:String = ''):Void
	{
		final key = formatSongBySuffix('week$week', suffix);
		if (!songScores.exists(key) || songScores.get(key) < score)
			_setScore(key, score);
	}

	// ─── Lectura ─────────────────────────────────────────────────────────────

	public static function getScore(song:String, suffix:String = ''):Int
	{
		final key = formatSongBySuffix(song, suffix);
		if (!songScores.exists(key)) return 0;
		return songScores.get(key);
	}

	public static function getRating(song:String, suffix:String = ''):Float
	{
		final key = formatSongBySuffix(song, suffix);
		if (!songRating.exists(key)) return 0.0;
		return songRating.get(key);
	}

	public static function getWeekScore(week:Int, suffix:String = ''):Int
	{
		final key = formatSongBySuffix('week$week', suffix);
		if (!songScores.exists(key)) return 0;
		return songScores.get(key);
	}

	// ─── Formato de clave ─────────────────────────────────────────────────────

	/**
	 * Clave de score estable: song + sufijo de dificultad.
	 * El sufijo ya viene resuelto (ej: "-erect"), no un índice.
	 */
	public static function formatSongBySuffix(song:String, suffix:String):String
		return song.toLowerCase() + suffix;

	/**
	 * Compatibilidad con código antiguo que pasa un índice Int.
	 * Resuelve el sufijo usando FreeplayState.difficultyStuff.
	 *
	 * ADVERTENCIA: puede devolver un sufijo incorrecto si difficultyStuff
	 * no está actualizado para la canción en cuestión.
	 * Preferir formatSongBySuffix() siempre que sea posible.
	 */
	@:deprecated("Usa formatSongBySuffix(song, CoolUtil.difficultySuffix()) en su lugar")
	public static function formatSong(song:String, diff:Int):String
	{
		final suffix = _suffixFromIndex(diff);
		return formatSongBySuffix(song, suffix);
	}

	// ─── Persistencia ────────────────────────────────────────────────────────

	public static function load():Void
	{
		if (FlxG.save.data.songScores != null)
			songScores = FlxG.save.data.songScores;
		// FIX: songRating no se cargaba → rating siempre 0 al relanzar
		if (FlxG.save.data.songRating != null)
			songRating = FlxG.save.data.songRating;
	}

	// ─── Internos ────────────────────────────────────────────────────────────

	static function _setScore(key:String, score:Int):Void
	{
		songScores.set(key, score);
		FlxG.save.data.songScores = songScores;
		FlxG.save.flush();
	}

	static function _setRating(key:String, rating:Float):Void
	{
		songRating.set(key, rating);
		FlxG.save.data.songRating = songRating;
		FlxG.save.flush();
	}

	/** Resuelve el sufijo de dificultad por índice en difficultyStuff. */
	static function _suffixFromIndex(diff:Int):String
	{
		final diffs = funkin.menus.FreeplayState.difficultyStuff;
		if (diff >= 0 && diff < diffs.length)
			return diffs[diff][1];
		// Fallback clásico para índices fuera de rango
		if (diff == 0) return '-easy';
		if (diff == 2) return '-hard';
		return '';
	}
}
