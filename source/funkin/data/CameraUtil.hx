package funkin.data;

import flixel.FlxG;
import flixel.FlxCamera;
import flixel.system.FlxAssets.FlxShader;
import openfl.filters.BitmapFilter;
import openfl.filters.ShaderFilter;

/**
 * CameraUtil — helpers para manipular FlxCamera de forma segura y consistente.
 *
 * Usa `@:access(flixel.FlxCamera)` a nivel de clase en vez de esparcir
 * `@:privateAccess` por todo el código base — patrón tomado de NightmareVision.
 * Esto también es lo que causaba el error de compilación:
 *   "flixel.FlxCamera has no field filters (Suggestion: _filters)"
 * La API pública de FlxCamera en Flixel 5.x expone `_filters`, no `filters`.
 * Esta clase centraliza todos los accesos a ese campo.
 *
 * @author  Cool Engine Team
 * @since   0.5.1
 */
@:access(flixel.FlxCamera)
class CameraUtil
{
	// ── Creación ──────────────────────────────────────────────────────────────

	/**
	 * Crea una cámara nueva con bgColor transparente y opcionalmente la añade
	 * al stack de FlxG.cameras.
	 * @param addToStack  Si true (default), la añade como cámara NO-default.
	 */
	public static function create(addToStack:Bool = true):FlxCamera
	{
		var cam:FlxCamera = new FlxCamera();
		cam.bgColor = 0x00000000; // transparente — no gasta fill-rect cada frame
		if (addToStack)
			FlxG.cameras.add(cam, false);
		return cam;
	}

	// ── Filtros / Shaders ─────────────────────────────────────────────────────

	/**
	 * Devuelve el array de filtros de la cámara, creándolo si no existe.
	 * Usa el campo interno `_filters` correctamente.
	 */
	public static inline function getFilters(cam:FlxCamera):Array<BitmapFilter>
	{
		if (cam._filters == null) cam._filters = [];
		return cam._filters;
	}

	/**
	 * Reemplaza TODOS los filtros de la cámara de una vez.
	 * Pasa null o array vacío para quitar todos los filtros
	 * (evita el render-pass off-screen innecesario).
	 */
	public static inline function setFilters(cam:FlxCamera, filters:Array<BitmapFilter>):Void
	{
		cam._filters = (filters != null && filters.length > 0) ? filters : null;
	}

	/**
	 * Añade un shader a la cámara.
	 * @param cam     Cámara destino. Default: FlxG.camera.
	 * @param shader  Shader a aplicar.
	 * @return El ShaderFilter creado (para poder quitarlo después).
	 */
	public static function addShader(shader:FlxShader, ?cam:FlxCamera):ShaderFilter
	{
		cam ??= FlxG.camera;
		var filter:ShaderFilter = new ShaderFilter(shader);
		if (cam._filters == null) cam._filters = [];
		cam._filters.push(filter);
		return filter;
	}

	/**
	 * Elimina un shader de la cámara por referencia al ShaderFilter.
	 * @return true si se eliminó correctamente.
	 */
	public static function removeFilter(filter:BitmapFilter, ?cam:FlxCamera):Bool
	{
		cam ??= FlxG.camera;
		if (cam._filters == null) return false;
		var removed:Bool = cam._filters.remove(filter);
		// Limpia el array si quedó vacío — evita render pass off-screen vacío
		if (cam._filters.length == 0) cam._filters = null;
		return removed;
	}

	/**
	 * Elimina todos los filtros de la cámara.
	 */
	public static inline function clearFilters(?cam:FlxCamera):Void
	{
		cam ??= FlxG.camera;
		cam._filters = null;
	}

	/**
	 * Elimina filtros vacíos o nulos del array interno.
	 * Útil para limpiar sin quitar filtros activos.
	 */
	public static function pruneEmptyFilters(?cam:FlxCamera):Void
	{
		cam ??= FlxG.camera;
		if (cam._filters == null) return;
		cam._filters = cam._filters.filter(f -> f != null);
		if (cam._filters.length == 0) cam._filters = null;
	}

	// ── Optimización ──────────────────────────────────────────────────────────

	/**
	 * Aplica configuración de renderizado óptima a una cámara de gameplay.
	 * - Sin filtros vacíos (evita el off-screen render pass).
	 * - bgColor transparente (evita fill-rect si hay otra cámara de fondo).
	 *
	 * No llamar en la cámara principal si ésta es la única — necesita clear.
	 */
	public static function optimizeForGameplay(cam:FlxCamera):Void
	{
		if (cam == null) return;
		pruneEmptyFilters(cam);
	}

	/**
	 * Devuelve la última cámara del stack (la del HUD normalmente).
	 */
	public static var lastCamera(get, never):FlxCamera;
	static inline function get_lastCamera():FlxCamera
		return FlxG.cameras.list[FlxG.cameras.list.length - 1];
}
