package extensions;

// ────────────────────────────────────────────────────────────────────────────
// InitAPI — native window-border color API
//
// Windows : uses DWM (dwmapi) to tint the window border colour.
// macOS   : no native equivalent; the function is a safe no-op.
// Linux   : no native equivalent; the function is a safe no-op.
// ────────────────────────────────────────────────────────────────────────────

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
class InitAPI
{
    /**
     * Changes the window title-bar / border accent colour using DWM.
     * Only has a visible effect on Windows 11 (22000+).
     */
    @:functionCode('
        auto color = RGB(r, g, b);
        HWND window = GetActiveWindow();
        if (S_OK != DwmSetWindowAttribute(window, 35, &color, sizeof(COLORREF))) {
            DwmSetWindowAttribute(window, 35, &color, sizeof(COLORREF));
        }
        UpdateWindow(window);
    ')
    @:noCompletion
    public static function setWindowBorderColor(r:Int, g:Int, b:Int):Void {}
}

#else

// ── Non-Windows stub ─────────────────────────────────────────────────────────
// macOS and Linux do not expose a public API for tinting the window border,
// so we simply provide an empty implementation so the rest of the code
// compiles without changes.
class InitAPI
{
    public static inline function setWindowBorderColor(r:Int, g:Int, b:Int):Void
    {
        // No-op on macOS / Linux
    }
}

#end
