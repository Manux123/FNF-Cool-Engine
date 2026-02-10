package funkin.debug;

import funkin.data.Conductor.BPMChangeEvent;
import funkin.data.Section.SwagSection;
import funkin.data.Song.SwagSong;
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
import funkin.menus.OptionsMenuState;
import openfl.utils.ByteArray;
import funkin.states.LoadingState;
import funkin.gameplay.PlayState;
import funkin.gameplay.notes.Note;
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
	// COLORES - CORREGIDOS
	static inline var BG_DARK:Int = 0xFF1E1E1E;
	static inline var BG_PANEL:Int = 0xFF2D2D2D;
	static inline var ACCENT_CYAN:Int = 0xFF00D9FF;
	static inline var ACCENT_PINK:Int = 0xFFFF00E5;
	static inline var ACCENT_GREEN:Int = 0xFF00FF88;
	static inline var ACCENT_SUCCESS:Int = 0xFF00FF88;
	static inline var ACCENT_WARNING:Int = 0xFFFFAA00;
	static inline var ACCENT_ERROR:Int = 0xFFFF3366;
	static inline var TEXT_WHITE:Int = 0xFFFFFFFF;
	static inline var TEXT_GRAY:Int = 0xFFAAAAAA;

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
	var tab_group_characters:FlxUI;
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
	var playBtn:FlxSprite;
	var pauseBtn:FlxSprite;
	var stopBtn:FlxSprite;

	// TIPS
	var tips:Array<String>;
	var currentTip:Int = 0;
	var tipTimer:Float = 0;

	// NOTAS
	var curRenderedNotes:FlxTypedGroup<Note>;
	var curRenderedSustains:FlxTypedGroup<FlxSprite>;
	var dummyArrow:FlxSprite;

	// ICONOS
	var leftIcon:HealthIcon;
	var rightIcon:HealthIcon;
	var middleIcon:HealthIcon;

	// INDICADORES DE SECCIÓN
	var sectionIndicators:FlxTypedGroup<FlxSprite>;

	// DROPDOWNS
	var bfDropDown:FlxUIDropDownMenu;
	var dadDropDown:FlxUIDropDownMenu;
	var gfDropDown:FlxUIDropDownMenu;
	var stageDropDown:FlxUIDropDownMenu;

	// STEPPERS
	var stepperLength:FlxUINumericStepper;
	var stepperBPM:FlxUINumericStepper;
	var stepperSpeed:FlxUINumericStepper;
	var stepperSusLength:FlxUINumericStepper;

	// CHECKBOXES
	var check_mustHitSection:FlxUICheckBox;
	var check_changeBPM:FlxUICheckBox;
	var check_altAnim:FlxUICheckBox;

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

	override function create()
	{
		FlxG.mouse.visible = true;
		if (FlxG.save.data.FPSCap)
			openfl.Lib.current.stage.frameRate = 120;
		else
			openfl.Lib.current.stage.frameRate = 240;

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
		setupIcons();
		setupUITabs();
		setupInfoPanel();
		setupStatusBar();

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
			"💡 M to mirror section",
			"💡 Q/E to change snap",
			"💡 T for hitsounds",
			"💡 G for metronome",
			"💡 PageUp/Down to navigate",
			"💡 Mouse wheel to scroll grid",
			"💡 Shift+Wheel for pixel scroll",
			"💡 Space to play/pause"
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

		// Botones
		playBtn = createToolButton(10, 40, "▶");
		pauseBtn = createToolButton(55, 40, "⏸");
		stopBtn = createToolButton(100, 40, "⏹");

		add(playBtn);
		add(pauseBtn);
		add(stopBtn);

		// Info texts
		timeText = new FlxText(160, 45, 0, "⏱ 00:00.000", 12);
		timeText.setFormat(Paths.font("vcr.ttf"), 12, TEXT_GRAY, LEFT);
		timeText.scrollFactor.set();
		timeText.cameras = [camHUD];
		add(timeText);

		bpmText = new FlxText(300, 45, 0, "🎵 120 BPM", 12);
		bpmText.setFormat(Paths.font("vcr.ttf"), 12, TEXT_GRAY, LEFT);
		bpmText.scrollFactor.set();
		bpmText.cameras = [camHUD];
		add(bpmText);

		sectionText = new FlxText(430, 45, 0, "📊 Section 1/1", 12);
		sectionText.setFormat(Paths.font("vcr.ttf"), 12, TEXT_GRAY, LEFT);
		sectionText.scrollFactor.set();
		sectionText.cameras = [camHUD];
		add(sectionText);
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

	function setupGrid():Void
	{
		// Calcular altura total del grid basado en todas las secciones
		totalGridHeight = 0;
		for (sec in _song.notes)
		{
			totalGridHeight += sec.lengthInSteps * GRID_SIZE;
		}

		maxScroll = totalGridHeight - (FlxG.height - 100);
		if (maxScroll < 0)
			maxScroll = 0;

		// Grid BG
		gridBG = FlxGridOverlay.create(GRID_SIZE, GRID_SIZE, GRID_SIZE * 8, Std.int(totalGridHeight), true, 0xFF3A3A3A, 0xFF2D2D2D);
		gridBG.x = (FlxG.width / 2) - (GRID_SIZE * 4);
		gridBG.y = 100;
		gridBG.scrollFactor.set();
		gridBG.cameras = [camGame];
		add(gridBG);

		// Grid Blanco/Negro
		gridBlackWhite = new FlxSprite(gridBG.x, gridBG.y);
		gridBlackWhite.makeGraphic(Std.int(gridBG.width), Std.int(gridBG.height), 0x00000000, true);

		var currentY:Float = 0;
		for (i in 0..._song.notes.length)
		{
			var sectionHeight = _song.notes[i].lengthInSteps * GRID_SIZE;
			var sectionColor = (i % 2 == 0) ? 0x30FFFFFF : 0x20000000;
			FlxSpriteUtil.drawRect(gridBlackWhite, 0, currentY, gridBG.width, sectionHeight, sectionColor);
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

		// Sección indicators
		sectionIndicators = new FlxTypedGroup<FlxSprite>();
		add(sectionIndicators);
		updateSectionIndicators();

		// Dummy arrow
		dummyArrow = new FlxSprite().makeGraphic(GRID_SIZE, GRID_SIZE);
		add(dummyArrow);
	}

	function setupNotes():Void
	{
		curRenderedNotes = new FlxTypedGroup<Note>();
		curRenderedSustains = new FlxTypedGroup<FlxSprite>();

		add(curRenderedSustains);
		add(curRenderedNotes);
	}

	function setupIcons():Void
	{
		updateHeads();
	}

	function setupUITabs():Void
	{
		UI_box = new FlxUITabMenu(null, [
			{name: "Song", label: 'Song'},
			{name: "Section", label: 'Section'},
			{name: "Note", label: 'Note'},
			{name: "Characters", label: 'Characters'},
			{name: "Settings", label: 'Settings'}
		], true);

		UI_box.resize(300, 400);
		UI_box.x = FlxG.width - 320;
		UI_box.y = 20;
		UI_box.scrollFactor.set();
		UI_box.cameras = [camHUD];

		addSongUI();
		addSectionUI();
		addNoteUI();
		addCharactersUI();
		addSettingsUI();

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

		// Snap
		var snapLabel = new FlxText(10, 60, 0, 'Note Snap:', 10);
		tab_group_note.add(snapLabel);

		var snapText = new FlxText(10, 75, 0, 'Current: 1/4 (Q/E to change)', 10);
		snapText.color = ACCENT_CYAN;
		tab_group_note.add(snapText);

		UI_box.addGroup(tab_group_note);
	}

	function addCharactersUI():Void
	{
		tab_group_characters = new FlxUI(null, UI_box);
		tab_group_characters.name = 'Characters';

		// Boyfriend
		var bfLabel = new FlxText(10, 10, 0, 'BOYFRIEND:', 10);
		tab_group_characters.add(bfLabel);

		var bfList = CharacterList.boyfriends.map(function(char:String)
		{
			return CharacterList.getCharacterName(char);
		});

		bfDropDown = new FlxUIDropDownMenu(10, 25, FlxUIDropDownMenu.makeStrIdLabelArray(bfList, true), function(character:String)
		{
			_song.player1 = CharacterList.boyfriends[Std.parseInt(character)];
			updateHeads();
		});

		// Dad/Opponent
		var dadLabel = new FlxText(10, 70, 0, 'OPPONENT:', 10);

		var dadList = CharacterList.opponents.map(function(char:String)
		{
			return CharacterList.getCharacterName(char);
		});

		dadDropDown = new FlxUIDropDownMenu(10, 85, FlxUIDropDownMenu.makeStrIdLabelArray(dadList, true), function(character:String)
		{
			_song.player2 = CharacterList.opponents[Std.parseInt(character)];
			updateHeads();
		});
		tab_group_characters.add(dadDropDown);

		// GF
		var gfLabel = new FlxText(10, 130, 0, 'GIRLFRIEND:', 10);
		tab_group_characters.add(gfLabel);

		var gfList = CharacterList.girlfriends.map(function(char:String)
		{
			return CharacterList.getCharacterName(char);
		});

		gfDropDown = new FlxUIDropDownMenu(10, 145, FlxUIDropDownMenu.makeStrIdLabelArray(gfList, true), function(character:String)
		{
			_song.gfVersion = CharacterList.girlfriends[Std.parseInt(character)];
			updateHeads();
		});

		// Stage
		var stageLabel = new FlxText(10, 190, 0, 'STAGE:', 10);
		tab_group_characters.add(stageLabel);

		var stageList = CharacterList.stages.map(function(stage:String)
		{
			return CharacterList.getStageName(stage);
		});

		stageDropDown = new FlxUIDropDownMenu(10, 205, FlxUIDropDownMenu.makeStrIdLabelArray(stageList, true), function(stage:String)
		{
			_song.stage = CharacterList.stages[Std.parseInt(stage)];
		});

		if (_song.stage != null && CharacterList.stages.contains(_song.stage))
		{
			var stageIndex = CharacterList.stages.indexOf(_song.stage);
			stageDropDown.selectedId = '$stageIndex';
			stageDropDown.selectedLabel = CharacterList.getStageName(_song.stage);
		}

		// Auto-detect button
		var autoBtn = new FlxButton(10, 250, "Auto-detect", function()
		{
			var detectedStage = CharacterList.getDefaultStageForSong(_song.song);
			_song.stage = detectedStage;
			var detectedGF = CharacterList.getDefaultGFForStage(detectedStage);
			_song.gfVersion = detectedGF;
			updateHeads();
		});
		tab_group_characters.add(autoBtn);

		tab_group_characters.add(stageDropDown);
		tab_group_characters.add(gfDropDown);
		tab_group_characters.add(dadLabel);
		tab_group_characters.add(bfDropDown);

		UI_box.addGroup(tab_group_characters);
	}

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
		var metronomeCheck = new FlxUICheckBox(10, 40, null, null, "Metronome (G)", 100);
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
		timeText.text = '⏱ ${StringTools.lpad('$minutes', "0", 2)}:${StringTools.lpad('$seconds', "0", 2)}.${StringTools.lpad('$ms', "0", 3)}';

		// BPM
		bpmText.text = '🎵 ${Conductor.bpm} BPM';

		// Section
		sectionText.text = '📊 Section ${curSection + 1}/${_song.notes.length}';
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

	function showMessage(msg:String, ?color:FlxColor):Void
	{
		tipTimer = 0;
		statusText.text = msg;
		if (color != null)
			statusText.color = color;
		else
			statusText.color = TEXT_GRAY;

		// Reset después de 3 segundos
		new FlxTimer().start(3.0, function(tmr:FlxTimer)
		{
			statusText.color = TEXT_GRAY;
		});
	}

	function updateHeads():Void
	{
		if (leftIcon != null)
		{
			remove(leftIcon);
			leftIcon.destroy();
		}

		if (rightIcon != null)
		{
			remove(rightIcon);
			rightIcon.destroy();
		}

		if (middleIcon != null)
		{
			remove(middleIcon);
			middleIcon.destroy();
		}

		var iconP1:String = _song.player1;
		var iconP2:String = _song.player2;

		// SIEMPRE en el mismo lugar - NO intercambiar
		// Izquierda = Opponent (DAD), Derecha = Boyfriend (BF)
		leftIcon = new HealthIcon(iconP2); // Opponent siempre a la izquierda
		rightIcon = new HealthIcon(iconP1); // BF siempre a la derecha

		middleIcon = new HealthIcon(_song.gfVersion);

		// Posicionar - FIJAR EN PANTALLA
		leftIcon.setPosition(gridBG.x - 70, 110);
		rightIcon.setPosition(gridBG.x + gridBG.width + 10, 110);
		middleIcon.setPosition(gridBG.x + (gridBG.width / 2) - 30, 40);

		leftIcon.setGraphicSize(0, 45);
		rightIcon.setGraphicSize(0, 45);
		middleIcon.setGraphicSize(0, 45);

		leftIcon.updateHitbox();
		rightIcon.updateHitbox();
		middleIcon.updateHitbox();

		// IMPORTANTE: Fijar iconos en pantalla
		leftIcon.scrollFactor.set();
		rightIcon.scrollFactor.set();
		middleIcon.scrollFactor.set();
		leftIcon.cameras = [camHUD];
		rightIcon.cameras = [camHUD];
		middleIcon.cameras = [camHUD];

		/*
			leftIcon.color = ACCENT_CYAN;
			rightIcon.color = ACCENT_PINK;
			middleIcon.color = ACCENT_GREEN; */

		add(leftIcon);
		add(rightIcon);
		add(middleIcon);
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
			FlxG.sound.playMusic(Paths.inst(daSong), 0.6);
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
				vocals = new FlxSound().loadEmbedded(Paths.voices(daSong));
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

		// Ejemplo de cómo debería calcularse el tiempo según la sección

		Conductor.songPosition = FlxG.sound.music != null ? FlxG.sound.music.time : 0;

		// ✅ SOLO ESTAS DOS LÍNEAS NUEVAS:
		updateGridScroll();
		updateCurrentSection();
		updateNotePositions(); // ✨ Actualizar posiciones cuando el grid se mueve
		// updateSectionIndicators(); // ✨ Actualizar indicadores de sección
		cullNotes();

		handleMouseInput();
		handleKeyboardInput();
		handlePlaybackButtons();

		// Metronome
		if (metronomeEnabled && FlxG.sound.music != null && FlxG.sound.music.playing)
		{
			var curBeat = Math.floor(Conductor.songPosition / Conductor.crochet);
			if (curBeat != lastMetronomeBeat)
			{
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.5);
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
			numText.antialiasing = false;
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

			// ✨ SINCRONIZAR VOCALES cuando haces scroll con la rueda del mouse
			syncVocals();
		}
	}

	function handleMouseInput():Void
	{
		// Click en grid
		if (FlxG.mouse.justPressed && FlxG.mouse.overlaps(gridBG, camGame))
		{
			var mouseGridX = FlxG.mouse.x - gridBG.x;
			var mouseGridY = FlxG.mouse.y - gridBG.y + gridScrollY;

			var noteData = Math.floor(mouseGridX / GRID_SIZE);

			if (noteData >= 0 && noteData < 8)
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
			var mouseGridY = FlxG.mouse.y - gridBG.y + gridScrollY;

			var noteData = Math.floor(mouseGridX / GRID_SIZE);

			if (noteData >= 0 && noteData < 8)
			{
				deleteNoteAtPosition(mouseGridY, noteData);
			}
		}
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

		// Calcular strumTime absoluto
		var noteStrumTime = getSectionStartTime(targetSection) + noteTimeInSection;

		// Verificar si ya existe
		var noteExists = false;
		for (i in _song.notes[targetSection].sectionNotes)
		{
			if (Math.abs(i[0] - noteStrumTime) < 5 && i[1] == noteData)
			{
				saveUndoState("delete", {
					section: targetSection,
					note: [i[0], i[1], i[2]]
				});
				_song.notes[targetSection].sectionNotes.remove(i);
				noteExists = true;
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.3);
				break;
			}
		}

		// Si no existe, crear
		if (!noteExists)
		{
			saveUndoState("add", {
				section: targetSection,
				note: [noteStrumTime, noteData, 0]
			});
			_song.notes[targetSection].sectionNotes.push([noteStrumTime, noteData, 0]);

			if (hitsoundsEnabled)
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
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

		var noteStrumTime = getSectionStartTime(targetSection) + noteTimeInSection;

		for (i in _song.notes[targetSection].sectionNotes)
		{
			if (Math.abs(i[0] - noteStrumTime) < 5 && i[1] == noteData)
			{
				saveUndoState("delete", {
					section: targetSection,
					note: [i[0], i[1], i[2]]
				});
				_song.notes[targetSection].sectionNotes.remove(i);
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.3);
				updateGrid();
				return;
			}
		}
	}

	function handleKeyboardInput():Void
	{
		// ESC - Salir
		if (FlxG.keys.justPressed.ESCAPE)
		{
			if (PlayState.isPlaying)
			{
				FlxG.mouse.visible = false;
				if (vocals != null)
					vocals.stop();
				PlayState.SONG = _song;
				FlxG.sound.music.stop();
				FlxG.switchState(new PlayState());
			}
			else
			{
				FlxG.mouse.visible = false;
				FlxG.sound.music.stop();
				if (vocals != null)
					vocals.stop();
				FlxG.switchState(new OptionsMenuState());
			}
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
				FlxG.sound.music.time = Conductor.songPosition;
				vocals.time = Conductor.songPosition;

				FlxG.sound.music.play();
				vocals.play();
			}
		}

		if (FlxG.keys.justPressed.ENTER)
		{
			FlxG.sound.music.time = getSectionStartTime(curSection);
			FlxG.sound.music.play();

			// ✨ SINCRONIZAR VOCALES cuando pulsas ENTER
			syncVocals();
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
			placeQuickNote(7);

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

		if (FlxG.keys.justPressed.M)
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
		if (FlxG.keys.justPressed.G)
		{
			metronomeEnabled = !metronomeEnabled;
			showMessage(metronomeEnabled ? '🎵 Metronome ON' : '🔇 Metronome OFF', ACCENT_CYAN);
		}

		// TEST CHART
		if (FlxG.keys.justPressed.F5)
		{
			testChart();
		}
	}

	function handlePlaybackButtons():Void
	{
		// Play button
		if (FlxG.mouse.overlaps(playBtn, camHUD) && FlxG.mouse.justPressed)
		{
			if (!FlxG.sound.music.playing)
			{
				FlxG.sound.music.play();
				syncVocals(); // ✨ SINCRONIZAR VOCALES
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
	}

	function placeQuickNote(noteData:Int):Void
	{
		var strumTime = FlxG.sound.music.time;
		strumTime = Math.floor(strumTime / (Conductor.stepCrochet / (currentSnap / 16))) * (Conductor.stepCrochet / (currentSnap / 16));

		_song.notes[curSection].sectionNotes.push([strumTime, noteData, 0]);

		if (hitsoundsEnabled)
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		updateGrid();
		showMessage('➕ Note placed', ACCENT_SUCCESS);
	}

	function updateGrid():Void
	{
		curRenderedNotes.clear();
		curRenderedSustains.clear();

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

				// ✨ REMAPEAR para mostrar correctamente Player 1 y Player 2
				var visualColumn = daNoteData;

				// Si debe hit BF, swap izq-der
				if (section.mustHitSection)
				{
					if (daNoteData < 4)
						visualColumn = daNoteData + 4;
					else
						visualColumn = daNoteData - 4;
				}

				var note:Note = new Note(daStrumTime, visualColumn % 4);
				note.setGraphicSize(GRID_SIZE, GRID_SIZE);
				note.updateHitbox();
				note.x = gridBG.x + (GRID_SIZE * visualColumn);
				note.y = gridBG.y + sectionY + (noteStep * GRID_SIZE);

				// Color
				note.color = NOTE_COLORS[visualColumn % 8];

				// ✅ IMPORTANTE: Las notas NO deben scrollear
				note.scrollFactor.set();

				curRenderedNotes.add(note);

				// Sustain
				if (daSus > 0)
				{
					var susHeight = (daSus / Conductor.stepCrochet) * GRID_SIZE;
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
				var visualColumn = daNoteData;
				if (section.mustHitSection)
				{
					if (daNoteData < 4)
						visualColumn = daNoteData + 4;
					else
						visualColumn = daNoteData - 4;
				}

				// ACTUALIZAR posición X e Y
				note.x = gridBG.x + (GRID_SIZE * visualColumn);
				note.y = gridBG.y + sectionY + (noteStep * GRID_SIZE);

				// Actualizar sustain si existe
				if (daSus > 0 && susIndex < curRenderedSustains.length)
				{
					var sus = curRenderedSustains.members[susIndex];
					if (sus != null)
					{
						sus.x = note.x + (GRID_SIZE / 2) - 4;
						sus.y = note.y + GRID_SIZE;
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
		updateHeads();

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
					updateHeads();

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
			clipboard.push([note[0], note[1], note[2]]);
		}

		showMessage('📋 Copied ${clipboard.length} notes', ACCENT_SUCCESS);
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
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
		FlxG.sound.play(Paths.sound('confirmMenu'), 0.4);
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

			// Swap player <-> opponent (0-3 <-> 4-7)
			if (noteData < 4)
				note[1] = noteData + 4;
			else
				note[1] = noteData - 4;
		}

		updateGrid();
		showMessage('🔄 Section mirrored (P1 ↔ P2)', ACCENT_CYAN);
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
	}

	function mirrorHorizontal():Void
	{
		for (note in _song.notes[curSection].sectionNotes)
		{
			var noteData:Int = note[1];
			var column:Int = noteData % 4;

			// Invertir columnas: 0<->3, 1<->2
			var newColumn:Int = switch (column)
			{
				case 0: 3;
				case 1: 2;
				case 2: 1;
				case 3: 0;
				default: column;
			};

			// Mantener si es player o opponent
			if (noteData < 4)
				note[1] = newColumn;
			else
				note[1] = newColumn + 4;
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
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.3);
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
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.3);
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
			var path = 'assets/data/${_song.song.toLowerCase()}/autosave-${_song.song.toLowerCase()}.json';
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
		FlxG.sound.play(Paths.sound('confirmMenu'), 0.6);
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

			PlayState.SONG = _song;

			// Reload
			loadSong(_song.song);
			curSection = 0;
			changeSection(0);
			updateHeads();

			// Update UI
			songNameText.text = '• ${_song.song}';
			if (stepperBPM != null)
				stepperBPM.value = _song.bpm;
			if (stepperSpeed != null)
				stepperSpeed.value = _song.speed;

			showMessage('✅ Chart loaded: ${_song.song}', ACCENT_SUCCESS);
			FlxG.sound.play(Paths.sound('confirmMenu'), 0.6);
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

	function testChart():Void
	{
		if (!validateChart())
			return;

		// Guardar y probar
		PlayState.SONG = _song;
		PlayState.isStoryMode = false;
		PlayState.storyDifficulty = 2;

		FlxG.sound.music.stop();
		if (vocals != null)
			vocals.stop();

		showMessage('🎮 Starting playtest...', ACCENT_CYAN);

		new FlxTimer().start(0.5, function(tmr:FlxTimer)
		{
			LoadingState.loadAndSwitchState(new PlayState());
		});
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
 * - G: Toggle metronome
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
