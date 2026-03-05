package funkin.gameplay;

import flixel.FlxG;
import funkin.gameplay.notes.Note;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.input.keyboard.FlxKey;

using StringTools;

/**
 * InputHandler — Manejo de inputs del jugador.
 *
 * OPTIMIZACIONES vs versión anterior:
 *
 *  1. possibleNotesByDir es un Array<Array<Note>> PREALLOCADO como campo de instancia.
 *     Antes se creaba `[[], [], [], []]` cada frame → 5 allocs × 60fps = 300 allocs/seg
 *     de objetos de corta vida que presionan el GC. Ahora se hace .resize(0) en su lugar.
 *
 *  2. forEachAlive() eliminado del hot path. Creaba un closure (heap alloc) en cada llamada.
 *     Reemplazado por iteración directa sobre members[i] con chequeo manual alive/canBeHit.
 *
 *  3. Sort lambda reemplazado por función estática — cero closures en el sort.
 *
 *  4. processInputs y processSustains son llamados ~60-120 veces/seg;
 *     eliminar los closures es lo más importante de todo.
 */
class InputHandler
{
	// === KEYBINDS ===
	public var leftBind:Array<FlxKey>  = [A, LEFT];
	public var downBind:Array<FlxKey>  = [S, DOWN];
	public var upBind:Array<FlxKey>    = [W, UP];
	public var rightBind:Array<FlxKey> = [D, RIGHT];
	public var killBind:Array<FlxKey>  = [R];

	// === INPUT STATE ===
	public var pressed:Array<Bool>  = [false, false, false, false];
	public var held:Array<Bool>     = [false, false, false, false];
	public var released:Array<Bool> = [false, false, false, false];

	// === CALLBACKS ===
	public var onNoteHit:Note->Void    = null;
	public var onNoteMiss:Note->Void   = null;
	public var onKeyRelease:Int->Void  = null;
	public var onKeyPress:Int->Void    = null;

	// === CONFIG ===
	public var ghostTapping:Bool   = true;
	public var inputBuffering:Bool = true;
	public var bufferTime:Float    = 0.1;

	// === ANTI-MASH ===
	private var mashCounter:Int    = 0;
	private var mashViolations:Int = 0;
	private static inline var MAX_MASH_VIOLATIONS:Int = 8;

	// === INPUT BUFFER ===
	private var bufferedInputs:Array<Float> = [0, 0, 0, 0];
	private var inputProcessed:Array<Bool>  = [false, false, false, false];

	// ── PREALLOCADOS — cero allocs en el hot path ────────────────────────────
	// Antes: [[], [], [], []] nuevo cada frame = 5 allocs × 60fps = 300 allocs/seg
	// Ahora: resize(0) en su lugar — el array interno no se reasigna.
	private var _notesByDir0:Array<Note> = [];
	private var _notesByDir1:Array<Note> = [];
	private var _notesByDir2:Array<Note> = [];
	private var _notesByDir3:Array<Note> = [];

	public function new()
	{
		leftBind[0]  = FlxKey.fromString(FlxG.save.data.leftBind);
		downBind[0]  = FlxKey.fromString(FlxG.save.data.downBind);
		upBind[0]    = FlxKey.fromString(FlxG.save.data.upBind);
		rightBind[0] = FlxKey.fromString(FlxG.save.data.rightBind);
		killBind[0]  = FlxKey.fromString(FlxG.save.data.killBind);
	}

	// ─── UPDATE ──────────────────────────────────────────────────────────────

	public function update():Void
	{
		pressed[0] = pressed[1] = pressed[2] = pressed[3] = false;
		released[0] = released[1] = released[2] = released[3] = false;

		if (FlxG.keys.anyJustPressed(leftBind))  pressed[0] = true;
		if (FlxG.keys.anyJustPressed(downBind))  pressed[1] = true;
		if (FlxG.keys.anyJustPressed(upBind))    pressed[2] = true;
		if (FlxG.keys.anyJustPressed(rightBind)) pressed[3] = true;

		held[0] = FlxG.keys.anyPressed(leftBind);
		held[1] = FlxG.keys.anyPressed(downBind);
		held[2] = FlxG.keys.anyPressed(upBind);
		held[3] = FlxG.keys.anyPressed(rightBind);

		if (FlxG.keys.anyJustReleased(leftBind))
		{
			released[0] = true;
			if (onKeyRelease != null) onKeyRelease(0);
		}
		if (FlxG.keys.anyJustReleased(downBind))
		{
			released[1] = true;
			if (onKeyRelease != null) onKeyRelease(1);
		}
		if (FlxG.keys.anyJustReleased(upBind))
		{
			released[2] = true;
			if (onKeyRelease != null) onKeyRelease(2);
		}
		if (FlxG.keys.anyJustReleased(rightBind))
		{
			released[3] = true;
			if (onKeyRelease != null) onKeyRelease(3);
		}
	}

	// ─── PROCESS INPUTS ──────────────────────────────────────────────────────

	/**
	 * Procesa inputs del jugador contra las notas disponibles.
	 *
	 * OPT: iteración directa sobre members[] en lugar de forEachAlive().
	 *      forEachAlive() asigna un closure nuevo en el heap cada llamada.
	 *      Con iteración directa hay cero allocs en este path.
	 *
	 * OPT: possibleNotesByDir usa arrays preallocados (resize vs new).
	 *
	 * OPT: sort comparator es función estática — cero closures.
	 */
	public function processInputs(notes:FlxTypedGroup<Note>):Void
	{
		if (funkin.gameplay.PlayState.isBotPlay)
		{
			pressed[0] = pressed[1] = pressed[2] = pressed[3] = false;
			held[0]    = held[1]    = held[2]    = held[3]    = false;
			released[0]= released[1]= released[2]= released[3]= false;

			// Iteración directa — sin closure
			final members = notes.members;
			final len = members.length;
			for (i in 0...len)
			{
				final note = members[i];
				if (note == null || !note.alive) continue;
				if (note.canBeHit && note.mustPress && !note.tooLate
					&& !note.wasGoodHit && !note.isSustainNote)
				{
					if (onNoteHit != null) onNoteHit(note);
					pressed[note.noteData] = true;
					if (onKeyPress != null) onKeyPress(note.noteData);
				}
			}
			return;
		}

		var keysPressed:Int = 0;
		if (pressed[0]) keysPressed++;
		if (pressed[1]) keysPressed++;
		if (pressed[2]) keysPressed++;
		if (pressed[3]) keysPressed++;
		mashCounter = keysPressed;

		final currentTime = FlxG.game.ticks / 1000.0;
		for (dir in 0...4)
		{
			if (pressed[dir])
			{
				bufferedInputs[dir] = currentTime;
				inputProcessed[dir] = false;
			}
		}

		// Limpiar buckets preallocados — resize(0) no reasigna memoria interna
		_notesByDir0.resize(0);
		_notesByDir1.resize(0);
		_notesByDir2.resize(0);
		_notesByDir3.resize(0);

		// Clasificar notas por dirección — iteración directa, sin closure
		final members = notes.members;
		final len = members.length;
		for (i in 0...len)
		{
			final note = members[i];
			if (note == null || !note.alive) continue;
			if (note.canBeHit && note.mustPress && !note.tooLate
				&& !note.wasGoodHit && !note.isSustainNote)
			{
				switch (note.noteData)
				{
					case 0: _notesByDir0.push(note);
					case 1: _notesByDir1.push(note);
					case 2: _notesByDir2.push(note);
					case 3: _notesByDir3.push(note);
				}
			}
		}

		// Ordenar por tiempo (función estática — cero closures)
		if (_notesByDir0.length > 1) _notesByDir0.sort(_compareByStrumTime);
		if (_notesByDir1.length > 1) _notesByDir1.sort(_compareByStrumTime);
		if (_notesByDir2.length > 1) _notesByDir2.sort(_compareByStrumTime);
		if (_notesByDir3.length > 1) _notesByDir3.sort(_compareByStrumTime);

		_processDir(0, _notesByDir0, currentTime);
		_processDir(1, _notesByDir1, currentTime);
		_processDir(2, _notesByDir2, currentTime);
		_processDir(3, _notesByDir3, currentTime);
	}

	/** Comparador estático — reutilizado por todos los sorts, cero allocs. */
	static function _compareByStrumTime(a:Note, b:Note):Int
		return Std.int(a.strumTime - b.strumTime);

	private inline function _processDir(dir:Int, possibleNotes:Array<Note>, currentTime:Float):Void
	{
		var hasValidInput = pressed[dir];

		if (!hasValidInput && inputBuffering && !inputProcessed[dir])
			hasValidInput = (currentTime - bufferedInputs[dir]) <= bufferTime;

		if (!hasValidInput) return;

		if (possibleNotes.length > 0)
		{
			if (mashCounter <= possibleNotes.length + 1 || mashViolations > MAX_MASH_VIOLATIONS)
			{
				if (onNoteHit != null)
				{
					onNoteHit(possibleNotes[0]);
					inputProcessed[dir] = true;
				}
			}
			else
			{
				mashViolations++;
			}
		}
		else if (!ghostTapping && pressed[dir])
		{
			if (onNoteMiss != null) onNoteMiss(null);
			inputProcessed[dir] = true;
		}
	}

	// ─── PROCESS SUSTAINS ────────────────────────────────────────────────────

	/**
	 * Procesa sustain notes del jugador.
	 * OPT: iteración directa — sin forEachAlive/closure.
	 */
	public function processSustains(notes:FlxTypedGroup<Note>):Void
	{
		final members = notes.members;
		final len = members.length;

		if (funkin.gameplay.PlayState.isBotPlay)
		{
			for (i in 0...len)
			{
				final note = members[i];
				if (note == null || !note.alive) continue;
				if (note.mustPress && note.isSustainNote && !note.wasGoodHit
					&& note.canBeHit && !note.tooLate)
				{
					held[note.noteData] = true;
					if (onNoteHit != null) onNoteHit(note);
				}
			}
			return;
		}

		for (i in 0...len)
		{
			final note = members[i];
			if (note == null || !note.alive) continue;
			if (note.canBeHit && note.mustPress && note.isSustainNote
				&& !note.wasGoodHit && held[note.noteData])
			{
				if (onNoteHit != null) onNoteHit(note);
			}
		}
	}

	// No-op mantenido por compatibilidad
	public function checkMisses(notes:FlxTypedGroup<Note>):Void {}

	public function resetMash():Void
	{
		mashViolations = 0;
		mashCounter    = 0;
	}

	public function clearBuffer():Void
	{
		bufferedInputs[0] = bufferedInputs[1] = bufferedInputs[2] = bufferedInputs[3] = 0;
		inputProcessed[0] = inputProcessed[1] = inputProcessed[2] = inputProcessed[3] = false;
	}

	public function anyKeyHeld():Bool
		return held[0] || held[1] || held[2] || held[3];
}
