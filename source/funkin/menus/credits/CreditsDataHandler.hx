package funkin.menus.credits;

import haxe.Json;
import funkin.menus.credits.CreditsData;

using StringTools;

/**
 * CreditsDataHandler — carga y fusiona los datos de créditos.
 *
 * Jerarquía de carga:
 *  1. assets/data/credits.json       → créditos base del juego
 *  2. mods/<mod>/data/credits.json   → créditos del mod activo (se AÑADEN al final)
 *
 * Si el JSON base no existe, usa fallback hardcodeado.
 * El mod puede añadir entradas nuevas pero NO reemplaza el JSON base.
 */
class CreditsDataHandler
{
	static final BASE_PATH   = 'assets/data/credits.json';
	static final MOD_SUBPATH = 'data/credits.json';

	/** Datos fusionados (base + mod). Se cachean hasta reload(). */
	static var _cached:Null<CreditsData> = null;

	/**
	 * Retorna los créditos fusionados (base + mod si aplica).
	 * Cacheado: llamar reload() para refrescar.
	 */
	public static function get():CreditsData
	{
		if (_cached == null) _cached = _load();
		return _cached;
	}

	/** Fuerza recarga en el próximo get(). */
	public static function reload():Void
	{
		_cached = null;
	}

	// ── Privado ──────────────────────────────────────────────────────────────

	static function _load():CreditsData
	{
		var base = _loadFromPath(BASE_PATH);
		if (base == null) base = _fallback();

		#if sys
		if (mods.ModManager.isActive())
		{
			final modPath = mods.ModManager.modRoot() + '/' + MOD_SUBPATH;
			var modData = _loadFromSys(modPath);
			if (modData != null && modData.entries != null)
			{
				// Añadir entradas del mod al final sin tocar las base
				for (e in modData.entries)
					base.entries.push(e);
			}
		}
		#end

		return base;
	}

	static function _loadFromPath(path:String):Null<CreditsData>
	{
		#if sys
		return _loadFromSys(path);
		#else
		// openfl.Assets fallback para targets no-sys (HTML5, etc.)
		try
		{
			var raw = openfl.Assets.getText(path);
			if (raw != null && raw.length > 0)
				return _parse(raw, path);
		}
		catch (e:Dynamic) { trace('[CreditsDataHandler] openfl.Assets error $path: $e'); }
		return null;
		#end
	}

	#if sys
	static function _loadFromSys(path:String):Null<CreditsData>
	{
		try
		{
			if (sys.FileSystem.exists(path))
			{
				var raw = sys.io.File.getContent(path).trim();
				if (raw.length > 0)
					return _parse(raw, path);
			}
		}
		catch (e:Dynamic) { trace('[CreditsDataHandler] Error leyendo $path: $e'); }
		return null;
	}
	#end

	static function _parse(raw:String, id:String):Null<CreditsData>
	{
		try
		{
			var data:CreditsData = cast Json.parse(raw);
			if (data != null && data.entries != null)
				return data;
			trace('[CreditsDataHandler] JSON inválido en $id (entries null)');
		}
		catch (e:Dynamic) { trace('[CreditsDataHandler] JSON parse error en $id: $e'); }
		return null;
	}

	/** Créditos de fallback si no hay JSON. */
	static function _fallback():CreditsData
	{
		return {
			entries: [
				{
					header: 'Fundadores',
					body: [
						{line: 'ninjamuffin99 — Programación'},
						{line: 'PhantomArcade — Animación'},
						{line: 'Kawai Sprite — Música & Sonido'},
						{line: 'evilsk8r — Arte'}
					],
					headerColor: 'FF4CA0',
					bodyColor: null
				}
			]
		};
	}
}
