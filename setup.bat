@echo off
title Cool Engine - VS Code Setup
echo.
echo  ======================================
echo   Cool Engine HScript - VS Code Setup
echo  ======================================
echo.

:: Verificar que VS Code esta instalado
where code >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo  [ERROR] VS Code was not found in the PATH.
    echo.
    echo  Download it from: https://code.visualstudio.com/
    echo  Make sure to check "Add to PATH" during installation.
    echo.
    pause
    exit /b 1
)

:: Instalar la extension
echo  [1/2] Installing HScript extension...
code --install-extension "tools\cool-engine-hscript.vsix" --force

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo  [ERROR] The extension could not be installed.
    echo  Try it manually: Extensions -^> "..." -^> Install from VSIX
    echo.
    pause
    exit /b 1
)

echo.
echo  [2/2] Opening a project in VS Code...
code .

echo.
echo  Done! The HScript extension is now active.
echo  You can close this window.
echo.
timeout /t 3 >nul
