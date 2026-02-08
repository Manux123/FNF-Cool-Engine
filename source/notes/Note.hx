package notes;

import lime.utils.Assets;
import states.PlayState;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
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
	public var noteRating:String = 'sick';

	public static var swagWidth:Float = 160 * 0.7;
	public static var PURP_NOTE:Int = 0;
	public static var BLUE_NOTE:Int = 1;
	public static var GREEN_NOTE:Int = 2;
	public static var RED_NOTE:Int = 3;

	var animArrows:Array<String> = ['purple', 'blue', 'green', 'red'];

	public function new(strumTime:Float, noteData:Int, ?prevNote:Note, ?sustainNote:Bool = false)
	{
		super();

		if (prevNote == null)
			prevNote = this;

		this.prevNote = prevNote;
		isSustainNote = sustainNote;

		x += (FlxG.save.data.middlescroll ? -250 : 0) + 100;
		y -= 2000;
		this.strumTime = strumTime + FlxG.save.data.offset;
		this.noteData = noteData;

		// Inicializar sistema
		NoteSkinSystem.init();

		var daStage:String = PlayState.curStage;

		switch (daStage)
		{
			case 'school' | 'schoolEvil':
				loadPixelNotes();
			default:
				loadNormalNotes();
		}

		// Posicionar y animar según dirección
		setupNoteDirection();

		// Configurar sustains
		if (isSustainNote && prevNote != null)
		{
			setupSustainNote();
		}
	}

	function loadPixelNotes():Void
	{
		// CORREGIDO: Cargar diferentes texturas según si es sustain o no
		if (isSustainNote)
		{
			var pixelEndsTex = NoteSkinSystem.getPixelNoteEnds();

			if (pixelEndsTex != null)
				frames = pixelEndsTex;
			else
				loadGraphic('assets/skins/Default/arrowEnds.png');

			// ANIMATIONS for hold ends
			for (i in 0...animArrows.length)
			{
				animation.add(animArrows[i] + 'holdend', [noteData + 4]);
				animation.add(animArrows[i] + 'hold', [noteData]);
			}
		}
		else
		{
			var pixelTex = NoteSkinSystem.getPixelNoteSkin();
			if (pixelTex != null)
				frames = pixelTex;
			else
				loadGraphic('assets/skins/Default/arrows-pixels.png');

			// Animations pixel (statics)
			for (anim in animArrows)
			{
				animation.add(anim + 'Scroll', [noteData + 4]);
			}
		}

		setGraphicSize(Std.int(width * PlayState.daPixelZoom));
		updateHitbox();
		antialiasing = false;
	}

	function loadNormalNotes():Void
	{
		// Obtener frames y animaciones de la skin actual
		frames = NoteSkinSystem.getNoteSkin();
		var anims = NoteSkinSystem.getSkinAnimations();

		if (anims != null)
		{
			var animTypes = [
				{key: 'Scroll', anims: [anims.left, anims.down, anims.up, anims.right]},
				{key: 'holdend', anims: [anims.leftHoldEnd, anims.downHoldEnd, anims.upHoldEnd, anims.rightHoldEnd]},
				{key: 'hold', anims: [anims.leftHold, anims.downHold, anims.upHold, anims.rightHold]}
			];

			for (animType in animTypes)
			{
				for (i in 0...animArrows.length)
				{
					if (animType.anims[i] != null)
						animation.addByPrefix(animArrows[i] + animType.key, animType.anims[i]);
				}
			}
		}
		else
		{
			// Fallback a animaciones default
			loadDefaultAnimations();
		}

		setGraphicSize(Std.int(width * 0.7));
		updateHitbox();
		antialiasing = true;
	}

	function loadDefaultAnimations():Void
	{
		// Animaciones por defecto de FNF
		var animPrefixes = [
			{key: 'Scroll', prefixes: ['purple0', 'blue0', 'green0', 'red0']},
			{key: 'holdend', prefixes: ['pruple end hold', 'blue hold end', 'green hold end', 'red hold end']},
			{key: 'hold', prefixes: ['purple hold piece', 'blue hold piece', 'green hold piece', 'red hold piece']}
		];

		for (animType in animPrefixes)
		{
			for (i in 0...animArrows.length)
			{
				animation.addByPrefix(animArrows[i] + animType.key, animType.prefixes[i]);
			}
		}
	}

	function setupNoteDirection():Void
	{
		for (i in 0...animArrows.length)
		{
			if (noteData == i)
			{
				x += swagWidth * i;
				animation.play(animArrows[i] + 'Scroll');
				break;
			}
		}
	}

	function setupSustainNote():Void
	{
		noteScore * 0.2;
		alpha = 0.6;

		if (FlxG.save.data.downscroll)
		{
			flipY = true;
			flipX = true;
		}

		x += width / 2;

		// Animar hold end según dirección
		for (i in 0...animArrows.length)
		{
			if (noteData == i)
			{
				animation.play(animArrows[i] + 'holdend');
				break;
			}
		}

		updateHitbox();
		x -= width / 2;

		if (PlayState.curStage.startsWith('school'))
		{
			x += 30;
		}

		// Configurar previous note hold

		if (prevNote.isSustainNote)
		{
			for (i in 0...animArrows.length)
			{
				if (prevNote.noteData == i)
				{
					prevNote.animation.play(animArrows[i] + 'hold');
					break;
				}
			}
			
			prevNote.scale.y *= Conductor.stepCrochet / 100 * 1.5 * PlayState.SONG.speed;

			if (PlayState.curStage.startsWith('school'))
				prevNote.scale.y *= 1.19;

			prevNote.updateHitbox();
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (mustPress)
		{
			// Ventana de hit más generosa
			var hitWindowMultiplier = isSustainNote ? 1.05 : 1.0;
			var safeZone = Conductor.safeZoneOffset * hitWindowMultiplier;

			canBeHit = (strumTime > Conductor.songPosition - safeZone && strumTime < Conductor.songPosition + safeZone);

			if (strumTime < Conductor.songPosition - safeZone && !wasGoodHit)
				tooLate = true;
		}
		else
		{
			canBeHit = false;

			if (strumTime <= Conductor.songPosition)
				wasGoodHit = true;
		}

		if (tooLate && alpha > 0.3)
			alpha = 0.3;
	}
}
