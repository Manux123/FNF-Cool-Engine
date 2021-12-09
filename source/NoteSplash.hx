package;

import flixel.FlxG;
import flixel.FlxSprite;

class NoteSplash extends FlxSprite
{
	public function new(x:Float = 0, y:Float = 0, ?note:Int = 0,?skin:String) {
		super(x, y);
		if(skin == null)skin = 'noteSplashes';
		setupAnimations(skin);

		setupNoteSplash(x, y, note);
	}

	public function setupNoteSplash(x:Float, y:Float, ?note:Int = 0) {
		setPosition(x - Note.swagWidth * 0.95, y - Note.swagWidth);
		alpha = 0.6;
		animation.play('note' + note + '-' + FlxG.random.int(1, 2), true);
		animation.curAnim.frameRate = 24 + FlxG.random.int(-2, 2);
		updateHitbox();
		offset.set(Std.int(0.3 * width), Std.int(0.3 * height));
	}
	
	public function setupAnimations(?skin:String){
		frames = Paths.getSparrowAtlas('UI/$skin');
		for(i in 1... 3){
			animation.addByPrefix("note1-" + i, "note impact " + i + " blue", 24, false);
			animation.addByPrefix("note2-" + i, "note impact " + i +" green", 24, false);
			animation.addByPrefix("note0-" + i, "note impact " + i + " purple", 24, false);
			animation.addByPrefix("note3-" + i, "note impact" + i +" red", 24, false);

			trace('note impact ' + i + ' is ready');
		}
	}

	override public function update(elapsed)
	{
		if (animation.curAnim.finished)
			kill();
		super.update(elapsed);
	}
}
