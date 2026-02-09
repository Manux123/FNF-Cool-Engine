package funkin.gameplay;

import funkin.gameplay.objects.character.Character;
import flixel.FlxG;
import funkin.data.Conductor;

using StringTools;

/**
 * CharacterController - Control optimizado de animaciones
 * Maneja: Singing, Idle, Timers, Special animations
 */
class CharacterController
{
	// === CHARACTERS ===
	public var boyfriend:Character;
	public var dad:Character;
	public var gf:Character;
	
	// === TIMERS ===
	private var dadHoldTimer:Float = 0;
	private var bfHoldTimer:Float = 0;
	private var gfHoldTimer:Float = 0;
	
	// === FLAGS ===
	private var dadAnimFinished:Bool = true;
	private var bfAnimFinished:Bool = true;
	private var gfAnimFinished:Bool = true;
	public var specialAnim:Bool = false;
	
	// === CONSTANTS ===
	private static inline var SING_DURATION:Float = 0.6;
	private static inline var IDLE_THRESHOLD:Float = 0.001;
	
	// === ANIMATIONS ===
	private var notesAnim:Array<String> = ['LEFT', 'DOWN', 'UP', 'RIGHT'];
	
	// === GF SPEED ===
	private var gfSpeed:Int = 1;
	
	public function new(boyfriend:Character, dad:Character, gf:Character)
	{
		this.boyfriend = boyfriend;
		this.dad = dad;
		this.gf = gf;
	}
	
	/**
	 * Update animaciones cada frame
	 */
	public function update(elapsed:Float):Void
	{
		// Actualizar timers
		dadHoldTimer += elapsed;
		bfHoldTimer += elapsed;
		gfHoldTimer += elapsed;
		
		// Update cada personaje
		updateDadAnimations(elapsed);
		updateBoyfriendAnimations(elapsed);
		updateGFAnimations(elapsed);
	}
	
	/**
	 * Update animaciones de Dad
	 */
	private function updateDadAnimations(elapsed:Float):Void
	{
		if (dad == null || dad.animation == null || dad.animation.curAnim == null)
			return;
		
		var curAnim = dad.animation.curAnim.name;
		
		// Si está cantando y el timer expiró, volver a idle
		if (curAnim.startsWith('sing') && !curAnim.endsWith('miss'))
		{
			if (dadHoldTimer > SING_DURATION && dad.canSing)
			{
				dadAnimFinished = true;
				if (!specialAnim)
					dad.dance();
			}
		}
		
		// Idle automático si no está cantando
		if (!curAnim.startsWith('sing') && dad.canSing && dadAnimFinished && !specialAnim)
		{
			dadAnimFinished = true;
		}
	}
	
	/**
	 * Update animaciones de Boyfriend
	 */
	private function updateBoyfriendAnimations(elapsed:Float):Void
	{
		if (boyfriend == null || boyfriend.animation == null || boyfriend.animation.curAnim == null)
			return;
		
		var curAnim = boyfriend.animation.curAnim.name;
		
		// Si está cantando y el timer expiró, volver a idle
		if (curAnim.startsWith('sing') && !curAnim.endsWith('miss') || curAnim.startsWith('hey'))
		{
			var threshold = Conductor.stepCrochet * 4 * IDLE_THRESHOLD;
			if (bfHoldTimer > threshold && boyfriend.canSing)
			{
				bfAnimFinished = true;
				if (!specialAnim)
				{
					boyfriend.playAnim('idle', true);
					boyfriend.holdTimer = 0;
				}
			}
		}
		
		// Reset cuando está idle
		if (curAnim.startsWith('idle'))
		{
			bfAnimFinished = true;
		}
	}
	
	/**
	 * Update animaciones de GF
	 */
	private function updateGFAnimations(elapsed:Float):Void
	{
		if (gf == null || gf.animation == null || gf.animation.curAnim == null)
			return;
		
		var curAnim = gf.animation.curAnim.name;
		
		if (curAnim.startsWith('sing'))
		{
			if (gfHoldTimer > SING_DURATION && gf.canSing)
			{
				gf.dance();
				gfHoldTimer = 0;
				gfAnimFinished = true;
			}
		}
		else
		{
			gfHoldTimer = 0;
		}
	}
	
	/**
	 * Hacer cantar a un personaje
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
		
		// Reset timers
		if (char == dad)
			dadHoldTimer = 0;
		else if (char == boyfriend)
			bfHoldTimer = 0;
		else if (char == gf)
			gfHoldTimer = 0;
	}
	
	/**
	 * Dance en beat
	 */
	public function danceOnBeat(curBeat:Int):Void
	{
		// GF dance
		if (gf != null && curBeat % gfSpeed == 0 && gfAnimFinished)
		{
			gf.dance();
			gfHoldTimer = 0;
		}
		
		// BF idle
		if (boyfriend != null && boyfriend.animation != null && boyfriend.animation.curAnim != null)
		{
			if (!boyfriend.animation.curAnim.name.startsWith("sing") && boyfriend.canSing && bfAnimFinished)
			{
				boyfriend.dance();
				bfHoldTimer = 0;
				specialAnim = false;
			}
		}
		
		// Dad idle
		if (dad != null && dad.animation != null && dad.animation.curAnim != null)
		{
			if (!dad.animation.curAnim.name.startsWith("sing") && dad.canSing && dadAnimFinished)
			{
				dad.dance();
				dadHoldTimer = 0;
				specialAnim = false;
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
		if (boyfriend != null)
			boyfriend.dance();
		if (dad != null)
			dad.dance();
		if (gf != null)
			gf.dance();
		
		specialAnim = false;
	}
}