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
	
	// === BUTTONS ===
	var loadInstBtn:FlxButton;
	var loadVocalsBtn:FlxButton;
	var loadIconBtn:FlxButton;
	var saveBtn:FlxButton;
	var cancelBtn:FlxButton;
	
	// === COLOR PICKER ===
	var selectedColor:String = "0xFFAF66CE";
	var colorButtons:Array<FlxButton> = [];
	var colorLabels:Array<FlxText> = [];
	
	// === DATA ===
	var songListData:FreeplayState.Songs;
	var currentInstPath:String = "";
	var currentVocalsPath:String = "";
	var currentIconPath:String = "";
	var instLoaded:Bool = false;
	var vocalsLoaded:Bool = false;
	var iconFileLoaded:Bool = false;
	
	// === EDIT MODE ===
	var editMode:Bool = false;
	var editingSong:FreeplayState.SongMetadata = null;
	
	// === ICON PRESETS ===
	var iconPresets:Array<String> = [
		"bf", "bf-pixel", "gf", "dad", "mom", "pico", 
		"spooky", "monster", "parents-christmas", "senpai", 
		"senpai-angry", "spirit", "face"
	];
	var currentIconIndex:Int = 0;
	
	// === COLOR PRESETS ===
	var colorPresets:Array<{name:String, hex:String}> = [
		{name: "Purple", hex: "0xFFAF66CE"},
		{name: "Dark", hex: "0xFF2A2A2A"},
		{name: "Green", hex: "0xFF6BAA4C"},
		{name: "Pink", hex: "0xFFD85889"},
		{name: "Violet", hex: "0xFF9A68A4"},
		{name: "Orange", hex: "0xFFFFAA6F"},
		{name: "Blue", hex: "0xFF31A2F4"},
		{name: "Red", hex: "0xFFFF0000"},
		{name: "Yellow", hex: "0xFFFFFF00"},
		{name: "Cyan", hex: "0xFF00FFFF"},
		{name: "White", hex: "0xFFFFFFFF"},
		{name: "Magenta", hex: "0xFFFF78BF"}
	];
	
	// === FILE STATUS INDICATORS ===
	var instStatusText:FlxText;
	var vocalsStatusText:FlxText;
	var iconStatusText:FlxText;
	
	public function new(?editSong:SongMetadata)
	{
		super();
		
		if (editSong != null)
		{
			editMode = true;
			editingSong = editSong;
		}
		
		loadSongList();
	}
	
	override function create()
	{
		super.create();
		
		// === BACKGROUND DARKENER ===
		bgDarkener = new FlxSprite();
		bgDarkener.makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bgDarkener.alpha = 0;
		add(bgDarkener);
		
		FlxTween.tween(bgDarkener, {alpha: 0.7}, 0.3, {ease: FlxEase.quadOut});
		
		// === WINDOW BACKGROUND ===
		var windowWidth:Int = 900;
		var windowHeight:Int = 650;
		var windowX:Float = (FlxG.width - windowWidth) / 2;
		var windowY:Float = (FlxG.height - windowHeight) / 2;
		
		windowBg = new FlxSprite(windowX, windowY);
		windowBg.makeGraphic(windowWidth, windowHeight, 0xFF1a1a2e);
		windowBg.alpha = 0;
		windowBg.scale.set(0.8, 0.8);
		add(windowBg);
		
		FlxTween.tween(windowBg, {alpha: 0.98, "scale.x": 1, "scale.y": 1}, 0.4, {
			ease: FlxEase.backOut,
			startDelay: 0.1
		});
		
		// === TOP BAR ===
		topBar = new FlxSprite(windowX, windowY);
		topBar.makeGraphic(windowWidth, 60, 0xFF0f3460);
		topBar.alpha = 0;
		add(topBar);
		
		FlxTween.tween(topBar, {alpha: 1}, 0.3, {ease: FlxEase.quadOut, startDelay: 0.2});
		
		// === TITLE ===
		var titleStr = editMode ? "EDIT SONG" : "ADD NEW SONG";
		titleText = new FlxText(windowX + 20, windowY + 15, 0, titleStr, 28);
		titleText.setFormat(Paths.font("vcr.ttf"), 28, FlxColor.WHITE, LEFT);
		titleText.setBorderStyle(OUTLINE, FlxColor.BLACK, 2);
		titleText.alpha = 0;
		add(titleText);
		
		FlxTween.tween(titleText, {alpha: 1}, 0.3, {ease: FlxEase.quadOut, startDelay: 0.25});
		
		// === STATUS TEXT ===
		statusText = new FlxText(windowX, windowY + windowHeight - 35, windowWidth, "Fill in the song details", 14);
		statusText.setFormat(Paths.font("vcr.ttf"), 14, 0xFF53a8b6, CENTER);
		statusText.alpha = 0;
		add(statusText);
		
		FlxTween.tween(statusText, {alpha: 1}, 0.3, {ease: FlxEase.quadOut, startDelay: 0.3});
		
		// === CREATE UI ===
		createInputFields(windowX, windowY);
		createFileButtons(windowX, windowY);
		createColorPicker(windowX, windowY);
		createActionButtons(windowX, windowY, windowWidth, windowHeight);
		
		// === LOAD EDIT DATA ===
		if (editMode && editingSong != null)
		{
			loadEditData();
		}
		
		FlxG.mouse.visible = true;
	}
	
	function createInputFields(windowX:Float, windowY:Float):Void
	{
		var startY:Float = windowY + 80;
		var inputWidth:Int = 400;
		
		// Song Name
		var label1 = new FlxText(windowX + 30, startY, 0, "Song Name:", 18);
		label1.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, LEFT);
		label1.alpha = 0;
		add(label1);
		FlxTween.tween(label1, {alpha: 1}, 0.3, {startDelay: 0.35});
		
		songNameInput = new FlxInputText(windowX + 30, startY + 25, inputWidth, "", 16);
		songNameInput.backgroundColor = 0xFF0f3460;
		songNameInput.fieldBorderColor = 0xFF53a8b6;
		songNameInput.fieldBorderThickness = 2;
		songNameInput.color = FlxColor.WHITE;
		songNameInput.maxLength = 50;
		songNameInput.alpha = 0;
		add(songNameInput);
		FlxTween.tween(songNameInput, {alpha: 1}, 0.3, {startDelay: 0.4});
		
		// Icon Name
		startY += 75;
		var label2 = new FlxText(windowX + 30, startY, 0, "Icon Name (use ← → arrows):", 18);
		label2.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, LEFT);
		label2.alpha = 0;
		add(label2);
		FlxTween.tween(label2, {alpha: 1}, 0.3, {startDelay: 0.4});
		
		iconNameInput = new FlxInputText(windowX + 30, startY + 25, inputWidth, iconPresets[0], 16);
		iconNameInput.backgroundColor = 0xFF0f3460;
		iconNameInput.fieldBorderColor = 0xFF53a8b6;
		iconNameInput.fieldBorderThickness = 2;
		iconNameInput.color = FlxColor.WHITE;
		iconNameInput.maxLength = 30;
		iconNameInput.alpha = 0;
		add(iconNameInput);
		FlxTween.tween(iconNameInput, {alpha: 1}, 0.3, {startDelay: 0.45});
		
		// BPM and Week on same row
		startY += 75;
		var label3 = new FlxText(windowX + 30, startY, 0, "BPM:", 18);
		label3.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, LEFT);
		label3.alpha = 0;
		add(label3);
		FlxTween.tween(label3, {alpha: 1}, 0.3, {startDelay: 0.45});
		
		bpmInput = new FlxInputText(windowX + 30, startY + 25, 180, "120", 16);
		bpmInput.backgroundColor = 0xFF0f3460;
		bpmInput.fieldBorderColor = 0xFF53a8b6;
		bpmInput.fieldBorderThickness = 2;
		bpmInput.color = FlxColor.WHITE;
		bpmInput.filterMode = FlxInputText.ONLY_NUMERIC;
		bpmInput.alpha = 0;
		add(bpmInput);
		FlxTween.tween(bpmInput, {alpha: 1}, 0.3, {startDelay: 0.5});
		
		var label4 = new FlxText(windowX + 250, startY, 0, "Week Index:", 18);
		label4.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, LEFT);
		label4.alpha = 0;
		add(label4);
		FlxTween.tween(label4, {alpha: 1}, 0.3, {startDelay: 0.5});
		
		weekInput = new FlxInputText(windowX + 250, startY + 25, 180, "0", 16);
		weekInput.backgroundColor = 0xFF0f3460;
		weekInput.fieldBorderColor = 0xFF53a8b6;
		weekInput.fieldBorderThickness = 2;
		weekInput.color = FlxColor.WHITE;
		weekInput.filterMode = FlxInputText.ONLY_NUMERIC;
		weekInput.alpha = 0;
		add(weekInput);
		FlxTween.tween(weekInput, {alpha: 1}, 0.3, {startDelay: 0.55});
	}
	
	function createFileButtons(windowX:Float, windowY:Float):Void
	{
		var btnY:Float = windowY + 330;
		var btnX:Float = windowX + 30;
		
		// Load Inst Button
		loadInstBtn = new FlxButton(btnX, btnY, "Load Inst.ogg", function()
		{
			#if desktop
			var dialog = new FileDialog();
			dialog.onSelect.add(function(path:String)
			{
				currentInstPath = path;
				instLoaded = true;
				updateFileStatus();
				updateStatus("✓ Inst.ogg loaded");
			});
			dialog.browse(OPEN, "ogg", null, "Select Inst.ogg");
			#else
			updateStatus("File loading only available on Desktop");
			#end
		});
		styleButton(loadInstBtn, 0xFF4a5568, 270);
		loadInstBtn.alpha = 0;
		add(loadInstBtn);
		FlxTween.tween(loadInstBtn, {alpha: 1}, 0.3, {startDelay: 0.6});
		
		// Inst status
		instStatusText = new FlxText(btnX + 280, btnY + 7, 0, "✗", 20);
		instStatusText.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.RED, LEFT);
		instStatusText.alpha = 0;
		add(instStatusText);
		FlxTween.tween(instStatusText, {alpha: 1}, 0.3, {startDelay: 0.65});
		
		// Load Vocals Button
		btnY += 50;
		loadVocalsBtn = new FlxButton(btnX, btnY, "Load Vocals.ogg", function()
		{
			#if desktop
			var dialog = new FileDialog();
			dialog.onSelect.add(function(path:String)
			{
				currentVocalsPath = path;
				vocalsLoaded = true;
				updateFileStatus();
				updateStatus("✓ Vocals.ogg loaded");
			});
			dialog.browse(OPEN, "ogg", null, "Select Vocals.ogg");
			#else
			updateStatus("File loading only available on Desktop");
			#end
		});
		styleButton(loadVocalsBtn, 0xFF4a5568, 270);
		loadVocalsBtn.alpha = 0;
		add(loadVocalsBtn);
		FlxTween.tween(loadVocalsBtn, {alpha: 1}, 0.3, {startDelay: 0.65});
		
		// Vocals status
		vocalsStatusText = new FlxText(btnX + 280, btnY + 7, 0, "✗", 20);
		vocalsStatusText.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.RED, LEFT);
		vocalsStatusText.alpha = 0;
		add(vocalsStatusText);
		FlxTween.tween(vocalsStatusText, {alpha: 1}, 0.3, {startDelay: 0.7});
		
		// Load Icon Button
		btnY += 50;
		loadIconBtn = new FlxButton(btnX, btnY, "Load Icon.png (optional)", function()
		{
			#if desktop
			var dialog = new FileDialog();
			dialog.onSelect.add(function(path:String)
			{
				currentIconPath = path;
				iconFileLoaded = true;
				updateFileStatus();
				updateStatus("✓ Icon.png loaded");
			});
			dialog.browse(OPEN, "png", null, "Select Icon.png");
			#else
			updateStatus("File loading only available on Desktop");
			#end
		});
		styleButton(loadIconBtn, 0xFF4a5568, 270);
		loadIconBtn.alpha = 0;
		add(loadIconBtn);
		FlxTween.tween(loadIconBtn, {alpha: 1}, 0.3, {startDelay: 0.7});
		
		// Icon status
		iconStatusText = new FlxText(btnX + 280, btnY + 7, 0, "○", 20);
		iconStatusText.setFormat(Paths.font("vcr.ttf"), 20, 0xFF888888, LEFT);
		iconStatusText.alpha = 0;
		add(iconStatusText);
		FlxTween.tween(iconStatusText, {alpha: 1}, 0.3, {startDelay: 0.75});
	}
	
	function createColorPicker(windowX:Float, windowY:Float):Void
	{
		var startX:Float = windowX + 480;
		var startY:Float = windowY + 80;
		
		var colorLabel = new FlxText(startX, startY, 0, "Song Color:", 18);
		colorLabel.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, LEFT);
		colorLabel.alpha = 0;
		add(colorLabel);
		FlxTween.tween(colorLabel, {alpha: 1}, 0.3, {startDelay: 0.5});
		
		startY += 35;
		
		var gridCols:Int = 3;
		var btnSize:Int = 50;
		var spacing:Int = 65;
		
		for (i in 0...colorPresets.length)
		{
			var row:Int = Math.floor(i / gridCols);
			var col:Int = i % gridCols;
			
			var btnX:Float = startX + (col * spacing);
			var btnY:Float = startY + (row * spacing);
			
			var btn = new FlxButton(btnX, btnY, "", function()
			{
				selectColor(colorPresets[i].hex);
			});
			btn.makeGraphic(btnSize, btnSize, Std.parseInt(colorPresets[i].hex));
			btn.alpha = 0;
			add(btn);
			colorButtons.push(btn);
			FlxTween.tween(btn, {alpha: 1}, 0.3, {startDelay: 0.55 + (i * 0.02)});
			
			var label = new FlxText(btnX, btnY + btnSize + 5, btnSize, colorPresets[i].name, 10);
			label.setFormat(Paths.font("vcr.ttf"), 10, FlxColor.WHITE, CENTER);
			label.alpha = 0;
			add(label);
			colorLabels.push(label);
			FlxTween.tween(label, {alpha: 0.7}, 0.3, {startDelay: 0.6 + (i * 0.02)});
		}
		
		selectColor(selectedColor);
	}
	
	function createActionButtons(windowX:Float, windowY:Float, windowWidth:Int, windowHeight:Int):Void
	{
		var btnY:Float = windowY + windowHeight - 70;
		
		// Save Button
		var saveBtnText = editMode ? "SAVE CHANGES" : "ADD SONG";
		saveBtn = new FlxButton(windowX + 30, btnY, saveBtnText, function()
		{
			saveSong();
		});
		styleButton(saveBtn, 0xFF00a8cc, 400);
		saveBtn.label.size = 18;
		saveBtn.alpha = 0;
		add(saveBtn);
		FlxTween.tween(saveBtn, {alpha: 1}, 0.3, {startDelay: 0.8});
		
		// Cancel Button
		cancelBtn = new FlxButton(windowX + 450, btnY, "CANCEL", function()
		{
			closeWindow();
		});
		styleButton(cancelBtn, 0xFF7209b7, 400);
		cancelBtn.label.size = 18;
		cancelBtn.alpha = 0;
		add(cancelBtn);
		FlxTween.tween(cancelBtn, {alpha: 1}, 0.3, {startDelay: 0.85});
	}
	
	function styleButton(btn:FlxButton, color:Int, width:Int):Void
	{
		btn.makeGraphic(width, 40, color);
		btn.label.setFormat(Paths.font("vcr.ttf"), 14, FlxColor.WHITE, CENTER);
		btn.label.setBorderStyle(OUTLINE, FlxColor.BLACK, 1);
		btn.onOver.callback = function()
		{
			FlxTween.cancelTweensOf(btn.scale);
			FlxTween.tween(btn.scale, {x: 1.05, y: 1.05}, 0.1);
		};
		btn.onOut.callback = function()
		{
			FlxTween.cancelTweensOf(btn.scale);
			FlxTween.tween(btn.scale, {x: 1, y: 1}, 0.1);
		};
	}
	
	function selectColor(colorHex:String):Void
	{
		selectedColor = colorHex;
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.3);
		
		for (i in 0...colorButtons.length)
		{
			var btn = colorButtons[i];
			if (colorPresets[i].hex == selectedColor)
			{
				btn.scale.set(1.2, 1.2);
				colorLabels[i].alpha = 1;
				colorLabels[i].color = 0xFF00FF00;
			}
			else
			{
				btn.scale.set(1, 1);
				colorLabels[i].alpha = 0.7;
				colorLabels[i].color = FlxColor.WHITE;
			}
		}
	}
	
	function updateFileStatus():Void
	{
		if (instLoaded)
		{
			instStatusText.text = "✓";
			instStatusText.color = FlxColor.GREEN;
		}
		
		if (vocalsLoaded)
		{
			vocalsStatusText.text = "✓";
			vocalsStatusText.color = FlxColor.GREEN;
		}
		
		if (iconFileLoaded)
		{
			iconStatusText.text = "✓";
			iconStatusText.color = FlxColor.GREEN;
		}
	}
	
	function loadEditData():Void
	{
		if (editingSong == null) return;
		
		songNameInput.text = editingSong.songName;
		iconNameInput.text = editingSong.songCharacter;
		weekInput.text = Std.string(editingSong.week);
		
		// Find the song in songInfo to get BPM and color
		for (week in songListData.songsWeeks)
		{
			var idx = week.weekSongs.indexOf(editingSong.songName);
			if (idx != -1)
			{
				bpmInput.text = Std.string(week.bpm[idx]);
				selectedColor = week.color[idx];
				selectColor(selectedColor);
				break;
			}
		}
		
		updateStatus("Editing: " + editingSong.songName);
	}
	
	function saveSong():Void
	{
		var songName = songNameInput.text.trim();
		
		if (songName == "")
		{
			updateStatus("❌ Please enter a song name!");
			FlxG.sound.play(Paths.sound('cancelMenu'));
			FlxG.camera.shake(0.005, 0.1);
			return;
		}
		
		#if !desktop
		if (!editMode && (!instLoaded || !vocalsLoaded))
		{
			updateStatus("❌ Please load Inst and Vocals files!");
			FlxG.sound.play(Paths.sound('cancelMenu'));
			FlxG.camera.shake(0.005, 0.1);
			return;
		}
		#end
		
		var weekIndex:Null<Int> = Std.parseInt(weekInput.text);
		if (weekIndex == null) weekIndex = 0;
		
		var bpmVal:Float = Std.parseFloat(bpmInput.text);
		if (Math.isNaN(bpmVal) || bpmVal <= 0) bpmVal = 120;
		
		if (editMode)
		{
			// Update existing song
			updateExistingSong(songName, weekIndex, bpmVal);
		}
		else
		{
			// Add new song
			addNewSong(songName, weekIndex, bpmVal);
		}
		
		// Save JSON
		saveJSON();
		
		FlxG.sound.play(Paths.sound('confirmMenu'));
		FlxG.camera.flash(FlxColor.GREEN, 0.3);
		
		closeWindow();
	}
	
	function addNewSong(songName:String, weekIndex:Int, bpmVal:Float):Void
	{
		// Ensure week exists
		while (songListData.songsWeeks.length <= weekIndex)
		{
			songListData.songsWeeks.push({
				weekSongs: [],
				songIcons: [],
				color: [],
				bpm: []
			});
		}
		
		var week = songListData.songsWeeks[weekIndex];
		week.weekSongs.push(songName);
		week.songIcons.push(iconNameInput.text.trim());
		week.color.push(selectedColor);
		week.bpm.push(bpmVal);
		
		// Create base chart JSON
		createBaseChartJSON(songName.toLowerCase(), bpmVal);
		
		// Copy files
		#if desktop
		if (instLoaded && currentInstPath != "")
		{
			copySongFile(currentInstPath, songName, "Inst");
		}
		if (vocalsLoaded && currentVocalsPath != "")
		{
			copySongFile(currentVocalsPath, songName, "Voices");
		}
		if (iconFileLoaded && currentIconPath != "")
		{
			copyIconFile(currentIconPath, iconNameInput.text.trim());
		}
		#end
	}
	
	function updateExistingSong(songName:String, weekIndex:Int, bpmVal:Float):Void
	{
		// Find and remove old entry
		for (week in songListData.songsWeeks)
		{
			var idx = week.weekSongs.indexOf(editingSong.songName);
			if (idx != -1)
			{
				week.weekSongs.splice(idx, 1);
				week.songIcons.splice(idx, 1);
				week.color.splice(idx, 1);
				week.bpm.splice(idx, 1);
				break;
			}
		}
		
		// Add updated entry
		while (songListData.songsWeeks.length <= weekIndex)
		{
			songListData.songsWeeks.push({
				weekSongs: [],
				songIcons: [],
				color: [],
				bpm: []
			});
		}
		
		var week = songListData.songsWeeks[weekIndex];
		week.weekSongs.push(songName);
		week.songIcons.push(iconNameInput.text.trim());
		week.color.push(selectedColor);
		week.bpm.push(bpmVal);
		
		// Create base chart JSON if it doesn't exist
		createBaseChartJSON(songName.toLowerCase(), bpmVal);
		
		// Copy files if new ones were loaded
		#if desktop
		if (instLoaded && currentInstPath != "")
		{
			copySongFile(currentInstPath, songName, "Inst");
		}
		if (vocalsLoaded && currentVocalsPath != "")
		{
			copySongFile(currentVocalsPath, songName, "Voices");
		}
		if (iconFileLoaded && currentIconPath != "")
		{
			copyIconFile(currentIconPath, iconNameInput.text.trim());
		}
		#end
	}
	
	function copySongFile(sourcePath:String, songName:String, fileType:String):Void
	{
		#if desktop
		try
		{
			var targetDir = "assets/songs/" + songName.toLowerCase();
			if (!FileSystem.exists(targetDir))
			{
				FileSystem.createDirectory(targetDir);
			}
			
			var targetPath = targetDir + "/" + fileType + ".ogg";
			File.copy(sourcePath, targetPath);
			
			trace('File copied: ' + targetPath);
			
			// Create base chart JSON if it doesn't exist
			createBaseChartJSON(songName.toLowerCase(), Std.parseFloat(bpmInput.text));
		}
		catch (e:Dynamic)
		{
			trace('Error copying file: ' + e);
			updateStatus("Error copying " + fileType + ".ogg");
		}
		#end
	}
	
	function createBaseChartJSON(songName:String, bpm:Float):Void
	{
		#if desktop
		try
		{
			var targetDir = "assets/songs/" + songName;
			
			// Create JSON manually to ensure correct field order
			var sb = new StringBuf();
			sb.add('{\n');
			sb.add('\t"song": {\n');
			sb.add('\t\t"song": "$songName",\n');
			sb.add('\t\t"bpm": $bpm,\n');
			sb.add('\t\t"speed": 2.5,\n');
			sb.add('\t\t"needsVoices": true,\n');
			sb.add('\t\t"player1": "bf",\n');
			sb.add('\t\t"player2": "dad",\n');
			sb.add('\t\t"gfVersion": "gf",\n');
			sb.add('\t\t"stage": "stage_week1",\n');
			sb.add('\t\t"notes": []\n');
			sb.add('\t}\n');
			sb.add('}');
			
			var jsonString = sb.toString();
			
			// Create chart files for all difficulties
			// Normal difficulty (no suffix)
			var chartPathNormal = targetDir + "/" + songName + ".json";
			if (!FileSystem.exists(chartPathNormal))
			{
				File.saveContent(chartPathNormal, jsonString);
				trace('Base chart created: ' + chartPathNormal);
			}
			else
			{
				trace('Chart already exists: ' + chartPathNormal);
			}
			
			// Easy difficulty
			var chartPathEasy = targetDir + "/" + songName + "-easy.json";
			if (!FileSystem.exists(chartPathEasy))
			{
				File.saveContent(chartPathEasy, jsonString);
				trace('Easy chart created: ' + chartPathEasy);
			}
			else
			{
				trace('Easy chart already exists: ' + chartPathEasy);
			}
			
			// Hard difficulty
			var chartPathHard = targetDir + "/" + songName + "-hard.json";
			if (!FileSystem.exists(chartPathHard))
			{
				File.saveContent(chartPathHard, jsonString);
				trace('Hard chart created: ' + chartPathHard);
			}
			else
			{
				trace('Hard chart already exists: ' + chartPathHard);
			}
		}
		catch (e:Dynamic)
		{
			trace('Error creating base chart: ' + e);
		}
		#end
	}
	
	function copyIconFile(sourcePath:String, iconName:String):Void
	{
		#if desktop
		try
		{
			var targetDir = "assets/images/icons";
			if (!FileSystem.exists(targetDir))
			{
				FileSystem.createDirectory(targetDir);
			}
			
			var targetPath = targetDir + "/" + iconName + ".png";
			File.copy(sourcePath, targetPath);
			
			trace('Icon copied: ' + targetPath);
		}
		catch (e:Dynamic)
		{
			trace('Error copying icon: ' + e);
		}
		#end
	}
	
	function saveJSON():Void
	{
		#if desktop
		try
		{
			var jsonString = Json.stringify(songListData, null, "\t");
			File.saveContent("assets/songs/songList.json", jsonString);
			trace("songList.json saved!");
		}
		catch (e:Dynamic)
		{
			trace('Error saving JSON: ' + e);
			updateStatus("Error saving JSON");
		}
		#end
	}
	
	function loadSongList():Void
	{
		try
		{
			var fileContent:String = Assets.getText(Paths.jsonSong('songList'));
			songListData = Json.parse(fileContent);
		}
		catch (e:Dynamic)
		{
			trace("Error loading songList.json: " + e);
			songListData = {
				songsWeeks: []
			};
		}
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
		FlxG.sound.play(Paths.sound('cancelMenu'));
		
		FlxTween.tween(bgDarkener, {alpha: 0}, 0.3);
		FlxTween.tween(windowBg, {alpha: 0, "scale.x": 0.8, "scale.y": 0.8}, 0.3, {
			ease: FlxEase.backIn,
			onComplete: function(twn:FlxTween)
			{
				close();
			}
		});
	}
	
	override function update(elapsed:Float)
	{
		super.update(elapsed);
		
		// Icon selector with arrow keys
		if (FlxG.keys.justPressed.LEFT)
		{
			currentIconIndex--;
			if (currentIconIndex < 0) currentIconIndex = iconPresets.length - 1;
			iconNameInput.text = iconPresets[currentIconIndex];
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		}
		else if (FlxG.keys.justPressed.RIGHT)
		{
			currentIconIndex++;
			if (currentIconIndex >= iconPresets.length) currentIconIndex = 0;
			iconNameInput.text = iconPresets[currentIconIndex];
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		}
		
		// ESC to close
		if (FlxG.keys.justPressed.ESCAPE)
		{
			closeWindow();
		}
	}
}
