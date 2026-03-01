var girls = null;

function onStageCreate()
{
    var crowd  = stage.getElement('crowd');
    var crowd2 = stage.getElement('crowd2');

    if (SONG.song.toLowerCase() == 'roses')
    {
        girls = crowd2;
        crowd2.visible = true;
        crowd.visible = false;
    }
    else
    {
        girls = crowd;
        crowd.visible = true;
        crowd2.visible = false;
    }
}

var danceDir = false;

function onBeatHit(beat)
{
	danceDir = !danceDir;

	if (danceDir)
		girls.animation.play('danceRight', true);
	else
		girls.animation.play('danceLeft', true);
}