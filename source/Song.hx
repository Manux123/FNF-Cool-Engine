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
		var rawJson = null;
		var loadingJSON:Bool = true;

		if(Assets.exists(Paths.json('songs/' + folder.toLowerCase() + '/' + jsonInput.toLowerCase())))
			rawJson = Assets.getText(Paths.json('songs/' + folder.toLowerCase() + '/' + jsonInput.toLowerCase())).trim();
		else{
			trace('you are dumm, chek out the root than you select');
			trace('loading tutorial-hard');
			rawJson = Assets.getText(Paths.json('songs/tutorial/tutorial-hard'));
		}

		while (!rawJson.endsWith("}")){
			// LOL GOING THROUGH THE BULLSHIT TO CLEAN IDK WHATS STRANGE
			rawJson = rawJson.substr(0, rawJson.length - 1);
		}

		return parseJSONshit(rawJson);

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
