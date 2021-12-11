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

        if (PlayState.accuracy == 0 && PlayState.misses == 0)
            daRanking = "N/A";
        else if (PlayState.accuracy <= 59.99 && !PlayState.startingSong)
            daRanking = "F";
        return daRanking;
    }

    public static function GenerateRatingMS(note:Note, diff:Float=0) //STOLEN FROM PSYCH ENGINE (Shadow Mario) - I had to rewrite it later anyway after i added the custom hit windows lmao (Overcharged Dev)
    {
        //tryna do MS based judgment due to popular demand
        var timingWindows:Array<Int> = [25, 75, 115, 145];
        var windowNames:Array<String> =['sick','good','bad','shit'];

        // var diff = Math.abs(note.strumTime - Conductor.songPosition) / (PlayState.songMultiplier >= 1 ? PlayState.songMultiplier : 1);
        for(i in 0...timingWindows.length) // based on 4 timing windows, will break with anything else
        {
            trace(timingWindows[Math.round(Math.min(i, timingWindows.length - 1))]);
            if (diff <= timingWindows[Math.round(Math.min(i, timingWindows.length - 1))])
            {
                return windowNames[i];
            }
        }
        return 'shit';
    }

    static public function GenerateRatingFrames(noteDiff:Float,?saveFrames:Float = 0):String{
        var daRating:String = 'sick';

        // late
        if (noteDiff > Conductor.safeZoneOffset * 0.75 + saveFrames)
            daRating = 'shit-later';

        else if (noteDiff > Conductor.safeZoneOffset * 0.5 + saveFrames)
            daRating = 'bad-later';

        else if (noteDiff > Conductor.safeZoneOffset * 0.28 + saveFrames)
            daRating = 'good-later';

        else if (noteDiff > Conductor.safeZoneOffset * 0.019 + saveFrames)
            daRating = 'sick-later';

        //Perfect
        if (noteDiff == Conductor.safeZoneOffset * 0.75 + saveFrames)
            daRating = 'shit';

        else if (noteDiff == Conductor.safeZoneOffset * 0.5 + saveFrames)
            daRating = 'bad';

        else if (noteDiff == Conductor.safeZoneOffset * 0.28 + saveFrames)
            daRating = 'good';

        else if(noteDiff == Conductor.safeZoneOffset + saveFrames)
            daRating = 'sick';

        // After
        else if (noteDiff < Conductor.safeZoneOffset * -0.019 + saveFrames)
            daRating = 'sick-soon';

        else if(noteDiff < Conductor.safeZoneOffset * -0.28 + saveFrames)
            daRating = 'good-soon';

        else if (noteDiff < Conductor.safeZoneOffset * -0.5 + saveFrames)
            daRating = 'bad-soon';

        else if (noteDiff < Conductor.safeZoneOffset * -0.75 + saveFrames)
            daRating = 'shit-soon';

            return daRating;
    }
}