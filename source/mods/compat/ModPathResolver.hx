package mods.compat;

#if sys
import sys.FileSystem;
#end

using StringTools;
/**
 * ModPathResolver
 * ─────────────────────────────────────────────────────────────────────────────
 * Resolves asset paths for mods built with different engines.
 * Each engine stores files in slightly different folder layouts.
 *
 * ── Folder structure comparison ──────────────────────────────────────────────
 *
 *  Asset          Cool Engine              Psych Engine           Codename Engine
 *  ─────────────  ───────────────────────  ─────────────────────  ──────────────────────
 *  Char JSON      characters/name.json     characters/name.json   data/characters/name.xml
 *  Char image     characters/images/name   images/characters/name images/characters/name
 *  Stage JSON     stages/name.json         stages/name.json       data/stages/name.hxs (!)
 *  Stage image    stages/name/images/img   images/stages/img      images/stages/img
 *  Chart          songs/name/hard.json     songs/name/hard.json   songs/name/chart.json
 *  Inst audio     songs/name/song/Inst.ogg songs/name/Inst.ogg    songs/name/Inst.ogg
 *  Voices audio   songs/name/song/Voices   songs/name/Voices      songs/name/Voices
 *
 * ── How to use ───────────────────────────────────────────────────────────────
 *  // Instead of ModManager.resolveInMod('characters/$name.json')
 *  ModPathResolver.characterJson(name);   // tries all known locations
 *  ModPathResolver.inst(songName);        // tries both audio layouts
 *  ModPathResolver.chartJson(song, diff); // tries all chart naming conventions
 */
class ModPathResolver
{
	// ─── Character files ──────────────────────────────────────────────────────

	/**
	 * Finds a character JSON or XML in the active mod.
	 * Returns null if nothing found.
	 * Check the extension of the returned path to know if it's XML or JSON.
	 */
	public static function characterFile(name:String):Null<String>
	{
		final mod = ModManager.activeMod;
		if (mod == null) return null;
		final base = '${ModManager.MODS_FOLDER}/$mod';

		return _first([
			// Cool / Psych
			'$base/characters/$name.json',
			// Codename
			'$base/data/characters/$name.xml',
			'$base/data/characters/$name.json',
			// Some Psych packs use shared/
			'$base/shared/characters/$name.json'
		]);
	}

	/**
	 * Finds a character spritesheet image (PNG) in the active mod.
	 * Returns path WITHOUT extension (caller adds .png / .xml as needed).
	 */
	public static function characterImageBase(name:String):Null<String>
	{
		final mod = ModManager.activeMod;
		if (mod == null) return null;
		final base = '${ModManager.MODS_FOLDER}/$mod';

		// Texture atlas folder (Codename / new Psych)
		final folder = _firstDir([
			'$base/images/characters/$name',
			'$base/characters/images/$name',
			'$base/shared/images/characters/$name'
		]);
		if (folder != null) return folder;

		// Flat PNG
		return _firstBase([
			'$base/images/characters/$name',
			'$base/characters/images/$name',
			'$base/shared/images/characters/$name'
		]);
	}

	// ─── Stage files ──────────────────────────────────────────────────────────

	/**
	 * Finds a stage definition file in the active mod.
	 * Returns null if nothing found.
	 * NOTE: Codename stages are .hxs — if that's what's returned, they can't be
	 * parsed as JSON. ModCompatLayer handles this by falling back to default stage.
	 */
	public static function stageFile(name:String):Null<String>
	{
		final mod = ModManager.activeMod;
		if (mod == null) return null;
		final base = '${ModManager.MODS_FOLDER}/$mod';

		return _first([
			// Cool / Psych flat
			'$base/stages/$name.json',
			// Psych subfolder
			'$base/stages/$name/$name.json',
			// Codename JSON (rare but some packs have it)
			'$base/data/stages/$name.json',
			// Codename HScript (we detect this and handle separately)
			'$base/data/stages/$name.hxs',
			'$base/stages/$name.hxs'
		]);
	}

	/**
	 * Finds a stage background image in the active mod.
	 * `stageName` is the folder name, `imgKey` is the image file name.
	 */
	public static function stageImage(stageName:String, imgKey:String):Null<String>
	{
		final mod = ModManager.activeMod;
		if (mod == null) return null;
		final base = '${ModManager.MODS_FOLDER}/$mod';

		return _firstWithExt([
			// Cool Engine layout
			'$base/stages/$stageName/images/$imgKey',
			// Psych / Codename layout
			'$base/images/stages/$imgKey',
			'$base/images/$imgKey',
			'$base/shared/images/$imgKey'
		], ['png', 'jpg']);
	}

	// ─── Song / chart files ───────────────────────────────────────────────────

	/**
	 * Finds a chart JSON for a given song + difficulty in the active mod.
	 * Tries multiple naming conventions across engines.
	 */
	public static function chartJson(song:String, diff:String = 'hard'):Null<String>
	{
		final mod = ModManager.activeMod;
		if (mod == null) return null;
		final base  = '${ModManager.MODS_FOLDER}/$mod';
		final lower = song.toLowerCase();
		final d     = diff.toLowerCase();

		// Genera variantes del nombre (espacios ↔ guiones, con/sin !)
		final variants:Array<String> = [];
		function addV(v:String) { v = v.trim(); if (v != '' && variants.indexOf(v) == -1) variants.push(v); }
		addV(lower); addV(lower.replace(' ', '-')); addV(lower.replace('-', ' '));
		addV(lower.replace('!', '')); addV(lower.replace(' ', '-').replace('!', ''));

		var candidates:Array<String> = [];
		for (v in variants)
		{
			// Cool / Psych flat: songs/name/hard.json
			candidates.push('$base/songs/$v/$d.json');
			// Psych: data/name/name-hard.json  ← layout más común en mods Psych
			candidates.push('$base/data/$v/$v-$d.json');
			candidates.push('$base/data/$v/$d.json');
			// Codename: songs/name/chart.json
			candidates.push('$base/songs/$v/chart.json');
			candidates.push('$base/songs/$v/$v-$d.json');
			candidates.push('$base/songs/$v/$v.json');
		}

		return _first(candidates);
	}

	// ─── Audio files ──────────────────────────────────────────────────────────

	/**
	 * Finds the Inst audio file for a song in the active mod.
	 * Tries both the Cool `song/` subfolder layout and the flat Psych/CNE layout.
	 */
	public static function inst(song:String):Null<String>
	{
		final mod = ModManager.activeMod;
		if (mod == null) return null;
		final base  = '${ModManager.MODS_FOLDER}/$mod';
		final lower = song.toLowerCase();
		final ext   = #if web "mp3" #else "ogg" #end;

		return _first([
			// Cool: songs/name/song/Inst.ogg
			'$base/songs/$lower/song/Inst.$ext',
			// Psych / Codename: songs/name/Inst.ogg
			'$base/songs/$lower/Inst.$ext'
		]);
	}

	/**
	 * Finds the Voices audio file for a song in the active mod.
	 */
	public static function voices(song:String):Null<String>
	{
		final mod = ModManager.activeMod;
		if (mod == null) return null;
		final base  = '${ModManager.MODS_FOLDER}/$mod';
		final lower = song.toLowerCase();
		final ext   = #if web "mp3" #else "ogg" #end;

		return _first([
			'$base/songs/$lower/song/Voices.$ext',
			'$base/songs/$lower/Voices.$ext'
		]);
	}

	// ─── Helpers ─────────────────────────────────────────────────────────────

	/** Returns the first path that exists on disk. */
	static function _first(paths:Array<String>):Null<String>
	{
		#if sys
		for (p in paths)
			if (p != null && FileSystem.exists(p)) return p;
		#end
		return null;
	}

	/** Returns the first directory path that exists on disk. */
	static function _firstDir(paths:Array<String>):Null<String>
	{
		#if sys
		for (p in paths)
			if (p != null && FileSystem.exists(p) && FileSystem.isDirectory(p)) return p;
		#end
		return null;
	}

	/**
	 * Returns the first path (without extension) that has a matching file
	 * with any of the given extensions.
	 */
	static function _firstBase(bases:Array<String>):Null<String>
	{
		#if sys
		for (b in bases)
			for (ext in ['png', 'jpg', 'jpeg'])
				if (FileSystem.exists('$b.$ext')) return b;
		#end
		return null;
	}

	static function _firstWithExt(bases:Array<String>, exts:Array<String>):Null<String>
	{
		#if sys
		for (b in bases)
			for (ext in exts)
				if (FileSystem.exists('$b.$ext')) return '$b.$ext';
		#end
		return null;
	}
}
