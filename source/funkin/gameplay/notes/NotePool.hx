package funkin.gameplay.notes;

/**
 * NotePool — STUB. El pool real está en NoteRenderer (instancia por canción).
 *
 * ¿Por qué existe este stub?
 *  - La versión anterior tenía DOS sistemas de pool simultáneos:
 *      1. NotePool (estático, FlxTypedSpriteGroup) — inicializado pero NUNCA usado para
 *         spawning real. Sus notas prewarm'd eran RAM desperdiciada.
 *      2. NoteRenderer.notePool/sustainPool (por instancia, Array<Note>) — el que SÍ
 *         maneja todas las notas en gameplay via getNote()/recycleNote().
 *  - Tener dos pools duplicaba GC pressure: 32 Note prewarm'd × 2 grupos = 64 objetos
 *    con texturas que nunca se utilizaban, más el overhead de FlxTypedSpriteGroup.
 *  - Este stub mantiene la API para que OptimizationManager y PlayState compilen
 *    sin cambios mientras se elimina el pool duplicado.
 *
 * El pool real se puede consultar vía NoteRenderer.getPoolStats().
 */
class NotePool
{
	// Stats delegados al renderer activo (solo lectura)
	public static var totalCreated  : Int = 0;
	public static var totalRecycled : Int = 0;

	public static var inUse(get, never) : Int;
	static inline function get_inUse():Int return 0;

	/** No-op: el pool real es NoteRenderer, gestionado por NoteManager. */
	public static inline function init():Void {}

	/** No-op: NoteRenderer limpia su pool interno al destruirse. */
	public static inline function clear():Void {}

	/** No-op. */
	public static inline function destroy():Void {}

	/** No-op. */
	public static inline function forceGC():Void
	{
		#if cpp  cpp.vm.Gc.run(true);  #end
		#if hl   hl.Gc.major();        #end
	}

	public static function getStats():String
	{
		// Las stats reales las reporta NoteRenderer vía NoteManager.getPoolStats()
		// que OptimizationManager puede consultar si tiene ref a PlayState.
		return '[NotePool] Delegado a NoteRenderer — ver NoteManager.getPoolStats()';
	}
}
