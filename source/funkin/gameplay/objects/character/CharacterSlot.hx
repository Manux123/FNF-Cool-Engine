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
		if (!isActive || !character.canSing)
			return;
		
		var notesAnim:Array<String> = ['LEFT', 'DOWN', 'UP', 'RIGHT'];
		var animName:String = 'sing' + notesAnim[noteData] + altAnim;
		
		// Fallback si no existe la animación alterna
		if (!character.animOffsets.exists(animName) && character.animation.getByName(animName) == null)
		{
			animName = 'sing' + notesAnim[noteData];
		}
		
		// No reiniciar si ya está en esta animación
		if (character.animation.curAnim != null && character.animation.curAnim.name == animName)
			return;
		
		character.playAnim(animName, true);
		holdTimer = 0;
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
		
		// Solo reproducir si existe la animación
		if (character.animOffsets.exists(animName) || character.animation.getByName(animName) != null)
		{
			character.playAnim(animName, true);
			holdTimer = 0;
			animFinished = false;
		}
	}
	
	/**
	 * Update del personaje
	 */
	public function update(elapsed:Float):Void
	{
		if (!isActive)
			return;
		
		holdTimer += elapsed;
		
		// Auto-idle después de cantar
		// NOTA: BF maneja su propio timing en Character.update(), así que lo saltamos aquí
		if (character.animation.curAnim != null && !character.curCharacter.startsWith('bf'))
		{
			var curAnim = character.animation.curAnim.name;
			
			if (curAnim.startsWith('sing') && !curAnim.endsWith('miss'))
			{
				if (holdTimer > 0.6 && character.canSing)
				{
					animFinished = true;
					character.dance();
				}
			}
		}
	}
	
	/**
	 * Dance en beat
	 */
	public function dance():Void
	{
		if (!isActive || !character.canSing)
			return;
		
		// Permitir dance si no está cantando o en animación especial
		if (character.animation.curAnim != null)
		{
			var curAnimName = character.animation.curAnim.name;
			// Bloqueamos solo si está cantando (sing) o en animación especial (hair, etc)
			// Para personajes con danceLeft/danceRight (GF, Spooky), SIEMPRE permitir dance en beat
			if (!curAnimName.startsWith('sing'))
			{
				// Si está en animación especial (hair), solo dance si terminó
				if (curAnimName.startsWith('hair'))
				{
					if (character.animation.curAnim.finished)
					{
						character.dance();
						holdTimer = 0;
					}
				}
				else
				{
					// Para danceLeft/danceRight o idle, siempre permitir dance en beat
					character.dance();
					holdTimer = 0;
				}
			}
		}
		else
		{
			// No hay animación actual, forzar dance
			character.dance();
			holdTimer = 0;
		}
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
