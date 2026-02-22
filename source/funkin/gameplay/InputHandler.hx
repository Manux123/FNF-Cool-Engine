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
	public var killBind:Array<FlxKey> = [R];

	// === INPUT STATE ===
	public var pressed:Array<Bool> = [false, false, false, false]; // Presionado este frame
	public var held:Array<Bool> = [false, false, false, false]; // Mantenido
	public var released:Array<Bool> = [false, false, false, false]; // Soltado este frame

	// === CALLBACKS ===
	public var onNoteHit:Note->Void = null;
	public var onNoteMiss:funkin.gameplay.notes.Note->Void = null;
	public var onKeyRelease:Int->Void = null; // NUEVO: Callback cuando se suelta una tecla (para hold notes)

	// === CONFIG ===
	public var ghostTapping:Bool = true; // No penalizar teclas incorrectas
	public var inputBuffering:Bool = true; // Buffer de inputs para mejor timing
	public var bufferTime:Float = 0.1; // Tiempo de buffer en segundos (100ms)

	// === ANTI-MASH ===
	private var mashCounter:Int = 0;
	private var mashViolations:Int = 0;

	private static inline var MAX_MASH_VIOLATIONS:Int = 8;
	
	// === INPUT BUFFER ===
	private var bufferedInputs:Array<Float> = [0, 0, 0, 0]; // Tiempo del último input por dirección
	private var inputProcessed:Array<Bool> = [false, false, false, false]; // Si el input ya fue procesado

	public function new()
	{
		leftBind[0] = FlxKey.fromString(FlxG.save.data.leftBind);
		downBind[0] = FlxKey.fromString(FlxG.save.data.downBind);
		upBind[0] = FlxKey.fromString(FlxG.save.data.upBind);
		rightBind[0] = FlxKey.fromString(FlxG.save.data.rightBind);
		killBind[0] = FlxKey.fromString(FlxG.save.data.killBind);
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
	 * OPTIMIZADO: Una sola pasada por todas las notas
	 * MEJORADO: Con sistema de input buffering
	 */
	public function processInputs(notes:FlxTypedGroup<Note>):Void
	{
		// Contar teclas presionadas este frame
		var keysPressed:Int = 0;
		for (p in pressed)
			if (p)
				keysPressed++;

		mashCounter = keysPressed;
		
		// Actualizar buffer de inputs
		var currentTime = FlxG.game.ticks / 1000.0; // Tiempo actual en segundos
		for (dir in 0...4)
		{
			if (pressed[dir])
			{
				bufferedInputs[dir] = currentTime;
				inputProcessed[dir] = false;
			}
		}

		// OPTIMIZACIÓN: Una sola pasada para obtener todas las notas disponibles
		var possibleNotesByDir:Array<Array<Note>> = [[], [], [], []];
		
		notes.forEachAlive(function(note:Note)
		{
			if (note.canBeHit && note.mustPress && !note.tooLate && !note.wasGoodHit && !note.isSustainNote)
			{
				possibleNotesByDir[note.noteData].push(note);
			}
		});

		// Ordenar cada dirección por tiempo (solo una vez)
		for (dir in 0...4)
		{
			if (possibleNotesByDir[dir].length > 0)
				possibleNotesByDir[dir].sort((a, b) -> Std.int(a.strumTime - b.strumTime));
		}

		// Procesar cada dirección (buffered o pressed)
		for (dir in 0...4)
		{
			// Verificar si hay input válido (recién presionado o en buffer)
			var hasValidInput = false;
			
			if (pressed[dir])
			{
				hasValidInput = true;
			}
			else if (inputBuffering && !inputProcessed[dir])
			{
				// Verificar si hay un input en buffer que no ha expirado
				var timeSinceInput = currentTime - bufferedInputs[dir];
				if (timeSinceInput <= bufferTime)
					hasValidInput = true;
			}
			
			if (!hasValidInput)
				continue;

			var possibleNotes = possibleNotesByDir[dir];

			if (possibleNotes.length > 0)
			{
				// Hit la nota más cercana
				var note = possibleNotes[0];

				// Anti-mash check - OPTIMIZADO: usar length en vez de llamar a getAvailableNotes()
				if (mashCounter <= possibleNotes.length + 1 || mashViolations > MAX_MASH_VIOLATIONS)
				{
					if (onNoteHit != null)
					{
						onNoteHit(note);
						inputProcessed[dir] = true; // Marcar como procesado
					}
				}
				else
				{
					mashViolations++;
				}
			}
			else if (!ghostTapping && pressed[dir]) // Solo penalizar si fue presionado este frame
			{
				// Miss por ghost tap
				if (onNoteMiss != null)
					onNoteMiss(null); // ghost tap — no hay nota concreta
				inputProcessed[dir] = true;
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
				trace('[InputHandler] ❌ MISS DETECTADO! noteData=${note.noteData}, tooLate=${note.tooLate}');
				
				// Evitamos que se procese de nuevo
				note.tooLate = false;
				note.canBeHit = false;

				// Ejecutamos el callback de fallo (penalización)
				if (onNoteMiss != null)
				{
					trace('[InputHandler] Llamando onNoteMiss para noteData=${note.noteData}');
					onNoteMiss(note);
				}
				else
				{
					trace('[InputHandler] ERROR: onNoteMiss es NULL!');
				}

				// Opcional: eliminar la nota para optimizar
				note.kill();
			}
		});
	}

	/**
	 * Procesar sustain notes (hold)
	 * OPTIMIZADO: Una sola pasada por todas las notas
	 */
	public function processSustains(notes:FlxTypedGroup<Note>):Void
	{
		// OPTIMIZACIÓN: Una sola pasada, procesar todas las direcciones
		notes.forEachAlive(function(note:Note)
		{
			// Solo procesar sustains que están siendo presionadas
			if (note.canBeHit && note.mustPress && note.isSustainNote && !note.wasGoodHit)
			{
				// Verificar si la tecla correspondiente está siendo presionada
				if (held[note.noteData])
				{
					if (onNoteHit != null)
						onNoteHit(note);
				}
			}
		});
	}

	/**
	 * Reset mashing y buffer de inputs
	 */
	public function resetMash():Void
	{
		mashViolations = 0;
		mashCounter = 0;
	}
	
	/**
	 * Limpiar buffer de inputs (útil al pausar/resetear)
	 */
	public function clearBuffer():Void
	{
		for (i in 0...4)
		{
			bufferedInputs[i] = 0;
			inputProcessed[i] = false;
		}
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
