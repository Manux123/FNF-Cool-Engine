var _sineTime:Float = 0.0;
var _evilTrail = null;
var _destroyed = false;

function postCreate()
{
    _evilTrail = new FlxTrail(dad, null, 4, 24, 0.3, 0.069);
    if (FlxG.save.data.specialVisualEffects)
        add(_evilTrail);
}

function onUpdate(elapsed:Float)
{
    if (_destroyed) return;
    try
    {
        if (dad == null || !dad.exists) return;
        _sineTime += elapsed;
        dad.y += Math.sin(_sineTime * 2.0) * 3.0 * elapsed * 60.0 / 2.8;
    }
    catch(_) { _destroyed = true; }
}

function onDestroy()
{
    _destroyed = true;
    // Desconectar el trail de dad ANTES de que los objetos se destruyan
    // para que no intente leer la posición de un sprite inválido
    try
    {
        if (_evilTrail != null)
        {
            _evilTrail.kill();
            _evilTrail.destroy();
            _evilTrail = null;
        }
    }
    catch(_) {}
}