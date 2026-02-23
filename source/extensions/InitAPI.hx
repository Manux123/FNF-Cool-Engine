package extensions;

// ─────────────────────────────────────────────────────────────────────────────
// InitAPI — funciones nativas de Windows via DWM/User32.
//
// Compilado condicionalmente: el bloque #if windows usa @:functionCode para
// generar C++ inline que llama directamente a la API de Windows.
// En macOS/Linux todas las funciones son stubs inline vacíos.
//
// ─── Funciones disponibles ───────────────────────────────────────────────────
//  setWindowBorderColor(r,g,b)  — tint DWM Win11 (DWMWA_BORDER_COLOR)
//  setWindowCaptionColor(r,g,b) — tint título DWM Win11 (DWMWA_CAPTION_COLOR)
//  setDarkMode(enable)          — Win10 1809+ dark/light frame
//  setDPIAware()                — SetProcessDPIAware para monitores HiDPI
//
// ─────────────────────────────────────────────────────────────────────────────

#if windows

@:buildXml('
<target id="haxe">
    <lib name="dwmapi.lib"  if="windows" />
    <lib name="user32.lib"  if="windows" />
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
// Deshacer macros de Windows que colisionan con Haxe
#undef TRUE
#undef FALSE
#undef NO_ERROR

// DWMWA constants que pueden no estar en SDKs viejos
#ifndef DWMWA_BORDER_COLOR
  #define DWMWA_BORDER_COLOR   34
#endif
#ifndef DWMWA_CAPTION_COLOR
  #define DWMWA_CAPTION_COLOR  35
#endif
#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
  #define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif
')
class InitAPI
{
    /**
     * Cambia el color del borde de la ventana (DWMWA_BORDER_COLOR).
     * Sólo visible en Windows 11 (build 22000+).
     */
    @:functionCode('
        COLORREF color = RGB(r, g, b);
        HWND hwnd = GetActiveWindow();
        DwmSetWindowAttribute(hwnd, DWMWA_BORDER_COLOR, &color, sizeof(COLORREF));
        UpdateWindow(hwnd);
    ')
    public static function setWindowBorderColor(r:Int, g:Int, b:Int):Void {}

    /**
     * Cambia el color del caption/titlebar (DWMWA_CAPTION_COLOR).
     * Sólo visible en Windows 11 (build 22000+).
     */
    @:functionCode('
        COLORREF color = RGB(r, g, b);
        HWND hwnd = GetActiveWindow();
        DwmSetWindowAttribute(hwnd, DWMWA_CAPTION_COLOR, &color, sizeof(COLORREF));
        UpdateWindow(hwnd);
    ')
    public static function setWindowCaptionColor(r:Int, g:Int, b:Int):Void {}

    /**
     * Activa/desactiva el frame oscuro (DWMWA_USE_IMMERSIVE_DARK_MODE).
     * Disponible en Windows 10 build 1809+ y Windows 11.
     */
    @:functionCode('
        BOOL darkMode = (BOOL)enable;
        HWND hwnd = GetActiveWindow();
        if (S_OK != DwmSetWindowAttribute(hwnd, DWMWA_USE_IMMERSIVE_DARK_MODE, &darkMode, sizeof(BOOL))) {
            DwmSetWindowAttribute(hwnd, 19, &darkMode, sizeof(BOOL));
        }
        UpdateWindow(hwnd);
    ')
    public static function setDarkMode(enable:Bool):Void {}

    /**
     * Registra el proceso como DPI-aware.
     * Llamar antes de que se cree cualquier ventana.
     * Sin esto, Windows escala el framebuffer en monitores HiDPI → blur + coords incorrectas.
     */
    @:functionCode('
        SetProcessDPIAware();
    ')
    public static function setDPIAware():Void {}
}

#else

// ── Stubs para macOS / Linux ──────────────────────────────────────────────────
class InitAPI
{
    public static inline function setWindowBorderColor(r:Int, g:Int, b:Int):Void {}
    public static inline function setWindowCaptionColor(r:Int, g:Int, b:Int):Void {}
    public static inline function setDarkMode(enable:Bool):Void {}
    public static inline function setDPIAware():Void {}
}

#end
