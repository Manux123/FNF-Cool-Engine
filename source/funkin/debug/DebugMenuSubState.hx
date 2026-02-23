package funkin.debug;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import funkin.gameplay.PlayState;
import funkin.data.Song.SwagSong;
import funkin.menus.FreeplayState.SongMetadata;
import funkin.transitions.StateTransition;
import funkin.menus.FreeplayEditorState;
import funkin.debug.charting.ChartingState;
import funkin.debug.StageEditor;
import funkin.debug.DialogueEditor;
import haxe.Json;
import sys.io.File;
import sys.FileSystem;

/**
 * Submenú que aparece al presionar Enter sobre una canción en FreeplayEditorState.
 * Permite elegir qué editor de debug abrir sin pasar por PlayState.
 */
class DebugMenuSubState extends FlxSubState
{
	// Opciones disponibles en el menú
	static var OPTIONS:Array<String> = [
		"✎  EDIT SONG DATA",
		"♪  CHART EDITOR",
		"⬡  STAGE EDITOR",
		"✦  DIALOGUE EDITOR"
	];

	var songData:SongMetadata;
	var songName:String;

	// UI
	var bg:FlxSprite;
	var panel:FlxSprite;
	var titleText:FlxText;
	var optionTexts:Array<FlxText> = [];
	var cursor:FlxSprite;

	var curSelected:Int = 0;

	// Colores
	static inline var COLOR_BG:Int       = 0xAA000000;
	static inline var COLOR_PANEL:Int    = 0xFF1A1A2E;
	static inline var COLOR_BORDER:Int   = 0xFF00D9FF;
	static inline var COLOR_HOVER:Int    = 0xFF00D9FF;
	static inline var COLOR_NORMAL:Int   = 0xFFCCCCCC;
	static inline var COLOR_TITLE:Int    = 0xFFFFFFFF;
	static inline var COLOR_CURSOR:Int   = 0xFF00D9FF;

	public function new(song:SongMetadata)
	{
		super(0x00000000);
		songData = song;
		songName = song.songName;
	}

	override function create()
	{
		// --- Fondo semitransparente que cubre toda la pantalla ---
		bg = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, COLOR_BG);
		bg.scrollFactor.set();
		bg.alpha = 0;
		add(bg);

		// --- Panel central ---
		var panelW:Int = 520;
		var panelH:Int = 320;
		var panelX:Float = (FlxG.width  - panelW) / 2;
		var panelY:Float = (FlxG.height - panelH) / 2;

		panel = new FlxSprite(panelX, panelY).makeGraphic(panelW, panelH, COLOR_PANEL);
		panel.scrollFactor.set();
		add(panel);

		// Borde superior del panel (acento de color)
		var border = new FlxSprite(panelX, panelY).makeGraphic(panelW, 4, COLOR_BORDER);
		border.scrollFactor.set();
		add(border);

		// --- Título ---
		titleText = new FlxText(panelX, panelY + 16, panelW,
			'OPEN EDITOR  —  ${songName.toUpperCase()}', 18);
		titleText.setFormat(Paths.font("vcr.ttf"), 18, COLOR_TITLE, CENTER,
			FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		titleText.scrollFactor.set();
		add(titleText);

		// Separador
		var sep = new FlxSprite(panelX + 20, panelY + 52).makeGraphic(panelW - 40, 1, 0xFF444466);
		sep.scrollFactor.set();
		add(sep);

		// --- Cursor de selección ---
		cursor = new FlxSprite(panelX + 14, panelY + 70);
		cursor.makeGraphic(6, 36, COLOR_CURSOR);
		cursor.scrollFactor.set();
		add(cursor);

		// --- Opciones ---
		for (i in 0...OPTIONS.length)
		{
			var optY:Float = panelY + 66 + i * 52;
			var txt = new FlxText(panelX + 30, optY, panelW - 60, OPTIONS[i], 20);
			txt.setFormat(Paths.font("vcr.ttf"), 20, COLOR_NORMAL, LEFT,
				FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			txt.scrollFactor.set();
			add(txt);
			optionTexts.push(txt);
		}

		// --- Texto de ayuda ---
		var hint = new FlxText(panelX, panelY + panelH - 30, panelW,
			"↑↓ Browse   ENTER Confirm   ESC Close", 13);
		hint.setFormat(Paths.font("vcr.ttf"), 13, 0xFF888899, CENTER);
		hint.scrollFactor.set();
		add(hint);

		// --- Animación de entrada ---
		panel.alpha   = 0;
		cursor.alpha  = 0;
		for (t in optionTexts) t.alpha = 0;

		FlxTween.tween(bg,    {alpha: 1},    0.18, {ease: FlxEase.quadOut});
		FlxTween.tween(panel, {alpha: 1},    0.22, {ease: FlxEase.quadOut});
		FlxTween.tween(cursor,{alpha: 1},    0.28, {ease: FlxEase.quadOut, startDelay: 0.05});
		for (i in 0...optionTexts.length)
			FlxTween.tween(optionTexts[i], {alpha: 1}, 0.2,
				{ease: FlxEase.quadOut, startDelay: 0.04 * (i + 1)});

		updateSelection();

		super.create();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		// Navegación
		if (FlxG.keys.justPressed.UP   || FlxG.keys.justPressed.W)
			changeSelection(-1);
		if (FlxG.keys.justPressed.DOWN || FlxG.keys.justPressed.S)
			changeSelection(1);

		// Confirmar
		if (FlxG.keys.justPressed.ENTER)
			confirmSelection();

		// Cerrar sin hacer nada
		if (FlxG.keys.justPressed.ESCAPE)
		{
			FlxG.sound.play(Paths.sound('menus/cancelMenu'));
			close();
		}
	}

	function changeSelection(dir:Int):Void
	{
		curSelected = (curSelected + dir + OPTIONS.length) % OPTIONS.length;
		FlxG.sound.play(Paths.sound('menus/scrollMenu'), 0.4);
		updateSelection();
	}

	function updateSelection():Void
	{
		for (i in 0...optionTexts.length)
		{
			var isSelected = (i == curSelected);
			optionTexts[i].color = isSelected ? COLOR_HOVER : COLOR_NORMAL;
			// Escalar levemente el texto seleccionado
			optionTexts[i].scale.set(isSelected ? 1.04 : 1.0, isSelected ? 1.04 : 1.0);
		}

		// Mover el cursor al lado de la opción seleccionada
		var targetY:Float = optionTexts[curSelected].y + (optionTexts[curSelected].height - cursor.height) / 2;
		FlxTween.cancelTweensOf(cursor);
		FlxTween.tween(cursor, {y: targetY}, 0.12, {ease: FlxEase.expoOut});
	}

	function confirmSelection():Void
	{
		FlxG.sound.play(Paths.sound('menus/confirmMenu'), 0.7);

		switch (curSelected)
		{
			// ── 0: Editar datos de la canción (comportamiento original) ──
			case 0:
				// Señalizamos al FreeplayEditorState con pendingAction = 1
				FreeplayEditorState.pendingAction = 1;
				close();

			// ── 1: Chart Editor ──
			case 1:
				openEditor(CHART_EDITOR);

			// ── 2: Stage Editor ──
			case 2:
				openEditor(STAGE_EDITOR);

			// ── 3: Dialogue Editor ──
			case 3:
				openEditor(DIALOGUE_EDITOR);
		}
	}

	function openEditor(type:DebugEditorType):Void
	{
		PlayState.SONG = loadSongFromDisk(songData.songName.toLowerCase());

		switch (type)
		{
			case CHART_EDITOR:    StateTransition.switchState(new ChartingState());
			case STAGE_EDITOR:    StateTransition.switchState(new StageEditor());
			case DIALOGUE_EDITOR: StateTransition.switchState(new DialogueEditor());
		}
	}

	/**
	 * Lee el JSON del chart desde disco y devuelve el SwagSong completo,
	 * preservando todos los campos del archivo (characters, strumsGroups, events, etc.)
	 * igual que hace onLoadComplete en ChartingState.
	 *
	 * Intenta en orden: sin sufijo → -easy → -hard
	 */
	function loadSongFromDisk(songName:String):SwagSong
	{
		var base:String = Paths.resolve('songs/$songName/');
		var paths:Array<String> = [
			base + '$songName.json',
			base + '$songName-easy.json',
			base + '$songName-hard.json'
		];

		for (path in paths)
		{
			try
			{
				if (!FileSystem.exists(path))
					continue;

				var raw:String = File.getContent(path);
				var parsed:Dynamic = Json.parse(raw);

				// El JSON tiene wrapper { "song": { ... } }  — igual que onLoadComplete
				var songObj:SwagSong = cast(parsed.song != null ? parsed.song : parsed);

				// Rellenar sólo campos mínimos que podrían faltar, sin tocar
				// characters, strumsGroups, events, etc. que ya vienen del JSON
				if (songObj.song    == null || songObj.song    == '') songObj.song    = songName;
				if (songObj.player1 == null || songObj.player1 == '') songObj.player1 = 'bf';
				if (songObj.player2 == null || songObj.player2 == '') songObj.player2 = 'dad';
				if (songObj.gfVersion == null)                         songObj.gfVersion = 'gf';
				if (songObj.stage   == null || songObj.stage   == '') songObj.stage   = 'stage_week1';
				if (songObj.bpm     <= 0)  songObj.bpm     = 120;
				if (songObj.speed   <= 0)  songObj.speed   = 2;
				if (songObj.notes   == null)                           songObj.notes   = [];

				trace('[DebugMenuSubState] Chart cargado desde: $path');
				return songObj;
			}
			catch (e:Dynamic)
			{
				trace('[DebugMenuSubState] Error leyendo $path: $e');
			}
		}

		// Fallback mínimo si no existe ningún JSON todavía
		trace('[DebugMenuSubState] No se encontró chart para "$songName", usando fallback vacío');
		return cast {
			song:        songName,
			notes:       [],
			events:      [],
			characters:  [],
			strumsGroups:[],
			bpm:         120,
			speed:       2,
			needsVoices: true,
			stage:       'stage_week1',
			player1:     'bf',
			player2:     'dad',
			gfVersion:   'gf',
			validScore:  false
		};
	}
}

// ─── Tipos auxiliares ───────────────────────────────────────────────
enum DebugEditorType
{
	CHART_EDITOR;
	STAGE_EDITOR;
	DIALOGUE_EDITOR;
}
