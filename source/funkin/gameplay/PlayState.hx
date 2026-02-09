package funkin.gameplay;

// Core imports
import flixel.FlxG;
import flixel.FlxCamera;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.tweens.FlxEase;
import flixel.FlxSubState;
// Game objects
import funkin.gameplay.objects.character.Character;
import funkin.gameplay.objects.stages.Stage;
import funkin.gameplay.notes.Note;
import funkin.gameplay.notes.NoteSplash;
import funkin.gameplay.notes.StrumNote;
import funkin.gameplay.notes.NoteSkinSystem;
// NUEVO: Import de batching
import funkin.gameplay.notes.NoteBatcher;
// Gameplay modules
import funkin.gameplay.*;
// Scripting
import funkin.scripting.ScriptHandler;
import funkin.scripting.EventManager;
// Other
import funkin.data.Song.SwagSong;
import funkin.data.Song;
import funkin.data.Section.SwagSection;
import funkin.data.Conductor;
import extensions.CoolUtil;
import funkin.gameplay.objects.hud.Highscore;
import funkin.states.LoadingState;
import funkin.states.GameOverSubstate;
import funkin.menus.RatingState;
import funkin.gameplay.objects.hud.ScoreManager;
// Menu Pause
import funkin.menus.GitarooPause;
import funkin.menus.PauseSubState;
import funkin.debug.ChartingState;
#if desktop
import data.Discord.DiscordClient;
#end

using StringTools;

class PlayState extends funkin.states.MusicBeatState
{
	// === SINGLETON ===
	public static var instance:PlayState = null;

	// === STATIC DATA ===
	public static var SONG:SwagSong;
	public static var curStage:String = '';
	public static var isStoryMode:Bool = false;
	public static var storyWeek:Int = 0;
	public static var storyPlaylist:Array<String> = [];
	public static var storyDifficulty:Int = 1;
	public static var weekSong:Int = 0;

	// === LEGACY STATS ===
	public static var misses:Int = 0;
	public static var shits:Int = 0;
	public static var bads:Int = 0;
	public static var goods:Int = 0;
	public static var sicks:Int = 0;
	public static var songScore:Int = 0;
	public static var accuracy:Float = 0.00;
	public static var campaignScore:Int = 0;

	// === CORE SYSTEMS ===
	private var gameState:GameState;
	private var noteManager:NoteManager;
	private var inputHandler:InputHandler;
	private var cameraController:CameraController;
	private var uiManager:UIManager;
	private var characterController:CharacterController;
	public var scriptsEnabled:Bool = true;

	public var scoreManager:ScoreManager;

	// === CAMERAS ===
	public var camGame:FlxCamera;
	public var camHUD:FlxCamera;
	public var camCountdown:FlxCamera;

	// === CHARACTERS ===
	public var boyfriend:Character;
	public var dad:Character;
	public var gf:Character;

	// === STAGE ===
	public var currentStage:Stage;

	private var gfSpeed:Int = 1;

	// === NOTES ===
	public var notes:FlxTypedGroup<Note>;
	public var strumLineNotes:FlxTypedGroup<FlxSprite>;

	private var playerStrums:FlxTypedGroup<FlxSprite>;

	public static var cpuStrums:FlxTypedGroup<FlxSprite> = null;

	public var grpNoteSplashes:FlxTypedGroup<NoteSplash>;

	// === AUDIO ===
	public var vocals:FlxSound;

	// === STATE ===
	private var generatedMusic:Bool = false;

	public static var startingSong:Bool = false;

	private var inCutscene:Bool = false;

	public static var isPlaying:Bool = false;

	var canPause:Bool = true;

	public var paused:Bool = false;

	// === HOOKS ===
	public var onBeatHitHooks:Map<String, Int->Void> = new Map();
	public var onStepHitHooks:Map<String, Int->Void> = new Map();
	public var onUpdateHooks:Map<String, Float->Void> = new Map();
	public var onNoteHitHooks:Map<String, Note->Void> = new Map();
	public var onNoteMissHooks:Map<String, Note->Void> = new Map();

	// === OPTIMIZATION ===
	private var strumLiney:Float = PlayStateConfig.STRUM_LINE_Y;

	// === SECTION CACHE ===
	private var cachedSection:SwagSection = null;
	private var cachedSectionIndex:Int = -1;
	
	// === NUEVO: BATCHING Y HOLD NOTES ===
	private var noteBatcher:NoteBatcher;
	private var heldNotes:Map<Int, Note> = new Map(); // dirección -> nota
	private var holdSplashes:Map<Int, NoteSplash> = new Map(); // dirección -> splash continuo
	
	// NUEVO: Configuración de optimizaciones
	public var enableBatching:Bool = true;
	public var enableHoldSplashes:Bool = true;
	private var showDebugStats:Bool = false;
	private var debugText:FlxText;

	#if desktop
	var storyDifficultyText:String = "";
	var iconRPC:String = "";
	var detailsText:String = "";
	var detailsPausedText:String = "";
	#end

	override public function create()
	{
		instance = this;
		isPlaying = true;

		FlxG.mouse.visible = false;

		if (scriptsEnabled)
		{
			ScriptHandler.init();
			ScriptHandler.loadSongScripts(SONG.song);
			EventManager.loadEventsFromSong();
			
			// Exponer PlayState a los scripts
			ScriptHandler.setOnScripts('playState', PlayState.instance);
			ScriptHandler.setOnScripts('game', PlayState.instance);
			
			// Llamar onCreate en scripts
			ScriptHandler.callOnScripts('onCreate', []);
		}

		// Validar SONG
		if (SONG.stage == null)
			SONG.stage = 'stage_week1';

		curStage = SONG.stage;

		// Discord RPC
		#if desktop
		setupDiscord();
		#end

		// Crear cámaras
		setupCameras();

		// Crear core systems
		gameState = GameState.get();
		gameState.reset();

		// Crear stage y personajes
		loadStageAndCharacters();

		if (scriptsEnabled)
		{
			ScriptHandler.setOnScripts('boyfriend', boyfriend);
			ScriptHandler.setOnScripts('dad', dad);
			ScriptHandler.setOnScripts('gf', gf);
			ScriptHandler.setOnScripts('stage', currentStage);
			ScriptHandler.callOnScripts('onStageCreate', []);
		}

		// Crear UI groups
		createNoteGroups();

		// Crear controllers
		setupControllers();

		// Generar música
		generateSong();

		// Crear UI
		setupUI();
		
		// NUEVO: Setup debug display
		setupDebugDisplay();

		if (scriptsEnabled)
		{
			ScriptHandler.setOnScripts('camGame', camGame);
			ScriptHandler.setOnScripts('camHUD', camHUD);
			ScriptHandler.setOnScripts('camCountdown', camCountdown);
		}

		// Start song
		startCountdown();

		super.create();
	}

	/**
	 * Setup Discord RPC
	 */
	#if desktop
	private function setupDiscord():Void
	{
		storyDifficultyText = CoolUtil.difficultyString();
		iconRPC = SONG.player2;

		switch (iconRPC)
		{
			case 'monster-christmas':
				iconRPC = 'monster';
			case 'mom-car':
				iconRPC = 'mom';
		}

		if (isStoryMode)
			detailsText = "Story Mode: Week " + storyWeek;
		else
			detailsText = "Freeplay";

		detailsPausedText = "Paused - " + detailsText;
		updatePresence();
	}

	function updatePresence():Void
	{
		DiscordClient.changePresence(detailsText, SONG.song + " (" + storyDifficultyText + ")", iconRPC);
	}
	#end

	/**
	 * Crear cámaras
	 */
	private function setupCameras():Void
	{
		camGame = new FlxCamera();
		camHUD = new FlxCamera();
		camHUD.bgColor.alpha = 0;
		camCountdown = new FlxCamera();
		camCountdown.bgColor.alpha = 0;

		FlxG.cameras.reset(camGame);
		FlxG.cameras.add(camHUD, false);
		FlxG.cameras.add(camCountdown, false);
	}

	/**
	 * Cargar stage y personajes
	 */
	private function loadStageAndCharacters():Void
	{
		// Crear stage
		currentStage = new Stage(curStage);
		add(currentStage);

		// Crear personajes desde stage
		if (SONG.gfVersion == null)
			SONG.gfVersion = 'gf';
		gf = new Character(currentStage.gfPosition.x, currentStage.gfPosition.y, SONG.gfVersion);
		dad = new Character(currentStage.dadPosition.x, currentStage.dadPosition.y, SONG.player2);
		boyfriend = new Character(currentStage.boyfriendPosition.x, currentStage.boyfriendPosition.y, SONG.player1, true);

		// Agregar a state
		if (gf != null){
			if (!currentStage.hideGirlfriend)
				add(gf);
		}
		if (currentStage.hideGirlfriend)
			gf.visible = false;
		if (dad != null)
			add(dad);
		if (boyfriend != null)
			add(boyfriend);
	}

	/**
	 * Crear grupos de notas - MEJORADO con batching
	 */
	private function createNoteGroups():Void
	{
		// NUEVO: Crear batcher primero si está habilitado
		noteBatcher = new NoteBatcher();
			noteBatcher.cameras = [camHUD];
			add(noteBatcher);
		
		strumLineNotes = new FlxTypedGroup<FlxSprite>();
		strumLineNotes.cameras = [camHUD];
		add(strumLineNotes);

		grpNoteSplashes = new FlxTypedGroup<NoteSplash>();
		grpNoteSplashes.cameras = [camHUD];
		add(grpNoteSplashes);

		notes = new FlxTypedGroup<Note>();
		notes.cameras = [camHUD];
		add(notes);

		playerStrums = new FlxTypedGroup<FlxSprite>();
		cpuStrums = new FlxTypedGroup<FlxSprite>();

		generateStaticArrows(0); // CPU
		generateStaticArrows(1); // Player
	}

	/**
	 * Setup controllers - MEJORADO con splashes
	 */
	private function setupControllers():Void
	{
		// Camera controller
		cameraController = new CameraController(camGame, camHUD, boyfriend, dad);
		if (currentStage.defaultCamZoom > 0)
			cameraController.defaultZoom = currentStage.defaultCamZoom;

		// Character controller
		characterController = new CharacterController(boyfriend, dad, gf);

		// Input handler
		inputHandler = new InputHandler();
		inputHandler.ghostTapping = FlxG.save.data.ghosttap;
		inputHandler.onNoteHit = onPlayerNoteHit;
		inputHandler.onNoteMiss = onPlayerNoteMiss;
		
		// NUEVO: Callback para release de hold notes
		inputHandler.onKeyRelease = onKeyRelease;

		// Note manager - MEJORADO con splashes
		noteManager = new NoteManager(notes, playerStrums, cpuStrums, grpNoteSplashes);
		noteManager.strumLineY = strumLiney;
		noteManager.downscroll = FlxG.save.data.downscroll;
		noteManager.middlescroll = FlxG.save.data.middlescroll;
		noteManager.onCPUNoteHit = onCPUNoteHit;
		noteManager.onNoteHit = onNoteHitCallback; // NUEVO: Callback para gestionar splashes
	}
	
	/**
	 * NUEVO: Setup debug display
	 */
	private function setupDebugDisplay():Void
	{
		debugText = new FlxText(10, 10, 0, "", 14);
		debugText.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 2);
		debugText.cameras = [camHUD];
		debugText.visible = showDebugStats;
		add(debugText);
	}

	/**
	 * Crear UI
	 */
	public function setupUI():Void
	{
		var icons:Array<String> = [SONG.player1, SONG.player2];

		if (boyfriend.healthIcon != null && dad.healthIcon != null)
			icons = [boyfriend.healthIcon, dad.healthIcon];

		uiManager = new UIManager(camHUD, gameState);
		uiManager.setIcons(icons[0], icons[1]);
		uiManager.setStage(curStage);
		add(uiManager);
	}

	/**
	 * Generar flechas estáticas
	 */
	private function generateStaticArrows(player:Int):Void
	{
		for (i in 0...4)
		{
			var targetAlpha:Float = 1;
			if (player < 1 && FlxG.save.data.middlescroll)
				targetAlpha = 0;

			var babyArrow:StrumNote = new StrumNote(0, strumLiney, i);
			babyArrow.ID = i;

			// Posición
			var xPos = 100 + (Note.swagWidth * i);
			if (player == 1)
			{
				if (FlxG.save.data.middlescroll)
					xPos = FlxG.width / 2 - (Note.swagWidth * 2) + (Note.swagWidth * i);
				else
					xPos += FlxG.width / 2;

				playerStrums.add(babyArrow);
			}
			else
			{
				if (FlxG.save.data.middlescroll)
					xPos = -275 + (Note.swagWidth * i);

				cpuStrums.add(babyArrow);
			}

			babyArrow.x = xPos;
			babyArrow.alpha = 0;

			FlxTween.tween(babyArrow, {alpha: targetAlpha}, 0.5, {
				startDelay: 0.5 + (0.2 * i)
			});

			babyArrow.animation.play('static');
			babyArrow.cameras = [camHUD];
			strumLineNotes.add(babyArrow);
		}
	}

	/**
	 * Generar canción
	 */
	private function generateSong():Void
	{
		Conductor.changeBPM(SONG.bpm);

		trace('[PlayState] === GENERANDO CANCIÓN ===');
		trace('[PlayState] Canción: ${SONG.song}');
		trace('[PlayState] BPM: ${SONG.bpm}, Speed: ${SONG.speed}');
		trace('[PlayState] Conductor.crochet: ${Conductor.crochet}');
		trace('[PlayState] Conductor.stepCrochet: ${Conductor.stepCrochet}');

		// Cargar instrumental
		FlxG.sound.playMusic(Paths.inst(SONG.song), 0, false);
		FlxG.sound.music.pause();

		// Cargar voces
		if (SONG.needsVoices)
			vocals = new FlxSound().loadEmbedded(Paths.voices(SONG.song));
		else
			vocals = new FlxSound();

		vocals.volume = 0;
		vocals.pause();
		FlxG.sound.list.add(vocals);

		// Generar notas
		trace('[PlayState] Llamando a noteManager.generateNotes()...');
		noteManager.generateNotes(SONG);
		trace('[PlayState] Notas en grupo notes: ${notes.length}');
		trace('[PlayState] Secciones en SONG: ${SONG.notes.length}');

		generatedMusic = true;
		trace('[PlayState] === GENERACIÓN COMPLETA ===');
	}

	/**
	 * Start countdown
	 */
	var ready:FlxSprite;

	var set:FlxSprite;
	var go:FlxSprite;

	var introAssets:Map<String, Array<String>> = new Map<String, Array<String>>();
	var altSuffix:String = '';
	var startedCountdown:Bool = false;

	var startTimer:FlxTimer;
	var introAlts:Array<String> = [];

	private function startCountdown():Void
	{
		if (scriptsEnabled)
		{
			var result = ScriptHandler.callOnScriptsReturn('onCountdownStarted', [], false);
			if (result == true)
				return; // Script canceló el countdown
		}

		if (startedCountdown)
		{
			trace('[PlayState] startCountdown ya ejecutado, retornando...');
			return;
		}

		trace('[PlayState] === INICIANDO COUNTDOWN ===');
		Conductor.songPosition = 0;
		Conductor.songPosition = -Conductor.crochet * 5;
		trace('[PlayState] Conductor.songPosition inicial: ${Conductor.songPosition}');
		trace('[PlayState] Conductor.crochet: ${Conductor.crochet}');
		trace('[PlayState] Timer durará: ${(Conductor.crochet / 1000) * 5} segundos (5 beats)');

		var swagCounter:Int = 0;

		introAssets = new Map<String, Array<String>>();
		introAssets.set('default', ['UI/normal/ready', "UI/normal/set", "UI/normal/go"]);
		introAssets.set('school', ['UI/pixelUI/ready-pixel', 'UI/pixelUI/set-pixel', 'UI/pixelUI/date-pixel']);
		introAssets.set('schoolEvil', ['UI/pixelUI/ready-pixel', 'UI/pixelUI/set-pixel', 'UI/pixelUI/date-pixel']);

		introAlts = introAssets.get('default');

		if (introAssets.exists(curStage))
		{
			introAlts = introAssets.get(curStage);
			altSuffix = '-pixel';
		}

		// Configurar startingSong ANTES del timer
		startingSong = true;
		startedCountdown = true;

		startTimer = new FlxTimer().start(Conductor.crochet / 1000, function(tmr:FlxTimer)
		{
			trace('[PlayState] Timer beat $swagCounter - Conductor.songPosition: ${Conductor.songPosition}');

			characterController.danceOnBeat(curBeat);

			switch (swagCounter)
			{
				case 0:
					FlxG.sound.play(Paths.sound('intro3' + altSuffix), 0.6);
				case 1:
					getCountdown(ready, 0, 2, introAlts);
				case 2:
					getCountdown(set, 1, 1, introAlts);
				case 3:
					getCountdown(go, 2, 32 // nose
						, introAlts, true);
			}

			swagCounter += 1;
		}, 5);
	}

	function getCountdown(asset:FlxSprite, sip:Int, wea:Int,introAlts:Array<String>, ?isGo = false)
	{
		asset = new FlxSprite().loadGraphic(Paths.image(introAlts[sip]));
		asset.cameras = [camCountdown];
		asset.scrollFactor.set();

		asset.scale.set(0.7, 0.7);

		if (curStage.startsWith('school'))
			asset.setGraphicSize(Std.int(asset.width * PlayStateConfig.PIXEL_ZOOM));

		asset.updateHitbox();

		asset.screenCenter();

		asset.y -= 100;
		add(asset);
		FlxTween.tween(asset, {y: asset.y += 100, alpha: 0}, Conductor.crochet / 1000, {
			ease: FlxEase.cubeInOut,
			onComplete: function(twn:FlxTween)
			{
				asset.destroy();
			}
		});

		if (!isGo)
			FlxG.sound.play(Paths.sound('intro' + wea + altSuffix), 0.6);
		else
			FlxG.sound.play(Paths.sound('introGo' + altSuffix), 0.6);
	}

	override public function update(elapsed:Float)
	{
		if (scriptsEnabled)
			ScriptHandler.callOnScripts('onUpdate', [elapsed]);

		if (currentStage != null)
        	currentStage.update(elapsed);

		super.update(elapsed);

		// === CRÍTICO: ACTUALIZAR CONDUCTOR.SONGPOSITION ===
		if (!paused && !inCutscene)
		{
			if (startingSong && startedCountdown)
			{
				// Durante countdown, usar tiempo basado en elapsed
				Conductor.songPosition += FlxG.elapsed * 1000;
			}
			else if (FlxG.sound.music != null && FlxG.sound.music.playing)
			{
				// Durante la canción, sincronizar con la música
				Conductor.songPosition = FlxG.sound.music.time;
			}
		}

		// Hooks
		for (hook in onUpdateHooks)
			hook(elapsed);

		// Update controllers
		if (!paused && !inCutscene)
		{
			// Update characters
			characterController.update(elapsed);

			// Update camera
			var mustHitSection = getMustHitSection(curStep);
			cameraController.update(elapsed, mustHitSection);

			// Update note manager
			if (generatedMusic)
			{
				noteManager.update(Conductor.songPosition);
			}

			// Update input
			if (!boyfriend.stunned)
			{
				inputHandler.update();
				inputHandler.processInputs(notes);
				inputHandler.processSustains(notes);
				updatePlayerStrums();
				if (inputHandler != null && noteManager != null)
					inputHandler.checkMisses(notes);
			}

			// Update UI
			uiManager.update(elapsed);

			// Sync legacy stats
			syncLegacyStats();

			// Check death
			if (gameState.isDead())
				gameOver();

			// Limpiar hold splashes de CPU que ya no tienen notas activas
			for (key in heldNotes.keys()) {
				if (key >= 4) { // Es una nota de CPU
					var note = heldNotes.get(key);
					// Si la canción ya pasó el tiempo de la nota + su duración
					if (Conductor.songPosition > note.strumTime + note.sustainLength) {
						onKeyRelease(key); // Reutilizamos la función de limpieza
					}
				}
			}
		}

		if (vocals != null && SONG.needsVoices)
		{
			if (vocals.volume < 1)
			{
				vocals.volume += elapsed * 2; // Aumenta 2 por segundo
				if (vocals.volume > 1)
					vocals.volume = 1;
			}
		}
		
		// NUEVO: Debug controls
		updateDebugControls();
		
		// NUEVO: Update debug text
		if (showDebugStats && debugText != null)
		{
			var stats = 'FPS: ${FlxG.drawFramerate}\n';
			stats += noteManager.getPoolStats() + '\n';
			if (noteBatcher != null)
				stats += noteBatcher.getBatchStats();
			debugText.text = stats;
		}

		if (FlxG.keys.justPressed.ENTER && startedCountdown && canPause)
		{
			pauseMenu();
		}

		if (FlxG.keys.justPressed.SEVEN)
		{
			FlxG.switchState(new ChartingState());
		}

		// Song time - SINCRONIZACIÓN MEJORADA
		if (startingSong && startedCountdown)
		{
			if (FlxG.sound.music != null && Conductor.songPosition >= 0)
			{
				trace('[PlayState] Iniciando música - songPosition: ${Conductor.songPosition}');
				startSong();
			}
		}

		if (scriptsEnabled && !paused)
		{
			EventManager.update(Conductor.songPosition);
			ScriptHandler.callOnScripts('onUpdatePost', [elapsed]);
		}
	}
	
	/**
	 * NUEVO: Debug controls
	 */
	private function updateDebugControls():Void
	{
		// F3: Toggle stats
		if (FlxG.keys.justPressed.F3)
		{
			showDebugStats = !showDebugStats;
			if (debugText != null)
				debugText.visible = showDebugStats;
			trace('[PlayState] Debug stats: $showDebugStats');
		}
		
		// F7: Print pool stats
		if (FlxG.keys.justPressed.F7)
		{
			trace('=== POOL STATS ===');
			trace(noteManager.getPoolStats());
			if (noteBatcher != null)
				trace(noteBatcher.getBatchStats());
		}
	}

	function pauseMenu()
	{
		persistentUpdate = false;
		persistentDraw = true;
		paused = true;
		FlxG.sound.pause();

		// 1 / 1000 chance for Gitaroo Man easter egg
		if (FlxG.random.bool(0.1))
		{
			FlxG.switchState(new GitarooPause());
		}
		else
		{
			openSubState(new PauseSubState());
		}
	}

	/**
	 * Start song - SINCRONIZACIÓN MEJORADA
	 */
	private function startSong():Void
	{
		trace('[PlayState] ==========================================');
		trace('[PlayState] === INIT SONG ===');

		startingSong = false;

		// Iniciar música e instrumental juntos
		if (FlxG.sound.music != null)
		{
			FlxG.sound.music.volume = 1;
			FlxG.sound.music.time = 0;
			FlxG.sound.music.play();
			FlxG.sound.music.onComplete = endSong;

			trace('[PlayState] SONG INICIATES');
		}

		// Sincronizar vocales con música
		if (SONG.needsVoices && vocals != null)
		{
			vocals.volume = 1;
			vocals.time = 0;
			vocals.play();

			trace('[PlayState] VOCALS INICIATES');
		}

		trace('[PlayState] FlxG.sound.music.time: ${FlxG.sound.music.time}');
		trace('[PlayState] vocals.time: ${vocals.time}');
		trace('[PlayState] ==========================================');

		#if desktop
		DiscordClient.changePresence(detailsText, SONG.song + " (" + storyDifficultyText + ")", iconRPC, true, FlxG.sound.music.length);
		#end

		if (scriptsEnabled)
			ScriptHandler.callOnScripts('onSongStart', []);
	}

	/**
	 * Update player strums
	 */
	private function updatePlayerStrums():Void
	{
		playerStrums.forEach(function(spr:FlxSprite)
		{
			if (inputHandler.pressed[spr.ID] && spr.animation.curAnim.name != 'confirm')
			{
				spr.animation.play('pressed');
			}

			if (inputHandler.released[spr.ID])
			{
				spr.animation.play('static');
				spr.centerOffsets();
			}
		});
	}
	
	/**
	 * NUEVO: Callback cuando se suelta una tecla (para hold notes)
	 */
	private function onKeyRelease(direction:Int):Void
	{
		// Notificar al note manager que se soltó una hold note
		if (noteManager != null)
			noteManager.releaseHoldNote(direction);
		
		// Limpiar tracking local y crear splash de fin
		if (heldNotes.exists(direction))
		{
			var note = heldNotes.get(direction);
			heldNotes.remove(direction);
			
			// NUEVO: Detener splash continuo si existe
			if (holdSplashes.exists(direction))
			{
				var splash = holdSplashes.get(direction);
				if (splash != null)
				{
					splash.recycleSplash();
					grpNoteSplashes.remove(splash, true);
				}
				holdSplashes.remove(direction);
			}
			
			// NUEVO: Crear splash de fin de hold note
			if (enableHoldSplashes && FlxG.save.data.notesplashes)
			{
				var strum = playerStrums.members[direction];
				if (strum != null)
				{
					var endSplash:NoteSplash = grpNoteSplashes.recycle(NoteSplash);
					endSplash.setup(strum.x, strum.y, direction, null, HOLD_END);
					endSplash.cameras = [camHUD];
					
					if (!grpNoteSplashes.members.contains(endSplash))
					{
						grpNoteSplashes.add(endSplash);
					}
					
					trace('Created HOLD_END splash for direction $direction');
				}
			}
		}
	}
	
	/**
	 * NUEVO: Callback cuando el jugador golpea una nota (para splashes)
	 */
	/**
	 * NUEVO: Callback cuando el jugador golpea una nota (para splashes)
	 * MEJORADO: Ahora usa HOLD_START y HOLD_CONTINUOUS
	 */
	private function onNoteHitCallback(note:Note):Void
	{
		if (!enableHoldSplashes) return;
		
		// Solo para notas del jugador
		if (!note.mustPress) return;
		
		// Si es sustain note
		if (note.isSustainNote)
		{
			// Primera parte de la hold note
			if (!heldNotes.exists(note.noteData))
			{
				heldNotes.set(note.noteData, note);
				
				// Crear splash de inicio usando HOLD_START
				var strum = playerStrums.members[note.noteData];
				if (strum != null && FlxG.save.data.notesplashes)
				{
					var startSplash:NoteSplash = grpNoteSplashes.recycle(NoteSplash);
					startSplash.setup(strum.x, strum.y, note.noteData, null, HOLD_START);
					startSplash.cameras = [camHUD];
					
					if (!grpNoteSplashes.members.contains(startSplash))
					{
						grpNoteSplashes.add(startSplash);
					}
					
					trace('Created HOLD_START splash for direction ${note.noteData}');
					
					// OPCIONAL: Iniciar splash continuo (descomenta si quieres el efecto continuo)
					// startContinuousHoldSplash(note.noteData, strum.x, strum.y);
				}
			}
		}
	}
	
	/**
	 * NUEVO: Iniciar splash continuo para hold note
	 * MEJORADO: Ahora usa HOLD_CONTINUOUS
	 */
	private function startContinuousHoldSplash(direction:Int, x:Float, y:Float):Void
	{
		if (holdSplashes.exists(direction))
			return;

		// Si direction >= 4, es CPU. Si no, es Player.
		var isCPU = direction >= 4;
		var actualDir = isCPU ? direction - 4 : direction;
		var strum = isCPU ? cpuStrums.members[actualDir] : playerStrums.members[actualDir];
		
		if (strum == null) return;

		var continuousSplash:NoteSplash = new NoteSplash(strum.x, strum.y, actualDir);
		continuousSplash.startContinuousSplash(strum.x, strum.y, actualDir);
		continuousSplash.cameras = [camHUD];
		
		grpNoteSplashes.add(continuousSplash);
		holdSplashes.set(direction, continuousSplash);
	}

	/**
	 * Callback: Player hit note
	 */
	private function onPlayerNoteHit(note:Note):Void
	{
		// Process hit
		var noteDiff:Float = Math.abs(note.strumTime - Conductor.songPosition);
		// Regular note - GameState calcula el rating automáticamente
		var rating:String = gameState.processNoteHit(noteDiff);
		if (scriptsEnabled)
		{
			var cancel = ScriptHandler.callOnScriptsReturn('onPlayerNoteHit', [note, rating], false);
			if (cancel == true)
				return;
		}

		if (!note.wasGoodHit)
		{
			if (!note.isSustainNote)
			{
				var health = getHealthForRating(rating);
				gameState.modifyHealth(health);

				// Show popup
				uiManager.showRatingPopup(rating, gameState.combo);

				// Splash
				if (rating == 'sick' && FlxG.save.data.notesplashes)
					spawnNoteSplashOnNote(note, 1);

				// Hitsound
				if (FlxG.save.data.hitsounds && rating == 'sick')
					playHitSound();
			}
			else
			{
				// Sustain note
				gameState.modifyHealth(0.023);
			}

			// Animate character
			characterController.sing(boyfriend, note.noteData);

			// Animate strum
			noteManager.hitNote(note);

			// Camera offset
			cameraController.applyNoteOffset(boyfriend, note.noteData);

			// Vocals
			vocals.volume = 1;

			// Hooks
			for (hook in onNoteHitHooks)
				hook(note);
		}

		if (scriptsEnabled)
			ScriptHandler.callOnScripts('onPlayerNoteHitPost', [note, rating]);
	}

	/**
	 * Callback: Player miss note
	 */
	private function onPlayerNoteMiss(direction:Int):Void
	{
		if (scriptsEnabled)
		{
			var cancel = ScriptHandler.callOnScriptsReturn('onPlayerNoteMiss', [direction], false);
			if (cancel == true)
				return;
		}
		// Process miss
		gameState.processMiss();
		gameState.modifyHealth(PlayStateConfig.MISS_HEALTH);

		// Sound
		FlxG.sound.play(Paths.soundRandom('missnote', 1, 3), FlxG.random.float(0.1, 0.2));

		// Animate
		if (boyfriend != null && gf != null)
		{
			gf.playAnim('sad',true);
			var anims = ['LEFT', 'DOWN', 'UP', 'RIGHT'];
			boyfriend.playAnim('sing' + anims[direction] + 'miss', true);
		}

		// Popup
		uiManager.showMissPopup();

		// Vocals
		vocals.volume = 0;

		if (scriptsEnabled)
			ScriptHandler.callOnScripts('onPlayerNoteMissPost', [direction]);
	}

	/**
	 * Callback: CPU hit note
	 */
	private function onCPUNoteHit(note:Note):Void
	{
		if (scriptsEnabled)
		{
			ScriptHandler.callOnScripts('onOpponentNoteHit', [note]);
			ScriptHandler.callOnScripts('onCharacterSing', ['dad', note.noteData]);
		}

		if (enableHoldSplashes && note.isSustainNote)
		{
			// Usamos un offset para no colisionar con las IDs de las notas del jugador (0-3)
			// Las notas de CPU las guardaremos como 4, 5, 6, 7
			var cpuDir = note.noteData + 4; 
			
			if (!heldNotes.exists(cpuDir))
			{
				heldNotes.set(cpuDir, note);
				var strum = cpuStrums.members[note.noteData];
				if (strum != null && FlxG.save.data.notesplashes)
				{
					var startSplash:NoteSplash = grpNoteSplashes.recycle(NoteSplash);
					startSplash.setup(strum.x, strum.y, note.noteData, null, HOLD_START);
					startSplash.cameras = [camHUD];
					
					if (!grpNoteSplashes.members.contains(startSplash))
						grpNoteSplashes.add(startSplash);
						
					// Iniciar el splash continuo para el oponente
					startContinuousHoldSplash(cpuDir, strum.x, strum.y);
				}
			}
		}

		// Enable zoom
		if (SONG.song != 'Tutorial')
			cameraController.zoomEnabled = true;

		var altAnim:String = getHasAltAnim(curStep) ? '-alt' : '';

		// GF/Dad singing logic
		var section = getSection(curStep);
		if (section != null)
		{
			gf.canSing = section.bothSing ? true : section.gfSing;

			if (gf.canSing && !section.bothSing)
			{
				dad.canSing = false;
				characterController.sing(gf, note.noteData, altAnim);
			}
			else
			{
				dad.canSing = true;
				characterController.sing(dad, note.noteData, altAnim);
			}
		}

		// Camera offset
		cameraController.applyNoteOffset(dad, note.noteData);

		// Splash
		if (FlxG.save.data.notesplashes && !FlxG.save.data.middlescroll && !note.isSustainNote)
			spawnNoteSplashOnNote(note, 0);

		// Vocals
		if (SONG.needsVoices)
			vocals.volume = 1;
	}

	/**
	 * Get health amount for rating
	 */
	private function getHealthForRating(rating:String):Float
	{
		switch (rating)
		{
			case 'sick':
				return PlayStateConfig.SICK_HEALTH;
			case 'good':
				return PlayStateConfig.GOOD_HEALTH;
			case 'bad':
				return PlayStateConfig.BAD_HEALTH;
			case 'shit':
				return PlayStateConfig.SHIT_HEALTH;
		}
		return 0;
	}

	/**
	 * Play hitsound
	 */
	private function playHitSound():Void
	{
		var hitSound:FlxSound = new FlxSound().loadEmbedded(Paths.sound('hitsounds/hit-${FlxG.random.int(1, 2)}'));
		hitSound.volume = 1 + FlxG.random.float(-0.2, 0.2);
		hitSound.looped = false;
		hitSound.play();
	}

	/**
	 * Spawn note splash
	 */
	public function spawnNoteSplashOnNote(note:Note, player:Int = 1):Void
	{
		if (note == null)
			return;

		var strum = player == 1 ? playerStrums.members[note.noteData] : cpuStrums.members[note.noteData];
		if (strum != null)
			spawnNoteSplash(strum.x, strum.y, note.noteData);
	}

	public function spawnNoteSplash(x:Float, y:Float, data:Int):Void
	{
		var splash:NoteSplash = grpNoteSplashes.recycle(NoteSplash);
		splash.setup(x, y, data);
		splash.cameras = [camHUD];
		splash.visible = true;
		splash.alpha = 0.7;
		splash.active = true;

		if (!grpNoteSplashes.members.contains(splash))
		{
			grpNoteSplashes.add(splash);
		}
	}

	/**
	 * Sync legacy stats
	 */
	private function syncLegacyStats():Void
	{
		songScore = gameState.score;
		misses = gameState.misses;
		sicks = gameState.sicks;
		goods = gameState.goods;
		bads = gameState.bads;
		shits = gameState.shits;
		accuracy = gameState.accuracy;
	}

	override function openSubState(SubState:FlxSubState)
	{
		if (paused)
		{
			if (scriptsEnabled)
			{
				var cancel = ScriptHandler.callOnScriptsReturn('onPause', [], false);
				if (cancel == true)
					return;
			}

			if (FlxG.sound.music != null)
			{
				FlxG.sound.music.pause();
				vocals.pause();
			}

			#if desktop
			updatePresence();
			#end
			if (!startTimer.finished)
				startTimer.active = false;
		}

		super.openSubState(SubState);
	}

	override function closeSubState()
	{
		if (paused)
		{
			if (FlxG.sound.music != null && !startingSong)
			{
				resyncVocals();
			}

			if (!startTimer.finished)
				startTimer.active = true;
			paused = false;

			#if desktop
			if (startTimer.finished)
			{
				updatePresence();
			}
			else
			{
				updatePresence();
			}
			#end
			if (scriptsEnabled)
				ScriptHandler.callOnScripts('onResume', []);
		}

		super.closeSubState();
	}

	/**
	 * Beat hit
	 */
	override function beatHit()
	{
		super.beatHit();

		// Hooks
		for (hook in onBeatHitHooks)
			hook(curBeat);

		if (currentStage != null)
        	currentStage.beatHit(curBeat);

		if (scriptsEnabled)
			ScriptHandler.callOnScripts('onBeatHit', [curBeat]);

		// Character dance
		characterController.danceOnBeat(curBeat);

		// Camera zoom
		if (curBeat % 4 == 0)
			cameraController.bumpZoom();

		// UI bump
		uiManager.bumpIcons();

		// Song-specific effects
		if (SONG.song.toLowerCase() == 'milf' && curBeat >= 168 && curBeat < 200)
		{
			if (camGame.zoom < 1.35)
			{
				camGame.zoom += 0.015;
				camHUD.zoom += 0.03;
			}
		}

		// Special animations
		if (curBeat % 8 == 7 && SONG.song.toLowerCase() == 'bopeebo')
		{
			if (boyfriend != null)
				characterController.playSpecialAnim(boyfriend, 'hey');
		}
	}

	/**
	 * Step hit
	 */
	override function stepHit()
	{
		super.stepHit();

		// Hooks
		for (hook in onStepHitHooks)
			hook(curStep);

		if (currentStage != null)
        	currentStage.stepHit(curStep);

		if (scriptsEnabled)
		{
			ScriptHandler.callOnScripts('onStepHit', [curStep]);
			
			// Section change
			var section = Math.floor(curStep / 16);
			if (section != cachedSectionIndex)
				ScriptHandler.callOnScripts('onSectionHit', [section]);
		}

		// Resync music - MEJORADO
		if (FlxG.sound.music != null && Math.abs(FlxG.sound.music.time - Conductor.songPosition) > 20)
		{
			resyncVocals();
		}
	}

	/**
	 * Resync vocals - MEJORADO
	 */
	function resyncVocals():Void
	{
		if (SONG.needsVoices && vocals != null)
		{
			vocals.pause();
		}

		FlxG.sound.music.play();
		Conductor.songPosition = FlxG.sound.music.time;

		if (SONG.needsVoices && vocals != null)
		{
			vocals.time = Conductor.songPosition;
			vocals.play();
		}
	}

	/**
	 * End song
	 */
	public function endSong():Void
	{
		if (scriptsEnabled)
		{
			ScriptHandler.callOnScripts('onSongEnd', []);
		}

		canPause = false;
		FlxG.sound.music.volume = 0;
		vocals.volume = 0;
		isPlaying = false;

		if (SONG.validScore)
		{
			Highscore.saveScore(SONG.song, songScore, storyDifficulty);
		}

		if (isStoryMode)
		{
			campaignScore += songScore;
			storyPlaylist.remove(storyPlaylist[0]);

			if (storyPlaylist.length <= 0)
			{
				FlxG.sound.playMusic(Paths.music('freakyMenu'));

				if (SONG.validScore)
					Highscore.saveWeekScore(storyWeek, campaignScore, storyDifficulty);

				FlxG.save.flush();
				LoadingState.loadAndSwitchState(new RatingState());
			}
			else
			{
				// Next song
				SONG = Song.loadFromJson(storyPlaylist[0].toLowerCase() + CoolUtil.difficultyPath[storyDifficulty], storyPlaylist[0]);
				FlxG.sound.music.stop();
				LoadingState.loadAndSwitchState(new PlayState());
			}
		}
		else
		{
			FlxG.sound.music.stop();
			vocals.stop();
			LoadingState.loadAndSwitchState(new RatingState());
		}
	}

	/**
	 * Game over
	 */
	function gameOver():Void
	{
		if (scriptsEnabled)
		{
			var cancel = ScriptHandler.callOnScriptsReturn('onGameOver', [], false);
			if (cancel == true)
				return;
		}

		boyfriend.stunned = true;
		persistentUpdate = false;
		persistentDraw = false;
		paused = true;

		FlxG.sound.music.stop();

		openSubState(new GameOverSubstate(boyfriend.getScreenPosition().x, boyfriend.getScreenPosition().y));

		#if desktop
		DiscordClient.changePresence("GAME OVER", SONG.song + " (" + storyDifficultyText + ")", iconRPC);
		#end
	}

	// ====================================
	// MÉTODOS HELPER PARA SECCIONES
	// ====================================

	/**
	 * Obtener sección actual (con cache)
	 */
	public function getSection(step:Int):SwagSection
	{
		var sectionIndex = Math.floor(step / 16);

		// Cache hit
		if (cachedSectionIndex == sectionIndex && cachedSection != null)
			return cachedSection;

		// Cache miss
		cachedSectionIndex = sectionIndex;
		cachedSection = (SONG.notes[sectionIndex] != null) ? SONG.notes[sectionIndex] : null;

		return cachedSection;
	}

	/**
	 * Verificar si la sección es del jugador
	 */
	public function getMustHitSection(step:Int):Bool
	{
		var section = getSection(step);
		return section != null ? section.mustHitSection : true;
	}

	/**
	 * Verificar si hay animación alterna
	 */
	public function getHasAltAnim(step:Int):Bool
	{
		var section = getSection(step);
		return section != null ? section.altAnim : false;
	}

	/**
	 * Destroy
	 */
	override function destroy()
	{
		currentStage.destroy();
		if (scriptsEnabled)
		{
			ScriptHandler.callOnScripts('onDestroy', []);
			ScriptHandler.clearSongScripts();
			EventManager.clear();
		}

		// Destroy controllers
		if (cameraController != null)
			cameraController.destroy();

		if (noteManager != null)
			noteManager.destroy();
		
		// NUEVO: Destroy batcher
		if (noteBatcher != null) {
			remove(noteBatcher, true);
			noteBatcher.destroy();
			noteBatcher = null;
		}
		
		// NUEVO: Limpiar hold splashes
		heldNotes.clear();
		holdSplashes.clear();

		GameState.destroy();

		// Clear hooks
		onBeatHitHooks.clear();
		onStepHitHooks.clear();
		onUpdateHooks.clear();
		onNoteHitHooks.clear();
		onNoteMissHooks.clear();

		super.destroy();
	}
}