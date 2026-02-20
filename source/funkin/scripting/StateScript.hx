package funkin.scripting;

import flixel.FlxState;
import flixel.FlxSprite;
import flixel.text.FlxText;

/**
 * Plantilla base para scripts de FlxStates (menús, opciones, freeplay…).
 *
 * Extiende esta clase en tus scripts HScript para obtener autocompletado
 * y documentación de todos los callbacks disponibles.
 *
 * ─── Ejemplo de uso ──────────────────────────────────────────────────────────
 *
 *   class MiScript extends StateScript {
 *     override function onCreate() {
 *       name = 'MiScript';
 *       var txt = createText(10, 10, 'Hola mundo!');
 *       addSprite(txt);
 *     }
 *     override function onBack():Bool {
 *       trace('Volviendo…');
 *       return false; // no cancelar
 *     }
 *   }
 *
 * ─── Callbacks disponibles ───────────────────────────────────────────────────
 *   Lifecycle    onCreate, postCreate, onUpdate, onUpdatePost, onDestroy
 *   Input        onBack (true=cancelar), onAccept (true=cancelar)
 *   Menú         getCustomMenuItems, onMenuItemSelected
 *   Opciones     getCustomOptions, getCustomCategories,
 *                onOptionSelected, onOptionChanged, onSelectionChanged
 *   Freeplay     onSongSelected, onDifficultyChanged, getCustomSongs
 *   Story        onWeekSelected, getCustomWeeks
 *   Title        onIntroComplete, onIntroBeat, getIntroText
 */
class StateScript
{
	// ─── Metadata ─────────────────────────────────────────────────────────────
	public var name        : String   = 'StateScript';
	public var description : String   = '';
	public var author      : String   = '';
	public var version     : String   = '1.0.0';
	public var active      : Bool     = true;

	/** El FlxState al que pertenece este script. Asignado automáticamente. */
	public var state       : FlxState;

	public function new() {}

	// ─── Lifecycle ────────────────────────────────────────────────────────────

	public function onCreate():Void {}
	public function postCreate():Void {}
	public function onUpdate(elapsed:Float):Void {}
	public function onUpdatePost(elapsed:Float):Void {}
	public function onDestroy():Void {}

	// ─── Input ────────────────────────────────────────────────────────────────

	/** @return true para cancelar el comportamiento por defecto. */
	public function onBack():Bool   return false;

	/** @return true para cancelar el comportamiento por defecto. */
	public function onAccept():Bool return false;

	// ─── Menú ─────────────────────────────────────────────────────────────────

	/** Añade items extra al menú principal. */
	public function getCustomMenuItems():Array<String>     return [];
	public function onMenuItemSelected(item:String, index:Int):Void {}

	// ─── Opciones ─────────────────────────────────────────────────────────────

	public function getCustomOptions():Array<Dynamic>      return [];
	public function getCustomCategories():Array<String>    return [];
	public function onOptionSelected(name:String):Void {}
	public function onOptionChanged(name:String, value:Dynamic):Void {}
	public function onSelectionChanged(index:Int):Void {}

	// ─── Freeplay ─────────────────────────────────────────────────────────────

	public function onSongSelected(song:String):Void {}
	public function onDifficultyChanged(diff:Int):Void {}

	/** Devuelve canciones extra para el freeplay. */
	public function getCustomSongs():Array<Dynamic>        return [];

	// ─── Story ────────────────────────────────────────────────────────────────

	public function onWeekSelected(weekIndex:Int):Void {}

	/** Devuelve semanas extra para el story mode. */
	public function getCustomWeeks():Array<Dynamic>        return [];

	// ─── Title ────────────────────────────────────────────────────────────────

	public function onIntroComplete():Void {}
	public function onIntroBeat(beat:Int):Void {}

	/** Sobreescribe el texto de intro. Array vacío = usar el por defecto. */
	public function getIntroText():Array<String>           return [];

	// ─── Utilidades ───────────────────────────────────────────────────────────

	public inline function getVar(name:String):Dynamic
		return Reflect.getProperty(state, name);

	public inline function setVar(name:String, value:Dynamic):Void
		Reflect.setProperty(state, name, value);

	public inline function log(msg:Dynamic):Void
		trace('[StateScript: $name] $msg');

	public inline function addSprite(sprite:FlxSprite):FlxSprite
	{
		state.add(sprite);
		return sprite;
	}

	public inline function removeSprite(sprite:FlxSprite):FlxSprite
	{
		state.remove(sprite);
		return sprite;
	}

	public function createText(x:Float, y:Float, text:String, size:Int = 16):FlxText
		return new FlxText(x, y, 0, text, size);
}
