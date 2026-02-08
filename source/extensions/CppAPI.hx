package extensions;

import extensions.InitAPI;
import Main;
import openfl.Lib;
import flixel.FlxG;
import flixel.system.scaleModes.StageSizeScaleMode;
import flixel.system.scaleModes.BaseScaleMode;

class CppAPI
{	
	public static function changeColor(r:Int,g:Int,b:Int)
	{
		return InitAPI.setWindowBorderColor(r,g,b);
	}
	
}