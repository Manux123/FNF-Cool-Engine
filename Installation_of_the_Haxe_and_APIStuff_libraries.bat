@echo off
title FNF Setup 2.0
echo Make sure you have Haxe and HaxeFlixel installed!
echo Press any key to continue!
pause >nul
title FNF Setup - Installation of libraries
echo Installing haxelib libraries ...
haxelib install hxcpp > nul 
haxelib install lime 7.8.0
haxelib install openfl 9.0.2
haxelib install flixel 4.9.0
haxelib run lime setup flixel
haxelib run lime setup
haxelib install flixel-tools
haxelib install flixel-ui
haxelib install flixel-addons
haxelib install hscript
haxelib install polymod
haxelib install newgrounds
haxelib git linc_luajit https://github.com/AndreiRudenko/linc_luajit
haxelib git discord_rpc https://github.com/Aidan63/linc_discord-rpc
haxelib install hxcpp-debug-server
title FNF Setup
cls
haxelib run flixel-tools setup
cls
echo Make sure you have git installed. You can download it at https://git-scm.com/downloads
echo Press any key to install Discord_RPC
pause >nul
title FNF Setup - Installation of libraries
haxelib git discord_rpc https://github.com/Aidan63/linc_discord-rpc
cls
echo Make sure you have the vs build tools installed. if not please press Y after extention webm is installed

pause >nul
title FNF Setup - Installation of libraries
haxelib git extension-webm https://github.com/GrowtopiaFli/extension-webm
cls
goto UserActions1
       
:UserActions2
title FNF Setup - User action required
set /p menu="Would you like to install Visual Studio Community and components? (Necessary to compile/ 5.5GB) [Y/N]"
       if %menu%==Y goto InstallVSCommunity
       if %menu%==y goto InstallVSCommunity
       if %menu%==N goto SkipVSCommunity
       if %menu%==n goto SkipVSCommunity
       cls


:SkipVSCommunity
cls
title FNF Setup - Success
echo succesfly skipped vs build tools

:UserActions3
title FNF Setup
set /p menu="Do you want to install the library that fixes some transition errors? [Y/N]"
       if %menu%==Y goto FixTransitionBug
       if %menu%==y goto FixTransitionBug
       if %menu%==N goto UserActions2
       if %menu%==n goto UserActions2
       cls

:UserActions3
cls
title FNF Setup 
echo Complete configuration. Press any key to exit.
pause >nul
exit

:FixTransitionBug
title FNF Setup - Installation of libraries
haxelib git flixel-addons https://github.com/HaxeFlixel/flixel-addons
goto UserActions2

:InstallVSCommunity
title FNF Setup - Installing Visual Studio Community
curl -# -O https://download.visualstudio.microsoft.com/download/pr/3105fcfe-e771-41d6-9a1c-fc971e7d03a7/8eb13958dc429a6e6f7e0d6704d43a55f18d02a253608351b6bf6723ffdaf24e/vs_Community.exe
vs_Community.exe --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.Windows10SDK.19041 -p
del vs_Community.exe
goto UserActions3

:ForWindows
title FNF Setup - Installation of libraries
lime rebuild extension-webm windows
lime rebuild extension-webm windows
goto UserActions3
