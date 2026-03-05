package shaders;

import flixel.FlxSprite;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.util.FlxColor;

/**
 * MaskEffect — API de alto nivel para aplicar máscaras a sprites y objetos.
 *
 * Inspirado en V-Slice (LeftMaskShader / AngleMask) pero unificado en una sola
 * clase con todos los tipos de máscara disponibles en MaskShader.
 *
 * Uso básico:
 * ```haxe
 * var mask = new MaskEffect(mySprite);
 * mask.cropLeft(100);              // ocultar los primeros 100px desde la izquierda
 * mask.cropRect(10, 10, 200, 100); // recorte rectangular
 * mask.circle(160, 120, 80);       // máscara circular
 * mask.angle(90, 100);             // máscara angular (como V-Slice AngleMask)
 * mask.remove();                   // quitar máscara
 * ```
 *
 * También se puede usar como ShaderFilter en una cámara:
 * ```haxe
 * var effect = new MaskEffect();
 * effect.cropLeft(400);
 * FlxG.camera.filters = [effect.asFilter()];
 * ```
 */
class MaskEffect
{
	public var shader(default, null):MaskShader;

	var _target:FlxSprite;

	// ── Constructor ──────────────────────────────────────────────────────────

	/**
	 * @param target  Sprite al que aplicar la máscara.
	 *                Si es null, crea solo el shader sin aplicarlo.
	 */
	public function new(?target:FlxSprite)
	{
		shader  = new MaskShader();
		_target = target;
		if (target != null)
			target.shader = shader;
	}

	// ── API pública ──────────────────────────────────────────────────────────

	/**
	 * Recorte por el lado izquierdo.
	 * Todo lo que esté a la IZQUIERDA de `x` (en px del sprite) se oculta.
	 * Equivalente a V-Slice LeftMaskShader.
	 * @param x        Posición horizontal del borde de corte (pixels).
	 * @param softness Suavizado del borde [0 = duro].
	 */
	public function cropLeft(x:Float, softness:Float = 0.0):MaskEffect
	{
		shader.maskType    = LEFT;
		shader.maskEdgePx  = x;
		shader.softness    = softness;
		shader.inverted    = false;
		return this;
	}

	/** Recorte por el lado derecho — oculta lo que esté a la DERECHA de `x`. */
	public function cropRight(x:Float, softness:Float = 0.0):MaskEffect
	{
		shader.maskType   = RIGHT;
		shader.maskEdgePx = x;
		shader.softness   = softness;
		shader.inverted   = false;
		return this;
	}

	/** Recorte desde arriba — oculta lo que esté ENCIMA de `y`. */
	public function cropTop(y:Float, softness:Float = 0.0):MaskEffect
	{
		shader.maskType   = TOP;
		shader.maskEdgePx = y;
		shader.softness   = softness;
		shader.inverted   = false;
		return this;
	}

	/** Recorte desde abajo — oculta lo que esté DEBAJO de `y`. */
	public function cropBottom(y:Float, softness:Float = 0.0):MaskEffect
	{
		shader.maskType   = BOTTOM;
		shader.maskEdgePx = y;
		shader.softness   = softness;
		shader.inverted   = false;
		return this;
	}

	/**
	 * Máscara rectangular — muestra solo el área dentro del rectángulo.
	 * @param x, y    Esquina superior-izquierda en pixels.
	 * @param w, h    Ancho y alto en pixels.
	 */
	public function cropRect(x:Float, y:Float, w:Float, h:Float, softness:Float = 0.0):MaskEffect
	{
		shader.maskType = RECT;
		shader.maskRect = new FlxRect(x, y, w, h);
		shader.softness = softness;
		shader.inverted = false;
		return this;
	}

	/**
	 * Máscara circular / elíptica.
	 * @param cx, cy  Centro en pixels.
	 * @param rx      Radio horizontal. Si ry no se especifica, usa rx (círculo).
	 * @param ry      Radio vertical.
	 */
	public function circle(cx:Float, cy:Float, rx:Float, ?ry:Float, softness:Float = 0.005):MaskEffect
	{
		shader.maskType       = CIRCLE;
		shader.circleCenterPx = new FlxPoint(cx, cy);
		shader.circleRadiusPx = new FlxPoint(rx, ry != null ? ry : rx);
		shader.softness       = softness;
		shader.inverted       = false;
		return this;
	}

	/**
	 * Máscara angular, port de V-Slice AngleMask.
	 * Muestra los píxeles dentro del ángulo formado desde la esquina (0,0)
	 * hasta el punto (endX, endY) en pixels del sprite.
	 * @param endX, endY  Punto final del ángulo en pixels.
	 */
	public function angle(endX:Float, endY:Float):MaskEffect
	{
		shader.maskType   = ANGLE;
		shader.angleEndPx = new FlxPoint(endX, endY);
		shader.inverted   = false;
		return this;
	}

	/**
	 * Invierte la máscara actual (muestra lo que antes se ocultaba y viceversa).
	 */
	public function invert(v:Bool = true):MaskEffect
	{
		shader.inverted = v;
		return this;
	}

	/**
	 * Quita la máscara del sprite asociado.
	 */
	public function remove():Void
	{
		if (_target != null)
			_target.shader = null;
	}

	/**
	 * Re-aplica la máscara al sprite asociado (útil si se llamó remove() antes).
	 */
	public function apply(?target:FlxSprite):Void
	{
		if (target != null) _target = target;
		if (_target != null) _target.shader = shader;
	}

	/**
	 * Devuelve un ShaderFilter para usarlo en cámaras u otros DisplayObjects.
	 */
	public function asFilter():openfl.filters.ShaderFilter
	{
		return new openfl.filters.ShaderFilter(cast shader);
	}
}
