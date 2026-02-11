package funkin.gameplay.objects;

import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import funkin.data.Song.StrumsGroupData;
import funkin.gameplay.notes.StrumNote;

/**
 * StrumsGroup - Representa un grupo de 4 flechas (strums)
 * 
 * Cada grupo tiene:
 * - 4 StrumNotes (LEFT, DOWN, UP, RIGHT)
 * - Posición X/Y configurable
 * - Visibilidad configurable
 * - Flag de CPU/Player
 * - Espaciado entre flechas configurable
 * 
 * Esto permite tener múltiples grupos de strums por canción
 * Ejemplo: 2 grupos para CPU (dad_strums_1, dad_strums_2), 1 para jugador
 */
class StrumsGroup
{
	public var strums:FlxTypedGroup<FlxSprite>;
	public var data:StrumsGroupData;
	public var id:String;
	public var isCPU:Bool;
	public var isVisible:Bool;
	
	// Individual strums (para acceso rápido)
	public var leftStrum:FlxSprite;
	public var downStrum:FlxSprite;
	public var upStrum:FlxSprite;
	public var rightStrum:FlxSprite;
	
	private var spacing:Float = 110;
	private var scale:Float = 1.0;
	
	public function new(groupData:StrumsGroupData)
	{
		this.data = groupData;
		this.id = groupData.id;
		this.isCPU = groupData.cpu;
		this.isVisible = groupData.visible;
		this.spacing = groupData.spacing != null ? groupData.spacing : 110;
		this.scale = groupData.scale != null ? groupData.scale : 1.0;
		
		strums = new FlxTypedGroup<FlxSprite>();
		
		createStrums();
		
		trace('[StrumsGroup] Creado grupo "$id" - CPU: $isCPU, Visible: $isVisible, en (${groupData.x}, ${groupData.y})');
	}
	
	/**
	 * Crear las 4 flechas
	 */
	private function createStrums():Void
	{
		for (i in 0...4)
		{
			var strum:StrumNote = new StrumNote(
				data.x + (i * spacing),
				data.y,
				i
			);
			
			strum.ID = i;
			strum.visible = isVisible;
			
			if (scale != 1.0)
			{
				strum.scale.set(scale, scale);
				strum.updateHitbox();
			}
			
			strums.add(strum);
			
			// Guardar referencias individuales
			switch (i)
			{
				case 0:
					leftStrum = strum;
				case 1:
					downStrum = strum;
				case 2:
					upStrum = strum;
				case 3:
					rightStrum = strum;
			}
		}
	}
	
	/**
	 * Obtener strum por dirección
	 */
	public function getStrum(direction:Int):FlxSprite
	{
		if (direction < 0 || direction > 3)
			return null;
		
		return switch (direction)
		{
			case 0: leftStrum;
			case 1: downStrum;
			case 2: upStrum;
			case 3: rightStrum;
			default: null;
		}
	}
	
	/**
	 * Tocar animación de confirm en un strum
	 */
	public function playConfirm(direction:Int):Void
	{
		var strum = getStrum(direction);
		if (strum != null && Std.isOfType(strum, StrumNote))
		{
			var strumNote:StrumNote = cast(strum, StrumNote);
			strumNote.playAnim('confirm', true);
		}
	}
	
	/**
	 * Tocar animación de pressed en un strum
	 */
	public function playPressed(direction:Int):Void
	{
		var strum = getStrum(direction);
		if (strum != null && Std.isOfType(strum, StrumNote))
		{
			var strumNote:StrumNote = cast(strum, StrumNote);
			strumNote.playAnim('pressed', true);
		}
	}
	
	/**
	 * Resetear strum a static
	 */
	public function resetStrum(direction:Int):Void
	{
		var strum = getStrum(direction);
		if (strum != null && Std.isOfType(strum, StrumNote))
		{
			var strumNote:StrumNote = cast(strum, StrumNote);
			strumNote.playAnim('static', true);
		}
	}
	
	/**
	 * Update animaciones
	 */
	public function update():Void
	{
		strums.forEach(function(spr:FlxSprite)
		{
			if (Std.isOfType(spr, StrumNote))
			{
				var strumNote:StrumNote = cast(spr, StrumNote);
				// El auto-reset ahora lo maneja el método update() de StrumNote
				// No necesitamos hacer nada aquí
			}
		});
	}
	
	/**
	 * Cambiar visibilidad del grupo
	 */
	public function setVisible(visible:Bool):Void
	{
		isVisible = visible;
		data.visible = visible;
		
		strums.forEach(function(spr:FlxSprite)
		{
			spr.visible = visible;
		});
	}
	
	/**
	 * Mover grupo a nueva posición
	 */
	public function setPosition(x:Float, y:Float):Void
	{
		data.x = x;
		data.y = y;
		
		var i:Int = 0;
		strums.forEach(function(spr:FlxSprite)
		{
			spr.x = x + (i * spacing);
			spr.y = y;
			i++;
		});
	}
	
	/**
	 * Cambiar espaciado entre flechas
	 */
	public function setSpacing(newSpacing:Float):Void
	{
		spacing = newSpacing;
		data.spacing = newSpacing;
		
		var i:Int = 0;
		strums.forEach(function(spr:FlxSprite)
		{
			spr.x = data.x + (i * spacing);
			i++;
		});
	}
	
	/**
	 * Destruir
	 */
	public function destroy():Void
	{
		if (strums != null)
		{
			strums.forEach(function(spr:FlxSprite)
			{
				if (spr != null)
					spr.destroy();
			});
			strums.clear();
			strums = null;
		}
		
		leftStrum = null;
		downStrum = null;
		upStrum = null;
		rightStrum = null;
		data = null;
	}
}
