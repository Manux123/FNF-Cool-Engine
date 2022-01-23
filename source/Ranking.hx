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
        var timingWindowsData:Array<Dynamic>=
            [[166,135,'shit-soon'],
            [135,90,'bad-soon'],
            [90,45,'good-soon'],
            [45,-45,'sick'],
            [-90,-45,'good-later'],
            [-135,-90,'bad-later'],
            [-166,-135,'shit-later']];

        for(i in 0... timingWindowsData.length){
            if(noteDiff <= timingWindowsData[i][0] * customTimeScale && noteDiff >= timingWindowsData[i][1] * customTimeScale){
                rating = timingWindowsData[i][2];
                break;
            }
        }

        return rating;
    }
}