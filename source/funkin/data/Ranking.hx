package funkin.data;
import funkin.gameplay.PlayState;
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
}