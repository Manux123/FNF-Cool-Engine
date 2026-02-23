function onBeatHit(beat)
{
    var crowd = stage.customClassGroups.get('crowd');
    if (crowd != null)
    {
        for (girl in crowd.members)
        {
            if (girl != null)
                cast(girl, BackgroundGirls).dance();
        }
    }
}