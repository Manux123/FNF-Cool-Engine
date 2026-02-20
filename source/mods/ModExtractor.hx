package mods;

#if sys
import sys.FileSystem;
import sys.io.File;
import haxe.zip.Reader as ZipReader;
import haxe.zip.Entry as ZipEntry;
import haxe.zip.Uncompress;
import haxe.io.Path;
#end

using StringTools;

/**
 * ModExtractor: mods adicionales en formato .zip o .rar en la carpeta mods/. 
 * 
 * ─── Flujo ────────────────────────────────── ────────────────────────────────── 
 * 1. ModManager.init() llama extractAll() ANTES de escanear carpetas. 
 * 2. Se buscan archivos .zip / .rar en mods/. 
 * 3. Cada archivo se extrae a mods/{nombre}/ (sin extensión). 
 * 4. Un marcador .extracted_info evita volver a extraer si el archivo no cambió. 
 * 
 * ─── Soporte RAR ────────────────────────────── ─────────────────────────────── 
 * RAR no tiene analizador puro en Haxe. Se intenta descomprimir y luego 7z. 
 * Si ninguno está instalado, se recomienda convertir el mod a .zip.
 */
class ModExtractor
{
	public static inline var MODS_FOLDER = 'mods';
	public static inline var EXTRACTED_MARKER = '.extracted_info';

	public static function extractAll():Array<String>
	{
		var result:Array<String> = [];

		#if sys
		if (!FileSystem.exists(MODS_FOLDER) || !FileSystem.isDirectory(MODS_FOLDER))
			return result;

		for (entry in FileSystem.readDirectory(MODS_FOLDER))
		{
			final fullPath = '$MODS_FOLDER/$entry';
			if (FileSystem.isDirectory(fullPath))
				continue;

			final lower:String = entry.toLowerCase();
			var modName:String = null;

			if (lower.endsWith('.zip'))
				modName = entry.substr(0, entry.length - 4);
			else if (lower.endsWith('.rar'))
				modName = entry.substr(0, entry.length - 4);

			if (modName == null)
				continue;

			modName = _sanitizeName(modName);
			if (modName == '')
				continue;

			final destDir = '$MODS_FOLDER/$modName';
			final ok = lower.endsWith('.zip') ? _extractZip(fullPath, destDir) : _extractRar(fullPath, destDir);

			if (ok)
				result.push(modName);
		}
		#end

		return result;
	}

	#if sys
	// ─── ZIP ─────────────────────────────────────────────────────────────────

	static function _extractZip(zipPath:String, destDir:String):Bool
	{
		if (_alreadyExtracted(zipPath, destDir))
			return false;

		trace('[ModExtractor] Extracting ZIP: $zipPath → $destDir');

		try
		{
			final bytes = File.getBytes(zipPath);
			final input = new haxe.io.BytesInput(bytes);

			// haxe.zip.Reader.read() devuelve List<haxe.zip.Entry>
			final entries:List<ZipEntry> = new ZipReader(input).read();

			_ensureDir(destDir);

			for (entry in entries)
			{
				var name:String = entry.fileName;

				// Seguridad: rechazar rutas que escapen del destino
				if (name.startsWith('/') || name.startsWith('\\') || name.indexOf('../') >= 0 || name.indexOf('..\\') >= 0)
					continue;

				name = name.split('\\').join('/');

				final fullDest:String = '$destDir/$name';

				if (name.endsWith('/') || entry.dataSize == 0)
				{
					_ensureDir(fullDest);
				}
				else
				{
					_ensureDir(Path.directory(fullDest));
					var data = entry.data;
					if (data == null)
						continue;
					if (entry.compressed)
						data = Uncompress.run(data);
					File.saveBytes(fullDest, data);
				}
			}

			_writeMarker(zipPath, destDir);
			trace('[ModExtractor] ZIP extracted: $destDir');
			return true;
		}
		catch (e:Dynamic)
		{
			trace('[ModExtractor] Error ZIP "$zipPath": $e');
			return false;
		}
	}

	// ─── RAR ─────────────────────────────────────────────────────────────────

	static function _extractRar(rarPath:String, destDir:String):Bool
	{
		if (_alreadyExtracted(rarPath, destDir))
			return false;

		trace('[ModExtractor] Extracting RAR: $rarPath → $destDir');
		_ensureDir(destDir);

		if (_runCommand('unrar', ['x', '-y', '-inul', rarPath, destDir]))
		{
			_writeMarker(rarPath, destDir);
			trace('[ModExtractor] RAR extracted with unrar: $destDir');
			return true;
		}

		if (_runCommand('7z', ['x', '-y', '-bso0', rarPath, '-o' + destDir]))
		{
			_writeMarker(rarPath, destDir);
			trace('[ModExtractor] RAR extracted with 7z: $destDir');
			return true;
		}

		trace('[ModExtractor] Could not extract "$rarPath". Install unrar or 7z, or convert to .zip.');
		return false;
	}

	// ─── Helpers ─────────────────────────────────────────────────────────────

	static function _alreadyExtracted(archivePath:String, destDir:String):Bool
	{
		final markerPath = '$destDir/$EXTRACTED_MARKER';
		if (!FileSystem.exists(markerPath))
			return false;
		try
		{
			final saved:String = File.getContent(markerPath).trim();
			final stat = FileSystem.stat(archivePath);
			final cur:String = '${stat.size}:${stat.mtime.getTime()}';
			return saved == cur;
		}
		catch (_:Dynamic)
		{
			return false;
		}
	}

	static function _writeMarker(archivePath:String, destDir:String):Void
	{
		try
		{
			final stat = FileSystem.stat(archivePath);
			final info:String = '${stat.size}:${stat.mtime.getTime()}';
			File.saveContent('$destDir/$EXTRACTED_MARKER', info);
		}
		catch (_:Dynamic)
		{
		}
	}

	static function _ensureDir(path:String):Void
	{
		if (path == '' || path == '.' || FileSystem.exists(path))
			return;
		final parent:String = Path.directory(path);
		if (parent != path && parent != '')
			_ensureDir(parent);
		try
		{
			FileSystem.createDirectory(path);
		}
		catch (_:Dynamic)
		{
		}
	}

	static function _runCommand(cmd:String, args:Array<String>):Bool
	{
		try
		{
			return Sys.command(cmd, args) == 0;
		}
		catch (_:Dynamic)
		{
			return false;
		}
	}

	static function _sanitizeName(name:String):String
	{
		var out = new StringBuf();
		for (i in 0...name.length)
		{
			final c = name.charAt(i);
			switch (c)
			{
				case '/', '\\', ':', '*', '?', '"', '<', '>', '|':
					out.add('_');
				default:
					out.add(c);
			}
		}
		return out.toString().trim();
	}
	#end
}
