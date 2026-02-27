package funkin.menus;

#if desktop
import data.Discord.DiscordClient;
#end
import flash.text.TextField;
import flixel.FlxG;
import lime.app.Application;
import flixel.FlxSprite;
import flixel.addons.display.FlxGridOverlay;
import flixel.addons.transition.FlxTransitionableState;
import funkin.transitions.StateTransition;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.tweens.FlxEase;
import funkin.menus.StoryMenuState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import lime.utils.Assets;
import flixel.sound.FlxSound;
import openfl.utils.Assets as OpenFlAssets;
import flixel.effects.particles.FlxEmitter;
import funkin.states.LoadingState;
import flixel.effects.particles.FlxParticle;
import funkin.gameplay.objects.character.HealthIcon;
import funkin.data.Song;
import funkin.gameplay.objects.hud.Highscore;
import funkin.scripting.StateScriptHandler;
import funkin.gameplay.PlayState;
import funkin.data.Conductor;
import funkin.data.CoolUtil;
import funkin.menus.StoryMenuState.Songs;
import funkin.menus.FreeplayState.SongMetadata;
import ui.Alphabet;
import funkin.debug.DebugMenuSubState;

using StringTools;

import haxe.Json;
import haxe.format.JsonParser;

class FreeplayEditorState extends funkin.states.MusicBeatState
{
	public static var songInfo:Songs;

	var songs:Array<SongMetadata> = [];

	var selector:FlxText;
	var discSpr:FlxSprite;

	private static var curSelected:Int = 0;
	private static var curDifficulty:Int = 1;

	// Expuesto para que DebugMenuSubState pueda leerlo
	public static var curDifficultyPublic(get, never):Int;
	static function get_curDifficultyPublic():Int return curDifficulty;

	/** Acción pendiente tras cerrar DebugMenuSubState. 0 = nada, 1 = editar datos canción */
	public static var pendingAction:Int = 0;

	var scoreBG:FlxSprite;
	var scoreText:FlxText;
	var diffText:FlxText;
	var lerpScore:Int = 0;
	var lerpRating:Float = 0;
	var intendedScore:Int = 0;
	var intendedRating:Float = 0;
	var songText:Alphabet;

	private var grpSongs:FlxTypedGroup<Alphabet>;
	private var curPlaying:Bool = false;

	private var iconArray:Array<HealthIcon> = [];

	public static var coolColors:Array<Int> = [];

	var bg:FlxSprite;
	var bgGradient:FlxSprite;
	var intendedColor:Int;
	var colorTween:FlxTween;

	// Visual effects
	var particleEmitter:FlxEmitter;
	var screenBumpAmount:Float = 0;
	var bpmTarget:Float = 0;
	var beatTimer:Float = 0;
	var visualBars:FlxTypedGroup<FlxSprite>;
	var glowOverlay:FlxSprite;

	var camBumpIntensity:Float = 1.0;
	var lastScreenBumpBeat:Int = -1;

	// Drag & Drop variables
	var isDragging:Bool = false;
	var draggedIndex:Int = -1;
	var dragStartY:Float = 0;
	var draggedAlphabet:Alphabet = null;
	var draggedIcon:HealthIcon = null;
	var hoverIndex:Int = -1;

	override function create()
	{
		funkin.debug.themes.EditorTheme.load();
		transIn = FlxTransitionableState.defaultTransIn;
		transOut = FlxTransitionableState.defaultTransOut;

		MainMenuState.musicFreakyisPlaying = false;

		FlxG.mouse.visible = true;
		
		FlxG.sound.playMusic(Paths.music('chartEditorLoop/chartEditorLoop'), 0.7);

		loadSongsData();

		if (songInfo != null)
		{
			songsSystem();
		}
		else
		{
			songInfo = null;
		}

		#if desktop
		DiscordClient.changePresence("In the Freeplay Editor", null);
		#end

		// === BACKGROUND ===
		bg = new FlxSprite();
		if (Paths.image('menu/menuDesat') != null)
		{
			bg.loadGraphic(Paths.image('menu/menuDesat'));
		}
		else
		{
			bg.makeGraphic(FlxG.width, FlxG.height, funkin.debug.themes.EditorTheme.current.bgDark);
		}
		bg.color = funkin.debug.themes.EditorTheme.current.bgDark;
		bg.scrollFactor.set(0.1, 0.1);
		add(bg);

		// Gradient overlay
		bgGradient = new FlxSprite();
		bgGradient.makeGraphic(FlxG.width, FlxG.height, FlxColor.TRANSPARENT, true);
		var gradientColors:Array<Int> = [0x00000000, 0x88000000];
		for (i in 0...FlxG.height)
		{
			var ratio:Float = i / FlxG.height;
			var alpha:Int = Std.int(ratio * 0x88);
			bgGradient.pixels.fillRect(new flash.geom.Rectangle(0, i, FlxG.width, 1), alpha << 24);
		}
		bgGradient.pixels.unlock();
		add(bgGradient);

		// === VISUAL BARS ===
		visualBars = new FlxTypedGroup<FlxSprite>();
		add(visualBars);

		for (i in 0...10)
		{
			var bar:FlxSprite = new FlxSprite(0 + (i * 140), FlxG.height - 150 + 100);
			bar.makeGraphic(120, 220, FlxColor.fromRGB(100 + i * 15, 150, 255 - i * 15));
			bar.alpha = 0.3;
			bar.scrollFactor.set();
			visualBars.add(bar);
		}

		// === PARTICLE SYSTEM ===
		particleEmitter = new FlxEmitter(0, 0, 50);
		particleEmitter.makeParticles(2, 2, FlxColor.WHITE, 50);
		particleEmitter.launchMode = FlxEmitterMode.SQUARE;
		particleEmitter.velocity.set(-50, -100, 50, -200);
		particleEmitter.lifespan.set(3, 6);
		particleEmitter.alpha.set(0.4, 0.8, 0, 0);
		particleEmitter.scale.set(1, 1, 0.5, 0.5);
		particleEmitter.width = FlxG.width;
		particleEmitter.y = FlxG.height;
		add(particleEmitter);
		particleEmitter.start(false, 0.1);

		grpSongs = new FlxTypedGroup<Alphabet>();
		add(grpSongs);

		// ADD THE "+ ADD SONG" OPTION AS FIRST ITEM
		var addSongText = new Alphabet(0, 30, "+ ADD SONG", true, false);
		addSongText.isMenuItem = true;
		addSongText.targetY = 0;
		grpSongs.add(addSongText);

		// Add special icon for add song option
		var addIcon:HealthIcon = new HealthIcon("face");
		addIcon.sprTracker = addSongText;
		iconArray.push(addIcon);
		add(addIcon);

		// Add all existing songs
		for (i in 0...songs.length)
		{
			songText = new Alphabet(0, (70 * (i + 1)) + 30, songs[i].songName, true, false);
			songText.isMenuItem = true;
			songText.targetY = i + 1;
			grpSongs.add(songText);

			var icon:HealthIcon = new HealthIcon(songs[i].songCharacter);
			icon.sprTracker = songText;

			if (icon != null)
			{
				iconArray.push(icon);
				add(icon);
			}
		}

		#if HSCRIPT_ALLOWED
		StateScriptHandler.init();
		StateScriptHandler.loadStateScripts('FreeplayEditorState', this);
		StateScriptHandler.callOnScripts('onCreate', []);
		#end

		// === GLOW OVERLAY ===
		glowOverlay = new FlxSprite();
		glowOverlay.makeGraphic(FlxG.width, FlxG.height, FlxColor.WHITE);
		glowOverlay.alpha = 0;
		glowOverlay.blend = ADD;
		add(glowOverlay);

		// === UI ===
		scoreBG = new FlxSprite(FlxG.width * 0.65, 30);
		scoreBG.makeGraphic(1, 95, 0xFF000000);
		scoreBG.alpha = 0.7;
		add(scoreBG);

		scoreText = new FlxText(FlxG.width * 0.66, 45, 0, "", 28);
		scoreText.setFormat(Paths.font("vcr.ttf"), 28, FlxColor.WHITE, RIGHT);
		scoreText.setBorderStyle(OUTLINE, FlxColor.BLACK, 2);
		add(scoreText);

		diffText = new FlxText(FlxG.width * 0.66, 85, 0, "", 24);
		diffText.setFormat(Paths.font("vcr.ttf"), 24, funkin.debug.themes.EditorTheme.current.accent, RIGHT);
		diffText.setBorderStyle(OUTLINE, FlxColor.BLACK, 2);
		add(diffText);

		var ratingText:FlxText = new FlxText(FlxG.width * 0.66, 115, 0, "", 20);
		ratingText.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.YELLOW, RIGHT);
		ratingText.setBorderStyle(OUTLINE, FlxColor.BLACK, 2);
		add(ratingText);

		if (songs.length > 0)
		{
			bg.color = funkin.debug.themes.EditorTheme.current.accent; // Color for editor mode
			intendedColor = bg.color;
		}
		else
		{
			bg.color = funkin.debug.themes.EditorTheme.current.bgDark;
			intendedColor = funkin.debug.themes.EditorTheme.current.bgDark;
		}
		changeSelection();

		// === BOTTOM TEXT ===
		var textBG:FlxSprite = new FlxSprite(0, FlxG.height - 30);
		textBG.makeGraphic(FlxG.width, 30, 0xFF000000);
		textBG.alpha = 0.8;
		add(textBG);

		var leText:FlxText = new FlxText(0, FlxG.height - 26, FlxG.width, "ENTER: Add/Edit Song | SPACE: Preview | ESC: Back | DELETE: Remove Song", 16);
		leText.scrollFactor.set();
		leText.setFormat('VCR OSD Mono', 16, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(leText);

		var versionShit:FlxText = new FlxText(12, FlxG.height - 26, 0, "EDITOR MODE", 12);
		versionShit.scrollFactor.set();
		versionShit.setFormat("VCR OSD Mono", 16, funkin.debug.themes.EditorTheme.current.accent, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(versionShit);
		// ✨ Botón de tema
		var _themeBtn = new flixel.ui.FlxButton(FlxG.width - 85, 4, "\u2728 Theme", function()
		{
			openSubState(new funkin.debug.themes.ThemePickerSubState());
		});
		add(_themeBtn);

		// Entry animation
		FlxTween.tween(bg, {alpha: 1, "scale.x": 1, "scale.y": 1}, 0.6, {ease: FlxEase.expoOut});

		super.create();

		#if HSCRIPT_ALLOWED
		StateScriptHandler.callOnScripts('postCreate', []);
		#end

		#if mobileC
		addVirtualPad(FULL, A_B);
		#end
	}

	function songsSystem()
	{
		for (i in 0...songInfo.songsWeeks.length)
		{
			// En el editor siempre mostramos TODAS las canciones,
			// independientemente de si la semana está desbloqueada.
			addWeek(songInfo.songsWeeks[i].weekSongs, i, songInfo.songsWeeks[i].songIcons);
			coolColors.push(Std.parseInt(songInfo.songsWeeks[i].color[i]));
		}
	}

	function loadSongsData():Void
	{
		#if sys
		// ── Cuando hay un mod activo, solo mostrar las canciones del mod ──────
		if (mods.ModManager.isActive())
		{
			final fmt = mods.compat.ModCompatLayer.getActiveModFormat();

			if (fmt == mods.compat.ModFormat.PSYCH_ENGINE)
			{
				songInfo = { songsWeeks: [] };
				for (modWeek in mods.compat.ModCompatLayer.getModSongsInfo())
				{
					var hideFP:Bool = Reflect.field(modWeek, 'hideFreeplay') == true;
					if (!hideFP)
						songInfo.songsWeeks.push(cast modWeek);
				}
				trace('[FreeplayEditorState] Mod Psych activo "${mods.ModManager.activeMod}" — semanas: ${songInfo.songsWeeks.length}');
			}
			else
			{
				var modSongListPath = '${mods.ModManager.modRoot()}/songs/songList.json';
				var file:String = null;
				if (sys.FileSystem.exists(modSongListPath))
					file = sys.io.File.getContent(modSongListPath);

				if (file != null && file.trim() != '')
				{
					try { songInfo = cast haxe.Json.parse(file); }
					catch (e:Dynamic) { songInfo = null; }
				}

				if (songInfo == null)
				{
					songInfo = _autoDiscoverModSongs();
					if (songInfo != null)
						trace('[FreeplayEditorState] Mod "${mods.ModManager.activeMod}" — canciones auto-descubiertas: ${songInfo.songsWeeks.length} semanas');
				}
			}
			return; // No cargar canciones base
		}
		#end

		// ── Sin mod activo: cargar songList base ──────────────────────────────
		var songListPath:String = Paths.jsonSong('songList');
		var file:String = null;
		#if sys
		if (sys.FileSystem.exists(songListPath))
			file = sys.io.File.getContent(songListPath);
		#end
		if (file == null)
		{
			try { file = lime.utils.Assets.getText(songListPath); } catch (_:Dynamic) {}
		}
		try
		{
			if (file != null && file.trim() != '')
				songInfo = cast haxe.Json.parse(file);
		}
		catch (e:Dynamic)
		{
			trace("Error loading song data for " + songListPath + ": " + e);
			songInfo = null;
		}
	}

	#if sys
	/** Auto-descubre canciones desde la carpeta songs/ del mod activo como una semana única. */
	function _autoDiscoverModSongs():StoryMenuState.Songs
	{
		final modId   = mods.ModManager.activeMod;
		if (modId == null) return null;
		final songsDir = '${mods.ModManager.MODS_FOLDER}/$modId/songs';
		if (!sys.FileSystem.exists(songsDir)) return null;

		var songNames:Array<String> = [];
		var songIcons:Array<String> = [];
		var bpms:Array<Float>       = [];
		for (entry in sys.FileSystem.readDirectory(songsDir))
		{
			final ep = '$songsDir/$entry';
			if (!sys.FileSystem.isDirectory(ep)) continue;
			// Check that a chart file exists
			var hasChart = false;
			for (diff in ['hard', 'normal', 'easy', 'chart'])
				if (sys.FileSystem.exists('$ep/$diff.json')) { hasChart = true; break; }
			if (!hasChart) continue;
			songNames.push(entry);
			songIcons.push('icon-$entry');
			bpms.push(120.0);
		}
		if (songNames.length == 0) return null;

		final modInfo = mods.ModManager.getInfo(modId);
		final colorHex = modInfo != null ? StringTools.hex(modInfo.color & 0xFFFFFF, 6) : 'FF9900';
		return {
			songsWeeks: [{
				weekName:       modInfo != null ? modInfo.name : modId,
				weekSongs:      songNames,
				songIcons:      songIcons,
				color:          [colorHex],
				bpm:            bpms,
				weekCharacters: ['bf', 'gf', 'dad']
			}]
		};
	}
	#end

	public function addWeek(songs:Array<String>, weekNum:Int, ?songCharacters:Array<String>)
	{
		if (songCharacters == null)
			songCharacters = ['dad'];

		var num:Int = 0;
		for (song in songs)
		{
			addSong(song, weekNum, songCharacters[num]);
			num++;
		}
	}

	public function addSong(songName:String, weekNum:Int, songCharacter:String)
	{
		songs.push(new SongMetadata(songName, weekNum, songCharacter));
	}

	override function closeSubState()
	{
		// Si el DebugMenuSubState pidió editar datos de la canción, abrir AddSongSubState
		if (pendingAction == 1 && curSelected > 0)
		{
			pendingAction = 0;
			var songIndex = curSelected - 1;
			// Recargar la lista primero para tener datos frescos
			reloadSongList();
			changeSelection();
			super.closeSubState();
			openSubState(new AddSongSubState(songs[songIndex]));
			return;
		}

		pendingAction = 0;

		// Reload songs after closing substate (in case new song was added)
		reloadSongList();
		changeSelection();
		super.closeSubState();
	}

	function reloadSongList():Void
	{
		// Clear current lists
		songs = [];
		coolColors = [];
		
		// Clear visual elements
		grpSongs.clear();
		for (icon in iconArray)
		{
			if (icon != null)
			{
				remove(icon);
				icon.destroy();
			}
		}
		iconArray = [];

		// Reload data
		loadSongsData();
		if (songInfo != null)
		{
			songsSystem();
		}

		// Recreate the list
		// Add "+ ADD SONG" option first
		var addSongText = new Alphabet(0, 30, "+ ADD SONG", true, false);
		addSongText.isMenuItem = true;
		addSongText.targetY = 0;
		grpSongs.add(addSongText);

		var addIcon:HealthIcon = new HealthIcon("face");
		addIcon.sprTracker = addSongText;
		iconArray.push(addIcon);
		add(addIcon);

		// Add all existing songs
		for (i in 0...songs.length)
		{
			songText = new Alphabet(0, (70 * (i + 1)) + 30, songs[i].songName, true, false);
			songText.isMenuItem = true;
			songText.targetY = i + 1;
			grpSongs.add(songText);

			var icon:HealthIcon = new HealthIcon(songs[i].songCharacter);
			icon.sprTracker = songText;

			if (icon != null)
			{
				iconArray.push(icon);
				add(icon);
			}
		}

		// Reset selection
		curSelected = 0;
	}

	override function update(elapsed:Float)
	{
		#if HSCRIPT_ALLOWED
		StateScriptHandler.callOnScripts('onUpdate', [elapsed]);
		#end

		Conductor.songPosition = FlxG.sound.music.time;

		// Update visual effects
		updateScreenBump(elapsed);
		updateVisualBars(elapsed);

		if (FlxG.sound.music.volume < 0.7)
		{
			FlxG.sound.music.volume += 0.5 * FlxG.elapsed;
		}

		lerpScore = Math.floor(FlxMath.lerp(lerpScore, intendedScore, 0.4));
		lerpRating = FlxMath.lerp(lerpRating, intendedRating, 0.4);

		if (Math.abs(lerpScore - intendedScore) <= 10)
			lerpScore = intendedScore;
		if (Math.abs(lerpRating - intendedRating) <= 0.01)
			lerpRating = intendedRating;

		var ratingSplit:Array<String> = Std.string(FlxMath.roundDecimal(lerpRating * 100, 2)).split('.');
		if (ratingSplit.length < 2)
		{
			ratingSplit.push('');
		}

		while (ratingSplit[1].length < 2)
		{
			ratingSplit[1] += '0';
		}

		if (curSelected == 0)
		{
			scoreText.text = "EDITOR MODE";
		}
		else
		{
			scoreText.text = "PERSONAL BEST:" + lerpScore + ' (' + ratingSplit.join('.') + '%)';
		}

		positionHighscore();

		var upP = controls.UP_P;
		var downP = controls.DOWN_P;
		var accepted = controls.ACCEPT;

		// Drag & Drop with mouse
		handleDragAndDrop();

		if (upP)
		{
			changeSelection(-1);
		}
		if (downP)
		{
			changeSelection(1);
		}

		// DELETE key to remove song
		if (FlxG.keys.justPressed.DELETE && curSelected > 0)
		{
			removeSong(curSelected - 1);
		}

		if (controls.BACK)
		{
			#if HSCRIPT_ALLOWED
			var cancelled = StateScriptHandler.callOnScriptsReturn('onBack', [], false);
			if (cancelled)
				return;
			#end

			FlxG.sound.play(Paths.sound('menus/cancelMenu'));
			StateTransition.switchState(new FreeplayState());
		}

		if (accepted)
		{
			#if HSCRIPT_ALLOWED
			var cancelled = StateScriptHandler.callOnScriptsReturn('onAccept', [], false);
			if (cancelled)
				return;
			#end

			if (curSelected == 0)
			{
				// Abrir substate para agregar canción nueva
				FlxG.sound.play(Paths.sound('menus/confirmMenu'), 0.7);
				openSubState(new AddSongSubState());
			}
			else
			{
				// Abrir menú de selección de editor de debug
				FlxG.sound.play(Paths.sound('menus/confirmMenu'), 0.7);
				openSubState(new DebugMenuSubState(songs[curSelected - 1]));
			}
		}

		super.update(elapsed);

		#if HSCRIPT_ALLOWED
		StateScriptHandler.callOnScripts('onUpdatePost', [elapsed]);
		#end
	}

	function removeSong(songIndex:Int):Void
	{
		if (songIndex < 0 || songIndex >= songs.length)
			return;

		var songToRemove = songs[songIndex];
		
		// Find and remove from songInfo
		for (week in songInfo.songsWeeks)
		{
			var idx = week.weekSongs.indexOf(songToRemove.songName);
			if (idx != -1)
			{
				week.weekSongs.splice(idx, 1);
				week.songIcons.splice(idx, 1);
				week.color.splice(idx, 1);
				week.bpm.splice(idx, 1);
				break;
			}
		}

		// Save JSON
		saveJSON();

		// Reload list
		reloadSongList();

		FlxG.sound.play(Paths.sound('menus/cancelMenu'));
		if (FlxG.save.data.flashing)
			FlxG.camera.flash(FlxColor.RED, 0.3);
	}

	function saveJSON():Void
	{
		#if desktop
		try
		{
			var savePath:String;
			#if sys
			if (mods.ModManager.isActive())
			{
				// Si hay mod activo, guardar en la carpeta del mod
				var modDir = '${mods.ModManager.modRoot()}/songs';
				if (!sys.FileSystem.exists(modDir))
					sys.FileSystem.createDirectory(modDir);
				savePath = '$modDir/songList.json';
			}
			else
			{
				// Sin mod: guardar en assets/songs/
				var dir = 'assets/songs';
				if (!sys.FileSystem.exists(dir))
					sys.FileSystem.createDirectory(dir);
				savePath = '$dir/songList.json';
			}
			#else
			savePath = Paths.resolve("songs/songList.json");
			#end

			var jsonString = Json.stringify(songInfo, null, "\t");
			sys.io.File.saveContent(savePath, jsonString);
			trace('[FreeplayEditor] songList.json guardado en: $savePath');
		}
		catch (e:Dynamic)
		{
			trace('Error saving JSON: ' + e);
		}
		#end
	}

	function handleDragAndDrop():Void
	{
		var mouseX = FlxG.mouse.x;
		var mouseY = FlxG.mouse.y;

		if (!isDragging)
		{
			// Check if mouse is over a song (skip index 0 which is "+ ADD SONG")
			if (FlxG.mouse.justPressed)
			{
				for (i in 1...grpSongs.members.length)
				{
					var item = grpSongs.members[i];
					if (item != null && FlxG.mouse.overlaps(item))
					{
						// Start dragging
						isDragging = true;
						draggedIndex = i;
						dragStartY = mouseY;
						draggedAlphabet = item;
						draggedIcon = iconArray[i];
						
						// Visual feedback
						item.alpha = 0.6;
						if (draggedIcon != null)
							draggedIcon.alpha = 0.6;
						
						FlxG.sound.play(Paths.sound('menus/scrollMenu'), 0.4);
						break;
					}
				}
			}
		}
		else
		{
			// Currently dragging
			if (FlxG.mouse.pressed)
			{
				// Move the dragged item with mouse
				var deltaY = mouseY - dragStartY;
				if (draggedAlphabet != null)
				{
					draggedAlphabet.y = draggedAlphabet.targetY * 70 + 30 + deltaY;
				}

				// Check which position we're hovering over
				hoverIndex = -1;
				for (i in 1...grpSongs.members.length)
				{
					if (i == draggedIndex) continue;
					
					var item = grpSongs.members[i];
					if (item != null)
					{
						var itemY = item.y + item.height / 2;
						if (Math.abs(mouseY - itemY) < 35)
						{
							hoverIndex = i;
							break;
						}
					}
				}
			}
			else
			{
				// Mouse released - drop the item
				if (draggedAlphabet != null)
					draggedAlphabet.alpha = 1;
				if (draggedIcon != null)
					draggedIcon.alpha = 1;

				if (hoverIndex != -1 && hoverIndex != draggedIndex)
				{
					// Reorder songs
					reorderSong(draggedIndex, hoverIndex);
					FlxG.sound.play(Paths.sound('menus/confirmMenu'), 0.5);
				}
				else
				{
					// Return to original position
					if (draggedAlphabet != null)
					{
						FlxTween.tween(draggedAlphabet, {y: draggedAlphabet.targetY * 70 + 30}, 0.2, {ease: FlxEase.expoOut});
					}
				}

				isDragging = false;
				draggedIndex = -1;
				draggedAlphabet = null;
				draggedIcon = null;
				hoverIndex = -1;
			}
		}
	}

	function reorderSong(fromIndex:Int, toIndex:Int):Void
	{
		// Adjust for "+ ADD SONG" being at index 0
		var fromSongIndex = fromIndex - 1;
		var toSongIndex = toIndex - 1;

		// Reorder in songs array
		var movedSong = songs[fromSongIndex];
		songs.remove(movedSong);
		songs.insert(toSongIndex, movedSong);

		// Update songInfo structure
		updateSongInfoOrder();

		// Save changes
		saveJSON();

		// Reload visual list
		reloadSongList();

		// Update selection to follow the moved song
		curSelected = toIndex;
		changeSelection(0);
	}

	function updateSongInfoOrder():Void
	{
		// Rebuild songInfo based on current songs order
		// Clear existing data
		for (week in songInfo.songsWeeks)
		{
			week.weekSongs = [];
			week.songIcons = [];
			week.color = [];
			week.bpm = [];
			// NUEVO: También limpiar showInStoryMode
			if (week.showInStoryMode != null)
				week.showInStoryMode = [];
		}

		// Repopulate with current order
		for (song in songs)
		{
			// Ensure week exists
			while (songInfo.songsWeeks.length <= song.week)
			{
				songInfo.songsWeeks.push({
					weekSongs: [],
					songIcons: [],
					color: [],
					bpm: [],
					showInStoryMode: [] // NUEVO
				});
			}

			var week = songInfo.songsWeeks[song.week];
			week.weekSongs.push(song.songName);
			week.songIcons.push(song.songCharacter);
			
			// Get color from coolColors if available
			if (song.week < coolColors.length)
			{
				week.color.push(Std.string(coolColors[song.week]));
			}
			else
			{
				week.color.push(Std.string(song.color));
			}
			
			// Get BPM from songInfo if it exists
			var bpm:Float = 120; // default
			var showInStory:Bool = true; // NUEVO: default
			
			for (w in songInfo.songsWeeks)
			{
				var idx = w.weekSongs.indexOf(song.songName);
				if (idx != -1 && w.bpm.length > idx)
				{
					bpm = w.bpm[idx];
					
					// NUEVO: También obtener showInStoryMode
					if (w.showInStoryMode != null && w.showInStoryMode.length > idx)
					{
						showInStory = w.showInStoryMode[idx];
					}
					break;
				}
			}
			week.bpm.push(bpm);
			
			// NUEVO: Agregar showInStoryMode
			if (week.showInStoryMode == null)
				week.showInStoryMode = [];
			week.showInStoryMode.push(showInStory);
		}
	}

	function updateScreenBump(elapsed:Float):Void
	{
		if (FlxG.sound.music != null && FlxG.sound.music.playing)
		{
			var curBPM:Float = bpmTarget > 0 ? bpmTarget : 102;
			var songPos:Float = Conductor.songPosition;

			beatTimer += elapsed * 1000;

			var calculatedBeat:Int = Math.floor((songPos / 1000) * (curBPM / 60));

			if (calculatedBeat != lastScreenBumpBeat && calculatedBeat % 1 == 0)
			{
				lastScreenBumpBeat = calculatedBeat;
				screenBump();

				if (calculatedBeat % 4 == 0)
				{
					for (icon in iconArray)
					{
						if (icon != null && icon.scale != null)
						{
							icon.scale.set(1.3, 1.3);
							FlxTween.tween(icon.scale, {x: 1, y: 1}, 0.2, {ease: FlxEase.expoOut});
						}
					}
				}
			}
		}

		FlxG.camera.zoom = FlxMath.lerp(FlxG.camera.zoom, 1, elapsed * 3);
	}

	function screenBump():Void
	{
		FlxG.camera.zoom += 0.015 * camBumpIntensity;
		FlxG.camera.shake(0.002, 0.05);

		if (glowOverlay != null)
		{
			glowOverlay.alpha = 0.05;
			FlxTween.tween(glowOverlay, {alpha: 0}, 0.3, {ease: FlxEase.quadOut});
		}
	}

	function updateVisualBars(elapsed:Float):Void
	{
		var i:Int = 0;
		for (bar in visualBars)
		{
			if (bar != null && bar.scale != null)
			{
				var targetHeight:Float = 50 + Math.sin((beatTimer / 100) + i) * 40;
				bar.scale.y = FlxMath.lerp(bar.scale.y, targetHeight / 100, elapsed * 8);
				bar.y = FlxG.height - 150 + 100 - (bar.scale.y * 150);
			}
			i++;
		}
	}

	function changeSelection(change:Int = 0)
	{
		FlxG.sound.play(Paths.sound('menus/scrollMenu'), 0.4);

		curSelected += change;

		var maxSelection = songs.length; // +1 for the add song option (index 0)

		if (curSelected < 0)
			curSelected = maxSelection;
		if (curSelected > maxSelection)
			curSelected = 0;

		// Update color based on selection
		if (curSelected == 0)
		{
			// Add song option - special color
			var newColor:Int = funkin.debug.themes.EditorTheme.current.accent;
			if (newColor != intendedColor)
			{
				if (colorTween != null)
				{
					colorTween.cancel();
				}
				intendedColor = newColor;
				colorTween = FlxTween.color(bg, 1, bg.color, intendedColor, {
					onComplete: function(twn:FlxTween)
					{
						colorTween = null;
					}
				});
			}
		}
		else if (curSelected > 0 && curSelected <= songs.length)
		{
			// Regular song
			var newColor:Int = songs[curSelected - 1].color;
			if (newColor != intendedColor)
			{
				if (colorTween != null)
				{
					colorTween.cancel();
				}
				intendedColor = newColor;
				colorTween = FlxTween.color(bg, 1, bg.color, intendedColor, {
					onComplete: function(twn:FlxTween)
					{
						colorTween = null;
					}
				});
			}

			#if !switch
			intendedScore = Highscore.getScore(songs[curSelected - 1].songName, curDifficulty);
			intendedRating = Highscore.getRating(songs[curSelected - 1].songName, curDifficulty);
			#end
		}

		var bullShit:Int = 0;

		for (i in 0...iconArray.length)
		{
			if (iconArray[i] != null)
				iconArray[i].alpha = 0.6;
		}

		if (iconArray[curSelected] != null)
			iconArray[curSelected].alpha = 1;

		for (item in grpSongs.members)
		{
			if (item != null)
			{
				item.targetY = bullShit - curSelected;
				bullShit++;

				item.alpha = 0.6;

				if (item.targetY == 0)
				{
					item.alpha = 1;

					FlxTween.cancelTweensOf(item.scale);
					item.scale.set(1.05, 1.05);
					FlxTween.tween(item.scale, {x: 1, y: 1}, 0.3, {ease: FlxEase.expoOut});
				}
			}
		}

		FlxG.camera.zoom = 1.02;

		#if HSCRIPT_ALLOWED
		StateScriptHandler.callOnScripts('onSelectionChanged', [curSelected]);
		#end
	}

	private function positionHighscore()
	{
		scoreText.x = FlxG.width - scoreText.width - 20;

		scoreBG.scale.x = FlxG.width - scoreText.x + 16;
		scoreBG.x = FlxG.width - (scoreBG.scale.x / 2);
		diffText.x = Std.int(scoreBG.x + (scoreBG.width / 2));
		diffText.x -= diffText.width / 2;
	}

	override function destroy()
	{
		#if HSCRIPT_ALLOWED
		StateScriptHandler.callOnScripts('onDestroy', []);
		StateScriptHandler.clearStateScripts();
		#end

		super.destroy();
	}
}