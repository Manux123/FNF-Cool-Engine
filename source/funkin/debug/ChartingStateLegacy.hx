package debug;

import Conductor.BPMChangeEvent;
import Section.SwagSection;
import Song.SwagSong;
import flixel.FlxG;
import flixel.tweens.FlxTween;
import flixel.FlxSprite;
import notes.Note;
import flixel.util.FlxStringUtil;
import flixel.addons.display.FlxGridOverlay;
import flixel.addons.ui.FlxInputText;
import flixel.addons.ui.FlxUI9SliceSprite;
import flixel.addons.ui.FlxUI;
import flixel.addons.ui.FlxUICheckBox;
import flixel.addons.ui.FlxUIDropDownMenu;
import flixel.addons.ui.FlxUIInputText;
import flixel.addons.ui.FlxUINumericStepper;
import flixel.addons.ui.FlxUITabMenu;
import flixel.addons.ui.FlxUITooltip.FlxUITooltipStyle;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxGroup;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.ui.FlxButton;
import flixel.ui.FlxSpriteButton;
import flixel.util.FlxColor;
import haxe.Json;
import lime.utils.Assets;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.media.Sound;
import openfl.net.FileReference;
import openfl.utils.ByteArray;
import states.PlayState.SONG;
import extensions.CharacterList; // NEW
#if desktop
import Discord.DiscordClient;
#end

using StringTools;

class ChartingStateLegacy extends states.MusicBeatState
{
	var _file:FileReference;

	var UI_box:FlxUITabMenu;

	/**
	 * Array of notes showing when each section STARTS in STEPS
	 * Usually rounded up??
	 */
	var curSection:Int = 0;

	public static var lastSection:Int = 0;

	var bpmTxt:FlxText;

	var strumLine:FlxSprite;
	var curSong:String = 'Dadbattle';
	var amountSteps:Int = 0;
	var bullshitUI:FlxGroup;
	var bg:FlxSprite;
	var gfDropDown:FlxUIDropDownMenu;

	var highlight:FlxSprite;

	var GRID_SIZE:Int = 40;

	var dummyArrow:FlxSprite;

	var curRenderedNotes:FlxTypedGroup<Note>;
	var curRenderedSustains:FlxTypedGroup<FlxSprite>;
	var curRenderedSustains2:FlxTypedGroup<FlxSprite>;

	var gridBG:FlxSprite;

	var _song:SwagSong;

	var typingShit:FlxInputText;
	/*
	 * WILL BE THE CURRENT / LAST PLACED NOTE
	**/
	var curSelectedNote:Array<Dynamic>;

	var tempBpm:Float = 0;

	var stageDropDown:FlxUIDropDownMenu;

	var vocals:FlxSound;

	var tab_group_song:FlxUI;
	var leftIcon:HealthIcon;
	var rightIcon:HealthIcon;
	var middleIcon:HealthIcon;

	var bfDropDown:FlxUIDropDownMenu;
	var dadDropDown:FlxUIDropDownMenu;

	var quickNoteMode:Bool = false;
	var currentSnap:Int = 16; // 16 = 1/4, 32 = 1/8, etc.

	// NUEVO: Copy/Paste
	var clipboard:Array<Dynamic> = [];

	// NUEVO: Herramientas
	var hitsoundsEnabled:Bool = false;
	var metronomeEnabled:Bool = false;
	var lastMetronomeBeat:Int = -1;

	var infoText:FlxText;

	override function create()
	{

		#if desktop
		DiscordClient.changePresence("Chart Editor", null, null, true);
		#end

		curSection = lastSection;

		CharacterList.init();

		// Ahora las listas están llenas automáticamente:
		trace(CharacterList.boyfriends); // ["bf", "bf-car", "bf-pixel", ...]
		trace(CharacterList.opponents); // ["dad", "pico", "mom", ...]
		trace(CharacterList.girlfriends); // ["gf", "gf-car", "gf-pixel", ...]
		trace(CharacterList.stages); // ["stage_week1", "spooky", "philly", ...]

		bg = new FlxSprite().loadGraphic(Paths.image('menu/menuChartingBG'));
		bg.color = 0xFF453F3F;
		bg.scrollFactor.set();
		bg.antialiasing = FlxG.save.data.antialiasing;
		add(bg);

		gridBG = FlxGridOverlay.create(GRID_SIZE, GRID_SIZE, GRID_SIZE * 8, GRID_SIZE * 16);
		add(gridBG);

		leftIcon = new HealthIcon(SONG.player1, true);
		rightIcon = new HealthIcon(SONG.player2, false);
		middleIcon = new HealthIcon(SONG.gfVersion, false);
		leftIcon.scrollFactor.set(1, 1);
		rightIcon.scrollFactor.set(1, 1);
		middleIcon.scrollFactor.set(1, 1);

		leftIcon.setGraphicSize(0, 45);
		rightIcon.setGraphicSize(0, 45);
		middleIcon.setGraphicSize(0, 45);

		add(leftIcon);
		add(rightIcon);
		// add(middleIcon);

		leftIcon.setPosition(0, -100);
		rightIcon.setPosition(gridBG.width / 3, -100);
		middleIcon.setPosition(gridBG.width / 2, -100);

		var gridBlackLine:FlxSprite = new FlxSprite(gridBG.x + gridBG.width / 2).makeGraphic(2, Std.int(gridBG.height), FlxColor.BLACK);
		add(gridBlackLine);

		curRenderedNotes = new FlxTypedGroup<Note>();
		curRenderedSustains = new FlxTypedGroup<FlxSprite>();
		curRenderedSustains2 = new FlxTypedGroup<FlxSprite>();

		curStep = recalculateSteps();

		curBeat = recalculateBeats();

		if (states.PlayState.SONG != null)
			_song = states.PlayState.SONG;
		else
		{
			_song = {
				song: 'Test',
				notes: [],
				bpm: 150,
				needsVoices: true,
				player1: 'bf',
				player2: 'dad',
				gfVersion: 'gf',
				stage: 'stage_week1',
				speed: 1,
				validScore: false
			};
		}

		FlxG.mouse.visible = true;
		FlxG.save.bind('funkin', 'ninjamuffin99');

		tempBpm = _song.bpm;

		addSection();

		// sections = _song.notes;

		updateGrid();

		loadSong(_song.song);
		Conductor.changeBPM(_song.bpm);
		Conductor.mapBPMChanges(_song);

		bpmTxt = new FlxText(1000, 50, 0, "", 16);
		bpmTxt.scrollFactor.set();
		add(bpmTxt);

		strumLine = new FlxSprite(0, 50).makeGraphic(Std.int(FlxG.width / 2), 4);
		add(strumLine);

		dummyArrow = new FlxSprite().makeGraphic(GRID_SIZE, GRID_SIZE);
		add(dummyArrow);

		var tabs = [
			{name: "Song", label: 'Song'},
			{name: "Section", label: 'Section'},
			{name: "Note", label: 'Note'},
			{name: "Characters", label: 'Characters'}
		];

		UI_box = new FlxUITabMenu(null, tabs, true);

		UI_box.resize(300, 400);
		UI_box.x = FlxG.width / 2;
		UI_box.y = 20;
		add(UI_box);

		addSongUI();
		addSectionUI();
		addNoteUI();
		addCharactersUI(); // NEW

		var infoPanelBG = new FlxSprite(FlxG.width - 220, 10).makeGraphic(210, 150, FlxColor.BLACK);
		infoPanelBG.alpha = 0.7;
		add(infoPanelBG);

		infoText = new FlxText(FlxG.width - 210, 20, 200);
		infoText.setFormat(null, 12, FlxColor.WHITE, LEFT);
		add(infoText);

		add(curRenderedNotes);
		add(curRenderedSustains);
		add(curRenderedSustains2);

		super.create();
	}

	function addSongUI():Void
	{
		var UI_songTitle = new FlxUIInputText(10, 10, 70, _song.song, 8);
		typingShit = UI_songTitle;

		var check_voices = new FlxUICheckBox(10, 25, null, null, "Has voice track", 100);
		check_voices.checked = _song.needsVoices;
		// _song.needsVoices = check_voices.checked;
		check_voices.callback = function()
		{
			_song.needsVoices = check_voices.checked;
			trace('CHECKED!');
		};

		var check_mute_inst = new FlxUICheckBox(10, 200, null, null, "Mute Instrumental (in editor)", 100);
		check_mute_inst.checked = false;
		check_mute_inst.callback = function()
		{
			var vol:Float = 1;

			if (check_mute_inst.checked)
				vol = 0;

			FlxG.sound.music.volume = vol;
		};

		var saveButton:FlxButton = new FlxButton(110, 8, "Save", function()
		{
			saveLevel();
		});

		var reloadSong:FlxButton = new FlxButton(saveButton.x + saveButton.width + 10, saveButton.y, "Reload Audio", function()
		{
			loadSong(_song.song);
		});

		var reloadSongJson:FlxButton = new FlxButton(reloadSong.x, saveButton.y + 30, "Reload JSON", function()
		{
			loadJson(_song.song.toLowerCase());
		});

		var loadAutosaveBtn:FlxButton = new FlxButton(reloadSongJson.x, reloadSongJson.y + 30, 'load autosave', loadAutosave);

		var stepperSpeed:FlxUINumericStepper = new FlxUINumericStepper(10, 80, 0.1, 1, 0.1, 10, 1);
		stepperSpeed.value = _song.speed;
		stepperSpeed.name = 'song_speed';

		var stepperBPM:FlxUINumericStepper = new FlxUINumericStepper(10, 65, 1, 1, 1, 339, 0);
		stepperBPM.value = Conductor.bpm;
		stepperBPM.name = 'song_bpm';

		tab_group_song = new FlxUI(null, UI_box);
		tab_group_song.name = "Song";
		tab_group_song.add(UI_songTitle);

		tab_group_song.add(check_voices);
		tab_group_song.add(check_mute_inst);
		tab_group_song.add(saveButton);
		tab_group_song.add(reloadSong);
		tab_group_song.add(reloadSongJson);
		tab_group_song.add(loadAutosaveBtn);
		tab_group_song.add(stepperBPM);
		tab_group_song.add(stepperSpeed);/*
		tab_group_song.add(player1DropDown);
		tab_group_song.add(player2DropDown);
		tab_group_song.add(gfDropDown);
		tab_group_song.add(player3DropDown);*/

		UI_box.addGroup(tab_group_song);
		UI_box.scrollFactor.set();

		FlxG.camera.follow(strumLine);
	}

	function addCharactersUI():Void
	{
		var tab_group_characters = new FlxUI(null, UI_box);
		tab_group_characters.name = 'Characters';

		// BOYFRIEND SELECTOR
		var bfLabel:FlxText = new FlxText(10, 10, 0, 'BOYFRIEND:', 12);
		bfLabel.setFormat(null, 12, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);

		var bfList:Array<String> = CharacterList.boyfriends.map(function(char:String)
		{
			return CharacterList.getCharacterName(char);
		});

		bfDropDown = new FlxUIDropDownMenu(10, 30, FlxUIDropDownMenu.makeStrIdLabelArray(bfList, true), function(character:String)
		{
			_song.player1 = CharacterList.boyfriends[Std.parseInt(character)];
			updateHeads();
		});
		bfDropDown.selectedLabel = CharacterList.getCharacterName(_song.player1);

		// OPPONENT SELECTOR
		var dadLabel:FlxText = new FlxText(10, 90, 0, 'OPPONENT:', 12);
		dadLabel.setFormat(null, 12, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);

		var dadList:Array<String> = CharacterList.opponents.map(function(char:String)
		{
			return CharacterList.getCharacterName(char);
		});

		dadDropDown = new FlxUIDropDownMenu(10, 110, FlxUIDropDownMenu.makeStrIdLabelArray(dadList, true), function(character:String)
		{
			_song.player2 = CharacterList.opponents[Std.parseInt(character)];
			updateHeads();
		});
		dadDropDown.selectedLabel = CharacterList.getCharacterName(_song.player2);

		// GF SELECTOR (mejorar el existente)
		var gfLabel:FlxText = new FlxText(10, 170, 0, 'GIRLFRIEND:', 12);
		gfLabel.setFormat(null, 12, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);

		var gfList:Array<String> = CharacterList.girlfriends.map(function(char:String)
		{
			return CharacterList.getCharacterName(char);
		});

		gfDropDown = new FlxUIDropDownMenu(10, 190, FlxUIDropDownMenu.makeStrIdLabelArray(gfList, true), function(character:String)
		{
			_song.gfVersion = CharacterList.girlfriends[Std.parseInt(character)];
		});
		gfDropDown.selectedLabel = CharacterList.getCharacterName(_song.gfVersion);

		// STAGE SELECTOR
		var stageLabel:FlxText = new FlxText(10, 250, 0, 'STAGE:', 12);
		stageLabel.setFormat(null, 12, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);

		var stageList:Array<String> = CharacterList.stages.map(function(stage:String)
		{
			return CharacterList.getStageName(stage);
		});

		stageDropDown = new FlxUIDropDownMenu(10, 270, FlxUIDropDownMenu.makeStrIdLabelArray(stageList, true), function(stage:String)
		{
			if (_song.stage == null)
				_song.stage = CharacterList.stages[0];
			_song.stage = CharacterList.stages[Std.parseInt(stage)];
		});

		// Auto-detect stage button
		var autoStageBtn:FlxButton = new FlxButton(10, 340, "Auto-detect Stage", function()
		{
			var detectedStage = CharacterList.getDefaultStageForSong(_song.song);
			_song.stage = detectedStage;
			stageDropDown.selectedLabel = CharacterList.getStageName(detectedStage);

			// Auto-detect GF too
			var detectedGF = CharacterList.getDefaultGFForStage(detectedStage);
			_song.gfVersion = detectedGF;
			gfDropDown.selectedLabel = CharacterList.getCharacterName(detectedGF);
		});

		tab_group_characters.add(bfLabel);
		tab_group_characters.add(bfDropDown);
		tab_group_characters.add(dadLabel);
		tab_group_characters.add(dadDropDown);
		tab_group_characters.add(gfLabel);
		tab_group_characters.add(gfDropDown);
		tab_group_characters.add(stageLabel);
		tab_group_characters.add(stageDropDown);
		tab_group_characters.add(autoStageBtn);

		UI_box.addGroup(tab_group_characters);
	}

	var tab_group_section:FlxUI;
	var stepperLength:FlxUINumericStepper;
	var check_mustHitSection:FlxUICheckBox;
	var check_changeBPM:FlxUICheckBox;
	var stepperSectionBPM:FlxUINumericStepper;
	var check_altAnim:FlxUICheckBox;
	var check_gfSing:FlxUICheckBox;
	var check_bothSing:FlxUICheckBox;
	var gfs:Array<String> = CoolUtil.coolTextFile('assets/characters/gfList.txt');

	function addSectionUI():Void
	{
		tab_group_section = new FlxUI(null, UI_box);
		tab_group_section.name = 'Section';

		stepperLength = new FlxUINumericStepper(10, 10, 4, 0, 0, 999, 0);
		stepperLength.value = _song.notes[curSection].lengthInSteps;
		stepperLength.name = "section_length";

		stepperSectionBPM = new FlxUINumericStepper(10, 80, 1, Conductor.bpm, 0, 999, 0);
		stepperSectionBPM.value = Conductor.bpm;
		stepperSectionBPM.name = 'section_bpm';

		var stepperCopy:FlxUINumericStepper = new FlxUINumericStepper(110, 130, 1, 1, -999, 999, 0);

		var copyButton:FlxButton = new FlxButton(10, 130, "Copy last section", function()
		{
			copySection(/*Std.int(stepperCopy.value)*/);
		});

		var clearSectionButton:FlxButton = new FlxButton(10, 150, "Clear", clearSection);

		// stageDropDown = new FlxUIDropDownMenu(140, 200, FlxUIDropDownMenu.makeStrIdLabelArray(stages, true), function(selStage:String)			{				_song.stage = stages[Std.parseInt(selStage)];			});		stageDropDown.selectedLabel = _song.stage;
		var swapSection:FlxButton = new FlxButton(10, 170, "Swap section", function()
		{
			for (i in 0..._song.notes[curSection].sectionNotes.length)
			{
				var note = _song.notes[curSection].sectionNotes[i];
				note[1] = (note[1] + 4) % 8;
				_song.notes[curSection].sectionNotes[i] = note;
				updateGrid();
			}
		});

		check_mustHitSection = new FlxUICheckBox(10, 30, null, null, "Must hit section", 100);
		check_mustHitSection.name = 'check_mustHit';
		check_mustHitSection.checked = true;
		// _song.needsVoices = check_mustHit.checked;

		check_gfSing = new FlxUICheckBox(10, 200, null, null, "Can GF Sing in this section", 100);
		check_gfSing.name = 'check_gfSing';
		check_gfSing.checked = false;

		check_bothSing = new FlxUICheckBox(10, 250, null, null, "Dad n' GF can sing in \nthis section", 100);
		check_bothSing.name = 'check_bothSing';
		check_bothSing.checked = false;

		check_altAnim = new FlxUICheckBox(10, 400, null, null, "Alt Animation", 100);
		check_altAnim.name = 'check_altAnim';
		/*
			stageDropDown = new FlxUIDropDownMenu(140, 200, FlxUIDropDownMenu.makeStrIdLabelArray(stages, true), function(selStage:String)
				{
					_song.stage = stages[Std.parseInt(selStage)];
				});
			stageDropDown.selectedLabel = _song.stage; */

		check_changeBPM = new FlxUICheckBox(10, 60, null, null, 'Change BPM', 100);
		check_changeBPM.name = 'check_changeBPM';

		tab_group_section.add(stepperLength);
		tab_group_section.add(stepperSectionBPM);
		tab_group_section.add(stepperCopy);
		tab_group_section.add(check_mustHitSection);
		tab_group_section.add(check_gfSing);
		tab_group_section.add(check_bothSing);
		tab_group_section.add(check_altAnim);
		tab_group_section.add(check_changeBPM);
		tab_group_section.add(copyButton);
		tab_group_section.add(clearSectionButton);
		tab_group_section.add(swapSection);

		UI_box.addGroup(tab_group_section);
	}

	var stepperSusLength:FlxUINumericStepper;

	function addNoteUI():Void
	{
		var tab_group_note = new FlxUI(null, UI_box);
		tab_group_note.name = 'Note';

		stepperSusLength = new FlxUINumericStepper(10, 10, Conductor.stepCrochet / 2, 0, 0, Conductor.stepCrochet * 16);
		stepperSusLength.value = 0;
		stepperSusLength.name = 'note_susLength';

		var applyLength:FlxButton = new FlxButton(100, 10, 'Apply');

		tab_group_note.add(stepperSusLength);
		tab_group_note.add(applyLength);

		UI_box.addGroup(tab_group_note);
	}

	function loadSong(daSong:String):Void
	{
		if (FlxG.sound.music != null)
		{
			FlxG.sound.music.stop();
			// vocals.stop();
		}

		FlxG.sound.playMusic(Paths.inst(daSong), 0.6);

		// WONT WORK FOR TUTORIAL OR TEST SONG!!! REDO LATER
		vocals = new FlxSound().loadEmbedded(Paths.voices(daSong));
		FlxG.sound.list.add(vocals);

		FlxG.sound.music.pause();
		vocals.pause();

		FlxG.sound.music.onComplete = function()
		{
			vocals.pause();
			vocals.time = 0;
			FlxG.sound.music.pause();
			FlxG.sound.music.time = 0;
			changeSection();
		};
	}

	function generateUI():Void
	{
		while (bullshitUI.members.length > 0)
		{
			bullshitUI.remove(bullshitUI.members[0], true);
		}

		// general shit
		var title:FlxText = new FlxText(UI_box.x + 20, UI_box.y + 20, 0);
		bullshitUI.add(title);
		/* 
			var loopCheck = new FlxUICheckBox(UI_box.x + 10, UI_box.y + 50, null, null, "Loops", 100, ['loop check']);
			loopCheck.checked = curNoteSelected.doesLoop;
			tooltips.add(loopCheck, {title: 'Section looping', body: "Whether or not it's a simon says style section", style: tooltipType});
			bullshitUI.add(loopCheck);

		 */
	}

	override function getEvent(id:String, sender:Dynamic, data:Dynamic, ?params:Array<Dynamic>)
	{
		if (id == FlxUICheckBox.CLICK_EVENT)
		{
			var check:FlxUICheckBox = cast sender;
			var label = check.getLabel().text;
			switch (label)
			{
				case 'Must hit section':
					_song.notes[curSection].mustHitSection = check.checked;

					updateHeads();

				case 'Change BPM':
					_song.notes[curSection].changeBPM = check.checked;
					FlxG.log.add('changed bpm shit');
				case "Alt Animation":
					_song.notes[curSection].altAnim = check.checked;
				case "Can GF Sing in this section":
					_song.notes[curSection].gfSing = check.checked;
				case "Dad n' GF can sing in \nthis section":
					_song.notes[curSection].bothSing = check.checked;
			}
		}
		else if (id == FlxUINumericStepper.CHANGE_EVENT && (sender is FlxUINumericStepper))
		{
			var nums:FlxUINumericStepper = cast sender;
			var wname = nums.name;
			FlxG.log.add(wname);
			if (wname == 'section_length')
			{
				_song.notes[curSection].lengthInSteps = Std.int(nums.value);
				updateGrid();
			}
			if (wname == 'section_length')
			{
				_song.notes[curSection].lengthInSteps = Std.int(nums.value);
				updateGrid();
			}
			else if (wname == 'song_speed')
			{
				_song.speed = nums.value;
			}
			else if (wname == 'song_bpm')
			{
				tempBpm = Std.int(nums.value);
				Conductor.mapBPMChanges(_song);
				Conductor.changeBPM(Std.int(nums.value));
			}
			else if (wname == 'note_susLength')
			{
				curSelectedNote[3] = nums.value;
				updateGrid();
			}
			else if (wname == 'section_bpm')
			{
				_song.notes[curSection].bpm = Std.int(nums.value);
				updateGrid();
			}
		}

		// FlxG.log.add(id + " WEED " + sender + " WEED " + data + " WEED " + params);
	}

	var updatedSection:Bool = false;

	/* this function got owned LOL
		function lengthBpmBullshit():Float
		{
			if (_song.notes[curSection].changeBPM)
				return _song.notes[curSection].lengthInSteps * (_song.notes[curSection].bpm / _song.bpm);
			else
				return _song.notes[curSection].lengthInSteps;
	}*/
	function sectionStartTime():Float
	{
		var daBPM:Float = _song.bpm;
		var daPos:Float = 0;
		for (i in 0...curSection)
		{
			if (_song.notes[i].changeBPM)
			{
				daBPM = _song.notes[i].bpm;
			}
			daPos += 4 * (1000 * 60 / daBPM);
		}
		return daPos;
	}

	override function update(elapsed:Float)
	{
		Conductor.songPosition = FlxG.sound.music.time;
		_song.song = typingShit.text;

		infoText.text = 'TIME: ${FlxStringUtil.formatTime(FlxG.sound.music.time / 1000, false)}\n';
		infoText.text += 'BPM: ${Conductor.bpm}\n';
		infoText.text += 'SECTION: ${curSection} / ${_song.notes.length}\n';
		infoText.text += 'NOTES: ${_song.notes[curSection].sectionNotes.length}';

		strumLine.y = getYfromStrum((Conductor.songPosition - sectionStartTime()) % (Conductor.stepCrochet * _song.notes[curSection].lengthInSteps));

		// METRONOME
		if (metronomeEnabled && FlxG.sound.music.playing)
		{
			var curBeat:Int = Math.floor(curStep / 4);
			if (curBeat != lastMetronomeBeat)
			{
				FlxG.sound.play(Paths.sound('menus/scrollMenu'), 0.6);
				lastMetronomeBeat = curBeat;
			}
		}

		if (curBeat % 4 == 0 && curStep >= 16 * (curSection + 1))
		{
			trace(curStep);
			trace((_song.notes[curSection].lengthInSteps) * (curSection + 1));
			trace('DUMBSHIT');

			if (_song.notes[curSection + 1] == null)
			{
				addSection();
			}

			changeSection(curSection + 1, false);
		}

		FlxG.watch.addQuick('daBeat', curBeat);
		FlxG.watch.addQuick('daStep', curStep);

		if (FlxG.mouse.justPressed)
		{
			if (FlxG.mouse.overlaps(curRenderedNotes))
			{
				curRenderedNotes.forEach(function(note:Note)
				{
					if (FlxG.mouse.overlaps(note))
					{
						if (FlxG.keys.pressed.CONTROL)
						{
							selectNote(note);
						}
						else
						{
							trace('tryin to delete note...');
							deleteNote(note);
						}
					}
				});
			}
			else
			{
				if (FlxG.mouse.x > gridBG.x
					&& FlxG.mouse.x < gridBG.x + gridBG.width
					&& FlxG.mouse.y > gridBG.y
					&& FlxG.mouse.y < gridBG.y + (GRID_SIZE * _song.notes[curSection].lengthInSteps))
				{
					FlxG.log.add('added note');
					addNote();
				}
			}
		}

		if (FlxG.mouse.x > gridBG.x
			&& FlxG.mouse.x < gridBG.x + gridBG.width
			&& FlxG.mouse.y > gridBG.y
			&& FlxG.mouse.y < gridBG.y + (GRID_SIZE * _song.notes[curSection].lengthInSteps))
		{
			dummyArrow.x = Math.floor(FlxG.mouse.x / GRID_SIZE) * GRID_SIZE;
			if (FlxG.keys.pressed.SHIFT)
				dummyArrow.y = FlxG.mouse.y;
			else
				dummyArrow.y = Math.floor(FlxG.mouse.y / GRID_SIZE) * GRID_SIZE;
		}

		if (FlxG.keys.justPressed.ENTER)
		{
			lastSection = curSection;

			states.PlayState.SONG = _song;
			FlxG.sound.music.stop();
			vocals.stop();
			FlxG.switchState(new states.PlayState());
		}

		if (FlxG.keys.justPressed.E)
		{
			changeNoteSustain(Conductor.stepCrochet);
		}
		if (FlxG.keys.justPressed.Q)
		{
			changeNoteSustain(-Conductor.stepCrochet);
		}

		if (FlxG.keys.justPressed.TAB)
		{
			if (FlxG.keys.pressed.SHIFT)
			{
				UI_box.selected_tab -= 1;
				if (UI_box.selected_tab < 0)
					UI_box.selected_tab = 2;
			}
			else
			{
				UI_box.selected_tab += 1;
				if (UI_box.selected_tab >= 3)
					UI_box.selected_tab = 0;
			}
		}

		if (!typingShit.hasFocus)
		{
			if (FlxG.keys.justPressed.SPACE)
			{
				if (FlxG.sound.music.playing)
				{
					FlxG.sound.music.pause();
					vocals.pause();
				}
				else
				{
					vocals.play();
					FlxG.sound.music.play();
				}
			}

			if (FlxG.keys.justPressed.R)
			{
				if (FlxG.keys.pressed.SHIFT)
					resetSection(true);
				else
					resetSection();
			}

			if (FlxG.mouse.wheel != 0)
			{
				FlxG.sound.music.pause();
				vocals.pause();

				FlxG.sound.music.time -= (FlxG.mouse.wheel * Conductor.stepCrochet * 0.4);
				vocals.time = FlxG.sound.music.time;
			}

			if (!FlxG.keys.pressed.SHIFT)
			{
				if (FlxG.keys.pressed.W || FlxG.keys.pressed.S)
				{
					FlxG.sound.music.pause();
					vocals.pause();

					var daTime:Float = 700 * FlxG.elapsed;

					if (FlxG.keys.pressed.W)
					{
						FlxG.sound.music.time -= daTime;
					}
					else
						FlxG.sound.music.time += daTime;

					vocals.time = FlxG.sound.music.time;
				}
			}
			else
			{
				if (FlxG.keys.justPressed.W || FlxG.keys.justPressed.S)
				{
					FlxG.sound.music.pause();
					vocals.pause();

					var daTime:Float = Conductor.stepCrochet * 2;

					if (FlxG.keys.justPressed.W)
					{
						FlxG.sound.music.time -= daTime;
					}
					else
						FlxG.sound.music.time += daTime;

					vocals.time = FlxG.sound.music.time;
				}
			}
		}

		_song.bpm = tempBpm;

		var shiftThing:Int = 1;
		if (FlxG.keys.pressed.SHIFT)
			shiftThing = 4;
		if (FlxG.keys.justPressed.RIGHT || FlxG.keys.justPressed.D)
			changeSection(curSection + shiftThing);
		if (FlxG.keys.justPressed.LEFT || FlxG.keys.justPressed.A)
			changeSection(curSection - shiftThing);

		bpmTxt.text = bpmTxt.text = Std.string(FlxMath.roundDecimal(Conductor.songPosition / 1000, 2))
			+ " / "
			+ Std.string(FlxMath.roundDecimal(FlxG.sound.music.length / 1000, 2))
			+ "\nSection: "
			+ curSection
			+ "\nCurStep: "
			+ curStep
			+ "\nCurBeat: "
			+ curBeat;

		// NUEVO: Quick note placement con números 1-8
		if (FlxG.keys.justPressed.ONE)
			placeNoteAtCursor(0); // Purple Left (Player)
		if (FlxG.keys.justPressed.TWO)
			placeNoteAtCursor(1); // Cyan Down (Player)
		if (FlxG.keys.justPressed.THREE)
			placeNoteAtCursor(2); // Green Up (Player)
		if (FlxG.keys.justPressed.FOUR)
			placeNoteAtCursor(3); // Red Right (Player)

		if (FlxG.keys.justPressed.FIVE)
			placeNoteAtCursor(4); // Purple Left (Opponent)
		if (FlxG.keys.justPressed.SIX)
			placeNoteAtCursor(5); // Cyan Down (Opponent)
		if (FlxG.keys.justPressed.SEVEN)
			placeNoteAtCursor(6); // Green Up (Opponent)
		if (FlxG.keys.justPressed.EIGHT)
			placeNoteAtCursor(7); // Red Right (Opponent)

		// NUEVO: Copy/Paste
		if (FlxG.keys.pressed.CONTROL)
		{
			if (FlxG.keys.justPressed.C)
				copySection();
			if (FlxG.keys.justPressed.V)
				pasteSection();
			if (FlxG.keys.justPressed.X)
				cutSection();
		}

		// NUEVO: Mirror
		if (FlxG.keys.justPressed.M)
			mirrorSection();

		// NUEVO: Tools
		if (FlxG.keys.justPressed.T)
		{
			hitsoundsEnabled = !hitsoundsEnabled;
			trace('Hitsounds: ' + (hitsoundsEnabled ? 'ON' : 'OFF'));
		}

		if (FlxG.keys.justPressed.G)
		{
			metronomeEnabled = !metronomeEnabled;
			trace('Metronome: ' + (metronomeEnabled ? 'ON' : 'OFF'));
		}
		super.update(elapsed);
	}

	function changeNoteSustain(value:Float):Void
	{
		if (curSelectedNote != null)
		{
			if (curSelectedNote[2] != null)
			{
				curSelectedNote[2] += value;
				curSelectedNote[2] = Math.max(curSelectedNote[2], 0);
			}
		}

		updateNoteUI();
		updateGrid();
	}

	function recalculateSteps():Int
	{
		var lastChange:BPMChangeEvent = {
			stepTime: 0,
			songTime: 0,
			bpm: 0
		}
		for (i in 0...Conductor.bpmChangeMap.length)
		{
			if (FlxG.sound.music.time > Conductor.bpmChangeMap[i].songTime)
				lastChange = Conductor.bpmChangeMap[i];
		}

		curStep = lastChange.stepTime + Math.floor((FlxG.sound.music.time - lastChange.songTime) / Conductor.stepCrochet);
		updateBeat();

		return curStep;
	}

	function recalculateBeats():Int
	{
		curBeat = Math.floor(curStep / 4);

		return curBeat;
	}

	function resetSection(songBeginning:Bool = false):Void
	{
		updateGrid();

		FlxG.sound.music.pause();
		vocals.pause();

		// Basically old shit from changeSection???
		FlxG.sound.music.time = sectionStartTime();

		if (songBeginning)
		{
			FlxG.sound.music.time = 0;
			curSection = 0;
		}

		vocals.time = FlxG.sound.music.time;
		updateCurStep();

		updateGrid();
		updateSectionUI();
	}

	function changeSection(sec:Int = 0, ?updateMusic:Bool = true):Void
	{
		trace('changing section' + sec);

		if (_song.notes[sec] != null)
		{
			curSection = sec;

			updateGrid();

			if (updateMusic)
			{
				FlxG.sound.music.pause();
				vocals.pause();

				/*var daNum:Int = 0;
					var daLength:Float = 0;
					while (daNum <= sec)
					{
						daLength += lengthBpmBullshit();
						daNum++;
				}*/

				FlxG.sound.music.time = sectionStartTime();
				vocals.time = FlxG.sound.music.time;
				updateCurStep();
			}

			updateGrid();
			updateSectionUI();
		}
	}
/*
	function copySection(?sectionNum:Int = 1)
	{
		var daSec = FlxMath.maxInt(curSection, sectionNum);

		for (note in _song.notes[daSec - sectionNum].sectionNotes)
		{
			var strum = note[0] + Conductor.stepCrochet * (_song.notes[daSec].lengthInSteps * sectionNum);

			var copiedNote:Array<Dynamic> = [strum, note[1], note[2]];
			_song.notes[daSec].sectionNotes.push(copiedNote);
		}

		updateGrid();
	}*/

	function updateSectionUI():Void
	{
		var sec = _song.notes[curSection];

		stepperLength.value = sec.lengthInSteps;
		check_mustHitSection.checked = sec.mustHitSection;
		check_altAnim.checked = sec.altAnim;
		check_changeBPM.checked = sec.changeBPM;
		stepperSectionBPM.value = sec.bpm;

		updateHeads();
	}

	function updateHeads():Void
	{
		if (leftIcon != null)
		{
			remove(leftIcon);
			leftIcon.destroy();
		}

		if (rightIcon != null)
		{
			remove(rightIcon);
			rightIcon.destroy();
		}

		if (middleIcon != null)
		{
			remove(middleIcon);
			middleIcon.destroy();
		}

		// Actualizar según must hit section
		var iconP1:String = _song.player1;
		var iconP2:String = _song.player2;

		if (_song.notes[curSection].mustHitSection)
		{
			leftIcon = new HealthIcon(iconP1);
			rightIcon = new HealthIcon(iconP2);
		}
		else
		{
			leftIcon = new HealthIcon(iconP2);
			rightIcon = new HealthIcon(iconP1);
		}

		middleIcon = new HealthIcon(_song.gfVersion);

		leftIcon.setPosition(0, 0);
		rightIcon.setPosition(gridBG.width / 2, 0);
		middleIcon.setPosition(gridBG.width / 4, 0);

		leftIcon.setGraphicSize(0, 45);
		rightIcon.setGraphicSize(0, 45);
		middleIcon.setGraphicSize(0, 45);

		add(leftIcon);
		add(rightIcon);
		add(middleIcon);

		leftIcon.updateHitbox();
		rightIcon.updateHitbox();
		middleIcon.updateHitbox();
	}

	function updateNoteUI():Void
	{
		if (curSelectedNote != null)
			stepperSusLength.value = curSelectedNote[2];
	}

	function updateGrid():Void
	{
		// En updateGrid(), busca donde se crea el sprite de la nota
		// y reemplaza con estos colores:

		// Usa noteColors[note.noteData % 8] para colorear
		while (curRenderedNotes.members.length > 0)
		{
			curRenderedNotes.remove(curRenderedNotes.members[0], true);
		}

		while (curRenderedSustains.members.length > 0)
		{
			curRenderedSustains.remove(curRenderedSustains.members[0], true);
		}

		while (curRenderedSustains2.members.length > 0)
		{
			curRenderedSustains2.remove(curRenderedSustains2.members[0], true);
		}

		var sectionInfo:Array<Dynamic> = _song.notes[curSection].sectionNotes;

		if (_song.notes[curSection].changeBPM && _song.notes[curSection].bpm > 0)
		{
			Conductor.changeBPM(_song.notes[curSection].bpm);
			FlxG.log.add('CHANGED BPM!');
		}
		else
		{
			// get last bpm
			var daBPM:Float = _song.bpm;
			for (i in 0...curSection)
				if (_song.notes[i].changeBPM)
					daBPM = _song.notes[i].bpm;
			Conductor.changeBPM(daBPM);
		}

		for (i in sectionInfo)
		{
			var daNoteInfo = i[1];
			var daStrumTime = i[0];
			var daSus = i[2];

			var note:Note = new Note(daStrumTime, daNoteInfo % 4);
			note.sustainLength = daSus;
			note.setGraphicSize(GRID_SIZE, GRID_SIZE);
			note.updateHitbox();
			note.x = Math.floor(daNoteInfo * GRID_SIZE);
			note.y = Math.floor(getYfromStrum((daStrumTime - sectionStartTime()) % (Conductor.stepCrochet * _song.notes[curSection].lengthInSteps)));

			curRenderedNotes.add(note);

			if (daSus > 0)
			{
				var sustainVis:FlxSprite = new FlxSprite(note.x + (GRID_SIZE / 3),
					note.y + GRID_SIZE).makeGraphic(8, Math.floor(FlxMath.remapToRange(daSus, 0, Conductor.stepCrochet * 16, 0, gridBG.height)));
				curRenderedSustains.add(sustainVis);
			}
		}
	}

	private function addSection(lengthInSteps:Int = 16):Void
	{
		var sec:SwagSection = {
			lengthInSteps: lengthInSteps,
			bpm: _song.bpm,
			changeBPM: false,
			mustHitSection: true,
			sectionNotes: [],
			typeOfSection: 0,
			stage: 'stage_week1',
			altAnim: false,
			gfSing: false,
			bothSing: false
		};

		_song.notes.push(sec);
	}

	function selectNote(note:Note):Void
	{
		var swagNum:Int = 0;

		for (i in _song.notes[curSection].sectionNotes)
		{
			if (i.strumTime == note.strumTime && i.noteData % 4 == note.noteData)
			{
				curSelectedNote = _song.notes[curSection].sectionNotes[swagNum];
			}

			swagNum += 1;
		}

		updateGrid();
		updateNoteUI();
	}

	function deleteNote(note:Note):Void
	{
		for (i in _song.notes[curSection].sectionNotes)
		{
			if (i[0] == note.strumTime && i[1] % 4 == note.noteData)
			{
				FlxG.log.add('FOUND EVIL NUMBER');
				_song.notes[curSection].sectionNotes.remove(i);
			}
		}

		updateGrid();
	}

	function clearSection():Void
	{
		_song.notes[curSection].sectionNotes = [];

		updateGrid();
	}

	function clearSong():Void
	{
		for (daSection in 0..._song.notes.length)
		{
			_song.notes[daSection].sectionNotes = [];
		}

		updateGrid();
	}

	private function addNote():Void
	{
		var noteStrum = getStrumTime(dummyArrow.y) + sectionStartTime();
		var noteData = Math.floor(FlxG.mouse.x / GRID_SIZE);
		var noteSus = 0;

		_song.notes[curSection].sectionNotes.push([noteStrum, noteData, noteSus]);

		curSelectedNote = _song.notes[curSection].sectionNotes[_song.notes[curSection].sectionNotes.length - 1];

		if (FlxG.keys.pressed.CONTROL)
		{
			_song.notes[curSection].sectionNotes.push([noteStrum, (noteData + 4) % 8, noteSus]);
		}

		trace(noteStrum);
		trace(curSection);

		updateGrid();
		updateNoteUI();

		autosaveSong();
	}

	function getYfromStrum(strumTime:Float):Float
	{
		return FlxMath.remapToRange(strumTime, 0, 16 * Conductor.stepCrochet, gridBG.y, gridBG.y + gridBG.height);
	}

	/*
		function calculateSectionLengths(?sec:SwagSection):Int
		{
			var daLength:Int = 0;

			for (i in _song.notes)
			{
				var swagLength = i.lengthInSteps;

				if (i.typeOfSection == Section.COPYCAT)
					swagLength * 2;

				daLength += swagLength;

				if (sec != null && sec == i)
				{
					trace('swag loop??');
					break;
				}
			}

			return daLength;
	}*/
	private var daSpacing:Float = 0.3;

	function loadLevel():Void
	{
		trace(_song.notes);
	}

	function getNotes():Array<Dynamic>
	{
		var noteData:Array<Dynamic> = [];

		for (i in _song.notes)
		{
			noteData.push(i.sectionNotes);
		}

		return noteData;
	}

	function loadJson(song:String):Void
	{
		// Después de cargar el JSON
		if (_song.stage == null || _song.stage == '')
		{
			_song.stage = CharacterList.getDefaultStageForSong(_song.song);
		}

		if (_song.gfVersion == null || _song.gfVersion == '')
		{
			_song.gfVersion = CharacterList.getDefaultGFForStage(_song.stage);
		}
		states.PlayState.SONG = Song.loadFromJson(song.toLowerCase(), song.toLowerCase());
		FlxG.resetState();
	}

	function loadAutosave():Void
	{
		states.PlayState.SONG = Song.parseJSONshit(FlxG.save.data.autosave);
		FlxG.resetState();
	}

	function autosaveSong():Void
	{
		FlxG.save.data.autosave = Json.stringify({
			"song": _song
		});
		FlxG.save.flush();
	}

	private function saveLevel()
	{
		var json = {
			"song": _song
		};

		var data:String = Json.stringify(json);

		if ((data != null) && (data.length > 0))
		{
			_file = new FileReference();
			_file.addEventListener(Event.COMPLETE, onSaveComplete);
			_file.addEventListener(Event.CANCEL, onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file.save(data.trim(), _song.song.toLowerCase() + ".json");
		}
	}

	function onSaveComplete(_):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		FlxG.log.notice("Successfully saved LEVEL DATA.");
	}

	/**
	 * Called when the save file dialog is cancelled.
	 */
	function onSaveCancel(_):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
	}

	/**
	 * Called if there is an error while saving the gameplay recording.
	 */
	function onSaveError(_):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		FlxG.log.error("Problem saving Level data");
	}

	function placeNoteAtCursor(column:Int):Void
	{
		var noteStrum = getStrumTime(FlxG.mouse.y);
		var noteData = column;
		var noteSus = 0;

		// Check if note already exists at this position
		var noteExists:Bool = false;
		for (i in _song.notes[curSection].sectionNotes)
		{
			if (i[0] == noteStrum && i[1] == noteData)
			{
				_song.notes[curSection].sectionNotes.remove(i);
				noteExists = true;
				break;
			}
		}

		// If note didn't exist, create it
		if (!noteExists)
		{
			_song.notes[curSection].sectionNotes.push([noteStrum, noteData, noteSus]);

			// Play hitsound
			if (hitsoundsEnabled)
				FlxG.sound.play(Paths.sound('menus/scrollMenu'), 0.4);
		}

		updateGrid();
		updateNoteUI();
	}

	function getStrumTime(yPos:Float):Float
	{
		return FlxMath.remapToRange(yPos, gridBG.y, gridBG.y + gridBG.height, 0, 16 * Conductor.stepCrochet);
	}

	function copySection():Void
	{
		clipboard = [];
		for (note in _song.notes[curSection].sectionNotes)
		{
			clipboard.push([note[0], note[1], note[2]]);
		}
		trace('Copied ${clipboard.length} notes');
	}

	function pasteSection():Void
	{
		if (clipboard.length == 0)
		{
			trace('Clipboard is empty!');
			return;
		}

		_song.notes[curSection].sectionNotes = [];
		for (note in clipboard)
		{
			_song.notes[curSection].sectionNotes.push([note[0], note[1], note[2]]);
		}

		updateGrid();
		trace('Pasted ${clipboard.length} notes');
	}

	function cutSection():Void
	{
		copySection();
		_song.notes[curSection].sectionNotes = [];
		updateGrid();
		trace('Cut section');
	}

	function mirrorSection():Void
	{
		for (note in _song.notes[curSection].sectionNotes)
		{
			// Swap player <-> opponent (0-3 <-> 4-7)
			var noteData:Int = note[1];
			if (noteData < 4)
				note[1] = noteData + 4;
			else
				note[1] = noteData - 4;
		}

		updateGrid();
		trace('Mirrored section');
	}
}
