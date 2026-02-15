package funkin.menus;

import funkin.cutscenes.MP4Handler;
import lime.utils.Assets;
#if desktop
import data.Discord.DiscordClient;
#end
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.transition.FlxTransitionableState;
import funkin.transitions.StickerTransition;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.group.FlxGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import lime.net.curl.CURLCode;
import funkin.menus.substate.MenuItem;
import funkin.menus.substate.MenuCharacter;
import funkin.gameplay.objects.hud.Highscore;
import funkin.scripting.StateScriptHandler;
import funkin.gameplay.PlayState;
import funkin.states.LoadingState;
import funkin.data.Song;
import funkin.cutscenes.VideoState;

using StringTools;

// Importar JSON
import haxe.Json;
import haxe.format.JsonParser;
#if sys
import sys.FileSystem;
#end

typedef Songs =
{
	var songsWeeks:Array<SongsInfo>;
}

typedef SongsInfo =
{
	var weekSongs:Array<String>;
	var songIcons:Array<String>;
	var color:Array<String>;
	var bpm:Array<Float>;

	// Campos adicionales para Story Mode (opcionales)
	@:optional var weekName:String;
	@:optional var weekCharacters:Array<String>;
	@:optional var locked:Bool;
	@:optional var showInStoryMode:Array<Bool>; // NUEVO: Flag para mostrar en Story Mode
}

class StoryMenuState extends funkin.states.MusicBeatState
{
	var scoreText:FlxText;

	// Usar el mismo sistema que FreeplayState
	public static var songInfo:Songs;

	var weekData:Array<Dynamic> = [];
	var weekCharacters:Array<Dynamic> = [];
	var weekNames:Array<String> = [];
	var weekColors:Array<FlxColor> = [];

	var curDifficulty:Int = 1;

	public static var weekUnlocked:Array<Bool> = [];

	var txtWeekTitle:FlxText;

	public var curWeek:Int = 0;

	var bg:FlxSprite;

	public var bgcol:FlxColor = 0xFF0A0A0A;

	var txtTracklist:FlxText;

	var grpWeekText:FlxTypedGroup<MenuItem>;
	var grpWeekCharacters:FlxTypedGroup<MenuCharacter>;

	var grpLocks:FlxTypedGroup<FlxSprite>;

	var difficultySelectors:FlxGroup;
	var sprDifficulty:FlxSprite;
	var leftArrow:FlxSprite;
	var rightArrow:FlxSprite;
	var yellowBG:FlxSprite;
	var tracksMenu:FlxSprite;
	var blackBarThingie:FlxSprite;
	var inverted:FlxSprite;

	// Error message
	var errorText:FlxText;
	var errorTween:FlxTween;

	override function create()
	{
		StickerTransition.reattachToState();

		if (StickerTransition.enabled)
		{
			transIn = null;
			transOut = null;
		}

		if (!MainMenuState.musicFreakyisPlaying)
		{
			FlxG.sound.playMusic(Paths.music('freakyMenu'));
			MainMenuState.musicFreakyisPlaying = true;
		}

		persistentUpdate = persistentDraw = true;

		// === CARGAR DATOS DESDE EL MISMO JSON QUE FREEPLAY ===
		loadSongsData();

		if (songInfo != null)
		{
			buildWeeksFromJSON();
		}
		else
		{
			trace("Error loading songs data, using default weeks");
			loadDefaultWeeks();
		}

		scoreText = new FlxText(10, 10, 0, "WEEK SCORE: 49324858", 36);
		scoreText.setFormat("VCR OSD Mono", 32);

		txtWeekTitle = new FlxText(FlxG.width * 0.7, 10, 0, "", 32);
		txtWeekTitle.setFormat("VCR OSD Mono", 32, FlxColor.WHITE, RIGHT);
		txtWeekTitle.alpha = 0.7;

		var rankText:FlxText = new FlxText(0, 10);
		rankText.text = 'RANK: GREAT';
		rankText.setFormat(Paths.font("vcr.ttf"), 32);
		rankText.size = scoreText.size;
		rankText.screenCenter(X);

		var ui_tex = Paths.getSparrowAtlas('storymenu/campaign_menu/campaign_menu_UI_assets');
		yellowBG = new FlxSprite(0, 56).makeGraphic(FlxG.width, 404, 0xFFF9CF51);
		inverted = new FlxSprite(0, 56).makeGraphic(FlxG.width, 400, 0xFFF9CF51);

		blackBarThingie = new FlxSprite().makeGraphic(FlxG.width, 56, FlxColor.BLACK);

		// Inicializar bg aquí
		bg = new FlxSprite().loadGraphic(Paths.image('menu/menuDesat'));
		add(bg);
		bg.color = bgcol;

		persistentUpdate = persistentDraw = true;

		grpWeekText = new FlxTypedGroup<MenuItem>();
		add(grpWeekText);

		add(blackBarThingie);

		grpWeekCharacters = new FlxTypedGroup<MenuCharacter>();

		grpLocks = new FlxTypedGroup<FlxSprite>();
		add(grpLocks);

		trace("Line 70");

		#if desktop
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Story Mode", null);
		#end

		// VALIDACIÓN: Solo crear items si hay semanas disponibles
		if (weekData.length > 0)
		{
			for (i in 0...weekData.length)
			{
				var weekThing:MenuItem = new MenuItem(0, yellowBG.y + yellowBG.height + 10, i);
				weekThing.y += ((weekThing.height + 20) * i);
				weekThing.targetY = i;
				grpWeekText.add(weekThing);

				weekThing.screenCenter(X);
				weekThing.antialiasing = true;
				// weekThing.updateHitbox();

				// Needs an offset thingie
				if (i < weekUnlocked.length && !weekUnlocked[i])
				{
					var lock:FlxSprite = new FlxSprite(weekThing.width + 10 + weekThing.x);
					lock.frames = ui_tex;
					lock.animation.addByPrefix('lock', 'lock');
					lock.animation.play('lock');
					lock.ID = i;
					lock.antialiasing = true;
					grpLocks.add(lock);
				}
			}
		}
		else
		{
			// NUEVO: Mostrar mensaje de error si no hay semanas
			trace("WARNING: No weeks available in Story Mode!");
		}

		trace("Line 96");

		// Inicializar personajes con la primera semana
		var initialChars:Array<String> = ['', 'bf', 'gf'];
		if (weekCharacters.length > 0 && weekCharacters[0] != null)
			initialChars = weekCharacters[0];

		for (char in 0...3)
		{
			var charName:String = char < initialChars.length ? initialChars[char] : '';
			var weekCharacterThing:MenuCharacter = new MenuCharacter((FlxG.width * 0.25) * (1 + char) - 150, charName);
			weekCharacterThing.y += 70;
			weekCharacterThing.antialiasing = true;
			grpWeekCharacters.add(weekCharacterThing);
		}

		#if HSCRIPT_ALLOWED
		StateScriptHandler.init();
		StateScriptHandler.loadStateScripts('StoryMenuState', this);
		StateScriptHandler.callOnScripts('onCreate', []);

		// Obtener semanas custom
		var customWeeks = StateScriptHandler.callOnScriptsReturn('getCustomWeeks', [], null);
		if (customWeeks != null && Std.isOfType(customWeeks, Array))
		{
			// Procesar semanas custom
		}
		#end

		difficultySelectors = new FlxGroup();
		add(difficultySelectors);

		trace("Line 124");

		// VALIDACIÓN CRÍTICA: Solo crear arrows si ui_tex existe Y hay al menos una semana
		if (ui_tex != null && grpWeekText.members.length > 0 && grpWeekText.members[0] != null)
		{
			leftArrow = new FlxSprite(grpWeekText.members[0].x + grpWeekText.members[0].width + 10, grpWeekText.members[0].y + 10);
			leftArrow.frames = ui_tex;
			leftArrow.animation.addByPrefix('idle', "arrow left");
			leftArrow.animation.addByPrefix('press', "arrow push left");
			leftArrow.animation.play('idle');
			difficultySelectors.add(leftArrow);

			sprDifficulty = new FlxSprite(leftArrow.x + 130, leftArrow.y);
			sprDifficulty.frames = ui_tex;
			sprDifficulty.animation.addByPrefix('easy', 'EASY');
			sprDifficulty.animation.addByPrefix('normal', 'NORMAL');
			sprDifficulty.animation.addByPrefix('hard', 'HARD');
			sprDifficulty.animation.play('easy');
			changeDifficulty();

			difficultySelectors.add(sprDifficulty);

			rightArrow = new FlxSprite(sprDifficulty.x + sprDifficulty.width + 50, leftArrow.y);
			rightArrow.frames = ui_tex;
			rightArrow.animation.addByPrefix('idle', 'arrow right');
			rightArrow.animation.addByPrefix('press', "arrow push right", 24, false);
			rightArrow.animation.play('idle');
			difficultySelectors.add(rightArrow);
		}
		else if (ui_tex != null)
		{
			// FALLBACK: Crear con posiciones por defecto si ui_tex existe pero no hay semanas
			trace("WARNING: No weeks available or invalid, using default arrow positions");

			leftArrow = new FlxSprite(FlxG.width * 0.2, yellowBG.y + yellowBG.height + 100);
			leftArrow.frames = ui_tex;
			leftArrow.animation.addByPrefix('idle', "arrow left");
			leftArrow.animation.addByPrefix('press', "arrow push left");
			leftArrow.animation.play('idle');
			difficultySelectors.add(leftArrow);

			sprDifficulty = new FlxSprite(leftArrow.x + 130, leftArrow.y);
			sprDifficulty.frames = ui_tex;
			sprDifficulty.animation.addByPrefix('easy', 'EASY');
			sprDifficulty.animation.addByPrefix('normal', 'NORMAL');
			sprDifficulty.animation.addByPrefix('hard', 'HARD');
			sprDifficulty.animation.play('easy');
			changeDifficulty();

			difficultySelectors.add(sprDifficulty);

			rightArrow = new FlxSprite(sprDifficulty.x + sprDifficulty.width + 50, leftArrow.y);
			rightArrow.frames = ui_tex;
			rightArrow.animation.addByPrefix('idle', 'arrow right');
			rightArrow.animation.addByPrefix('press', "arrow push right", 24, false);
			rightArrow.animation.play('idle');
			difficultySelectors.add(rightArrow);

			// Ocultar difficulty selectors si no hay semanas
			difficultySelectors.visible = false;
		}
		else
		{
			// CRÍTICO: Si ui_tex es null, NO crear ningún arrow
			trace("ERROR: ui_tex is null, cannot create arrows! difficultySelectors will be empty.");
			difficultySelectors.visible = false;
		}

		trace("Line 150");

		add(yellowBG);
		add(grpWeekCharacters);

		// VALIDACIÓN: Verificar que la imagen existe antes de cargar
		var tracksMenuPath:String = 'storymenu/campaign_menu/tracksMenu';
		if (Paths.image(tracksMenuPath) != null)
		{
			try
			{
				tracksMenu = new FlxSprite(FlxG.width * 0.07, yellowBG.y + 435).loadGraphic(Paths.image(tracksMenuPath));
				tracksMenu.antialiasing = true;
				add(tracksMenu);
			}
			catch (e:Dynamic)
			{
				trace("ERROR: Failed to load tracksMenu: " + e);
				// Crear un sprite de fallback
				tracksMenu = new FlxSprite(FlxG.width * 0.07, yellowBG.y + 435);
				tracksMenu.makeGraphic(Std.int(FlxG.width * 0.5), 100, 0xFFFFFFFF);
				add(tracksMenu);
			}
		}
		else
		{
			trace("WARNING: tracksMenu image not found, creating fallback");
			tracksMenu = new FlxSprite(FlxG.width * 0.07, yellowBG.y + 435);
			tracksMenu.makeGraphic(Std.int(FlxG.width * 0.5), 100, 0xFF000000);
			add(tracksMenu);
		}

		txtTracklist = new FlxText(FlxG.width * 0.05, tracksMenu.y + 60, 0, "", 32);
		txtTracklist.alignment = CENTER;
		txtTracklist.font = rankText.font;
		txtTracklist.color = 0xFFe55777;
		add(txtTracklist);
		// add(rankText);
		add(scoreText);
		add(txtWeekTitle);

		// Error message text
		errorText = new FlxText(0, FlxG.height * 0.5 - 50, FlxG.width, "", 32);
		errorText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.RED, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		errorText.setBorderStyle(OUTLINE, FlxColor.BLACK, 4);
		errorText.scrollFactor.set();
		errorText.alpha = 0;
		errorText.visible = false;
		add(errorText);

		updateText();

		// NUEVO: Mostrar error si no hay semanas disponibles
		if (weekData.length == 0)
		{
			showError("No weeks available in Story Mode!\nAll songs may be set to Freeplay-only.");
		}

		trace("Line 165");

		super.create();

		StickerTransition.clearStickers();
	}

	// === FUNCIÓN PARA CARGAR DATOS DESDE EL MISMO JSON QUE FREEPLAY ===
	function loadSongsData():Void
	{
		try
		{
			var file:String = Assets.getText(Paths.jsonSong('songList'));
			songInfo = cast Json.parse(file);
			trace("Songs data loaded successfully from songList.json");
		}
		catch (e:Dynamic)
		{
			trace("Error loading songs data: " + e);
			songInfo = null;
		}
	}

	// === CONSTRUIR SEMANAS DESDE JSON ===
	function buildWeeksFromJSON():Void
	{
		if (songInfo == null || songInfo.songsWeeks == null)
		{
			loadDefaultWeeks();
			return;
		}

		weekData = [];
		weekCharacters = [];
		weekNames = [];
		weekUnlocked = [];
		weekColors = [];

		for (i in 0...songInfo.songsWeeks.length)
		{
			var week = songInfo.songsWeeks[i];

			// NUEVO: Filtrar canciones según showInStoryMode
			var filteredSongs:Array<String> = [];
			for (j in 0...week.weekSongs.length)
			{
				var showInStory:Bool = true; // Por defecto mostrar

				// Verificar si existe el flag showInStoryMode
				if (week.showInStoryMode != null && j < week.showInStoryMode.length)
				{
					showInStory = week.showInStoryMode[j];
				}

				// Solo agregar si debe mostrarse en Story Mode
				if (showInStory)
				{
					filteredSongs.push(week.weekSongs[j]);
				}
			}

			// Solo agregar la semana si tiene canciones para mostrar
			if (filteredSongs.length > 0)
			{
				// Agregar canciones filtradas de la semana
				weekData.push(filteredSongs);

				// Nombre de la semana (usar el proporcionado o generar uno por defecto)
				var weekName:String = week.weekName != null ? week.weekName : 'Week ${i + 1}';
				weekNames.push(weekName);

				// Personajes de la semana (usar los proporcionados o usar defaults)
				var chars:Array<String> = ['', 'bf', 'gf']; // Default
				if (week.weekCharacters != null && week.weekCharacters.length >= 3)
				{
					chars = week.weekCharacters;
				}
				else if (week.songIcons != null && week.songIcons.length > 0)
				{
					// Fallback: usar el primer icono como personaje de la izquierda
					chars = [week.songIcons[0], 'bf', 'gf'];
				}
				weekCharacters.push(chars);

				// Estado de bloqueo (usar el proporcionado o desbloquear por defecto)
				var isLocked:Bool = week.locked != null ? week.locked : false;
				weekUnlocked.push(!isLocked);

				// Color de la semana (usar el primer color de la lista)
				var colorStr:String = week.color != null && week.color.length > 0 ? week.color[0] : '0xFF9271FD';
				var color:FlxColor = Std.parseInt(colorStr);
				var colornull:Null<FlxColor> = color;
				if (colornull == null)
					color = 0xFF9271FD;
				weekColors.push(color);

				trace('Loaded week ${i}: ${weekName} with ${filteredSongs.length} songs (filtered from ${week.weekSongs.length})');
			}
			else
			{
				trace('Week ${i} has no songs to show in Story Mode, skipping...');
			}
		}

		// Actualizar color de fondo con la primera semana
		if (weekColors.length > 0)
			bgcol = weekColors[0];
		else
			bgcol = 0xFF0A0A0A; // Color por defecto si no hay semanas

		// VALIDACIÓN CRÍTICA: Verificar que todos los arrays estén sincronizados
		var expectedLength:Int = weekData.length;
		var syncIssues:Bool = false;

		if (weekNames.length != expectedLength)
		{
			trace("WARNING: weekNames.length (" + weekNames.length + ") != weekData.length (" + expectedLength + ")");
			syncIssues = true;
		}
		if (weekCharacters.length != expectedLength)
		{
			trace("WARNING: weekCharacters.length (" + weekCharacters.length + ") != weekData.length (" + expectedLength + ")");
			syncIssues = true;
		}
		if (weekUnlocked.length != expectedLength)
		{
			trace("WARNING: weekUnlocked.length (" + weekUnlocked.length + ") != weekData.length (" + expectedLength + ")");
			syncIssues = true;
		}
		if (weekColors.length != expectedLength)
		{
			trace("WARNING: weekColors.length (" + weekColors.length + ") != weekData.length (" + expectedLength + ")");
			syncIssues = true;
		}

		if (syncIssues)
		{
			trace("ERROR: Array synchronization issues detected! This may cause crashes.");
		}
		else
		{
			trace("SUCCESS: All arrays synchronized (" + expectedLength + " weeks loaded)");
		}
	}

	// === FUNCIÓN DE FALLBACK PARA CARGAR SEMANAS POR DEFECTO ===
	function loadDefaultWeeks():Void
	{
		weekData = [
			['Tutorial'],
			['Bopeebo', 'Fresh', 'Dadbattle'],
			['Spookeez', 'South', "Monster"],
			['Pico', 'Philly', "Blammed"],
			['Satin-Panties', "High", "Milf"],
			['Cocoa', 'Eggnog', 'Winter-Horrorland'],
			['Senpai', 'Roses', 'Thorns']
		];

		weekCharacters = [
			['', 'bf', 'gf'],
			['dad', 'bf', 'gf'],
			['spooky', 'bf', 'gf'],
			['pico', 'bf', 'gf'],
			['mom', 'bf', 'gf'],
			['parents-christmas', 'bf', 'gf'],
			['senpai', 'bf', 'gf']
		];

		weekNames = [
			"Tutorial",
			"Daddy Dearest",
			"Spooky Month",
			"PICO",
			"MOMMY MUST MURDER",
			"RED SNOW",
			"hating simulator ft. moawling"
		];

		weekUnlocked = [true, true, true, true, true, true, true];

		weekColors = [
			0xFF9271FD,
			0xFFAF66CE,
			0xFF2A2A2A,
			0xFF6BAA4C,
			0xFFD85889,
			0xFF9A68A4,
			0xFFFFAA6F
		];
	}

	override function update(elapsed:Float)
	{
		#if HSCRIPT_ALLOWED
		StateScriptHandler.callOnScripts('onUpdate', [elapsed]);
		#end

		// VALIDACIÓN: Solo actualizar si hay semanas
		if (weekData.length > 0)
		{
			// Update score lerp
			lerpScore = Math.floor(FlxMath.lerp(lerpScore, intendedScore, 0.5));
			if (Math.abs(intendedScore - lerpScore) < 10)
				lerpScore = intendedScore;

			scoreText.text = "WEEK SCORE:" + lerpScore;

			// Actualizar título de la semana si es válido
			// VALIDACIÓN TRIPLE: curWeek, weekNames, y txtWeekTitle
			if (txtWeekTitle != null && curWeek >= 0 && curWeek < weekNames.length && weekNames[curWeek] != null)
			{
				try
				{
					txtWeekTitle.text = weekNames[curWeek].toUpperCase();
					txtWeekTitle.x = FlxG.width - (txtWeekTitle.width + 10);
				}
				catch (e:Dynamic)
				{
					trace("ERROR: Failed to update week title: " + e);
				}

				// Actualizar color de fondo según la semana
				if (bg != null && curWeek >= 0 && curWeek < weekColors.length)
				{
					try
					{
						bg.color = weekColors[curWeek];
					}
					catch (e:Dynamic)
					{
						trace("ERROR: Failed to update bg color: " + e);
					}
				}
			}
			else if (curWeek >= weekNames.length)
			{
				// CORRECCIÓN: Si curWeek está fuera de rango, resetear
				trace("WARNING: curWeek (" + curWeek + ") >= weekNames.length (" + weekNames.length + "), resetting to 0");
				curWeek = 0;
			}

			// FlxG.watch.addQuick('font', scoreText.font);

			// Validar antes de acceder al array
			if (curWeek >= 0 && curWeek < weekUnlocked.length && difficultySelectors != null)
				difficultySelectors.visible = weekUnlocked[curWeek];

			if (grpLocks != null)
			{
				grpLocks.forEach(function(lock:FlxSprite)
				{
					if (lock != null && grpWeekText != null && grpWeekText.members != null && lock.ID < grpWeekText.members.length)
					{
						var member = grpWeekText.members[lock.ID];
						if (member != null)
							lock.y = member.y;
					}
				});
			}

			if (!movedBack)
			{
				if (!selectedWeek)
				{
					if (controls.UP_P)
					{
						changeWeek(-1);
					}

					if (controls.DOWN_P)
					{
						changeWeek(1);
					}

					// VALIDACIÓN: Solo interactuar con arrows si existen Y tienen frames válidos
					if (rightArrow != null && rightArrow.frames != null && rightArrow.animation != null)
					{
						try
						{
							if (controls.RIGHT)
								rightArrow.animation.play('press')
							else
								rightArrow.animation.play('idle');
						}
						catch (e:Dynamic)
						{
							trace("ERROR: Failed to play rightArrow animation: " + e);
						}
					}

					if (leftArrow != null && leftArrow.frames != null && leftArrow.animation != null)
					{
						try
						{
							if (controls.LEFT)
								leftArrow.animation.play('press');
							else
								leftArrow.animation.play('idle');
						}
						catch (e:Dynamic)
						{
							trace("ERROR: Failed to play leftArrow animation: " + e);
						}
					}

					if (controls.RIGHT_P)
						changeDifficulty(1);
					if (controls.LEFT_P)
						changeDifficulty(-1);
				}

				if (controls.ACCEPT)
				{
					selectWeek();
				}
			}
		}
		else
		{
			// NUEVO: Si no hay semanas, solo permitir volver atrás
			scoreText.text = "NO WEEKS AVAILABLE";
			if (txtWeekTitle != null)
				txtWeekTitle.text = "";
		}

		if (controls.BACK && !movedBack && !selectedWeek)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			movedBack = true;
			FlxG.switchState(new MainMenuState());
			return; // IMPORTANTE: Detener la ejecución aquí
		}

		super.update(elapsed);

		#if HSCRIPT_ALLOWED
		StateScriptHandler.callOnScripts('onUpdatePost', [elapsed]);
		#end
	}

	var movedBack:Bool = false;
	var selectedWeek:Bool = false;
	var stopspamming:Bool = false;

	function selectWeek()
	{
		#if HSCRIPT_ALLOWED
		var cancelled = StateScriptHandler.callOnScriptsReturn('onAccept', [], false);
		if (cancelled)
			return;
		#end

		// VALIDACIÓN: Verificar que hay semanas disponibles
		if (weekData.length == 0)
		{
			showError("No weeks available!");
			return;
		}

		// Validar índice antes de acceder
		if (curWeek < 0 || curWeek >= weekUnlocked.length || curWeek >= weekData.length)
			return;

		if (weekUnlocked[curWeek])
		{
			if (stopspamming == false)
			{
				FlxG.sound.play(Paths.sound('confirmMenu'));
				FlxG.camera.flash(FlxColor.WHITE, 1);

				if (grpWeekText != null
					&& grpWeekText.members != null
					&& curWeek < grpWeekText.members.length
					&& grpWeekText.members[curWeek] != null)
					grpWeekText.members[curWeek].startFlashing();

				if (grpWeekCharacters != null
					&& grpWeekCharacters.members != null
					&& grpWeekCharacters.members.length > 1
					&& grpWeekCharacters.members[1] != null)
					grpWeekCharacters.members[1].animation.play('confirm');

				stopspamming = true;
			}

			PlayState.storyPlaylist = weekData[curWeek];
			PlayState.isStoryMode = true;
			selectedWeek = true;

			var diffic = "";

			switch (curDifficulty)
			{
				case 0:
					diffic = '-easy';
				case 2:
					diffic = '-hard';
			}

			PlayState.storyDifficulty = curDifficulty;

			PlayState.SONG = Song.loadFromJson(PlayState.storyPlaylist[0].toLowerCase() + diffic, PlayState.storyPlaylist[0].toLowerCase());
			PlayState.storyWeek = curWeek;
			PlayState.campaignScore = 0;
			if (curWeek == 0)
				new FlxTimer().start(1, function(tmr:FlxTimer)
				{
					LoadingState.loadAndSwitchState(new VideoState('test', new PlayState()), true);
				});
			else
				new FlxTimer().start(1, function(tmr:FlxTimer)
				{
					LoadingState.loadAndSwitchState(new PlayState(), true);
				});
		}
	}

	function changeDifficulty(change:Int = 0):Void
	{
		// VALIDACIÓN: Solo cambiar dificultad si sprDifficulty existe
		if (sprDifficulty == null)
			return;

		// VALIDACIÓN ADICIONAL: Verificar que sprDifficulty tiene frames válidos
		if (sprDifficulty.frames == null)
		{
			trace("ERROR: sprDifficulty.frames is null, cannot change difficulty");
			return;
		}

		curDifficulty += change;

		if (curDifficulty < 0)
			curDifficulty = 2;
		if (curDifficulty > 2)
			curDifficulty = 0;

		sprDifficulty.offset.x = 0;

		// VALIDACIÓN: Try-catch en animaciones por si no existen
		try
		{
			switch (curDifficulty)
			{
				case 0:
					sprDifficulty.animation.play('easy');
					sprDifficulty.offset.x = 20;
				case 1:
					sprDifficulty.animation.play('normal');
					sprDifficulty.offset.x = 70;
				case 2:
					sprDifficulty.animation.play('hard');
					sprDifficulty.offset.x = 20;
			}
		}
		catch (e:Dynamic)
		{
			trace("ERROR: Failed to play difficulty animation: " + e);
			return;
		}

		sprDifficulty.alpha = 0;

		// VALIDACIÓN: Solo actualizar posición si leftArrow existe
		if (leftArrow != null)
		{
			sprDifficulty.y = leftArrow.y - 15;
			FlxTween.tween(sprDifficulty, {y: leftArrow.y + 15, alpha: 1}, 0.07);
		}
		else
		{
			FlxTween.tween(sprDifficulty, {alpha: 1}, 0.07);
		}

		// VALIDACIÓN: Solo obtener score si hay semanas
		if (weekData.length > 0 && curWeek >= 0 && curWeek < weekData.length)
		{
			#if !switch
			intendedScore = Highscore.getWeekScore(curWeek, curDifficulty);
			#end
		}
	}

	var lerpScore:Int = 0;
	var intendedScore:Int = 0;

	function changeWeek(change:Int = 0):Void
	{
		// VALIDACIÓN: No hacer nada si no hay semanas
		if (weekData.length == 0)
			return;

		curWeek += change;

		// Validación mejorada con protección extra y clamp
		if (curWeek >= weekData.length)
		{
			curWeek = 0;
			trace("Wrapped to first week");
		}
		if (curWeek < 0)
		{
			curWeek = weekData.length - 1;
			trace("Wrapped to last week");
		}

		// VALIDACIÓN CRÍTICA: Asegurar que curWeek está en rango válido
		// para TODOS los arrays antes de continuar
		if (curWeek >= weekData.length || curWeek < 0)
		{
			trace("ERROR: curWeek out of range after wrap: " + curWeek);
			curWeek = 0;
		}

		var bullShit:Int = 0;

		// Verificar que grpWeekText no sea null
		if (grpWeekText != null && grpWeekText.members != null)
		{
			for (item in grpWeekText.members)
			{
				if (item != null)
				{
					item.targetY = bullShit - curWeek;

					// Validar índices antes de acceder a weekUnlocked
					if (item.targetY == Std.int(0) && curWeek >= 0 && curWeek < weekUnlocked.length && weekUnlocked[curWeek])
						item.alpha = 1;
					else
						item.alpha = 0.6;
				}
				bullShit++;
			}
		}

		FlxG.sound.play(Paths.sound('scrollMenu'));

		// Asegurar que curWeek es válido justo antes de updateText
		if (curWeek >= 0 && curWeek < weekData.length)
		{
			updateText();
		}
		else
		{
			trace("ERROR: Skipping updateText, curWeek invalid: " + curWeek);
		}

		#if HSCRIPT_ALLOWED
		var cancelled = StateScriptHandler.callOnScriptsReturn('onWeekSelected', [], false);
		#end
	}

	function updateText()
	{
		// VALIDACIÓN: Solo actualizar si hay semanas
		if (weekData.length == 0)
			return;

		// Validar que curWeek esté dentro del rango ANTES de hacer cualquier cosa
		if (curWeek < 0 || curWeek >= weekData.length)
		{
			trace("WARNING: curWeek out of range in updateText: " + curWeek + " (weekData.length: " + weekData.length + ")");
			curWeek = 0; // Reset a la primera semana
			if (weekData.length == 0)
				return;
		}

		// Validación mejorada para prevenir índices fuera de rango
		var weekArray:Array<String> = ['', 'bf', 'gf']; // Default seguro

		if (curWeek >= 0 && curWeek < weekCharacters.length && weekCharacters[curWeek] != null)
		{
			weekArray = weekCharacters[curWeek];
		}
		else if (weekCharacters.length > 0 && weekCharacters[0] != null)
		{
			weekArray = weekCharacters[0]; // Fallback al primero
		}
		else
		{
			trace("WARNING: weekCharacters is empty or null, using defaults");
		}

		// Verificar que grpWeekCharacters no sea null y tenga el tamaño correcto
		if (grpWeekCharacters != null && grpWeekCharacters.members != null)
		{
			for (i in 0...grpWeekCharacters.length)
			{
				var member = grpWeekCharacters.members[i];
				if (member != null && i < weekArray.length && weekArray[i] != null)
				{
					try
					{
						member.changeCharacter(weekArray[i]);
					}
					catch (e:Dynamic)
					{
						trace("ERROR: Failed to change character at index " + i + " to '" + weekArray[i] + "': " + e);
					}
				}
			}
		}

		// Doble validación de curWeek antes de acceder a weekData
		if (curWeek < 0 || curWeek >= weekData.length)
		{
			trace("WARNING: curWeek still out of range after validation: " + curWeek);
			return;
		}

		var stringThing:Array<String> = weekData[curWeek];

		// Validar que stringThing no sea null
		if (stringThing == null)
		{
			trace("ERROR: weekData[" + curWeek + "] is null!");
			return;
		}

		if (txtTracklist != null)
		{
			txtTracklist.text = '';
			for (i in 0...stringThing.length)
			{
				if (stringThing[i] != null)
					txtTracklist.text += stringThing[i] + '\n';
			}

			txtTracklist.text = StringTools.replace(txtTracklist.text, '-', ' ');
			txtTracklist.text = txtTracklist.text.toUpperCase();

			txtTracklist.screenCenter(X);
			txtTracklist.x -= FlxG.width * 0.35;
		}

		#if !switch
		if (curWeek >= 0 && curWeek < weekData.length)
			intendedScore = Highscore.getWeekScore(curWeek, curDifficulty);
		#end
	}

	function showError(message:String):Void
	{
		// Cancel any existing error tween
		if (errorTween != null)
		{
			errorTween.cancel();
		}

		// Set error message
		errorText.text = message;
		errorText.visible = true;
		errorText.alpha = 0;

		// Fade in
		errorTween = FlxTween.tween(errorText, {alpha: 1}, 0.3, {
			ease: FlxEase.expoOut,
			onComplete: function(twn:FlxTween)
			{
				// Wait 3 seconds then fade out
				errorTween = FlxTween.tween(errorText, {alpha: 0}, 0.5, {
					ease: FlxEase.expoIn,
					startDelay: 3.0,
					onComplete: function(twn:FlxTween)
					{
						errorText.visible = false;
					}
				});
			}
		});
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
