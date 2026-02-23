function postCreate()
{
    var evilTrail = new FlxTrail(dad, null, 4, 24, 0.3, 0.069);
    if (FlxG.save.data.specialVisualEffects)
	    add(evilTrail);
}

function onUpdate(elapsed)
{
    if (dad != null)
        dad.y += Mathf.sineByTime(elapsed);
}