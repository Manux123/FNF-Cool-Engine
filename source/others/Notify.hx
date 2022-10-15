package others;

import flixel.util.FlxTimer;
import flixel.FlxG;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.FlxSubState;

class Notify extends FlxSubState {

    public static var groupShit = new FlxSpriteGroup();

    public static var NText = "None";
    var NDesc = "None";

    override public function create() {
        super.create();

       

        var blackBox = new FlxSprite().makeGraphic(FlxG.width, 50, FlxColor.BLACK);
        add(blackBox);
        
        var notificationText = new FlxText(0,0,0,NText,16);
        add(notificationText);
        notificationText.screenCenter(X);
        

        groupShit.add(notificationText);
        groupShit.add(blackBox);
        groupShit.y = 600;

        var timer = new FlxTimer().start(1, function(timer:FlxTimer){
            groupShit.kill();
            closeSubState();
        });
    }

    public static function removeNotification() { // Not a point of using
        groupShit.kill();
    }
}