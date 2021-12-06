/*
SETUP:
To add your game's keys, you will need to make a file in the source folder named GJKeys.hx (filepath: ../source/GJKeys.hx)
In this file, you will need to add the GJKeys class with two public static variables, id:Int and key:String
Example:
package;
class GJKeys
{
    public static var id:Int = 	0; // Put your game's ID here
    public static var key:String = ""; // Put your game's private API key here
}
You can find your game's API key and ID code within the game page's settngs under the game API tab.
Hope this helps! -tenta
USAGE:
To start up the API, the two commands you want to use will be:
GameJoltAPI.connect();
GameJoltAPI.authDaUser(FlxG.save.data.gjUser, FlxG.save.data.gjToken);
*You can't use the API until this step is done!*
FlxG.save.data.gjUser & gjToken are the save values for the username and token, used for logging in once someone already logs in.
Save values (gjUser & gjToken) are deleted when the player signs out with GameJoltAPI.deAuthDaUser(); and are replaced with "".
To open up the login menu, switch the state to GameJoltLogin.
Exiting the login menu will throw you back to Main Menu State. You can change this in the GameJoltLogin class.
The session will automatically start on login and will be pinged every 30 seconds.
If it isn't pinged within 120 seconds, the session automatically ends from GameJolt's side.
Thanks GameJolt, makes my life much easier! Not sarcasm!
You can give a trophy by using:
GameJoltAPI.getTrophy(trophyID);
Each trophy has an ID attached to it. Use that to give a trophy. It could be used for something like a week clear...
Hope this helps! -tenta
And yes, I run Mac. A fate worse than death.
*/
package states;

import flixel.ui.FlxButton;
import flixel.text.FlxText;
import flixel.addons.api.FlxGameJolt as GJApi;
import flixel.FlxSubState;
import flixel.addons.ui.FlxUIInputText;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.util.FlxColor;
import flixel.FlxG;
import lime.system.System;
import flixel.util.FlxTimer;
import flixel.FlxSprite;
import flixel.ui.FlxBar;

class GameJoltAPI // Connects to flixel-addons
{
    public static var userLogin:Bool = false;
    public static var totalTrophies:Float = GJApi.TROPHIES_ACHIEVED + GJApi.TROPHIES_MISSING;
    public static function getUserInfo(username:Bool = true):String /* Grabs user data and returns as a string, true for Username, false for Token */
    {
        if(username)return GJApi.username;
        else return GJApi.usertoken;
    }
    public static function getStatus():Bool /* Checks to see if the user has signed in */
    {
        return (userLogin ? true : false);
    }
    public static function connect() /* Sets the game ID and game key */
    {
        trace("Grabbing API keys...");
        GJApi.init(Std.int(GJKeys.id), Std.string(GJKeys.key), false);
    }

    public static function authDaUser(in1, in2, ?login:Bool = false) /* Logs the user in */
    {
        GJApi.authUser(in1, in2, function(v:Bool)
            {
                if(v)
                    {
                        trace("User authenticated!");
                        FlxG.save.data.gjUser = in1;
                        FlxG.save.data.gjToken = in2;
                        FlxG.save.flush();
                        userLogin = true;
                        startSession();
                        if(login)
                        {
                            FlxG.switchState(new GameJoltLogin());
                        }
                    }
                else 
                    {
                        trace("User login failure!");
                    }
            });
    }
    public static function deAuthDaUser() /* Logs the user out and closes the game */
    {
        closeSession();
        userLogin = false;
        FlxG.save.data.gjUser = "";
        FlxG.save.data.gjToken = "";
        FlxG.save.flush();
        trace("Logged out!");
        GameJoltLogin.restart();
    }

    public static function getTrophy(trophyID:Int) /* Awards a trophy to the user! */
    {
        if(userLogin)
        {
            GJApi.addTrophy(trophyID, function(){trace("Unlocked a trophy with an ID of "+trophyID);});
        }
    }
    public static function startSession() /*Starts the session */
    {
        GJApi.openSession(function()
            {
                trace("Session started!");
                new FlxTimer().start(20, function(tmr:FlxTimer){pingSession();}, 0);
            });
    }
    public static function pingSession() /* Pings GameJolt to show the session is still active */
    {
        GJApi.pingSession(true, function(){trace("Ping!");});
    }
    public static function closeSession() /* Closes the session, used for signing out */
    {
        GJApi.closeSession(function(){trace('Closed out the session');});
    }
}

class GameJoltInfo extends FlxSubState
{
    public static var version:String = "1.0.1 beta";
}

class GameJoltLogin extends MusicBeatSubstate
{
    var gamejoltText:FlxText;
    var loginTexts:FlxTypedGroup<FlxText>;
    var loginBoxes:FlxTypedGroup<FlxUIInputText>;
    var loginButtons:FlxTypedGroup<FlxButton>;
    var usernameText:FlxText;
    var tokenText:FlxText;
    var usernameBox:FlxUIInputText;
    var tokenBox:FlxUIInputText;
    var signInBox:FlxButton;
    var helpBox:FlxButton;
    var logOutBox:FlxButton;
    var cancelBox:FlxButton;
    var profileIcon:FlxSprite;
    var username:FlxText;
    var gamename:FlxText;
    var trophy:FlxBar;
    var trophyText:FlxText;
    var missTrophyText:FlxText;
    var charBop:FlxSprite;
    var icon:FlxSprite;

    var baseX:Int = 200;

    override function create()
    {
        trace(GJApi.initialized);
        FlxG.mouse.visible = true;

        var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat', 'preload'));
		bg.setGraphicSize(FlxG.width);
		bg.antialiasing = true;
		bg.updateHitbox();
		bg.screenCenter();
		bg.scrollFactor.set();
		bg.alpha = 0.25;
		add(bg);

        charBop = new FlxSprite(100, 250);
		charBop.frames = Paths.getSparrowAtlas('characters/sixsheet', 'shared', false);
		charBop.animation.addByPrefix('idle', 'BF idle dance', 24, false);
		charBop.setGraphicSize(Std.int(charBop.width * 1.6));
		charBop.antialiasing = true;
        charBop.flipX = true;
		add(charBop);

        gamejoltText = new FlxText(0, 25, 0, "Sign into your GameJolt account", 16);
        gamejoltText.screenCenter(X);
        gamejoltText.x += baseX;
        gamejoltText.color = FlxColor.fromRGB(84,155,149);
        gamejoltText.font = Paths.font('menu.ttf');
        add(gamejoltText);

        icon = new FlxSprite(0, gamejoltText.y + 260).loadGraphic(Paths.image('gamejolt', 'preload'));
        icon.x = gamejoltText.getGraphicMidpoint().x - (icon.width / 5);
        trace(icon.x);
        icon.setGraphicSize(200, 200);
		icon.antialiasing = true;
		icon.updateHitbox();
		icon.scrollFactor.set();
        if (GameJoltAPI.getStatus())
		    add(icon);

        loginTexts = new FlxTypedGroup<FlxText>(2);
        add(loginTexts);

        usernameText = new FlxText(0, 125, 300, "Username:", 30);

        tokenText = new FlxText(0, 225, 300, "Token:", 30);

        loginTexts.add(usernameText);
        loginTexts.add(tokenText);
        loginTexts.forEach(function(item:FlxText){
            item.screenCenter(X);
            item.x += baseX;
            item.font = Paths.font('menu.ttf');
        });

        loginBoxes = new FlxTypedGroup<FlxUIInputText>(2);
        add(loginBoxes);

        usernameBox = new FlxUIInputText(0, 175, 300, null, 32, FlxColor.BLACK, FlxColor.GRAY);
        tokenBox = new FlxUIInputText(0, 275, 300, null, 32, FlxColor.BLACK, FlxColor.GRAY);

        loginBoxes.add(usernameBox);
        loginBoxes.add(tokenBox);
        loginBoxes.forEach(function(item:FlxUIInputText){
            item.screenCenter(X);
            item.x += baseX;
        });

        if(GameJoltAPI.getStatus())
        {
            remove(loginTexts);
            remove(loginBoxes);
        }

        loginButtons = new FlxTypedGroup<FlxButton>(3);
        add(loginButtons);

        signInBox = new FlxButton(0, 450, "Sign In", function()
        {
            trace(usernameBox.text);
            trace(tokenBox.text);
            GameJoltAPI.authDaUser(usernameBox.text,tokenBox.text,true);
        });

        helpBox = new FlxButton(0, 550, "GameJolt Token", function()
        {
            MusicBeatState.fancyOpenURL('https://www.youtube.com/watch?v=T5-x7kAGGnE');
        });
        helpBox.color = FlxColor.fromRGB(84,155,149);

        logOutBox = new FlxButton(0, 650, "Log Out & Restart", function()
        {
            GameJoltAPI.deAuthDaUser();
        });
        logOutBox.color = FlxColor.fromRGB(255,134,61);

        cancelBox = new FlxButton(0,650, "Not Right Now", function()
        {
            FlxG.sound.play(Paths.sound('confirmMenu'), 0.7);
            FlxG.switchState(new MainMenuState());
        });

        if(!GameJoltAPI.getStatus())
        {
            loginButtons.add(signInBox);
            loginButtons.add(helpBox);
        }
        else
        {
            cancelBox.y = 550;
            cancelBox.text = "Continue";
            loginButtons.add(logOutBox);
        }
        loginButtons.add(cancelBox);

        loginButtons.forEach(function(item:FlxButton){
            item.screenCenter(X);
            item.setGraphicSize(Std.int(item.width) * 3);
            item.x += baseX;
        });

        if(GameJoltAPI.getStatus())
        {
            username = new FlxText(0, 150, 0, "Signed in as:\n" + GameJoltAPI.getUserInfo(true), 40);
            username.alignment = CENTER;
            username.screenCenter(X);
            username.x += baseX;
            username.font = Paths.font('menu.ttf');
            add(username);
        }
    }

    override function update(elapsed:Float)
    {
        if (FlxG.sound.music != null)
            Conductor.songPosition = FlxG.sound.music.time;

        if (FlxG.keys.justPressed.ESCAPE)
        {
            FlxG.mouse.visible = false;
            FlxG.switchState(new MainMenuState());
        }

        if (FlxG.mouse.overlaps(icon))
        {
            if (FlxG.mouse.justPressed && GameJoltAPI.getStatus())
            {
                MusicBeatState.fancyOpenURL('https://gamejolt.com');
            }
        }

        super.update(elapsed);
    }

    override function beatHit()
    {
        super.beatHit();
        charBop.animation.play('idle', true);
    }

    public static function restart()
    {
        var os = Sys.systemName();
        var args = "Test.hx";
        var app = "";
        var workingdir = Sys.getCwd();

        FlxG.log.add(app);

        app = Sys.programPath();

        // Launch application:
        var result = systools.win.Tools.createProcess(app // app. path
            , args // app. args
            , workingdir // app. working directory
            , false // do not hide the window
            , false // do not wait for the application to terminate
        );
        // Show result:
        if (result == 0)
        {
            FlxG.log.add('SUS');
            System.exit(1337);
          //SUS
        }
        else
            throw "Failed to restart bich";
    }
}
