package ui;

import openfl.display.Sprite;
import openfl.display.Shape;
import ui.FPSCount;

class DataInfoUI extends Sprite
{
    public var fps:FPSCount;
    public var dataText:FPSCount.DataText;

    public function new(x:Float, y:Float)
    {
        super();
        
        var bg:Shape = new Shape();
        bg.graphics.beginFill(0x000000, 0.6);
        bg.graphics.drawRect(x, y, 130, 70);
        bg.graphics.endFill();
        addChild(bg);

        fps = new FPSCount(x, y, 0xFFFFFF);
        dataText = new DataText(x, y + 15);

        addChild(fps);
        addChild(dataText);

        this.visible = true;
        fps.visible = true;
        dataText.visible = true;
    }
}