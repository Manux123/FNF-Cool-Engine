package funkin.gameplay;

import flixel.FlxG;
import flixel.FlxCamera;
import flixel.FlxObject;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.FlxCamera.FlxCameraFollowStyle;
import funkin.gameplay.objects.character.Character;

using StringTools;

/**
 * CameraController — Control de cámara basado en eventos.
 * 
 * La cámara sigue al personaje definido por `currentTarget`,
 * que se cambia EXCLUSIVAMENTE a través del evento "Camera Follow"
 * del EventManager. No hay ninguna lógica de mustHitSection aquí.
 */
class CameraController
{
	// === CAMERAS ===
	public var camGame:FlxCamera;
	public var camHUD:FlxCamera;

	// === FOLLOW OBJECT ===
	// Expuesto para que EventManager pueda leerlo si hace falta.
	public var camFollow:FlxObject;
	private var camPos:FlxPoint;

	// === CHARACTERS ===
	// Se guardan las referencias para poder resolver el target por nombre.
	private var boyfriend:Character;
	private var dad:Character;
	private var gf:Character;

	// === TARGET ACTUAL ===
	// "player" | "opponent" | "gf"
	// Cambiar con setTarget() desde EventManager.
	public var currentTarget:String = 'opponent';

	// === LERP SPEED del follow ===
	// Puede sobreescribirse por evento (Camera Follow, value2).
	public var followLerp:Float = 0.04;

	// === ZOOM ===
	public var defaultZoom:Float = 1.05;
	public var zoomEnabled:Bool  = false;
	private var zoomTween:FlxTween;

	// === NOTE MOVEMENT OFFSETS ===
	public var dadOffsetX:Int = 0;
	public var dadOffsetY:Int = 0;
	public var bfOffsetX:Int  = 0;
	public var bfOffsetY:Int  = 0;

	// === CONFIG ===
	private static inline var LERP_SPEED:Float       = 2.4;
	private static inline var NOTE_OFFSET_AMOUNT:Float = 30.0;

	// ─────────────────────────────────────────────────────────────

	public function new(camGame:FlxCamera, camHUD:FlxCamera,
		boyfriend:Character, dad:Character, ?gf:Character)
	{
		this.camGame    = camGame;
		this.camHUD     = camHUD;
		this.boyfriend  = boyfriend;
		this.dad        = dad;
		this.gf         = gf;

		camFollow = new FlxObject(0, 0, 1, 1);
		camPos    = new FlxPoint();

		// Iniciar la cámara siguiendo el objeto de follow con lerp suave.
		camGame.follow(camFollow, FlxCameraFollowStyle.LOCKON, followLerp);
		camGame.zoom = defaultZoom;

		// Posición inicial: sobre el oponente (target por defecto).
		_snapToTarget();
	}

	// ─────────────────────────────────────────────────────────────
	//  API PÚBLICA
	// ─────────────────────────────────────────────────────────────

	/**
	 * Cambiar el personaje al que sigue la cámara.
	 * Llamar desde EventManager al procesar el evento "Camera Follow".
	 *
	 * @param target  "player" | "opponent" | "gf"
	 *                (también acepta aliases bf/dad/boyfriend/girlfriend)
	 * @param snap    Si true, mueve camFollow instantáneamente en lugar de lerp.
	 */
	public function setTarget(target:String, snap:Bool = false):Void
	{
		currentTarget = resolveTarget(target);
		trace('[CameraController] Target → $currentTarget (snap=$snap)');

		if (snap)
			_snapToTarget();
	}

	/**
	 * Actualizar lerp speed del follow.
	 * Llamar desde EventManager si se especifica value2 en el evento.
	 */
	public function setFollowLerp(lerp:Float):Void
	{
		followLerp = lerp;
		camGame.followLerp = lerp;
	}

	// ─────────────────────────────────────────────────────────────
	//  UPDATE
	// ─────────────────────────────────────────────────────────────

	/**
	 * Llamar desde PlayState.update() cada frame.
	 * Ya NO recibe mustHitSection — el target se controla por eventos.
	 */
	public function update(elapsed:Float):Void
	{
		updateFollowPosition(elapsed);
		lerpZoom(elapsed);
	}

	// ─────────────────────────────────────────────────────────────
	//  INTERNOS
	// ─────────────────────────────────────────────────────────────

	private function updateFollowPosition(elapsed:Float):Void
	{
		var targetChar = getTargetCharacter();
		if (targetChar == null) return;

		var targetPos = targetChar.getMidpoint();

		// Offsets propios del personaje (definidos en su JSON).
		targetPos.x += targetChar.cameraOffset[0];
		targetPos.y += targetChar.cameraOffset[1];

		// Offsets base según slot (ajusta según tu diseño de stage).
		switch (currentTarget)
		{
			case 'player':
				targetPos.x -= 100;
				targetPos.y -= 100;
			case 'opponent':
				targetPos.x += 150;
				targetPos.y -= 100;
			case 'gf':
				targetPos.y -= 80;
			default:
				targetPos.y -= 100;
		}

		// Offsets de animación de nota.
		var noteOffX = currentTarget == 'player' ? bfOffsetX : dadOffsetX;
		var noteOffY = currentTarget == 'player' ? bfOffsetY : dadOffsetY;

		// Lerp suave hacia el destino.
		var lerpVal:Float = FlxMath.bound(elapsed * LERP_SPEED, 0, 1);
		camFollow.x = FlxMath.lerp(camFollow.x, targetPos.x + noteOffX, lerpVal);
		camFollow.y = FlxMath.lerp(camFollow.y, targetPos.y + noteOffY, lerpVal);

		targetPos.put();
	}

	private function lerpZoom(elapsed:Float):Void
	{
		var lerpVal:Float = FlxMath.bound(elapsed * 3.125, 0, 1);
		camGame.zoom = FlxMath.lerp(camGame.zoom, defaultZoom, lerpVal);
		camHUD.zoom  = FlxMath.lerp(camHUD.zoom,  1.0,         lerpVal);
	}

	/** Mueve camFollow instantáneamente al target actual (sin lerp). */
	private function _snapToTarget():Void
	{
		var targetChar = getTargetCharacter();
		if (targetChar == null) return;

		var mid = targetChar.getMidpoint();
		switch (currentTarget)
		{
			case 'player':
				camFollow.setPosition(mid.x - 100 + targetChar.cameraOffset[0],
					mid.y - 100 + targetChar.cameraOffset[1]);
			case 'opponent':
				camFollow.setPosition(mid.x + 150 + targetChar.cameraOffset[0],
					mid.y - 100 + targetChar.cameraOffset[1]);
			default:
				camFollow.setPosition(mid.x + targetChar.cameraOffset[0],
					mid.y - 80 + targetChar.cameraOffset[1]);
		}
		mid.put();
	}

	private function getTargetCharacter():Character
	{
		return switch (currentTarget)
		{
			case 'player':   boyfriend;
			case 'opponent': dad;
			case 'gf':       gf;
			default:         dad;
		};
	}

	/** Normaliza aliases a los tres nombres canónicos. */
	private function resolveTarget(raw:String):String
	{
		return switch (raw.toLowerCase().trim())
		{
			case 'player'   | 'bf' | 'boyfriend': 'player';
			case 'opponent' | 'dad' | 'enemy':    'opponent';
			case 'gf'       | 'girlfriend':        'gf';
			default: raw;
		};
	}

	// ─────────────────────────────────────────────────────────────
	//  ZOOM Y EFECTOS
	// ─────────────────────────────────────────────────────────────

	public function bumpZoom():Void
	{
		if (!zoomEnabled) return;
		if (camGame.zoom < 1.35)
		{
			camGame.zoom += 0.015;
			camHUD.zoom  += 0.03;
		}
	}

	public function applyNoteOffset(character:Character, noteData:Int):Void
	{
		var camX:Float = 0;
		var camY:Float = 0;

		switch (noteData)
		{
			case 0: camX = -NOTE_OFFSET_AMOUNT;
			case 1: camY =  NOTE_OFFSET_AMOUNT;
			case 2: camY = -NOTE_OFFSET_AMOUNT;
			case 3: camX =  NOTE_OFFSET_AMOUNT;
		}

		if (character == dad)
		{
			dadOffsetX = Std.int(camX);
			dadOffsetY = Std.int(camY);
		}
		else if (character == boyfriend)
		{
			bfOffsetX = Std.int(camX);
			bfOffsetY = Std.int(camY);
		}
	}

	public function resetOffsets():Void
	{
		dadOffsetX = 0; dadOffsetY = 0;
		bfOffsetX  = 0; bfOffsetY  = 0;
	}

	public function tweenZoomIn():Void
	{
		if (zoomTween != null) zoomTween.cancel();
		zoomTween = FlxTween.tween(camGame, {zoom: defaultZoom}, 1, {ease: FlxEase.elasticInOut});
	}

	public function shake(intensity:Float = 0.05, duration:Float = 0.1):Void
		camGame.shake(intensity, duration);

	public function flash(duration:Float = 0.5, color:Int = 0xFFFFFFFF):Void
		camGame.flash(color, duration);

	// ─────────────────────────────────────────────────────────────

	public function destroy():Void
	{
		if (zoomTween != null) { zoomTween.cancel(); zoomTween = null; }
		camPos.put();
		camFollow = null;
	}
}
