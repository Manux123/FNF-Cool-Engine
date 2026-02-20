package funkin.gameplay.objects.character;

import funkin.gameplay.objects.character.Character;
import funkin.data.Song.CharacterSlotData;

using StringTools;
/**
 * CharacterSlot - Representa un "slot" de personaje en el juego
 * 
 * Cada slot contiene:
 * - Un personaje (Character)
 * - Sus datos de configuración (CharacterSlotData)
 * - Su índice en el array de personajes
 * 
 * Esto permite tener múltiples personajes por lado (ej: 2 dads, 3 bfs)
 */
class CharacterSlot
{
	public var character:Character;
	public var data:CharacterSlotData;
	public var index:Int;
	public var isActive:Bool = true;
	
	// Timers para animaciones
	public var holdTimer:Float = 0;
	public var animFinished:Bool = true;
	
	public function new(charData:CharacterSlotData, index:Int)
	{
		this.data = charData;
		this.index = index;
		
		// Crear personaje
		var charName = charData.name != null ? charData.name : 'bf';
		character = new Character(charData.x, charData.y, charName, false);
		
		// Aplicar configuración
		if (charData.flip != null && charData.flip)
			character.flipX = !character.flipX;
		
		if (charData.scale != null && charData.scale != 1.0)
		{
			character.scale.set(charData.scale, charData.scale);
			character.updateHitbox();
		}
		
		if (charData.visible != null)
			character.visible = charData.visible;
		
		trace('[CharacterSlot] Creado slot $index: ${charData.name} en (${charData.x}, ${charData.y})');
	}
	
	/**
	 * Hacer cantar al personaje
	 */
	public function sing(noteData:Int, ?altAnim:String = ""):Void
	{
		if (!isActive || !character.canSing || character.isPlayingSpecialAnim())
			return;
		
		var notesAnim:Array<String> = ['LEFT', 'DOWN', 'UP', 'RIGHT'];
		var animName:String = 'sing' + notesAnim[noteData] + altAnim;
		
		// Fallback si no existe la animación alterna.
		// NOTA: Para FunkinSprite/FlxAnimate usamos animOffsets como fuente de verdad
		// porque animation.getByName() solo conoce las anims del FlxSprite legacy,
		// no las del sistema FlxAnimate interno.
		if (!character.animOffsets.exists(animName))
		{
			animName = 'sing' + notesAnim[noteData];
		}
		
		character.playAnim(animName, true);

		// CRÍTICO: Resetear el holdTimer DEL PERSONAJE, no el del slot.
		// Character.update() acumula character.holdTimer para saber cuándo volver al idle.
		// Si no lo reseteamos aquí, puede que ya haya superado el umbral y dance() se
		// dispare en el siguiente frame, haciendo que parezca que el personaje no canta.
		character.holdTimer = 0;
		animFinished = false;
	}
	
	/**
	 * Reproducir animación de miss
	 */
	public function playMiss(noteData:Int):Void
	{
		if (!isActive)
			return;
		
		var notesAnim:Array<String> = ['LEFT', 'DOWN', 'UP', 'RIGHT'];
		var animName:String = 'sing' + notesAnim[noteData] + 'miss';
		
		// Solo reproducir si existe la animación (usando animOffsets como fuente de verdad)
		if (character.animOffsets.exists(animName))
		{
			character.playAnim(animName, true);
			character.holdTimer = 0;
			animFinished = false;
		}
	}
	
	/**
	 * Update del personaje.
	 *
	 * IMPORTANTE: NO duplicar lógica de animación aquí.
	 * Character extiende FlxSprite y Flixel llama Character.update() automáticamente
	 * cada frame porque el personaje está add()-eado al FlxState.
	 * Character.update() ya gestiona: holdTimer, sing→idle, special anim→idle, dance.
	 * Ejecutar esa lógica una segunda vez desde aquí causaría el flickering
	 * entre animaciones de canto e idle.
	 */
	public function update(elapsed:Float):Void
	{
		// Reservado para lógica futura específica del slot (no de animación).
	}
	
	/**
	 * Dance en beat.
	 * Delega a character.dance(), que ya guarda internamente:
	 *   - No interrumpe animaciones de canto (sing*)
	 *   - No interrumpe animaciones especiales en curso (isPlayingSpecialAnim)
	 */
	public function dance():Void
	{
		if (!isActive || !character.canSing)
			return;
		
		character.dance();
	}
	
	/**
	 * Activar/desactivar slot
	 */
	public function setActive(active:Bool):Void
	{
		isActive = active;
		character.visible = active && (data.visible != null ? data.visible : true);
	}
	
	/**
	 * Destruir
	 */
	public function destroy():Void
	{
		if (character != null)
		{
			character.destroy();
			character = null;
		}
		data = null;
	}
}
