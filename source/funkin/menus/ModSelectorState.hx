package funkin.menus;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.FlxSubState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.math.FlxMath;
import openfl.display.BitmapData as Bitmap;
import openfl.events.KeyboardEvent as OflKeyboardEvent;
import lime.app.Application as LimeApp;
import mods.ModManager;
import mods.ModManager.ModInfo;
import funkin.transitions.StateTransition;
import funkin.states.MusicBeatState;
import funkin.data.GlobalConfig;
import funkin.debug.themes.EditorTheme;
import funkin.debug.themes.ThemePickerSubState;
import funkin.menus.MainMenuState;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

/**
 * ModSelectorState — 3 tabs: Mods / Configuración / Sistema
 *
 * MODS tab:
 *  [↑↓]   Navegar lista           [Enter] Activar mod
 *  [X]    Enable/Disable          [E]     Editar mod.json
 *  [N]    Crear nuevo mod         [F]     Toggle startup mod
 *
 * CONFIG tab (GlobalConfig):
 *  [↑↓]   Seleccionar campo       [Enter] Editar valor
 *  [F5]   Guardar a disco
 *
 * SISTEMA tab:
 *  [↑↓]   Navegar opciones        [Enter] Cambiar/Abrir
 *  [F5]   Guardar configuración
 *
 * Global: [1][2][3] cambiar tab   [Esc] volver al menú
 *
 * Todos los colores se toman de EditorTheme.current.
 */
class ModSelectorState extends MusicBeatState
{
	// ─── Layout ───────────────────────────────────────────────────────────────
	public static inline var LIST_W = 380;
	public static inline var LIST_ITEM_H = 68;
	static inline var PREVIEW_X = LIST_W + 20;
	static inline var PREVIEW_W = 860;
	static inline var PREVIEW_H = 480;
	static inline var CONTENT_Y = 32; // Y bajo el tab bar

	// ─── Tabs ─────────────────────────────────────────────────────────────────
	var _curTab:Int = 0;

	static final TAB_NAMES = ['MODS', 'CONFIGURATION', 'SYSTEM'];

	var _tabBtns:Array<FlxText> = [];
	var _tabUnderlines:Array<FlxSprite> = [];

	// ─── Cameras ──────────────────────────────────────────────────────────────
	var _camBG:FlxCamera;
	var _camUI:FlxCamera;

	// ─── Shared bg ────────────────────────────────────────────────────────────
	var _bg:FlxSprite;
	var _panelBg:FlxSprite;

	// ─── Tab MODS ─────────────────────────────────────────────────────────────
	var _mods:Array<ModInfo> = [];
	var _cur:Int = 0;
	var _prevCur:Int = -1;
	var _listScrollY:Float = 0;

	var _itemGroup:FlxTypedGroup<ModListItem>;
	var _newBtn:FlxSprite;
	var _newBtnTxt:FlxText;
	var _previewBg:FlxSprite;
	var _previewImg:FlxSprite;
	var _previewNone:FlxSprite;
	var _previewTween:FlxTween = null;

	var _infoName:FlxText;
	var _infoAuthor:FlxText;
	var _infoVersion:FlxText;
	var _infoDesc:FlxText;
	var _infoActive:FlxText;
	var _infoWebsite:FlxText;
	var _infoStartup:FlxText;

	#if vlc
	var _video:vlc.VlcBitmap = null;
	var _videoSprite:FlxSprite = null;
	#end

	// ─── Tab CONFIG ───────────────────────────────────────────────────────────
	var _cfgItems:Array<{label:FlxText, value:FlxText, key:String}> = [];
	var _cfgCursor:Int = 0;
	var _cfgBar:FlxSprite;
	var _cfgHint:FlxText;

	// ─── Tab SYSTEM ───────────────────────────────────────────────────────────
	var _sysItems:Array<{label:FlxText, value:FlxText, key:String}> = [];
	var _sysCursor:Int = 0;
	var _sysBar:FlxSprite;
	var _sysDescText:FlxText;
	var _sysHint:FlxText;

	static final SYS_DESCS:Array<String> = [
		'Activate editors and debugging tools in the main menu (Ctrl+D)',
		'Visual theme for all editors. [Enter] opens the preset selector'
	];

	// ─── Shared ───────────────────────────────────────────────────────────────
	var _infoKey:FlxText;
	var _statusMsg:FlxText;
	var _inputCooldown:Float = 0;

	static inline var INPUT_CD = 0.13;

	// ─────────────────────────────────────────────────────────────────────────
	// create
	// ─────────────────────────────────────────────────────────────────────────

	override function create()
	{
		EditorTheme.load();
		ModManager.init();
		_mods = ModManager.installedMods.copy();

		FlxG.mouse.visible = true;
		_setupCameras();
		_buildBG();
		_buildTabBar();
		_buildHelpBar();
		_buildStatusMsg();

		// Tab contents
		_buildModsTab();
		_buildConfigTab();
		_buildSystemTab();

		super.create();

		// Posicionar cursor de lista al mod activo
		if (ModManager.activeMod != null)
			for (i in 0..._mods.length)
				if (_mods[i].id == ModManager.activeMod)
				{
					_cur = i;
					break;
				}

		if (_mods.length == 0)
			_showEmptyMessage();

		_switchTab(0, true);
	}

	inline function _sndScroll():Void
		FlxG.sound.play(Paths.sound('menus/scrollMenu'));

	inline function _sndConfirm():Void
		FlxG.sound.play(Paths.sound('menus/confirmMenu'));

	function _setupCameras():Void
	{
		_camBG = new FlxCamera();
		_camBG.bgColor = EditorTheme.current.bgDark;
		FlxG.cameras.add(_camBG, false);
		_camUI = new FlxCamera();
		_camUI.bgColor = FlxColor.TRANSPARENT;
		FlxG.cameras.add(_camUI, false);
	}

	function _buildBG():Void
	{
		final T = EditorTheme.current;

		_bg = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, T.bgDark);
		_bg.scrollFactor.set();
		_bg.cameras = [_camBG];
		add(_bg);

		_panelBg = new FlxSprite(0, 0).makeGraphic(LIST_W, FlxG.height, T.bgPanel);
		_panelBg.scrollFactor.set();
		_panelBg.cameras = [_camUI];
		add(_panelBg);

		final divider = new FlxSprite(LIST_W, 0).makeGraphic(2, FlxG.height, T.borderColor);
		divider.scrollFactor.set();
		divider.cameras = [_camUI];
		add(divider);
	}

	// ─── Tab Bar ──────────────────────────────────────────────────────────────

	function _buildTabBar():Void
	{
		final T = EditorTheme.current;
		final startX = LIST_W + 4;
		final tabW = (FlxG.width - startX) / TAB_NAMES.length;

		for (i in 0...TAB_NAMES.length)
		{
			final tx = startX + i * tabW;
			final lbl = new FlxText(tx, 4, tabW, TAB_NAMES[i]);
			lbl.setFormat(null, 14, T.textSecondary, CENTER, OUTLINE, T.bgDark);
			lbl.scrollFactor.set();
			lbl.cameras = [_camUI];
			add(lbl);
			_tabBtns.push(lbl);

			final bar = new FlxSprite(tx + 8, 24).makeGraphic(Std.int(tabW - 16), 3, T.accent);
			bar.scrollFactor.set();
			bar.cameras = [_camUI];
			bar.alpha = 0;
			add(bar);
			_tabUnderlines.push(bar);
		}

		// Separador bajo tab bar
		final sep = new FlxSprite(LIST_W + 4, 28).makeGraphic(FlxG.width - LIST_W - 4, 2, T.borderColor);
		sep.scrollFactor.set();
		sep.cameras = [_camUI];
		add(sep);
	}

	// ─── Help bar ─────────────────────────────────────────────────────────────

	function _buildHelpBar():Void
	{
		final T = EditorTheme.current;

		// Izquierda: controles del panel de mods
		_infoKey = new FlxText(8, FlxG.height - 44, LIST_W - 16,
			'[1][2][3] Tabs   [↑↓] Browse   [Enter] Active\n[X] Enable   [E] Edit   [N] New   [F] Startup');
		_infoKey.setFormat(null, 11, T.textDim, LEFT);
		_infoKey.scrollFactor.set();
		_infoKey.cameras = [_camUI];
		add(_infoKey);

		// Título arriba del panel izquierdo
		final title = new FlxText(0, 4, LIST_W, 'MODS');
		title.setFormat(null, 20, T.accent, CENTER, OUTLINE, T.bgDark);
		title.scrollFactor.set();
		title.cameras = [_camUI];
		add(title);
	}

	function _buildStatusMsg():Void
	{
		_statusMsg = new FlxText(PREVIEW_X + 8, FlxG.height - 62, PREVIEW_W, '');
		_statusMsg.setFormat(null, 13, EditorTheme.current.success, LEFT);
		_statusMsg.scrollFactor.set();
		_statusMsg.cameras = [_camUI];
		_statusMsg.alpha = 0;
		add(_statusMsg);
	}

	function _showEmptyMessage():Void
	{
		final msg = new FlxText(16, 80, LIST_W - 32, 'No mods installed.\n\nInstall your mods in\nthe folder mods/\n\n[N] to create a new one.');
		msg.setFormat(null, 14, EditorTheme.current.textDim, CENTER);
		msg.scrollFactor.set();
		msg.cameras = [_camUI];
		add(msg);
	}

	// ─────────────────────────────────────────────────────────────────────────
	// Tab MODS
	// ─────────────────────────────────────────────────────────────────────────

	function _buildModsTab():Void
	{
		final T = EditorTheme.current;

		// Lista
		_itemGroup = new FlxTypedGroup<ModListItem>();
		_itemGroup.cameras = [_camUI];
		add(_itemGroup);
		for (i in 0..._mods.length)
		{
			final item = new ModListItem(_mods[i], i);
			item.y = CONTENT_Y + i * (LIST_ITEM_H + 4);
			_itemGroup.add(item);
		}

		// Preview area
		_previewBg = new FlxSprite(PREVIEW_X - 8, CONTENT_Y).makeGraphic(FlxG.width - PREVIEW_X + 8, PREVIEW_H + 10, T.bgPanelAlt);
		_previewBg.scrollFactor.set();
		_previewBg.cameras = [_camUI];
		add(_previewBg);

		_previewImg = new FlxSprite(PREVIEW_X, CONTENT_Y + 4);
		_previewImg.alpha = 0;
		_previewImg.scrollFactor.set();
		_previewImg.cameras = [_camUI];
		add(_previewImg);

		_previewNone = new FlxSprite(PREVIEW_X, CONTENT_Y + 4).makeGraphic(PREVIEW_W, PREVIEW_H, T.bgPanel);
		_previewNone.alpha = 0;
		_previewNone.scrollFactor.set();
		_previewNone.cameras = [_camUI];
		add(_previewNone);

		// Info panel bajo el preview
		final iy = PREVIEW_H + CONTENT_Y + 18;
		final ix = PREVIEW_X;

		_infoActive = new FlxText(ix, iy, PREVIEW_W, '');
		_infoActive.setFormat(null, 13, T.success, LEFT);
		_infoActive.scrollFactor.set();
		_infoActive.cameras = [_camUI];
		add(_infoActive);

		_infoStartup = new FlxText(ix + 200, iy, PREVIEW_W - 200, '');
		_infoStartup.setFormat(null, 13, T.warning, RIGHT);
		_infoStartup.scrollFactor.set();
		_infoStartup.cameras = [_camUI];
		add(_infoStartup);

		_infoName = new FlxText(ix, iy + 20, PREVIEW_W, '');
		_infoName.setFormat(null, 26, T.textPrimary, LEFT, OUTLINE, T.bgDark);
		_infoName.scrollFactor.set();
		_infoName.cameras = [_camUI];
		add(_infoName);

		_infoAuthor = new FlxText(ix, iy + 52, PREVIEW_W - 120, '');
		_infoAuthor.setFormat(null, 14, T.textSecondary, LEFT);
		_infoAuthor.scrollFactor.set();
		_infoAuthor.cameras = [_camUI];
		add(_infoAuthor);

		_infoVersion = new FlxText(ix + PREVIEW_W - 120, iy + 52, 120, '');
		_infoVersion.setFormat(null, 13, T.textDim, RIGHT);
		_infoVersion.scrollFactor.set();
		_infoVersion.cameras = [_camUI];
		add(_infoVersion);

		_infoDesc = new FlxText(ix, iy + 74, PREVIEW_W, '');
		_infoDesc.setFormat(null, 12, T.textSecondary, LEFT);
		_infoDesc.scrollFactor.set();
		_infoDesc.wordWrap = true;
		_infoDesc.cameras = [_camUI];
		add(_infoDesc);

		_infoWebsite = new FlxText(ix, iy + 118, PREVIEW_W, '');
		_infoWebsite.setFormat(null, 12, T.accent, LEFT);
		_infoWebsite.scrollFactor.set();
		_infoWebsite.cameras = [_camUI];
		add(_infoWebsite);

		// ── Botón "+ NEW MOD" ─────────────────────────────────────────────────
		final btnY = FlxG.height - 80;
		_newBtn = new FlxSprite(8, btnY).makeGraphic(LIST_W - 16, 30, T.accent);
		_newBtn.scrollFactor.set();
		_newBtn.cameras = [_camUI];
		add(_newBtn);
		_newBtnTxt = new FlxText(8, btnY + 7, LIST_W - 16, '+ NEW MOD');
		_newBtnTxt.setFormat(null, 13, T.bgDark, CENTER, OUTLINE, T.bgDark);
		_newBtnTxt.bold = true;
		_newBtnTxt.scrollFactor.set();
		_newBtnTxt.cameras = [_camUI];
		add(_newBtnTxt);
	}

	// ─────────────────────────────────────────────────────────────────────────
	// Tab CONFIG
	// ─────────────────────────────────────────────────────────────────────────

	function _buildConfigTab():Void
	{
		final T = EditorTheme.current;
		final gc = GlobalConfig.instance;
		final ix = PREVIEW_X + 12;
		final iy = CONTENT_Y + 8;

		_cfgBar = new FlxSprite(ix - 10, iy).makeGraphic(5, 34, T.accent);
		_cfgBar.scrollFactor.set();
		_cfgBar.cameras = [_camUI];
		add(_cfgBar);

		final defs = [
			{label: 'UI Script', key: 'ui', value: gc.ui},
			{label: 'Note Skin', key: 'noteSkin', value: gc.noteSkin},
			{label: 'Note Splash', key: 'noteSplash', value: gc.noteSplash}
		];

		for (i in 0...defs.length)
		{
			final d = defs[i];
			final fy = iy + i * 44;

			final lbl = new FlxText(ix, fy + 8, 185, d.label);
			lbl.setFormat(null, 13, T.textDim, RIGHT);
			lbl.scrollFactor.set();
			lbl.cameras = [_camUI];
			add(lbl);

			final val = new FlxText(ix + 200, fy + 4, PREVIEW_W - 220, d.value);
			val.setFormat(null, 16, T.textPrimary, LEFT);
			val.scrollFactor.set();
			val.cameras = [_camUI];
			add(val);

			_cfgItems.push({label: lbl, value: val, key: d.key});
		}

		_cfgHint = new FlxText(ix, iy + defs.length * 44 + 10, PREVIEW_W - 24, '[↑↓] Select field   [Enter] Edit value   [F5] Save to disk');
		_cfgHint.setFormat(null, 12, T.textDim, LEFT);
		_cfgHint.scrollFactor.set();
		_cfgHint.cameras = [_camUI];
		add(_cfgHint);
	}

	// ─────────────────────────────────────────────────────────────────────────
	// Tab SISTEMA
	// ─────────────────────────────────────────────────────────────────────────

	function _buildSystemTab():Void
	{
		final T = EditorTheme.current;
		final ix = PREVIEW_X + 12;
		final iy = CONTENT_Y + 8;

		_sysBar = new FlxSprite(ix - 10, iy).makeGraphic(5, 34, T.accent);
		_sysBar.scrollFactor.set();
		_sysBar.cameras = [_camUI];
		add(_sysBar);

		final defs = [
			{label: 'Developer Mode', key: 'devMode', value: _devModeStr()},
			{label: 'Editor Theme', key: 'theme', value: EditorTheme.current.name.toUpperCase()}
		];

		for (i in 0...defs.length)
		{
			final d = defs[i];
			final fy = iy + i * 44;

			final lbl = new FlxText(ix, fy + 8, 210, d.label);
			lbl.setFormat(null, 13, T.textDim, RIGHT);
			lbl.scrollFactor.set();
			lbl.cameras = [_camUI];
			add(lbl);

			final val = new FlxText(ix + 224, fy + 4, PREVIEW_W - 244, d.value);
			val.setFormat(null, 16, T.textPrimary, LEFT);
			val.scrollFactor.set();
			val.cameras = [_camUI];
			add(val);

			_sysItems.push({label: lbl, value: val, key: d.key});
		}

		// Descripción dinámica
		_sysDescText = new FlxText(ix, iy + defs.length * 44 + 8, PREVIEW_W - 24, '');
		_sysDescText.setFormat(null, 12, T.textDim, LEFT);
		_sysDescText.scrollFactor.set();
		_sysDescText.wordWrap = true;
		_sysDescText.cameras = [_camUI];
		add(_sysDescText);

		_sysHint = new FlxText(ix, iy + defs.length * 44 + 52, PREVIEW_W - 24, '[↑↓] Browse   [Enter] Change / Open   [F5] Save');
		_sysHint.setFormat(null, 12, T.textDim, LEFT);
		_sysHint.scrollFactor.set();
		_sysHint.cameras = [_camUI];
		add(_sysHint);
	}

	// ─────────────────────────────────────────────────────────────────────────
	// Tab switching
	// ─────────────────────────────────────────────────────────────────────────

	function _switchTab(idx:Int, instant:Bool = false):Void
	{
		_curTab = idx;
		final T = EditorTheme.current;

		for (i in 0...TAB_NAMES.length)
		{
			final active = i == idx;
			_tabBtns[i].color = active ? T.accent : T.textSecondary;
			FlxTween.cancelTweensOf(_tabUnderlines[i]);
			if (instant)
				_tabUnderlines[i].alpha = active ? 1 : 0;
			else
				FlxTween.tween(_tabUnderlines[i], {alpha: active ? 1.0 : 0.0}, 0.15, {ease: FlxEase.quadOut});
		}

		final isMods = idx == 0;
		final isConfig = idx == 1;
		final isSys = idx == 2;

		// Tab MODS visibility
		_itemGroup.visible = isMods;
		_previewBg.visible = isMods;
		_previewImg.visible = isMods;
		_previewNone.visible = isMods;
		_infoName.visible = isMods;
		_infoAuthor.visible = isMods;
		_infoVersion.visible = isMods;
		_infoDesc.visible = isMods;
		_infoWebsite.visible = isMods;
		_infoActive.visible = isMods;
		_infoStartup.visible = isMods;

		// Tab CONFIG visibility
		if (_cfgBar != null)
			_cfgBar.visible = isConfig;
		if (_cfgHint != null)
			_cfgHint.visible = isConfig;
		for (it in _cfgItems)
		{
			it.label.visible = isConfig;
			it.value.visible = isConfig;
		}

		// Tab SISTEMA visibility
		if (_sysBar != null)
			_sysBar.visible = isSys;
		if (_sysDescText != null)
			_sysDescText.visible = isSys;
		if (_sysHint != null)
			_sysHint.visible = isSys;
		for (it in _sysItems)
		{
			it.label.visible = isSys;
			it.value.visible = isSys;
		}

		if (isMods && _mods.length > 0)
		{
			_camUI.scroll.y = _listScrollY;
			_selectItem(_cur, instant);
		}
		if (isConfig)
		{
			_camUI.scroll.y = 0;
			_updateCfgCursor();
		}
		if (isSys)
		{
			_camUI.scroll.y = 0;
			_updateSysCursor();
			_updateSysDesc();
		}
	}

	// ─────────────────────────────────────────────────────────────────────────
	// Update
	// ─────────────────────────────────────────────────────────────────────────

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (_inputCooldown > 0)
		{
			_inputCooldown -= elapsed;
			return;
		}

		// Tab keys
		if (FlxG.keys.justPressed.ONE)
		{
			_inputCooldown = INPUT_CD;
			_sndScroll();
			_switchTab(0);
			return;
		}
		if (FlxG.keys.justPressed.TWO)
		{
			_inputCooldown = INPUT_CD;
			_sndScroll();
			_switchTab(1);
			return;
		}
		if (FlxG.keys.justPressed.THREE)
		{
			_inputCooldown = INPUT_CD;
			_sndScroll();
			_switchTab(2);
			return;
		}
		if (FlxG.keys.justPressed.ESCAPE)
		{
			_sndConfirm();
			_goBack();
			return;
		}

		// ── Mouse ────────────────────────────────────────────────────────────
		_handleMouse();

		switch (_curTab)
		{
			case 0:
				_updateMods(elapsed);
			case 1:
				_updateConfig();
			case 2:
				_updateSystem();
		}
	}

	function _handleMouse():Void
	{
		final mx = FlxG.mouse.screenX;
		final my = FlxG.mouse.screenY;

		// ── Scroll de rueda en lista ─────────────────────────────────────────
		if (_curTab == 0 && FlxG.mouse.wheel != 0 && _mods.length > 0)
		{
			_cur = Std.int(Math.max(0, Math.min(_mods.length - 1, _cur - FlxG.mouse.wheel)));
			_sndScroll();
			_selectItem(_cur);
		}

		if (!FlxG.mouse.justPressed)
			return;

		// ── Click en tabs ────────────────────────────────────────────────────
		final tabStartX = LIST_W + 4;
		final tabW = (FlxG.width - tabStartX) / TAB_NAMES.length;
		if (my >= 0 && my <= 28 && mx >= tabStartX)
		{
			final tabIdx = Math.floor((mx - tabStartX) / tabW);
			if (tabIdx >= 0 && tabIdx < TAB_NAMES.length && tabIdx != _curTab)
			{
				_sndScroll();
				_switchTab(tabIdx);
				return;
			}
		}

		// ── Tab MODS ─────────────────────────────────────────────────────────
		if (_curTab == 0)
		{
			// Botón "+ NEW MOD"
			if (_newBtn != null && mx >= _newBtn.x && mx <= _newBtn.x + _newBtn.width
				&& my >= _newBtn.y && my <= _newBtn.y + _newBtn.height)
			{
				_sndConfirm();
				_openCreateMod();
				return;
			}
			// Click en item de lista
			if (mx >= 0 && mx <= LIST_W)
			{
				_itemGroup.forEachAlive(function(item:ModListItem)
				{
					final screenY = item.y - _camUI.scroll.y;
					if (my >= screenY && my < screenY + LIST_ITEM_H)
					{
						if (item.modIndex == _cur)
						{
							// Segundo click en seleccionado → activar
							_sndConfirm();
							_activateMod();
						}
						else
						{
							_sndScroll();
							_cur = item.modIndex;
							_selectItem(_cur);
						}
					}
				});
			}
		}

		// ── Tab CONFIG ────────────────────────────────────────────────────────
		if (_curTab == 1)
		{
			final ix = PREVIEW_X + 12;
			final iy = CONTENT_Y + 8;
			for (i in 0..._cfgItems.length)
			{
				final itemY:Float = iy + i * 44;
				if (mx >= ix && mx <= FlxG.width - 20 && my >= itemY && my < itemY + 44)
				{
					if (i == _cfgCursor)
					{
						_sndScroll();
						_editCfgField();
					}
					else
					{
						_sndScroll();
						_cfgCursor = i;
						_updateCfgCursor();
					}
					return;
				}
			}
		}

		// ── Tab SYSTEM ────────────────────────────────────────────────────────
		if (_curTab == 2)
		{
			final ix = PREVIEW_X + 12;
			final iy = CONTENT_Y + 8;
			for (i in 0..._sysItems.length)
			{
				final itemY:Float = iy + i * 44;
				if (mx >= ix && mx <= FlxG.width - 20 && my >= itemY && my < itemY + 44)
				{
					if (i == _sysCursor)
					{
						_sndConfirm();
						_activateSysItem();
					}
					else
					{
						_sndScroll();
						_sysCursor = i;
						_updateSysCursor();
						_updateSysDesc();
					}
					return;
				}
			}
		}
	}

	// ─── Mods update ─────────────────────────────────────────────────────────

	function _updateMods(elapsed:Float):Void
	{
		if (FlxG.keys.justPressed.N)
		{
			_openCreateMod();
			return;
		}
		if (_mods.length == 0)
			return;

		if (FlxG.keys.justPressed.UP || FlxG.keys.justPressed.W)
		{
			_inputCooldown = INPUT_CD;
			_sndScroll();
			_cur = (_cur - 1 + _mods.length) % _mods.length;
			_selectItem(_cur);
		}
		else if (FlxG.keys.justPressed.DOWN || FlxG.keys.justPressed.S)
		{
			_inputCooldown = INPUT_CD;
			_sndScroll();
			_cur = (_cur + 1) % _mods.length;
			_selectItem(_cur);
		}
		else if (FlxG.keys.justPressed.ENTER)
		{
			_inputCooldown = 0.25;
			_sndConfirm();
			_activateMod();
		}
		else if (FlxG.keys.justPressed.X || FlxG.keys.justPressed.BACKSPACE)
		{
			_inputCooldown = INPUT_CD;
			_sndScroll();
			_toggleEnable();
		}
		else if (FlxG.keys.justPressed.E)
		{
			_inputCooldown = 0.2;
			_sndScroll();
			_openEditMod(_mods[_cur]);
		}
		else if (FlxG.keys.justPressed.F)
		{
			_inputCooldown = INPUT_CD;
			_sndScroll();
			_toggleStartup();
		}

		// Scroll suave
		final vis = Math.floor((FlxG.height - CONTENT_Y - 60) / (LIST_ITEM_H + 4)) - 1;
		if (_mods.length > vis)
		{
			final target = Math.max(0, (_cur - Math.floor(vis * 0.5)) * (LIST_ITEM_H + 4));
			_listScrollY = FlxMath.lerp(_listScrollY, target, Math.min(elapsed * 10, 1.0));
			_camUI.scroll.y = _listScrollY;
		}
	}

	// ─── Config update ────────────────────────────────────────────────────────

	function _updateConfig():Void
	{
		if (FlxG.keys.justPressed.UP || FlxG.keys.justPressed.W)
		{
			_inputCooldown = INPUT_CD;
			_sndScroll();
			_cfgCursor = (_cfgCursor - 1 + _cfgItems.length) % _cfgItems.length;
			_updateCfgCursor();
		}
		else if (FlxG.keys.justPressed.DOWN || FlxG.keys.justPressed.S)
		{
			_inputCooldown = INPUT_CD;
			_sndScroll();
			_cfgCursor = (_cfgCursor + 1) % _cfgItems.length;
			_updateCfgCursor();
		}
		else if (FlxG.keys.justPressed.ENTER)
		{
			_inputCooldown = 0.2;
			_sndScroll();
			_editCfgField();
		}
		else if (FlxG.keys.justPressed.F5)
		{
			_sndConfirm();
			_saveCfg();
		}
	}

	function _updateCfgCursor():Void
	{
		final T = EditorTheme.current;
		final iy = CONTENT_Y + 8;
		FlxTween.cancelTweensOf(_cfgBar);
		FlxTween.tween(_cfgBar, {y: iy + _cfgCursor * 44 + 6}, 0.12, {ease: FlxEase.expoOut});
		for (i in 0..._cfgItems.length)
			_cfgItems[i].value.color = i == _cfgCursor ? T.accent : T.textPrimary;
	}

	function _editCfgField():Void
	{
		final item = _cfgItems[_cfgCursor];
		openSubState(new SimpleTextInputSubState('Editing "${item.label.text}"', item.value.text, v -> item.value.text = v, v -> item.value.text = v));
	}

	function _saveCfg():Void
	{
		final gc = GlobalConfig.instance;
		for (it in _cfgItems)
		{
			switch (it.key)
			{
				case 'ui':
					gc.ui = it.value.text;
				case 'noteSkin':
					gc.noteSkin = it.value.text;
				case 'noteSplash':
					gc.noteSplash = it.value.text;
			}
		}
		gc.save();
		GlobalConfig.reload();
		_showStatus('✓ GlobalConfig saved.', true);
	}

	// ─── System update ────────────────────────────────────────────────────────

	function _updateSystem():Void
	{
		if (FlxG.keys.justPressed.UP || FlxG.keys.justPressed.W)
		{
			_inputCooldown = INPUT_CD;
			_sndScroll();
			_sysCursor = (_sysCursor - 1 + _sysItems.length) % _sysItems.length;
			_updateSysCursor();
			_updateSysDesc();
		}
		else if (FlxG.keys.justPressed.DOWN || FlxG.keys.justPressed.S)
		{
			_inputCooldown = INPUT_CD;
			_sndScroll();
			_sysCursor = (_sysCursor + 1) % _sysItems.length;
			_updateSysCursor();
			_updateSysDesc();
		}
		else if (FlxG.keys.justPressed.ENTER)
		{
			_inputCooldown = 0.25;
			_sndConfirm();
			_activateSysItem();
		}
		else if (FlxG.keys.justPressed.F5)
		{
			_sndConfirm();
			FlxG.save.flush();
			_showStatus('✓ Saved.', true);
		}
	}

	function _updateSysCursor():Void
	{
		final T = EditorTheme.current;
		final iy = CONTENT_Y + 8;
		FlxTween.cancelTweensOf(_sysBar);
		FlxTween.tween(_sysBar, {y: iy + _sysCursor * 44 + 6}, 0.12, {ease: FlxEase.expoOut});
		for (i in 0..._sysItems.length)
			_sysItems[i].value.color = i == _sysCursor ? T.accent : T.textPrimary;
	}

	function _updateSysDesc():Void
	{
		if (_sysDescText == null)
			return;
		_sysDescText.text = SYS_DESCS[_sysCursor] ?? '';
	}

	function _activateSysItem():Void
	{
		final item = _sysItems[_sysCursor];
		switch (item.key)
		{
			case 'devMode':
				MainMenuState.developerMode = !MainMenuState.developerMode;
				item.value.text = _devModeStr();
				_showStatus(MainMenuState.developerMode ? '⚙ Developer Mode ACTIVATED' : '⚙ Developer Mode desactivated', true);
			case 'theme':
				final sub = new ThemePickerSubState(function()
				{
					item.value.text = EditorTheme.current.name.toUpperCase();
					_showStatus('✓ Theme "${EditorTheme.current.name}" applied.', true);
				});
				FlxG.mouse.visible = true;
				openSubState(sub);
		}
	}

	// ─── Mods actions ─────────────────────────────────────────────────────────

	function _selectItem(idx:Int, instant:Bool = false):Void
	{
		if (idx == _prevCur && !instant)
			return;
		_prevCur = idx;
		_itemGroup.forEachAlive(function(it:ModListItem) it.setSelected(it.modIndex == idx));
		final mod = _mods[idx];
		_updateInfo(mod);
		_loadPreview(mod, instant);
	}

	function _updateInfo(mod:ModInfo):Void
	{
		final T = EditorTheme.current;
		_infoName.text = mod.name;
		_infoAuthor.text = mod.author.length > 0 ? 'by ' + mod.author : '';
		_infoVersion.text = 'v' + mod.version;
		_infoDesc.text = mod.description;
		_infoWebsite.text = mod.website.length > 0 ? '🌐 ' + mod.website : '';
		final isActive = ModManager.activeMod == mod.id;
		_infoActive.text = isActive ? '✓ ACTIVE' : (!mod.enabled ? '✗ DISABLED' : '');
		_infoActive.color = isActive ? T.success : T.error;
		_infoStartup.text = ModManager.startupMod == mod.id ? '⚑ STARTUP MOD' : '';
		_infoStartup.color = T.warning;
	}

	function _loadPreview(mod:ModInfo, instant:Bool = false):Void
	{
		if (_previewTween != null)
		{
			_previewTween.cancel();
			_previewTween = null;
		}
		#if vlc _stopVideo(); #end

		switch (ModManager.previewType(mod.id))
		{
			case VIDEO:
				_previewImg.alpha = 0;
				_previewNone.makeGraphic(PREVIEW_W, PREVIEW_H, mod.color | 0xFF000000);
				_previewNone.alpha = 1;
				#if vlc _playVideo(ModManager.previewVideo(mod.id)); #end
			case IMAGE:
				_previewNone.alpha = 0;
				#if vlc _stopVideo(); #end
				_loadPreviewImage(mod, instant);
			case NONE:
				_previewImg.alpha = 0;
				#if vlc _stopVideo(); #end
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

	function _loadPreviewImage(mod:ModInfo, instant:Bool):Void
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
			if (bmp == null)
			{
				_previewImg.alpha = 0;
				return;
			}
			final scale = Math.min(PREVIEW_W / bmp.width, PREVIEW_H / bmp.height);
			_previewImg.loadGraphic(bmp);
			_previewImg.setGraphicSize(Std.int(bmp.width * scale), Std.int(bmp.height * scale));
			_previewImg.updateHitbox();
			_previewImg.x = PREVIEW_X + (PREVIEW_W - _previewImg.width) * 0.5;
			_previewImg.y = CONTENT_Y + 4 + (PREVIEW_H - _previewImg.height) * 0.5;
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
			trace('[ModSelectorState] Preview error: $e');
			_previewImg.alpha = 0;
		}
	}

	#if vlc
	function _playVideo(path:Null<String>):Void
	{
		if (path == null)
			return;
		_stopVideo();
		try
		{
			_video = new vlc.VlcBitmap();
			_video.onReady = function()
			{
				if (_videoSprite == null)
				{
					_videoSprite = new FlxSprite(PREVIEW_X, CONTENT_Y + 4);
					_videoSprite.cameras = [_camUI];
					_videoSprite.scrollFactor.set();
					add(_videoSprite);
				}
				_videoSprite.loadGraphic(_video.bitmapData);
				_videoSprite.setGraphicSize(PREVIEW_W, PREVIEW_H);
				_videoSprite.updateHitbox();
				FlxTween.tween(_videoSprite, {alpha: 1}, 0.3, {ease: FlxEase.quadOut});
			};
			_video.play(path, true, true);
		}
		catch (e:Dynamic)
		{
			trace('[ModSelectorState] VLC error: $e');
		}
	}

	function _stopVideo():Void
	{
		if (_video != null)
		{
			try
			{
				_video.stop();
			}
			catch (_)
			{
			}
			_video = null;
		}
		if (_videoSprite != null)
			_videoSprite.alpha = 0;
	}
	#end

	function _activateMod():Void
	{
		if (_mods.length == 0)
			return;
		final mod = _mods[_cur];
		if (ModManager.activeMod == mod.id)
			ModManager.deactivate();
		else
			ModManager.setActive(mod.id);
		#if vlc _stopVideo(); #end
		if (FlxG.sound.music != null)
			FlxG.sound.music.stop();
		Paths.forceClearCache();
		#if cpp cpp.vm.Gc.run(true); #end
		#if hl hl.Gc.major(); #end
		FlxG.camera.fade(flixel.util.FlxColor.BLACK, 0.5, false, () -> FlxG.resetGame());
	}

	function _toggleEnable():Void
	{
		if (_mods.length == 0)
			return;
		ModManager.toggleEnabled(_mods[_cur].id);
		_updateInfo(_mods[_cur]);
		_itemGroup.forEachAlive(function(it:ModListItem) it.refresh());
	}

	function _toggleStartup():Void
	{
		if (_mods.length == 0)
			return;
		final mod = _mods[_cur];
		if (ModManager.startupMod == mod.id)
			ModManager.setStartupMod(null);
		else
			ModManager.setStartupMod(mod.id);
		_updateInfo(mod);
		_itemGroup.forEachAlive(function(it:ModListItem) it.refresh());
	}

	function _openEditMod(mod:ModInfo):Void
	{
		openSubState(new ModEditSubState(mod, false, function(saved:ModInfo)
		{
			for (i in 0..._mods.length)
				if (_mods[i].id == saved.id)
				{
					_mods[i] = saved;
					break;
				}
			_prevCur = -1;
			_selectItem(_cur, true);
			_itemGroup.forEachAlive(function(it:ModListItem) it.refresh());
		}));
	}

	function _openCreateMod():Void
	{
		FlxG.mouse.visible = true;
		final empty:ModInfo = {
			id: '',
			name: 'New Mod',
			description: '',
			author: '',
			version: '1.0.0',
			priority: 0,
			color: 0xFF6633CC,
			website: '',
			enabled: true,
			startupDefault: false,
			folder: ''
		};
		openSubState(new ModEditSubState(empty, true, function(created:ModInfo)
		{
			ModManager.init();
			_mods = ModManager.installedMods.copy();
			_itemGroup.forEachAlive(function(it:ModListItem) it.kill());
			_itemGroup.clear();
			for (i in 0..._mods.length)
			{
				final item = new ModListItem(_mods[i], i);
				item.y = CONTENT_Y + i * (LIST_ITEM_H + 4);
				_itemGroup.add(item);
			}
			for (i in 0..._mods.length)
				if (_mods[i].id == created.id)
				{
					_cur = i;
					break;
				}
			_prevCur = -1;
			if (_mods.length > 0)
				_selectItem(_cur, true);
		}));
	}

	// ─── Helpers ──────────────────────────────────────────────────────────────

	inline function _boolStr(v:Dynamic):String
		return (v == true) ? 'ON' : 'OFF';

	inline function _devModeStr():String
		return MainMenuState.developerMode ? 'ACTIVATED  ⚙' : 'OFF';

	function _showStatus(msg:String, ok:Bool):Void
	{
		final T = EditorTheme.current;
		_statusMsg.text = msg;
		_statusMsg.color = ok ? T.success : T.error;
		FlxTween.cancelTweensOf(_statusMsg);
		_statusMsg.alpha = 1;
		FlxTween.tween(_statusMsg, {alpha: 0}, 0.5, {startDelay: 2.0, ease: FlxEase.quadIn});
	}

	function _goBack():Void
	{
		#if vlc _stopVideo(); #end
		StateTransition.switchState(new MainMenuState());
	}

	override function destroy()
	{
		#if vlc _stopVideo(); #end
		super.destroy();
	}
}

// ═══════════════════════════════════════════════════════════════════════════
//  ModListItem
// ═══════════════════════════════════════════════════════════════════════════

class ModListItem extends FlxSprite
{
	public var modIndex:Int;

	var _mod:ModInfo;
	var _bg:FlxSprite;
	var _icon:FlxSprite;
	var _nameTxt:FlxText;
	var _authorTxt:FlxText;
	var _enableDot:FlxSprite;
	var _startupDot:FlxSprite;

	static inline var W = ModSelectorState.LIST_W - 16;
	static inline var H = ModSelectorState.LIST_ITEM_H;

	public function new(mod:ModInfo, index:Int)
	{
		super(8, 0);
		_mod = mod;
		modIndex = index;
		final T = EditorTheme.current;

		_bg = new FlxSprite(0, 0);
		_bg.scrollFactor.set();

		// Icono
		_icon = new FlxSprite(6, (H - 40) * 0.5);
		_icon.scrollFactor.set();
		#if sys
		final iconP = ModManager.iconPath(mod.id);
		if (iconP != null)
		{
			final bmp = openfl.display.BitmapData.fromFile(iconP);
			if (bmp != null)
			{
				_icon.loadGraphic(flixel.graphics.FlxGraphic.fromBitmapData(bmp));
				_icon.setGraphicSize(40, 40);
				_icon.updateHitbox();
			}
			else
				_icon = null;
		}
		else
			_icon = null;
		#else
		_icon = null;
		#end

		final offX:Int = _icon != null ? 52 : 10;

		_nameTxt = new FlxText(offX, 10, W - offX - 30, mod.name);
		_nameTxt.setFormat(null, 16, T.textPrimary, LEFT, OUTLINE, T.bgDark);
		_nameTxt.scrollFactor.set();

		_authorTxt = new FlxText(offX, 32, W - offX - 30, mod.author.length > 0 ? 'By ' + mod.author : '');
		_authorTxt.setFormat(null, 11, T.textSecondary, LEFT);
		_authorTxt.scrollFactor.set();

		_enableDot = new FlxSprite(W - 26, H * 0.5 - 6).makeGraphic(12, 12, FlxColor.TRANSPARENT);
		_enableDot.scrollFactor.set();
		_startupDot = new FlxSprite(W - 14, H * 0.5 - 6).makeGraphic(8, 8, FlxColor.TRANSPARENT);
		_startupDot.scrollFactor.set();

		_refresh();
	}

	override public function draw():Void
	{
		_dc(_bg);
		if (_icon != null)
			_dc(_icon);
		_dc(_nameTxt);
		_dc(_authorTxt);
		_dc(_enableDot);
		_dc(_startupDot);
	}

	inline function _dc(s:flixel.FlxBasic):Void
	{
		if (s == null || !s.alive || !s.visible)
			return;
		final spr = cast(s, flixel.FlxObject);
		final ox = spr.x;
		final oy = spr.y;
		spr.x += x;
		spr.y += y;
		spr.cameras = cameras;
		s.draw();
		spr.x = ox;
		spr.y = oy;
	}

	public function setSelected(sel:Bool):Void
	{
		final T = EditorTheme.current;
		FlxTween.cancelTweensOf(this);
		FlxTween.tween(this, {alpha: sel ? 1.0 : (ModManager.activeMod == _mod.id ? 0.85 : 0.55)}, 0.15, {ease: FlxEase.quadOut});
		_bg.makeGraphic(W, H, sel ? (_mod.color | 0xCC000000) : T.bgPanel);
	}

	public function refresh():Void
		_refresh();

	function _refresh():Void
	{
		final T = EditorTheme.current;
		final en = ModManager.isEnabled(_mod.id);
		final st = ModManager.startupMod == _mod.id;
		_nameTxt.color = en ? T.textPrimary : T.textDim;
		_authorTxt.color = en ? T.textSecondary : T.textDim;
		_enableDot.makeGraphic(12, 12, en ? T.success : T.error);
		_startupDot.makeGraphic(8, 8, st ? T.warning : FlxColor.TRANSPARENT);
	}
}

// ═══════════════════════════════════════════════════════════════════════════
//  SimpleTextInputSubState
// ═══════════════════════════════════════════════════════════════════════════

class SimpleTextInputSubState extends FlxSubState
{
	var _title:String;
	var _text:String;
	var _onDone:String->Void;
	var _onChange:String->Void;
	var _inputTxt:FlxText;

	public function new(title:String, initial:String, onDone:String->Void, ?onChange:String->Void)
	{
		super(0x00000000);
		_title = title;
		_text = initial;
		_onDone = onDone;
		_onChange = onChange;
	}

	override function create()
	{
		// Cámara propia para renderizarse sobre camUI del estado padre
		final camSub = new flixel.FlxCamera();
		camSub.bgColor = flixel.util.FlxColor.TRANSPARENT;
		FlxG.cameras.add(camSub, false);
		cameras = [camSub];

		final T = EditorTheme.current;
		final pw = 640;
		final ph = 160;
		final px = (FlxG.width - pw) / 2;
		final py = (FlxG.height - ph) / 2;

		final bg = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, 0xBB000000);
		bg.scrollFactor.set();
		bg.alpha = 0;
		add(bg);
		FlxTween.tween(bg, {alpha: 1}, 0.15, {ease: FlxEase.quadOut});

		final panel = new FlxSprite(px, py).makeGraphic(pw, ph, T.bgPanel);
		panel.scrollFactor.set();
		add(panel);

		final bord = new FlxSprite(px, py).makeGraphic(pw, 3, T.accent);
		bord.scrollFactor.set();
		add(bord);

		final lbl = new FlxText(px, py + 8, pw, _title);
		lbl.setFormat(null, 14, T.textSecondary, CENTER);
		lbl.scrollFactor.set();
		add(lbl);

		final iBg = new FlxSprite(px + 20, py + 44).makeGraphic(pw - 40, 42, T.bgPanelAlt);
		iBg.scrollFactor.set();
		add(iBg);

		_inputTxt = new FlxText(px + 28, py + 50, pw - 56, _text + '|');
		_inputTxt.setFormat(null, 18, T.textPrimary, LEFT);
		_inputTxt.scrollFactor.set();
		add(_inputTxt);

		final hint = new FlxText(px, py + ph - 28, pw, '[Enter] Confirm   [Esc] Cancel');
		hint.setFormat(null, 12, T.textDim, CENTER);
		hint.scrollFactor.set();
		add(hint);

		// Escucha nativa via Lime — independiente de foco
		LimeApp.current.window.onTextInput.add(_onLimeTextInput);
		FlxG.stage.addEventListener(OflKeyboardEvent.KEY_DOWN, _onKeyDown);

		super.create();
	}

	function _onLimeTextInput(text:String):Void
	{
		_text += text;
		_inputTxt.text = _text + '|';
		if (_onChange != null) _onChange(_text);
	}

	function _onKeyDown(e:OflKeyboardEvent):Void
	{
		if (e.keyCode == 8 && _text.length > 0)
		{
			_text = _text.substr(0, _text.length - 1);
			_inputTxt.text = _text + '|';
			if (_onChange != null) _onChange(_text);
		}
	}

	override function destroy()
	{
		if (cameras != null && cameras.length > 0)
		{
			final cam = cameras[0];
			if (cam != null)
				FlxG.cameras.remove(cam, true);
		}
		LimeApp.current.window.onTextInput.remove(_onLimeTextInput);
		FlxG.stage.removeEventListener(OflKeyboardEvent.KEY_DOWN, _onKeyDown);
		super.destroy();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if (FlxG.keys.justPressed.ESCAPE)
		{
			FlxG.sound.play(Paths.sound('menus/scrollMenu'));
			close();
			return;
		}
		if (FlxG.keys.justPressed.ENTER)
		{
			FlxG.sound.play(Paths.sound('menus/confirmMenu'));
			_onDone(_text);
			close();
			return;
		}
	}

	// _kc ya no se necesita — se mantiene por compatibilidad si algo lo llama
	function _kc(key:flixel.input.keyboard.FlxKey, sh:Bool):String
	{
		final n = key.toString();
		if (n.length == 1)
			return sh ? n.toUpperCase() : n.toLowerCase();
		return switch (key)
		{
			case SPACE: ' ';
			case MINUS: sh ? '_' : '-';
			case PERIOD: sh ? '>' : '.';
			case SLASH: sh ? '?' : '/';
			case SEMICOLON: sh ? ':' : ';';
			case NUMPADZERO | ZERO: '0';
			case NUMPADONE | ONE: '1';
			case NUMPADTWO | TWO: '2';
			case NUMPADTHREE | THREE: '3';
			case NUMPADFOUR | FOUR: '4';
			case NUMPADFIVE | FIVE: '5';
			case NUMPADSIX | SIX: '6';
			case NUMPADSEVEN | SEVEN: '7';
			case NUMPADEIGHT | EIGHT: '8';
			case NUMPADNINE | NINE: '9';
			default: '';
		};
	}
}

// ═══════════════════════════════════════════════════════════════════════════
//  ModEditSubState — con colores de EditorTheme
// ═══════════════════════════════════════════════════════════════════════════

class ModEditSubState extends FlxSubState
{
	var _mod:ModInfo;
	var _isCreate:Bool;
	var _onDone:ModInfo->Void;

	var _fields:Array<{label:String, key:String, value:String}> = [];
	var _fieldValues:Array<FlxText> = [];
	var _cursor:FlxSprite;
	var _curField:Int = 0;
	var _editMode:Bool = false;
	var _editingText:String = '';
	var _editBg:FlxSprite;
	var _editText:FlxText;
	var _hint:FlxText;

	var _panelW:Int = 700;
	var _panelH:Int = 520;
	var _panelX:Float;
	var _panelY:Float;
	var _saveBtn:FlxSprite;
	var _closeBtn:FlxSprite;

	public function new(mod:ModInfo, isCreate:Bool, onDone:ModInfo->Void)
	{
		super(0x00000000);
		_mod = Reflect.copy(mod);
		_isCreate = isCreate;
		_onDone = onDone;
	}

	override function create()
	{
		// Cámara propia para renderizarse sobre camUI del estado padre
		final camSub = new flixel.FlxCamera();
		camSub.bgColor = flixel.util.FlxColor.TRANSPARENT;
		FlxG.cameras.add(camSub, false);
		cameras = [camSub];

		final T = EditorTheme.current;
		_panelX = (FlxG.width - _panelW) / 2;
		_panelY = (FlxG.height - _panelH) / 2;

		final bg = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, 0xCC000000);
		bg.scrollFactor.set();
		bg.alpha = 0;
		add(bg);
		FlxTween.tween(bg, {alpha: 1}, 0.18, {ease: FlxEase.quadOut});

		final panel = new FlxSprite(_panelX, _panelY).makeGraphic(_panelW, _panelH, T.bgPanel);
		panel.scrollFactor.set();
		panel.alpha = 0;
		add(panel);
		FlxTween.tween(panel, {alpha: 1}, 0.22, {ease: FlxEase.quadOut});

		final bord = new FlxSprite(_panelX, _panelY).makeGraphic(_panelW, 4, T.accent);
		bord.scrollFactor.set();
		add(bord);

		final title = new FlxText(_panelX, _panelY + 14, _panelW, _isCreate ? '✦  CREATE NEW MOD' : '✎  EDIT MOD  —  ' + _mod.name.toUpperCase());
		title.setFormat(null, 18, T.textPrimary, CENTER, OUTLINE, T.bgDark);
		title.scrollFactor.set();
		add(title);

		final sep = new FlxSprite(_panelX + 20, _panelY + 44).makeGraphic(_panelW - 40, 1, T.borderColor);
		sep.scrollFactor.set();
		add(sep);

		_cursor = new FlxSprite(_panelX + 12, _panelY + 60).makeGraphic(5, 28, T.accent);
		_cursor.scrollFactor.set();
		add(_cursor);

		_fields = _isCreate ? [
			{label: 'ID (carpeta)', key: 'id', value: _mod.id},
			{label: 'Name', key: 'name', value: _mod.name},
			{label: 'Description', key: 'description', value: _mod.description},
			{label: 'Author', key: 'author', value: _mod.author},
			{label: 'Version', key: 'version', value: _mod.version},
			{label: 'Priority', key: 'priority', value: Std.string(_mod.priority)},
			{label: 'Color (HEX)', key: 'color', value: StringTools.hex(_mod.color & 0xFFFFFF, 6)},
			{label: 'Website', key: 'website', value: _mod.website},
		] : [
			{label: 'Name', key: 'name', value: _mod.name},
			{label: 'Description', key: 'description', value: _mod.description},
			{label: 'Author', key: 'author', value: _mod.author},
			{label: 'Version', key: 'version', value: _mod.version},
			{label: 'Priority', key: 'priority', value: Std.string(_mod.priority)},
			{label: 'Color (HEX)', key: 'color', value: StringTools.hex(_mod.color & 0xFFFFFF, 6)},
			{label: 'Website', key: 'website', value: _mod.website},
			];

		for (i in 0..._fields.length)
		{
			final fy = _panelY + 58 + i * 48;
			final lbl = new FlxText(_panelX + 24, fy + 6, 180, _fields[i].label);
			lbl.setFormat(null, 13, T.textDim, RIGHT);
			lbl.scrollFactor.set();
			add(lbl);
			final val = new FlxText(_panelX + 220, fy + 2, _panelW - 240, _fields[i].value);
			val.setFormat(null, 15, T.textPrimary, LEFT);
			val.scrollFactor.set();
			_fieldValues.push(val);
			add(val);
		}

		_editBg = new FlxSprite(_panelX + 20, _panelY + _panelH - 80).makeGraphic(_panelW - 40, 36, T.bgPanelAlt);
		_editBg.scrollFactor.set();
		_editBg.visible = false;
		add(_editBg);

		_editText = new FlxText(_panelX + 28, _panelY + _panelH - 74, _panelW - 56, '');
		_editText.setFormat(null, 16, T.textPrimary, LEFT);
		_editText.scrollFactor.set();
		_editText.visible = false;
		add(_editText);

		// ── Botones Save / Close ─────────────────────────────────────────────
		final btnW = 140;
		final btnH = 28;
		final btnY = _panelY + _panelH - 40;

		_saveBtn = new FlxSprite(_panelX + _panelW - btnW * 2 - 20, btnY).makeGraphic(btnW, btnH, T.success);
		_saveBtn.scrollFactor.set();
		add(_saveBtn);
		final saveTxt = new FlxText(_saveBtn.x, btnY + 7, btnW, '[F5] SAVE');
		saveTxt.setFormat(null, 13, T.bgDark, CENTER);
		saveTxt.bold = true;
		saveTxt.scrollFactor.set();
		add(saveTxt);

		_closeBtn = new FlxSprite(_panelX + _panelW - btnW - 10, btnY).makeGraphic(btnW, btnH, T.error);
		_closeBtn.scrollFactor.set();
		add(_closeBtn);
		final closeTxt = new FlxText(_closeBtn.x, btnY + 7, btnW, '[Esc] CLOSE');
		closeTxt.setFormat(null, 13, T.bgDark, CENTER);
		closeTxt.bold = true;
		closeTxt.scrollFactor.set();
		add(closeTxt);

		_hint = new FlxText(_panelX + 10, btnY + 6, _panelW - btnW * 2 - 40, '[↑↓ / Click] Field   [Enter / Click] Edit');
		_hint.setFormat(null, 11, T.textDim, LEFT);
		_hint.scrollFactor.set();
		add(_hint);

		_updateCursor();

		// Captura nativa de texto via Lime — independiente de foco
		LimeApp.current.window.onTextInput.add(_onLimeTextInput);
		FlxG.stage.addEventListener(OflKeyboardEvent.KEY_DOWN, _onKeyDown);
		FlxG.mouse.visible = true;

		super.create();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if (_editMode)
		{
			_handleTextInput();
			return;
		}

		// ── Mouse ─────────────────────────────────────────────────────────────
		if (FlxG.mouse.justPressed)
		{
			final mx = FlxG.mouse.screenX;
			final my = FlxG.mouse.screenY;
			// Botón SAVE
			if (_saveBtn != null && mx >= _saveBtn.x && mx <= _saveBtn.x + _saveBtn.width
				&& my >= _saveBtn.y && my <= _saveBtn.y + _saveBtn.height)
			{
				FlxG.sound.play(Paths.sound('menus/confirmMenu'));
				_save();
			}
			// Botón CLOSE
			else if (_closeBtn != null && mx >= _closeBtn.x && mx <= _closeBtn.x + _closeBtn.width
				&& my >= _closeBtn.y && my <= _closeBtn.y + _closeBtn.height)
			{
				FlxG.mouse.visible = true;
				FlxG.sound.play(Paths.sound('menus/scrollMenu'));
				close();
			}
			// Click en campo
			else if (mx >= _panelX && mx <= _panelX + _panelW)
			{
				for (i in 0..._fields.length)
				{
					final fy = _panelY + 58 + i * 48;
					if (my >= fy && my < fy + 44)
					{
						if (i == _curField)
						{
							FlxG.sound.play(Paths.sound('menus/scrollMenu'));
							_startEdit();
						}
						else
						{
							FlxG.sound.play(Paths.sound('menus/scrollMenu'));
							_curField = i;
							_updateCursor();
						}
						break;
					}
				}
			}
		}

		if (FlxG.keys.justPressed.UP || FlxG.keys.justPressed.W)
		{
			FlxG.sound.play(Paths.sound('menus/scrollMenu'));
			_changeField(-1);
		}
		if (FlxG.keys.justPressed.DOWN || FlxG.keys.justPressed.S)
		{
			FlxG.sound.play(Paths.sound('menus/scrollMenu'));
			_changeField(1);
		}
		if (FlxG.keys.justPressed.ENTER)
		{
			FlxG.sound.play(Paths.sound('menus/scrollMenu'));
			_startEdit();
		}
		if (FlxG.keys.justPressed.F5)
		{
			FlxG.sound.play(Paths.sound('menus/confirmMenu'));
			_save();
		}
		if (FlxG.keys.justPressed.ESCAPE)
		{
			FlxG.mouse.visible = true;
			FlxG.sound.play(Paths.sound('menus/scrollMenu'));
			close();
		}
	}

	function _handleTextInput():Void
	{
		if (FlxG.keys.justPressed.ESCAPE)
		{
			_endEdit(false);
			return;
		}
		if (FlxG.keys.justPressed.ENTER)
		{
			_endEdit(true);
			return;
		}
		// La actualización real la hacen _onLimeTextInput / _onKeyDown
	}

	function _onLimeTextInput(text:String):Void
	{
		if (!_editMode)
			return;
		_editingText += text;
		_editText.text = _editingText + '|';
	}

	function _onKeyDown(e:OflKeyboardEvent):Void
	{
		if (!_editMode)
			return;
		if (e.keyCode == 8 && _editingText.length > 0)
		{
			_editingText = _editingText.substr(0, _editingText.length - 1);
			_editText.text = _editingText + '|';
		}
	}

	function _kc(key:flixel.input.keyboard.FlxKey, sh:Bool):String
	{
		final n = key.toString();
		if (n.length == 1)
			return sh ? n.toUpperCase() : n.toLowerCase();
		return switch (key)
		{
			case SPACE: ' ';
			case MINUS: sh ? '_' : '-';
			case PERIOD: sh ? '>' : '.';
			case SLASH: sh ? '?' : '/';
			case SEMICOLON: sh ? ':' : ';';
			case NUMPADZERO | ZERO: '0';
			case NUMPADONE | ONE: '1';
			case NUMPADTWO | TWO: '2';
			case NUMPADTHREE | THREE: '3';
			case NUMPADFOUR | FOUR: '4';
			case NUMPADFIVE | FIVE: '5';
			case NUMPADSIX | SIX: '6';
			case NUMPADSEVEN | SEVEN: '7';
			case NUMPADEIGHT | EIGHT: '8';
			case NUMPADNINE | NINE: '9';
			default: '';
		};
	}

	function _changeField(d:Int):Void
	{
		_curField = (_curField + d + _fields.length) % _fields.length;
		_updateCursor();
	}

	function _updateCursor():Void
	{
		final T = EditorTheme.current;
		FlxTween.cancelTweensOf(_cursor);
		FlxTween.tween(_cursor, {y: _panelY + 58 + _curField * 48 + 8}, 0.12, {ease: FlxEase.expoOut});
		for (i in 0..._fieldValues.length)
			_fieldValues[i].color = i == _curField ? T.accent : T.textPrimary;
	}

	function _startEdit():Void
	{
		_editingText = _fields[_curField].value;
		_editMode = true;
		_editBg.visible = true;
		_editText.visible = true;
		_editText.text = _editingText + '|';
		_hint.text = '  Writing "${_fields[_curField].label}" — [Enter] Apply   [Esc] Cancel';
	}

	function _endEdit(apply:Bool):Void
	{
		_editMode = false;
		_editBg.visible = false;
		_editText.visible = false;
		if (apply)
		{
			_fields[_curField].value = _editingText;
			_fieldValues[_curField].text = _editingText;
		}
		_hint.text = '[↑↓] Field   [Enter] Edit/Confirm   [Esc] Cancel/Close   [F5] Save';
	}

	function _save():Void
	{
		final T = EditorTheme.current;
		for (f in _fields)
			switch (f.key)
			{
				case 'id':
					_mod.id = f.value.trim().toLowerCase().replace(' ', '-');
				case 'name':
					_mod.name = f.value;
				case 'description':
					_mod.description = f.value;
				case 'author':
					_mod.author = f.value;
				case 'version':
					_mod.version = f.value;
				case 'website':
					_mod.website = f.value;
				case 'priority':
					final p = Std.parseInt(f.value);
					_mod.priority = p ?? 0;
				case 'color':
					try
					{
						var h = f.value.trim();
						if (h.startsWith('#'))
							h = h.substr(1);
						_mod.color = 0xFF000000 | Std.parseInt('0x$h');
					}
					catch (_)
					{
					}
			}

		if (_isCreate)
		{
			if (_mod.id == '' || _mod.id == null)
			{
				_hint.text = '⚠  The ID field cannot be empty.';
				_hint.color = T.error;
				return;
			}
			final c = ModManager.createMod(_mod.id, _mod);
			if (c == null)
			{
				_hint.text = '⚠  Error: A mod with that ID already exists.';
				_hint.color = T.error;
				return;
			}
			_onDone(c);
		}
		else
		{
			ModManager.saveModInfo(_mod);
			_onDone(_mod);
		}
		close();
	}

	override function destroy()
	{
		if (cameras != null && cameras.length > 0)
		{
			final cam = cameras[0];
			if (cam != null)
				FlxG.cameras.remove(cam, true);
		}
		LimeApp.current.window.onTextInput.remove(_onLimeTextInput);
		FlxG.stage.removeEventListener(OflKeyboardEvent.KEY_DOWN, _onKeyDown);
		super.destroy();
	}
}
