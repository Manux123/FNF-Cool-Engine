@echo off
title FNF Setup 2.0
echo Asegurate tener Haxe 4.1.5 y HaxeFlixel instalado!
echo Presiona cualquier tecla para continuar!
pause >nul
title FNF Setup - Instalando librerias
echo Instalando librerias haxelib...
haxelib install lime 7.9.0
haxelib install openfl 9.0.2
haxelib install flixel 4.8.1
haxelib install flixel-addons 2.9.0
haxelib install flixel-ui 2.3.3
haxelib install hscript 2.4.0
haxelib install newgrounds 1.1.4
haxelib run lime setup
haxelib install flixel-tools 1.4.4
title FNF Setup
cls
haxelib run flixel-tools setup
cls
echo Asegurate tener git instalado. Puedes descargarlo en https://git-scm.com/downloads
echo Presiona cualquier tecla para instalar PolyMod.
pause >nul
title FNF Setup - Instalando librerias
haxelib git polymod https://github.com/larsiusprime/polymod.git
cls
echo Presiona cualquier tecla para instalar Discord_RPC
pause >nul
title FNF Setup - Instalando librerias
haxelib git discord_rpc https://github.com/Aidan63/linc_discord-rpc
cls
goto UserActions1

:UserActions1
title FNF Setup
set /p menu="Desea instalar la libreria que arregla algunos bugs de transiciones? [Y/N]"
       if %menu%==Y goto FixTransitionBug
       if %menu%==y goto FixTransitionBug
       if %menu%==N goto UserActions2
       if %menu%==n goto UserActions2
       cls

:UserActions2
cls
title FNF Setup
set /p menu2="Quieres que yo cree el archivo APIStuff.hx de forma automatica? [Y/N]"
       if %menu2%==Y goto APIStuffYes
       if %menu2%==y goto APIStuffYes
       if %menu2%==N goto APIStuffNo
       if %menu2%==n goto APIStuffNo
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
echo Setup completo. Presione cualquier tecla para salir.
pause >nul
exit

:APIStuffNo
cls
title FNF Setup
echo Setup completo. Presione cualquier tecla para salir.
pause >nul
exit

:FixTransitionBug
title FNF Setup - Instalando librerias
haxelib git flixel-addons https://github.com/HaxeFlixel/flixel-addons
goto UserActions2
