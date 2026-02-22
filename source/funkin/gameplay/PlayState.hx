package funkin.gameplay;

// Core imports
import flixel.FlxG;
import flixel.FlxCamera;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import funkin.transitions.StateTransition;
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
import funkin.gameplay.notes.NotePool;
import funkin.optimization.GPURenderer;
import funkin.optimization.OptimizationManager;
import funkin.gameplay.objects.character.CharacterSlot;
import funkin.gameplay.objects.StrumsGroup;
import funkin.debug.StageEditor;
import funkin.data.Song.CharacterSlotData;
import funkin.data.Song.StrumsGroupData;
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
import funkin.data.Section;
import funkin.data.Conductor;
import funkin.data.CoolUtil;
import funkin.gameplay.objects.hud.Highscore;
import funkin.states.LoadingState;
import funkin.states.GameOverSubstate;
import funkin.menus.RatingState;
import funkin.gameplay.objects.hud.ScoreManager;
import funkin.transitions.StickerTransition;
// Menu Pause
import funkin.menus.GitarooPause;
import funkin.menus.PauseSubState;
import funkin.debug.charting.ChartingState;
import funkin.debug.DialogueEditor;
#if desktop
import data.Discord.DiscordClient;
#end
// Cutscenes
import funkin.cutscenes.dialogue.DialogueBoxImproved;
import funkin.cutscenes.dialogue.DialogueData;
import funkin.cutscenes.VideoManager;
import funkin.data.MetaData;
import funkin.gameplay.UIScriptedManager;
// ModChart
import funkin.gameplay.modchart.ModChartEvent;
import funkin.gameplay.modchart.ModChartManager;
import funkin.gameplay.modchart.ModChartEditorState;

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

	// ✨ CHART TESTING: Tiempo desde el cual empezar (para testear secciones específicas)
	public static var startFromTime:Null<Float> = null;

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
	public var gameState:GameState;
	private var noteManager:NoteManager;
	private var inputHandler:InputHandler;

	public var cameraController:CameraController;

	public var uiManager:UIScriptedManager;
	private var characterController:CharacterController;

	public var metaData:MetaData;

	public var scriptsEnabled:Bool = true;

	var isCutscene:Bool = false;

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

	// ── MODCHART ──
	public var modChartManager:ModChartManager;

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

	public var inCutscene:Bool = false;

	public static var isPlaying:Bool = false;

	public var canPause:Bool = true;

	public var paused:Bool = false;

	// === HOOKS ===
	// Almacenados como Map para registro por nombre (add/remove O(1))
	// pero iterados via arrays cacheados para evitar el overhead del iterador de Map.
	public var onBeatHitHooks:Map<String, Int->Void> = new Map();
	public var onStepHitHooks:Map<String, Int->Void> = new Map();
	public var onUpdateHooks:Map<String, Float->Void> = new Map();
	public var onNoteHitHooks:Map<String, Note->Void> = new Map();
	public var onNoteMissHooks:Map<String, Note->Void> = new Map();

	// Arrays cacheados para iteración en el game loop (se reconstruyen al modificar los Maps)
	private var _beatHookArr:Array<Int->Void> = [];
	private var _stepHookArr:Array<Int->Void> = [];
	private var _updateHookArr:Array<Float->Void> = [];
	private var _noteHitHookArr:Array<Note->Void> = [];
	private var _noteMissHookArr:Array<Note->Void> = [];

	/** Llama tras añadir/quitar cualquier hook para reconstruir los arrays cacheados. */
	public function rebuildHookArrays():Void
	{
		_beatHookArr = [for (h in onBeatHitHooks) h];
		_stepHookArr = [for (h in onStepHitHooks) h];
		_updateHookArr = [for (h in onUpdateHooks) h];
		_noteHitHookArr = [for (h in onNoteHitHooks) h];
		_noteMissHookArr = [for (h in onNoteMissHooks) h];
	}

	// === OPTIMIZATION ===
	private var strumLiney:Float = PlayStateConfig.STRUM_LINE_Y;

	public var optimizationManager:OptimizationManager;

	// === SECTION CACHE ===
	private var cachedSection:SwagSection = null;
	private var cachedSectionIndex:Int = -1;

	// Wrapper de Section reutilizable — evita new Section() en cada nota del CPU
	private var _cachedSectionClass:Section = null;
	private var _cachedSectionClassIdx:Int = -2;

	// === NEW: BATCHING AND HOLD NOTES ===
	private var noteBatcher:NoteBatcher;
	private var heldNotes:Map<Int, Note> = new Map(); // dirección -> nota
	private var holdSplashes:Map<Int, NoteSplash> = new Map(); // dirección -> splash continuo

	// NEW: CONFIG OPTIMIZATIONS
	public var enableBatching:Bool = true;
	public var enableHoldSplashes:Bool = true;

	private var showDebugStats:Bool = false;
	private var debugText:FlxText;

	// ─── Countdown pre-loaded sprites (evita lag en el primer frame) ──────────
	private var _cntdwnSprites:Array<FlxSprite> = [];
	private var _cntdwnLoaded:Bool = false;

	private var characterSlots:Array<CharacterSlot> = [];
	private var strumsGroups:Array<StrumsGroup> = [];

	// Mapeos para acceso rápido
	private var strumsGroupMap:Map<String, StrumsGroup> = new Map();
	private var activeCharIndices:Array<Int> = []; // Personajes activos en la sección actual

	// ✅ Referencias directas a los grupos de strums
	private var playerStrumsGroup:StrumsGroup = null;
	private var cpuStrumsGroup:StrumsGroup = null;

	#if desktop
	var storyDifficultyText:String = "";
	var iconRPC:String = "";
	var detailsText:String = "";
	var detailsPausedText:String = "";
	#end

	override public function create()
	{
		if (StickerTransition.enabled)
		{
			transIn = null;
			transOut = null;
		}
		instance = this;
		isPlaying = true;

		FlxG.mouse.visible = false;

		if (scriptsEnabled)
		{
			ScriptHandler.init();
			ScriptHandler.loadSongScripts(SONG.song);
			EventManager.loadEventsFromSong();

			// Exponer PlayState a los scripts
			ScriptHandler.setOnScripts('playState', this);
			ScriptHandler.setOnScripts('game', this);
			ScriptHandler.setOnScripts('SONG', SONG);
			// Llamar onCreate en scripts
			ScriptHandler.callOnScripts('onCreate', []);
		}

		// Validar SONG
		if (SONG.stage == null)
			SONG.stage = 'stage_week1';

		curStage = SONG.stage;
		Paths.currentStage = curStage; // sync Paths para resolución de assets de stage

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

		metaData = MetaData.load(SONG.song);
		NoteSkinSystem.init();
		NoteSkinSystem.setTemporarySkin(metaData.noteSkin);

		StickerTransition.clearStickers();

		if (scriptsEnabled)
		{
			ScriptHandler.setOnScripts('boyfriend', boyfriend);
			ScriptHandler.setOnScripts('dad', dad);
			ScriptHandler.setOnScripts('gf', gf);
			ScriptHandler.setOnScripts('stage', currentStage);
			ScriptHandler.callOnScripts('onStageCreate', []);
			ScriptHandler.callOnScripts('postCreate', []);
			ScriptHandler.setOnScripts('author', GameState.listAuthor);
		}

		// Crear UI groups
		createNoteGroups();

		// Crear controllers
		setupControllers();

		modChartManager = new ModChartManager(strumsGroups);
		modChartManager.data.song = SONG.song;
		modChartManager.loadFromFile(SONG.song); // carga assets/modcharts/<song>.json si existe

		// Generar música
		generateSong();

		// Crear UI
		setupUI();

		// Pool de sonidos de golpe (evita alloc por nota)
		initHitSoundPool();

		// NUEVO: Setup debug display
		setupDebugDisplay();

		if (scriptsEnabled)
		{
			ScriptHandler.setOnScripts('camGame', camGame);
			ScriptHandler.setOnScripts('camHUD', camHUD);
			ScriptHandler.setOnScripts('camCountdown', camCountdown);
		}

		optimizationManager = new OptimizationManager();
		optimizationManager.init();

		// Pre-cargar sprites de countdown ANTES de iniciar el timer
		// (evita el lag del primer frame donde loadGraphic parsea la imagen)
		_preloadCountdown();

		// StickerTransition.clearStickers(function() {
		startCountdown();
		// });

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
		loadCharacters();

		if (characterSlots.length > 0)
			gf = characterSlots[0].character;
		if (characterSlots.length > 1)
			dad = characterSlots[1].character;
		if (characterSlots.length > 2)
			boyfriend = characterSlots[2].character;
	}

	private function loadCharacters():Void
	{
		if (SONG.characters != null)
			// ✅ NUEVO: Si no hay personajes, crear por defecto (compatibilidad con charts antiguos)
			if (SONG.characters == null || SONG.characters.length == 0)
			{
				// Crear personajes por defecto usando los campos legacy
				SONG.characters = [];

				SONG.characters.push({
					name: SONG.gfVersion != null ? SONG.gfVersion : 'gf',
					x: 0,
					y: 0,
					visible: true
				});

				SONG.characters.push({
					name: SONG.player2 != null ? SONG.player2 : 'dad',
					x: 0,
					y: 0,
					visible: true
				});

				SONG.characters.push({
					name: SONG.player1 != null ? SONG.player1 : 'bf',
					x: 0,
					y: 0,
					visible: true
				});
			}

		// Crear slots de personajes
		for (i in 0...SONG.characters.length)
		{
			var charData = SONG.characters[i];
			var slot = new CharacterSlot(charData, i);

			// Si la posición es (0,0), usar posición del stage
			if (charData.x == 0 && charData.y == 0)
			{
				switch (i)
				{
					case 0: // GF
						slot.character.setPosition(currentStage.gfPosition.x, currentStage.gfPosition.y);
					case 1: // Dad
						slot.character.setPosition(currentStage.dadPosition.x, currentStage.dadPosition.y);
					case 2: // BF (o segundo oponente)
						slot.character.setPosition(currentStage.boyfriendPosition.x, currentStage.boyfriendPosition.y);
					default:
						// Posicionamiento personalizado para personajes adicionales
				}
			}
			else
			{
				// Usar posición del JSON
				slot.character.setPosition(charData.x, charData.y);
			}

			characterSlots.push(slot);
			add(slot.character);
		}
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

		// ✅ Inicializar strumLineNotes ANTES de loadStrums()
		strumLineNotes = new FlxTypedGroup<FlxSprite>();
		strumLineNotes.cameras = [camHUD];
		add(strumLineNotes);

		// loadStrums() asigna playerStrums y cpuStrums automáticamente
		loadStrums();

		notes = new FlxTypedGroup<Note>();
		notes.cameras = [camHUD];
		add(notes);

		grpNoteSplashes = new FlxTypedGroup<NoteSplash>();
		grpNoteSplashes.cameras = [camHUD];
		add(grpNoteSplashes);
	}

	private function loadStrums():Void
	{
		if (SONG.strumsGroups == null || SONG.strumsGroups.length == 0)
		{
			return;
		}

		// Crear grupos
		for (groupData in SONG.strumsGroups)
		{
			var group = new StrumsGroup(groupData);
			strumsGroups.push(group);
			strumsGroupMap.set(groupData.id, group);

			// Añadir strums al juego
			group.strums.forEach(function(strum:FlxSprite)
			{
				strumLineNotes.add(strum);
			});

			// Separar CPU y Player strums (para compatibilidad)
			if (groupData.cpu && cpuStrums == null)
			{
				cpuStrums = group.strums;
				cpuStrumsGroup = group; // ✅ Guardar referencia al grupo completo
				if (FlxG.save.data.downscroll)
				{
					for (i in 0...cpuStrums.members.length)
					{
						cpuStrums.members[i].y = FlxG.height - 150;
					}
				}
				if (FlxG.save.data.middlescroll)
				{
					for (i in 0...cpuStrums.members.length)
					{
						cpuStrums.members[i].alpha = 0;
					}
				}
			}
			else if (!groupData.cpu && playerStrums == null)
			{
				playerStrums = group.strums;
				playerStrumsGroup = group; // ✅ Guardar referencia al grupo completo

				// Verificar posiciones de cada strum
				for (i in 0...playerStrums.members.length)
				{
					var s = playerStrums.members[i];

					if (FlxG.save.data.downscroll)
						playerStrums.members[i].y = FlxG.height - 150;

					if (FlxG.save.data.middlescroll)
					{
						playerStrums.members[i].x -= (FlxG.width / 4);
					}
				}
			}
		}
	}

	/**
	 * Setup controllers - MEJORADO con splashes
	 */
	private function setupControllers():Void
	{
		// ✅ Verificar que boyfriend y dad existan antes de crear CameraController
		if (boyfriend == null || dad == null)
		{
			// En modo debug, crear personajes de emergencia
			#if debug
			if (boyfriend == null)
			{
				boyfriend = new Character(100, 100, 'bf');
				add(boyfriend);
			}
			if (dad == null)
			{
				dad = new Character(100, 100, 'dad');
				add(dad);
			}
			#else
			// En producción, volver al menú
			StateTransition.switchState(new funkin.menus.MainMenuState());
			return;
			#end
		}

		// Camera controller
		cameraController = new CameraController(camGame, camHUD, boyfriend, dad, gf);

		if (currentStage.defaultCamZoom > 0)
			cameraController.defaultZoom = currentStage.defaultCamZoom;

		// Character controller
		characterController = new CharacterController();
		characterController.initFromSlots(characterSlots);

		ScriptHandler.setOnScripts('characterController', characterController);

		// Input handler
		inputHandler = new InputHandler();
		inputHandler.ghostTapping = FlxG.save.data.ghosttap;
		inputHandler.onNoteHit = onPlayerNoteHit;
		inputHandler.onNoteMiss = onPlayerNoteMiss;

		// NUEVO: Configurar buffering si lo deseas
		inputHandler.inputBuffering = true;
		inputHandler.bufferTime = 0.1; // 100ms

		// NUEVO: Callback para release de hold notes
		// inputHandler.onKeyRelease = onKeyRelease;  for now note hold splashes disabled :(

		// AJUSTE: Calcular posición de strums según downscroll
		if (FlxG.save.data.downscroll)
			strumLiney = FlxG.height - 150; // Flechas abajo
		else
			strumLiney = PlayStateConfig.STRUM_LINE_Y; // Flechas arriba (50 por defecto)

		// Note manager - MEJORADO con splashes
		// ✅ Pasar referencias a StrumsGroup para animaciones de confirm
		// ✅ Pasar lista completa de grupos para soporte de personajes extra
		noteManager = new NoteManager(notes, playerStrums, cpuStrums, grpNoteSplashes, playerStrumsGroup, cpuStrumsGroup, strumsGroups);
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

		// ✅ Verificar que existan antes de acceder a sus propiedades
		if (boyfriend != null && dad != null)
		{
			if (boyfriend.healthIcon != null && dad.healthIcon != null)
				icons = [boyfriend.healthIcon, dad.healthIcon];
		}

		uiManager = new UIScriptedManager(camHUD, gameState, metaData);
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

		// Cargar instrumental usando el método seguro que soporta archivos externos
		FlxG.sound.music = Paths.loadInst(SONG.song);
		FlxG.sound.music.volume = 0;
		FlxG.sound.music.pause();
		// NO añadir FlxG.sound.music a sound.list manualmente:
		// Flixel ya lo gestiona internamente — añadirlo duplica la entrada
		// y provoca doble-destroy del buffer de audio al cambiar de estado.

		// Limpiar vocals anterior si existía (por si se llama generateSong más de una vez)
		if (vocals != null)
		{
			FlxG.sound.list.remove(vocals, true);
			vocals.stop();
			vocals.destroy();
			vocals = null;
		}

		// Cargar voces usando el método seguro
		if (SONG.needsVoices)
			vocals = Paths.loadVoices(SONG.song);
		else
			vocals = new FlxSound();

		vocals.volume = 0;
		vocals.pause();
		FlxG.sound.list.add(vocals);

		// Generar notas

		noteManager.generateNotes(SONG);

		generatedMusic = true;
	}

	/**
	 * Start countdown
	 */
	var startedCountdown:Bool = false;

	var startTimer:FlxTimer = null;

	public function startCountdown():Void
	{
		if (scriptsEnabled)
		{
			var result = ScriptHandler.callOnScriptsReturn('onCountdownStarted', [], false);
			if (result == true)
				return; // Script canceló el countdown
		}

		if (startedCountdown)
		{
			return;
		}

		// ── Intro video (meta.json: "introVideo": "my-video") ─────────────────
		// If there is a defined introduction video, it plays BEFORE the dialogue/countdown.
		if (metaData != null && metaData.introVideo != null)
		{
			final vidKey = metaData.introVideo;
			metaData.introVideo = null; // avoid loop if called again

			if (VideoManager._resolvePath(vidKey) != null)
			{
				inCutscene = true;
				VideoManager.playCutscene(vidKey, function()
				{
					inCutscene = false;
					startCountdown(); // continuar flujo normal
				});
				return;
			}
		}

		if (checkForDialogue('intro') && isStoryMode)
		{
			inCutscene = true;

			showDialogue('intro', function()
			{
				// CRÍTICO: Restaurar FlxG.sound.music con el instrumental de la canción
				// El diálogo pudo haber usado FlxG.sound.music, así que lo restauramos
				FlxG.sound.music = Paths.loadInst(SONG.song);
				FlxG.sound.music.volume = 0;
				FlxG.sound.music.pause();
				// No añadir a sound.list — Flixel gestiona FlxG.sound.music internamente

				// CRÍTICO: Recargar las vocales también
				if (vocals != null)
				{
					FlxG.sound.list.remove(vocals, true);
					vocals.stop();
					vocals.destroy();
					vocals = null;
				}

				if (SONG.needsVoices)
				{
					vocals = Paths.loadVoices(SONG.song);
				}
				else
				{
					vocals = new FlxSound();
				}

				vocals.volume = 0;
				vocals.pause();
				FlxG.sound.list.add(vocals);

				// Cuando termina el diálogo, ejecutar el countdown
				executeCountdown();
			});
			return;
		}
		else
			executeCountdown();
	}

	public function executeCountdown():Void
	{
		isCutscene = false;

		// ✨ CHART TESTING: Si hay un tiempo de inicio específico, skipear countdown
		if (startFromTime != null)
		{
			// Verificar que la música esté cargada
			if (FlxG.sound.music == null)
			{
				startFromTime = null;
				// Continuar con countdown normal como fallback
			}
			else
			{
				var targetTime = startFromTime; // Guardar el tiempo antes de resetear

				// Configurar estado del juego
				startingSong = false;
				startedCountdown = true;

				// Resetear startFromTime inmediatamente
				startFromTime = null;

				// ✨ LIMPIAR NOTAS ANTIGUAS antes de empezar (marcarlas como ya golpeadas)
				// ✨ NUEVO: Limpieza profunda de notas (internas y activas)

				if (noteManager != null)
				{
					// 1. Limpiar las notas que aún no han "nacido" (unspawnNotes) en el manager
					noteManager.clearNotesBefore(targetTime);
				}

				// 2. Limpiar cualquier nota que ya esté en el grupo activo por error
				notes.forEachAlive(function(note:Note)
				{
					if (note.strumTime < targetTime - 100)
					{
						note.kill();
						notes.remove(note, true);
					}
				});

				// 3. Limpiar el buffer de entrada para evitar inputs residuales
				if (inputHandler != null)
				{
					inputHandler.resetMash();
					inputHandler.clearBuffer();
				}

				// ✨ Usar un delay para asegurar que la música esté lista
				new FlxTimer().start(0.2, function(tmr:FlxTimer)
				{
					if (FlxG.sound.music == null)
					{
						return;
					}

					// Configurar callbacks y volumen
					FlxG.sound.music.volume = 1;
					FlxG.sound.music.onComplete = endSong;

					// ✨ CRITICAL: Primero REPRODUCIR, luego setear el tiempo
					FlxG.sound.music.play();

					// Ahora setear el tiempo DESPUÉS de play()
					FlxG.sound.music.time = targetTime;
					var actualTime = FlxG.sound.music.time;

					// Verificar que el tiempo se haya seteado correctamente
					if (Math.abs(actualTime - targetTime) > 100)
					{
						FlxG.sound.music.time = targetTime;
						actualTime = FlxG.sound.music.time;
					}

					// Setear tiempo para vocals
					if (vocals != null)
					{
						vocals.volume = 1;
						vocals.play();
						vocals.time = targetTime;
						var vocalsTime = vocals.time;
					}

					// Actualizar Conductor.songPosition
					Conductor.songPosition = actualTime;
				});

				return;
			}
		}

		// Countdown normal
		Conductor.songPosition = 0;
		Conductor.songPosition = -Conductor.crochet * 5;

		var swagCounter:Int = 0;

		// Configurar startingSong ANTES del timer
		startingSong = true;
		startedCountdown = true;

		var introSprPaths:Array<String> = ["UI/normal/ready", "UI/normal/set", "UI/normal/go"];
		var altSuffix:String = "";

		if (curStage.startsWith('school'))
		{
			altSuffix = '-pixel';
			introSprPaths = ['UI/pixelUI/ready-pixel', 'UI/pixelUI/set-pixel', 'UI/pixelUI/date-pixel'];
		}

		var introSndPaths:Array<String> = [
			"intro3" + altSuffix, "intro2" + altSuffix,
			"intro1" + altSuffix, "introGo" + altSuffix
		];

		startTimer = new FlxTimer().start(Conductor.crochet / 1000, function(tmr:FlxTimer)
		{
			characterController.danceOnBeat(curBeat);

			if (swagCounter > 0)
				getCountdown(introSprPaths[swagCounter - 1]);

			FlxG.sound.play(Paths.sound(introSndPaths[swagCounter]), 0.6);
			swagCounter += 1;
		}, 4);
	}

	// ─── Pre-carga de sprites de countdown ──────────────────────────────────
	// Llamado una vez antes de startTimer. Carga los 3 gráficos en memoria.
	// Cuando llega el beat, el sprite ya está listo → cero lag.
	private function _preloadCountdown():Void
	{
		if (_cntdwnLoaded)
			return;

		var paths:Array<String> = curStage.startsWith('school') ? ['UI/pixelUI/ready-pixel', 'UI/pixelUI/set-pixel', 'UI/pixelUI/date-pixel'] : ['UI/normal/ready', 'UI/normal/set', 'UI/normal/go'];

		_cntdwnSprites = [];
		for (p in paths)
		{
			var spr = new FlxSprite();
			spr.loadGraphic(Paths.image(p));
			spr.cameras = [camCountdown];
			spr.scrollFactor.set();
			if (curStage.startsWith('school'))
				spr.setGraphicSize(Std.int(spr.width * PlayStateConfig.PIXEL_ZOOM));
			else
			{
				spr.setGraphicSize(Std.int(spr.width * 0.7));
				spr.antialiasing = FlxG.save.data.antialiasing;
			}
			spr.updateHitbox();
			spr.alpha = 0;
			spr.visible = false;
			spr.active = false;
			add(spr);
			_cntdwnSprites.push(spr);
		}
		_cntdwnLoaded = true;
	}

	// ─── Mostrar sprite de countdown con animación suave ─────────────────────
	// Entrada: scale punch 1.3 → 1.0 con elasticOut + alpha rápido
	// Salida:  flota 30px hacia arriba + fade con cubeIn
	function getCountdown(path:String)
	{
		// Determinar índice del sprite pre-cargado
		var idx:Int = -1;
		var paths:Array<String> = curStage.startsWith('school') ? ['UI/pixelUI/ready-pixel', 'UI/pixelUI/set-pixel', 'UI/pixelUI/date-pixel'] : ['UI/normal/ready', 'UI/normal/set', 'UI/normal/go'];

		for (i in 0...paths.length)
			if (paths[i] == path)
			{
				idx = i;
				break;
			}

		// Fallback al comportamiento antiguo si no hay sprite pre-cargado
		if (idx < 0 || idx >= _cntdwnSprites.length)
		{
			var asset:FlxSprite = new FlxSprite().loadGraphic(Paths.image(path));
			asset.cameras = [camCountdown];
			asset.scrollFactor.set();
			asset.scale.set(0.7, 0.7);
			if (curStage.startsWith('school'))
				asset.setGraphicSize(Std.int(asset.width * PlayStateConfig.PIXEL_ZOOM));
			else
				asset.antialiasing = FlxG.save.data.antialiasing;

			asset.updateHitbox();
			asset.screenCenter();
			add(asset);
			FlxTween.tween(asset, {y: asset.y + 80, alpha: 0}, Conductor.crochet / 1000, {ease: FlxEase.cubeInOut, onComplete: function(_)
			{
				asset.destroy();
			}});
			return;
		}

		var spr = _cntdwnSprites[idx];
		final dur = Conductor.crochet / 1000.0;

		// Cancelar tweens anteriores de este sprite
		FlxTween.cancelTweensOf(spr);
		FlxTween.cancelTweensOf(spr.scale);

		// Estado inicial: centrado, invisible, escala grande
		spr.screenCenter();
		spr.visible = true;
		spr.active = true;
		spr.alpha = 0;
		spr.scale.set(1.3, 1.3);

		// Pequeña rotación aleatoria para dar vida (solo sprites HD, no pixel)
		if (!curStage.startsWith('school'))
			spr.angle = FlxG.random.float(-4, 4);

		// ── ENTRADA: alpha + scale punch rápidos ──────────────────────────────
		final inDur = dur * 0.20;
		FlxTween.tween(spr, {alpha: 1.0}, inDur, {ease: FlxEase.quadOut});
		FlxTween.tween(spr.scale, {x: spr.scale.x + 0.3, y: spr.scale.y + 0.3}, inDur * 1.8, {ease: FlxEase.elasticOut});

		// Micro-pulse a mitad del beat (scale 1.0 → 1.05 → 1.0)
		FlxTween.tween(spr.scale, {x: spr.scale.x + 0.06, y: spr.scale.y + 0.06}, dur * 0.12, {
			ease: FlxEase.sineOut,
			startDelay: dur * 0.3,
			onComplete: function(_)
			{
				if (spr.alive)
					FlxTween.tween(spr.scale, {x: spr.scale.x - 0.06, y: spr.scale.y - 0.06}, dur * 0.08, {ease: FlxEase.sineIn});
			}
		});

		// ── SALIDA: flota hacia arriba + fade ─────────────────────────────────
		final exitDelay = dur * 0.52;
		final exitDur = dur * 0.48;
		var targetY = spr.y; // guardar Y antes de que el tween la mueva
		FlxTween.tween(spr, {alpha: 0, y: targetY - 32}, exitDur, {
			ease: FlxEase.quadIn,
			startDelay: exitDelay,
			onComplete: function(_)
			{
				spr.visible = false;
				spr.active = false;
				spr.angle = 0;
				spr.scale.set(1, 1);
			}
		});
	}

	override public function update(elapsed:Float)
	{
		if (scriptsEnabled)
			ScriptHandler.callOnScripts('onUpdate', [elapsed]);

		if (currentStage != null)
			currentStage.update(elapsed);

		// Update ModChart
		if (modChartManager != null && !paused && generatedMusic)
			modChartManager.update(Conductor.songPosition);

		super.update(elapsed);

		if (optimizationManager != null)
			optimizationManager.update(elapsed);

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

		// Hooks — iteración sobre arrays cacheados (sin overhead de Map iterator)
		for (hook in _updateHookArr)
			hook(elapsed);

		// Update controllers
		if (!paused && !inCutscene)
		{
			// Update characters
			characterController.update(elapsed);

			// Update camera — el target se controla por eventos (Camera Follow)
			cameraController.update(elapsed);

			// Update note manager
			if (generatedMusic)
			{
				noteManager.update(Conductor.songPosition);
			}

			// Update input
			if (boyfriend != null && !boyfriend.stunned)
			{
				inputHandler.update();
				inputHandler.processInputs(notes);
				inputHandler.processSustains(notes);
				updatePlayerStrums();

				if (paused)
					inputHandler.clearBuffer();

				// ✅ Actualizar animaciones de StrumsGroups
				for (group in strumsGroups)
				{
					if (group != null)
						group.update();
				}

				if (inputHandler != null && noteManager != null)
					inputHandler.checkMisses(notes);
			}

			// Update UI
			uiManager.update(elapsed);

			// Sync legacy stats
			syncLegacyStats();

			// Check death
			if (gameState.isDead() || FlxG.keys.anyJustPressed(inputHandler.killBind))
				gameOver();

			// Limpiar hold splashes de CPU que ya no tienen notas activas
			for (key in heldNotes.keys())
			{
				if (key >= 4)
				{ // Es una nota de CPU
					var note = heldNotes.get(key);
					// Si la canción ya pasó el tiempo de la nota + su duración
					if (Conductor.songPosition > note.strumTime + note.sustainLength)
					{
						onKeyRelease(key); // Reutilizamos la función de limpieza
					}
				}
			}
		}

		if (vocals != null && SONG.needsVoices && !inCutscene)
		{
			if (vocals.volume < 1)
			{
				vocals.volume += elapsed * 2; // Aumenta 2 por segundo
				if (vocals.volume > 1)
					vocals.volume = 1;
			}
		}

		if (FlxG.keys.justPressed.ENTER && startedCountdown && canPause)
		{
			pauseMenu();
		}

		if (FlxG.keys.justPressed.SEVEN)
		{
			FlxG.mouse.visible = true;
			StateTransition.switchState(new ChartingState());
		}

		if (FlxG.keys.justPressed.F8 && startedCountdown && canPause)
		{
			// Transferir datos al editor vía statics ANTES de hacer el switch
			// (PlayState.destroy() se llamará después del switch)
			ModChartEditorState.pendingManager = modChartManager;
			ModChartEditorState.pendingStrumsData = strumsGroups.map(function(g) return g.data);
			// Nullear para que PlayState.destroy() no destruya el manager que el editor necesita
			modChartManager = null;

			FlxG.mouse.visible = true;
			StateTransition.switchState(new ModChartEditorState());
		}

		/*
			if (FlxG.keys.justPressed.EIGHT)
			{
				StateTransition.switchState(new StageEditor());
			}

			if (FlxG.keys.justPressed.NINE)
			{
				persistentUpdate = false;
				persistentDraw = true;
				paused = true;
				StateTransition.switchState(new DialogueEditor());
		}*/

		// Song time - SINCRONIZACIÓN MEJORADA
		if (startingSong && startedCountdown && !inCutscene)
		{
			if (FlxG.sound.music != null && Conductor.songPosition >= 0)
			{
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
			StateTransition.switchState(new GitarooPause());
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
		startingSong = false;

		// Iniciar música e instrumental juntos
		if (FlxG.sound.music != null && !inCutscene)
		{
			// La música ya está cargada, solo necesitamos reproducirla
			FlxG.sound.music.volume = 1;
			FlxG.sound.music.time = 0;
			FlxG.sound.music.play();
			FlxG.sound.music.onComplete = endSong;
		}

		// Sincronizar vocales con música
		if (SONG.needsVoices && vocals != null && !inCutscene)
		{
			vocals.volume = 1;
			vocals.time = 0;
			vocals.play();
		}

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
		// ✅ Si tenemos StrumsGroup, usarlo directamente
		if (playerStrumsGroup != null)
		{
			for (i in 0...4)
			{
				if (inputHandler.pressed[i] && !isPlayingConfirm(i))
				{
					playerStrumsGroup.playPressed(i);
				}

				if (inputHandler.released[i])
				{
					playerStrumsGroup.resetStrum(i);
				}
			}
			return;
		}

		// ✅ Fallback al sistema antiguo
		playerStrums.forEach(function(spr:FlxSprite)
		{
			// Verificar que animation y curAnim no sean null
			if (spr.animation == null || spr.animation.curAnim == null)
				return;

			if (Std.isOfType(spr, StrumNote))
			{
				var strumNote:StrumNote = cast(spr, StrumNote);

				if (inputHandler.pressed[spr.ID] && strumNote.animation.curAnim.name != 'confirm')
				{
					strumNote.playAnim('pressed');
				}

				if (inputHandler.released[spr.ID])
				{
					strumNote.playAnim('static');
				}
			}
			else
			{
				// Fallback para FlxSprite genérico
				if (inputHandler.pressed[spr.ID] && spr.animation.curAnim.name != 'confirm')
				{
					spr.animation.play('pressed');
				}

				if (inputHandler.released[spr.ID])
				{
					spr.animation.play('static');
					spr.centerOffsets();
				}
			}
		});
	}

	/**
	 * Helper para verificar si un strum está tocando 'confirm'
	 */
	private function isPlayingConfirm(direction:Int):Bool
	{
		if (playerStrumsGroup != null)
		{
			var strum = playerStrumsGroup.getStrum(direction);
			if (strum != null && strum.animation != null && strum.animation.curAnim != null)
			{
				return strum.animation.curAnim.name == 'confirm';
			}
		}
		return false;
	}

	/**
	 * NUEVO: Callback cuando se suelta una tecla (para hold notes)
	 */
	private function onKeyRelease(direction:Int):Void
	{
		// Validar dirección
		if (direction < 0 || direction > 3)
		{
			return;
		}

		// Notificar al note manager que se soltó una hold note
		if (noteManager != null)
		{
			noteManager.releaseHoldNote(direction);
		}

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
					try
					{
						splash.recycleSplash();
						// ✅ CAMBIO: NO remover del grupo - dejarlo ahí para reutilizar
						// grpNoteSplashes.remove(splash, true); ❌ ESTO CAUSABA PROBLEMAS
						// El splash con exists=false no se renderiza, pero puede reutilizarse
					}
					catch (e:Dynamic)
					{
					}
				}
				holdSplashes.remove(direction);
			}

			// NUEVO: Crear splash de fin de hold note
			if (enableHoldSplashes && FlxG.save.data.notesplashes)
			{
				// Validar que playerStrums existe y tiene suficientes elementos
				if (playerStrums == null)
				{
					return;
				}

				if (playerStrums.members == null || playerStrums.members.length <= direction)
				{
					return;
				}

				var strum = playerStrums.members[direction];
				if (strum != null)
				{
					try
					{
						var endSplash:NoteSplash = recycleSplashSafe();
						if (endSplash == null)
						{
							return;
						}

						// ✅ CRÍTICO: cameras ANTES de setup
						endSplash.cameras = [camHUD];

						endSplash.setup(strum.x, strum.y, note.noteData, null, HOLD_END);

						if (!grpNoteSplashes.members.contains(endSplash))
						{
							grpNoteSplashes.add(endSplash);
						}
					}
					catch (e:Dynamic)
					{
					}
				}
				else
				{
				}
			}
		}
		else
		{
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
		if (!enableHoldSplashes)
		{
			return;
		}

		// Solo para notas del jugador
		if (!note.mustPress)
			return;

		// Si es sustain note
		if (note.isSustainNote)
		{
			// Primera parte de la hold note
			if (!heldNotes.exists(note.noteData))
			{
				heldNotes.set(note.noteData, note);

				// Validaciones null-safe
				if (playerStrums == null)
				{
					return;
				}

				if (playerStrums.members == null || playerStrums.members.length <= note.noteData)
				{
					return;
				}

				// Crear splash de inicio usando HOLD_START
				var strum = playerStrums.members[note.noteData];
				if (strum != null && FlxG.save.data.notesplashes)
				{
					try
					{
						var startSplash:NoteSplash = recycleSplashSafe();
						if (startSplash == null)
						{
							return;
						}

						// ✅ CRÍTICO: Asignar cameras ANTES de setup
						startSplash.cameras = [camHUD];

						// Ahora hacer setup con tipo HOLD_START
						startSplash.setup(strum.x, strum.y, note.noteData, null, HOLD_START);

						if (!grpNoteSplashes.members.contains(startSplash))
						{
							grpNoteSplashes.add(startSplash);
						}
					}
					catch (e:Dynamic)
					{
					}

					// OPCIONAL: Iniciar splash continuo (descomenta si quieres el efecto continuo)
					// startContinuousHoldSplash(note.noteData, strum.x, strum.y);
				}
				else
				{
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

		if (strum == null)
			return;

		var continuousSplash:NoteSplash = new NoteSplash(0, 0, 0); // Crear vacío para pool
		continuousSplash.cameras = [camHUD];
		continuousSplash.startContinuousSplash(strum.x, strum.y, actualDir);

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
		var rating:String = gameState.processNoteHit(noteDiff, note.isSustainNote);
		if (scriptsEnabled)
		{
			var cancel = ScriptHandler.callOnScriptsReturn('onPlayerNoteHit', [note, rating], false);
			if (cancel == true)
				return;
		}

		// NoteType: onPlayerHit — true cancela la lógica normal
		var _ntCancelled:Bool = funkin.gameplay.notes.NoteTypeManager.onPlayerHit(note, this);

		if (!note.wasGoodHit)
		{
			if (!_ntCancelled)
			{
				if (!note.isSustainNote)
				{
					var health = getHealthForRating(rating);
					gameState.modifyHealth(health);
					uiManager.showRatingPopup(rating, gameState.combo);
					if (FlxG.save.data.hitsounds && rating == 'sick')
						playHitSound();
				}
				else
				{
					gameState.modifyHealth(0.023);
				}
			} // end !_ntCancelled

			// Animate character - USAR ÍNDICE FIJO DEL JUGADOR
			var playerCharIndex:Int = 2;
			if (characterSlots.length > playerCharIndex)
			{
				characterController.singByIndex(playerCharIndex, note.noteData);
				var playerChar = characterController.getCharacter(playerCharIndex);
				if (playerChar != null)
					cameraController.applyNoteOffset(playerChar, note.noteData);
				else if (boyfriend != null)
					cameraController.applyNoteOffset(boyfriend, note.noteData);
			}
			else if (boyfriend != null)
			{
				characterController.sing(boyfriend, note.noteData);
				cameraController.applyNoteOffset(boyfriend, note.noteData);
			}

			noteManager.hitNote(note, rating);
			vocals.volume = 1;

			for (hook in _noteHitHookArr)
				hook(note);
		}

		// NoteType: onPlayerHitPost (siempre)
		funkin.gameplay.notes.NoteTypeManager.onPlayerHitPost(note, this);

		if (scriptsEnabled)
			ScriptHandler.callOnScripts('onPlayerNoteHitPost', [note, rating]);
	}

	/**
	 * Callback: Player miss note
	 */
	private function onPlayerNoteMiss(missedNote:funkin.gameplay.notes.Note):Void
	{
		if (scriptsEnabled)
		{
			var cancel = ScriptHandler.callOnScriptsReturn('onPlayerNoteMiss', [missedNote], false);
			if (cancel == true)
			{
				return;
			}
		}
		// Extraer dirección
		var direction:Int = missedNote != null ? missedNote.noteData : 0;

		// NoteType: onMiss — true cancela la lógica normal de miss
		var _ntMissCancelled:Bool = missedNote != null
			? funkin.gameplay.notes.NoteTypeManager.onMiss(missedNote, this)
			: false;

		if (!_ntMissCancelled)
		{
			// Process miss
			gameState.processMiss();
			gameState.modifyHealth(PlayStateConfig.MISS_HEALTH);
			FlxG.sound.play(Paths.soundRandom('missnote', 1, 3), FlxG.random.float(0.1, 0.2));
		}

		// Animate - USAR ÍNDICE FIJO DEL JUGADOR
		var playerCharIndex:Int = 2;
		if (characterSlots.length > playerCharIndex)
		{
			var slot = characterSlots[playerCharIndex];
			if (slot != null)
				characterController.missByIndex(playerCharIndex, direction);
		}
		else if (boyfriend != null)
		{
			var anims = ['LEFT', 'DOWN', 'UP', 'RIGHT'];
			boyfriend.playAnim('sing' + anims[direction] + 'miss', true);
		}

		if (gf != null && gf.animOffsets.exists('sad'))
			gf.playAnim('sad', true);

		if (!_ntMissCancelled)
			uiManager.showMissPopup();

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

		// NoteType: onCPUHit
		funkin.gameplay.notes.NoteTypeManager.onCPUHit(note, this);

		// ✅ FIX: Splashes del CPU ahora las maneja NoteManager
		// Código de hold splashes DESACTIVADO para evitar duplicación
		/*
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
						// ✅ CAMBIO: Usar recycleSplashSafe() en lugar de recycle() de Flixel
						var startSplash:NoteSplash = recycleSplashSafe();
						startSplash.cameras = [camHUD];
						startSplash.setup(strum.x, strum.y, note.noteData, null, HOLD_START);

						if (!grpNoteSplashes.members.contains(startSplash))
							grpNoteSplashes.add(startSplash);

						// Iniciar el splash continuo para el oponente
						startContinuousHoldSplash(cpuDir, strum.x, strum.y);
					}
				}
			}
		 */

		// Enable zoom
		if (SONG.song != 'Tutorial')
			cameraController.zoomEnabled = true;

		var altAnim:String = getHasAltAnim(curStep) ? '-alt' : '';

		// ✅ FIX: Animar solo al personaje DAD (índice 1), NO a GF
		// GF (índice 0) solo baila, no canta
		var section = getSectionAsClass(curStep);
		if (section != null)
		{
			var charIndices = section.getActiveCharacterIndices(1, 2); // (dadIndex, bfIndex)

			// ✅ ARREGLADO: Solo hacer cantar al personaje DAD (índice 1)
			// GF (índice 0) NO debe cantar, solo bailar
			var dadIndex:Int = 1; // Dad es siempre el índice 1

			if (characterSlots.length > dadIndex)
			{
				var dadSlot = characterSlots[dadIndex];
				if (dadSlot != null && dadSlot.isActive && dadSlot.character != null)
				{
					// Hacer cantar solo a Dad
					characterController.singByIndex(dadIndex, note.noteData, altAnim);
				}
			}
			else if (dad != null)
			{
				// Fallback al sistema legacy si no hay slots
				characterController.sing(dad, note.noteData, altAnim);
			}

			// Camera offset - usar el primer personaje activo del CPU para el offset de cámara
			if (charIndices.length > 0)
			{
				var activeChar = characterController.getCharacter(charIndices[0]);
				if (activeChar != null)
					cameraController.applyNoteOffset(activeChar, note.noteData);
				else if (dad != null)
					cameraController.applyNoteOffset(dad, note.noteData);
			}
			else if (dad != null)
			{
				cameraController.applyNoteOffset(dad, note.noteData);
			}
		}
		else
		{
			// FALLBACK: Si la sección es null, animar solo a Dad (índice 1)
			var dadIndex:Int = 1;

			if (characterSlots.length > dadIndex)
			{
				var dadSlot = characterSlots[dadIndex];
				if (dadSlot != null && dadSlot.isActive && dadSlot.character != null)
				{
					characterController.singByIndex(dadIndex, note.noteData, altAnim);
				}
			}
			else if (dad != null)
			{
				// Fallback al sistema legacy
				characterController.sing(dad, note.noteData, altAnim);
			}

			// Fallback para offset de cámara
			if (dad != null)
			{
				cameraController.applyNoteOffset(dad, note.noteData);
			}
		}

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

	// ── Hitsound pool (evita new FlxSound cada golpe) ─────────────────────
	private var _hitSounds:Array<FlxSound> = [];
	private var _hitSoundIdx:Int = 0;

	private static inline var HIT_SOUND_POOL_SIZE:Int = 4;

	private function initHitSoundPool():Void
	{
		_hitSounds = [];
		for (i in 0...HIT_SOUND_POOL_SIZE)
		{
			var snd = new FlxSound();
			try
			{
				snd.loadEmbedded(Paths.sound('hitsounds/hit-1'));
			}
			catch (_:Dynamic)
			{
			}
			snd.looped = false;
			FlxG.sound.list.add(snd);
			_hitSounds.push(snd);
		}
	}

	/**
	 * Play hitsound — usa pool de FlxSound para evitar alloc por golpe
	 */
	private function playHitSound():Void
	{
		if (_hitSounds.length == 0)
			initHitSoundPool();
		var snd = _hitSounds[_hitSoundIdx % HIT_SOUND_POOL_SIZE];
		_hitSoundIdx++;
		if (snd == null)
			return;
		snd.volume = 1 + FlxG.random.float(-0.2, 0.2);
		snd.play(true);
	}

	/**
	 * Spawn note splash
	 */
	/**
	 * NUEVO: Reciclar splash de forma segura - solo splashes que NO estén en uso
	 */
	private function recycleSplashSafe():NoteSplash
	{
		// ✅ CRÍTICO: Buscar un splash que no esté en uso y no exista (reciclado)
		// Ya NO buscamos por !alive porque ahora los splashes permanecen alive
		var availableSplash:NoteSplash = null;

		grpNoteSplashes.forEach(function(splash:NoteSplash)
		{
			// ✅ NUEVO: Buscar por !inUse && !exists en lugar de !alive
			if (availableSplash == null && !splash.inUse && !splash.exists)
			{
				availableSplash = splash;
			}
		});

		// Si encontramos uno disponible, usarlo
		if (availableSplash != null)
		{
			return availableSplash;
		}

		// Si no hay ninguno disponible, crear uno nuevo

		var newSplash = new NoteSplash(0, 0, 0);
		grpNoteSplashes.add(newSplash);

		return newSplash;
	}

	/**
	 * Sync legacy stats — solo copia cuando algo cambió realmente.
	 * Se comparan score+misses como proxy rápido; si coinciden, el resto tampoco cambia.
	 */
	private function syncLegacyStats():Void
	{
		if (gameState.score == songScore && gameState.misses == misses)
			return; // nada cambió — evitar 7 asignaciones por frame
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
			if (startTimer != null && !startTimer.finished)
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

			if (startTimer != null && !startTimer.finished)
				startTimer.active = true;
			paused = false;

			#if desktop
			if (startTimer == null || startTimer.finished)
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
		for (hook in _beatHookArr)
			hook(curBeat);

		if (currentStage != null)
			currentStage.beatHit(curBeat);

		if (modChartManager != null)
			modChartManager.onBeatHit(curBeat);

		if (scriptsEnabled)
			ScriptHandler.callOnScripts('onBeatHit', [curBeat]);

		// Character dance
		characterController.danceOnBeat(curBeat);

		// Camera zoom
		if (curBeat % 4 == 0)
			cameraController.bumpZoom();

		// UI bump
		uiManager.onBeatHit(curBeat);
	}

	/**
	 * Step hit
	 */
	override function stepHit()
	{
		super.stepHit();

		// Hooks
		for (hook in _stepHookArr)
			hook(curStep);

		if (modChartManager != null)
			modChartManager.onStepHit(curStep);

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

		// ── Outro video (meta.json: "outroVideo": "mi-video") ─────────────────
		if (metaData != null && metaData.outroVideo != null)
		{
			final vidKey = metaData.outroVideo;
			metaData.outroVideo = null; // evitar doble reproducción

			if (VideoManager._resolvePath(vidKey) != null)
			{
				isCutscene = true;
				VideoManager.playCutscene(vidKey, function()
				{
					isCutscene = false;
					if (showOutroDialogue() && isStoryMode) return;
					continueAfterSong();
				});
				return;
			}
		}

		if (showOutroDialogue() && isStoryMode)
		{
			return; // El diálogo manejará el resto
		}

		if (!isCutscene)
			continueAfterSong();
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

		// ✅ Verificar que boyfriend exista
		if (boyfriend == null)
		{
			// Forzar game over de emergencia
			StateTransition.switchState(new funkin.menus.MainMenuState());
			return;
		}

		GameState.deathCounter++;

		boyfriend.stunned = true;
		persistentUpdate = false;
		persistentDraw = false;
		paused = true;

		FlxG.sound.music.stop();

		openSubState(new GameOverSubstate(boyfriend.getScreenPosition().x, boyfriend.getScreenPosition().y, boyfriend));

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
	 * Convert SwagSection to Section class for accessing methods.
	 * OPTIMIZADO: reutiliza un único objeto Section en lugar de crear uno nuevo
	 * en cada llamada (esto se llama en cada nota del CPU → muchas veces por segundo).
	 */
	public function getSectionAsClass(step:Int):Section
	{
		final sectionIndex = Math.floor(step / 16);

		// Cache hit — misma sección, mismo objeto
		if (_cachedSectionClassIdx == sectionIndex && _cachedSectionClass != null)
			return _cachedSectionClass;

		final swagSection = getSection(step);

		if (swagSection == null)
		{
			_cachedSectionClassIdx = sectionIndex;
			_cachedSectionClass = null;
			return null;
		}

		// Reutilizar el objeto si ya existe, crear uno solo la primera vez
		if (_cachedSectionClass == null)
			_cachedSectionClass = new Section();

		_cachedSectionClass.sectionNotes = swagSection.sectionNotes;
		_cachedSectionClass.lengthInSteps = swagSection.lengthInSteps;
		_cachedSectionClass.typeOfSection = swagSection.typeOfSection;
		_cachedSectionClass.mustHitSection = swagSection.mustHitSection;
		_cachedSectionClass.characterIndex = swagSection.characterIndex != null ? swagSection.characterIndex : -1;
		_cachedSectionClass.strumsGroupId = swagSection.strumsGroupId;
		_cachedSectionClass.activeCharacters = swagSection.activeCharacters;

		_cachedSectionClassIdx = sectionIndex;
		return _cachedSectionClass;
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

	// draw() eliminado: la versión anterior añadía sprites al GPURenderer
	// Y luego llamaba super.draw() que los volvía a renderizar todos —
	// resultado: doble render de personajes, notas y splashes en cada frame.
	// Ahora usamos el pipeline estándar de Flixel (super.draw implícito).
	// OptimizationManager sigue activo para: adaptive quality, FPS tracking,
	// y NotePool. El GPURenderer se mantiene pero no interfiere con el draw.

	/**
	 * Destroy
	 */
	override function destroy()
	{
		// ── 1. Resetear estáticas ────────────────────────────────────────────────
		instance = null;
		isPlaying = false;
		cpuStrums = null;
		startingSong = false; // Era estático y podía quedar true si se salía mid-countdown

		// ── 2. Cancelar el timer del countdown ANTES de destruir characterController
		//       Si no se cancela, el callback dispara sobre objetos ya destruidos
		if (startTimer != null)
		{
			startTimer.cancel();
			startTimer.destroy();
			startTimer = null;
		}

		// ── 3. Limpiar vocals del sound list y destruirla
		//       vocals se añadió manualmente a FlxG.sound.list así que hay que quitarla
		if (vocals != null)
		{
			FlxG.sound.list.remove(vocals, true);
			vocals.stop();
			vocals.destroy();
			vocals = null;
		}

		// ── 4. Scripts (antes de destruir objetos del stage que usen scripts)
		if (scriptsEnabled)
		{
			ScriptHandler.callOnScripts('onDestroy', []);
			ScriptHandler.clearSongScripts();
			EventManager.clear();
		}

		// ── 5. OMITIR currentStage.destroy() manual ─────────────────────────────
		//       currentStage fue add()-eado al FlxState, así que super.destroy()
		//       ya lo destruye al recorrer sus miembros.
		//       Llamarlo aquí causaba DOBLE DESTROY → corrupción de texturas → crash.

		// ── 6. Optimization manager
		if (optimizationManager != null)
		{
			optimizationManager.destroy();
			optimizationManager = null;
		}

		// ── 7. Controllers
		if (cameraController != null)
		{
			cameraController.destroy();
			cameraController = null;
		}

		if (noteManager != null)
		{
			noteManager.destroy();
			noteManager = null;
		}

		if (modChartManager != null)
		{
			modChartManager.destroy();
			modChartManager = null;
		}

		// ── 8. Note batcher
		if (noteBatcher != null)
		{
			remove(noteBatcher, true);
			noteBatcher.destroy();
			noteBatcher = null;
		}

		// ── 9. Limpiar estructuras internas
		NoteSkinSystem.restoreGlobalSkin();
		heldNotes.clear();
		holdSplashes.clear();
		characterSlots = [];
		strumsGroups = [];
		strumsGroupMap.clear();
		activeCharIndices = [];

		GameState.destroy();

		// ── 10. Pool de hitsounds
		for (snd in _hitSounds)
		{
			if (snd != null)
			{
				snd.stop();
				FlxG.sound.list.remove(snd, true);
				snd.destroy();
			}
		}
		_hitSounds = [];

		// ── 11. Hooks
		onBeatHitHooks.clear();
		onStepHitHooks.clear();
		onUpdateHooks.clear();
		onNoteHitHooks.clear();
		onNoteMissHooks.clear();
		_beatHookArr = [];
		_stepHookArr = [];
		_updateHookArr = [];
		_noteHitHookArr = [];
		_noteMissHookArr = [];

		// ── 12. Section wrapper cache
		_cachedSectionClass = null;
		_cachedSectionClassIdx = -2;

		// super.destroy() destruye todos los miembros (characters, stage, notes, etc.)
		// DESPUÉS es seguro liberar bitmaps con dispose() porque ya no hay sprites vivos
		// que los referencien. Hacerlo ANTES provocaba crashes si algún sprite dibujaba
		// en el mismo frame que el bitmap se disponía.
		super.destroy();

		// Limpiar caché de assets: todos los sprites ya están destruidos (arriba).
		Paths.forceClearCache();
		Paths.clearFlxBitmapCache();

		// Forzar GC con todo ya limpiado
		#if cpp
		cpp.vm.Gc.run(true);
		#end
	}

	// ====================================
	// SISTEMA DE DIÁLOGOS
	// ====================================

	/**
	 * Verificar si existe un archivo de diálogo para la canción actual
	 */
	private function checkForDialogue(type:String = 'intro'):Bool
	{
		var songName = SONG.song.toLowerCase();
		var dialoguePath = 'assets/songs/${songName}/${type}.json';

		#if sys
		return sys.FileSystem.exists(dialoguePath);
		#else
		// En web/móvil, intentar cargar y verificar
		try
		{
			var data = DialogueData.loadDialogue(dialoguePath);
			return (data != null);
		}
		catch (e:Dynamic)
		{
			return false;
		}
		#end
	}

	/**
	 * Mostrar diálogo
	 */
	private function showDialogue(type:String = 'intro', ?onFinish:Void->Void):Void
	{
		isCutscene = true;

		var songName = SONG.song.toLowerCase();

		var doof:DialogueBoxImproved = null;

		try
		{
			doof = new DialogueBoxImproved(songName);
		}
		catch (e:Dynamic)
		{
			if (onFinish != null)
				onFinish();
			return;
		}

		if (doof == null)
		{
			if (onFinish != null)
				onFinish();
			return;
		}

		// Configurar callback de finalización
		doof.finishThing = function()
		{
			inCutscene = false;
			if (onFinish != null)
				onFinish();
		};

		// Agregar diálogo
		add(doof);

		doof.cameras = [camHUD];
	}

	/**
	 * Mostrar diálogo de outro (al final de la canción)
	 */
	private function showOutroDialogue():Bool
	{
		if (checkForDialogue('outro'))
		{
			isCutscene = true;

			showDialogue('outro', function()
			{
				// Continuar con el flujo normal después del diálogo
				if (FlxG.sound.music != null)
					FlxG.sound.music.stop();
				isCutscene = false;
				continueAfterSong();
			});
			return true;
		}
		return false;
	}

	/**
	 * Continuar después de la canción (separado para reutilizar)
	 */
	private function continueAfterSong():Void
	{
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
	 * Actualiza las configuraciones de gameplay en tiempo real
	 * Se llama cuando se modifican opciones desde el pause menu
	 * SOLO aplica cambios SEGUROS que no pueden causar bugs
	 */
	public function updateGameplaySettings():Void
	{
		// Verificación de seguridad: solo actualizar si el juego está pausado
		if (!paused)
		{
			return;
		}

		// === CAMBIOS SEGUROS (no afectan lógica del juego) ===

		// 1. Actualizar visibilidad del HUD (100% seguro)
		if (uiManager != null)
		{
			var hideHud = FlxG.save.data.HUD;
			uiManager.visible = !hideHud; // Controlar visibilidad del grupo completo
		}

		// 2. Actualizar antialiasing (solo visual, 100% seguro)
		updateAntialiasing();

		// 3. Actualizar ghost tapping (seguro, solo afecta siguiente input)
		if (inputHandler != null)
		{
			inputHandler.ghostTapping = FlxG.save.data.ghosttap;
		}

		// === CAMBIOS QUE REQUIEREN MÁS CUIDADO ===
		// NO actualizar downscroll/middlescroll en tiempo real
		// Estos cambios pueden causar confusión y bugs con las notas en vuelo
		// El usuario debe reiniciar la canción para aplicar estos cambios
	}

	/**
	 * Actualiza el antialiasing de todos los sprites del stage
	 */
	private function updateAntialiasing():Void
	{
		if (currentStage == null)
			return;

		// Actualizar antialiasing del stage
		for (sprite in currentStage.members)
		{
			if (sprite != null && Std.isOfType(sprite, FlxSprite))
			{
				var spr:FlxSprite = cast sprite;
				spr.antialiasing = cast(FlxG.save.data.antialiasing, Bool);
			}
		}

		// Actualizar antialiasing de personajes
		if (boyfriend != null)
			boyfriend.antialiasing = cast(FlxG.save.data.antialiasing, Bool);
		if (dad != null)
			dad.antialiasing = cast(FlxG.save.data.antialiasing, Bool);
		if (gf != null)
			gf.antialiasing = cast(FlxG.save.data.antialiasing, Bool);
	}

	/**
	 * Llamado cuando el juego pierde foco (minimizar ventana)
	 * Pausa las vocals para que estén sincronizadas con el instrumental
	 */
	override public function onFocusLost():Void
	{
		super.onFocusLost();

		// Pausar vocals cuando se pierde foco
		if (vocals != null && vocals.playing)
		{
			vocals.pause();
		}

		// FlxG.sound.music se pausa automáticamente, pero lo marcamos
	}

	/**
	 * Llamado cuando el juego recupera foco (volver a la ventana)
	 * Reanuda TANTO el instrumental como las vocals
	 */
	override public function onFocus():Void
	{
		super.onFocus();

		// CRÍTICO: Con loadStream(), FlxG.sound.music NO se reanuda automáticamente
		// Necesitamos reanudarlo manualmente
		if (FlxG.sound.music != null && !startingSong && generatedMusic && !paused)
		{
			// Reanudar el instrumental
			FlxG.sound.music.play();

			// Reanudar vocals sincronizadas con el instrumental
			if (vocals != null && SONG.needsVoices)
			{
				vocals.time = FlxG.sound.music.time;
				vocals.play();
			}
		}
	}
}
