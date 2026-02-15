package funkin.transitions;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.group.FlxGroup;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxTimer;
import flixel.math.FlxMath;
import flixel.sound.FlxSound;
import haxe.Json;
import sys.FileSystem;

/**
 * Sistema de transición con stickers al estilo FNF
 * Los stickers aparecen de forma aleatoria cubriendo toda la pantalla
 */
class StickerTransition
{
	// Configuración
	public static var enabled:Bool = true;
	public static var configPath:String = 'assets/images/transitionSwag/sticker-config.json';
	
	private static var config:StickerConfig;
	private static var stickerGroup:FlxTypedGroup<FlxSprite>;
	private static var stickerCamera:FlxCamera;
	private static var onComplete:Void->Void;
	private static var isPlaying:Bool = false;
	private static var allStickers:Array<FlxSprite> = [];
	
	/**
	 * Inicializa el sistema de transición
	 */
	public static function init():Void
	{
		loadConfig();
	}
	
	/**
	 * Carga la configuración desde JSON
	 */
	private static function loadConfig():Void
	{
		try
		{
			var jsonPath = configPath;
			
			#if sys
			if (!FileSystem.exists(jsonPath))
			{
				trace('[StickerTransition] Config not found, using defaults');
				config = getDefaultConfig();
				return;
			}
			#end
			
			var rawJson = sys.io.File.getContent(jsonPath);
			config = Json.parse(rawJson);
			trace('[StickerTransition] Config loaded successfully');
		}
		catch (e:Dynamic)
		{
			trace('[StickerTransition] Error loading config: $e');
			config = getDefaultConfig();
		}
	}
	
	/**
	 * Configuración por defecto - Aparecen en GRUPOS cubriendo MÁS pantalla
	 */
	private static function getDefaultConfig():StickerConfig
	{
		return {
			enabled: true,
			stickerSets: [
				{
					name: "stickers-set-1",
					path: "transitionSwag/stickers-set-1",
					stickers: ["bfSticker3", "picoSticker1", "dadSticker1", "gfSticker1", "momSticker1", "monsterSticker1"]
				},
				{
					name: "stickers-set-2",
					path: "transitionSwag/stickers-set-2",
					stickers: ["bfSticker3", "picoSticker1", "dadSticker1"]
				}
			],
			soundPath: "stickersounds/keys",
			sounds: ["keyClick1", "keyClick2", "keyClick3"],
			stickersPerWave: 8,  // Más stickers por grupo (antes: 6)
			totalWaves: 12,      // Más oleadas para cubrir toda la pantalla (antes: 10)
			delayBetweenStickers: 0.0,  // Sin delay dentro del grupo
			delayBetweenWaves: 0.1,     // Oleadas más rápidas (antes: 0.12)
			minScale: 0.85,       // Rango más amplio de tamaños (antes: 0.85)
			maxScale: 1.0,      // Algunos más grandes (antes: 1.0)
			animationDuration: 0.35,
			stickerLifetime: 999
		};
	}
	
	/**
	 * Inicia la transición con stickers
	 */
	public static function start(?callback:Void->Void, ?customSet:String):Void
	{
		if (!enabled || isPlaying)
			return;
		
		if (config == null)
			loadConfig();
		
		isPlaying = true;
		onComplete = callback;
		allStickers = [];
		
		// Crear cámara dedicada para stickers (PERSISTE entre states)
		if (stickerCamera == null)
		{
			stickerCamera = new FlxCamera();
			stickerCamera.bgColor.alpha = 0; // Transparente
			FlxG.cameras.add(stickerCamera, false);
		}
		
		// Asegurar que la cámara esté al final (encima de todo)
		if (FlxG.cameras.list.contains(stickerCamera))
		{
			FlxG.cameras.remove(stickerCamera, false);
			FlxG.cameras.add(stickerCamera, false);
		}
		
		// Crear grupo de stickers
		stickerGroup = new FlxTypedGroup<FlxSprite>();
		FlxG.state.add(stickerGroup);
		
		// Seleccionar set de stickers
		var selectedSet:StickerSet = null;
		
		if (customSet != null)
		{
			for (set in config.stickerSets)
			{
				if (set.name == customSet)
				{
					selectedSet = set;
					break;
				}
			}
		}
		
		if (selectedSet == null)
			selectedSet = FlxG.random.getObject(config.stickerSets);
		
		// Generar oleadas de stickers
		generateWaves(selectedSet);
	}
	
	/**
	 * Genera oleadas de stickers
	 */
	private static function generateWaves(stickerSet:StickerSet):Void
	{
		var totalDelay:Float = 0;
		
		for (wave in 0...config.totalWaves)
		{
			new FlxTimer().start(totalDelay, function(timer:FlxTimer)
			{
				spawnWave(stickerSet);
			});
			
			totalDelay += config.delayBetweenWaves + (config.stickersPerWave * config.delayBetweenStickers);
		}
		
		// Llamar al callback después de que aparezcan todos (sin esperar a que desaparezcan)
		var totalDuration = totalDelay + config.animationDuration;
		new FlxTimer().start(totalDuration, function(timer:FlxTimer)
		{
			if (onComplete != null)
			{
				onComplete();
				// NO llamamos a finish() aquí, esperamos a clearStickers()
			}
		});
	}
	
	/**
	 * Genera una oleada de stickers - TODOS AL MISMO TIEMPO
	 */
	private static function spawnWave(stickerSet:StickerSet):Void
	{
		// Generar todos los stickers de la oleada simultáneamente (sin delay)
		for (i in 0...config.stickersPerWave)
		{
			spawnSticker(stickerSet);
		}
	}
	
	/**
	 * Genera un sticker individual
	 */
	private static function spawnSticker(stickerSet:StickerSet):Void
	{
		// Seleccionar sticker aleatorio
		var stickerName = FlxG.random.getObject(stickerSet.stickers);
		var stickerPath = '${stickerSet.path}/$stickerName';
		
		// Crear sprite
		var sticker = new FlxSprite();
		
		try
		{
			sticker.loadGraphic(Paths.image(stickerPath));
		}
		catch (e:Dynamic)
		{
			trace('[StickerTransition] Error loading sticker: $stickerPath');
			return;
		}
		
		// Posición aleatoria en pantalla - EXTENDIDA para cubrir más área
		// Pueden aparecer parcialmente fuera de la pantalla para cubrir mejor
		sticker.x = FlxG.random.float(-sticker.width * 0.5, FlxG.width - sticker.width * 0.5);
		sticker.y = FlxG.random.float(-sticker.height * 0.5, FlxG.height - sticker.height * 0.5);
		
		// Escala con rango más amplio para variedad
		var targetScale = FlxG.random.float(config.minScale, config.maxScale);
		sticker.scale.set(0.1, 0.1);
		sticker.updateHitbox();
		
		// Ángulo aleatorio
		var targetAngle = FlxG.random.float(-15, 15);
		sticker.angle = targetAngle + FlxG.random.float(-45, 45);
		
		// Alpha inicial
		sticker.alpha = 0;
		
		// IMPORTANTE: scrollFactor (0,0) para que esté siempre visible
		sticker.scrollFactor.set(0, 0);
		
		// CRÍTICO: Asignar a la cámara dedicada (encima de todo)
		sticker.cameras = [stickerCamera];
		
		// Agregar a la lista para poder limpiarlos después
		allStickers.push(sticker);
		stickerGroup.add(sticker);
		
		// Animación de entrada: escala + rotación + alpha
		FlxTween.tween(sticker.scale, {x: targetScale, y: targetScale}, config.animationDuration, {
			ease: FlxEase.backOut,
			onUpdate: function(tween:FlxTween) {
				sticker.updateHitbox();
			}
		});
		
		FlxTween.tween(sticker, {angle: targetAngle, alpha: 1}, config.animationDuration, {
			ease: FlxEase.cubeOut
		});
		
		// Los stickers NO se eliminan automáticamente, esperan a clearStickers()
		
		// Reproducir sonido aleatorio MÁS ALTO
		playRandomSound();
	}
	
	/**
	 * Reproduce un sonido aleatorio - MÁS ALTO
	 */
	private static function playRandomSound():Void
	{
		if (config.sounds.length == 0)
			return;
		
		var soundName = FlxG.random.getObject(config.sounds);
		var soundPath = '${config.soundPath}/$soundName';
		
		try
		{
			// Volumen más alto: 0.9 a 1.3 (antes: 0.6 a 1.0)
			FlxG.sound.play(Paths.sound(soundPath), FlxG.random.float(0.9, 1.3));
		}
		catch (e:Dynamic)
		{
			trace('[StickerTransition] Error playing sound: $soundPath');
		}
	}
	
	/**
	 * Re-agrega los stickers al state actual (llamar en create del nuevo state antes de clearStickers)
	 */
	public static function reattachToState():Void
	{
		if (!isPlaying || stickerGroup == null)
			return;
		
		// Agregar el grupo al nuevo state
		if (FlxG.state != null && !FlxG.state.members.contains(stickerGroup))
		{
			FlxG.state.add(stickerGroup);
			trace('[StickerTransition] Reattached to new state');
		}
		
		// Asegurar que la cámara esté al final (encima de todo)
		ensureCameraOnTop();
	}
	
	/**
	 * Verifica si hay una transición activa
	 */
	public static function isActive():Bool
	{
		return isPlaying;
	}
	
	/**
	 * Asegura que la cámara de stickers esté al final (encima de todo)
	 * Llamar en update() del state para mantener encima de transiciones
	 */
	public static function ensureCameraOnTop():Void
	{
		if (stickerCamera != null && FlxG.cameras.list.contains(stickerCamera))
		{
			// Si no es la última cámara, moverla al final
			var lastIndex = FlxG.cameras.list.length - 1;
			if (FlxG.cameras.list[lastIndex] != stickerCamera)
			{
				FlxG.cameras.remove(stickerCamera, false);
				FlxG.cameras.add(stickerCamera, false);
			}
		}
	}
	
	/**
	 * Limpia todos los stickers - LLAMAR CUANDO EL PRÓXIMO STATE ESTÉ LISTO
	 */
	public static function clearStickers():Void
	{
		if (!isPlaying)
			return;
		
		trace('[StickerTransition] Will clear stickers after all appear');
		
		// Calcular cuánto tiempo toma que aparezcan TODOS los stickers
		var totalAppearTime = (config.totalWaves * config.delayBetweenWaves) + config.animationDuration;
		
		// Esperar a que TODOS los stickers hayan aparecido + un momento extra para verlos
		var delayBeforeDissipate = totalAppearTime + 0.4; // +0.4s para ver la pantalla llena
		
		trace('[StickerTransition] Waiting ${delayBeforeDissipate}s before dissipation');
		
		new FlxTimer().start(delayBeforeDissipate, function(timer:FlxTimer)
		{
			trace('[StickerTransition] Starting dissipation animation');
			
			// Animar salida de todos los stickers con DISIPACIÓN DRAMÁTICA (sin rotación)
			for (sticker in allStickers)
			{
				if (sticker != null && sticker.exists && sticker.alive)
				{
					// Cancelar tweens previos para evitar conflictos
					FlxTween.cancelTweensOf(sticker);
					FlxTween.cancelTweensOf(sticker.scale);
					
					// Dirección aleatoria para dispersar los stickers
					var disperseX = FlxG.random.float(-400, 400);
					var disperseY = FlxG.random.float(-400, 400);
					
					// DISIPACIÓN DRAMÁTICA MÁS LENTA: Escala + Movimiento + Alpha
					FlxTween.tween(sticker.scale, {x: 0.05, y: 0.05}, 0.5, {
						ease: FlxEase.backIn,
						onUpdate: function(tween:FlxTween) {
							if (sticker != null && sticker.exists)
								sticker.updateHitbox();
						},
						onComplete: function(tween:FlxTween) {
							if (sticker != null && sticker.exists)
							{
								sticker.kill();
								sticker.destroy();
							}
						}
					});
					
					// Mover + Desvanecer más lento
					FlxTween.tween(sticker, {
						alpha: 0,
						x: sticker.x + disperseX,
						y: sticker.y + disperseY
					}, 0.5, {
						ease: FlxEase.cubeIn
					});
				}
			}
			
			// Limpiar después de la animación
			new FlxTimer().start(0.6, function(timer:FlxTimer)
			{
				finish();
			});
		});
	}
	
	/**
	 * Finaliza la transición
	 */
	private static function finish():Void
	{
		isPlaying = false;
		
		// Cancelar todos los tweens pendientes
		for (sticker in allStickers)
		{
			if (sticker != null && sticker.exists)
			{
				FlxTween.cancelTweensOf(sticker);
				FlxTween.cancelTweensOf(sticker.scale);
				sticker.kill();
				sticker.destroy();
			}
		}
		
		if (stickerGroup != null)
		{
			stickerGroup.clear();
			if (FlxG.state != null && FlxG.state.members.contains(stickerGroup))
				FlxG.state.remove(stickerGroup);
			stickerGroup = null;
		}
		
		// Limpiar cámara dedicada
		if (stickerCamera != null)
		{
			if (FlxG.cameras.list.contains(stickerCamera))
				FlxG.cameras.remove(stickerCamera);
			stickerCamera.destroy();
			stickerCamera = null;
		}
		
		allStickers = [];
		onComplete = null;
		
		trace('[StickerTransition] Finished');
	}
	
	/**
	 * Cancela la transición actual
	 */
	public static function cancel():Void
	{
		if (!isPlaying)
			return;
		
		trace('[StickerTransition] Cancelled');
		finish();
	}
	
	/**
	 * Recarga la configuración
	 */
	public static function reloadConfig():Void
	{
		loadConfig();
		trace('[StickerTransition] Config reloaded');
	}
}

// ==========================================
// TYPEDEFS PARA CONFIGURACIÓN
// ==========================================

typedef StickerConfig =
{
	var enabled:Bool;
	var stickerSets:Array<StickerSet>;
	var soundPath:String;
	var sounds:Array<String>;
	var stickersPerWave:Int;
	var totalWaves:Int;
	var delayBetweenStickers:Float;
	var delayBetweenWaves:Float;
	var minScale:Float;
	var maxScale:Float;
	var animationDuration:Float;
	var stickerLifetime:Float;
}

typedef StickerSet =
{
	var name:String;
	var path:String;
	var stickers:Array<String>;
}
