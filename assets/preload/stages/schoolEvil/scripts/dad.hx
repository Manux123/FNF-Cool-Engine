function onUpdate(elapsed)
{
    if (dad != null)
        dad.y += Mathf.sineByTime(elapsed);
}