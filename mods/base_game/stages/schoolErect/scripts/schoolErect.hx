// schoolErect.hx — Stage script portado de V-Slice a Cool Engine
// Ubicación: mods/base_game/stages/schoolErect/scripts/schoolErect.hx
//
// NOTA: el shader se aplica via sprite.filters (ShaderFilter), NO via sprite.shader.
// FlxAnimate ignora/rompe sprite.shader en algunos paths de render.
// Con filters, el shader recibe el sprite ya rasterizado → uFrameBounds = [0,0,1,1] fijo.

// Refs a los ShaderFilter para poder actualizarlos en onUpdate
var _rimBF:Dynamic  = null;
var _rimGF:Dynamic  = null;
var _rimDad:Dynamic = null;

// Refs a los shaders para llamar updateFrameInfo cada frame
var _shBF:Dynamic  = null;
var _shGF:Dynamic  = null;
var _shDad:Dynamic = null;

var _initialized = false;

// Clase ShaderFilter obtenida via reflexión (no está expuesta directamente en scripts)
var _ShaderFilter:Dynamic = Type.resolveClass("openfl.filters.ShaderFilter");

function onUpdate(elapsed)
{
	if (!_initialized)
	{
		_initialized = true;
		_setupBF();
		_setupGF();
		_setupDad();
	}

	// Con filters el shader procesa el sprite ya renderizado,
	// pero seguimos actualizando uFrameBounds en caso de que el
	// shader use esta info para el offset del shadow.
	// Si el frame es null, simplemente omitimos la actualización.
	if (_shBF != null && boyfriend != null && boyfriend.frame != null)
		_shBF.updateFrameInfo(boyfriend.frame);

	if (_shGF != null && gf != null && gf.frame != null)
		_shGF.updateFrameInfo(gf.frame);

	if (_shDad != null && dad != null && dad.frame != null)
		_shDad.updateFrameInfo(dad.frame);
}

function onDestroy()
{
	// Quitar filtros al destruir
	if (boyfriend != null) Reflect.setProperty(boyfriend, "filters", null);
	if (gf != null)        Reflect.setProperty(gf, "filters", null);
	if (dad != null)       Reflect.setProperty(dad, "filters", null);

	_rimBF  = null;
	_rimGF  = null;
	_rimDad = null;
	_shBF   = null;
	_shGF   = null;
	_shDad  = null;
}

// ─── Helper: crea el ShaderFilter y lo aplica al sprite ──────────────────────

function _applyFilter(sprite:Dynamic, shader:Dynamic):Dynamic
{
	if (_ShaderFilter == null || sprite == null || shader == null)
		return null;

	// Con filters el shader recibe el sprite rasterizado completo → UVs = [0,0,1,1]
	shader.uFrameBounds.value = [0.0, 0.0, 1.0, 1.0];
	shader.angOffset.value    = [0.0];

	var filter:Dynamic = Type.createInstance(_ShaderFilter, [shader]);
	Reflect.setProperty(sprite, "filters", [filter]);
	return filter;
}

// ─── Setup por personaje ─────────────────────────────────────────────────────

function _setupBF()
{
	if (boyfriend == null)
	{
		trace("[schoolErect] BF es null, saltando shader");
		return;
	}

	var rim = new DropShadowShader();
	rim.setAdjustColor(-66, -10, 24, -23);
	rim.color        = 0xFF52351D;
	rim.antialiasAmt = 0;
	rim.distance     = 5;
	rim.angle        = 90;
	rim.strength     = 1;
	rim.useAltMask   = false;

	var filter = _applyFilter(boyfriend, rim);
	if (filter != null)
	{
		_shBF  = rim;
		_rimBF = filter;
		trace("[schoolErect] DropShadowShader (filter) aplicado a BF (" + boyfriend.curCharacter + ")");
	}
	else
	{
		trace("[schoolErect] ADVERTENCIA: no se pudo aplicar filtro a BF (ShaderFilter no disponible)");
	}
}

function _setupGF()
{
	if (gf == null)
	{
		trace("[schoolErect] GF es null, saltando shader");
		return;
	}

	var rim = new DropShadowShader();
	rim.setAdjustColor(-42, -10, 5, -25);
	rim.color        = 0xFF52351D;
	rim.antialiasAmt = 0;
	rim.distance     = 3;
	rim.angle        = 90;
	rim.threshold    = 0.3;
	rim.strength     = 1;
	rim.useAltMask   = false;

	var filter = _applyFilter(gf, rim);
	if (filter != null)
	{
		_shGF  = rim;
		_rimGF = filter;
		trace("[schoolErect] DropShadowShader (filter) aplicado a GF (" + gf.curCharacter + ")");
	}
	else
	{
		trace("[schoolErect] ADVERTENCIA: no se pudo aplicar filtro a GF");
	}
}

function _setupDad()
{
	if (dad == null)
	{
		trace("[schoolErect] Dad es null, saltando shader");
		return;
	}

	var rim = new DropShadowShader();
	rim.setAdjustColor(-66, -10, 24, -23);
	rim.color        = 0xFF52351D;
	rim.antialiasAmt = 0;
	rim.distance     = 5;
	rim.angle        = 90;
	rim.strength     = 1;
	rim.useAltMask   = false;

	var filter = _applyFilter(dad, rim);
	if (filter != null)
	{
		_shDad  = rim;
		_rimDad = filter;
		trace("[schoolErect] DropShadowShader (filter) aplicado a Dad (" + dad.curCharacter + ")");
	}
	else
	{
		trace("[schoolErect] ADVERTENCIA: no se pudo aplicar filtro a Dad");
	}
}
