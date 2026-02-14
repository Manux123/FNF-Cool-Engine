var upperBopper = null;
var downBopper = null;
var santa = null;

function onCreate()
{
	trace('[Mall] Loaded');
}

function onStageCreate()
{
	if (stage != null)
	{
		upperBopper = stage.getElement('upperBoppers');
		downBopper = stage.getElement('bottomBoppers');
		santa = stage.getElement('santa');
	}
}

function onBeatHit(beat)
{
	upperBopper.animation.play('bop', true);
	downBopper.animation.play('bop', true);
	santa.animation.play('idle', true);
}