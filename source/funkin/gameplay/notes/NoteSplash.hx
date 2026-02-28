package funkin.gameplay.notes;

import flixel.FlxG;
import flixel.FlxSprite;
import funkin.gameplay.notes.NoteSkinSystem;
import funkin.gameplay.notes.NoteSkinSystem.NoteSplashData;

/**
 * Splash visual que aparece al golpear una nota normal.
 *
 * Basado en el patrón limpio de v-slice (NoteSplash.hx):
 * - Responsabilidad única: splashes de hit, sin ningún código de hold
 * - Object pooling con kill()/revive()
 * - Animaciones registradas una sola vez; se reaprovechan entre reciclajes
 * - Skin soportada vía NoteSkinSystem
 *
 * Para splashes de hold notes, ver NoteHoldCover.hx
 */
class NoteSplash extends FlxSprite
{
	/** Dirección de la nota (0=left 1=down 2=up 3=right). */
	public var noteData:Int = 0;

	/** true mientras el splash está en uso (no en el pool). */
	public var inUse:Bool = false;

	/** Nombre del splash skin con el que se cargaron los frames actuales. */
	private var _loadedSplash:String = "";

	// ─────────────────────────────────────────────────────────────────────────

	public function new()
	{
		super(0, 0);
		kill();
	}

	// ─────────────── API pública ──────────────────────────────────────────────

	/**
	 * Inicializar/reciclar el splash para una nota.
	 *
	 * @param x          Posición X
	 * @param y          Posición Y
	 * @param noteData   Columna de la nota (0-3)
	 * @param splashName Skin de splash (null = currentSplash)
	 */
	public function setup(x:Float, y:Float, noteData:Int = 0, ?splashName:String):Void
	{
		this.x = x;
		this.y = y;
		this.noteData = noteData;
		inUse = true;

		var targetSplash:String = splashName != null ? splashName : NoteSkinSystem.currentSplash;

		// Obtener datos del splash
		var splashData:NoteSplashData = NoteSkinSystem.getSplashData(targetSplash);
		if (splashData == null)
		{
			_fallback();
			return;
		}

		// Solo recargar atlas si el skin cambió o el bitmap fue destruido
		@:privateAccess
		var needsReload = (_loadedSplash != targetSplash)
			|| frames == null
			|| frames.parent == null
			|| frames.parent.bitmap == null;

		if (needsReload)
		{
			if (!_loadFrames(splashData, targetSplash))
			{
				_fallback();
				return;
			}
			_loadedSplash = targetSplash;
		}

		alpha = 0.8;
		visible = true;
		revive();

		_playRandomAnim(splashData, noteData);
	}

	// ─────────────────────────────────────────────────────────────────────────

	override function kill():Void
	{
		super.kill();
		inUse = false;
		visible = false;
	}

	override function revive():Void
	{
		super.revive();
		visible = true;
	}

	// ─────────────── Internos ────────────────────────────────────────────────

	/**
	 * Cargar el atlas y registrar todas las animaciones.
	 * Solo se llama cuando el skin realmente cambió.
	 */
	private function _loadFrames(splashData:NoteSplashData, splashName:String):Bool
	{
		var loaded = NoteSkinSystem.getSplashTexture(splashName);
		if (loaded == null) return false;

		frames = loaded;

		var assets = splashData.assets;
		scale.set(assets.scale != null ? assets.scale : 1.0, assets.scale != null ? assets.scale : 1.0);
		antialiasing = assets.antialiasing != null ? assets.antialiasing : true;

		if (assets.offset != null && assets.offset.length >= 2)
		{
			x += assets.offset[0];
			y += assets.offset[1];
		}

		// Registrar animaciones para las 4 direcciones
		if (animation != null) animation.destroyAnimations();

		var anims = splashData.animations;
		var framerate:Int = anims.framerate != null ? anims.framerate : 24;
		var dirs = ["left", "down", "up", "right"];
		var dirAnims = [anims.left, anims.down, anims.up, anims.right];

		for (i in 0...4)
		{
			var animList:Array<String> = dirAnims[i];
			if (animList == null) continue;
			for (j in 0...animList.length)
			{
				animation.addByPrefix('${dirs[i]}_$j', animList[j], framerate, false);
			}
		}

		animation.finishCallback = _onAnimationFinished;

		updateHitbox();
		offset.set(width * 0.3, height * 0.3);

		return true;
	}

	/**
	 * Reproducir una variante aleatoria de la dirección indicada.
	 */
	private function _playRandomAnim(splashData:NoteSplashData, noteData:Int):Void
	{
		var dirs = ["left", "down", "up", "right"];
		var dirAnims = [splashData.animations.left, splashData.animations.down,
						splashData.animations.up, splashData.animations.right];

		var animList:Array<String> = dirAnims[noteData];
		if (animList == null || animList.length == 0) return;

		var variant:Int = FlxG.random.int(0, animList.length - 1);
		var animName:String = '${dirs[noteData]}_$variant';

		if (animation.exists(animName))
		{
			var range:Int = splashData.animations.randomFramerateRange != null ? splashData.animations.randomFramerateRange : 2;
			var baseFps:Int = splashData.animations.framerate != null ? splashData.animations.framerate : 24;

			animation.play(animName, true);
			if (animation.curAnim != null)
				animation.curAnim.frameRate = baseFps + FlxG.random.int(-range, range);
		}
	}

	private function _onAnimationFinished(name:String):Void
	{
		kill();
	}

	private function _fallback():Void
	{
		makeGraphic(1, 1, 0x00000000);
		inUse = false;
		visible = false;
	}
}
