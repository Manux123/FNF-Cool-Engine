package;
import states.PlayState;
class Ranking {
    public static function generateLetterRank():String{
        var daRanking:String = 'N/A';
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
                        daRanking = "SS";
                    case 1:
                        daRanking = "S";
                    case 2:
                        daRanking = "A";
                    case 3:
                        daRanking = "B";
                    case 4:
                        daRanking = "C";
                    case 5:
                        daRanking = "D";
                }
                break;
            }
        }

        if (PlayState.accuracy == 0 /*&& PlayState.startingSong*/)
            daRanking = "N/A";
        else if (PlayState.accuracy <= 59.99 && !PlayState.startingSong)
            daRanking = "F";
        return daRanking;
    }

    static public function GenerateRating(noteDiff:Float,?saveFrames:Float = 0):String{
        var daRating:String = 'sick';
        if (noteDiff > Conductor.safeZoneOffset * 0.75 + saveFrames)
        {
            daRating = 'shit';
        }
        else if (noteDiff > Conductor.safeZoneOffset * 0.5 + saveFrames)
        {
            daRating = 'bad';
        }
        else if (noteDiff > Conductor.safeZoneOffset * 0.28 + saveFrames)
        {
            daRating = 'good';
        }
        else if (noteDiff > Conductor.safeZoneOffset * 0.01 + saveFrames)
        {
            daRating = 'sick';
        }

            return daRating;
    }
}