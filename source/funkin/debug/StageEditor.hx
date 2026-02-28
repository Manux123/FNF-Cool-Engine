package funkin.debug;

import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.addons.ui.FlxUI;
import flixel.addons.ui.FlxUICheckBox;
import flixel.addons.ui.FlxUIDropDownMenu;
import flixel.addons.ui.FlxUIInputText;
import flixel.addons.ui.FlxUINumericStepper;
import flixel.addons.ui.FlxUITabMenu;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import funkin.gameplay.objects.character.Character;
import funkin.gameplay.objects.stages.Stage;
import funkin.gameplay.objects.stages.Stage.StageAnimation;
import funkin.gameplay.objects.stages.Stage.StageData;
import funkin.gameplay.objects.stages.Stage.StageElement;
import funkin.gameplay.PlayState;
import funkin.transitions.StateTransition;
import haxe.Json;
import mods.ModManager;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.net.FileReference;
#if sys
import sys.FileSystem;
import sys.io.File;
#end
import funkin.debug.themes.EditorTheme;
import funkin.debug.themes.ThemePickerSubState;

using StringTools;

// ── Private helpers ───────────────────────────────────────────────────────────

/** Data stored per visible layer row for click detection. */
private typedef LayerHit =
{
	x:Float, // left edge of clickable zone (screen coords)
	w:Int, // width of clickable zone
	y:Float,
	h:Int, // height of clickable zone
	idx:Int, // element index in stageData.elements (-1 = char row)
	charId:String, // "bf" | "gf" | "dad" | null
	zone:String // "row" | "eye" | "up" | "down" | "del" | "char" | "add_element"
}

/** Simple fixed-size button for the toolbar / layer panel. */
private class MiniBtn extends FlxSprite
{
	public var label:FlxText;
	public var onClick:Void->Void;

	public function new(x:Float, y:Float, w:Int, h:Int, txt:String, color:Int, txtColor:Int, ?cb:Void->Void)
	{
		super(x, y);
		makeGraphic(w, h, color);
		onClick = cb;
		label = new FlxText(x, y, w, txt, 11);
		label.setFormat(Paths.font('vcr.ttf'), 11, txtColor, CENTER);
		label.scrollFactor.set();
	}
}

// ─────────────────────────────────────────────────────────────────────────────
//  StageEditor
// ─────────────────────────────────────────────────────────────────────────────

class StageEditor extends funkin.states.MusicBeatState
{
	// ── Layout constants ──────────────────────────────────────────────────────
	static inline final TITLE_H:Int = 34;
	static inline final TOOLBAR_H:Int = 40;
	static inline final TOP_H:Int = TITLE_H + TOOLBAR_H;
	static inline final STATUS_H:Int = 24;
	static inline final LEFT_W:Int = 252;
	static inline final RIGHT_W:Int = 282;
	static inline final ROW_H:Int = 26;
	static inline final ANIM_ROW_H:Int = 22;
	static inline final MAX_VISIBLE_LAYERS:Int = 18;

	// ── Cameras ───────────────────────────────────────────────────────────────
	var camGame:FlxCamera;
	var camHUD:FlxCamera;
	var camUI:FlxCamera; // cámara invisible en cameras[0]: zoom siempre 1 → FlxUI calcula bien los clicks
	var camZoom:Float = 0.75;
	var camTargetX:Float = 0;
	var camTargetY:Float = 0;

	// ── Editor state ──────────────────────────────────────────────────────────
	var stageData:StageData;
	var currentFilePath:String = '';
	var hasUnsavedChanges:Bool = false;
	/** True once stageData has been populated from disk or from loadJSON.
	 *  When true, reloadStageView uses __fromData__ (in-memory) instead of disk. */
	var _stageDataReady:Bool = false;
	var selectedIdx:Int = -1;
	var selectedCharId:String = null;
	var history:Array<String> = [];
	var historyIndex:Int = -1;
	var clipboard:Dynamic = null;
	var layerScrollStart:Int = 0;
	var animSelIdx:Int = 0;

	// ── Canvas objects (camGame) ──────────────────────────────────────────────
	var stage:Stage;
	var elementSprites:Map<String, FlxSprite> = new Map();
	/** Group containing aboveChars:true sprites — rendered ABOVE characters. */
	var stageAboveGroup:FlxTypedGroup<FlxBasic>;
	var charGroup:FlxTypedGroup<Character>;
	var characters:Map<String, Character> = new Map();
	var gridSprite:FlxSprite;
	var selBox:FlxSprite;
	var charLabels:FlxTypedGroup<FlxText>;

	/** Cached selection-box pixel dimensions – avoids rebuilding BitmapData every frame. */
	var _selBoxW:Int = 0;
	var _selBoxH:Int = 0;

	// ── HUD: title + toolbar + status ────────────────────────────────────────
	var titleText:FlxText;
	var unsavedDot:FlxText;
	var statusText:FlxText;
	var coordText:FlxText;
	var zoomText:FlxText;
	var modBadge:FlxText;

	// ── HUD: left panel (layer list) ─────────────────────────────────────────
	var layerPanelBg:FlxSprite;
	var layerRowsGroup:FlxTypedGroup<FlxSprite>;
	var layerTextsGroup:FlxTypedGroup<FlxText>;
	var layerHitData:Array<LayerHit> = [];
	var layerHoverIdx:Int = -1;

	// ── HUD: right panel (FlxUITabMenu) ──────────────────────────────────────
	var rightPanel:FlxUITabMenu;

	// Element tab widgets
	var elemNameInput:FlxUIInputText;
	var elemAssetInput:FlxUIInputText;
	var elemTypeDropdown:FlxUIDropDownMenu;
	var elemXStepper:FlxUINumericStepper;
	var elemYStepper:FlxUINumericStepper;
	var elemScaleXStepper:FlxUINumericStepper;
	var elemScaleYStepper:FlxUINumericStepper;
	var elemScrollXStepper:FlxUINumericStepper;
	var elemScrollYStepper:FlxUINumericStepper;
	var elemAlphaStepper:FlxUINumericStepper;
	var elemZIndexStepper:FlxUINumericStepper;
	var elemFlipXCheck:FlxUICheckBox;
	var elemFlipYCheck:FlxUICheckBox;
	var elemAntialiasingCheck:FlxUICheckBox;
	var elemVisibleCheck:FlxUICheckBox;
	var elemAboveCharsCheck:FlxUICheckBox;
	var elemColorInput:FlxUIInputText;

	// Animations tab widgets
	var animNameInput:FlxUIInputText;
	var animPrefixInput:FlxUIInputText;
	var animFPSStepper:FlxUINumericStepper;
	var animLoopCheck:FlxUICheckBox;
	var animIndicesInput:FlxUIInputText;
	var animFirstInput:FlxUIInputText;
	var animListBg:FlxTypedGroup<FlxSprite>;
	var animListText:FlxTypedGroup<FlxText>;
	var animHitData:Array<{y:Float, idx:Int}> = [];

	// Stage tab widgets
	var stageNameInput:FlxUIInputText;
	var stageZoomStepper:FlxUINumericStepper;
	var stagePixelCheck:FlxUICheckBox;
	var stageHideGFCheck:FlxUICheckBox;

	// Chars tab widgets
	var bfXStepper:FlxUINumericStepper;
	var bfYStepper:FlxUINumericStepper;
	var gfXStepper:FlxUINumericStepper;
	var gfYStepper:FlxUINumericStepper;
	var dadXStepper:FlxUINumericStepper;
	var dadYStepper:FlxUINumericStepper;
	var camBFXStepper:FlxUINumericStepper;
	var camBFYStepper:FlxUINumericStepper;
	var camDadXStepper:FlxUINumericStepper;
	var camDadYStepper:FlxUINumericStepper;
	var gfVersionInput:FlxUIInputText;

	// Shaders tab widgets
	var stageShaderInput:FlxUIInputText;
	var elemShaderInput:FlxUIInputText;

	// ── Drag ─────────────────────────────────────────────────────────────────
	var isDraggingEl:Bool = false;
	var isDraggingChar:Bool = false;
	var dragCharId:String = null;
	var dragStart:FlxPoint;
	var dragObjStart:FlxPoint;
	var isDraggingCam:Bool = false;
	var dragCamStart:FlxPoint;
	var dragCamScrollStart:FlxPoint;

	// ── File reference ────────────────────────────────────────────────────────
	var _fileRef:FileReference;

	// ── Animation list visibility (managed at state level, not inside FlxUI tab) ──
	var _animTabVisible:Bool = false;

	// ─────────────────────────────────────────────────────────────────────────
	// LIFECYCLE
	// ─────────────────────────────────────────────────────────────────────────

	override public function create():Void
	{
		super.create();

		// Load theme
		EditorTheme.load();
		var T = EditorTheme.current;

		FlxG.mouse.visible = true;
		FlxG.sound.playMusic(Paths.music('chartEditorLoop/chartEditorLoop'), 0.6);

		// ── Cameras ───────────────────────────────────────────────────────────
		camGame = new FlxCamera();
		camGame.bgColor = T.bgDark;
		camHUD = new FlxCamera();
		camHUD.bgColor.alpha = 0;

		// Igual que AnimationDebug: camUI es una cámara transparente y vacía
		// que ocupa cameras[0] (= FlxG.camera). FlxUI usa cameras[0] para
		// calcular las posiciones de click. Al tener zoom=1 fijo, los inputs,
		// steppers y checkboxes responden correctamente sin importar el zoom
		// del canvas. camGame y camHUD renderizan encima de ella.
		camUI = new FlxCamera();
		camUI.bgColor.alpha = 0;

		FlxG.cameras.reset(camUI);           // cameras[0] → FlxG.camera = camUI (zoom 1 fijo)
		FlxG.cameras.add(camGame, false);    // canvas, encima de camUI
		FlxG.cameras.add(camHUD,  false);    // HUD, encima de todo

		camGame.zoom = camZoom;

		dragStart = FlxPoint.get();
		dragObjStart = FlxPoint.get();
		dragCamStart = FlxPoint.get();
		dragCamScrollStart = FlxPoint.get();

		// ── Default stage data ────────────────────────────────────────────────
		var songData = PlayState.SONG;
		stageData = {
			name: songData != null ? (songData.stage ?? 'stage') : 'stage',
			defaultZoom: 0.9,
			isPixelStage: false,
			elements: [],
			gfVersion: songData != null ? (songData.gfVersion ?? 'gf') : 'gf',
			boyfriendPosition: [770.0, 450.0],
			dadPosition: [100.0, 100.0],
			gfPosition: [400.0, 130.0],
			cameraBoyfriend: [0.0, 0.0],
			cameraDad: [0.0, 0.0],
			hideGirlfriend: false,
			scripts: []
		};

		// ── Build everything ──────────────────────────────────────────────────
		buildCanvas();
		buildGrid();
		loadStageIntoCanvas();
		buildUI();
		buildLayerPanel();
		buildRightPanel();
		buildSelectionBox();
		saveHistory();

		// Camera start position
		camTargetX = FlxG.width * 0.5;
		camTargetY = FlxG.height * 0.5;
		camGame.scroll.x = camTargetX - FlxG.width * 0.5;
		camGame.scroll.y = camTargetY - FlxG.height * 0.5;
	}

	// ─────────────────────────────────────────────────────────────────────────
	// CANVAS SETUP
	// ─────────────────────────────────────────────────────────────────────────

	function buildCanvas():Void
	{
		var canvasBg = new FlxSprite().makeGraphic(FlxG.width * 4, FlxG.height * 4, EditorTheme.current.bgDark);
		canvasBg.x = -FlxG.width * 1.5;
		canvasBg.y = -FlxG.height * 1.5;
		canvasBg.cameras = [camGame];
		add(canvasBg);
	}

	function buildGrid():Void
	{
		var gs = 64;
		var gw = 2560;
		var gh = 1440;

		gridSprite = new FlxSprite(-320, -180);
		gridSprite.makeGraphic(gw, gh, FlxColor.TRANSPARENT, true);

		var pix = gridSprite.pixels;
		var gridLineColor = 0x22FFFFFF;

		// Vertical lines
		var x = 0;
		while (x < gw)
		{
			for (py in 0...gh)
				pix.setPixel32(x, py, gridLineColor);
			x += gs;
		}
		// Horizontal lines
		var y = 0;
		while (y < gh)
		{
			for (px in 0...gw)
				pix.setPixel32(px, y, gridLineColor);
			y += gs;
		}
		// Center axes (brighter)
		var cx = gw >> 1;
		var cy = gh >> 1;
		for (py in 0...gh)
			pix.setPixel32(cx, py, 0x55FFFFFF);
		for (px in 0...gw)
			pix.setPixel32(px, cy, 0x55FFFFFF);

		gridSprite.cameras = [camGame];
		gridSprite.scrollFactor.set(1, 1);
		add(gridSprite);
	}

	function loadStageIntoCanvas():Void
	{
		// ── Remove previous canvas objects ────────────────────────────────────
		if (stage != null)
		{
			// stageAboveGroup is stage.aboveCharsGroup — stage.destroy() cleans it up.
			// We only need to remove it from the FlxState render list first.
			if (stageAboveGroup != null)
			{
				remove(stageAboveGroup, true);
				stageAboveGroup = null;
			}
			remove(stage);
			stage.destroy();
			stage = null;
		}
		else if (stageAboveGroup != null)
		{
			remove(stageAboveGroup, true);
			stageAboveGroup = null;
		}
		if (charGroup != null)
		{
			remove(charGroup);
			charGroup.destroy();
			charGroup = null;
		}
		if (charLabels != null)
		{
			remove(charLabels);
			charLabels.destroy();
			charLabels = null;
		}

		elementSprites.clear();
		characters.clear();

		// ── Build stage: from disk on first load, from memory on subsequent reloads ──
		//
		// • _stageDataReady == false  →  first launch or fresh open: load from disk so
		//   the user sees the actual stage assets immediately.
		//   We capture stageData from the loaded Stage and mark the flag true.
		//
		// • _stageDataReady == true   →  the user has already loaded/edited data;
		//   use __fromData__ so in-memory changes (aboveChars, positions, etc.)
		//   are reflected instantly without needing to save first.
		try
		{
			if (!_stageDataReady)
			{
				// ── First load: read from disk ──────────────────────────────────
				stage = new Stage(stageData.name);
				if (stage.stageData != null)
				{
					stageData = stage.stageData;   // safe: nothing in memory yet
					_stageDataReady = true;
				}
			}
			else
			{
				// ── Subsequent reloads: build from in-memory stageData ───────────
				// __fromData__ sentinel skips loadStage() / disk I/O entirely.
				stage = new Stage('__fromData__');
				stage.curStage  = stageData.name ?? 'stage';
				stage.stageData = stageData;
				stage.buildStage();  // routes aboveChars:true → stage.aboveCharsGroup
			}

			stage.cameras = [camGame];
			// FlxTypedGroup.cameras doesn't auto-cascade to existing members
			for (obj in stage.members)
				if (obj != null) obj.cameras = [camGame];
			add(stage);

			// Map all element sprites so the editor can select/drag/highlight them
			for (name => spr in stage.elements)
				elementSprites.set(name, spr);
			for (name => grp in stage.groups)
				if (grp.length > 0 && grp.members[0] != null)
					elementSprites.set(name, grp.members[0]);
			for (name => spr in stage.customClasses)
				elementSprites.set(name, spr);
		}
		catch (e:Dynamic)
		{
			trace('[StageEditor] Stage build error: $e');
			stage = null;
		}

		// ── Characters ────────────────────────────────────────────────────────
		charGroup  = new FlxTypedGroup<Character>();
		charLabels = new FlxTypedGroup<FlxText>();
		charGroup.cameras  = [camGame];
		charLabels.cameras = [camGame];
		add(charGroup);
		add(charLabels);

		// ── Above-chars group ─────────────────────────────────────────────────
		// buildStage() already placed aboveChars:true elements into
		// stage.aboveCharsGroup. We add that group HERE — after charGroup —
		// so those sprites render on top of all characters in the preview.
		// We keep a plain reference; stage.destroy() is responsible for cleanup.
		if (stage != null && stage.aboveCharsGroup != null && stage.aboveCharsGroup.length > 0)
		{
			stageAboveGroup = stage.aboveCharsGroup;
			stageAboveGroup.cameras = [camGame];
			// FlxTypedGroup.cameras doesn't cascade to existing members — set each one
			for (obj in stageAboveGroup.members)
				if (obj != null)
					obj.cameras = [camGame];
			add(stageAboveGroup);
		}
		else
		{
			stageAboveGroup = null;
		}

		loadCharacters();
	}

	function loadCharacters():Void
	{
		// Clear existing
		for (spr in charGroup.members)
			if (spr != null)
				spr.destroy();
		charGroup.clear();
		for (t in charLabels.members)
			if (t != null)
				t.destroy();
		charLabels.clear();
		characters.clear();

		var songData = PlayState.SONG;
		var p1 = songData != null ? (songData.player1 ?? 'bf') : 'bf';
		var p2 = songData != null ? (songData.player2 ?? 'dad') : 'dad';
		var gfVer = stageData.gfVersion ?? (songData != null ? (songData.gfVersion ?? 'gf') : 'gf');

		var bfPos = stageData.boyfriendPosition ?? [770.0, 450.0];
		var dadPos = stageData.dadPosition ?? [100.0, 100.0];
		var gfPos = stageData.gfPosition ?? [400.0, 130.0];

		function addChar(id:String, name:String, x:Float, y:Float, isPlayer:Bool, label:String):Void
		{
			try
			{
				var c = new Character(x, y, name, isPlayer);
				c.alpha = 0.85;
				charGroup.add(c);
				characters.set(id, c);

				var lbl = new FlxText(x, y - 22, 200, label, 10);
				lbl.setFormat(Paths.font('vcr.ttf'), 10, id == 'bf' ? 0xFF00D9FF : (id == 'gf' ? 0xFFFF88FF : 0xFFFFAA00), LEFT);
				charLabels.add(lbl);
			}
			catch (e:Dynamic)
			{
				trace('[StageEditor] Char load error ($id: $name): $e');
			}
		}

		addChar('dad', p2, dadPos[0], dadPos[1], false, 'DAD (' + p2 + ')');
		if (!(stageData.hideGirlfriend == true))
			addChar('gf', gfVer, gfPos[0], gfPos[1], false, 'GF (' + gfVer + ')');
		addChar('bf', p1, bfPos[0], bfPos[1], true, 'BF (' + p1 + ')');
	}

	function buildSelectionBox():Void
	{
		selBox = new FlxSprite();
		selBox.makeGraphic(1, 1, FlxColor.TRANSPARENT);
		selBox.visible = false;
		selBox.cameras = [camGame];
		add(selBox);
	}

	// ─────────────────────────────────────────────────────────────────────────
	// HUD SETUP — TITLE / TOOLBAR / STATUS
	// ─────────────────────────────────────────────────────────────────────────

	function buildUI():Void
	{
		var T = EditorTheme.current;

		// Title bar
		var titleBg = new FlxSprite().makeGraphic(FlxG.width, TITLE_H, T.bgPanelAlt);
		titleBg.cameras = [camHUD];
		titleBg.scrollFactor.set();
		add(titleBg);

		var titleBorder = new FlxSprite(0, TITLE_H - 2).makeGraphic(FlxG.width, 2, T.borderColor);
		titleBorder.cameras = [camHUD];
		titleBorder.scrollFactor.set();
		titleBorder.alpha = 0.6;
		add(titleBorder);

		titleText = new FlxText(10, 6, 0, '\u26AA  STAGE EDITOR  \u2022  ' + stageData.name, 15);
		titleText.setFormat(Paths.font('vcr.ttf'), 15, T.accent, LEFT, OUTLINE, FlxColor.BLACK);
		titleText.cameras = [camHUD];
		titleText.scrollFactor.set();
		add(titleText);

		unsavedDot = new FlxText(0, 8, 0, '  [UNSAVED]', 11);
		unsavedDot.setFormat(Paths.font('vcr.ttf'), 11, T.warning, LEFT);
		unsavedDot.visible = false;
		unsavedDot.cameras = [camHUD];
		unsavedDot.scrollFactor.set();
		add(unsavedDot);

		// Toolbar
		var toolbarBg = new FlxSprite(0, TITLE_H).makeGraphic(FlxG.width, TOOLBAR_H, T.bgPanel);
		toolbarBg.cameras = [camHUD];
		toolbarBg.scrollFactor.set();
		add(toolbarBg);

		var toolbarBorder = new FlxSprite(0, TOP_H - 1).makeGraphic(FlxG.width, 1, T.borderColor);
		toolbarBorder.cameras = [camHUD];
		toolbarBorder.scrollFactor.set();
		toolbarBorder.alpha = 0.4;
		add(toolbarBorder);

		buildToolbarButtons();

		// Status bar
		var statusBg = new FlxSprite(0, FlxG.height - STATUS_H).makeGraphic(FlxG.width, STATUS_H, T.bgPanelAlt);
		statusBg.cameras = [camHUD];
		statusBg.scrollFactor.set();
		add(statusBg);

		var statusBorder = new FlxSprite(0, FlxG.height - STATUS_H).makeGraphic(FlxG.width, 1, T.borderColor);
		statusBorder.alpha = 0.4;
		statusBorder.cameras = [camHUD];
		statusBorder.scrollFactor.set();
		add(statusBorder);

		statusText = new FlxText(8, FlxG.height - STATUS_H + 5, 400, 'Stage Editor ready', 10);
		statusText.setFormat(Paths.font('vcr.ttf'), 10, T.textSecondary, LEFT);
		statusText.cameras = [camHUD];
		statusText.scrollFactor.set();
		add(statusText);

		modBadge = new FlxText(FlxG.width - 320, FlxG.height - STATUS_H + 5, 150, _modLabel(), 10);
		modBadge.setFormat(Paths.font('vcr.ttf'), 10, ModManager.isActive() ? T.success : T.textDim, RIGHT);
		modBadge.cameras = [camHUD];
		modBadge.scrollFactor.set();
		add(modBadge);

		coordText = new FlxText(FlxG.width - 160, FlxG.height - STATUS_H + 5, 80, 'x:0 y:0', 10);
		coordText.setFormat(Paths.font('vcr.ttf'), 10, T.textSecondary, RIGHT);
		coordText.cameras = [camHUD];
		coordText.scrollFactor.set();
		add(coordText);

		zoomText = new FlxText(FlxG.width - 75, FlxG.height - STATUS_H + 5, 65, 'Zoom: 75%', 10);
		zoomText.setFormat(Paths.font('vcr.ttf'), 10, T.textSecondary, RIGHT);
		zoomText.cameras = [camHUD];
		zoomText.scrollFactor.set();
		add(zoomText);
	}

	function buildToolbarButtons():Void
	{
		var T = EditorTheme.current;
		var by = TITLE_H + 6;

		function toolBtn(x:Float, w:Int, label:String, col:Int, cb:Void->Void):FlxSprite
		{
			var bg = new FlxSprite(x, by).makeGraphic(w, 28, col);
			bg.cameras = [camHUD];
			bg.scrollFactor.set();
			add(bg);
			var txt = new FlxText(x, by + 7, w, label, 10);
			txt.setFormat(Paths.font('vcr.ttf'), 10, T.textPrimary, CENTER);
			txt.cameras = [camHUD];
			txt.scrollFactor.set();
			add(txt);
			// Store callback on bg tag field (via a simple wrapper Map)
			_toolBtns.set(bg, cb);
			return bg;
		}

		toolBtn(LEFT_W + 4, 82, '+ ADD ELEMENT', T.bgHover, openAddElementDialog);
		toolBtn(LEFT_W + 90, 58, 'LOAD', T.bgPanelAlt, loadJSON);
		toolBtn(LEFT_W + 152, 58, 'SAVE', 0xFF003A20, saveJSON);
		toolBtn(LEFT_W + 214, 76, 'SAVE TO MOD', 0xFF2A1A00, saveToMod);

		toolBtn(FlxG.width - RIGHT_W - 4 - 166, 40, 'UNDO', T.bgPanelAlt, undo);
		toolBtn(FlxG.width - RIGHT_W - 4 - 122, 40, 'REDO', T.bgPanelAlt, redo);
		toolBtn(FlxG.width - RIGHT_W - 4 - 78, 38, 'COPY', T.bgPanelAlt, copyElement);
		toolBtn(FlxG.width - RIGHT_W - 4 - 36, 36, 'PASTE', T.bgPanelAlt, pasteElement);
		toolBtn(FlxG.width - RIGHT_W - 4, 32, '\u2728', T.bgPanelAlt, () -> openSubState(new ThemePickerSubState()));
	}

	var _toolBtns:Map<FlxSprite, Void->Void> = new Map();

	// ─────────────────────────────────────────────────────────────────────────
	// LAYER PANEL (LEFT)
	// ─────────────────────────────────────────────────────────────────────────

	function buildLayerPanel():Void
	{
		var T = EditorTheme.current;
		var panelH = FlxG.height - TOP_H - STATUS_H;

		layerPanelBg = new FlxSprite(0, TOP_H).makeGraphic(LEFT_W, panelH, T.bgPanel);
		layerPanelBg.cameras = [camHUD];
		layerPanelBg.scrollFactor.set();
		add(layerPanelBg);

		// Right border
		var border = new FlxSprite(LEFT_W, TOP_H).makeGraphic(2, panelH, T.borderColor);
		border.alpha = 0.5;
		border.cameras = [camHUD];
		border.scrollFactor.set();
		add(border);

		layerRowsGroup = new FlxTypedGroup<FlxSprite>();
		layerTextsGroup = new FlxTypedGroup<FlxText>();
		layerRowsGroup.cameras = [camHUD];
		layerTextsGroup.cameras = [camHUD];
		add(layerRowsGroup);
		add(layerTextsGroup);

		refreshLayerPanel();
	}

	function refreshLayerPanel():Void
	{
		var T = EditorTheme.current;

		// ── Clear existing rows ───────────────────────────────────────────────
		for (s in layerRowsGroup.members)  if (s != null) s.visible = false;
		for (t in layerTextsGroup.members) if (t != null) t.visible = false;
		layerRowsGroup.clear();
		layerTextsGroup.clear();
		layerHitData = [];

		var rowY = TOP_H + 0.0;

		// ── LAYERS header ─────────────────────────────────────────────────────
		var headerBg = new FlxSprite(0, rowY).makeGraphic(LEFT_W, 28, T.bgPanelAlt);
		headerBg.cameras = [camHUD]; headerBg.scrollFactor.set(); add(headerBg); layerRowsGroup.add(headerBg);
		var headerTxt = new FlxText(10, rowY + 6, 0, '\u25A3 LAYERS', 12);
		headerTxt.setFormat(Paths.font('vcr.ttf'), 12, T.accent, LEFT);
		headerTxt.cameras = [camHUD]; headerTxt.scrollFactor.set(); add(headerTxt); layerTextsGroup.add(headerTxt);

		// [+] button in header
		var addBg = new FlxSprite(LEFT_W - 26, rowY + 4).makeGraphic(22, 20, T.bgHover);
		addBg.cameras = [camHUD]; addBg.scrollFactor.set(); add(addBg); layerRowsGroup.add(addBg);
		var addTxt = new FlxText(LEFT_W - 26, rowY + 5, 22, '+', 12);
		addTxt.setFormat(Paths.font('vcr.ttf'), 12, T.success, CENTER);
		addTxt.cameras = [camHUD]; addTxt.scrollFactor.set(); add(addTxt); layerTextsGroup.add(addTxt);
		layerHitData.push({ x: LEFT_W - 26, w: 22, y: rowY + 4, h: 20, idx: -2, charId: null, zone: 'add_element' });
		rowY += 28;

		// ── Layer rows (top of list = topmost on screen = last in array) ──────
		var elements = stageData.elements;
		var totalRows = elements != null ? elements.length : 0;
		var drawnCount = 0;
		var i = totalRows - 1;
		while (i >= 0)
		{
			if (drawnCount < layerScrollStart) { drawnCount++; i--; continue; }
			if (drawnCount >= layerScrollStart + MAX_VISIBLE_LAYERS) { i--; continue; }
			drawnCount++;

			var elemIdx = i;
			var elem    = elements[elemIdx];
			var isSelected  = (elemIdx == selectedIdx);
			var isVisible   = !(elem.visible == false);
			var isAbove     = (elem.aboveChars == true);

			// Row background — tinted amber if aboveChars
			var rowBgColor = isSelected ? T.rowSelected
				: isAbove ? 0xFF2A1A00          // warm amber tint = above-chars layer
				: (drawnCount % 2 == 0 ? T.rowEven : T.rowOdd);
			var rowBg = new FlxSprite(0, rowY).makeGraphic(LEFT_W, ROW_H, rowBgColor);
			rowBg.cameras = [camHUD]; rowBg.scrollFactor.set(); add(rowBg); layerRowsGroup.add(rowBg);
			layerHitData.push({ x: 0, w: LEFT_W, y: rowY, h: ROW_H, idx: elemIdx, charId: null, zone: 'row' });

			// Eye toggle
			var eyeColor = isVisible ? T.success : T.textDim;
			var eyeTxt = new FlxText(4, rowY + 5, 16, isVisible ? '\u25CF' : '\u2013', 10);
			eyeTxt.setFormat(Paths.font('vcr.ttf'), 10, eyeColor, CENTER);
			eyeTxt.cameras = [camHUD]; eyeTxt.scrollFactor.set(); add(eyeTxt); layerTextsGroup.add(eyeTxt);
			layerHitData.push({ x: 0, w: 22, y: rowY, h: ROW_H, idx: elemIdx, charId: null, zone: 'eye' });

			// Layer name
			var nameStr = elem.name ?? ('elem_' + elemIdx);
			if (nameStr.length > 14) nameStr = nameStr.substr(0, 12) + '..';
			var nameColor = isSelected ? T.accent : (isAbove ? 0xFFFFAA00 : T.textPrimary);
			var nameTxt = new FlxText(22, rowY + 6, 90, nameStr, 10);
			nameTxt.setFormat(Paths.font('vcr.ttf'), 10, nameColor, LEFT);
			nameTxt.cameras = [camHUD]; nameTxt.scrollFactor.set(); add(nameTxt); layerTextsGroup.add(nameTxt);

			// Type badge
			var typeStr = switch (elem.type.toLowerCase()) {
				case 'sprite': 'SPR'; case 'animated': 'ANI'; case 'group': 'GRP';
				case 'custom_class': 'CLS'; case 'custom_class_group': 'CGP'; case 'sound': 'SND';
				default: elem.type.toUpperCase().substr(0, 3);
			}
			var typeBgColor = switch (elem.type.toLowerCase()) {
				case 'animated': T.accentAlt; case 'group', 'custom_class_group': T.warning;
				case 'sound': T.success; default: T.bgHover;
			}
			var typeBg = new FlxSprite(116, rowY + 5).makeGraphic(28, 16, typeBgColor);
			typeBg.cameras = [camHUD]; typeBg.scrollFactor.set(); add(typeBg); layerRowsGroup.add(typeBg);
			var typeTxt = new FlxText(116, rowY + 5, 28, typeStr, 8);
			typeTxt.setFormat(Paths.font('vcr.ttf'), 8, 0xFF000000, CENTER);
			typeTxt.cameras = [camHUD]; typeTxt.scrollFactor.set(); add(typeTxt); layerTextsGroup.add(typeTxt);

			// ▲ Above-Chars toggle — the KEY button for foreground layers
			// Shows "AB" (amber) when enabled, "ab" (dim) when disabled.
			var abBgColor = isAbove ? 0xFFFF8800 : T.bgHover;
			var abBg = new FlxSprite(148, rowY + 4).makeGraphic(20, 18, abBgColor);
			abBg.cameras = [camHUD]; abBg.scrollFactor.set(); add(abBg); layerRowsGroup.add(abBg);
			var abTxt = new FlxText(148, rowY + 5, 20, isAbove ? 'AB' : 'ab', 8);
			abTxt.setFormat(Paths.font('vcr.ttf'), 8, isAbove ? 0xFF000000 : T.textDim, CENTER);
			abTxt.cameras = [camHUD]; abTxt.scrollFactor.set(); add(abTxt); layerTextsGroup.add(abTxt);
			layerHitData.push({ x: 145, w: 26, y: rowY, h: ROW_H, idx: elemIdx, charId: null, zone: 'above' });

			// ▲ Up
			var upBg = new FlxSprite(172, rowY + 4).makeGraphic(16, 18, T.bgHover);
			upBg.cameras = [camHUD]; upBg.scrollFactor.set(); add(upBg); layerRowsGroup.add(upBg);
			var upTxt = new FlxText(172, rowY + 4, 16, '\u25B2', 9);
			upTxt.setFormat(Paths.font('vcr.ttf'), 9, T.textSecondary, CENTER);
			upTxt.cameras = [camHUD]; upTxt.scrollFactor.set(); add(upTxt); layerTextsGroup.add(upTxt);
			layerHitData.push({ x: 169, w: 22, y: rowY, h: ROW_H, idx: elemIdx, charId: null, zone: 'up' });

			// ▼ Down
			var downBg = new FlxSprite(191, rowY + 4).makeGraphic(16, 18, T.bgHover);
			downBg.cameras = [camHUD]; downBg.scrollFactor.set(); add(downBg); layerRowsGroup.add(downBg);
			var downTxt = new FlxText(191, rowY + 4, 16, '\u25BC', 9);
			downTxt.setFormat(Paths.font('vcr.ttf'), 9, T.textSecondary, CENTER);
			downTxt.cameras = [camHUD]; downTxt.scrollFactor.set(); add(downTxt); layerTextsGroup.add(downTxt);
			layerHitData.push({ x: 188, w: 22, y: rowY, h: ROW_H, idx: elemIdx, charId: null, zone: 'down' });

			// ✕ Delete
			var delBg = new FlxSprite(211, rowY + 4).makeGraphic(22, 18, T.bgHover);
			delBg.cameras = [camHUD]; delBg.scrollFactor.set(); add(delBg); layerRowsGroup.add(delBg);
			var delTxt = new FlxText(211, rowY + 5, 22, '\u2715', 9);
			delTxt.setFormat(Paths.font('vcr.ttf'), 9, T.error, CENTER);
			delTxt.cameras = [camHUD]; delTxt.scrollFactor.set(); add(delTxt); layerTextsGroup.add(delTxt);
			layerHitData.push({ x: 208, w: 26, y: rowY, h: ROW_H, idx: elemIdx, charId: null, zone: 'del' });

			// Sprite-loaded indicator dot
			if (elem.name != null && elementSprites.exists(elem.name))
			{
				var dot = new FlxSprite(237, rowY + 9).makeGraphic(6, 6, T.success);
				dot.cameras = [camHUD]; dot.scrollFactor.set(); add(dot); layerRowsGroup.add(dot);
			}

			rowY += ROW_H;
			i--;
		}

		// ── CHARACTERS section ────────────────────────────────────────────────
		rowY += 6;
		var charHeaderBg = new FlxSprite(0, rowY).makeGraphic(LEFT_W, 24, T.bgPanelAlt);
		charHeaderBg.cameras = [camHUD]; charHeaderBg.scrollFactor.set(); add(charHeaderBg); layerRowsGroup.add(charHeaderBg);
		var charHeaderTxt = new FlxText(10, rowY + 5, 0, '\u25B6 CHARACTERS', 11);
		charHeaderTxt.setFormat(Paths.font('vcr.ttf'), 11, T.accentAlt, LEFT);
		charHeaderTxt.cameras = [camHUD]; charHeaderTxt.scrollFactor.set(); add(charHeaderTxt); layerTextsGroup.add(charHeaderTxt);

		// Legend: AB = above chars
		var legendTxt = new FlxText(LEFT_W - 68, rowY + 6, 62, 'AB=above chars', 8);
		legendTxt.setFormat(Paths.font('vcr.ttf'), 8, 0xFFFF8800, RIGHT);
		legendTxt.cameras = [camHUD]; legendTxt.scrollFactor.set(); add(legendTxt); layerTextsGroup.add(legendTxt);
		rowY += 24;

		var charDefs = [
			{id: 'bf',  label: 'BF',  color: 0xFF00D9FF},
			{id: 'gf',  label: 'GF',  color: 0xFFFF88FF},
			{id: 'dad', label: 'Dad', color: 0xFFFFAA00}
		];
		for (cd in charDefs)
		{
			var c = characters.get(cd.id);
			var pos = '---';
			if (c != null) pos = 'x:${Std.int(c.x)}  y:${Std.int(c.y)}';
			var cRowBg = new FlxSprite(0, rowY).makeGraphic(LEFT_W, ROW_H, selectedCharId == cd.id ? T.rowSelected : T.rowOdd);
			cRowBg.cameras = [camHUD]; cRowBg.scrollFactor.set(); add(cRowBg); layerRowsGroup.add(cRowBg);
			layerHitData.push({ x: 0, w: LEFT_W, y: rowY, h: ROW_H, idx: -1, charId: cd.id, zone: 'char' });
			var cLbl = new FlxText(8, rowY + 7, 35, cd.label, 10);
			cLbl.setFormat(Paths.font('vcr.ttf'), 10, cd.color, LEFT);
			cLbl.cameras = [camHUD]; cLbl.scrollFactor.set(); add(cLbl); layerTextsGroup.add(cLbl);
			var cPos = new FlxText(48, rowY + 7, 190, pos, 9);
			cPos.setFormat(Paths.font('vcr.ttf'), 9, T.textSecondary, LEFT);
			cPos.cameras = [camHUD]; cPos.scrollFactor.set(); add(cPos); layerTextsGroup.add(cPos);
			rowY += ROW_H;
		}
	}

	// ─────────────────────────────────────────────────────────────────────────
	// RIGHT PANEL (FlxUITabMenu)
	// ─────────────────────────────────────────────────────────────────────────

	function buildRightPanel():Void
	{
		var T = EditorTheme.current;
		var panelH = FlxG.height - TOP_H - STATUS_H;

		// Panel background
		var rpBg = new FlxSprite(FlxG.width - RIGHT_W, TOP_H).makeGraphic(RIGHT_W, panelH, T.bgPanel);
		rpBg.cameras = [camHUD];
		rpBg.scrollFactor.set();
		add(rpBg);

		var rpBorder = new FlxSprite(FlxG.width - RIGHT_W, TOP_H).makeGraphic(2, panelH, T.borderColor);
		rpBorder.alpha = 0.5;
		rpBorder.cameras = [camHUD];
		rpBorder.scrollFactor.set();
		add(rpBorder);

		// Tab menu
		var tabs = [
			{name: 'Element', label: 'Element'},
			{name: 'Anims', label: 'Anims'},
			{name: 'Stage', label: 'Stage'},
			{name: 'Chars', label: 'Chars'},
			{name: 'Shaders', label: 'Shaders'}
		];

		rightPanel = new FlxUITabMenu(null, tabs, true);
		rightPanel.resize(RIGHT_W - 2, panelH);
		rightPanel.x = FlxG.width - RIGHT_W + 2;
		rightPanel.y = TOP_H;
		rightPanel.scrollFactor.set();
		rightPanel.cameras = [camHUD];
		add(rightPanel);

		buildElementTab();
		buildAnimsTab();
		buildStageTab();
		buildCharsTab();
		buildShadersTab();

		// The animation list groups must be added to the state (not to FlxUI tab,
		// which only accepts FlxSprite). Sprites inside use absolute screen coords + camHUD.
		if (animListBg != null)
		{
			animListBg.cameras = [camHUD];
			add(animListBg);
		}
		if (animListText != null)
		{
			animListText.cameras = [camHUD];
			add(animListText);
		}
	}

	// ── Element Tab ───────────────────────────────────────────────────────────

	function buildElementTab():Void
	{
		var tab = new FlxUI(null, rightPanel);
		tab.name = 'Element';

		var y = 8.0;
		function lbl(text:String, ly:Float):FlxText
		{
			var t = new FlxText(8, ly, 0, text, 10);
			t.color = FlxColor.fromInt(EditorTheme.current.textSecondary);
			tab.add(t);
			return t;
		}
		function sep(sy:Float):FlxSprite
		{
			var s = new FlxSprite(4, sy).makeGraphic(RIGHT_W - 16, 1, EditorTheme.current.borderColor);
			s.alpha = 0.25;
			tab.add(s);
			return s;
		}

		lbl('Name:', y);
		elemNameInput = new FlxUIInputText(8, y + 12, 180, '', 10);
		tab.add(elemNameInput);

		lbl('Type:', y + 32);
		var types = ['sprite', 'animated', 'group', 'custom_class', 'sound'];
		elemTypeDropdown = new FlxUIDropDownMenu(8, y + 44, FlxUIDropDownMenu.makeStrIdLabelArray(types, true), function(sel:String)
		{
			var t = types[Std.parseInt(sel)];
			if (selectedIdx >= 0 && selectedIdx < stageData.elements.length)
				stageData.elements[selectedIdx].type = t;
		});
		tab.add(elemTypeDropdown);

		y += 72;
		lbl('Asset path:', y);
		elemAssetInput = new FlxUIInputText(8, y + 12, RIGHT_W - 60, '', 10);
		tab.add(elemAssetInput);
		var browseBtn = new FlxButton(RIGHT_W - 48, y + 11, 'Browse', browseAsset);
		tab.add(browseBtn);

		y += 36;
		sep(y);
		y += 8;

		lbl('Position  X:', y);
		lbl('Y:', y + 20);
		elemXStepper = new FlxUINumericStepper(8, y + 12, 10, 0, -4000, 4000, 0);
		elemYStepper = new FlxUINumericStepper(130, y + 12, 10, 0, -4000, 4000, 0);
		tab.add(elemXStepper);
		tab.add(elemYStepper);

		y += 34;
		lbl('Scale  X:', y);
		lbl('Y:', y + 20);
		elemScaleXStepper = new FlxUINumericStepper(8, y + 12, 0.1, 1, 0.01, 20, 2);
		elemScaleYStepper = new FlxUINumericStepper(130, y + 12, 0.1, 1, 0.01, 20, 2);
		tab.add(elemScaleXStepper);
		tab.add(elemScaleYStepper);

		y += 34;
		lbl('Scroll Factor  X:', y);
		lbl('Y:', y + 20);
		elemScrollXStepper = new FlxUINumericStepper(8, y + 12, 0.1, 1, 0, 5, 2);
		elemScrollYStepper = new FlxUINumericStepper(130, y + 12, 0.1, 1, 0, 5, 2);
		tab.add(elemScrollXStepper);
		tab.add(elemScrollYStepper);

		y += 34;
		lbl('Alpha:', y);
		elemAlphaStepper = new FlxUINumericStepper(8, y + 12, 0.05, 1, 0, 1, 2);
		tab.add(elemAlphaStepper);

		lbl('Z-Index:', y + 0);
		elemZIndexStepper = new FlxUINumericStepper(130, y + 12, 1, 0, -100, 100, 0);
		tab.add(elemZIndexStepper);

		y += 34;
		lbl('Color (hex):', y);
		elemColorInput = new FlxUIInputText(8, y + 12, 90, '#FFFFFF', 10);
		tab.add(elemColorInput);

		y += 34;
		sep(y);
		y += 6;

		elemFlipXCheck = new FlxUICheckBox(8, y, null, null, 'Flip X', 70);
		elemFlipYCheck = new FlxUICheckBox(90, y, null, null, 'Flip Y', 70);
		elemAntialiasingCheck = new FlxUICheckBox(8, y + 22, null, null, 'Antialiasing', 110);
		elemVisibleCheck = new FlxUICheckBox(130, y + 22, null, null, 'Visible', 80);

		tab.add(elemFlipXCheck);
		tab.add(elemFlipYCheck);
		tab.add(elemAntialiasingCheck);
		tab.add(elemVisibleCheck);

		y += 50;
		sep(y); y += 6;

		// ── Above-characters layer ────────────────────────────────────────────
		// When checked, this element renders ON TOP of characters (like a front
		// camera, light shaft, or bokeh overlay — same as Codename Engine).
		elemAboveCharsCheck = new FlxUICheckBox(8, y, null, null, 'Above Characters  (foreground layer)', RIGHT_W - 24);
		elemAboveCharsCheck.color = 0xFFFFAA00;
		tab.add(elemAboveCharsCheck);

		y += 26;
		var applyBtn = new FlxButton(8, y, 'Apply Changes', applyElementProps);
		tab.add(applyBtn);

		rightPanel.addGroup(tab);
	}

	// ── Animations Tab ────────────────────────────────────────────────────────

	function buildAnimsTab():Void
	{
		var tab = new FlxUI(null, rightPanel);
		tab.name = 'Anims';

		var T = EditorTheme.current;
		var y = 8.0;

		// Animation list (static display area)
		var listBg = new FlxSprite(4, y).makeGraphic(RIGHT_W - 16, 140, T.bgPanelAlt);
		tab.add(listBg);

		animListBg = new FlxTypedGroup<FlxSprite>();
		animListText = new FlxTypedGroup<FlxText>();
		// Groups are added to the state directly in buildRightPanel (FlxUI.add only accepts FlxSprite)

		var addAnimBtn = new FlxButton(4, y + 144, '+ Add Anim', addAnimation);
		var delAnimBtn = new FlxButton(RIGHT_W - 86, y + 144, 'Remove', removeAnimation);
		tab.add(addAnimBtn);
		tab.add(delAnimBtn);

		y += 172;
		var sep = new FlxSprite(4, y).makeGraphic(RIGHT_W - 16, 1, T.borderColor);
		sep.alpha = 0.25;
		tab.add(sep);
		y += 8;

		function lbl(t:String, ly:Float)
		{
			var tx = new FlxText(8, ly, 0, t, 10);
			tx.color = T.textSecondary;
			tab.add(tx);
		}

		lbl('Animation Name:', y);
		animNameInput = new FlxUIInputText(8, y + 12, 180, 'idle', 10);
		tab.add(animNameInput);

		y += 32;
		lbl('XML Prefix:', y);
		animPrefixInput = new FlxUIInputText(8, y + 12, 180, 'idle0', 10);
		tab.add(animPrefixInput);

		y += 32;
		lbl('FPS:', y);
		animFPSStepper = new FlxUINumericStepper(8, y + 12, 1, 24, 1, 120, 0);
		tab.add(animFPSStepper);

		animLoopCheck = new FlxUICheckBox(90, y + 12, null, null, 'Looped', 80);
		tab.add(animLoopCheck);

		y += 34;
		lbl('Indices (e.g. 0,1,2):', y);
		animIndicesInput = new FlxUIInputText(8, y + 12, 180, '', 10);
		tab.add(animIndicesInput);

		y += 32;
		lbl('First Animation:', y);
		animFirstInput = new FlxUIInputText(8, y + 12, 180, 'idle', 10);
		tab.add(animFirstInput);

		y += 32;
		var saveAnimBtn = new FlxButton(8, y, 'Save Anim Data', saveAnimData);
		tab.add(saveAnimBtn);

		rightPanel.addGroup(tab);
	}

	// ── Stage Tab ─────────────────────────────────────────────────────────────

	function buildStageTab():Void
	{
		var tab = new FlxUI(null, rightPanel);
		tab.name = 'Stage';

		var T = EditorTheme.current;
		var y = 8.0;
		function lbl(t:String, ly:Float)
		{
			var tx = new FlxText(8, ly, 0, t, 10);
			tx.color = T.textSecondary;
			tab.add(tx);
		}

		lbl('Stage Name:', y);
		stageNameInput = new FlxUIInputText(8, y + 12, 180, stageData.name, 10);
		tab.add(stageNameInput);

		y += 32;
		lbl('Default Zoom:', y);
		stageZoomStepper = new FlxUINumericStepper(8, y + 12, 0.05, stageData.defaultZoom, 0.1, 5.0, 2);
		tab.add(stageZoomStepper);

		y += 32;
		stagePixelCheck = new FlxUICheckBox(8, y, null, null, 'Pixel Stage', 120);
		stageHideGFCheck = new FlxUICheckBox(8, y + 22, null, null, 'Hide Girlfriend', 130);
		stagePixelCheck.checked = stageData.isPixelStage;
		stageHideGFCheck.checked = stageData.hideGirlfriend ?? false;
		tab.add(stagePixelCheck);
		tab.add(stageHideGFCheck);

		y += 52;
		var applyStageBtn = new FlxButton(8, y, 'Apply Stage Props', applyStageProps);
		tab.add(applyStageBtn);

		y += 30;
		var sep = new FlxSprite(4, y).makeGraphic(RIGHT_W - 16, 1, T.borderColor);
		sep.alpha = 0.25;
		tab.add(sep);
		y += 8;

		lbl('Scripts (one per line):', y);
		y += 14;
		var scriptsInfo = new FlxText(8, y, RIGHT_W - 24,
			(stageData.scripts != null && stageData.scripts.length > 0) ? stageData.scripts.join('\n') : '(none)', 9);
		scriptsInfo.color = T.textDim;
		tab.add(scriptsInfo);

		y += Std.int(scriptsInfo.textField.textHeight) + 8;
		var addScriptBtn = new FlxButton(8, y, '+ Add Script Path', addScript);
		tab.add(addScriptBtn);

		y += 30;
		var reloadBtn = new FlxButton(8, y, 'Reload Stage View', reloadStageView);
		tab.add(reloadBtn);

		rightPanel.addGroup(tab);
	}

	// ── Characters Tab ────────────────────────────────────────────────────────

	function buildCharsTab():Void
	{
		var tab = new FlxUI(null, rightPanel);
		tab.name = 'Chars';

		var T = EditorTheme.current;
		var y = 8.0;

		function sectionHeader(text:String, ly:Float, col:Int):Void
		{
			var bg = new FlxSprite(4, ly).makeGraphic(RIGHT_W - 16, 18, T.bgPanelAlt);
			tab.add(bg);
			var tx = new FlxText(8, ly + 2, 0, text, 10);
			tx.setFormat(Paths.font('vcr.ttf'), 10, col, LEFT);
			tab.add(tx);
		}
		function lbl(t:String, ly:Float)
		{
			var tx = new FlxText(8, ly, 0, t, 9);
			tx.color = T.textSecondary;
			tab.add(tx);
		}

		var bfPos = stageData.boyfriendPosition ?? [770.0, 450.0];
		var gfPos = stageData.gfPosition ?? [400.0, 130.0];
		var dadPos = stageData.dadPosition ?? [100.0, 100.0];
		var camBF = stageData.cameraBoyfriend ?? [0.0, 0.0];
		var camDad = stageData.cameraDad ?? [0.0, 0.0];

		sectionHeader('BOYFRIEND', y, 0xFF00D9FF);
		y += 22;
		lbl('X:', y);
		lbl('Y:', y + 20);
		bfXStepper = new FlxUINumericStepper(16, y + 12, 10, bfPos[0], -2000, 4000, 0);
		bfYStepper = new FlxUINumericStepper(130, y + 12, 10, bfPos[1], -2000, 4000, 0);
		tab.add(bfXStepper);
		tab.add(bfYStepper);
		y += 26;
		lbl('Cam Offset X:', y);
		lbl('Y:', y + 20);
		camBFXStepper = new FlxUINumericStepper(80, y + 12, 10, camBF[0], -500, 500, 0);
		camBFYStepper = new FlxUINumericStepper(165, y + 12, 10, camBF[1], -500, 500, 0);
		tab.add(camBFXStepper);
		tab.add(camBFYStepper);

		y += 34;
		sectionHeader('GIRLFRIEND', y, 0xFFFF88FF);
		y += 22;
		lbl('X:', y);
		lbl('Y:', y + 20);
		gfXStepper = new FlxUINumericStepper(16, y + 12, 10, gfPos[0], -2000, 4000, 0);
		gfYStepper = new FlxUINumericStepper(130, y + 12, 10, gfPos[1], -2000, 4000, 0);
		tab.add(gfXStepper);
		tab.add(gfYStepper);

		lbl('GF Version:', y + 24);
		gfVersionInput = new FlxUIInputText(8, y + 36, 120, stageData.gfVersion ?? 'gf', 10);
		tab.add(gfVersionInput);

		y += 60;
		sectionHeader('DAD / OPPONENT', y, 0xFFFFAA00);
		y += 22;
		lbl('X:', y);
		lbl('Y:', y + 20);
		dadXStepper = new FlxUINumericStepper(16, y + 12, 10, dadPos[0], -2000, 4000, 0);
		dadYStepper = new FlxUINumericStepper(130, y + 12, 10, dadPos[1], -2000, 4000, 0);
		tab.add(dadXStepper);
		tab.add(dadYStepper);
		y += 26;
		lbl('Cam Offset X:', y);
		lbl('Y:', y + 20);
		camDadXStepper = new FlxUINumericStepper(80, y + 12, 10, camDad[0], -500, 500, 0);
		camDadYStepper = new FlxUINumericStepper(165, y + 12, 10, camDad[1], -500, 500, 0);
		tab.add(camDadXStepper);
		tab.add(camDadYStepper);

		y += 36;
		var applyBtn = new FlxButton(8, y, 'Apply + Reload Chars', applyCharProps);
		tab.add(applyBtn);

		rightPanel.addGroup(tab);
	}

	// ── Shaders Tab ───────────────────────────────────────────────────────────

	function buildShadersTab():Void
	{
		var tab = new FlxUI(null, rightPanel);
		tab.name = 'Shaders';

		var T = EditorTheme.current;
		var y = 8.0;

		var info = new FlxText(8, y, RIGHT_W - 20, 'Shaders are stored in the stage\'s JSON file\nand are applied at runtime via scripts.', 10);
		info.color = T.textSecondary;
		tab.add(info);
		y += 40;

		var sep = new FlxSprite(4, y).makeGraphic(RIGHT_W - 16, 1, T.borderColor);
		sep.alpha = 0.25;
		tab.add(sep);
		y += 8;

		var lbl1 = new FlxText(8, y, 0, 'Stage Shader:', 10);
		lbl1.color = T.accent;
		tab.add(lbl1);
		y += 14;
		stageShaderInput = new FlxUIInputText(8, y, 180, '', 10);
		tab.add(stageShaderInput);

		y += 28;
		var applyStageShader = new FlxButton(8, y, 'Set Stage Shader', function()
		{
			var shaderName = stageShaderInput.text.trim();
			if (stageData.scripts == null)
				stageData.scripts = [];
			trace('[StageEditor] Stage shader: $shaderName');
			markUnsaved();
			saveHistory();
		});
		tab.add(applyStageShader);

		y += 34;
		var sep2 = new FlxSprite(4, y).makeGraphic(RIGHT_W - 16, 1, T.borderColor);
		sep2.alpha = 0.25;
		tab.add(sep2);
		y += 8;

		var lbl2 = new FlxText(8, y, 0, 'Selected Element Shader:', 10);
		lbl2.color = T.accentAlt;
		tab.add(lbl2);
		y += 14;
		elemShaderInput = new FlxUIInputText(8, y, 180, '', 10);
		tab.add(elemShaderInput);

		y += 28;
		var applyElemShader = new FlxButton(8, y, 'Set Element Shader', function()
		{
			if (selectedIdx < 0 || selectedIdx >= stageData.elements.length)
				return;
			var shaderName = elemShaderInput.text.trim();
			// Store as a custom property on the element
			if (stageData.elements[selectedIdx].customProperties == null)
				stageData.elements[selectedIdx].customProperties = {};
			Reflect.setField(stageData.elements[selectedIdx].customProperties, 'shader', shaderName);
			markUnsaved();
			saveHistory();
			setStatus('Shader "${shaderName}" assigned to selected element');
		});
		tab.add(applyElemShader);

		y += 34;
		var note = new FlxText(8, y, RIGHT_W - 20, 'To use shaders, add a script to the stage that applies the shader in onStageCreate.', 9);
		note.color = T.textDim;
		tab.add(note);

		rightPanel.addGroup(tab);
	}

	// ─────────────────────────────────────────────────────────────────────────
	// UPDATE
	// ─────────────────────────────────────────────────────────────────────────

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		handleKeyboard();
		handleCameraMovement(elapsed);
		handleLayerPanelClick();
		handleCanvasDrag();
		handleToolbarClick();
		updateSelectionBox();
		updateCharLabels();
		updateStatusBar();

		// Track which right-panel tab is selected to show/hide the animation list overlay.
		// Tab header strip sits at y ≈ TOP_H, height ≈ 20px. 5 tabs share RIGHT_W-2 px.
		if (FlxG.mouse.justPressed)
		{
			var mx = FlxG.mouse.x;
			var my = FlxG.mouse.y;
			if (my >= TOP_H && my <= TOP_H + 22 && mx >= FlxG.width - RIGHT_W)
			{
				var tabW:Float = (RIGHT_W - 2) / 5;
				var ti = Std.int((mx - (FlxG.width - RIGHT_W + 2)) / tabW);
				// FlxUITabMenu sorts tabs alphabetically:
				// [Anims=0, Chars=1, Element=2, Shaders=3, Stage=4]
				_animTabVisible = (ti == 0); // tab index 0 = "Anims" (sorted first)
			}
		}
		if (animListBg != null)
			animListBg.visible = _animTabVisible;
		if (animListText != null)
			animListText.visible = _animTabVisible;
	}

	function handleKeyboard():Void
	{
		// Si el usuario está escribiendo en un input, no disparar shortcuts ni nudge
		if (isTyping()) return;

		if (FlxG.keys.pressed.CONTROL)
		{
			if (FlxG.keys.justPressed.Z)
			{
				undo();
				return;
			}
			if (FlxG.keys.justPressed.Y)
			{
				redo();
				return;
			}
			if (FlxG.keys.justPressed.C)
			{
				copyElement();
				return;
			}
			if (FlxG.keys.justPressed.V)
			{
				pasteElement();
				return;
			}
			if (FlxG.keys.justPressed.S)
			{
				saveJSON();
				return;
			}
		}

		if (FlxG.keys.justPressed.ESCAPE)
		{
			FlxG.mouse.visible = false;
			StateTransition.switchState(new funkin.menus.FreeplayState());
			return;
		}

		if (FlxG.keys.justPressed.DELETE && !isMouseOverUI())
			deleteSelectedElement();

		// Nudge selected element with arrow keys
		if (selectedIdx >= 0 && selectedIdx < stageData.elements.length)
		{
			var step = FlxG.keys.pressed.SHIFT ? 10.0 : 1.0;
			var elem = stageData.elements[selectedIdx];
			var moved = false;

			// Guardia: position puede ser null si el elemento se cargó de un JSON incompleto
			if (elem.position == null) elem.position = [0.0, 0.0];

			if (FlxG.keys.justPressed.LEFT)
			{
				elem.position[0] -= step;
				moved = true;
			}
			if (FlxG.keys.justPressed.RIGHT)
			{
				elem.position[0] += step;
				moved = true;
			}
			if (FlxG.keys.justPressed.UP)
			{
				elem.position[1] -= step;
				moved = true;
			}
			if (FlxG.keys.justPressed.DOWN)
			{
				elem.position[1] += step;
				moved = true;
			}

			if (moved)
			{
				if (elem.name != null && elementSprites.exists(elem.name))
					elementSprites.get(elem.name).setPosition(elem.position[0], elem.position[1]);
				syncElementFieldsToUI();
				markUnsaved();
			}
		}
	}

	function handleCameraMovement(elapsed:Float):Void
	{
		var speed = 400 * elapsed;
		var overUI = isMouseOverUI();

		if (!overUI && !FlxG.keys.pressed.SHIFT)
		{
			if (FlxG.keys.pressed.A || FlxG.keys.pressed.LEFT)
				camTargetX -= speed;
			if (FlxG.keys.pressed.D || FlxG.keys.pressed.RIGHT)
				camTargetX += speed;
			if (FlxG.keys.pressed.W || FlxG.keys.pressed.UP)
				camTargetY -= speed;
			if (FlxG.keys.pressed.S || FlxG.keys.pressed.DOWN)
				camTargetY += speed;
		}

		// Middle mouse drag
		if (!overUI && FlxG.mouse.pressedMiddle)
		{
			if (FlxG.mouse.justPressedMiddle)
			{
				isDraggingCam = true;
				dragCamStart.set(FlxG.mouse.screenX, FlxG.mouse.screenY);
				dragCamScrollStart.set(camTargetX, camTargetY);
			}
		}
		if (isDraggingCam)
		{
			if (FlxG.mouse.pressedMiddle)
			{
				camTargetX = dragCamScrollStart.x - (FlxG.mouse.screenX - dragCamStart.x) / camZoom;
				camTargetY = dragCamScrollStart.y - (FlxG.mouse.screenY - dragCamStart.y) / camZoom;
			}
			else
			{
				isDraggingCam = false;
			}
		}

		// Zoom with scroll wheel
		if (!overUI && FlxG.mouse.wheel != 0)
		{
			camZoom += FlxG.mouse.wheel * 0.05;
			camZoom = Math.max(0.15, Math.min(2.5, camZoom));
		}

		if (FlxG.keys.justPressed.R && !isMouseOverUI())
		{
			camTargetX = FlxG.width * 0.5;
			camTargetY = FlxG.height * 0.5;
			camZoom = 0.75;
		}

		camGame.scroll.x = FlxMath.lerp(camGame.scroll.x, camTargetX - FlxG.width * 0.5, 0.12);
		camGame.scroll.y = FlxMath.lerp(camGame.scroll.y, camTargetY - FlxG.height * 0.5, 0.12);
		camGame.zoom = FlxMath.lerp(camGame.zoom, camZoom, 0.12);
	}

	function handleLayerPanelClick():Void
	{
		var mx = FlxG.mouse.x;
		var my = FlxG.mouse.y;

		// Mouse wheel scrolling over layer panel
		if (FlxG.mouse.wheel != 0 && mx < LEFT_W && my > TOP_H && my < FlxG.height - STATUS_H)
		{
			layerScrollStart = Std.int(Math.max(0, Math.min(stageData.elements.length - 1, layerScrollStart - Std.int(FlxG.mouse.wheel))));
			refreshLayerPanel();
			return;
		}

		if (!FlxG.mouse.justPressed || mx > LEFT_W || my < TOP_H || my > FlxG.height - STATUS_H)
			return;

		// ── Two-pass hit detection ────────────────────────────────────────────
		// Pass 1: look for specific small-button zones (eye, up, down, del, add_element)
		//         These must be checked first; they share the same Y band as 'row'
		//         but have a narrower X range.
		// Pass 2: fallback to 'row' and 'char' (full-width zones).
		var rowFallback:LayerHit = null;

		for (hit in layerHitData)
		{
			var hitX = hit.x;
			var hitW = hit.w;
			var hitY = hit.y;
			var hitH = hit.h;

			if (my < hitY || my > hitY + hitH)
				continue;
			if (mx < hitX || mx > hitX + hitW)
				continue;

			// Exact match on a specific zone → fire immediately
			if (hit.zone != 'row' && hit.zone != 'char')
			{
				switch (hit.zone)
				{
					case 'above':
						// Toggle aboveChars on this element (renders above characters)
						if (hit.idx >= 0 && hit.idx < stageData.elements.length)
						{
							var elem = stageData.elements[hit.idx];
							elem.aboveChars = !(elem.aboveChars == true);
							saveHistory();
							reloadStageView();
							refreshLayerPanel();
							markUnsaved();
							var onOff = elem.aboveChars ? 'ON' : 'OFF';
							setStatus('"${elem.name ?? "element"}" above-chars: $onOff');
						}

					case 'add_element':
						openAddElementDialog();

					case 'eye':
						if (hit.idx >= 0 && hit.idx < stageData.elements.length)
						{
							var elem = stageData.elements[hit.idx];
							elem.visible = !(elem.visible != false);
							if (elem.name != null && elementSprites.exists(elem.name))
								elementSprites.get(elem.name).visible = elem.visible;
							refreshLayerPanel();
							markUnsaved();
						}

					case 'up':
						moveLayer(hit.idx, 1);

					case 'down':
						moveLayer(hit.idx, -1);

					case 'del':
						if (hit.idx == selectedIdx)
							selectedIdx = -1;
						stageData.elements.splice(hit.idx, 1);
						saveHistory();
						reloadStageView();
						refreshLayerPanel();
						markUnsaved();
				}
				return;
			}

			// Save row/char as fallback (will be used if no specific zone matched)
			if (rowFallback == null)
				rowFallback = hit;
		}

		// Pass 2: fire the row/char fallback if we found one and no specific zone matched
		if (rowFallback != null)
		{
			switch (rowFallback.zone)
			{
				case 'row':
					if (rowFallback.idx >= 0 && rowFallback.idx < stageData.elements.length)
					{
						selectedIdx = rowFallback.idx;
						selectedCharId = null;
						syncElementFieldsToUI();
						refreshLayerPanel();
					}

				case 'char':
					selectedCharId = rowFallback.charId;
					selectedIdx = -1;
					refreshLayerPanel();
			}
		}
	}

	function handleCanvasDrag():Void
	{
		if (isMouseOverUI())
			return;

		// cameras[0] es camUI (zoom=1) → FlxG.mouse.x/y está en screen-space.
		// Para el canvas necesitamos coordenadas de mundo relativas a camGame.
		var worldPos = FlxG.mouse.getWorldPosition(camGame);
		var worldX = worldPos.x;
		var worldY = worldPos.y;
		worldPos.put();

		if (FlxG.mouse.justPressed)
		{
			// Try to select element under cursor
			var clickedIdx = -1;
			var clickedChar = '';

			// Check characters first (they're on top)
			for (cid => c in characters)
			{
				if (c.overlapsPoint(new FlxPoint(worldX, worldY)))
				{
					clickedChar = cid;
					break;
				}
			}

			if (clickedChar != '')
			{
				selectedCharId = clickedChar;
				selectedIdx = -1;
				refreshLayerPanel();
				isDraggingChar = true;
				dragCharId = clickedChar;
				dragStart.set(worldX, worldY);
				var c = characters.get(clickedChar);
				dragObjStart.set(c.x, c.y);
			}
			else
			{
				// Check elements (reverse order = topmost first)
				var i = stageData.elements.length - 1;
				while (i >= 0)
				{
					var elem = stageData.elements[i];
					if (elem.name != null && elementSprites.exists(elem.name))
					{
						var spr = elementSprites.get(elem.name);
						if (spr.overlapsPoint(new FlxPoint(worldX, worldY)))
						{
							clickedIdx = i;
							break;
						}
					}
					i--;
				}

				if (clickedIdx >= 0)
				{
					selectedIdx = clickedIdx;
					selectedCharId = null;
					syncElementFieldsToUI();
					refreshLayerPanel();
					isDraggingEl = true;
					dragStart.set(worldX, worldY);
					dragObjStart.set(stageData.elements[clickedIdx].position[0], stageData.elements[clickedIdx].position[1]);
				}
			}
		}

		// Drag element
		if (isDraggingEl && selectedIdx >= 0 && selectedIdx < stageData.elements.length)
		{
			if (FlxG.mouse.pressed)
			{
				var dx = worldX - dragStart.x;
				var dy = worldY - dragStart.y;
				stageData.elements[selectedIdx].position[0] = dragObjStart.x + dx;
				stageData.elements[selectedIdx].position[1] = dragObjStart.y + dy;
				var elem = stageData.elements[selectedIdx];
				if (elem.name != null && elementSprites.exists(elem.name))
					elementSprites.get(elem.name).setPosition(elem.position[0], elem.position[1]);
				syncElementFieldsToUI();
			}
			else
			{
				isDraggingEl = false;
				saveHistory();
				markUnsaved();
			}
		}

		// Drag character
		if (isDraggingChar && dragCharId != null)
		{
			if (FlxG.mouse.pressed)
			{
				var dx = worldX - dragStart.x;
				var dy = worldY - dragStart.y;
				var c = characters.get(dragCharId);
				if (c != null)
					c.setPosition(dragObjStart.x + dx, dragObjStart.y + dy);
			}
			else
			{
				isDraggingChar = false;
				// Save new position into stageData
				var c = characters.get(dragCharId);
				if (c != null)
				{
					switch (dragCharId)
					{
						case 'bf':
							stageData.boyfriendPosition = [c.x, c.y];
							if (bfXStepper != null)
								bfXStepper.value = c.x;
							if (bfYStepper != null)
								bfYStepper.value = c.y;
						case 'gf':
							stageData.gfPosition = [c.x, c.y];
							if (gfXStepper != null)
								gfXStepper.value = c.x;
							if (gfYStepper != null)
								gfYStepper.value = c.y;
						case 'dad':
							stageData.dadPosition = [c.x, c.y];
							if (dadXStepper != null)
								dadXStepper.value = c.x;
							if (dadYStepper != null)
								dadYStepper.value = c.y;
					}
				}
				saveHistory();
				markUnsaved();
				refreshLayerPanel(); // Update position display
			}
		}
	}

	function handleToolbarClick():Void
	{
		if (!FlxG.mouse.justPressed)
			return;
		var mx = FlxG.mouse.x;
		var my = FlxG.mouse.y;
		// Toolbar occupies TITLE_H → TOP_H (i.e. y=34 to y=74)
		// Use a slightly generous top bound to avoid missing the top row
		if (my < 0 || my > TOP_H)
			return;

		for (bg => cb in _toolBtns)
		{
			if (mx >= bg.x && mx <= bg.x + bg.width && my >= bg.y && my <= bg.y + bg.height)
			{
				cb();
				return;
			}
		}
	}

	function updateSelectionBox():Void
	{
		if (selBox == null)
			return;

		if (selectedIdx < 0 || selectedIdx >= stageData.elements.length)
		{
			selBox.visible = false;
			return;
		}

		var elem = stageData.elements[selectedIdx];
		if (elem.name == null || !elementSprites.exists(elem.name))
		{
			selBox.visible = false;
			return;
		}

		var spr = elementSprites.get(elem.name);
		var pad = 3;
		var needW = Std.int(spr.width  + pad * 2);
		var needH = Std.int(spr.height + pad * 2);

		// ── Only rebuild the BitmapData when dimensions change ────────────────
		// Calling makeGraphic + pixel-fill every frame was the main memory/CPU spike.
		if (needW != _selBoxW || needH != _selBoxH)
		{
			_selBoxW = needW;
			_selBoxH = needH;

			selBox.makeGraphic(needW, needH, FlxColor.TRANSPARENT, true);

			var pix = selBox.pixels;
			var c   = EditorTheme.current.selection;

			for (xi in 0...needW)
			{
				pix.setPixel32(xi, 0,         c);
				pix.setPixel32(xi, 1,         c);
				pix.setPixel32(xi, needH - 1, c);
				pix.setPixel32(xi, needH - 2, c);
			}
			for (yi in 0...needH)
			{
				pix.setPixel32(0,         yi, c);
				pix.setPixel32(1,         yi, c);
				pix.setPixel32(needW - 1, yi, c);
				pix.setPixel32(needW - 2, yi, c);
			}

			selBox.dirty = true;
		}

		selBox.setPosition(spr.x - pad, spr.y - pad);
		selBox.visible = true;
	}

	function updateCharLabels():Void
	{
		var lArr = charLabels.members;
		var cIds = ['dad', 'gf', 'bf'];
		var ci = 0;
		for (cid in cIds)
		{
			if (!characters.exists(cid))
				continue;
			var c = characters.get(cid);
			if (ci < lArr.length && lArr[ci] != null)
			{
				lArr[ci].setPosition(c.x, c.y - 22);
			}
			ci++;
		}
	}

	function updateStatusBar():Void
	{
		// Necesitamos coordenadas de mundo (camGame) para mostrar en status bar
		var worldPos = FlxG.mouse.getWorldPosition(camGame);
		var worldX = Std.int(worldPos.x);
		var worldY = Std.int(worldPos.y);
		worldPos.put();
		coordText.text = 'x:$worldX y:$worldY';
		zoomText.text = 'Zoom: ${Std.int(camZoom * 100)}%';
		unsavedDot.x = titleText.x + titleText.textField.textWidth + 10;
	}

	// ─────────────────────────────────────────────────────────────────────────
	// ELEMENT OPERATIONS
	// ─────────────────────────────────────────────────────────────────────────

	function openAddElementDialog():Void
	{
		openSubState(new AddElementSubState(function(elem:StageElement)
		{
			stageData.elements.push(elem);
			saveHistory();
			reloadStageView();
			selectedIdx = stageData.elements.length - 1;
			syncElementFieldsToUI();
			refreshLayerPanel();
			markUnsaved();
			setStatus('Element "${elem.name}" added');
		}, stageData.name ?? 'stage', ModManager.isActive()));
	}

	function deleteSelectedElement():Void
	{
		if (selectedIdx < 0 || selectedIdx >= stageData.elements.length)
			return;
		var name = stageData.elements[selectedIdx].name ?? 'element';
		stageData.elements.splice(selectedIdx, 1);
		selectedIdx = -1;
		saveHistory();
		reloadStageView();
		refreshLayerPanel();
		markUnsaved();
		setStatus('Element "$name" deleted');
	}

	function copyElement():Void
	{
		if (selectedIdx < 0 || selectedIdx >= stageData.elements.length)
			return;
		clipboard = Json.parse(Json.stringify(stageData.elements[selectedIdx]));
		setStatus('Element copied to clipboard');
	}

	function pasteElement():Void
	{
		if (clipboard == null)
			return;
		var newElem:StageElement = Json.parse(Json.stringify(clipboard));
		newElem.name = (clipboard.name ?? 'elem') + '_copy';
		newElem.position = [(clipboard.position[0] : Float) + 30, (clipboard.position[1] : Float) + 30];
		stageData.elements.push(newElem);
		saveHistory();
		reloadStageView();
		selectedIdx = stageData.elements.length - 1;
		syncElementFieldsToUI();
		refreshLayerPanel();
		markUnsaved();
		setStatus('Element pasted: "${newElem.name}"');
	}

	function moveLayer(idx:Int, delta:Int):Void
	{
		// In the array, higher index = drawn on top.
		// delta = 1 means move element up visually = increase index
		var newIdx = idx + delta;
		if (newIdx < 0 || newIdx >= stageData.elements.length)
			return;

		var temp = stageData.elements[idx];
		stageData.elements[idx] = stageData.elements[newIdx];
		stageData.elements[newIdx] = temp;

		if (selectedIdx == idx)
			selectedIdx = newIdx;
		else if (selectedIdx == newIdx)
			selectedIdx = idx;

		saveHistory();
		reloadStageView();
		refreshLayerPanel();
		markUnsaved();
	}

	function applyElementProps():Void
	{
		if (selectedIdx < 0 || selectedIdx >= stageData.elements.length)
			return;
		var elem = stageData.elements[selectedIdx];

		elem.name = elemNameInput.text.trim();
		elem.asset = elemAssetInput.text.trim();
		elem.position = [elemXStepper.value, elemYStepper.value];
		elem.scale = [elemScaleXStepper.value, elemScaleYStepper.value];
		elem.scrollFactor = [elemScrollXStepper.value, elemScrollYStepper.value];
		elem.alpha = elemAlphaStepper.value;
		elem.zIndex = Std.int(elemZIndexStepper.value);
		elem.flipX = elemFlipXCheck.checked;
		elem.flipY = elemFlipYCheck.checked;
		elem.antialiasing = elemAntialiasingCheck.checked;
		elem.visible    = elemVisibleCheck.checked;
		elem.aboveChars = elemAboveCharsCheck.checked;

		var colorStr = elemColorInput.text.trim();
		elem.color = (colorStr != '' && colorStr != '#FFFFFF') ? colorStr : null;

		saveHistory();
		reloadStageView();
		selectedIdx = stageData.elements.length > 0 ? Std.int(Math.min(selectedIdx, stageData.elements.length - 1)) : -1;
		refreshLayerPanel();
		markUnsaved();
		setStatus('Properties applied: "${elem.name}"');
	}

	function syncElementFieldsToUI():Void
	{
		if (selectedIdx < 0 || selectedIdx >= stageData.elements.length)
			return;
		var elem = stageData.elements[selectedIdx];

		if (elemNameInput != null)
			elemNameInput.text = elem.name ?? '';
		if (elemAssetInput != null)
			elemAssetInput.text = elem.asset;
		if (elemTypeDropdown != null)
			elemTypeDropdown.selectedLabel = elem.type;

		if (elemXStepper != null)
			elemXStepper.value = elem.position[0];
		if (elemYStepper != null)
			elemYStepper.value = elem.position[1];

		var sc = elem.scale ?? [1.0, 1.0];
		if (elemScaleXStepper != null)
			elemScaleXStepper.value = sc[0];
		if (elemScaleYStepper != null)
			elemScaleYStepper.value = sc[1];

		var sf = elem.scrollFactor ?? [1.0, 1.0];
		if (elemScrollXStepper != null)
			elemScrollXStepper.value = sf[0];
		if (elemScrollYStepper != null)
			elemScrollYStepper.value = sf[1];

		if (elemAlphaStepper != null)
			elemAlphaStepper.value = elem.alpha ?? 1.0;
		if (elemZIndexStepper != null)
			elemZIndexStepper.value = elem.zIndex ?? 0;

		if (elemFlipXCheck != null)
			elemFlipXCheck.checked = elem.flipX ?? false;
		if (elemFlipYCheck != null)
			elemFlipYCheck.checked = elem.flipY ?? false;
		if (elemAntialiasingCheck != null)
			elemAntialiasingCheck.checked = elem.antialiasing ?? true;
		if (elemVisibleCheck != null)
			elemVisibleCheck.checked = elem.visible ?? true;
		if (elemAboveCharsCheck != null)
			elemAboveCharsCheck.checked = elem.aboveChars == true;
		if (elemColorInput != null)
			elemColorInput.text = elem.color ?? '#FFFFFF';

		// Shader
		if (elemShaderInput != null && elem.customProperties != null)
		{
			var sh = Reflect.field(elem.customProperties, 'shader');
			elemShaderInput.text = sh != null ? Std.string(sh) : '';
		}

		// Sync animation tab
		syncAnimListUI();
	}

	// ─────────────────────────────────────────────────────────────────────────
	// ANIMATION OPERATIONS
	// ─────────────────────────────────────────────────────────────────────────

	function syncAnimListUI():Void
	{
		if (animListBg == null || animListText == null)
			return;
		for (s in animListBg.members)
			if (s != null)
			{
				s.visible = false;
			}
		for (t in animListText.members)
			if (t != null)
			{
				t.visible = false;
			}
		animListBg.clear();
		animListText.clear();
		animHitData = [];

		if (selectedIdx < 0 || selectedIdx >= stageData.elements.length)
			return;
		var elem = stageData.elements[selectedIdx];
		if (elem.animations == null || elem.animations.length == 0)
			return;

		var T = EditorTheme.current;
		var ay = 10.0;

		// Absolute offset: right panel starts at (FlxG.width - RIGHT_W + 2), tab header ≈ 20px
		var ox:Float = FlxG.width - RIGHT_W + 2;
		var oy:Float = TOP_H + 20;

		for (i in 0...elem.animations.length)
		{
			var anim = elem.animations[i];
			var isSelAnim = (i == animSelIdx);
			var rowColor = isSelAnim ? T.rowSelected : (i % 2 == 0 ? T.rowEven : T.rowOdd);

			var bg = new FlxSprite(ox + 4, oy + ay).makeGraphic(RIGHT_W - 16, ANIM_ROW_H, rowColor);
			bg.cameras = [camHUD];
			bg.scrollFactor.set();
			animListBg.add(bg);

			var nameT = new FlxText(ox + 8, oy + ay + 4, 100, anim.name, 9);
			nameT.setFormat(Paths.font('vcr.ttf'), 9, isSelAnim ? T.accent : T.textPrimary, LEFT);
			nameT.cameras = [camHUD];
			nameT.scrollFactor.set();
			animListText.add(nameT);

			var prefT = new FlxText(ox + 110, oy + ay + 4, 80, anim.prefix, 9);
			prefT.setFormat(Paths.font('vcr.ttf'), 9, T.textSecondary, LEFT);
			prefT.cameras = [camHUD];
			prefT.scrollFactor.set();
			animListText.add(prefT);

			var fpsT = new FlxText(ox + RIGHT_W - 50, oy + ay + 4, 40, '${anim.framerate ?? 24}fps', 8);
			fpsT.color = T.textDim;
			fpsT.cameras = [camHUD];
			fpsT.scrollFactor.set();
			animListText.add(fpsT);

			animHitData.push({y: oy + ay, idx: i});
			ay += ANIM_ROW_H;

			if (i == animSelIdx)
			{
				// Populate edit fields with selected anim
				if (animNameInput != null)
					animNameInput.text = anim.name;
				if (animPrefixInput != null)
					animPrefixInput.text = anim.prefix;
				if (animFPSStepper != null)
					animFPSStepper.value = anim.framerate ?? 24;
				if (animLoopCheck != null)
					animLoopCheck.checked = anim.looped ?? false;
				if (animIndicesInput != null)
					animIndicesInput.text = (anim.indices != null ? anim.indices.join(',') : '');
			}
		}

		if (elem.firstAnimation != null && animFirstInput != null)
			animFirstInput.text = elem.firstAnimation;
	}

	function addAnimation():Void
	{
		if (selectedIdx < 0 || selectedIdx >= stageData.elements.length)
			return;
		var elem = stageData.elements[selectedIdx];
		if (elem.animations == null)
			elem.animations = [];
		elem.animations.push({
			name: 'new_anim',
			prefix: 'new0',
			framerate: 24,
			looped: false
		});
		animSelIdx = elem.animations.length - 1;
		syncAnimListUI();
		markUnsaved();
	}

	function removeAnimation():Void
	{
		if (selectedIdx < 0 || selectedIdx >= stageData.elements.length)
			return;
		var elem = stageData.elements[selectedIdx];
		if (elem.animations == null || animSelIdx < 0 || animSelIdx >= elem.animations.length)
			return;
		elem.animations.splice(animSelIdx, 1);
		animSelIdx = Std.int(Math.max(0, animSelIdx - 1));
		syncAnimListUI();
		markUnsaved();
	}

	function saveAnimData():Void
	{
		if (selectedIdx < 0 || selectedIdx >= stageData.elements.length)
			return;
		var elem = stageData.elements[selectedIdx];
		if (elem.animations == null || elem.animations.length == 0)
			return;

		var anim = elem.animations[animSelIdx];
		anim.name = animNameInput.text.trim();
		anim.prefix = animPrefixInput.text.trim();
		anim.framerate = Std.int(animFPSStepper.value);
		anim.looped = animLoopCheck.checked;

		var indStr = animIndicesInput.text.trim();
		if (indStr != '')
		{
			anim.indices = indStr.split(',').map(s -> Std.parseInt(s.trim())).filter(v -> v != null);
		}
		else
		{
			anim.indices = null;
		}

		elem.firstAnimation = animFirstInput.text.trim();

		syncAnimListUI();
		saveHistory();
		markUnsaved();
		setStatus('Animation "${anim.name}" saved');
	}

	// ─────────────────────────────────────────────────────────────────────────
	// STAGE / CHARS PROPS
	// ─────────────────────────────────────────────────────────────────────────

	function applyStageProps():Void
	{
		stageData.name = stageNameInput.text.trim();
		stageData.defaultZoom = stageZoomStepper.value;
		stageData.isPixelStage = stagePixelCheck.checked;
		stageData.hideGirlfriend = stageHideGFCheck.checked;
		titleText.text = '\u26AA  STAGE EDITOR  \u2022  ' + stageData.name;
		saveHistory();
		markUnsaved();
		setStatus('Stage properties updated');
	}

	function applyCharProps():Void
	{
		stageData.boyfriendPosition = [bfXStepper.value, bfYStepper.value];
		stageData.gfPosition = [gfXStepper.value, gfYStepper.value];
		stageData.dadPosition = [dadXStepper.value, dadYStepper.value];
		stageData.cameraBoyfriend = [camBFXStepper.value, camBFYStepper.value];
		stageData.cameraDad = [camDadXStepper.value, camDadYStepper.value];
		stageData.gfVersion = gfVersionInput.text.trim();
		loadCharacters();
		saveHistory();
		markUnsaved();
		refreshLayerPanel();
		setStatus('Character positions updated');
	}

	function addScript():Void
	{
		if (stageData.scripts == null)
			stageData.scripts = [];
		stageData.scripts.push('scripts/newScript.hx');
		saveHistory();
		markUnsaved();
		setStatus('Script placeholder added — edit the JSON to set the real path');
	}

	// ─────────────────────────────────────────────────────────────────────────
	// SAVE / LOAD
	// ─────────────────────────────────────────────────────────────────────────

	function _getSavePath(toMod:Bool):String
	{
		#if sys
		var stageName = stageData.name;
		if (toMod && ModManager.isActive())
			return '${ModManager.modRoot()}/stages/$stageName.json';
		else
			return 'assets/stages/$stageName.json';
		#else
		return '';
		#end
	}

	function _ensureDir(path:String):Void
	{
		#if sys
		var dir = haxe.io.Path.directory(path);
		if (dir != '' && !FileSystem.exists(dir))
			FileSystem.createDirectory(dir);
		#end
	}

	function saveJSON():Void
	{
		#if sys
		var path = _getSavePath(false);
		try
		{
			_ensureDir(path);
			File.saveContent(path, Json.stringify(stageData, null, '\t'));
			currentFilePath = path;
			hasUnsavedChanges = false;
			unsavedDot.visible = false;
			modBadge.text = _modLabel();
			setStatus('Saved: $path');
		}
		catch (e:Dynamic)
		{
			setStatus('ERROR saving: $e');
		}
		#end
	}

	function saveToMod():Void
	{
		#if sys
		if (!ModManager.isActive())
		{
			setStatus('No active mod — using base path');
			saveJSON();
			return;
		}
		var path = _getSavePath(true);
		try
		{
			_ensureDir(path);
			File.saveContent(path, Json.stringify(stageData, null, '\t'));
			currentFilePath = path;
			hasUnsavedChanges = false;
			unsavedDot.visible = false;
			setStatus('Saved in mod: $path');
		}
		catch (e:Dynamic)
		{
			setStatus('ERROR saving in mod: $e');
		}
		#end
	}

	function loadJSON():Void
	{
		#if sys
		_fileRef = new FileReference();
		_fileRef.addEventListener(Event.SELECT, function(e:Event)
		{
			_fileRef.addEventListener(Event.COMPLETE, function(e2:Event)
			{
				try
				{
					var raw = _fileRef.data.toString();
					stageData = Json.parse(raw);
					history = [];
					historyIndex = -1;
					_stageDataReady = true; // data is now in memory — use __fromData__ for rebuilds
					saveHistory();
					reloadStageView();
					refreshLayerPanel();
					currentFilePath = _fileRef.name;
					hasUnsavedChanges = false;
					unsavedDot.visible = false;
					setStatus('Stage loaded: ' + _fileRef.name);
				}
				catch (e:Dynamic)
				{
					setStatus('Error parsing JSON: $e');
				}
			});
			_fileRef.load();
		});
		_fileRef.browse([new openfl.net.FileFilter('Stage JSON', '*.json')]);
		#end
	}

	function browseAsset():Void
	{
		#if sys
		_fileRef = new FileReference();
		_fileRef.addEventListener(Event.SELECT, function(e:Event)
		{
			_fileRef.addEventListener(Event.COMPLETE, function(e2:Event)
			{
				var filename = _fileRef.name;

				// Determine destination folder based on active mod
				var stageName = stageData.name ?? 'stage';
				var destDir:String;
				if (ModManager.isActive())
					destDir = '${ModManager.modRoot()}/stages/$stageName/images';
				else
					destDir = 'assets/stages/$stageName/images';

				try
				{
					if (!FileSystem.exists(destDir))
						FileSystem.createDirectory(destDir);

					var destPath = '$destDir/$filename';
					var bytes = _fileRef.data;
					if (bytes != null)
					{
						sys.io.File.saveBytes(destPath, bytes);
						setStatus('Image copied to: $destPath');
					}
				}
				catch (ex:Dynamic)
				{
					setStatus('Error copying image: $ex');
				}

				// Set asset key (strip extension, use relative path for asset system)
				var assetKey = filename;
				if (assetKey.endsWith('.png'))  assetKey = assetKey.substr(0, assetKey.length - 4);
				else if (assetKey.endsWith('.jpg')) assetKey = assetKey.substr(0, assetKey.length - 4);

				if (elemAssetInput != null)
					elemAssetInput.text = 'images/$assetKey';
			});
			_fileRef.load();
		});
		_fileRef.addEventListener(Event.CANCEL, function(_) { setStatus('Browse cancelled.'); });
		_fileRef.addEventListener(IOErrorEvent.IO_ERROR, function(_) { setStatus('Error opening file browser.'); });
		_fileRef.browse([new openfl.net.FileFilter('Images/XML', '*.png;*.jpg;*.xml')]);
		#end
	}

	// ─────────────────────────────────────────────────────────────────────────
	// HISTORY (UNDO / REDO)
	// ─────────────────────────────────────────────────────────────────────────

	function saveHistory():Void
	{
		if (historyIndex < history.length - 1)
			history.splice(historyIndex + 1, history.length - historyIndex - 1);

		history.push(Json.stringify(stageData));
		historyIndex = history.length - 1;

		if (history.length > 60)
		{
			history.shift();
			historyIndex--;
		}
	}

	function undo():Void
	{
		if (historyIndex <= 0)
			return;
		historyIndex--;
		stageData = Json.parse(history[historyIndex]);
		_stageDataReady = true;
		reloadStageView();
		refreshLayerPanel();
		markUnsaved();
		setStatus('Undo \u2190  (${historyIndex + 1}/${history.length})');
	}

	function redo():Void
	{
		if (historyIndex >= history.length - 1)
			return;
		historyIndex++;
		stageData = Json.parse(history[historyIndex]);
		_stageDataReady = true;
		reloadStageView();
		refreshLayerPanel();
		markUnsaved();
		setStatus('Redo \u2192  (${historyIndex + 1}/${history.length})');
	}

	// ─────────────────────────────────────────────────────────────────────────
	// HELPERS
	// ─────────────────────────────────────────────────────────────────────────

	function reloadStageView():Void
	{
		loadStageIntoCanvas();
		_selBoxW = 0;
		_selBoxH = 0;
		if (selBox != null)
			selBox.visible = false;
	}

	function markUnsaved():Void
	{
		hasUnsavedChanges = true;
		unsavedDot.visible = true;
	}

	function setStatus(msg:String):Void
	{
		if (statusText != null)
			statusText.text = msg;
		trace('[StageEditor] $msg');
	}

	/** True si algún input de texto tiene el foco.
	 *  Mientras el usuario escribe, las flechas/delete NO deben mover el elemento. */
	function isTyping():Bool
	{
		if (elemNameInput    != null && elemNameInput.hasFocus)    return true;
		if (elemAssetInput   != null && elemAssetInput.hasFocus)   return true;
		if (elemColorInput   != null && elemColorInput.hasFocus)   return true;
		if (animNameInput    != null && animNameInput.hasFocus)    return true;
		if (animPrefixInput  != null && animPrefixInput.hasFocus)  return true;
		if (animIndicesInput != null && animIndicesInput.hasFocus) return true;
		if (animFirstInput   != null && animFirstInput.hasFocus)   return true;
		if (stageNameInput   != null && stageNameInput.hasFocus)   return true;
		if (gfVersionInput   != null && gfVersionInput.hasFocus)   return true;
		if (stageShaderInput != null && stageShaderInput.hasFocus) return true;
		if (elemShaderInput  != null && elemShaderInput.hasFocus)  return true;
		return false;
	}

	function isMouseOverUI():Bool
	{
		var mx = FlxG.mouse.screenX;
		var my = FlxG.mouse.screenY;
		return my < TOP_H || my > FlxG.height - STATUS_H || mx < LEFT_W || mx > FlxG.width - RIGHT_W;
	}

	function _modLabel():String
	{
		return ModManager.isActive() ? 'Mod: ${ModManager.activeMod}' : 'Base Game';
	}

	// ─────────────────────────────────────────────────────────────────────────
	// DESTROY
	// ─────────────────────────────────────────────────────────────────────────

	override public function destroy():Void
	{
		dragStart.put();
		dragObjStart.put();
		dragCamStart.put();
		dragCamScrollStart.put();
		if (stage != null)
		{
			stage.destroy();
			stage = null;
		}
		super.destroy();
	}
}

// ─────────────────────────────────────────────────────────────────────────────
//  AddElementSubState
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Substate flotante para añadir un nuevo elemento al stage.
 * Muestra un formulario con tipo, nombre y asset, y llama al callback al confirmar.
 */
class AddElementSubState extends flixel.FlxSubState
{
	var onConfirm:StageElement->Void;

	var nameInput:FlxUIInputText;
	var assetInput:FlxUIInputText;
	var typeDropdown:FlxUIDropDownMenu;

	static inline final W:Int = 420;
	static inline final H:Int = 320;

	var _camSub:flixel.FlxCamera;
	var _fileRef:FileReference;
	/** The stage name (passed from the editor) so we know where to copy assets. */
	var _stageName:String;
	/** Whether to copy to the active mod folder (true) or base assets (false). */
	var _toMod:Bool;

	public function new(cb:StageElement->Void, stageName:String = 'stage', toMod:Bool = false)
	{
		super();
		onConfirm  = cb;
		_stageName = stageName;
		_toMod     = toMod;
	}

	override function create():Void
	{
		super.create();

		_camSub = new flixel.FlxCamera();
		_camSub.bgColor.alpha = 0;
		FlxG.cameras.add(_camSub, false);
		cameras = [_camSub];

		var T = EditorTheme.current;
		var panX = (FlxG.width  - W) * 0.5;
		var panY = (FlxG.height - H) * 0.5;

		var overlay = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xBB000000);
		overlay.scrollFactor.set();
		overlay.cameras = [_camSub];
		add(overlay);

		var panel = new FlxSprite(panX, panY).makeGraphic(W, H, T.bgPanel);
		panel.scrollFactor.set();
		panel.cameras = [_camSub];
		add(panel);

		var topBorder = new FlxSprite(panX, panY).makeGraphic(W, 3, T.borderColor);
		topBorder.scrollFactor.set();
		topBorder.cameras = [_camSub];
		add(topBorder);

		var title = new FlxText(panX + 12, panY + 10, W - 24, '\u2795  ADD ELEMENT', 16);
		title.setFormat(Paths.font('vcr.ttf'), 16, T.accent, LEFT);
		title.scrollFactor.set();
		title.cameras = [_camSub];
		add(title);

		var y = panY + 44.0;

		function lbl(t:String, ly:Float):Void
		{
			var tx = new FlxText(panX + 12, ly, 0, t, 10);
			tx.color = T.textSecondary;
			tx.scrollFactor.set();
			tx.cameras = [_camSub];
			add(tx);
		}

		lbl('Element Name:', y);
		nameInput = new FlxUIInputText(panX + 12, y + 14, W - 28, 'new_element', 11);
		nameInput.scrollFactor.set();
		nameInput.cameras = [_camSub];
		add(nameInput);

		y += 40;
		lbl('Type:', y);
		var types = ['sprite', 'animated', 'group', 'custom_class', 'sound'];
		typeDropdown = new FlxUIDropDownMenu(panX + 12, y + 14, FlxUIDropDownMenu.makeStrIdLabelArray(types, true), null);
		typeDropdown.scrollFactor.set();
		typeDropdown.cameras = [_camSub];
		add(typeDropdown);

		y += 52;
		lbl('Asset path  (images/stages/… or browse to copy):', y);

		// Asset path input
		assetInput = new FlxUIInputText(panX + 12, y + 14, W - 110, 'images/stages/myAsset', 11);
		assetInput.scrollFactor.set();
		assetInput.cameras = [_camSub];
		add(assetInput);

		// ── Browse button ──────────────────────────────────────────────────────
		// Opens a native file picker. The selected PNG/JPG/XML is copied to the
		// engine's asset folder (mod or base) and the asset path is filled in.
		var browseBtn = new FlxButton(panX + W - 96, y + 13, 'Browse...', _browseAsset);
		browseBtn.cameras = [_camSub];
		add(browseBtn);

		// Copy-destination info
		var destRoot = _toMod && ModManager.isActive()
			? '${ModManager.modRoot()}/stages/$_stageName/images'
			: 'assets/stages/$_stageName/images';
		var destInfo = new FlxText(panX + 12, y + 30, W - 28, '\u2192 copies to: $destRoot', 9);
		destInfo.color = T.textDim;
		destInfo.scrollFactor.set();
		destInfo.cameras = [_camSub];
		add(destInfo);

		y += 56;

		// Confirm / Cancel
		var confirmBtn = new FlxButton(panX + 12, y, 'Add Element', function()
		{
			var types2  = ['sprite', 'animated', 'group', 'custom_class', 'sound'];
			var typeIdx = Std.parseInt(typeDropdown.selectedId);
			var typeName = (typeIdx != null && typeIdx >= 0 && typeIdx < types2.length) ? types2[typeIdx] : 'sprite';
			var newElem:StageElement = {
				type:         typeName,
				name:         nameInput.text.trim(),
				asset:        assetInput.text.trim(),
				position:     [100.0, 100.0],
				scrollFactor: [1.0, 1.0],
				scale:        [1.0, 1.0],
				alpha:        1.0,
				visible:      true,
				antialiasing: true,
				zIndex:       0
			};
			if (typeName == 'animated')
				newElem.animations = [
					{
						name:      'idle',
						prefix:    'idle0',
						framerate: 24,
						looped:    true
					}
				];
			onConfirm(newElem);
			close();
		});
		confirmBtn.cameras = [_camSub];
		add(confirmBtn);

		var cancelBtn = new FlxButton(panX + W - 102, y, 'Cancel', close);
		cancelBtn.cameras = [_camSub];
		add(cancelBtn);

		var hint = new FlxText(panX + 12, panY + H - 20, W - 24, 'ESC to cancel', 9);
		hint.color = T.textDim;
		hint.scrollFactor.set();
		hint.cameras = [_camSub];
		add(hint);
	}

	/** Opens a native file browser. The selected image/XML is copied to the engine
	 *  asset folder (mod or base) and the asset path field is filled in. */
	function _browseAsset():Void
	{
		#if sys
		_fileRef = new FileReference();
		_fileRef.addEventListener(Event.SELECT, function(_)
		{
			_fileRef.addEventListener(Event.COMPLETE, function(_)
			{
				var filename = _fileRef.name;

				// Determine destination
				var destDir:String = _toMod && ModManager.isActive()
					? '${ModManager.modRoot()}/stages/$_stageName/images'
					: 'assets/stages/$_stageName/images';

				try
				{
					if (!FileSystem.exists(destDir))
						FileSystem.createDirectory(destDir);

					var destPath = '$destDir/$filename';
					var bytes = _fileRef.data;
					if (bytes != null)
						sys.io.File.saveBytes(destPath, bytes);
				}
				catch (ex:Dynamic)
				{
					trace('[AddElementSubState] Error copying asset: $ex');
				}

				// Strip extension → asset key
				var assetKey = filename;
				if (assetKey.endsWith('.png'))       assetKey = assetKey.substr(0, assetKey.length - 4);
				else if (assetKey.endsWith('.jpg'))  assetKey = assetKey.substr(0, assetKey.length - 4);
				else if (assetKey.endsWith('.jpeg')) assetKey = assetKey.substr(0, assetKey.length - 5);

				// If name input is still the default, auto-fill it
				if (nameInput.text == 'new_element' || nameInput.text == '')
					nameInput.text = assetKey;

				assetInput.text = 'stages/$_stageName/images/$assetKey';
			});
			_fileRef.load();
		});
		_fileRef.addEventListener(Event.CANCEL, function(_) {});
		_fileRef.addEventListener(IOErrorEvent.IO_ERROR, function(_)
		{
			trace('[AddElementSubState] File browse IO error');
		});
		_fileRef.browse([new openfl.net.FileFilter('Images / Sprite XML', '*.png;*.jpg;*.jpeg;*.xml')]);
		#end
	}

	override function close():Void
	{
		if (_camSub != null)
		{
			FlxG.cameras.remove(_camSub, true);
			_camSub = null;
		}
		super.close();
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (FlxG.keys.justPressed.ESCAPE)
			close();
	}
}
