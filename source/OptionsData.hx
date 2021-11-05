package;

import flixel.FlxG;

class OptionsData
{
	public static function initSave()
		{
			if (FlxG.save.data.newInput == null)
				FlxG.save.data.newInput = true;
	
			if (FlxG.save.data.downscroll == null)
				FlxG.save.data.downscroll = false;
	
			if (FlxG.save.data.dfjk == null)
				FlxG.save.data.dfjk = false;
	
			if (FlxG.save.data.accuracyDisplay == null)
				FlxG.save.data.accuracyDisplay = true;
	
			if (FlxG.save.data.accuracyDisplay == null)
				FlxG.save.data.accuracyDisplay = true;

			if (FlxG.save.data.notesplashes == null)
				FlxG.save.data.notesplashes = true;
	
			if (FlxG.save.data.offset == null)
				FlxG.save.data.offset = 0;
			
			if(FlxG.save.data.perfectmode = null)
				FlxG.save.data.perfectmode = false;

			if(FlxG.save.data.sickmode = null)
				FlxG.save.data.sickmode = false;

			if(FlxG.save.data.animatedstage = null)
				FlxG.save.data.animatedstage = true;

			if(FlxG.save.data.gfbye = null)
				FlxG.save.data.gfbye = true;

			if(FlxG.save.data.byebg = null)
				FlxG.save.data.byebg = true;
		}
}
