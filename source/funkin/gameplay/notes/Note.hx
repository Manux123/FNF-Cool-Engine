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

	// Índice del StrumsGroup al que pertenece esta nota (0 = grupo 0, 1 = grupo 1, etc.)
	public var strumsGroupIndex:Int = 0;

	/** Tipo de nota personalizado. "" / "normal" = normal. Guardado en chart como noteData[3]. */
	public var noteType:String = '';

	public static var swagWidth:Float = 160 * 0.7;
	public static var PURP_NOTE:Int = 0;
	public static var BLUE_NOTE:Int = 1;
	public static var GREEN_NOTE:Int = 2;
	public static var RED_NOTE:Int = 3;

	var animArrows:Array<String> = ['purple', 'blue', 'green', 'red'];
	
	// OPTIMIZATION: Cache para evitar recalcular
	private var _lastSongPos:Float = -1;
	private var _cachedCanHit:Bool = false;
	private var _hitWindowCache:Float = 0;

	public function new(strumTime:Float, noteData:Int, ?prevNote:Note, ?sustainNote:Bool = false, ?mustHitNote:Bool = false)
	{
		super();

		if (prevNote == null)
			prevNote = this;

		this.prevNote = prevNote;
		isSustainNote = sustainNote;
		this.mustPress = mustHitNote; // CORREGIDO: Asignar mustPress desde el inicio

		// CORREGIDO: Calcular posición X según mustPress y middlescroll
		var baseX:Float = 100;
		
		if (FlxG.save.data.middlescroll)
		{
			// En middlescroll, las notas del jugador están centradas
			if (mustHitNote)
				baseX = FlxG.width / 2 - (swagWidth * 2); // Centrado
			else
				baseX = -275; // CPU fuera de pantalla (invisible)
		}
		else
		{
			// En modo normal, CPU a la izquierda, jugador a la derecha
			if (mustHitNote)
				baseX = FlxG.width / 2 + 100; // Lado derecho para jugador
			else
				baseX = 100; // Lado izquierdo para CPU
		}
		
		x = baseX;
		y = -2000;
		this.strumTime = strumTime + FlxG.save.data.offset;
		this.noteData = noteData;

		// Inicializar sistema
		NoteSkinSystem.init();

		var daStage:String = PlayState.curStage;

		switch (daStage)
		{
			case 'school' | 'schoolEvil':
				loadPixelNotes();
			default:
				loadNormalNotes();
		}

		// Posicionar y animar según dirección
		setupNoteDirection();

		// Configurar sustains
		if (isSustainNote && prevNote != null)
		{
			setupSustainNote();
		}
		
		// OPTIMIZATION: Precalcular hit window
		var hitWindowMultiplier = isSustainNote ? 1.05 : 1.0;
		_hitWindowCache = Conductor.safeZoneOffset * hitWindowMultiplier;

		// NoteType: aplicar textura/script después de cargar la nota
		if (NoteTypeManager.isCustomType(noteType))
			NoteTypeManager.onNoteSpawn(this);
	}

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
				try { animation.addByPrefix(dirs[i] + 'Scroll', dirs[i] + '0'); } catch(_:Dynamic) {}
				try { animation.addByPrefix(dirs[i] + 'Scroll', dirs[i]); }       catch(_:Dynamic) {}
			}
			for (i in 0...dirs.length)
				if (noteData == i && animation.exists(dirs[i] + 'Scroll'))
					{ animation.play(dirs[i] + 'Scroll'); break; }
		}
		else
		{
			for (i in 0...dirs.length)
			{
				try { animation.addByPrefix(dirs[i] + 'holdend', dirs[i] + ' hold end');   } catch(_:Dynamic) {}
				try { animation.addByPrefix(dirs[i] + 'holdend', dirs[i] + 'holdend');     } catch(_:Dynamic) {}
				try { animation.addByPrefix(dirs[i] + 'hold',    dirs[i] + ' hold piece'); } catch(_:Dynamic) {}
				try { animation.addByPrefix(dirs[i] + 'hold',    dirs[i] + 'hold');        } catch(_:Dynamic) {}
			}
			for (i in 0...dirs.length)
				if (noteData == i && animation.exists(dirs[i] + 'holdend'))
					{ animation.play(dirs[i] + 'holdend'); break; }
		}
		setGraphicSize(Std.int(width * 0.7));
		updateHitbox();
	}

	// OPTIMIZATION: Método para reciclar/resetear nota (Object Pooling)
	public function recycle(strumTime:Float, noteData:Int, ?prevNote:Note, ?sustainNote:Bool = false, ?mustHitNote:Bool = false):Void
	{
		// Resetear propiedades
		this.strumTime = strumTime + FlxG.save.data.offset;
		this.noteData = noteData;
		this.prevNote = prevNote != null ? prevNote : this;
		this.isSustainNote = sustainNote;
		this.mustPress = mustHitNote; // CORREGIDO
		this.canBeHit = false;
		this.tooLate = false;
		this.wasGoodHit = false;
		this.noteScore = 1;
		this.noteRating = 'sick';
		this.strumsGroupIndex = 0;
		this.noteType = '';
		this.alpha = sustainNote ? 0.6 : 1.0;
		this.visible = true;
		
		// CORREGIDO: Recalcular posición X según mustPress
		var baseX:Float = 100;
		
		if (FlxG.save.data.middlescroll)
		{
			if (mustHitNote)
				baseX = FlxG.width / 2 - (swagWidth * 2);
			else
				baseX = -275;
		}
		else
		{
			if (mustHitNote)
				baseX = FlxG.width / 2 + 100;
			else
				baseX = 100;
		}
		
		x = baseX + (swagWidth * noteData); // Agregar offset por dirección
		y = -2000;
		
		// Recalcular hit window
		var hitWindowMultiplier = isSustainNote ? 1.05 : 1.0;
		_hitWindowCache = Conductor.safeZoneOffset * hitWindowMultiplier;
		_lastSongPos = -1;
		
		// Revivir sprite
		revive();

		// CORREGIDO: Restaurar animación y setup según tipo de nota.
		// Sin esto, notas recicladas del pool conservan la animación anterior
		// (ej. una nota normal reciclada como sustain sigue mostrando 'purpleScroll').
		if (!isSustainNote)
		{
			// Nota normal: reproducir la animación de dirección correcta
			if (animation.exists(animArrows[noteData] + 'Scroll'))
				animation.play(animArrows[noteData] + 'Scroll');
		}
		else
		{
			// Nota sustain: resetear escala, aplicar flip y reproducir 'holdend'
			scale.set(1, 1);
			flipY = false;
			flipX = false;
			setupSustainNote();
		}
	}

	function loadPixelNotes():Void
	{
		// CORREGIDO: Cargar diferentes texturas según si es sustain o no
		if (isSustainNote)
		{
			var pixelEndsTex = NoteSkinSystem.getPixelNoteEnds();

			if (pixelEndsTex != null)
				frames = pixelEndsTex;
			else
				loadGraphic('assets/skins/Default/arrowEnds.png');

			// ANIMATIONS for hold ends
			for (i in 0...animArrows.length)
			{
				animation.add(animArrows[i] + 'holdend', [i + 4]);
				animation.add(animArrows[i] + 'hold', [i]);
			}
		}
		else
		{
			var pixelTex = NoteSkinSystem.getPixelNoteSkin();
			if (pixelTex != null)
				frames = pixelTex;
			else
				loadGraphic('assets/skins/Default/arrows-pixels.png');

			// Animations pixel (statics)
			for (i in 0...animArrows.length)
			{
				animation.add(animArrows[i] + 'Scroll', [i + 4]);
			}
		}

		setGraphicSize(Std.int(width * PlayStateConfig.PIXEL_ZOOM));
		updateHitbox();
		antialiasing = false;
	}

	function loadNormalNotes():Void
	{
		// Obtener frames y animaciones de la skin actual
		frames = NoteSkinSystem.getNoteSkin();
		var anims = NoteSkinSystem.getSkinAnimations();

		if (anims != null)
		{
			var animTypes = [
				{key: 'Scroll', anims: [anims.left, anims.down, anims.up, anims.right]},
				{key: 'holdend', anims: [anims.leftHoldEnd, anims.downHoldEnd, anims.upHoldEnd, anims.rightHoldEnd]},
				{key: 'hold', anims: [anims.leftHold, anims.downHold, anims.upHold, anims.rightHold]}
			];

			for (animType in animTypes)
			{
				for (i in 0...animArrows.length)
				{
					if (animType.anims[i] != null)
						animation.addByPrefix(animArrows[i] + animType.key, animType.anims[i]);
				}
			}
		}
		else
		{
			// Fallback a animaciones default
			loadDefaultAnimations();
		}

		setGraphicSize(Std.int(width * 0.7));
		updateHitbox();
		antialiasing = true;
	}

	function loadDefaultAnimations():Void
	{
		// Animaciones por defecto de FNF
		var animPrefixes = [
			{key: 'Scroll', prefixes: ['purple0', 'blue0', 'green0', 'red0']},
			{key: 'holdend', prefixes: ['pruple end hold', 'blue hold end', 'green hold end', 'red hold end']},
			{key: 'hold', prefixes: ['purple hold piece', 'blue hold piece', 'green hold piece', 'red hold piece']}
		];

		for (animType in animPrefixes)
		{
			for (i in 0...animArrows.length)
			{
				animation.addByPrefix(animArrows[i] + animType.key, animType.prefixes[i]);
			}
		}
	}

	function setupNoteDirection():Void
	{
		for (i in 0...animArrows.length)
		{
			if (noteData == i)
			{
				x += swagWidth * i; // CORREGIDO: Ahora solo suma el offset de dirección
				animation.play(animArrows[i] + 'Scroll');
				break;
			}
		}
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

		// Animar hold end según dirección
		for (i in 0...animArrows.length)
		{
			if (noteData == i)
			{
				animation.play(animArrows[i] + 'holdend');
				break;
			}
		}

		updateHitbox();
		x -= width / 2;

		if (PlayState.curStage.startsWith('school'))
		{
			x += 30;
		}

		// Configurar previous note hold

		if (prevNote.isSustainNote)
		{
			for (i in 0...animArrows.length)
			{
				if (prevNote.noteData == i)
				{
					prevNote.animation.play(animArrows[i] + 'hold');
					break;
				}
			}
			
			prevNote.scale.y *= Conductor.stepCrochet / 100 * 1.5 * PlayState.SONG.speed;

			if (PlayState.curStage.startsWith('school'))
				prevNote.scale.y *= 1.19;

			prevNote.updateHitbox();
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		// canBeHit se recalcula solo cada ~10ms de cambio en songPosition (cache).
		// tooLate lo gestiona NoteManager exclusivamente para evitar duplicados
		// (antes se seteaba aqui Y en NoteManager, causando que missNote() nunca
		// se llamara porque el manager asumia que ya estaba gestionado).
		if (Math.abs(Conductor.songPosition - _lastSongPos) > 10)
		{
			_lastSongPos = Conductor.songPosition;

			if (mustPress)
			{
				canBeHit = (strumTime > Conductor.songPosition - _hitWindowCache
				         && strumTime < Conductor.songPosition + _hitWindowCache);
			}
			else
			{
				canBeHit = false;
				if (strumTime <= Conductor.songPosition)
					wasGoodHit = true;
			}
		}

		// Visual feedback cuando NoteManager marca la nota como tooLate
		if (tooLate && alpha > 0.3)
			alpha = 0.3;
	}
}