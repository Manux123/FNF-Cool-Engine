package funkin.debug;

import flixel.*;
import flixel.addons.ui.*;
import flixel.group.FlxGroup;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.*;
import flixel.ui.*;
import flixel.util.*;
import haxe.Json;
import openfl.events.Event;
import openfl.net.FileReference;
import ui.Alphabet;

using StringTools;
/**
 * MenuEditor v2 — Editor visual de menus estilo Godot.
 *
 * Nuevo en v2:
 *  - Vista previa en vivo con objetos Flixel reales (Alphabet, FlxSprite, etc.)
 *  - Tipo "Alphabet" (como MainMenu/FreePlay)
 *  - Sistema de grupos/capas
 *  - ScriptEditorSubState para scripts por item y transiciones custom
 *  - Importar imagenes / Sparrow atlas
 *  - Drag-and-drop de items en el preview
 *  - Musica de fondo con preview en vivo
 *  - Templates: MainMenu, FreePlay, StoryMenu
 *  - Exportar HScript
 */
class MenuEditor extends funkin.states.MusicBeatState
{
	// Colores
	static inline var C_BG        : Int = 0xFF0D0D14;
	static inline var C_PANEL     : Int = 0xFF161620;
	static inline var C_PANEL_ALT : Int = 0xFF1C1C2C;
	static inline var C_PREVIEW   : Int = 0xFF08080F;
	static inline var C_ACCENT    : Int = 0xFF00D9FF;
	static inline var C_GREEN     : Int = 0xFF00FF88;
	static inline var C_RED       : Int = 0xFFFF3355;
	static inline var C_YELLOW    : Int = 0xFFFFCC00;
	static inline var C_ORANGE    : Int = 0xFFFF8844;
	static inline var C_WHITE     : Int = 0xFFFFFFFF;
	static inline var C_GRAY      : Int = 0xFFAAAAAA;
	static inline var C_DARK      : Int = 0xFF080810;
	static inline var C_SELECTED  : Int = 0xFF1A3048;

	static var TYPE_COLORS : Map<String,Int> = [
		"Button"         => 0xFF4488FF,
		"Alphabet"       => 0xFFFF88FF,
		"Image"          => 0xFF44FF88,
		"AnimatedSprite" => 0xFF88FF44,
		"Text"           => 0xFFFFCC44,
		"Separator"      => 0xFF666677,
		"Script"         => 0xFFAA44FF,
		"Group"          => 0xFFFF8844,
	];

	// Layout
	static inline var TOOLBAR_H  : Int = 40;
	static inline var PANEL_W    : Int = 310;
	static inline var TAB_H      : Int = 28;
	static inline var STATUS_H   : Int = 24;
	static inline var ROW_H      : Int = 26;
	static inline var MAX_ROWS   : Int = 9;

	// Cameras
	var camUI      : FlxCamera;
	var camPreview : FlxCamera;

	// Data
	var _data        : MenuEditorData;
	var _selectedIdx : Int  = -1;
	var _isDirty     : Bool = false;
	var _file        : FileReference;
	var _music       : FlxSound;

	// Live objects in preview (index -> FlxBasic)
	var _live : Map<Int,FlxBasic> = new Map();

	// Tab state
	var _tab        : String = "Items";
	var _tabGrps    : Map<String,FlxGroup>  = new Map();
	var _tabBgs     : Map<String,FlxSprite> = new Map();
	var _tabTxts    : Map<String,FlxText>   = new Map();

	// UI inputs
	var _inputs  : Map<String,FlxUIInputText>    = new Map();
	var _checks  : Map<String,FlxUICheckBox>     = new Map();
	var _dds     : Map<String,FlxUIDropDownMenu> = new Map();
	var _typeDD  : FlxUIDropDownMenu;

	// Item list group (rebuilt on refresh)
	var _listGrp  : FlxGroup;
	var _groupGrp : FlxGroup;

	// Preview selector highlight
	var _selector : FlxSprite;

	// Drag
	var _dragIdx  : Int   = -1;
	var _dragOffX : Float = 0;
	var _dragOffY : Float = 0;

	// Hit rects
	var _btns : Array<{id:String, x:Float, y:Float, w:Float, h:Float}> = [];

	// Status
	var _statusTxt : FlxText;

	// ─────────────────────────────────────────────────────────────────────────
	override public function create() : Void
	{
		funkin.debug.themes.EditorTheme.load();
		FlxG.mouse.visible = true;

		camUI = new FlxCamera();
		camUI.bgColor = C_BG;
		FlxG.cameras.reset(camUI);

		var prevW = FlxG.width - PANEL_W;
		var prevH = FlxG.height - TOOLBAR_H - STATUS_H;
		camPreview = new FlxCamera(0, TOOLBAR_H, prevW, prevH);
		camPreview.bgColor = C_PREVIEW;
		FlxG.cameras.add(camPreview, false);
		FlxCamera.defaultCameras = [camUI];

		_data = _mkDefaultMenu();
		_buildBg();
		_buildToolbar();
		_buildPanel();
		_buildStatusBar();
		_buildPreviewGrid();
		_rebuildPreview();
		_refreshAll();

		super.create();
	}

	// ─── Default templates ────────────────────────────────────────────────────

	function _mkDefaultMenu() : MenuEditorData
	{
		return {
			name: "my_custom_menu", title: "MY MENU",
			bgColor: "0xFF1A1A2E", bgImage: "", bgScrollX: 0.0, bgScrollY: 0.0,
			music: "", transition: "fade", transitionCode: "", bgScroll: true,
			groups: [ {id:"main", name:"Main", visible:true, locked:false, color:"0xFF00D9FF"} ],
			items: [
				_mkItem("PLAY",    "play",    "Alphabet", "0xFFFFFFFF", "main"),
				_mkItem("OPTIONS", "options", "Alphabet", "0xFFAAAAAA", "main"),
				_mkItem("CREDITS", "credits", "Alphabet", "0xFFAAAAAA", "main"),
				_mkItem("",        "",        "Separator","0xFF333333", "main"),
				_mkItem("EXIT",    "exit",    "Alphabet", "0xFFFF4444", "main"),
			]
		};
	}

	function _mkItem(lbl:String, act:String, type:String, col:String, grpId:String) : MenuEditorItemData
	{
		return {
			label: lbl, action: act, type: type, color: col, script: "",
			visible: true, enabled: true, x: 0.0, y: 0.0, groupId: grpId,
			fontSize: 24, bold: false, spritePath: "", animPath: "", animName: "idle",
			scaleX: 1.0, scaleY: 1.0, alpha: 1.0, isMenuItem: true
		};
	}

	// ─── UI build ─────────────────────────────────────────────────────────────

	function _buildBg() : Void
	{
		var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, C_BG);
		bg.scrollFactor.set(); bg.cameras = [camUI]; add(bg);
		var sep = new FlxSprite(FlxG.width - PANEL_W - 1, TOOLBAR_H).makeGraphic(2, FlxG.height - TOOLBAR_H - STATUS_H, C_ACCENT);
		sep.alpha = 0.2; sep.scrollFactor.set(); sep.cameras = [camUI]; add(sep);
	}

	function _buildToolbar() : Void
	{
		var tb = new FlxSprite(0,0).makeGraphic(FlxG.width, TOOLBAR_H, 0xFF111120);
		tb.scrollFactor.set(); tb.cameras = [camUI]; add(tb);
		var ln = new FlxSprite(0, TOOLBAR_H-2).makeGraphic(FlxG.width, 2, C_ACCENT);
		ln.alpha = 0.4; ln.scrollFactor.set(); ln.cameras = [camUI]; add(ln);

		var ttl = new FlxText(10, 11, 0, "🎛 MENU EDITOR", 14);
		ttl.setFormat(Paths.font("vcr.ttf"), 14, C_ACCENT, LEFT);
		ttl.scrollFactor.set(); ttl.cameras = [camUI]; add(ttl);

		var nm = new FlxText(160, 12, FlxG.width - PANEL_W - 170, _data.name, 12);
		nm.setFormat(Paths.font("vcr.ttf"), 12, C_GRAY, LEFT);
		nm.scrollFactor.set(); nm.cameras = [camUI]; add(nm);

		var actions = [
			{id:"back",    lbl:"← Back",     col:0xFF2A1515, tc:C_RED},
			{id:"tmpl",    lbl:"📋 Tmpl",     col:0xFF1A1A2A, tc:C_GRAY},
			{id:"load",    lbl:"📂 Load",     col:0xFF1A2820, tc:C_YELLOW},
			{id:"save",    lbl:"💾 Save",     col:0xFF0E2020, tc:C_ACCENT},
			{id:"export",  lbl:"📤 Script",   col:0xFF200E28, tc:0xFFCC88FF},
			{id:"testlive",lbl:"▶ Test",      col:0xFF0E200E, tc:C_GREEN},
		];
		var bx = FlxG.width - 5.0;
		for (i in 0...actions.length) {
			var a = actions[actions.length - 1 - i];
			bx -= 80;
			_spr(bx, 5, 78, 30, a.col, camUI);
			_txt(bx, 12, 78, a.lbl, 10, a.tc, camUI);
			_reg(a.id, bx, 5, 78, 30);
		}
	}

	function _buildPreviewGrid() : Void
	{
		var prevW = FlxG.width - PANEL_W;
		var prevH = FlxG.height - TOOLBAR_H - STATUS_H;
		for (gx in 0...Std.int(prevW / 80)) {
			var gl = new FlxSprite(gx * 80, 0).makeGraphic(1, prevH, 0x08AAAAFF);
			gl.scrollFactor.set(); gl.cameras = [camPreview]; add(gl);
		}
		for (gy in 0...Std.int(prevH / 60)) {
			var gl = new FlxSprite(0, gy * 60).makeGraphic(prevW, 1, 0x08AAAAFF);
			gl.scrollFactor.set(); gl.cameras = [camPreview]; add(gl);
		}
		var wm = new FlxText(0, 6, FlxG.width - PANEL_W, "LIVE PREVIEW  •  1280×720", 10);
		wm.setFormat(Paths.font("vcr.ttf"), 10, 0x22FFFFFF, CENTER);
		wm.scrollFactor.set(); wm.cameras = [camUI]; add(wm);
	}

	// ─── Right Panel ──────────────────────────────────────────────────────────

	function _buildPanel() : Void
	{
		var px = FlxG.width - PANEL_W;
		var pbg = new FlxSprite(px, 0).makeGraphic(PANEL_W, FlxG.height - STATUS_H, C_PANEL);
		pbg.scrollFactor.set(); pbg.cameras = [camUI]; add(pbg);

		var tabs = ["Items", "Groups", "Settings"];
		var tw   = Std.int(PANEL_W / tabs.length);
		for (i in 0...tabs.length) {
			var t  = tabs[i];
			var tx = px + i * tw;
			var isA = t == _tab;
			var tbg = new FlxSprite(tx, 0).makeGraphic(tw, TAB_H, isA ? C_SELECTED : C_PANEL_ALT);
			tbg.scrollFactor.set(); tbg.cameras = [camUI]; add(tbg); _tabBgs.set(t, tbg);
			var ttx = new FlxText(tx, 8, tw, t, 10);
			ttx.setFormat(Paths.font("vcr.ttf"), 10, isA ? C_ACCENT : C_GRAY, CENTER);
			ttx.scrollFactor.set(); ttx.cameras = [camUI]; add(ttx); _tabTxts.set(t, ttx);
			_reg('tab_$t', tx, 0, tw, TAB_H);
			var grp = new FlxGroup(); _tabGrps.set(t, grp); add(grp);
		}
		_buildItemsTab(px);
		_buildGroupsTab(px);
		_buildSettingsTab(px);
		_setTabVis();
	}

	function _setTabVis() : Void
	{
		for (t in _tabGrps.keys())  { var g = _tabGrps.get(t);  if (g  != null) g.visible = (t == _tab); }
		for (t in _tabBgs.keys())   { var isA = t == _tab; _tabBgs.get(t).color  = isA ? C_SELECTED : C_PANEL_ALT; }
		for (t in _tabTxts.keys())  { var isA = t == _tab; _tabTxts.get(t).color = isA ? C_ACCENT   : C_GRAY; }
	}

	// ── Items Tab ──────────────────────────────────────────────────────────

	function _buildItemsTab(px:Float) : Void
	{
		var g = _tabGrps.get("Items");
		var cw = PANEL_W - 16;
		var y  = TAB_H + 4.0;

		// Type DD
		_mkL(g, px+8, y, "Type for new:", C_GRAY); y += 14;
		var iTypes = ["Button","Alphabet","Image","AnimatedSprite","Text","Separator","Script"];
		_typeDD = new FlxUIDropDownMenu(px+8, y, FlxUIDropDownMenu.makeStrIdLabelArray(iTypes, true), function(_){});
		_typeDD.scrollFactor.set(); _typeDD.cameras = [camUI]; g.add(_typeDD); add(_typeDD); y += 28;

		// Buttons row
		_mkTBtn(g, px+8,   y, 58, 24, "+ Add",  0xFF0A2A0A, C_GREEN,  "add_item");
		_mkTBtn(g, px+70,  y, 58, 24, "- Del",  0xFF2A0A0A, C_RED,    "del_item");
		_mkTBtn(g, px+132, y, 58, 24, "↑ Up",   0xFF0A0A2A, C_ACCENT, "up_item");
		_mkTBtn(g, px+194, y, 58, 24, "↓ Down", 0xFF0A0A2A, C_ACCENT, "down_item");
		y += 28;
		_mkTBtn(g, px+8,   y, 88, 22, "⎘ Dup",       0xFF0A1A1A, C_ACCENT,    "dup_item");
		_mkTBtn(g, px+100, y, 88, 22, "📋 Defaults",  0xFF1A0A1A, 0xFFCC88FF, "item_tmpl");
		y += 26;

		// Item list (rebuilt)
		_mkL(g, px+8, y, "Items:", C_GRAY); y += 14;
		_listGrp = new FlxGroup(); _listGrp.cameras = [camUI]; g.add(_listGrp); add(_listGrp);
		y += MAX_ROWS * ROW_H + 4;

		_mkSep(g, px+8, y, cw); y += 8;
		_mkL(g, px+8, y, "── Selected Item ──", 0xFF3A4A5A); y += 14;

		// Label
		_mkL(g, px+8, y, "Label / Text:", C_GRAY); y += 13;
		_addIn(g, "label", px+8, y, cw, "", 11); y += 22;

		// Action
		_mkL(g, px+8, y, "Action:", C_GRAY); y += 13;
		_addIn(g, "action", px+8, y, cw, "", 11); y += 22;

		// Color
		_mkL(g, px+8, y, "Color (0xFFRRGGBB):", C_GRAY); y += 13;
		_addIn(g, "color", px+8, y, cw, "0xFFFFFFFF", 11); y += 22;

		// Pos
		_mkL(g, px+8, y, "X  /  Y:", C_GRAY); y += 13;
		var hw = Std.int(cw/2) - 3;
		_addIn(g, "posX", px+8,      y, hw, "0", 11);
		_addIn(g, "posY", px+8+hw+6, y, hw, "0", 11);
		y += 22;

		// Scale
		_mkL(g, px+8, y, "Scale X  /  Y:", C_GRAY); y += 13;
		_addIn(g, "scaleX", px+8,      y, hw, "1", 11);
		_addIn(g, "scaleY", px+8+hw+6, y, hw, "1", 11);
		y += 22;

		// Font size + bold
		_mkL(g, px+8, y, "Font size:", C_GRAY); y += 13;
		_addIn(g, "fontSize", px+8, y, 56, "24", 11);
		_addCB(g, "bold",       px+68,  y, "Bold",       50);
		_addCB(g, "isMenuItem", px+128, y, "asMenuItem", 80);
		y += 24;

		// Sprite path + browse
		_mkL(g, px+8, y, "Sprite path:", C_GRAY); y += 13;
		_addIn(g, "spritePath", px+8, y, cw-28, "", 10);
		_mkTBtn(g, px+8+cw-26, y, 26, 18, "…", 0xFF1A1A2A, C_ACCENT, "browse_sprite");
		y += 22;

		// Anim name
		_mkL(g, px+8, y, "Anim name:", C_GRAY); y += 13;
		_addIn(g, "animName", px+8, y, cw, "idle", 11);
		y += 22;

		// Alpha
		_mkL(g, px+8, y, "Alpha (0.0-1.0):", C_GRAY); y += 13;
		_addIn(g, "alpha", px+8, y, 60, "1", 11);
		_addCB(g, "visible",  px+72,  y, "Vis",   50);
		_addCB(g, "enabled",  px+132, y, "Enbl",  50);
		y += 24;

		// Script
		_mkL(g, px+8, y, "Item Script:", C_GRAY); y += 13;
		_addIn(g, "script", px+8, y, cw-92, "", 10);
		_mkTBtn(g, px+8+cw-90, y, 90, 18, "📝 Full Editor", 0xFF0E0E28, 0xFFCC88FF, "edit_script");
		y += 22;

		// Apply
		_mkTBtn(g, px+8, y, cw, 26, "✔ Apply Changes", C_SELECTED, C_ACCENT, "apply_item");
	}

	// ── Groups Tab ────────────────────────────────────────────────────────

	function _buildGroupsTab(px:Float) : Void
	{
		var g  = _tabGrps.get("Groups");
		var cw = PANEL_W - 16;
		var y  = TAB_H + 8.0;

		_mkL(g, px+8, y, "Layers / Groups:", C_GRAY); y += 14;
		_groupGrp = new FlxGroup(); _groupGrp.cameras = [camUI]; g.add(_groupGrp); add(_groupGrp);
		y += 8 * ROW_H + 4;

		_mkTBtn(g, px+8,   y, 80, 24, "+ Group", 0xFF0A2A0A, C_GREEN, "add_group");
		_mkTBtn(g, px+92,  y, 80, 24, "- Delete",0xFF2A0A0A, C_RED,   "del_group");
		y += 30;

		_mkSep(g, px+8, y, cw); y += 8;
		_mkL(g, px+8, y, "── Selected Group ──", 0xFF3A4A5A); y += 14;

		_mkL(g, px+8, y, "Name:", C_GRAY); y += 13;
		_addIn(g, "groupName", px+8, y, cw, "", 11); y += 22;

		_mkL(g, px+8, y, "Color:", C_GRAY); y += 13;
		_addIn(g, "groupColor", px+8, y, cw, "0xFF00D9FF", 11); y += 22;

		_addCB(g, "groupLocked", px+8, y, "Lock group", 100); y += 26;

		_mkTBtn(g, px+8, y, cw, 24, "✔ Apply Group", C_SELECTED, C_ACCENT, "apply_group");
		y += 30;

		_mkSep(g, px+8, y, cw); y += 8;
		_mkL(g, px+8, y, "Assign selected item to group:", C_GRAY); y += 14;

		var gnames = [for (gr in (_data.groups ?? [])) gr.name];
		if (gnames.length == 0) gnames = ["main"];
		var gdd = new FlxUIDropDownMenu(px+8, y, FlxUIDropDownMenu.makeStrIdLabelArray(gnames, true), function(_){});
		gdd.scrollFactor.set(); gdd.cameras = [camUI]; g.add(gdd); add(gdd); _dds.set("groupAssign", gdd); y += 28;

		_mkTBtn(g, px+8, y, cw, 24, "Assign to Group", C_SELECTED, C_YELLOW, "assign_group");
	}

	// ── Settings Tab ──────────────────────────────────────────────────────

	function _buildSettingsTab(px:Float) : Void
	{
		var g  = _tabGrps.get("Settings");
		var cw = PANEL_W - 16;
		var hw = Std.int(cw/2) - 3;
		var y  = TAB_H + 8.0;

		_mkL(g, px+8, y, "Menu ID:", C_GRAY);           y += 13; _addIn(g, "menuName",  px+8, y, cw, _data.name,  11); y += 22;
		_mkL(g, px+8, y, "Title (display):", C_GRAY);   y += 13; _addIn(g, "menuTitle", px+8, y, cw, _data.title, 11); y += 22;
		_mkL(g, px+8, y, "BG Color:", C_GRAY);          y += 13; _addIn(g, "bgColor",   px+8, y, cw, _data.bgColor,  11); y += 22;

		_mkL(g, px+8, y, "BG Image:", C_GRAY); y += 13;
		_addIn(g, "bgImage", px+8, y, cw-28, "", 10);
		_mkTBtn(g, px+8+cw-26, y, 26, 18, "…", 0xFF1A1A2A, C_ACCENT, "browse_bg");
		y += 22;

		_mkL(g, px+8, y, "BG Scroll speed X / Y:", C_GRAY); y += 13;
		_addIn(g, "bgScrollX", px+8,      y, hw, "0", 11);
		_addIn(g, "bgScrollY", px+8+hw+6, y, hw, "0", 11);
		y += 22;

		_mkL(g, px+8, y, "Music path:", C_GRAY); y += 13;
		_addIn(g, "music", px+8, y, cw-62, "", 11);
		_mkTBtn(g, px+8+cw-60, y, 60, 18, "▶ Test", 0xFF0A200A, C_GREEN, "test_music");
		y += 22;

		_mkL(g, px+8, y, "Transition:", C_GRAY); y += 13;
		var transitions = ["fade","slide_left","slide_right","zoom","instant","custom"];
		var tdd = new FlxUIDropDownMenu(px+8, y, FlxUIDropDownMenu.makeStrIdLabelArray(transitions, true),
			function(id:String) { var idx = Std.parseInt(id) ?? 0; _data.transition = transitions[idx]; });
		tdd.scrollFactor.set(); tdd.cameras = [camUI]; g.add(tdd); add(tdd); _dds.set("transition", tdd); y += 28;

		_mkTBtn(g, px+8, y, cw, 24, "📝 Edit Custom Transition (HScript)", 0xFF0E0E28, 0xFFCC88FF, "edit_trans");
		y += 28;

		_addCB(g, "bgScroll", px+8, y, "Scrolling BG", 120); y += 26;

		_mkTBtn(g, px+8, y, cw, 26, "✔ Apply Settings", C_SELECTED, C_ACCENT, "apply_settings");
		y += 32;

		_mkSep(g, px+8, y, cw); y += 8;
		_mkL(g, px+8, y, "Load template:", C_GRAY); y += 14;
		_mkTBtn(g, px+8,   y, 86, 24, "🏠 MainMenu",  0xFF0E1A0E, C_GREEN,  "tmpl_main");
		_mkTBtn(g, px+98,  y, 86, 24, "🎵 Freeplay",  0xFF0E0E1A, C_ACCENT, "tmpl_free");
		_mkTBtn(g, px+188, y, 86, 24, "📖 StoryMenu", 0xFF1A0E0E, C_ORANGE, "tmpl_story");
	}

	function _buildStatusBar() : Void
	{
		var sy  = FlxG.height - STATUS_H;
		var sbb = new FlxSprite(0, sy).makeGraphic(FlxG.width, STATUS_H, C_DARK);
		sbb.scrollFactor.set(); sbb.cameras = [camUI]; add(sbb);
		var sbl = new FlxSprite(0, sy).makeGraphic(FlxG.width, 1, C_ACCENT);
		sbl.alpha = 0.2; sbl.scrollFactor.set(); sbl.cameras = [camUI]; add(sbl);
		_statusTxt = new FlxText(8, sy+5, FlxG.width-16, '', 10);
		_statusTxt.setFormat(Paths.font("vcr.ttf"), 10, C_GRAY, LEFT);
		_statusTxt.scrollFactor.set(); _statusTxt.cameras = [camUI]; add(_statusTxt);
		_st('Menu Editor ready');
	}

	// ─────────────────────────────────────────────────────────────────────────
	//  Live Preview
	// ─────────────────────────────────────────────────────────────────────────

	function _rebuildPreview() : Void
	{
		for (k in _live.keys()) {
			var obj = _live.get(k);
			if (obj != null) { remove(obj, true); try { obj.destroy(); } catch(_) {} }
		}
		_live.clear();

		if (_selector != null) { remove(_selector, true); try { _selector.destroy(); } catch(_) {} _selector = null; }

		// BG color
		var bgCol = _parseColor(_data.bgColor, 0xFF1A1A2E);
		camPreview.bgColor = bgCol;

		// BG image
		if (_data.bgImage != null && _data.bgImage.trim() != "") {
			try {
				var bgspr = new FlxSprite(0, 0);
				bgspr.loadGraphic(_data.bgImage);
				bgspr.setGraphicSize(FlxG.width - PANEL_W, FlxG.height - TOOLBAR_H - STATUS_H);
				bgspr.updateHitbox();
				bgspr.cameras = [camPreview]; add(bgspr); _live.set(-1, bgspr);
			} catch (_) {}
		}

		// Title
		if (_data.title != null && _data.title.trim() != "") {
			var titleObj : FlxBasic;
			try {
				var al = new Alphabet(0, 8, _data.title, true);
				al.screenCenter(X); al.cameras = [camPreview]; titleObj = al;
			} catch (_) {
				var ft = new FlxText(0, 12, FlxG.width - PANEL_W, _data.title, 22);
				ft.setFormat(Paths.font("vcr.ttf"), 22, C_WHITE, CENTER);
				ft.cameras = [camPreview]; titleObj = ft;
			}
			add(titleObj); _live.set(-2, titleObj);
		}

		// Group vis map
		var gvis : Map<String,Bool> = new Map();
		for (gr in (_data.groups ?? [])) gvis.set(gr.id, gr.visible);

		var prevW  = FlxG.width - PANEL_W;
		var startY = 80.0;
		var spacing = 50.0;

		for (i in 0..._data.items.length) {
			var it = _data.items[i];
			if (!it.visible) continue;
			if (it.groupId != null && it.groupId != "" && gvis.exists(it.groupId) && !gvis.get(it.groupId)) continue;

			var ix = it.x != 0 ? it.x : 0.0;
			var iy = it.y != 0 ? it.y : startY + i * spacing;
			var obj : FlxBasic = null;

			switch (it.type) {
				case "Alphabet":
					try {
						var al = new Alphabet(ix, iy, it.label != "" ? it.label : "(empty)", it.bold);
						al.isMenuItem = it.isMenuItem;
						if (it.x == 0) al.screenCenter(X);
						al.alpha   = it.alpha;
						al.cameras = [camPreview];
						obj = al;
					} catch (e:Dynamic) {
						var ft = new FlxText(ix, iy, prevW - 20, it.label, it.fontSize);
						ft.setFormat(Paths.font("vcr.ttf"), it.fontSize, _parseColor(it.color, C_WHITE), CENTER);
						ft.alpha = it.alpha; ft.cameras = [camPreview]; obj = ft;
					}

				case "Button", "Text":
					var ft = new FlxText(ix, iy, it.x == 0 ? prevW - 20 : 400, it.label, it.fontSize);
					ft.setFormat(Paths.font("vcr.ttf"), it.fontSize, _parseColor(it.color, C_WHITE),
						it.x == 0 ? CENTER : LEFT);
					if (i == _selectedIdx) ft.color = C_ACCENT;
					ft.alpha = it.alpha; ft.cameras = [camPreview]; obj = ft;

				case "Separator":
					var sp = new FlxSprite(20, iy + 5).makeGraphic(prevW - 40, 2, _parseColor(it.color, 0xFF333333));
					sp.cameras = [camPreview]; obj = sp;

				case "Image":
					var spr = new FlxSprite(ix, iy);
					if (it.spritePath != null && it.spritePath.trim() != "") {
						try { spr.loadGraphic(it.spritePath); } catch (_) { spr.makeGraphic(80, 80, _parseColor(it.color, 0xFF4488FF)); }
					} else { spr.makeGraphic(80, 80, _parseColor(it.color, 0xFF4488FF)); }
					spr.scale.set(it.scaleX, it.scaleY); spr.updateHitbox();
					spr.alpha = it.alpha; spr.cameras = [camPreview]; obj = spr;

				case "AnimatedSprite":
					var spr = new FlxSprite(ix, iy);
					if (it.spritePath != null && it.spritePath.trim() != "") {
						try {
							var fr = flixel.graphics.frames.FlxAtlasFrames.fromSparrow(it.spritePath, it.animPath ?? "");
							spr.frames = fr;
							spr.animation.addByPrefix(it.animName ?? "idle", it.animName ?? "idle", 24, true);
							spr.animation.play(it.animName ?? "idle");
						} catch (_) { spr.makeGraphic(80, 80, _parseColor(it.color, 0xFF44FF88)); }
					} else { spr.makeGraphic(80, 80, _parseColor(it.color, 0xFF44FF88)); }
					spr.scale.set(it.scaleX, it.scaleY); spr.updateHitbox();
					spr.alpha = it.alpha; spr.cameras = [camPreview]; obj = spr;

				case "Script":
					var sb = new FlxSprite(it.x == 0 ? prevW/2 - 60 : ix, iy).makeGraphic(120, 26, 0xFF1A0A2A);
					sb.cameras = [camPreview]; add(sb); _live.set(i * 2 + 2000, sb);
					var st = new FlxText(it.x == 0 ? prevW/2 - 60 : ix, iy + 6, 120,
						"📜 " + (it.label != "" ? it.label : it.action), 10);
					st.setFormat(Paths.font("vcr.ttf"), 10, 0xFFAA88FF, CENTER);
					st.cameras = [camPreview]; add(st); _live.set(i * 2 + 2001, st);
					continue;

				default:
					var spr = new FlxSprite(ix, iy).makeGraphic(100, 30, _parseColor(it.color, C_ACCENT));
					spr.cameras = [camPreview]; obj = spr;
			}

			if (obj != null) { add(obj); _live.set(i, obj); }
		}

		// Selection highlight
		var pw = FlxG.width - PANEL_W;
		_selector = new FlxSprite(0, 0).makeGraphic(pw - 20, 46, 0x00000000, true);
		flixel.util.FlxSpriteUtil.drawRect(_selector, 0,  0,  pw - 20, 2,  0xCC00D9FF);
		flixel.util.FlxSpriteUtil.drawRect(_selector, 0, 44,  pw - 20, 2,  0xCC00D9FF);
		flixel.util.FlxSpriteUtil.drawRect(_selector, 0,  0,  2, 46, 0xCC00D9FF);
		flixel.util.FlxSpriteUtil.drawRect(_selector, pw - 22, 0, 2, 46, 0xCC00D9FF);
		_selector.scrollFactor.set(); _selector.cameras = [camPreview]; _selector.visible = false;
		add(_selector);
		_updateSel();
	}

	function _updateSel() : Void
	{
		if (_selector == null || _selectedIdx < 0 || _selectedIdx >= _data.items.length) {
			if (_selector != null) _selector.visible = false; return;
		}
		var obj = _live.get(_selectedIdx);
		if (obj == null) { _selector.visible = false; return; }
		var spr = Std.downcast(obj, FlxSprite);
		var grp = Std.downcast(obj, flixel.group.FlxSpriteGroup);
		if      (spr != null) { _selector.x = spr.x - 10; _selector.y = spr.y - 3; _selector.visible = true; }
		else if (grp != null) { _selector.x = grp.x - 10; _selector.y = grp.y - 3; _selector.visible = true; }
	}

	// ─────────────────────────────────────────────────────────────────────────
	//  Refresh panels
	// ─────────────────────────────────────────────────────────────────────────

	function _refreshAll() : Void
	{
		_refreshItemList();
		_refreshGroupList();
		_syncSettingsInputs();
		_loadPropInputs();
	}

	function _refreshItemList() : Void
	{
		if (_listGrp == null) return;
		_listGrp.clear();
		_btns = _btns.filter(b -> !StringTools.startsWith(b.id, "row_"));

		var px = FlxG.width - PANEL_W;
		var sy = TAB_H + 62.0;
		var cw = PANEL_W - 16;

		for (i in 0...Std.int(Math.min(_data.items.length, MAX_ROWS))) {
			var it  = _data.items[i];
			var iy  = sy + i * ROW_H;
			var isS = i == _selectedIdx;
			var tc  = TYPE_COLORS.exists(it.type) ? TYPE_COLORS.get(it.type) : C_GRAY;
			var gc  = _getGroupColor(it.groupId ?? "");

			var ibg = new FlxSprite(px+8, iy).makeGraphic(cw, ROW_H-1, isS ? C_SELECTED : C_PANEL_ALT);
			ibg.scrollFactor.set(); ibg.cameras = [camUI]; _listGrp.add(ibg); add(ibg);

			var tbar = new FlxSprite(px+8, iy).makeGraphic(3, ROW_H-1, tc);
			tbar.scrollFactor.set(); tbar.cameras = [camUI]; _listGrp.add(tbar); add(tbar);

			var gdot = new FlxSprite(px+13, iy + Std.int(ROW_H/2) - 4).makeGraphic(8, 8, gc);
			gdot.scrollFactor.set(); gdot.cameras = [camUI]; _listGrp.add(gdot); add(gdot);

			var lbl = it.label != "" ? it.label : '(${it.type})';
			var itx = new FlxText(px+24, iy + 7, cw-74, (it.visible ? "" : "🚫 ") + lbl, 10);
			itx.setFormat(Paths.font("vcr.ttf"), 10, isS ? C_ACCENT : (it.enabled ? C_WHITE : C_GRAY), LEFT);
			itx.scrollFactor.set(); itx.cameras = [camUI]; _listGrp.add(itx); add(itx);

			var badge = new FlxSprite(px+cw-62, iy+5).makeGraphic(58, ROW_H-10, tc);
			badge.alpha = 0.45; badge.scrollFactor.set(); badge.cameras = [camUI]; _listGrp.add(badge); add(badge);
			var btx = new FlxText(px+cw-62, iy+7, 58, it.type, 8);
			btx.setFormat(Paths.font("vcr.ttf"), 8, C_DARK, CENTER);
			btx.scrollFactor.set(); btx.cameras = [camUI]; _listGrp.add(btx); add(btx);

			_reg('row_$i', px+8, iy, cw, ROW_H);
		}

		if (_data.items.length > MAX_ROWS) {
			var ht = new FlxText(px+8, sy + MAX_ROWS * ROW_H + 2, cw,
				'↕ ${_data.items.length} items  (↑↓ arrow keys)', 9);
			ht.setFormat(Paths.font("vcr.ttf"), 9, C_GRAY, CENTER);
			ht.scrollFactor.set(); ht.cameras = [camUI]; _listGrp.add(ht); add(ht);
		}
	}

	function _refreshGroupList() : Void
	{
		if (_groupGrp == null) return;
		_groupGrp.clear();
		_btns = _btns.filter(b -> !StringTools.startsWith(b.id, "gvis_") || StringTools.startsWith(b.id, "grow_"));

		var px = FlxG.width - PANEL_W;
		var sy = TAB_H + 22.0;
		var cw = PANEL_W - 16;

		for (i in 0...Std.int(Math.min((_data.groups ?? []).length, 8))) {
			var gr  = _data.groups[i];
			var gy  = sy + i * ROW_H;
			var gc  = _parseColor(gr.color, C_ACCENT);
			var gbg = new FlxSprite(px+8, gy).makeGraphic(cw, ROW_H-1, C_PANEL_ALT);
			gbg.scrollFactor.set(); gbg.cameras = [camUI]; _groupGrp.add(gbg); add(gbg);
			var gbar = new FlxSprite(px+8, gy).makeGraphic(3, ROW_H-1, gc);
			gbar.scrollFactor.set(); gbar.cameras = [camUI]; _groupGrp.add(gbar); add(gbar);
			var gtx = new FlxText(px+14, gy+7, cw-56, gr.name + (gr.locked ? " 🔒" : ""), 10);
			gtx.setFormat(Paths.font("vcr.ttf"), 10, gr.visible ? C_WHITE : C_GRAY, LEFT);
			gtx.scrollFactor.set(); gtx.cameras = [camUI]; _groupGrp.add(gtx); add(gtx);

			// Eye toggle btn
			var eyBg = new FlxSprite(px+cw-44, gy+3).makeGraphic(22, ROW_H-8, 0xFF0A0A16);
			eyBg.scrollFactor.set(); eyBg.cameras = [camUI]; _groupGrp.add(eyBg); add(eyBg);
			var eyTx = new FlxText(px+cw-44, gy+6, 22, gr.visible ? "👁" : "☐", 9);
			eyTx.setFormat(Paths.font("vcr.ttf"), 9, gr.visible ? C_ACCENT : C_GRAY, CENTER);
			eyTx.scrollFactor.set(); eyTx.cameras = [camUI]; _groupGrp.add(eyTx); add(eyTx);
			_reg('gvis_$i', px+cw-44, gy+3, 22, ROW_H-8);

			var cnt = (_data.items ?? []).filter(it -> it.groupId == gr.id).length;
			var ctx = new FlxText(px+cw-20, gy+7, 20, '×$cnt', 9);
			ctx.setFormat(Paths.font("vcr.ttf"), 9, C_GRAY, RIGHT);
			ctx.scrollFactor.set(); ctx.cameras = [camUI]; _groupGrp.add(ctx); add(ctx);

			_reg('grow_$i', px+8, gy, cw-50, ROW_H);
		}
	}

	function _syncSettingsInputs() : Void
	{
		_si("menuName",  _data.name);
		_si("menuTitle", _data.title);
		_si("bgColor",   _data.bgColor);
		_si("bgImage",   _data.bgImage ?? "");
		_si("bgScrollX", Std.string(_data.bgScrollX));
		_si("bgScrollY", Std.string(_data.bgScrollY));
		_si("music",     _data.music ?? "");
		_sc("bgScroll",  _data.bgScroll);
	}

	function _loadPropInputs() : Void
	{
		if (_selectedIdx < 0 || _selectedIdx >= _data.items.length) return;
		var it = _data.items[_selectedIdx];
		_si("label",      it.label);
		_si("action",     it.action);
		_si("color",      it.color);
		_si("posX",       Std.string(Std.int(it.x)));
		_si("posY",       Std.string(Std.int(it.y)));
		_si("scaleX",     Std.string(it.scaleX));
		_si("scaleY",     Std.string(it.scaleY));
		_si("fontSize",   Std.string(it.fontSize));
		_si("spritePath", it.spritePath ?? "");
		_si("animName",   it.animName ?? "idle");
		_si("alpha",      Std.string(it.alpha));
		_si("script",     it.script ?? "");
		_sc("bold",       it.bold);
		_sc("isMenuItem", it.isMenuItem);
		_sc("visible",    it.visible);
		_sc("enabled",    it.enabled);
	}

	// ─────────────────────────────────────────────────────────────────────────
	//  Update
	// ─────────────────────────────────────────────────────────────────────────

	override public function update(elapsed:Float) : Void
	{
		super.update(elapsed);
		_handleClick();
		_handleDrag();
		_handleKeys();
		if (_data.bgScroll && camPreview != null) {
			camPreview.scroll.x += _data.bgScrollX * elapsed;
			camPreview.scroll.y += _data.bgScrollY * elapsed;
		}
	}

	function _handleClick() : Void
	{
		if (!FlxG.mouse.justPressed) return;
		var mx = FlxG.mouse.x; var my = FlxG.mouse.y;
		for (b in _btns) {
			if (mx >= b.x && mx <= b.x+b.w && my >= b.y && my <= b.y+b.h) { _onBtn(b.id); return; }
		}
		// Click in preview
		if (mx < FlxG.width - PANEL_W && my > TOOLBAR_H && my < FlxG.height - STATUS_H) {
			_hitPreview(mx, my - TOOLBAR_H);
		}
	}

	function _hitPreview(mx:Float, my:Float) : Void
	{
		var best = 9999.0; var bi = -1;
		for (i in 0..._data.items.length) {
			var obj = _live.get(i); if (obj == null) continue;
			var spr = Std.downcast(obj, FlxSprite);
			var grp = Std.downcast(obj, flixel.group.FlxSpriteGroup);
			var ox = 0.0; var oy = 0.0; var ow = 100.0; var oh = 40.0;
			if      (spr != null) { ox = spr.x; oy = spr.y; ow = spr.width;  oh = spr.height; }
			else if (grp != null) { ox = grp.x; oy = grp.y; ow = grp.width;  oh = grp.height; }
			if (mx >= ox-8 && mx <= ox+ow+8 && my >= oy-8 && my <= oy+oh+8) {
				var d = Math.abs(mx-(ox+ow/2)) + Math.abs(my-(oy+oh/2));
				if (d < best) { best = d; bi = i; }
			}
		}
		if (bi >= 0) {
			_selectedIdx = bi;
			_loadPropInputs(); _refreshItemList(); _updateSel();
			var obj = _live.get(bi);
			var spr = Std.downcast(obj, FlxSprite);
			if (spr != null) { _dragIdx = bi; _dragOffX = mx - spr.x; _dragOffY = my - spr.y; }
			_st('Selected: ${_data.items[bi].label} (${_data.items[bi].type}) — drag to reposition');
		}
	}

	function _handleDrag() : Void
	{
		if (_dragIdx < 0) return;
		if (FlxG.mouse.justReleased) {
			var obj = _live.get(_dragIdx);
			if (obj != null && _dragIdx < _data.items.length) {
				var spr = Std.downcast(obj, FlxSprite);
				var grp = Std.downcast(obj, flixel.group.FlxSpriteGroup);
				if      (spr != null) { _data.items[_dragIdx].x = spr.x; _data.items[_dragIdx].y = spr.y; }
				else if (grp != null) { _data.items[_dragIdx].x = grp.x; _data.items[_dragIdx].y = grp.y; }
			}
			_loadPropInputs(); _isDirty = true; _dragIdx = -1; return;
		}
		if (!FlxG.mouse.pressed) { _dragIdx = -1; return; }
		var mx = FlxG.mouse.x; var my = FlxG.mouse.y - TOOLBAR_H;
		var obj = _live.get(_dragIdx); if (obj == null) return;
		var spr = Std.downcast(obj, FlxSprite);
		var grp = Std.downcast(obj, flixel.group.FlxSpriteGroup);
		if      (spr != null) { spr.x = mx - _dragOffX; spr.y = my - _dragOffY; }
		else if (grp != null) { grp.x = mx - _dragOffX; grp.y = my - _dragOffY; }
		_updateSel();
	}

	function _handleKeys() : Void
	{
		if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.S) _save();
		if (FlxG.keys.justPressed.ESCAPE) _goBack();
		var foc = false;
		for (k in _inputs.keys()) { var inp = _inputs.get(k); if (inp != null && inp.hasFocus) { foc = true; break; } }
		if (foc) return;
		if (FlxG.keys.justPressed.DELETE  && _selectedIdx >= 0) _deleteItem();
		if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.D) _dupItem();
		if (FlxG.keys.justPressed.UP   && !FlxG.keys.pressed.SHIFT) { _selectedIdx = Std.int(Math.max(0, _selectedIdx-1)); _loadPropInputs(); _refreshItemList(); _updateSel(); }
		if (FlxG.keys.justPressed.DOWN && !FlxG.keys.pressed.SHIFT) { _selectedIdx = Std.int(Math.min(_data.items.length-1, _selectedIdx+1)); _loadPropInputs(); _refreshItemList(); _updateSel(); }
		if (FlxG.keys.justPressed.UP   && FlxG.keys.pressed.SHIFT)  _moveItem(-1);
		if (FlxG.keys.justPressed.DOWN && FlxG.keys.pressed.SHIFT)  _moveItem(1);
	}

	// ─────────────────────────────────────────────────────────────────────────
	//  Button dispatch
	// ─────────────────────────────────────────────────────────────────────────

	function _onBtn(id:String) : Void
	{
		switch (id) {
			case "back":           _goBack();
			case "save":           _save();
			case "load":           _load();
			case "export":         _export();
			case "testlive":       _testLive();
			case "tmpl":           _st('Use Settings tab → Load template');

			case "add_item":       _addItem();
			case "del_item":       _deleteItem();
			case "up_item":        _moveItem(-1);
			case "down_item":      _moveItem(1);
			case "dup_item":       _dupItem();
			case "item_tmpl":      _itemDefaults();
			case "apply_item":     _applyItemProps();
			case "edit_script":    _editItemScript();
			case "browse_sprite":  _browseFile("sprite");

			case "add_group":      _addGroup();
			case "del_group":      _delGroup();
			case "apply_group":    _applyGroup();
			case "assign_group":   _assignGroup();

			case "apply_settings": _applySettings();
			case "test_music":     _testMusic();
			case "browse_bg":      _browseFile("bg");
			case "edit_trans":     _editTransScript();
			case "tmpl_main":      _loadTemplate("main");
			case "tmpl_free":      _loadTemplate("free");
			case "tmpl_story":     _loadTemplate("story");

			case _ if (StringTools.startsWith(id, "tab_")):
				_tab = id.substr(4); _setTabVis();

			case _ if (StringTools.startsWith(id, "row_")):
				var idx = Std.parseInt(id.substr(4));
				if (idx != null) { _selectedIdx = idx; _loadPropInputs(); _refreshItemList(); _updateSel(); }

			case _ if (StringTools.startsWith(id, "grow_")):
				var idx = Std.parseInt(id.substr(5));
				if (idx != null && _data.groups != null && idx < _data.groups.length) {
					var gr = _data.groups[idx];
					_si("groupName", gr.name); _si("groupColor", gr.color); _sc("groupLocked", gr.locked);
				}

			case _ if (StringTools.startsWith(id, "gvis_")):
				var idx = Std.parseInt(id.substr(5));
				if (idx != null && _data.groups != null && idx < _data.groups.length) {
					_data.groups[idx].visible = !_data.groups[idx].visible;
					_refreshGroupList(); _rebuildPreview(); _isDirty = true;
					_st('Group "${_data.groups[idx].name}" ' + (_data.groups[idx].visible ? "shown" : "hidden"));
				}
		}
	}

	// ─────────────────────────────────────────────────────────────────────────
	//  Operations
	// ─────────────────────────────────────────────────────────────────────────

	function _addItem() : Void
	{
		var types = ["Button","Alphabet","Image","AnimatedSprite","Text","Separator","Script"];
		var ti = Std.parseInt(_typeDD?.selectedId ?? "1") ?? 1;
		var type = (ti >= 0 && ti < types.length) ? types[ti] : "Alphabet";
		var gid  = (_data.groups != null && _data.groups.length > 0) ? _data.groups[0].id : "main";
		_data.items.push(_mkItem("NEW ITEM", "action", type, "0xFFFFFFFF", gid));
		_selectedIdx = _data.items.length - 1;
		_loadPropInputs(); _refreshItemList(); _rebuildPreview(); _isDirty = true;
		_st('+ Added $type item');
	}

	function _deleteItem() : Void
	{
		if (_selectedIdx < 0 || _selectedIdx >= _data.items.length) return;
		var n = _data.items[_selectedIdx].label;
		_data.items.splice(_selectedIdx, 1);
		_selectedIdx = Std.int(Math.max(-1, Math.min(_data.items.length-1, _selectedIdx)));
		_loadPropInputs(); _refreshItemList(); _rebuildPreview(); _isDirty = true;
		_st('🗑 Deleted "$n"');
	}

	function _moveItem(d:Int) : Void
	{
		var ni = _selectedIdx + d;
		if (ni < 0 || ni >= _data.items.length) return;
		var tmp = _data.items[_selectedIdx]; _data.items[_selectedIdx] = _data.items[ni]; _data.items[ni] = tmp;
		_selectedIdx = ni;
		_refreshItemList(); _rebuildPreview(); _isDirty = true;
	}

	function _dupItem() : Void
	{
		if (_selectedIdx < 0 || _selectedIdx >= _data.items.length) return;
		var s = _data.items[_selectedIdx];
		_data.items.insert(_selectedIdx+1, {
			label:s.label+"_copy", action:s.action, type:s.type, color:s.color, script:s.script,
			visible:s.visible, enabled:s.enabled, x:s.x+20, y:s.y+20, groupId:s.groupId,
			fontSize:s.fontSize, bold:s.bold, spritePath:s.spritePath, animPath:s.animPath,
			animName:s.animName, scaleX:s.scaleX, scaleY:s.scaleY, alpha:s.alpha, isMenuItem:s.isMenuItem
		});
		_selectedIdx++;
		_refreshItemList(); _rebuildPreview(); _isDirty = true;
		_st('⎘ Duplicated "${s.label}"');
	}

	function _itemDefaults() : Void
	{
		if (_selectedIdx < 0) { _addItem(); return; }
		var it = _data.items[_selectedIdx];
		switch (it.type) {
			case "Alphabet":  it.fontSize = 24; it.bold = false; it.isMenuItem = true;  it.color = "0xFFFFFFFF";
			case "Button":    it.fontSize = 20; it.bold = false; it.isMenuItem = false; it.color = "0xFF4488FF";
			case "Text":      it.fontSize = 16; it.bold = false; it.color = "0xFFCCCCCC";
			case "Separator": it.color = "0xFF333333";
			default:          it.scaleX = 1; it.scaleY = 1; it.alpha = 1;
		}
		_loadPropInputs(); _rebuildPreview();
		_st('📋 Defaults applied for ${it.type}');
	}

	function _applyItemProps() : Void
	{
		if (_selectedIdx < 0 || _selectedIdx >= _data.items.length) return;
		var it = _data.items[_selectedIdx];
		it.label      = _gi("label");
		it.action     = _gi("action");
		it.color      = _gi("color");
		it.x          = _pf(_gi("posX"),      it.x);
		it.y          = _pf(_gi("posY"),      it.y);
		it.scaleX     = _pf(_gi("scaleX"),    1.0);
		it.scaleY     = _pf(_gi("scaleY"),    1.0);
		it.fontSize   = Std.parseInt(_gi("fontSize")) ?? 24;
		it.spritePath = _gi("spritePath");
		it.animName   = _gi("animName");
		it.alpha      = _pf(_gi("alpha"),     1.0);
		it.script     = _gi("script");
		it.bold       = _gc("bold");
		it.isMenuItem = _gc("isMenuItem");
		it.visible    = _gc("visible");
		it.enabled    = _gc("enabled");
		_refreshItemList(); _rebuildPreview(); _isDirty = true;
		_st('✔ "${it.label}" updated');
	}

	function _editItemScript() : Void
	{
		if (_selectedIdx < 0 || _selectedIdx >= _data.items.length) return;
		var it   = _data.items[_selectedIdx];
		var name = (it.label != "" ? it.label.toLowerCase().replace(" ","_") : "item") + "_script";
		openSubState(new ScriptEditorSubState(null, name, camUI));
		_st('📝 Script editor → "${it.label}"');
	}

	function _browseFile(ctx:String) : Void
	{
		_file = new FileReference();
		_file.addEventListener(Event.SELECT, function(_) {
			if (ctx == "sprite" && _selectedIdx >= 0) {
				_data.items[_selectedIdx].spritePath = _file.name;
				_si("spritePath", _file.name);
				_rebuildPreview();
			} else if (ctx == "bg") {
				_data.bgImage = _file.name;
				_si("bgImage", _file.name);
				_rebuildPreview();
			}
			_st('📁 ${ctx}: ${_file.name}');
		});
		_file.browse([
			new openfl.net.FileFilter("Images / Atlas (*.png,*.xml)", "*.png;*.xml"),
			new openfl.net.FileFilter("All files", "*.*")
		]);
	}

	// Groups
	function _addGroup() : Void
	{
		if (_data.groups == null) _data.groups = [];
		var id = "grp_" + Std.string(_data.groups.length);
		_data.groups.push({id:id, name:"Group " + (_data.groups.length+1), visible:true, locked:false, color:"0xFF00FF88"});
		_refreshGroupList(); _isDirty = true; _st('➕ Group added');
	}

	function _delGroup() : Void
	{
		if (_data.groups == null || _data.groups.length == 0) return;
		_data.groups.pop(); _refreshGroupList(); _isDirty = true; _st('🗑 Group deleted');
	}

	function _applyGroup() : Void
	{
		var nm = _gi("groupName");
		if (_data.groups == null || _data.groups.length == 0) return;
		// Try to find by current name, otherwise update index 0
		var found = false;
		for (gr in _data.groups) if (gr.name == nm) {
			gr.color = _gi("groupColor"); gr.locked = _gc("groupLocked"); found = true; break;
		}
		if (!found) { _data.groups[0].name = nm; _data.groups[0].color = _gi("groupColor"); _data.groups[0].locked = _gc("groupLocked"); }
		_refreshGroupList(); _rebuildPreview(); _isDirty = true; _st('✔ Group updated');
	}

	function _assignGroup() : Void
	{
		if (_selectedIdx < 0 || _selectedIdx >= _data.items.length) return;
		var dd  = _dds.get("groupAssign");
		var idx = Std.parseInt(dd?.selectedId ?? "0") ?? 0;
		if (_data.groups != null && idx < _data.groups.length) {
			_data.items[_selectedIdx].groupId = _data.groups[idx].id;
			_rebuildPreview(); _refreshItemList(); _isDirty = true;
			_st('Assigned to "${_data.groups[idx].name}"');
		}
	}

	// Settings
	function _applySettings() : Void
	{
		_data.name      = _gi("menuName");
		_data.title     = _gi("menuTitle");
		_data.bgColor   = _gi("bgColor");
		_data.bgImage   = _gi("bgImage");
		_data.bgScrollX = _pf(_gi("bgScrollX"), 0);
		_data.bgScrollY = _pf(_gi("bgScrollY"), 0);
		_data.music     = _gi("music");
		_data.bgScroll  = _gc("bgScroll");
		_rebuildPreview(); _isDirty = true; _st('✔ Settings applied');
	}

	function _testMusic() : Void
	{
		var path = _gi("music");
		if (path == null || path.trim() == "") { _st('⚠ No music path'); return; }
		if (_music != null) { _music.stop(); _music = null; }
		try { _music = FlxG.sound.play(path, 0.7, true); _st('▶ Music: $path'); }
		catch (_) { _st('❌ Music not found: $path'); }
	}

	function _editTransScript() : Void
	{
		openSubState(new ScriptEditorSubState(null, "custom_transition", camUI));
		_st('📝 Transition script editor');
	}

	function _loadTemplate(t:String) : Void
	{
		_data = switch(t) {
			case "free":
				var d = _mkDefaultMenu(); d.name = "freeplay_custom"; d.title = "FREEPLAY"; d.bgColor = "0xFF1A0E2E";
				d.items = [_mkItem("← BACK","back","Alphabet","0xFFAAAAAA","main"), _mkItem("SONG NAME","select","Alphabet","0xFFFFFFFF","main")]; d;
			case "story":
				var d = _mkDefaultMenu(); d.name = "story_custom"; d.title = "STORY MODE"; d.bgColor = "0xFF1A1E0A";
				d.items = [_mkItem("WEEK 1","week1","Button","0xFF44FF88","main"), _mkItem("WEEK 2","week2","Button","0xFFFFCC44","main")]; d;
			default: _mkDefaultMenu();
		};
		_selectedIdx = -1; _refreshAll(); _rebuildPreview(); _isDirty = true;
		_st('📋 Template: $t');
	}

	// Save / Load / Export
	function _save() : Void
	{
		var json = Json.stringify(_data, "\t");
		#if sys
		try {
			var dir = "assets/data/menus/";
			if (!sys.FileSystem.exists(dir)) sys.FileSystem.createDirectory(dir);
			sys.io.File.saveContent(dir + _data.name + ".json", json);
			_isDirty = false; _st('💾 Saved → assets/data/menus/${_data.name}.json'); return;
		} catch (_) {}
		#end
		_file = new FileReference();
		_file.addEventListener(Event.COMPLETE, function(_) { _isDirty = false; _st('💾 Saved!'); });
		_file.save(json, _data.name + ".json");
	}

	function _load() : Void
	{
		_file = new FileReference();
		_file.addEventListener(Event.SELECT, function(_) {
			_file.addEventListener(Event.COMPLETE, function(_) {
				try {
					var d : MenuEditorData = cast Json.parse(_file.data.toString());
					if (d.groups == null)       d.groups = [{id:"main",name:"Main",visible:true,locked:false,color:"0xFF00D9FF"}];
					if (d.items == null)         d.items  = [];
					if (d.bgScrollX == null)     d.bgScrollX = 0;
					if (d.bgScrollY == null)     d.bgScrollY = 0;
					if (d.transitionCode == null) d.transitionCode = "";
					_data = d; _selectedIdx = -1;
					_refreshAll(); _rebuildPreview(); _st('📂 Loaded: ${_data.name}');
				} catch (e:Dynamic) { _st('❌ Error: $e'); }
			});
			_file.load();
		});
		_file.browse([new openfl.net.FileFilter("Menu JSON", "*.json")]);
	}

	function _export() : Void
	{
		var lines = ['// Auto-generated: ${_data.name}  by MenuEditor v2', '', 'function buildMenu(state) {',
			'  state.bgColor = ${_data.bgColor};', '  state.title = "${_data.title}";'];
		if (_data.music != null && _data.music.trim() != "") lines.push('  state.playMusic("${_data.music}");');
		for (it in _data.items) {
			if      (it.type == "Separator") lines.push('  state.addSeparator();');
			else if (it.type == "Alphabet")  lines.push('  state.addAlphabet("${it.label}", "${it.action}", ${it.x}, ${it.y}, ${it.bold});');
			else     lines.push('  state.addItem({label:"${it.label}", action:"${it.action}", type:"${it.type}", color:${it.color}, x:${it.x}, y:${it.y}});');
			if (it.script != null && it.script.trim() != "") lines.push('  // Script: ${it.script}');
		}
		if (_data.transitionCode != null && _data.transitionCode.trim() != "") {
			lines.push(''); lines.push('  state.setTransition(function() {');
			for (l in _data.transitionCode.split('\n')) lines.push('    $l');
			lines.push('  });');
		}
		lines.push('}');
		_file = new FileReference();
		_file.addEventListener(Event.COMPLETE, function(_) { _st('📤 Exported!'); });
		_file.save(lines.join("\n"), _data.name + "_menu.hx");
	}

	function _testLive() : Void { _st('▶ Live test — see export for CustomMenuState integration'); }

	function _goBack() : Void
	{
		if (_music != null) { _music.stop(); _music = null; }
		if (_isDirty) { _st('⚠ Unsaved changes — Ctrl+S to save, ESC to force quit'); _isDirty = false; return; }
		FlxG.mouse.visible = false;
		FlxG.switchState(new funkin.menus.MainMenuState());
	}

	// ─────────────────────────────────────────────────────────────────────────
	//  Helpers
	// ─────────────────────────────────────────────────────────────────────────

	function _spr(x:Float,y:Float,w:Int,h:Int,col:Int,cam:FlxCamera):FlxSprite {
		var s=new FlxSprite(x,y).makeGraphic(w,h,col); s.scrollFactor.set(); s.cameras=[cam]; add(s); return s;
	}
	function _txt(x:Float,y:Float,w:Int,lbl:String,sz:Int,col:Int,cam:FlxCamera):FlxText {
		var t=new FlxText(x,y,w,lbl,sz); t.setFormat(Paths.font("vcr.ttf"),sz,col,CENTER);
		t.scrollFactor.set(); t.cameras=[cam]; add(t); return t;
	}
	function _reg(id:String,x:Float,y:Float,w:Float,h:Float):Void {
		_btns=_btns.filter(b->b.id!=id); _btns.push({id:id,x:x,y:y,w:w,h:h});
	}
	function _mkTBtn(g:FlxGroup,x:Float,y:Float,w:Int,h:Int,lbl:String,col:Int,tc:Int,bid:String):Void {
		var bg=new FlxSprite(x,y).makeGraphic(w,h,col); bg.scrollFactor.set(); bg.cameras=[camUI]; g.add(bg); add(bg);
		var tx=new FlxText(x,y+Std.int((h-10)/2),w,lbl,9); tx.setFormat(Paths.font("vcr.ttf"),9,tc,CENTER);
		tx.scrollFactor.set(); tx.cameras=[camUI]; g.add(tx); add(tx);
		_reg(bid,x,y,w,h);
	}
	function _mkL(g:FlxGroup,x:Float,y:Float,txt:String,col:Int):Void {
		var t=new FlxText(x,y,0,txt,10); t.setFormat(Paths.font("vcr.ttf"),10,col,LEFT);
		t.scrollFactor.set(); t.cameras=[camUI]; g.add(t); add(t);
	}
	function _mkSep(g:FlxGroup,x:Float,y:Float,w:Int):Void {
		var s=new FlxSprite(x,y).makeGraphic(w,1,0xFF2A2A44); s.scrollFactor.set(); s.cameras=[camUI]; g.add(s); add(s);
	}
	function _addIn(g:FlxGroup,k:String,x:Float,y:Float,w:Int,def:String,sz:Int):Void {
		var inp=new FlxUIInputText(x,y,w,def,sz); inp.scrollFactor.set(); inp.cameras=[camUI]; g.add(inp); add(inp); _inputs.set(k,inp);
	}
	function _addCB(g:FlxGroup,k:String,x:Float,y:Float,lbl:String,w:Int):Void {
		var cb=new FlxUICheckBox(x,y,null,null,lbl,w); cb.scrollFactor.set(); cb.cameras=[camUI]; g.add(cb); add(cb); _checks.set(k,cb);
	}
	inline function _gi(k:String):String  return _inputs.exists(k)  ? (_inputs.get(k)?.text  ?? "") : "";
	inline function _si(k:String,v:String):Void if (_inputs.exists(k) && _inputs.get(k) != null) _inputs.get(k).text = v;
	inline function _gc(k:String):Bool    return _checks.exists(k)  ? (_checks.get(k)?.checked ?? false) : false;
	inline function _sc(k:String,v:Bool):Void  if (_checks.exists(k) && _checks.get(k) != null) _checks.get(k).checked = v;
	inline function _pf(s:String,fb:Float):Float { var v=Std.parseFloat(s); return Math.isNaN(v)?fb:v; }
	inline function _parseColor(hex:String,fb:Int):Int { if (hex==null||hex=="") return fb; var v=Std.parseInt(hex); return v!=null?v:fb; }
	function _getGroupColor(id:String):Int {
		for (g in (_data.groups??[])) if (g.id==id) return _parseColor(g.color,C_ACCENT);
		return C_GRAY;
	}
	function _st(msg:String):Void {
		if (_statusTxt==null) return;
		FlxTween.cancelTweensOf(_statusTxt);
		_statusTxt.text='${_data.name} (${_data.items.length} items)  •  $msg';
		_statusTxt.alpha=1;
		FlxTween.tween(_statusTxt,{alpha:0.6},0.3,{startDelay:4.0});
	}

	override public function destroy():Void {
		if (_music!=null){_music.stop();_music=null;}
		for (k in _live.keys()){var o=_live.get(k);if(o!=null&&o.alive)try{o.destroy();}catch(_){}}
		_live.clear();
		super.destroy();
	}
}

// ─── Data structures ──────────────────────────────────────────────────────────

typedef MenuEditorData =
{
	var name            : String;
	var title           : String;
	var bgColor         : String;
	var bgImage         : String;
	@:optional var bgScrollX       : Float;
	@:optional var bgScrollY       : Float;
	var music           : String;
	var transition      : String;
	@:optional var transitionCode  : String;
	var bgScroll        : Bool;
	var groups          : Array<MenuEditorGroupData>;
	var items           : Array<MenuEditorItemData>;
}

typedef MenuEditorGroupData =
{
	var id      : String;
	var name    : String;
	var visible : Bool;
	var locked  : Bool;
	var color   : String;
}

typedef MenuEditorItemData =
{
	var label      : String;
	var action     : String;
	var type       : String;
	var color      : String;
	var script     : String;
	var visible    : Bool;
	var enabled    : Bool;
	var x          : Float;
	var y          : Float;
	@:optional var groupId    : String;
	@:optional var fontSize   : Int;
	@:optional var bold       : Bool;
	@:optional var spritePath : String;
	@:optional var animPath   : String;
	@:optional var animName   : String;
	@:optional var scaleX     : Float;
	@:optional var scaleY     : Float;
	@:optional var alpha      : Float;
	@:optional var isMenuItem : Bool;
}

// Backwards-compat aliases
typedef MenuData     = MenuEditorData;
typedef MenuItemData = MenuEditorItemData;
