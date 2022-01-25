package states;

#if desktop
import Discord.DiscordClient;
#end
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.display.FlxGridOverlay;
import flixel.addons.transition.FlxTransitionableState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.tweens.FlxEase;
import states.StoryMenuState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import lime.utils.Assets;
import flixel.system.FlxSound;
import openfl.utils.Assets as OpenFlAssets;

using StringTools;

//Just a edited vercion of FreeplayState.hx
class ModsFreeplayState extends states.MusicBeatState
{
	var toBeFinished = 0;
	var finished = 0;

	//now you need to add the music to the file cache-music, in the path `mods/data/cache-music.txt`
	public var musicgame:Array<String> = CoolUtil.coolTextFile(Paths.txt('cache-music'));

	var songs:Array<FreeplayState.SongMetadata> = [];

	var selector:FlxText;
	var discSpr:FlxSprite;
	private static var curSelected:Int = 0;
	private static var curDifficulty:Int = 1;

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
	var intendedColor:Int;
	var colorTween:FlxTween;
	
	private var initSonglist:Array<String>;

	public static var mod:String;
	public static var onMods:Bool = false;

	override function create()
	{
		onMods = true;

		initSonglist = CoolUtil.coolTextFile(ModPaths.getModTxt('songList',mod));

		transIn = FlxTransitionableState.defaultTransIn;
		transOut = FlxTransitionableState.defaultTransOut;
		for (i in 0...initSonglist.length)
		{
			var songArray:Array<String> = initSonglist[i].split(":");
			addSong(songArray[0], (songArray[2]==null)?0:Std.parseInt(songArray[2]), songArray[1]);
			songs[songs.length-1].color = Std.parseInt(songArray[3]);
		}
		var colorsList = CoolUtil.coolTextFile(ModPaths.getModTxt('songColors',mod));
		for (i in 0...colorsList.length)
		{
			coolColors.push(Std.parseInt(colorsList[i]));
		}

		// Jloor god B)

		#if desktop
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the FreePlay", null);
		#end

		//addSong('Test', 7,'bf-pixel');

		bg = new FlxSprite().loadGraphic(Paths.image('menu/menuDesat'));
		add(bg);

		grpSongs = new FlxTypedGroup<Alphabet>();
		add(grpSongs);

		for (i in 0...songs.length)
		{
			songText = new Alphabet(0, (70 * i) + 30, songs[i].songName, true, false);
			songText.isMenuItem = true;
			songText.targetY = i;
			grpSongs.add(songText);

			var icon:HealthIcon = new HealthIcon(songs[i].songCharacter);
			icon.sprTracker = songText;

			// using a FlxGroup is too much fuss!
			iconArray.push(icon);
			add(icon);

			// songText.x += 40;
			// DONT PUT X IN THE FIRST PARAMETER OF new ALPHABET() !!
			// songText.screenCenter(X);
		}
		
		scoreText = new FlxText(FlxG.width * 0.7, 5, 0, "", 32);
		scoreText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, RIGHT);

		scoreBG = new FlxSprite(scoreText.x - 6, 0).makeGraphic(1, 66, 0xFF000000);
		scoreBG.alpha = 0.6;
		add(scoreBG);

		diffText = new FlxText(scoreText.x, scoreText.y + 36, 0, "", 24);
		diffText.font = scoreText.font;
		add(diffText);

		add(scoreText);

		bg.color = songs[curSelected].color;
		intendedColor = bg.color;
		changeSelection();
		changeDiff();

		var swag:Alphabet = new Alphabet(1, 0, "swag");

		var textBG:FlxSprite = new FlxSprite(0, FlxG.height - 26).makeGraphic(FlxG.width, 26, 0xFF000000);
		textBG.alpha = 0.6;
		add(textBG);

		var leText:FlxText = new FlxText(5, FlxG.height - 19, 0, "Press SPACE to listen to this Song / ESC to exit", 12);
		leText.scrollFactor.set();
		leText.screenCenter(X);
		leText.setFormat('VCR OSD Mono', 16, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(leText);
		
		var text:FlxText = new FlxText(textBG.x, textBG.y + 4, FlxG.width, 18);
		text.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, RIGHT);
		text.scrollFactor.set();
		add(text);

		var versionShit:FlxText = new FlxText(5, FlxG.height - 19, 0, "FNF Cool Engine - v" + lime.app.Application.current.meta.get('version'), 12);
		versionShit.scrollFactor.set();
		versionShit.setFormat("Friday Night Funkin Regular", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(versionShit);
		super.create();

		#if mobileC
		addVirtualPad(FULL, A_B);
		#end
		
		bpmSong = (60/Song.loadFromJson(initSonglist[curSelected] + difficultyStuff[curDifficulty],initSonglist[curSelected]).bpm)/1;
	}

	override function closeSubState() {
		changeSelection();
		super.closeSubState();
	}

	public function addSong(songName:String, weekNum:Int, songCharacter:String)
	{
		songs.push(new FreeplayState.SongMetadata(songName, weekNum, songCharacter));
	}

	public function addWeek(songs:Array<String>, weekNum:Int, ?songCharacters:Array<String>)
	{
		if (songCharacters == null)
			songCharacters = ['bf'];

		var num:Int = 0;
		for (song in songs)
		{
			addSong(song, weekNum, songCharacters[num]);

			if (songCharacters.length != 1)
				num++;
		}
	}

	var instPlaying:Int = -1;
	private static var vocals:FlxSound = null;

	private var bpmtime:Float = 0;
	private var bpmSong:Float = 0;

	private var vibing:Bool = false;

	override function update(elapsed:Float)
	{
		bpmtime+=elapsed;

		if (FlxG.sound.music.volume < 0.7)
		{
			FlxG.sound.music.volume += 0.5 * FlxG.elapsed;
		}

		lerpScore = Math.floor(FlxMath.lerp(lerpScore, intendedScore, boundTo(elapsed * 24, 0, 1)));
		lerpRating = FlxMath.lerp(lerpRating, intendedRating, boundTo(elapsed * 12, 0, 1));

		if (Math.abs(lerpScore - intendedScore) <= 10)
			lerpScore = intendedScore;
		if (Math.abs(lerpRating - intendedRating) <= 0.01)
			lerpRating = intendedRating;

		scoreText.text = 'PERSONAL BEST: ' + lerpScore;
		positionHighscore();

		var upP = controls.UP_P;
		var downP = controls.DOWN_P;
		var accepted = controls.ACCEPT;
		var space = FlxG.keys.justPressed.SPACE;

		if(vibing)
			if(bpmtime > bpmSong){
				var inZoom = FlxG.camera.zoom;
				FlxG.camera.zoom = inZoom*1.07;
				FlxTween.tween(FlxG.camera,{zoom: inZoom},(cast(bpmSong/5)));
				bpmtime -= bpmSong;
			}

		if (upP)
		{
			changeSelection(-1);
		}
		if (downP)
		{
			changeSelection(1);
		}

		if (controls.LEFT_P)
			changeDiff(-1);
		if (controls.RIGHT_P)
			changeDiff(1);

		if (controls.BACK)
		{
			if(colorTween != null) {
				colorTween.cancel();
			}
			FlxG.sound.play(Paths.sound('cancelMenu'));
			FlxG.switchState(new ModsState());
			onMods = false;
		}

		#if PRELOAD_ALL
		if(space && instPlaying != curSelected)
		{
			destroyFreeplayVocals();
			var poop:String = Highscore.formatSong(songs[curSelected].songName.toLowerCase(), curDifficulty);
			states.PlayState.SONG = Song.loadFromJson(poop, songs[curSelected].songName.toLowerCase());
			if (states.PlayState.SONG.needsVoices)
				vocals = new FlxSound().loadEmbedded(ModPaths.getModVoices(states.PlayState.SONG.song,mod));
			else
				vocals = new FlxSound();

			FlxG.sound.list.add(vocals);
			FlxG.sound.playMusic(ModPaths.getModInst(states.PlayState.SONG.song,mod), 0.7);
			vocals.play();
			vocals.persist = true;
			vocals.looped = true;
			vocals.volume = 0.7;
			instPlaying = curSelected;

			discSpr = new FlxSprite(750, 280);
			discSpr.frames = Paths.getSparrowAtlas('freeplay/record player freeplay'); // made by zero B) is very cool.
			discSpr.antialiasing = true;
			discSpr.animation.addByPrefix('idle', 'disco', 24);
			discSpr.animation.play('idle');
			discSpr.x += 750;
			vibing = true;
			bpmSong = (60/Song.loadFromJson(initSonglist[curSelected] + difficultyStuff[curDifficulty],initSonglist[curSelected]).bpm)/1;
			bpmtime = 0;

			//disc.y += 880;
			discSpr.setGraphicSize(Std.int(discSpr.width * 0.5));
			discSpr.updateHitbox();
			add(discSpr);
			
			FlxTween.tween(discSpr,{"x":750},0.6,{ease: FlxEase.elasticInOut});
			//FlxTween.tween(disc, {y: disc.y - 770}, 1.5, {ease: FlxEase.quadInOut, type: ONESHOT});

			// I speak spanish ._.XD
			// code made by Manux Bv
		}
		else #end if (accepted)
		{
			loadFreeplaySong(songs[curSelected].songName.toLowerCase(),0,curDifficulty);
			if(colorTween != null) {
				colorTween.cancel();
			}
		}
		super.update(elapsed);
	}

	public static function destroyFreeplayVocals() {
		if(vocals != null) {
			vocals.stop();
			vocals.destroy();
		}
		vocals = null;
	}

	function changeDiff(change:Int = 0)
	{
		curDifficulty += change;

		if (curDifficulty < 0)
			curDifficulty = difficultyStuff.length-1;
		if (curDifficulty >= difficultyStuff.length)
			curDifficulty = 0;

		#if !switch
		intendedScore = Highscore.getScore(songs[curSelected].songName, curDifficulty);
		intendedRating = Highscore.getRating(songs[curSelected].songName, curDifficulty);
		#end

		states.PlayState.storyDifficulty = curDifficulty;
		diffText.text = '< ' + CoolUtil.difficultyString() + ' >';
		positionHighscore();
	}

	inline static public function loadFreeplaySong(song:String,week:Int,difficulty:Int){
		var songLowercase:String = song;
		var poop:String = Highscore.formatSong(songLowercase, difficulty);
		//FlxTween.tween(songText.isMenuItem, {y: songText.y - 2000}, 0.6, {ease: FlxEase.quadIn, type: ONESHOT});
		trace(poop);

		states.PlayState.SONG = Song.loadFromJson(poop, songLowercase);
		states.PlayState.isStoryMode = false;
		states.PlayState.storyDifficulty = difficulty;

		states.PlayState.storyWeek = week;
		FlxG.sound.music.volume = 0;

		FlxG.camera.flash(FlxColor.WHITE, 1);
		FlxG.sound.play(Paths.sound('confirmMenu'), 0.7);

		LoadingState.loadAndSwitchState(new PlayState());
		PlayState.instance.isMod = true;

		destroyFreeplayVocals();
	}
	function changeSelection(change:Int = 0)
	{
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		curSelected += change;

		if (curSelected < 0)
			curSelected = songs.length - 1;
		if (curSelected >= songs.length)
			curSelected = 0;

		var newColor:Int = songs[curSelected].color;
		if(newColor != intendedColor) {
			if(colorTween != null) {
				colorTween.cancel();
			}
			intendedColor = newColor;
			colorTween = FlxTween.color(bg, 1, bg.color, intendedColor, {
				onComplete: function(twn:FlxTween) {
					colorTween = null;
				}
			});
		}

		// selector.y = (70 * curSelected) + 30;

		#if !switch
		intendedScore = Highscore.getScore(songs[curSelected].songName, curDifficulty);
		intendedRating = Highscore.getRating(songs[curSelected].songName, curDifficulty);
		#end

		var bullShit:Int = 0;

		for (i in 0...iconArray.length)
		{
			iconArray[i].alpha = 0.6;
		}

		iconArray[curSelected].alpha = 1;

		for (item in grpSongs.members)
		{
			item.targetY = bullShit - curSelected;
			bullShit++;

			item.alpha = 0.6;
			// item.setGraphicSize(Std.int(item.width * 0.8));

			if (item.targetY == 0)
			{
				item.alpha = 1;
				// item.setGraphicSize(Std.int(item.width));
			}
		}
		changeDiff();
	}

	private function positionHighscore() {
		scoreText.x = FlxG.width - scoreText.width - 6;

		scoreBG.scale.x = FlxG.width - scoreText.x + 6;
		scoreBG.x = FlxG.width - (scoreBG.scale.x / 2);
		diffText.x = Std.int(scoreBG.x + (scoreBG.width / 2));
		diffText.x -= diffText.width / 2;
	}

	public static var difficultyStuff:Array<Dynamic> = [
		['Easy', '-easy'],
		['Normal', ''],
		['Hard', '-hard']
	];

	public static function difficultyString():String
	{
		return difficultyStuff[states.PlayState.storyDifficulty][0].toUpperCase();
	}

	public static function boundTo(value:Float, min:Float, max:Float):Float {
		var newValue:Float = value;
		if(newValue < min) newValue = min;
		else if(newValue > max) newValue = max;
		return newValue;
	}
}