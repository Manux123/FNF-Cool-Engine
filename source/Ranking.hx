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

    public static function GenerateRatingMS(noteDiff:Float, ?customSafeZone:Float = 10):String // Generate a judgement through some timing shit
    {
    
        var customTimeScale = Conductor.timeScale * customSafeZone / 166 * 15;

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

        return rating;
    }
}