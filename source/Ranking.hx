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

    public static function GenerateRatingMS(noteDiff:Float, ?customSafeZone:Float):String // Generate a judgement through some timing shit
    {
    
        var customTimeScale = Conductor.timeScale;
    
        if (customSafeZone != null)
            customTimeScale = customSafeZone / 166;

        var rating = "";

        var timingWindowsRating:Array<String> = ['shit-soon','bad-soon','good-soon','sick','good-later','bad-later','shit-later'];
        var timingWindows:Array<Int> = [166, 135, 90, 45, -90, -135, -166];
        var timingWindowsTiny:Array<Int> = [135, 90, 45, -45, -45, -90, -135];

        for(i in 0... timingWindows.length){
            if(noteDiff <= timingWindows[i] * customTimeScale && noteDiff >= timingWindowsTiny[i] * customTimeScale){
                rating = timingWindowsRating[i];
                break;
            }
        }

        //piñera chupame el pico, grande boric
        trace('${noteDiff} && ${customTimeScale}');

        return rating;
    }

    static public function GenerateRatingFrames(noteDiff:Float,?saveFrames:Float = 0):String{
        var daRating:String = 'sick';

        // late
        if (noteDiff > Conductor.safeZoneOffset * 0.95 + saveFrames)
            daRating = 'shit-later';

        else if (noteDiff > Conductor.safeZoneOffset * 0.7 + saveFrames)
            daRating = 'bad-later';

        else if (noteDiff > Conductor.safeZoneOffset * 0.38 + saveFrames)
            daRating = 'good-later';

        else if (noteDiff > Conductor.safeZoneOffset * 0.029 + saveFrames)
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
        else if (noteDiff < Conductor.safeZoneOffset * -0.029 + saveFrames)
            daRating = 'sick-soon';

        else if(noteDiff < Conductor.safeZoneOffset * -0.38 + saveFrames)
            daRating = 'good-soon';

        else if (noteDiff < Conductor.safeZoneOffset * -0.7 + saveFrames)
            daRating = 'bad-soon';

        else if (noteDiff < Conductor.safeZoneOffset * -0.95 + saveFrames)
            daRating = 'shit-soon';

            return daRating;
    }
}