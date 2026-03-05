function onBeatHit(beat)
{
	if (storyDifficulty < 3)
	{	
		if (beat % 8 == 7)
		{
			if (boyfriend != null)
				characterController.playSpecialAnim(boyfriend, 'hey');
		}
	}
}
