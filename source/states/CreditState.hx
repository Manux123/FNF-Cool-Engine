package states;

import flixel.FlxState;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.util.FlxColor;
import Alphabet;
import flixel.text.FlxText;

class CreditState extends FlxState {
    
    var curSelected = 0;

    var Manux123:Alphabet;
    var Jloor:Alphabet;
    var Chasetodie:Alphabet;
    var JotaroGaming:Alphabet;
    var OverchargedDev:Alphabet;
    var FairyBoy:Alphabet;
    var ZeroArtist:Alphabet;
    var XuelDev:Alphabet;

    var ExitState:FlxText;

    var hidden = false;

    var DescriptionText:FlxText;

    public var descriptions = [
        "(Retired) Programmer of the Friday Night Funkin: Cool Engine", // Manux123
        "(Retired) Programmer Friday Night Funkin: Cool Engine", // Jloor
        "(Retired) Programmer Friday Night Funkin: Cool Engine", // Chasetodie
        "Programmer and composer Friday Night Funkin: Cool Engine", // JotaroGaming
        "(Retired) Programmer Friday Night Funkin: Cool Engine", // OverchargedDev
        "(Retired) Artists Friday Night Funkin: Cool Engine", // Fairy Boy and Zero Artist
        "Programmer of the Friday Night Funkin: Cool Engine" // XuelDev

    ];
    
    public static var maxAmount = 7;


    var bg:FlxSprite;

    override public function create() {
        super.create();

        bg = new FlxSprite().loadGraphic("assets/images/menu/menuBGloading.png");
        bg.screenCenter();
        add(bg);

        Manux123 = new Alphabet(13, 40, "Manux123", true, false);
        Manux123.color = FlxColor.GREEN;
        add(Manux123);

        Jloor = new Alphabet(13, 100, "Jloor", true, false);
        Jloor.color = FlxColor.WHITE;
        add(Jloor);

        Chasetodie = new Alphabet(13, 160, "Chasetodie", true, false);
        Chasetodie.color = FlxColor.WHITE;
        add(Chasetodie);

        JotaroGaming = new Alphabet(13, 220, "Jotaro-Gaming", true, false);
        JotaroGaming.color = FlxColor.WHITE;
        add(JotaroGaming);

        OverchargedDev = new Alphabet(13, 280, "Overcharged-Dev", true, false);
        OverchargedDev.color = FlxColor.WHITE;
        add(OverchargedDev);

        FairyBoy = new Alphabet(13, 340, "FairyBoy", true, false);
        FairyBoy.color = FlxColor.WHITE;
        add(FairyBoy);

        ZeroArtist = new Alphabet(13, 400, "ZeroArtist", true, false);
        ZeroArtist.color = FlxColor.WHITE;
        add(ZeroArtist);

        XuelDev = new Alphabet(13, 460, "XuelDev", true, false);
        XuelDev.color = FlxColor.WHITE;
        add(XuelDev);

        DescriptionText = new FlxText(0,0,0, "Loading...", 30);
        DescriptionText.screenCenter();
        DescriptionText.visible = false;
        add(DescriptionText);

        ExitState = new FlxText(0,0,0, "ESC TO EXIT", 12);
        ExitState.screenCenter();
        ExitState.y = 13;
        ExitState.visible = true;
        add(ExitState);
    }

    override public function update(elapsed) {
        super.update(elapsed);

        switch (curSelected) {
            case 0:
                Manux123.color = FlxColor.GREEN;
                Jloor.color = FlxColor.WHITE;
                Chasetodie.color = FlxColor.WHITE;
                JotaroGaming.color = FlxColor.WHITE;
                OverchargedDev.color = FlxColor.WHITE;
                FairyBoy.color = FlxColor.WHITE;
                ZeroArtist.color = FlxColor.WHITE;
                XuelDev.color = FlxColor.WHITE;
            case 1:
                Manux123.color = FlxColor.WHITE;
                Jloor.color = FlxColor.GREEN;
                Chasetodie.color = FlxColor.WHITE;
                JotaroGaming.color = FlxColor.WHITE;
                OverchargedDev.color = FlxColor.WHITE;
                FairyBoy.color = FlxColor.WHITE;
                ZeroArtist.color = FlxColor.WHITE;
                XuelDev.color = FlxColor.WHITE;

            case 2:
                Manux123.color = FlxColor.WHITE;
                Jloor.color = FlxColor.WHITE;
                Chasetodie.color = FlxColor.GREEN;
                JotaroGaming.color = FlxColor.WHITE;
                OverchargedDev.color = FlxColor.WHITE;
                FairyBoy.color = FlxColor.WHITE;
                ZeroArtist.color = FlxColor.WHITE;
                XuelDev.color = FlxColor.WHITE;
            case 3:
                Manux123.color = FlxColor.WHITE;
                Jloor.color = FlxColor.WHITE;
                Chasetodie.color = FlxColor.WHITE;
                JotaroGaming.color = FlxColor.GREEN;
                OverchargedDev.color = FlxColor.WHITE;
                FairyBoy.color = FlxColor.WHITE;
                ZeroArtist.color = FlxColor.WHITE;
                XuelDev.color = FlxColor.WHITE;
            case 4:
                Manux123.color = FlxColor.WHITE;
                Jloor.color = FlxColor.WHITE;
                Chasetodie.color = FlxColor.WHITE;
                JotaroGaming.color = FlxColor.WHITE;
                OverchargedDev.color = FlxColor.GREEN;
                FairyBoy.color = FlxColor.WHITE;
                ZeroArtist.color = FlxColor.WHITE;
                XuelDev.color = FlxColor.WHITE;
            case 5:
                Manux123.color = FlxColor.WHITE;
                Jloor.color = FlxColor.WHITE;
                Chasetodie.color = FlxColor.WHITE;
                JotaroGaming.color = FlxColor.WHITE;
                OverchargedDev.color = FlxColor.WHITE;
                FairyBoy.color = FlxColor.GREEN;
                ZeroArtist.color = FlxColor.WHITE;
                XuelDev.color = FlxColor.WHITE;
            case 6:
                Manux123.color = FlxColor.WHITE;
                Jloor.color = FlxColor.WHITE;
                Chasetodie.color = FlxColor.WHITE;
                JotaroGaming.color = FlxColor.WHITE;
                OverchargedDev.color = FlxColor.WHITE;
                FairyBoy.color = FlxColor.WHITE;
                ZeroArtist.color = FlxColor.GREEN;
                XuelDev.color = FlxColor.WHITE;
            case 7:
                Manux123.color = FlxColor.WHITE;
                Jloor.color = FlxColor.WHITE;
                Chasetodie.color = FlxColor.WHITE;
                JotaroGaming.color = FlxColor.WHITE;
                OverchargedDev.color = FlxColor.WHITE;
                FairyBoy.color = FlxColor.WHITE;
                ZeroArtist.color = FlxColor.WHITE;
                XuelDev.color = FlxColor.GREEN;
        }


        if (FlxG.keys.justPressed.UP) {
            if (curSelected == 0) {
                trace("Hell nah");
            } else {
                curSelected = curSelected - 1;
            }
        } else if (FlxG.keys.justPressed.DOWN) {
            if (curSelected == 7) {
                trace("Hell nah");
            } else {
                curSelected = curSelected + 1;
            }
        }

        if (FlxG.keys.justPressed.ENTER) {
            if (hidden == false) {
                hideShit();
            } 
        } else if (FlxG.keys.justPressed.ESCAPE) {
            if (hidden == true) {
                showShit();
            } else {
                FlxG.switchState(new states.MainMenuState());
            }
        }


    }

    public function showShit() {
        Manux123.visible = true;
        Jloor.visible = true;
        Chasetodie.visible = true;
        JotaroGaming.visible = true;
        OverchargedDev.visible = true;
        FairyBoy.visible = true;
        ZeroArtist.visible = true;
        XuelDev.visible = true;
        ExitState.text = "ESC TO EXIT";
        ExitState.screenCenter();
        ExitState.y = 13;
        hidden = false;
        hideDescriptions();
    }

    public function hideDescriptions() {
        DescriptionText.visible = false;
        DescriptionText.text = "Closing..";
    }

    public function hideShit() {
        Manux123.visible = false;
        Jloor.visible = false;
        Chasetodie.visible = false;
        JotaroGaming.visible = false;
        OverchargedDev.visible = false;
        FairyBoy.visible = false;
        ZeroArtist.visible = false;
        XuelDev.visible = false;
        hidden = true;
        sortDescriptions();
    }

    public function sortDescriptions() {
        DescriptionText.visible = true;
        ExitState.text = "ESC TO RETURN TO CREDITS";
        ExitState.screenCenter();
        ExitState.y = 13;
        switch (curSelected) {
            case 0:
                DescriptionText.text = descriptions[0];
                DescriptionText.screenCenter();
            case 1:
                DescriptionText.text = descriptions[1];
                DescriptionText.screenCenter();
            case 2:
                DescriptionText.text = descriptions[2];
                DescriptionText.screenCenter();
            case 3:
                DescriptionText.text = descriptions[3];
                DescriptionText.screenCenter();
            case 4:
                DescriptionText.text = descriptions[4];
                DescriptionText.screenCenter();
            case 5:
                DescriptionText.text = descriptions[5];
                DescriptionText.screenCenter();
            case 6:
                DescriptionText.text = descriptions[5];
                DescriptionText.screenCenter();
            case 7:
                DescriptionText.text = descriptions[6];
                DescriptionText.screenCenter();
                
            
        }
    }


}