package debug;

import flixel.FlxG;
import flixel.input.keyboard.FlxKey;
import sys.io.Process;

#if windows
import sys.FileSystem;
#end

class DebugConsole
{
    public static var enabled:Bool = true;
    public static var consoleKey:FlxKey = FlxKey.F2;
    public static var consoleOpened:Bool = false;
    
    public static function init():Void
    {
        #if debug
        trace("Debug Console inicializado - Presiona F2 para abrir consola");
        enabled = true;
        #else
        enabled = false;
        #end
    }
    
    public static function update():Void
    {
        #if debug
        if (!enabled) return;
        
        // Detectar cuando se presiona F2
        if (FlxG.keys.justPressed.F2)
        {
            openConsole();
        }
        
        // Atajos adicionales de debug
        if (FlxG.keys.justPressed.F3)
        {
            toggleDebugger();
        }
        
        if (FlxG.keys.justPressed.F4)
        {
            openProjectFolder();
        }
        #end
    }

    public static function openConsole():Void
    {
        #if debug
        trace("Abriendo consola del sistema...");
        
        #if windows
        openWindowsConsole();
        #elseif linux
        openLinuxTerminal();
        #elseif mac
        openMacTerminal();
        #else
        trace("Sistema operativo no soportado para abrir consola");
        #end
        
        consoleOpened = true;
        #end
    }
    
    #if windows
    private static function openWindowsConsole():Void
    {
        try
        {
            var projectPath = Sys.getCwd();
            
            // Intenta abrir PowerShell (más moderno)
            try
            {
                new Process('powershell', ['-NoExit', '-Command', 'cd "$projectPath"']);
                trace("PowerShell abierto en: " + projectPath);
            }
            catch (e:Dynamic)
            {
                try
                {
                    new Process('cmd', ['/K', 'cd /d "$projectPath"']);
                    trace("CMD abierto en: " + projectPath);
                }
                catch (e2:Dynamic)
                {
                    trace("Error abriendo consola: " + e2);
                }
            }
        }
        catch (e:Dynamic)
        {
            trace("Error general abriendo consola Windows: " + e);
        }
    }
    #end
    
    #if linux

    private static function openLinuxTerminal():Void
    {
        try
        {
            var projectPath = Sys.getCwd();
            
            // List of terminals comuns in Linux (in orden of preference)
            var terminals = [
                'gnome-terminal',      // GNOME
                'konsole',             // KDE
                'xfce4-terminal',      // XFCE
                'mate-terminal',       // MATE
                'lxterminal',          // LXDE
                'xterm',               // Fallback universal
                'terminator',          // Terminator
                'tilix'                // Tilix
            ];
            
            var opened = false;
            for (terminal in terminals)
            {
                try
                {
                    if (terminal == 'gnome-terminal' || terminal == 'mate-terminal')
                    {
                        new Process(terminal, ['--working-directory=$projectPath']);
                    }
                    else if (terminal == 'konsole')
                    {
                        new Process(terminal, ['--workdir', projectPath]);
                    }
                    else
                    {
                        new Process(terminal, ['-e', 'cd $projectPath && bash']);
                    }
                    
                    trace('Terminal $terminal abierto en: $projectPath');
                    opened = true;
                    break;
                }
                catch (e:Dynamic)
                {
                    continue;
                }
            }
            
            if (!opened)
            {
                trace("No se pudo encontrar ninguna terminal disponible");
            }
        }
        catch (e:Dynamic)
        {
            trace("Error abriendo terminal Linux: " + e);
        }
    }
    #end
    
    #if mac
    private static function openMacTerminal():Void
    {
        try
        {
            var projectPath = Sys.getCwd();
            
            var script = 'tell application "Terminal"
                activate
                do script "cd \\"$projectPath\\""
            end tell';
            
            new Process('osascript', ['-e', script]);
            trace("Terminal abierto en: " + projectPath);
        }
        catch (e:Dynamic)
        {
            trace("Error abriendo Terminal macOS: " + e);
        }
    }
    #end
    
    public static function toggleDebugger():Void
    {
        #if debug
        FlxG.debugger.visible = !FlxG.debugger.visible;
        trace("Debugger visual: " + (FlxG.debugger.visible ? "ACTIVADO" : "DESACTIVADO"));
        #end
    }
    
    public static function openProjectFolder():Void
    {
        #if debug
        try
        {
            var projectPath = Sys.getCwd();
            
            #if windows
            new Process('explorer', [projectPath]);
            #elseif linux
            new Process('xdg-open', [projectPath]);
            #elseif mac
            new Process('open', [projectPath]);
            #end
            
            trace("Carpeta del proyecto abierta: " + projectPath);
        }
        catch (e:Dynamic)
        {
            trace("Error abriendo carpeta: " + e);
        }
        #end
    }
    
    public static function executeCommand(command:String, ?args:Array<String>):String
    {
        #if debug
        try
        {
            if (args == null) args = [];
            
            var process = new Process(command, args);
            var output = process.stdout.readAll().toString();
            var exitCode = process.exitCode();
            
            trace('Comando ejecutado: $command ${args.join(" ")}');
            trace('Código de salida: $exitCode');
            
            process.close();
            return output;
        }
        catch (e:Dynamic)
        {
            trace('Error ejecutando comando: $e');
            return null;
        }
        #else
        return null;
        #end
    }
    
    public static function showSystemInfo():Void
    {
        #if debug
        trace("=== INFORMACIÓN DEL SISTEMA ===");
        trace("Sistema Operativo: " + Sys.systemName());
        trace("Directorio actual: " + Sys.getCwd());
        trace("Variables de entorno:");
        
        for (key in Sys.environment().keys())
        {
            trace('  $key = ${Sys.environment().get(key)}');
        }
        
        trace("================================");
        #end
    }
}
