package funkin.scripting;

import flixel.FlxG;
import flixel.FlxState;
import flixel.FlxSprite;
import flixel.text.FlxText;
import funkin.menus.OptionsMenuState;

/**
 * Clase base para scripts de States
 * Similar a ModuleScript pero para cualquier FlxState
 */
class StateScript
{
	public var name:String = 'StateScript';
	public var description:String = '';
	public var author:String = '';
	public var version:String = '1.0.0';
	
	public var state:FlxState;
	public var active:Bool = true;
	
	public function new()
	{
		// Se asignará cuando se cargue
	}
	
	// ===========================
	// LIFECYCLE CALLBACKS
	// ===========================
	
	/**
	 * Llamado cuando el script es cargado
	 */
	public function onCreate():Void
	{
		trace('[StateScript $name] Created');
	}
	
	/**
	 * Llamado después de create del state
	 */
	public function postCreate():Void
	{
	}
	
	/**
	 * Llamado cada frame
	 */
	public function onUpdate(elapsed:Float):Void
	{
	}
	
	/**
	 * Llamado después de update
	 */
	public function onUpdatePost(elapsed:Float):Void
	{
	}
	
	/**
	 * Llamado al destruir el state
	 */
	public function onDestroy():Void
	{
		trace('[StateScript $name] Destroyed');
	}
	
	// ===========================
	// OPTIONS-SPECIFIC CALLBACKS
	// ===========================
	
	/**
	 * Retorna opciones personalizadas para añadir al menú
	 * @return Array de opciones custom
	 */
	public function getCustomOptions():Array<Dynamic>
	{
		return [];
	}
	
	/**
	 * Retorna categorías personalizadas
	 * @return Array de nombres de categorías
	 */
	public function getCustomCategories():Array<String>
	{
		return [];
	}
	
	/**
	 * Llamado cuando se selecciona una opción
	 */
	public function onOptionSelected(optionName:String):Void
	{
	}
	
	/**
	 * Llamado cuando cambia el valor de una opción
	 */
	public function onOptionChanged(optionName:String, newValue:Dynamic):Void
	{
	}
	
	/**
	 * Llamado cuando se navega entre opciones/items
	 */
	public function onSelectionChanged(curSelected:Int):Void
	{
	}
	
	// ===========================
	// STATE CALLBACKS
	// ===========================
	
	/**
	 * Llamado cuando se presiona BACK
	 * @return true para cancelar el comportamiento por defecto
	 */
	public function onBack():Bool
	{
		return false;
	}
	
	/**
	 * Llamado cuando se presiona ACCEPT
	 * @return true para cancelar el comportamiento por defecto
	 */
	public function onAccept():Bool
	{
		return false;
	}
	
	// ===========================
	// MENU-SPECIFIC CALLBACKS
	// ===========================
	
	/**
	 * Retorna items de menú personalizados
	 * @return Array de strings con nombres de items
	 */
	public function getCustomMenuItems():Array<String>
	{
		return [];
	}
	
	/**
	 * Llamado cuando se selecciona un item del menú
	 */
	public function onMenuItemSelected(itemName:String, itemIndex:Int):Void
	{
	}
	
	// ===========================
	// FREEPLAY-SPECIFIC CALLBACKS
	// ===========================
	
	/**
	 * Llamado cuando se selecciona una canción
	 */
	public function onSongSelected(songName:String):Void
	{
	}
	
	/**
	 * Llamado cuando cambia la dificultad
	 */
	public function onDifficultyChanged(difficulty:Int):Void
	{
	}
	
	/**
	 * Retorna canciones personalizadas para freeplay
	 * @return Array de objetos con datos de canciones
	 */
	public function getCustomSongs():Array<Dynamic>
	{
		return [];
	}
	
	// ===========================
	// STORY-SPECIFIC CALLBACKS
	// ===========================
	
	/**
	 * Llamado cuando se selecciona una semana
	 */
	public function onWeekSelected(weekIndex:Int):Void
	{
	}
	
	/**
	 * Retorna semanas personalizadas
	 * @return Array de objetos con datos de semanas
	 */
	public function getCustomWeeks():Array<Dynamic>
	{
		return [];
	}
	
	// ===========================
	// TITLE-SPECIFIC CALLBACKS
	// ===========================
	
	/**
	 * Llamado cuando se completa la intro
	 */
	public function onIntroComplete():Void
	{
	}
	
	/**
	 * Llamado en cada beat durante la intro
	 */
	public function onIntroBeat(beat:Int):Void
	{
	}
	
	/**
	 * Permite modificar el texto de intro
	 */
	public function getIntroText():Array<String>
	{
		return [];
	}
	
	// ===========================
	// UTILITIES
	// ===========================
	
	/**
	 * Helper para acceso rápido a variables del State
	 */
	public function getVar(name:String):Dynamic
	{
		return Reflect.getProperty(state, name);
	}
	
	/**
	 * Helper para establecer variables del State
	 */
	public function setVar(name:String, value:Dynamic):Void
	{
		Reflect.setProperty(state, name, value);
	}
	
	/**
	 * Log con prefijo del script
	 */
	public function log(message:Dynamic):Void
	{
		trace('[StateScript: $name] $message');
	}
	
	/**
	 * Añadir un sprite al state
	 */
	public function addSprite(sprite:FlxSprite):FlxSprite
	{
		state.add(sprite);
		return sprite;
	}
	
	/**
	 * Remover un sprite del state
	 */
	public function removeSprite(sprite:FlxSprite):FlxSprite
	{
		state.remove(sprite);
		return sprite;
	}
	
	/**
	 * Crear un FlxText fácilmente
	 */
	public function createText(x:Float, y:Float, text:String, size:Int = 16):FlxText
	{
		var txt = new FlxText(x, y, 0, text, size);
		return txt;
	}
}
