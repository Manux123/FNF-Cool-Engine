package funkin.transitions;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.group.FlxGroup;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxTimer;
import flixel.math.FlxMath;
import flixel.graphics.FlxGraphic;
import haxe.Json;
import sys.FileSystem;

/**
 * Sistema de transición con stickers al estilo FNF
 * ✅ BASADO en el sistema del FNF base - usa OpenFL Sprite para persistir entre states
 */
class StickerTransition
{
	// Configuración
	public static var enabled:Bool = true;
	public static var configPath:String = Paths.resolve('images/transitionSwag/sticker-config.json');

	private static var config:StickerConfig;
	private static var onComplete:Void->Void;
	private static var isPlaying:Bool = false;
	
	// ✅ OpenFL Sprite container (como StickerTransitionSprite del FNF base)
	private static var transitionSprite:Null<StickerTransitionContainer> = null;
	
	// Cache de gráficos
	private static var graphicsCache:Map<String, FlxGraphic> = new Map<String, FlxGraphic>();
	private static var cacheLoaded:Bool = false;
	
	// ✅ Map para guardar datos de cada sticker
	private static var stickerData:Map<FlxSprite, StickerSpriteData> = new Map<FlxSprite, StickerSpriteData>();
	
	// ✅ Lista de timers activos para poder cancelarlos
	private static var activeTimers:Array<FlxTimer> = [];

	/**
	 * Inicializa el sistema de transición
	 */
	public static function init():Void
	{
		loadConfig();
		preloadGraphics();
		
		// Crear el contenedor de transición
		if (transitionSprite == null)
		{
			transitionSprite = new StickerTransitionContainer();
		}
		
		trace('[StickerTransition] System initialized');
	}

	/**
	 * Pre-carga todos los gráficos de stickers
	 */
	private static function preloadGraphics():Void
	{
		if (cacheLoaded || config == null)
			return;
			
		trace('[StickerTransition] ========== PRE-LOADING GRAPHICS ==========');
		
		var loadedCount = 0;
		var failedCount = 0;
		
		for (set in config.stickerSets)
		{
			for (stickerName in set.stickers)
			{
				var stickerPath = '${set.path}/$stickerName';
				var cacheKey = stickerPath;
				
				if (!graphicsCache.exists(cacheKey))
				{
					try
					{
						// En native cpp, openfl.Assets.getBitmapData() solo funciona con
						// assets embebidos, no con rutas de filesystem de mods — de ahí
						// el crash en lime build (FlxImageFrame::findFrame con bitmap null).
						// Solución: usar BitmapData.fromFile() en targets sys.
						var resolvedPath = Paths.image(stickerPath);
						var bitmapData:openfl.display.BitmapData = null;
						#if sys
						if (sys.FileSystem.exists(resolvedPath))
							bitmapData = openfl.display.BitmapData.fromFile(resolvedPath);
						#else
						bitmapData = openfl.Assets.getBitmapData(resolvedPath);
						#end
						if (bitmapData == null)
						{
							trace('[StickerTransition] ❌ BitmapData null (asset no existe): $stickerPath');
							failedCount++;
						}
						else
						{
							var graphic = FlxGraphic.fromBitmapData(bitmapData);
							graphic.persist = true;
							graphicsCache.set(cacheKey, graphic);
							loadedCount++;
						}
					}
					catch (e:Dynamic)
					{
						trace('[StickerTransition] ❌ Failed to cache: $stickerPath ($e)');
						failedCount++;
					}
				}
			}
		}
		
		cacheLoaded = true;
		trace('[StickerTransition] ========== CACHE COMPLETE ==========');
		trace('[StickerTransition] Loaded: $loadedCount | Failed: $failedCount');
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
	 * Configuración por defecto
	 */
	private static function getDefaultConfig():StickerConfig
	{
		return {
			enabled: true,
			stickerSets: [
				{
					name: "stickers-set-1",
					path: "transitionSwag/stickers-set-1",
					stickers: [
						"bfSticker3",
						"picoSticker1",
						"dadSticker1",
						"gfSticker1",
						"momSticker1",
						"monsterSticker1"
					]
				},
				{
					name: "stickers-set-2",
					path: "transitionSwag/stickers-set-2",
					stickers: ["bfSticker3", "picoSticker1", "dadSticker1"]
				}
			],
			soundPath: "stickersounds/keys",
			sounds: ["keyClick1", "keyClick2", "keyClick3"],
			stickersPerWave: 8,
			totalWaves: 12,
			delayBetweenStickers: 0.0,
			delayBetweenWaves: 0.1,
			minScale: 0.85,
			maxScale: 1.0,
			animationDuration: 0.25,
			stickerLifetime: 999
		};
	}

	/**
	 * Inicia la transición con stickers
	 */
	public static function start(?callback:Void->Void, ?customSet:String):Void
	{
		if (!enabled)
			return;
		
		// ✅ CRÍTICO: Si ya hay una transición corriendo, cancelarla primero
		if (isPlaying)
		{
			trace('[StickerTransition] Transition already playing, cancelling it first');
			cancel();
		}

		if (config == null)
			loadConfig();
			
		if (!cacheLoaded)
			preloadGraphics();
			
		if (transitionSprite == null)
		{
			transitionSprite = new StickerTransitionContainer();
		}

		isPlaying = true;
		onComplete = callback;

		trace('[StickerTransition] ========== STARTING TRANSITION ==========');

		// ✅ Insertar el sprite en OpenFL (como hace el FNF base)
		transitionSprite.insert();

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

		trace('[StickerTransition] Selected set: ${selectedSet.name}');

		// Generar stickers
		generateStickers(selectedSet);
	}

	/**
	 * Genera todos los stickers
	 */
	private static function generateStickers(stickerSet:StickerSet):Void
	{
		transitionSprite.clearStickers();
		
		// ✅ Limpiar datos viejos
		stickerData.clear();
		
		// ✅ CRÍTICO: CANCELAR timers viejos ANTES de limpiar la lista
		// Si no hacemos esto, los timers viejos siguen corriendo como "fantasmas"
		cancelAllTimers();
		
		var allStickers:Array<FlxSprite> = [];

		// ✅ VOLVER A DISTRIBUCIÓN ALEATORIA (como antes que funcionaba bien)
		var totalStickers = config.totalWaves * config.stickersPerWave; // 12 * 8 = 96
		
		for (i in 0...totalStickers)
		{
			var sticker = createSticker(stickerSet);
			if (sticker != null)
			{
				sticker.x = FlxG.random.float(-sticker.width * 0.5 - 200, FlxG.width + sticker.width * 0.5 - 150);
				sticker.y = FlxG.random.float(-sticker.height * 0.5 - 200, FlxG.height + sticker.height * 0.5 - 150);
				
				allStickers.push(sticker);
				transitionSprite.addSticker(sticker);
			}
		}
		
		// ✅ Mezclar orden de aparición
		FlxG.random.shuffle(allStickers);

		trace('[StickerTransition] Created ${allStickers.length} stickers with random distribution');

		// Animar aparición en el orden mezclado
		for (i in 0...allStickers.length)
		{
			var sticker = allStickers[i];
			// Timing distribuido uniformemente entre 0 y 0.9 segundos
			var timing = FlxMath.remapToRange(i, 0, allStickers.length, 0, 0.9);
			
			// ✅ Usar globalManager para que sobreviva cambios de state
			var timer = new FlxTimer(FlxTimer.globalManager);
			activeTimers.push(timer); // ✅ Guardar referencia
			
			timer.start(timing, function(t:FlxTimer)
			{
				animateStickerIn(sticker);
				playRandomSound();
			});
		}

		// Llamar callback cuando terminen de aparecer
		// ✅ Usar globalManager
		var callbackTimer = new FlxTimer(FlxTimer.globalManager);
		activeTimers.push(callbackTimer); // ✅ Guardar referencia
		
		callbackTimer.start(0.9 + config.animationDuration, function(t:FlxTimer)
		{
			trace('[StickerTransition] All stickers appeared, calling callback');
			if (onComplete != null)
			{
				onComplete();
			}
		});
	}

	/**
	 * Crea un sticker individual
	 */
	private static function createSticker(stickerSet:StickerSet):Null<FlxSprite>
	{
		var stickerName = FlxG.random.getObject(stickerSet.stickers);
		var stickerPath = '${stickerSet.path}/$stickerName';
		var cacheKey = stickerPath;

		// Obtener gráfico del cache
		var graphic = graphicsCache.get(cacheKey);
		if (graphic == null)
		{
			trace('[StickerTransition] ⚠️ Graphic not in cache: $cacheKey');
			return null;
		}
		// Segunda defensa: bitmap puede ser null si el asset no existía al cachear
		if (graphic.bitmap == null)
		{
			trace('[StickerTransition] ⚠️ Graphic bitmap=null, descartando: $cacheKey');
			graphicsCache.remove(cacheKey);
			return null;
		}

		var sticker = new FlxSprite();
		try
		{
			sticker.loadGraphic(graphic);
		}
		catch (e:Dynamic)
		{
			// El bitmap fue dispuesto (p.ej. por PlayState.destroy) — invalidar cache
			trace('[StickerTransition] ⚠️ loadGraphic falló ($cacheKey): $e — invalidando cache');
			graphicsCache.remove(cacheKey);
			cacheLoaded = false;
			sticker.destroy();
			return null;
		}

		// ✅ La posición se asigna en generateStickers()

		// Escala inicial
		var targetScale = FlxG.random.float(config.minScale, config.maxScale);
		sticker.scale.set(0.1, 0.1);
		sticker.updateHitbox();

		// Ángulo
		var targetAngle = FlxG.random.float(-15, 15);
		sticker.angle = targetAngle + FlxG.random.float(-45, 45);

		// Alpha inicial
		sticker.alpha = 0;
		sticker.visible = false;

		// ScrollFactor
		sticker.scrollFactor.set(0, 0);

		// ✅ Guardar datos en el Map
		stickerData.set(sticker, {
			targetScale: targetScale,
			targetAngle: targetAngle
		});

		return sticker;
	}

	/**
	 * Anima la entrada de un sticker
	 */
	private static function animateStickerIn(sticker:FlxSprite):Void
	{
		if (sticker == null)
			return;

		sticker.visible = true;

		// ✅ Obtener datos del Map
		var data = stickerData.get(sticker);
		if (data == null)
			return;
			
		var targetScale:Float = data.targetScale;
		var targetAngle:Float = data.targetAngle;

		// Animación de escala
		FlxTween.tween(sticker.scale, {x: targetScale, y: targetScale}, config.animationDuration, {
			ease: FlxEase.backOut,
			onUpdate: function(tween:FlxTween)
			{
				if (sticker != null && sticker.exists)
					sticker.updateHitbox();
			}
		});

		// Animación de ángulo y alpha
		FlxTween.tween(sticker, {angle: targetAngle, alpha: 1}, config.animationDuration, {
			ease: FlxEase.cubeOut
		});
	}

	/**
	 * Reproduce un sonido aleatorio
	 */
	public static function playRandomSound():Void
	{
		if (config.sounds.length == 0)
			return;

		var soundName = FlxG.random.getObject(config.sounds);
		var soundPath = '${config.soundPath}/$soundName';

		try
		{
			FlxG.sound.play(Paths.sound(soundPath), FlxG.random.float(0.9, 1.3));
		}
		catch (e:Dynamic)
		{
			// Silenciar error de sonido
		}
	}

	/**
	 * ✅ NUEVO: Cancela todos los timers activos para evitar stickers fantasma
	 */
	private static function cancelAllTimers():Void
	{
		trace('[StickerTransition] Cancelling ${activeTimers.length} active timers');
		
		for (timer in activeTimers)
		{
			if (timer != null && timer.active)
			{
				timer.cancel();
			}
		}
		
		activeTimers = [];
	}

	/**
	 * Verifica si hay una transición activa
	 */
	public static function isActive():Bool
	{
		return isPlaying;
	}

	/**
	 * Limpia todos los stickers
	 * @param onFinished Callback opcional que se llama cuando los stickers terminan de desaparecer
	 */
	public static function clearStickers(?onFinished:Void->Void):Void
	{
		if (!isPlaying)
		{
			trace('[StickerTransition] clearStickers called but not playing - calling callback immediately');
			if (onFinished != null)
				onFinished(); // Llamar callback inmediatamente si no está activo
			return;
		}

		trace('[StickerTransition] ========== CLEARING STICKERS ==========');
		
		// ✅ CRÍTICO: Cancelar todos los timers de aparición pendientes
		// Esto evita que aparezcan stickers durante la disipación
		cancelAllTimers();

		// ✅ Tiempo de aparición: 0.9s (timing) + config.animationDuration
		var totalAppearTime = 0.9 + config.animationDuration;
		// ✅ REDUCIDO: Empezar a disipar más rápido (antes: 0.4, ahora: 0.2)
		var delayBeforeDissipate = totalAppearTime + 0.2;

		trace('[StickerTransition] Waiting ${delayBeforeDissipate}s before dissipation');

		var dissipateTimer = new FlxTimer(FlxTimer.globalManager);
		activeTimers.push(dissipateTimer); // ✅ CRÍTICO: Agregar a la lista para poder cancelarlo
		dissipateTimer.start(delayBeforeDissipate, function(timer:FlxTimer)
		{
			trace('[StickerTransition] Starting dissipation');
			
			if (transitionSprite != null)
			{
				transitionSprite.dissipateStickers(function()
				{
					trace('[StickerTransition] Dissipation complete, finishing transition');
					finish();
					
					// ✅ Llamar callback INMEDIATAMENTE - sin delay
					if (onFinished != null)
					{
						trace('[StickerTransition] Calling onFinished callback');
						onFinished();
					}
				});
			}
			else
			{
				finish();
				if (onFinished != null)
					onFinished();
			}
		});
	}

	/**
	 * Finaliza la transición
	 */
	private static function finish():Void
	{
		trace('[StickerTransition] ========== FINISHING ==========');

		isPlaying = false;
		
		// ✅ NO cancelar timers aquí - ya deberían estar completos
		// Solo limpiar la lista de referencias
		activeTimers = [];

		if (transitionSprite != null)
		{
			transitionSprite.clear();
		}

		// ✅ Limpiar Map de datos
		stickerData.clear();

		onComplete = null;

		trace('[StickerTransition] ========== FINISHED ==========');
	}

	/**
	 * Cancela la transición
	 */
	public static function cancel():Void
	{
		if (!isPlaying)
			return;

		trace('[StickerTransition] Cancelled');
		finish();
	}

	/**
	 * Invalida el cache de gráficos para que se recarguen en el próximo start().
	 * Llamar desde PlayState.destroy() para evitar crash por bitmaps dispuestos.
	 */
	public static function invalidateCache():Void
	{
		graphicsCache.clear();
		cacheLoaded = false;
		trace('[StickerTransition] Cache invalidado — se recargará en el próximo start()');
	}

	/**
	 * Recarga la configuración
	 */
	public static function reloadConfig():Void
	{
		loadConfig();
		preloadGraphics();
		trace('[StickerTransition] Config reloaded');
	}
}

/**
 * ✅ Container de OpenFL Sprite (como StickerTransitionSprite del FNF base)
 * Este sprite persiste entre cambios de state porque está en la capa de OpenFL
 */
@:access(flixel.FlxCamera)
class StickerTransitionContainer extends openfl.display.Sprite
{
	public var stickersCamera:FlxCamera;
	public var grpStickers:FlxTypedGroup<FlxSprite>;
	
	// ✅ CRÍTICO: Trackear timers de disipación para poder cancelarlos
	private var dissipationTimers:Array<FlxTimer> = [];

	public function new():Void
	{
		super();
		visible = false;
		
		// Crear cámara dedicada
		stickersCamera = new FlxCamera();
		stickersCamera.bgColor = 0x00000000; // Transparente
		addChild(stickersCamera.flashSprite);
		
		// Crear grupo
		grpStickers = new FlxTypedGroup<FlxSprite>();
		grpStickers.camera = stickersCamera;
		
		// Listener de resize
		FlxG.signals.gameResized.add((_, _) -> this.onResize());
		scrollRect = new openfl.geom.Rectangle();
		onResize();
		
		trace('[StickerTransitionContainer] Created');
	}

	public function update(elapsed:Float):Void
	{
		stickersCamera.visible = visible;
		if (!visible) return;
		
		// Actualizar stickers
		grpStickers?.update(elapsed);
		stickersCamera.update(elapsed);

		// Limpiar y renderizar
		stickersCamera?.clearDrawStack();
		stickersCamera?.canvas?.graphics.clear();

		grpStickers?.draw();

		stickersCamera.render();
	}

	/**
	 * ✅ Insertar en OpenFL (como hace el FNF base)
	 */
	public function insert():Void
	{
		// Agregar a OpenFL en un nivel alto para que esté encima de todo
		FlxG.addChildBelowMouse(this, 9999);
		visible = true;
		onResize();
		
		// ✅ Conectar update manual
		FlxG.signals.preUpdate.add(manualUpdate);
		
		trace('[StickerTransitionContainer] Inserted into OpenFL');
	}

	/**
	 * Update manual (llamado por signal)
	 */
	private function manualUpdate():Void
	{
		update(FlxG.elapsed);
	}

	/**
	 * Limpiar y remover de OpenFL
	 */
	public function clear():Void
	{
		FlxG.signals.preUpdate.remove(manualUpdate);
		FlxG.removeChild(this);
		visible = false;
		clearStickers();
		stickersCamera?.clearDrawStack();
		stickersCamera?.canvas?.graphics.clear();
		
		trace('[StickerTransitionContainer] Cleared from OpenFL');
	}

	public function onResize():Void
	{
		x = y = 0;
		scaleX = 1;
		scaleY = 1;

		// Ajustar cámara al tamaño del juego
		__scrollRect.setTo(0, 0, FlxG.camera._scrollRect.scrollRect.width, FlxG.camera._scrollRect.scrollRect.height);

		stickersCamera.onResize();
		stickersCamera._scrollRect.scrollRect = scrollRect;
	}

	public function addSticker(sticker:FlxSprite):Void
	{
		grpStickers.add(sticker);
	}

	public function clearStickers():Void
	{
		if (grpStickers != null)
		{
			// Destruir cada sticker
			for (sticker in grpStickers.members)
			{
				if (sticker != null)
				{
					FlxTween.cancelTweensOf(sticker);
					if (sticker.scale != null)
						FlxTween.cancelTweensOf(sticker.scale);
					sticker.destroy();
				}
			}
			grpStickers.clear();
		}
		
		// ✅ También cancelar timers de disipación
		cancelDissipationTimers();
	}
	
	/**
	 * ✅ Cancela todos los timers de disipación activos
	 */
	private function cancelDissipationTimers():Void
	{
		for (timer in dissipationTimers)
		{
			if (timer != null && timer.active)
			{
				timer.cancel();
			}
		}
		dissipationTimers = [];
	}

	/**
	 * Animar disipación de stickers
	 */
	public function dissipateStickers(onComplete:Void->Void):Void
	{
		if (grpStickers == null || grpStickers.members.length == 0)
		{
			if (onComplete != null)
				onComplete();
			return;
		}
		
		// ✅ Cancelar cualquier timer de disipación anterior
		cancelDissipationTimers();

		var dissipatedCount = 0;
		var totalStickers = grpStickers.members.length;
		
		// ✅ Mezclar orden de desaparición para efecto más natural
		FlxG.random.shuffle(grpStickers.members);

		// ✅ Animar desaparición escalonada más RÁPIDA
		for (i in 0...grpStickers.members.length)
		{
			var sticker = grpStickers.members[i];
			if (sticker == null || !sticker.exists)
				continue;
			
			// ✅ REDUCIDO: Timing más corto (antes: 0.6, ahora: 0.4)
			var timing = FlxMath.remapToRange(i, 0, grpStickers.members.length, 0, 0.4);
			
			// ✅ CRÍTICO: Usar globalManager y guardar referencia del timer
			var dissipationTimer = new FlxTimer(FlxTimer.globalManager);
			dissipationTimers.push(dissipationTimer);
			
			dissipationTimer.start(timing, function(timer:FlxTimer)
			{
				if (sticker == null || !sticker.exists)
					return;
				
				// ✅ Reproducir sonido al desaparecer
				StickerTransition.playRandomSound();
				
				// Cancelar tweens previos
				FlxTween.cancelTweensOf(sticker);
				if (sticker.scale != null)
					FlxTween.cancelTweensOf(sticker.scale);

				var disperseX = FlxG.random.float(-1000, 1000);
				var disperseY = FlxG.random.float(-1100, 1100);

				// ✅ REDUCIDO: Animación más rápida (antes: 0.4, ahora: 0.3)
				FlxTween.tween(sticker.scale, {x: 0.05, y: 0.05}, 0.3, {
					type: PERSIST,
					ease: FlxEase.backIn,
					onUpdate: function(tween:FlxTween)
					{
						if (sticker != null && sticker.exists)
							sticker.updateHitbox();
					},
					onComplete: function(tween:FlxTween)
					{
						dissipatedCount++;
						if (sticker != null && sticker.exists)
						{
							sticker.kill();
							sticker.destroy();
						}
						
						// Si todos terminaron, llamar callback
						if (dissipatedCount >= totalStickers && onComplete != null)
						{
							onComplete();
						}
					}
				});

				FlxTween.tween(sticker, {
					alpha: 0,
					x: sticker.x + disperseX,
					y: sticker.y + disperseY
				}, 0.3, {
					type: PERSIST,
					ease: FlxEase.cubeIn
				});
			});
		}

		trace('[StickerTransitionContainer] Dissipating $totalStickers stickers');
	}
}

// ==========================================
// TYPEDEFS
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

typedef StickerSpriteData =
{
	var targetScale:Float;
	var targetAngle:Float;
}