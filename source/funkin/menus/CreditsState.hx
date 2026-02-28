package funkin.menus;

/**
 * CreditsState v2 — Friday Night Funkin' v-slice style credits.
 *
* ─── Features ───────────────────────────────── ──────────────────────────────────
* • Smooth and continuous scrolling with variable speed (hold ENTER/SPACE = fast, SHIFT = pause)
* • Lazy build: Lines are created on demand based on scrolling.
* • FlxText pool recycled via FlxSpriteGroup.recycle() — zero allocations in-game
* • Data in JSON (assets/data/credits.json) → editable without recompiling
* • Mod support: mods/<mod>/data/credits.json adds entries to the end
* • Scripting: assets/states/CreditsState/ (automatically loaded by MusicBeatState)
* • Hooks: onCreate, onUpdate (elapsed), onCreditsEnd, onExit
* • headerColor/bodyColor per entry (hex without # e.g., "FF4CA0", optional)
 *
 * ─── Scripts (HScript) ───────────────────────────────────────────────────────
 *  Variables: creditsState, creditsGroup, bg
 *  Functions: onCreate(), onUpdate(elapsed), onCreditsEnd(), onExit()
 *
 * ─── Credits JSON ────────────────────────────────────────────────────────
 *  assets/data/credits.json:
 *  {
 *    "entries": [
 *      {
 *        "header": "Directores",
 *        "headerColor": "FF4CA0",
 *        "body": [
 *          { "line": "ninjamuffin99 — Programación" },
 *          { "line": "PhantomArcade — Animación" }
 *        ]
 *      }
 *    ]
 *  }
 *
 *  For mods, place in mods/<mod>/data/credits.json
 *  Entries are added to the END of the database.
 */
#if desktop
import data.Discord.DiscordClient;
#end
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import funkin.menus.credits.CreditsData;
import funkin.menus.credits.CreditsDataHandler;
import funkin.scripting.ScriptHandler;
import funkin.transitions.StateTransition;

using StringTools;

class CreditsState extends funkin.states.MusicBeatState
{
	// ── Layout ─────────────────────────────────────────────────────────────
	static final SCREEN_PAD       = 140;
	static final FONT_HEADER      = 40;
	static final FONT_BODY        = 28;
	static final LINE_SPACING     = 8;    // px extra entre líneas
	static final SECTION_GAP      = 60;   // px entre secciones
	static final COLOR_HEADER_DEF = 0xFFFFFFFF;
	static final COLOR_BODY_DEF   = 0xFFCCCCCC;
	static final COLOR_STROKE     = 0xFF000000;
	static final STROKE_SIZE      = 2.0;

	// ── Velocidades de scroll ───────────────────────────────────────────────
	/** Velocidad base en px/segundo. Los scripts pueden modificar esta variable. */
	public var scrollSpeed:Float   = 80.0;
	static final FAST_MULTIPLIER   = 4.0;

	// ── Escena ─────────────────────────────────────────────────────────────
	public var bg:FlxSprite;
	public var creditsGroup:FlxSpriteGroup;

	// ── Construcción lazy ──────────────────────────────────────────────────
	var _entries:Array<CreditsEntry> = [];
	var _entryIdx:Int  = 0;   // índice de la entrada actual
	var _lineIdx:Int   = 0;   // sub-índice dentro de la entrada (0 = header, 1+ = body)
	var _buildY:Float  = 0;   // Y relativa al grupo donde añadir la próxima línea
	var _allBuilt:Bool = false;

	// ── Estado interno ─────────────────────────────────────────────────────
	var _hasEnded:Bool        = false;
	var _creditsExiting:Bool  = false;

	// ───────────────────────────────────────────────────────────────────────

	override function create():Void
	{
		super.create(); // MusicBeatState carga automáticamente assets/states/CreditsState/

		#if desktop
		DiscordClient.changePresence("Créditos", null);
		#end

		// ── Fondo oscuro ───────────────────────────────────────────────────
		bg = new FlxSprite();
		bg.makeGraphic(FlxG.width, FlxG.height, 0xFF1a1a2e);
		bg.scrollFactor.set();
		add(bg);

		// ── Borde decorativo inferior ──────────────────────────────────────
		var bottomBar = new FlxSprite(0, FlxG.height - 4);
		bottomBar.makeGraphic(FlxG.width, 4, 0x44FFFFFF);
		bottomBar.scrollFactor.set();
		add(bottomBar);

		// ── Grupo de créditos ──────────────────────────────────────────────
		creditsGroup = new FlxSpriteGroup();
		creditsGroup.x = SCREEN_PAD;
		creditsGroup.y = FlxG.height / 1.5; // empieza dos pantallas abajo para que no pop al inicio
		add(creditsGroup);

		// ── Datos de créditos ──────────────────────────────────────────────
		CreditsDataHandler.reload();
		final data = CreditsDataHandler.get();
		_entries = (data != null && data.entries != null) ? data.entries : [];

		// ── Música ─────────────────────────────────────────────────────────
		if (FreeplayState.vocals == null)
		{
			final music = Paths.music('freeplayRandom/freeplayRandom');
			if (music != null) FlxG.sound.playMusic(music, 0.0);
		}
		if (FlxG.sound.music != null) FlxG.sound.music.volume = 0.0;

		// ── Exponer vars a scripts ─────────────────────────────────────────
		ScriptHandler.setOnScripts('creditsState', this);
		ScriptHandler.setOnScripts('creditsGroup', creditsGroup);
		ScriptHandler.setOnScripts('bg', bg);
		ScriptHandler.callOnScripts('onCreate', null);
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		// Fade-in de música
		if (FlxG.sound.music != null && FlxG.sound.music.volume < 0.7)
			FlxG.sound.music.volume = Math.min(0.7, FlxG.sound.music.volume + 0.5 * elapsed);

		// ── Construcción lazy ──────────────────────────────────────────────
		if (!_allBuilt) _buildPendingLines();

		// ── Velocidad de scroll ────────────────────────────────────────────
		var spd:Float;
		if (controls.PAUSE || FlxG.keys.pressed.SHIFT)
			spd = 0.0;
		else if (controls.ACCEPT || FlxG.keys.pressed.SPACE)
			spd = scrollSpeed * FAST_MULTIPLIER;
		else
			spd = scrollSpeed;

		creditsGroup.y -= spd * elapsed;

		// ── Culling + fade-in basado en posición en pantalla ──────────────
		final fadeZoneBottom = 100.0;
		creditsGroup.forEachExists(function(s:FlxSprite)
		{
			final screenY = creditsGroup.y + s.y;

			if (screenY + s.height <= 0)
			{
				s.kill();
				return;
			}

			// Fade suave al entrar desde el borde inferior
			if (screenY > FlxG.height - fadeZoneBottom)
				s.alpha = Math.max(0, 1 - (screenY - (FlxG.height - fadeZoneBottom)) / fadeZoneBottom);
			else
				s.alpha = 1.0;
		});

		// ── Detectar fin de créditos ───────────────────────────────────────
		if (!_hasEnded && _allBuilt && creditsGroup.getFirstExisting() == null)
		{
			_hasEnded = true;
			ScriptHandler.callOnScripts('onCreditsEnd', null);
			new FlxTimer().start(1.5, function(_) exit());
		}

		// ── BACK para salir ────────────────────────────────────────────────
		if (controls.BACK)
		{
			FlxG.sound.play(Paths.sound('menus/cancelMenu'));
			exit();
		}

		ScriptHandler.callOnScripts('onUpdate', [elapsed]);
	}

	// ── Construcción lazy ────────────────────────────────────────────────────

	/**
	 * Construye líneas mientras el frente del contenido
	 * esté dentro del viewport (+ prefetch de 200px).
	 */
	function _buildPendingLines():Void
	{
		final viewBottom = FlxG.height + 200;

		while (!_allBuilt && creditsGroup.y + _buildY <= viewBottom)
		{
			if (_entryIdx >= _entries.length)
			{
				_allBuilt = true;
				return;
			}

			final entry  = _entries[_entryIdx];
			final hColor = _parseColor(entry.headerColor, COLOR_HEADER_DEF);
			final bColor = _parseColor(entry.bodyColor,   COLOR_BODY_DEF);

			// ── Header (lineIdx == 0) ──────────────────────────────────────
			if (_lineIdx == 0)
			{
				if (entry.header != null && entry.header.trim() != '')
				{
					final t = _makeLine(entry.header, _buildY, true, hColor);
					_buildY += t.height + LINE_SPACING;
					_lineIdx = 1;
					return; // una sola línea por frame
				}
				else
				{
					_lineIdx = 1; // sin header, pasar directo al body
				}
			}

			// ── Body (lineIdx >= 1) ────────────────────────────────────────
			final body    = entry.body != null ? entry.body : [];
			final bodyIdx = _lineIdx - 1;

			if (bodyIdx < body.length)
			{
				final t = _makeLine(body[bodyIdx].line, _buildY, false, bColor);
				_buildY += t.height + LINE_SPACING;
				_lineIdx++;
				return;
			}

			// ── Entrada completa → siguiente ──────────────────────────────
			_buildY  += SECTION_GAP;
			_entryIdx++;
			_lineIdx  = 0;
		}
	}

	/**
	 * Crea o recicla un FlxText y lo añade al creditsGroup.
	 * Usa el objeto pool interno de FlxSpriteGroup.
	 */
	function _makeLine(text:String, yPos:Float, isHeader:Bool, color:FlxColor):FlxText
	{
		var t:FlxText = cast creditsGroup.recycle(() ->
		{
			var nt = new FlxText();
			nt.antialiasing = true;
			return nt;
		});

		t.x           = 0;
		t.y           = yPos;
		t.fieldWidth  = FlxG.width - SCREEN_PAD * 2;
		t.text        = text;
		t.bold        = isHeader;
		t.setFormat(
			Paths.font('Funkin.otf'),
			isHeader ? FONT_HEADER : FONT_BODY,
			color,
			FlxTextAlign.LEFT,
			FlxTextBorderStyle.OUTLINE,
			COLOR_STROKE,
			true
		);
		t.borderSize  = STROKE_SIZE;
		t.alpha       = 0;   // empieza invisible; el update lo va a hacer fade-in
		t.alive       = true;
		t.visible     = true;

		return t;
	}

	// ── Helpers ──────────────────────────────────────────────────────────────

	static function _parseColor(hex:Null<String>, def:Int):FlxColor
	{
		if (hex == null || hex.trim() == '') return def;
		try   { return FlxColor.fromString('#' + hex.trim()); }
		catch (_:Dynamic) { return def; }
	}

	// ── API pública (para scripts) ────────────────────────────────────────────

	/**
	 * Añade una entrada extra a los créditos (solo funciona antes de _allBuilt).
	 * Útil para mods que quieran añadir créditos via script en runtime.
	 */
	public function addEntry(entry:CreditsEntry):Void
	{
		if (_entries != null && !_allBuilt)
			_entries.push(entry);
	}

	/** Salta al final de los créditos. */
	public function skipToEnd():Void
	{
		_allBuilt = true;
		creditsGroup.forEach(function(s:FlxSprite) s.kill(), true);
	}

	// ── Salida ────────────────────────────────────────────────────────────────

	public function exit():Void
	{
		if (_creditsExiting) return;
		_creditsExiting = true;
		ScriptHandler.callOnScripts('onExit', null);
		StateTransition.switchState(new funkin.menus.MainMenuState());
	}

	// ── Cleanup ───────────────────────────────────────────────────────────────

	override function destroy():Void
	{
		_entries = null;
		super.destroy();
	}
}