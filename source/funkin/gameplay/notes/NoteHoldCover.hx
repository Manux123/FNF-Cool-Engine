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
 * Animaciones esperadas en el atlas (por color: Purple, Blue, Green, Red):
 *   holdCoverStart{Color}   — inicio  (no looping)
 *   holdCover{Color}        — loop continuo
 *   holdCoverEnd{Color}     — fin/release (no looping → kill)
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
		// Empezamos muerto/invisible hasta que se recicle del pool
		kill();
	}

	// ─────────────── API pública ──────────────────────────────────────────────

	/**
	 * Inicializar/reciclar el cover para una nota.
	 * Carga el atlas si el splash skin cambió o si los frames son inválidos.
	 *
	 * @param x         Posición X (centro del strum)
	 * @param y         Posición Y (centro del strum)
	 * @param noteData  Columna de la nota (0-3)
	 * @param splashName  Skin de splash a usar (null = currentSplash)
	 */
	public function setup(x:Float, y:Float, noteData:Int, ?splashName:String):Void
	{
		this.noteData = noteData;
		this.x = x;
		this.y = y;
		inUse = true;

		var targetSplash:String = splashName != null ? splashName : NoteSkinSystem.currentSplash;

		// Solo recargar si el skin cambió o el bitmap fue destruido
		@:privateAccess
		var needsReload = (_loadedSplash != targetSplash)
			|| frames == null
			|| frames.parent == null
			|| frames.parent.bitmap == null;

		if (needsReload)
		{
			if (!_loadFrames(noteData, targetSplash))
			{
				// Sin assets → cover invisible, no crashea
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

	/** Reproducir animación de release; al terminar, el cover se mata solo.
	 *  Si el cover está todavía en "start", espera a que termine antes de hacer end.
	 *  Devuelve false si se pospuso (todavía en start). */
	public function playEnd():Bool
	{
		// No interrumpir la animación de inicio — se resolverá en _onAnimationFinished
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
		// Limpiar estado de animación para que no quede un frame fantasma al reciclar
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
	 * Cargar frames del atlas para todos los colores del splash skin.
	 * Devuelve false si el skin no tiene holdCover assets.
	 */
	private function _loadFrames(noteData:Int, splashName:String):Bool
	{
		// Intentar cargar con el splash name indicado
		var color:String = COLOR_NAMES[noteData];
		var loaded:FlxAtlasFrames = NoteSkinSystem.getHoldCoverTexture(color, splashName);

		if (loaded == null)
		{
			// Fallback: intentar con el splash por defecto
			loaded = NoteSkinSystem.getHoldCoverTexture(color);
		}

		if (loaded == null) return false;

		frames = loaded;
		antialiasing = true;
		scale.set(1.0, 1.0);

		// Registrar animaciones para los 4 colores (el atlas puede tener todas)
		if (animation != null) animation.destroyAnimations();

		for (i in 0...4)
		{
			var c:String = COLOR_NAMES[i];
			animation.addByPrefix('holdCoverStart$c', 'holdCoverStart$c', FRAMERATE_DEFAULT, false);
			animation.addByPrefix('holdCover$c', 'holdCover$c', FRAMERATE_DEFAULT * 2, true);
			animation.addByPrefix('holdCoverEnd$c', 'holdCoverEnd$c', FRAMERATE_DEFAULT, false);
		}

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
				playEnd();   // se pidió end mientras estaba en start → ejecutar ahora
			else
				playContinue();
		}
		else if (name.startsWith('holdCoverEnd'))
		{
			kill();
		}
	}
}
