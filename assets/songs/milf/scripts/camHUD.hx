function onBeatHit(beat)
{
	if (beat >= 168 && beat < 200)
	{
		if (camGame.zoom < 1.35)
		{
			camGame.zoom += 0.015;
			camHUD.zoom += 0.03;
		}
	}
}