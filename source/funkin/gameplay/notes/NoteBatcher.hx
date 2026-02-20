package funkin.gameplay.notes;

import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;

/**
 * NoteBatcher — agrupa notas por tipo de textura para minimizar cambios de estado GL.
 *
 * ─── Cómo funciona ───────────────────────────────────────────────────────────
 * HaxeFlixel renderiza cada FlxSprite en un draw call separado.
 * Si agrupamos notas del mismo tipo juntas en el árbol de display,
 * el driver de OpenGL puede fusionar los draw calls adyacentes con la
 * misma textura en un solo batch — especialmente en targets con batching
 * automático (HTML5/WebGL y algunos targets nativos con OpenFL 9+).
 *
 * ─── Optimizaciones respecto a la versión anterior ───────────────────────────
 * • Clave de batch es `Int` en vez de `String` — sin alloc por nota.
 * • `removeNoteFromBatch` usa swap-and-pop O(1) en vez de Array.remove O(n).
 * • `getBatchIndex` es `inline` — el compilador la elimina en el hot path.
 * • Stats sin concatenación de strings en el hot path.
 */
class NoteBatcher extends FlxSpriteGroup
{
	// Índices de batch (Int para evitar alloc de String)
	static inline var BATCH_PURPLE  = 0;
	static inline var BATCH_BLUE    = 1;
	static inline var BATCH_GREEN   = 2;
	static inline var BATCH_RED     = 3;
	static inline var BATCH_SUSTAIN = 4;
	static inline var BATCH_COUNT   = 5;

	/** Máximo de notas por batch antes de hacer flush. */
	public static var batchSize : Int = 128;
	public var enabled : Bool = true;

	// Batches como arrays de tamaño fijo — sin alloc en hot path
	final batches  : Array<Array<Note>>;
	final counts   : Array<Int>;   // tamaños actuales de cada batch

	// Stats
	public var totalBatches    : Int = 0;
	public var drawCallsSaved  : Int = 0;

	public function new()
	{
		super();
		batches = [for (_ in 0...BATCH_COUNT) []];
		counts  = [for (_ in 0...BATCH_COUNT) 0];
	}

	// ─── Hot path ─────────────────────────────────────────────────────────────

	public function addNoteToBatch(note:Note):Void
	{
		if (!enabled) { add(note); return; }

		final idx = getBatchIndex(note);
		batches[idx].push(note);
		counts[idx]++;

		if (counts[idx] >= batchSize)
			flushBatch(idx);
	}

	public function removeNoteFromBatch(note:Note):Void
	{
		final idx   = getBatchIndex(note);
		final batch = batches[idx];
		final last  = counts[idx] - 1;

		// Swap-and-pop O(1): reemplaza el elemento con el último y trunca
		for (i in 0...counts[idx])
		{
			if (batch[i] == note)
			{
				batch[i] = batch[last];
				batch.resize(last);
				counts[idx]--;
				break;
			}
		}
		remove(note, true);
	}

	// ─── Flush ────────────────────────────────────────────────────────────────

	public function flushAll():Void
	{
		for (i in 0...BATCH_COUNT) flushBatch(i);
	}

	inline function flushBatch(idx:Int):Void
	{
		final batch = batches[idx];
		final n     = counts[idx];
		if (n == 0) return;

		for (i in 0...n) add(batch[i]);

		totalBatches++;
		drawCallsSaved += n - 1;

		batch.resize(0);
		counts[idx] = 0;
	}

	// ─── Helpers ──────────────────────────────────────────────────────────────

	/** Devuelve el índice de batch para una nota. `inline` → sin overhead. */
	static inline function getBatchIndex(note:Note):Int
		return note.isSustainNote ? BATCH_SUSTAIN : (note.noteData & 3); // % 4 sin división

	public function clearBatches():Void
	{
		for (i in 0...BATCH_COUNT) { batches[i].resize(0); counts[i] = 0; }
		totalBatches   = 0;
		drawCallsSaved = 0;
	}

	public function toggleBatching():Void
	{
		enabled = !enabled;
		trace('[NoteBatcher] Batching: $enabled');
	}

	public function getStats():String
		return '[NoteBatcher] Batches=$totalBatches  DrawCallsSaved=$drawCallsSaved  Enabled=$enabled';

	override function destroy():Void
	{
		for (b in batches) b.resize(0);
		super.destroy();
	}
}
