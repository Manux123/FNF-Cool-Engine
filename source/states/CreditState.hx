package states;

import flixel.util.FlxColor;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.FlxSprite;
import flixel.FlxG;

class CreditState extends FlxState
{
    // Buttons
    var Manux = new FlxText(); // 0
    var Jloor = new FlxText(); // 1
    var mrClogsworth = new FlxText(); // 2
    var Overcharged_Dev = new FlxText(); // 3
    var FairyBoy = new FlxText(); // 4
    var Zero_Artist = new FlxText(); // 5 
    // All above is from the readme
    
    // MenuBG
    // Uh I dont know where menuBG is. 

    // lazy
    var GREEN = FlxColor.GREEN;
    var WHITE = FlxColor.WHITE;

    // Button Config Shit lol
    var ButtonSel = 0;

    // Even more lazy lol
    var size = 20;

    override public function create()
    {
        // Add menu BG here
        //add(menuBG);
        // Manux (Programmer) also Button 0
        Manux.text = "Manux - Main programmer of Cool Engine";
        Manux.screenCenter(); // Im lazy too lol
        Manux.y = 10;
        Manux.color = GREEN;
        Manux.size = size;
        add(Manux);
        // Jloor (Programmer) button 1
        Jloor.text = "Jloor - Another programmer of Cool Engine";
        Jloor.screenCenter();
        Jloor.y = 10 * 2;
        Jloor.color = WHITE;
        Jloor.size = size;
        add(Jloor);
        // mrClogsworth
        mrClogsworth.text = "MrClogsWorth - Another programmer and composer of Cool Engine";
        mrClogsworth.screenCenter();
        mrClogsworth.y = 10 * 3;
        mrClogsworth.color = WHITE;
        mrClogsworth.size = size;
        add(mrClogsworth);
        // Overcharged
        Overcharged_Dev.text = "Overcharged dev - Another programmer of Cool Engine";
        Overcharged_Dev.screenCenter();
        Overcharged_Dev.y = 10 * 4;
        Overcharged_Dev.color = WHITE;
        Overcharged_Dev.size = size;
        // Fairyboy
        FairyBoy.text = "FairyBoy - Artist of Cool Engine";
        FairyBoy.screenCenter();
        FairyBoy.y = 10 * 5;
        FairyBoy.color = WHITE;
        FairyBoy.size = size;
        add(FairyBoy);
        // Zero_Artist
        Zero_Artist.text = "Zero Artist - Another artist of Cool Engine";
        Zero_Artist.screenCenter();
        Zero_Artist.y = 10 * 6;
        Zero_Artist.color = WHITE;
        Zero_Artist.size = size;
        add(Zero_Artist);

        super.create();
    }
    override public function update(elapsed:Float)
    {
        if (FlxG.keys.justPressed.UP)
        {
            switch ButtonSel
            {
                case 0:
                    trace("Nope lol");
                case 1:
                    ButtonSel = 0;
                    Jloor.color = WHITE;
                    Manux.color = GREEN;
                case 2:
                    ButtonSel = 1;
                    mrClogsworth.color = WHITE;
                    Jloor.color = GREEN;
                case 3:
                    ButtonSel = 2;
                    Overcharged_Dev.color = WHITE;
                    mrClogsworth.color = GREEN;
                case 4:
                    ButtonSel = 3;
                    Overcharged_Dev.color = GREEN;
                    FairyBoy.color = WHITE;
                case 5:
                    ButtonSel = 4;
                    FairyBoy.color = GREEN;
                    Zero_Artist.color = WHITE;
                    

            }
        }
        else if (FlxG.keys.justPressed.DOWN)
        {
            switch ButtonSel
            {
                case 0:
                    ButtonSel=1;
                    Manux.color = WHITE;
                    Jloor.color = GREEN;
                case 1:
                    ButtonSel=2;
                    Jloor.color = WHITE;
                    mrClogsworth.color = GREEN;
                case 2:
                    ButtonSel=3;
                    Overcharged_Dev.color = GREEN;
                    mrClogsworth.color = WHITE;
                case 3:
                    ButtonSel=4;
                    Overcharged_Dev.color = WHITE;
                    FairyBoy.color = GREEN;
                case 4:
                    ButtonSel=5;
                    FairyBoy.color = WHITE;
                    Zero_Artist.color = GREEN;
                case 5:
                    trace("No more buttons");
            }
        }
    

        super.update(elapsed);
    }
}
