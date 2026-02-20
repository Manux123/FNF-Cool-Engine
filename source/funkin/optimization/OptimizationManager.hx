package funkin.optimization;

import flixel.FlxG;
import flixel.FlxCamera;
import funkin.gameplay.notes.NotePool;
import funkin.gameplay.notes.Note;

/**
 * OptimizationManager — coordina NotePool, GPURenderer y calidad adaptativa.
 *
 * ─── Optimizaciones ──────────────────────────────────────────────────────────
 * • FPS medido con un acumulador de elapsed en vez de `1.0/FlxG.elapsed`
 *   (más estable y sin división flotante por frame).
 * • `haxe.Timer.stamp()` solo se llama cuando `trackTiming` está activo.
 * • Wrappers `spawnNote/recycleNote` eliminados — callers acceden a NotePool directamente.
 * • Adaptive quality usa histéresis real (no resetea contadores al estabilizarse).
 */
class OptimizationManager
{
	public var gpuRenderer:GPURenderer;
	public var qualityLevel:QualityLevel = QualityLevel.HIGH;

	// ─── Adaptive quality ─────────────────────────────────────────────────────
	public var enableAdaptiveQuality:Bool = true;
	public var targetFPS:Int = 60;

	/** Activar para medir update/render time (desactivado por defecto — tiene coste). */
	public var trackTiming:Bool = false;

	static inline var LOW_FPS_THRESHOLD = 120; // frames bajo FPS antes de bajar calidad
	static inline var HIGH_FPS_THRESHOLD = 240; // frames alto FPS antes de subir calidad

	var _lowFrames:Int = 0;
	var _highFrames:Int = 0;

	// FPS suavizado (acumulador de elapsed)
	var _fpsAccum:Float = 0;
	var _fpsFrames:Int = 0;
	var _smoothFPS:Int = 60;

	// Timing (solo cuando trackTiming=true)
	public var updateTime:Float = 0;
	public var renderTime:Float = 0;

	var _initialized:Bool = false;

	// ─── Init ─────────────────────────────────────────────────────────────────

	public function new()
	{
	}

	public function init(?camera:FlxCamera):Void
	{
		if (_initialized)
			return;

		NotePool.init();
		gpuRenderer = new GPURenderer(camera ?? FlxG.camera);
		applyQualitySettings();

		_initialized = true;
		trace('[OptimizationManager] Listo. Calidad: $qualityLevel');
	}

	// ─── Update ───────────────────────────────────────────────────────────────

	public function update(elapsed:Float):Void
	{
		if (!_initialized)
			return;

		// Acumular FPS suavizado (más preciso que 1/elapsed)
		_fpsAccum += elapsed;
		_fpsFrames += 1;

		if (_fpsAccum >= 0.5) // muestrear cada 0.5 s
		{
			_smoothFPS = Math.round(_fpsFrames / _fpsAccum);
			_fpsAccum = 0;
			_fpsFrames = 0;
		}

		if (!enableAdaptiveQuality)
			return;

		final tgt = targetFPS;

		if (_smoothFPS < tgt - 10)
		{
			_highFrames = 0;
			_lowFrames++;
			if (_lowFrames > LOW_FPS_THRESHOLD)
			{
				lowerQuality();
				_lowFrames = 0;
			}
		}
		else if (_smoothFPS > tgt + 10)
		{
			_lowFrames = 0;
			_highFrames++;
			if (_highFrames > HIGH_FPS_THRESHOLD)
			{
				raiseQuality();
				_highFrames = 0;
			}
		}
		// No resetear contadores al estar en rango — histéresis real
	}

	public function addSpriteToRenderer(sprite:flixel.FlxSprite):Void
	{
		if (gpuRenderer != null && gpuRenderer.enabled)
		{
			gpuRenderer.addSprite(sprite);
		}
	}

	public function render():Void
	{
		if (!_initialized || gpuRenderer == null)
			return;

		if (trackTiming)
		{
			final t = haxe.Timer.stamp();
			gpuRenderer.render();
			renderTime = haxe.Timer.stamp() - t;
		}
		else
		{
			gpuRenderer.render();
		}
	}

	// ─── Calidad ──────────────────────────────────────────────────────────────

	public function setQuality(level:QualityLevel):Void
	{
		if (qualityLevel == level)
			return;
		qualityLevel = level;
		applyQualitySettings();
		trace('[OptimizationManager] Calidad → $qualityLevel');
	}

	function lowerQuality():Void
	{
		switch (qualityLevel)
		{
			case ULTRA:
				setQuality(HIGH);
			case HIGH:
				setQuality(MEDIUM);
			case MEDIUM:
				setQuality(LOW);
			case LOW:
				trace('[OptimizationManager] Calidad mínima alcanzada.');
		}
	}

	function raiseQuality():Void
	{
		switch (qualityLevel)
		{
			case LOW:
				setQuality(MEDIUM);
			case MEDIUM:
				setQuality(HIGH);
			case HIGH:
				setQuality(ULTRA);
			case ULTRA:
				trace('[OptimizationManager] Calidad máxima alcanzada.');
		}
	}

	function applyQualitySettings():Void
	{
		if (gpuRenderer == null)
			return;
		gpuRenderer.enabled = true;
		gpuRenderer.enableCulling = true;
		gpuRenderer.enableZSorting = (qualityLevel == ULTRA || qualityLevel == HIGH);
	}

	// ─── Limpieza ─────────────────────────────────────────────────────────────

	public function clear():Void
	{
		if (!_initialized)
			return;
		NotePool.clear();
		gpuRenderer?.clear();
	}

	public function destroy():Void
	{
		if (!_initialized)
			return;
		NotePool.destroy();
		if (gpuRenderer != null)
		{
			gpuRenderer.destroy();
			gpuRenderer = null;
		}
		_initialized = false;
	}

	// ─── Stats ────────────────────────────────────────────────────────────────

	public function getFullStats():String
	{
		var s = '=== OPT STATS ===\n' + 'Quality=$qualityLevel  FPS=$_smoothFPS  TargetFPS=$targetFPS\n';
		if (trackTiming)
			s += 'Update=${Math.round(updateTime * 1e6)}μs  Render=${Math.round(renderTime * 1e6)}μs\n';
		s += NotePool.getStats() + '\n';
		if (gpuRenderer != null)
			s += gpuRenderer.getStats();
		return s;
	}
}

enum QualityLevel
{
	ULTRA;
	HIGH;
	MEDIUM;
	LOW;
}
