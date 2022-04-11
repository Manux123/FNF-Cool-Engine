package;

import flixel.FlxG;
import flixel.FlxSprite;

class Button extends FlxSprite{
    var canOverllap:Bool = true;
    public function new(x:Float,y:Float,?file:String = "button",?defaultAnimation:String="default-anim",?overllapAnimation:String="overllap-anim",?onPressAnimation:String="press-anim",?canOverllap:Bool=true) {
        super(x,y);
        this.canOverllap = canOverllap;
        
        try{
            FlxG.mouse.visible = true;
            frames = Paths.getSparrowAtlas(file);
            animation.addByPrefix('idle',defaultAnimation,24,true);
            animation.addByPrefix('overllap',overllapAnimation,24,true);
            animation.addByPrefix('press',onPressAnimation,24,false);
            animation.play("idle");
        }catch(e){
            throw "Something failed while loading the button";
        }
    }

    var onClick:Void->Void = function(){
        return trace("clicked");
    };
    override function update(elapsed){
        super.update(elapsed);
        if(FlxG.mouse.overlaps(this)){
            if(FlxG.mouse.pressed && canOverllap){
                animation.play("press",true);
                onClick();
            }
            else if(animation.curAnim.name != "press")
                animation.play("overllap");
        }
        else
            animation.play('idle');
    }
}