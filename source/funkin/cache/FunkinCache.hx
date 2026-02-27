package funkin.cache;

import flixel.FlxG;
import openfl.display.BitmapData;
import openfl.media.Sound;
import openfl.text.Font;
import openfl.utils.AssetCache;
import animationdata.FunkinSprite;
#if lime
import lime.utils.Assets as LimeAssets;
#end

/**
 * FunkinCache — gestiona el ciclo de vida de assets entre estados.
 *
 * Basado directamente en Codename Engine FunkinCache (sistema probado).
 *
 * ─── Arquitectura (2 capas, igual que Codename) ────────────────────────────
 *
 *  Capa CURRENT  (bitmapData / font / sound)
 *    → Assets cargados en la sesión activa.
 *    → Se mueven a SECOND en preStateSwitch.
 *
 *  Capa SECOND   (bitmapData2 / font2 / sound2)
 *    → Assets de la sesión anterior.
 *    → getBitmapData() los "rescata" a CURRENT si el nuevo estado los necesita.
 *    → Lo que nadie rescató se destruye en postStateSwitch via clearSecondLayer().
 *
 * ─── Por qué NO usamos PathsCache en los signals ──────────────────────────
 *  PathsCache.beginSession() + clearPreviousSession() destruían FlxGraphics
 *  después de que los sprites del nuevo estado ya los cargaron → crash.
 *  FunkinCache maneja todo via FlxG.bitmap.removeByKey (exactamente como Codename).
 */
class FunkinCache extends AssetCache
{
	public static var instance:FunkinCache;

	@:noCompletion public var bitmapData2:Map<String, BitmapData>;
	@:noCompletion public var font2:Map<String, Font>;
	@:noCompletion public var sound2:Map<String, Sound>;

	public function new()
	{
		super();
		moveToSecondLayer();
		instance = this;
	}

	public static function init():Void
	{
		openfl.utils.Assets.cache = new FunkinCache();

		FlxG.signals.preStateSwitch.add(function()
		{
			// Mover assets CURRENT → SECOND antes del cambio.
			// El nuevo estado rescatará lo que necesite via getBitmapData().
			instance.moveToSecondLayer();

			// Limpiar caché de atlas — el nuevo estado crea FlxAtlasFrames frescos.
			// Sin esto, sprites reutilizan atlas con gráficos ya destruidos → crash.
			FunkinSprite.clearAllCaches();
		});

		FlxG.signals.postStateSwitch.add(function()
		{
			// Destruir lo que el nuevo estado no rescató.
			instance.clearSecondLayer();

			// GC ligero para devolver memoria al OS sin pausa visible
			try { openfl.system.System.gc(); } catch (_:Dynamic) {}
			#if cpp
			try { cpp.vm.Gc.run(false); } catch (_:Dynamic) {}
			#end
		});
	}

	// ── Rotación de capas ─────────────────────────────────────────────────

	public function moveToSecondLayer():Void
	{
		bitmapData2 = bitmapData != null ? bitmapData : new Map();
		font2       = font       != null ? font       : new Map();
		sound2      = sound      != null ? sound      : new Map();

		bitmapData = new Map();
		font       = new Map();
		sound      = new Map();
	}

	/**
	 * Destruye los assets de SECOND que el nuevo estado no rescató.
	 * Usa FlxG.bitmap.removeByKey() exactamente como Codename Engine:
	 * elimina Y destruye el FlxGraphic asociado de forma segura porque
	 * getBitmapData() ya rescató a CURRENT todo lo que el nuevo estado usó.
	 */
	public function clearSecondLayer():Void
	{
		for (k => b in bitmapData2)
		{
			// removeByKey: elimina de FlxG.bitmap y llama destroy() en el FlxGraphic.
			// Seguro porque si el nuevo estado necesitaba este asset,
			// getBitmapData() ya lo movió de bitmapData2 → bitmapData.
			FlxG.bitmap.removeByKey(k);
			#if lime
			LimeAssets.cache.image.remove(k);
			#end
		}
		for (k => f in font2)
		{
			#if lime
			LimeAssets.cache.font.remove(k);
			#end
		}
		for (k => s in sound2)
		{
			#if lime
			LimeAssets.cache.audio.remove(k);
			#end
		}

		bitmapData2 = new Map();
		font2       = new Map();
		sound2      = new Map();

		// Limpiar gráficos huérfanos (useCount=0, no persist).
		// Cubre assets cargados via lime.fromFile que no pasan por FunkinCache.
		try { FlxG.bitmap.clearUnused(); } catch (_:Dynamic) {}
	}

	// ── getBitmapData ─────────────────────────────────────────────────────

	public override function getBitmapData(id:String):BitmapData
	{
		var s = bitmapData.get(id);
		if (s != null) return s;

		// Rescate de SECOND → CURRENT (el nuevo estado necesita este asset)
		var s2 = bitmapData2.get(id);
		if (s2 != null)
		{
			bitmapData2.remove(id);
			bitmapData.set(id, s2);
		}
		return s2;
	}

	public override function hasBitmapData(id:String):Bool
		return bitmapData.exists(id) || bitmapData2.exists(id);

	public override function setBitmapData(id:String, bitmapDataValue:BitmapData):Void
		bitmapData.set(id, bitmapDataValue);

	public override function removeBitmapData(id:String):Bool
	{
		#if lime
		LimeAssets.cache.image.remove(id);
		#end
		return bitmapData.remove(id) || bitmapData2.remove(id);
	}

	// ── getFont ───────────────────────────────────────────────────────────

	public override function getFont(id:String):Font
	{
		var s = font.get(id);
		if (s != null) return s;

		var s2 = font2.get(id);
		if (s2 != null)
		{
			font2.remove(id);
			font.set(id, s2);
		}
		return s2;
	}

	public override function hasFont(id:String):Bool
		return font.exists(id) || font2.exists(id);

	public override function setFont(id:String, fontValue:Font):Void
		font.set(id, fontValue);

	public override function removeFont(id:String):Bool
	{
		#if lime
		LimeAssets.cache.font.remove(id);
		#end
		return font.remove(id) || font2.remove(id);
	}

	// ── getSound ──────────────────────────────────────────────────────────

	public override function getSound(id:String):Sound
	{
		var s = sound.get(id);
		if (s != null) return s;

		var s2 = sound2.get(id);
		if (s2 != null)
		{
			sound2.remove(id);
			sound.set(id, s2);
		}
		return s2;
	}

	public override function hasSound(id:String):Bool
		return sound.exists(id) || sound2.exists(id);

	public override function setSound(id:String, soundValue:Sound):Void
		sound.set(id, soundValue);

	public override function removeSound(id:String):Bool
	{
		#if lime
		LimeAssets.cache.audio.remove(id);
		#end
		return sound.remove(id) || sound2.remove(id);
	}

	// ── clear ─────────────────────────────────────────────────────────────

	public override function clear(?id:String):Void
	{
		if (id != null)
		{
			removeBitmapData(id);
			removeFont(id);
			removeSound(id);
			return;
		}
		bitmapData.clear();
		font.clear();
		sound.clear();
		bitmapData2.clear();
		font2.clear();
		sound2.clear();
	}
}
