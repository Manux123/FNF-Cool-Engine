package states;

#if desktop
import Discord.DiscordClient;
#end
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.addons.transition.FlxTransitionableState;
import flixel.effects.FlxFlicker;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import lime.app.Application;
import openfl.display.BitmapData as Bitmap;

using StringTools;

class MainMenuState extends states.MusicBeatState
{
	var curSelected:Int = 0;

	var menuItems:FlxTypedGroup<FlxSprite>;

	var optionShit:Array<String> = ['story-mode', 'freeplay'#if !switch ,'options', 'donate'#end];

	var canSnap:Array<Float> = [];
	var camFollow:FlxObject;
	var newInput:Bool = true;
	var menuItem:FlxSprite;
	public static var firstStart:Bool = true;

	public static var finishedFunnyMove:Bool = false;

	override function create()
	{
		//LOAD CUZ THIS SHIT DONT DO IT SOME IN THE CACHESTATE.HX FUCK
		PlayerSettings.player1.controls.loadKeyBinds();

		#if desktop
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menu", null);
		#end

		transIn = FlxTransitionableState.defaultTransIn;
		transOut = FlxTransitionableState.defaultTransOut;

		#if !MAINMENU
		if (!FlxG.sound.music.playing){
			FlxG.sound.playMusic(Paths.music('freakyMenu'));
		}
		#end

		persistentUpdate = persistentDraw = true;

		var bg:FlxSprite = new FlxSprite(-80).loadGraphic(Bitmap.fromFile(Paths.image('menu/menuBG')));
		bg.scrollFactor.x = 0;
		bg.scrollFactor.y = 0.18;
		bg.screenCenter();
		bg.antialiasing = true;
		add(bg);

		camFollow = new FlxObject(0, 0, 1, 1);
		add(camFollow);

		menuItems = new FlxTypedGroup<FlxSprite>();
		add(menuItems);

		for (i in 0...optionShit.length)
		{
			var offset:Float = 108 - (Math.max(optionShit.length, 4) - 4) * 80;
			var menuItem:FlxSprite = new FlxSprite(70, (i * 140)  + offset);
			menuItem.frames = Paths.getSparrowAtlas('mainmenu/menu_' + optionShit[i]);
			menuItem.animation.addByPrefix('idle', optionShit[i] + " basic", 24);
			menuItem.animation.addByPrefix('selected', optionShit[i] + " white", 24);
			menuItem.animation.play('idle');
			menuItem.ID = i;
			//menuItem.screenCenter(X);
			menuItems.add(menuItem);
			var scr:Float = (optionShit.length - 4) * 0.135;
			if(optionShit.length < 6) scr = 0;
			menuItem.scrollFactor.set(0, scr);
			menuItem.antialiasing = true;
			menuItem.setGraphicSize(Std.int(menuItem.width * 0.8));
			menuItem.updateHitbox();

		}
		//FlxG.camera.follow(camFollow, null, 0.06);
		
		var versionShit:FlxText = new FlxText(5, FlxG.height - 19, 0, "Friday Night Funkin v0.2.7.1", 12);
		versionShit.scrollFactor.set();
		versionShit.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(versionShit);

		var versionShit2:FlxText = new FlxText(5, FlxG.height - 19, 0, 'Cool Engine - V${Application.current.meta.get('version')}', 12);
		versionShit2.scrollFactor.set();
		versionShit2.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		versionShit2.y -= 20;
		add(versionShit2);

		// NG.core.calls.event.logEvent('swag').send();

		changeItem();

		#if mobileC
		addVirtualPad(UP_DOWN, A_B);
		#end
		
		super.create();
	}

	var selectedSomethin:Bool = false;

	override function update(elapsed:Float)
	{
		#if !MAINMENU
		if (FlxG.sound.music.volume < 0.8)
		{
			FlxG.sound.music.volume += 0.5 * FlxG.elapsed;
		}
		#end

		if (!selectedSomethin)
		{
			if (controls.UP_P)
			{
				FlxG.sound.play(Paths.sound('scrollMenu'));
				changeItem(-1);
			}

			if (controls.DOWN_P)
			{
				FlxG.sound.play(Paths.sound('scrollMenu'));
				changeItem(1);
			}

			if (controls.BACK)
			{
				FlxG.switchState(new TitleState());
			}

			if (controls.ACCEPT)
			{
				if (optionShit[curSelected] == 'donate')
				{
					#if linux
					Sys.command('/usr/bin/xdg-open', ["https://www.kickstarter.com/projects/funkin/friday-night-funkin-the-full-ass-game", "&"]);
					#else
					FlxG.openURL('https://www.kickstarter.com/projects/funkin/friday-night-funkin-the-full-ass-game');
					#end
				}
				else
				{
					//FlxTween.tween(menuItem, {x: menuItem.x + 200}, 0.6, {ease: FlxEase.quadInOut, type: ONESHOT});
					selectedSomethin = true;
					FlxG.sound.play(Paths.sound('confirmMenu'));
					FlxG.camera.flash(FlxColor.WHITE);

					menuItems.forEach(function(spr:FlxSprite)
					{
						if (curSelected != spr.ID)
						{
							FlxTween.tween(spr, {alpha: 0}, 0.4, {
								ease: FlxEase.quadOut,
								onComplete: function(twn:FlxTween)
								{
									spr.kill();
								}
							});
						}
						else
						{
							menuItems.forEach(function(spr:FlxSprite)
								{
									if (curSelected != spr.ID)
									{
										FlxTween.tween(spr, {alpha: 0}, 0.4, {
											ease: FlxEase.quadOut,
											onComplete: function(twn:FlxTween)
											{
												spr.kill();
											}
										});
									}
									else
									{
										FlxFlicker.flicker(spr, 1, 0.06, false, false, function(flick:FlxFlicker)
										{
											var daChoice:String = optionShit[curSelected];
			
											switch (daChoice)
											{
												case 'story-mode':
													FlxG.switchState(new StoryMenuState());
												case 'freeplay':
													FlxG.switchState(new FreeplayState());
												case 'options':
													FlxG.switchState(new OptionsMenuState());
											}
										});
									}
								});
						}
					});
				}
			}
		}

		super.update(elapsed);

		/*
		menuItems.forEach(function(spr:FlxSprite)
		{
			spr.screenCenter(X); no
		}); */
	}

	function changeItem(huh:Int = 0)
	{
		curSelected += huh;

		if (curSelected >= menuItems.length)
			curSelected = 0;
		if (curSelected < 0)
			curSelected = menuItems.length - 1;

		menuItems.forEach(function(spr:FlxSprite)
		{
			spr.animation.play('idle');
			spr.offset.y = 0;
			spr.updateHitbox();

			if (spr.ID == curSelected)
			{
				FlxTween.tween(spr,{x:150},0.45,{ease:FlxEase.elasticInOut});
				spr.animation.play('selected');
				camFollow.setPosition(spr.getGraphicMidpoint().x, spr.getGraphicMidpoint().y);
				spr.offset.x = 0.15 * (spr.frameWidth / 2 + 180);
				spr.offset.y = 0.15 * spr.frameHeight;
				FlxG.log.add(spr.frameWidth);
			}
			else
				FlxTween.tween(spr,{x:70},0.45,{ease:FlxEase.elasticInOut});
		});
	}
}
