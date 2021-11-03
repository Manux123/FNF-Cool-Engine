import flixel.FlxG;
import states.PlayState;

class Rank
{
    public static var ranking:String = "N/A";
    public static function generateLetterRank()
    {
        var accuracy:Array<Bool> = [
            PlayState.accuracy >= 99.99, //S
            PlayState.accuracy >= 89.99, //A
            PlayState.accuracy >= 69.99, //B
            PlayState.accuracy >= 64.99, //C
            PlayState.accuracy >= 59.99, //D
            PlayState.accuracy >= 54.99, //E
            PlayState.accuracy <= 49 //F
        ];

        for(i in 0...accuracy.length)
        {
            var lyrics = accuracy[i];
            if (lyrics)
            {
                switch(i)
                {
                    case 0:
						ranking = "S";
					case 1:
						ranking = "A";
					case 2:
						ranking = "B";
					case 3:
						ranking = "C";
                    case 4:
                        ranking = "D";
                    case 5:
                        ranking = "E";
                    case 6:
                        ranking = "F";
                }
                break;
            }
        }

        if (PlayState.accuracy == 0 && PlayState.startingSong)
            ranking = "N/A";
        else if (PlayState.accuracy == 0 && !PlayState.startingSong)
            ranking = "F";

        return ranking;
    }
}