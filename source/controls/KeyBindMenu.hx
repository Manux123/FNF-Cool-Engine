//Code by ThatRozedubDude(https://github.com/ThatRozebudDude) thanks a lot bud :D
//Edited by OverchargedDev

package controls;

import states.PlayState;
import states.PauseSubState;
import states.MusicBeatSubstate;
import flixel.FlxSubState;
import flixel.input.FlxInput;
import flixel.input.keyboard.FlxKey;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.effects.FlxFlicker;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import lime.app.Application;
import lime.utils.Assets;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.input.FlxKeyManager;


using StringTools;

class KeyBindMenu extends MusicBeatSubstate
{
    var keyDisplayText:FlxTypedGroup<FlxText>;

    var keyTextDisplay:FlxText;
    var keyWarning:FlxText;
    var advertenceText:FlxText;
    var warningTween:FlxTween;

    var keyText:Array<String> = ["LEFT", "DOWN", "UP", "RIGHT"];
    var defaultKeys:Array<String> = ["D", "F", "J", "K", "R"];
    var curSelected:Int = 0;

    var keys:Array<String> = [FlxG.save.data.leftBind,
                              FlxG.save.data.downBind,
                              FlxG.save.data.upBind,
                              FlxG.save.data.rightBind,
                              FlxG.save.data.killBind];

    var tempKey:String = "";
    var blacklist:Array<String> = ["ESCAPE", "ENTER", "BACKSPACE", "SPACE"];

    var state:String = "select";
    var black:FlxSprite;

    public static var isPlaying:Bool = false;
	override function create()
	{
        black = new FlxSprite(0,0).makeGraphic(FlxG.width,FlxG.height,FlxColor.BLACK);
        black.screenCenter();
        black.scrollFactor.set();
        black.setGraphicSize(Std.int(black.width * 5));
		black.updateHitbox();
        black.alpha = 0.6;
        add(black);

        keyDisplayText = new FlxTypedGroup<FlxText>();
        add(keyDisplayText);

		persistentUpdate = persistentDraw = true;

        keyTextDisplay = new FlxText(0, 0, 1280, "", 72);
		keyTextDisplay.scrollFactor.set(0, 0);
		keyTextDisplay.setFormat(Paths.font("vcr.ttf"), 72, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		keyTextDisplay.borderSize = 3;
		keyTextDisplay.borderQuality = 1;
        add(keyTextDisplay);

        advertenceText = new FlxText(0, 580, 1280, "Backspace: Back to Options Menu\n Enter: Change the keyblind", 42);
		advertenceText.scrollFactor.set(0, 0);
		advertenceText.setFormat(Paths.font("vcr.ttf"), 42, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        advertenceText.borderSize = 3;
		advertenceText.borderQuality = 1;
        advertenceText.screenCenter(X);
        add(advertenceText);

        keyWarning = new FlxText(0, 58, 1280, "You select an not alowed key\n please, select another one :D", 42);
		keyWarning.scrollFactor.set(0, 0);
		keyWarning.setFormat(Paths.font("vcr.ttf"), 42, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        keyWarning.borderSize = 3;
		keyWarning.borderQuality = 1;
        keyWarning.screenCenter(X);
        keyWarning.alpha = 0;
        add(keyWarning);

        warningTween = FlxTween.tween(keyWarning, {alpha: 0}, 0);

        textUpdate();

		super.create();
	}

	override function update(elapsed:Float)
	{

        switch(state){

            case "select":
                if (controls.UP_P)
				{
					changeItem(-1);
				}

				if (controls.DOWN_P)
				{
					changeItem(1);
				}

                if (FlxG.keys.justPressed.ENTER){
                    FlxG.sound.play(Paths.sound('confirmMenu'));
                    state = "input";
                }
                else if(FlxG.keys.justPressed.ESCAPE){
                    quit();
                }
				else if (FlxG.keys.justPressed.BACKSPACE){
                    FlxG.sound.play(Paths.sound('scrollMenu'));
                    reset();
                }

            case "input":
                tempKey = keys[curSelected];
                keys[curSelected] = "?";
                textUpdate();
                state = "waiting";

            case "waiting":
                if(controls.BACK){
                    keys[curSelected] = tempKey;
                    state = "select";
                }
                else if(controls.ACCEPT){
                    addKey(defaultKeys[curSelected]);
                    save();
                    state = "select";
                }
                else if(FlxG.keys.justPressed.ANY){
                    addKey(FlxG.keys.getIsDown()[0].ID.toString());
                    save();
                    state = "select";
                }


            case "exiting":
                exitSubState();
                state = "changing";

            default:
                state = "select";

        }

        if(FlxG.keys.justPressed.ANY)
			textUpdate();

		super.update(elapsed);
	}

    function exitSubState(){
        FlxG.sound.play(Paths.sound('cancelMenu'));
        keyDisplayText.forEach(function(txt:FlxText){
            FlxTween.tween(txt,{alpha: 0},0.45,{ease: FlxEase.elasticInOut});
        });
        FlxTween.tween(black,{alpha: 0},0.45,{ease: FlxEase.elasticInOut});
        FlxTween.tween(keyTextDisplay,{alpha: 0},0.45,{ease: FlxEase.elasticInOut,onComplete: function(twn:FlxTween){
            FlxG.state.closeSubState();
            if(isPlaying) {
                FlxG.state.openSubState(new PauseSubState(PlayState.instance.boyfriend.getScreenPosition().x, PlayState.instance.boyfriend.getScreenPosition().y));
                FlxG.sound.music.pause();
            }
        }});
    }

    function textUpdate(){
        keyTextDisplay.text = "\n\n";

        for(i in 0...4){

            var textStart = (i == curSelected) ? ">" : "  ";
            keyTextDisplay.text += textStart + keyText[i] + ": " + ((keys[i] != keyText[i]) ? (keys[i]) : "" ) + "\n";

        }

        var textStart = (curSelected == 4) ? ">" : "  ";

        keyTextDisplay.text += textStart + "RESET: " + keys[4]  + "\n";

        keyTextDisplay.screenCenter();
    }

    function save(){

        FlxG.save.data.upBind = keys[2];
        FlxG.save.data.downBind = keys[1];
        FlxG.save.data.leftBind = keys[0];
        FlxG.save.data.rightBind = keys[3];
        FlxG.save.data.killBind = keys[4];

        FlxG.save.flush();
        PlayerSettings.player1.controls.loadKeyBinds();

    }

    function reset(){

        for(i in 0...5){
            keys[i] = defaultKeys[i];
        }
        quit();

    }

    function quit(){

        state = "exiting";
        save();
    }

	function addKey(r:String){

        var shouldReturn:Bool = true;

        var notAllowed:Array<String> = [];

        for(x in blacklist){notAllowed.push(x);}

        if(curSelected != 4){

            for(x in keyText){
                if(x != keyText[curSelected]){notAllowed.push(x);}
            }
            
        }
        else {for(x in keyText){notAllowed.push(x);}}

        trace(notAllowed);

        for(x in notAllowed){
            if(x == r){
                shouldReturn = false;
                FlxG.sound.play(Paths.sound('cancelMenu'));
            }
        }

        if(shouldReturn){
            keys[curSelected] = r;
            FlxG.sound.play('assets/sounds/scrollMenu.ogg');
        }
        else{
            keys[curSelected] = tempKey;
            FlxG.sound.play('assets/sounds/cancelMenu.ogg');
            keyWarning.alpha = 1;
            warningTween.cancel();
            warningTween = FlxTween.tween(keyWarning, {alpha: 0}, 0.5, {ease: FlxEase.circOut, startDelay: 2});
        }

	}

    function changeItem(_amount:Int = 0)
    {
        FlxG.sound.play(Paths.sound('scrollMenu'));

        curSelected += _amount;
                
        if (curSelected > 4)
            curSelected = 0;
        if (curSelected < 0)
            curSelected = 4;
    }
}
