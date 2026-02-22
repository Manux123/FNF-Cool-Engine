package funkin.menus;

#if desktop
import lime.ui.FileDialog;
#end
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.ui.FlxButton;
import flixel.addons.ui.FlxInputText;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.math.FlxMath;
import flixel.group.FlxGroup.FlxTypedGroup;
import haxe.Json;
import lime.utils.Assets;
import sys.io.File;
import sys.FileSystem;
import funkin.menus.FreeplayState.SongMetadata;
import funkin.data.MetaData;

using StringTools;

class AddSongSubState extends FlxSubState
{
	// === BACKGROUND ===
	var bgDarkener:FlxSprite;
	var windowBg:FlxSprite;
	var topBar:FlxSprite;

	// === TEXT ===
	var titleText:FlxText;
	var statusText:FlxText;

	// === INPUT FIELDS ===
	var songNameInput:FlxInputText;
	var iconNameInput:FlxInputText;
	var bpmInput:FlxInputText;
	var weekInput:FlxInputText;

	// === META INPUT FIELDS ===
	var uiInput:FlxInputText;
	var noteSkinInput:FlxInputText;
	var introVideoInput:FlxInputText;   // video de intro (antes del countdown)
	var outroVideoInput:FlxInputText;   // video de outro (tras la cancion)

	// === BUTTONS ===
	var loadInstBtn:FlxButton;
	var loadVocalsBtn:FlxButton;
	var loadIconBtn:FlxButton;
	var saveBtn:FlxButton;
	var cancelBtn:FlxButton;

	// === TOGGLE: STORY MODE ===
	var storyModeToggleBtn:FlxButton;
	var storyModeToggleText:FlxText;
	var showInStoryMode:Bool = true;

	// === TOGGLE: NEEDS VOICES ===
	var needsVoicesToggleBtn:FlxButton;
	var needsVoicesToggleText:FlxText;
	var needsVoices:Bool = true;

	// === COLOR PICKER ===
	var selectedColor:String = "0xFFAF66CE";
	var colorButtons:Array<FlxButton> = [];
	var colorLabels:Array<FlxText>   = [];

	// === DATA ===
	var songListData:StoryMenuState.Songs;
	var currentInstPath:String  = "";
	var currentVocalsPath:String = "";
	var currentIconPath:String  = "";
	var instLoaded:Bool      = false;
	var vocalsLoaded:Bool    = false;
	var iconFileLoaded:Bool  = false;

	// === EDIT MODE ===
	var editMode:Bool = false;
	var editingSong:FreeplayState.SongMetadata = null;

	// === ICON PRESETS ===
	var iconPresets:Array<String> = [
		"bf", "bf-pixel", "gf", "dad", "mom", "pico",
		"spooky", "monster", "parents-christmas",
		"senpai", "senpai-angry", "spirit", "face"
	];
	var currentIconIndex:Int = 0;

	// === COLOR PRESETS ===
	var colorPresets:Array<{name:String, hex:String}> = [
		{name:"Purple",  hex:"0xFFAF66CE"},
		{name:"Dark",    hex:"0xFF2A2A2A"},
		{name:"Green",   hex:"0xFF6BAA4C"},
		{name:"Pink",    hex:"0xFFD85889"},
		{name:"Violet",  hex:"0xFF9A68A4"},
		{name:"Orange",  hex:"0xFFFFAA6F"},
		{name:"Blue",    hex:"0xFF31A2F4"},
		{name:"Red",     hex:"0xFFFF0000"},
		{name:"Yellow",  hex:"0xFFFFFF00"},
		{name:"Cyan",    hex:"0xFF00FFFF"},
		{name:"White",   hex:"0xFFFFFFFF"},
		{name:"Magenta", hex:"0xFFFF78BF"}
	];

	// === FILE STATUS INDICATORS ===
	var instStatusText:FlxText;
	var vocalsStatusText:FlxText;
	var iconStatusText:FlxText;

	// ─────────────────────────────────────────────────────────────────────────

	public function new(?editSong:SongMetadata)
	{
		super();
		if (editSong != null) { editMode = true; editingSong = editSong; }
		loadSongList();
	}

	override function create()
	{
		super.create();

		// Background darkener
		bgDarkener = new FlxSprite();
		bgDarkener.makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bgDarkener.alpha = 0;
		add(bgDarkener);
		FlxTween.tween(bgDarkener, {alpha: 0.7}, 0.3, {ease: FlxEase.quadOut});

		// Window — height 720 to fit all fields on a 720p screen
		var windowWidth:Int  = 900;
		var windowHeight:Int = 720;
		var windowX:Float = (FlxG.width  - windowWidth)  / 2;
		var windowY:Float = (FlxG.height - windowHeight) / 2;

		windowBg = new FlxSprite(windowX, windowY);
		windowBg.makeGraphic(windowWidth, windowHeight, 0xFF1a1a2e);
		windowBg.alpha = 0;
		windowBg.scale.set(0.8, 0.8);
		add(windowBg);
		FlxTween.tween(windowBg, {alpha: 0.98, "scale.x": 1, "scale.y": 1}, 0.4, {ease: FlxEase.backOut, startDelay: 0.1});

		topBar = new FlxSprite(windowX, windowY);
		topBar.makeGraphic(windowWidth, 50, 0xFF0f3460);
		topBar.alpha = 0;
		add(topBar);
		FlxTween.tween(topBar, {alpha: 1}, 0.3, {ease: FlxEase.quadOut, startDelay: 0.2});

		titleText = new FlxText(windowX + 20, windowY + 11, 0, editMode ? "EDIT SONG" : "ADD NEW SONG", 24);
		titleText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, LEFT);
		titleText.setBorderStyle(OUTLINE, FlxColor.BLACK, 2);
		titleText.alpha = 0;
		add(titleText);
		FlxTween.tween(titleText, {alpha: 1}, 0.3, {ease: FlxEase.quadOut, startDelay: 0.25});

		statusText = new FlxText(windowX, windowY + windowHeight - 35, windowWidth, "Fill in the song details", 14);
		statusText.setFormat(Paths.font("vcr.ttf"), 14, 0xFF53a8b6, CENTER);
		statusText.alpha = 0;
		add(statusText);
		FlxTween.tween(statusText, {alpha: 1}, 0.3, {ease: FlxEase.quadOut, startDelay: 0.3});

		createInputFields(windowX, windowY);
		createMetaFields(windowX, windowY);
		createToggles(windowX, windowY);
		createFileButtons(windowX, windowY);
		createColorPicker(windowX, windowY);
		createActionButtons(windowX, windowY, windowWidth, windowHeight);

		if (editMode && editingSong != null) loadEditData();

		FlxG.mouse.visible = true;
	}

	// ─────────────────────────────────────────────────────────────────────────
	// UI BUILDERS
	// ─────────────────────────────────────────────────────────────────────────

	function createInputFields(windowX:Float, windowY:Float):Void
	{
		var startY:Float = windowY + 65;

		// Song Name
		_lbl(windowX + 30, startY, "Song Name:", 0.35);
		songNameInput = _inp(windowX + 30, startY + 20, 400, "", 50, 0.4);

		// Icon Name
		startY += 62;
		_lbl(windowX + 30, startY, "Icon Name (use \u2190 \u2192 arrows):", 0.4);
		iconNameInput = _inp(windowX + 30, startY + 20, 400, iconPresets[0], 30, 0.45);

		// BPM + Week (same row)
		startY += 62;
		_lbl(windowX + 30,  startY, "BPM:",        0.45);
		_lbl(windowX + 250, startY, "Week Index:", 0.5);
		bpmInput  = _inpNum(windowX + 30,  startY + 20, 180, "120", 0.5);
		weekInput = _inpNum(windowX + 250, startY + 20, 180, "0",   0.55);
	}

	// ── Meta: UI / NoteSkin / Intro Video / Outro Video ──────────────────────
	function createMetaFields(windowX:Float, windowY:Float):Void
	{
		var startY:Float = windowY + 255;
		var colW:Int     = 180;

		// Row 1 — UI Script | Note Skin
		_lbl(windowX + 30,  startY, "UI Script:", 0.55);
		_lbl(windowX + 240, startY, "Note Skin:", 0.55);
		uiInput       = _inp(windowX + 30,  startY + 20, colW, "default", 40, 0.57);
		noteSkinInput = _inp(windowX + 240, startY + 20, colW, "default", 40, 0.59);

		var h1 = new FlxText(windowX + 30, startY + 44, 430, "Leave 'default' to use global config", 11);
		h1.setFormat(Paths.font("vcr.ttf"), 11, 0xFF53a8b6, LEFT);
		h1.alpha = 0; add(h1); FlxTween.tween(h1, {alpha: 0.7}, 0.3, {startDelay: 0.6});

		// Row 2 — Intro Video | Outro Video
		startY += 65;
		_lbl(windowX + 30,  startY, "Intro Video:", 0.61);
		_lbl(windowX + 240, startY, "Outro Video:", 0.61);
		introVideoInput = _inp(windowX + 30,  startY + 20, colW, "", 80, 0.63);
		outroVideoInput = _inp(windowX + 240, startY + 20, colW, "", 80, 0.63);

		var h2 = new FlxText(windowX + 30, startY + 44, 430, "Video filename without extension  (empty = no cutscene)", 11);
		h2.setFormat(Paths.font("vcr.ttf"), 11, 0xFF53a8b6, LEFT);
		h2.alpha = 0; add(h2); FlxTween.tween(h2, {alpha: 0.7}, 0.3, {startDelay: 0.64});
	}

	// ── Toggles: Story Mode + Needs Voices (same row) ─────────────────────
	function createToggles(windowX:Float, windowY:Float):Void
	{
		var y:Float = windowY + 385;

		// Story Mode (left side)
		_lbl(windowX + 30, y, "Show in Story Mode:", 0.65);
		storyModeToggleBtn = _toggleBtn(windowX + 225, y - 4, function() {
			showInStoryMode = !showInStoryMode;
			_refreshStoryToggle();
			FlxG.sound.play(Paths.sound('menus/scrollMenu'), 0.6);
		}, 0.67);
		storyModeToggleText = _toggleText(windowX + 232, y, 0.69);

		// Needs Voices (right side, same row)
		_lbl(windowX + 340, y, "Needs Voices:", 0.65);
		needsVoicesToggleBtn = _toggleBtn(windowX + 480, y - 4, function() {
			needsVoices = !needsVoices;
			_refreshVoicesToggle();
			FlxG.sound.play(Paths.sound('menus/scrollMenu'), 0.6);
		}, 0.67);
		needsVoicesToggleText = _toggleText(windowX + 487, y, 0.69);

		_refreshStoryToggle();
		_refreshVoicesToggle();
	}

	function createFileButtons(windowX:Float, windowY:Float):Void
	{
		var btnY:Float = windowY + 430;
		var btnX:Float = windowX + 30;

		// Inst.ogg
		loadInstBtn = new FlxButton(btnX, btnY, "Load Inst.ogg", function() {
			#if desktop
			var d = new FileDialog();
			d.onSelect.add(function(p) { currentInstPath = p; instLoaded = true; updateFileStatus(); updateStatus("\u2713 Inst.ogg loaded"); });
			d.browse(OPEN, "ogg", null, "Select Inst.ogg");
			#else updateStatus("File loading only available on Desktop"); #end
		});
		styleButton(loadInstBtn, 0xFF4a5568, 270); loadInstBtn.alpha = 0; add(loadInstBtn);
		FlxTween.tween(loadInstBtn, {alpha: 1}, 0.3, {startDelay: 0.7});

		instStatusText = _statusIcon(btnX + 280, btnY + 7, 0.72);

		// Vocals.ogg
		btnY += 42;
		loadVocalsBtn = new FlxButton(btnX, btnY, "Load Vocals.ogg", function() {
			#if desktop
			var d = new FileDialog();
			d.onSelect.add(function(p) { currentVocalsPath = p; vocalsLoaded = true; updateFileStatus(); updateStatus("\u2713 Vocals.ogg loaded"); });
			d.browse(OPEN, "ogg", null, "Select Vocals.ogg");
			#else updateStatus("File loading only available on Desktop"); #end
		});
		styleButton(loadVocalsBtn, 0xFF4a5568, 270); loadVocalsBtn.alpha = 0; add(loadVocalsBtn);
		FlxTween.tween(loadVocalsBtn, {alpha: 1}, 0.3, {startDelay: 0.72});

		vocalsStatusText = _statusIcon(btnX + 280, btnY + 7, 0.74);

		// Icon.png
		btnY += 42;
		loadIconBtn = new FlxButton(btnX, btnY, "Load Icon.png", function() {
			#if desktop
			var d = new FileDialog();
			d.onSelect.add(function(p) { currentIconPath = p; iconFileLoaded = true; updateFileStatus(); updateStatus("\u2713 Icon.png loaded"); });
			d.browse(OPEN, "png", null, "Select Icon.png");
			#else updateStatus("File loading only available on Desktop"); #end
		});
		styleButton(loadIconBtn, 0xFF4a5568, 270); loadIconBtn.alpha = 0; add(loadIconBtn);
		FlxTween.tween(loadIconBtn, {alpha: 1}, 0.3, {startDelay: 0.74});

		iconStatusText = _statusIcon(btnX + 280, btnY + 7, 0.76);
	}

	function createColorPicker(windowX:Float, windowY:Float):Void
	{
		var colorY:Float = windowY + 430;
		var colorX:Float = windowX + 480;

		var t = new FlxText(colorX, colorY, 0, "Select Color:", 16);
		t.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT);
		t.alpha = 0; add(t); FlxTween.tween(t, {alpha: 1}, 0.3, {startDelay: 0.7});

		colorY += 24;
		var btnSize = 30; var spacing = 8; var perRow = 4;

		for (i in 0...colorPresets.length)
		{
			var bx = colorX + (i % perRow)         * (btnSize + spacing);
			var by = colorY + Math.floor(i / perRow) * (btnSize + spacing + 16);

			var cb = new FlxButton(bx, by, "", function() {
				selectedColor = colorPresets[i].hex;
				updateColorButtons();
				FlxG.sound.play(Paths.sound('menus/scrollMenu'), 0.4);
			});
			cb.makeGraphic(btnSize, btnSize, Std.parseInt(colorPresets[i].hex));
			cb.alpha = 0; add(cb); colorButtons.push(cb);
			FlxTween.tween(cb, {alpha: 0.7}, 0.3, {startDelay: 0.75 + i * 0.02});

			var lbl = new FlxText(bx, by + btnSize + 1, btnSize, colorPresets[i].name, 9);
			lbl.setFormat(Paths.font("vcr.ttf"), 9, FlxColor.WHITE, CENTER);
			lbl.alpha = 0; add(lbl); colorLabels.push(lbl);
			FlxTween.tween(lbl, {alpha: 0.8}, 0.3, {startDelay: 0.75 + i * 0.02});
		}
		updateColorButtons();
	}

	function createActionButtons(windowX:Float, windowY:Float, windowWidth:Int, windowHeight:Int):Void
	{
		var y = windowY + windowHeight - 70;

		saveBtn = new FlxButton(windowX + windowWidth - 220, y, editMode ? "UPDATE" : "SAVE", saveSong);
		styleButton(saveBtn, 0xFF2ecc71, 100); saveBtn.alpha = 0; add(saveBtn);
		FlxTween.tween(saveBtn, {alpha: 1}, 0.3, {startDelay: 0.8});

		cancelBtn = new FlxButton(windowX + windowWidth - 110, y, "CANCEL", closeWindow);
		styleButton(cancelBtn, 0xFFe74c3c, 100); cancelBtn.alpha = 0; add(cancelBtn);
		FlxTween.tween(cancelBtn, {alpha: 1}, 0.3, {startDelay: 0.85});
	}

	// ─────────────────────────────────────────────────────────────────────────
	// TOGGLE REFRESH
	// ─────────────────────────────────────────────────────────────────────────

	function _refreshStoryToggle():Void
	{
		var on = showInStoryMode;
		storyModeToggleBtn.makeGraphic(80, 35, on ? 0xFF4CAF50 : 0xFFFF5252);
		storyModeToggleText.text  = on ? "ON" : "OFF";
		storyModeToggleText.color = on ? 0xFF4CAF50 : 0xFFFF5252;
	}

	function _refreshVoicesToggle():Void
	{
		var on = needsVoices;
		needsVoicesToggleBtn.makeGraphic(80, 35, on ? 0xFF4CAF50 : 0xFFFF5252);
		needsVoicesToggleText.text  = on ? "ON" : "OFF";
		needsVoicesToggleText.color = on ? 0xFF4CAF50 : 0xFFFF5252;
	}

	// ─────────────────────────────────────────────────────────────────────────
	// SAVE / LOAD
	// ─────────────────────────────────────────────────────────────────────────

	function saveSong():Void
	{
		var songName = songNameInput.text.trim();
		if (songName == "") { updateStatus("Song name cannot be empty!"); return; }

		var weekIndex = Std.parseInt(weekInput.text);
		var bpmVal    = Std.parseFloat(bpmInput.text);
		if (Math.isNaN(bpmVal) || bpmVal <= 0) { updateStatus("Invalid BPM value!"); return; }

		FlxG.sound.play(Paths.sound('menus/confirmMenu'));

		if (editMode)
		{
			updateExistingSong(songName, weekIndex, bpmVal);
			updateStatus("Song updated successfully!");
		}
		else
		{
			addNewSong(songName, weekIndex, bpmVal);
			updateStatus("Song added successfully!");
		}

		saveJSON();
		saveMetaJSON(songName);
		closeWindow();
	}

	function addNewSong(songName:String, weekIndex:Int, bpmVal:Float):Void
	{
		while (songListData.songsWeeks.length <= weekIndex)
			songListData.songsWeeks.push({weekSongs:[], songIcons:[], color:[], bpm:[], showInStoryMode:[]});

		var week = songListData.songsWeeks[weekIndex];
		week.weekSongs.push(songName);
		week.songIcons.push(iconNameInput.text.trim());
		week.color.push(selectedColor);
		week.bpm.push(bpmVal);
		if (week.showInStoryMode == null) week.showInStoryMode = [];
		week.showInStoryMode.push(showInStoryMode);

		createBaseChartJSON(songName.toLowerCase(), bpmVal);

		#if desktop
		if (instLoaded     && currentInstPath   != "") copySongFile(currentInstPath,   songName, "Inst");
		if (vocalsLoaded   && currentVocalsPath != "") copySongFile(currentVocalsPath, songName, "Voices");
		if (iconFileLoaded && currentIconPath   != "") copyIconFile(currentIconPath,   iconNameInput.text.trim());
		#end
	}

	function updateExistingSong(songName:String, weekIndex:Int, bpmVal:Float):Void
	{
		for (week in songListData.songsWeeks)
		{
			var idx = week.weekSongs.indexOf(editingSong.songName);
			if (idx != -1)
			{
				week.weekSongs.splice(idx, 1);
				week.songIcons.splice(idx, 1);
				week.color.splice(idx, 1);
				week.bpm.splice(idx, 1);
				if (week.showInStoryMode != null && week.showInStoryMode.length > idx)
					week.showInStoryMode.splice(idx, 1);
				break;
			}
		}

		while (songListData.songsWeeks.length <= weekIndex)
			songListData.songsWeeks.push({weekSongs:[], songIcons:[], color:[], bpm:[], showInStoryMode:[]});

		var week = songListData.songsWeeks[weekIndex];
		week.weekSongs.push(songName);
		week.songIcons.push(iconNameInput.text.trim());
		week.color.push(selectedColor);
		week.bpm.push(bpmVal);
		if (week.showInStoryMode == null) week.showInStoryMode = [];
		week.showInStoryMode.push(showInStoryMode);

		createBaseChartJSON(songName.toLowerCase(), bpmVal);
		_patchNeedsVoicesInCharts(songName.toLowerCase()); // patch existing charts too

		#if desktop
		if (instLoaded     && currentInstPath   != "") copySongFile(currentInstPath,   songName, "Inst");
		if (vocalsLoaded   && currentVocalsPath != "") copySongFile(currentVocalsPath, songName, "Voices");
		if (iconFileLoaded && currentIconPath   != "") copyIconFile(currentIconPath,   iconNameInput.text.trim());
		#end
	}

	// ── meta.json ─────────────────────────────────────────────────────────────
	/**
	 * Saves meta.json for the song including all fields:
	 *   ui, noteSkin, needsVoices, introVideo (if set), outroVideo (if set).
	 */
	function saveMetaJSON(songName:String):Void
	{
		var ui         = uiInput != null         ? uiInput.text.trim()         : 'default';
		var noteSkin   = noteSkinInput != null    ? noteSkinInput.text.trim()   : 'default';
		var introVideo = introVideoInput != null  ? introVideoInput.text.trim() : '';
		var outroVideo = outroVideoInput != null  ? outroVideoInput.text.trim() : '';

		#if sys
		try
		{
			var dir = Paths.resolve('songs/${songName.toLowerCase()}');
			if (!FileSystem.exists(dir)) FileSystem.createDirectory(dir);

			var meta:Dynamic    = {};
			meta.ui             = ui       != '' ? ui       : 'default';
			meta.noteSkin       = noteSkin != '' ? noteSkin : 'default';
			meta.needsVoices    = needsVoices;
			if (introVideo != '') meta.introVideo = introVideo;
			if (outroVideo != '') meta.outroVideo = outroVideo;

			File.saveContent('$dir/meta.json', Json.stringify(meta, null, "\t"));
			trace('[AddSongSubState] meta.json saved for "$songName"');
		}
		catch (e:Dynamic) { trace('[AddSongSubState] Error saving meta.json: $e'); }
		#else
		MetaData.save(songName, ui != '' ? ui : 'default', noteSkin != '' ? noteSkin : 'default');
		#end
	}

	function loadEditData():Void
	{
		if (editingSong == null) return;

		songNameInput.text = editingSong.songName;
		iconNameInput.text = editingSong.songCharacter;
		weekInput.text     = Std.string(editingSong.week);

		for (week in songListData.songsWeeks)
		{
			var idx = week.weekSongs.indexOf(editingSong.songName);
			if (idx != -1)
			{
				if (week.bpm.length > idx)   bpmInput.text = Std.string(week.bpm[idx]);
				if (week.color.length > idx)  selectedColor = week.color[idx];
				if (week.showInStoryMode != null && week.showInStoryMode.length > idx)
					showInStoryMode = week.showInStoryMode[idx];
				break;
			}
		}

		updateColorButtons();
		_refreshStoryToggle();

		// Load meta.json fields
		var m = MetaData.load(editingSong.songName);
		if (uiInput         != null) uiInput.text         = m.ui;
		if (noteSkinInput   != null) noteSkinInput.text   = m.noteSkin;
		if (introVideoInput != null) introVideoInput.text = m.introVideo ?? '';
		if (outroVideoInput != null) outroVideoInput.text = m.outroVideo ?? '';

		// needsVoices: read from chart (most accurate source), fall back to true
		needsVoices = _readNeedsVoicesFromChart(editingSong.songName);
		_refreshVoicesToggle();
	}

	// ─────────────────────────────────────────────────────────────────────────
	// CHART HELPERS
	// ─────────────────────────────────────────────────────────────────────────

	/**
	 * Creates base chart JSONs (normal / easy / hard) if they don't exist yet.
	 * Writes the current `needsVoices` value.
	 */
	function createBaseChartJSON(songName:String, bpm:Float):Void
	{
		#if desktop
		try
		{
			var dir = Paths.resolve("songs/" + songName);
			var nv  = needsVoices ? "true" : "false";

			var sb = new StringBuf();
			sb.add('{\n\t"song": {\n');
			sb.add('\t\t"song": "$songName",\n');
			sb.add('\t\t"bpm": $bpm,\n');
			sb.add('\t\t"speed": 2.5,\n');
			sb.add('\t\t"needsVoices": $nv,\n');
			sb.add('\t\t"player1": "bf",\n');
			sb.add('\t\t"player2": "dad",\n');
			sb.add('\t\t"gfVersion": "gf",\n');
			sb.add('\t\t"stage": "stage_week1",\n');
			sb.add('\t\t"notes": []\n\t}\n}');
			var json = sb.toString();

			for (suffix in ["", "-easy", "-hard"])
			{
				var p = '$dir/$songName$suffix.json';
				if (!FileSystem.exists(p)) { File.saveContent(p, json); trace('Chart created: $p'); }
				else trace('Chart already exists: $p');
			}
		}
		catch (e:Dynamic) { trace('Error creating base chart: $e'); }
		#end
	}

	/**
	 * Patches `needsVoices` into ALL existing chart JSONs of the song.
	 * Called when editing an existing song so old charts are updated.
	 */
	function _patchNeedsVoicesInCharts(songLower:String):Void
	{
		#if sys
		var dir = Paths.resolve('songs/$songLower');
		if (!FileSystem.exists(dir)) return;
		for (file in FileSystem.readDirectory(dir))
		{
			if (!file.endsWith('.json')) continue;
			var p = '$dir/$file';
			try
			{
				var raw:Dynamic     = Json.parse(File.getContent(p));
				var songObj:Dynamic = (raw.song != null) ? raw.song : raw;
				if (Reflect.hasField(songObj, 'song')) // valid chart object
				{
					songObj.needsVoices = needsVoices;
					File.saveContent(p, Json.stringify(raw, null, "\t"));
				}
			}
			catch (_:Dynamic) {}
		}
		#end
	}

	/**
	 * Reads `needsVoices` from the first chart JSON found.
	 * Returns true (safe default) when no chart exists.
	 */
	function _readNeedsVoicesFromChart(songName:String):Bool
	{
		#if sys
		var lower = songName.toLowerCase();
		for (suffix in ["", "-hard", "-easy"])
		{
			var p = Paths.resolve('songs/$lower/$lower$suffix.json');
			if (!FileSystem.exists(p)) continue;
			try
			{
				var raw:Dynamic     = Json.parse(File.getContent(p));
				var songObj:Dynamic = (raw.song != null) ? raw.song : raw;
				if (Reflect.hasField(songObj, 'needsVoices'))
					return (songObj.needsVoices == true);
			}
			catch (_:Dynamic) {}
		}
		#end
		return true;
	}

	// ─────────────────────────────────────────────────────────────────────────
	// FILE OPS
	// ─────────────────────────────────────────────────────────────────────────

	function copySongFile(sourcePath:String, songName:String, fileType:String):Void
	{
		#if desktop
		try
		{
			var dir = Paths.resolve("songs/" + songName.toLowerCase());
			if (!FileSystem.exists(dir)) FileSystem.createDirectory(dir);
			File.copy(sourcePath, '$dir/song/$fileType.ogg');
			trace('File copied: $dir/song/$fileType.ogg');
			createBaseChartJSON(songName.toLowerCase(), Std.parseFloat(bpmInput.text));
		}
		catch (e:Dynamic) { trace('Error copying file: $e'); updateStatus("Error copying " + fileType + ".ogg"); }
		#end
	}

	function copyIconFile(sourcePath:String, iconName:String):Void
	{
		#if desktop
		try
		{
			var dir = Paths.resolve("images/icons");
			if (!FileSystem.exists(dir)) FileSystem.createDirectory(dir);
			File.copy(sourcePath, '$dir/$iconName.png');
			trace('Icon copied: $dir/$iconName.png');
		}
		catch (e:Dynamic) { trace('Error copying icon: $e'); }
		#end
	}

	function saveJSON():Void
	{
		#if desktop
		try
		{
			File.saveContent(Paths.resolve("songs/songList.json"), Json.stringify(songListData, null, "\t"));
			trace("songList.json saved!");
		}
		catch (e:Dynamic) { trace('Error saving JSON: $e'); updateStatus("Error saving JSON"); }
		#end
	}

	function loadSongList():Void
	{
		var path = Paths.jsonSong('songList');
		var content:String = null;
		#if sys
		if (sys.FileSystem.exists(path)) content = sys.io.File.getContent(path);
		#end
		if (content == null) try { content = lime.utils.Assets.getText(path); } catch (_:Dynamic) {}
		try
		{
			songListData = (content != null && content.trim() != '') ? haxe.Json.parse(content) : {songsWeeks:[]};
		}
		catch (e:Dynamic) { trace("Error loading songList.json: " + e); songListData = {songsWeeks:[]}; }
	}

	// ─────────────────────────────────────────────────────────────────────────
	// UI MISC
	// ─────────────────────────────────────────────────────────────────────────

	function updateColorButtons():Void
	{
		for (i in 0...colorButtons.length)
		{
			var sel = colorPresets[i].hex == selectedColor;
			colorButtons[i].alpha = sel ? 1 : 0.7;
			colorLabels[i].color  = sel ? FlxColor.YELLOW : FlxColor.WHITE;
		}
	}

	function updateFileStatus():Void
	{
		instStatusText.text    = instLoaded      ? "\u2713" : "\u2717";
		instStatusText.color   = instLoaded      ? FlxColor.GREEN : FlxColor.RED;
		vocalsStatusText.text  = vocalsLoaded    ? "\u2713" : "\u2717";
		vocalsStatusText.color = vocalsLoaded    ? FlxColor.GREEN : FlxColor.RED;
		iconStatusText.text    = iconFileLoaded  ? "\u2713" : "\u2717";
		iconStatusText.color   = iconFileLoaded  ? FlxColor.GREEN : FlxColor.RED;
	}

	function updateStatus(text:String):Void
	{
		statusText.text = text;
		FlxTween.cancelTweensOf(statusText);
		statusText.alpha = 1;
		statusText.scale.set(1.1, 1.1);
		FlxTween.tween(statusText.scale, {x: 1, y: 1}, 0.2);
	}

	function closeWindow():Void
	{
		FlxG.sound.play(Paths.sound('menus/cancelMenu'));
		FlxTween.tween(bgDarkener, {alpha: 0}, 0.3);
		FlxTween.tween(windowBg, {alpha: 0, "scale.x": 0.8, "scale.y": 0.8}, 0.3, {
			ease: FlxEase.backIn,
			onComplete: function(_) { close(); }
		});
	}

	// ─────────────────────────────────────────────────────────────────────────
	// WIDGET FACTORIES
	// ─────────────────────────────────────────────────────────────────────────

	function _lbl(x:Float, y:Float, text:String, delay:Float):Void
	{
		var l = new FlxText(x, y, 0, text, 16);
		l.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT);
		l.alpha = 0; add(l);
		FlxTween.tween(l, {alpha: 1}, 0.3, {startDelay: delay});
	}

	function _inp(x:Float, y:Float, w:Int, def:String, maxLen:Int, delay:Float):FlxInputText
	{
		var f = new FlxInputText(x, y, w, def, 15);
		f.backgroundColor    = 0xFF0f3460;
		f.fieldBorderColor   = 0xFF53a8b6;
		f.fieldBorderThickness = 2;
		f.color    = FlxColor.WHITE;
		f.maxLength = maxLen;
		f.alpha     = 0;
		add(f);
		FlxTween.tween(f, {alpha: 1}, 0.3, {startDelay: delay});
		return f;
	}

	function _inpNum(x:Float, y:Float, w:Int, def:String, delay:Float):FlxInputText
	{
		var f = _inp(x, y, w, def, 10, delay);
		f.filterMode = FlxInputText.ONLY_NUMERIC;
		return f;
	}

	function _toggleBtn(x:Float, y:Float, cb:Void->Void, delay:Float):FlxButton
	{
		var b = new FlxButton(x, y, "", cb);
		b.makeGraphic(80, 35, 0xFF4CAF50);
		b.label.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER);
		b.alpha = 0; add(b);
		FlxTween.tween(b, {alpha: 1}, 0.3, {startDelay: delay});
		return b;
	}

	function _toggleText(x:Float, y:Float, delay:Float):FlxText
	{
		var t = new FlxText(x, y, 66, "ON", 15);
		t.setFormat(Paths.font("vcr.ttf"), 15, 0xFF4CAF50, CENTER);
		t.alpha = 0; add(t);
		FlxTween.tween(t, {alpha: 1}, 0.3, {startDelay: delay});
		return t;
	}

	function _statusIcon(x:Float, y:Float, delay:Float):FlxText
	{
		var t = new FlxText(x, y, 0, "\u2717", 20);
		t.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.RED, LEFT);
		t.alpha = 0; add(t);
		FlxTween.tween(t, {alpha: 1}, 0.3, {startDelay: delay});
		return t;
	}

	function styleButton(btn:FlxButton, color:Int, width:Int):Void
	{
		btn.makeGraphic(width, 40, color);
		btn.label.size = 18;
		btn.label.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, CENTER);
	}

	// ─────────────────────────────────────────────────────────────────────────
	// UPDATE
	// ─────────────────────────────────────────────────────────────────────────

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (FlxG.keys.justPressed.LEFT)
		{
			currentIconIndex = (currentIconIndex - 1 + iconPresets.length) % iconPresets.length;
			iconNameInput.text = iconPresets[currentIconIndex];
			FlxG.sound.play(Paths.sound('menus/scrollMenu'), 0.4);
		}
		else if (FlxG.keys.justPressed.RIGHT)
		{
			currentIconIndex = (currentIconIndex + 1) % iconPresets.length;
			iconNameInput.text = iconPresets[currentIconIndex];
			FlxG.sound.play(Paths.sound('menus/scrollMenu'), 0.4);
		}

		if (FlxG.keys.justPressed.ESCAPE)
			closeWindow();
	}
}
