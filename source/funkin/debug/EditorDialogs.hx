package funkin.debug;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.ui.FlxButton;
import sys.FileSystem;
import sys.io.File;
import funkin.gameplay.objects.stages.Stage.StageAnimation;

class AddElementDialog extends FlxTypedGroup<FlxSprite>
{
	public var onElementTypeSelected:String->Void;
	public var onCancel:Void->Void;
	
	var bg:FlxSprite;
	
	public function new()
	{
		super();
		setupUI();
	}
	
	function setupUI():Void
	{
		// Background overlay
		bg = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, 0xAA000000);
		add(bg);
		
		// Dialog box
		var dialog = new FlxSprite(FlxG.width / 2 - 200, FlxG.height / 2 - 250).makeGraphic(400, 500, 0xFF2a2a3e);
		add(dialog);
		
		var title = new FlxText(FlxG.width / 2 - 180, FlxG.height / 2 - 240, 0, "Select Element Type", 20);
		title.setFormat(null, 20, FlxColor.WHITE, CENTER);
		add(title);
		
		var yPos = FlxG.height / 2 - 200;
		
		// Sprite Simple
		var spriteBtn = new FlxButton(FlxG.width / 2 - 150, yPos, "Sprite Simple", () -> selectType("sprite"));
		spriteBtn.loadGraphic("assets/images/ui/button.png");
		add(spriteBtn);
		add(createDescription(FlxG.width / 2 - 150, yPos + 25, "Imagen estática básica"));
		yPos += 60;
		
		// Sprite Animado
		var animatedBtn = new FlxButton(FlxG.width / 2 - 150, yPos, "Sprite Animado", () -> selectType("animated"));
		add(animatedBtn);
		add(createDescription(FlxG.width / 2 - 150, yPos + 25, "Sprite con animaciones"));
		yPos += 60;
		
		// Grupo
		var groupBtn = new FlxButton(FlxG.width / 2 - 150, yPos, "Grupo", () -> selectType("group"));
		add(groupBtn);
		add(createDescription(FlxG.width / 2 - 150, yPos + 25, "Colección de sprites"));
		yPos += 60;
		
		// Sonido
		var soundBtn = new FlxButton(FlxG.width / 2 - 150, yPos, "Sonido", () -> selectType("sound"));
		add(soundBtn);
		add(createDescription(FlxG.width / 2 - 150, yPos + 25, "Audio ambiental"));
		yPos += 60;
		
		// Clase Custom
		var customBtn = new FlxButton(FlxG.width / 2 - 150, yPos, "Clase Custom", () -> selectType("custom_class"));
		add(customBtn);
		add(createDescription(FlxG.width / 2 - 150, yPos + 25, "Instancia de clase personalizada"));
		yPos += 60;
		
		// Grupo de Clases Custom
		var customGroupBtn = new FlxButton(FlxG.width / 2 - 150, yPos, "Grupo Custom", () -> selectType("custom_class_group"));
		add(customGroupBtn);
		add(createDescription(FlxG.width / 2 - 150, yPos + 25, "Múltiples instancias de clase"));
		yPos += 60;
		
		// Cancel button
		var cancelBtn = new FlxButton(FlxG.width / 2 - 50, yPos + 20, "Cancel", cancel);
		add(cancelBtn);
	}
	
	function createDescription(x:Float, y:Float, text:String):FlxText
	{
		var desc = new FlxText(x, y, 300, text, 10);
		desc.setFormat(null, 10, 0xFF888888, CENTER);
		return desc;
	}
	
	function selectType(type:String):Void
	{
		if (onElementTypeSelected != null)
			onElementTypeSelected(type);
	}
	
	function cancel():Void
	{
		if (onCancel != null)
			onCancel();
	}
}

class FileManagerDialog extends FlxTypedGroup<FlxSprite>
{
	public var onFileSelected:String->Void;
	public var onCancel:Void->Void;
	
	var bg:FlxSprite;
	var stageName:String;
	var fileType:String; // "image", "sound", "script"
	
	public function new(stageName:String, fileType:String = "image")
	{
		super();
		this.stageName = stageName;
		this.fileType = fileType;
		setupUI();
	}
	
	function setupUI():Void
	{
		// Background overlay
		bg = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, 0xAA000000);
		add(bg);
		
		// Dialog box
		var dialog = new FlxSprite(200, 100).makeGraphic(FlxG.width - 400, FlxG.height - 200, 0xFF2a2a3e);
		add(dialog);
		
		var title = new FlxText(220, 120, 0, 'Select ${fileType.toUpperCase()} File', 18);
		title.setFormat(null, 18, FlxColor.WHITE, LEFT);
		add(title);
		
		var info = new FlxText(220, 150, 600, 
			'Files will be copied to: assets/stages/${stageName}/${fileType}s/\n' +
			'Click "Browse" to select a file from your computer.');
		info.setFormat(null, 12, 0xFFCCCCCC, LEFT);
		add(info);
		
		// Browse button
		var browseBtn = new FlxButton(220, 220, "Browse Computer", browseFile);
		add(browseBtn);
		
		// Cancel button
		var cancelBtn = new FlxButton(350, 220, "Cancel", cancel);
		add(cancelBtn);
	}
	
	function browseFile():Void
	{
		#if sys
		// Aquí se usaría lime.ui.FileDialog para abrir el explorador de archivos
		// Por ahora simulamos con un path de ejemplo
		
		// En producción:
		// var dialog = new lime.ui.FileDialog();
		// dialog.onSelect.add(function(path:String) {
		//     copyFileToStageFolder(path);
		// });
		// dialog.browse();
		
		// Simulación:
		trace("File dialog would open here. User would select a file.");
		trace("Selected file would be copied to: assets/stages/" + stageName + "/" + fileType + "s/");
		
		if (onFileSelected != null)
			onFileSelected("example_file.png");
		#else
		trace("File browsing not available on this platform");
		#end
	}
	
	function copyFileToStageFolder(sourcePath:String):Void
	{
		#if sys
		var fileName = sourcePath.split("/").pop().split("\\").pop();
		var destFolder = 'assets/stages/${stageName}/${fileType}s';
		var destPath = '$destFolder/$fileName';
		
		// Crear carpeta si no existe
		if (!FileSystem.exists(destFolder))
		{
			FileSystem.createDirectory(destFolder);
		}
		
		// Copiar archivo
		try
		{
			File.copy(sourcePath, destPath);
			trace('File copied to: $destPath');
			
			if (onFileSelected != null)
				onFileSelected(fileName);
		}
		catch (e:Dynamic)
		{
			trace('Error copying file: $e');
		}
		#end
	}
	
	function cancel():Void
	{
		if (onCancel != null)
			onCancel();
	}
}

class AnimationEditorDialog extends FlxTypedGroup<FlxSprite>
{
	public var onSave:Array<StageAnimation>->Void;
	public var onCancel:Void->Void;
	
	var bg:FlxSprite;
	var animations:Array<StageAnimation>;
	
	public function new(animations:Array<StageAnimation>)
	{
		super();
		this.animations = animations != null ? animations : [];
		setupUI();
	}
	
	function setupUI():Void
	{
		// Background overlay
		bg = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, 0xAA000000);
		add(bg);
		
		// Dialog box
		var dialog = new FlxSprite(150, 80).makeGraphic(FlxG.width - 300, FlxG.height - 160, 0xFF2a2a3e);
		add(dialog);
		
		var title = new FlxText(170, 100, 0, "Edit Animations", 18);
		title.setFormat(null, 18, FlxColor.WHITE, LEFT);
		add(title);
		
		// Add animation button
		var addBtn = new FlxButton(170, 130, "Add Animation", addAnimation);
		add(addBtn);
		
		// List animations
		var yPos = 170;
		for (i in 0...animations.length)
		{
			var anim = animations[i];
			
			var animBg = new FlxSprite(170, yPos).makeGraphic(FlxG.width - 340, 120, 0xFF3a3a4e);
			add(animBg);
			
			add(new FlxText(180, yPos + 5, 0, 'Animation ${i + 1}'));
			
			add(new FlxText(180, yPos + 25, 0, "Name:"));
			var nameInput = new flixel.addons.ui.FlxUIInputText(250, yPos + 25, 150, anim.name);
			add(nameInput);
			
			add(new FlxText(180, yPos + 55, 0, "Prefix:"));
			var prefixInput = new flixel.addons.ui.FlxUIInputText(250, yPos + 55, 150, anim.prefix);
			add(prefixInput);
			
			add(new FlxText(180, yPos + 85, 0, "FPS:"));
			var fpsStepper = new flixel.addons.ui.FlxUINumericStepper(250, yPos + 85, 1, 
				anim.framerate != null ? anim.framerate : 24, 1, 120, 0);
			add(fpsStepper);
			
			var loopCheckbox = new flixel.addons.ui.FlxUICheckBox(400, yPos + 85, null, null, "Loop", 50);
			loopCheckbox.checked = anim.looped != null ? anim.looped : false;
			add(loopCheckbox);
			
			var deleteBtn = new FlxButton(FlxG.width - 380, yPos + 10, "Delete", () -> {
				deleteAnimation(i);
			});
			add(deleteBtn);
			
			yPos += 130;
		}
		
		// Save and Cancel buttons
		var saveBtn = new FlxButton(FlxG.width - 350, FlxG.height - 120, "Save", save);
		var cancelBtn = new FlxButton(FlxG.width - 250, FlxG.height - 120, "Cancel", cancel);
		
		add(saveBtn);
		add(cancelBtn);
	}
	
	function addAnimation():Void
	{
		var newAnim:StageAnimation = {
			name: 'anim_${animations.length}',
			prefix: "",
			framerate: 24,
			looped: false
		};
		
		animations.push(newAnim);
		
		// Refresh UI
		clear();
		setupUI();
	}
	
	function deleteAnimation(index:Int):Void
	{
		animations.splice(index, 1);
		
		// Refresh UI
		clear();
		setupUI();
	}
	
	function save():Void
	{
		if (onSave != null)
			onSave(animations);
	}
	
	function cancel():Void
	{
		if (onCancel != null)
			onCancel();
	}
}
