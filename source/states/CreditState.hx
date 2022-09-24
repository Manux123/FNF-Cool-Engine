package states;

import lime.ui.KeyCode;
import flixel.FlxState;
import flixel.FlxG;
import flixel.util.FlxColor;
import flixel.text.FlxText;
import flixel.FlxSprite;

class CreditState extends FlxState {

    var bg = new FlxSprite().loadGraphic("assets/images/menu/menuBG.png");

    var pissPoopUwuCred:Array<Dynamic> = [ // User's name, Description
        ["Manux123", "Main Programmer of Cool-Engine"],
        ["Jloor", "Programmer Friday Night Funkin: Cool Engine"],
        ["Chasetodie", "Programmer Friday Night Funkin: Cool Engine"],
        ["Jotaro Gaming", "Programmer and Composer Friday Night Funkin: Cool Engine"],
        ["Overcharged Dev", "Programmer Friday Night Funkin: Cool Engine"],
        ["FairyBoy", "Artist Friday Night Funkin: Cool Engine"],
        ["Zero Artist", "Artist Friday Night Funkin: Cool Engine"],
        ["XuelDev", "Programmer Friday Night Funkin: Cool Engine"]
    ];

    var DescriptionBox = new FlxSprite().makeGraphic(1000, 100, FlxColor.BLACK);
    var DescriptionText = new FlxText(0,0,0,"None",16);

    var selShit = 0;

    var Manux123:FlxText;
    var Jloor:FlxText;
    var Chasetodie:FlxText;
    var MrClogsworthYT:FlxText;
    var OverchargedDev:FlxText;
    var FairyBoy:FlxText;
    var ZeroArtist:FlxText;
    var XuelDev:FlxText;

    // Color

    var NOTSEL = FlxColor.WHITE;
    var SELECTED = FlxColor.GREEN;
    

    override public function create() {
        super.create();

        DescriptionBox.screenCenter();
        DescriptionBox.y = 600;

        DescriptionText.screenCenter();
        DescriptionText.y = 645;
        


        Manux123 = new FlxText(0,50,0,pissPoopUwuCred[0][0], 40);
        Manux123.scrollFactor.set();
		Manux123.setFormat(Paths.font("Funkin.otf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        Manux123.color = FlxColor.GREEN;
        
        Jloor = new FlxText(0,64,0,pissPoopUwuCred[1][0], 40);
        Jloor.scrollFactor.set();
		Jloor.setFormat(Paths.font("Funkin.otf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        Jloor.color = FlxColor.WHITE;

        Chasetodie = new FlxText(0,74,0,pissPoopUwuCred[2][0], 40);
        Chasetodie.scrollFactor.set();
		Chasetodie.setFormat(Paths.font("Funkin.otf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        Chasetodie.color = FlxColor.WHITE;
        
        MrClogsworthYT = new FlxText(0,84,0,pissPoopUwuCred[3][0], 40);
        MrClogsworthYT.scrollFactor.set();
		MrClogsworthYT.setFormat(Paths.font("Funkin.otf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        MrClogsworthYT.color = FlxColor.WHITE;

        OverchargedDev = new FlxText(0,94,0,pissPoopUwuCred[4][0], 40);
        OverchargedDev.scrollFactor.set();
		OverchargedDev.setFormat(Paths.font("Funkin.otf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        OverchargedDev.color = FlxColor.WHITE;        
        
        FairyBoy = new FlxText(0,104,0,pissPoopUwuCred[5][0], 40);
        FairyBoy.scrollFactor.set();
		FairyBoy.setFormat(Paths.font("Funkin.otf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        FairyBoy.color = FlxColor.WHITE;      
        
        ZeroArtist = new FlxText(0,114,0,pissPoopUwuCred[6][0], 40);
        ZeroArtist.scrollFactor.set();
		ZeroArtist.setFormat(Paths.font("Funkin.otf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        ZeroArtist.color = FlxColor.WHITE;

        XuelDev = new FlxText(0,124,0,pissPoopUwuCred[7][0], 40);
        XuelDev.scrollFactor.set();
		XuelDev.setFormat(Paths.font("Funkin.otf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        XuelDev.color = FlxColor.WHITE;
        
        
        



        add(bg);
        add(DescriptionBox);
        add(DescriptionText);
        add(Manux123);
        add(Jloor);
        add(Chasetodie);
        add(MrClogsworthYT);
        add(OverchargedDev);
        add(FairyBoy);
        add(ZeroArtist);
        add(XuelDev);
    }

    override public function update(elapsed) {
        super.update(elapsed);

        DescriptionText.screenCenter();
        DescriptionText.y = 640;

        switch (selShit) {
            case 0:
                DescriptionText.text = pissPoopUwuCred[0][1];
            case 1:
                DescriptionText.text = pissPoopUwuCred[1][1];
            case 2:
                DescriptionText.text = pissPoopUwuCred[2][1];
            case 3:
                DescriptionText.text = pissPoopUwuCred[3][1];
            case 4:
                DescriptionText.text = pissPoopUwuCred[4][1];
            case 5:
                DescriptionText.text = pissPoopUwuCred[5][1];
            case 6:
                DescriptionText.text = pissPoopUwuCred[6][1];
            case 7:
                DescriptionText.text = pissPoopUwuCred[7][1];

        }

        if (FlxG.keys.justPressed.DOWN) {
            switch (selShit) {
                case 0:
                    selShit=1;
                    Manux123.color = NOTSEL;
                    Jloor.color = SELECTED;
                case 1:
                    Jloor.color = NOTSEL;
                    Chasetodie.color = SELECTED;
                    selShit=2;
                case 2:
                    Chasetodie.color = NOTSEL;
                    MrClogsworthYT.color = SELECTED;
                    selShit=3;
                case 3:
                    MrClogsworthYT.color = NOTSEL;
                    OverchargedDev.color = SELECTED;
                    selShit=4;
                case 4:
                    OverchargedDev.color = NOTSEL;
                    FairyBoy.color = SELECTED;
                    selShit=5;
                case 5:
                    FairyBoy.color = NOTSEL;
                    ZeroArtist.color = SELECTED;
                    selShit=6;
                case 6:
                    ZeroArtist.color = NOTSEL;
                    XuelDev.color = SELECTED;
                    selShit=7;
                case 7:
                    trace("Just No.");

            }
        } else if (FlxG.keys.justPressed.UP) {
            switch (selShit) {
                case 0:
                    trace("Just No.");
                case 1:
                    Jloor.color = NOTSEL;
                    Manux123.color = SELECTED;
                    selShit--;
                case 2:
                    Chasetodie.color = NOTSEL;
                    Jloor.color = SELECTED;
                    selShit--;
                case 3:
                    MrClogsworthYT.color = NOTSEL;
                    Chasetodie.color = SELECTED;
                    selShit--;
                case 4:
                    OverchargedDev.color = NOTSEL;
                    MrClogsworthYT.color = SELECTED;
                    selShit--;
                case 5:
                    FairyBoy.color = NOTSEL;
                    OverchargedDev.color = SELECTED;
                    selShit--;
                case 6:
                    ZeroArtist.color = NOTSEL;
                    FairyBoy.color = SELECTED;
                    selShit--;
                case 7:
                    XuelDev.color = NOTSEL;
                    ZeroArtist.color = SELECTED;
                    selShit--;
            }
        } 
        
        if (FlxG.keys.justPressed.ESCAPE) {
            FlxG.camera.fade(FlxColor.BLACK, 0.5, false, function() {
                FlxG.switchState(new states.MainMenuState());
            });
        }
    }
}
