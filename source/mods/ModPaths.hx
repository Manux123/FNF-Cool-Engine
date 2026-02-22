package mods;

import flixel.FlxG;
import flixel.graphics.frames.FlxAtlasFrames;
import openfl.display.BitmapData as Bitmap;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

/**
	* ModPaths: A convenience API for accessing assets of a specific mod.

	* Most of the time you DON'T need ModPaths directly.

	* If you activate a mod with `ModManager.setActive('my-mod')`,

	* all the methods in `Paths` will automatically search the mod.

	* ModPaths is useful when you need to:

	* • Access a mod's assets without activating it globally.

	* • Compare assets between two mods.

	* • Display mod previews in a selector. *

	* ─── Usage ─────────────────────────────────── ─────────────────────────────────────

	* // Explicit access to a mod without changing it globally
	* ModPaths.image('ui/logo', 'mi-mod');
	*
	* // Access to the active mod (equivalent to using Paths directly)
	* ModPaths.image('ui/logo'); // Uses ModManager.activeMod
 */

class ModPaths
{
	// ─── Paths básicos ────────────────────────────────────────────────────────

	/** Resuelve `file` dentro del mod `mod` (o el activo si no se especifica). */
	public static function resolve(file:String, ?mod:String):String
	{
		final id = mod ?? ModManager.activeMod;
		final path = ModManager.resolveInSpecific(id, file);
		return path ?? 'assets/$file'; // fallback base
	}

	// ─── Assets de texto ─────────────────────────────────────────────────────

	public static inline function txt(key:String, ?mod:String):String
		return resolve('data/$key.txt', mod);

	public static inline function xml(key:String, ?mod:String):String
		return resolve('data/$key.xml', mod);

	public static inline function json(key:String, ?mod:String):String
		return resolve('data/$key.json', mod);

	// ─── Canciones ────────────────────────────────────────────────────────────

	public static function songJson(song:String, difficulty:String = 'Hard', ?mod:String):String
		return resolve('songs/${song.toLowerCase()}/$difficulty.json', mod);

	public static function inst(song:String, ?mod:String):String
		return resolve('songs/${song.toLowerCase()}/song/Inst.${Paths.SOUND_EXT}', mod);

	public static function voices(song:String, ?mod:String):String
		return resolve('songs/${song.toLowerCase()}/song/Voices.${Paths.SOUND_EXT}', mod);

	// ─── Personajes ───────────────────────────────────────────────────────────

	public static function characterJSON(key:String, ?mod:String):String
		return resolve('characters/$key.json', mod);

	public static function characterImage(key:String, ?mod:String):String
		return resolve('characters/images/$key.png', mod);

	// ─── Stages ───────────────────────────────────────────────────────────────

	public static function stageJSON(key:String, ?mod:String):String
		return resolve('stages/$key/$key.json',
			mod) != 'assets/stages/$key/$key.json' ? resolve('stages/$key/$key.json', mod) : resolve('stages/$key.json', mod);

	// ─── Imágenes y sprites ───────────────────────────────────────────────────

	public static function image(key:String, ?mod:String):String
		return resolve('images/$key.png', mod);

	public static function bgImage(key:String, ?mod:String):String
		return resolve('images/BGs/$key.png', mod);

	public static function iconImage(key:String, ?mod:String):String
		return resolve('images/icons/$key.png', mod);

	/** Previsualización de vídeo del mod en un selector. */
	public static function previewVideo(modId:String, key:String):String
		return '${ModManager.MODS_FOLDER}/previewVids/$modId/$key.mp4';

	// ─── Shaders ──────────────────────────────────────────────────────────────

	/** Resuelve un shader .frag del mod especificado (o el activo). */
	public static inline function shader(key:String, ?mod:String):String
		return resolve('shaders/$key.frag', mod);

	// ─── Audio ────────────────────────────────────────────────────────────────

	public static function sound(key:String, ?mod:String):String
		return resolve('sounds/$key.${Paths.SOUND_EXT}', mod);

	public static function soundRandom(key:String, min:Int, max:Int, ?mod:String):String
		return sound(key + FlxG.random.int(min, max), mod);

	public static function music(key:String, ?mod:String):String
		return resolve('music/$key.${Paths.SOUND_EXT}', mod);

	// ─── Vídeo ────────────────────────────────────────────────────────────────

	public static function video(key:String, ?mod:String):String
		return resolve('videos/$key.mp4', mod);

	// ─── Fuentes ─────────────────────────────────────────────────────────────

	public static function font(key:String, ?mod:String):String
		return resolve('fonts/$key', mod);

	// ─── Atlas ────────────────────────────────────────────────────────────────

	/**
	 * Carga un atlas Sparrow del mod especificado.
	 * Nota: NO usa el caché de Paths (es una carga puntual para un mod específico).
	 * Si quieres caché, activa el mod con ModManager y usa Paths.getSparrowAtlas().
	 */
	public static function getSparrowAtlas(key:String, ?mod:String):FlxAtlasFrames
	{
		final pngPath = image(key, mod);
		final xmlPath = resolve('images/$key.xml', mod);

		#if sys
		if (sys.FileSystem.exists(pngPath) && sys.FileSystem.exists(xmlPath))
		{
			return FlxAtlasFrames.fromSparrow(openfl.display.BitmapData.fromFile(pngPath), sys.io.File.getContent(xmlPath));
		}
		#end

		return FlxAtlasFrames.fromSparrow(pngPath, xmlPath);
	}

	// ─── Utilidades ───────────────────────────────────────────────────────────

	/** ¿Existe `file` en el mod `mod` (o el activo)? */
	public static function exists(file:String, ?mod:String):Bool
	{
		final id = mod ?? ModManager.activeMod;
		final path = ModManager.resolveInSpecific(id, file);

		if (path == null)
			return false;
		#if sys
		return sys.FileSystem.exists(path);
		#else
		return openfl.utils.Assets.exists(path);
		#end
	}
}
