package;

import states.CacheState.ImageCache;
import lime.utils.Assets;
import states.NoteSkinState;
import states.PlayState;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.math.FlxMath;
import flixel.util.FlxColor;
import flixel.graphics.frames.FlxFramesCollection;
import openfl.display.BitmapData;
import flixel.FlxG;

using StringTools;

class Note extends FlxSprite
{
	public var strumTime:Float = 0;

	public var mustPress:Bool = false;
	public var noteData:Int = 0;
	public var canBeHit:Bool = false;
	public var tooLate:Bool = false;
	public var wasGoodHit:Bool = false;
	public var prevNote:Note;

	public var sustainLength:Float = 0;
	public var isSustainNote:Bool = false;

	public var noteScore:Float = 1;

	public static var swagWidth:Float = 160 * 0.7;
	public static var PURP_NOTE:Int = 0;
	public static var GREEN_NOTE:Int = 2;
	public static var BLUE_NOTE:Int = 1;
	public static var RED_NOTE:Int = 3;

	public var noteRating:String = 'sick';

	public var dataColor:Array<String> = ['purple', 'blue', 'green', 'red'];

	public function new(strumTime:Float, noteData:Int, ?prevNote:Note, ?sustainNote:Bool = false)
	{
		super();

		if (prevNote == null)
			prevNote = this;

		this.prevNote = prevNote;
		isSustainNote = sustainNote;

		x += (FlxG.save.data.middlescroll ? -250 : 0) + 50;
		// MAKE SURE ITS DEFINITELY OFF SCREEN?
		y -= 2000;
		this.strumTime = strumTime + FlxG.save.data.offset;

		this.noteData = noteData;

		//var noteSkin:String = states.NoteSkinDetectorState.noteskindetector;
		var daStage:String = states.PlayState.SONG.stage;
		
		switch (daStage)
		{
			case 'school' | 'schoolEvil':
				loadGraphic(NoteSkinDetector.noteSkinPixel(FlxG.save.data.noteSkin), true, 17, 17);
				if (isSustainNote)
					loadGraphic(NoteSkinDetector.noteSkinPixel(FlxG.save.data.noteSkin), true, 7, 6);

				for (i in 0...4)
				{
					animation.add(dataColor[i] + 'Scroll', [i + 4]); // Normal notes
					animation.add(dataColor[i] + 'hold', [i]); // Holds
					animation.add(dataColor[i] + 'holdend', [i + 4]); // Tails
				}

				setGraphicSize(Std.int(width * states.PlayState.daPixelZoom));
				updateHitbox();

			default:
				loadAnimationsFromTextFile(Std.string(FlxG.save.data.noteSkin));
				setGraphicSize(Std.int(width * 0.7));
				updateHitbox();
				antialiasing = true;
		}
		

		switch (noteData)
		{
			case 0:
				x += swagWidth * 0;
				animation.play('purpleScroll');
			case 1:
				x += swagWidth * 1;
				animation.play('blueScroll');
			case 2:
				x += swagWidth * 2;
				animation.play('greenScroll');
			case 3:
				x += swagWidth * 3;
				animation.play('redScroll');
		}

		// trace(prevNote);

		if (isSustainNote && prevNote != null)
		{
			noteScore * 0.2;
			alpha = 0.6;

			if(FlxG.save.data.downscroll){
				flipY = true;
				flipX = true;
			}

			x += width / 2;

			switch (noteData)
			{
				case 2:
					animation.play('greenholdend');
				case 3:
					animation.play('redholdend');
				case 1:
					animation.play('blueholdend');
				case 0:
					animation.play('purpleholdend');
			}

			updateHitbox();

			x -= width / 2;

			if (states.PlayState.SONG.stage.startsWith('school'))
				x += 30;

			if (prevNote.isSustainNote)
			{
				switch (prevNote.noteData)
				{
					case 0:
						prevNote.animation.play('purplehold');
					case 1:
						prevNote.animation.play('bluehold');
					case 2:
						prevNote.animation.play('greenhold');
					case 3:
						prevNote.animation.play('redhold');
				}

				prevNote.scale.y *= Conductor.stepCrochet / 100 * 1.5 * states.PlayState.SONG.speed;
				prevNote.updateHitbox();
				// prevNote.setGraphicSize();
			}
		}
	}

	function loadAnimationsFromTextFile(cum:String){
		var coolFile = CoolUtil.coolTextFile(Paths.txt('skin/${cum}'));

		frames = NoteSkinDetector.noteSkinNormal();

		for(i in 0...coolFile.length){
			var animations = coolFile[i].split(':');
			animation.addByPrefix(animations[0],animations[1]);
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (mustPress)
		{
			// The * 0.5 is so that it's easier to hit them too late, instead of too early
			if (strumTime > Conductor.songPosition - Conductor.safeZoneOffset
				&& strumTime < Conductor.songPosition + (Conductor.safeZoneOffset * (isSustainNote ? 0.5 : 1)))
				canBeHit = true;
			else
				canBeHit = false;

			if (strumTime < Conductor.songPosition - Conductor.safeZoneOffset && !wasGoodHit)
				tooLate = true;
		}
		else
		{
			canBeHit = false;

			if (strumTime <= Conductor.songPosition)
				wasGoodHit = true;
		}

		if (tooLate)
		{
			if (alpha > 0.3)
				alpha = 0.3;
		}
	}
}
