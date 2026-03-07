var shadersEnabled = true;

// Sprites del stage que reciben el shader
var TARGETS = ['weebBackTrees', 'weebSchool', 'weebStreet', 'weebTrees'];

function _applyShader(name:String)
{
    var spr = stage.getElement(name);
    if (spr == null)
    {
        trace('[shader] "' + name + '" no encontrado, ignorando.');
        return;
    }
    ShaderManager.applyShader(spr, 'evilSchoolWarp');
    trace('[shader] OK: shader aplicado a "' + name + '"');
}

function onStageCreate()
{
    shadersEnabled = FlxG.save.data.shaders;
    if (!shadersEnabled) return;

    new FlxTimer().start(0.0, function(_) {
        try
        {
            for (name in TARGETS)
                _applyShader(name);

            // Solo uTime necesita inicializarse; las demás constantes
            // están embebidas en el GLSL y no dependen de setShaderParam.
            ShaderManager.setShaderParam('evilSchoolWarp', 'uTime', warpTime);
        }
        catch (e:Dynamic)
        {
            trace('[shader] WARN onStageCreate: ' + e);
        }
    }, 1);
}

var warpTime:Float = 0.0;

function onUpdate(elapsed:Float)
{
    if (!shadersEnabled) return;
    warpTime += elapsed;
    try
    {
        ShaderManager.setShaderParam('evilSchoolWarp', 'uTime', warpTime);
    }
    catch (e:Dynamic)
    {
        trace('[shader] WARN onUpdate: ' + e);
    }
}

function onDestroy()
{
    shadersEnabled = false;
    ShaderManager.clearSpriteShaders();
}
