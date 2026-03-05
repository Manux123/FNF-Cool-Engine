var shadersEnabled = true;

// Sprites del stage que reciben el shader
var TARGETS = ['weebBackTrees', 'weebSchool', 'weebStreet', 'weebTrees'];

function _applyShader(name:String, shader:String)
{
    var spr = stage.getElement(name);
    if (spr == null)
    {
        trace('[shader] "' + name + '" no encontrado, ignorando.');
        return;
    }
    ShaderManager.applyShader(spr, shader);
    trace('[shader] OK: shader aplicado a "' + name + '"');
}

function _setDefaults()
{
    // Setear todos los uniforms con sus valores por defecto
    // (el .frag ya NO usa def() — depende de que estos valores estén seteados)
    ShaderManager.setShaderParam('evilSchoolWarp', 'uTime',     0.0);
    ShaderManager.setShaderParam('evilSchoolWarp', 'uWaveX',    0.006);
    ShaderManager.setShaderParam('evilSchoolWarp', 'uWaveY',    0.004);
    ShaderManager.setShaderParam('evilSchoolWarp', 'uFreqX',    8.0);
    ShaderManager.setShaderParam('evilSchoolWarp', 'uFreqY',    6.0);
    ShaderManager.setShaderParam('evilSchoolWarp', 'uSpeedX',   1.2);
    ShaderManager.setShaderParam('evilSchoolWarp', 'uSpeedY',   0.9);
    ShaderManager.setShaderParam('evilSchoolWarp', 'uRipple',   0.003);
    ShaderManager.setShaderParam('evilSchoolWarp', 'uVignette', 0.5);
}

function onStageCreate()
{
    shadersEnabled = FlxG.save.data.shaders;
    if (!shadersEnabled) return;

    new FlxTimer().start(0.0, function(_) {
        try
        {
            for (name in TARGETS)
                _applyShader(name, 'evilSchoolWarp');

            _setDefaults();
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
