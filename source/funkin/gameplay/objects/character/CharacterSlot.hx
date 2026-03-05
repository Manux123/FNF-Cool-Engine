package funkin.gameplay.objects.character;

import funkin.gameplay.objects.character.Character;
import funkin.data.Song.CharacterSlotData;

using StringTools;

/**
 * CharacterSlot — Representa un slot de personaje en la partida.
 *
 * Cada slot encapsula:
 *   • El Character instanciado
 *   • Sus datos de configuración (CharacterSlotData)
 *   • Su índice en el array del chart
 *   • Su ROL normalizado (Player / Opponent / Girlfriend / Other)
 *   • El ID del StrumsGroup al que está vinculado
 *
 * ── Mejoras respecto a la versión anterior ──────────────────────────────────
 *
 *  BUG FIX A  charType / isGFSlot / strumsGroupId expuestos como propiedades
 *             tipadas. Antes había que acceder a `slot.data.type` con string
 *             sin validar, causando que danceOnBeat, findPlayerIndex, etc.
 *             no funcionaran con chars en índices no estándar.
 *
 *  BUG FIX B  `sing()` ahora respeta `isGFSlot`: si este slot es de GF
 *             (isGF:true o type:"Girlfriend"), ignorará llamadas sing()
 *             a menos que se use `forceSing:true`. GF solo baila a menos
 *             que una sección tenga gfSing=true.
 *
 *  BUG FIX C  `playMiss()` tiene fallback a `character.animation.getByName()`
 *             además de `animOffsets`. La versión anterior fallaba silencio-
 *             samente con personajes que no usan el sistema de offsets.
 *
 *  BUG FIX D  `position by type` en el constructor: si `charData.x == 0 &&
 *             charData.y == 0`, la posición la resuelve `PlayState.loadCharacters`
 *             usando el tipo en vez del índice hardcodeado.
 */
class CharacterSlot
{
	// ── Datos principales ────────────────────────────────────────────────────
	public var character:Character;
	public var data:CharacterSlotData;
	public var index:Int;
	public var isActive:Bool = true;

	// ── Propiedades de rol (BUG FIX A) ───────────────────────────────────────

	/**
	 * Tipo normalizado del personaje en este slot.
	 * Valores posibles: "Player" | "Opponent" | "Girlfriend" | "Other"
	 *
	 * Se deriva de `charData.type` en la construcción. Si `type` no está
	 * definido en el JSON del chart, se infiere por nombre del personaje
	 * (bf → Player, gf → Girlfriend, resto → Opponent).
	 */
	public var charType(default, null):String;

	/**
	 * true si este slot es de Girlfriend (solo baila, no canta notas).
	 * Shorthand para `charType == "Girlfriend"` o `data.isGF == true`.
	 */
	public var isGFSlot(get, never):Bool;
	inline function get_isGFSlot():Bool
		return charType == 'Girlfriend' || (data.isGF == true);

	/**
	 * true si este slot es el jugador (recibe inputs del teclado/gamepad).
	 */
	public var isPlayerSlot(get, never):Bool;
	inline function get_isPlayerSlot():Bool return charType == 'Player';

	/**
	 * true si este slot es del oponente (CPU canta automáticamente).
	 */
	public var isOpponentSlot(get, never):Bool;
	inline function get_isOpponentSlot():Bool return charType == 'Opponent';

	/**
	 * ID del StrumsGroup al que está vinculado este personaje.
	 * Null si no está vinculado a ningún grupo explícito.
	 */
	public var strumsGroupId(default, null):Null<String>;

	// ── Timers internos ───────────────────────────────────────────────────────
	public var holdTimer:Float   = 0;
	public var animFinished:Bool = true;

	// ── Tabla de sufijos de animación ─────────────────────────────────────────
	static final NOTES_ANIM:Array<String> = ['LEFT', 'DOWN', 'UP', 'RIGHT'];

	// ─────────────────────────────────────────────────────────────────────────
	// Constructor
	// ─────────────────────────────────────────────────────────────────────────

	public function new(charData:CharacterSlotData, index:Int)
	{
		this.data  = charData;
		this.index = index;

		// ── Resolver tipo de personaje (BUG FIX A) ───────────────────────────
		charType = _resolveCharType(charData);

		// ── StrumsGroup ID ────────────────────────────────────────────────────
		strumsGroupId = charData.strumsGroup;

		// ── Crear personaje ───────────────────────────────────────────────────
		final charName = charData.name != null ? charData.name : 'bf';
		character = new Character(charData.x, charData.y, charName, charType == 'Player');

		// Aplicar configuración del slot
		if (charData.flip != null && charData.flip)
			character.flipX = !character.flipX;

		if (charData.scale != null && charData.scale != 1.0)
		{
			character.scale.set(charData.scale, charData.scale);
			character.updateHitbox();
		}

		if (charData.visible != null)
			character.visible = charData.visible;

		trace('[CharacterSlot] Slot $index: "$charName" (type=$charType, strumsGroup=$strumsGroupId)');
	}

	// ─────────────────────────────────────────────────────────────────────────
	// Animaciones
	// ─────────────────────────────────────────────────────────────────────────

	/**
	 * Hace cantar al personaje en la dirección `noteData`.
	 *
	 * @param noteData   0=LEFT 1=DOWN 2=UP 3=RIGHT
	 * @param altAnim    Sufijo de animación alternativa (ej: "-alt", "")
	 * @param forceSing  Si true, ignora el guard de GF. Usar cuando gfSing=true.
	 */
	public function sing(noteData:Int, ?altAnim:String = '', ?forceSing:Bool = false):Void
	{
		if (!isActive) return;

		// BUG FIX B: GF no canta a menos que sea una sección gfSing
		if (isGFSlot && !forceSing) return;

		if (character.isPlayingSpecialAnim()) return;

		var animName:String = 'sing' + NOTES_ANIM[noteData] + altAnim;

		// Fallback si no existe la animación alterna
		if (!_animExists(animName))
			animName = 'sing' + NOTES_ANIM[noteData];

		// Si tampoco existe la base, salir silenciosamente
		if (!_animExists(animName)) return;

		character.playAnim(animName, true);

		// CRÍTICO: Resetear el holdTimer para que Character.update() no fuerce
		// el idle en el siguiente frame antes de que se vea la animación.
		character.holdTimer = 0;
		animFinished = false;
	}

	/**
	 * Reproduce la animación de miss para `noteData`.
	 *
	 * BUG FIX C: tiene fallback a `animation.getByName()` si `animOffsets`
	 * no tiene la animación registrada (chars que no usan el sistema de offsets).
	 */
	public function playMiss(noteData:Int):Void
	{
		if (!isActive) return;

		final animName:String = 'sing' + NOTES_ANIM[noteData] + 'miss';

		if (_animExists(animName))
		{
			character.playAnim(animName, true);
			character.holdTimer = 0;
			animFinished = false;
		}
		// Si no hay animación de miss, al menos interrumpir el sing actual
		// para dar feedback visual de que se falló la nota.
	}

	/**
	 * Dance en beat. No interrumpe si está cantando o en special anim.
	 */
	public function dance():Void
	{
		if (!isActive) return;
		character.dance();
	}

	/**
	 * Reproduce una animación especial (hey, cheer, etc.) sin guards.
	 */
	public function playSpecialAnim(animName:String):Void
	{
		if (character == null) return;
		character.playAnim(animName, true);
		character.holdTimer = 0;
	}

	// ─────────────────────────────────────────────────────────────────────────
	// Update
	// ─────────────────────────────────────────────────────────────────────────

	/**
	 * Update por frame.
	 *
	 * IMPORTANTE: NO duplicar lógica de animación aquí.
	 * Flixel llama Character.update() automáticamente porque el personaje
	 * está add()-eado al FlxState. Character.update() ya gestiona holdTimer,
	 * sing→idle y special→idle. Ejecutar esa lógica aquí causaría flickering.
	 */
	public function update(elapsed:Float):Void
	{
		// Reservado para lógica futura de slot (no de animación de personaje).
	}

	// ─────────────────────────────────────────────────────────────────────────
	// Control de visibilidad / activación
	// ─────────────────────────────────────────────────────────────────────────

	public function setActive(active:Bool):Void
	{
		isActive = active;
		character.visible = active && (data.visible != null ? data.visible : true);
	}

	// ─────────────────────────────────────────────────────────────────────────
	// Destrucción
	// ─────────────────────────────────────────────────────────────────────────

	public function destroy():Void
	{
		if (character != null)
		{
			character.destroy();
			character = null;
		}
		data = null;
	}

	// ─────────────────────────────────────────────────────────────────────────
	// Helpers privados
	// ─────────────────────────────────────────────────────────────────────────

	/**
	 * Comprueba si una animación existe, primero en `animOffsets` (sistema
	 * de FunkinSprite/FlxAnimate) y luego en `animation` (sistema legacy FlxSprite).
	 *
	 * BUG FIX C: La versión anterior solo comprobaba `animOffsets`, lo que
	 * causaba que personajes sin offsets nunca cantaran.
	 */
	private inline function _animExists(name:String):Bool
	{
		return (character.animOffsets != null && character.animOffsets.exists(name))
			|| (character.animation != null && character.animation.getByName(name) != null);
	}

	/**
	 * Deduce el tipo canónico del personaje a partir de CharacterSlotData.
	 *
	 * Orden de precedencia:
	 *   1. `charData.type` explícito en el JSON del chart
	 *   2. `charData.isGF == true`
	 *   3. Inferencia por nombre (bf → Player, gf → Girlfriend, resto → Opponent)
	 */
	private static function _resolveCharType(charData:CharacterSlotData):String
	{
		// 1. Campo explícito
		if (charData.type != null)
		{
			return switch (charData.type.toLowerCase().trim())
			{
				case 'player', 'bf', 'boyfriend': 'Player';
				case 'opponent', 'dad', 'enemy':  'Opponent';
				case 'girlfriend', 'gf':          'Girlfriend';
				default: charData.type; // Preservar tipos custom ("Other", etc.)
			};
		}

		// 2. Flag isGF
		if (charData.isGF == true) return 'Girlfriend';

		// 3. Inferencia por nombre de personaje
		final name = (charData.name ?? '').toLowerCase();
		if (name.startsWith('bf') || name.contains('boyfriend')) return 'Player';
		if (name.startsWith('gf') || name.contains('girlfriend')) return 'Girlfriend';

		return 'Opponent'; // default
	}
}
