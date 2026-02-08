package extensions;

#if windows
@:buildXml('
<target id="haxe">
    <lib name="dwmapi.lib" if="windows" />
</target>
')
@:headerCode('
#include <Windows.h>
#include <cstdio>
#include <iostream>
#include <tchar.h>
#include <dwmapi.h>
#include <winuser.h>
#include <vector>
#include <string>
#undef TRUE
#undef FALSE
#undef NO_ERROR
')
#elseif linux
@:headerCode("#include <stdio.h>")
#end
class InitAPI
{

	@:functionCode('
	    auto color = RGB(r, g, b);
        HWND window = GetActiveWindow();
        if (S_OK != DwmSetWindowAttribute(window, 35, &color, sizeof(COLORREF))) {
            DwmSetWindowAttribute(window, 35, &color, sizeof(COLORREF));
        }
        UpdateWindow(window);
    ')
	@:noCompletion
    public static function setWindowBorderColor(r:Int, g:Int, b:Int) 
    {
    }
}