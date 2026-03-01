var animationNotes:Array<Dynamic> = [];
var chart:SwagSong = null;

function onCreate()
{
    trace("[Pico Speaker] Loaded script");
    chart = Song.loadFromJson("picospeaker", SONG.song);
    if(chart != null)
		for (section in chart.notes)
			for (songNotes in section.sectionNotes)
				animationNotes.push(songNotes);

    animationNotes.sort(sortAnims);
}

function postCreate()
{
    gf.animation.play("shoot1");
}

function sortAnims(Obj1:Array<Dynamic>, Obj2:Array<Dynamic>):Int
{
	return FlxSort.byValues(FlxSort.ASCENDING, Obj1[0], Obj2[0]);
}

var lastPlayedAnim:String = "";
function onUpdate(elapsed:Float)
{
    if(animationNotes.length > 0 && Conductor.songPosition > animationNotes[0][0])
	{
		var noteData:Int = 1;
		if(animationNotes[0][1] > 2) noteData = 3;

		noteData += FlxG.random.int(0, 1);
		gf.animation.play('shoot' + noteData, true);
        lastPlayedAnim = "shoot" + noteData;
		animationNotes.shift();
	}
	if(gf.animation.curAnim.finished) playAnim(lastPlayedAnim, false, false, animation.curAnim.frames.length - 3);
}