# [Cool Engine REBORN (65%)](https://github.com/Manux123/FNF-Cool-Engine)

**FNF': Cool Engine is a modification of the original FNF' source code the mod includes new Options and better Graphics!!**
----------------------------------------------

![](/art/cool-logo-animated.gif)
----------------------------------------------

## The Cool Engine Team Credits
- [Manux (me)](https://x.com/ManuxAc) - Programmer Friday Night Funkin: Cool Engine
- [Jloor](https://twitter.com/GamerJloor) - Programmer Friday Night Funkin: Cool Engine
- [Chasetodie](https://x.com/Chasetodie10) - Programmer Friday Night Funkin: Cool Engine
- [MrClogsworthYT](https://youtube.com/c/MrClogsworthYT) - Programmer and composer Friday Night Funkin: Cool Engine
- [Overcharged Dev](https://www.youtube.com/channel/UCkcscIIXyUsfj2DsnNDWQbg/) - Programmer Friday Night Funkin: Cool Engine
- [Kass.wav](https://x.com/SoyJulian_XP) and [Zero Artist](https://x.com/zero_artist24) - Artists Friday Night Funkin: Cool Engine

## FNF
- [Kawaisprite](https://twitter.com/kawaisprite) - Musician of fnf
- [ninjamuffin99](https://twitter.com/ninja_muffin99) - Programmer of fnf
- [PhantomArcade3K](https://twitter.com/phantomarcade3k) - Animator of of fnf
- [Evilsk8r](https://twitter.com/evilsk8r)  - Artist of fnf

## mp4 stuff
- [PolybiusProxy](https://twitter.com/polybiusproxy) - MP4 Extension Loader

# Building
THESE INSTRUCTIONS ARE FOR COMPILING THE GAME'S SOURCE CODE!!!
IF YOU JUST WANT TO PLAY AND NOT EDIT THE CODE CLICK [HERE](https://gamebanana.com/mods/326036)!!!

### Installing the Required Programs

First, you need to install Haxe and HaxeFlixel. I'm too lazy to write and keep updated with that setup (which is pretty simple). 
1. [Install Haxe](https://haxe.org/download/)
2. [Install HaxeFlixel](https://haxeflixel.com/documentation/install-haxeflixel/) after downloading Haxe (This is a required step and compilation will fail if it isn't installed!)

You'll also need to install a couple things that involve Gits. To do this, you need to do a few things first.
1. Download [git-scm](https://git-scm.com/downloads). Works for Windows, and Mac, just select your build. (Linux users can install the git package via their respective package manager.)
2. Run [this](https://github.com/Manux123/FNF-Cool-Engine/blob/master/Installation_of_the_Haxe_and_APIStuff_libraries.bat), and everything should be installed automatically
if it doesnt use the errors to download the left libraries

You should have everything ready for compiling the game! Follow the guide below to continue!

NOTE: If you see any messages relating to deprecated packages, ignore them. They're just warnings that don't affect compiling

The -debug flag is completely optional.
Applying it will make a folder called `export/debug/[TARGET]/bin` instead of `export/release/[TARGET]/bin`

Once you have all those installed, it's pretty easy to compile the game. You just need to run `lime build html5 -minify` in the root of the project to build and run the HTML5 version command prompt navigation guide can be found [here](https://ninjamuffin99.newgrounds.com/news/post/1090480).
To run it from your desktop (Windows, Mac, Linux) it can be a bit more involved. For Linux, you only need to open a terminal in the project directory and run `lime test linux -debug` and then run the executable file in export/release/linux/bin. For Windows, you need to install Visual Studio Community 2019. While installing VSC, don't click on any of the options to install workloads. Instead, go to the individual components tab and choose the following:
* MSVC v142 - VS 2019 C++ x64/x86 build tools
* Windows SDK (10.0.17763.0)

Once that is done you can open up a command line in the project's directory and run `lime test windows -debug`. Once that command finishes (it takes forever even on a higher end PC), you can run FNF from the .exe file under export\release\windows\bin

As for Mac, `lime test mac -debug` will work,
----------------------------------------------

ADDITIONS IN 0.4.1

- REWRITTED ALL
- Stickers!
- Freeplay Editor
- More Softcoding
- HUD for Script
- New Chart Editor
- New Character Editor
- Mods Support ZIP, RAR, Folder
- More Optimization
- Better Options

----------------------------------------------
Thanks for checking out our Engine! Do you have any question? Go to the [discussions](https://github.com/Manux123/FNF-Cool-Engine/discussions) tab!
