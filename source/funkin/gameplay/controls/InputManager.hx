package funkin.gameplay.controls;

import flixel.FlxG;

class InputManager
{
	public static inline var LEFT  = 0;
	public static inline var DOWN  = 1;
	public static inline var UP    = 2;
	public static inline var RIGHT = 3;

	public static var justPressed:Array<Bool> = [false, false, false, false];
	public static var pressed:Array<Bool>     = [false, false, false, false];
	public static var released:Array<Bool>    = [false, false, false, false];

	public static function update():Void
	{
		check(LEFT,  FlxG.keys.justPressed.A, FlxG.keys.pressed.A, FlxG.keys.justReleased.A);
		check(DOWN,  FlxG.keys.justPressed.S, FlxG.keys.pressed.S, FlxG.keys.justReleased.S);
		check(UP,    FlxG.keys.justPressed.W, FlxG.keys.pressed.W, FlxG.keys.justReleased.W);
		check(RIGHT, FlxG.keys.justPressed.D, FlxG.keys.pressed.D, FlxG.keys.justReleased.D);
	}

	static inline function check(id:Int, jp:Bool, p:Bool, jr:Bool)
	{
		justPressed[id] = jp;
		pressed[id]     = p;
		released[id]    = jr;
	}
}