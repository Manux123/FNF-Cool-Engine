package funkin.gameplay;

import flixel.FlxG;
import funkin.gameplay.notes.Note;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.input.keyboard.FlxKey;

using StringTools;

/**
 * InputHandler - Manejo optimizado de inputs
 * Detecta teclas, procesa hits, maneja combos
 * 
 * MEJORADO: Ahora con callback onKeyRelease para hold notes
 */
class InputHandler
{
	// === KEYBINDS ===
	public var leftBind:Array<FlxKey> = [A, LEFT];
	public var downBind:Array<FlxKey> = [S, DOWN];
	public var upBind:Array<FlxKey> = [W, UP];
	public var rightBind:Array<FlxKey> = [D, RIGHT];

	// === INPUT STATE ===
	public var pressed:Array<Bool> = [false, false, false, false]; // Presionado este frame
	public var held:Array<Bool> = [false, false, false, false]; // Mantenido
	public var released:Array<Bool> = [false, false, false, false]; // Soltado este frame

	// === CALLBACKS ===
	public var onNoteHit:Note->Void = null;
	public var onNoteMiss:Int->Void = null;
	public var onKeyRelease:Int->Void = null; // NUEVO: Callback cuando se suelta una tecla (para hold notes)

	// === CONFIG ===
	public var ghostTapping:Bool = true; // No penalizar teclas incorrectas

	// === ANTI-MASH ===
	private var mashCounter:Int = 0;
	private var mashViolations:Int = 0;

	private static inline var MAX_MASH_VIOLATIONS:Int = 8;

	public function new()
	{
		leftBind[0] = FlxKey.fromString(FlxG.save.data.leftBind);
		downBind[0] = FlxKey.fromString(FlxG.save.data.downBind);
		upBind[0] = FlxKey.fromString(FlxG.save.data.upBind);
		rightBind[0] = FlxKey.fromString(FlxG.save.data.rightBind);
	}

	/**
	 * Actualizar estado de inputs
	 */
	public function update():Void
	{
		// Reset arrays
		for (i in 0...4)
		{
			pressed[i] = false;
			released[i] = false;
		}

		// Detectar inputs usando controls
		if (FlxG.keys.anyJustPressed(leftBind))
			pressed[0] = true;
		if (FlxG.keys.anyJustPressed(downBind))
			pressed[1] = true;
		if (FlxG.keys.anyJustPressed(upBind))
			pressed[2] = true;
		if (FlxG.keys.anyJustPressed(rightBind))
			pressed[3] = true;

		if (FlxG.keys.anyPressed(leftBind))
			held[0] = true;
		else
			held[0] = false;

		if (FlxG.keys.anyPressed(downBind))
			held[1] = true;
		else
			held[1] = false;

		if (FlxG.keys.anyPressed(upBind))
			held[2] = true;
		else
			held[2] = false;

		if (FlxG.keys.anyPressed(rightBind))
			held[3] = true;
		else
			held[3] = false;

		// NUEVO: Detectar releases y llamar callback
		if (FlxG.keys.anyJustReleased(leftBind))
		{
			released[0] = true;
			if (onKeyRelease != null)
				onKeyRelease(0);
		}
		if (FlxG.keys.anyJustReleased(downBind))
		{
			released[1] = true;
			if (onKeyRelease != null)
				onKeyRelease(1);
		}
		if (FlxG.keys.anyJustReleased(upBind))
		{
			released[2] = true;
			if (onKeyRelease != null)
				onKeyRelease(2);
		}
		if (FlxG.keys.anyJustReleased(rightBind))
		{
			released[3] = true;
			if (onKeyRelease != null)
				onKeyRelease(3);
		}
	}

	/**
	 * Procesar inputs contra notas disponibles
	 */
	public function processInputs(notes:FlxTypedGroup<Note>):Void
	{
		// Contar teclas presionadas este frame
		var keysPressed:Int = 0;
		for (p in pressed)
			if (p)
				keysPressed++;

		mashCounter = keysPressed;

		// Procesar cada dirección presionada
		for (dir in 0...4)
		{
			if (!pressed[dir])
				continue;

			// Buscar notas disponibles en esta dirección
			var possibleNotes:Array<Note> = [];

			notes.forEachAlive(function(note:Note)
			{
				if (note.canBeHit && note.mustPress && !note.tooLate && !note.wasGoodHit)
				{
					if (note.noteData == dir)
						possibleNotes.push(note);
				}
			});

			// Ordenar por tiempo
			possibleNotes.sort((a, b) -> Std.int(a.strumTime - b.strumTime));

			if (possibleNotes.length > 0)
			{
				// Hit la nota más cercana
				var note = possibleNotes[0];

				// Anti-mash check
				if (mashCounter <= getAvailableNotes(notes, dir) + 1 || mashViolations > MAX_MASH_VIOLATIONS)
				{
					if (onNoteHit != null)
						onNoteHit(note);
				}
				else
				{
					mashViolations++;
				}
			}
			else if (!ghostTapping)
			{
				// Miss por ghost tap
				if (onNoteMiss != null)
					onNoteMiss(dir);
			}
		}
	}

	public function checkMisses(notes:FlxTypedGroup<Note>):Void
	{
		notes.forEachAlive(function(note:Note)
		{
			// Si la nota debe ser presionada, no ha sido golpeada y ya es tarde
			if (note.mustPress && !note.wasGoodHit && note.tooLate)
			{
				// Evitamos que se procese de nuevo
				note.tooLate = false;
				note.canBeHit = false;

				// Ejecutamos el callback de fallo (penalización)
				if (onNoteMiss != null)
					onNoteMiss(note.noteData);

				// Opcional: eliminar la nota para optimizar
				note.kill();
			}
		});
	}

	/**
	 * Contar notas disponibles en una dirección
	 */
	private function getAvailableNotes(notes:FlxTypedGroup<Note>, direction:Int):Int
	{
		var count:Int = 0;
		notes.forEachAlive(function(note:Note)
		{
			if (note.canBeHit && note.mustPress && !note.tooLate && note.noteData == direction)
				count++;
		});
		return count;
	}

	/**
	 * Procesar sustain notes (hold)
	 */
	public function processSustains(notes:FlxTypedGroup<Note>):Void
	{
		for (dir in 0...4)
		{
			if (!held[dir])
				continue;

			notes.forEachAlive(function(note:Note)
			{
				if (note.canBeHit && note.mustPress && note.isSustainNote && !note.wasGoodHit)
				{
					if (note.noteData == dir)
					{
						if (onNoteHit != null)
							onNoteHit(note);
					}
				}
			});
		}
	}

	/**
	 * Reset mashing
	 */
	public function resetMash():Void
	{
		mashViolations = 0;
		mashCounter = 0;
	}

	/**
	 * Verificar si alguna tecla está siendo presionada
	 */
	public function anyKeyHeld():Bool
	{
		for (h in held)
			if (h)
				return true;
		return false;
	}
}
