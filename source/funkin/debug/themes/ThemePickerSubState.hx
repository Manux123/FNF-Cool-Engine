package funkin.debug.themes;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.ui.FlxButton;
import flixel.addons.ui.FlxUIInputText;
import funkin.transitions.StateTransition;
import funkin.debug.themes.EditorTheme.ThemeData;

using StringTools;

/**
 * ThemePickerSubState — Selector / editor de temas del editor.
 *
 * Funciones:
 *  - Elegir entre 6 presets (Dark, Neon, Midnight, FL Studio, Pastel, Light)
 *  - Editar los colores individualmente (hex #RRGGBB) para un tema custom
 *  - Guardar con nombre propio
 *  - "Apply & Restart" aplica y reinicia el editor con el nuevo tema
 *  - "Save Only"       guarda sin reiniciar (efecto al siguiente arranque)
 *
 * Se abre con:  openSubState(new ThemePickerSubState())
 */
class ThemePickerSubState extends FlxSubState
{
	// ── Layout ────────────────────────────────────────────────────────────────
	static inline final W:Int           = 700;
	static inline final H:Int           = 510;
	static inline final PRESET_COL:Int  = 210;
	static inline final COLOR_COL:Int   = 248;

	// ── Estado interno ────────────────────────────────────────────────────────
	var panX:Float;
	var panY:Float;

	var _preview:ThemeData;

	// Hit-rects para botones de preset
	var _presetRects:Array<{name:String, x:Float, y:Float, w:Int, h:Int}> = [];

	// Campos de color (uno por cada campo del theme)
	static final COLOR_FIELDS:Array<{f:String, l:String}> = [
		{f:'bgDark',        l:'BG Dark'},
		{f:'bgPanel',       l:'BG Panel'},
		{f:'bgPanelAlt',    l:'BG Alt'},
		{f:'bgHover',       l:'BG Hover'},
		{f:'borderColor',   l:'Border'},
		{f:'accent',        l:'Accent'},
		{f:'accentAlt',     l:'Accent Alt'},
		{f:'selection',     l:'Selection'},
		{f:'textPrimary',   l:'Text Primary'},
		{f:'textSecondary', l:'Text Sec.'},
		{f:'textDim',       l:'Text Dim'},
		{f:'warning',       l:'Warning'},
		{f:'success',       l:'Success'},
		{f:'error',         l:'Error'},
		{f:'rowSelected',   l:'Row Sel.'},
		{f:'rowEven',       l:'Row Even'},
		{f:'rowOdd',        l:'Row Odd'},
	];

	var _colorInputs:Array<FlxUIInputText> = [];
	var _colorSwatches:Array<FlxSprite>    = [];
	var _previewSwatches:Array<FlxSprite>  = [];

	var _nameInput:FlxUIInputText;
	var _statusTxt:FlxText;

	var _onApply:Null<Void->Void> = null;

	public function new(?onApply:Void->Void)
	{
		super();
		_onApply = onApply;
		_preview = _copyTheme(EditorTheme.current);
	}

	// ─────────────────────────────────────────────────────────────────────────
	override function create():Void
	{
		super.create();

		// FIX: cámara propia para ser visible sobre camUI (transparente) del StageEditor
		var camSub = new flixel.FlxCamera();
		camSub.bgColor.alpha = 0;
		FlxG.cameras.add(camSub, false);
		cameras = [camSub];
		// Limpiar al cerrar
		var _selfCam = camSub;
		// (se limpia en close() via override abajo, ver destroy)
		FlxG.signals.postDraw.addOnce(function() {}); // dummy para evitar warning

		panX = (FlxG.width  - W) / 2;
		panY = (FlxG.height - H) / 2;

		_addOverlay();
		_addPanel();
		_addPresetColumn();
		_addColorColumn();
		_addPreviewColumn();
		_addActionRow();
	}

	// ─────────────────────────────────────────────────────────────────────────
	override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (FlxG.keys.justPressed.ESCAPE) { close(); return; }

		// Detecta cambios en los inputs de color y refresca swatches en tiempo real
		_flushColorInputs();

		// Click en botón de preset
		if (FlxG.mouse.justPressed)
		{
			var mx = FlxG.mouse.screenX;
			var my = FlxG.mouse.screenY;
			for (r in _presetRects)
			{
				if (mx >= r.x && mx <= r.x + r.w && my >= r.y && my <= r.y + r.h)
				{
					_applyPreset(r.name);
					break;
				}
			}
		}
	}

	// ─────────────────────────────────────────────────────────────────────────
	// CONSTRUCCIÓN DEL UI
	// ─────────────────────────────────────────────────────────────────────────

	function _addOverlay():Void
	{
		var ov = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xBB000000);
		ov.scrollFactor.set();
		add(ov);
	}

	function _addPanel():Void
	{
		var T = EditorTheme.current;

		var bg = new FlxSprite(panX, panY).makeGraphic(W, H, T.bgPanel);
		bg.scrollFactor.set(); add(bg);

		var topBar = new FlxSprite(panX, panY).makeGraphic(W, 3, T.accent);
		topBar.scrollFactor.set(); add(topBar);

		var title = new FlxText(panX + 12, panY + 8, W - 24,
			'\u2728  THEME PICKER  \u2014  active: ${EditorTheme.current.name}', 13);
		title.setFormat(Paths.font('vcr.ttf'), 13, T.accent, LEFT);
		title.scrollFactor.set(); add(title);

		var sep = new FlxSprite(panX, panY + 30).makeGraphic(W, 1, T.borderColor);
		sep.alpha = 0.4; sep.scrollFactor.set(); add(sep);

		_statusTxt = new FlxText(panX + 10, panY + H - 22, W - 20, 'ESC = cancel', 9);
		_statusTxt.color = T.textDim; _statusTxt.scrollFactor.set(); add(_statusTxt);
	}

	function _colHeader(x:Float, y:Float, w:Int, label:String):Void
	{
		var T = EditorTheme.current;
		var bg = new FlxSprite(x, y).makeGraphic(w, 18, T.bgPanelAlt);
		bg.scrollFactor.set(); add(bg);
		var t = new FlxText(x + 5, y + 2, w, label, 9);
		t.setFormat(Paths.font('vcr.ttf'), 9, T.accentAlt, LEFT);
		t.scrollFactor.set(); add(t);
	}

	// ── Columna de presets ────────────────────────────────────────────────────

	function _addPresetColumn():Void
	{
		var T   = EditorTheme.current;
		var ox  = panX + 8;
		var oy  = panY + 34.0;

		_colHeader(ox, oy, PRESET_COL - 8, 'PRESETS');
		oy += 22;

		for (name in EditorTheme.presetNames())
		{
			var preset   = EditorTheme.getPreset(name);
			var isActive = (T.name == name);

			var rowBg = new FlxSprite(ox, oy).makeGraphic(PRESET_COL - 8, 34,
				isActive ? T.rowSelected : T.bgPanelAlt);
			rowBg.scrollFactor.set(); add(rowBg);

			// Mini swatches del preset (accent + bgDark)
			var sw1 = new FlxSprite(ox + PRESET_COL - 30, oy + 7).makeGraphic(14, 20, preset.accent);
			sw1.scrollFactor.set(); add(sw1);
			var sw2 = new FlxSprite(ox + PRESET_COL - 46, oy + 7).makeGraphic(14, 20, preset.bgDark);
			sw2.scrollFactor.set(); add(sw2);

			var lbl = new FlxText(ox + 6, oy + 9, PRESET_COL - 54,
				'${isActive ? "\u25B6 " : ""}$name', 10);
			lbl.setFormat(Paths.font('vcr.ttf'), 10, isActive ? T.accent : T.textPrimary, LEFT);
			lbl.scrollFactor.set(); add(lbl);

			_presetRects.push({name: name, x: ox, y: oy, w: PRESET_COL - 8, h: 34});
			oy += 36;
		}

		// Hint
		var hint = new FlxText(ox, oy + 4, PRESET_COL - 10,
			'Click to preview.\nEdit colors in the column\ncentral to a custom theme.', 8);
		hint.color = T.textDim; hint.scrollFactor.set(); add(hint);
	}

	// ── Columna de colores ────────────────────────────────────────────────────

	function _addColorColumn():Void
	{
		var T   = EditorTheme.current;
		var ox  = panX + PRESET_COL + 8;
		var oy  = panY + 34.0;

		_colHeader(ox, oy, COLOR_COL, 'CUSTOM COLORS (hex #RRGGBB)');
		oy += 22;

		for (cf in COLOR_FIELDS)
		{
			var colorVal:Int = Reflect.field(_preview, cf.f);
			var hex = '#' + StringTools.hex(colorVal & 0xFFFFFF, 6);

			var lbl = new FlxText(ox, oy + 2, 80, cf.l, 8);
			lbl.color = T.textSecondary; lbl.scrollFactor.set(); add(lbl);

			var inp = new FlxUIInputText(ox + 82, oy, COLOR_COL - 106, hex, 8);
			inp.scrollFactor.set(); add(inp);
			_colorInputs.push(inp);

			var sw = new FlxSprite(ox + COLOR_COL - 20, oy + 1).makeGraphic(16, 16, colorVal);
			sw.scrollFactor.set(); add(sw);
			_colorSwatches.push(sw);

			oy += 20;
		}

		// Input nombre del tema
		var nameLbl = new FlxText(ox, oy + 5, 78, 'Theme name:', 8);
		nameLbl.color = T.textSecondary; nameLbl.scrollFactor.set(); add(nameLbl);

		_nameInput = new FlxUIInputText(ox + 80, oy + 2, COLOR_COL - 82, _preview.name, 8);
		_nameInput.scrollFactor.set(); add(_nameInput);
	}

	// ── Columna de previsualización ───────────────────────────────────────────

	function _addPreviewColumn():Void
	{
		var ox = Std.int(panX + PRESET_COL + COLOR_COL + 18);
		var oy = panY + 34.0;
		var pw = Std.int(W - PRESET_COL - COLOR_COL - 26);

		_colHeader(ox, oy, pw, 'PREVIEW');
		_buildPreviewSwatches(ox, oy + 22, pw);
	}

	function _buildPreviewSwatches(ox:Float, oy:Float, pw:Int):Void
	{
		for (s in _previewSwatches) { remove(s, true); s.destroy(); }
		_previewSwatches = [];

		var T = _preview;
		function sw(label:String, color:Int):Void
		{
			var bg = new FlxSprite(ox, oy).makeGraphic(pw, 22, color);
			bg.scrollFactor.set(); add(bg); _previewSwatches.push(bg);
			var tc = (_lum(color) > 0.38) ? 0xFF111111 : 0xFFEEEEEE;
			var t  = new FlxText(ox + 4, oy + 4, pw - 8, label, 8);
			t.setFormat(Paths.font('vcr.ttf'), 8, tc, LEFT);
			t.scrollFactor.set(); add(t); _previewSwatches.push(cast t);
			oy += 24;
		}
		sw('BG Dark',      T.bgDark);
		sw('BG Panel',     T.bgPanel);
		sw('BG Alt',       T.bgPanelAlt);
		sw('BG Hover',     T.bgHover);
		sw('Border',       T.borderColor);
		sw('Accent',       T.accent);
		sw('Accent Alt',   T.accentAlt);
		sw('Selection',    T.selection);
		sw('Text Primary', T.textPrimary);
		sw('Text Dim',     T.textDim);
		sw('Warning',      T.warning);
		sw('Success',      T.success);
		sw('Error',        T.error);
		sw('Row Selected', T.rowSelected);
		sw('Row Even',     T.rowEven);
	}

	// ── Botones de acción ─────────────────────────────────────────────────────

	function _addActionRow():Void
	{
		var T  = EditorTheme.current;
		var by = panY + H - 46;
		var bx = panX + PRESET_COL + 8;

		var applyBtn = new FlxButton(bx,       by, 'Apply & Restart', _applyAndRestart);
		applyBtn.scrollFactor.set(); add(applyBtn);

		var saveBtn  = new FlxButton(bx + 112, by, 'Save Only',       _saveOnly);
		saveBtn.scrollFactor.set(); add(saveBtn);

		var cancelBtn = new FlxButton(bx + 204, by, 'Cancel',         close);
		cancelBtn.scrollFactor.set(); add(cancelBtn);

		var hint = new FlxText(panX + 8, by, PRESET_COL - 8,
			'Apply & Restart:\napply and restart\nthe editor.', 8);
		hint.color = T.textDim; hint.scrollFactor.set(); add(hint);
	}

	// ─────────────────────────────────────────────────────────────────────────
	// LÓGICA
	// ─────────────────────────────────────────────────────────────────────────

	function _applyPreset(name:String):Void
	{
		_preview = _copyTheme(EditorTheme.getPreset(name));
		_preview.name = name;

		// Sync inputs
		for (i in 0...COLOR_FIELDS.length)
		{
			var val:Int = Reflect.field(_preview, COLOR_FIELDS[i].f);
			_colorInputs[i].text = '#' + StringTools.hex(val & 0xFFFFFF, 6);
			_colorSwatches[i].makeGraphic(16, 16, val);
		}
		if (_nameInput != null) _nameInput.text = name;

		// Rebuild preview column
		var ox = Std.int(panX + PRESET_COL + COLOR_COL + 18);
		var oy = panY + 34.0 + 22;
		var pw = Std.int(W - PRESET_COL - COLOR_COL - 26);
		_buildPreviewSwatches(ox, oy, pw);

		_setStatus('Previewing: $name  —  click "Apply & Restart" to confirm');
	}

	function _flushColorInputs():Void
	{
		var changed = false;
		for (i in 0...COLOR_FIELDS.length)
		{
			var s = _colorInputs[i].text.trim().replace('#', '').replace('0x', '').replace('0X', '');
			var val:Null<Int> = null;
			if (s.length == 6)
			{
				// Parsear sólo los 6 dígitos RGB (max 0xFFFFFF = 16777215, cabe en Int32).
				// Si concatenamos 'FF' antes → '0xFFRRGGBB' overflowea en C++ Haxe
				// y Std.parseInt devuelve 0x7FFFFFFF → todos los colores se vuelven #FFFFFF.
				var rgb = Std.parseInt('0x' + s);
				if (rgb != null) val = rgb | 0xFF000000;
			}
			else if (s.length == 8)
			{
				// AARRGGBB: parsear en dos mitades para evitar overflow
				var hi = Std.parseInt('0x' + s.substr(0, 2));
				var lo = Std.parseInt('0x' + s.substr(2));
				if (hi != null && lo != null) val = ((hi & 0xFF) << 24) | lo;
			}
			if (val == null) continue;
			var cur:Int = Reflect.field(_preview, COLOR_FIELDS[i].f);
			if (cur != val)
			{
				Reflect.setField(_preview, COLOR_FIELDS[i].f, val);
				_colorSwatches[i].makeGraphic(16, 16, val);
				_preview.name = (_nameInput != null && _nameInput.text.trim() != '') ?
					_nameInput.text.trim() : 'custom';
				changed = true;
			}
		}
		if (changed)
		{
			var ox = Std.int(panX + PRESET_COL + COLOR_COL + 18);
			var oy = panY + 34.0 + 22;
			var pw = Std.int(W - PRESET_COL - COLOR_COL - 26);
			_buildPreviewSwatches(ox, oy, pw);
		}
	}

	function _applyAndRestart():Void
	{
		if (_nameInput != null && _nameInput.text.trim() != '')
			_preview.name = _nameInput.text.trim();
		EditorTheme.applyCustom(_preview);
		_setStatus('Saved "${_preview.name}". Restarting…');
		close();
		// Restart the current editor state so all colors refresh
		var curState = flixel.FlxG.state;
		if (Std.isOfType(curState, StageEditor))
		{
			flixel.FlxG.mouse.visible = false;
			funkin.transitions.StateTransition.switchState(new StageEditor());
		}
		else if (Std.isOfType(curState, funkin.debug.AnimationDebug))
		{
			var ad:funkin.debug.AnimationDebug = cast curState;
			funkin.transitions.StateTransition.switchState(new funkin.debug.AnimationDebug(ad.daAnim));
		}
		else if (Std.isOfType(curState, funkin.debug.charting.ChartingState))
		{
			funkin.transitions.StateTransition.switchState(new funkin.debug.charting.ChartingState());
		}
		else if (Std.isOfType(curState, funkin.debug.DialogueEditor))
		{
			funkin.transitions.StateTransition.switchState(new funkin.debug.DialogueEditor());
		}
		else if (Std.isOfType(curState, funkin.menus.FreeplayEditorState))
		{
			funkin.transitions.StateTransition.switchState(new funkin.menus.FreeplayEditorState());
		}
		else
		{
			// Fallback: just re-create the current state
			flixel.FlxG.resetState();
		}
	}

	function _saveOnly():Void
	{
		if (_nameInput != null && _nameInput.text.trim() != '')
			_preview.name = _nameInput.text.trim();
		EditorTheme.applyCustom(_preview);
		if (_onApply != null) _onApply();
		_setStatus('Theme "${_preview.name}" saved. Close and reopen the editor to see it.');
	}

	function _setStatus(msg:String):Void { if (_statusTxt != null) _statusTxt.text = msg; }

	// ─────────────────────────────────────────────────────────────────────────
	// UTILIDADES
	// ─────────────────────────────────────────────────────────────────────────

	static function _copyTheme(t:ThemeData):ThemeData return {
		name: t.name, bgDark: t.bgDark, bgPanel: t.bgPanel,
		bgPanelAlt: t.bgPanelAlt, bgHover: t.bgHover, borderColor: t.borderColor,
		accent: t.accent, accentAlt: t.accentAlt, selection: t.selection,
		textPrimary: t.textPrimary, textSecondary: t.textSecondary, textDim: t.textDim,
		warning: t.warning, success: t.success, error: t.error,
		rowSelected: t.rowSelected, rowEven: t.rowEven, rowOdd: t.rowOdd,
	};

	static function _lum(c:Int):Float
	{
		var r = ((c >> 16) & 0xFF) / 255.0;
		var g = ((c >>  8) & 0xFF) / 255.0;
		var b = ( c        & 0xFF) / 255.0;
		return 0.2126 * r + 0.7152 * g + 0.0722 * b;
	}

	override function close():Void
	{
		// FIX: limpiar la cámara temporal al cerrar
		if (cameras != null && cameras.length > 0)
		{
			var cam = cameras[0];
			if (cam != null)
				FlxG.cameras.remove(cam, true);
		}
		super.close();
	}
}
