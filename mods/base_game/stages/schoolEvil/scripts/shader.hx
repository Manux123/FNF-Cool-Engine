var shadersEnabled = true;

function _applyShader(name:String, shader:String)
{
    var spr = stage.getElement(name);
    if (spr == null)
    {
        trace('[shader] WARN: "' + name + '" not found, ignorando.');
        return;
    }
    ShaderManager.applyShader(spr, shader);
    trace('[shader] OK: shader aplicado a "' + name + '"');
}

function onStageCreate()
{
    shadersEnabled = FlxG.save.data.shaders;
    if (!shadersEnabled)
        return;

    new FlxTimer().start(0.0, function(_) {
        try
        {
            _applyShader('weebBackTrees', 'evilSchoolWarp');
            _applyShader('weebSchool',    'evilSchoolWarp');
            _applyShader('weebStreet',    'evilSchoolWarp');
            _applyShader('weebTrees',     'evilSchoolWarp');
            ShaderManager.setShaderParam("evilSchoolWarp", "uTime", [0.0]);
        }
        catch (e:Dynamic)
        {
            trace('[shader] WARN onStageCreate timer: ' + e);
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
        ShaderManager.setShaderParam("evilSchoolWarp", "uTime", [warpTime]);
    }
    catch (e:Dynamic)
    {
        trace('[shader] WARN onUpdate uTime: ' + e);
    }
}

function onDestroy()
{
    // Deshabilitar PRIMERO para cortar onUpdate en seco,
    // luego limpiar el mapa antes de que los sprites sean destruidos.
    shadersEnabled = false;
    ShaderManager.clearSpriteShaders();
}
