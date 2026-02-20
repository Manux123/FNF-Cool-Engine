package funkin.debug.charting;

import flixel.FlxG;
import flixel.FlxCamera;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.addons.ui.FlxUICheckBox;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import funkin.data.Song.SwagSong;
import funkin.gameplay.objects.character.Character;
import funkin.gameplay.CharacterController;
import funkin.data.Conductor;

using StringTools;

class PreviewPanel extends FlxGroup
{
	var parent:ChartingState;
	var _song:SwagSong;
	var camHUD:FlxCamera;
	var camGame:FlxCamera;

	// ── Estado ───────────────────────────────────────────
	public var isExpanded:Bool = true;
	var isPreviewActive:Bool   = false;
	var selectedCharType:Int   = 0;

	// ── Grid selector ────────────────────────────────────
	public var selectedGroupIndex:Int = 0;

	// ── Personaje ────────────────────────────────────────
	// IMPORTANTE: El personaje se añade a este FlxGroup (add()),
	// NO a parent. Así este grupo controla su ciclo de vida y
	// no hay riesgo de crash en FlxDrawQuadsItem.
	var previewChar:Character    = null;
	var charController:CharacterController = null;

	// Carga diferida: se setea en update() y se procesa al inicio del siguiente frame
	// (evita destruir previewChar mientras super.update() lo está iterando)
	var _pendingCharName:String  = null;

	// ── Ajustes en vivo ──────────────────────────────────
	var debugOffsetX:Float = 0;
	var debugOffsetY:Float = 0;
	var debugScale:Float   = 1.0;
	var debugInfoTxt:FlxText;

	// ── Cámara dedicada ──────────────────────────────────
	var camPreview:FlxCamera;
	static inline var CAM_W:Int = 175;
	static inline var CAM_H:Int = 210;
	static inline var CAM_X:Int = 0;
	static inline var CAM_Y:Int = 130;

	// ── UI ───────────────────────────────────────────────
	var panelBg:FlxSprite;
	var rightBorder:FlxSprite;
	var camBorder:FlxSprite;
	var toggleBtn:FlxSprite;
	var toggleBtnText:FlxText;
	var titleText:FlxText;
	var charLabel:FlxText;
	var activateLabel:FlxText;
	var activateCheck:FlxUICheckBox;
	var gridSelectorBg:FlxSprite;
	var gridSelectorLabel:FlxText;
	var gridPrevBtn:FlxSprite;
	var gridNextBtn:FlxSprite;
	var gridPrevTxt:FlxText;
	var gridNextTxt:FlxText;
	var gridValueTxt:FlxText;
	var adjXMinusBtn:FlxSprite;
	var adjXPlusBtn:FlxSprite;
	var adjYMinusBtn:FlxSprite;
	var adjYPlusBtn:FlxSprite;
	var adjSMinusBtn:FlxSprite;
	var adjSPlusBtn:FlxSprite;

	// Labels y valores de ajuste (necesarios para toggle y actualización en vivo)
	var adjXLabel:FlxText;
	var adjYLabel:FlxText;
	var adjSLabel:FlxText;
	var adjXValTxt:FlxText;
	var adjYValTxt:FlxText;
	var adjSValTxt:FlxText;

	var adjBtnTexts:Array<FlxText>  = [];  // textos "-"/"+" de los botones adj (para toggle)
	var optionBgs:Array<FlxSprite>  = [];
	var optionTexts:Array<FlxText>  = [];
	var charOptions:Array<String>   = ["Opponent", "Player", "Girlfriend"];

	// ── Layout ───────────────────────────────────────────
	static inline var PANEL_W:Int = 175;
	static inline var PANEL_H:Int = 520;
	static inline var PANEL_X:Int = 0;
	static inline var PANEL_Y:Int = 130;

	// ── Colores ──────────────────────────────────────────
	static inline var BG_PANEL:Int     = 0xFF0D0D1F;
	static inline var ACCENT_CYAN:Int  = 0xFF00D9FF;
	static inline var ACCENT_GREEN:Int = 0xFF00FF88;
	static inline var ACCENT_WARN:Int  = 0xFFFFAA00;
	static inline var TEXT_GRAY:Int    = 0xFFAAAAAA;
	static var TYPE_COLORS:Array<Int>  = [0xFFFF8888, 0xFF88AAFF, 0xFFFF88FF];

	public function new(parent:ChartingState, song:SwagSong, camGame:FlxCamera, camHUD:FlxCamera)
	{
		super();
		this.parent  = parent;
		this._song   = song;
		this.camGame = camGame;
		this.camHUD  = camHUD;
		setupCamera();
		buildUI();
	}

	// ─────────────────────────────────────────────────────
	// CÁMARA
	// ─────────────────────────────────────────────────────

	function setupCamera():Void
	{
		camPreview = new FlxCamera(CAM_X, CAM_Y, CAM_W, CAM_H);
		camPreview.bgColor = 0xFF111122;
		camPreview.scroll.set(0, 0);
		camPreview.visible = false;
		FlxG.cameras.add(camPreview, false);

		camBorder = new FlxSprite(CAM_X, CAM_Y).makeGraphic(CAM_W, CAM_H, ACCENT_CYAN);
		camBorder.alpha = 0.2;
		camBorder.scrollFactor.set();
		camBorder.cameras = [camHUD];
		camBorder.visible = false;
		add(camBorder);
	}

	// ─────────────────────────────────────────────────────
	// BUILD UI
	// ─────────────────────────────────────────────────────

	function buildUI():Void
	{
		panelBg = new FlxSprite(PANEL_X, PANEL_Y).makeGraphic(PANEL_W, PANEL_H, BG_PANEL);
		panelBg.alpha = 0.93;
		panelBg.scrollFactor.set();
		panelBg.cameras = [camHUD];
		add(panelBg);

		rightBorder = new FlxSprite(PANEL_X + PANEL_W - 2, PANEL_Y).makeGraphic(2, PANEL_H, ACCENT_CYAN);
		rightBorder.alpha = 0.4;
		rightBorder.scrollFactor.set();
		rightBorder.cameras = [camHUD];
		add(rightBorder);

		titleText = new FlxText(PANEL_X + 6, PANEL_Y + 5, PANEL_W - 10, "Preview:", 11);
		titleText.setFormat(Paths.font("vcr.ttf"), 11, ACCENT_CYAN, LEFT);
		titleText.scrollFactor.set();
		titleText.cameras = [camHUD];
		add(titleText);

		toggleBtn = new FlxSprite(PANEL_X + PANEL_W, PANEL_Y + 60).makeGraphic(18, 44, 0xFF1A1A33);
		toggleBtn.scrollFactor.set();
		toggleBtn.cameras = [camHUD];
		add(toggleBtn);

		toggleBtnText = new FlxText(PANEL_X + PANEL_W, PANEL_Y + 72, 18, "<", 14);
		toggleBtnText.setFormat(Paths.font("vcr.ttf"), 14, ACCENT_CYAN, CENTER);
		toggleBtnText.scrollFactor.set();
		toggleBtnText.cameras = [camHUD];
		add(toggleBtnText);

		var optY = PANEL_Y + CAM_H + 10;

		charLabel = new FlxText(PANEL_X + 6, optY, 0, "Character:", 10);
		charLabel.setFormat(Paths.font("vcr.ttf"), 10, TEXT_GRAY, LEFT);
		charLabel.scrollFactor.set();
		charLabel.cameras = [camHUD];
		add(charLabel);

		for (i in 0...charOptions.length)
		{
			var bg = new FlxSprite(PANEL_X + 4, optY + 14 + (i * 22)).makeGraphic(PANEL_W - 8, 19, 0xFF1A2233);
			bg.scrollFactor.set(); bg.cameras = [camHUD];
			optionBgs.push(bg); add(bg);

			var txt = new FlxText(PANEL_X + 8, optY + 16 + (i * 22), PANEL_W - 14, charOptions[i], 10);
			txt.setFormat(Paths.font("vcr.ttf"), 10, TEXT_GRAY, LEFT);
			txt.scrollFactor.set(); txt.cameras = [camHUD];
			optionTexts.push(txt); add(txt);
		}
		updateOptionColors();

		// ── Grid selector ──────────────────────────
		var gsY = optY + 14 + charOptions.length * 22 + 8;

		gridSelectorLabel = makeLabel(PANEL_X + 6, gsY, "Grid:");
		gridSelectorBg    = makeBg(PANEL_X + 4, gsY + 13, PANEL_W - 8, 22, 0xFF0D1A2A);
		gridPrevBtn = makeAdjBtn(PANEL_X + 4,             gsY + 13, "<");
		gridNextBtn = makeAdjBtn(PANEL_X + PANEL_W - 26,  gsY + 13, ">");

		gridPrevTxt = new FlxText(PANEL_X + 4, gsY + 15, 22, "<", 11);
		gridPrevTxt.setFormat(Paths.font("vcr.ttf"), 11, ACCENT_CYAN, CENTER);
		gridPrevTxt.scrollFactor.set(); gridPrevTxt.cameras = [camHUD]; add(gridPrevTxt);

		gridNextTxt = new FlxText(PANEL_X + PANEL_W - 26, gsY + 15, 22, ">", 11);
		gridNextTxt.setFormat(Paths.font("vcr.ttf"), 11, ACCENT_CYAN, CENTER);
		gridNextTxt.scrollFactor.set(); gridNextTxt.cameras = [camHUD]; add(gridNextTxt);

		gridValueTxt = new FlxText(PANEL_X + 26, gsY + 15, PANEL_W - 52, "Group 0", 10);
		gridValueTxt.setFormat(Paths.font("vcr.ttf"), 10, ACCENT_GREEN, CENTER);
		gridValueTxt.scrollFactor.set(); gridValueTxt.cameras = [camHUD]; add(gridValueTxt);
		refreshGridSelectorLabel();

		// ── Ajustes en vivo ────────────────────────
		var adjY = gsY + 42;

		adjXLabel    = makeLabel(PANEL_X + 6, adjY,      "X offset:");
		adjXMinusBtn = makeAdjBtn(PANEL_X + 4,             adjY + 13, "-");
		adjXPlusBtn  = makeAdjBtn(PANEL_X + PANEL_W - 26,  adjY + 13, "+");
		adjXValTxt   = makeValTxt(PANEL_X + 26, adjY + 15, "0");

		adjYLabel    = makeLabel(PANEL_X + 6, adjY + 38, "Y offset:");
		adjYMinusBtn = makeAdjBtn(PANEL_X + 4,             adjY + 51, "-");
		adjYPlusBtn  = makeAdjBtn(PANEL_X + PANEL_W - 26,  adjY + 51, "+");
		adjYValTxt   = makeValTxt(PANEL_X + 26, adjY + 53, "0");

		adjSLabel    = makeLabel(PANEL_X + 6, adjY + 76, "Scale:");
		adjSMinusBtn = makeAdjBtn(PANEL_X + 4,             adjY + 89, "-");
		adjSPlusBtn  = makeAdjBtn(PANEL_X + PANEL_W - 26,  adjY + 89, "+");
		adjSValTxt   = makeValTxt(PANEL_X + 26, adjY + 91, "1.0");

		debugInfoTxt = new FlxText(PANEL_X + 4, adjY + 112, PANEL_W - 8, "", 8);
		debugInfoTxt.setFormat(Paths.font("vcr.ttf"), 8, 0xFF557799, LEFT);
		debugInfoTxt.scrollFactor.set(); debugInfoTxt.cameras = [camHUD]; add(debugInfoTxt);

		// ── Activate ──────────────────────────────
		var checkY = adjY + 130;
		activateLabel = makeLabel(PANEL_X + 6, checkY + 2, "Activate?");

		activateCheck = new FlxUICheckBox(PANEL_X + 90, checkY, null, null, "", 20);
		activateCheck.checked = false;
		activateCheck.scrollFactor.set(); activateCheck.cameras = [camHUD];
		activateCheck.callback = function() {
			if (activateCheck.checked) activatePreview();
			else deactivatePreview();
		};
		add(activateCheck);
	}

	function makeLabel(x:Float, y:Float, txt:String):FlxText
	{
		var t = new FlxText(x, y, 0, txt, 9);
		t.setFormat(Paths.font("vcr.ttf"), 9, TEXT_GRAY, LEFT);
		t.scrollFactor.set(); t.cameras = [camHUD]; add(t);
		return t;
	}

	function makeBg(x:Float, y:Float, w:Int, h:Int, col:Int):FlxSprite
	{
		var s = new FlxSprite(x, y).makeGraphic(w, h, col);
		s.scrollFactor.set(); s.cameras = [camHUD]; add(s);
		return s;
	}

	function makeAdjBtn(x:Float, y:Float, lbl:String):FlxSprite
	{
		var bg = new FlxSprite(x, y).makeGraphic(22, 22, 0xFF1A2A3A);
		bg.scrollFactor.set(); bg.cameras = [camHUD]; add(bg);
		var t = new FlxText(x, y + 3, 22, lbl, 12);
		t.setFormat(Paths.font("vcr.ttf"), 12, ACCENT_CYAN, CENTER);
		t.scrollFactor.set(); t.cameras = [camHUD]; add(t);
		adjBtnTexts.push(t); // guardar referencia para poder ocultar en toggle()
		return bg;
	}

	function makeValTxt(x:Float, y:Float, val:String):FlxText
	{
		var t = new FlxText(x, y, PANEL_W - 52, val, 10);
		t.setFormat(Paths.font("vcr.ttf"), 10, ACCENT_WARN, CENTER);
		t.scrollFactor.set(); t.cameras = [camHUD]; add(t);
		return t;
	}

	function refreshGridSelectorLabel():Void
	{
		if (gridValueTxt == null) return;
		var n = getNumGroups();
		if (n == 0) { gridValueTxt.text = "No groups"; return; }
		selectedGroupIndex = Std.int(Math.max(0, Math.min(selectedGroupIndex, n - 1)));
		if (_song.strumsGroups != null && selectedGroupIndex < _song.strumsGroups.length)
			gridValueTxt.text = _song.strumsGroups[selectedGroupIndex].id + " (#" + selectedGroupIndex + ")";
		else
			gridValueTxt.text = "Group " + selectedGroupIndex;
	}

	function getNumGroups():Int
	{
		if (_song.strumsGroups != null && _song.strumsGroups.length > 0)
			return _song.strumsGroups.length;
		return 2;
	}

	// ─────────────────────────────────────────────────────
	// ACTIVAR / DESACTIVAR
	// ─────────────────────────────────────────────────────

	function activatePreview():Void
	{
		isPreviewActive    = true;
		camPreview.visible = true;
		camBorder.visible  = true;
		loadPreviewCharacter(getCharNameForType(selectedCharType));
		parent.showMessage('👁 Preview: ${charOptions[selectedCharType]} | Grid #$selectedGroupIndex', ACCENT_CYAN);
	}

	function deactivatePreview():Void
	{
		isPreviewActive    = false;
		camPreview.visible = false;
		camBorder.visible  = false;
		destroyPreviewChar();
		parent.showMessage('👁 Preview desactivado', 0xFF555555);
	}

	// ─────────────────────────────────────────────────────
	// CARGAR PERSONAJE
	// ─────────────────────────────────────────────────────

	function getCharNameForType(typeIndex:Int):String
	{
		if (_song.characters == null || _song.characters.length == 0)
			return switch (typeIndex) {
				case 0: (_song.player2   != null) ? _song.player2   : "dad";
				case 1: (_song.player1   != null) ? _song.player1   : "bf";
				case 2: (_song.gfVersion != null) ? _song.gfVersion : "gf";
				default: "bf";
			}
		var typeName = charOptions[typeIndex];
		for (c in _song.characters)
			if (c.type == typeName) return c.name;
		return switch (typeIndex) { case 0: "dad"; case 1: "bf"; case 2: "gf"; default: "bf"; }
	}

	function loadPreviewCharacter(charName:String):Void
	{
		// Destruir anterior de forma segura
		destroyPreviewChar();

		try
		{
			var isPlayer = (selectedCharType == 1);
			previewChar = new Character(0, 0, charName, isPlayer);

			// Asignar cámara y scroll ANTES de add()
			previewChar.cameras     = [camPreview];
			previewChar.scrollFactor.set(1, 1);

			// add() al FlxGroup PROPIO — no a parent
			// Esto evita el crash en FlxDrawQuadsItem porque este group
			// controla el render del personaje de forma aislada
			add(previewChar);

			// Crear controller con el personaje en el slot correcto según su tipo:
			// - Opponent (0) → dad
			// - Player (1)   → boyfriend
			// - Girlfriend (2) → gf
			// Esto hace que CharacterController.sing() use la lógica correcta
			if (selectedCharType == 1) // Player/BF
				charController = new CharacterController(previewChar, null, null);
			else if (selectedCharType == 2) // Girlfriend
				charController = new CharacterController(null, null, previewChar);
			else // Opponent/Dad (default)
				charController = new CharacterController(null, previewChar, null);

			// Idle inicial para obtener dimensiones reales (protegido)
			try { previewChar.dance(); } catch (e:Dynamic) { trace('[PreviewPanel] dance() falló: $e'); }

			// Calcular escala usando hitbox (no frameWidth que incluye espacio vacío)
			previewChar.scale.set(1, 1);
			previewChar.updateHitbox();

			var hw = previewChar.width  > 0 ? previewChar.width  : 150.0;
			var hh = previewChar.height > 0 ? previewChar.height : 250.0;

			var ratioH = (CAM_H * 0.9)  / hh;
			var ratioW = (CAM_W * 0.95) / hw;
			var ratio  = Math.min(ratioH, ratioW) * debugScale;

			previewChar.scale.set(ratio, ratio);
			previewChar.updateHitbox();

			applyCharPosition();

			trace('[PreviewPanel] "$charName" ratio=${Math.round(ratio*100)/100} size=${Math.round(previewChar.width)}x${Math.round(previewChar.height)} offset=(${previewChar.offset.x},${previewChar.offset.y})');
		}
		catch (e:Dynamic)
		{
			trace('[PreviewPanel] ERROR "$charName": $e');
			if (previewChar != null)
			{
				remove(previewChar, true);
				previewChar.destroy();
				previewChar = null;
			}
			parent.showMessage('❌ No se pudo cargar: $charName', 0xFFFF3366);
		}
	}

	function applyCharPosition():Void
	{
		if (previewChar == null) return;
		// targetX/Y = posición visual deseada (dentro de camPreview 0..CAM_W, 0..CAM_H)
		// x = targetX + offset.x  porque FNF renderiza en (x - offset.x, y - offset.y)
		var targetX = CAM_W / 2 - previewChar.width  / 2 - 160 + debugOffsetX;
		var targetY = CAM_H     - previewChar.height  - 5 - 290 + debugOffsetY;
		previewChar.x = targetX + previewChar.offset.x;
		previewChar.y = targetY + previewChar.offset.y;
	}

	function destroyPreviewChar():Void
	{
		if (charController != null) { charController.destroy(); charController = null; }

		if (previewChar != null)
		{
			previewChar.exists  = false;
			previewChar.visible = false;
			previewChar.cameras = [];
			remove(previewChar, true);
			previewChar.destroy();
			previewChar = null;
		}
	}

	// ─────────────────────────────────────────────────────
	// NOTA HIT
	// ─────────────────────────────────────────────────────

	public function onNotePass(direction:Int, dataGroupIndex:Int):Void
	{
		if (!isPreviewActive || previewChar == null || charController == null) return;
		if (dataGroupIndex != selectedGroupIndex) return;

		// CharacterController.sing() maneja nombre de anim, fallback y holdTimer
		charController.sing(previewChar, direction % 4);
		applyCharPosition();
	}

	// ─────────────────────────────────────────────────────
	// TOGGLE
	// ─────────────────────────────────────────────────────

	public function toggle():Void
	{
		isExpanded = !isExpanded;

		// ── Animación de slide horizontal ────────────────────────────────
		// El panel desliza hacia la izquierda (ocultar) o desde la izquierda (mostrar).
		// El botón toggle siempre permanece visible en el borde.
		final slideTarget:Float = isExpanded ? PANEL_X : -PANEL_W;
		final slideDur:Float   = 0.28;
		final slideEase        = isExpanded ? FlxEase.backOut : FlxEase.quintIn;

		// Recolectar todos los sprites del panel para moverlos juntos
		var panelMembers:Array<FlxSprite> = [];
		forEach(function(m:flixel.FlxBasic)
		{
			// El botón toggle y su texto NO participan en el slide
			if (m == toggleBtn || m == toggleBtnText) return;
			if (Std.isOfType(m, FlxSprite))
				panelMembers.push(cast m);
		});

		// Antes del slide: asegurarse de que todos estén visibles para la animación
		if (isExpanded)
		{
			// Activar los elementos ANTES de animar para que sean visibles
			panelBg.visible = true; rightBorder.visible = true;
			titleText.visible = true; charLabel.visible = true;
			activateLabel.visible = true;
			activateCheck.visible = true; activateCheck.active = true;
			gridSelectorBg.visible = true; gridSelectorLabel.visible = true;
			gridPrevBtn.visible = true; gridNextBtn.visible = true;
			gridPrevTxt.visible = true; gridNextTxt.visible = true;
			gridValueTxt.visible = true; debugInfoTxt.visible = true;
			adjXMinusBtn.visible = true; adjXPlusBtn.visible = true;
			adjYMinusBtn.visible = true; adjYPlusBtn.visible = true;
			adjSMinusBtn.visible = true; adjSPlusBtn.visible = true;
			if (adjXLabel  != null) adjXLabel.visible  = true;
			if (adjYLabel  != null) adjYLabel.visible  = true;
			if (adjSLabel  != null) adjSLabel.visible  = true;
			if (adjXValTxt != null) adjXValTxt.visible = true;
			if (adjYValTxt != null) adjYValTxt.visible = true;
			if (adjSValTxt != null) adjSValTxt.visible = true;
			for (t in adjBtnTexts)  t.visible = true;
			for (bg  in optionBgs)   bg.visible  = true;
			for (txt in optionTexts) txt.visible = true;
			camPreview.visible = isPreviewActive;
			camBorder.visible  = isPreviewActive;
		}

		// Deslizar todos los miembros del panel
		for (spr in panelMembers)
		{
			final offsetFromPanel = spr.x - (isExpanded ? -PANEL_W : PANEL_X);
			FlxTween.cancelTweensOf(spr);
			FlxTween.tween(spr, {x: slideTarget + offsetFromPanel}, slideDur, {
				ease: slideEase,
				onComplete: !isExpanded ? function(_)
				{
					// Ocultar DESPUÉS del slide de salida
					panelBg.visible           = false;
					rightBorder.visible       = false;
					titleText.visible         = false;
					charLabel.visible         = false;
					activateLabel.visible     = false;
					activateCheck.visible     = false;
					activateCheck.active      = false;
					gridSelectorBg.visible    = false;
					gridSelectorLabel.visible = false;
					gridPrevBtn.visible       = false;
					gridNextBtn.visible       = false;
					gridPrevTxt.visible       = false;
					gridNextTxt.visible       = false;
					gridValueTxt.visible      = false;
					debugInfoTxt.visible      = false;
					adjXMinusBtn.visible      = false;
					adjXPlusBtn.visible       = false;
					adjYMinusBtn.visible      = false;
					adjYPlusBtn.visible       = false;
					adjSMinusBtn.visible      = false;
					adjSPlusBtn.visible       = false;
					if (adjXLabel  != null) adjXLabel.visible  = false;
					if (adjYLabel  != null) adjYLabel.visible  = false;
					if (adjSLabel  != null) adjSLabel.visible  = false;
					if (adjXValTxt != null) adjXValTxt.visible = false;
					if (adjYValTxt != null) adjYValTxt.visible = false;
					if (adjSValTxt != null) adjSValTxt.visible = false;
					for (t in adjBtnTexts)  t.visible          = false;
					for (bg  in optionBgs)   bg.visible  = false;
					for (txt in optionTexts) txt.visible = false;
					camPreview.visible = false;
					camBorder.visible  = false;
				} : null
			});
		}

		// Botón toggle: siempre visible, desliza al borde correcto
		final btnTarget:Float = isExpanded ? PANEL_X + PANEL_W : 0;
		FlxTween.cancelTweensOf(toggleBtn);
		FlxTween.cancelTweensOf(toggleBtnText);
		FlxTween.tween(toggleBtn,     {x: btnTarget}, slideDur, {ease: slideEase});
		FlxTween.tween(toggleBtnText, {x: btnTarget}, slideDur, {ease: slideEase});
		toggleBtnText.text = isExpanded ? "<" : ">";
	}

	// ─────────────────────────────────────────────────────
	// UPDATE
	// ─────────────────────────────────────────────────────

	override public function update(elapsed:Float):Void
	{
		// Procesar carga diferida ANTES de super.update() para que el personaje
		// anterior ya no esté en la lista de iteración cuando se destruye
		if (_pendingCharName != null)
		{
			var name = _pendingCharName;
			_pendingCharName = null;
			loadPreviewCharacter(name);
		}

		if (camPreview != null)
			camPreview.scroll.set(0, 0);

		super.update(elapsed);

		if (previewChar != null && isPreviewActive)
		{
			// NO llamar charController.update() aquí — previewChar ya fue actualizado
			// por super.update() (es parte del grupo), y Character.update() maneja
			// su propio holdTimer e idle. CharacterController solo se usa para sing().
			applyCharPosition();

			if (debugInfoTxt != null)
				debugInfoTxt.text = 'ox:${debugOffsetX} oy:${debugOffsetY} s:${Math.round(debugScale*100)/100}\nw:${Math.round(previewChar.width)} h:${Math.round(previewChar.height)}\noff:(${Math.round(previewChar.offset.x)},${Math.round(previewChar.offset.y)})';
		}

		if (FlxG.mouse.justPressed && FlxG.mouse.overlaps(toggleBtn, camHUD)) { toggle(); return; }
		if (!isExpanded) return;

		// Grid selector
		if (FlxG.mouse.justPressed && FlxG.mouse.overlaps(gridPrevBtn, camHUD))
		{ selectedGroupIndex = (selectedGroupIndex - 1 + getNumGroups()) % getNumGroups(); refreshGridSelectorLabel(); return; }
		if (FlxG.mouse.justPressed && FlxG.mouse.overlaps(gridNextBtn, camHUD))
		{ selectedGroupIndex = (selectedGroupIndex + 1) % getNumGroups(); refreshGridSelectorLabel(); return; }

		// Ajuste X (+/- 5px)
		if (FlxG.mouse.justPressed && FlxG.mouse.overlaps(adjXMinusBtn, camHUD))
		{ debugOffsetX -= 5; if (adjXValTxt != null) adjXValTxt.text = '${Std.int(debugOffsetX)}'; applyCharPosition(); return; }
		if (FlxG.mouse.justPressed && FlxG.mouse.overlaps(adjXPlusBtn, camHUD))
		{ debugOffsetX += 5; if (adjXValTxt != null) adjXValTxt.text = '${Std.int(debugOffsetX)}'; applyCharPosition(); return; }

		// Ajuste Y (+/- 5px)
		if (FlxG.mouse.justPressed && FlxG.mouse.overlaps(adjYMinusBtn, camHUD))
		{ debugOffsetY -= 5; if (adjYValTxt != null) adjYValTxt.text = '${Std.int(debugOffsetY)}'; applyCharPosition(); return; }
		if (FlxG.mouse.justPressed && FlxG.mouse.overlaps(adjYPlusBtn, camHUD))
		{ debugOffsetY += 5; if (adjYValTxt != null) adjYValTxt.text = '${Std.int(debugOffsetY)}'; applyCharPosition(); return; }

		// Ajuste escala (+/- 5%)
		if (FlxG.mouse.justPressed && FlxG.mouse.overlaps(adjSMinusBtn, camHUD))
		{
			debugScale = Math.max(0.1, debugScale - 0.05);
			if (adjSValTxt != null) adjSValTxt.text = '${Math.round(debugScale * 100) / 100}';
			if (isPreviewActive) _pendingCharName = getCharNameForType(selectedCharType);
			return;
		}
		if (FlxG.mouse.justPressed && FlxG.mouse.overlaps(adjSPlusBtn, camHUD))
		{
			debugScale += 0.05;
			if (adjSValTxt != null) adjSValTxt.text = '${Math.round(debugScale * 100) / 100}';
			if (isPreviewActive) _pendingCharName = getCharNameForType(selectedCharType);
			return;
		}

		// Click en opción de personaje
		for (i in 0...charOptions.length)
		{
			if (optionBgs[i] != null && FlxG.mouse.justPressed && FlxG.mouse.overlaps(optionBgs[i], camHUD))
			{
				selectedCharType = i;
				updateOptionColors();
				autoSelectGroupForType(i);
				if (isPreviewActive)
					_pendingCharName = getCharNameForType(i);
				break;
			}
		}
	}

	function autoSelectGroupForType(typeIndex:Int):Void
	{
		if (_song.strumsGroups == null || _song.strumsGroups.length == 0)
		{ selectedGroupIndex = (typeIndex == 1) ? 1 : 0; refreshGridSelectorLabel(); return; }
		if (_song.characters != null)
		{
			var typeName = charOptions[typeIndex];
			for (c in _song.characters)
			{
				if (c.type != typeName || c.strumsGroup == null) continue;
				for (gi in 0..._song.strumsGroups.length)
					if (_song.strumsGroups[gi].id == c.strumsGroup)
					{ selectedGroupIndex = gi; refreshGridSelectorLabel(); return; }
			}
		}
		for (gi in 0..._song.strumsGroups.length)
		{
			var cpu = _song.strumsGroups[gi].cpu;
			if (typeIndex == 0 && cpu)  { selectedGroupIndex = gi; break; }
			if (typeIndex == 1 && !cpu) { selectedGroupIndex = gi; break; }
		}
		refreshGridSelectorLabel();
	}

	// ─────────────────────────────────────────────────────
	// HELPERS
	// ─────────────────────────────────────────────────────

	function updateOptionColors():Void
	{
		for (i in 0...charOptions.length)
		{
			if (optionBgs[i]   != null) optionBgs[i].color   = (i == selectedCharType) ? 0xFF0D1A2A : 0xFF0D0D1F;
			if (optionTexts[i] != null) optionTexts[i].color = (i == selectedCharType) ? TYPE_COLORS[i] : TEXT_GRAY;
		}
	}

	public function getCurrentPreviewType():String { return charOptions[selectedCharType]; }

	override public function destroy():Void
	{
		destroyPreviewChar();
		if (camPreview != null) { FlxG.cameras.remove(camPreview); camPreview = null; }
		super.destroy();
	}
}
