package;

import states.CacheState.ImageCache;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.text.FlxTypeText;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;

using StringTools;

class DialogueBox extends FlxSpriteGroup
{
	var box:FlxSprite;

	var curCharacter:String = '';

	var dialogue:Alphabet;
	var dialogueList:Array<String> = [];

	// SECOND DIALOGUE FOR THE PIXEL SHIT INSTEAD???
	var swagDialogue:FlxTypeText;

	var dropText:FlxText;

	public var finishThing:Void->Void;

	var portraitLeft:FlxSprite;
	var portraitRight:FlxSprite;

	var handSelect:FlxSprite;
	var bgFade:FlxSprite;

	public function new(talkingRight:Bool = true, ?dialogueList:Array<String>)
	{
		super();

		switch (states.PlayState.SONG.song.toLowerCase())
		{
			case 'senpai':
				FlxG.sound.playMusic(Paths.music('Lunchbox'), 0);
				FlxG.sound.music.fadeIn(1, 0, 0.8);
			case 'thorns':
				FlxG.sound.playMusic(Paths.music('LunchboxScary'), 0);
				FlxG.sound.music.fadeIn(1, 0, 0.8);
		}

		bgFade = new FlxSprite(-200, -200).makeGraphic(Std.int(FlxG.width * 1.3), Std.int(FlxG.height * 1.3), 0xFFB3DFd8);
		bgFade.scrollFactor.set();
		bgFade.alpha = 0;
		add(bgFade);

		new FlxTimer().start(0.83, function(tmr:FlxTimer)
		{
			bgFade.alpha += (1 / 5) * 0.7;
			if (bgFade.alpha > 0.7)
				bgFade.alpha = 0.7;
		}, 5);

		box = new FlxSprite(-20, 45);
		
		var hasDialog = false;
		switch (states.PlayState.SONG.song.toLowerCase())
		{
			case 'senpai':
				hasDialog = true;
				box.frames = Paths.getSparrowAtlas('weeb/pixelUI/dialogueBox-pixel');
				box.animation.addByPrefix('normalOpen', 'Text Box Appear', 24, false);
				box.animation.addByIndices('normal', 'Text Box Appear', [4], "", 24);
			case 'roses':
				hasDialog = true;
				FlxG.sound.play(Paths.sound('ANGRY_TEXT_BOX'));

				box.frames = Paths.getSparrowAtlas('weeb/pixelUI/dialogueBox-senpaiMad');
				box.animation.addByPrefix('normalOpen', 'SENPAI ANGRY IMPACT SPEECH', 24, false);
				box.animation.addByIndices('normal', 'SENPAI ANGRY IMPACT SPEECH', [4], "", 24);

			case 'thorns':
				hasDialog = true;
				box.frames = Paths.getSparrowAtlas('weeb/pixelUI/dialogueBox-evil');
				box.animation.addByPrefix('normalOpen', 'Spirit Textbox spawn', 24, false);
				box.animation.addByIndices('normal', 'Spirit Textbox spawn', [11], "", 24);
		}

		this.dialogueList = dialogueList;
		
		if (!hasDialog)
			return;

		switch(states.PlayState.SONG.song.toLowerCase())
		{
			case 'senpai' | 'roses':
				portraitPath('weeb/senpaiPortrait','Senpai Portrait Enter',-20,40, //Oponnent Portrait
				'weeb/bfPortrait','Boyfriend portrait enter',0,40); //Boyfriend Portrait
			case 'thorns':
				portraitPath('weeb/spiritFaceForward', '',320,170, //Oponnent Portrait
				'weeb/bfPortrait','Boyfriend portrait enter',0,40); //Boyfriend Portrait
		}

		dropText = new FlxText(242, 502, Std.int(FlxG.width * 0.6), "", 32);
		dropText.font = 'Pixel Arial 11 Bold';
		dropText.color = 0xFFD89494;
		add(dropText);

		swagDialogue = new FlxTypeText(240, 500, Std.int(FlxG.width * 0.6), "", 32);
		swagDialogue.font = 'Pixel Arial 11 Bold';
		swagDialogue.color = 0xFF3F2021;
		swagDialogue.sounds = [FlxG.sound.load(Paths.sound('pixelText'), 0.6)];
		add(swagDialogue);

		dialogue = new Alphabet(0, 80, "", false, true);
		// dialogue.x = 90;
		// add(dialogue);
	}

	var dialogueOpened:Bool = false;
	var dialogueStarted:Bool = false;
	var textcontrols:FlxText;

	override function update(elapsed:Float)
	{
		// HARD CODING CUZ IM STUPDI
		if (states.PlayState.SONG.song.toLowerCase() == 'roses')
			portraitLeft.visible = false;
		if (states.PlayState.SONG.song.toLowerCase() == 'thorns')
		{
			//portraitLeft.color = FlxColor.BLACK;
			swagDialogue.color = FlxColor.WHITE;
			dropText.color = FlxColor.BLACK;
		}

		dropText.text = swagDialogue.text;

		if (box.animation.curAnim != null)
		{
			if (box.animation.curAnim.name == 'normalOpen' && box.animation.curAnim.finished)
			{
				box.animation.play('normal');
				dialogueOpened = true;
			}
		}

		if (dialogueOpened && !dialogueStarted)
		{
			startDialogue();
			dialogueStarted = true;
		}

		#if mobile
		var justTouched:Bool = false;

		for (touch in FlxG.touches.list)
		{
			justTouched = false;

			if (touch.justReleased){
				justTouched = true;
			}
		}
		#end

		if (FlxG.keys.justPressed.ANY #if mobile || justTouched #end && dialogueStarted == true)
		{
			remove(dialogue);
				
			FlxG.sound.play(Paths.sound('clickText'), 0.8);

			if(FlxG.keys.justPressed.SHIFT){
				finishThing();
				kill();
				trace('dialogue: SKIP!');
			};

			if (dialogueList[1] == null && dialogueList[0] != null)
			{
				if (!isEnding)
				{
					isEnding = true;

					if (states.PlayState.SONG.song.toLowerCase() == 'senpai' || states.PlayState.SONG.song.toLowerCase() == 'thorns')
						FlxG.sound.music.fadeOut(2.2, 0);

					new FlxTimer().start(0.2, function(tmr:FlxTimer)
					{
						box.alpha -= 1 / 5;
						bgFade.alpha -= 1 / 5 * 0.7;
						portraitLeft.visible = false;
						portraitRight.visible = false;
						swagDialogue.alpha -= 1 / 5;
						dropText.alpha = swagDialogue.alpha;
					}, 5);

					new FlxTimer().start(1.2, function(tmr:FlxTimer)
					{
						finishThing();
						kill();
					});
				}
			}
			else
			{
				dialogueList.remove(dialogueList[0]);
				startDialogue();
			}
		}

		textcontrols = new FlxText(0,50,'Press SHIFT for skip dialogue');
        textcontrols.size = 28;
		textcontrols.x += 600;
		textcontrols.y += 590;
        textcontrols.setBorderStyle(FlxTextBorderStyle.OUTLINE,FlxColor.BLACK,4,1);
        textcontrols.color = FlxColor.WHITE;
        textcontrols.scrollFactor.set();
        add(textcontrols);
		
		super.update(elapsed);
	}

	var isEnding:Bool = false;

	function portraitPath(portLeftFile:String, portLeftXML:String, ?xLeft:Int, ?yLeft:Int, portRightFile:String, portRightXML:String, ?xRight:Int, ?yRight:Int) {
		switch (states.PlayState.SONG.song.toLowerCase()) {
			case 'senpai' | 'roses':
				portraitLeft = new FlxSprite(xLeft, yLeft);
				portraitLeft.frames = Paths.getSparrowAtlas(portLeftFile);
				portraitLeft.animation.addByPrefix('enter', portLeftXML, 24, false);
				portraitLeft.setGraphicSize(Std.int(portraitLeft.width * states.PlayState.daPixelZoom * 0.9));
				portraitLeft.updateHitbox();
				portraitLeft.scrollFactor.set();
				add(portraitLeft);
				portraitLeft.visible = false; 
			case 'thorns':
				portraitLeft = new FlxSprite(xLeft, yLeft).loadGraphic(Paths.image(portLeftFile));
				portraitLeft.setGraphicSize(Std.int(portraitLeft.width * states.PlayState.daPixelZoom * 0.9));
				portraitLeft.updateHitbox();
				portraitLeft.scrollFactor.set();
				add(portraitLeft);
		}

		portraitRight = new FlxSprite(xRight, yRight);
		portraitRight.frames = Paths.getSparrowAtlas(portRightFile);
		portraitRight.animation.addByPrefix('enter', portRightXML, 24, false);
		portraitRight.setGraphicSize(Std.int(portraitRight.width * states.PlayState.daPixelZoom * 0.9));
		portraitRight.updateHitbox();
		portraitRight.scrollFactor.set();
		add(portraitRight);
		portraitRight.visible = false;
		
		box.animation.play('normalOpen');
		box.setGraphicSize(Std.int(box.width * states.PlayState.daPixelZoom * 0.9));
		box.updateHitbox();
		add(box);

		box.screenCenter(X);
		portraitLeft.screenCenter(X);

		handSelect = new FlxSprite(FlxG.width * 0.9, FlxG.height * 0.9).loadGraphic(Paths.image('weeb/pixelUI/hand_textbox'));
		add(handSelect);
	}

	function startDialogue():Void
	{
		cleanDialog();
		// var theDialog:Alphabet = new Alphabet(0, 70, dialogueList[0], false, true);
		// dialogue = theDialog;
		// add(theDialog);

		// swagDialogue.text = ;
		swagDialogue.resetText(dialogueList[0]);
		swagDialogue.start(0.04, true);

		switch (curCharacter)
		{
			case 'dad':
				portraitRight.visible = false;
				if (!portraitLeft.visible){
					portraitLeft.visible = true;
					portraitLeft.animation.play('enter');
				}
			case 'bf':
				portraitLeft.visible = false;
				if (!portraitRight.visible){
					portraitRight.visible = true;
					portraitRight.animation.play('enter');
				}
		}
	}

	function cleanDialog():Void
	{
		var splitName:Array<String> = dialogueList[0].split(":");
		curCharacter = splitName[1];
		dialogueList[0] = dialogueList[0].substr(splitName[1].length + 2).trim();
	}
}
