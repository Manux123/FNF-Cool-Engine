package;

import Section.SwagSection;
import haxe.Json;
import haxe.format.JsonParser;
import lime.utils.Assets;

using StringTools;

typedef SwagSong =
{
	var song:String;
	var notes:Array<SwagSection>;
	var bpm:Float;
	var needsVoices:Bool;
	var speed:Float;

	var modchart:Bool;

	var player1:String;
	var player2:String;
        var gfVersion:String;
	var validScore:Bool;
}

class Song
{
	public var song:String;
	public var notes:Array<SwagSection>;
	public var bpm:Float;
	public var modchart:Array<SwagSection>;
	public var needsVoices:Bool = true;
	public var speed:Float = 1;

	public var player1:String = 'bf';
	public var player2:String = 'dad';
    public var gfVersion:String = 'gf';

	public function new(song, notes, bpm, modchart)
	{
		this.song = song;
		this.notes = notes;
		this.bpm = bpm;
		this.modchart = modchart;
	}

	public static function loadFromJson(jsonInput:String, ?folder:String):SwagSong
	{
		var loadingJSON:Bool = true;
		if(loadingJSON)
		{
			var rawJson = Assets.getText(Paths.json('songs/' + folder.toLowerCase() + '/' + jsonInput.toLowerCase())).trim();

			while (!rawJson.endsWith("}"))
			{
				rawJson = rawJson.substr(0, rawJson.length - 1);
				// LOL GOING THROUGH THE BULLSHIT TO CLEAN IDK WHATS STRANGE
			}
			return parseJSONshit(rawJson);
		}
		else {
			var rawJson1 = Assets.getText(Paths.json('defaultjsonsong/' + jsonInput.toLowerCase())).trim();

			while (!rawJson1.endsWith("}"))
			{
				rawJson1 = rawJson1.substr(0, rawJson1.length - 1);
				// LOL GOING THROUGH THE BULLSHIT TO CLEAN IDK WHATS STRANGE
			}
			return parseJSONshit(rawJson1);
		}

		// FIX THE CASTING ON WINDOWS/NATIVE
		// Windows???
		// trace(songData);

		// trace('LOADED FROM JSON: ' + songData.notes);
		/* 
			for (i in 0...songData.notes.length)
			{
				trace('LOADED FROM JSON: ' + songData.notes[i].sectionNotes);
				// songData.notes[i].sectionNotes = songData.notes[i].sectionNotes
			}

				daNotes = songData.notes;
				daSong = songData.song;
				daBpm = songData.bpm; */
	}

	public static function parseJSONshit(rawJson:String):SwagSong
	{
		var swagShit:SwagSong = cast Json.parse(rawJson).song;
		swagShit.validScore = true;
		return swagShit;
	}
}
