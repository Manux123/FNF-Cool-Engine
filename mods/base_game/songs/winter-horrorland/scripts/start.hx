function onCountdownStarted()
{
	if (isStoryMode){
		var blackScreen:FlxSprite = new FlxSprite(0, 0).makeGraphic(Std.int(FlxG.width * 2), Std.int(FlxG.height * 2), FlxColor.BLACK);
		add(blackScreen);
		blackScreen.scrollFactor.set();
		camHUD.visible = false;

		new FlxTimer().start(0.1, function(tmr:FlxTimer)
		{
			remove(blackScreen);

			FlxG.sound.play(Paths.sound('Lights_Turn_On'));
			camFollow.y = -2050;
			camFollow.x += 200;
			FlxG.camera.focusOn(camFollow.getPosition());
			FlxG.camera.zoom = 1.5;

			new FlxTimer().start(0.8, function(tmr:FlxTimer)
			{
				camHUD.visible = true;
				remove(blackScreen);
				FlxTween.tween(FlxG.camera, {zoom: defaultCamZoom}, 2.5, {
					ease: FlxEase.quadInOut,
					onComplete: function(twn:FlxTween)
					{
						startCountdown();
					}
				});
			});
		});
	}
	else{
		startCountdown();
	}
}
