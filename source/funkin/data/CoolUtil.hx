package extensions;

using StringTools;

/**
 * CoolUtil — utilidades generales de uso frecuente.
 *
 * Todos los métodos de carga de archivos buscan en mods primero (via Paths),
 * por lo que los mods pueden sobreescribir archivos de datos como listas de canciones.
 */
class CoolUtil
{
	/** Lista de nombres de dificultad para mostrar en UI. */
	public static var difficultyArray : Array<String> = ['EASY', 'NORMAL', 'HARD'];

	/** Sufijos de dificultad para construir paths de chart. */
	public static var difficultyPath  : Array<String> = ['-easy', '', '-hard'];

	// ─── Dificultad ───────────────────────────────────────────────────────────

	/** Nombre de la dificultad actual en mayúsculas. */
	public static inline function difficultyString():String
		return difficultyArray[funkin.gameplay.PlayState.storyDifficulty];

	// ─── Lectura de archivos ──────────────────────────────────────────────────

	/**
	 * Lee un archivo de texto y devuelve sus líneas sin espacios extra.
	 * Busca en el mod activo primero (vía Paths.getText).
	 */
	public static function coolTextFile(path:String):Array<String>
		return splitTrimmed(Paths.getText(path));

	/**
	 * Divide un string en líneas y elimina espacios extra de cada una.
	 * Versión sin I/O — útil cuando ya tienes el contenido en memoria.
	 */
	public static function coolStringFile(content:String):Array<String>
		return splitTrimmed(content);

	// ─── Arrays ───────────────────────────────────────────────────────────────

	/**
	 * Crea un array de enteros [min, min+1, … max-1].
	 * Equivalente a Python `range(min, max)`.
	 */
	public static function numberArray(max:Int, min:Int = 0):Array<Int>
	{
		final arr = new Array<Int>();
		arr.resize(max - min); // reserva capacidad de una vez
		for (i in 0...(max - min)) arr[i] = min + i;
		return arr;
	}

	// ─── Strings ──────────────────────────────────────────────────────────────

	/** Capitaliza la primera letra de un string. */
	public static inline function capitalize(s:String):String
		return s.length == 0 ? s : s.charAt(0).toUpperCase() + s.substr(1);

	/** Trunca `s` a `maxLen` caracteres, añadiendo '…' si se truncó. */
	public static inline function truncate(s:String, maxLen:Int):String
		return s.length <= maxLen ? s : s.substr(0, maxLen - 1) + '…';

	// ─── Helpers internos ─────────────────────────────────────────────────────

	/** Divide por '\n', hace trim de cada línea y elimina líneas vacías. */
	static function splitTrimmed(raw:String):Array<String>
	{
		final lines = raw.trim().split('\n');
		// trim in-place, sin array intermedio
		var write = 0;
		for (i in 0...lines.length)
		{
			final l = lines[i].trim();
			if (l.length > 0) lines[write++] = l;
		}
		lines.resize(write);
		return lines;
	}
}
