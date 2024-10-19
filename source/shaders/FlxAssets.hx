package shaders;

import openfl.Assets;
import openfl.utils.ByteArray;

@:keep @:bitmap("menu/logo.png")
class GraphicLogo extends BitmapData {}

@:keep @:bitmap("titlestate/virtual-input.txt")
class VirtualInputData extends #if (lime_legacy || nme) ByteArray #else ByteArrayData #end {}

typedef FlxShader =
    #if (openfl_legacy || nme)
    Dynamic;
    #elseif FLX_DRAW_QUADS
    flixel.graphics.title.FlxGraphicsShader;
    #else
    openfl.display.Shader;
    #end
#end