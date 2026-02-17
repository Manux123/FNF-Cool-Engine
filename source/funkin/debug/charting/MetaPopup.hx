package funkin.debug.charting;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import flixel.addons.ui.*;
import funkin.data.Song.SwagSong;

using StringTools;

/**
 * Popup de Meta: permite editar Stage y Speed de la canción.
 * Se abre al hacer clic en el botón "Meta" de la toolbar.
 */
class MetaPopup extends FlxGroup
{
	var parent:ChartingState;
	var _song:SwagSong;
	var camHUD:FlxCamera;

	// Fondo oscuro semitransparente
	var overlay:FlxSprite;
	// Panel del popup
	var panel:FlxSprite;
	// Título
	var titleText:FlxText;

	// Campos de Stage
	var stageLabel:FlxText;
	var stageInput:FlxUIInputText;

	// Campos de Speed
	var speedLabel:FlxText;
	var speedStepper:FlxUINumericStepper;

	// Botón cerrar
	var closeBtn:FlxButton;
	var confirmBtn:FlxButton;

	public var isOpen:Bool = false;

	static inline var POPUP_W:Int = 400;
	static inline var POPUP_H:Int = 220;
	static inline var BG_DARK:Int = 0xFF0D0D0D;
	static inline var BG_PANEL:Int = 0xFF1A1A2E;
	static inline var ACCENT_CYAN:Int = 0xFF00D9FF;
	static inline var TEXT_WHITE:Int = 0xFFFFFFFF;
	static inline var TEXT_GRAY:Int = 0xFFAAAAAA;

	public function new(parent:ChartingState, song:SwagSong, camHUD:FlxCamera)
	{
		super();
		this.parent = parent;
		this._song = song;
		this.camHUD = camHUD;

		buildUI();
		close(); // Empieza cerrado
	}

	function buildUI():Void
	{
		var cx = (FlxG.width - POPUP_W) / 2;
		var cy = (FlxG.height - POPUP_H) / 2;

		// Overlay semitransparente
		overlay = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, 0xAA000000);
		overlay.scrollFactor.set();
		overlay.cameras = [camHUD];
		add(overlay);

		// Panel
		panel = new FlxSprite(cx, cy).makeGraphic(POPUP_W, POPUP_H, BG_PANEL);
		panel.scrollFactor.set();
		panel.cameras = [camHUD];
		add(panel);

		// Borde superior decorativo
		var topBar = new FlxSprite(cx, cy).makeGraphic(POPUP_W, 4, ACCENT_CYAN);
		topBar.scrollFactor.set();
		topBar.cameras = [camHUD];
		add(topBar);

		// Título
		titleText = new FlxText(cx + 15, cy + 15, POPUP_W - 30, "META:", 18);
		titleText.setFormat(Paths.font("vcr.ttf"), 18, ACCENT_CYAN, LEFT);
		titleText.scrollFactor.set();
		titleText.cameras = [camHUD];
		add(titleText);

		// Stage label
		stageLabel = new FlxText(cx + 15, cy + 55, 0, "Stage:", 12);
		stageLabel.setFormat(Paths.font("vcr.ttf"), 12, TEXT_GRAY, LEFT);
		stageLabel.scrollFactor.set();
		stageLabel.cameras = [camHUD];
		add(stageLabel);

		// Stage input
		stageInput = new FlxUIInputText(cx + 15, cy + 72, 150, _song.stage != null ? _song.stage : "", 12);
		stageInput.scrollFactor.set();
		stageInput.cameras = [camHUD];
		add(stageInput);

		// Speed label
		speedLabel = new FlxText(cx + 210, cy + 55, 0, "Speed:", 12);
		speedLabel.setFormat(Paths.font("vcr.ttf"), 12, TEXT_GRAY, LEFT);
		speedLabel.scrollFactor.set();
		speedLabel.cameras = [camHUD];
		add(speedLabel);

		// Speed stepper
		speedStepper = new FlxUINumericStepper(cx + 210, cy + 72, 0.1, _song.speed > 0 ? _song.speed : 1.0, 0.1, 10.0, 1);
		speedStepper.scrollFactor.set();
		speedStepper.cameras = [camHUD];
		add(speedStepper);

		// Botón Confirmar
		confirmBtn = new FlxButton(cx + 15, cy + 160, "Apply", function()
		{
			applyChanges();
			close();
		});
		confirmBtn.scrollFactor.set();
		confirmBtn.cameras = [camHUD];
		add(confirmBtn);

		// Botón Cerrar
		closeBtn = new FlxButton(cx + POPUP_W - 100, cy + 160, "Close", function()
		{
			close();
		});
		closeBtn.scrollFactor.set();
		closeBtn.cameras = [camHUD];
		add(closeBtn);
	}

	function applyChanges():Void
	{
		if (stageInput != null && stageInput.text.length > 0)
			_song.stage = stageInput.text.trim();

		if (speedStepper != null)
			_song.speed = speedStepper.value;

		parent.showMessage('✅ Meta updated: Stage=${_song.stage}, Speed=${_song.speed}', 0xFF00FF88);
	}

	public function open():Void
	{
		isOpen = true;
		visible = true;
		active = true;

		// Refrescar valores del song
		if (stageInput != null)
			stageInput.text = _song.stage != null ? _song.stage : "";
		if (speedStepper != null)
			speedStepper.value = _song.speed > 0 ? _song.speed : 1.0;
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

		// Cerrar con ESC
		if (FlxG.keys.justPressed.ESCAPE)
			close();

		// Cerrar al clicar fuera del panel
		if (FlxG.mouse.justPressed)
		{
			var cx = (FlxG.width - POPUP_W) / 2;
			var cy = (FlxG.height - POPUP_H) / 2;
			var mx = FlxG.mouse.x;
			var my = FlxG.mouse.y;

			if (mx < cx || mx > cx + POPUP_W || my < cy || my > cy + POPUP_H)
				close();
		}
	}
}
