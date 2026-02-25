package funkin.menus;

#if desktop
import data.Discord.DiscordClient;
#end
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.addons.transition.FlxTransitionableState;
import funkin.transitions.StateTransition;
import flixel.effects.FlxFlicker;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxGroup.FlxTypedGroup;
import funkin.transitions.StickerTransition;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import lime.app.Application;
import funkin.menus.OptionsMenuState;
import openfl.display.BitmapData as Bitmap;
import funkin.debug.AnimationDebug;
import funkin.debug.StageEditor;
import funkin.debug.DialogueEditor;
import funkin.debug.charting.ChartingState;
import data.PlayerSettings;
import funkin.scripting.StateScriptHandler;

using StringTools;

class MainMenuState extends funkin.states.MusicBeatState
{
	var curSelected:Int = 0;

	var menuItems:FlxTypedGroup<FlxSprite>;

	var optionShit:Array<String> = ['story-mode', 'freeplay' #if !switch, 'options', 'donate' #end];

	var canSnap:Array<Float> = [];

	public static var musicFreakyisPlaying:Bool = false;

	var camFollow:FlxObject;
	var newInput:Bool = true;
	var menuItem:FlxSprite;

	public static var firstStart:Bool = true;

	public static var finishedFunnyMove:Bool = false;

	override function create()
	{
		FlxG.mouse.visible = false;
		// LOAD CUZ THIS SHIT DONT DO IT SOME IN THE CACHESTATE.HX FUCK
		PlayerSettings.player1.controls.loadKeyBinds();

		if (StickerTransition.enabled){
			transIn = null;
			transOut = null;
		}

		#if desktop
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menu", null);
		#end

		transIn = FlxTransitionableState.defaultTransIn;
		transOut = FlxTransitionableState.defaultTransOut;

		#if !MAINMENU
		// TitleState already started freakyMenu - only play it here if somehow missing
		if (FlxG.sound.music == null || !FlxG.sound.music.playing)
		{
			if (FreeplayState.vocals == null)
				FlxG.sound.playMusic(Paths.music('freakyMenu'), 0.7);
		}
		musicFreakyisPlaying = true;
		#end

		persistentUpdate = persistentDraw = true;

		var bg:FlxSprite = new FlxSprite(-80).loadGraphic(Bitmap.fromFile(Paths.image('menu/menuBG')));
		bg.color = 0xFF3E3E3E;
		bg.scrollFactor.x = 0;
		bg.scrollFactor.y = 0.18;
		bg.screenCenter();
		bg.antialiasing = FlxG.save.data.antialiasing;
		add(bg);

		camFollow = new FlxObject(0, 0, 1, 1);
		add(camFollow);

		menuItems = new FlxTypedGroup<FlxSprite>();
		add(menuItems);

		#if HSCRIPT_ALLOWED
		StateScriptHandler.init();
		StateScriptHandler.loadStateScripts('MainMenuState', this);
		StateScriptHandler.callOnScripts('onCreate', []);

		// Obtener items custom
		var customItems = StateScriptHandler.callOnScriptsReturn('getCustomMenuItems', [], null);
		if (customItems != null && Std.isOfType(customItems, Array))
		{
			var itemsArray:Array<String> = cast customItems;
			for (item in itemsArray)
				optionShit.push(item);
		}
		#end

		for (i in 0...optionShit.length)
		{
			var offset:Float = 108 - (Math.max(optionShit.length, 4) - 4) * 80;
			var menuItem:FlxSprite = new FlxSprite(70, (i * 140) + offset);
			menuItem.frames = Paths.getSparrowAtlas('menu/menu_' + optionShit[i]);
			menuItem.animation.addByPrefix('idle', optionShit[i] + " basic", 24);
			menuItem.animation.addByPrefix('selected', optionShit[i] + " white", 24);
			menuItem.animation.play('idle');
			menuItem.ID = i;
			// menuItem.screenCenter(X);
			menuItems.add(menuItem);
			var scr:Float = (optionShit.length - 4) * 0.135;
			if (optionShit.length < 6)
				scr = 0;
			menuItem.scrollFactor.set(0, scr);
			menuItem.antialiasing = FlxG.save.data.antialiasing;
			menuItem.setGraphicSize(Std.int(menuItem.width * 0.8));
			menuItem.updateHitbox();
		}

		var modShit:FlxText = new FlxText(5, FlxG.height - 19, 0, "Press Shift - Menu Mods", 12);
		modShit.scrollFactor.set();
		modShit.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		modShit.y -= 40;
		add(modShit);

		var versionShit:FlxText = new FlxText(5, FlxG.height - 19, 0, "Friday Night Funkin v0.2.7.1", 12);
		versionShit.scrollFactor.set();
		versionShit.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(versionShit);

		var versionShit2:FlxText = new FlxText(5, FlxG.height - 19, 0, 'Cool Engine - V${Application.current.meta.get('version')}', 12);
		versionShit2.scrollFactor.set();
		versionShit2.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		versionShit2.y -= 20;
		add(versionShit2);

		// Etiqueta del mod activo — solo visible si hay uno cargado
		final _activeMod = mods.ModManager.activeMod;
		if (_activeMod != null)
		{
			final _modInfo  = mods.ModManager.getInfo(_activeMod);
			final _modLabel = _modInfo != null ? _modInfo.name : _activeMod;
			final _modVer   = _modInfo != null ? ' v${_modInfo.version}' : '';
			final _modColor:flixel.util.FlxColor = _modInfo != null
				? new flixel.util.FlxColor(_modInfo.color | 0xFF000000)
				: FlxColor.fromRGB(255, 170, 0);

			var modActiveText:FlxText = new FlxText(FlxG.width - 270, FlxG.height - 19, 0, '\u25B6 MOD: $_modLabel$_modVer', 16);
			modActiveText.scrollFactor.set();
			modActiveText.setFormat("VCR OSD Mono", 16, _modColor, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			add(modActiveText);
		}

		changeItem();

		#if mobileC
		addVirtualPad(UP_DOWN, A_B);
		#end

		StickerTransition.clearStickers();

		#if HSCRIPT_ALLOWED
		StateScriptHandler.callOnScripts('postCreate', []);
		#end

		super.create();
	}

	var selectedSomethin:Bool = false;

	/** Developer Mode — da acceso a los editores (Chart, Stage, Dialogue, AnimDebug). */
	public static var developerMode(get, set):Bool;
	static inline function get_developerMode():Bool
		return FlxG.save.data.developerMode == true;
	static inline function set_developerMode(v:Bool):Bool
	{
		FlxG.save.data.developerMode = v;
		FlxG.save.flush();
		return v;
	}

	override function update(elapsed:Float)
	{
		#if HSCRIPT_ALLOWED
		StateScriptHandler.callOnScripts('onUpdate', [elapsed]);
		#end

		#if !MAINMENU
		if (FlxG.sound.music != null && FlxG.sound.music.volume < 0.8)
		{
			FlxG.sound.music.volume += 0.5 * FlxG.elapsed;
		}
		#end

		// ── Teclas de editor (solo en developer mode) ──────────────────────────
		if (developerMode)
		{
			if (FlxG.keys.justPressed.ONE)
				StateTransition.switchState(new AnimationDebug('bf'));
		}

		// ── Mod Selector ────────────────────────────────────────────────────────
		if (FlxG.keys.justPressed.SHIFT)
			StateTransition.switchState(new ModSelectorState());

		if (!selectedSomethin)
		{
			if (controls.UP_P)
			{
				FlxG.sound.play(Paths.sound('menus/scrollMenu'));
				changeItem(-1);
			}

			if (controls.DOWN_P)
			{
				FlxG.sound.play(Paths.sound('menus/scrollMenu'));
				changeItem(1);
			}

			if (controls.BACK)
			{
				StateTransition.switchState(new TitleState());
			}

			if (controls.ACCEPT)
			{
				#if HSCRIPT_ALLOWED
				var cancelled = StateScriptHandler.callOnScriptsReturn('onAccept', [], false);
				if (cancelled)
				{
					super.update(elapsed);
					return;
				}

				StateScriptHandler.callOnScripts('onMenuItemSelected', [optionShit[curSelected], curSelected]);
				#end

				if (optionShit[curSelected] == 'donate')
				{
					#if linux
					Sys.command('/usr/bin/xdg-open', [
						"https://www.kickstarter.com/projects/funkin/friday-night-funkin-the-full-ass-game",
						"&"
					]);
					#else
					FlxG.openURL('https://www.kickstarter.com/projects/funkin/friday-night-funkin-the-full-ass-game');
					#end
				}
				else
				{
					// FlxTween.tween(menuItem, {x: menuItem.x + 200}, 0.6, {ease: FlxEase.quadInOut, type: ONESHOT});
					selectedSomethin = true;
					FlxG.sound.play(Paths.sound('menus/confirmMenu'));
					if (FlxG.save.data.flashing)
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
												StateTransition.switchState(new StoryMenuState());
											case 'freeplay':
												StateTransition.switchState(new FreeplayState());
											case 'options':
												StateTransition.switchState(new OptionsMenuState());
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

		#if HSCRIPT_ALLOWED
		StateScriptHandler.callOnScripts('onUpdatePost', [elapsed]);
		#end
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
				FlxTween.tween(spr, {x: 150}, 0.45, {ease: FlxEase.elasticInOut});
				spr.animation.play('selected');
				camFollow.setPosition(spr.getGraphicMidpoint().x, spr.getGraphicMidpoint().y);
				spr.offset.x = 0.15 * (spr.frameWidth / 2 + 180);
				spr.offset.y = 0.15 * spr.frameHeight;
				FlxG.log.add(spr.frameWidth);
			}
			else
				FlxTween.tween(spr, {x: 70}, 0.45, {ease: FlxEase.elasticInOut});
		});

		#if HSCRIPT_ALLOWED
		StateScriptHandler.callOnScripts('onSelectionChanged', [curSelected]);
		#end
	}

	override function destroy()
	{
		#if HSCRIPT_ALLOWED
		StateScriptHandler.callOnScripts('onDestroy', []);
		StateScriptHandler.clearStateScripts();
		#end

		super.destroy();
	}
}
