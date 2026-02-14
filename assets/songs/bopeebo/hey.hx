function onBeatHit(beat)
{
	if (beat % 8 == 7)
	{
		if (boyfriend != null)
			characterController.playSpecialAnim(boyfriend, 'hey');
	}
}
