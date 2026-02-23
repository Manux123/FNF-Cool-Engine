package funkin.debug.charting;

import funkin.data.Conductor.BPMChangeEvent;
import funkin.data.Section.SwagSection;
import funkin.data.Song.SwagSong;
import funkin.data.Song.CharacterSlotData;
import funkin.data.Song.StrumsGroupData;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.addons.display.FlxGridOverlay;
import flixel.addons.ui.*;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxGroup;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import funkin.data.Conductor;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import flixel.util.FlxStringUtil;
import flixel.util.FlxTimer;
import haxe.Json;
import lime.utils.Assets;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.net.FileReference;
import funkin.menus.MainMenuState;
import openfl.utils.ByteArray;
import funkin.states.LoadingState;
import funkin.gameplay.PlayState;
import funkin.gameplay.notes.Note;
import funkin.gameplay.notes.NoteTypeManager;
import funkin.gameplay.objects.character.CharacterList;
import flixel.util.FlxSpriteUtil;
#if desktop
import data.Discord.DiscordClient;
#end
import funkin.gameplay.objects.character.HealthIcon;

// init
using StringTools;

class ChartingState extends funkin.states.MusicBeatState
{
	// COLORES — actualizados desde EditorTheme en _applyTheme()
	static var BG_DARK:Int         = 0xFF1E1E1E;
	static var BG_PANEL:Int        = 0xFF2D2D2D;
	static var ACCENT_CYAN:Int     = 0xFF00D9FF;
	static var ACCENT_PINK:Int     = 0xFFFF00E5;
	static var ACCENT_GREEN:Int    = 0xFF00FF88;
	static var ACCENT_SUCCESS:Int  = 0xFF00FF88;
	static var ACCENT_WARNING:Int  = 0xFFFFAA00;
	static var ACCENT_ERROR:Int    = 0xFFFF3366;
	static var TEXT_WHITE:Int      = 0xFFFFFFFF;
	static var TEXT_GRAY:Int       = 0xFFAAAAAA;

	/** Sincroniza las vars de color con el tema activo. */
	static function _applyTheme():Void
	{
		var T   = funkin.debug.themes.EditorTheme.current;
		BG_DARK        = T.bgDark;
		BG_PANEL       = T.bgPanel;
		ACCENT_CYAN    = T.accent;
		ACCENT_PINK    = T.accentAlt;
		ACCENT_GREEN   = T.success;
		ACCENT_SUCCESS = T.success;
		ACCENT_WARNING = T.warning;
		ACCENT_ERROR   = T.error;
		TEXT_WHITE     = T.textPrimary;
		TEXT_GRAY      = T.textSecondary;
	}

	// NOTAS COLORES
	static var NOTE_COLORS:Array<Int> = [
		0xFFC24B99, 0xFF00FFFF, 0xFF12FA05, 0xFFF9393F,
		0xFF8B3A7C, 0xFF00A8A8, 0xFF0CAF00, 0xFFBD2831
	];

	// GRID
	var GRID_SIZE:Int = 40;
	var totalGridHeight:Float = 0;
	var gridScrollY:Float = 0;
	var maxScroll:Float = 0;

	var gridBG:FlxSprite;
	var gridBlackWhite:FlxSprite;
	var strumLine:FlxSprite;
	var highlight:FlxSprite;

	// DATOS
	var _file:FileReference;
	var _song:SwagSong;
	var curSection:Int = 0;

	public static var lastSection:Int = 0;

	var curSelectedNote:Array<Dynamic>;
	var tempBpm:Float = 0;
	var vocals:FlxSound;

	// UI PRINCIPAL
	var UI_box:FlxUITabMenu;
	var camGame:FlxCamera;
	var camHUD:FlxCamera;

	// TABS
	var tab_group_song:FlxUI;
	var tab_group_section:FlxUI;
	var tab_group_note:FlxUI;
	// tab_group_characters fue REEMPLAZADO por CharacterIconRow
	var tab_group_settings:FlxUI;

	// UI MODERNA
	var titleBar:FlxSprite;
	var toolbar:FlxSprite;
	var statusBar:FlxSprite;
	var infoPanel:FlxSprite;
	var titleText:FlxText;
	var songNameText:FlxText;
	var timeText:FlxText;
	var bpmText:FlxText;
	var sectionText:FlxText;
	var statusText:FlxText;
	var infoLabels:Array<FlxText> = [];
	var infoValues:Array<FlxText> = [];

	// BOTONES
	var _themeBtnRect:{x:Float, y:Float, w:Int, h:Int} = {x:0, y:0, w:0, h:0};
	var playBtn:FlxSprite;
	var pauseBtn:FlxSprite;
	var stopBtn:FlxSprite;
	var testBtn:FlxSprite;

	// TIPS
	var tips:Array<String>;
	var currentTip:Int = 0;
	var tipTimer:Float = 0;

	// NOTAS
	var curRenderedNotes:FlxTypedGroup<Note>;
	var curRenderedSustains:FlxTypedGroup<FlxSprite>;
	var curRenderedTypeLabels:FlxTypedGroup<FlxText>;
	var noteTypeDropdown:FlxUIDropDownMenu;
	var _noteTypesList:Array<String> = ['normal'];
	var dummyArrow:FlxSprite;

	// INDICADORES DE SECCIÓN
	var sectionIndicators:FlxTypedGroup<FlxSprite>;

	// DROPDOWNS (characters dropdowns moved to CharacterIconRow extension)
	// bfDropDown, dadDropDown, gfDropDown, stageDropDown -> removed
	// STEPPERS
	var stepperLength:FlxUINumericStepper;
	var stepperBPM:FlxUINumericStepper;
	var stepperSpeed:FlxUINumericStepper;
	var stepperSusLength:FlxUINumericStepper;

	// CHECKBOXES
	var check_mustHitSection:FlxUICheckBox;
	var check_changeBPM:FlxUICheckBox;
	var check_altAnim:FlxUICheckBox;

	// ===== NUEVAS EXTENSIONES =====
	public var charIconRow:CharacterIconRow;

	var eventsSidebar:EventsSidebar;
	var previewPanel:PreviewPanel;
	var metaPopup:MetaPopup;

	// Botón META en toolbar (zona clickeable)
	var metaBtn:FlxSprite;
	var metaBtnText:FlxText;

	// BPM y Section clickeables - indicadores en toolbar
	var bpmClickable:Bool = false; // ¿Está en modo edición de BPM?
	var bpmInputActive:FlxUIInputText;
	var sectionInputActive:FlxUIInputText;

	var openSectionNav:Bool = false;

	// HERRAMIENTAS
	var clipboard:Array<Dynamic> = [];
	var currentSnap:Int = 16;
	var hitsoundsEnabled:Bool = false;
	var metronomeEnabled:Bool = false;
	var lastMetronomeBeat:Int = -1;
	var autosaveTimer:Float = 0;

	// UNDO/REDO System
	var undoStack:Array<ChartAction> = [];
	var redoStack:Array<ChartAction> = [];
	var MAX_UNDO_STEPS:Int = 50;

	// ANIMACIÓN DE NOTA SELECCIONADA
	var selectedNotePulse:Float = 0;
	var selectedNotePulseSpeed:Float = 3.0; // Velocidad de pulsación

	override function create()
	{
		funkin.debug.themes.EditorTheme.load();
		_applyTheme();
		FlxG.mouse.visible = true;

		#if desktop
		DiscordClient.changePresence("Chart Editor", null, null, true);
		#end

		curSection = lastSection;

		// Inicializar CharacterList
		CharacterList.init();

		// Cargar canción
		if (PlayState.SONG != null)
			_song = PlayState.SONG;
		else
		{
			_song = {
				song: 'Test',
				notes: [],
				bpm: 120,
				needsVoices: true,
				stage: 'stage_week1',
				player1: 'bf',
				player2: 'dad',
				gfVersion: 'gf',
				speed: 2,
				validScore: false
			};
		}

		// CRÍTICO: Crear sección por defecto si el array está vacío
		if (_song.notes == null || _song.notes.length == 0)
		{
			trace('[ChartingState] Notes array is empty, creating default section');
			_song.notes = [
				{
					lengthInSteps: 16,
					bpm: _song.bpm,
					changeBPM: false,
					mustHitSection: true,
					sectionNotes: [],
					typeOfSection: 0,
					altAnim: false
				}
			];
		}

		// Asegurar que curSection sea válido
		if (curSection < 0)
			curSection = 0;
		if (curSection >= _song.notes.length)
			curSection = _song.notes.length - 1;

		// Setup cameras
		camGame = new FlxCamera();
		camHUD = new FlxCamera();
		camHUD.bgColor.alpha = 0;
		FlxG.cameras.reset(camGame);
		FlxG.cameras.add(camHUD);
		FlxCamera.defaultCameras = [camGame];

		// Setup UI
		setupBackground();
		setupTips();
		setupTitleBar();
		setupToolbar();
		setupGrid();
		setupNotes();
		setupUITabs();
		setupInfoPanel();
		setupStatusBar();
		setupNewExtensions(); // ← NUEVAS EXTENSIONES

		// Cargar audio
		loadSong(_song.song);

		// Estado inicial
		changeSection();
		updateGrid(); // ✨ Cargar todas las notas al inicio

		super.create();
	}

	function setupBackground():Void
	{
		var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, BG_DARK);
		bg.scrollFactor.set();
		bg.cameras = [camGame];
		add(bg);
	}

	function setupTips():Void
	{
		tips = [
			"💡 Press 1-8 to place notes",
			"💡 Ctrl+C/V to copy/paste",
			"💡 N to mirror section",
			"💡 Q/E to change snap",
			"💡 T for hitsounds",
			"💡 M for metronome",
			"💡 PageUp/Down to navigate",
			"💡 Mouse wheel to scroll grid",
			"💡 Shift+Wheel for pixel scroll",
			"💡 Space to play/pause",
			"💡 F5 to test from current section",
			"💡 Ctrl+Enter to test from start",
			"💡 ESC to go back to PlayState"
		];
	}

	function setupTitleBar():Void
	{
		titleBar = new FlxSprite(0, 0);
		titleBar.makeGraphic(FlxG.width, 35, 0xFF121212);
		titleBar.scrollFactor.set();
		titleBar.cameras = [camHUD];
		add(titleBar);

		titleText = new FlxText(10, 8, 0, "⚡ CHART EDITOR", 16);
		titleText.setFormat(Paths.font("vcr.ttf"), 16, ACCENT_CYAN, LEFT, OUTLINE, FlxColor.BLACK);
		titleText.scrollFactor.set();
		titleText.cameras = [camHUD];
		add(titleText);

		songNameText = new FlxText(180, 8, 0, '• ${_song.song}', 16);
		songNameText.setFormat(Paths.font("vcr.ttf"), 16, TEXT_GRAY, LEFT);
		songNameText.scrollFactor.set();
		songNameText.cameras = [camHUD];
		add(songNameText);
	}

	function setupToolbar():Void
	{
		toolbar = new FlxSprite(0, 35);
		toolbar.makeGraphic(FlxG.width, 45, BG_PANEL);
		toolbar.scrollFactor.set();
		toolbar.cameras = [camHUD];
		add(toolbar);

		// Botones de playback
		playBtn = createToolButton(10, 40, "▶");
		pauseBtn = createToolButton(55, 40, "⏸");
		stopBtn = createToolButton(100, 40, "⏹");
		testBtn = createToolButton(145, 40, "🎮");

		add(playBtn);
		add(pauseBtn);
		add(stopBtn);
		add(testBtn);

		// Time (solo display)
		timeText = new FlxText(200, 45, 0, "00:00.000", 12);
		timeText.setFormat(Paths.font("vcr.ttf"), 12, TEXT_GRAY, LEFT);
		timeText.scrollFactor.set();
		timeText.cameras = [camHUD];
		add(timeText);

		// BPM - CLICKEABLE para editar
		var bpmBg = new FlxSprite(320, 10).makeGraphic(70, 18, 0xFF2A2A00);
		bpmBg.scrollFactor.set();
		bpmBg.cameras = [camHUD];
		add(bpmBg);

		bpmText = new FlxText(322, 11, 66, "120 BPM", 11);
		bpmText.setFormat(Paths.font("vcr.ttf"), 11, ACCENT_WARNING, CENTER);
		bpmText.scrollFactor.set();
		bpmText.cameras = [camHUD];
		add(bpmText);

		// Section - CLICKEABLE para navegar
		var secBg = new FlxSprite(400, 10).makeGraphic(90, 18, 0xFF002A1A);
		secBg.scrollFactor.set();
		secBg.cameras = [camHUD];
		add(secBg);

		sectionText = new FlxText(402, 11, 86, "Section 1/1", 11);
		sectionText.setFormat(Paths.font("vcr.ttf"), 11, ACCENT_GREEN, CENTER);
		sectionText.scrollFactor.set();
		sectionText.cameras = [camHUD];
		add(sectionText);

		// Botón META
		metaBtn = new FlxSprite(502, 10).makeGraphic(55, 22, 0xFF1A1A3A);
		metaBtn.scrollFactor.set();
		metaBtn.cameras = [camHUD];
		add(metaBtn);

		metaBtnText = new FlxText(502, 10, 55, "Meta", 12);
		metaBtnText.setFormat(Paths.font("vcr.ttf"), 12, ACCENT_CYAN, CENTER);
		metaBtnText.scrollFactor.set();
		metaBtnText.cameras = [camHUD];
		add(metaBtnText);

		// Borde del botón Meta
		var metaBorder = new FlxSprite(502, 29).makeGraphic(55, 2, ACCENT_CYAN);
		metaBorder.alpha = 0.6;
		metaBorder.scrollFactor.set();
		metaBorder.cameras = [camHUD];
		add(metaBorder);

		// ✨ Botón de tema (abre ThemePickerSubState)
		var themeBtnBg = new FlxSprite(FlxG.width - 38, 40).makeGraphic(32, 32, BG_PANEL);
		themeBtnBg.scrollFactor.set();
		themeBtnBg.cameras = [camHUD];
		add(themeBtnBg);
		_themeBtnRect = {x: FlxG.width - 38.0, y: 40.0, w: 32, h: 32};
		var themeBtnTxt = new FlxText(FlxG.width - 38, 46, 32, "\u2728", 13);
		themeBtnTxt.setFormat(Paths.font("vcr.ttf"), 13, ACCENT_CYAN, CENTER);
		themeBtnTxt.scrollFactor.set();
		themeBtnTxt.cameras = [camHUD];
		add(themeBtnTxt);
	}

	function createToolButton(x:Float, y:Float, icon:String):FlxSprite
	{
		var btn = new FlxSprite(x, y);
		btn.makeGraphic(35, 35, 0xFF3A3A3A);
		btn.scrollFactor.set();
		btn.cameras = [camHUD];

		var txt = new FlxText(x, y, 35, icon, 18);
		txt.setFormat(Paths.font("vcr.ttf"), 18, TEXT_WHITE, CENTER);
		txt.scrollFactor.set();
		txt.cameras = [camHUD];
		add(txt);

		return btn;
	}

	function getGridColumns():Int
	{
		// 4 columnas por cada grupo de strums. Mínimo 8 (2 grupos default)
		if (_song.strumsGroups != null && _song.strumsGroups.length > 0)
			return _song.strumsGroups.length * 4;
		return 8;
	}

	function setupGrid():Void
	{
		// Calcular altura total del grid basado en todas las secciones
		totalGridHeight = 0;

		// VALIDACIÓN CRÍTICA: Asegurar que hay secciones
		if (_song.notes == null || _song.notes.length == 0)
		{
			trace('[GRID ERROR] No hay secciones en _song.notes!');
			_song.notes = [
				{
					lengthInSteps: 16,
					bpm: _song.bpm,
					changeBPM: false,
					mustHitSection: true,
					sectionNotes: [],
					typeOfSection: 0,
					altAnim: false
				}
			];
		}

		for (sec in _song.notes)
		{
			// Validar que lengthInSteps sea válido (mayor que 0)
			var steps = (sec.lengthInSteps > 0) ? sec.lengthInSteps : 16;
			totalGridHeight += steps * GRID_SIZE;
		}

		// VALIDACIÓN: Asegurar altura mínima
		if (totalGridHeight <= 0)
		{
			trace('[GRID ERROR] totalGridHeight es 0 o negativo! Forzando altura mínima.');
			totalGridHeight = 16 * GRID_SIZE; // Al menos 16 steps
		}

		// VALIDACIÓN: Limitar altura máxima para evitar problemas de memoria
		var MAX_GRID_HEIGHT = 16000; // Máximo ~250 secciones
		if (totalGridHeight > MAX_GRID_HEIGHT)
		{
			trace('[GRID WARNING] totalGridHeight muy grande (${totalGridHeight}), limitando a $MAX_GRID_HEIGHT');
			totalGridHeight = MAX_GRID_HEIGHT;
		}

		trace('[GRID] Song: ${_song.song}, totalGridHeight: $totalGridHeight, secciones: ${_song.notes.length}');

		maxScroll = totalGridHeight - (FlxG.height - 100);
		if (maxScroll < 0)
			maxScroll = 0;

		// === COLUMNAS DINÁMICAS basadas en strumsGroups ===
		var numCols = getGridColumns();
		var gridWidth = GRID_SIZE * numCols;

		// Centrar el grid según su ancho real
		var centerX = (FlxG.width / 2) - (gridWidth / 2);
		// Si el grid es muy ancho, colocarlo más a la izquierda
		if (gridWidth > FlxG.width * 0.6)
			centerX = (FlxG.width - gridWidth) / 2;

		gridBG = new FlxSprite();
		gridBG.makeGraphic(gridWidth, Std.int(totalGridHeight), 0xFF000000, true);

		var numRows = Std.int(totalGridHeight / GRID_SIZE) + 1;

		// Dibujar celdas con colores alternados POR GRUPO
		for (row in 0...numRows)
		{
			for (col in 0...numCols)
			{
				var xPos = col * GRID_SIZE;
				var yPos = row * GRID_SIZE;

				var groupIndex = Math.floor(col / 4);
				// Alternar tono de fondo por grupo de strums
				var baseLight = (groupIndex % 2 == 0) ? 0x40 : 0x35;
				var baseDark = (groupIndex % 2 == 0) ? 0x2A : 0x22;

				var isEven = (row + col) % 2 == 0;
				var r = isEven ? baseLight : baseDark;
				var cellColor = (0xFF << 24) | (r << 16) | (r << 8) | r;
				FlxSpriteUtil.drawRect(gridBG, xPos, yPos, GRID_SIZE, GRID_SIZE, cellColor);
			}
		}

		// Líneas horizontales (beats)
		for (row in 0...numRows)
		{
			var yPos = row * GRID_SIZE;
			var lineColor = (row % 4 == 0) ? 0xFF707070 : 0xFF505050;
			FlxSpriteUtil.drawRect(gridBG, 0, yPos, gridWidth, 1, lineColor);
		}

		// Líneas verticales — más gruesas en las divisiones de grupos
		for (col in 0...(numCols + 1))
		{
			var xPos = col * GRID_SIZE;
			var isGroupBorder = (col % 4 == 0);
			var lineColor = isGroupBorder ? 0xFFB0B0B0 : 0xFF707070;
			var lineWidth = isGroupBorder ? 2 : 1;
			FlxSpriteUtil.drawRect(gridBG, xPos, 0, lineWidth, totalGridHeight, lineColor);
		}

		gridBG.x = centerX;
		gridBG.y = 100;
		gridBG.scrollFactor.set();
		gridBG.cameras = [camGame];
		add(gridBG);

		trace('[GRID] Grid creado: ${gridWidth}x${Std.int(totalGridHeight)}, $numCols columnas (${Std.int(numCols / 4)} grupos)');

		// Overlay divisores de sección
		gridBlackWhite = new FlxSprite(gridBG.x, gridBG.y);
		gridBlackWhite.makeGraphic(gridWidth, Std.int(totalGridHeight), 0x00000000, true);

		var currentY:Float = 0;
		for (i in 0..._song.notes.length)
		{
			var steps = (_song.notes[i].lengthInSteps > 0) ? _song.notes[i].lengthInSteps : 16;
			var sectionHeight = steps * GRID_SIZE;

			// Dibujar solo una LÍNEA al inicio de cada sección
			var lineColor = (i % 2 == 0) ? 0x80FFFFFF : 0x4000D9FF;
			var lineHeight = 2;
			FlxSpriteUtil.drawRect(gridBlackWhite, 0, currentY, GRID_SIZE * getGridColumns(), lineHeight, lineColor);

			currentY += sectionHeight;
		}

		gridBlackWhite.scrollFactor.set();
		gridBlackWhite.cameras = [camGame];
		add(gridBlackWhite);

		// Strum line
		strumLine = new FlxSprite(gridBG.x, gridBG.y);
		strumLine.makeGraphic(Std.int(gridBG.width), 4, ACCENT_CYAN);
		strumLine.scrollFactor.set();
		strumLine.cameras = [camGame];
		add(strumLine);

		// Highlight
		highlight = new FlxSprite(gridBG.x, gridBG.y);
		highlight.makeGraphic(GRID_SIZE, GRID_SIZE, 0x40FFFFFF);
		highlight.scrollFactor.set();
		highlight.cameras = [camGame];
		highlight.visible = false;
		add(highlight);

		// Etiquetas de grupos de strums encima de cada grupo de 4 columnas
		drawStrumsGroupLabels();

		// Sección indicators
		sectionIndicators = new FlxTypedGroup<FlxSprite>();
		add(sectionIndicators);
		updateSectionIndicators();

		// Dummy arrow
		dummyArrow = new FlxSprite().makeGraphic(GRID_SIZE, GRID_SIZE);
		add(dummyArrow);
	}

	// Etiquetas de nombre del grupo encima de cada bloque de 4 columnas
	var strumsGroupLabels:FlxTypedGroup<FlxText>;

	function drawStrumsGroupLabels():Void
	{
		if (strumsGroupLabels != null)
		{
			for (lbl in strumsGroupLabels.members)
				remove(lbl, true);
			strumsGroupLabels.clear();
		}
		else
			strumsGroupLabels = new FlxTypedGroup<FlxText>();

		var orderedGroups = getOrderedStrumsGroups();
		var numGroups = orderedGroups.length;
		var groupColors:Array<Int> = [0xFFFF8888, 0xFF88FFFF, 0xFF88FF88, 0xFFFFFF88, 0xFFFF88FF, 0xFF88AAFF];

		for (g in 0...numGroups)
		{
			var gd = orderedGroups[g];
			var groupX = gridBG.x + (g * 4 * GRID_SIZE);
			var groupW = 4 * GRID_SIZE;
			var isInvis = !gd.visible;

			var labelBg = new FlxSprite(groupX, gridBG.y - 18).makeGraphic(groupW, 18, isInvis ? 0xAA2A1500 : 0xAA000000);
			labelBg.scrollFactor.set();
			labelBg.cameras = [camHUD];
			add(labelBg);

			var cpuTag = gd.cpu ? " [CPU]" : " [P]";
			var visTag = isInvis ? " 👁" : "";
			var groupName = gd.id + cpuTag + visTag;

			var labelColor = isInvis ? 0xFFFFAA00 : groupColors[g % groupColors.length];

			var lbl = new FlxText(groupX + 2, gridBG.y - 16, groupW - 4, groupName, 9);
			lbl.setFormat(Paths.font("vcr.ttf"), 9, labelColor, CENTER);
			lbl.scrollFactor.set();
			lbl.cameras = [camHUD];
			strumsGroupLabels.add(lbl);
			add(lbl);
		}
	}

	/**
	 * Reconstruye todo el grid desde cero.
	 * Llamar cuando se agregan/eliminan grupos de strums.
	 */
	public function rebuildGrid():Void
	{
		// Limpiar sprites del grid anteriores
		if (gridBG != null)
		{
			remove(gridBG, true);
			gridBG.destroy();
		}
		if (gridBlackWhite != null)
		{
			remove(gridBlackWhite, true);
			gridBlackWhite.destroy();
		}
		if (strumLine != null)
		{
			remove(strumLine, true);
			strumLine.destroy();
		}
		if (highlight != null)
		{
			remove(highlight, true);
			highlight.destroy();
		}
		if (sectionIndicators != null)
			sectionIndicators.clear();

		// ← NUEVO: sacar los grupos de notas de la lista para re-insertarlos encima del grid
		if (curRenderedSustains != null)
			remove(curRenderedSustains);
		if (curRenderedNotes != null)
			remove(curRenderedNotes);

		// Recrear grid (añade los sprites del fondo)
		setupGrid();

		// ← NUEVO: volver a añadir notas y sustains ENCIMA del grid
		if (curRenderedSustains != null)
			add(curRenderedSustains);
		if (curRenderedNotes != null)
			add(curRenderedNotes);

		// Actualizar notas y extensiones
		updateGrid();

		if (eventsSidebar != null)
			eventsSidebar.setScrollY(gridScrollY, gridBG.y);

		if (charIconRow != null)
			charIconRow.refreshIcons();

		showMessage('🔧 Grid updated: ${getGridColumns() / 4} groups of strums', ACCENT_CYAN);
		trace('[ChartingState] Grid rebuilt with ${getGridColumns()} columns');
	}

	function setupNotes():Void
	{
		curRenderedNotes = new FlxTypedGroup<Note>();
		curRenderedSustains = new FlxTypedGroup<FlxSprite>();

		add(curRenderedSustains);
		add(curRenderedNotes);
	}

	function setupUITabs():Void
	{
		UI_box = new FlxUITabMenu(null, [
			{name: "Song", label: 'Song'},
			{name: "Section", label: 'Section'},
			{name: "Note", label: 'Note'},
			{name: "Settings", label: 'Settings'}
		], true);

		UI_box.resize(300, 400);
		UI_box.x = FlxG.width - 320;
		UI_box.y = 20;
		UI_box.scrollFactor.set();
		UI_box.cameras = [camHUD];

		addSongUI();
		addSectionUI();
		// Build noteTypes list for dropdown
		_noteTypesList = ['normal'];
		for (t in NoteTypeManager.getTypes()) _noteTypesList.push(t);

		addNoteUI();
		curRenderedTypeLabels = new FlxTypedGroup<FlxText>();
		add(curRenderedTypeLabels);
		addSettingsUI();
		// ↑ El tab de Characters fue reemplazado por la fila de iconos encima del grid

		add(UI_box);
	}

	function addSongUI():Void
	{
		tab_group_song = new FlxUI(null, UI_box);
		tab_group_song.name = 'Song';

		// Song name
		var songLabel = new FlxText(10, 10, 0, 'Song:', 10);
		tab_group_song.add(songLabel);

		var songText = new FlxText(10, 25, 0, _song.song, 12);
		songText.color = ACCENT_CYAN;
		tab_group_song.add(songText);

		// BPM
		var bpmLabel = new FlxText(10, 50, 0, 'BPM:', 10);
		tab_group_song.add(bpmLabel);

		stepperBPM = new FlxUINumericStepper(10, 65, 1, _song.bpm, 1, 999, 0);
		stepperBPM.value = _song.bpm;
		stepperBPM.name = 'song_bpm';
		tab_group_song.add(stepperBPM);

		// Speed
		var speedLabel = new FlxText(10, 100, 0, 'Speed:', 10);
		tab_group_song.add(speedLabel);

		stepperSpeed = new FlxUINumericStepper(10, 115, 0.1, _song.speed, 0.1, 10, 1);
		stepperSpeed.value = _song.speed;
		stepperSpeed.name = 'song_speed';
		tab_group_song.add(stepperSpeed);

		// Player 1 & 2 info
		var p1Label = new FlxText(10, 150, 0, 'Player 1: ${_song.player1}', 10);
		tab_group_song.add(p1Label);

		var p2Label = new FlxText(10, 165, 0, 'Player 2: ${_song.player2}', 10);
		tab_group_song.add(p2Label);

		// Buttons
		var reloadBtn = new FlxButton(10, 200, "Reload Audio", function()
		{
			loadSong(_song.song);
		});
		tab_group_song.add(reloadBtn);

		var clearAllBtn = new FlxButton(10, 230, "Clear All Notes", function()
		{
			for (sec in _song.notes)
				sec.sectionNotes = [];
			updateGrid();
		});
		tab_group_song.add(clearAllBtn);

		UI_box.addGroup(tab_group_song);
	}

	function addSectionUI():Void
	{
		tab_group_section = new FlxUI(null, UI_box);
		tab_group_section.name = 'Section';

		// Section info
		var secLabel = new FlxText(10, 10, 0, 'Section: ${curSection + 1}/${_song.notes.length}', 12);
		tab_group_section.add(secLabel);

		// Checkboxes
		check_mustHitSection = new FlxUICheckBox(10, 40, null, null, "Must Hit Section", 100);
		check_mustHitSection.checked = false;
		tab_group_section.add(check_mustHitSection);

		check_changeBPM = new FlxUICheckBox(10, 70, null, null, "Change BPM", 100);
		check_changeBPM.checked = false;
		tab_group_section.add(check_changeBPM);

		check_altAnim = new FlxUICheckBox(10, 100, null, null, "Alt Animation", 100);
		check_altAnim.checked = false;
		tab_group_section.add(check_altAnim);

		// Section length
		var lengthLabel = new FlxText(10, 135, 0, 'Section Length (steps):', 10);
		tab_group_section.add(lengthLabel);

		stepperLength = new FlxUINumericStepper(10, 150, 4, 0, 0, 999, 0);
		stepperLength.value = 16;
		stepperLength.name = 'section_length';
		tab_group_section.add(stepperLength);

		// Buttons
		var copyBtn = new FlxButton(10, 190, "Copy Section", copySection);
		tab_group_section.add(copyBtn);

		var clearBtn = new FlxButton(10, 220, "Clear Section", function()
		{
			_song.notes[curSection].sectionNotes = [];
			updateGrid();
		});
		tab_group_section.add(clearBtn);

		UI_box.addGroup(tab_group_section);
	}

	function addNoteUI():Void
	{
		tab_group_note = new FlxUI(null, UI_box);
		tab_group_note.name = 'Note';

		// Sustain length
		var susLabel = new FlxText(10, 10, 0, 'Sustain Length:', 10);
		tab_group_note.add(susLabel);

		stepperSusLength = new FlxUINumericStepper(10, 25, Conductor.stepCrochet / 2, 0, 0, Conductor.stepCrochet * 16);
		stepperSusLength.value = 0;
		stepperSusLength.name = 'note_susLength';
		tab_group_note.add(stepperSusLength);

		// Note Type dropdown
		var typeLabel = new FlxText(10, 55, 0, 'Note Type:', 10);
		tab_group_note.add(typeLabel);

		var ddItems:Array<String> = [];
		for (i in 0..._noteTypesList.length)
			ddItems.push('$i: ${_noteTypesList[i]}');

		noteTypeDropdown = new FlxUIDropDownMenu(10, 68, FlxUIDropDownMenu.makeStrIdLabelArray(ddItems, true), function(chosen:String)
		{
			if (curSelectedNote == null) return;
			var colonIdx = chosen.indexOf(':');
			var idx = colonIdx > 0 ? Std.parseInt(chosen.substr(0, colonIdx).trim()) : 0;
			if (idx == null || idx < 0 || idx >= _noteTypesList.length) idx = 0;
			var typeName:String = _noteTypesList[idx];
			curSelectedNote[3] = (typeName == 'normal' || typeName == '') ? null : typeName;
			updateGrid();
		});
		noteTypeDropdown.selectedLabel = '0: normal';

		// Snap
		var snapLabel = new FlxText(10, 135, 0, 'Note Snap:', 10);
		tab_group_note.add(snapLabel);

		var snapText = new FlxText(10, 150, 0, 'Current: 1/4 (Q/E to change)', 10);
		snapText.color = ACCENT_CYAN;
		tab_group_note.add(snapText);

		tab_group_note.add(noteTypeDropdown);

		UI_box.addGroup(tab_group_note);
	}

	// addCharactersUI() fue REEMPLAZADO por CharacterIconRow
	// Los personajes ahora se gestionan desde la fila de iconos encima del grid

	function addSettingsUI():Void
	{
		tab_group_settings = new FlxUI(null, UI_box);
		tab_group_settings.name = 'Settings';

		// Hitsounds
		var hitsoundCheck = new FlxUICheckBox(10, 10, null, null, "Hitsounds (T)", 100);
		hitsoundCheck.checked = hitsoundsEnabled;
		hitsoundCheck.callback = function()
		{
			hitsoundsEnabled = !hitsoundsEnabled;
		};
		tab_group_settings.add(hitsoundCheck);

		// Metronome
		var metronomeCheck = new FlxUICheckBox(10, 40, null, null, "Metronome (M)", 100);
		metronomeCheck.checked = metronomeEnabled;
		metronomeCheck.callback = function()
		{
			metronomeEnabled = !metronomeEnabled;
		};
		tab_group_settings.add(metronomeCheck);

		// Save/Load
		var saveBtn = new FlxButton(10, 80, "Save Chart", saveChart);
		tab_group_settings.add(saveBtn);

		var loadBtn = new FlxButton(10, 110, "Load Chart", loadChart);
		tab_group_settings.add(loadBtn);

		UI_box.addGroup(tab_group_settings);
	}

	function setupInfoPanel():Void
	{
		// Background del panel
		infoPanel = new FlxSprite(FlxG.width - 220, FlxG.height - 240);
		infoPanel.makeGraphic(200, 200, BG_PANEL);
		infoPanel.alpha = 0.95;
		infoPanel.scrollFactor.set();
		infoPanel.cameras = [camHUD];
		add(infoPanel);

		// Title del panel
		var panelTitle = new FlxText(infoPanel.x + 10, infoPanel.y + 10, 180, "📊 INFO", 14);
		panelTitle.setFormat(Paths.font("vcr.ttf"), 14, ACCENT_CYAN, LEFT, OUTLINE, FlxColor.BLACK);
		panelTitle.borderSize = 1;
		panelTitle.scrollFactor.set();
		panelTitle.cameras = [camHUD];
		add(panelTitle);

		// Labels y valores
		var labels = ["TIME", "BPM", "SECTION", "STEP", "BEAT", "NOTES", "SNAP"];

		for (i in 0...labels.length)
		{
			// Label
			var label = new FlxText(infoPanel.x + 15, infoPanel.y + 40 + (i * 22), 0, labels[i], 10);
			label.setFormat(Paths.font("vcr.ttf"), 10, TEXT_GRAY, LEFT);
			label.scrollFactor.set();
			label.cameras = [camHUD];
			infoLabels.push(label);
			add(label);

			// Value
			var value = new FlxText(infoPanel.x + 100, infoPanel.y + 40 + (i * 22), 90, "---", 12);
			value.setFormat(Paths.font("vcr.ttf"), 12, TEXT_WHITE, RIGHT);
			value.scrollFactor.set();
			value.cameras = [camHUD];
			infoValues.push(value);
			add(value);
		}
	}

	function setupStatusBar():Void
	{
		statusBar = new FlxSprite(0, FlxG.height - 25);
		statusBar.makeGraphic(FlxG.width, 25, BG_PANEL);
		statusBar.scrollFactor.set();
		statusBar.cameras = [camHUD];
		add(statusBar);

		statusText = new FlxText(10, FlxG.height - 20, FlxG.width - 20, tips[0], 12);
		statusText.setFormat(Paths.font("vcr.ttf"), 12, TEXT_GRAY, LEFT);
		statusText.scrollFactor.set();
		statusText.cameras = [camHUD];
		add(statusText);
	}

	function setupNewExtensions():Void
	{
		// 1. Meta popup (Stage y Speed)
		metaPopup = new MetaPopup(this, _song, camHUD);
		add(metaPopup);

		// 2. Preview panel (izquierdo, colapsable) — con Character.hx real
		previewPanel = new PreviewPanel(this, _song, camGame, camHUD);
		add(previewPanel);

		// 3. Events sidebar (izquierdo, encima del grid)
		eventsSidebar = new EventsSidebar(this, _song, camGame, camHUD, gridBG.x, gridBG.y);
		add(eventsSidebar);

		// 4. Character icon row (encima del grid)
		charIconRow = new CharacterIconRow(this, _song, camHUD, gridBG.x);
		add(charIconRow);

		// Asegurar que los eventos estén inicializados en la canción
		if (_song.events == null)
			_song.events = [];
	}

	function updateInfoPanel():Void
	{
		// Time
		var time = FlxG.sound.music != null ? FlxG.sound.music.time / 1000 : 0;
		infoValues[0].text = formatTime(time);

		// BPM
		infoValues[1].text = '${Conductor.bpm}';

		// Section
		infoValues[2].text = '${curSection + 1}/${_song.notes.length}';

		// Step
		var curStep = Math.floor(Conductor.songPosition / Conductor.stepCrochet);
		infoValues[3].text = '$curStep';

		// Beat
		var curBeat = Math.floor(curStep / 4);
		infoValues[4].text = '$curBeat';

		// Notes in section
		var notesInSec = _song.notes[curSection].sectionNotes.length;
		infoValues[5].text = '$notesInSec';

		// Snap
		var snapDisplay = getSnapName(currentSnap);
		infoValues[6].text = snapDisplay;
	}

	function updateToolbar():Void
	{
		// Time
		var time = FlxG.sound.music != null ? FlxG.sound.music.time / 1000 : 0;
		var minutes = Math.floor(time / 60);
		var seconds = Math.floor(time % 60);
		var ms = Math.floor((time % 1) * 1000);
		timeText.text = '${StringTools.lpad('$minutes', "0", 2)}:${StringTools.lpad('$seconds', "0", 2)}.${StringTools.lpad('$ms', "0", 3)}';

		// BPM - mostrar valor editable
		bpmText.text = '${Conductor.bpm} BPM';

		// Section
		sectionText.text = 'Section ${curSection + 1}/${_song.notes.length}';

		// Resaltar botón Meta si el popup está abierto
		if (metaBtn != null && metaPopup != null)
			metaBtn.color = metaPopup.isOpen ? 0xFF2A2A6A : 0xFF1A1A3A;
	}

	function updateStatusBar(elapsed:Float):Void
	{
		// Rotar tips cada 5 segundos
		tipTimer += elapsed;
		if (tipTimer >= 5.0)
		{
			tipTimer = 0;
			currentTip = (currentTip + 1) % tips.length;

			FlxTween.tween(statusText, {alpha: 0}, 0.2, {
				onComplete: function(twn:FlxTween)
				{
					statusText.text = tips[currentTip];
					FlxTween.tween(statusText, {alpha: 1}, 0.2);
				}
			});
		}
	}

	public function showMessage(msg:String, ?color:FlxColor):Void
	{
		tipTimer = 0;

		// ── Animación: flash rápido y slide-up desde abajo ────────────────
		FlxTween.cancelTweensOf(statusText);
		statusText.text  = msg;
		statusText.color = (color != null) ? color : cast TEXT_GRAY;
		statusText.alpha = 0;

		// Posición base
		final baseY:Float = FlxG.height - 20;
		statusText.y = baseY + 10;

		// Slide up + fade in rápido
		FlxTween.tween(statusText, {alpha: 1, y: baseY}, 0.18, {ease: FlxEase.backOut});

		// Mantener visible 2.5s, luego fade out
		FlxTween.tween(statusText, {alpha: 0}, 0.30, {
			ease: FlxEase.quadIn,
			startDelay: 2.5,
			onComplete: function(_)
			{
				statusText.color = cast TEXT_GRAY;
			}
		});
	}

	function loadSong(daSong:String):Void
	{
		if (FlxG.sound.music != null)
		{
			FlxG.sound.music.stop();
			FlxG.sound.music = null;
		}

		try
		{
			FlxG.sound.music = Paths.loadInst(daSong);
			FlxG.sound.music.pause();
			FlxG.sound.music.onComplete = function()
			{
				FlxG.sound.music.pause();
				FlxG.sound.music.time = 0;
			};
		}
		catch (e:Dynamic)
		{
			trace('Error loading song: $e');
			showMessage("❌ Error loading song!", ACCENT_ERROR);
		}

		// Vocals
		if (_song.needsVoices)
		{
			try
			{
				vocals = Paths.loadVoices(daSong);
				vocals.volume = 0.6; // Mismo volumen que la música
				vocals.looped = false;
				vocals.pause();
				FlxG.sound.list.add(vocals);
			}
			catch (e:Dynamic)
			{
				trace('Error loading vocals: $e');
			}
		}
		else
		{
			// Asegurar que no haya vocals si no son necesarias
			if (vocals != null)
			{
				vocals.stop();
				vocals.destroy();
				vocals = null;
			}
		}

		Conductor.changeBPM(_song.bpm);
		Conductor.mapBPMChanges(_song);
	}

	// ✨ FUNCIÓN NUEVA: Sincronizar vocales con la música
	function syncVocals():Void
	{
		if (vocals != null && FlxG.sound.music != null)
		{
			// Solo ajustar tiempo si la diferencia es significativa (>50ms)
			var timeDiff = Math.abs(vocals.time - FlxG.sound.music.time);
			if (timeDiff > 50)
			{
				vocals.time = FlxG.sound.music.time;
			}

			// Sincronizar volumen
			vocals.volume = FlxG.sound.music.volume;

			// Controlar reproducción
			if (FlxG.sound.music.playing)
			{
				if (!vocals.playing)
					vocals.play();
			}
			else
			{
				if (vocals.playing)
					vocals.pause();
			}
		}
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		updateToolbar();
		updateInfoPanel();
		updateStatusBar(elapsed);

		// ✨ SINCRONIZAR VOCALES - llamar en cada frame
		syncVocals();

		// ✨ Actualizar animación pulsante de nota seleccionada
		selectedNotePulse += elapsed * selectedNotePulseSpeed;

		// Ejemplo de cómo debería calcularse el tiempo según la sección

		Conductor.songPosition = FlxG.sound.music != null ? FlxG.sound.music.time : 0;

		// ✅ SOLO ESTAS DOS LÍNEAS NUEVAS:
		updateGridScroll();
		updateCurrentSection();
		updateNotePositions(); // ✨ Actualizar posiciones cuando el grid se mueve
		// updateSectionIndicators(); // ✨ Actualizar indicadores de sección
		cullNotes();

		// Preview character: detectar notas que pasa el playhead
		if (previewPanel != null && FlxG.sound.music != null && FlxG.sound.music.playing)
			checkNotesForPreview();

		handleMouseInput();
		handleKeyboardInput();
		handlePlaybackButtons();

		// Metronome
		if (metronomeEnabled && FlxG.sound.music != null && FlxG.sound.music.playing)
		{
			var curBeat = Math.floor(Conductor.songPosition / Conductor.crochet);
			if (curBeat != lastMetronomeBeat)
			{
				FlxG.sound.play(Paths.soundRandom('menus/chartingSounds/metronome', 1, 2), 0.5);
				lastMetronomeBeat = curBeat;
			}
		}

		// Autosave
		autosaveTimer += elapsed;
		if (autosaveTimer >= 300.0)
		{
			autosaveTimer = 0;
			autosaveChart();
		}

		if (UI_box != null)
			UI_box.selected_tab_id = UI_box.selected_tab_id;
	}

	function updateCurrentSection():Void
	{
		// Determinar en qué sección estamos basado en la posición de la música
		if (FlxG.sound.music == null)
			return;

		var currentTime = FlxG.sound.music.time;
		var accumulatedTime:Float = 0;

		for (i in 0..._song.notes.length)
		{
			var sectionTime = getSectionDuration(i);

			if (currentTime >= accumulatedTime && currentTime < accumulatedTime + sectionTime)
			{
				if (curSection != i)
				{
					curSection = i;
					updateSectionUI();
					updateSectionIndicators();
				}
				break;
			}

			accumulatedTime += sectionTime;
		}
	}

	function getSectionDuration(sectionNum:Int):Float
	{
		var section = _song.notes[sectionNum];
		var bpm = section.changeBPM ? section.bpm : _song.bpm;
		var beats = section.lengthInSteps / 4;
		return (beats * 60 / bpm) * 1000;
	}

	/**
	 * Detecta qué notas están siendo "tocadas" por el playhead en este momento
	 * y dispara onNotePass en el PreviewPanel.
	 * Se llama cada frame mientras la música esté reproduciendo.
	 */
	function checkNotesForPreview():Void
	{
		if (previewPanel == null)
			return;

		var currentTime = FlxG.sound.music.time;
		var tolerance = Conductor.stepCrochet * 0.6;

		// Reset del mapa cuando la música salta/reinicia
		if (Math.abs(currentTime - _lastMusicTime) > 500)
			_firedNotes = new Map();
		_lastMusicTime = currentTime;

		for (secNum in 0..._song.notes.length)
		{
			var section = _song.notes[secNum];
			for (noteData in section.sectionNotes)
			{
				var noteTime:Float = noteData[0];
				var rawData:Int = Std.int(noteData[1]);

				if (Math.abs(noteTime - currentTime) > tolerance)
					continue;

				// Clave única por nota para no dispararla dos veces
				var key = '${Std.int(noteTime)}_${rawData}';
				if (_firedNotes.exists(key))
					continue;
				_firedNotes.set(key, true);

				var groupIndex = Math.floor(rawData / 4);
				var direction = rawData % 4;

				previewPanel.onNotePass(direction, groupIndex);
			}
		}
	}

	// Timestamp de la última nota enviada al preview (evitar spam)
	var _firedNotes:Map<String, Bool> = new Map();
	var _lastMusicTime:Float = -999;

	function updateSectionIndicators():Void
	{
		// Limpiar indicadores previos
		sectionIndicators.clear();

		var currentY:Float = 0;
		for (i in 0..._song.notes.length)
		{
			var sectionHeight = _song.notes[i].lengthInSteps * GRID_SIZE;

			// Línea divisora
			var divider = new FlxSprite(gridBG.x, gridBG.y + currentY);
			divider.makeGraphic(Std.int(gridBG.width), 2, (i == curSection ? ACCENT_CYAN : 0x80FFFFFF));
			divider.scrollFactor.set();
			divider.cameras = [camGame];
			sectionIndicators.add(divider);

			// Número de sección
			var numText = new FlxText(gridBG.x - 30, gridBG.y + currentY + 5, 0, '${i + 1}', 12);
			numText.setFormat(Paths.font("vcr.ttf"), 12, (i == curSection ? ACCENT_CYAN : TEXT_GRAY), LEFT);
			numText.scrollFactor.set();
			numText.cameras = [camGame];
			numText.antialiasing = FlxG.save.data.antialiasing;
			sectionIndicators.add(cast numText);

			currentY += sectionHeight;
		}
	}

	function updateGridScroll():Void
	{
		// ✨ AUTO-SCROLL cuando la música está tocando
		if (FlxG.sound.music != null && FlxG.sound.music.playing)
		{
			// Calcular posición del grid basada en la posición de la música
			var accumulatedSteps:Float = 0;
			var targetScrollY:Float = 0;

			for (i in 0..._song.notes.length)
			{
				var sectionStartTime = getSectionStartTime(i);
				var sectionEndTime = sectionStartTime + getSectionDuration(i);

				if (Conductor.songPosition >= sectionStartTime && Conductor.songPosition < sectionEndTime)
				{
					// Estamos en esta sección
					var progressInSection = (Conductor.songPosition - sectionStartTime) / getSectionDuration(i);
					var sectionHeight = _song.notes[i].lengthInSteps * GRID_SIZE;
					targetScrollY = accumulatedSteps + (progressInSection * sectionHeight);
					break;
				}

				accumulatedSteps += _song.notes[i].lengthInSteps * GRID_SIZE;
			}

			// Suavizar el movimiento de la cámara
			gridScrollY = FlxMath.lerp(gridScrollY, targetScrollY, 0.15);
			gridScrollY = clamp(gridScrollY, 0, maxScroll);

			gridBG.y = 100 - gridScrollY;
			gridBlackWhite.y = gridBG.y;
			strumLine.y = gridBG.y;

			// Actualizar sidebar de eventos con nuevo scroll
			if (eventsSidebar != null)
				eventsSidebar.setScrollY(gridScrollY, gridBG.y);
		}

		// Scroll con rueda del mouse
		if (FlxG.mouse.wheel != 0)
		{
			updateSectionIndicators();
			var scrollAmount = FlxG.mouse.wheel * (FlxG.keys.pressed.SHIFT ? GRID_SIZE : GRID_SIZE * 4);
			gridScrollY -= scrollAmount;
			gridScrollY = clamp(gridScrollY, 0, maxScroll);

			gridBG.y = 100 - gridScrollY;
			gridBlackWhite.y = gridBG.y;
			strumLine.y = gridBG.y;

			// Actualizar sidebar de eventos con nuevo scroll
			if (eventsSidebar != null)
				eventsSidebar.setScrollY(gridScrollY, gridBG.y);

			// ✨ SINCRONIZAR VOCALES cuando haces scroll con la rueda del mouse
			syncVocals();
		}
	}

	function handleMouseInput():Void
	{
		if (isAnyPopupOpen())
			return;
		// Click en grid
		if (FlxG.mouse.justPressed && FlxG.mouse.overlaps(gridBG, camGame))
		{
			var mouseGridX = FlxG.mouse.x - gridBG.x;
			var mouseGridY = FlxG.mouse.y - gridBG.y; // ✨ NO sumar gridScrollY

			var noteData = Math.floor(mouseGridX / GRID_SIZE);

			// ✨ Primero intentar seleccionar una nota existente
			var noteSelected = selectNoteAtPosition(mouseGridY, noteData);

			// Si no hay nota, crear una nueva
			// overlaps(gridBG) ya garantiza que noteData es válido — sin límite superior hardcodeado
			if (!noteSelected && noteData >= 0)
			{
				addNoteAtWorldPosition(mouseGridY, noteData);
			}
		}

		// Highlight
		if (FlxG.mouse.overlaps(gridBG, camGame))
		{
			var mouseGridX = FlxG.mouse.x - gridBG.x;
			var mouseGridY = FlxG.mouse.y - gridBG.y;

			var gridX = Math.floor(mouseGridX / GRID_SIZE) * GRID_SIZE;
			var stepHeight = GRID_SIZE / (currentSnap / 16);
			var gridY = Math.floor(mouseGridY / stepHeight) * stepHeight;

			highlight.x = gridBG.x + gridX;
			highlight.y = gridBG.y + gridY;
			highlight.visible = true;
		}
		else
		{
			highlight.visible = false;
		}

		// Right click - delete
		if (FlxG.mouse.justPressedRight && FlxG.mouse.overlaps(gridBG, camGame))
		{
			var mouseGridX = FlxG.mouse.x - gridBG.x;
			var mouseGridY = FlxG.mouse.y - gridBG.y;

			var noteData = Math.floor(mouseGridX / GRID_SIZE);

			// overlaps(gridBG) ya garantiza que noteData es válido
			if (noteData >= 0)
			{
				deleteNoteAtPosition(mouseGridY, noteData);
			}
		}
	}

	function isAnyPopupOpen():Bool
	{
		if (openSectionNav)
			return true;

		if (metaPopup != null && metaPopup.isOpen)
			return true;

		if (charIconRow != null && charIconRow.isAnyModalOpen())
			return true;

		if (eventsSidebar != null && eventsSidebar.isAnyPopupOpen())
			return true;

		return false;
	}

	function addNoteAtWorldPosition(worldY:Float, noteData:Int):Void
	{
		// Convertir worldY a step global
		var clickedStep = worldY / GRID_SIZE;

		// Snap
		var snapSteps = (currentSnap / 16);
		clickedStep = Math.floor(clickedStep / snapSteps) * snapSteps;

		// Encontrar en qué sección está
		var accumulatedSteps:Float = 0;
		var targetSection:Int = 0;
		var noteTimeInSection:Float = 0;

		for (i in 0..._song.notes.length)
		{
			var sectionSteps = _song.notes[i].lengthInSteps;

			if (clickedStep < accumulatedSteps + sectionSteps)
			{
				targetSection = i;
				noteTimeInSection = (clickedStep - accumulatedSteps) * Conductor.stepCrochet;
				break;
			}

			accumulatedSteps += sectionSteps;
		}

		// CRITICAL FIX: Deshacer el mapeo visual antes de guardar
		// Solo los primeros 2 grupos (col 0-7) hacen swap si mustHitSection
		// Paso 1: deshacer reordenamiento visual → columna en espacio de datos
		var reorderedData = visualColToDataCol(noteData);

		// Paso 2: deshacer mustHitSection swap
		var actualNoteData = reorderedData;
		if (reorderedData < 8 && _song.notes[targetSection].mustHitSection)
		{
			if (reorderedData < 4)
				actualNoteData = reorderedData + 4;
			else
				actualNoteData = reorderedData - 4;
		}
		// Para noteData ≥ 8 (grupos extra): no hay swap, actualNoteData = noteData

		// Calcular strumTime absoluto
		var noteStrumTime = getSectionStartTime(targetSection) + noteTimeInSection;

		// Verificar si ya existe
		var noteExists = false;
		for (i in _song.notes[targetSection].sectionNotes)
		{
			if (Math.abs(i[0] - noteStrumTime) < 5 && i[1] == actualNoteData)
			{
				saveUndoState("delete", {
					section: targetSection,
					note: [i[0], i[1], i[2]]
				});
				_song.notes[targetSection].sectionNotes.remove(i);
				noteExists = true;
				FlxG.sound.play(Paths.sound('menus/chartingSounds/undo'), 0.6);
				curSelectedNote = null; // ✨ Deseleccionar la nota eliminada
				break;
			}
		}

		// Si no existe, crear
		if (!noteExists)
		{
			// ✨ Obtener el sustain actual del stepper si hay uno
			var currentSus:Float = (stepperSusLength != null) ? stepperSusLength.value : 0;

			var newNote = [noteStrumTime, actualNoteData, currentSus];

			saveUndoState("add", {
				section: targetSection,
				note: newNote
			});
			_song.notes[targetSection].sectionNotes.push(newNote);

			// ✨ Seleccionar automáticamente la nota recién creada
			curSelectedNote = newNote;
			updateNoteUI();

			FlxG.sound.play(Paths.sound('menus/chartingSounds/openWindow'), 0.6);
		}
		updateGrid();
	}

	function deleteNoteAtPosition(worldY:Float, noteData:Int):Void
	{
		var clickedStep = worldY / GRID_SIZE;
		var snapSteps = (currentSnap / 16);
		clickedStep = Math.floor(clickedStep / snapSteps) * snapSteps;

		var accumulatedSteps:Float = 0;
		var targetSection:Int = 0;
		var noteTimeInSection:Float = 0;

		for (i in 0..._song.notes.length)
		{
			var sectionSteps = _song.notes[i].lengthInSteps;

			if (clickedStep < accumulatedSteps + sectionSteps)
			{
				targetSection = i;
				noteTimeInSection = (clickedStep - accumulatedSteps) * Conductor.stepCrochet;
				break;
			}

			accumulatedSteps += sectionSteps;
		}

		// CRITICAL FIX: Deshacer el mapeo visual antes de buscar la nota
		// Solo los primeros 2 grupos hacen swap si mustHitSection
		// Paso 1: deshacer reordenamiento visual → columna en espacio de datos
		var reorderedData = visualColToDataCol(noteData);

		// Paso 2: deshacer mustHitSection swap
		var actualNoteData = reorderedData;
		if (reorderedData < 8 && _song.notes[targetSection].mustHitSection)
		{
			if (reorderedData < 4)
				actualNoteData = reorderedData + 4;
			else
				actualNoteData = reorderedData - 4;
		}

		var noteStrumTime = getSectionStartTime(targetSection) + noteTimeInSection;

		for (i in _song.notes[targetSection].sectionNotes)
		{
			if (Math.abs(i[0] - noteStrumTime) < 5 && i[1] == actualNoteData)
			{
				saveUndoState("delete", {
					section: targetSection,
					note: [i[0], i[1], i[2]]
				});
				_song.notes[targetSection].sectionNotes.remove(i);
				FlxG.sound.play(Paths.sound('menus/chartingSounds/noteErase'), 0.6);
				updateGrid();
				return;
			}
		}
	}

	// ✨ NUEVA FUNCIÓN: Seleccionar una nota al hacer clic en ella
	function selectNoteAtPosition(worldY:Float, noteData:Int):Bool
	{
		var clickedStep = worldY / GRID_SIZE;
		var snapSteps = (currentSnap / 16);
		clickedStep = Math.floor(clickedStep / snapSteps) * snapSteps;

		var accumulatedSteps:Float = 0;
		var targetSection:Int = 0;
		var noteTimeInSection:Float = 0;

		for (i in 0..._song.notes.length)
		{
			var sectionSteps = _song.notes[i].lengthInSteps;

			if (clickedStep < accumulatedSteps + sectionSteps)
			{
				targetSection = i;
				noteTimeInSection = (clickedStep - accumulatedSteps) * Conductor.stepCrochet;
				break;
			}

			accumulatedSteps += sectionSteps;
		}

		// Deshacer el mapeo visual antes de buscar la nota
		// Paso 1: deshacer reordenamiento visual → columna en espacio de datos
		var reorderedData = visualColToDataCol(noteData);

		// Paso 2: deshacer mustHitSection swap
		var actualNoteData = reorderedData;
		if (reorderedData < 8 && _song.notes[targetSection].mustHitSection)
		{
			if (reorderedData < 4)
				actualNoteData = reorderedData + 4;
			else
				actualNoteData = reorderedData - 4;
		}

		var noteStrumTime = getSectionStartTime(targetSection) + noteTimeInSection;

		// Buscar la nota en esa posición
		for (i in _song.notes[targetSection].sectionNotes)
		{
			if (Math.abs(i[0] - noteStrumTime) < 5 && i[1] == actualNoteData)
			{
				// ✨ Nota encontrada! Seleccionarla
				curSelectedNote = i;
				updateNoteUI();
				showMessage('📝 Note selected (Sustain: ${i[2]}ms)', ACCENT_CYAN);
				FlxG.sound.play(Paths.sound('menus/chartingSounds/ClickUp'), 0.6);
				return true;
			}
		}

		return false;
	}

	function handleKeyboardInput():Void
	{
		if (isAnyPopupOpen() || openSectionNav)
			return;
		// ESC - Volver al PlayState (empezar desde el inicio)
		if (FlxG.keys.justPressed.ESCAPE)
		{
			testChart();
		}

		// PLAYBACK
		if (FlxG.keys.justPressed.SPACE)
		{
			if (FlxG.sound.music.playing)
			{
				FlxG.sound.music.pause();
				vocals.pause();
			}
			else
			{
				// ✨ Reproducir desde la sección actual basado en el scroll del grid
				FlxG.sound.music.time = getSectionStartTime(curSection);
				vocals.time = FlxG.sound.music.time;

				FlxG.sound.music.play();
				vocals.play();
				showMessage('▶ Playing from Section ${curSection + 1}', ACCENT_CYAN);
			}
		}

		if (FlxG.keys.justPressed.ENTER)
		{
			FlxG.sound.music.time = getSectionStartTime(curSection);
			FlxG.sound.music.play();

			// ✨ SINCRONIZAR VOCALES cuando pulsas ENTER
			syncVocals();
			showMessage('▶ Playing from Section ${curSection + 1}', ACCENT_CYAN);
		}

		// F5 - Ir al PlayState para probar el chart desde la sección actual
		if (FlxG.keys.justPressed.F5)
		{
			testChartFromSection();
		}

		// NAVEGACIÓN
		if (FlxG.keys.pressed.W || FlxG.keys.pressed.UP)
		{
			FlxG.sound.music.time -= 100 * FlxG.elapsed;
		}

		if (FlxG.keys.pressed.S || FlxG.keys.pressed.DOWN)
		{
			FlxG.sound.music.time += 100 * FlxG.elapsed;
		}

		if (FlxG.keys.justPressed.A || FlxG.keys.justPressed.LEFT)
		{
			FlxG.sound.music.time -= Conductor.stepCrochet;
		}

		if (FlxG.keys.justPressed.D || FlxG.keys.justPressed.RIGHT)
		{
			FlxG.sound.music.time += Conductor.stepCrochet;
		}

		// SECCIONES
		if (FlxG.keys.justPressed.PAGEUP)
		{
			changeSection(-1);
		}

		if (FlxG.keys.justPressed.PAGEDOWN)
		{
			changeSection(1);
		}
		/*
			// QUICK NOTE PLACEMENT (1-8)
			if (FlxG.keys.justPressed.ONE)
				placeQuickNote(0);
			if (FlxG.keys.justPressed.TWO)
				placeQuickNote(1);
			if (FlxG.keys.justPressed.THREE)
				placeQuickNote(2);
			if (FlxG.keys.justPressed.FOUR)
				placeQuickNote(3);
			if (FlxG.keys.justPressed.FIVE)
				placeQuickNote(4);
			if (FlxG.keys.justPressed.SIX)
				placeQuickNote(5);
			if (FlxG.keys.justPressed.SEVEN)
				placeQuickNote(6);
			if (FlxG.keys.justPressed.EIGHT)
				placeQuickNote(7); */

		// COPY/PASTE/MIRROR
		if (FlxG.keys.pressed.CONTROL)
		{
			if (FlxG.keys.justPressed.C)
				copySection();
			if (FlxG.keys.justPressed.V)
				pasteSection();
			if (FlxG.keys.justPressed.X)
				cutSection();
			if (FlxG.keys.justPressed.S)
				saveChart();
			if (FlxG.keys.justPressed.Z)
				undo();
			if (FlxG.keys.justPressed.Y)
				redo();
		}

		if (FlxG.keys.justPressed.N)
			mirrorSection();

		// SNAP CHANGE
		if (FlxG.keys.justPressed.Q)
		{
			currentSnap -= 16;
			if (currentSnap < 16)
				currentSnap = 64;
			showMessage('⚙️ Snap: ${getSnapName(currentSnap)}', ACCENT_CYAN);
		}

		if (FlxG.keys.justPressed.E)
		{
			currentSnap += 16;
			if (currentSnap > 64)
				currentSnap = 16;
			showMessage('⚙️ Snap: ${getSnapName(currentSnap)}', ACCENT_CYAN);
		}

		// TOGGLE HITSOUNDS
		if (FlxG.keys.justPressed.T)
		{
			hitsoundsEnabled = !hitsoundsEnabled;
			showMessage(hitsoundsEnabled ? '🔊 Hitsounds ON' : '🔇 Hitsounds OFF', ACCENT_CYAN);
		}

		// TOGGLE METRONOME
		if (FlxG.keys.justPressed.M)
		{
			metronomeEnabled = !metronomeEnabled;
			showMessage(metronomeEnabled ? '🎵 Metronome ON' : '🔇 Metronome OFF', ACCENT_CYAN);
		}
	}

	function handlePlaybackButtons():Void
	{
		// Play button
		if (FlxG.mouse.overlaps(playBtn, camHUD) && FlxG.mouse.justPressed)
		{
			if (!FlxG.sound.music.playing)
			{
				// ✨ Reproducir desde la sección actual basado en el scroll del grid
				FlxG.sound.music.time = getSectionStartTime(curSection);
				FlxG.sound.music.play();
				syncVocals(); // ✨ SINCRONIZAR VOCALES
				showMessage('▶ Playing from Section ${curSection + 1}', ACCENT_CYAN);
			}
		}

		// Pause button
		if (FlxG.mouse.overlaps(pauseBtn, camHUD) && FlxG.mouse.justPressed)
		{
			if (FlxG.sound.music.playing)
			{
				FlxG.sound.music.pause();
				syncVocals(); // ✨ SINCRONIZAR VOCALES
			}
		}

		// Stop button
		if (FlxG.mouse.overlaps(stopBtn, camHUD) && FlxG.mouse.justPressed)
		{
			FlxG.sound.music.stop();
			FlxG.sound.music.time = 0;
			syncVocals(); // ✨ SINCRONIZAR VOCALES
		}

		// Test button - Go to PlayState to test the chart from current section
		if (FlxG.mouse.overlaps(testBtn, camHUD) && FlxG.mouse.justPressed)
		{
			testChartFromSection();
		}

		// ===== NUEVOS BOTONES CLICKEABLES EN TOOLBAR =====

		// Click en BPM → abrir diálogo de input en el Song tab
		if (bpmText != null && FlxG.mouse.justPressed && FlxG.mouse.overlaps(bpmText, camHUD))
		{
			// Cambiar al Song tab para editar el BPM
			UI_box.selected_tab_id = 'Song';
			showMessage('✏️ Edit the BPM in the tab Song', ACCENT_WARNING);
		}

		// Click en Section → abrir diálogo de navegación
		if (sectionText != null && FlxG.mouse.justPressed && FlxG.mouse.overlaps(sectionText, camHUD))
		{
			openSectionNavigator();
		}

		// Click en botón Meta → toggle del popup
		if (metaBtn != null && FlxG.mouse.justPressed && FlxG.mouse.overlaps(metaBtn, camHUD))
		{
			if (metaPopup != null)
			{
				if (metaPopup.isOpen)
					metaPopup.close();
				else
					metaPopup.open();
			}
		}
	}

	// Abre un diálogo rápido para saltar a una sección específica
	function openSectionNavigator():Void
	{
		openSectionNav = true;
		// Crear overlay temporal de navegación
		var overlay = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, 0x88000000);
		overlay.scrollFactor.set();
		overlay.cameras = [camHUD];

		var panel = new FlxSprite(FlxG.width / 2 - 120, FlxG.height / 2 - 60).makeGraphic(240, 120, 0xFF1A1A33);
		panel.scrollFactor.set();
		panel.cameras = [camHUD];

		var label = new FlxText(FlxG.width / 2 - 115, FlxG.height / 2 - 50, 230, 'Go to section (1-${_song.notes.length}):', 11);
		label.setFormat(Paths.font("vcr.ttf"), 11, 0xFFAAAAAA, CENTER);
		label.scrollFactor.set();
		label.cameras = [camHUD];

		var input = new FlxUIInputText(FlxG.width / 2 - 50, FlxG.height / 2 - 25, 100, '${curSection + 1}', 14);
		input.scrollFactor.set();
		input.cameras = [camHUD];

		var confirmBtn:FlxButton = null;

		confirmBtn = new FlxButton(FlxG.width / 2 - 40, FlxG.height / 2 + 15, "Go", function()
		{
			var target = Std.parseInt(input.text);
			if (target != null && target >= 1 && target <= _song.notes.length)
			{
				changeSection(target - 1 - curSection);
				showMessage('📍 Navigating to section ${target}', ACCENT_CYAN);
			}
			remove(overlay);
			remove(panel);
			remove(label);
			remove(input);
			remove(confirmBtn);
			openSectionNav = false;
		});
		confirmBtn.scrollFactor.set();
		confirmBtn.cameras = [camHUD];

		add(overlay);
		add(panel);
		add(label);
		add(input);
		add(confirmBtn);
	}

	function placeQuickNote(noteData:Int):Void
	{
		var strumTime = FlxG.sound.music.time;
		strumTime = Math.floor(strumTime / (Conductor.stepCrochet / (currentSnap / 16))) * (Conductor.stepCrochet / (currentSnap / 16));

		_song.notes[curSection].sectionNotes.push([strumTime, noteData, 0]);

		if (hitsoundsEnabled)
			FlxG.sound.play(Paths.sound('menus/scrollMenu'), 0.4);

		updateGrid();
		showMessage('➕ Note placed', ACCENT_SUCCESS);
	}

	function updateGrid():Void
	{
		curRenderedNotes.clear();
		curRenderedSustains.clear();
		if (curRenderedTypeLabels != null) curRenderedTypeLabels.clear();

		var currentStep:Float = 0;

		for (secNum in 0..._song.notes.length)
		{
			var section = _song.notes[secNum];
			var sectionY = currentStep * GRID_SIZE;

			for (noteData in section.sectionNotes)
			{
				var daStrumTime:Float = noteData[0];
				var daNoteData:Int = Std.int(noteData[1]);
				var daSus:Float = noteData[2];

				var noteStep = (daStrumTime - getSectionStartTime(secNum)) / Conductor.stepCrochet;

				// === REMAPEAR COLUMNA VISUAL ===
				// Solo los primeros 2 grupos (col 0-7) hacen swap si mustHitSection
				// Los grupos extra (col ≥8) nunca hacen swap
				// Paso 1: mustHitSection swap (solo grupos 0 y 1 de datos)
				var swappedCol = daNoteData;
				if (daNoteData < 8 && section.mustHitSection)
				{
					if (daNoteData < 4)
						swappedCol = daNoteData + 4;
					else
						swappedCol = daNoteData - 4;
				}
				// Paso 2: reordenamiento visual por personaje
				var visualColumn = dataColToVisualCol(swappedCol);

				// Para noteData ≥ 8 (grupos extra): visualColumn = daNoteData sin cambios

				var note:Note = new Note(daStrumTime, visualColumn % 4);
				note.setGraphicSize(GRID_SIZE, GRID_SIZE);
				note.updateHitbox();
				note.x = gridBG.x + (GRID_SIZE * visualColumn);
				note.y = gridBG.y + sectionY + (noteStep * GRID_SIZE);

				// Color base
				var baseColor = NOTE_COLORS[visualColumn % 8];

				// ✨ Aplicar efecto pulsante si es la nota seleccionada
				if (curSelectedNote != null && noteData == curSelectedNote)
				{
					// Crear efecto pulsante: oscila entre 0.4 y 1.0
					var pulseAmount = 0.4 + (Math.sin(selectedNotePulse) * 0.5 + 0.5) * 0.6;

					// Oscurecer el color multiplicando cada componente
					var r = Std.int((baseColor >> 16 & 0xFF) * pulseAmount);
					var g = Std.int((baseColor >> 8 & 0xFF) * pulseAmount);
					var b = Std.int((baseColor & 0xFF) * pulseAmount);

					note.color = (0xFF << 24) | (r << 16) | (g << 8) | b;
				}
				else
				{
					note.color = baseColor;
				}

				// ✅ IMPORTANTE: Las notas NO deben scrollear
				note.scrollFactor.set();

				curRenderedNotes.add(note);

				// NoteType: etiqueta sobre la nota
				var _ntLabel:String = (noteData.length > 3 && noteData[3] != null) ? Std.string(noteData[3]) : '';
				if (_ntLabel != '' && _ntLabel != 'normal' && curRenderedTypeLabels != null)
				{
					var tl = new FlxText(note.x, note.y - 8, GRID_SIZE, _ntLabel, 7);
					tl.color = 0xFFFFFFFF;
					tl.borderStyle = OUTLINE;
					tl.borderColor = 0xFF000000;
					tl.borderSize = 1;
					tl.scrollFactor.set();
					curRenderedTypeLabels.add(tl);
				}

				// Sustain
				if (daSus > 0)
				{
					var susHeight = (daSus / Conductor.stepCrochet) * GRID_SIZE;

					// ✨ ASEGURAR QUE EL SUSTAIN SEA VISIBLE (mínimo 2 pixels)
					if (susHeight < 2)
						susHeight = 2;

					var sustainVis = new FlxSprite(note.x + (GRID_SIZE / 2) - 4, note.y + GRID_SIZE);
					sustainVis.makeGraphic(8, Std.int(susHeight), NOTE_COLORS[visualColumn % 8]);
					sustainVis.alpha = 0.6;
					sustainVis.scrollFactor.set(); // ✅ AGREGAR
					curRenderedSustains.add(sustainVis);
				}
			}

			currentStep += section.lengthInSteps;
		}
		updateNotePositions();
	}

	function getSectionStartTime(sectionNum:Int):Float
	{
		var time:Float = 0;

		for (i in 0...sectionNum)
		{
			var section = _song.notes[i];
			var bpm = section.changeBPM ? section.bpm : _song.bpm;
			var beats = section.lengthInSteps / 4;
			time += (beats * 60 / bpm) * 1000;
		}

		return time;
	}

	function getYfromStrum(strumTime:Float):Float
	{
		return FlxMath.remapToRange(strumTime, 0, 16 * Conductor.stepCrochet, gridBG.y, gridBG.y + gridBG.height);
	}

	function getStrumTime(yPos:Float):Float
	{
		return FlxMath.remapToRange(yPos, gridBG.y, gridBG.y + gridBG.height, 0, 16 * Conductor.stepCrochet);
	}

	// ✨ NUEVA FUNCIÓN: Actualizar posiciones de notas cuando el grid se mueve
	function updateNotePositions():Void
	{
		// Recalcular posiciones de todas las notas basándose en gridBG.y actual
		var currentStep:Float = 0;
		var noteIndex = 0;
		var susIndex = 0;

		for (secNum in 0..._song.notes.length)
		{
			var section = _song.notes[secNum];
			var sectionY = currentStep * GRID_SIZE;

			for (noteData in section.sectionNotes)
			{
				if (noteIndex >= curRenderedNotes.length)
					break;

				var note = curRenderedNotes.members[noteIndex];
				if (note == null)
				{
					noteIndex++;
					continue;
				}

				var daStrumTime:Float = noteData[0];
				var daNoteData:Int = Std.int(noteData[1]);
				var daSus:Float = noteData[2];
				var noteStep = (daStrumTime - getSectionStartTime(secNum)) / Conductor.stepCrochet;

				// ✨ REMAPEAR POSICIÓN VISUAL (igual que en updateGrid)
				// Paso 1: mustHitSection swap
				var swappedCol = daNoteData;
				if (section.mustHitSection)
				{
					if (daNoteData < 4)
						swappedCol = daNoteData + 4;
					else if (daNoteData < 8)
						swappedCol = daNoteData - 4;
				}
				// Paso 2: reordenamiento visual
				var visualColumn = dataColToVisualCol(swappedCol);

				// ACTUALIZAR posición X e Y
				note.x = gridBG.x + (GRID_SIZE * visualColumn);
				note.y = gridBG.y + sectionY + (noteStep * GRID_SIZE);

				// ✨ Aplicar efecto pulsante si es la nota seleccionada
				var baseColor = NOTE_COLORS[visualColumn % 8];

				if (curSelectedNote != null && noteData == curSelectedNote)
				{
					// Crear efecto pulsante: oscila entre 0.4 y 1.0
					var pulseAmount = 0.4 + (Math.sin(selectedNotePulse) * 0.5 + 0.5) * 0.6;

					// Oscurecer el color multiplicando cada componente
					var r = Std.int((baseColor >> 16 & 0xFF) * pulseAmount);
					var g = Std.int((baseColor >> 8 & 0xFF) * pulseAmount);
					var b = Std.int((baseColor & 0xFF) * pulseAmount);

					note.color = (0xFF << 24) | (r << 16) | (g << 8) | b;
				}
				else
				{
					note.color = baseColor;
				}

				// Actualizar sustain si existe
				// Alrededor de la línea 545 en ChartingState.hx
				if (daSus > 0 && susIndex < curRenderedSustains.length)
				{
					var sus = curRenderedSustains.members[susIndex];
					if (sus != null)
					{
						var susHeight = (daSus / Conductor.stepCrochet) * GRID_SIZE;

						// ✨ ASEGURAR QUE EL SUSTAIN SEA VISIBLE (mínimo 5 pixels)
						susHeight = Math.max(5, susHeight);

						sus.x = note.x + (GRID_SIZE / 2) - 4;
						sus.y = note.y + GRID_SIZE;

						// Redibujamos el gráfico con la nueva altura calculada
						// Usamos visualColumn % 8 para mantener el color correcto de la nota
						sus.makeGraphic(8, Std.int(susHeight), NOTE_COLORS[visualColumn % 8]);
						sus.alpha = 0.6; // ✨ Restaurar la transparencia
					}
					susIndex++;
				}

				noteIndex++;
			}

			currentStep += section.lengthInSteps;
		}
	}

	function cullNotes():Void
	{
		// Mostrar notas que están cerca de la pantalla visible
		var minY = 0;
		var maxY = FlxG.height;

		for (note in curRenderedNotes)
		{
			if (note == null)
				continue;
			// Mostrar si está en la ventana visible (con margen generoso)
			note.visible = (note.y >= minY - 200 && note.y <= maxY + 200);
		}

		for (sus in curRenderedSustains)
		{
			if (sus == null)
				continue;
			sus.visible = (sus.y >= minY - 200 && sus.y <= maxY + 200);
		}
	}

	function changeSection(change:Int = 0):Void
	{
		curSection += change;

		// Safety checks mejorados
		if (_song.notes.length == 0)
		{
			trace('[ChartingState] ERROR: Cannot change section, notes array is empty!');
			return;
		}

		if (curSection < 0)
			curSection = 0;
		if (curSection >= _song.notes.length)
			curSection = _song.notes.length - 1;

		// En lugar de cambiar vista, hacer scroll al section
		var targetY:Float = 0;
		for (i in 0...curSection)
		{
			targetY += _song.notes[i].lengthInSteps * GRID_SIZE;
		}

		gridScrollY = targetY;
		if (gridScrollY > maxScroll)
			gridScrollY = maxScroll;

		gridBG.y = 100 - gridScrollY;
		gridBlackWhite.y = gridBG.y;

		// Mover música al inicio de la sección
		if (FlxG.sound.music != null)
			FlxG.sound.music.time = getSectionStartTime(curSection);

		updateSectionUI();

		// ✨ SINCRONIZAR VOCALES cuando cambias de sección
		syncVocals();
	}

	function addSection(lengthInSteps:Int = 16):Void
	{
		var sec:SwagSection = {
			lengthInSteps: lengthInSteps,
			bpm: _song.bpm,
			stage: 'stage_week1',
			changeBPM: false,
			mustHitSection: true,
			sectionNotes: [],
			typeOfSection: 0,
			altAnim: false,
			gfSing: false,
			bothSing: false
		};

		_song.notes.push(sec);
		showMessage("➕ Section added", ACCENT_SUCCESS);
	}

	function updateSectionUI():Void
	{
		// Safety check: asegurar que curSection es válido
		if (curSection < 0 || curSection >= _song.notes.length)
		{
			trace('[ChartingState] WARNING: Invalid curSection ($curSection), clamping to valid range');
			curSection = FlxMath.maxInt(0, FlxMath.minInt(curSection, _song.notes.length - 1));
		}

		if (check_mustHitSection != null)
			check_mustHitSection.checked = _song.notes[curSection].mustHitSection;

		if (check_altAnim != null)
			check_altAnim.checked = _song.notes[curSection].altAnim;

		if (check_changeBPM != null)
			check_changeBPM.checked = _song.notes[curSection].changeBPM;

		if (stepperLength != null)
			stepperLength.value = _song.notes[curSection].lengthInSteps;
	}

	function updateNoteUI():Void
	{
		if (stepperSusLength != null && curSelectedNote != null)
		{
			stepperSusLength.value = curSelectedNote[2];
		}

		// Sync noteType dropdown
		if (noteTypeDropdown != null)
		{
			var typeName:String = (curSelectedNote != null && curSelectedNote.length > 3 && curSelectedNote[3] != null)
				? Std.string(curSelectedNote[3]) : 'normal';
			var idx = _noteTypesList.indexOf(typeName);
			if (idx < 0) idx = 0;
			noteTypeDropdown.selectedLabel = '$idx: ${_noteTypesList[idx]}';
		}
	}

	override function getEvent(id:String, sender:Dynamic, data:Dynamic, ?params:Array<Dynamic>)
	{
		if (id == FlxUICheckBox.CLICK_EVENT)
		{
			var check:FlxUICheckBox = cast sender;
			var label = check.getLabel().text;

			switch (label)
			{
				case 'Must Hit Section':
					_song.notes[curSection].mustHitSection = check.checked;

				case 'Change BPM':
					_song.notes[curSection].changeBPM = check.checked;

				case 'Alt Animation':
					_song.notes[curSection].altAnim = check.checked;
			}
		}
		else if (id == FlxUINumericStepper.CHANGE_EVENT && (sender is FlxUINumericStepper))
		{
			var nums:FlxUINumericStepper = cast sender;
			var wname = nums.name;

			switch (wname)
			{
				case 'section_length':
					_song.notes[curSection].lengthInSteps = Std.int(nums.value);
					updateGrid();

				case 'song_speed':
					_song.speed = nums.value;

				case 'song_bpm':
					tempBpm = nums.value;
					_song.bpm = tempBpm;
					Conductor.mapBPMChanges(_song);
					Conductor.changeBPM(tempBpm);

				case 'note_susLength':
					if (curSelectedNote != null)
					{
						curSelectedNote[2] = nums.value;
						updateGrid();
					}
			}
		}
	}

	function copySection():Void
	{
		clipboard = [];
		for (note in _song.notes[curSection].sectionNotes)
		{
			clipboard.push([note[0], note[1], note[2], note.length > 3 ? note[3] : null]);
		}

		showMessage('📋 Copied ${clipboard.length} notes', ACCENT_SUCCESS);
		FlxG.sound.play(Paths.sound('menus/chartingSounds/noteLay'), 0.6);
	}

	function pasteSection():Void
	{
		if (clipboard.length == 0)
		{
			showMessage('❌ Clipboard is empty!', ACCENT_ERROR);
			return;
		}

		saveUndoState("paste", {
			oldNotes: _song.notes[curSection].sectionNotes.copy(),
			newNotes: clipboard.copy()
		});

		_song.notes[curSection].sectionNotes = [];
		for (note in clipboard)
		{
			_song.notes[curSection].sectionNotes.push([note[0], note[1], note[2]]);
		}

		updateGrid();
		showMessage('📌 Pasted ${clipboard.length} notes', ACCENT_SUCCESS);
		FlxG.sound.play(Paths.sound('menus/chartingSounds/stretchSNAP_UI'), 0.6);
	}

	function cutSection():Void
	{
		copySection();
		_song.notes[curSection].sectionNotes = [];
		updateGrid();
		showMessage('✂️ Cut section', ACCENT_WARNING);
	}

	function mirrorSection():Void
	{
		for (note in _song.notes[curSection].sectionNotes)
		{
			var noteData:Int = note[1];

			// Swap player <-> opponent solo en los primeros 2 grupos (0-7)
			if (noteData < 8)
			{
				if (noteData < 4)
					note[1] = noteData + 4;
				else
					note[1] = noteData - 4;
			}
			// Grupos extra (≥8): no se hace swap
		}

		updateGrid();
		showMessage('🔄 Section mirrored (P1 ↔ P2)', ACCENT_CYAN);
		FlxG.sound.play(Paths.sound('menus/chartingSounds/stretchSNAP_UI'), 0.6);
	}

	function mirrorHorizontal():Void
	{
		for (note in _song.notes[curSection].sectionNotes)
		{
			var noteData:Int = note[1];
			var group = Math.floor(noteData / 4);
			var column:Int = noteData % 4;

			// Invertir columnas dentro de su grupo: 0<->3, 1<->2
			var newColumn:Int = switch (column)
			{
				case 0: 3;
				case 1: 2;
				case 2: 1;
				case 3: 0;
				default: column;
			};

			note[1] = (group * 4) + newColumn;
		}

		updateGrid();
		showMessage('↔️ Section flipped horizontally', ACCENT_CYAN);
	}

	function saveUndoState(actionType:String, data:Dynamic):Void
	{
		if (undoStack.length >= MAX_UNDO_STEPS)
			undoStack.shift();

		undoStack.push({
			type: actionType,
			section: curSection,
			data: data
		});

		redoStack = [];
	}

	function undo():Void
	{
		if (undoStack.length == 0)
		{
			showMessage('❌ Nothing to undo!', ACCENT_WARNING);
			return;
		}

		var action = undoStack.pop();
		redoStack.push(action);

		switch (action.type)
		{
			case "add":
				var note = action.data.note;
				_song.notes[action.section].sectionNotes.remove(note);

			case "delete":
				var note = action.data.note;
				_song.notes[action.section].sectionNotes.push(note);

			case "paste":
				_song.notes[curSection].sectionNotes = action.data.oldNotes.copy();
		}

		updateGrid();
		showMessage('↶ Undo', ACCENT_CYAN);
		FlxG.sound.play(Paths.sound('menus/chartingSounds/undo'), 0.6);
	}

	function redo():Void
	{
		if (redoStack.length == 0)
		{
			showMessage('❌ Nothing to redo!', ACCENT_WARNING);
			return;
		}

		var action = redoStack.pop();
		undoStack.push(action);

		switch (action.type)
		{
			case "add":
				var note = action.data.note;
				_song.notes[action.section].sectionNotes.push(note);

			case "delete":
				var note = action.data.note;
				_song.notes[action.section].sectionNotes.remove(note);

			case "paste":
				_song.notes[curSection].sectionNotes = action.data.newNotes.copy();
		}

		updateGrid();
		showMessage('↷ Redo', ACCENT_CYAN);
		FlxG.sound.play(Paths.sound('menus/chartingSounds/openWindow'), 0.6);
	}

	function calculateNPS():Float
	{
		if (_song.notes.length == 0)
			return 0;

		var totalNotes = countTotalNotes();
		var totalSeconds = getSectionStartTime(_song.notes.length) / 1000;

		if (totalSeconds <= 0)
			return 0;

		return totalNotes / totalSeconds;
	}

	function autosaveChart():Void
	{
		if (!validateChart())
			return;

		var json = {
			"song": _song
		};

		var data:String = Json.stringify(json, "\t");

		#if sys
		try
		{
			var path = Paths.resolve('data/${_song.song.toLowerCase()}/autosave-${_song.song.toLowerCase()}.json');
			sys.io.File.saveContent(path, data);
			showMessage('💾 Autosaved!', ACCENT_SUCCESS);
		}
		catch (e:Dynamic)
		{
			trace('Autosave error: $e');
		}
		#else
		showMessage('💾 Autosave not available on this platform', ACCENT_WARNING);
		#end
	}

	function saveChart():Void
	{
		if (!validateChart())
			return;

		var json = {
			"song": _song
		};

		var data:String = Json.stringify(json, "\t");

		if (data.length > 0)
		{
			_file = new FileReference();
			_file.addEventListener(Event.COMPLETE, onSaveComplete);
			_file.addEventListener(Event.CANCEL, onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file.save(data, _song.song.toLowerCase() + ".json");
		}

		showMessage('💾 Saving chart...', ACCENT_CYAN);
	}

	function onSaveComplete(_):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;

		showMessage('✅ Chart saved successfully!', ACCENT_SUCCESS);
		FlxG.sound.play(Paths.sound('menus/confirmMenu'), 0.6);
	}

	function onSaveCancel(_):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;

		showMessage('❌ Save cancelled', ACCENT_WARNING);
	}

	function onSaveError(_):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;

		showMessage('❌ Error saving chart!', ACCENT_ERROR);
	}

	/** Devuelve strumsGroups en el orden visual (igual que los iconos de personajes). */
	function getOrderedStrumsGroups():Array<StrumsGroupData>
	{
		if (_song.strumsGroups == null || _song.strumsGroups.length == 0)
			return _song.strumsGroups != null ? _song.strumsGroups : [];

		var ordered:Array<StrumsGroupData> = [];
		var usedIds:Array<String> = [];

		if (_song.characters != null)
		{
			for (char in _song.characters)
			{
				if (char.strumsGroup == null || char.strumsGroup.length == 0)
					continue;
				if (usedIds.indexOf(char.strumsGroup) >= 0)
					continue;
				for (sg in _song.strumsGroups)
				{
					if (sg.id == char.strumsGroup)
					{
						ordered.push(sg);
						usedIds.push(sg.id);
						break;
					}
				}
			}
		}

		// Grupos sin personaje asignado van al final
		for (sg in _song.strumsGroups)
			if (usedIds.indexOf(sg.id) < 0)
				ordered.push(sg);

		return ordered;
	}

	/** Columna de datos → columna visual (aplica reordenamiento por personaje). */
	function dataColToVisualCol(dataCol:Int):Int
	{
		if (_song.strumsGroups == null || _song.strumsGroups.length == 0)
			return dataCol;
		var dataGroupIdx = Math.floor(dataCol / 4);
		var direction = dataCol % 4;
		if (dataGroupIdx >= _song.strumsGroups.length)
			return dataCol;

		var dataGroupId = _song.strumsGroups[dataGroupIdx].id;
		var ordered = getOrderedStrumsGroups();

		for (i in 0...ordered.length)
			if (ordered[i].id == dataGroupId)
				return i * 4 + direction;

		return dataCol;
	}

	/** Columna visual → columna de datos (inverso del anterior). */
	function visualColToDataCol(visualCol:Int):Int
	{
		var visualGroupIdx = Math.floor(visualCol / 4);
		var direction = visualCol % 4;
		var ordered = getOrderedStrumsGroups();

		if (visualGroupIdx >= ordered.length)
			return visualCol;
		var visualGroupId = ordered[visualGroupIdx].id;

		if (_song.strumsGroups == null)
			return visualCol;
		for (i in 0..._song.strumsGroups.length)
			if (_song.strumsGroups[i].id == visualGroupId)
				return i * 4 + direction;

		return visualCol;
	}

	// ✨ NUEVA FUNCIÓN: Probar el chart en PlayState
	function testChart():Void
	{
		if (!validateChart())
		{
			showMessage('❌ Chart has errors! Fix them before testing.', ACCENT_ERROR);
			return;
		}

		showMessage('🎮 Loading PlayState from start...', ACCENT_CYAN);
		FlxG.sound.play(Paths.sound('menus/confirmMenu'), 0.6);

		// Detener audio
		FlxG.sound.music.stop();
		if (vocals != null)
			vocals.stop();

		// Actualizar PlayState.SONG con el chart actual
		PlayState.SONG = _song;
		PlayState.isStoryMode = false;
		PlayState.storyDifficulty = 1;
		PlayState.startFromTime = null; // ✨ Empezar desde el inicio

		// Pequeño delay para que el usuario vea el mensaje
		new FlxTimer().start(0.3, function(tmr:FlxTimer)
		{
			FlxG.mouse.visible = false;
			LoadingState.loadAndSwitchState(new PlayState());
		});
	}

	// ✨ NUEVA FUNCIÓN: Probar el chart desde la sección actual
	function testChartFromSection():Void
	{
		if (!validateChart())
		{
			showMessage('❌ Chart has errors! Fix them before testing.', ACCENT_ERROR);
			return;
		}

		var sectionStartTime = getSectionStartTime(curSection);

		showMessage('🎮 Testing from Section ${curSection + 1} (${formatTime(sectionStartTime)})...', ACCENT_CYAN);
		FlxG.sound.play(Paths.sound('menus/confirmMenu'), 0.6);

		// Detener audio
		FlxG.sound.music.stop();
		if (vocals != null)
			vocals.stop();

		// Actualizar PlayState.SONG con el chart actual
		PlayState.SONG = _song;
		PlayState.isStoryMode = false;
		PlayState.storyDifficulty = 1;
		PlayState.startFromTime = sectionStartTime; // ✨ Empezar desde esta sección

		trace('[ChartingState] Testing chart from section ${curSection + 1}, time: ${sectionStartTime}ms');

		// Pequeño delay para que el usuario vea el mensaje
		new FlxTimer().start(0.3, function(tmr:FlxTimer)
		{
			FlxG.mouse.visible = false;
			LoadingState.loadAndSwitchState(new PlayState());
		});
	}

	function loadChart():Void
	{
		var jsonFilter:String = "JSON files (*.json)";
		_file = new FileReference();
		_file.addEventListener(Event.SELECT, onLoadSelect);
		_file.addEventListener(Event.CANCEL, onLoadCancel);
		_file.addEventListener(IOErrorEvent.IO_ERROR, onLoadError);
		_file.browse();

		showMessage('📂 Select chart to load...', ACCENT_CYAN);
	}

	function onLoadSelect(_):Void
	{
		_file.addEventListener(Event.COMPLETE, onLoadComplete);
		_file.load();
	}

	function onLoadComplete(_):Void
	{
		var fullJson:String = _file.data.toString();

		try
		{
			var parsedJson = Json.parse(fullJson);
			_song = parsedJson.song;

			// Verificar que tenga los campos necesarios
			if (_song.player1 == null)
				_song.player1 = 'bf';
			if (_song.player2 == null)
				_song.player2 = 'dad';
			if (_song.gfVersion == null)
				_song.gfVersion = 'gf';
			if (_song.stage == null)
				_song.stage = CharacterList.getDefaultStageForSong(_song.song);

			// CRÍTICO: Crear sección por defecto si el array está vacío
			if (_song.notes == null || _song.notes.length == 0)
			{
				trace('[ChartingState] Loaded chart has empty notes array, creating default section');
				_song.notes = [
					{
						lengthInSteps: 16,
						bpm: _song.bpm,
						changeBPM: false,
						mustHitSection: true,
						sectionNotes: [],
						typeOfSection: 0,
						altAnim: false
					}
				];
			}

			PlayState.SONG = _song;

			// Reload
			loadSong(_song.song);
			curSection = 0;
			changeSection(0);

			// Update UI
			songNameText.text = '• ${_song.song}';
			if (stepperBPM != null)
				stepperBPM.value = _song.bpm;
			if (stepperSpeed != null)
				stepperSpeed.value = _song.speed;

			showMessage('✅ Chart loaded: ${_song.song}', ACCENT_SUCCESS);
			FlxG.sound.play(Paths.sound('menus/confirmMenu'), 0.6);
		}
		catch (e:Dynamic)
		{
			showMessage('❌ Error parsing JSON: $e', ACCENT_ERROR);
			trace('Load error: $e');
		}

		_file.removeEventListener(Event.SELECT, onLoadSelect);
		_file.removeEventListener(Event.CANCEL, onLoadCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onLoadError);
		_file.removeEventListener(Event.COMPLETE, onLoadComplete);
		_file = null;
	}

	function onLoadCancel(_):Void
	{
		_file.removeEventListener(Event.SELECT, onLoadSelect);
		_file.removeEventListener(Event.CANCEL, onLoadCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onLoadError);
		_file = null;

		showMessage('❌ Load cancelled', ACCENT_WARNING);
	}

	function onLoadError(_):Void
	{
		_file.removeEventListener(Event.SELECT, onLoadSelect);
		_file.removeEventListener(Event.CANCEL, onLoadCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onLoadError);
		_file = null;

		showMessage('❌ Error loading chart!', ACCENT_ERROR);
	}

	function exportChart():Void
	{
		// Exportar chart con metadata adicional
		var json = {
			"song": _song,
			"metadata": {
				"editor": "Chart Editor v2.0",
				"exportDate": Date.now().toString(),
				"totalNotes": countTotalNotes(),
				"nps": Math.round(calculateNPS() * 100) / 100,
				"difficulty": "unknown"
			}
		};

		var data:String = Json.stringify(json, "\t");

		if (data.length > 0)
		{
			_file = new FileReference();
			_file.addEventListener(Event.COMPLETE, onExportComplete);
			_file.addEventListener(Event.CANCEL, onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file.save(data, _song.song.toLowerCase() + "-export.json");
		}
	}

	function onExportComplete(_):Void
	{
		_file.removeEventListener(Event.COMPLETE, onExportComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;

		showMessage('📦 Chart exported with metadata!', ACCENT_SUCCESS);
	}

	function countTotalNotes():Int
	{
		var total = 0;
		for (section in _song.notes)
			total += section.sectionNotes.length;
		return total;
	}

	function validateChart():Bool
	{
		// Validar que el chart tenga sentido
		if (_song.notes.length == 0)
		{
			showMessage('⚠️ Chart is empty!', ACCENT_WARNING);
			return false;
		}

		if (_song.bpm <= 0)
		{
			showMessage('⚠️ Invalid BPM!', ACCENT_WARNING);
			return false;
		}

		if (_song.song == null || _song.song == "")
		{
			showMessage('⚠️ Song name is empty!', ACCENT_WARNING);
			return false;
		}

		return true;
	}

	override function destroy():Void
	{
		// Cleanup
		if (vocals != null)
		{
			vocals.stop();
			vocals.destroy();
		}

		// Remove event listeners
		if (_file != null)
		{
			_file.removeEventListener(Event.COMPLETE, onSaveComplete);
			_file.removeEventListener(Event.CANCEL, onSaveCancel);
			_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file = null;
		}

		// Save last section
		lastSection = curSection;

		super.destroy();
	}

	// ==================== HELPER FUNCTIONS ====================

	function formatTime(seconds:Float):String
	{
		var minutes = Math.floor(seconds / 60);
		var secs = Math.floor(seconds % 60);
		var ms = Math.floor((seconds % 1) * 1000);

		return '${StringTools.lpad('$minutes', "0", 2)}:${StringTools.lpad('$secs', "0", 2)}.${StringTools.lpad('$ms', "0", 3)}';
	}

	function clamp(value:Float, min:Float, max:Float):Float
	{
		if (value < min)
			return min;
		if (value > max)
			return max;
		return value;
	}

	function getNoteDataName(noteData:Int):String
	{
		var names = ["Left", "Down", "Up", "Right"];
		return names[noteData % 4];
	}

	function getSnapName(snap:Int):String
	{
		return switch (snap)
		{
			case 16: "1/4";
			case 32: "1/8";
			case 48: "1/12";
			case 64: "1/16";
			default: "1/4";
		};
	}
}

typedef ChartAction =
{
	var type:String;
	var section:Int;
	var data:Dynamic;
}
/*
 * 
 * SHORTCUTS:
 * - 1-8: Colocar notas rápido
 * - Shift+1-8: Colocar holds
 * - Ctrl+C/V/X: Copy/Paste/Cut
 * - M: Mirror section
 * - Q/E: Change snap
 * - T: Toggle hitsounds
 * - M: Toggle metronome
 * - Space: Play/Pause
 * - Enter: Restart from section
 * - PageUp/Down: Navigate sections
 * - ESC: Exit
 * 
 * FEATURES:
 * ✅ UI Moderna con colores
 * ✅ Info panel en tiempo real
 * ✅ Status bar con tips rotativos
 * ✅ Copy/Paste/Mirror
 * ✅ Quick note placement
 * ✅ Hitsounds y metronome
 * ✅ Autosave cada 5 minutos
 * ✅ Selector de personajes y stages
 * ✅ Save/Load con metadata
 * ✅ Chart validation
 * ✅ Playtest mode
 * ✅ Sincronización de vocales mejorada
 * 
 * AUTOSAVE:
 * - Cada 5 minutos automáticamente
 * - Guarda en assets/data/[song]/autosave-[song].json
 * - Backups manuales disponibles
 * 
 * DISFRUTA! 🎮✨
 */
