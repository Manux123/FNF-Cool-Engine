package;

import NoteSkinDetector;
import flixel.FlxG;
import flixel.FlxSprite;

class NoteSplash extends FlxSprite
{
	public function new(x:Float = 0, y:Float = 0, ?note:Int = 0,?skin:String = 'noteSplashes_3') {
		super(x, y);
		setupAnimations(skin);

		setupNoteSplash(x, y, note);
	}

	public function setupNoteSplash(x:Float, y:Float, ?direction:Int = 0) {
		setPosition(x - Note.swagWidth * 0.95, y - Note.swagWidth);
		alpha = 0.6;

		var animNum:Int = FlxG.random.int(1, 2);
		animation.play('note' + direction + '-' + animNum, true);
		if(animation.curAnim != null)animation.curAnim.frameRate = 24 + FlxG.random.int(-2, 2);
		offset.set(10, 10);
	}

	var posibleShit:Array<String> = [" purple"," blue"," green"," red"];
	
	public function setupAnimations(?skin:String){
		frames = NoteSkinDetector.noteSplashSkin(skin);
		for(i in 1...3){
			for(y in 0...5){
				animation.addByPrefix("note" + y + "-" + i, "note impact " + i + posibleShit[y], 24, false);
			}
		}
	}

	override public function update(elapsed)
	{
		if (animation.curAnim.finished)
			kill();
		super.update(elapsed);
	}
}
