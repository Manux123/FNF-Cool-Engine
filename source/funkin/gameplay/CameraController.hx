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

	// === INITIAL STATE (for restart/rewind) ===
	// Saved at construction time so resetToInitial() can fully restore the camera.
	private var _initialTarget : String = 'opponent';
	private var _initialZoom   : Float  = 1.05;
	private var _initialLerp   : Float  = 0.04;

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

	// === STAGE CAMERA OFFSETS ===
	// Definidos en el stage JSON como cameraBoyfriend / cameraDad / cameraGirlfriend.
	// Se suman al follow position igual que los offsets del personaje.
	public var stageOffsetBf:FlxPoint  = new FlxPoint(0, 0);
	public var stageOffsetDad:FlxPoint = new FlxPoint(0, 0);
	/** Offset de cámara para GF (camera_girlfriend en Psych). */
	public var stageOffsetGf:FlxPoint  = new FlxPoint(0, 0);

	// === CONFIG ===
	/**
	 * Velocidad del lerp de cámara. Equivalente a camera_speed en Psych.
	 * Se inicializa a 2.4 (default de Cool Engine). PlayState lo sobreescribe
	 * con currentStage.cameraSpeed * BASE_LERP_SPEED tras cargar el stage.
	 */
	public var lerpSpeed:Float = 2.4;
	public static inline var BASE_LERP_SPEED:Float = 2.4;
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

		// Save initial state so resetToInitial() can fully restore it on rewind/restart.
		_initialTarget = currentTarget;
		_initialZoom   = defaultZoom;
		_initialLerp   = followLerp;

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

	/**
	 * Restaura el estado inicial de la cámara (target, zoom, lerp).
	 * Llamar desde PlayState._finishRestart() y PlayStateEditorState._onRestart()
	 * DESPUÉS de que EventManager.rewindToStart() haya marcado los eventos como
	 * no disparados, para que la cámara quede donde estaba al inicio de la canción.
	 */
	public function resetToInitial():Void
	{
		// Cancel any active zoom tween first
		if (zoomTween != null) { zoomTween.cancel(); zoomTween = null; }

		currentTarget = _initialTarget;
		defaultZoom   = _initialZoom;
		followLerp    = _initialLerp;
		zoomEnabled   = false;
		dadOffsetX    = 0;
		dadOffsetY    = 0;
		bfOffsetX     = 0;
		bfOffsetY     = 0;

		camGame.zoom        = defaultZoom;
		camGame.followLerp  = followLerp;

		_snapToTarget();
		trace('[CameraController] resetToInitial → target=$currentTarget zoom=$defaultZoom');
	}

	/**
	 * Toma una foto del estado actual como "estado inicial".
	 * PlayState llama esto DESPUÉS de aplicar todos los overrides del stage
	 * (defaultCamZoom, stageOffsets, lerpSpeed) para que resetToInitial()
	 * vuelva al punto correcto tras un rewind.
	 */
	public function snapshotInitialState():Void
	{
		_initialTarget = currentTarget;
		_initialZoom   = defaultZoom;
		_initialLerp   = followLerp;
		trace('[CameraController] snapshotInitialState → target=$_initialTarget zoom=$_initialZoom lerp=$_initialLerp');
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
		// ── Target 'both': centrar entre bf y dad ─────────────────────────
		if (currentTarget == 'both')
		{
			if (boyfriend == null || dad == null) return;

			var bfMid  = boyfriend.getMidpoint();
			var dadMid = dad.getMidpoint();

			var midX = (bfMid.x + dadMid.x) * 0.5;
			var midY = (bfMid.y + dadMid.y) * 0.5;

			// Offset vertical genérico para que no quede en los pies
			midY -= 100;

			var lerpVal:Float = FlxMath.bound(elapsed * lerpSpeed, 0, 1);
			camFollow.x = FlxMath.lerp(camFollow.x, midX, lerpVal);
			camFollow.y = FlxMath.lerp(camFollow.y, midY, lerpVal);

			bfMid.put();
			dadMid.put();
			return;
		}

		// ── Target normal ─────────────────────────────────────────────────
		var targetChar = getTargetCharacter();
		if (targetChar == null) return;

		var targetPos = targetChar.getMidpoint();

		// Offsets propios del personaje (definidos en su JSON).
		targetPos.x += targetChar.cameraOffset[0];
		targetPos.y += targetChar.cameraOffset[1];

		// BUG FIX: Seleccionar el stage offset correcto según el target.
		// Antes: `currentTarget == 'player' ? stageOffsetBf : stageOffsetDad`
		// → GF siempre recibía el offset del Dad (else branch), que era incorrecto.
		var stageOff = switch (currentTarget)
		{
			case 'player':   stageOffsetBf;
			case 'opponent': stageOffsetDad;
			case 'gf':       stageOffsetGf;
			default:         stageOffsetDad;
		};
		targetPos.x += stageOff.x;
		targetPos.y += stageOff.y;

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
		var lerpVal:Float = FlxMath.bound(elapsed * lerpSpeed, 0, 1);
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
		// ── Target 'both': snap al centro entre bf y dad ──────────────────
		if (currentTarget == 'both')
		{
			if (boyfriend == null || dad == null) return;
			var bfMid  = boyfriend.getMidpoint();
			var dadMid = dad.getMidpoint();
			camFollow.setPosition(
				(bfMid.x + dadMid.x) * 0.5,
				(bfMid.y + dadMid.y) * 0.5 - 100
			);
			bfMid.put();
			dadMid.put();
			return;
		}

		var targetChar = getTargetCharacter();
		if (targetChar == null) return;

		var mid = targetChar.getMidpoint();
		// BUG FIX: igual que en updateFollowPosition, GF necesita su propio stageOffset.
		var stageOff = switch (currentTarget)
		{
			case 'player':   stageOffsetBf;
			case 'opponent': stageOffsetDad;
			case 'gf':       stageOffsetGf;
			default:         stageOffsetDad;
		};
		switch (currentTarget)
		{
			case 'player':
				camFollow.setPosition(mid.x - 100 + targetChar.cameraOffset[0] + stageOff.x,
					mid.y - 100 + targetChar.cameraOffset[1] + stageOff.y);
			case 'opponent':
				camFollow.setPosition(mid.x + 150 + targetChar.cameraOffset[0] + stageOff.x,
					mid.y - 100 + targetChar.cameraOffset[1] + stageOff.y);
			default:
				camFollow.setPosition(mid.x + targetChar.cameraOffset[0] + stageOff.x,
					mid.y - 80 + targetChar.cameraOffset[1] + stageOff.y);
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

	/** Normaliza aliases a los cuatro nombres canónicos. */
	private function resolveTarget(raw:String):String
	{
		return switch (raw.toLowerCase().trim())
		{
			case 'player'   | 'bf' | 'boyfriend':          'player';
			case 'opponent' | 'dad' | 'enemy':             'opponent';
			case 'gf'       | 'girlfriend':                 'gf';
			case 'both'     | 'center' | 'middle' | 'all': 'both';
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
		stageOffsetBf.put();
		stageOffsetDad.put();
		stageOffsetGf.put();
		camFollow = null;
	}
}
