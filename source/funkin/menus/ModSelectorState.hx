package funkin.menus;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.math.FlxMath;
import openfl.display.BitmapData as Bitmap;
import mods.ModManager;
import funkin.transitions.StateTransition;
import funkin.states.MusicBeatState;

#if sys
import sys.FileSystem;
#end

using StringTools;

/**
 * ModSelectorState — pantalla de selección de mods.
 *
 * ─── Features ────────────────────────────────────────────────────────────────
 *  • Lista de todos los mods instalados, ordenada por prioridad.
 *  • Preview de vídeo (preview.mp4) si existe.
 *  • Preview de imagen (preview.png / .jpg) como fallback.
 *  • Sin preview: fondo negro con gradiente de color del mod.
 *  • Activar/desactivar mods (Enter = activar, X/Backspace = toggle enable).
 *  • Icono del mod (icon.png) si existe.
 *  • Metadata: nombre, autor, versión, descripción.
 *  • Indicador del mod activo.
 *
 * ─── Controles ───────────────────────────────────────────────────────────────
 *  UP / DOWN     — navegar lista
 *  ENTER         — activar el mod seleccionado (o desactivar si ya está activo)
 *  X / BACKSPACE — habilitar/deshabilitar mod en la lista
 *  ESCAPE        — volver al menú principal
 */
class ModSelectorState extends MusicBeatState
{
	// ─── Layout ───────────────────────────────────────────────────────────────
	public static inline var LIST_W       = 380;  // ancho del panel izquierdo
	public static inline var LIST_ITEM_H  = 68;   // altura de cada ítem
	static inline var PREVIEW_X    = LIST_W + 20;
	static inline var PREVIEW_W    = 860;  // ancho del área de preview
	static inline var PREVIEW_H    = 480;

	// ─── Datos ────────────────────────────────────────────────────────────────
	var _mods:Array<mods.ModInfo> = [];
	var _cur:Int = 0;
	var _prevCur:Int = -1;

	// ─── UI ───────────────────────────────────────────────────────────────────
	var _camBG:FlxCamera;
	var _camUI:FlxCamera;

	var _bg:FlxSprite;                        // fondo sólido
	var _panelBg:FlxSprite;                   // fondo panel lista
	var _previewBg:FlxSprite;                 // fondo área preview

	var _itemGroup:FlxTypedGroup<ModListItem>;
	var _previewImg:FlxSprite;                // preview imagen
	var _previewNone:FlxSprite;               // bloque de color cuando no hay preview

	// Info panel
	var _infoName:FlxText;
	var _infoAuthor:FlxText;
	var _infoVersion:FlxText;
	var _infoDesc:FlxText;
	var _infoActive:FlxText;
	var _infoKey:FlxText;

	// Video handle (si VLC disponible)
	#if vlc
	var _video:vlc.VlcBitmap = null;
	var _videoSprite:FlxSprite = null;
	#end

	// Tweens activos
	var _previewTween:FlxTween = null;

	// Debounce
	var _inputCooldown:Float = 0;
	static inline var INPUT_CD = 0.13;

	// ─── Creación ─────────────────────────────────────────────────────────────

	override function create()
	{
		// Cargar mods frescos
		ModManager.init();
		_mods = ModManager.installedMods.copy();

		_setupCameras();
		_buildBG();
		_buildList();
		_buildPreviewArea();
		_buildInfoPanel();
		_buildHelpBar();

		super.create();

		// Seleccionar el mod actualmente activo si existe
		if (ModManager.activeMod != null)
		{
			for (i in 0..._mods.length)
				if (_mods[i].id == ModManager.activeMod) { _cur = i; break; }
		}

		// Si no hay mods, mostrar mensaje vacío
		if (_mods.length == 0)
			_showEmptyMessage();
		else
			_selectItem(_cur, true);
	}

	function _setupCameras():Void
	{
		_camBG = new FlxCamera();
		_camBG.bgColor = 0xFF0A0A12;
		FlxG.cameras.add(_camBG, false);

		_camUI = new FlxCamera();
		_camUI.bgColor = FlxColor.TRANSPARENT;
		FlxG.cameras.add(_camUI, false);
	}

	function _buildBG():Void
	{
		_bg = new FlxSprite(0, 0);
		_bg.makeGraphic(FlxG.width, FlxG.height, 0xFF0A0A12);
		_bg.scrollFactor.set();
		_bg.cameras = [_camBG];
		add(_bg);

		// Panel lista (izquierda)
		_panelBg = new FlxSprite(0, 0);
		_panelBg.makeGraphic(LIST_W, FlxG.height, 0xFF111118);
		_panelBg.scrollFactor.set();
		_panelBg.cameras = [_camUI];
		add(_panelBg);
	}

	function _buildList():Void
	{
		_itemGroup = new FlxTypedGroup<ModListItem>();
		_itemGroup.cameras = [_camUI];
		add(_itemGroup);

		for (i in 0..._mods.length)
		{
			final mod = _mods[i];
			final item = new ModListItem(mod, i);
			item.y = 10 + i * (LIST_ITEM_H + 4);
			_itemGroup.add(item);
		}
	}

	function _buildPreviewArea():Void
	{
		// Fondo del área de preview
		_previewBg = new FlxSprite(PREVIEW_X - 10, 10);
		_previewBg.makeGraphic(Std.int(FlxG.width - PREVIEW_X + 10), PREVIEW_H + 20, 0xFF0D0D1A);
		_previewBg.scrollFactor.set();
		_previewBg.cameras = [_camUI];
		add(_previewBg);

		// Sprite de preview imagen
		_previewImg = new FlxSprite(PREVIEW_X, 20);
		_previewImg.alpha = 0;
		_previewImg.cameras = [_camUI];
		_previewImg.scrollFactor.set();
		add(_previewImg);

		// Bloque de color (placeholder sin preview)
		_previewNone = new FlxSprite(PREVIEW_X, 20);
		_previewNone.makeGraphic(PREVIEW_W, PREVIEW_H, 0xFF1A1A2E);
		_previewNone.alpha = 0;
		_previewNone.scrollFactor.set();
		_previewNone.cameras = [_camUI];
		add(_previewNone);
	}

	function _buildInfoPanel():Void
	{
		final iy = PREVIEW_H + 40;
		final ix = PREVIEW_X;

		_infoActive = new FlxText(ix, iy, PREVIEW_W, '');
		_infoActive.setFormat(null, 14, 0xFF44FF88, LEFT);
		_infoActive.scrollFactor.set();
		_infoActive.cameras = [_camUI];
		add(_infoActive);

		_infoName = new FlxText(ix, iy + 22, PREVIEW_W, '');
		_infoName.setFormat(null, 28, FlxColor.WHITE, LEFT, OUTLINE, 0xFF000000);
		_infoName.scrollFactor.set();
		_infoName.cameras = [_camUI];
		add(_infoName);

		_infoAuthor = new FlxText(ix, iy + 56, PREVIEW_W, '');
		_infoAuthor.setFormat(null, 15, 0xFFAAAAAA, LEFT);
		_infoAuthor.scrollFactor.set();
		_infoAuthor.cameras = [_camUI];
		add(_infoAuthor);

		_infoVersion = new FlxText(ix + PREVIEW_W - 120, iy + 56, 120, '');
		_infoVersion.setFormat(null, 14, 0xFF666688, RIGHT);
		_infoVersion.scrollFactor.set();
		_infoVersion.cameras = [_camUI];
		add(_infoVersion);

		_infoDesc = new FlxText(ix, iy + 80, PREVIEW_W, '');
		_infoDesc.setFormat(null, 13, 0xFFCCCCDD, LEFT);
		_infoDesc.scrollFactor.set();
		_infoDesc.wordWrap = true;
		_infoDesc.cameras = [_camUI];
		add(_infoDesc);
	}

	function _buildHelpBar():Void
	{
		_infoKey = new FlxText(20, FlxG.height - 30, FlxG.width - 20,
			'[↑↓] Browse   [Enter] Activate   [X] Enable/Disable   [Esc] Volver');
		_infoKey.setFormat(null, 13, 0xFF555566, CENTER);
		_infoKey.scrollFactor.set();
		_infoKey.cameras = [_camUI];
		add(_infoKey);

		// Título
		final title = new FlxText(0, 0, LIST_W, 'MODS');
		title.setFormat(null, 22, FlxColor.WHITE, CENTER, OUTLINE, 0xFF000000);
		title.scrollFactor.set();
		title.y = FlxG.height - 34;
		title.cameras = [_camUI];
		add(title);
	}

	function _showEmptyMessage():Void
	{
		final msg = new FlxText(LIST_W * 0.5 - 50, FlxG.height * 0.5 - 20, LIST_W,
			'There are no mods\ninstalled.\n\nInstall your mods\nin the folder\nmods/');
		msg.setFormat(null, 16, 0xFF666688, CENTER);
		msg.x -= 140;
		msg.y -= 100;
		msg.scrollFactor.set();
		msg.cameras = [_camUI];
		add(msg);
	}

	// ─── Update ───────────────────────────────────────────────────────────────

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (_inputCooldown > 0)
		{
			_inputCooldown -= elapsed;
			return;
		}

		if (_mods.length == 0)
		{
			if (FlxG.keys.justPressed.ESCAPE)
				_goBack();
			return;
		}

		if (FlxG.keys.justPressed.UP || FlxG.keys.justPressed.W)
		{
			_inputCooldown = INPUT_CD;
			_cur = (_cur - 1 + _mods.length) % _mods.length;
			_selectItem(_cur);
		}
		else if (FlxG.keys.justPressed.DOWN || FlxG.keys.justPressed.S)
		{
			_inputCooldown = INPUT_CD;
			_cur = (_cur + 1) % _mods.length;
			_selectItem(_cur);
		}
		else if (FlxG.keys.justPressed.ENTER)
		{
			_inputCooldown = 0.25;
			_activateMod();
		}
		else if (FlxG.keys.justPressed.X || FlxG.keys.justPressed.BACKSPACE)
		{
			_inputCooldown = INPUT_CD;
			_toggleEnable();
		}
		else if (FlxG.keys.justPressed.ESCAPE)
		{
			_goBack();
		}

		// Scroll suave de lista si hay muchos mods
		_scrollList(elapsed);
	}

	// Destino de scroll del camUI
	var _listScrollY:Float = 0;

	function _scrollList(elapsed:Float):Void
	{
		final visibleItems = Math.floor(FlxG.height / (LIST_ITEM_H + 4)) - 1;
		if (_mods.length <= visibleItems) return;

		final targetScroll = Math.max(0, (_cur - Math.floor(visibleItems * 0.5)) * (LIST_ITEM_H + 4));
		_listScrollY = FlxMath.lerp(_listScrollY, targetScroll, Math.min(elapsed * 10, 1.0));
		_camUI.scroll.y = _listScrollY;
	}

	// ─── Selección ────────────────────────────────────────────────────────────

	function _selectItem(idx:Int, instant:Bool = false):Void
	{
		if (idx == _prevCur && !instant) return;
		_prevCur = idx;

		// Actualizar estados visuales de la lista
		_itemGroup.forEachAlive(function(item:ModListItem)
		{
			item.setSelected(item.modIndex == idx);
		});

		final mod = _mods[idx];
		_updateInfo(mod);
		_loadPreview(mod, instant);
	}

	function _updateInfo(mod:mods.ModInfo):Void
	{
		_infoName.text    = mod.name;
		_infoAuthor.text  = mod.author.length > 0 ? 'by ' + mod.author : '';
		_infoVersion.text = 'v' + mod.version;
		_infoDesc.text    = mod.description;

		final isActive = ModManager.activeMod == mod.id;
		_infoActive.text = isActive ? '✓ ACTIVE MOD' : (!mod.enabled ? '✗ DESACTIVATED' : '');
		_infoActive.color = isActive ? 0xFF44FF88 : 0xFFFF4455;
	}

	function _loadPreview(mod:mods.ModInfo, instant:Bool = false):Void
	{
		// Cancelar tween anterior
		if (_previewTween != null) { _previewTween.cancel(); _previewTween = null; }

		// Detener vídeo anterior
		#if vlc
		_stopVideo();
		#end

		final previewType = ModManager.previewType(mod.id);

		switch (previewType)
		{
			case VIDEO:
				_previewImg.alpha = 0;
				// Mostrar placeholder de color mientras carga vídeo
				_previewNone.makeGraphic(PREVIEW_W, PREVIEW_H, mod.color | 0xFF000000);
				_previewNone.alpha = 1;
				#if vlc
				_playVideo(ModManager.previewVideo(mod.id));
				#end

			case IMAGE:
				_previewNone.alpha = 0;
				#if vlc
				_stopVideo();
				#end
				_loadPreviewImage(mod, instant);

			case NONE:
				_previewImg.alpha = 0;
				#if vlc
				_stopVideo();
				#end
				// Gradiente de color del mod como fondo
				_previewNone.makeGraphic(PREVIEW_W, PREVIEW_H, mod.color | 0xFF000000);
				if (instant)
					_previewNone.alpha = 1;
				else
				{
					_previewNone.alpha = 0;
					_previewTween = FlxTween.tween(_previewNone, {alpha: 1}, 0.3, {ease: FlxEase.quadOut});
				}
		}
	}

	function _loadPreviewImage(mod:mods.ModInfo, instant:Bool):Void
	{
		final imgPath = ModManager.previewImage(mod.id);
		if (imgPath == null)
		{
			_previewImg.alpha = 0;
			return;
		}

		try
		{
			final bmp = Bitmap.fromFile(imgPath);
			if (bmp == null) { _previewImg.alpha = 0; return; }

			// Escalar al área de preview manteniendo ratio
			final scaleX = PREVIEW_W / bmp.width;
			final scaleY = PREVIEW_H / bmp.height;
			final scale  = Math.min(scaleX, scaleY);

			_previewImg.loadGraphic(bmp);
			_previewImg.setGraphicSize(Std.int(bmp.width * scale), Std.int(bmp.height * scale));
			_previewImg.updateHitbox();
			// Centrar en el área de preview
			_previewImg.x = PREVIEW_X + (PREVIEW_W - _previewImg.width) * 0.5;
			_previewImg.y = 20 + (PREVIEW_H - _previewImg.height) * 0.5;
			_previewImg.antialiasing = true;

			if (instant)
				_previewImg.alpha = 1;
			else
			{
				_previewImg.alpha = 0;
				_previewTween = FlxTween.tween(_previewImg, {alpha: 1}, 0.35, {ease: FlxEase.quadOut});
			}
		}
		catch (e:Dynamic)
		{
			trace('[ModSelectorState] Error cargando preview "$imgPath": $e');
			_previewImg.alpha = 0;
		}
	}

	// ─── Vídeo (VLC) ─────────────────────────────────────────────────────────

	#if vlc
	function _playVideo(path:Null<String>):Void
	{
		if (path == null) return;
		_stopVideo();
		try
		{
			_video = new vlc.VlcBitmap();
			_video.onReady = function() {
				if (_videoSprite == null)
				{
					_videoSprite = new FlxSprite(PREVIEW_X, 20);
					_videoSprite.cameras = [_camUI];
					_videoSprite.scrollFactor.set();
					add(_videoSprite);
				}
				_videoSprite.loadGraphic(_video.bitmapData);
				_videoSprite.setGraphicSize(PREVIEW_W, PREVIEW_H);
				_videoSprite.updateHitbox();
				FlxTween.tween(_videoSprite, {alpha: 1}, 0.3, {ease: FlxEase.quadOut});
			};
			_video.play(path, true, true); // loop, muted
		}
		catch (e:Dynamic) { trace('[ModSelectorState] VLC error: $e'); }
	}

	function _stopVideo():Void
	{
		if (_video != null)
		{
			try { _video.stop(); } catch(_) {}
			_video = null;
		}
		if (_videoSprite != null)
		{
			_videoSprite.alpha = 0;
		}
	}
	#end

	// ─── Acciones ─────────────────────────────────────────────────────────────

	function _activateMod():Void
	{
		if (_mods.length == 0) return;
		final mod = _mods[_cur];

		final alreadyActive = ModManager.activeMod == mod.id;

		if (alreadyActive)
		{
			// Ya activo → desactivar y reiniciar en modo base
			ModManager.deactivate();
			trace('[ModSelector] Mod desactivado, reiniciando en modo base...');
		}
		else
		{
			ModManager.setActive(mod.id);
			trace('[ModSelector] Mod activado: ${mod.id}, reiniciando...');
		}

		_restartGame();
	}

	/**
	 * Limpia todos los caches y reinicia el juego desde CacheState → TitleState.
	 * Es necesario para que el mod (o su desactivación) tome efecto en todos
	 * los assets, scripts y configuración cargados al inicio.
	 */
	function _restartGame():Void
	{
		#if vlc
		_stopVideo();
		#end

		// Detener música si hay
		if (FlxG.sound.music != null)
			FlxG.sound.music.stop();

		// Limpiar caches de assets
		Paths.forceClearCache();
		#if cpp cpp.vm.Gc.run(true); #end
		#if hl  hl.Gc.major();       #end

		// Fade a negro y luego resetear
		FlxG.camera.fade(flixel.util.FlxColor.BLACK, 0.5, false, function()
		{
			// FlxG.resetGame() reinicia el juego desde el initialState (CacheState)
			// sin tener que recrear la ventana — limpia states, tweens, timers, etc.
			FlxG.resetGame();
		});
	}

	function _toggleEnable():Void
	{
		if (_mods.length == 0) return;
		final mod = _mods[_cur];
		final newEnabled = ModManager.toggleEnabled(mod.id);
		trace('[ModSelector] Mod ${mod.id} enabled=$newEnabled');
		_updateInfo(mod);
		_itemGroup.forEachAlive(function(item:ModListItem) item.refresh());
	}

	function _goBack():Void
	{
		#if vlc
		_stopVideo();
		#end
		StateTransition.switchState(new MainMenuState());
	}

	// ─── Destroy ──────────────────────────────────────────────────────────────

	override function destroy()
	{
		#if vlc
		_stopVideo();
		#end
		super.destroy();
	}
}

// ═════════════════════════════════════════════════════════════════════════════
//  ModListItem — un ítem de la lista de mods
// ═════════════════════════════════════════════════════════════════════════════

class ModListItem extends FlxSprite
{
	public var modIndex:Int;

	var _mod:mods.ModInfo;
	var _bg:FlxSprite;
	var _icon:FlxSprite;
	var _nameText:FlxText;
	var _authorText:FlxText;
	var _activeBadge:FlxSprite;
	var _enabledDot:FlxSprite;

	static inline var W = ModSelectorState.LIST_W - 16;
	static inline var H = ModSelectorState.LIST_ITEM_H;

	public function new(mod:mods.ModInfo, index:Int)
	{
		super(8, 0);
		_mod = mod;
		modIndex = index;

		// Fondo del ítem
		_bg = new FlxSprite(0, 0);
		_bg.scrollFactor.set();

		// Nombre
		_nameText = new FlxText(10, 10, W - 20, mod.name);
		_nameText.setFormat(null, 16, FlxColor.WHITE, LEFT, OUTLINE, 0xFF000000);
		_nameText.scrollFactor.set();

		// Autor
		_authorText = new FlxText(10, 32, W - 20, mod.author.length > 0 ? 'By ' + mod.author : '');
		_authorText.setFormat(null, 11, 0xFF888899, LEFT);
		_authorText.scrollFactor.set();

		// Dot de estado enabled
		_enabledDot = new FlxSprite(W - 14, H * 0.5 - 6);
		_enabledDot.makeGraphic(12, 12, FlxColor.TRANSPARENT);
		_enabledDot.scrollFactor.set();

		// Badge "ACTIVO"
		_activeBadge = new FlxSprite(W - 80, 6);
		_activeBadge.makeGraphic(72, 20, FlxColor.TRANSPARENT);
		_activeBadge.scrollFactor.set();

		_refresh(false);
	}

	public function setSelected(selected:Bool):Void
	{
		FlxTween.cancelTweensOf(this);
		final targetAlpha = selected ? 1.0 : (ModManager.activeMod == _mod.id ? 0.85 : 0.55);
		FlxTween.tween(this, {alpha: targetAlpha}, 0.15, {ease: FlxEase.quadOut});

		_bg.makeGraphic(W, H, selected ? (_mod.color | 0xCC000000) : 0xFF111118);
	}

	public function refresh():Void _refresh(true);

	function _refresh(animate:Bool):Void
	{
		final isActive  = ModManager.activeMod == _mod.id;
		final isEnabled = ModManager.isEnabled(_mod.id);

		_nameText.color  = isEnabled ? FlxColor.WHITE : 0xFF555566;
		_authorText.color = isEnabled ? 0xFF888899 : 0xFF333344;

		_enabledDot.makeGraphic(12, 12, isEnabled ? 0xFF44CC88 : 0xFF883344);

		if (animate && isActive)
		{
			FlxTween.tween(_nameText, {}, 0.1);  // flash visual
		}
	}
}
