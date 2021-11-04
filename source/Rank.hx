import flixel.FlxG;
import states.PlayState;

class Rank
{
    public static var ranking:String = "N/A";
    public static function generateLetterRank()
    {
        var accuracy:Array<Bool> = [
            PlayState.accuracy >= 99.99, //SS
            PlayState.accuracy >= 94.99, //S
            PlayState.accuracy >= 89.99, //A
            PlayState.accuracy >= 79.99, //B
            PlayState.accuracy >= 69.99, //C
            PlayState.accuracy >= 59.99, //D
        ];

        //Osu!Mania Ranking System

        for(i in 0...accuracy.length)
        {
            var lyrics = accuracy[i];
            if (lyrics)
            {
                switch(i)
                {
                    case 0:
						ranking = "SS";
					case 1:
						ranking = "S";
					case 2:
						ranking = "A";
					case 3:
						ranking = "B";
                    case 4:
                        ranking = "C";
                    case 5:
                        ranking = "D";
                }
                break;
            }
        }

        if (PlayState.accuracy == 0 && PlayState.startingSong)
            ranking = "N/A";
        else if (PlayState.accuracy <= 59.99 && !PlayState.startingSong)
            ranking = "F";

        return ranking;
    }
}
