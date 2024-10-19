package;

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
		var daStage:String = states.PlayState.curStage;
		//if (noteSkin) {
			switch (daStage)
			{
				case 'school' | 'schoolEvil':
					if(Assets.exists(NoteSkinDetector.noteSkinPixel(FlxG.save.data.noteSkin)))
						loadGraphic(NoteSkinDetector.noteSkinPixel(FlxG.save.data.noteSkin));
					else{
						loadGraphic(Paths.image('skins_arrows/pixels/arrows-pixels'));
						trace('Assets Path: ' + NoteSkinDetector.noteSkinPixel(FlxG.save.data.noteSkin) + " Dosn't Exist");
					}
			
					animation.add('greenScroll', [6]);
					animation.add('redScroll', [7]);
					animation.add('blueScroll', [5]);
					animation.add('purpleScroll', [4]);

					if (isSustainNote)
					{
						if(Assets.exists(NoteSkinDetector.noteSkinPixel(FlxG.save.data.noteSkin)))
							loadGraphic(NoteSkinDetector.noteSkinPixel(FlxG.save.data.noteSkin));
						else{
							loadGraphic(Paths.image('skins_arrows/pixels/arrows-pixels'));
							trace('Assets Path: ' + NoteSkinDetector.noteSkinPixel(FlxG.save.data.noteSkin) + " Dosn't Exist");
						}

						animation.add('purpleholdend', [4]);
						animation.add('greenholdend', [6]);
						animation.add('redholdend', [7]);
						animation.add('blueholdend', [5]);

						animation.add('purplehold', [0]);
						animation.add('greenhold', [2]);
						animation.add('redhold', [3]);
						animation.add('bluehold', [1]);
					}

					setGraphicSize(Std.int(width * states.PlayState.daPixelZoom));
					updateHitbox();

				default:
					loadAnimationsFromTextFile(Std.string(FlxG.save.data.noteSkin));
					/*frames = NoteSkinDetector.noteSkinNormal();

					animation.addByPrefix('greenScroll', 'green alone');
					animation.addByPrefix('redScroll', 'red alone');
					animation.addByPrefix('blueScroll', 'blue alone');
					animation.addByPrefix('purpleScroll', 'purple alone');

					animation.addByPrefix('purpleholdend', 'purple tail');
					animation.addByPrefix('greenholdend', 'green tail');
					animation.addByPrefix('redholdend', 'red tail');
					animation.addByPrefix('blueholdend', 'blue tail');

					animation.addByPrefix('purplehold', 'purple hold');
					animation.addByPrefix('greenhold', 'green hold');
					animation.addByPrefix('redhold', 'red hold');
					animation.addByPrefix('bluehold', 'blue hold');*/

					setGraphicSize(Std.int(width * 0.7));
					updateHitbox();
					antialiasing = true;
			}
		//}

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

			if (states.PlayState.curStage.startsWith('school'))
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
