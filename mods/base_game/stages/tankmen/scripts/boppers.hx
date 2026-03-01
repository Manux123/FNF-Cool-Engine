var tank0 = null;
var tank1 = null;
var tank2 = null;
var tank3 = null;
var tank4 = null;
var tank5 = null;
var watchtower = null;

function onCreate()
{
	trace('[Boppers Tank] Loaded script');
}

function onStageCreate()
{
	trace('[Boppers Tank] Getting elements...');

	if (stage != null)
	{
		tank0 = stage.getElement('tank0');
		tank1 = stage.getElement('tank1');
		tank2 = stage.getElement('tank2');
		tank3 = stage.getElement('tank3');
		tank4 = stage.getElement('tank4');
		tank5 = stage.getElement('tank5');
		watchtower = stage.getElement('tankTower');
	}
}

function onBeatHit(beat)
{
	tank0.animation.play("idle");
	tank1.animation.play("idle");
	tank2.animation.play("idle");
	tank3.animation.play("idle");
	tank4.animation.play("idle");
	tank5.animation.play("idle");
	watchtower.animation.play("idle");
}