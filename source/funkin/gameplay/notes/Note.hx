package funkin.gameplay.notes;

import lime.utils.Assets;
import funkin.gameplay.PlayState;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.FlxG;
import funkin.data.Conductor;
import funkin.gameplay.PlayStateConfig;

using StringTools;

class Note extends FlxSprite
{
	public var strumTime:Float = 0;
	public var mustPress:Bool = false;
	public var noteData:Int = 0;
	public var canBeHit:Bool = false;
	public var tooLate:Bool = false;
	public var wasGoodHit:Bool = false;
	public var prevNote:Note;
	public var sustainLength:Float = 0;
	public var isSustainNote:Bool = false;
	public var noteScore:Float = 1;
	public var noteRating:String = 'sick';

	public var strumsGroupIndex:Int = 0;

	/** Tipo de nota personalizado. "" / "normal" = normal. */
	public var noteType:String = '';

	public static var swagWidth:Float = 160 * 0.7;
	public static var PURP_NOTE:Int = 0;
	public static var BLUE_NOTE:Int = 1;
	public static var GREEN_NOTE:Int = 2;
	public static var RED_NOTE:Int = 3;

	var animArrows:Array<String> = ['purple', 'blue', 'green', 'red'];

	// ── Estado de skin ────────────────────────────────────────────────────

	/** Nombre de la skin actualmente cargada. Usado para detectar cambios en recycle(). */
	private var _loadedSkinName:String = '';

	/** Tipo con el que se cargó la skin: true=sustain, false=normal. Si cambia hay que recargar animaciones. */
	private var _loadedAsSustain:Bool = false;

	/** true si la skin cargada tiene isPixel:true. */
	private var isPixelNote:Bool = false;

	/** Escala aplicada al sprite, leída del JSON de skin. */
	private var _noteScale:Float = 1.0;

	/** Offset X extra para notas sustain, leído del JSON de skin. */
	private var _skinSustainOffset:Float = 0.0;

	/** Multiplicador de scale.y para hold chain, leído del JSON de skin. */
	private var _skinHoldStretch:Float = 1.0;

	// ── Cache de hit window ───────────────────────────────────────────────
	private var _lastSongPos:Float = -1;
	private var _hitWindowCache:Float = 0;

	public function new(strumTime:Float, noteData:Int, ?prevNote:Note, ?sustainNote:Bool = false, ?mustHitNote:Bool = false)
	{
		super();

		if (prevNote == null)
			prevNote = this;
		this.prevNote = prevNote;
		isSustainNote = sustainNote;
		this.mustPress = mustHitNote;

		// BUGFIX: aplicar el offset de dirección aquí mismo — setupNoteDirection
		// ya no hace x += swagWidth*i para notas sustain (causaba WARNING),
		// así que calculamos la X final directamente igual que en recycle().
		x = _calcBaseX(mustHitNote) + (swagWidth * noteData);
		y = -2000;
		this.strumTime = strumTime + FlxG.save.data.offset;
		this.noteData = noteData;

		NoteSkinSystem.init();
		loadSkin(NoteSkinSystem.getCurrentSkinData());

		setupNoteDirection();

		if (isSustainNote && prevNote != null)
			setupSustainNote();

		var hitWindowMultiplier = isSustainNote ? 1.05 : 1.0;
		_hitWindowCache = Conductor.safeZoneOffset * hitWindowMultiplier;

		if (NoteTypeManager.isCustomType(noteType))
			NoteTypeManager.onNoteSpawn(this);
	}

	// ==================== CARGA DE SKIN ====================

	/**
	 * Carga la textura y las animaciones desde un NoteSkinData.
	 *
	 * No hay ninguna referencia a PlayState.curStage aquí.
	 * El caller (constructor / recycle) pasa el skinData ya resuelto
	 * por NoteSkinSystem (que sabe qué skin corresponde al stage actual).
	 */
	function loadSkin(skinData:NoteSkinSystem.NoteSkinData):Void
	{
		if (skinData == null)
			return;

		_loadedSkinName = skinData.name;
		_loadedAsSustain = isSustainNote; // rastrear tipo para detectar cambio en recycle
		isPixelNote = skinData.isPixel == true;
		_skinSustainOffset = skinData.sustainOffset != null ? skinData.sustainOffset : 0.0;
		_skinHoldStretch = skinData.holdStretch != null ? skinData.holdStretch : 1.0;

		// ── Elegir textura ────────────────────────────────────────────────
		// Notas cabeza y strums → texture principal
		// Sustain pieces + tails → holdTexture (si existe) o fallback a texture
		var tex = (isSustainNote && skinData.holdTexture != null) ? skinData.holdTexture : skinData.texture;

		// ── Cargar frames ─────────────────────────────────────────────────
		frames = NoteSkinSystem.loadSkinFrames(tex, skinData.folder);

		// BUGFIX CRÍTICO: si frames es null (asset faltante, XML roto, etc.)
		// el sprite crashea en FlxDrawQuadsItem::render al primer frame de PlayState.
		if (frames == null)
		{
			trace('[Note] WARN: frames null para skin "${skinData.name}" noteData=$noteData — usando placeholder');
			makeGraphic(Std.int(Note.swagWidth), Std.int(Note.swagWidth), 0x00000000);
		}

		// ── Escala ────────────────────────────────────────────────────────
		// BUGFIX: NO usar `width * _noteScale` porque `width` es el hitbox del
		// ciclo anterior (stale) hasta que se llame updateHitbox(). Usar
		// scale.set() directamente para evitar que el scale se multiplique
		// acumulativamente en cada recycle (_noteScale^N en la N-ésima reutilización).
		_noteScale = tex.scale != null ? tex.scale : 1.0;
		scale.set(_noteScale, _noteScale);
		updateHitbox();

		// ── Antialiasing ──────────────────────────────────────────────────
		antialiasing = tex.antialiasing != null ? tex.antialiasing : !isPixelNote;

		// ── Animaciones ───────────────────────────────────────────────────
		var anims = skinData.animations;
		if (anims == null)
			return;

		if (!isSustainNote)
		{
			// Animaciones de notas (las que bajan por la pantalla)
			var defs = [anims.left, anims.down, anims.up, anims.right];
			for (i in 0...animArrows.length)
				NoteSkinSystem.addAnimToSprite(this, animArrows[i] + 'Scroll', defs[i]);
		}
		else
		{
			// Hold pieces
			var holdDefs = [anims.leftHold, anims.downHold, anims.upHold, anims.rightHold];
			// Hold tails/ends
			var holdEndDefs = [anims.leftHoldEnd, anims.downHoldEnd, anims.upHoldEnd, anims.rightHoldEnd];

			for (i in 0...animArrows.length)
			{
				NoteSkinSystem.addAnimToSprite(this, animArrows[i] + 'hold', holdDefs[i]);
				NoteSkinSystem.addAnimToSprite(this, animArrows[i] + 'holdend', holdEndDefs[i]);
			}
		}
	}

	// ==================== RECYCLE (Object Pooling) ====================

	public function recycle(strumTime:Float, noteData:Int, ?prevNote:Note, ?sustainNote:Bool = false, ?mustHitNote:Bool = false):Void
	{
		this.strumTime = strumTime + FlxG.save.data.offset;
		this.noteData = noteData;
		this.prevNote = prevNote != null ? prevNote : this;
		this.isSustainNote = sustainNote;
		this.mustPress = mustHitNote;
		this.canBeHit = false;
		this.tooLate = false;
		this.wasGoodHit = false;
		this.noteScore = 1;
		this.noteRating = 'sick';
		this.strumsGroupIndex = 0;
		this.noteType = '';
		this.alpha = sustainNote ? 0.6 : 1.0;
		this.visible = true;

		x = _calcBaseX(mustHitNote) + (swagWidth * noteData);
		y = -2000;

		var hitWindowMultiplier = isSustainNote ? 1.05 : 1.0;
		_hitWindowCache = Conductor.safeZoneOffset * hitWindowMultiplier;
		_lastSongPos = -1;

		revive();

		// ── Recargar skin si cambió nombre O si cambió el tipo (sustain↔normal) ────
		// BUGFIX: el tipo de nota puede cambiar si el pool de NoteRenderer mezcla
		// sustain y normales. loadSkin registra animaciones distintas según isSustainNote,
		// así que hay que recargar también cuando cambia el tipo aunque la skin sea igual.
		var skinData = NoteSkinSystem.getCurrentSkinData();
		if (skinData.name != _loadedSkinName || isSustainNote != _loadedAsSustain)
			loadSkin(skinData);

		// ── Restaurar animación y escala ──────────────────────────────────
		if (!isSustainNote)
		{
			// Resetear escala — puede haber quedado corrupta si esta nota fue
			// usada como prevNote en una cadena de holds.
			// BUGFIX: usar scale.set() directamente en lugar de
			// scale.set(1,1) + setGraphicSize(width*_noteScale), que acumulaba
			// _noteScale^N porque `width` era el hitbox stale del ciclo anterior.
			scale.set(_noteScale, _noteScale);
			updateHitbox();

			if (animation.exists(animArrows[noteData] + 'Scroll'))
				animation.play(animArrows[noteData] + 'Scroll');
		}
		else
		{
			// Re-aplicar escala antes de setupSustainNote para que el stretch
			// del hold sea proporcional al tamaño real de frame.
			// BUGFIX: misma corrección que para notas normales — scale.set()
			// directo en lugar de setGraphicSize(width*_noteScale) stale.
			scale.set(_noteScale, _noteScale);
			updateHitbox();
			flipY = false;
			flipX = false;
			setupSustainNote();
		}
	}

	// ==================== SETUP HELPERS ====================

	function setupNoteDirection():Void
	{
		// BUGFIX: las notas sustain NO tienen animación 'purpleScroll' registrada.
		// Además, la X ya fue calculada en el constructor con swagWidth*noteData,
		// así que no necesitamos x += aquí.
		if (isSustainNote)
			return;

		// Solo reproducir la animación de scroll (X ya calculada en constructor)
		if (animation.exists(animArrows[noteData] + 'Scroll'))
			animation.play(animArrows[noteData] + 'Scroll');
	}

	function setupSustainNote():Void
	{
		noteScore * 0.2;
		alpha = 0.6;

		if (FlxG.save.data.downscroll)
		{
			flipY = true;
			flipX = true;
		}

		x += width / 2;

		for (i in 0...animArrows.length)
		{
			if (noteData == i)
			{
				// BUGFIX: check existence para no disparar WARNING si la skin
				// aún no tiene esta animación registrada
				if (animation.exists(animArrows[i] + 'holdend'))
					animation.play(animArrows[i] + 'holdend');
				break;
			}
		}

		updateHitbox();
		x -= width / 2;

		// Offset X extra (leído del JSON de skin — e.g. 30 para pixel, 0 para normal)
		x += _skinSustainOffset;

		if (prevNote.isSustainNote)
		{
			for (i in 0...animArrows.length)
			{
				if (prevNote.noteData == i)
				{
					if (prevNote.animation.exists(animArrows[i] + 'hold'))
						prevNote.animation.play(animArrows[i] + 'hold');
					break;
				}
			}

			prevNote.scale.y *= Conductor.stepCrochet / 100 * 1.5 * PlayState.SONG.speed;
			// Multiplicador extra de hold (leído del JSON — 1.19 para pixel, 1.0 para normal)
			prevNote.scale.y *= _skinHoldStretch;
			prevNote.updateHitbox();
		}
	}

	// ==================== SETUP DE ANIMACIONES DE TIPO ====================

	/**
	 * Reconfigura animaciones cuando NoteTypeManager asigna sus propios frames.
	 * Llamado desde NoteTypeManager.onNoteSpawn().
	 */
	public function setupTypeAnimations():Void
	{
		var dirs = ['purple', 'blue', 'green', 'red'];
		if (!isSustainNote)
		{
			for (i in 0...dirs.length)
			{
				try
				{
					animation.addByPrefix(dirs[i] + 'Scroll', dirs[i] + '0');
				}
				catch (_:Dynamic)
				{
				}
				try
				{
					animation.addByPrefix(dirs[i] + 'Scroll', dirs[i]);
				}
				catch (_:Dynamic)
				{
				}
			}
			for (i in 0...dirs.length)
				if (noteData == i && animation.exists(dirs[i] + 'Scroll'))
				{
					animation.play(dirs[i] + 'Scroll');
					break;
				}
		}
		else
		{
			for (i in 0...dirs.length)
			{
				try
				{
					animation.addByPrefix(dirs[i] + 'holdend', dirs[i] + ' hold end');
				}
				catch (_:Dynamic)
				{
				}
				try
				{
					animation.addByPrefix(dirs[i] + 'holdend', dirs[i] + 'holdend');
				}
				catch (_:Dynamic)
				{
				}
				try
				{
					animation.addByPrefix(dirs[i] + 'hold', dirs[i] + ' hold piece');
				}
				catch (_:Dynamic)
				{
				}
				try
				{
					animation.addByPrefix(dirs[i] + 'hold', dirs[i] + 'hold');
				}
				catch (_:Dynamic)
				{
				}
			}
			for (i in 0...dirs.length)
				if (noteData == i && animation.exists(dirs[i] + 'holdend'))
				{
					animation.play(dirs[i] + 'holdend');
					break;
				}
		}
		setGraphicSize(Std.int(width * _noteScale));
		updateHitbox();
	}

	// ==================== UTILIDADES ====================

	/** Calcula la posición X base según mustPress y middlescroll. */
	inline function _calcBaseX(mustHitNote:Bool):Float
	{
		if (FlxG.save.data.middlescroll)
			return mustHitNote ? (FlxG.width / 2 - swagWidth * 2) : -275;
		else
			return mustHitNote ? (FlxG.width / 2 + 100) : 100;
	}

	// ==================== UPDATE ====================

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (Math.abs(Conductor.songPosition - _lastSongPos) > 10)
		{
			_lastSongPos = Conductor.songPosition;

			if (mustPress)
			{
				canBeHit = (strumTime > Conductor.songPosition - _hitWindowCache
					&& strumTime < Conductor.songPosition + (_hitWindowCache / 2.5));
			}
			else
			{
				canBeHit = false;
				if (strumTime <= Conductor.songPosition)
					wasGoodHit = true;
			}
		}

		if (tooLate && alpha > 0.3)
			alpha = 0.3;
	}
}
