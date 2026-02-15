package funkin.gameplay;

import funkin.gameplay.objects.character.Character;
import funkin.gameplay.objects.character.CharacterSlot;
import flixel.FlxG;
import funkin.data.Conductor;

using StringTools;

/**
 * CharacterController MEJORADO - Control de múltiples personajes
 * Maneja: Arrays de personajes, Singing, Idle, Timers
 */
class CharacterController
{
	// === CHARACTERS (nuevo sistema) ===
	public var characterSlots:Array<CharacterSlot> = [];
	
	// === LEGACY SUPPORT (para compatibilidad) ===
	public var boyfriend:Character;
	public var dad:Character;
	public var gf:Character;
	
	// === FLAGS ===
	public var specialAnim:Bool = false;
	
	// === CONSTANTS ===
	private static inline var SING_DURATION:Float = 0.6;
	private static inline var IDLE_THRESHOLD:Float = 0.001;
	
	// === ANIMATIONS ===
	private var notesAnim:Array<String> = ['LEFT', 'DOWN', 'UP', 'RIGHT'];
	
	// === GF SPEED ===
	private var gfSpeed:Int = 1;
	
	/**
	 * Constructor LEGACY (para compatibilidad con código existente)
	 */
	public function new(?boyfriend:Character, ?dad:Character, ?gf:Character)
	{
		// Guardar referencias legacy
		this.boyfriend = boyfriend;
		this.dad = dad;
		this.gf = gf;
		
		// Si se pasan personajes legacy, crear slots automáticamente
		if (gf != null || dad != null || boyfriend != null)
		{
			initFromLegacyCharacters();
		}
	}
	
	/**
	 * NUEVO: Inicializar desde array de CharacterSlots
	 */
	public function initFromSlots(slots:Array<CharacterSlot>):Void
	{
		characterSlots = slots;
		
		// Auto-asignar personajes legacy para compatibilidad
		// Asumiendo: [0]=GF, [1]=DAD, [2]=BF (orden estándar)
		if (slots.length > 0) gf = slots[0].character;
		if (slots.length > 1) dad = slots[1].character;
		if (slots.length > 2) boyfriend = slots[2].character;
		
		trace('[CharacterController] Inicializado con ${slots.length} character slots');
	}
	
	/**
	 * Crear slots desde personajes legacy
	 */
	private function initFromLegacyCharacters():Void
	{
		characterSlots = [];
		
		// Crear slots básicos (sin CharacterSlotData completo)
		// Esto es solo para compatibilidad, idealmente usar initFromSlots()
		if (gf != null)
		{
			var slot = createSlotFromCharacter(gf, 0);
			characterSlots.push(slot);
		}
		
		if (dad != null)
		{
			var slot = createSlotFromCharacter(dad, 1);
			characterSlots.push(slot);
		}
		
		if (boyfriend != null)
		{
			var slot = createSlotFromCharacter(boyfriend, 2);
			characterSlots.push(slot);
		}
		
		trace('[CharacterController] Inicializado en modo legacy con ${characterSlots.length} personajes');
	}
	
	/**
	 * Helper para crear slot desde Character existente
	 */
	private function createSlotFromCharacter(char:Character, index:Int):CharacterSlot
	{
		var data:funkin.data.Song.CharacterSlotData = {
			name: char.curCharacter,
			x: char.x,
			y: char.y,
			visible: true
		};
		
		var slot = new CharacterSlot(data, index);
		slot.character = char; // Reemplazar el personaje creado con el existente
		return slot;
	}
	
	/**
	 * Update animaciones cada frame
	 */
	public function update(elapsed:Float):Void
	{
		// Update todos los slots
		for (slot in characterSlots)
		{
			if (slot != null && slot.isActive)
				slot.update(elapsed);
		}
		
		// Legacy update - SOLO si no hay slots (para compatibilidad)
		// Si hay slots, ya se manejó arriba, no duplicar
		if (characterSlots.length == 0)
		{
			updateLegacyAnimations(elapsed);
		}
	}
	
	/**
	 * Update legacy (compatibilidad)
	 */
	private function updateLegacyAnimations(elapsed:Float):Void
	{
		// Dad
		if (dad != null && dad.animation != null && dad.animation.curAnim != null)
		{
			var curAnim = dad.animation.curAnim.name;
			if (curAnim.startsWith('sing') && !curAnim.endsWith('miss'))
			{
				if (dad.holdTimer > SING_DURATION && dad.canSing && !specialAnim)
					dad.dance();
			}
		}
		
		// Boyfriend
		if (boyfriend != null && boyfriend.animation != null && boyfriend.animation.curAnim != null)
		{
			var curAnim = boyfriend.animation.curAnim.name;
			if (curAnim.startsWith('sing') && !curAnim.endsWith('miss'))
			{
				var threshold = Conductor.stepCrochet * 4 * IDLE_THRESHOLD;
				if (boyfriend.holdTimer > threshold && boyfriend.canSing && !specialAnim)
				{
					boyfriend.playAnim('idle', true);
					boyfriend.holdTimer = 0;
				}
			}
		}
		
		// GF
		if (gf != null && gf.animation != null && gf.animation.curAnim != null)
		{
			var curAnim = gf.animation.curAnim.name;
			if (curAnim.startsWith('sing'))
			{
				if (gf.holdTimer > SING_DURATION && gf.canSing)
				{
					gf.dance();
					gf.holdTimer = 0;
				}
			}
		}
	}
	
	/**
	 * NUEVO: Hacer cantar a un personaje por índice
	 */
	public function singByIndex(charIndex:Int, noteData:Int, ?altAnim:String = ""):Void
	{
		if (charIndex < 0 || charIndex >= characterSlots.length)
			return;
		
		var slot = characterSlots[charIndex];
		if (slot != null && slot.isActive)
			slot.sing(noteData, altAnim);
	}
	
	/**
	 * NUEVO: Reproducir animación de miss por índice
	 */
	public function missByIndex(charIndex:Int, noteData:Int):Void
	{
		if (charIndex < 0 || charIndex >= characterSlots.length)
			return;
		
		var slot = characterSlots[charIndex];
		if (slot != null && slot.isActive)
			slot.playMiss(noteData);
	}
	
	/**
	 * NUEVO: Hacer cantar a múltiples personajes
	 */
	public function singMultiple(charIndices:Array<Int>, noteData:Int, ?altAnim:String = ""):Void
	{
		for (index in charIndices)
		{
			singByIndex(index, noteData, altAnim);
		}
	}
	
	/**
	 * Hacer cantar a un personaje (legacy)
	 */
	public function sing(char:Character, noteData:Int, ?altAnim:String = ""):Void
	{
		if (char == null || !char.canSing)
			return;
		
		// BF no usa animaciones alternas por defecto
		if (char == boyfriend)
			altAnim = "";
		
		// Construir nombre de animación
		var animName:String = 'sing' + notesAnim[noteData] + altAnim;
		
		// Fallback si no existe la animación alterna
		if (!char.animOffsets.exists(animName) && char.animation.getByName(animName) == null)
		{
			animName = 'sing' + notesAnim[noteData];
		}
		
		// No reiniciar si ya está en esta animación
		if (char.animation.curAnim != null && char.animation.curAnim.name == animName)
			return;
		
		char.playAnim(animName, true);
		char.holdTimer = 0;
	}
	
	/**
	 * Dance en beat
	 */
	public function danceOnBeat(curBeat:Int):Void
	{
		// Dance todos los slots
		for (slot in characterSlots)
		{
			if (slot != null && slot.isActive)
			{
				// GF dance cada gfSpeed beats
				if (slot.index == 0 && curBeat % gfSpeed == 0)
					slot.dance();
				// Otros personajes dance cada beat
				else if (slot.index != 0)
					slot.dance();
			}
		}
		
		// Legacy dance - SOLO si no hay slots (para compatibilidad con código antiguo)
		// Si hay slots, ya se manejó arriba, no duplicar las llamadas
		if (characterSlots.length == 0)
		{
			if (gf != null && curBeat % gfSpeed == 0)
				gf.dance();
			
			if (boyfriend != null && boyfriend.animation != null && boyfriend.animation.curAnim != null)
			{
				if (!boyfriend.animation.curAnim.name.startsWith("sing") && boyfriend.canSing && !specialAnim)
					boyfriend.dance();
			}
			
			if (dad != null && dad.animation != null && dad.animation.curAnim != null)
			{
				if (!dad.animation.curAnim.name.startsWith("sing") && dad.canSing && !specialAnim)
					dad.dance();
			}
		}
	}
	
	/**
	 * Special animations (hey, cheer, etc.)
	 */
	public function playSpecialAnim(char:Character, animName:String):Void
	{
		if (char == null)
			return;
		
		char.playAnim(animName, true);
		specialAnim = true;
	}
	
	/**
	 * NUEVO: Play special anim por índice
	 */
	public function playSpecialAnimByIndex(charIndex:Int, animName:String):Void
	{
		if (charIndex < 0 || charIndex >= characterSlots.length)
			return;
		
		var slot = characterSlots[charIndex];
		if (slot != null && slot.character != null)
		{
			slot.character.playAnim(animName, true);
			specialAnim = true;
		}
	}
	
	/**
	 * Set GF speed
	 */
	public function setGFSpeed(speed:Int):Void
	{
		gfSpeed = speed;
	}
	
	/**
	 * Reset special anim flag
	 */
	public function resetSpecialAnim():Void
	{
		specialAnim = false;
	}
	
	/**
	 * NUEVO: Obtener personaje por índice
	 */
	public function getCharacter(index:Int):Character
	{
		if (index < 0 || index >= characterSlots.length)
			return null;
		
		var slot = characterSlots[index];
		return slot != null ? slot.character : null;
	}
	
	/**
	 * NUEVO: Obtener slot por índice
	 */
	public function getSlot(index:Int):CharacterSlot
	{
		if (index < 0 || index >= characterSlots.length)
			return null;
		
		return characterSlots[index];
	}
	
	/**
	 * NUEVO: Activar/desactivar personaje
	 */
	public function setCharacterActive(index:Int, active:Bool):Void
	{
		if (index < 0 || index >= characterSlots.length)
			return;
		
		var slot = characterSlots[index];
		if (slot != null)
			slot.setActive(active);
	}
	
	/**
	 * Verificar si BF está en idle
	 */
	public function isBFIdle():Bool
	{
		if (boyfriend == null || boyfriend.animation == null || boyfriend.animation.curAnim == null)
			return true;
		
		return !boyfriend.animation.curAnim.name.startsWith("sing");
	}
	
	/**
	 * Forzar idle a todos
	 */
	public function forceIdleAll():Void
	{
		for (slot in characterSlots)
		{
			if (slot != null && slot.character != null)
				slot.character.dance();
		}
		
		// Legacy
		if (boyfriend != null)
			boyfriend.dance();
		if (dad != null)
			dad.dance();
		if (gf != null)
			gf.dance();
		
		specialAnim = false;
	}
	
	/**
	 * NUEVO: Obtener total de personajes
	 */
	public function getCharacterCount():Int
	{
		return characterSlots.length;
	}
	
	/**
	 * Destruir
	 */
	public function destroy():Void
	{
		for (slot in characterSlots)
		{
			if (slot != null)
				slot.destroy();
		}
		characterSlots = [];
		
		boyfriend = null;
		dad = null;
		gf = null;
	}
}