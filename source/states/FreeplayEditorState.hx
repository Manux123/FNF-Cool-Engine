package states;

#if desktop
import Discord.DiscordClient;
#end
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.math.FlxMath;
import flixel.sound.FlxSound;
import flixel.ui.FlxButton;
import flixel.addons.ui.FlxInputText;
import haxe.Json;
import lime.utils.Assets;
import sys.io.File;
import sys.FileSystem;
import flixel.group.FlxSpriteGroup;
import states.FreeplayState.Songs;

#if desktop
import lime.ui.FileDialog;
#end

using StringTools;

class FreeplayEditorState extends MusicBeatState
{
	// === BACKGROUND ===
	var bg:FlxSprite;
	var overlay:FlxSprite;
	
	// === PANELS ===
	var leftPanel:FlxSprite;
	var rightPanel:FlxSprite;
	var topBar:FlxSprite;
	
	// === TEXT ELEMENTS ===
	var titleText:FlxText;
	var infoText:FlxText;
	var statusText:FlxText;
	
	// === INPUT FIELDS ===
	var songNameInput:FlxInputText;
	var iconNameInput:FlxInputText;
	var bpmInput:FlxInputText;
	var weekInput:FlxInputText;
	var selectedColor:String = "0xFFFFFFFF";
	
	// === BUTTONS ===
	var addSongBtn:FlxButton;
	var saveJsonBtn:FlxButton;
	var loadInstBtn:FlxButton;
	var loadVocalsBtn:FlxButton;
	var backBtn:FlxButton;
	var newWeekBtn:FlxButton;
	var previewSongBtn:FlxButton;
	
	// === COLOR PICKER ===
	var colorButtons:Array<FlxButton> = [];
	var colorLabels:Array<FlxText> = [];
	
	// === PREVIEW ===
	var previewGroup:FlxTypedGroup<PreviewItem>;
	var scrollOffset:Float = 0;
	var maxScroll:Float = 0;
	
	// === DATA ===
	var songListData:Songs;
	var currentInstPath:String = "";
	var currentVocalsPath:String = "";
	var instLoaded:Bool = false;
	var vocalsLoaded:Bool = false;
	
	// === PREVIEW MUSIC ===
	var previewMusic:FlxSound;
	
	// === COMMON ICONS ===
	var iconPresets:Array<String> = [
		"bf", "bf-pixel", "gf", "dad", "mom", "pico", 
		"spooky", "monster", "parents", "senpai", "spirit"
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
	
	override function create()
	{
		#if desktop
		DiscordClient.changePresence("Freeplay Editor", null);
		#end

        FlxG.mouse.visible = true;
		
		// Load existing songList
		loadSongList();
		
		// === BACKGROUND ===
		bg = new FlxSprite();
		bg.makeGraphic(FlxG.width, FlxG.height, 0xFF1a1a2e);
		add(bg);
		
		// Gradient overlay
		overlay = new FlxSprite();
		overlay.makeGraphic(FlxG.width, FlxG.height, FlxColor.TRANSPARENT, true);
		for (i in 0...FlxG.height)
		{
			var ratio:Float = i / FlxG.height;
			var alpha:Int = Std.int(ratio * 0x40);
			overlay.pixels.fillRect(new flash.geom.Rectangle(0, i, FlxG.width, 1), 
				FlxColor.fromRGB(26, 26, 46, alpha));
		}
		overlay.pixels.unlock();
		add(overlay);
		
		// === TOP BAR ===
		topBar = new FlxSprite(0, 0);
		topBar.makeGraphic(FlxG.width, 80, 0xFF16213e);
		add(topBar);
		
		titleText = new FlxText(20, 15, 0, "FREEPLAY EDITOR", 32);
		titleText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, LEFT);
		titleText.setBorderStyle(OUTLINE, 0xFF0f3460, 3);
		add(titleText);
		
		infoText = new FlxText(20, 50, 0, "Add songs to Freeplay • View in real time", 16);
		infoText.setFormat(Paths.font("vcr.ttf"), 16, 0xFF53a8b6, LEFT);
		add(infoText);
		
		// === LEFT PANEL (EDITOR) ===
		leftPanel = new FlxSprite(20, 100);
		leftPanel.makeGraphic(550, 580, 0xFF16213e);
		leftPanel.alpha = 0.95;
		add(leftPanel);
		
		// === RIGHT PANEL (PREVIEW) ===
		rightPanel = new FlxSprite(590, 100);
		rightPanel.makeGraphic(670, 580, 0xFF16213e);
		rightPanel.alpha = 0.95;
		add(rightPanel);
		
		// === STATUS BAR ===
		statusText = new FlxText(0, FlxG.height - 25, FlxG.width, "Ready for add songs", 14);
		statusText.setFormat(Paths.font("vcr.ttf"), 14, FlxColor.WHITE, CENTER);
		statusText.setBorderStyle(OUTLINE, FlxColor.BLACK, 2);
		add(statusText);
		
		// === BUILD UI ===
		createInputFields();
		createButtons();
		createColorPicker();
		createPreview();
		
		super.create();
	}
	
	function createInputFields():Void
	{
		var startY:Float = 120;
		var inputWidth:Int = 500;
		
		// Song Name
		var label1 = new FlxText(40, startY, 0, "Song Name:", 18);
		label1.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, LEFT);
		add(label1);
		
		songNameInput = new FlxInputText(40, startY + 25, inputWidth, "", 16);
		songNameInput.backgroundColor = 0xFF0f3460;
		songNameInput.fieldBorderColor = 0xFF53a8b6;
		songNameInput.fieldBorderThickness = 2;
		songNameInput.color = FlxColor.WHITE;
		songNameInput.maxLength = 50;
		add(songNameInput);
		
		// Icon Name
		startY += 80;
		var label2 = new FlxText(40, startY, 0, "Icon (use arrows ← →):", 18);
		label2.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, LEFT);
		add(label2);
		
		iconNameInput = new FlxInputText(40, startY + 25, inputWidth, iconPresets[0], 16);
		iconNameInput.backgroundColor = 0xFF0f3460;
		iconNameInput.fieldBorderColor = 0xFF53a8b6;
		iconNameInput.fieldBorderThickness = 2;
		iconNameInput.color = FlxColor.WHITE;
		iconNameInput.maxLength = 30;
		add(iconNameInput);
		
		// BPM
		startY += 80;
		var label3 = new FlxText(40, startY, 0, "BPM:", 18);
		label3.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, LEFT);
		add(label3);
		
		bpmInput = new FlxInputText(40, startY + 25, 240, "120", 16);
		bpmInput.backgroundColor = 0xFF0f3460;
		bpmInput.fieldBorderColor = 0xFF53a8b6;
		bpmInput.fieldBorderThickness = 2;
		bpmInput.color = FlxColor.WHITE;
		bpmInput.filterMode = FlxInputText.ONLY_NUMERIC;
		add(bpmInput);
		
		// Week Index
		var label4 = new FlxText(300, startY, 0, "Week:", 18);
		label4.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, LEFT);
		add(label4);
		
		weekInput = new FlxInputText(300, startY + 25, 240, "0", 16);
		weekInput.backgroundColor = 0xFF0f3460;
		weekInput.fieldBorderColor = 0xFF53a8b6;
		weekInput.fieldBorderThickness = 2;
		weekInput.color = FlxColor.WHITE;
		weekInput.filterMode = FlxInputText.ONLY_NUMERIC;
		add(weekInput);
	}
	
	function createButtons():Void
	{
		var btnY:Float = 560;
		
		// Load Inst Button
		loadInstBtn = new FlxButton(40, btnY, "Load Inst.ogg", function()
		{
			#if desktop
			var dialog = new FileDialog();
			dialog.onSelect.add(function(path:String)
			{
				currentInstPath = path;
				instLoaded = true;
				loadInstBtn.label.text = "✓ Loaded Inst";
				loadInstBtn.label.color = 0xFF00FF00;
				updateStatus("Loaded Inst.ogg properly");
			});
			dialog.browse(OPEN, "ogg", null, "Choose Inst.ogg");
			#else
			updateStatus("Loading files is only available on Desktop");
			#end
		});
		styleButton(loadInstBtn, 0xFF4a5568, 240);
		add(loadInstBtn);
		
		// Load Vocals Button
		loadVocalsBtn = new FlxButton(300, btnY, "Load Vocals.ogg", function()
		{
			#if desktop
			var dialog = new FileDialog();
			dialog.onSelect.add(function(path:String)
			{
				currentVocalsPath = path;
				vocalsLoaded = true;
				loadVocalsBtn.label.text = "✓ Loaded Vocals!";
				loadVocalsBtn.label.color = 0xFF00FF00;
				updateStatus("Loaded Vocals.ogg correctly");
			});
			dialog.browse(OPEN, "ogg", null, "Choose Vocals.ogg");
			#else
			updateStatus("Loading files is only available on Desktop");
			#end
		});
		styleButton(loadVocalsBtn, 0xFF4a5568, 240);
		add(loadVocalsBtn);
		
		btnY += 50;
		
		// Add Song Button
		addSongBtn = new FlxButton(40, btnY, "ADD SONG", addSongToList);
		styleButton(addSongBtn, 0xFF00a8cc, 320);
		addSongBtn.label.size = 20;
		add(addSongBtn);
		
		// Save JSON Button
		saveJsonBtn = new FlxButton(380, btnY, "SAVE JSON", saveJSON);
		styleButton(saveJsonBtn, 0xFF00d9ff, 160);
		add(saveJsonBtn);
		
		// New Week Button
		newWeekBtn = new FlxButton(40, btnY + 50, "NEW WEEK", addNewWeek);
		styleButton(newWeekBtn, 0xFF7209b7, 160);
		add(newWeekBtn);
		
		// Preview Song Button
		previewSongBtn = new FlxButton(220, btnY + 50, "PREVIEW SONG", previewCurrentSong);
		styleButton(previewSongBtn, 0xFFf72585, 160);
		add(previewSongBtn);
		
		// Back Button
		backBtn = new FlxButton(400, btnY + 50, "BACK", function()
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			FlxG.switchState(new MainMenuState());
		});
		styleButton(backBtn, 0xFFe63946, 140);
		add(backBtn);
	}
	
	function createColorPicker():Void
	{
		var startY:Float = 380;
		var label = new FlxText(40, startY, 0, "BG Color:", 18);
		label.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, LEFT);
		add(label);
		
		startY += 30;
		var btnX:Float = 40;
		var btnSize:Int = 40;
		var padding:Int = 5;
		
		for (i in 0...colorPresets.length)
		{
			var preset = colorPresets[i];
			var btn = new FlxButton(btnX, startY, "", function()
			{
				selectedColor = preset.hex;
				updateColorSelection();
				updateStatus("Selected Color: " + preset.name);
			});
			
			btn.makeGraphic(btnSize, btnSize, Std.parseInt(preset.hex));
			colorButtons.push(btn);
			add(btn);
			
			// Label
			var colorLabel = new FlxText(btnX, startY + btnSize + 2, btnSize, preset.name, 8);
			colorLabel.setFormat(Paths.font("vcr.ttf"), 8, FlxColor.WHITE, CENTER);
			colorLabel.alpha = 0.7;
			colorLabels.push(colorLabel);
			add(colorLabel);
			
			btnX += btnSize + padding;
			if ((i + 1) % 6 == 0)
			{
				btnX = 40;
				startY += btnSize + 20;
			}
		}
	}
	
	function createPreview():Void
	{
		previewGroup = new FlxTypedGroup<PreviewItem>();
		add(previewGroup);
		
		var headerText = new FlxText(610, 115, 0, "PREVIEW IN REAL TIME", 24);
		headerText.setFormat(Paths.font("vcr.ttf"), 24, 0xFF53a8b6, LEFT);
		headerText.setBorderStyle(OUTLINE, FlxColor.BLACK, 2);
		add(headerText);
		
		var subText = new FlxText(610, 145, 0, "FREEPLAY PREVIEW:", 14);
		subText.setFormat(Paths.font("vcr.ttf"), 14, FlxColor.WHITE, LEFT);
		subText.alpha = 0.7;
		add(subText);
		
		updatePreview();
	}
	
	function updatePreview():Void
	{
		previewGroup.clear();
		
		var yPos:Float = 180 - scrollOffset;
		var index:Int = 0;
		
		if (songListData != null && songListData.songsWeeks != null)
		{
			for (week in songListData.songsWeeks)
			{
				for (i in 0...week.weekSongs.length)
				{
					if (yPos > 160 && yPos < 670)
					{
						var item = new PreviewItem(
							610, 
							yPos, 
							week.weekSongs[i],
							week.songIcons[i],
							week.color[i],
							week.bpm[i],
							index
						);
						previewGroup.add(item);
					}
					yPos += 65;
					index++;
				}
			}
		}
		
		maxScroll = Math.max(0, (index * 65) - 400);
	}
	
	function styleButton(btn:FlxButton, color:Int, width:Int):Void
	{
		btn.makeGraphic(width, 40, color);
		btn.label.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER);
		btn.label.setBorderStyle(OUTLINE, FlxColor.BLACK, 2);
		btn.onOver.callback = function()
		{
			FlxTween.tween(btn, {"scale.x": 1.05, "scale.y": 1.05}, 0.1);
		};
		btn.onOut.callback = function()
		{
			FlxTween.tween(btn, {"scale.x": 1, "scale.y": 1}, 0.1);
		};
	}
	
	function updateColorSelection():Void
	{
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
	
	function addSongToList():Void
	{
		var songName = songNameInput.text.trim();
		
		if (songName == "")
		{
			updateStatus("Oops! You must enter the name of the song");
			FlxG.sound.play(Paths.sound('cancelMenu'));
			return;
		}
		
		var weekIndex:Null<Int> = Std.parseInt(weekInput.text);
		if (weekIndex == null) weekIndex = 0;
		
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
		
		var bpmVal:Float = Std.parseFloat(bpmInput.text);
		if (Math.isNaN(bpmVal) || bpmVal <= 0) bpmVal = 120;
		week.bpm.push(bpmVal);
		
		// Copy files if loaded
		#if desktop
		if (instLoaded && currentInstPath != "")
		{
			copySongFile(currentInstPath, songName, "Inst");
		}
		if (vocalsLoaded && currentVocalsPath != "")
		{
			copySongFile(currentVocalsPath, songName, "Voices");
		}
		#end
		
		// Update preview
		updatePreview();
		
		// Reset form
		resetForm();
		
		FlxG.sound.play(Paths.sound('confirmMenu'));
		updateStatus('✓ Song "' + songName + '" was added to Week ' + weekIndex);
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
			
			trace('Archivo copiado: ' + targetPath);
		}
		catch (e:Dynamic)
		{
			trace('Error copiando archivo: ' + e);
			updateStatus("Error copying file " + fileType + ".ogg");
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
			
			FlxG.sound.play(Paths.sound('confirmMenu'));
			updateStatus("✓ songList.json saved!");
			
			// Visual feedback
			FlxG.camera.flash(FlxColor.GREEN, 0.3);
		}
		catch (e:Dynamic)
		{
			trace('Error guardando JSON: ' + e);
			updateStatus("Error saving JSON: " + e);
			FlxG.sound.play(Paths.sound('cancelMenu'));
		}
		#else
		updateStatus("Saving JSON is only available on Desktop");
		#end
	}
	
	function loadSongList():Void
	{
		try
		{
			var fileContent:String = Assets.getText(Paths.jsonSong('songList'));
			songListData = Json.parse(fileContent);
			trace("songList.json cargado correctamente");
		}
		catch (e:Dynamic)
		{
			trace("Error cargando songList.json: " + e);
			// Create default structure
			songListData = {
				songsWeeks: []
			};
		}
	}
	
	function addNewWeek():Void
	{
		songListData.songsWeeks.push({
			weekSongs: [],
			songIcons: [],
			color: [],
			bpm: []
		});
		
		weekInput.text = Std.string(songListData.songsWeeks.length - 1);
		updateStatus("✓ Created new Week " + (songListData.songsWeeks.length - 1));
		FlxG.sound.play(Paths.sound('scrollMenu'));
	}
	
	function previewCurrentSong():Void
	{
		if (!instLoaded || currentInstPath == "")
		{
			updateStatus("You must load an Inst.ogg file first");
			FlxG.sound.play(Paths.sound('cancelMenu'));
			return;
		}
		
		#if desktop
		try
		{
			if (previewMusic != null)
			{
				previewMusic.stop();
				previewMusic.destroy();
			}
			
			previewMusic = new FlxSound();
			previewMusic.loadEmbedded(currentInstPath, false);
			previewMusic.play();
			previewMusic.volume = 0.7;
			
			updateStatus("♪ Playing preview...");
		}
		catch (e:Dynamic)
		{
			updateStatus("Error playing music: " + e);
		}
		#end
	}
	
	function resetForm():Void
	{
		songNameInput.text = "";
		currentInstPath = "";
		currentVocalsPath = "";
		instLoaded = false;
		vocalsLoaded = false;
		loadInstBtn.label.text = "Load Inst.ogg";
		loadInstBtn.label.color = FlxColor.WHITE;
		loadVocalsBtn.label.text = "Load Vocals.ogg";
		loadVocalsBtn.label.color = FlxColor.WHITE;
	}
	
	function updateStatus(text:String):Void
	{
		statusText.text = text;
		FlxTween.cancelTweensOf(statusText);
		statusText.alpha = 1;
		statusText.scale.set(1.1, 1.1);
		FlxTween.tween(statusText.scale, {x: 1, y: 1}, 0.2);
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
		
		// Scroll preview with mouse wheel
		if (FlxG.mouse.wheel != 0)
		{
			scrollOffset -= FlxG.mouse.wheel * 30;
			scrollOffset = FlxMath.bound(scrollOffset, 0, maxScroll);
			updatePreview();
		}
		
		// ESC to go back
		if (FlxG.keys.justPressed.ESCAPE)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			FlxG.switchState(new MainMenuState());
            FlxG.mouse.visible = true;
		}
	}
	
	override function destroy()
	{
		if (previewMusic != null)
		{
			previewMusic.stop();
			previewMusic.destroy();
		}
		super.destroy();
	}
}

// === PREVIEW ITEM CLASS ===
class PreviewItem extends FlxSpriteGroup
{
	var songText:FlxText;
	var iconSprite:FlxSprite;
	var bpmText:FlxText;
	var bgBar:FlxSprite;
	
	public function new(x:Float, y:Float, songName:String, icon:String, colorHex:String, bpm:Float, index:Int)
	{
		super(x, y);
		
		// Background bar
		bgBar = new FlxSprite(x, y);
		bgBar.makeGraphic(630, 55, FlxColor.BLACK);
		bgBar.alpha = 0.3;
		
		// Color indicator
		var colorBar = new FlxSprite(x, y);
		colorBar.makeGraphic(5, 55, Std.parseInt(colorHex));
		
		// Song name
		songText = new FlxText(x + 70, y + 10, 0, songName, 20);
		songText.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, LEFT);
		songText.setBorderStyle(OUTLINE, FlxColor.BLACK, 2);
		
		// BPM info
		bpmText = new FlxText(x + 70, y + 32, 0, Std.int(bpm) + " BPM • " + icon, 12);
		bpmText.setFormat(Paths.font("vcr.ttf"), 12, 0xFF53a8b6, LEFT);
		bpmText.alpha = 0.8;
		
		// Icon circle
		iconSprite = new FlxSprite(x + 15, y + 8);
		iconSprite.makeGraphic(40, 40, Std.parseInt(colorHex));
		iconSprite.alpha = 0.8;
		
		// Add text on icon
		var iconText = new FlxText(x + 15, y + 18, 40, icon.substr(0, 2).toUpperCase(), 16);
		iconText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER);
		iconText.setBorderStyle(OUTLINE, FlxColor.BLACK, 2);
	}
}
