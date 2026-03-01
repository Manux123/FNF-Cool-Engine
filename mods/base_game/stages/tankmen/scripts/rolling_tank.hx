var tank = null;

var offsetX:Float = 400;
var offsetY:Float = 1300;
var tankSpeed:Float = 0;
var tankAngle:Float = 0;

function onCreate()
{
	trace('[Rolling Tank] Loaded script');
    
    tankSpeed = FlxG.random.float(5, 7);
    tankAngle = FlxG.random.int(-90, 45);
}

function onStageCreate()
{
	trace('[Rolling Tank] Getting elements...');

	if (stage != null)
	{
		tank = stage.getElement('backgroundTank');
	}
}

function onUpdate(elapsed)
{
	tankAngle += elapsed * tankSpeed;
	tank.angle = tankAngle - 90 + 15;
	tank.x = offsetX + 1500 * Math.cos(Math.PI / 180 * (tankAngle + 180));
	tank.y = offsetY + 1100 * Math.sin(Math.PI / 180 * (tankAngle + 180));
}