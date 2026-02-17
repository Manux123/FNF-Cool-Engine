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
import funkin.data.Song.SwagSong;

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
 * Muestra los eventos de la canción (Camera, BPM Change, etc.)
 * y permite agregar nuevos al hacer clic en el borde izquierdo del grid.
 */
class EventsSidebar extends FlxGroup
{
	var parent:ChartingState;
	var _song:SwagSong;
	var camGame:FlxCamera;
	var camHUD:FlxCamera;

	// Posición del grid (para saber dónde dibujar eventos)
	var gridX:Float;
	var gridY:Float;
	var gridScrollY:Float = 0;
	var GRID_SIZE:Int = 40;

	// Sprites de eventos renderizados
	var eventSprites:FlxTypedGroup<FlxSprite>;
	var eventLabels:FlxTypedGroup<FlxText>;

	// Botón "+" que aparece al hacer hover en el borde izquierdo
	var addEventBtn:FlxSprite;
	var addEventBtnText:FlxText;
	var addEventBtnVisible:Bool = false;
	var hoverBeatY:Float = -1;

	// Popup de selección de evento
	var eventPopup:EventPopup;

	static inline var SIDEBAR_WIDTH:Int = 120;
	static inline var EVENT_H:Int = 20;
	static inline var ACCENT_CYAN:Int = 0xFF00D9FF;
	static inline var ACCENT_YELLOW:Int = 0xFFFFCC00;
	static inline var TEXT_WHITE:Int = 0xFFFFFFFF;
	static inline var TEXT_GRAY:Int = 0xFFAAAAAA;

	// Tipos de eventos disponibles
	public static var EVENT_TYPES:Array<String> = ["Camera", "BPM Change", "Alt Anim", "Play Anim", "Set Property", "Camera Zoom"];

	public function new(parent:ChartingState, song:SwagSong, camGame:FlxCamera, camHUD:FlxCamera, gridX:Float, gridY:Float)
	{
		super();
		this.parent = parent;
		this._song = song;
		this.camGame = camGame;
		this.camHUD = camHUD;
		this.gridX = gridX;
		this.gridY = gridY;

		eventSprites = new FlxTypedGroup<FlxSprite>();
		eventLabels = new FlxTypedGroup<FlxText>();

		add(eventSprites);
		add(eventLabels);

		buildAddButton();

		// Popup de evento
		eventPopup = new EventPopup(parent, song, camHUD, this);
		add(eventPopup);

		refreshEvents();
	}

	function buildAddButton():Void
	{
		// Botón hexagonal "+" para agregar eventos
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
	}

	public function setScrollY(scrollY:Float, currentGridY:Float):Void
	{
		this.gridScrollY = scrollY;
		this.gridY = currentGridY;
		refreshEvents();
	}

	public function isAnyPopupOpen():Bool
	{
		return eventPopup != null && eventPopup.isOpen;
	}

	public function refreshEvents():Void
	{
		eventSprites.clear();
		eventLabels.clear();

		if (_song.events == null)
			return;

		for (evt in _song.events)
		{
			// Calcular posición Y del evento en pantalla
			var evtY = gridY + (evt.stepTime * GRID_SIZE);

			// Solo mostrar si está visible en pantalla
			if (evtY < 80 || evtY > FlxG.height - 30)
				continue;

			// Color según tipo
			var evtColor = getEventColor(evt.type);

			// Píldora del evento
			var evtSprite = new FlxSprite(gridX - SIDEBAR_WIDTH - 5, evtY - EVENT_H / 2);
			evtSprite.makeGraphic(SIDEBAR_WIDTH, EVENT_H, evtColor);
			evtSprite.scrollFactor.set();
			evtSprite.cameras = [camHUD];
			eventSprites.add(evtSprite);

			// Línea conectora al grid
			var connector = new FlxSprite(gridX - 5, evtY - 1);
			connector.makeGraphic(5, 2, evtColor);
			connector.scrollFactor.set();
			connector.cameras = [camHUD];
			eventSprites.add(connector);

			// Texto del evento
			var evtLabel = new FlxText(gridX - SIDEBAR_WIDTH - 3, evtY - EVENT_H / 2 + 3, SIDEBAR_WIDTH - 4, '${evt.type}: ${evt.value}', 9);
			evtLabel.setFormat(Paths.font("vcr.ttf"), 9, 0xFF000000, LEFT);
			evtLabel.scrollFactor.set();
			evtLabel.cameras = [camHUD];
			eventLabels.add(evtLabel);
		}
	}

	function getEventColor(type:String):Int
	{
		return switch (type)
		{
			case "Camera": 0xFF88CCFF;
			case "BPM Change": 0xFFFFAA00;
			case "Alt Anim": 0xFFFF88CC;
			case "Play Anim": 0xFF88FF88;
			case "Camera Zoom": 0xFFCCAAFF;
			default: 0xFFAAAAAA;
		}
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (eventPopup.isOpen)
			return;

		// Detectar hover en el borde izquierdo del grid
		var mx = FlxG.mouse.x;
		var my = FlxG.mouse.y;
		var hoverZoneX = gridX - 20;
		var hoverZoneW = 20;

		var isHoveringBorder = (mx >= hoverZoneX && mx <= gridX && my >= 80 && my <= FlxG.height - 30);

		if (isHoveringBorder)
		{
			// Snap al beat más cercano
			var relY = my - gridY;
			var beatSize = GRID_SIZE * 4;
			var snappedBeat = Math.floor(relY / beatSize);
			hoverBeatY = gridY + (snappedBeat * beatSize);

			// Mostrar el botón "+"
			addEventBtn.x = gridX - 24;
			addEventBtn.y = hoverBeatY - 14;
			addEventBtnText.x = gridX - 24;
			addEventBtnText.y = hoverBeatY - 14 + 2;

			addEventBtn.visible = true;
			addEventBtnText.visible = true;

			// Glow/efecto hover
			addEventBtn.alpha = FlxG.mouse.overlaps(addEventBtn, camHUD) ? 1.0 : 0.7;

			// Click en el botón
			if (FlxG.mouse.justPressed && FlxG.mouse.overlaps(addEventBtn, camHUD))
			{
				var stepTime = (hoverBeatY - gridY) / GRID_SIZE;
				eventPopup.openAtStep(stepTime);
			}
		}
		else
		{
			// Ocultar botón si no estamos en hover
			if (!FlxG.mouse.overlaps(addEventBtn, camHUD))
			{
				addEventBtn.visible = false;
				addEventBtnText.visible = false;
			}
		}

		// Click derecho en un evento para borrarlo
		if (FlxG.mouse.justPressedRight)
		{
			removeEventAtMouse();
		}
	}

	function removeEventAtMouse():Void
	{
		if (_song.events == null)
			return;

		var mx = FlxG.mouse.x;
		var my = FlxG.mouse.y;

		for (evt in _song.events)
		{
			var evtY = gridY + (evt.stepTime * GRID_SIZE);
			var evtX = gridX - SIDEBAR_WIDTH - 5;

			if (mx >= evtX && mx <= gridX && my >= evtY - EVENT_H && my <= evtY + EVENT_H)
			{
				_song.events.remove(evt);
				refreshEvents();
				parent.showMessage('🗑 Evento "${evt.type}" eliminado', 0xFFFF3366);
				return;
			}
		}
	}

	public function addEvent(stepTime:Float, type:String, value:String):Void
	{
		if (_song.events == null)
			_song.events = [];

		// Evitar duplicados exactos en el mismo step
		for (existing in _song.events)
		{
			if (Math.abs(existing.stepTime - stepTime) < 0.1 && existing.type == type)
			{
				existing.value = value;
				refreshEvents();
				parent.showMessage('✅ Evento "${type}" actualizado en step ${stepTime}', 0xFF00FF88);
				return;
			}
		}

		_song.events.push({
			stepTime: stepTime,
			type: type,
			value: value
		});

		// Ordenar por tiempo
		_song.events.sort(function(a, b) return Std.int(a.stepTime - b.stepTime));

		refreshEvents();
		parent.showMessage('✅ Evento "${type}" añadido en step ${stepTime}', 0xFF00FF88);
	}
}

/**
 * Popup para seleccionar y configurar un evento al añadirlo.
 */
class EventPopup extends FlxGroup
{
	var parent:ChartingState;
	var _song:SwagSong;
	var camHUD:FlxCamera;
	var sidebar:EventsSidebar;

	public var isOpen:Bool = false;

	var targetStep:Float = 0;

	var overlay:FlxSprite;
	var panel:FlxSprite;
	var titleText:FlxText;
	var typeDropDown:FlxUIDropDownMenu;
	var valueInput:FlxUIInputText;
	var addBtn:FlxButton;
	var closeBtn:FlxButton;

	static inline var POPUP_W:Int = 320;
	static inline var POPUP_H:Int = 200;
	static inline var BG_PANEL:Int = 0xFF0D1F0D;
	static inline var ACCENT_GREEN:Int = 0xFF00FF88;
	static inline var TEXT_GRAY:Int = 0xFFAAAAAA;

	public function new(parent:ChartingState, song:SwagSong, camHUD:FlxCamera, sidebar:EventsSidebar)
	{
		super();
		this.parent = parent;
		this._song = song;
		this.camHUD = camHUD;
		this.sidebar = sidebar;

		buildUI();
		close();
	}

	function buildUI():Void
	{
		var cx = (FlxG.width - POPUP_W) / 2;
		var cy = (FlxG.height - POPUP_H) / 2;

		overlay = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, 0xAA000000);
		overlay.scrollFactor.set();
		overlay.cameras = [camHUD];
		add(overlay);

		panel = new FlxSprite(cx, cy).makeGraphic(POPUP_W, POPUP_H, BG_PANEL);
		panel.scrollFactor.set();
		panel.cameras = [camHUD];
		add(panel);

		var topBar = new FlxSprite(cx, cy).makeGraphic(POPUP_W, 4, ACCENT_GREEN);
		topBar.scrollFactor.set();
		topBar.cameras = [camHUD];
		add(topBar);

		titleText = new FlxText(cx + 15, cy + 12, POPUP_W, "Add Event", 16);
		titleText.setFormat(Paths.font("vcr.ttf"), 16, ACCENT_GREEN, LEFT);
		titleText.scrollFactor.set();
		titleText.cameras = [camHUD];
		add(titleText);

		var typeLabel = new FlxText(cx + 15, cy + 45, 0, "Type:", 11);
		typeLabel.setFormat(Paths.font("vcr.ttf"), 11, TEXT_GRAY, LEFT);
		typeLabel.scrollFactor.set();
		typeLabel.cameras = [camHUD];
		add(typeLabel);

		typeDropDown = new FlxUIDropDownMenu(cx + 15, cy + 60, FlxUIDropDownMenu.makeStrIdLabelArray(EventsSidebar.EVENT_TYPES, true), function(id:String)
		{
		});
		typeDropDown.scrollFactor.set();
		typeDropDown.cameras = [camHUD];

		var valueLabel = new FlxText(cx + 15, cy + 100, 0, "Valor:", 11);
		valueLabel.setFormat(Paths.font("vcr.ttf"), 11, TEXT_GRAY, LEFT);
		valueLabel.scrollFactor.set();
		valueLabel.cameras = [camHUD];
		add(valueLabel);

		valueInput = new FlxUIInputText(cx + 15, cy + 115, 280, "", 12);
		valueInput.scrollFactor.set();
		valueInput.cameras = [camHUD];
		add(valueInput);

		addBtn = new FlxButton(cx + 15, cy + POPUP_H - 40, "Add Event", function()
		{
			var idx = Std.parseInt(typeDropDown.selectedId);
			var type = (idx >= 0 && idx < EventsSidebar.EVENT_TYPES.length) ? EventsSidebar.EVENT_TYPES[idx] : "Camera";
			sidebar.addEvent(targetStep, type, valueInput.text);
			close();
		});
		addBtn.scrollFactor.set();
		addBtn.cameras = [camHUD];
		add(addBtn);

		add(typeDropDown);

		closeBtn = new FlxButton(cx + POPUP_W - 90, cy + POPUP_H - 40, "Cancel", close);
		closeBtn.scrollFactor.set();
		closeBtn.cameras = [camHUD];
		add(closeBtn);
	}

	public function openAtStep(step:Float):Void
	{
		targetStep = step;
		titleText.text = 'Add Event @ step ${Std.int(step)}';
		valueInput.text = "";

		isOpen = true;
		visible = true;
		active = true;
	}

	public function close():Void
	{
		isOpen = false;
		visible = false;
		active = false;
	}

	override public function update(elapsed:Float):Void
	{
		if (!isOpen)
			return;
		super.update(elapsed);
		if (FlxG.keys.justPressed.ESCAPE)
			close();
	}
}
