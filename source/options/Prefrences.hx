package options;


import flixel.text.FlxText;
import flixel.FlxSprite;
import flixel.FlxG;
import flixel.group.FlxSpriteGroup;

class Preferances extends MusicBeatState {
    public var options = ["Downscroll"];

    public var id = 1;
    public var curSelected = 1;

    public var group = new FlxSpriteGroup();

    public var des:FlxText;

    override public function create() {


        var bg = new MenuBackground();
        bg.blueBG();
        add(bg);

        des = new FlxText(0,669,0,"Description Text", 30);
        add(des);


        for (i in options) {
            if (id == 1) {
                var Option = new Alphabet(0,13,i,true,false);
                Option.ID = id;

                add(Option);
                group.add(Option);

                id++;
            } else {
                var Option = new Alphabet(0,13*id,i,true,false);
                Option.ID = id;

                Option.alpha = 0.7;

                add(Option);
                group.add(Option);  

                id++;
            }
        } 

        super.create();
    }

    override public function update(elapsed:Float) {
        super.update(elapsed);

        group.forEach(function(spr:FlxSprite) {
            spr.screenCenter(X);
        });

        checkText();

        if(FlxG.keys.justPressed.DOWN) {changeItem('DOWN');}
        if (FlxG.keys.justPressed.UP) {changeItem('UP');}
        if (FlxG.keys.justPressed.ENTER) {runOperation();}
        if (FlxG.keys.justPressed.ESCAPE) {FlxG.switchState(new OptionsState());}
    }

    public function checkText() {
        var daChoice = options[curSelected-1];
        switch(daChoice) {
            case "Downscroll":
                if (FlxG.save.data.downscroll) {
                    des.text = "Flip the strumline. Status : On";
                } else {
                    des.text = "Flip the strumline. Status : Off";
                }
        }

        des.screenCenter(X);
    }

    public function runOperation() {
        var daChoice = options[curSelected - 1];
        switch(daChoice) {
            case "Downscroll":
                FlxG.save.data.downscroll = !FlxG.save.data.downscroll;
        }
    }

    public function changeItem(way:String) {
        switch (way) {
            case "DOWN":
                if (curSelected == options.length) {
                    curSelected = 1;
                } else {
                    curSelected++;
                }
            case "UP":
                if (curSelected == 1) {
                    curSelected == options.length;
                } else {
                    curSelected += -1;
                }
        }

        group.forEach(function(spr:FlxSprite) {
            if (curSelected == spr.ID) {
                spr.alpha = 1;
            } else {
                spr.alpha = 0.7;
            }
        });
    }
}