package funkin.gameplay.notes;

import flixel.FlxSprite;
import flixel.FlxG;
import funkin.gameplay.PlayState;
import lime.utils.Assets;
import funkin.gameplay.PlayStateConfig;

using StringTools;

class StrumNote extends FlxSprite
{
	public var noteID:Int = 0;

	var animArrow:Array<String> = ['LEFT', 'DOWN', 'UP', 'RIGHT'];

	// ── Estado de skin ────────────────────────────────────────────────────

	/** true si la skin tiene isPixel:true. */
	private var _isPixelSkin:Bool = false;

	/** Si la skin aplica el offset -13,-13 al confirm. */
	private var _skinConfirmOffset:Bool = true;

	public function new(x:Float, y:Float, noteID:Int = 0)
	{
		super(x, y);

		this.noteID = noteID;

		NoteSkinSystem.init();
		loadSkin(NoteSkinSystem.getCurrentSkinData());

		updateHitbox();
		scrollFactor.set();
		animation.play('static');
		centerOffsets();
	}

	// ==================== CARGA DE SKIN ====================

	/**
	 * Carga la textura y las animaciones de strum desde un NoteSkinData.
	 *
	 * Sin ninguna referencia a PlayState.curStage.
	 * El índice noteID determina qué animaciones cargar (left/down/up/right).
	 */
	function loadSkin(skinData:NoteSkinSystem.NoteSkinData):Void
	{
		if (skinData == null)
			return;

		_isPixelSkin = skinData.isPixel == true;

		// confirmOffset: leer del JSON; si no está, true para normal, false para pixel
		_skinConfirmOffset = skinData.confirmOffset != null ? skinData.confirmOffset : (skinData.offsetDefault != null ? skinData.offsetDefault : !_isPixelSkin);

		// ── Cargar textura principal (strums siempre usan texture, nunca holdTexture) ──
		var tex = skinData.texture;
		frames = NoteSkinSystem.loadSkinFrames(tex, skinData.folder);

		var noteScale = tex.scale != null ? tex.scale : 1.0;
		// BUGFIX: usar scale.set() directo en lugar de setGraphicSize(width*scale)
		// que usaría el hitbox stale si loadSkin() se llamara de nuevo (recarga de skin).
		scale.set(noteScale, noteScale);
		updateHitbox();

		antialiasing = tex.antialiasing != null ? tex.antialiasing : !_isPixelSkin;

		// ── Cargar animaciones ────────────────────────────────────────────
		var anims = skinData.animations;
		if (anims == null)
		{
			loadDefaultStrumAnimations();
			return;
		}

		var i = Std.int(Math.abs(noteID));

		var strumDefs = [anims.strumLeft, anims.strumDown, anims.strumUp, anims.strumRight];
		var pressDefs = [
			anims.strumLeftPress,
			anims.strumDownPress,
			anims.strumUpPress,
			anims.strumRightPress
		];
		var confirmDefs = [
			anims.strumLeftConfirm,
			anims.strumDownConfirm,
			anims.strumUpConfirm,
			anims.strumRightConfirm
		];

		// 'static' may loop freely; 'pressed' and 'confirm' must NOT loop so that
		// animation.curAnim.finished becomes true and the auto-reset to 'static'
		// fires correctly.  We pass overrideLoop=false for those two.
		// Previously the code tried to set FlxAnimation.looped after registration,
		// but that field is read-only in HaxeFlixel — this is the correct fix.
		NoteSkinSystem.addAnimToSprite(this, 'static', strumDefs[i]);
		NoteSkinSystem.addAnimToSprite(this, 'pressed', pressDefs[i], false);
		NoteSkinSystem.addAnimToSprite(this, 'confirm', confirmDefs[i], false);

		// Fallback si no se definió animación estática
		if (!animation.exists('static'))
		{
			trace('[StrumNote] "static" no encontrada en skin "${skinData.name}" para noteID $noteID — cargando defaults');
			loadDefaultStrumAnimations();
		}
	}

	/** Recarga la skin en un strum existente (útil en rewind para corregir scale). */
	public function reloadSkin(skinData:NoteSkinSystem.NoteSkinData):Void
	{
		loadSkin(skinData);
		animation.play('static');
		centerOffsets();
	}

	function loadDefaultStrumAnimations():Void
	{
		var i = Std.int(Math.abs(noteID));
		animation.addByPrefix('static', 'arrow' + animArrow[i]);
		animation.addByPrefix('pressed', animArrow[i].toLowerCase() + ' press', 24, false);
		animation.addByPrefix('confirm', animArrow[i].toLowerCase() + ' confirm', 24, false);
	}

	// ==================== ANIMACIÓN ====================

	/**
	 * Reproduce una animación de forma segura.
	 * Aplica el offset -13,-13 al confirm si la skin lo requiere (confirmOffset:true).
	 * centerOffsets() siempre resetea el offset, por lo que el ajuste se re-aplica
	 * en cada llamada a confirm para mantener la posición correcta.
	 */
	public function playAnim(animName:String, force:Bool = false):Void
	{
		if (animation == null)
			return;

		animation.play(animName, force);
		centerOffsets();

		// centerOffsets() resetea el offset a 0, así que re-aplicar -13,-13
		// siempre que la animación sea 'confirm' para mantener la posición correcta.
		if (animName == 'confirm' && _skinConfirmOffset)
		{
			offset.x -= 13;
			offset.y -= 13;
		}
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		// Auto-reset confirm → static cuando termina la animación
		if (animation.curAnim != null && animation.curAnim.name == 'confirm' && animation.curAnim.finished)
		{
			playAnim('static');
		}
	}
}
