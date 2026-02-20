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
import funkin.data.Song.CharacterSlotData;
import funkin.data.Song.StrumsGroupData;
import funkin.gameplay.objects.character.HealthIcon;

using StringTools;

/**
 * Fila de iconos de personajes encima del grid.
 * 
 * Cada personaje (CharacterSlotData) tiene:
 * - name: nombre del char (bf, dad, etc.)
 * - type: "Player", "Opponent", "Girlfriend", "Other"
 * - strumsGroup: ID del StrumsGroupData que usa
 * - x, y, scale, visible, flip
 * 
 * Al agregar un personaje se ofrece crear también un StrumsGroup nuevo,
 * lo que añade 4 columnas al grid (rebuildGrid).
 */
class CharacterIconRow extends FlxGroup
{
	var parent:ChartingState;
	var _song:SwagSong;
	var camHUD:FlxCamera;

	var iconSprites:FlxTypedGroup<FlxSprite>;
	var iconLabels:FlxTypedGroup<FlxText>;
	var iconHitboxes:Array<
		{
			x:Float,
			y:Float,
			w:Float,
			h:Float,
			index:Int
		}>;

	var addCharBtn:FlxSprite;
	var addCharBtnText:FlxText;

	var rowY:Float = 30;
	var iconSize:Int = 38;
	var iconSpacing:Int = 66;
	var gridX:Float;

	var charDataPopup:CharacterDataPopup;

	public var addCharModalOpen:Bool = false;

	static inline var ACCENT_GREEN:Int = 0xFF00FF88;
	static inline var ACCENT_CYAN:Int = 0xFF00D9FF;
	static inline var TEXT_GRAY:Int = 0xFFAAAAAA;

	public static var CHAR_TYPES:Array<String> = ["Opponent", "Player", "Girlfriend", "Other"];

	public function new(parent:ChartingState, song:SwagSong, camHUD:FlxCamera, gridX:Float)
	{
		super();
		this.parent = parent;
		this._song = song;
		this.camHUD = camHUD;
		this.gridX = gridX;
		this.iconHitboxes = [];

		iconSprites = new FlxTypedGroup<FlxSprite>();
		iconLabels = new FlxTypedGroup<FlxText>();
		add(iconSprites);
		add(iconLabels);

		charDataPopup = new CharacterDataPopup(parent, song, camHUD, this);
		add(charDataPopup);

		// Botón "+"
		addCharBtn = new FlxSprite(0, rowY).makeGraphic(28, 28, 0xFF1A3A2A);
		addCharBtn.scrollFactor.set();
		addCharBtn.cameras = [camHUD];
		add(addCharBtn);

		addCharBtnText = new FlxText(0, rowY + 2, 28, "+", 16);
		addCharBtnText.setFormat(Paths.font("vcr.ttf"), 16, ACCENT_GREEN, CENTER);
		addCharBtnText.scrollFactor.set();
		addCharBtnText.cameras = [camHUD];
		add(addCharBtnText);

		refreshIcons();
	}

	public function refreshIcons():Void
	{
		iconSprites.clear();
		iconLabels.clear();
		iconHitboxes = [];

		var chars = (_song.characters != null) ? _song.characters : [];
		var currentX = gridX;

		for (i in 0...chars.length)
		{
			var char = chars[i];
			var typeBg = getTypeColor(char.type);

			// Fondo
			var bg = new FlxSprite(currentX, rowY).makeGraphic(iconSize, iconSize, typeBg);
			bg.alpha = 0.8;
			bg.scrollFactor.set();
			bg.cameras = [camHUD];
			iconSprites.add(bg);

			// HealthIcon
			try
			{
				var icon = new HealthIcon(char.name);
				icon.setPosition(currentX + 2, rowY + 2);
				icon.setGraphicSize(iconSize - 4, iconSize - 4);
				icon.updateHitbox();
				icon.scrollFactor.set();
				icon.cameras = [camHUD];
				iconSprites.add(cast icon);
			}
			catch (e:Dynamic)
			{
				var ph = new FlxSprite(currentX + 6, rowY + 6).makeGraphic(iconSize - 12, iconSize - 12, 0xFF444466);
				ph.scrollFactor.set();
				ph.cameras = [camHUD];
				iconSprites.add(ph);
			}

			// Nombre
			var nameLabel = new FlxText(currentX, rowY + iconSize + 2, iconSize, char.name, 8);
			nameLabel.setFormat(Paths.font("vcr.ttf"), 8, TEXT_GRAY, CENTER);
			nameLabel.scrollFactor.set();
			nameLabel.cameras = [camHUD];
			iconLabels.add(nameLabel);

			// Indicador de StrumsGroup
			if (char.strumsGroup != null && char.strumsGroup.length > 0)
			{
				var sgLabel = new FlxText(currentX, rowY - 11, iconSize, char.strumsGroup, 7);
				sgLabel.setFormat(Paths.font("vcr.ttf"), 7, ACCENT_CYAN, CENTER);
				sgLabel.scrollFactor.set();
				sgLabel.cameras = [camHUD];
				iconLabels.add(sgLabel);
			}

			iconHitboxes.push({
				x: currentX,
				y: rowY,
				w: iconSize,
				h: iconSize,
				index: i
			});
			currentX += iconSpacing;
		}

		// Reposicionar botón "+"
		addCharBtn.x = currentX + 4;
		addCharBtn.y = rowY + 5;
		addCharBtnText.x = currentX + 4;
		addCharBtnText.y = rowY + 7;
	}

	public function isAnyModalOpen():Bool
	{
		return addCharModalOpen || (charDataPopup != null && charDataPopup.isOpen);
	}

	function getTypeColor(type:String):Int
	{
		return switch (type)
		{
			case "Player": 0xFF002233;
			case "Girlfriend": 0xFF220022;
			case "Other": 0xFF222200;
			default: 0xFF220000; // Opponent
		}
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (charDataPopup.isOpen)
			return;

		if (!FlxG.mouse.justPressed)
			return;

		// Click en "+"
		if (FlxG.mouse.overlaps(addCharBtn, camHUD))
		{
			openAddCharacterMenu();
			return;
		}

		// Click en un icono existente
		var mx = FlxG.mouse.x;
		var my = FlxG.mouse.y;

		for (hb in iconHitboxes)
		{
			if (mx >= hb.x && mx <= hb.x + hb.w && my >= hb.y && my <= hb.y + hb.h)
			{
				charDataPopup.openForCharacter(hb.index);
				return;
			}
		}
	}

	function openAddCharacterMenu():Void
	{
		addCharModalOpen = true;
		var cx = FlxG.width / 2 - 200;
		var cy = FlxG.height / 2 - 140;

		// Panel
		var panelBg = new FlxSprite(cx, cy).makeGraphic(400, 280, 0xFF0D0D1F);
		panelBg.scrollFactor.set();
		panelBg.cameras = [camHUD];

		var topBar = new FlxSprite(cx, cy).makeGraphic(400, 3, ACCENT_CYAN);
		topBar.scrollFactor.set();
		topBar.cameras = [camHUD];

		var title = new FlxText(cx + 10, cy + 10, 380, "Agregar Personaje", 14);
		title.setFormat(Paths.font("vcr.ttf"), 14, ACCENT_CYAN, LEFT);
		title.scrollFactor.set();
		title.cameras = [camHUD];

		// Nombre
		var nameLabel = new FlxText(cx + 10, cy + 38, 0, "Nombre:", 10);
		nameLabel.setFormat(Paths.font("vcr.ttf"), 10, TEXT_GRAY, LEFT);
		nameLabel.scrollFactor.set();
		nameLabel.cameras = [camHUD];

		var nameInput = new FlxUIInputText(cx + 10, cy + 52, 175, "bf", 12);
		nameInput.scrollFactor.set();
		nameInput.cameras = [camHUD];

		// Tipo
		var typeLabel = new FlxText(cx + 210, cy + 38, 0, "Tipo:", 10);
		typeLabel.setFormat(Paths.font("vcr.ttf"), 10, TEXT_GRAY, LEFT);
		typeLabel.scrollFactor.set();
		typeLabel.cameras = [camHUD];

		var typeDropDown = new FlxUIDropDownMenu(cx + 210, cy + 52, FlxUIDropDownMenu.makeStrIdLabelArray(CHAR_TYPES, true), function(id:String)
		{
		});
		typeDropDown.scrollFactor.set();
		typeDropDown.cameras = [camHUD];

		// ¿Crear StrumsGroup?
		var strumsCheck = new FlxUICheckBox(cx + 10, cy + 95, null, null, "Crear nuevo StrumsGroup (agrega 4 columnas al grid)", 360);
		strumsCheck.checked = true;
		strumsCheck.scrollFactor.set();
		strumsCheck.cameras = [camHUD];

		var strumsIdLabel = new FlxText(cx + 10, cy + 120, 0, "ID del StrumsGroup:", 10);
		strumsIdLabel.setFormat(Paths.font("vcr.ttf"), 10, TEXT_GRAY, LEFT);
		strumsIdLabel.scrollFactor.set();
		strumsIdLabel.cameras = [camHUD];

		var nextId = (_song.strumsGroups != null) ? _song.strumsGroups.length : 2;
		var strumsIdInput = new FlxUIInputText(cx + 10, cy + 134, 180, "strums_" + nextId, 11);
		strumsIdInput.scrollFactor.set();
		strumsIdInput.cameras = [camHUD];

		var cpuCheck = new FlxUICheckBox(cx + 210, cy + 134, null, null, "CPU", 100);
		cpuCheck.checked = true;
		cpuCheck.scrollFactor.set();
		cpuCheck.cameras = [camHUD];

		var posHint = new FlxText(cx + 10, cy + 158, 380, "El personaje usará las notas de su StrumsGroup para cantar.", 9);
		posHint.setFormat(Paths.font("vcr.ttf"), 9, 0xFF445566, LEFT);
		posHint.scrollFactor.set();
		posHint.cameras = [camHUD];

		var allObjs:Array<Dynamic> = [
			panelBg,
			topBar,
			title,
			nameLabel,
			nameInput,
			typeLabel,
			typeDropDown,
			strumsCheck,
			strumsIdLabel,
			strumsIdInput,
			cpuCheck,
			posHint
		];

		for (o in allObjs)
			parent.add(o);

		// Botones — definidos así para que se puedan referenciar entre sí
		var cancelBtn:FlxButton = null;
		var confirmBtn:FlxButton = null;

		function closeModal():Void
		{
			addCharModalOpen = false;
			for (o in allObjs)
				parent.remove(o);
			parent.remove(cancelBtn);
			parent.remove(confirmBtn);
		}

		cancelBtn = new FlxButton(cx + 280, cy + 240, "Cancel", closeModal);
		cancelBtn.scrollFactor.set();
		cancelBtn.cameras = [camHUD];

		confirmBtn = new FlxButton(cx + 10, cy + 240, "Agregar", function()
		{
			var charName = nameInput.text.trim();
			if (charName.length == 0)
				charName = "bf";

			var typeIdx = Std.parseInt(typeDropDown.selectedId);
			if (typeIdx == null || typeIdx < 0)
				typeIdx = 0;
			var charType = CHAR_TYPES[typeIdx];

			var groupId:String = strumsCheck.checked ? strumsIdInput.text.trim() : null;
			if (groupId != null && groupId.length == 0)
				groupId = "strums_" + nextId;

			// Crear CharacterSlotData
			var newChar:CharacterSlotData = {
				name: charName,
				x: 0,
				y: 0,
				visible: true,
				scale: 1.0,
				type: charType,
				strumsGroup: groupId
			};

			if (_song.characters == null)
				_song.characters = [];
			_song.characters.push(newChar);

			// Si se pidió un nuevo StrumsGroup
			// Si se pidió un nuevo StrumsGroup
			if (strumsCheck.checked && groupId != null)
			{
				if (_song.strumsGroups == null)
					_song.strumsGroups = [];

				var extraGroupX = 100.0 + (_song.strumsGroups.length * 4 * 120.0);

				// GF → strums ocultas en PlayState (no se ven los arrows),
				// pero el grid SÍ muestra las columnas para chartear sus notas.
				var groupVisible = (charType != "Girlfriend");

				var newGroup:StrumsGroupData = {
					id: groupId,
					x: extraGroupX,
					y: 50,
					visible: groupVisible, // ← false para GF
					cpu: cpuCheck.checked,
					spacing: 110
				};

				_song.strumsGroups.push(newGroup);

				parent.rebuildGrid();

				var gfNote = (charType == "Girlfriend") ? " [strums ocultas en juego]" : "";
				parent.showMessage('✅ "${charName}" [${charType}] + "${groupId}"${gfNote} creados', ACCENT_GREEN);
			}
			else
			{
				refreshIcons();
				parent.showMessage('✅ "${charName}" [${charType}] creado (sin StrumsGroup nuevo)', ACCENT_GREEN);
			}

			closeModal();
		});
		confirmBtn.scrollFactor.set();
		confirmBtn.cameras = [camHUD];

		parent.add(cancelBtn);
		parent.add(confirmBtn);
	}
}

// ====================================================================
// POPUP DE DATOS DEL PERSONAJE
// ====================================================================

class CharacterDataPopup extends FlxGroup
{
	var parent:ChartingState;
	var _song:SwagSong;
	var camHUD:FlxCamera;
	var iconRow:CharacterIconRow;

	public var isOpen:Bool = false;

	var editingIndex:Int = -1;

	var overlay:FlxSprite;
	var panel:FlxSprite;
	var titleText:FlxText;

	var nameInput:FlxUIInputText;
	var typeDropDown:FlxUIDropDownMenu;
	var posXStepper:FlxUINumericStepper;
	var posYStepper:FlxUINumericStepper;
	var scaleStepper:FlxUINumericStepper;
	var visibleCheck:FlxUICheckBox;
	var flipCheck:FlxUICheckBox;
	var strumsGroupInput:FlxUIInputText;

	var applyBtn:FlxButton;
	var deleteBtn:FlxButton;
	var closeBtn:FlxButton;

	static inline var POPUP_W:Int = 460;
	static inline var POPUP_H:Int = 370;
	static inline var BG_PANEL:Int = 0xFF0D0D1F;
	static inline var ACCENT_CYAN:Int = 0xFF00D9FF;
	static inline var ACCENT_ERROR:Int = 0xFFFF3366;
	static inline var TEXT_GRAY:Int = 0xFFAAAAAA;

	public function new(parent:ChartingState, song:SwagSong, camHUD:FlxCamera, iconRow:CharacterIconRow)
	{
		super();
		this.parent = parent;
		this._song = song;
		this.camHUD = camHUD;
		this.iconRow = iconRow;
		buildUI();
		close();
	}

	function lbl(x:Float, y:Float, text:String):Void
	{
		var t = new FlxText(x, y, 0, text, 10);
		t.setFormat(Paths.font("vcr.ttf"), 10, TEXT_GRAY, LEFT);
		t.scrollFactor.set();
		t.cameras = [camHUD];
		add(t);
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

		var topBar = new FlxSprite(cx, cy).makeGraphic(POPUP_W, 4, ACCENT_CYAN);
		topBar.scrollFactor.set();
		topBar.cameras = [camHUD];
		add(topBar);

		titleText = new FlxText(cx + 15, cy + 12, POPUP_W, "Character Data", 18);
		titleText.setFormat(Paths.font("vcr.ttf"), 18, ACCENT_CYAN, LEFT);
		titleText.scrollFactor.set();
		titleText.cameras = [camHUD];
		add(titleText);

		// Name
		lbl(cx + 15, cy + 48, "Name:");
		nameInput = new FlxUIInputText(cx + 15, cy + 62, 165, "bf", 12);
		nameInput.scrollFactor.set();
		nameInput.cameras = [camHUD];
		add(nameInput);

		// Type
		lbl(cx + 220, cy + 48, "Type:");
		typeDropDown = new FlxUIDropDownMenu(cx + 220, cy + 62, FlxUIDropDownMenu.makeStrIdLabelArray(CharacterIconRow.CHAR_TYPES, true), function(id:String)
		{
		});
		typeDropDown.scrollFactor.set();
		typeDropDown.cameras = [camHUD];

		// Strums Group
		lbl(cx + 15, cy + 100, "Strums Group ID:");
		strumsGroupInput = new FlxUIInputText(cx + 15, cy + 114, 200, "strums_0", 12);
		strumsGroupInput.scrollFactor.set();
		strumsGroupInput.cameras = [camHUD];
		add(strumsGroupInput);

		var hint = new FlxText(cx + 15, cy + 133, POPUP_W - 30, "Las notas de este StrumsGroup harán cantar a este personaje en PlayState.", 9);
		hint.setFormat(Paths.font("vcr.ttf"), 9, 0xFF445566, LEFT);
		hint.scrollFactor.set();
		hint.cameras = [camHUD];
		add(hint);

		add(typeDropDown);

		// Pos X
		lbl(cx + 15, cy + 158, "Pos X:");
		posXStepper = new FlxUINumericStepper(cx + 15, cy + 172, 10, 0, -3000, 3000, 0);
		posXStepper.scrollFactor.set();
		posXStepper.cameras = [camHUD];
		add(posXStepper);

		// Pos Y
		lbl(cx + 150, cy + 158, "Pos Y:");
		posYStepper = new FlxUINumericStepper(cx + 150, cy + 172, 10, 0, -3000, 3000, 0);
		posYStepper.scrollFactor.set();
		posYStepper.cameras = [camHUD];
		add(posYStepper);

		// Scale
		lbl(cx + 285, cy + 158, "Scale:");
		scaleStepper = new FlxUINumericStepper(cx + 285, cy + 172, 0.1, 1.0, 0.1, 5.0, 1);
		scaleStepper.scrollFactor.set();
		scaleStepper.cameras = [camHUD];
		add(scaleStepper);

		// Visible / Flip
		visibleCheck = new FlxUICheckBox(cx + 15, cy + 215, null, null, "Visible", 100);
		visibleCheck.checked = true;
		visibleCheck.scrollFactor.set();
		visibleCheck.cameras = [camHUD];
		add(visibleCheck);

		flipCheck = new FlxUICheckBox(cx + 120, cy + 215, null, null, "Flip X", 100);
		flipCheck.checked = false;
		flipCheck.scrollFactor.set();
		flipCheck.cameras = [camHUD];
		add(flipCheck);

		// Botones
		applyBtn = new FlxButton(cx + 15, cy + POPUP_H - 42, "Apply", applyChanges);
		applyBtn.scrollFactor.set();
		applyBtn.cameras = [camHUD];
		add(applyBtn);

		deleteBtn = new FlxButton(cx + 115, cy + POPUP_H - 42, "Delete", function()
		{
			deleteCharacter();
			close();
		});
		deleteBtn.scrollFactor.set();
		deleteBtn.cameras = [camHUD];
		add(deleteBtn);

		closeBtn = new FlxButton(cx + POPUP_W - 100, cy + POPUP_H - 42, "OK", function()
		{
			applyChanges();
			close();
		});
		closeBtn.scrollFactor.set();
		closeBtn.cameras = [camHUD];
		add(closeBtn);
	}

	public function openForCharacter(index:Int):Void
	{
		if (_song.characters == null || index < 0 || index >= _song.characters.length)
			return;

		editingIndex = index;
		var char = _song.characters[index];

		if (nameInput != null)
			nameInput.text = char.name != null ? char.name : "bf";

		if (typeDropDown != null)
		{
			var typeName = char.type != null ? char.type : "Opponent";
			var idx = CharacterIconRow.CHAR_TYPES.indexOf(typeName);
			if (idx < 0)
				idx = 0;
			typeDropDown.selectedId = '$idx';
			typeDropDown.selectedLabel = CharacterIconRow.CHAR_TYPES[idx];
		}

		if (strumsGroupInput != null)
			strumsGroupInput.text = char.strumsGroup != null ? char.strumsGroup : "";

		if (posXStepper != null)
			posXStepper.value = (cast char.x : Null<Float>) != null ? char.x : 0;
		if (posYStepper != null)
			posYStepper.value = (cast char.y : Null<Float>) != null ? char.y : 0;
		if (scaleStepper != null)
			scaleStepper.value = char.scale != null ? char.scale : 1.0;
		if (visibleCheck != null)
			visibleCheck.checked = char.visible != null ? char.visible : true;
		if (flipCheck != null)
			flipCheck.checked = char.flip != null ? char.flip : false;

		titleText.text = 'Character #${index + 1}: ${char.name}';

		isOpen = true;
		visible = true;
		active = true;
	}

	function applyChanges():Void
	{
		if (editingIndex < 0 || _song.characters == null || editingIndex >= _song.characters.length)
			return;

		var char = _song.characters[editingIndex];

		if (nameInput != null && nameInput.text.length > 0)
			char.name = nameInput.text.trim();

		if (typeDropDown != null)
		{
			var idx = Std.parseInt(typeDropDown.selectedId);
			if (idx != null && idx >= 0 && idx < CharacterIconRow.CHAR_TYPES.length)
				char.type = CharacterIconRow.CHAR_TYPES[idx];
		}

		if (strumsGroupInput != null)
		{
			var sg = strumsGroupInput.text.trim();
			char.strumsGroup = sg.length > 0 ? sg : null;
		}

		if (posXStepper != null)
			char.x = posXStepper.value;
		if (posYStepper != null)
			char.y = posYStepper.value;
		if (scaleStepper != null)
			char.scale = scaleStepper.value;
		if (visibleCheck != null)
			char.visible = visibleCheck.checked;
		if (flipCheck != null)
			char.flip = flipCheck.checked;

		parent.showMessage('✅ Character #${editingIndex + 1} updated: ${char.name}', ACCENT_CYAN);

		if (iconRow != null)
			iconRow.refreshIcons();
	}

	function deleteCharacter():Void
	{
		if (_song.characters == null || editingIndex < 0 || editingIndex >= _song.characters.length)
			return;

		var charData = _song.characters[editingIndex];
		var name = charData.name;
		var sgId = charData.strumsGroup;

		_song.characters.splice(editingIndex, 1);
		editingIndex = -1;

		// ¿Algún otro personaje usa ese mismo StrumsGroup?
		var sgStillUsed = false;
		if (sgId != null && sgId.length > 0 && _song.characters != null)
		{
			for (c in _song.characters)
			{
				if (c.strumsGroup == sgId)
				{
					sgStillUsed = true;
					break;
				}
			}
		}

		// Si nadie más lo usa → eliminar el grupo y reconstruir el grid
		if (!sgStillUsed && sgId != null && sgId.length > 0 && _song.strumsGroups != null)
		{
			for (i in 0..._song.strumsGroups.length)
			{
				if (_song.strumsGroups[i].id == sgId)
				{
					_song.strumsGroups.splice(i, 1);
					break;
				}
			}
			parent.rebuildGrid(); // ← reconstruye con las columnas correctas
			parent.showMessage('🗑 "${name}" + StrumsGroup "${sgId}" deleted', ACCENT_ERROR);
			if (iconRow != null)
				iconRow.refreshIcons();
			return;
		}

		if (iconRow != null)
			iconRow.refreshIcons();
		parent.showMessage('🗑 Character "${name}" deleted', ACCENT_ERROR);
	}

	public function close():Void
	{
		isOpen = false;
		visible = false;
		active = false;
		editingIndex = -1;
	}

	override public function update(elapsed:Float):Void
	{
		if (!isOpen)
			return;
		super.update(elapsed);
		if (FlxG.keys.justPressed.ESCAPE)
		{
			applyChanges();
			close();
		}
	}
}
