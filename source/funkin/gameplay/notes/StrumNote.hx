package funkin.gameplay.notes;

import flixel.FlxSprite;
import flixel.FlxG;
import funkin.gameplay.PlayState;
import lime.utils.Assets;
import funkin.gameplay.PlayStateConfig;

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

		for (i in 0...animColor.length){
			animation.add(animColor[i],[i+4]);
		}
		
		setGraphicSize(Std.int(width * PlayStateConfig.PIXEL_ZOOM));
		updateHitbox();
		antialiasing = false;
		
		for (i in 0...4)
		{
			if (Math.abs(noteID) == i) 
    		{
				x += Note.swagWidth * i;
				animation.add('static', [i]);
				animation.add('pressed', [4+i, 8+i], 12, false);
				animation.add('confirm', [12+i, 16+i], 24, false);
			}
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
}