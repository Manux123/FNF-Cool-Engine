package;

import flixel.system.FlxBasePreloader;
import openfl.text.TextFormat;
import openfl.text.TextField;
import openfl.text.Font;
import flash.display.BitmapData;

//THIS ONLY WORKS ON WEB
/**
 * This was maded for the Get Funky Engine
 * OG Code By: OverchargedDev
 */
@:bitmap("art/preloaderArt.png") class LogoImage extends BitmapData { }
@:font("assets/fonts/vcr.ttf") class Vcr extends Font {}
class Preloader extends FlxBasePreloader{
    public function new(MinDisplayTime:Float = 0){
        super();
    }
    override public function create(){
        super.create();

        logo = new Sprite();
        logo.addChild(new Bitmap(new LogoImage(0,0)));
        logo.scaleX = logo.scaleX*4;
        logo.scaleY = logo.scaleY*4;
        addChild(logo);

        Font.registerFont(Vcr);
        final text = new TextField();
        text.defaultTextFormat = new TextFormat("vcr",24,0xffffff);
        text.embedFonts = true;
        text.text = "Loading...";
        text.width = 109;
        text.x = 1138;
        text.y = -668;
        addChild(text);
    }
}