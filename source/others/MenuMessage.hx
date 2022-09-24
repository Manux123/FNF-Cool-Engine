package others;

import flixel.FlxState;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.FlxG;
import others.Config;


class MenuMessage extends FlxState {
    

    var AcceptButton:FlxText;
    var DeclineButton:FlxText;

    var Content:FlxText;
    var Description:FlxText;

    var menuBG:FlxSprite;
    
    var SelButton:Int = 1;

    override public function create() {
        super.create();

        Content = new FlxText(0,0,0,Config.Title,16);
        Content.screenCenter();
        Content.y = 200;

        Description = new FlxText(0,0,0,Config.Content,16);
        Description.screenCenter();
        Description.y = 250;
        
        menuBG = new FlxSprite().loadGraphic(Paths.image('menu/menuBG'));
		menuBG.screenCenter();
		menuBG.color = 0xFF2835AF;


        AcceptButton = new FlxText(0,0,0,Config.AcceptText,16);
        AcceptButton.color = FlxColor.GREEN;
        AcceptButton.screenCenter();
        AcceptButton.x = 500;
        DeclineButton = new FlxText(0,0,0,Config.DeclineText,16);
        DeclineButton.color = FlxColor.WHITE;
        DeclineButton.screenCenter();
        DeclineButton.x = 700;
        
        add(menuBG);
        add(Content);
        add(Description);
        add(AcceptButton);
        add(DeclineButton);

        
    }

    override public function update(elapsed) {
        super.update(elapsed);

        switch (SelButton) {
            case 1:
                AcceptButton.color = FlxColor.GREEN;
                DeclineButton.color = FlxColor.WHITE;
            case 2:
                AcceptButton.color = FlxColor.WHITE;
                DeclineButton.color = FlxColor.GREEN;
        }

        if (FlxG.keys.justPressed.LEFT) doMove("LEFT");
        else if (FlxG.keys.justPressed.RIGHT) doMove("RIGHT");
        else if (FlxG.keys.justPressed.ENTER) doMove("ENTER");
    }

    public function doMove(Where:String) {
        if(Where == "LEFT") {
            switch (SelButton) {
                case 1:
                    trace("Cant");
                case 2:
                    SelButton = 1;
            }
        } else if (Where == "RIGHT") {
            switch (SelButton) {
                case 1:
                    SelButton = 2;
                case 2:
                    trace("Cant");
            }
        } else if (Where == "ENTER") {
            switch (SelButton) {
                case 1:
                    FlxG.switchState(Config.onAccept);
                case 2:
                    FlxG.switchState(Config.onDecline);
            }
        }
    }
}