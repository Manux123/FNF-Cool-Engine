package funkin.gameplay.notes;

/**
 * NotePool — object pool de notas sin dependencia en FlxPool.
 *
 * ─── Por qué no FlxPool ──────────────────────────────────────────────────────
 * FlxPool<Note> requiere que Note tenga un constructor sin parámetros Y llama
 * internamente a `new Note()` cuando el pool está vacío, lo que ignora los
 * parámetros de `get()`. Usar un Array<Note> propio da control total.
 *
 * ─── Optimizaciones ──────────────────────────────────────────────────────────
 * • `prewarm()` sin arrays intermedios — push directo al pool.
 * • `put()` no consulta `pool.length` (O(n) en Array) — usa contador propio.
 * • `get()` / `put()` son las únicas funciones en el hot path; sin allocs.
 */
class NotePool
{
	static inline var INITIAL_SIZE : Int = 200;
	static inline var MAX_SIZE     : Int = 500;

	static var notePool    : Array<Note> = [];
	static var sustainPool : Array<Note> = [];

	static var noteCount    : Int  = 0;
	static var sustainCount : Int  = 0;

	// Stats
	public static var totalCreated  : Int = 0;
	public static var totalRecycled : Int = 0;
	public static var inUse         : Int = 0;
	public static var hits          : Int = 0;
	public static var misses        : Int = 0;

	static var initialized : Bool = false;

	// ─── Init ─────────────────────────────────────────────────────────────────

	public static function init():Void
	{
		if (initialized) return;
		prewarm(INITIAL_SIZE);
		initialized = true;
		trace('[NotePool] Listo — ${totalCreated} notas pre-creadas.');
	}

	/** Crea `count` notas y las devuelve al pool directamente, sin arrays intermedios. */
	static function prewarm(count:Int):Void
	{
		final half = count >> 1; // count / 2

		for (_ in 0...half)
		{
			notePool.push(new Note(0, 0, null, false, false));
			noteCount++;
			totalCreated++;
		}
		for (_ in 0...half)
		{
			sustainPool.push(new Note(0, 0, null, true, false));
			sustainCount++;
			totalCreated++;
		}
	}

	// ─── Hot path ─────────────────────────────────────────────────────────────

	/** Obtiene una nota del pool (o crea una nueva si está vacío). */
	public static function get(strumTime:Float, noteData:Int, ?prevNote:Note,
	                            sustainNote:Bool = false, mustHitNote:Bool = false):Note
	{
		if (!initialized) init();

		final pool  = sustainNote ? sustainPool  : notePool;
		final count = sustainNote ? sustainCount : noteCount;
		var note : Note;

		if (count > 0)
		{
			note = pool.pop();
			if (sustainNote) sustainCount--; else noteCount--;
			hits++;
		}
		else
		{
			note = new Note(0, 0, null, sustainNote, false);
			totalCreated++;
			misses++;
		}

		note.recycle(strumTime, noteData, prevNote, sustainNote, mustHitNote);
		inUse++;
		return note;
	}

	/** Devuelve una nota al pool. */
	public static function put(note:Note):Void
	{
		if (!initialized || note == null) return;

		note.prevNote = null;
		note.kill();

		if (note.isSustainNote)
		{
			if (sustainCount < MAX_SIZE) { sustainPool.push(note); sustainCount++; totalRecycled++; }
			else note.destroy();
		}
		else
		{
			if (noteCount < MAX_SIZE) { notePool.push(note); noteCount++; totalRecycled++; }
			else note.destroy();
		}

		if (inUse > 0) inUse--;
	}

	// ─── Gestión ──────────────────────────────────────────────────────────────

	/** Limpia el pool (entre canciones). */
	public static function clear():Void
	{
		notePool.resize(0);    noteCount    = 0;
		sustainPool.resize(0); sustainCount = 0;
		inUse  = 0;
		hits   = 0;
		misses = 0;
		prewarm(INITIAL_SIZE);
	}

	/** Destruye completamente el pool (al salir del juego). */
	public static function destroy():Void
	{
		for (n in notePool)    n.destroy();
		for (n in sustainPool) n.destroy();
		notePool.resize(0);    noteCount    = 0;
		sustainPool.resize(0); sustainCount = 0;
		initialized = false;
	}

	/** Fuerza GC y recrea el pool. Útil entre canciones largas. */
	public static function forceGC():Void
	{
		for (n in notePool)    n.destroy();
		for (n in sustainPool) n.destroy();
		notePool.resize(0);
		sustainPool.resize(0);
		noteCount    = 0;
		sustainCount = 0;
		#if cpp  cpp.vm.Gc.run(true);  #end
		#if hl   hl.Gc.major();        #end
		prewarm(INITIAL_SIZE);
		trace('[NotePool] GC forzado y pool recreado.');
	}

	// ─── Stats ────────────────────────────────────────────────────────────────

	public static function getStats():String
	{
		final eff = (hits + misses) > 0 ? Math.round(hits / (hits + misses) * 100) : 0;
		return '[NotePool] Created=$totalCreated  InUse=$inUse  '
		     + 'NormalPool=$noteCount  SustainPool=$sustainCount  '
		     + 'Hits=$hits  Misses=$misses  Eff=$eff%';
	}
}
