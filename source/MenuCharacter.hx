package;

import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;

class MenuCharacter extends FlxSprite
{
	public var character:String;

	public function new(x:Float, character:String = 'bf')
	{
		super(x);

		changeCharacter(character);
	}

	public function changeCharacter(?character:String = 'bf') {
		if(character == this.character) return;
	
		this.character = character;
		antialiasing = true;

		switch(character) {
			case 'bf':
				frames = Paths.getSparrowAtlas('storymenu/campaign_menu/Menu_BF');
				animation.addByPrefix('idle', "M BF Idle", 24);
				animation.addByPrefix('confirm', 'M bf HEY', 24, false);

			case 'gf':
				frames = Paths.getSparrowAtlas('storymenu/campaign_menu/Menu_GF');
				animation.addByPrefix('idle', "M GF Idle", 24);

			case 'dad':
				frames = Paths.getSparrowAtlas('storymenu/campaign_menu/Menu_Dad');
				animation.addByPrefix('idle', "M Dad Idle", 24);

			case 'spooky':
				frames = Paths.getSparrowAtlas('storymenu/campaign_menu/Menu_Spooky_Kids');
				animation.addByPrefix('idle', "M Spooky Kids Idle", 24);

			case 'pico':
				frames = Paths.getSparrowAtlas('storymenu/campaign_menu/Menu_Pico');
				animation.addByPrefix('idle', "M Pico Idle", 24);

			case 'mom':
				frames = Paths.getSparrowAtlas('storymenu/campaign_menu/Menu_Mom');
				animation.addByPrefix('idle', "M Mom Idle", 24);

			case 'parents-christmas':
				frames = Paths.getSparrowAtlas('storymenu/campaign_menu/Menu_Parents');
				animation.addByPrefix('idle', "M Parents Idle", 24);

			case 'senpai':
				frames = Paths.getSparrowAtlas('storymenu/campaign_menu/Menu_Senpai');
				animation.addByPrefix('idle', "M Senpai Idle", 24);
			
			case '':
				frames = Paths.getSparrowAtlas('storymenu/campaign_menu/Menu_');
				animation.addByPrefix('idle', "M Senpai Idle", 24);
		}
		animation.play('idle');
		updateHitbox();

		switch(character) {
			case 'bf':
				offset.set(15, -40);

			case 'gf':
				offset.set(0, -25);

			case 'spooky':
				offset.set(0, -80);

			case 'pico':
				offset.set(0, -120);

			case 'mom':
				offset.set(0, 10);

			case 'parents-christmas':
				offset.set(110, 10);

			case 'senpai':
				offset.set(60, -70);

			case '':
				offset.set(60, -70);
		}
	}
}
