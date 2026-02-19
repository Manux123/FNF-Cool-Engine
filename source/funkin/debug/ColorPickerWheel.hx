package funkin.debug;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.ui.FlxButton;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import openfl.display.BitmapData;

using StringTools;

/**
 * ColorPickerWheel — SubState flotante con rueda de color HSB.
 *
 * Uso:
 *   var picker = new ColorPickerWheel(currentColor);
 *   picker.onColorSelected = function(c) { doSomethingWith(c); };
 *   openSubState(picker);
 */
class ColorPickerWheel extends FlxSubState
{
	/** Callback que se dispara al confirmar o cancelar. **/
	public var onColorSelected:FlxColor->Void;

	// ── Constantes de layout ──────────────────────────────────────────────────
	static inline var WHEEL_SIZE:Int  = 210;
	static inline var PANEL_W:Int     = 310;
	static inline var PANEL_H:Int     = 460;
	static inline var ACCENT:Int      = 0xFF00E5FF;
	static inline var BG_DARK:Int     = 0xFF0B0B16;
	static inline var BG_MID:Int      = 0xFF141428;

	// ── Sprites ───────────────────────────────────────────────────────────────
	var wheelSprite:FlxSprite;
	var selectorRing:FlxSprite;
	var briSliderBg:FlxSprite;
	var briHandle:FlxSprite;
	var colorSwatch:FlxSprite;
	var healthBarPreview:FlxSprite;
	var hexText:FlxText;
	var panel:FlxSprite;

	// ── Estado HSB ────────────────────────────────────────────────────────────
	var hue:Float        = 200;
	var sat:Float        = 0.7;
	var bri:Float        = 0.9;

	var isDraggingWheel:Bool = false;
	var isDraggingBri:Bool   = false;

	var initialColor:FlxColor;

	// ── Geometría ─────────────────────────────────────────────────────────────
	var panelX:Float;
	var panelY:Float;
	var wheelCX:Float;
	var wheelCY:Float;
	var outerR:Float;
	var innerR:Float;
	var sliderX:Float;
	var sliderY:Float;
	var sliderW:Float;

	public function new(initialColor:FlxColor)
	{
		super(0xAA000000);
		this.initialColor = initialColor;
		hue = initialColor.hue;
		sat = initialColor.saturation;
		bri = initialColor.brightness;
	}

	// ── create ────────────────────────────────────────────────────────────────

	override function create()
	{
		super.create();

		panelX = Math.round((FlxG.width  - PANEL_W) / 2);
		panelY = Math.round((FlxG.height - PANEL_H) / 2);

		// ── Panel de fondo ────────────────────────────────────────────────────
		panel = new FlxSprite(panelX, panelY);
		panel.makeGraphic(PANEL_W, PANEL_H, BG_DARK);
		panel.scrollFactor.set();
		add(panel);

		// Borde izquierdo accent (4px)
		var leftBorder = new FlxSprite(panelX, panelY);
		leftBorder.makeGraphic(3, PANEL_H, ACCENT);
		leftBorder.scrollFactor.set();
		add(leftBorder);

		// Borde superior accent
		var topBorder = new FlxSprite(panelX, panelY);
		topBorder.makeGraphic(PANEL_W, 3, ACCENT);
		topBorder.scrollFactor.set();
		add(topBorder);

		// Título
		var title = new FlxText(panelX, panelY + 8, PANEL_W, "HEALTH BAR COLOR", 14);
		title.alignment = CENTER;
		title.color = ACCENT;
		title.setBorderStyle(FlxTextBorderStyle.OUTLINE, BG_DARK, 1);
		title.scrollFactor.set();
		add(title);

		// Separador bajo el título
		var sep = new FlxSprite(panelX + 10, panelY + 28);
		sep.makeGraphic(PANEL_W - 20, 1, 0x33FFFFFF);
		sep.scrollFactor.set();
		add(sep);

		// ── Rueda de color ────────────────────────────────────────────────────
		var wheelOffY = 38;
		wheelCX = panelX + PANEL_W / 2;
		wheelCY = panelY + wheelOffY + WHEEL_SIZE / 2;
		outerR  = WHEEL_SIZE / 2 - 2;
		innerR  = outerR * 0.22; // anillo — el centro queda vacío (BG)

		wheelSprite = new FlxSprite(panelX + (PANEL_W - WHEEL_SIZE) / 2, panelY + wheelOffY);
		wheelSprite.scrollFactor.set();
		add(wheelSprite);

		// Centro del anillo (fondo oscuro para que el hueco se vea limpio)
		var centerFill = new FlxSprite(wheelCX - innerR, wheelCY - innerR);
		centerFill.makeGraphic(Std.int(innerR * 2), Std.int(innerR * 2), BG_DARK);
		centerFill.scrollFactor.set();
		add(centerFill);

		// Punto selector (anillo blanco + negro por dentro)
		selectorRing = new FlxSprite(0, 0);
		selectorRing.makeGraphic(16, 16, FlxColor.TRANSPARENT);
		drawSelectorDot(selectorRing);
		selectorRing.scrollFactor.set();
		add(selectorRing);

		// ── Slider de brillo ──────────────────────────────────────────────────
		sliderX = panelX + 14;
		sliderY = panelY + wheelOffY + WHEEL_SIZE + 14;
		sliderW = PANEL_W - 28;

		var sliderLabel = new FlxText(Std.int(sliderX), Std.int(sliderY - 14), 100, "Brightness", 10);
		sliderLabel.color = 0xFF8899BB;
		sliderLabel.scrollFactor.set();
		add(sliderLabel);

		// Track del slider (se rellena con gradiente)
		briSliderBg = new FlxSprite(sliderX, sliderY);
		briSliderBg.scrollFactor.set();
		add(briSliderBg);

		// Handle del slider
		briHandle = new FlxSprite(0, sliderY - 3);
		briHandle.makeGraphic(10, 22, FlxColor.WHITE);
		briHandle.scrollFactor.set();
		add(briHandle);

		// ── Sección de preview ────────────────────────────────────────────────
		var previewY = sliderY + 34;

		var previewLabel = new FlxText(Std.int(sliderX), Std.int(previewY - 14), 120, "Preview:", 10);
		previewLabel.color = 0xFF8899BB;
		previewLabel.scrollFactor.set();
		add(previewLabel);

		// HealthBar tintada con el color actual
		healthBarPreview = new FlxSprite(sliderX, previewY);
		healthBarPreview.loadGraphic(Paths.image("UI/healthBar"));
		healthBarPreview.setGraphicSize(Std.int(sliderW), 24);
		healthBarPreview.updateHitbox();
		healthBarPreview.scrollFactor.set();
		add(healthBarPreview);

		// Swatch de color cuadrado
		colorSwatch = new FlxSprite(sliderX, previewY + 32);
		colorSwatch.makeGraphic(36, 36, FlxColor.WHITE);
		colorSwatch.scrollFactor.set();
		add(colorSwatch);

		// Valor hex
		hexText = new FlxText(Std.int(sliderX + 44), Std.int(previewY + 42), 220, "#FFFFFF", 14);
		hexText.color = FlxColor.WHITE;
		hexText.setBorderStyle(FlxTextBorderStyle.OUTLINE, BG_DARK, 1);
		hexText.scrollFactor.set();
		add(hexText);

		// ── Botones ───────────────────────────────────────────────────────────
		var btnY = panelY + PANEL_H - 44;

		var confirmBtn = new FlxButton(panelX + 14, btnY, "✓  Confirm", function()
		{
			if (onColorSelected != null)
				onColorSelected(getCurrentColor());
			close();
		});
		styleButton(confirmBtn, ACCENT, BG_DARK);
		add(confirmBtn);

		var cancelBtn = new FlxButton(panelX + PANEL_W - 114, btnY, "✗  Cancel", function()
		{
			if (onColorSelected != null)
				onColorSelected(initialColor);
			close();
		});
		styleButton(cancelBtn, 0xFFFF4466, BG_DARK);
		add(cancelBtn);

		// ── Generar gráficos iniciales ────────────────────────────────────────
		rebuildWheelBitmap();
		updateBrightnessSlider();
		updateSelectorPosition();
		updatePreviews();

		// ── Animación de entrada ──────────────────────────────────────────────
		panel.y = panelY - 30;
		panel.alpha = 0;
		FlxTween.tween(panel, {y: panelY, alpha: 1}, 0.3, {ease: FlxEase.backOut});
	}

	// ── Generación de bitmaps ─────────────────────────────────────────────────

	/**
	 * Genera la rueda HSB completa.
	 * Angulo = Hue (0-360), Radio = Saturación (0=centro, 1=borde), Brillo = currentBri.
	 * Solo se regenera cuando cambia el brillo.
	 */
	function rebuildWheelBitmap():Void
	{
		var bd = new BitmapData(WHEEL_SIZE, WHEEL_SIZE, true, 0);
		var cx = WHEEL_SIZE / 2.0;
		var cy = WHEEL_SIZE / 2.0;
		bd.lock();
		for (py in 0...WHEEL_SIZE)
		{
			for (px in 0...WHEEL_SIZE)
			{
				var dx   = px - cx;
				var dy   = py - cy;
				var dist = Math.sqrt(dx * dx + dy * dy);
				if (dist <= outerR && dist >= innerR)
				{
					var angle = Math.atan2(dy, dx) * (180 / Math.PI);
					if (angle < 0) angle += 360;
					var s = (dist - innerR) / (outerR - innerR);
					var col:FlxColor = FlxColor.fromHSB(angle, s, bri);
					// Anti-alias suave en el borde exterior
					var edgeFade = Math.min(1.0, (outerR - dist) / 1.5);
					var edgeAlpha = Std.int(edgeFade * 255);
					bd.setPixel32(px, py, (col : Int) & 0x00FFFFFF | (edgeAlpha << 24));
				}
			}
		}
		bd.unlock();
		wheelSprite.pixels = bd;
		wheelSprite.dirty   = true;
	}

	/**
	 * Reconstruye el gradiente del track del slider de brillo.
	 * Va de negro (izquierda) al color puro (derecha) para el hue/sat actual.
	 */
	function updateBrightnessSlider():Void
	{
		var w = Std.int(sliderW);
		var h = 16;
		var bd = new BitmapData(w, h, false, 0xFF000000);
		bd.lock();
		for (px in 0...w)
		{
			var b = px / w;
			var col:FlxColor = FlxColor.fromHSB(hue, sat, b);
			for (py in 0...h)
				bd.setPixel(px, py, (col : Int) & 0x00FFFFFF);
		}
		bd.unlock();
		briSliderBg.pixels = bd;
		briSliderBg.dirty   = true;

		// Mover handle
		briHandle.x = sliderX + bri * (sliderW - 10);
	}

	function updateSelectorPosition():Void
	{
		var r = innerR + sat * (outerR - innerR);
		var a = hue * Math.PI / 180;
		selectorRing.x = wheelCX + Math.cos(a) * r - 8;
		selectorRing.y = wheelCY + Math.sin(a) * r - 8;
	}

	function updatePreviews():Void
	{
		var col = getCurrentColor();
		healthBarPreview.color = col;
		colorSwatch.color      = col;
		var hex = "#" + col.toHexString(false, false).toUpperCase();
		if (hexText != null) hexText.text = hex;
	}

	// ── Helpers ───────────────────────────────────────────────────────────────

	inline function getCurrentColor():FlxColor
		return FlxColor.fromHSB(hue, sat, bri);

	function drawSelectorDot(s:FlxSprite):Void
	{
		var bd = new BitmapData(16, 16, true, 0);
		bd.lock();
		for (py in 0...16)
		{
			for (px in 0...16)
			{
				var dx   = px - 8;
				var dy   = py - 8;
				var dist = Math.sqrt(dx * dx + dy * dy);
				if (dist <= 7.5 && dist >= 5.5)
					bd.setPixel32(px, py, 0xFFFFFFFF);
				else if (dist < 5.5 && dist >= 4.0)
					bd.setPixel32(px, py, 0xFF000000);
			}
		}
		bd.unlock();
		s.pixels = bd;
		s.dirty   = true;
	}

	function styleButton(btn:FlxButton, textColor:Int, bgColor:Int):Void
	{
		btn.color     = bgColor;
		btn.label.color = textColor;
	}

	// ── Update ────────────────────────────────────────────────────────────────

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		var mx = FlxG.mouse.x;
		var my = FlxG.mouse.y;

		// ── Inicio de drag ────────────────────────────────────────────────────
		if (FlxG.mouse.justPressed)
		{
			// ¿Dentro de la rueda?
			var dx   = mx - wheelCX;
			var dy   = my - wheelCY;
			var dist = Math.sqrt(dx * dx + dy * dy);
			if (dist <= outerR)
				isDraggingWheel = true;

			// ¿Sobre el slider de brillo?
			if (mx >= sliderX && mx <= sliderX + sliderW
				&& my >= sliderY - 4 && my <= sliderY + 20)
				isDraggingBri = true;
		}

		if (FlxG.mouse.justReleased)
		{
			isDraggingWheel = false;
			isDraggingBri   = false;
		}

		var dirty = false;

		// ── Arrastrar en la rueda ─────────────────────────────────────────────
		if (isDraggingWheel && FlxG.mouse.pressed)
		{
			var dx   = mx - wheelCX;
			var dy   = my - wheelCY;
			var dist = Math.sqrt(dx * dx + dy * dy);

			var newHue = Math.atan2(dy, dx) * (180 / Math.PI);
			if (newHue < 0) newHue += 360;
			hue = newHue;

			// Saturación: clampar al anillo
			var rawSat = (Math.min(dist, outerR) - innerR) / (outerR - innerR);
			sat   = Math.max(0.0, Math.min(1.0, rawSat));
			dirty = true;
		}

		// ── Arrastrar el slider de brillo ─────────────────────────────────────
		if (isDraggingBri && FlxG.mouse.pressed)
		{
			bri   = Math.max(0.0, Math.min(1.0, (mx - sliderX) / sliderW));
			rebuildWheelBitmap(); // reconstruir solo cuando cambia el brillo
			dirty = true;
		}

		if (dirty)
		{
			updateBrightnessSlider();
			updateSelectorPosition();
			updatePreviews();
		}

		// ESC = cancelar
		if (FlxG.keys.justPressed.ESCAPE)
		{
			if (onColorSelected != null)
				onColorSelected(initialColor);
			close();
		}
	}
}
