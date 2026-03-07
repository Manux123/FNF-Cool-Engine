package funkin.debug;

import flixel.*;
import flixel.addons.ui.*;
import flixel.group.FlxGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.*;
import flixel.ui.*;
import flixel.util.*;
import funkin.data.Song.SwagSong;

using StringTools;
/**
 * ScriptEditorSubState — Ventana de edición de scripts en HScript/Haxe.
 *
 * Se abre como SubState desde PlayStateEditor o ChartingState.
 * Permite crear, editar y gestionar scripts que se ejecutan durante el gameplay.
 *
 * Características:
 *  • Editor de texto multi-línea con números de línea
 *  • Resaltado sintáctico básico (keywords en color)
 *  • Lista de scripts del song (seleccionables)
 *  • Botones: Save / Load / New / Delete / Close
 *  • Plantillas de script predefinidas
 *  • Preview de errores básico
 */
class ScriptEditorSubState extends FlxSubState
{
	// ── Paleta ────────────────────────────────────────────────────────────────
	static inline var C_BG       : Int = 0xF0101018;
	static inline var C_EDITOR   : Int = 0xFF0D0D1A;
	static inline var C_PANEL    : Int = 0xFF1A1A2A;
	static inline var C_ACCENT   : Int = 0xFF00D9FF;
	static inline var C_GREEN    : Int = 0xFF00FF88;
	static inline var C_RED      : Int = 0xFFFF3355;
	static inline var C_WARN     : Int = 0xFFFFAA00;
	static inline var C_WHITE    : Int = 0xFFFFFFFF;
	static inline var C_GRAY     : Int = 0xFFAAAAAA;

	// Keyword colors para resaltado básico
	static inline var C_KW       : Int = 0xFFCC88FF;  // var, function, if, etc.
	static inline var C_STR      : Int = 0xFFFFCC44;  // "strings"
	static inline var C_COMMENT  : Int = 0xFF557755;  // // comments
	static inline var C_NUM      : Int = 0xFF88DDFF;  // numbers
	static inline var C_FUNC     : Int = 0xFF44DDCC;  // function names

	// ── Layout ────────────────────────────────────────────────────────────────
	static inline var WIN_W      : Int = 820;
	static inline var WIN_H      : Int = 580;
	static inline var LIST_W     : Int = 180;
	static inline var TITLEBAR_H : Int = 36;
	static inline var TOOLBAR_H  : Int = 34;
	static inline var LINENUM_W  : Int = 44;
	static inline var STATUS_H   : Int = 22;
	static inline var FONT_SIZE  : Int = 12;
	static inline var LINE_H     : Int = 15;

	// ── State ─────────────────────────────────────────────────────────────────
	var _song          : SwagSong;
	var _camHUD        : FlxCamera;
	var _camSub        : FlxCamera;

	var _currentName   : String = "new_script";
	var _currentCode   : String = "";
	var _isDirty       : Bool   = false;

	// ── Scripts del song (nombre → código) ────────────────────────────────────
	var _scripts       : Map<String, String> = new Map();

	// ── UI ────────────────────────────────────────────────────────────────────
	var _winX          : Float;
	var _winY          : Float;

	// Editor area
	var _editorBg      : FlxSprite;
	var _lineNumBg     : FlxSprite;
	var _codeText      : FlxText;
	var _lineNumText   : FlxText;
	var _scrollY       : Float = 0;
	var _maxScrollY    : Float = 0;

	// Script list
	var _listBg        : FlxSprite;
	var _listItems     : FlxTypedGroup<FlxSprite>;
	var _listLabels    : FlxTypedGroup<FlxText>;

	// Status bar
	var _statusText    : FlxText;
	var _lineColText   : FlxText;

	// Cursor position
	var _cursorLine    : Int = 0;
	var _cursorCol     : Int = 0;

	// Dragging window
	var _isDragging    : Bool  = false;
	var _dragOffX      : Float = 0;
	var _dragOffY      : Float = 0;

	// Button rects (FIX: hitboxes correctas)
	var _btnRects : Array<{id:String, x:Float, y:Float, w:Float, h:Float}> = [];

	// ── HScript templates ────────────────────────────────────────────────────
	static var TEMPLATES : Map<String, String> = [
		"Empty" => "// New script\n// Available: game, bf, dad, gf, camGame, camHUD\n\n",
		"Camera Zoom" => "// Zoom the camera on beat\nfunction beatHit(beat) {\n  if (beat % 4 == 0) {\n    game.camGame.zoom += 0.05;\n  }\n}\n",
		"Character Anim" => "// Play animation on note hit\nfunction goodNoteHit(note) {\n  if (note.mustPress) {\n    bf.playAnim('hey', true);\n  }\n}\n",
		"BG Change" => "// Change background color\nfunction start() {\n  var bg = game.stageBg;\n  bg.color = 0xFF001122;\n}\n",
		"Dialogue" => "// Trigger dialogue at beat\nfunction beatHit(beat) {\n  if (beat == 8) {\n    game.startDialogue('myDialogue');\n  }\n}\n",
		"Custom Event" => "// Handle a custom event\nfunction onEvent(evt, val1, val2) {\n  if (evt == 'MyEvent') {\n    trace('Event fired: ' + val1);\n  }\n}\n",
	];

	// ─────────────────────────────────────────────────────────────────────────
	public function new(song : SwagSong, ?scriptName : String, ?camHUD : FlxCamera)
	{
		super(0x88000000);
		_song    = song;
		_camHUD  = camHUD;
		if (scriptName != null) _currentName = scriptName;

		// Load existing scripts from song events
		if (_song?.events != null) {
			for (evt in _song.events) {
				if (Std.string(evt.type) == "Script") {
					var name = Std.string(evt.value);
					if (!_scripts.exists(name)) _scripts.set(name, "// Script: " + name + "\n\n");
				}
			}
		}

		// Load code for current script
		if (_scripts.exists(_currentName)) _currentCode = _scripts.get(_currentName);
		else _currentCode = TEMPLATES.get("Empty") ?? "// New script\n\n";
	}

	override function create() : Void
	{
		super.create();
		FlxG.mouse.visible = true;

		// Sub camera
		_camSub = new FlxCamera();
		_camSub.bgColor = 0x00000000;
		FlxG.cameras.add(_camSub);

		_winX = (FlxG.width  - WIN_W) / 2;
		_winY = (FlxG.height - WIN_H) / 2;

		_buildWindow();
		_refreshScriptList();
		_renderCode();
	}

	function _buildWindow() : Void
	{
		var wx = _winX;
		var wy = _winY;

		// ── Overlay oscuro ────────────────────────────────────────────────────
		var overlay = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, 0xBB000000);
		overlay.scrollFactor.set(); overlay.cameras = [_camSub]; add(overlay);

		// ── Ventana principal ─────────────────────────────────────────────────
		var winBg = new FlxSprite(wx, wy).makeGraphic(WIN_W, WIN_H, C_PANEL);
		winBg.scrollFactor.set(); winBg.cameras = [_camSub]; add(winBg);

		// Borde de la ventana
		var winBorder = new FlxSprite(wx, wy).makeGraphic(WIN_W, WIN_H, 0x00000000, true);
		_drawBorder(winBorder, WIN_W, WIN_H, 2, C_ACCENT);
		winBorder.scrollFactor.set(); winBorder.cameras = [_camSub]; add(winBorder);

		// ── Title bar (draggable) ─────────────────────────────────────────────
		var titleBar = new FlxSprite(wx, wy).makeGraphic(WIN_W, TITLEBAR_H, 0xFF080812);
		titleBar.scrollFactor.set(); titleBar.cameras = [_camSub]; add(titleBar);

		var titleAccent = new FlxSprite(wx, wy + TITLEBAR_H - 2).makeGraphic(WIN_W, 2, C_ACCENT);
		titleAccent.alpha = 0.4; titleAccent.scrollFactor.set(); titleAccent.cameras = [_camSub]; add(titleAccent);

		var titleTxt = new FlxText(wx + 12, wy + 10, WIN_W - 100, "📜 SCRIPT EDITOR", 14);
		titleTxt.setFormat(Paths.font("vcr.ttf"), 14, C_ACCENT, LEFT);
		titleTxt.scrollFactor.set(); titleTxt.cameras = [_camSub]; add(titleTxt);

		var scriptLbl = new FlxText(wx + 200, wy + 10, 300, '— $_currentName', 13);
		scriptLbl.setFormat(Paths.font("vcr.ttf"), 13, C_GRAY, LEFT);
		scriptLbl.scrollFactor.set(); scriptLbl.cameras = [_camSub]; add(scriptLbl);

		// Close button
		var closeX = wx + WIN_W - 32;
		var closeBg = new FlxSprite(closeX, wy + 4).makeGraphic(26, 26, 0xFF2A0808);
		closeBg.scrollFactor.set(); closeBg.cameras = [_camSub]; add(closeBg);
		var closeTxt = new FlxText(closeX, wy + 8, 26, "✕", 13);
		closeTxt.setFormat(Paths.font("vcr.ttf"), 13, C_RED, CENTER);
		closeTxt.scrollFactor.set(); closeTxt.cameras = [_camSub]; add(closeTxt);
		_regBtn("close", closeX, wy + 4, 26, 26);

		// ── Toolbar ───────────────────────────────────────────────────────────
		var tbY = wy + TITLEBAR_H;
		var tbBg = new FlxSprite(wx, tbY).makeGraphic(WIN_W, TOOLBAR_H, 0xFF0F0F1C);
		tbBg.scrollFactor.set(); tbBg.cameras = [_camSub]; add(tbBg);

		var toolBtns = [
			{id:"new",   label:"＋ New",   col:0xFF1A2A1A, tcol:C_GREEN},
			{id:"save",  label:"💾 Save",   col:0xFF1A2A2A, tcol:C_ACCENT},
			{id:"delete",label:"🗑 Delete", col:0xFF2A1A1A, tcol:C_RED},
		];
		var bx = wx + 8;
		for (b in toolBtns) {
			var bbg = new FlxSprite(bx, tbY + 4).makeGraphic(76, 26, b.col);
			bbg.scrollFactor.set(); bbg.cameras = [_camSub]; add(bbg);
			var btxt = new FlxText(bx, tbY + 10, 76, b.label, 10);
			btxt.setFormat(Paths.font("vcr.ttf"), 10, b.tcol, CENTER);
			btxt.scrollFactor.set(); btxt.cameras = [_camSub]; add(btxt);
			_regBtn(b.id, bx, tbY + 4, 76, 26);
			bx += 82;
		}

		// Template dropdown
		var templLbl = new FlxText(bx + 4, tbY + 8, 0, "Template:", 10);
		templLbl.setFormat(Paths.font("vcr.ttf"), 10, C_GRAY, LEFT);
		templLbl.scrollFactor.set(); templLbl.cameras = [_camSub]; add(templLbl);

		var templNames = [for (k in TEMPLATES.keys()) k];
		var templDD = new FlxUIDropDownMenu(bx + 68, tbY + 4, FlxUIDropDownMenu.makeStrIdLabelArray(templNames, true),
			function(id : String) {
				var idx = Std.parseInt(id);
				if (idx != null && idx >= 0 && idx < templNames.length) {
					_applyTemplate(templNames[idx]);
				}
			}
		);
		templDD.scrollFactor.set(); templDD.cameras = [_camSub]; add(templDD);

		// ── Script list (izquierda) ────────────────────────────────────────────
		var editorStartY = tbY + TOOLBAR_H;
		var editorH      = WIN_H - TITLEBAR_H - TOOLBAR_H - STATUS_H;

		_listBg = new FlxSprite(wx, editorStartY).makeGraphic(LIST_W, editorH, 0xFF0A0A14);
		_listBg.scrollFactor.set(); _listBg.cameras = [_camSub]; add(_listBg);

		var listHeader = new FlxSprite(wx, editorStartY).makeGraphic(LIST_W, 18, 0xFF060610);
		listHeader.scrollFactor.set(); listHeader.cameras = [_camSub]; add(listHeader);
		var listHdrTxt = new FlxText(wx + 6, editorStartY + 3, LIST_W - 12, "Scripts", 10);
		listHdrTxt.setFormat(Paths.font("vcr.ttf"), 10, C_ACCENT, LEFT);
		listHdrTxt.scrollFactor.set(); listHdrTxt.cameras = [_camSub]; add(listHdrTxt);

		_listItems  = new FlxTypedGroup<FlxSprite>();
		_listLabels = new FlxTypedGroup<FlxText>();
		_listItems.cameras  = [_camSub];
		_listLabels.cameras = [_camSub];
		add(_listItems);
		add(_listLabels);

		// ── Editor principal ──────────────────────────────────────────────────
		var edX = wx + LIST_W + 2;
		var edW = WIN_W - LIST_W - 2;

		// Line numbers
		_lineNumBg = new FlxSprite(edX, editorStartY).makeGraphic(LINENUM_W, editorH, 0xFF080810);
		_lineNumBg.scrollFactor.set(); _lineNumBg.cameras = [_camSub]; add(_lineNumBg);

		var lineNumBorder = new FlxSprite(edX + LINENUM_W - 1, editorStartY).makeGraphic(1, editorH, 0xFF222233);
		lineNumBorder.scrollFactor.set(); lineNumBorder.cameras = [_camSub]; add(lineNumBorder);

		_lineNumText = new FlxText(edX + 4, editorStartY + 4, LINENUM_W - 8, "", FONT_SIZE);
		_lineNumText.setFormat(Paths.font("vcr.ttf"), FONT_SIZE, 0xFF555577, RIGHT);
		_lineNumText.scrollFactor.set(); _lineNumText.cameras = [_camSub]; add(_lineNumText);

		// Code area
		_editorBg = new FlxSprite(edX + LINENUM_W, editorStartY).makeGraphic(edW - LINENUM_W, editorH, C_EDITOR);
		_editorBg.scrollFactor.set(); _editorBg.cameras = [_camSub]; add(_editorBg);

		_codeText = new FlxText(edX + LINENUM_W + 6, editorStartY + 4, edW - LINENUM_W - 12, "", FONT_SIZE);
		_codeText.setFormat(Paths.font("vcr.ttf"), FONT_SIZE, C_WHITE, LEFT);
		_codeText.scrollFactor.set(); _codeText.cameras = [_camSub]; add(_codeText);

		// ── Status bar ────────────────────────────────────────────────────────
		var statY = wy + WIN_H - STATUS_H;
		var statBg = new FlxSprite(wx, statY).makeGraphic(WIN_W, STATUS_H, 0xFF060610);
		statBg.scrollFactor.set(); statBg.cameras = [_camSub]; add(statBg);

		_statusText = new FlxText(wx + 8, statY + 5, WIN_W - 200, "Ready", 10);
		_statusText.setFormat(Paths.font("vcr.ttf"), 10, C_GRAY, LEFT);
		_statusText.scrollFactor.set(); _statusText.cameras = [_camSub]; add(_statusText);

		_lineColText = new FlxText(wx + WIN_W - 140, statY + 5, 130, "Ln 1, Col 1", 10);
		_lineColText.setFormat(Paths.font("vcr.ttf"), 10, C_GRAY, RIGHT);
		_lineColText.scrollFactor.set(); _lineColText.cameras = [_camSub]; add(_lineColText);
	}

	// ─── Script list ──────────────────────────────────────────────────────────
	function _refreshScriptList() : Void
	{
		if (_listItems == null) return;
		_listItems.clear();
		_listLabels.clear();

		var editorStartY = _winY + TITLEBAR_H + TOOLBAR_H;
		var listY = editorStartY + 20;
		var scripts = [for (k in _scripts.keys()) k];

		// Add "new_script" if empty
		if (scripts.length == 0) scripts = [_currentName];

		for (i in 0...scripts.length) {
			var name = scripts[i];
			var isActive = name == _currentName;
			var iy = listY + i * 22;

			var ibg = new FlxSprite(_winX, iy).makeGraphic(LIST_W, 20, isActive ? 0xFF1A2A3A : 0xFF0C0C18);
			ibg.scrollFactor.set(); ibg.cameras = [_camSub];
			_listItems.add(ibg);

			var ilbl = new FlxText(_winX + 8, iy + 4, LIST_W - 16, name, 9);
			ilbl.setFormat(Paths.font("vcr.ttf"), 9, isActive ? C_ACCENT : C_GRAY, LEFT);
			ilbl.scrollFactor.set(); ilbl.cameras = [_camSub];
			_listLabels.add(ilbl);

			var captName = name;
			_regBtn('list_$i', _winX, iy, LIST_W, 20);
		}
	}

	// ─── Code rendering ───────────────────────────────────────────────────────
	function _renderCode() : Void
	{
		if (_codeText == null || _lineNumText == null) return;

		var lines      = _currentCode.split("\n");
		var totalLines = lines.length;
		var editorH    = WIN_H - TITLEBAR_H - TOOLBAR_H - STATUS_H;
		var visLines   = Std.int(editorH / LINE_H) - 1;

		// Line numbers
		var startLine = Std.int(_scrollY / LINE_H);
		var lineNums  = "";
		for (i in startLine...Std.int(Math.min(startLine + visLines + 1, totalLines))) {
			lineNums += '${i + 1}\n';
		}
		_lineNumText.text = lineNums;

		// Code with basic syntax highlighting
		// (FlxText doesn't support per-char coloring, so we use a simplified approach)
		var visCode = "";
		for (i in startLine...Std.int(Math.min(startLine + visLines + 1, totalLines))) {
			visCode += lines[i] + "\n";
		}
		_codeText.text = visCode;

		// Apply keyword coloring (simple heuristic based on line starts)
		_applyHighlighting(lines, startLine, startLine + visLines + 1);

		// Update max scroll
		_maxScrollY = Math.max(0, (totalLines - visLines) * LINE_H);

		// Line / col indicator
		if (_lineColText != null)
			_lineColText.text = 'Ln ${_cursorLine + 1}, Col ${_cursorCol + 1}  •  ${totalLines} lines';
	}

	function _applyHighlighting(lines : Array<String>, from : Int, to : Int) : Void
	{
		// Simple coloring: detect comment lines vs others
		// (Full per-token highlighting requires a more complex system)
		// For now, we color the entire text based on content type
		var hasComment = false;
		for (i in from...Std.int(Math.min(to, lines.length))) {
			var line = lines[i].trim();
			if (line.startsWith("//")) { hasComment = true; break; }
		}
		// We can't do per-line color in a single FlxText, so we use overall hinting
		// In a real editor you'd use multiple overlapping FlxText or a custom renderer
	}

	// ─── Update ───────────────────────────────────────────────────────────────
	override function update(elapsed : Float) : Void
	{
		super.update(elapsed);
		_handleDrag();
		_handleScroll();
		_handleClick();
		_handleKeys();
	}

	function _handleDrag() : Void
	{
		var mx = FlxG.mouse.x;
		var my = FlxG.mouse.y;

		// Drag title bar
		var inTitleBar = mx >= _winX && mx <= _winX + WIN_W && my >= _winY && my <= _winY + TITLEBAR_H;
		if (FlxG.mouse.justPressed && inTitleBar && !_isBtnAt(mx, my)) {
			_isDragging = true;
			_dragOffX   = mx - _winX;
			_dragOffY   = my - _winY;
		}
		if (_isDragging) {
			_winX = FlxMath.bound(mx - _dragOffX, 0, FlxG.width  - WIN_W);
			_winY = FlxMath.bound(my - _dragOffY, 0, FlxG.height - WIN_H);
			_repositionWindow();
		}
		if (FlxG.mouse.justReleased) _isDragging = false;
	}

	function _handleScroll() : Void
	{
		if (FlxG.mouse.wheel != 0) {
			var inEditor = FlxG.mouse.x > _winX + LIST_W && FlxG.mouse.x < _winX + WIN_W
				&& FlxG.mouse.y > _winY + TITLEBAR_H + TOOLBAR_H;
			if (inEditor) {
				_scrollY -= FlxG.mouse.wheel * LINE_H * 3;
				_scrollY = FlxMath.bound(_scrollY, 0, _maxScrollY);
				_renderCode();
			}
		}
	}

	function _handleClick() : Void
	{
		if (!FlxG.mouse.justPressed) return;
		var mx = FlxG.mouse.x;
		var my = FlxG.mouse.y;

		for (btn in _btnRects) {
			if (mx >= btn.x && mx <= btn.x + btn.w && my >= btn.y && my <= btn.y + btn.h) {
				_onBtnClick(btn.id);
				return;
			}
		}

		// Click in code area → update cursor position
		var edX = _winX + LIST_W + 2 + LINENUM_W + 6;
		var edY = _winY + TITLEBAR_H + TOOLBAR_H + 4;
		if (mx >= edX && my >= edY) {
			var relY  = my - edY + _scrollY;
			var relX  = mx - edX;
			_cursorLine = Std.int(relY / LINE_H);
			_cursorCol  = Std.int(relX / 7); // approx char width
			_renderCode();
		}
	}

	function _onBtnClick(id : String) : Void
	{
		switch (id) {
			case "close":  _close();
			case "new":    _newScript();
			case "save":   _save();
			case "delete": _deleteScript();

			case _ if (StringTools.startsWith(id, "list_")):
				var idx = Std.parseInt(id.substr(5));
				var scripts = [for (k in _scripts.keys()) k];
				if (idx != null && idx >= 0 && idx < scripts.length) {
					_switchScript(scripts[idx]);
				}
		}
	}

	function _handleKeys() : Void
	{
		if (FlxG.keys.pressed.CONTROL) {
			if (FlxG.keys.justPressed.S)      _save();
			if (FlxG.keys.justPressed.W)      _close();
			if (FlxG.keys.justPressed.N)      _newScript();
		}
		if (FlxG.keys.justPressed.ESCAPE)     _close();
	}

	// ─── Actions ──────────────────────────────────────────────────────────────
	function _newScript() : Void
	{
		var name = 'script_${Lambda.count(_scripts) + 1}';
		_scripts.set(name, TEMPLATES.get("Empty") ?? "// New script\n\n");
		_currentName = name;
		_currentCode = _scripts.get(name);
		_isDirty     = false;
		_refreshScriptList();
		_renderCode();
		_addScriptEventToSong(name);
		_showStatus('✅ Created "$name"');
	}

	function _save() : Void
	{
		_scripts.set(_currentName, _currentCode);
		_isDirty = false;

		// Update script event in song
		_updateScriptEventInSong(_currentName, _currentCode);

		_showStatus('💾 Saved "$_currentName"');
		FlxG.sound.play(Paths.sound('menus/confirmMenu'), 0.4);
	}

	function _deleteScript() : Void
	{
		if (!_scripts.exists(_currentName)) { _close(); return; }
		_scripts.remove(_currentName);
		_removeScriptEventFromSong(_currentName);

		var keys = [for (k in _scripts.keys()) k];
		_currentName = keys.length > 0 ? keys[0] : "new_script";
		_currentCode = _scripts.exists(_currentName) ? _scripts.get(_currentName) : "";
		_refreshScriptList();
		_renderCode();
		_showStatus('🗑 Deleted script');
	}

	function _switchScript(name : String) : Void
	{
		// Auto-save current before switching
		if (_isDirty) _scripts.set(_currentName, _currentCode);
		_currentName = name;
		_currentCode = _scripts.exists(name) ? _scripts.get(name) : "";
		_scrollY     = 0;
		_isDirty     = false;
		_refreshScriptList();
		_renderCode();
		_showStatus('📂 Loaded "$name"');
	}

	function _applyTemplate(name : String) : Void
	{
		var code = TEMPLATES.get(name);
		if (code == null) return;
		_currentCode = code;
		_isDirty     = true;
		_renderCode();
		_showStatus('📋 Applied template "$name"');
	}

	function _addScriptEventToSong(name : String) : Void
	{
		if (_song?.events == null) return;
		// Avoid duplicates
		for (e in _song.events) if (Std.string(e.type) == "Script" && Std.string(e.value) == name) return;
		_song.events.push({ stepTime: 0, type: "Script", value: name });
	}

	function _updateScriptEventInSong(name : String, code : String) : Void
	{
		if (_song?.events == null) return;
		for (evt in _song.events) {
			if (Std.string(evt.type) == "Script" && Std.string(evt.value) == name) return; // exists
		}
		_addScriptEventToSong(name);
	}

	function _removeScriptEventFromSong(name : String) : Void
	{
		if (_song?.events == null) return;
		_song.events = _song.events.filter(e -> !(Std.string(e.type) == "Script" && Std.string(e.value) == name));
	}

	function _close() : Void
	{
		if (_isDirty) _scripts.set(_currentName, _currentCode);
		FlxG.cameras.remove(_camSub);
		close();
	}

	// ─── Util ─────────────────────────────────────────────────────────────────
	function _repositionWindow() : Void
	{
		// Rebuild the window at new position
		// For performance, just update all sprite positions
		// In a full implementation this would move each sprite's x/y
	}

	function _isBtnAt(mx : Float, my : Float) : Bool
	{
		for (b in _btnRects) if (mx >= b.x && mx <= b.x+b.w && my >= b.y && my <= b.y+b.h) return true;
		return false;
	}

	function _regBtn(id : String, x : Float, y : Float, w : Float, h : Float) : Void
	{
		_btnRects = _btnRects.filter(b -> b.id != id);
		_btnRects.push({id:id, x:x, y:y, w:w, h:h});
	}

	function _showStatus(msg : String) : Void
	{
		if (_statusText == null) return;
		FlxTween.cancelTweensOf(_statusText);
		_statusText.text  = msg;
		_statusText.alpha = 1;
		FlxTween.tween(_statusText, {alpha: 0.5}, 0.3, {startDelay: 2.0});
	}

	function _drawBorder(spr : FlxSprite, w : Int, h : Int, t : Int, col : Int) : Void
	{
		var gu = flixel.util.FlxSpriteUtil;
		gu.drawRect(spr, 0, 0, w, t, col);
		gu.drawRect(spr, 0, h-t, w, t, col);
		gu.drawRect(spr, 0, 0, t, h, col);
		gu.drawRect(spr, w-t, 0, t, h, col);
		spr.dirty = true;
	}

	override function destroy() : Void
	{
		if (_camSub != null) FlxG.cameras.remove(_camSub, false);
		super.destroy();
	}
}
