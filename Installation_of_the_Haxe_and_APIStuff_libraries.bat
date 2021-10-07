@echo off
title FNF Setup 2.0
echo Make sure you have Haxe 4.1.5 and HaxeFlixel installed!
echo Press any key to continue!
pause >nul
title FNF Setup - Installation of libraries
echo Installing haxelib libraries ...
haxelib install lime 7.9.0
haxelib install openfl 9.0.2
haxelib install flixel 4.8.1
haxelib install flixel-addons 2.9.0
haxelib install flixel-ui 2.3.3
haxelib install openfl-webm
haxelib install actuate
haxelib install hscript 2.4.0
haxelib install newgrounds 1.1.4
haxelib run lime setup
haxelib install flixel-tools 1.4.4
title FNF Setup
cls
haxelib run flixel-tools setup
cls
echo Make sure you have git installed. You can download it at https://git-scm.com/downloads
echo Presiona cualquier tecla para instalar PolyMod.
pause >nul
title FNF Setup - Installation of libraries
haxelib remove polymod
haxelib git polymod https://github.com/Manux123/Polymod
cls
echo Press any key to install Discord_RPC
pause >nul
title FNF Setup - Installation of libraries
haxelib git discord_rpc https://github.com/Aidan63/linc_discord-rpc
cls
echo Make sure you have the vs build tools installed. You can download it at https://visualstudio.microsoft.com/es/downloads/
echo Press any key to install the webm-extension.
pause >nul
title FNF Setup - Installation of libraries
haxelib git extension-webm https://github.com/GrowtopiaFli/extension-webm
cls
goto UserActions1

:UserActions1
title FNF Setup
set /p menu="Do you want to install the library that fixes some transition errors? [Y/N]"
       if %menu%==Y goto FixTransitionBug
       if %menu%==y goto FixTransitionBug
       if %menu%==N goto UserActions2
       if %menu%==n goto UserActions2
       cls

:UserActions2
cls
title FNF Setup
set /p menu2="To rebuild the webm extension according to your system, Press W for Windows, L for Linux, or M for Mac [W/L/M]"
       if %menu2%==W goto ForWindows
       if %menu2%==w goto ForWindows
       if %menu2%==L goto ForLinux
       if %menu2%==l goto ForLinux
       if %menu2%==M goto ForMac
       if %menu2%==m goto ForMac
       cls

:UserActions3
cls
title FNF Setup
set /p menu3="Do you want it to create the APIStuff.hx file automatically? [Y/N]"
       if %menu3%==Y goto APIStuffYes
       if %menu3%==y goto APIStuffYes
       if %menu3%==N goto APIStuffNo
       if %menu3%==n goto APIStuffNo
       cls


       
:APIStuffYes
rem Stores the APIStuff.hx contents automatically
cd source
(
echo package;
echo class APIStuff
echo {
echo         public static var API:String = "";
echo         public static var EncKey:String = "";
echo }
)>APIStuff.hx
cd ..
cls
title FNF Setup 
echo Complete configuration. Press any key to exit.
pause >nul
exit

:APIStuffNo
cls
title FNF Setup
echo Complete configuration. Press any key to exit.
pause >nul
exit

:FixTransitionBug
title FNF Setup - Installation of libraries
haxelib git flixel-addons https://github.com/HaxeFlixel/flixel-addons
goto UserActions2

:ForWindows
title FNF Setup - Installation of libraries
lime rebuild extension-webm windows
lime rebuild extension-webm windows
goto UserActions3

:ForLinux
title FNF Setup - Installation of libraries
lime rebuild extension-webm linux
lime rebuild extension-webm linux
goto UserActions3

:ForMac
title FNF Setup - Installation of libraries
lime rebuild extension-webm mac
lime rebuild extension-webm mac
goto UserActions3
