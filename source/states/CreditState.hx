package states;

import lime.app.Application;
import states.OptionsMenuState.OptionsData;
import flixel.FlxG;
import flixel.util.FlxColor;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;

class CreditState extends FlxState {

    public static var pisspoop = [
        ["Manux123", "(Retired) Programmer of Friday Night Funkin: Cool Engine"],
        ["Jloor", "(Retired) Programmer of Friday Night Funkin: Cool Engine"],
        ["Chasetodie", "(Retired) Programmer of Friday Night Funkin: Cool Engine"],
        ["Jotaro Gaming", "Programmer of Friday Night Funkin: Cool Engine"],
        ["Overcharged Dev", "(Retired) Programmer of Friday Night Funkin: Cool Engine"],
        ["Fairy Boy", "(Retired) Artist of Friday Night Funkin: Cool Engine"],
        ["Zero Artist", "(Retired) Artist of Friday Night Funkin: Cool Engine"],
        ["Juanen100", "Programmer of Friday Night Funkin: Cool Engine"],
        ["XuelDev", "Programmer of Friday Night Funkin: Cool Engine"]
    ];

    public var idnum = 0;

    // Do not touch (Its not really important (If you touch it tho you may fuck the whole thing over))
    public var yShit = 13;
    public var timeBy = 0;

    public var setGreen = true;

    public var CredGroup = new FlxSpriteGroup();

    var bg:FlxSprite;
    
    var versionShit:FlxText;


    // Config for CreditsScreen

    public var minCur = 1; // The lowest id of the trace list (Dont Change This)
    public var maxCur = 9; // The highest id of the trace list (Change this)

    // Don't touch
    public var curSel = 1;

    // Go ahead

    

    override public function create() {
        super.create();

        bg = new FlxSprite().loadGraphic(Paths.image("menu/menuChartingBG"));
        add(bg);

        versionShit= new FlxText(5, FlxG.height - 19, 0, 'Cool Engine - V${Application.current.meta.get('version')}', 12);
		versionShit.scrollFactor.set();
		versionShit.setFormat(Paths.font("Funkin.otf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(versionShit);


        for(i in pisspoop) {
            var CredShit = new FlxText(13,yShit*timeBy,0,i[0], 16);
            if (setGreen) {CredShit.color = FlxColor.GREEN;} else {CredShit.color = FlxColor.WHITE;}
            CredGroup.add(CredShit);
            add(CredShit);
            setGreen = false;
            idnum++;
            CredShit.ID = idnum;
            trace("ID CARD : " + idnum + " | ID : " + CredShit.ID);
            timeBy++;

            
        }
    }

    override public function update(elapsed) {
        super.update(elapsed);

        if (FlxG.keys.justPressed.DOWN) {
            changeItem("DOWN");
        }

        if (FlxG.keys.justPressed.UP) {
            changeItem("UP");
        }

        if (FlxG.keys.justPressed.ESCAPE) {
            FlxG.switchState(new states.MainMenuState());
        }

        CredGroup.screenCenter(X);
    }

    public function changeItem(counterWay:String) {
        if (counterWay.toLowerCase() == "down") {
            if (curSel == maxCur) {
                curSel = minCur;
            } else {
                curSel++;
            }
        } 

        if (counterWay.toLowerCase() == "up") {
            if (curSel == minCur) {
                curSel = maxCur;
            } else {
                curSel = curSel - 1;
            }
        }

        CredGroup.forEach(function(spr:FlxSprite) {
            if (spr.ID == curSel) {
                spr.color = FlxColor.GREEN;
            } else {
                spr.color = FlxColor.WHITE;
            }
        });
    }
}