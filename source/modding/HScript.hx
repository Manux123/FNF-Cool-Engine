package modding;

import flixel.input.keyboard.FlxKey;
import flixel.FlxSprite;
import flixel.FlxG;
import flixel.text.FlxText;
import flixel.system.FlxSound;
import flixel.math.FlxMath;
import hscript.Parser;
import hscript.Interp;
import StringTools;



class SongScript {
    public var interp = new Interp();
	public var parser = new Parser();
	public var script:hscript.Expr;

	public function new()
	{
		parser.allowTypes = true;
		parser.allowJSON = true;
		parser.allowMetadata = true;
		interp.variables.set("create", FlxG.state.create);
		interp.variables.set("update", FlxG.state.update);
		interp.variables.set("Int", Int);
		interp.variables.set("String", String);
		interp.variables.set("Float", Float);
		interp.variables.set("Array", Array);
		interp.variables.set("Bool", Bool);
		interp.variables.set("Dynamic", Dynamic);
		interp.variables.set("Math", Math);
		interp.variables.set("Main", Main);
		interp.variables.set("FlxMath", FlxMath);
		interp.variables.set("Std", Std);
		interp.variables.set("StringTools", StringTools);
		interp.variables.set("FlxG",FlxG);
		interp.variables.set("FlxSound",FlxSound);
		interp.variables.set("FlxSprite",FlxSprite);
		interp.variables.set("FlxText",FlxText);
		interp.variables.set("Paths",ModPaths);
		interp.variables.set("CoolUtil",CoolUtil);

		interp.variables.set('Modchart', ModchartAPI);
	}

	public function call(funcName:String, ?args:Array<Dynamic>):Dynamic
	{
		if (args == null)
			args = [];
		// if(!running) return true;
		try
		{
			var func:Dynamic = interp.variables.get(funcName);
			if (func != null && Reflect.isFunction(func))
				return Reflect.callMethod(null, func, args);
		}
		catch (e)
		{
			// scriptType = EmptyScript;
			FlxG.log.add(e.details());
			// running = false;
		}
		return true;
	}

	public function loadScript(file:String)
	{
		script = parser.parseString(openfl.Assets.getText(ModPaths.getSongScript('$file')));
		interp.execute(script);
	}
}

class StoryScript {
	public var interp = new Interp();
	public var parser = new Parser();
	public var script:hscript.Expr;

	public function new()
	{
		parser.allowTypes = true;
		parser.allowJSON = true;
		parser.allowMetadata = true;

		// No need to set variables
	}

	public function call(funcName:String, ?args:Array<Dynamic>):Dynamic
	{
		if (args == null)
			args = [];
		// if(!running) return true;
		try
		{
			var func:Dynamic = interp.variables.get(funcName);
			if (func != null && Reflect.isFunction(func))
				return Reflect.callMethod(null, func, args);
		}
		catch (e)
		{
			// scriptType = EmptyScript;
			FlxG.log.add(e.details());
			// running = false;
		}
		return true;
	}

	public function loadScript(file:String)
	{
		script = parser.parseString(openfl.Assets.getText(ModPaths.getScript('$file')));
		interp.execute(script);
	}
}

class ControlsScript {
	public var interp = new Interp();
	public var parser = new Parser();
	public var script:hscript.Expr;

	public function new()
	{
		parser.allowTypes = true;
		parser.allowJSON = true;
		parser.allowMetadata = true;


		interp.variables.set('FlxG', FlxG);
	}

	public function call(funcName:String, ?args:Array<Dynamic>):Dynamic
	{
		if (args == null)
			args = [];
		// if(!running) return true;
		try
		{
			var func:Dynamic = interp.variables.get(funcName);
			if (func != null && Reflect.isFunction(func))
				return Reflect.callMethod(null, func, args);
		}
		catch (e)
		{
			// scriptType = EmptyScript;
			FlxG.log.add(e.details());
			// running = false;
		}
		return true;
	}

	public function loadScript(file:String)
	{
		script = parser.parseString(openfl.Assets.getText(ModPaths.getAScript('$file')));
		interp.execute(script);
	}
}

class ModchartAPI {
	public static function triggerEvent(event:String, ?arg1:Dynamic, ?arg2:Dynamic) {
		switch(event) {
			case "Camera Zoom":
				FlxG.camera.zoom += arg1;
		}
	}
}