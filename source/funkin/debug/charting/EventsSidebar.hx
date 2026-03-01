package funkin.debug.charting;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.group.FlxGroup;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import flixel.addons.ui.*;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import funkin.data.Song.SwagSong;
import funkin.scripting.EventInfoSystem;
import funkin.scripting.EventInfoSystem.EventParamType;
import funkin.scripting.EventInfoSystem.EventParamDef;

/**
 * Tipo de evento del charting.
 */
typedef ChartEvent =
{
	var stepTime:Float;
	var type:String;
	var value:String;
}

/**
 * Sidebar izquierdo para el sistema de eventos.
 *
 * v2 — Todas las mejoras:
 *  • Tipos de evento 100% softcodeados via EventInfoSystem (JSON en data/events/).
 *  • UI del popup generada dinámicamente segun los params del evento.
 *  • Eventos se pueden MOVER arrastrando con clic izquierdo.
 *  • Eventos se pueden BORRAR con clic derecho.
 *  • Soporte de eventos compartidos (data/events/shared/) que aplican a todos los mods.
 */
class EventsSidebar extends FlxGroup
{
	var parent:ChartingState;
	var _song:SwagSong;
	var camGame:FlxCamera;
	var camHUD:FlxCamera;

	var gridX:Float;
	var gridY:Float;
	var gridScrollY:Float = 0;
	var GRID_SIZE:Int = 40;

	var eventSprites:FlxTypedGroup<FlxSprite>;
	var eventLabels:FlxTypedGroup<FlxText>;

	var addEventBtn:FlxSprite;
	var addEventBtnText:FlxText;
	var hoverBeatY:Float = -1;

	var eventPopup:EventPopup;

	// Drag-to-move
	var _dragging:Bool        = false;
	var _dragEvt:ChartEvent   = null;
	var _dragSprite:FlxSprite = null;
	var _dragLabel:FlxText    = null;
	var _dragOffsetY:Float    = 0;

	// ── Ctrl+Z ───────────────────────────────────────────────────────────────
	var _evtHistory:Array<String> = [];   // JSON snapshots de _song.events
	var _evtHistIdx:Int = -1;
	static inline var MAX_EVT_HIST:Int = 50;

	static inline var SIDEBAR_WIDTH:Int = 120;
	static inline var EVENT_H:Int       = 20;

	public function new(parent:ChartingState, song:SwagSong, camGame:FlxCamera, camHUD:FlxCamera, gridX:Float, gridY:Float)
	{
		super();
		this.parent  = parent;
		this._song   = song;
		this.camGame = camGame;
		this.camHUD  = camHUD;
		this.gridX   = gridX;
		this.gridY   = gridY;

		// Cargar definiciones softcodeadas
		EventInfoSystem.reload();

		// Snapshot inicial para que Ctrl+Z pueda volver al estado vacío
		if (_song.events == null) _song.events = [];
		_evtHistory.push(haxe.Json.stringify(_song.events));
		_evtHistIdx = 0;

		eventSprites = new FlxTypedGroup<FlxSprite>();
		eventLabels  = new FlxTypedGroup<FlxText>();
		add(eventSprites);
		add(eventLabels);

		_buildAddButton();
		eventPopup = new EventPopup(parent, song, camHUD, this);
		add(eventPopup);

		refreshEvents();
	}

	function _buildAddButton():Void
	{
		addEventBtn = new FlxSprite(0, 0).makeGraphic(28, 28, 0xFF1A3A2A);
		addEventBtn.scrollFactor.set();
		addEventBtn.cameras = [camHUD];
		addEventBtn.visible = false;
		add(addEventBtn);

		addEventBtnText = new FlxText(0, 0, 28, "+", 16);
		addEventBtnText.setFormat(Paths.font("vcr.ttf"), 16, 0xFF00FF88, CENTER);
		addEventBtnText.scrollFactor.set();
		addEventBtnText.cameras = [camHUD];
		addEventBtnText.visible = false;
		add(addEventBtnText);

		// Sprite temporal para visualizar el drag
		_dragSprite = new FlxSprite().makeGraphic(SIDEBAR_WIDTH, EVENT_H, 0xFFAAAAAA);
		_dragSprite.scrollFactor.set();
		_dragSprite.cameras = [camHUD];
		_dragSprite.visible = false;
		_dragSprite.alpha   = 0.75;
		add(_dragSprite);

		_dragLabel = new FlxText(0, 0, SIDEBAR_WIDTH - 4, "", 9);
		_dragLabel.setFormat(Paths.font("vcr.ttf"), 9, 0xFF000000, LEFT);
		_dragLabel.scrollFactor.set();
		_dragLabel.cameras = [camHUD];
		_dragLabel.visible = false;
		add(_dragLabel);
	}

	public function setScrollY(scrollY:Float, currentGridY:Float):Void
	{
		this.gridScrollY = scrollY;
		this.gridY       = currentGridY;
		refreshEvents();
	}

	public function isAnyPopupOpen():Bool
		return eventPopup != null && eventPopup.isOpen;

	public function refreshEvents():Void
	{
		eventSprites.clear();
		eventLabels.clear();

		if (_song.events == null) return;

		for (evt in _song.events)
		{
			// Ocultar el que se está arrastrando
			if (_dragging && _dragEvt == evt) continue;

			var evtY = gridY + (evt.stepTime * GRID_SIZE);
			if (evtY < 80 || evtY > FlxG.height - 30) continue;

			var evtColor = _eventColor(evt.type);

			var pill = new FlxSprite(gridX - SIDEBAR_WIDTH - 5, evtY - EVENT_H / 2);
			pill.makeGraphic(SIDEBAR_WIDTH, EVENT_H, evtColor);
			pill.scrollFactor.set();
			pill.cameras = [camHUD];
			eventSprites.add(pill);

			var con = new FlxSprite(gridX - 5, evtY - 1);
			con.makeGraphic(5, 2, evtColor);
			con.scrollFactor.set();
			con.cameras = [camHUD];
			eventSprites.add(con);

			var lbl = new FlxText(gridX - SIDEBAR_WIDTH - 3, evtY - EVENT_H / 2 + 3, SIDEBAR_WIDTH - 4, '${evt.type}: ${evt.value}', 9);
			lbl.setFormat(Paths.font("vcr.ttf"), 9, 0xFF000000, LEFT);
			lbl.scrollFactor.set();
			lbl.cameras = [camHUD];
			eventLabels.add(lbl);
		}
	}

	function _eventColor(type:String):Int
	{
		if (EventInfoSystem.eventColors.exists(type))
			return EventInfoSystem.eventColors.get(type);
		return switch (type)
		{
			case "Camera":      0xFF88CCFF;
			case "BPM Change":  0xFFFFAA00;
			case "Alt Anim":    0xFFFF88CC;
			case "Play Anim":   0xFF88FF88;
			case "Camera Zoom": 0xFFCCAAFF;
			default:            0xFFAAAAAA;
		}
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (eventPopup.isOpen) return;

		// Ctrl+Z → deshacer último cambio de evento
		if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.Z)
		{
			_undoEvt();
			return;
		}

		var mx = FlxG.mouse.x;
		var my = FlxG.mouse.y;

		// ── Drag activo ───────────────────────────────────────────────────────
		if (_dragging && _dragEvt != null)
		{
			_dragSprite.y = my + _dragOffsetY;
			_dragLabel.y  = _dragSprite.y + 3;

			if (FlxG.mouse.justReleased)
			{
				var relY    = (_dragSprite.y + EVENT_H / 2) - gridY;
				var newStep = Math.max(0, Math.round(relY / GRID_SIZE));
				_saveEvtHistory();
				_dragEvt.stepTime = newStep;
				_song.events.sort(function(a, b) return Std.int(a.stepTime - b.stepTime));
				_stopDrag();
				refreshEvents();
				parent.showMessage('✅ Evento movido a step ${newStep}', 0xFF00FF88);
			}
			return;
		}

		// ── Hover en el borde izq → botón "+" ────────────────────────────────
		var isHoveringBorder = (mx >= gridX - 20 && mx <= gridX && my >= 80 && my <= FlxG.height - 30);

		if (isHoveringBorder)
		{
			var relY     = my - gridY;
			var beatSize = GRID_SIZE * 4;
			hoverBeatY   = gridY + (Math.floor(relY / beatSize) * beatSize);

			var justShown = !addEventBtn.visible;
			addEventBtn.x     = gridX - 24;
			addEventBtn.y     = hoverBeatY - 14;
			addEventBtnText.x = gridX - 24;
			addEventBtnText.y = hoverBeatY - 14 + 2;

			if (justShown)
			{
				addEventBtn.alpha = addEventBtnText.alpha = 0;
				addEventBtn.visible = addEventBtnText.visible = true;
				FlxTween.cancelTweensOf(addEventBtn);
				FlxTween.cancelTweensOf(addEventBtnText);
				FlxTween.tween(addEventBtn,     {alpha: 0.85}, 0.12, {ease: FlxEase.quadOut});
				FlxTween.tween(addEventBtnText, {alpha: 1.0},  0.12, {ease: FlxEase.quadOut});
			}

			var overBtn = FlxG.mouse.overlaps(addEventBtn, camHUD);
			addEventBtn.alpha = overBtn ? 1.0 : 0.75;

			if (FlxG.mouse.justPressed && overBtn)
				eventPopup.openAtStep((hoverBeatY - gridY) / GRID_SIZE);
		}
		else if (addEventBtn.visible && !FlxG.mouse.overlaps(addEventBtn, camHUD))
		{
			FlxTween.cancelTweensOf(addEventBtn);
			FlxTween.cancelTweensOf(addEventBtnText);
			FlxTween.tween(addEventBtn,     {alpha: 0}, 0.10, {ease: FlxEase.quadIn, onComplete: function(_) { addEventBtn.visible = false; }});
			FlxTween.tween(addEventBtnText, {alpha: 0}, 0.10, {ease: FlxEase.quadIn, onComplete: function(_) { addEventBtnText.visible = false; }});
		}

		// ── Clic izquierdo sobre píldora → iniciar drag ───────────────────────
		if (FlxG.mouse.justPressed && !FlxG.mouse.overlaps(addEventBtn, camHUD))
			_tryStartDrag(mx, my);

		// ── Clic derecho → borrar ─────────────────────────────────────────────
		if (FlxG.mouse.justPressedRight)
			_removeEventAtMouse(mx, my);
	}

	function _tryStartDrag(mx:Float, my:Float):Void
	{
		if (_song.events == null) return;
		for (evt in _song.events)
		{
			var evtY = gridY + (evt.stepTime * GRID_SIZE);
			var evtX = gridX - SIDEBAR_WIDTH - 5;
			if (mx >= evtX && mx <= gridX - 5 && my >= evtY - EVENT_H && my <= evtY + EVENT_H)
			{
				_dragging    = true;
				_dragEvt     = evt;
				_dragOffsetY = (evtY - EVENT_H / 2) - my;

				var color = _eventColor(evt.type);
				_dragSprite.makeGraphic(SIDEBAR_WIDTH, EVENT_H, color);
				_dragSprite.x = evtX;
				_dragSprite.y = my + _dragOffsetY;
				_dragSprite.visible = true;

				_dragLabel.text    = '${evt.type}: ${evt.value}';
				_dragLabel.x       = evtX + 2;
				_dragLabel.y       = _dragSprite.y + 3;
				_dragLabel.visible = true;

				refreshEvents();
				return;
			}
		}
	}

	function _stopDrag():Void
	{
		_dragging = false;
		_dragEvt  = null;
		_dragSprite.visible = false;
		_dragLabel.visible  = false;
	}

	function _removeEventAtMouse(mx:Float, my:Float):Void
	{
		if (_song.events == null) return;
		for (evt in _song.events)
		{
			var evtY = gridY + (evt.stepTime * GRID_SIZE);
			var evtX = gridX - SIDEBAR_WIDTH - 5;
			if (mx >= evtX && mx <= gridX && my >= evtY - EVENT_H && my <= evtY + EVENT_H)
			{
				_saveEvtHistory();
				_song.events.remove(evt);
				refreshEvents();
				parent.showMessage('🗑 Evento "${evt.type}" eliminado', 0xFFFF3366);
				return;
			}
		}
	}

	// ── Historia de eventos (Ctrl+Z) ──────────────────────────────────────────

	function _saveEvtHistory():Void
	{
		if (_song.events == null) _song.events = [];
		// Truncar rama futura si la hay
		if (_evtHistIdx < _evtHistory.length - 1)
			_evtHistory.splice(_evtHistIdx + 1, _evtHistory.length - _evtHistIdx - 1);

		_evtHistory.push(haxe.Json.stringify(_song.events));
		_evtHistIdx = _evtHistory.length - 1;

		if (_evtHistory.length > MAX_EVT_HIST)
		{
			_evtHistory.shift();
			_evtHistIdx--;
		}
	}

	function _undoEvt():Void
	{
		if (_evtHistIdx <= 0)
		{
			parent.showMessage('⚠ No hay más acciones que deshacer', 0xFFFFAA00);
			return;
		}
		_evtHistIdx--;
		_song.events = haxe.Json.parse(_evtHistory[_evtHistIdx]);
		refreshEvents();
		parent.showMessage('↩ Undo evento (${_evtHistIdx + 1}/${_evtHistory.length})', 0xFF00CCFF);
	}

	public function addEvent(stepTime:Float, type:String, value:String):Void
	{
		if (_song.events == null) _song.events = [];

		for (existing in _song.events)
		{
			if (Math.abs(existing.stepTime - stepTime) < 0.1 && existing.type == type)
			{
				_saveEvtHistory();
				existing.value = value;
				refreshEvents();
				parent.showMessage('✅ Evento "${type}" actualizado en step ${stepTime}', 0xFF00FF88);
				return;
			}
		}

		_saveEvtHistory();
		_song.events.push({ stepTime: stepTime, type: type, value: value });
		_song.events.sort(function(a, b) return Std.int(a.stepTime - b.stepTime));
		refreshEvents();
		parent.showMessage('✅ Evento "${type}" añadido en step ${stepTime}', 0xFF00FF88);
	}
}

// ─────────────────────────────────────────────────────────────────────────────

/**
 * Popup para configurar un evento antes de añadirlo al chart.
 * Los campos se generan dinámicamente según los parámetros del evento
 * definidos en EventInfoSystem (JSON en data/events/).
 */
class EventPopup extends FlxGroup
{
	var parent:ChartingState;
	var _song:SwagSong;
	var camHUD:FlxCamera;
	var sidebar:EventsSidebar;

	public var isOpen:Bool = false;
	var targetStep:Float   = 0;

	var overlay:FlxSprite;
	var panel:FlxSprite;
	var titleText:FlxText;
	var typeDropDown:FlxUIDropDownMenu;

	var _selectedType:String        = "";
	var _paramWidgets:Array<Dynamic>     = [];
	var _paramDefs:Array<EventParamDef> = [];
	var _dynamicGroup:FlxGroup;

	var addBtn:FlxButton;
	var closeBtn:FlxButton;

	static inline var POPUP_W:Int  = 360;
	static inline var POPUP_H:Int  = 290;
	static inline var BG:Int       = 0xFF0D1F0D;
	static inline var ACCENT:Int   = 0xFF00FF88;
	static inline var GRAY:Int     = 0xFFAAAAAA;
	static inline var FIELD_W:Int  = 320;

	public function new(parent:ChartingState, song:SwagSong, camHUD:FlxCamera, sidebar:EventsSidebar)
	{
		super();
		this.parent  = parent;
		this._song   = song;
		this.camHUD  = camHUD;
		this.sidebar = sidebar;
		_build();
		visible = false;
		close();
	}

	function _build():Void
	{
		var cx = (FlxG.width  - POPUP_W) / 2;
		var cy = (FlxG.height - POPUP_H) / 2;

		overlay = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, 0xAA000000);
		overlay.scrollFactor.set(); overlay.cameras = [camHUD]; add(overlay);

		panel = new FlxSprite(cx, cy).makeGraphic(POPUP_W, POPUP_H, BG);
		panel.scrollFactor.set(); panel.cameras = [camHUD]; add(panel);

		var bar = new FlxSprite(cx, cy).makeGraphic(POPUP_W, 4, ACCENT);
		bar.scrollFactor.set(); bar.cameras = [camHUD]; add(bar);

		titleText = new FlxText(cx + 15, cy + 10, POPUP_W - 30, "Add Event", 16);
		titleText.setFormat(Paths.font("vcr.ttf"), 16, ACCENT, LEFT);
		titleText.scrollFactor.set(); titleText.cameras = [camHUD]; add(titleText);

		var typeLbl = new FlxText(cx + 15, cy + 38, 0, "Type:", 11);
		typeLbl.setFormat(Paths.font("vcr.ttf"), 11, GRAY, LEFT);
		typeLbl.scrollFactor.set(); typeLbl.cameras = [camHUD]; add(typeLbl);

		var typeNames = EventInfoSystem.eventList.copy();
		if (typeNames.length == 0) typeNames.push("(no events)");

		typeDropDown = new FlxUIDropDownMenu(cx + 15, cy + 53, FlxUIDropDownMenu.makeStrIdLabelArray(typeNames, true), function(id:String)
		{
			var idx = Std.parseInt(id);
			if (idx != null && idx >= 0 && idx < typeNames.length)
				_switchToType(typeNames[idx]);
		});
		typeDropDown.scrollFactor.set(); typeDropDown.cameras = [camHUD]; add(typeDropDown);

		_dynamicGroup = new FlxGroup();
		add(_dynamicGroup);

		addBtn = new FlxButton(cx + 15, cy + POPUP_H - 42, "Add Event", _onAddPressed);
		addBtn.scrollFactor.set(); addBtn.cameras = [camHUD]; add(addBtn);

		closeBtn = new FlxButton(cx + POPUP_W - 110, cy + POPUP_H - 42, "Cancel", close);
		closeBtn.scrollFactor.set(); closeBtn.cameras = [camHUD]; add(closeBtn);
	}

	function _switchToType(type:String):Void
	{
		_selectedType = type;
		_clearDynamic();

		_paramDefs    = EventInfoSystem.eventParams.exists(type) ? EventInfoSystem.eventParams.get(type) : [];
		_paramWidgets = [];

		var cx   = (FlxG.width  - POPUP_W) / 2;
		var cy   = (FlxG.height - POPUP_H) / 2;
		var yOff = cy + 108;
		var maxY = cy + POPUP_H - 55;

		for (i in 0..._paramDefs.length)
		{
			if (yOff > maxY) break;
			var p = _paramDefs[i];

			var lbl = new FlxText(cx + 15, yOff, 0, p.name + ":", 10);
			lbl.setFormat(Paths.font("vcr.ttf"), 10, GRAY, LEFT);
			lbl.scrollFactor.set(); lbl.cameras = [camHUD];
			_dynamicGroup.add(lbl);
			yOff += 16;

			var widget:Dynamic = null;
			switch (p.type)
			{
				case PDBool:
					widget = new FlxUIDropDownMenu(cx + 15, yOff, FlxUIDropDownMenu.makeStrIdLabelArray(["true","false"], true), null);

				case PDDropDown(opts):
					widget = new FlxUIDropDownMenu(cx + 15, yOff, FlxUIDropDownMenu.makeStrIdLabelArray(opts, true), null);

				default:
					var inp = new FlxUIInputText(cx + 15, yOff, FIELD_W, p.defValue, 12);
					inp.scrollFactor.set(); inp.cameras = [camHUD];
					widget = inp;
			}

			if (widget != null)
			{
				widget.scrollFactor.set();
				widget.cameras = [camHUD];
				_dynamicGroup.add(widget);
				_paramWidgets.push(widget);
				yOff += 30;
			}
		}
	}

	function _clearDynamic():Void
	{
		_dynamicGroup.forEach(function(m:flixel.FlxBasic) { m.destroy(); });
		_dynamicGroup.clear();
		_paramWidgets = [];
	}

	function _readValues():String
	{
		var parts:Array<String> = [];
		for (i in 0..._paramWidgets.length)
		{
			var w = _paramWidgets[i];
			var val:String = "";
			if (Std.isOfType(w, FlxUIInputText))
				val = cast(w, FlxUIInputText).text;
			else if (Std.isOfType(w, FlxUIDropDownMenu))
			{
				var dd  = cast(w, FlxUIDropDownMenu);
				var idx = Std.parseInt(dd.selectedId);
				var p   = _paramDefs[i];
				switch (p.type)
				{
					case PDBool:
						val = (idx == 0) ? "true" : "false";
					case PDDropDown(opts):
						val = (idx != null && idx >= 0 && idx < opts.length) ? opts[idx] : "";
					default:
						val = dd.selectedId;
				}
			}
			parts.push(val);
		}
		return parts.join("|");
	}

	function _onAddPressed():Void
	{
		if (_selectedType == "" || _selectedType == "(no events)") return;
		sidebar.addEvent(targetStep, _selectedType, _readValues());
		close();
	}

	public function openAtStep(step:Float):Void
	{
		targetStep = step;
		titleText.text = 'Add Event @ step ${Std.int(step)}';

		var types = EventInfoSystem.eventList;
		if (types.length > 0) _switchToType(types[0]);

		isOpen = true;
		visible = true;
		active  = true;

		var cx = (FlxG.width  - POPUP_W) / 2;
		var cy = (FlxG.height - POPUP_H) / 2;
		overlay.alpha = 0;
		FlxTween.cancelTweensOf(overlay);
		FlxTween.tween(overlay, {alpha: 0.60}, 0.16, {ease: FlxEase.quadOut});
		panel.y = cy + 30; panel.alpha = 0;
		FlxTween.cancelTweensOf(panel);
		FlxTween.tween(panel, {alpha: 1, y: cy}, 0.22, {ease: FlxEase.backOut});
		_fadeKids(true);
	}

	public function close():Void
	{
		if (!isOpen && !visible) { visible = false; active = false; return; }
		isOpen = false; active = false;
		if (!visible) { visible = false; return; }
		var cy = (FlxG.height - POPUP_H) / 2;
		FlxTween.cancelTweensOf(overlay);
		FlxTween.tween(overlay, {alpha: 0}, 0.14, {ease: FlxEase.quadIn});
		FlxTween.cancelTweensOf(panel);
		FlxTween.tween(panel, {alpha: 0, y: cy + 20}, 0.17, {ease: FlxEase.quadIn, onComplete: function(_) { visible = false; }});
		_fadeKids(false);
	}

	function _fadeKids(opening:Bool):Void
	{
		forEach(function(m:flixel.FlxBasic)
		{
			if (m == overlay || m == panel || m == _dynamicGroup) return;
			if (Std.isOfType(m, FlxSprite))
			{
				var spr:FlxSprite = cast m;
				FlxTween.cancelTweensOf(spr);
				FlxTween.tween(spr, {alpha: opening ? 1.0 : 0.0}, opening ? 0.18 : 0.12, {ease: opening ? FlxEase.quadOut : FlxEase.quadIn, startDelay: opening ? 0.10 : 0.0});
			}
		});
	}

	override public function update(elapsed:Float):Void
	{
		if (!isOpen) return;
		super.update(elapsed);
		if (FlxG.keys.justPressed.ESCAPE) close();
	}
}
