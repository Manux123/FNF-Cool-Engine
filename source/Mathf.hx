package;

class Mathf {
    public static function getPercentage(number:Float,toGet:Float):Float{
        var num = number;
		num = num * Math.pow(10, toGet);
		num = Math.round( num ) / Math.pow(10, toGet);
        return num;
    }
    static var sineShit:Float;

    public static function sineByTime(elapsed:Float, ?multi:Int = 1){
        sineShit+=elapsed;
        return Math.sin(Math.abs(sineShit * multi));
    }
}