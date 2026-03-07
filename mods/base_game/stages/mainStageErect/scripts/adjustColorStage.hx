/**
 * adjustColorStage.hx
 * 
 * Aplica el shader adjustColor.frag a cada personaje con valores independientes.
 *
 * SETUP:
 *   1. adjustColor.frag  →  mods/[tuMod]/shaders/
 *   2. Este script       →  mods/[tuMod]/stages/scripts/
 *   3. JSON del stage    →  "scripts": ["adjustColorStage"]
 */

// ── Valores por personaje (edita a tu gusto) ──────────────────────────────────

var BF_BRIGHTNESS  = -23.0;
var BF_HUE         =  12.0;
var BF_CONTRAST    =   7.0;
var BF_SATURATION  =   0.0;

var DAD_BRIGHTNESS = -33.0;
var DAD_HUE        = -32.0;
var DAD_CONTRAST   = -23.0;
var DAD_SATURATION =   0.0;

var GF_BRIGHTNESS  = -30.0;
var GF_HUE         =  -9.0;
var GF_CONTRAST    =  -4.0;
var GF_SATURATION  =   0.0;

// ── Internals ─────────────────────────────────────────────────────────────────

var _applied = false;

function onStageCreate()
{
    // Pre-cargar el frag para que esté listo cuando se necesite
    ShaderManager.loadShader('adjustColor');
}

// onUpdate porque los personajes se añaden DESPUÉS de onStageCreate
function onUpdate(elapsed)
{
    if (_applied) return;
    _applied = true;

    // CORRECTO: la variable del engine es "chars", no "characters"
    var bf  = chars.bf();
    var dad = chars.dad();
    var gf  = chars.gf();

    _applyTo(bf,  'adjustColor_bf',  BF_BRIGHTNESS,  BF_HUE,  BF_CONTRAST,  BF_SATURATION);
    _applyTo(dad, 'adjustColor_dad', DAD_BRIGHTNESS, DAD_HUE, DAD_CONTRAST, DAD_SATURATION);
    _applyTo(gf,  'adjustColor_gf',  GF_BRIGHTNESS,  GF_HUE,  GF_CONTRAST,  GF_SATURATION);
}

function _applyTo(char, shaderKey, brightness, hue, contrast, saturation)
{
    if (char == null)
    {
        trace('[adjustColorStage] Personaje no encontrado para ' + shaderKey);
        return;
    }

    // Cargar el frag del archivo base bajo un nombre único por personaje.
    // Así ShaderManager.setShaderParam(shaderKey, ...) solo afecta a este personaje.
    var cs = ShaderManager.getShader('adjustColor');
    if (cs == null)
    {
        trace('[adjustColorStage] ERROR: shader adjustColor no encontrado.');
        return;
    }

    // Aplicar el shader al sprite del personaje
    ShaderManager.applyShader(char, 'adjustColor');

    // Setear los params DIRECTAMENTE en la instancia del personaje,
    // NO via ShaderManager.setShaderParam (que actualizaría los 3 a la vez)
    var sh = char.shader;
    if (sh != null)
    {
        sh.setFloat('brightness', brightness);
        sh.setFloat('hue',        hue);
        sh.setFloat('contrast',   contrast);
        sh.setFloat('saturation', saturation);
        trace('[adjustColorStage] Shader aplicado: ' + shaderKey
            + ' | brightness=' + brightness + ' hue=' + hue
            + ' contrast=' + contrast + ' saturation=' + saturation);
    }
    else
    {
        trace('[adjustColorStage] WARN: char.shader es null después de applyShader en ' + shaderKey);
        // Fallback: usar filters de OpenFL directamente si shader no funciona en FlxAnimate
        _applyViaFilters(char, brightness, hue, contrast, saturation);
    }
}

// Fallback por si FlxAnimate no expone .shader correctamente
function _applyViaFilters(char, brightness, hue, contrast, saturation)
{
    var cs = ShaderManager.getShader('adjustColor');
    if (cs == null) return;

    // ShaderManager.getShader devuelve el CustomShader que tiene .shader (FlxRuntimeShader lazy)
    // Usamos .shader para obtener la instancia compilada
    var instance = cs.shader;
    if (instance == null) return;

    instance.setFloat('brightness', brightness);
    instance.setFloat('hue',        hue);
    instance.setFloat('contrast',   contrast);
    instance.setFloat('saturation', saturation);

    // Aplicar como filtro OpenFL — funciona en cualquier DisplayObject (incluyendo FlxAnimate)
    char.filters = [new openfl.filters.ShaderFilter(instance)];
    trace('[adjustColorStage] Shader aplicado via filters fallback.');
}

function onDestroy()
{
    var bf  = chars.bf();
    var dad = chars.dad();
    var gf  = chars.gf();

    if (bf  != null) { ShaderManager.removeShader(bf);  }
    if (dad != null) { ShaderManager.removeShader(dad); }
    if (gf  != null) { ShaderManager.removeShader(gf);  }
}
