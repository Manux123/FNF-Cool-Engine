import flixel.FlxG;
import states.PlayState;

class Rank
{
    public static var ranking:String = "NA";
    public static function generateLetterRank() // generate a letter ranking
    {
        // WIFE TIME :)))) (based on Wife3)

        var wifeConditions:Array<Bool> = [
            PlayState.accuracy >= 99.99, //S
            PlayState.accuracy >= 89.99, //A
            PlayState.accuracy >= 69.99, //B
            PlayState.accuracy >= 64.99, //C
            PlayState.accuracy >= 59.99, //D
            PlayState.accuracy >= 54.99, //E
            PlayState.accuracy <= 49 //F
        ];

        for(i in 0...wifeConditions.length)
        {
            var b = wifeConditions[i];
            if (b)
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

        if (PlayState.accuracy == 0)
            ranking = "N/A";

        return ranking;
    }
}