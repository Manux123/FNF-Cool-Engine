// schoolErect.hx — Stage script portado de V-Slice a Cool Engine
// Requiere ScriptAPI con setFilters / makeShaderFilter expuestos.

var _shBF  = null;
var _shGF  = null;
var _shDad = null;
var _initialized = false;

function onUpdate(elapsed)
{
    if (_initialized) return;
    _initialized = true;
    _setupBF();
    _setupGF();
    _setupDad();
}

function onDestroy()
{
    clearFilters(boyfriend);
    clearFilters(gf);
    clearFilters(dad);
    _shBF  = null;
    _shGF  = null;
    _shDad = null;
}

function _applyFilter(sprite, shader)
{
    if (sprite == null || shader == null) return false;
    shader.uFrameBounds.value = [0.0, 0.0, 1.0, 1.0];
    shader.angOffset.value    = [0.0];
    var filter = makeShaderFilter(shader);
    if (filter == null) return false;
    setFilters(sprite, [filter]);
    return true;
}

function _setupBF()
{
    if (boyfriend == null) { trace("[schoolErect] BF null"); return; }
    var rim = new DropShadowShader();
    rim.setAdjustColor(-66, -10, 24, -23);
    rim.color        = 0xFF52351D;
    rim.antialiasAmt = 0;
    rim.distance     = 5;
    rim.angle        = 90;
    rim.strength     = 1;
    rim.threshold    = 0.1;
    rim.useAltMask   = false;
    if (_applyFilter(boyfriend, rim)) { _shBF = rim; trace("[schoolErect] BF OK"); }
    else trace("[schoolErect] BF FAIL");
}

function _setupGF()
{
    if (gf == null) { trace("[schoolErect] GF null"); return; }
    var rim = new DropShadowShader();
    rim.setAdjustColor(-42, -10, 5, -25);
    rim.color        = 0xFF52351D;
    rim.antialiasAmt = 0;
    rim.distance     = 3;
    rim.angle        = 90;
    rim.threshold    = 0.3;
    rim.strength     = 1;
    rim.useAltMask   = false;
    if (_applyFilter(gf, rim)) { _shGF = rim; trace("[schoolErect] GF OK"); }
    else trace("[schoolErect] GF FAIL");
}

function _setupDad()
{
    if (dad == null) { trace("[schoolErect] Dad null"); return; }
    var rim = new DropShadowShader();
    rim.setAdjustColor(-66, -10, 24, -23);
    rim.color        = 0xFF52351D;
    rim.antialiasAmt = 0;
    rim.distance     = 5;
    rim.angle        = 90;
    rim.strength     = 1;
    rim.threshold    = 0.1;
    rim.useAltMask   = false;
    if (_applyFilter(dad, rim)) { _shDad = rim; trace("[schoolErect] Dad OK"); }
    else trace("[schoolErect] Dad FAIL");
}
