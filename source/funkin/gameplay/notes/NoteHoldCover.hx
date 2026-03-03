package funkin.gameplay.notes;

import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import funkin.gameplay.notes.NoteSkinSystem;

using StringTools;

/**
 * Cover visual para notas largas (hold notes).
 *
 * Basado en el patrón de v-slice (NoteHoldCover.hx):
 * - Clase separada de NoteSplash — responsabilidad única
 * - Máquina de estados: start → loop → end, transiciones en onAnimationFinished
 * - Object pooling limpio con kill()/revive()
 * - Skin de splash determinada por NoteSkinSystem.currentSplash
 *
 * FIX: _loadFrames ahora solo registra animaciones del color correspondiente
 * al noteData cargado. Antes registraba los 4 colores sobre un atlas de 1 color,
 * lo que producía warnings "no frames were found" para los 3 restantes.
 */
class NoteHoldCover extends FlxSprite
{
	static final FRAMERATE_DEFAULT:Int = 24;
	static final COLOR_NAMES:Array<String> = ["Purple", "Blue", "Green", "Red"];

	/** Dirección/columna de la nota (0=left 1=down 2=up 3=right). */
	public var noteData:Int = 0;

	/** true mientras el cover está siendo utilizado (no está en el pool). */
	public var inUse:Bool = false;

	/** Estado actual de la máquina de animación. */
	public var coverState:String = "idle"; // "start" | "continue" | "end" | "idle"

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
	 * Inicializar/reciclar el cover para una nota.
	 * Carga el atlas si el splash skin cambió o si los frames son inválidos.
	 *
	 * @param x          Posición X (centro del strum)
	 * @param y          Posición Y (centro del strum)
	 * @param noteData   Columna de la nota (0-3)
	 * @param splashName Skin de splash a usar (null = currentSplash)
	 */
	public function setup(x:Float, y:Float, noteData:Int, ?splashName:String):Void
	{
		this.noteData = noteData;
		this.x = x;
		this.y = y;
		inUse = true;

		var targetSplash:String = splashName != null ? splashName : NoteSkinSystem.currentSplash;

		@:privateAccess
		var needsReload = (_loadedSplash != targetSplash)
			|| frames == null
			|| frames.parent == null
			|| frames.parent.bitmap == null;

		if (needsReload)
		{
			if (!_loadFrames(noteData, targetSplash))
			{
				makeGraphic(1, 1, 0x00000000);
				inUse = false;
				visible = false;
				return;
			}
			_loadedSplash = targetSplash;
		}

		alpha = 1.0;
		visible = true;
		revive();
	}

	/** Iniciar secuencia: reproduce la animación de inicio. */
	public function playStart():Void
	{
		coverState = "start";
		_playAnim('holdCoverStart${COLOR_NAMES[noteData]}');
	}

	/** Reproducir loop continuo mientras se sostiene la nota. */
	public function playContinue():Void
	{
		coverState = "continue";
		_playAnim('holdCover${COLOR_NAMES[noteData]}');
	}

	/**
	 * Reproducir animación de release; al terminar, el cover se mata solo.
	 * Si el cover está todavía en "start", espera a que termine antes de hacer end.
	 * Devuelve false si se pospuso (todavía en start).
	 */
	public function playEnd():Bool
	{
		if (coverState == "start")
		{
			coverState = "end_pending";
			return false;
		}
		var endAnim = 'holdCoverEnd${COLOR_NAMES[noteData]}';
		if (!animation.exists(endAnim))
		{
			kill();
			return true;
		}
		coverState = "end";
		_playAnim(endAnim);
		return true;
	}

	// ─────────────────────────────────────────────────────────────────────────

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);
	}

	override function kill():Void
	{
		super.kill();
		inUse = false;
		visible = false;
		coverState = "idle";
		if (animation != null && animation.curAnim != null)
			animation.stop();
	}

	override function revive():Void
	{
		super.revive();
		visible = true;
	}

	// ─────────────── Internos ────────────────────────────────────────────────

	/**
	 * Cargar frames del atlas para el color de esta nota.
	 *
	 * FIX: Solo se registran las animaciones del color cargado (COLOR_NAMES[noteData]).
	 * Antes se iteraban los 4 colores sobre un atlas de 1 color, generando warnings
	 * "no frames were found with prefix holdCover{OtroColor}" para los 3 restantes.
	 *
	 * Devuelve false si el skin no tiene holdCover assets.
	 */
	private function _loadFrames(noteData:Int, splashName:String):Bool
	{
		var color:String = COLOR_NAMES[noteData];
		var loaded:FlxAtlasFrames = NoteSkinSystem.getHoldCoverTexture(color, splashName);

		if (loaded == null)
			loaded = NoteSkinSystem.getHoldCoverTexture(color);

		if (loaded == null) return false;

		frames = loaded;
		antialiasing = true;
		scale.set(1.0, 1.0);

		if (animation != null) animation.destroyAnimations();

		// FIX: registrar SOLO las animaciones del color de esta nota.
		// El atlas solo contiene prefijos de ese color — registrar otros
		// causa los warnings "no frames were found with prefix holdCover*".
		animation.addByPrefix('holdCoverStart$color', 'holdCoverStart$color', FRAMERATE_DEFAULT, false);
		animation.addByPrefix('holdCover$color',      'holdCover$color',      FRAMERATE_DEFAULT * 2, true);
		animation.addByPrefix('holdCoverEnd$color',   'holdCoverEnd$color',   FRAMERATE_DEFAULT, false);

		animation.finishCallback = _onAnimationFinished;

		updateHitbox();
		offset.set(width * 0.3, height * 0.3);

		return true;
	}

	private function _playAnim(name:String, force:Bool = true):Void
	{
		if (!animation.exists(name))
		{
			trace('[NoteHoldCover] Animación no encontrada: $name');
			return;
		}
		animation.play(name, force);
	}

	private function _onAnimationFinished(name:String):Void
	{
		if (name.startsWith('holdCoverStart'))
		{
			if (coverState == "end_pending")
				playEnd();
			else
				playContinue();
		}
		else if (name.startsWith('holdCoverEnd'))
		{
			kill();
		}
	}
}