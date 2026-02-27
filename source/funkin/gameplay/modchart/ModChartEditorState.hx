package funkin.gameplay.modchart;

import flixel.FlxG;
import flixel.FlxCamera;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.group.FlxGroup;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.math.FlxMath;
import funkin.gameplay.objects.StrumsGroup;
import funkin.gameplay.notes.StrumNote;
import funkin.gameplay.notes.Note;
import funkin.transitions.StateTransition;
import funkin.gameplay.notes.NoteSplash;
import funkin.gameplay.NoteManager;
import funkin.gameplay.modchart.ModChartEvent;
import funkin.gameplay.modchart.ModChartManager;
import funkin.gameplay.PlayState;
import funkin.data.Conductor;
import funkin.data.Song.StrumsGroupData;
import funkin.data.Song;

/**
 * ============================================================
 *  ModChartEditorState.hx  –  Editor visual de ModCharts v2
 * ============================================================
 *
 *  Es un FlxState independiente — NO un SubState.
 *  Se abre con StateTransition.switchState(new ModChartEditorState())
 *  después de guardar los datos necesarios en los statics.
 *
 *  Desde PlayState (F8):
 *    ModChartEditorState.pendingManager    = modChartManager;
 *    ModChartEditorState.pendingStrumsData = strumsGroups.map(g -> g.data);
 *    modChartManager = null; // evitar doble-destroy
 *    StateTransition.switchState(new ModChartEditorState());
 */

// ─── Typedef ventana flotante ─────────────────────────────────────────────────
typedef WinData =
{
	var title     : String;
	var x         : Float;
	var y         : Float;
	var w         : Float;
	var h         : Float;
	var visible   : Bool;
	var minimized : Bool;
	var allSprites: Array<flixel.FlxBasic>;
	var bg        : FlxSprite;
	var shadow    : FlxSprite;
	var titleBar  : FlxSprite;
	var titleTxt  : FlxText;
	var minBtn    : FlxText;
	var closeBtn  : FlxText;
	@:optional var contentGroup: FlxGroup;
}

// ═════════════════════════════════════════════════════════════════════════════

class ModChartEditorState extends FlxState
{
	// ── Datos transferidos desde PlayState vía statics ────────────────────────
	public static var pendingManager    : ModChartManager       = null;
	public static var pendingStrumsData : Array<funkin.data.Song.StrumsGroupData> = null;
	// ── Referencias externas (sólo para leer metadatos del modchart) ──────────
	private var manager      : ModChartManager;
	// Datos de los grupos originales de PlayState (solo metadatos, no sprites)
	private var srcStrumsGrps: Array<funkin.data.Song.StrumsGroupData>;

	// ── Cámara exclusiva del editor ───────────────────────────────────────────
	private var editorCam : FlxCamera;

	// ── Layout ────────────────────────────────────────────────────────────────
	static inline var SW      = 1280;
	static inline var SH      = 720;
	static inline var TL_H   = 200;
	static inline var TL_RH  = 28;
	static inline var BAR_H  = 26;

	private var tlY       : Float;
	private var gameAreaH : Float;

	// ── STRUMS PROPIOS DEL EDITOR ─────────────────────────────────────────────
	// Creamos StrumsGroups nuevos — NO tocamos los de PlayState
	private var editorGroups      : Array<StrumsGroup>   = [];
	private var editorStrumBaseX  : Array<Array<Float>>  = [];
	private var editorStrumBaseY  : Array<Array<Float>>  = [];
	private var strumLineY        : Float = 0;

	// ── NOTE MANAGER (igual que PlayState) ────────────────────────────────────
	private var noteManager  : NoteManager;
	private var editorNotes  : FlxTypedGroup<Note>;
	private var editorSplash : FlxTypedGroup<NoteSplash>;

	// Los grupos de strums que NoteManager necesita
	private var editorCpuStrums    : FlxTypedGroup<FlxSprite>;
	private var editorPlayerStrums : FlxTypedGroup<FlxSprite>;
	private var editorCpuGroup     : StrumsGroup;
	private var editorPlayerGroup  : StrumsGroup;

	// ── Selection boxes sobre strums ──────────────────────────────────────────
	private var selBoxGroup : FlxGroup;
	private var selBoxes    : Array<Array<FlxSprite>> = [];

	// ── Playback ──────────────────────────────────────────────────────────────
	private var playheadBeat : Float = 0;
	private var isPlaying    : Bool  = false;
	private var songPosition : Float = 0; // ms

	// ── Audio ─────────────────────────────────────────────────────────────────
	private var vocals   : FlxSound = null;
	private var volValue : Float    = 1.0;
	private var audioLbl : FlxText;
	private var volLbl   : FlxText;

	// ── Timeline ──────────────────────────────────────────────────────────────
	private var tlScroll     : Float = 0;
	private var beatsVisible : Float = 16;
	static inline var BV_MIN = 2.0;
	static inline var BV_MAX = 128.0;

	private var tlGroup     : FlxGroup;
	private var evSprites   : Array<{sp:FlxSprite, lbl:FlxText, ev:ModChartEvent}> = [];
	private var playheadSpr : FlxSprite;
	private var zoomLbl     : FlxText;
	private var beatInfoLbl : FlxText;
	private var rowCount    : Int   = 0;
	private var rowH        : Float = 20;

	// ── Evento seleccionado ───────────────────────────────────────────────────
	private var selectedEv : ModChartEvent = null;

	// ── Undo ──────────────────────────────────────────────────────────────────
	private var undoStack : Array<String> = [];

	// ── Ventanas ──────────────────────────────────────────────────────────────
	private var windows     : Array<WinData> = [];
	private var windowGroup : FlxGroup;
	private var draggingWin : WinData = null;
	private var dragOX      : Float   = 0;
	private var dragOY      : Float   = 0;

	// ── Formulario ────────────────────────────────────────────────────────────
	private var newType   : ModEventType = MOVE_X;
	private var newTarget : String       = "player";
	private var newStrumI : Int          = -1;
	private var newBeat   : Float        = 0;
	private var newValue  : Float        = 0;
	private var newDur    : Float        = 1;
	private var newEase   : ModEase      = QUAD_OUT;
	private var focusField: String       = "";
	private var fieldBufs : Map<String, String> = new Map();

	private var lblType   : FlxText;
	private var lblTarget : FlxText;
	private var lblStrum  : FlxText;
	private var lblEase   : FlxText;
	private var fldBeat   : FlxText;
	private var fldVal    : FlxText;
	private var fldDur    : FlxText;
	private var inspTxt   : FlxText;
	private var statusTxt : FlxText;
	private var evListTxts: Array<FlxText> = [];
	private var evListWin : WinData;
	private var evListX   : Float;
	private var evListY   : Float;

	// ── Strum Properties window ───────────────────────────────────────────────
	private var strumPropWin  : WinData;
	private var strumPropTxts : Array<FlxText> = [];
	private var strumPropBtns : Array<{x:Float,y:Float,w:Float,h:Float,cb:Void->Void}> = [];

	private var selectedGroupIdx : Int = -1;
	private var selectedStrumIdx : Int = -1;

	// ── Hit-areas ─────────────────────────────────────────────────────────────
	private var hitBtns  : Array<{x:Float,y:Float,w:Float,h:Float,cb:Void->Void}> = [];
	private var hitFields: Array<{x:Float,y:Float,w:Float,h:Float,key:String}>    = [];

	// ── Ayuda ─────────────────────────────────────────────────────────────────
	private var helpBg  : FlxSprite;
	private var helpTxt : FlxText;
	private var showHelp: Bool = false;

	// ── Paleta ────────────────────────────────────────────────────────────────
	static inline var C_GAME_BG   = 0xFF080815;
	static inline var C_GRID      = 0xFF101022;
	static inline var C_TL_BG    = 0xFF050510;
	static inline var C_TL_BORDER= 0xFF2233AA;
	static inline var C_RULER    = 0xFF0E0E22;
	static inline var C_BEAT_LINE= 0xFF1A1A3C;
	static inline var C_STEP_LINE= 0xFF10102A;
	static inline var C_PLAYHEAD = 0xFFFF2255;
	static inline var C_ROW_A    = 0xFF0A0A1A;
	static inline var C_ROW_B    = 0xFF080814;
	static inline var C_WIN_T    = 0xFF121228;
	static inline var C_ACCENT   = 0xFF4466EE;
	static inline var C_ACCENT2  = 0xFFEE4466;
	static inline var C_TEXT     = 0xFFDDDDFF;
	static inline var C_DIM      = 0xFF5566AA;
	static inline var C_SEL_BOX  = 0xAAFFCC00;

	// ═════════════════════════════════════════════════════════════════════════
	// CONSTRUCTOR
	// ═════════════════════════════════════════════════════════════════════════

	public function new()
	{
		super();

		// Leer datos transferidos por PlayState vía statics
		manager       = pendingManager    ?? new ModChartManager([]);
		srcStrumsGrps = pendingStrumsData ?? [];
		pendingManager    = null;
		pendingStrumsData = null;

		rowCount  = srcStrumsGrps.length * 4;
		tlY       = SH - TL_H;
		gameAreaH = tlY - BAR_H;

		fieldBufs.set("beat",     "0.00");
		fieldBufs.set("value",    "0.00");
		fieldBufs.set("duration", "1.00");
	}

	// ═════════════════════════════════════════════════════════════════════════
	// CREATE
	// ═════════════════════════════════════════════════════════════════════════

	override function create():Void
	{
		super.create();

		// Como es un FlxState, FlxG.camera ya es nuestra cámara exclusiva.
		// Solo configuramos el color de fondo.
		editorCam         = FlxG.camera;
		editorCam.bgColor = 0xFF000000;
		camera = editorCam;

		// Grupos de render (orden de capas)
		var gameBgGrp = new FlxGroup(); add(gameBgGrp);
		selBoxGroup   = new FlxGroup(); add(selBoxGroup);

		// Grupos de notas y splashes (añadidos antes que strums para que queden detrás)
		editorNotes  = new FlxTypedGroup<Note>();
		editorSplash = new FlxTypedGroup<NoteSplash>();
		add(editorNotes);
		add(editorSplash);

		tlGroup     = new FlxGroup(); add(tlGroup);
		windowGroup = new FlxGroup(); add(windowGroup);

		buildGameBackground(gameBgGrp);

		// ── CREAR STRUMS Y NOTE MANAGER ────────────────────────────────────
		setupEditorStrums();
		setupNoteManager();

		// ── REDIRIGIR EL MANAGER A LOS STRUMS DEL EDITOR ──────────────────
		// Los StrumsGroups originales de PlayState ya fueron destruidos con el
		// switchState. Hay que apuntar el manager a los strums propios del editor
		// para que seekToBeat/applyAllStates no crashee con sprites destruidos.
		manager.replaceStrumsGroups(editorGroups);

		buildInfoBar();
		buildTimeline();
		buildWinProps();
		buildWinTools();
		buildWinStrumProps();
		buildHelp();

		initAudio();

		// Beat inicial
		var bps      = bps();
		var initBeat = Conductor.songPosition * bps / 1000.0;
		playheadBeat = Math.max(0, Math.floor(initBeat));
		songPosition = playheadBeat * Conductor.crochet;
		newBeat      = playheadBeat;
		fieldBufs.set("beat", Std.string(newBeat));

		manager.seekToBeat(playheadBeat);
		applyManagerToStrums();

		pushUndo();
		refreshTimeline();
		refreshStrumPropWindow();

		trace('[MCEditor] Abierto. Grupos: ${srcStrumsGrps.length}  Eventos: ${manager.data.events.length}');
	}

	// ─────────────────────────────────────────────────────────────────────────
	// FONDO DEL ÁREA DE JUEGO
	// ─────────────────────────────────────────────────────────────────────────

	function buildGameBackground(grp:FlxGroup):Void
	{
		grp.add(mkBg(0, BAR_H, SW, gameAreaH, C_GAME_BG));
		var cols = 16;
		for (c in 0...cols + 1)
			grp.add(mkBg(Std.int(c * SW / cols), BAR_H, 1, gameAreaH, C_GRID));
		for (r in 0...9)
			grp.add(mkBg(0, Std.int(BAR_H + r * gameAreaH / 8), SW, 1, C_GRID));
	}

	// ─────────────────────────────────────────────────────────────────────────
	// CREAR STRUMS PROPIOS DEL EDITOR
	//
	// Crea nuevos StrumsGroups con los mismos IDs/flags que los de PlayState
	// pero posicionados en el área de juego del editor.
	// NO toca los strums de PlayState.
	// ─────────────────────────────────────────────────────────────────────────

	function setupEditorStrums():Void
	{
		editorGroups     = [];
		editorStrumBaseX = [];
		editorStrumBaseY = [];
		selBoxes         = [];
		editorCpuStrums    = new FlxTypedGroup<FlxSprite>();
		editorPlayerStrums = new FlxTypedGroup<FlxSprite>();
		editorCpuGroup     = null;
		editorPlayerGroup  = null;

		var ng     = srcStrumsGrps.length;

		// ── Área disponible entre paneles laterales ──────────────────────────
		// Panel izquierdo: 296px  Panel derecho: 222px
		var gameX0 = 296.0;
		var gameX1 = SW - 230.0;
		var availW = gameX1 - gameX0;   // ~754px para todos los grupos
		var zoneW  = availW / Math.max(1, ng);

		// ── Y igual que PlayState (strumLineY en la parte superior del área) ──
		strumLineY = BAR_H + gameAreaH * 0.18;

		// ── Spacing igual que PlayState: Note.swagWidth = 160 * 0.7 = 112 ───
		// Reducimos con un factor para que quepan en el editor sin solaparse.
		// El factor se calcula para que 4 strums llenen el 85% de cada zona.
		var swag       = Note.swagWidth;              // 112
		var fitFactor  = (zoneW * 0.85) / (swag * 4); // escala para que quepan
		if (fitFactor > 1.0) fitFactor = 1.0;          // nunca más grande que PlayState
		var spacing    = swag * fitFactor;              // spacing escalado

		for (gi in 0...ng)
		{
			var src = srcStrumsGrps[gi];

			// ── Centrar el grupo de 4 strums en su zona (igual que PlayState) ─
			var centerX = gameX0 + gi * zoneW + zoneW / 2.0;
			var startX  = centerX - spacing * 1.5;

			// ── StrumsGroupData: scale=1.0 porque StrumNote ya aplica 0.7
			//    internamente con setGraphicSize. No escalar dos veces. ─────────
			var gdata:StrumsGroupData = {
				id      : src.id,
				x       : startX,
				y       : strumLineY,
				cpu     : src.cpu,
				visible : true,
				spacing : spacing,
				scale   : 1.0
			};

			var edGrp = new StrumsGroup(gdata);
			editorGroups.push(edGrp);

			// ── Forzar el tamaño correcto en cada strum ───────────────────────
			// StrumNote hace setGraphicSize(w * 0.7) internamente.
			// Aplicamos fitFactor encima para que quepan en el editor.
			edGrp.strums.forEach(function(s:FlxSprite) {
				s.setGraphicSize(Std.int(s.width * fitFactor));
				s.updateHitbox();
				s.centerOffsets();
				s.cameras = [editorCam];
				add(s);
			});

			// ── Guardar posición base de cada strum ───────────────────────────
			var bx  : Array<Float>    = [];
			var by  : Array<Float>    = [];
			var sel : Array<FlxSprite> = [];

			for (si in 0...4)
			{
				var strum = edGrp.getStrum(si);
				if (strum != null)
				{
					bx.push(strum.x);
					by.push(strum.y);

					// Selection box basada en hitbox real
					var bsz = Std.int(Math.max(strum.width, strum.height) + 8);
					var box = new FlxSprite(strum.x - 4, strum.y - 4);
					box.makeGraphic(bsz, bsz, FlxColor.fromInt(C_SEL_BOX));
					box.cameras = [editorCam];
					box.visible = false;
					selBoxGroup.add(box);
					sel.push(box);
				}
				else
				{
					bx.push(0); by.push(0); sel.push(null);
				}
			}

			editorStrumBaseX.push(bx);
			editorStrumBaseY.push(by);
			selBoxes.push(sel);

			// ── Etiqueta de grupo ─────────────────────────────────────────────
			add(mkTxt(startX, strumLineY - 14, src.id + (src.cpu ? " [CPU]" : " [PLY]"), 9, C_DIM));

			// ── Registrar en los grupos que NoteManager necesita ──────────
			// Grupo 0 = CPU por defecto, Grupo 1 = Player por defecto
			// (misma lógica que PlayState)
			if (src.cpu)
			{
				if (editorCpuGroup == null) editorCpuGroup = edGrp;
				edGrp.strums.forEach(function(s:FlxSprite) editorCpuStrums.add(s));
			}
			else
			{
				if (editorPlayerGroup == null) editorPlayerGroup = edGrp;
				edGrp.strums.forEach(function(s:FlxSprite) editorPlayerStrums.add(s));
			}
		}

		// Fallback: si todos son del mismo tipo, asignar primer grupo como cpu y segundo como player
		if (editorCpuGroup == null && editorGroups.length > 0)
		{
			editorCpuGroup = editorGroups[0];
			editorGroups[0].strums.forEach(function(s:FlxSprite) editorCpuStrums.add(s));
		}
		if (editorPlayerGroup == null && editorGroups.length > 1)
		{
			editorPlayerGroup = editorGroups[1];
			editorGroups[1].strums.forEach(function(s:FlxSprite) editorPlayerStrums.add(s));
		}
		else if (editorPlayerGroup == null && editorGroups.length > 0)
		{
			editorPlayerGroup = editorGroups[0];
			editorGroups[0].strums.forEach(function(s:FlxSprite) editorPlayerStrums.add(s));
		}
	}

	// ─────────────────────────────────────────────────────────────────────────
	// CREAR NOTE MANAGER (igual que PlayState)
	// ─────────────────────────────────────────────────────────────────────────

	function setupNoteManager():Void
	{
		noteManager = new NoteManager(
			editorNotes,
			editorPlayerStrums,
			editorCpuStrums,
			editorSplash,
			editorPlayerGroup,
			editorCpuGroup,
			editorGroups
		);

		noteManager.strumLineY = strumLineY;
		noteManager.downscroll = FlxG.save.data.downscroll ?? false;

		// Generar notas desde la canción actual
		if (PlayState.SONG != null)
			noteManager.generateNotes(PlayState.SONG);

		trace('[MCEditor] NoteManager listo. strumLineY=$strumLineY');
	}

	// ─────────────────────────────────────────────────────────────────────────
	// BARRA SUPERIOR
	// ─────────────────────────────────────────────────────────────────────────

	function buildInfoBar():Void
	{
		add(mkBg(0, 0, SW, BAR_H, 0xFF090920));
		add(mkBg(0, BAR_H - 1, SW, 1, C_TL_BORDER));

		beatInfoLbl = mkTxt(6, 6, "Beat: 0.00  Step: 0  BPM: 120  0ms", 11, C_TEXT);
		add(beatInfoLbl);

		audioLbl = mkTxt(SW - 370, 6, "♪ Parado", 11, 0xFF88FFAA);
		add(audioLbl);

		volLbl = mkTxt(SW - 230, 6, "Vol: 100%", 11, C_DIM);
		add(volLbl);

		addBarBtn(SW - 172, 4, "Vol−", function() { volValue = Math.max(0, volValue - 0.1); applyVolume(); });
		addBarBtn(SW - 132, 4, "Vol+", function() { volValue = Math.min(1, volValue + 0.1); applyVolume(); });
		addBarBtn(SW - 84,  4, "[ESC]", exitEditor);
	}

	function addBarBtn(x:Float, y:Float, lbl:String, cb:Void->Void):Void
	{
		var t = mkTxt(x, y, lbl, 10, C_ACCENT); add(t);
		hitBtns.push({ x: x, y: y, w: lbl.length * 7.0 + 4, h: 18.0, cb: cb });
	}

	// ─────────────────────────────────────────────────────────────────────────
	// AUDIO
	// ─────────────────────────────────────────────────────────────────────────

	function initAudio():Void
	{
		// El audio de FlxG.sound.music persiste entre states — solo pausamos.
		if (FlxG.sound.music != null && FlxG.sound.music.playing)
			FlxG.sound.music.pause();

		// vocals es un FlxSound que vive en PlayState — no podemos accederlo
		// desde aquí tras el switchState. El editor trabaja solo con music.
		vocals = null;
		applyVolume();
	}

	function applyVolume():Void
	{
		if (FlxG.sound.music != null) FlxG.sound.music.volume = volValue;
		if (vocals != null)           vocals.volume           = volValue;
		if (volLbl != null)           volLbl.text = 'Vol: ${Std.int(volValue * 100)}%';
	}

	function seekAudioTo(ms:Float):Void
	{
		ms = Math.max(0, ms);
		if (FlxG.sound.music != null) FlxG.sound.music.time = ms;
		if (vocals != null)           vocals.time           = ms;
	}

	function pauseAudio():Void
	{
		if (FlxG.sound.music != null && FlxG.sound.music.playing) FlxG.sound.music.pause();
		if (vocals != null && vocals.playing) vocals.pause();
	}

	function resumeAudio():Void
	{
		if (FlxG.sound.music != null && !FlxG.sound.music.playing) FlxG.sound.music.resume();
		if (vocals != null && !vocals.playing) vocals.resume();
	}

	function updateAudioLabel():Void
	{
		if (audioLbl == null) return;
		var ms = isPlaying && FlxG.sound.music != null ? FlxG.sound.music.time : songPosition;
		var s  = Std.int(ms / 1000);
		var ts = '${Std.int(s / 60)}:${s % 60 < 10 ? "0" : ""}${s % 60}';
		audioLbl.text = isPlaying ? '♪ ▶ $ts' : '♪ ⏸ $ts';
	}

	// ─────────────────────────────────────────────────────────────────────────
	// APLICAR MODCHART A LOS STRUMS DEL EDITOR
	// ─────────────────────────────────────────────────────────────────────────

	function applyManagerToStrums():Void
	{
		for (gi in 0...editorGroups.length)
		{
			var grp = editorGroups[gi];
			var src = gi < srcStrumsGrps.length ? srcStrumsGrps[gi] : null;
			var id  = src != null ? src.id : grp.id;

			for (si in 0...4)
			{
				var strum = grp.getStrum(si);
				if (strum == null || gi >= editorStrumBaseX.length) continue;

				var st = manager.getState(id, si);
				if (st != null)
				{
					strum.x     = editorStrumBaseX[gi][si] + st.offsetX;
					strum.y     = editorStrumBaseY[gi][si] + st.offsetY;
					strum.angle = st.angle;
					strum.alpha = FlxMath.bound(st.alpha, 0.05, 1.0);
					strum.scale.set(st.scaleX, st.scaleY);
				}
				else
				{
					strum.x     = editorStrumBaseX[gi][si];
					strum.y     = editorStrumBaseY[gi][si];
					strum.angle = 0;
					strum.alpha = 1;
					strum.scale.set(1, 1);
				}

				// Actualizar hitbox para que strum.width/height reflejen la escala actual
				strum.updateHitbox();
				strum.centerOffsets();

				// Sync selection box sobre el strum (centrada en él)
				if (gi < selBoxes.length && si < selBoxes[gi].length && selBoxes[gi][si] != null)
				{
					var box = selBoxes[gi][si];
					box.x = strum.x - 4;
					box.y = strum.y - 4;
				}
			}
		}
	}

	// ─────────────────────────────────────────────────────────────────────────
	// TIMELINE
	// ─────────────────────────────────────────────────────────────────────────

	function buildTimeline():Void
	{
		tlGroup.add(mkBg(0, tlY, SW, TL_H, C_TL_BG));
		tlGroup.add(mkBg(0, tlY, SW, 2, C_TL_BORDER));
		tlGroup.add(mkBg(0, tlY, SW, TL_RH, C_RULER));
		tlGroup.add(mkBg(0, tlY + TL_RH, SW, 1, C_TL_BORDER));

		zoomLbl = mkTxt(SW - 155, tlY + 7, "Zoom: 16b", 11, C_DIM);
		tlGroup.add(zoomLbl);

		addTLBtn(SW - 200, tlY + 4, " + ", function() { beatsVisible = Math.max(BV_MIN, beatsVisible / 2); refreshTimeline(); });
		addTLBtn(SW - 180, tlY + 4, " − ", function() { beatsVisible = Math.min(BV_MAX, beatsVisible * 2); refreshTimeline(); });
		addTLBtn(SW - 160, tlY + 4, "ALL", function() { tlScroll = 0; beatsVisible = FlxMath.bound(getMaxBeat() + 4, BV_MIN, BV_MAX); refreshTimeline(); });

		playheadSpr = new FlxSprite(0, tlY);
		playheadSpr.makeGraphic(2, TL_H, FlxColor.fromInt(C_PLAYHEAD));
		playheadSpr.cameras = [editorCam];
		tlGroup.add(playheadSpr);

		rowH = Math.max(10.0, (TL_H - TL_RH - 2) / Math.max(1, rowCount));
	}

	public function refreshTimeline():Void
	{
		for (es in evSprites) { tlGroup.remove(es.sp, true); es.sp.destroy(); tlGroup.remove(es.lbl, true); es.lbl.destroy(); }
		evSprites = [];

		var ppb  = SW / beatsVisible;
		var dirs = ["L","D","U","R"];

		for (ri in 0...rowCount)
		{
			var ry = tlY + TL_RH + ri * rowH;
			tlGroup.add(mkBg(0, ry, SW, rowH - 1, ri % 2 == 0 ? C_ROW_A : C_ROW_B));
			var gi = Std.int(ri / 4);
			var si = ri % 4;
			var gc = gi < srcStrumsGrps.length ? srcStrumsGrps[gi] : null;
			tlGroup.add(mkTxt(2, ry + 1, '${gc != null ? gc.id.substr(0,5) : "?"}.${dirs[si]}', 8, C_DIM));
			if (si == 3 && gi < srcStrumsGrps.length - 1)
				tlGroup.add(mkBg(0, ry + rowH - 1, SW, 1, C_TL_BORDER));
		}

		var startB = Std.int(tlScroll);
		var endB   = Std.int(tlScroll + beatsVisible) + 2;
		for (b in startB...(endB + 1))
		{
			var bx = Std.int((b - tlScroll) * ppb);
			if (bx < -10 || bx > SW + 10) continue;
			tlGroup.add(mkBg(bx, tlY + TL_RH, 1, TL_H - TL_RH, b % 4 == 0 ? 0xFF3344AA : C_BEAT_LINE));
			tlGroup.add(mkTxt(bx + 2, tlY + 8, Std.string(b), b % 4 == 0 ? 11 : 9, b % 4 == 0 ? C_TEXT : C_DIM));
			for (st in 1...4)
			{
				var sx = Std.int(bx + st * ppb / 4);
				if (sx >= 0 && sx < SW) tlGroup.add(mkBg(sx, tlY + TL_RH, 1, TL_H - TL_RH, C_STEP_LINE));
			}
		}

		for (ev in manager.data.events)
		{
			for (ri in getEvRows(ev))
			{
				var ry  = tlY + TL_RH + ri * rowH;
				var ex  = (ev.beat - tlScroll) * ppb;
				var ew  = Math.max(4.0, ev.duration * ppb);
				if (ex + ew < 0 || ex > SW) continue;
				var sp  = new FlxSprite(ex, ry + 1);
				sp.makeGraphic(Std.int(Math.max(4, ew)), Std.int(rowH - 3), FlxColor.fromInt(ev.color));
				sp.alpha   = selectedEv == ev ? 1.0 : 0.75;
				sp.cameras = [editorCam];
				var lbl    = mkTxt(ex + 2, ry + 2, (ev.type:String).substr(0,6), 8, 0xFF000000);
				tlGroup.add(sp); tlGroup.add(lbl);
				evSprites.push({ sp: sp, lbl: lbl, ev: ev });
			}
		}

		tlGroup.remove(playheadSpr);
		syncPlayhead();
		tlGroup.add(playheadSpr);
		if (zoomLbl != null) zoomLbl.text = 'Zoom: ${Std.int(beatsVisible)}b';
	}

	function syncPlayhead():Void
		playheadSpr.x = (playheadBeat - tlScroll) * (SW / beatsVisible);

	function getEvRows(ev:ModChartEvent):Array<Int>
	{
		var rows:Array<Int> = [];
		for (gi in 0...srcStrumsGrps.length)
		{
			var g  = srcStrumsGrps[gi];
			var ok = ev.target == "all"
				|| (ev.target == "player" && !g.cpu)
				|| (ev.target == "cpu"    &&  g.cpu)
				|| ev.target == g.id;
			if (!ok) continue;
			if (ev.strumIdx == -1)
				for (si in 0...4) rows.push(gi * 4 + si);
			else
				rows.push(gi * 4 + ev.strumIdx);
		}
		return rows;
	}

	// ═════════════════════════════════════════════════════════════════════════
	// VENTANA: PROPIEDADES
	// ═════════════════════════════════════════════════════════════════════════

	function buildWinProps():Void
	{
		var wd = mkWin("Propiedades", 0, BAR_H + 2, 288, tlY - BAR_H - 4);
		var cx = wd.x + 8;
		var cy = wd.y + 28;
		var cw = wd.w - 16;

		wTxt(wd, cx, cy, "── NUEVO EVENTO ──", 12, C_ACCENT); cy += 18;

		wTxt(wd, cx, cy, "Tipo:",   11, C_DIM);
		lblType = wTxt(wd, cx+55, cy, (newType:String), 11, 0xFF4FC3F7);
		wBtn(wd, wd.x+cw-26, cy, "◄", function() cycleType(-1));
		wBtn(wd, wd.x+cw-10, cy, "►", function() cycleType( 1));
		cy += 15;

		wTxt(wd, cx, cy, "Target:", 11, C_DIM);
		lblTarget = wTxt(wd, cx+55, cy, newTarget, 11, 0xFF81C784);
		wBtn(wd, wd.x+cw-26, cy, "◄", function() cycleTarget(-1));
		wBtn(wd, wd.x+cw-10, cy, "►", function() cycleTarget( 1));
		cy += 15;

		wTxt(wd, cx, cy, "Strum:",  11, C_DIM);
		lblStrum = wTxt(wd, cx+55, cy, strumLbl(), 11, 0xFFFFB74D);
		wBtn(wd, wd.x+cw-26, cy, "◄", function() { newStrumI--; if (newStrumI<-1) newStrumI=3; });
		wBtn(wd, wd.x+cw-10, cy, "►", function() { newStrumI++; if (newStrumI> 3) newStrumI=-1; });
		cy += 15;

		wTxt(wd, cx, cy, "Beat:",   11, C_DIM);
		fldBeat = wField(wd, cx+55, cy, cw-57, "beat"); cy += 15;

		wTxt(wd, cx, cy, "Valor:",  11, C_DIM);
		fldVal  = wField(wd, cx+55, cy, cw-57, "value"); cy += 15;

		wTxt(wd, cx, cy, "Dur(b):", 11, C_DIM);
		fldDur  = wField(wd, cx+55, cy, cw-57, "duration"); cy += 15;

		wTxt(wd, cx, cy, "Ease:",   11, C_DIM);
		lblEase = wTxt(wd, cx+55, cy, (newEase:String), 11, 0xFFBA68C8);
		wBtn(wd, wd.x+cw-26, cy, "◄", function() cycleEaseDir(-1));
		wBtn(wd, wd.x+cw-10, cy, "►", function() cycleEaseDir( 1));
		cy += 18;

		var addBg = mkBg(cx, cy, cw, 22, C_ACCENT); addBg.alpha = 0.85;
		wSpr(wd, addBg);
		wTxt(wd, cx+6, cy+4, "+ Añadir Evento al Beat", 11, 0xFFFFFFFF);
		hitBtns.push({ x: cx, y: cy, w: cw, h: 22, cb: onClickAdd }); cy += 26;

		var phBg = mkBg(cx, cy, cw, 20, 0xFF225533); phBg.alpha = 0.82;
		wSpr(wd, phBg);
		wTxt(wd, cx+6, cy+3, "⊕ Añadir en Playhead", 11, 0xFFCCFFCC);
		hitBtns.push({ x: cx, y: cy, w: cw, h: 20, cb: function() {
			newBeat = Math.round(playheadBeat * 4) / 4;
			fieldBufs.set("beat", Std.string(newBeat));
			onClickAdd();
		}}); cy += 26;

		wSpr(wd, mkBg(cx, cy, cw, 1, C_BEAT_LINE)); cy += 5;
		wTxt(wd, cx, cy, "── EVENTOS ──", 11, C_ACCENT); cy += 14;

		evListWin = wd; evListX = cx; evListY = cy;

		var iY = wd.y + wd.h - 120;
		wSpr(wd, mkBg(wd.x, iY, wd.w, 120, 0xFF060616));
		wSpr(wd, mkBg(wd.x, iY, wd.w, 1, C_TL_BORDER));
		wTxt(wd, cx, iY + 4, "─ INSPECTOR ─", 11, C_ACCENT);
		inspTxt = wTxt(wd, cx, iY + 18, "(sin selección)", 10, C_DIM);
		inspTxt.wordWrap = true; inspTxt.fieldWidth = cw;
		statusTxt = wTxt(wd, cx, iY + 103, "Listo.", 10, 0xFF88FF88);

		addToWinGroup(wd);
		windows.push(wd);
	}

	// ═════════════════════════════════════════════════════════════════════════
	// VENTANA: TOOLS
	// ═════════════════════════════════════════════════════════════════════════

	function buildWinTools():Void
	{
		var wd = mkWin("Tools", SW - 222, BAR_H + 2, 220, 300);
		var cx = wd.x + 8;
		var cy = wd.y + 30;
		var bw = wd.w - 16;

		function tb(label:String, col:Int, cb:Void->Void):Void {
			var sbg = mkBg(cx, cy, bw, 24, col); sbg.alpha = 0.82;
			wSpr(wd, sbg);
			wTxt(wd, cx+8, cy+5, label, 12, 0xFFFFFFFF);
			hitBtns.push({ x: cx, y: cy, w: bw, h: 24, cb: cb }); cy += 28;
		}

		tb("▶  Play / Pausa  [Space]", 0xFF1E5E22, onClickPlay);
		tb("■  Stop + Reiniciar",      0xFF5E1A1A, onClickStop);
		tb("💾  Guardar   Ctrl+S",      0xFF1A3A66, onClickSave);
		tb("📂  Cargar",                0xFF2A3444, onClickLoad);
		tb("✕  Limpiar Todo",          0xFF5A1A1A, onClickNew);
		tb("↩  Deshacer   Ctrl+Z",     0xFF252535, doUndo);
		tb("❓  Ayuda   F1",            0xFF253030, function() {
			showHelp = !showHelp;
			helpBg.visible = helpTxt.visible = showHelp;
		});

		wSpr(wd, mkBg(cx, cy, bw, 1, C_BEAT_LINE)); cy += 6;
		wTxt(wd, cx, cy, "SPACE → play/pause audio",  9, C_DIM); cy += 12;
		wTxt(wd, cx, cy, "Rueda en TL → scroll",      9, C_DIM); cy += 12;
		wTxt(wd, cx, cy, "CTRL+Rueda → zoom TL",      9, C_DIM);

		addToWinGroup(wd);
		windows.push(wd);
	}

	// ═════════════════════════════════════════════════════════════════════════
	// VENTANA: STRUM PROPERTIES
	// ═════════════════════════════════════════════════════════════════════════

	function buildWinStrumProps():Void
	{
		strumPropWin = mkWin("Strum Properties", SW - 222, BAR_H + 308, 220, 220);
		addToWinGroup(strumPropWin);
		windows.push(strumPropWin);
	}

	function refreshStrumPropWindow():Void
	{
		if (strumPropWin == null) return;
		var wd = strumPropWin;
		for (t in strumPropTxts) { wd.contentGroup.remove(t, true); t.destroy(); }
		strumPropTxts = []; strumPropBtns = [];

		var cx = wd.x + 8; var cy = wd.y + 30; var cw = wd.w - 16;

		if (selectedGroupIdx < 0 || selectedStrumIdx < 0)
		{
			var t = mkTxt(cx, cy, "Click sobre un strum\ndel área de juego\npara ver propiedades.", 10, C_DIM);
			t.cameras = [editorCam];
			wd.contentGroup.add(t); strumPropTxts.push(t); return;
		}

		var gi   = selectedGroupIdx;
		var si   = selectedStrumIdx;
		var src  = srcStrumsGrps[gi];
		var st   = manager.getState(src.id, si);
		var dirs = ["LEFT","DOWN","UP","RIGHT"];

		var tt = mkTxt(cx, cy, '${src.id} / ${dirs[si]}', 10, C_ACCENT);
		tt.cameras = [editorCam]; wd.contentGroup.add(tt); strumPropTxts.push(tt); cy += 16;

		var tgt = mkTxt(cx, cy, "→ Usar como target", 9, C_DIM);
		tgt.cameras = [editorCam]; wd.contentGroup.add(tgt); strumPropTxts.push(tgt);
		hitBtns.push({ x: cx, y: cy, w: cw, h: 12, cb: function() { newTarget = src.id; newStrumI = si; }});
		cy += 16;

		function propRow(label:String, val:Float, etype:ModEventType, step:Float):Void {
			var row = mkTxt(cx, cy, '$label: ${Math.round(val*100)/100}', 10, C_TEXT);
			row.cameras = [editorCam]; wd.contentGroup.add(row); strumPropTxts.push(row);
			var bm = mkTxt(wd.x+cw-26, cy, "−", 11, C_ACCENT2);
			bm.cameras = [editorCam]; wd.contentGroup.add(bm); strumPropTxts.push(bm);
			var bp = mkTxt(wd.x+cw-10, cy, "+", 11, 0xFF44FF88);
			bp.cameras = [editorCam]; wd.contentGroup.add(bp); strumPropTxts.push(bp);
			var cT = etype; var cS = step; var cGi = gi; var cSi = si; var cSrcId = src.id;
			strumPropBtns.push({ x: wd.x+cw-26, y: cy, w: 14, h: 14, cb: function() addQuickEvent(cGi, cSi, cT, -cS, cSrcId) });
			strumPropBtns.push({ x: wd.x+cw-10, y: cy, w: 14, h: 14, cb: function() addQuickEvent(cGi, cSi, cT,  cS, cSrcId) });
			cy += 16;
		}

		propRow("X",     st != null ? st.offsetX : 0.0, MOVE_X, 10.0);
		propRow("Y",     st != null ? st.offsetY : 0.0, MOVE_Y, 10.0);
		propRow("Angle", st != null ? st.angle   : 0.0, ANGLE,  15.0);
		propRow("Alpha", st != null ? st.alpha   : 1.0, ALPHA,  0.1);
		propRow("Scale", st != null ? st.scaleX  : 1.0, SCALE,  0.1);

		var hint = mkTxt(cx, cy+2, "− / + → evento rápido\nen el beat actual.", 9, C_DIM);
		hint.cameras = [editorCam]; wd.contentGroup.add(hint); strumPropTxts.push(hint);
	}

	function addQuickEvent(gi:Int, si:Int, etype:ModEventType, delta:Float, srcId:String):Void
	{
		pushUndo();
		var ev = ModChartHelpers.makeEvent(Math.round(playheadBeat * 4) / 4, srcId, si, etype, delta, 0, INSTANT);
		manager.addEvent(ev);
		manager.seekToBeat(playheadBeat);
		applyManagerToStrums();
		refreshTimeline();
		refreshStrumPropWindow();
		setStatus('+ ${(etype:String)} ${delta>0?"+":""}${delta} @b${ev.beat}');
	}

	// ═════════════════════════════════════════════════════════════════════════
	// UPDATE
	// ═════════════════════════════════════════════════════════════════════════

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		handleKeyboard();
		handleMouse();

		// Actualizar notas via NoteManager (igual que PlayState)
		if (isPlaying)
		{
			if (FlxG.sound.music != null && FlxG.sound.music.playing)
				songPosition = FlxG.sound.music.time;
			else
				songPosition += elapsed * 1000;

			playheadBeat = songPosition / Conductor.crochet;

			// Auto-scroll timeline
			var margin = beatsVisible * 0.1;
			if (playheadBeat > tlScroll + beatsVisible - margin)
				tlScroll = playheadBeat - beatsVisible + margin;
			else if (playheadBeat < tlScroll)
				tlScroll = Math.max(0, playheadBeat - margin);

			manager.seekToBeat(playheadBeat);
			applyManagerToStrums();
			syncPlayhead();

			if (FlxG.sound.music != null && !FlxG.sound.music.playing && isPlaying)
			{
				isPlaying = false;
				setStatus("♪ Fin de la canción.");
			}
		}

		// NoteManager maneja toda la lógica de notas (spawn, movimiento, animaciones)
		// Conductor.songPosition debe estar sincronizado
		Conductor.songPosition = songPosition;
		if (noteManager != null)
			noteManager.update(songPosition);

		// Actualizar animaciones de strums del editor
		for (edGrp in editorGroups) edGrp.update();

		if (beatInfoLbl != null)
			beatInfoLbl.text = 'Beat: ${Math.round(playheadBeat*100)/100}  Step: ${Std.int(playheadBeat*4)}  BPM: ${Conductor.bpm}  ${Std.int(songPosition)}ms';

		if (lblType   != null) lblType.text   = (newType:String);
		if (lblTarget != null) lblTarget.text  = newTarget;
		if (lblStrum  != null) lblStrum.text   = strumLbl();
		if (lblEase   != null) lblEase.text    = (newEase:String);
		if (fldBeat   != null) fldBeat.text    = (focusField=="beat"     ? "▌" : "") + fieldBufs.get("beat");
		if (fldVal    != null) fldVal.text     = (focusField=="value"    ? "▌" : "") + fieldBufs.get("value");
		if (fldDur    != null) fldDur.text     = (focusField=="duration" ? "▌" : "") + fieldBufs.get("duration");

		refreshEvList();
		updateAudioLabel();
	}

	// ── Teclado ────────────────────────────────────────────────────────────────

	function handleKeyboard():Void
	{
		if (FlxG.keys.justPressed.ESCAPE) { exitEditor(); return; }
		if (FlxG.keys.justPressed.F1) {
			showHelp = !showHelp;
			helpBg.visible = helpTxt.visible = showHelp;
		}
		if (FlxG.keys.justPressed.SPACE)  togglePlay();
		if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.Z) doUndo();
		if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.S) onClickSave();
		if (focusField != "") handleTextInput();
	}

	function togglePlay():Void
	{
		isPlaying = !isPlaying;
		if (isPlaying)
		{
			seekAudioTo(songPosition);
			resumeAudio();
			// Regenerar notas desde la posición actual
			setupNoteManager();
			manager.seekToBeat(playheadBeat);
			setStatus("▶ Reproduciendo...");
		}
		else
		{
			pauseAudio();
			setStatus("⏸ Pausado.");
		}
	}

	function handleTextInput():Void
	{
		if (FlxG.keys.justPressed.BACKSPACE) {
			var b = fieldBufs.get(focusField);
			if (b != null && b.length > 0) fieldBufs.set(focusField, b.substr(0, b.length-1));
		}
		if (FlxG.keys.justPressed.ENTER)  { commitField(focusField); focusField = ""; }
		if (FlxG.keys.justPressed.TAB) {
			commitField(focusField);
			var ord = ["beat","value","duration"];
			focusField = ord[(ord.indexOf(focusField)+1) % ord.length];
		}
		var numKeys = [
			{k:FlxG.keys.justPressed.ZERO,   c:"0"}, {k:FlxG.keys.justPressed.ONE,    c:"1"},
			{k:FlxG.keys.justPressed.TWO,    c:"2"}, {k:FlxG.keys.justPressed.THREE,  c:"3"},
			{k:FlxG.keys.justPressed.FOUR,   c:"4"}, {k:FlxG.keys.justPressed.FIVE,   c:"5"},
			{k:FlxG.keys.justPressed.SIX,    c:"6"}, {k:FlxG.keys.justPressed.SEVEN,  c:"7"},
			{k:FlxG.keys.justPressed.EIGHT,  c:"8"}, {k:FlxG.keys.justPressed.NINE,   c:"9"},
			{k:FlxG.keys.justPressed.PERIOD, c:"."}, {k:FlxG.keys.justPressed.MINUS,  c:"-"}
		];
		for (nk in numKeys) if (nk.k) fieldBufs.set(focusField, (fieldBufs.get(focusField) ?? "") + nk.c);
	}

	function commitField(key:String):Void
	{
		var v = Std.parseFloat(fieldBufs.get(key));
		if (Math.isNaN(v)) v = 0;
		switch (key) {
			case "beat":     newBeat  = Math.max(0, v);
			case "value":    newValue = v;
			case "duration": newDur   = Math.max(0, v);
		}
		fieldBufs.set(key, Std.string(Math.round(v * 100) / 100));
	}

	// ── Mouse ──────────────────────────────────────────────────────────────────

	function handleMouse():Void
	{
		var mx = FlxG.mouse.x;
		var my = FlxG.mouse.y;
		var lp = FlxG.mouse.justPressed;
		var lr = FlxG.mouse.justReleased;
		var rp = FlxG.mouse.justPressedRight;

		if (lr) draggingWin = null;

		if (draggingWin != null)
		{
			var nx = FlxMath.bound(mx - dragOX, 0, SW - draggingWin.w);
			var ny = FlxMath.bound(my - dragOY, 0, tlY - 20);
			moveWin(draggingWin, nx, ny); return;
		}

		if (lp)
		{
			var i = windows.length - 1;
			while (i >= 0)
			{
				var wd = windows[i];
				if (!wd.visible) { i--; continue; }
				if (inR(mx,my, wd.x+wd.w-22, wd.y+4,  18, 18)) { hideWin(wd); return; }
				if (inR(mx,my, wd.x+wd.w-42, wd.y+4,  18, 18)) { wd.minimized = !wd.minimized; applyMinimize(wd); return; }
				if (inR(mx,my, wd.x, wd.y, wd.w-44, 24))       { draggingWin = wd; dragOX = mx-wd.x; dragOY = my-wd.y; bringFront(wd); return; }
				if (!wd.minimized && inR(mx,my, wd.x, wd.y+24, wd.w, wd.h-24))
				{
					for (btn in strumPropBtns) if (inR(mx,my,btn.x,btn.y,btn.w,btn.h)) { btn.cb(); return; }
					for (btn in hitBtns)       if (inR(mx,my,btn.x,btn.y,btn.w,btn.h)) { btn.cb(); return; }
					for (hf  in hitFields)     if (inR(mx,my,hf.x,hf.y,hf.w,hf.h))    { focusField = hf.key; return; }
					return;
				}
				i--;
			}

			if (my < BAR_H)
				for (btn in hitBtns) if (inR(mx,my,btn.x,btn.y,btn.w,btn.h)) { btn.cb(); return; }

			// Click en strum del editor
			if (my >= BAR_H && my < tlY)
			{
				for (gi in 0...editorGroups.length)
				{
					var hit = false;
					for (si in 0...4)
					{
						var s = editorGroups[gi].getStrum(si);
						if (s == null || !s.visible) continue;
						// Usar hitbox real del strum (ya actualizada por updateHitbox)
						// El x,y del sprite ya es el top-left del hitbox tras updateHitbox+centerOffsets
						var sw = s.width  > 0 ? s.width  : 40.0;
						var sh = s.height > 0 ? s.height : 40.0;
						// Añadir margen de tolerancia para facilitar el click
						var margin = 8.0;
						if (inR(mx, my, s.x - margin, s.y - margin, sw + margin*2, sh + margin*2))
						{
							selectStrum(gi, si); hit = true; break;
						}
					}
					if (hit) break;
				}
			}

			// Click en timeline
			if (my >= tlY)
			{
				for (btn in hitBtns) if (inR(mx,my,btn.x,btn.y,btn.w,btn.h)) { btn.cb(); return; }
				var hitEv = false;
				for (es in evSprites) {
					if (inR(mx,my, es.sp.x, es.sp.y, es.sp.width, es.sp.height)) { selectEvent(es.ev); hitEv = true; break; }
				}
				if (!hitEv)
				{
					playheadBeat = Math.max(0, tlScroll + mx / (SW / beatsVisible));
					songPosition = playheadBeat * Conductor.crochet;
					seekAudioTo(songPosition);
					manager.seekToBeat(playheadBeat);
					applyManagerToStrums();
					refreshStrumPropWindow();
					selectedEv = null;
					if (inspTxt != null) inspTxt.text = "(sin selección)";
					syncPlayhead();
					refreshTimeline();
					// Regenerar notas para mostrar las de este beat
					setupNoteManager();
				}
			}
		}

		// RMB en timeline → borrar evento
		if (rp && my >= tlY)
		{
			for (es in evSprites) {
				if (inR(mx,my, es.sp.x, es.sp.y, es.sp.width, es.sp.height)) {
					pushUndo();
					manager.data.events.remove(es.ev);
					if (selectedEv == es.ev) selectedEv = null;
					refreshTimeline();
					setStatus("Evento eliminado."); return;
				}
			}
		}

		// RMB en strum → seleccionar + target
		if (rp && my >= BAR_H && my < tlY)
		{
			for (gi in 0...editorGroups.length)
			{
				for (si in 0...4)
				{
					var s = editorGroups[gi].getStrum(si);
					if (s == null) continue;
					var sw     = s.width  > 0 ? s.width  : 40.0;
					var sh     = s.height > 0 ? s.height : 40.0;
					var margin = 8.0;
					if (inR(mx, my, s.x - margin, s.y - margin, sw + margin*2, sh + margin*2))
					{
						selectStrum(gi, si);
						newTarget = srcStrumsGrps[gi].id;
						newStrumI = si;
						setStatus('Target → ${srcStrumsGrps[gi].id}[$si]'); return;
					}
				}
			}
		}

		var wheel = FlxG.mouse.wheel;
		if (wheel != 0 && my >= tlY)
		{
			if (FlxG.keys.pressed.CONTROL)
				beatsVisible = FlxMath.bound(wheel>0 ? beatsVisible/1.5 : beatsVisible*1.5, BV_MIN, BV_MAX);
			else
				tlScroll = Math.max(0, tlScroll - wheel * beatsVisible * 0.08);
			refreshTimeline();
		}

		if (wheel != 0 && my >= BAR_H && my < tlY && FlxG.keys.pressed.CONTROL)
		{
			volValue = FlxMath.bound(volValue + wheel * 0.05, 0, 1);
			applyVolume();
		}
	}

	function selectStrum(gi:Int, si:Int):Void
	{
		selectedGroupIdx = gi; selectedStrumIdx = si;
		for (gBoxes in selBoxes) for (box in gBoxes) if (box != null) box.visible = false;
		if (gi < selBoxes.length && si < selBoxes[gi].length && selBoxes[gi][si] != null)
			selBoxes[gi][si].visible = true;
		refreshStrumPropWindow();
		setStatus('Strum: ${srcStrumsGrps[gi].id} [${["LEFT","DOWN","UP","RIGHT"][si]}]');
	}

	// ── Lista de eventos ──────────────────────────────────────────────────────

	function refreshEvList():Void
	{
		if (evListWin == null) return;
		for (t in evListTxts) { evListWin.contentGroup.remove(t, true); t.destroy(); }
		evListTxts = [];
		hitBtns = hitBtns.filter(function(b) return b.h != 12.0 || b.w != evListWin.w - 16);

		var cx = evListX; var cy = evListY; var lh = 12;
		var maxH = evListWin.y + evListWin.h - 124 - cy;
		var max  = Std.int(maxH / lh);

		for (i in 0...Std.int(Math.min(max, manager.data.events.length)))
		{
			var ev  = manager.data.events[i];
			var col = (selectedEv == ev) ? FlxColor.fromInt(C_ACCENT2) : FlxColor.fromInt(C_DIM);
			var ts  = (ev.type:String);
			var txt = 'b${Math.round(ev.beat*10)/10} $ts ${ev.target}[${ev.strumIdx==-1?"A":Std.string(ev.strumIdx)}]→${ev.value}';
			var t   = mkTxt(cx, cy, txt, 9, col);
			t.cameras = [editorCam];
			evListWin.contentGroup.add(t); evListTxts.push(t);
			var captEv = ev;
			hitBtns.push({ x: cx, y: cy, w: evListWin.w-16, h: 12.0, cb: function() selectEvent(captEv) });
			cy += lh;
		}
	}

	// ═════════════════════════════════════════════════════════════════════════
	// ACCIONES
	// ═════════════════════════════════════════════════════════════════════════

	function onClickAdd():Void
	{
		commitField("beat"); commitField("value"); commitField("duration");
		pushUndo();
		var ev = ModChartHelpers.makeEvent(newBeat, newTarget, newStrumI, newType, newValue, newDur, newEase);
		manager.addEvent(ev);
		refreshTimeline();
		selectEvent(ev);
		setStatus('+ ${(newType:String)} en beat $newBeat');
		newBeat += newDur > 0 ? newDur : 1;
		fieldBufs.set("beat", Std.string(Math.round(newBeat * 100) / 100));
	}

	function onClickPlay():Void
	{
		if (isPlaying) { togglePlay(); return; }
		isPlaying = true;
		seekAudioTo(songPosition);
		resumeAudio();
		setupNoteManager();
		manager.seekToBeat(playheadBeat);
		setStatus("▶ Reproduciendo...");
	}

	function onClickStop():Void
	{
		isPlaying = false; playheadBeat = 0; songPosition = 0;
		pauseAudio(); seekAudioTo(0);
		manager.seekToBeat(0);
		applyManagerToStrums();
		setupNoteManager();
		refreshTimeline();
		setStatus("■ Detenido. Beat: 0");
	}

	function onClickSave():Void
	{
		#if sys
		try {
			var p = Paths.ensureDir(Paths.resolveWrite('modcharts/${manager.data.song.toLowerCase()}.json'));
			sys.io.File.saveContent(p, manager.toJson());
			setStatus('✓ Guardado: $p');
		} catch (e:Dynamic) { setStatus("Error: " + e); }
		#else
		FlxG.save.data.modchart_last = manager.toJson();
		FlxG.save.flush();
		setStatus("✓ Guardado en save.");
		#end
	}

	function onClickLoad():Void
	{
		#if sys
		var p = Paths.resolve('modcharts/${manager.data.song.toLowerCase()}.json');
		if (sys.FileSystem.exists(p)) {
			try { manager.loadFromJson(sys.io.File.getContent(p)); refreshTimeline(); setStatus('✓ ${manager.data.events.length} eventos'); }
			catch (e:Dynamic) { setStatus("Error: " + e); }
		} else setStatus("No encontrado: " + p);
		#else
		if (FlxG.save.data.modchart_last != null) {
			manager.loadFromJson(FlxG.save.data.modchart_last);
			refreshTimeline();
			setStatus("✓ Cargado desde save.");
		} else setStatus("No hay save.");
		#end
	}

	function onClickNew():Void
	{
		pushUndo(); manager.clearEvents(); refreshTimeline(); setStatus("Modchart limpiado.");
	}

	function selectEvent(ev:ModChartEvent):Void
	{
		selectedEv = ev;
		if (inspTxt != null)
			inspTxt.text =
				'Tipo:   ${(ev.type:String)}\n' +
				'Beat:   ${Math.round(ev.beat*100)/100}\n' +
				'Target: ${ev.target}  Strum: ${ev.strumIdx==-1?"ALL":Std.string(ev.strumIdx)}\n' +
				'Valor:  ${ev.value}\n' +
				'Dur: ${ev.duration}b  Ease: ${(ev.ease:String)}';

		newType=ev.type; newTarget=ev.target; newStrumI=ev.strumIdx;
		newBeat=ev.beat; newValue=ev.value;   newDur=ev.duration; newEase=ev.ease;
		fieldBufs.set("beat",     Std.string(ev.beat));
		fieldBufs.set("value",    Std.string(ev.value));
		fieldBufs.set("duration", Std.string(ev.duration));

		playheadBeat = ev.beat;
		songPosition = playheadBeat * Conductor.crochet;
		seekAudioTo(songPosition);
		manager.seekToBeat(playheadBeat);
		applyManagerToStrums();
		refreshStrumPropWindow();
		refreshTimeline();
		setupNoteManager();
	}

	function doUndo():Void
	{
		if (undoStack.length == 0) { setStatus("Nada que deshacer."); return; }
		manager.loadFromJson(undoStack.pop());
		refreshTimeline(); setStatus("↩ Deshecho.");
	}

	function pushUndo():Void
	{
		undoStack.push(manager.toJson());
		if (undoStack.length > 50) undoStack.shift();
	}

	function setStatus(msg:String):Void { if (statusTxt != null) statusTxt.text = msg; trace('[MCEditor] $msg'); }

	function getMaxBeat():Float
	{
		var m = 16.0;
		for (ev in manager.data.events) if (ev.beat + ev.duration > m) m = ev.beat + ev.duration;
		return m;
	}

	function cycleType(d:Int):Void
	{
		var all = ModChartHelpers.ALL_TYPES;
		var i = all.indexOf(newType);
		newType = all[((i+d) % all.length + all.length) % all.length];
	}

	function cycleEaseDir(d:Int):Void
	{
		var all = ModChartHelpers.ALL_EASES;
		var i = all.indexOf(newEase);
		newEase = all[((i+d) % all.length + all.length) % all.length];
	}

	function cycleTarget(d:Int):Void
	{
		var opts = ["player","cpu","all"];
		for (g in srcStrumsGrps) opts.push(g.id);
		var i = opts.indexOf(newTarget);
		newTarget = opts[((i+d) % opts.length + opts.length) % opts.length];
	}

	function strumLbl():String
		return newStrumI == -1 ? "ALL" : ["LEFT","DOWN","UP","RIGHT"][newStrumI];

	inline function bps():Float
		return Conductor.crochet > 0 ? 1000.0 / Conductor.crochet : 2.0;

	// ═════════════════════════════════════════════════════════════════════════
	// SISTEMA DE VENTANAS
	// ═════════════════════════════════════════════════════════════════════════

	function mkWin(title:String, x:Float, y:Float, w:Float, h:Float):WinData
	{
		var wd:WinData = {
			title:title, x:x, y:y, w:w, h:h, visible:true, minimized:false,
			allSprites:[], bg:null, shadow:null, titleBar:null,
			titleTxt:null, minBtn:null, closeBtn:null, contentGroup: new FlxGroup()
		};

		wd.shadow = mkRaw(x+4, y+4, w, h, 0xAA000000);
		wd.bg     = mkRaw(x, y+24, w, h-24, 0xDD07071A);
		var brd   = mkRaw(x, y+24, 2, h-24, C_ACCENT); brd.alpha = 0.5;

		wd.titleBar = mkRaw(x, y, w, 24, C_WIN_T);
		wd.titleTxt = mkTxt(x+10, y+5, title, 12, C_TEXT);
		(wd.titleTxt:FlxText).fieldWidth = w-52;
		wd.minBtn   = mkTxt(x+w-42, y+4, "─", 12, 0xFFAAAAFF);
		wd.closeBtn = mkTxt(x+w-22, y+4, "✕", 12, 0xFFFF5566);

		for (s in [wd.shadow, wd.bg, brd, wd.titleBar]) wd.allSprites.push(s);
		for (t in [wd.titleTxt, wd.minBtn, wd.closeBtn]) wd.allSprites.push(t);
		return wd;
	}

	function addToWinGroup(wd:WinData):Void
	{
		for (s in wd.allSprites) windowGroup.add(s);
		if (wd.contentGroup != null) windowGroup.add(wd.contentGroup);
	}

	function moveWin(wd:WinData, nx:Float, ny:Float):Void
	{
		var dx = nx-wd.x; var dy = ny-wd.y;
		wd.x = nx; wd.y = ny;
		for (s in wd.allSprites) shiftBasic(s, dx, dy);
		if (wd.contentGroup != null)
			wd.contentGroup.forEach(function(b:flixel.FlxBasic) {
				shiftBasic(b, dx, dy);
				if (Std.isOfType(b, FlxGroup))
					(cast b:FlxGroup).forEach(function(bb:flixel.FlxBasic) shiftBasic(bb, dx, dy));
			});
		if (wd == strumPropWin) refreshStrumPropWindow();
	}

	inline function shiftBasic(b:flixel.FlxBasic, dx:Float, dy:Float):Void
	{
		if (Std.isOfType(b, FlxSprite)) { var s:FlxSprite=cast b; s.x+=dx; s.y+=dy; }
		else if (Std.isOfType(b, FlxText)) { var t:FlxText=cast b; t.x+=dx; t.y+=dy; }
	}

	function bringFront(wd:WinData):Void
	{
		windows.remove(wd); windows.push(wd);
		if (wd.contentGroup != null) { windowGroup.remove(wd.contentGroup); windowGroup.add(wd.contentGroup); }
	}

	function hideWin(wd:WinData):Void
	{
		for (s in wd.allSprites) if (s != null) s.visible = false;
		if (wd.contentGroup != null) wd.contentGroup.visible = false;
		wd.visible = false;
	}

	function applyMinimize(wd:WinData):Void
	{
		var show = !wd.minimized;
		if (wd.bg != null) wd.bg.visible = show;
		for (s in wd.allSprites)
		{
			if (s==wd.shadow||s==wd.titleBar||s==wd.titleTxt||s==wd.minBtn||s==wd.closeBtn) continue;
			s.visible = show;
		}
		if (wd.contentGroup != null) wd.contentGroup.visible = show;
	}

	function wSpr(wd:WinData, s:FlxSprite):FlxSprite
	{
		s.cameras = [editorCam];
		wd.allSprites.push(s);
		if (wd.contentGroup != null) wd.contentGroup.add(s);
		return s;
	}

	function wTxt(wd:WinData, x:Float, y:Float, txt:String, size:Int, col:Int=0xFFDDDDFF):FlxText
	{
		var t = mkTxt(x, y, txt, size, col);
		if (wd.contentGroup != null) wd.contentGroup.add(t);
		return t;
	}

	function wBtn(wd:WinData, x:Float, y:Float, label:String, cb:Void->Void):FlxText
	{
		var t = mkTxt(x, y, label, 11, C_ACCENT);
		if (wd.contentGroup != null) wd.contentGroup.add(t);
		hitBtns.push({ x:x, y:y, w:16.0, h:16.0, cb:cb });
		return t;
	}

	function wField(wd:WinData, x:Float, y:Float, w:Float, key:String):FlxText
	{
		var bg = new FlxSprite(x, y); bg.makeGraphic(Std.int(w), 14, 0xFF050511);
		bg.cameras = [editorCam];
		if (wd.contentGroup != null) wd.contentGroup.add(bg);
		var t = mkTxt(x+2, y+1, fieldBufs.get(key) ?? "0", 10, 0xFFFFDD44);
		if (wd.contentGroup != null) wd.contentGroup.add(t);
		hitFields.push({ x:x, y:y, w:w, h:14.0, key:key });
		return t;
	}

	function addTLBtn(x:Float, y:Float, label:String, cb:Void->Void):FlxText
	{
		var t = mkTxt(x, y, label, 11, C_ACCENT);
		tlGroup.add(t);
		hitBtns.push({ x:x, y:y, w:label.length*7.0+4, h:18.0, cb:cb });
		return t;
	}

	// ═════════════════════════════════════════════════════════════════════════
	// AYUDA
	// ═════════════════════════════════════════════════════════════════════════

	function buildHelp():Void
	{
		helpBg = new FlxSprite(70, 20);
		helpBg.makeGraphic(1140, 660, 0xF3020210);
		helpBg.cameras = [editorCam]; helpBg.visible = false; add(helpBg);

		helpTxt = new FlxText(86, 32, 1100,
			"═══ AYUDA EDITOR MODCHART ═══\n\n" +
			"AUDIO\n" +
			"  SPACE / ▶ Play           → Play/Pausa inst + vocals\n" +
			"  ■ Stop                   → Para y vuelve al beat 0\n" +
			"  CTRL+Rueda (juego)       → Volumen\n\n" +
			"STRUMS (área de juego)\n" +
			"  LMB sobre flecha         → Seleccionar strum\n" +
			"  RMB sobre flecha         → Seleccionar + poner como target\n" +
			"  Ventana 'Strum Props'    → X/Y/Angle/Alpha/Scale + botones − / +\n\n" +
			"LÍNEA DE TIEMPO\n" +
			"  LMB vacío                → Mover playhead\n" +
			"  LMB sobre evento         → Seleccionar (copia datos al form)\n" +
			"  RMB sobre evento         → Eliminar\n" +
			"  Rueda                    → Scroll   CTRL+Rueda → Zoom\n" +
			"  ALL                      → Ver toda la canción\n\n" +
			"FORMULARIO\n" +
			"  + Añadir al Beat         → Crea evento en el beat del campo\n" +
			"  ⊕ Añadir en Playhead     → Crea en el beat actual\n\n" +
			"TIPOS: MOVE_X/Y  SET_ABS_X/Y  ANGLE  SPIN  ALPHA  SCALE  RESET\n\n" +
			"ATAJOS: SPACE play  CTRL+Z deshacer  CTRL+S guardar  ESC cerrar  F1 ayuda\n\n" +
			"[F1 para cerrar]", 12);
		helpTxt.color = FlxColor.fromInt(C_TEXT); helpTxt.cameras = [editorCam]; helpTxt.visible = false; add(helpTxt);
	}

	// ═════════════════════════════════════════════════════════════════════════
	// SALIR AL PLAYSTATE
	// ═════════════════════════════════════════════════════════════════════════

	function exitEditor():Void
	{
		// Guardar automáticamente antes de salir
		onClickSave();

		manager.captureBasePositions();
		manager.resetToStart();

		if (noteManager != null) noteManager.destroy();

		for (edGrp in editorGroups) edGrp.destroy();
		editorGroups = [];

		FlxG.mouse.visible = false;

		trace('[MCEditor] Cerrado. Eventos: ${manager.data.events.length}');

		// Volver a PlayState — carga el modchart desde el archivo que acabamos de guardar
		StateTransition.switchState(new PlayState());
	}

	override function destroy():Void
	{
		manager = null; noteManager = null;
		srcStrumsGrps = null; vocals = null;
		super.destroy();
	}

	// ═════════════════════════════════════════════════════════════════════════
	// UTILIDADES
	// ═════════════════════════════════════════════════════════════════════════

	function mkRaw(x:Float, y:Float, w:Float, h:Float, col:Int):FlxSprite
	{
		var s = new FlxSprite(x, y);
		s.makeGraphic(Std.int(Math.max(1,w)), Std.int(Math.max(1,h)), FlxColor.fromInt(col));
		s.cameras = [editorCam];
		return s;
	}

	function mkBg(x:Float, y:Float, w:Float, h:Float, col:Int):FlxSprite
		return mkRaw(x, y, w, h, col);

	function mkTxt(x:Float, y:Float, txt:String, size:Int, col:Int=0xFFDDDDFF):FlxText
	{
		var t = new FlxText(x, y, 0, txt, size);
		t.color = FlxColor.fromInt(col); t.cameras = [editorCam];
		return t;
	}

	inline function inR(mx:Float,my:Float,rx:Float,ry:Float,rw:Float,rh:Float):Bool
		return mx>=rx && mx<=rx+rw && my>=ry && my<=ry+rh;
}
