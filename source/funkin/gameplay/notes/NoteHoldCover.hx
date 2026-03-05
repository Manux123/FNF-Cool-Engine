package funkin.gameplay.notes;

import flixel.FlxSprite;
import flixel.FlxG;
import flixel.graphics.frames.FlxAtlasFrames;
import funkin.gameplay.notes.NoteSkinSystem;

using StringTools;
/**
 * NoteHoldCover — Animación visual que se muestra mientras el jugador sostiene una nota larga.
 *
 * ─── CICLO DE VIDA ───────────────────────────────────────────────────────────
 *
 *   IDLE ──playStart()──→ START ──(fin)──→ LOOP
 *                                           │
 *                              playEnd() ───┤
 *                                           ▼
 *                                          END ──(fin)──→ IDLE (kill)
 *
 *   Si playEnd() se llama durante START → END_PENDING:
 *   cuando START termina pasa a END directamente sin pasar por LOOP.
 *
 * ─── POSICIONAMIENTO ─────────────────────────────────────────────────────────
 *
 *   setup() recibe el CENTRO del strum (strumCenterX, strumCenterY).
 *   NoteManager debe pasar strum.x + strum.width/2 y strum.y + strum.height/2.
 *   El cover se centra sobre ese punto más el offset configurado en splash.json.
 *
 * ─── COMPATIBILIDAD CON MODS ─────────────────────────────────────────────────
 *
 *   Toda la resolución de assets pasa por NoteSkinSystem.getHoldCoverTexture()
 *   y NoteSkinSystem.getHoldCoverData(), que buscan primero en el mod activo
 *   y hacen fallback a los assets base automáticamente.
 */
class NoteHoldCover extends FlxSprite
{
	// ─── Estados ──────────────────────────────────────────────────────────────
	static inline var STATE_IDLE        = 0;
	static inline var STATE_START       = 1;
	static inline var STATE_LOOP        = 2;
	static inline var STATE_END         = 3;
	static inline var STATE_END_PENDING = 4;

	var _state:Int = STATE_IDLE;

	// ─── Skin cargada ─────────────────────────────────────────────────────────
	var _hcData:NoteSkinSystem.NoteHoldCoverData = null;
	var _color:String        = 'Purple';
	var _loadedSplash:String = '';
	var _loadedColor:String  = '';

	/** Prefijos de animación activos (con sufijo de color si perColorTextures=true). */
	var _startAnim:String = '';
	var _loopAnim:String  = '';
	var _endAnim:String   = '';

	/** Centro del strum guardado para re-centrar tras cambio de skin. */
	var _strumCenterX:Float = 0;
	var _strumCenterY:Float = 0;

	// ─── Propiedad pública ────────────────────────────────────────────────────

	/**
	 * true mientras el cover esté en uso (START / LOOP / END / END_PENDING).
	 * NoteRenderer lo comprueba para decidir si puede reutilizar este cover del pool.
	 */
	public var inUse(get, never):Bool;
	inline function get_inUse():Bool return _state != STATE_IDLE && alive;

	public function new()
	{
		super(0, 0);
		visible = false;
		active  = false;
		alive   = false;
	}

	// ─── API PÚBLICA ──────────────────────────────────────────────────────────

	/**
	 * Prepara el cover para ser usado.
	 * Carga la skin desde NoteSkinSystem (con caché — no recarga si ya es la misma),
	 * centra el sprite sobre el strum y lo pone listo para playStart().
	 *
	 * @param strumCenterX  Centro-X del strum  (strum.x + strum.width  / 2).
	 * @param strumCenterY  Centro-Y del strum  (strum.y + strum.height / 2).
	 * @param noteData      Dirección 0-3 → determina el color (Purple/Blue/Green/Red).
	 * @param splashName    Override de splash (null = splash activo del sistema).
	 */
	public function setup(strumCenterX:Float, strumCenterY:Float, noteData:Int, ?splashName:String):Void
	{
		_state = STATE_IDLE;
		_strumCenterX = strumCenterX;
		_strumCenterY = strumCenterY;

		final colors = ['Purple', 'Blue', 'Green', 'Red'];
		_color = (noteData >= 0 && noteData < colors.length) ? colors[noteData] : 'Purple';

		final resolvedSplash = (splashName != null && splashName != '')
			? splashName
			: NoteSkinSystem.currentSplash;

		// ── Cargar frames solo si cambió splash o color ───────────────────
		if (resolvedSplash != _loadedSplash || _color != _loadedColor || frames == null)
		{
			_hcData = NoteSkinSystem.getHoldCoverData(resolvedSplash);

			var atlasFrames:FlxAtlasFrames = null;
			try { atlasFrames = NoteSkinSystem.getHoldCoverTexture(_color, resolvedSplash); }
			catch (e:Dynamic) { trace('[NoteHoldCover] Error cargando textura $_color/$resolvedSplash: $e'); }

			if (atlasFrames != null)
			{
				frames = atlasFrames;

				// Prefijos con sufijo de color si perColorTextures=true
				final perColor    = (_hcData.perColorTextures == true);
				final colorSuffix = perColor ? _color : '';
				_startAnim = (_hcData.startPrefix != null ? _hcData.startPrefix : 'holdCoverStart') + colorSuffix;
				_loopAnim  = (_hcData.loopPrefix  != null ? _hcData.loopPrefix  : 'holdCover')      + colorSuffix;
				_endAnim   = (_hcData.endPrefix   != null ? _hcData.endPrefix   : 'holdCoverEnd')   + colorSuffix;

				_setupAnimations();

				antialiasing = (_hcData.antialiasing == true);
				final s:Float = (_hcData.scale != null && _hcData.scale > 0) ? _hcData.scale : 1.0;
				scale.set(s, s);
				updateHitbox();

				_loadedSplash = resolvedSplash;
				_loadedColor  = _color;
			}
			else
			{
				trace('[NoteHoldCover] WARN: sin frames para $_color/$resolvedSplash → cover invisible');
				makeGraphic(1, 1, 0x00000000);
				_loadedSplash = '';
				_loadedColor  = '';
				_startAnim = _loopAnim = _endAnim = '';
			}
		}

		// ── Centrar el cover sobre el strum ───────────────────────────────
		_applyPosition();

		revive();
		visible = false;
		active  = true;
	}

	/**
	 * Arranca la animación de START.
	 * Cuando termina pasa automáticamente a LOOP (o END si playEnd() fue llamado antes).
	 *
	 * FIX: si startPrefix == loopPrefix (mismo nombre de animación), saltamos
	 * directamente a LOOP. De lo contrario la animación se registra solo una vez
	 * como looped=true (la segunda addByPrefix sobreescribe la primera) y
	 * animation.finished nunca sería true → el state machine se atasca en START.
	 */
	public function playStart():Void
	{
		if (!alive) return;

		final hasUniqueStart = (_startAnim != '' && _startAnim != _loopAnim
			&& animation.getByName(_startAnim) != null);

		if (hasUniqueStart)
		{
			_state = STATE_START;
			visible = true;
			animation.play(_startAnim, true);
		}
		else
		{
			// Sin animación de inicio propia → ir directo al loop
			_state = STATE_START;
			_playLoop();
		}
	}

	/**
	 * Arranca END (o marca END_PENDING si START aún no terminó).
	 * @return true si END se inició directamente; false si quedó pendiente.
	 */
	public function playEnd():Bool
	{
		switch (_state)
		{
			case STATE_LOOP:
				_playEnd();
				return true;

			case STATE_START:
				_state = STATE_END_PENDING;
				return false;

			case STATE_END, STATE_END_PENDING:
				return true; // ya está saliendo

			default:
				_killSelf();
				return true;
		}
	}

	// ─── UPDATE ───────────────────────────────────────────────────────────────

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (!alive) return;

		switch (_state)
		{
			case STATE_START:
				// START → LOOP cuando la animación termina
				if (animation.name == _startAnim && animation.finished)
					_playLoop();

			case STATE_END_PENDING:
				// START terminó mientras esperábamos el end → ahora reproducir END
				// Cuando startAnim == loopAnim no hay animación de start separada;
				// en ese caso END_PENDING no debería ocurrir (playStart va directo a LOOP).
				// Por seguridad: si estamos en loop y animation.finished=false simplemente
				// esperamos a que playEnd() sea llamado de nuevo desde el exterior.
				if (_startAnim != _loopAnim && animation.name == _startAnim && animation.finished)
					_playEnd();

			case STATE_END:
				// AUTO-KILL cuando el end termina
				if (animation.name == _endAnim && animation.finished)
					_killSelf();

			case STATE_LOOP:
				// looped=true se encarga solo — nada que hacer aquí

			default:
		}
	}

	// ─── PRIVADAS ─────────────────────────────────────────────────────────────

	function _setupAnimations():Void
	{
		if (_hcData == null || frames == null) return;

		final fps:Int     = (_hcData.framerate     != null && _hcData.framerate     > 0) ? _hcData.framerate     : 24;
		final loopFps:Int = (_hcData.loopFramerate != null && _hcData.loopFramerate > 0) ? _hcData.loopFramerate : 48;

		_addPrefixAnim(_startAnim, fps,     false);
		_addPrefixAnim(_loopAnim,  loopFps, true);
		_addPrefixAnim(_endAnim,   fps,     false);
	}

	inline function _addPrefixAnim(prefix:String, fps:Int, looped:Bool):Void
	{
		if (prefix == '' || frames == null) return;
		var found = false;
		for (f in frames.frames)
			if (f.name != null && f.name.startsWith(prefix)) { found = true; break; }
		if (found)
			animation.addByPrefix(prefix, prefix, fps, looped);
	}

	/**
	 * Centra el cover sobre _strumCenterX / _strumCenterY (centro VISUAL del strum).
	 *
	 * FIX: usar width/height (ya incluyen scale) en lugar de frameWidth/frameHeight
	 * que son las dimensiones del frame SIN escalar. Con scale=4 y frameWidth=200,
	 * width=800 — usar frameWidth desplazaba el cover ~300px a la derecha.
	 *
	 * El offset del splash.json permite ajuste fino por skin.
	 */
	function _applyPosition():Void
	{
		// width/height ya incorporan scale → correcto para cualquier escala
		final fw:Float = (width  > 0) ? width  : frameWidth;
		final fh:Float = (height > 0) ? height : frameHeight;

		x = _strumCenterX - fw * 0.5 - 20;
		y = _strumCenterY - fh * 0.5 + 40;

		// Ajuste fino desde splash.json
		if (_hcData != null && _hcData.offset != null && _hcData.offset.length >= 2)
		{
			x += _hcData.offset[0];
			y += _hcData.offset[1];
		}
	}

	function _playLoop():Void
	{
		_state = STATE_LOOP;
		visible = true;
		if (_loopAnim != '' && animation.getByName(_loopAnim) != null)
			animation.play(_loopAnim, true);
	}

	function _playEnd():Void
	{
		_state = STATE_END;
		visible = true;
		if (_endAnim != '' && animation.getByName(_endAnim) != null)
			animation.play(_endAnim, true);
		else
			_killSelf(); // sin animación de fin → desaparecer
	}

	function _killSelf():Void
	{
		_state  = STATE_IDLE;
		visible = false;
		active  = false;
		kill();
	}
}
