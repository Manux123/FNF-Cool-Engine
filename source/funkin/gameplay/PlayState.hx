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
import extensions.CoolUtil;
import funkin.gameplay.objects.hud.Highscore;
import funkin.states.LoadingState;
import funkin.states.GameOverSubstate;
import funkin.menus.RatingState;
import funkin.gameplay.objects.hud.ScoreManager;
import funkin.transitions.StickerTransition;
// Menu Pause
import funkin.menus.GitarooPause;
import funkin.menus.PauseSubState;
import funkin.debug.ChartingState;
import funkin.debug.DialogueEditor;
#if desktop
import data.Discord.DiscordClient;
#end
// Cutscenes
import funkin.cutscenes.dialogue.DialogueBoxImproved;
import funkin.cutscenes.dialogue.DialogueData;

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

	public var optimizationManager:OptimizationManager;

	// === SECTION CACHE ===
	private var cachedSection:SwagSection = null;
	private var cachedSectionIndex:Int = -1;

	// === NEW: BATCHING AND HOLD NOTES ===
	private var noteBatcher:NoteBatcher;
	private var heldNotes:Map<Int, Note> = new Map(); // dirección -> nota
	private var holdSplashes:Map<Int, NoteSplash> = new Map(); // dirección -> splash continuo

	// NEW: CONFIG OPTIMIZATIONS
	public var enableBatching:Bool = true;
	public var enableHoldSplashes:Bool = true;

	private var showDebugStats:Bool = false;
	private var debugText:FlxText;

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
		StickerTransition.reattachToState();
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
			ScriptHandler.callOnScripts('postCreate', []);
			ScriptHandler.setOnScripts('author', GameState.listAuthor);
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

		trace('[PlayState] Inicializando sistema de optimización...');

		optimizationManager = new OptimizationManager();
		optimizationManager.init();

		// Start song
		startCountdown();

		super.create();

		StickerTransition.clearStickers();
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
		trace('[PlayState] === CARGANDO PERSONAJES ===');
		trace('[PlayState] SONG.characters: ' + (SONG.characters != null ? 'EXISTS' : 'NULL'));
		if (SONG.characters != null)
			trace('[PlayState] SONG.characters.length: ' + SONG.characters.length);
		trace('[PlayState] SONG.player1: ' + SONG.player1);
		trace('[PlayState] SONG.player2: ' + SONG.player2);
		trace('[PlayState] SONG.gfVersion: ' + SONG.gfVersion);

		// ✅ NUEVO: Si no hay personajes, crear por defecto (compatibilidad con charts antiguos)
		if (SONG.characters == null || SONG.characters.length == 0)
		{
			trace('[PlayState] ADVERTENCIA: No hay personajes en SONG.characters');
			trace('[PlayState] Creando personajes por defecto desde campos legacy...');

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

			trace('[PlayState] Personajes por defecto creados: ${SONG.characters.length}');
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
						trace('[PlayState] Personaje adicional #$i en posición custom');
				}
			}
			else
			{
				// Usar posición del JSON
				slot.character.setPosition(charData.x, charData.y);
			}

			characterSlots.push(slot);
			add(slot.character);

			trace('[PlayState] Personaje #$i cargado: ${charData.name} en (${slot.character.x}, ${slot.character.y})');
		}

		trace('[PlayState] Total personajes cargados: ${characterSlots.length}');
		trace('[PlayState] boyfriend: ' + (boyfriend != null ? 'OK (' + boyfriend.curCharacter + ')' : 'NULL'));
		trace('[PlayState] dad: ' + (dad != null ? 'OK (' + dad.curCharacter + ')' : 'NULL'));
		trace('[PlayState] gf: ' + (gf != null ? 'OK (' + gf.curCharacter + ')' : 'NULL'));
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
		trace('[PlayState] === CARGANDO GRUPOS DE STRUMS ===');

		if (SONG.strumsGroups == null || SONG.strumsGroups.length == 0)
		{
			trace('[PlayState] ADVERTENCIA: No hay grupos de strums');
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
				trace('[PlayState] ✅ cpuStrums asignado: ${cpuStrums.members.length} strums');
			}
			else if (!groupData.cpu && playerStrums == null)
			{
				playerStrums = group.strums;
				playerStrumsGroup = group; // ✅ Guardar referencia al grupo completo
				trace('[PlayState] ✅ playerStrums asignado: ${playerStrums.members.length} strums');

				// Verificar posiciones de cada strum
				for (i in 0...playerStrums.members.length)
				{
					var s = playerStrums.members[i];
					if (s != null)
						trace('[PlayState]    Strum[$i]: x=${s.x}, y=${s.y}, visible=${s.visible}');
				}
			}

			trace('[PlayState] Grupo "${groupData.id}" cargado - CPU: ${groupData.cpu}, Visible: ${groupData.visible}');
		}

		trace('[PlayState] Total grupos de strums: ${strumsGroups.length}');
		trace('[PlayState] playerStrums final: ${playerStrums != null ? playerStrums.members.length + " strums" : "NULL"}');
		trace('[PlayState] cpuStrums final: ${cpuStrums != null ? cpuStrums.members.length + " strums" : "NULL"}');
	}

	/**
	 * Setup controllers - MEJORADO con splashes
	 */
	private function setupControllers():Void
	{
		// ✅ Verificar que boyfriend y dad existan antes de crear CameraController
		if (boyfriend == null || dad == null)
		{
			trace('[PlayState] ERROR CRÍTICO: boyfriend o dad son null!');
			trace('[PlayState] boyfriend: ' + (boyfriend != null ? 'OK' : 'NULL'));
			trace('[PlayState] dad: ' + (dad != null ? 'OK' : 'NULL'));
			trace('[PlayState] No se puede continuar sin personajes principales');
			// En modo debug, crear personajes de emergencia
			#if debug
			trace('[PlayState] Intentando recuperación de emergencia...');
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
			FlxG.switchState(new funkin.menus.MainMenuState());
			return;
			#end
		}

		// Camera controller
		cameraController = new CameraController(camGame, camHUD, boyfriend, dad);
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

		// NUEVO: Callback para release de hold notes
		//inputHandler.onKeyRelease = onKeyRelease;  for now note hold splashes disabled :(

		// Note manager - MEJORADO con splashes
		// ✅ Pasar referencias a StrumsGroup para animaciones de confirm
		noteManager = new NoteManager(notes, playerStrums, cpuStrums, grpNoteSplashes, playerStrumsGroup, cpuStrumsGroup);
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

		// Cargar instrumental usando el método seguro que soporta archivos externos
		FlxG.sound.music = Paths.loadInst(SONG.song);
		FlxG.sound.music.volume = 0;
		FlxG.sound.music.pause();
		FlxG.sound.list.add(FlxG.sound.music);

		// Cargar voces usando el método seguro
		if (SONG.needsVoices)
			vocals = Paths.loadVoices(SONG.song);
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

		if (checkForDialogue('intro') && isStoryMode)
		{
			inCutscene = true;
			trace('[PlayState] Diálogo de intro encontrado, mostrando...');
			showDialogue('intro', function()
			{
				if (FlxG.sound.music != null)
					FlxG.sound.music.stop();
				if (vocals != null)
				{
					vocals.stop();
					vocals.volume = 0;
				}
				// Cuando termina el diálogo, ejecutar el countdown
				executeCountdown();
				isCutscene = false;
			});
			return;
		}

		if (!isCutscene)
			executeCountdown();
	}

	private function executeCountdown():Void
	{
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

	function getCountdown(asset:FlxSprite, sip:Int, wea:Int, introAlts:Array<String>, ?isGo = false)
	{
		asset = new FlxSprite().loadGraphic(Paths.image(introAlts[sip]));
		asset.cameras = [camCountdown];
		asset.scrollFactor.set();

		asset.scale.set(0.7, 0.7);

		if (curStage.startsWith('school'))
			asset.setGraphicSize(Std.int(asset.width * PlayStateConfig.PIXEL_ZOOM));
		else
			asset.antialiasing = FlxG.save.data.antialiasing;

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

		if (StickerTransition.isActive())
		{
			StickerTransition.ensureCameraOnTop();
		}

		if (currentStage != null)
			currentStage.update(elapsed);

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
			if (boyfriend != null && !boyfriend.stunned)
			{
				inputHandler.update();
				inputHandler.processInputs(notes);
				inputHandler.processSustains(notes);
				updatePlayerStrums();

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
			if (gameState.isDead())
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

		if (FlxG.keys.justPressed.EIGHT)
		{
			FlxG.switchState(new StageEditor());
		}

		if (FlxG.keys.justPressed.NINE)
		{
			persistentUpdate = false;
			persistentDraw = true;
			paused = true;
			FlxG.switchState(new DialogueEditor());
		}

		// Song time - SINCRONIZACIÓN MEJORADA
		if (startingSong && startedCountdown && !inCutscene)
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
		if (FlxG.sound.music != null && !inCutscene)
		{
			// La música ya está cargada, solo necesitamos reproducirla
			FlxG.sound.music.volume = 1;
			FlxG.sound.music.time = 0;
			FlxG.sound.music.play();
			FlxG.sound.music.onComplete = endSong;
			
			trace('[PlayState] SONG INICIATES');
		}

		// Sincronizar vocales con música
		if (SONG.needsVoices && vocals != null && !inCutscene)
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
		trace('[PlayState] onKeyRelease llamado para direction=$direction');

		// Validar dirección
		if (direction < 0 || direction > 3)
		{
			trace('[PlayState] ERROR: dirección inválida: $direction');
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
			trace('[PlayState] Hold note removida para direction=$direction');

			// NUEVO: Detener splash continuo si existe
			if (holdSplashes.exists(direction))
			{
				var splash = holdSplashes.get(direction);
				if (splash != null)
				{
					trace('[PlayState] Reciclando splash continuo para direction=$direction');
					try
					{
						splash.recycleSplash();
						// ✅ CAMBIO: NO remover del grupo - dejarlo ahí para reutilizar
						// grpNoteSplashes.remove(splash, true); ❌ ESTO CAUSABA PROBLEMAS
						// El splash con exists=false no se renderiza, pero puede reutilizarse
					}
					catch (e:Dynamic)
					{
						trace('[PlayState] ERROR reciclando splash: $e');
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
					trace('[PlayState] ERROR: playerStrums es NULL');
					return;
				}

				if (playerStrums.members == null || playerStrums.members.length <= direction)
				{
					trace('[PlayState] ERROR: playerStrums.members no tiene suficientes elementos (length: ${playerStrums.members != null ? Std.string(playerStrums.members.length) : "NULL"})');
					return;
				}

				var strum = playerStrums.members[direction];
				if (strum != null)
				{
					trace('[PlayState] Creando HOLD_END splash en strum x=${strum.x}, y=${strum.y}');

					try
					{
						var endSplash:NoteSplash = recycleSplashSafe();
						if (endSplash == null)
						{
							trace('[PlayState] ERROR: No se pudo obtener splash');
							return;
						}

						// ✅ CRÍTICO: cameras ANTES de setup
						endSplash.cameras = [camHUD];

						endSplash.setup(strum.x, strum.y, note.noteData, null, HOLD_END);

						if (!grpNoteSplashes.members.contains(endSplash))
						{
							grpNoteSplashes.add(endSplash);
						}

						trace('[PlayState] ✅ HOLD_END splash creado');
					}
					catch (e:Dynamic)
					{
						trace('[PlayState] ERROR creando HOLD_END splash: $e');
					}
				}
				else
				{
					trace('[PlayState] ERROR: strum es NULL para direction=$direction');
				}
			}
		}
		else
		{
			trace('[PlayState] No hay hold note activa para direction=$direction');
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
			trace('[PlayState] Hold splashes deshabilitados');
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
				trace('[PlayState] Hold note iniciada para noteData=${note.noteData}');

				// Validaciones null-safe
				if (playerStrums == null)
				{
					trace('[PlayState] ERROR: playerStrums es NULL');
					return;
				}

				if (playerStrums.members == null || playerStrums.members.length <= note.noteData)
				{
					trace('[PlayState] ERROR: playerStrums.members insuficiente');
					return;
				}

				// Crear splash de inicio usando HOLD_START
				var strum = playerStrums.members[note.noteData];
				if (strum != null && FlxG.save.data.notesplashes)
				{
					trace('[PlayState] Creando HOLD_START splash en strum x=${strum.x}, y=${strum.y}');

					try
					{
						var startSplash:NoteSplash = recycleSplashSafe();
						if (startSplash == null)
						{
							trace('[PlayState] ERROR: No se pudo obtener splash');
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

						trace('[PlayState] ✅ HOLD_START splash creado para noteData=${note.noteData}');
					}
					catch (e:Dynamic)
					{
						trace('[PlayState] ERROR creando HOLD_START splash: $e');
					}

					// OPCIONAL: Iniciar splash continuo (descomenta si quieres el efecto continuo)
					// startContinuousHoldSplash(note.noteData, strum.x, strum.y);
				}
				else
				{
					trace('[PlayState] strum=${strum != null ? "OK" : "NULL"}, notesplashes=${FlxG.save.data.notesplashes}');
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

		if (!note.wasGoodHit)
		{
			if (!note.isSustainNote)
			{
				var health = getHealthForRating(rating);
				gameState.modifyHealth(health);

				// Show popup
				uiManager.showRatingPopup(rating, gameState.combo);

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
			var section:Section = getSectionAsClass(curStep);
			var charIndices = section.getActiveCharacterIndices(1, 2);

			// Solo hacer cantar al BF (índice 2 o 3 típicamente)
			var bfIndex = charIndices.length > 0 ? charIndices[charIndices.length - 1] : 2;
			characterController.singByIndex(bfIndex, note.noteData);

			// Animate strum
			noteManager.hitNote(note,rating);

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
			if (gf.animOffsets.exists('sad'))
				gf.playAnim('sad', true);
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

		// GF/Dad singing logic
		var section = getSectionAsClass(curStep);
		if (section != null)
		{
			var charIndices = section.getActiveCharacterIndices(1, 2); // (dadIndex, bfIndex)

			// Hacer cantar a todos los personajes activos
			for (charIndex in charIndices)
			{
				characterController.singByIndex(charIndex, note.noteData, getHasAltAnim(curStep) ? '-alt' : '');
			}
		}

		// Camera offset
		cameraController.applyNoteOffset(dad, note.noteData);

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
				trace('[PlayState] 🔄 Encontrado splash reciclable: inUse=${splash.inUse}, exists=${splash.exists}, alive=${splash.alive}');
			}
		});

		// Si encontramos uno disponible, usarlo
		if (availableSplash != null)
		{
			trace('[PlayState] ✅ Reciclando splash (existe pero no está en uso)');
			return availableSplash;
		}

		// Si no hay ninguno disponible, crear uno nuevo
		trace('[PlayState] ⚠️ Todos los splashes en uso (total: ${grpNoteSplashes.length}), creando nuevo');
		var newSplash = new NoteSplash(0, 0, 0);
		grpNoteSplashes.add(newSplash);
		trace('[PlayState] ✅ Nuevo splash creado, total ahora: ${grpNoteSplashes.length}');
		return newSplash;
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
			trace('[PlayState] ERROR: boyfriend es null en gameOver()');
			// Forzar game over de emergencia
			FlxG.switchState(new funkin.menus.MainMenuState());
			return;
		}

		GameState.deathCounter++;

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
	 * Convert SwagSection to Section class for accessing methods
	 */
	public function getSectionAsClass(step:Int):Section
	{
		var swagSection = getSection(step);
		if (swagSection == null)
			return null;

		var section = new Section();
		section.sectionNotes = swagSection.sectionNotes;
		section.lengthInSteps = swagSection.lengthInSteps;
		section.typeOfSection = swagSection.typeOfSection;
		section.mustHitSection = swagSection.mustHitSection;
		section.characterIndex = swagSection.characterIndex != null ? swagSection.characterIndex : -1;
		section.strumsGroupId = swagSection.strumsGroupId;
		section.activeCharacters = swagSection.activeCharacters;

		return section;
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

	/*
	 * NUEVO: Método draw() personalizado para renderizado optimizado
	 * 
	 * IMPORTANTE: Este método reemplaza el renderizado estándar de Flixel
	 * con el GPURenderer para obtener:
	 * - Batching automático de sprites
	 * - Frustum culling
	 * - Menor cantidad de draw calls
	 * - Mejor rendimiento en general
	 * 
	 * ORDEN DE RENDERIZADO:
	 * 1. Limpiar frame anterior del GPU
	 * 2. Agregar todos los sprites visibles al GPURenderer
	 * 3. Renderizar todo de una vez con batching
	 * 4. Llamar a super.draw() para UI y otros elementos */
	override function draw():Void
	{
		// 1. Agregar sprites al renderer
		if (optimizationManager != null)
		{
			// Renderizar splashes
			if (gf != null && gf.visible)
				optimizationManager.addSpriteToRenderer(gf);

			if (dad != null && dad.visible)
				optimizationManager.addSpriteToRenderer(dad);

			if (boyfriend != null && boyfriend.visible)
				optimizationManager.addSpriteToRenderer(boyfriend);

			if (grpNoteSplashes != null)
			{
				grpNoteSplashes.forEachAlive(function(splash:NoteSplash)
				{
					if (splash != null && splash.visible)
						optimizationManager.addSpriteToRenderer(splash);
				});
			}

			notes.forEachAlive(function(n)
			{
				optimizationManager.addSpriteToRenderer(n);
			});

			optimizationManager.render(); // Dibujamos todo por GPU
		}

		super.draw();
	}

	/**
	 * Destroy
	 */
	override function destroy()
	{
		// ⚠️ CRÍTICO: Limpiar singleton y variables estáticas
		instance = null;
		isPlaying = false;
		cpuStrums = null;

		currentStage.destroy();
		if (scriptsEnabled)
		{
			ScriptHandler.callOnScripts('onDestroy', []);
			ScriptHandler.clearSongScripts();
			EventManager.clear();
		}

		if (optimizationManager != null)
		{
			trace('[PlayState] Destruyendo optimizaciones...');
			optimizationManager.destroy();
			optimizationManager = null;
		}

		// Destroy controllers
		if (cameraController != null)
			cameraController.destroy();

		if (noteManager != null)
			noteManager.destroy();

		// NUEVO: Destroy batcher
		if (noteBatcher != null)
		{
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

		Paths.clearAllCaches();

		// Forzar GC
		#if cpp
		cpp.vm.Gc.run(true);
		#end

		super.destroy();
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
		var dialoguePath = 'assets/songs/${songName}/${type}.json';

		trace('[PlayState] Cargando diálogo: $dialoguePath');

		var doof:DialogueBoxImproved = null;

		try
		{
			doof = new DialogueBoxImproved(dialoguePath);
		}
		catch (e:Dynamic)
		{
			trace('[PlayState] Error al cargar diálogo: $e');
			if (onFinish != null)
				onFinish();
			return;
		}

		if (doof == null)
		{
			trace('[PlayState] Diálogo es null, ejecutando callback...');
			if (onFinish != null)
				onFinish();
			return;
		}

		// Configurar callback de finalización
		doof.finishThing = function()
		{
			trace('[PlayState] Diálogo terminado');
			inCutscene = false;
			if (onFinish != null)
				onFinish();
		};

		// Agregar diálogo
		add(doof);

		doof.cameras = [camHUD];

		// Reproducir música de diálogo si existe (para Week 6 por ejemplo)
		playDialogueMusic();
	}

	/**
	 * Reproducir música específica de diálogo según la canción
	 */
	private function playDialogueMusic():Void
	{
		switch (SONG.song.toLowerCase())
		{
			case 'senpai':
				FlxG.sound.playMusic(Paths.music('gameplay/week6/Lunchbox'), 0);
				FlxG.sound.music.fadeIn(1, 0, 0.8);
			case 'thorns':
				FlxG.sound.playMusic(Paths.music('gameplay/week6/LunchboxScary'), 0);
				FlxG.sound.music.fadeIn(1, 0, 0.8);
		}
	}

	/**
	 * Mostrar diálogo de outro (al final de la canción)
	 */
	private function showOutroDialogue():Bool
	{
		if (checkForDialogue('outro'))
		{
			isCutscene = true;
			trace('[PlayState] Diálogo de outro encontrado, mostrando...');
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
			trace('[PlayState] Focus lost - vocals paused');
		}
		
		// FlxG.sound.music se pausa automáticamente, pero lo marcamos
		trace('[PlayState] Focus lost - music will be paused by FlxG');
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
			trace('[PlayState] Focus gained - music resumed');
			
			// Reanudar vocals sincronizadas con el instrumental
			if (vocals != null && SONG.needsVoices)
			{
				vocals.time = FlxG.sound.music.time;
				vocals.play();
				trace('[PlayState] Focus gained - vocals resumed and resynced');
			}
		}
	}
}
