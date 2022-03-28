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
		num = num / toGet;
		num = num * 100;
        return Math.round(num);
    }

    //Returns the largest integer smaller to or equal to value
    public static function floor2int(value){
        return Std.int(Math.floor(value));
    }

    //this functions are for angles and rotations
    public static function radiants2degrees(value:Float){
        return value * (180/Math.PI);
    }

    public static function degrees2radiants(value:Float){
        return value * (Math.PI/180);
    }
}