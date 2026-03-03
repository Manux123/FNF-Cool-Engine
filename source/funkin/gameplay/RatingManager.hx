package funkin.gameplay;

/**
 * Datos de un rating individual.
 * Todos los campos son primitivas para minimizar allocations.
 */
typedef RatingData = {
	var name:String;
	/** Ventana de timing superior (ms, exclusiva). */
	var window:Float;
	/** Puntos que otorga. */
	var score:Int;
	/** Contribución a la accuracy (0.0–1.0). */
	var accuracyWeight:Float;
	/** Modificador de salud. */
	var health:Float;
	/** Si true, resetea el combo. */
	var breakCombo:Bool;
	/** Si false, no muestra popup de rating (útil para "perfect" silencioso, etc.). */
	var ?showPopup:Bool;
}

/**
 * RatingManager — Sistema de ratings completamente softcodeado.
 *
 * Jerarquía de carga (primera encontrada gana):
 *   1. mods/{mod}/data/songs/{song}/ratings.json   ← per-song override de mod
 *   2. mods/{mod}/data/ratings.json                ← override global de mod
 *   3. assets/data/songs/{song}/ratings.json       ← per-song base
 *   4. assets/data/ratings.json                    ← global base
 *   5. Defaults hardcoded (FNF vanilla)
 *
 * Para añadir un rating nuevo (ejemplo "perfect"):
 *   En ratings.json agregar ANTES de "sick" (window menor):
 *   { "name": "perfect", "window": 20, "score": 500,
 *     "accuracyWeight": 1.0, "health": 0.15, "breakCombo": false }
 *   Y añadir el sprite en: assets/images/UI/normal/score/perfect.png
 *
 * Los ratings se ordenan automáticamente por `window` ascendente,
 * así getRating() siempre devuelve la ventana más estricta posible.
 */
class RatingManager
{
	// ── Defaults (FNF vanilla) ────────────────────────────────────────────────
	static final DEFAULTS:Array<RatingData> = [
		{ name: 'sick',  window: 45.0,  score: 350, accuracyWeight: 1.00, health:  0.10, breakCombo: false, showPopup: true },
		{ name: 'good',  window: 90.0,  score: 200, accuracyWeight: 0.75, health:  0.05, breakCombo: false, showPopup: true },
		{ name: 'bad',   window: 135.0, score: 100, accuracyWeight: 0.50, health: -0.03, breakCombo: false, showPopup: true },
		{ name: 'shit',  window: 166.0, score:  50, accuracyWeight: 0.25, health: -0.03, breakCombo: true,  showPopup: true },
	];

	/** Lista activa de ratings, ordenada por window ascendente. */
	public static var ratings:Array<RatingData> = [];

	/** Nombre del rating "top" (menor window). Cacheado para isSickMode(). */
	public static var topRatingName:String = 'sick';

	/** Ventana máxima válida. Notas con diff > esto son miss. */
	public static var missWindow:Float = 166.0;

	/** Lookup O(1) por nombre. */
	static var _byName:Map<String, RatingData> = new Map();

	static var _initialized:Bool = false;

	// ────────────────────────────────────────────────────────────────────────

	/** Inicializar con defaults. Ignorado si ya fue llamado. */
	public static inline function init():Void
		if (!_initialized) { _load(null); _initialized = true; }

	/**
	 * Recargar ratings para una canción específica.
	 * Llamar en PlayState.create() pasando el nombre de la canción.
	 */
	public static function reload(?songName:String):Void
	{
		_initialized = false;
		_load(songName != null ? songName.toLowerCase() : null);
		_initialized = true;
	}

	/** Limpiar al destruir PlayState. */
	public static function destroy():Void
	{
		ratings = [];
		_byName.clear();
		_initialized = false;
	}

	// ── Lookup ────────────────────────────────────────────────────────────────

	/**
	 * Devuelve el RatingData para una diferencia de timing dada.
	 * Retorna null si noteDiff > missWindow (= miss, manejar externamente).
	 * O(n) sobre los ratings activos — en la práctica n ≤ 6, coste insignificante.
	 */
	public static function getRating(noteDiff:Float):Null<RatingData>
	{
		for (r in ratings)
			if (noteDiff <= r.window)
				return r;
		return null;
	}

	/** Lookup O(1) por nombre. */
	public static inline function getByName(name:String):Null<RatingData>
		return _byName.get(name);

	/** true si el rating muestra popup (default true si el campo no está definido). */
	public static inline function showsPopup(r:RatingData):Bool
		return r.showPopup != false;

	// ── Carga interna ─────────────────────────────────────────────────────────

	static function _load(?songName:String):Void
	{
		ratings = [];
		_byName.clear();

		var raw:Null<String> = null;

		#if sys
		// Candidatos en orden de prioridad
		var candidates:Array<String> = [];

		if (mods.ModManager.isActive())
		{
			var modRoot = mods.ModManager.modRoot();
			if (songName != null)
				candidates.push('$modRoot/data/songs/$songName/ratings.json');
			candidates.push('$modRoot/data/ratings.json');
		}
		if (songName != null)
			candidates.push('assets/data/songs/$songName/ratings.json');
		candidates.push('assets/data/ratings.json');

		for (path in candidates)
		{
			if (sys.FileSystem.exists(path))
			{
				try   { raw = sys.io.File.getContent(path); trace('[RatingManager] Cargando $path'); break; }
				catch (e:Dynamic) { trace('[RatingManager] Error leyendo $path: $e'); }
			}
		}
		#end

		if (raw != null)
		{
			try
			{
				var parsed:Array<Dynamic> = haxe.Json.parse(raw);
				for (r in parsed)
				{
					if (r.name == null || r.window == null) continue; // entrada inválida
					ratings.push({
						name:           Std.string(r.name),
						window:         r.window,
						score:          r.score   != null ? Std.int(r.score)   : 0,
						accuracyWeight: r.accuracyWeight != null ? r.accuracyWeight : 1.0,
						health:         r.health  != null ? r.health  : 0.0,
						breakCombo:     r.breakCombo == true,
						showPopup:      r.showPopup  != false
					});
				}
				trace('[RatingManager] ${ratings.length} ratings cargados desde JSON');
			}
			catch (e:Dynamic)
			{
				trace('[RatingManager] JSON inválido: $e — usando defaults');
				ratings = [];
			}
		}

		// Fallback a defaults si no se cargó nada
		if (ratings.length == 0)
		{
			for (r in DEFAULTS) ratings.push(r);
			trace('[RatingManager] Usando ${ratings.length} ratings por defecto');
		}

		// Ordenar ascendente por window (garantiza getRating() correcto)
		ratings.sort((a, b) -> {
			if (a.window < b.window) return -1;
			if (a.window > b.window) return  1;
			return 0;
		});

		// Poblar caché de lookup
		for (r in ratings)
			_byName.set(r.name, r);

		topRatingName = ratings.length > 0 ? ratings[0].name : 'sick';
		missWindow    = ratings.length > 0 ? ratings[ratings.length - 1].window : 166.0;
	}
}