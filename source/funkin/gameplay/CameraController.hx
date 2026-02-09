package funkin.gameplay;

import flixel.FlxG;
import flixel.FlxCamera;
import flixel.FlxObject;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import funkin.gameplay.objects.character.Character;

/**
 * CameraController - Control de cámara optimizado
 * Maneja: Follow, Zoom, Tweens, Note movement offsets
 */
class CameraController
{
	// === CAMERAS ===
	public var camGame:FlxCamera;
	public var camHUD:FlxCamera;
	
	// === FOLLOW ===
	private var camFollow:FlxObject;
	private var camPos:FlxPoint;
	
	// === CHARACTERS ===
	private var boyfriend:Character;
	private var dad:Character;
	
	// === ZOOM ===
	public var defaultZoom:Float = 1.05;
	public var zoomEnabled:Bool = false;
	private var zoomTween:FlxTween;
	
	// === NOTE MOVEMENT OFFSETS ===
	public var dadOffsetX:Int = 0;
	public var dadOffsetY:Int = 0;
	public var bfOffsetX:Int = 0;
	public var bfOffsetY:Int = 0;
	
	// === CONFIG ===
	private static inline var LERP_SPEED:Float = 2.4;
	private static inline var NOTE_OFFSET_AMOUNT:Float = 30.0;
	
	public function new(camGame:FlxCamera, camHUD:FlxCamera, boyfriend:Character, dad:Character)
	{
		this.camGame = camGame;
		this.camHUD = camHUD;
		this.boyfriend = boyfriend;
		this.dad = dad;
		
		// Crear follow object
		camFollow = new FlxObject(0, 0, 1, 1);
		camPos = new FlxPoint();
		
		camGame.follow(camFollow, LOCKON, 0.04);
		camGame.zoom = defaultZoom;
	}
	
	/**
	 * Update cámara cada frame
	 */
	public function update(elapsed:Float, mustHitSection:Bool):Void
	{
		// Actualizar posición del follow
		updateFollowPosition(elapsed, mustHitSection);
		
		// Lerp zoom de vuelta al default
		lerpZoom(elapsed);
	}
	
	/**
	 * Actualizar posición de cámara (follow)
	 */
	private function updateFollowPosition(elapsed:Float, mustHitSection:Bool):Void
	{
		var targetChar:Character = mustHitSection ? boyfriend : dad;
		var targetCamPos:FlxPoint = targetChar.getMidpoint();
		
		// Aplicar offsets del personaje
		targetCamPos.x += targetChar.cameraOffset[0];
		targetCamPos.y += targetChar.cameraOffset[1];
		
		// Ajustes base según quien canta
		if (mustHitSection)
		{
			targetCamPos.x -= 100;
			targetCamPos.y -= 100;
		}
		else
		{
			targetCamPos.x += 150;
			targetCamPos.y -= 100;
		}
		
		// Aplicar offsets de notas
		var noteOffsetX = mustHitSection ? bfOffsetX : dadOffsetX;
		var noteOffsetY = mustHitSection ? bfOffsetY : dadOffsetY;
		
		// Lerp suave
		var lerpVal:Float = FlxMath.bound(elapsed * LERP_SPEED, 0, 1);
		camFollow.x = FlxMath.lerp(camFollow.x, targetCamPos.x + noteOffsetX, lerpVal);
		camFollow.y = FlxMath.lerp(camFollow.y, targetCamPos.y + noteOffsetY, lerpVal);
		
		targetCamPos.put();
	}
	
	/**
	 * Lerp zoom de vuelta al default
	 */
	private function lerpZoom(elapsed:Float):Void
	{
		var lerpVal:Float = FlxMath.bound(elapsed * 3.125, 0, 1);
		camGame.zoom = FlxMath.lerp(camGame.zoom, defaultZoom, lerpVal);
		camHUD.zoom = FlxMath.lerp(camHUD.zoom, 1, lerpVal);
	}
	
	/**
	 * Aplicar zoom en beat
	 */
	public function bumpZoom():Void
	{
		if (!zoomEnabled)
			return;
		
		if (camGame.zoom < 1.35)
		{
			camGame.zoom += 0.015;
			camHUD.zoom += 0.03;
		}
	}
	
	/**
	 * Aplicar offset de nota (para movimiento reactivo)
	 */
	public function applyNoteOffset(character:Character, noteData:Int):Void
	{
		var camX:Float = 0;
		var camY:Float = 0;
		
		switch (noteData)
		{
			case 0: // LEFT
				camX = -NOTE_OFFSET_AMOUNT;
			case 1: // DOWN
				camY = NOTE_OFFSET_AMOUNT;
			case 2: // UP
				camY = -NOTE_OFFSET_AMOUNT;
			case 3: // RIGHT
				camX = NOTE_OFFSET_AMOUNT;
		}
		
		// Asignar según personaje
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
	
	/**
	 * Reset offsets
	 */
	public function resetOffsets():Void
	{
		dadOffsetX = 0;
		dadOffsetY = 0;
		bfOffsetX = 0;
		bfOffsetY = 0;
	}
	
	/**
	 * Tween zoom in (para tutorial)
	 */
	public function tweenZoomIn():Void
	{
		if (zoomTween != null)
			zoomTween.cancel();
		
		zoomTween = FlxTween.tween(camGame, {zoom: defaultZoom}, 1, {ease: FlxEase.elasticInOut});
	}
	
	/**
	 * Shake cámara
	 */
	public function shake(intensity:Float = 0.05, duration:Float = 0.1):Void
	{
		camGame.shake(intensity, duration);
	}
	
	/**
	 * Flash cámara
	 */
	public function flash(duration:Float = 0.5, color:Int = 0xFFFFFFFF):Void
	{
		camGame.flash(color, duration);
	}
	
	/**
	 * Destruir
	 */
	public function destroy():Void
	{
		if (zoomTween != null)
		{
			zoomTween.cancel();
			zoomTween = null;
		}
		
		camPos.put();
		camFollow = null;
	}
}