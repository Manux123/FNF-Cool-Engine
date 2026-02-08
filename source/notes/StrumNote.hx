package notes;

import flixel.FlxSprite;
import flixel.FlxG;
import states.PlayState;
import lime.utils.Assets;

class StrumNote extends FlxSprite
{
	public var noteID:Int = 0;

	var animArrow:Array<String> = ['LEFT','DOWN','UP','RIGHT'];

	var animColor:Array<String> = ['purple','blue','green','red'];

	public function new(x:Float, y:Float, noteID:Int = 0)
	{
		super(x, y);
		
		this.noteID = noteID;
		
		// Inicializar sistema
		NoteSkinSystem.init();
		
		var daStage:String = PlayState.curStage;
		
		switch (daStage)
		{
			case 'school' | 'schoolEvil':
				loadPixelStrum();
			default:
				loadNormalStrum();
		}
		
		updateHitbox();
		scrollFactor.set();
	}

	function loadPixelStrum():Void
	{
		var pixelTex = NoteSkinSystem.getPixelNoteSkin();
		
		if (pixelTex != null)
			frames = pixelTex;
		else
			loadGraphic('assets/skins/arrows-pixels.png');
		// Animaciones base pixel
		animation.add('green', [6]);
		animation.add('red', [7]);
		animation.add('blue', [5]);
		animation.add('purple', [4]);
		
		setGraphicSize(Std.int(width * PlayState.daPixelZoom));
		updateHitbox();
		antialiasing = false;
		
		// Animaciones específicas por dirección (pixel)
		switch (Math.abs(noteID))
		{
			case 0:
				x += Note.swagWidth * 0;
				animation.add('static', [0]);
				animation.add('pressed', [4, 8], 12, false);
				animation.add('confirm', [12, 16], 24, false);
			case 1:
				x += Note.swagWidth * 1;
				animation.add('static', [1]);
				animation.add('pressed', [5, 9], 12, false);
				animation.add('confirm', [13, 17], 24, false);
			case 2:
				x += Note.swagWidth * 2;
				animation.add('static', [2]);
				animation.add('pressed', [6, 10], 12, false);
				animation.add('confirm', [14, 18], 12, false);
			case 3:
				x += Note.swagWidth * 3;
				animation.add('static', [3]);
				animation.add('pressed', [7, 11], 12, false);
				animation.add('confirm', [15, 19], 24, false);
		}
	}

	function loadNormalStrum():Void
	{
		// Obtener frames y animaciones de la skin actual
		var tex = NoteSkinSystem.getNoteSkin();
		frames = tex;
		
		var anims = NoteSkinSystem.getSkinAnimations();
		
		if (anims != null)
		{
			// Cargar animaciones configurables
			loadConfigurableAnimations(anims);
		}
		else
		{
			// Fallback a animaciones default
			loadDefaultStrumAnimations();
		}
		
		antialiasing = true;
		setGraphicSize(Std.int(width * 0.7));
	}

	function loadConfigurableAnimations(anims:NoteSkinSystem.NoteAnimations):Void
	{
		switch (Math.abs(noteID))
		{
			case 0: // Left
				x += Note.swagWidth * 0;
				if (anims.strumLeft != null)
					animation.addByPrefix('static', anims.strumLeft);
				if (anims.strumLeftPress != null)
					animation.addByPrefix('pressed', anims.strumLeftPress, 24, false);
				if (anims.strumLeftConfirm != null)
					animation.addByPrefix('confirm', anims.strumLeftConfirm, 24, false);
					
			case 1: // Down
				x += Note.swagWidth * 1;
				if (anims.strumDown != null)
					animation.addByPrefix('static', anims.strumDown);
				if (anims.strumDownPress != null)
					animation.addByPrefix('pressed', anims.strumDownPress, 24, false);
				if (anims.strumDownConfirm != null)
					animation.addByPrefix('confirm', anims.strumDownConfirm, 24, false);
					
			case 2: // Up
				x += Note.swagWidth * 2;
				if (anims.strumUp != null)
					animation.addByPrefix('static', anims.strumUp);
				if (anims.strumUpPress != null)
					animation.addByPrefix('pressed', anims.strumUpPress, 24, false);
				if (anims.strumUpConfirm != null)
					animation.addByPrefix('confirm', anims.strumUpConfirm, 24, false);
					
			case 3: // Right
				x += Note.swagWidth * 3;
				if (anims.strumRight != null)
					animation.addByPrefix('static', anims.strumRight);
				if (anims.strumRightPress != null)
					animation.addByPrefix('pressed', anims.strumRightPress, 24, false);
				if (anims.strumRightConfirm != null)
					animation.addByPrefix('confirm', anims.strumRightConfirm, 24, false);
		}
		
		// Verificar que al menos static existe, si no, cargar default
		if (!animation.exists('static'))
		{
			trace('Warning: Static animation not found for strum ${noteID}, loading defaults');
			loadDefaultStrumAnimations();
		}
	}

	function loadDefaultStrumAnimations():Void
	{
		// Animaciones default de FNF
		
		for (i in 0...Std.int(Math.abs(noteID)))
		{
			x += Note.swagWidth * i;
			animation.addByPrefix('static', 'arrow'+animArrow[i]);
			animation.addByPrefix('pressed', animArrow[i].toLowerCase() + ' press',24,false);
			animation.addByPrefix('confirm', animArrow[i].toLowerCase() + ' confirm',24,false);
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
	}
}
