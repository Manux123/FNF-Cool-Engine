package funkin.data;

/**
 * SwagSection MEJORADO - Soporte para múltiples personajes
 */
typedef SwagSection =
{
	var sectionNotes:Array<Dynamic>;
	var lengthInSteps:Int;
	var typeOfSection:Int;
	var mustHitSection:Bool;
	var bpm:Float;
	var changeBPM:Bool;
	var altAnim:Bool;
	
	// === LEGACY ===
	@:optional var gfSing:Bool; // GF canta (legacy)
	@:optional var bothSing:Bool; // Ambos cantan (legacy)
	
	// === NUEVO SISTEMA ===
	@:optional var characterIndex:Int; // Índice del personaje que canta (desde array characters)
	@:optional var strumsGroupId:String; // ID del grupo de strums a usar
	@:optional var activeCharacters:Array<Int>; // Array de índices de personajes activos en esta sección
	
	@:optional var stage:String;
}

class Section
{
	public var sectionNotes:Array<Dynamic> = [];

	public var lengthInSteps:Int = 16;
	public var typeOfSection:Int = 0;
	public var mustHitSection:Bool = true;
	
	// Nuevo
	public var characterIndex:Int = -1; // -1 = usar lógica default (mustHitSection)
	public var strumsGroupId:String = null;
	public var activeCharacters:Array<Int> = null; // null = solo personaje principal

	/**
	 *	Copies the first section into the second section!
	 */
	public static var COPYCAT:Int = 0;

	public function new(lengthInSteps:Int = 16)
	{
		this.lengthInSteps = lengthInSteps;
	}
	
	/**
	 * NUEVO: Obtener personaje que canta según lógica
	 */
	public function getSingingCharacterIndex(defaultDadIndex:Int = 1, defaultBFIndex:Int = 2):Int
	{
		// Si se especificó un personaje manualmente, usar ese
		if (characterIndex >= 0)
			return characterIndex;
		
		// Si no, usar lógica legacy
		if (mustHitSection)
			return defaultBFIndex; // Boyfriend
		else
			return defaultDadIndex; // Dad
	}
	
	/**
	 * NUEVO: Obtener todos los personajes activos en esta sección
	 */
	public function getActiveCharacterIndices(defaultDadIndex:Int = 1, defaultBFIndex:Int = 2):Array<Int>
	{
		// Si se especificaron personajes activos, usar esos
		if (activeCharacters != null && activeCharacters.length > 0)
			return activeCharacters;
		
		// Si no, retornar solo el personaje principal
		return [getSingingCharacterIndex(defaultDadIndex, defaultBFIndex)];
	}
}
