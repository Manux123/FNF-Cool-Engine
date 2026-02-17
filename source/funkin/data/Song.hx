package funkin.data;

import funkin.data.Section.SwagSection;
import haxe.Json;
import haxe.format.JsonParser;
import lime.utils.Assets;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

/**
 * Datos de un slot de personaje
 */
typedef CharacterSlotData =
{
	var name:String; // Nombre del personaje (ej: "bf", "dad", "pico")
	var x:Float; // Posición X
	var y:Float; // Posición Y
	var ?flip:Bool; // Voltear sprite
	var ?scale:Float; // Escala del personaje
	var ?visible:Bool; // Visibilidad del personaje
	// === CAMPOS DEL CHART EDITOR ===
	var ?type:String; // "Opponent", "Player", "Girlfriend", "Other"
	var ?strumsGroup:String; // ID del StrumsGroup al que está vinculado
}

/**
 * Datos de un grupo de strums (4 flechas)
 */
typedef StrumsGroupData =
{
	var id:String; // ID único del grupo (ej: "bf_strums_1", "dad_strums_1")
	var x:Float; // Posición X base
	var y:Float; // Posición Y
	var visible:Bool; // Si se muestran o no
	var cpu:Bool; // Si es CPU o jugador
	var ?spacing:Float; // Espaciado entre flechas (default 160)
	var ?scale:Float; // Escala de las flechas
}

/**
 * Evento del chart editor (Camera, BPM Change, etc.)
 */
typedef ChartEvent =
{
	var stepTime:Float; // Step en el que ocurre
	var type:String;    // "Camera", "BPM Change", "Alt Anim", "Play Anim", "Camera Zoom", etc.
	var value:String;   // Valor del evento (ej: "dad", "1.2", etc.)
}

/**
 * SwagSong MEJORADO - Soporte para múltiples personajes
 */
typedef SwagSong =
{
	var song:String;
	var notes:Array<SwagSection>;
	var bpm:Float;
	var needsVoices:Bool;
	var speed:Float;
	
	// === LEGACY SUPPORT (compatibilidad con charts viejos) ===
	@:optional var player1:String; // BF (legacy)
	@:optional var player2:String; // Dad (legacy)
	@:optional var gfVersion:String; // GF (legacy)
	
	// === NUEVO SISTEMA MULTI-CHARACTER ===
	@:optional var characters:Array<CharacterSlotData>; // Array de personajes
	@:optional var strumsGroups:Array<StrumsGroupData>; // Array de grupos de strums

	// === EVENTOS DEL CHART EDITOR ===
	@:optional var events:Array<ChartEvent>; // Eventos (camera, bpm change, etc.)
	
	var stage:String;
	var validScore:Bool;
}

class Song
{
	public var song:String;
	public var notes:Array<SwagSection>;
	public var bpm:Float;
	public var needsVoices:Bool = true;
	public var speed:Float = 1;

	// Legacy
	public var player1:String = 'bf';
	public var player2:String = 'dad';
	public var gfVersion:String = 'gf';
	
	// Nuevo sistema
	public var characters:Array<CharacterSlotData> = [];
	public var strumsGroups:Array<StrumsGroupData> = [];

	public function new(song, notes, bpm)
	{
		this.song = song;
		this.notes = notes;
		this.bpm = bpm;
	}

	public static function loadFromJson(jsonInput:String, ?folder:String):SwagSong
	{
		var rawJson = null;
		var loadingJSON:Bool = true;

		var jsonPath = folder.toLowerCase() + '/' + jsonInput.toLowerCase();
		
		trace('[Song] loadFromJson called with: folder=$folder, jsonInput=$jsonInput');
		trace('[Song] Constructed jsonPath: $jsonPath');
		
		// Check if file exists using appropriate method for platform
		var fileExists:Bool = false;
		
		#if sys
		// Desktop: use FileSystem
		var fullPath = 'assets/songs/$jsonPath.json';
		fileExists = FileSystem.exists(fullPath);
		trace('[Song] Checking FileSystem.exists($fullPath) = $fileExists');
		
		if (fileExists)
		{
			rawJson = File.getContent(fullPath).trim();
			trace('[Song] Loaded file with FileSystem');
		}
		#else
		// Web/Mobile: use Assets
		fileExists = Assets.exists(Paths.jsonSong(jsonPath));
		trace('[Song] Checking Assets.exists(${Paths.jsonSong(jsonPath)}) = $fileExists');
		
		if (fileExists)
		{
			rawJson = Assets.getText(Paths.jsonSong(jsonPath)).trim();
			trace('[Song] Loaded file with Assets');
		}
		#end
		
		if (!fileExists)
		{
			trace('[Song] ERROR: Chart file not found at: $jsonPath');
			throw 'Chart file not found: $jsonPath.json';
		}

		while (!rawJson.endsWith("}")){
			// LOL GOING THROUGH THE BULLSHIT TO CLEAN IDK WHATS STRANGE
			rawJson = rawJson.substr(0, rawJson.length - 1);
		}

		return parseJSONshit(rawJson);
	}

	public static function parseJSONshit(rawJson:String):SwagSong
	{
		trace('[Song] === parseJSONshit LLAMADO ===');
		var swagShit:SwagSong = cast Json.parse(rawJson).song;
		swagShit.validScore = true;
		
		trace('[Song] characters antes de migración: ' + (swagShit.characters != null ? swagShit.characters.length + ' personajes' : 'NULL'));
		trace('[Song] strumsGroups antes de migración: ' + (swagShit.strumsGroups != null ? swagShit.strumsGroups.length + ' grupos' : 'NULL'));
		
		// === AUTO-MIGRATION: Convertir formato legacy a nuevo ===
		if (swagShit.characters == null || swagShit.characters.length == 0)
		{
			trace('[Song] Detectado formato legacy, convirtiendo a nuevo formato...');
			trace('[Song] player1 (bf): ' + swagShit.player1);
			trace('[Song] player2 (dad): ' + swagShit.player2);
			trace('[Song] gfVersion: ' + swagShit.gfVersion);
			
			swagShit.characters = [];
			swagShit.strumsGroups = [];
			
			// Crear personajes por defecto
			var gfChar:CharacterSlotData = {
				name: swagShit.gfVersion != null ? swagShit.gfVersion : 'gf',
				x: 0, // Se ajustará en PlayState según el stage
				y: 0,
				visible: true
			};
			
			var dadChar:CharacterSlotData = {
				name: swagShit.player2 != null ? swagShit.player2 : 'dad',
				x: 0,
				y: 0,
				visible: true
			};
			
			var bfChar:CharacterSlotData = {
				name: swagShit.player1 != null ? swagShit.player1 : 'bf',
				x: 0,
				y: 0,
				visible: true
			};
			
			swagShit.characters = [gfChar, dadChar, bfChar];
			
			// Crear grupos de strums por defecto
			var cpuStrums:StrumsGroupData = {
				id: 'cpu_strums_0',
				x: 100,
				y: 50,
				visible: true,
				cpu: true,
				spacing: 110
			};
			
			var playerStrums:StrumsGroupData = {
				id: 'player_strums_0',
				x: 740,
				y: 50,
				visible: true,
				cpu: false,
				spacing: 110
			};
			
			swagShit.strumsGroups = [cpuStrums, playerStrums];
			
			trace('[Song] Migración completa:');
			trace('[Song]   - characters: ${swagShit.characters.length}');
			for (i in 0...swagShit.characters.length)
				trace('[Song]     [$i] ${swagShit.characters[i].name}');
			trace('[Song]   - strumsGroups: ${swagShit.strumsGroups.length}');
			for (group in swagShit.strumsGroups)
				trace('[Song]     - ${group.id} (CPU: ${group.cpu})');
		}
		else
		{
			trace('[Song] Formato nuevo detectado, NO se requiere migración');
			trace('[Song]   - characters: ${swagShit.characters.length}');
			trace('[Song]   - strumsGroups: ${swagShit.strumsGroups != null ? swagShit.strumsGroups.length : 0}');
		}
		
		return swagShit;
	}
	
	/**
	 * NUEVO: Obtener personaje por índice
	 */
	public static function getCharacter(SONG:SwagSong, index:Int):CharacterSlotData
	{
		if (SONG.characters != null && index >= 0 && index < SONG.characters.length)
			return SONG.characters[index];
		return null;
	}
	
	/**
	 * NUEVO: Obtener grupo de strums por ID
	 */
	public static function getStrumsGroup(SONG:SwagSong, id:String):StrumsGroupData
	{
		if (SONG.strumsGroups != null)
		{
			for (group in SONG.strumsGroups)
			{
				if (group.id == id)
					return group;
			}
		}
		return null;
	}
	
	/**
	 * NUEVO: Obtener todos los grupos de strums CPU
	 */
	public static function getCPUStrumsGroups(SONG:SwagSong):Array<StrumsGroupData>
	{
		var cpuGroups:Array<StrumsGroupData> = [];
		if (SONG.strumsGroups != null)
		{
			for (group in SONG.strumsGroups)
			{
				if (group.cpu)
					cpuGroups.push(group);
			}
		}
		return cpuGroups;
	}
	
	/**
	 * NUEVO: Obtener todos los grupos de strums del jugador
	 */
	public static function getPlayerStrumsGroups(SONG:SwagSong):Array<StrumsGroupData>
	{
		var playerGroups:Array<StrumsGroupData> = [];
		if (SONG.strumsGroups != null)
		{
			for (group in SONG.strumsGroups)
			{
				if (!group.cpu)
					playerGroups.push(group);
			}
		}
		return playerGroups;
	}
}