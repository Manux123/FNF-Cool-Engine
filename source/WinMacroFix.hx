package;

#if macro
import haxe.macro.Context;
import sys.io.File;
import sys.FileSystem;

/**
 * WinMacroFix.hx — source/WinMacroFix.hx
 *
 * Parchea los .h generados de FlxKey y FlxColor DESPUÉS de que Haxe
 * los genera pero ANTES de que MSVC los compile.
 * Inyecta #undef al principio de cada header para eliminar las macros
 * de windows.h que colisionan (TRANSPARENT, DELETE, etc.).
 *
 * En project.xml añade:
 *   <haxeflag name="--macro" value="WinMacroFix.apply()" if="windows"/>
 */
class WinMacroFix
{
	static final UNDEFS_COLOR = '
#ifdef TRANSPARENT
#undef TRANSPARENT
#endif
#ifdef BLACK
#undef BLACK
#endif
#ifdef WHITE
#undef WHITE
#endif
#ifdef RED
#undef RED
#endif
#ifdef GREEN
#undef GREEN
#endif
#ifdef BLUE
#undef BLUE
#endif
';

	static final UNDEFS_KEY = '
#ifdef DELETE
#undef DELETE
#endif
#ifdef HOME
#undef HOME
#endif
#ifdef END
#undef END
#endif
#ifdef INSERT
#undef INSERT
#endif
#ifdef PAUSE
#undef PAUSE
#endif
#ifdef PRINT
#undef PRINT
#endif
#ifdef ESCAPE
#undef ESCAPE
#endif
';

	public static function apply()
	{
		Context.onAfterGenerate(function()
		{
			// La carpeta de salida del C++ generado
			var outDir = Context.definedValue('HXCPP_OUT');
			if (outDir == null || outDir == '')
				outDir = 'export/debug/windows/obj'; // fallback típico de Lime

			var targets = [
				{ path: outDir + '/include/flixel/util/_FlxColor/FlxColor_Impl_.h', undefs: UNDEFS_COLOR },
				{ path: outDir + '/include/flixel/input/keyboard/_FlxKey/FlxKey_Impl_.h', undefs: UNDEFS_KEY }
			];

			for (t in targets)
			{
				if (!FileSystem.exists(t.path))
				{
					trace('[WinMacroFix] No encounter: ' + t.path);
					continue;
				}

				var content = File.getContent(t.path);

				// Solo parchear si aún no tiene los undefs (evita doble parcheo)
				if (content.indexOf('#undef TRANSPARENT') != -1 ||
				    content.indexOf('#undef DELETE') != -1)
				{
					trace('[WinMacroFix] Now parched: ' + t.path);
					continue;
				}

				// Inyectar después del primer #pragma once o #ifndef guard
				var insertAfter = '#pragma once';
				var idx = content.indexOf(insertAfter);
				if (idx == -1)
				{
					// Si no hay pragma once, insertar al principio
					content = t.undefs + content;
				}
				else
				{
					var pos = idx + insertAfter.length;
					content = content.substr(0, pos) + '\n' + t.undefs + content.substr(pos);
				}

				File.saveContent(t.path, content);
				trace('[WinMacroFix] Parched OK: ' + t.path);
			}
		});
	}
}
#end
