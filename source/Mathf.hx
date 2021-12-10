package;

class Mathf {
    //only works whyle geting acuraccy cuz yes
    public static function getPercentage(number:Float,toGet:Float):Float{
        var num = number;
		num = num * Math.pow(10, toGet);
		num = Math.round( num ) / Math.pow(10, toGet);
        return num;
    }
    //use this instead XD
    public static function getPercentage2(number:Float,toGet:Float):Float{
        var num = number;
		num = toGet / num;
		num = Math.round( num ) * 100;
        return num;
    }
    
    static var sineShit:Float;

    public static function sineByTime(elapsed:Float, ?multi:Int = 1){
        sineShit+=elapsed;
        return Math.sin(Math.abs(sineShit * multi));
    }
}