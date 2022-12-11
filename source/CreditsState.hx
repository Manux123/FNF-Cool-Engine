package;

import flixel.FlxG;
import flixel.group.FlxSpriteGroup;
import flixel.FlxSprite;

class CreditsState extends MusicBeatState{
    public var bg:FlxSprite;

    public var credits = [
        'Cool Engine Team',
        'XuelDeveloper',
        'JotaroGaming',
        'Juanen100',
        'Shygee',
        '',
        'Funkin Team',
        'NinjaMuffin99',
        'Evilsk8r',
        'kawaisprite',
        'phantomArcade'
    ];

    var curSelected = 1;
    var id = 1;
    var timeBy = 1;

    var blanks = 0;

    var group = new FlxSpriteGroup();

    override public function create() {
        super.create();


		var yScroll:Float = Math.max(0.25 - (0.05 * (credits.length - 4)), 0.1);
		var bg:FlxSprite = new FlxSprite(-80).loadGraphic(Paths.image('menuBGBlue'));
		bg.scrollFactor.set(0, yScroll);
		bg.setGraphicSize(Std.int(bg.width * 1.175));
		bg.updateHitbox();
		bg.screenCenter();
		bg.antialiasing = true;
		add(bg);

        for (i in credits) {
            if (i == "") {
                trace("Blank!");
                timeBy++;
                blanks++;
            } else {
                if (id == 1) {
                    var Person = new Alphabet(13, 100, i, true,false);
                    Person.alpha = 1;
                    Person.ID = id;
    
                    add(Person);
                    group.add(Person);
    
                    id++;
                    timeBy++;
    
                    FlxG.camera.follow(Person, null, 0.7);
    
                } else {
                    
                    var Person = new Alphabet(13, 100*timeBy, i, true,false);
                    Person.alpha = 0.7;
                    Person.ID = id;
    
                    add(Person);
                    group.add(Person);
    
                    id++;
                    timeBy++;
                }
            }

        }
    }

    override public function update(elapsed) {
        super.update(elapsed);

        group.forEach(function(spr:FlxSprite) {
            spr.screenCenter(X);
        });

        if (FlxG.keys.justPressed.DOWN) {changeItem(1);}
        if (FlxG.keys.justPressed.UP) {changeItem(-1);}
    }

    public function changeItem(huh:Int) {
        curSelected += huh;
        
        if (curSelected == credits.length - blanks) {
            curSelected = 1;
        }
        if (curSelected == 1) {
            curSelected =  credits.length - blanks;
        }

        group.forEach(function(spr:FlxSprite) {
            if (curSelected == spr.ID) {
                spr.alpha = 1;
                FlxG.camera.follow(spr, null, 0.7);
            } else {
                spr.alpha = 0.7;
            }
        });
    } 
}