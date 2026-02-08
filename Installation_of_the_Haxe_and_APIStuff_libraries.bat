@echo off
title FNF Environment Setup
color 0A

echo ===============================================
echo        FNF / HaxeFlixel Environment Setup
echo ===============================================
echo.
echo This script will install a STABLE and COMPATIBLE
echo HaxeFlixel environment for FNF-based projects.
echo.
echo Make sure the following are already installed:
echo  - Haxe 4.2.5
echo  - Git
echo  - Visual Studio Build Tools (for Windows)
echo.
pause

cls
echo ===============================================
echo Cleaning conflicting libraries...
echo ===============================================

haxelib remove flixel-ui >nul 2>&1
haxelib remove flixel >nul 2>&1
haxelib remove openfl >nul 2>&1
haxelib remove lime >nul 2>&1

cls
echo ===============================================
echo Installing core dependencies...
echo ===============================================

haxelib install hxcpp >nul
haxelib install lime 8.0.2
haxelib install openfl 9.2.2

haxelib set lime 8.0.2
haxelib set openfl 9.2.2

cls
echo ===============================================
echo Installing HaxeFlixel...
echo ===============================================

haxelib install flixel 5.3.1
haxelib set flixel 5.3.1

haxelib install flixel-addons 3.2.2
haxelib install flixel-ui 2.6.1
haxelib install flixel-tools 1.5.1

cls
echo ===============================================
echo Installing additional libraries...
echo ===============================================

haxelib install actuate
haxelib install hscript
haxelib install hxcpp-debug-server

cls
echo ===============================================
echo Setting up Lime and Flixel...
echo ===============================================

haxelib run lime setup windows
haxelib run lime setup flixel
haxelib run flixel-tools setup

cls
echo ===============================================
echo Installing Discord RPC...
echo ===============================================

haxelib git discord_rpc https://github.com/Aidan63/linc_discord-rpc

echo ===============================================
echo Re-locking Lime and OpenFL versions...
echo ===============================================

haxelib set lime 8.0.2
haxelib set openfl 9.2.2
haxelib set flixel 5.3.1
haxelib set flixel-ui 2.6.1
haxelib set flixel-addons 3.2.2

cls
echo ===============================================
echo Setup completed successfully!
echo ===============================================
echo.
echo Installed versions:
echo  - Lime:        8.0.2
echo  - OpenFL:      9.2.2
echo  - Flixel:      5.3.1
echo  - Flixel-UI:   2.5.0
echo  - Flixel-Addons: 3.0.2
echo.
echo You are now ready to compile your project.
echo.
pause
exit
