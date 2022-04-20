/*package debug;

import flixel.*;
import flixel.util.*;
import flixel.text.FlxText;
import states.PlayState;
import states.MusicBeatState;
import states.ModsFreeplayState;
#if windows
import Discord.DiscordClient;
#end

using StringTools;

class StageDebug extends MusicBeatState
{
	var camGame:FlxCamera;
	var camHUD:FlxCamera;
	var boyfriend:Boyfriend;
	var dad:Character;
	var gf:Character;
	var q:FlxText;
	var gfno:Bool = false;
	var coords:Array<Float> = [
		400, 130, //Gf
		100, 100, //Dad
		770, 450 //Bf
	];

	override public function create() {
		FlxG.mouse.visible = true;
		//FlxG.sound.music.stop();

		camGame = new FlxCamera();
		camHUD = new FlxCamera();
		camHUD.bgColor.alpha = 0;

		FlxG.cameras.reset(camGame);
		FlxG.cameras.add(camHUD,false);

		if(ModsFreeplayState.onMods){
			if (PlayState.SONG.player1 == null) //To prevent the application from closing.
				PlayState.SONG.player1 = 'bf';
			if (PlayState.SONG.player2 == null)
				PlayState.SONG.player2 = 'dad';
			if (PlayState.SONG.gfVersion == null)
				PlayState.SONG.gfVersion = 'gf';

			if (PlayState.SONG.stage != null)
			{
				var STAGE:StageData.StageFile = StageData.loadFromJson(PlayState.SONG.stage);
				STAGE.name = PlayState.SONG.stage;
				for(i in 0... STAGE.stagePices.length){
					var object:FlxSprite = new FlxSprite(0,0);
					var curPice = STAGE.stagePices[i][0];
					var framesAnim = STAGE.intFrameslol[i];
					var animData = STAGE.animationsData[i];
					if (STAGE.animated[i]) {
						for(i in 0... animData.length){
							object.frames = ModPaths.getBGsAnimated(curPice);
							var split = STAGE.animationsData[i].split(':');
							object.animation.addByPrefix(split[0],split[1],framesAnim[0],true);
							object.animation.play(split[0]);
						}
					}
					else
						object.loadGraphic(ModPaths.modBGImage(curPice, ModsFreeplayState.mod));
					var offsets = STAGE.picesOffsets[i];
					var offsetsScroll = STAGE.scrollOffsets[i];
					var alphaLol = STAGE.alpha[i];
					if (STAGE.screenCenter)
						object.screenCenter();
					object.x += offsets[0];
					object.y += offsets[1];
					object.alpha = alphaLol[0];
					object.antialiasing = STAGE.antialiasing;
					object.scrollFactor.set(offsetsScroll[0],offsetsScroll[1]);
					PlayState.defaultCamZoom = STAGE.defaultZoom;
					add(object); //BETA
				}
			}
			else
				PlayState.SONG.stage = 'stage_week1';
		} else
			stages();

		FlxG.camera.zoom = PlayState.defaultCamZoom;
		gf = new Character(coords[0],coords[1],PlayState.SONG.gfVersion);
		gf.scrollFactor.set(0.95, 0.95);
		add(gf);

		dad = new Character(coords[2],coords[3],PlayState.SONG.player2);
		add(dad);

		boyfriend = new Boyfriend(coords[4],coords[5],PlayState.SONG.player1);
		add(boyfriend);

		q = new FlxText(0,50, 0, "", 32);
		q.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE,FlxColor.BLACK);
		q.scrollFactor.set();
		add(q);

		q.cameras = [camHUD];

		super.create();
	}
	override public function update(elapsed:Float) {
		if (FlxG.keys.justPressed.ESCAPE)
		{
			FlxG.mouse.visible = false;
			LoadingState.loadAndSwitchState(new PlayState());
		}

		if (FlxG.mouse.overlaps(boyfriend) && FlxG.mouse.pressed) 
		{
			boyfriend.setPosition(FlxG.mouse.x, FlxG.mouse.y);
		}
		else
		{
			boyfriend.setPosition(coords[4], coords[5]);
		}
		if (FlxG.mouse.overlaps(dad) && FlxG.mouse.pressed) 
		{
			dad.setPosition(FlxG.mouse.x, FlxG.mouse.y);
		}
		else
		{
			dad.setPosition(coords[2], coords[3]);
		}
		if (FlxG.mouse.overlaps(gf) && FlxG.mouse.pressed) 
		{
			gf.setPosition(FlxG.mouse.x, FlxG.mouse.y);
		}
		else
		{
			gf.setPosition(coords[0], coords[1]);
		}

		q.text = ' Bf.x = ' + boyfriend.x +'\n Bf.y = ' + boyfriend.y + '\n  Dad.x = ' + dad.x +
		'\n  Dad.y = ' + dad.y +'\n' + ' Gf.x = ' + gf.x +'\n Gf.y = ' + gf.y + '\n';
		
		super.update(elapsed);
	}

	function stages() {
		switch(PlayState.SONG.stage)
		{
			case 'stage_week1': {
				PlayState.defaultCamZoom = 0.9;
				var bg:FlxSprite = new FlxSprite(-600, -200).loadGraphic(Paths.image('stageback'));
				bg.antialiasing = true;
				bg.scrollFactor.set(0.9, 0.9);
				bg.active = false;
				add(bg);

				var stageFront:FlxSprite = new FlxSprite(-650, 600).loadGraphic(Paths.image('stagefront'));
				stageFront.setGraphicSize(Std.int(stageFront.width * 1.1));
				stageFront.updateHitbox();
				stageFront.antialiasing = true;
				stageFront.scrollFactor.set(0.9, 0.9);
				stageFront.active = false;
				add(stageFront);

				var stageCurtains:FlxSprite = new FlxSprite(-500, -300).loadGraphic(Paths.image('stagecurtains'));
				stageCurtains.setGraphicSize(Std.int(stageCurtains.width * 0.9));
				stageCurtains.updateHitbox();
				stageCurtains.antialiasing = true;
				stageCurtains.scrollFactor.set(1.3, 1.3);
				stageCurtains.active = false;
				add(stageCurtains);
			}
			default: {
				PlayState.defaultCamZoom = 0.9;
				var bg:FlxSprite = new FlxSprite(-600, -200).loadGraphic(Paths.image('stageback'));
				bg.antialiasing = true;
				bg.scrollFactor.set(0.9, 0.9);
				bg.active = false;
				add(bg);

				var stageFront:FlxSprite = new FlxSprite(-650, 600).loadGraphic(Paths.image('stagefront'));
				stageFront.setGraphicSize(Std.int(stageFront.width * 1.1));
				stageFront.updateHitbox();
				stageFront.antialiasing = true;
				stageFront.scrollFactor.set(0.9, 0.9);
				stageFront.active = false;
				add(stageFront);

				var stageCurtains:FlxSprite = new FlxSprite(-500, -300).loadGraphic(Paths.image('stagecurtains'));
				stageCurtains.setGraphicSize(Std.int(stageCurtains.width * 0.9));
				stageCurtains.updateHitbox();
				stageCurtains.antialiasing = true;
				stageCurtains.scrollFactor.set(1.3, 1.3);
				stageCurtains.active = false;

				add(stageCurtains);
			}
		}
	}
}
*/ //temporarly closing dis
