package funkin.debug;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.addons.ui.*;
import funkin.gameplay.objects.stages.Stage;
import flixel.ui.FlxButton;

class ElementPropertiesDialog extends FlxTypedGroup<FlxSprite>
{
	public var onSave:StageElement->Void;
	public var onCancel:Void->Void;
	
	var bg:FlxSprite;
	var element:StageElement;
	var isAnimated:Bool = false;
	var isGroup:Bool = false;
	var isSound:Bool = false;
	var isCustomClass:Bool = false;
	
	// Input fields
	var nameInput:FlxUIInputText;
	var assetInput:FlxUIInputText;
	var posXStepper:FlxUINumericStepper;
	var posYStepper:FlxUINumericStepper;
	var scrollXStepper:FlxUINumericStepper;
	var scrollYStepper:FlxUINumericStepper;
	var scaleXStepper:FlxUINumericStepper;
	var scaleYStepper:FlxUINumericStepper;
	var alphaStepper:FlxUINumericStepper;
	var zIndexStepper:FlxUINumericStepper;
	var colorInput:FlxUIInputText;
	var blendDropdown:FlxUIDropDownMenu;
	var antialiasingCheckbox:FlxUICheckBox;
	var activeCheckbox:FlxUICheckBox;
	var visibleCheckbox:FlxUICheckBox;
	var flipXCheckbox:FlxUICheckBox;
	var flipYCheckbox:FlxUICheckBox;
	
	// Animated sprite fields
	var animationsList:FlxUIList;
	var firstAnimInput:FlxUIInputText;
	
	// Sound fields
	var volumeStepper:FlxUINumericStepper;
	var loopedCheckbox:FlxUICheckBox;
	
	// Custom class fields
	var classNameInput:FlxUIInputText;
	
	var saveBtn:FlxButton;
	var cancelBtn:FlxButton;
	
	public function new(element:StageElement)
	{
		super();
		
		this.element = element;
		this.isAnimated = (element.type == "animated");
		this.isGroup = (element.type == "group");
		this.isSound = (element.type == "sound");
		this.isCustomClass = (element.type == "custom_class" || element.type == "custom_class_group");
		
		setupUI();
	}
	
	function setupUI():Void
	{
		// Background overlay
		bg = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, 0xAA000000);
		add(bg);
		
		// Dialog box
		var dialog = new FlxSprite(200, 50).makeGraphic(FlxG.width - 400, FlxG.height - 100, 0xFF2a2a3e);
		add(dialog);
		
		var title = new FlxText(220, 60, 0, "Edit Element Properties", 16);
		title.setFormat(null, 16, FlxColor.WHITE, LEFT);
		add(title);
		
		var yPos = 90;
		
		// Name
		add(new FlxText(220, yPos, 0, "Name:"));
		nameInput = new FlxUIInputText(350, yPos, 300, element.name);
		add(nameInput);
		yPos += 30;
		
		if (!isSound)
		{
			// Asset
			add(new FlxText(220, yPos, 0, "Asset Path:"));
			assetInput = new FlxUIInputText(350, yPos, 300, element.asset);
			add(assetInput);
			yPos += 30;
			
			// Position
			add(new FlxText(220, yPos, 0, "Position X:"));
			posXStepper = new FlxUINumericStepper(350, yPos, 10, element.position[0], -5000, 5000, 0);
			add(posXStepper);
			
			add(new FlxText(520, yPos, 0, "Y:"));
			posYStepper = new FlxUINumericStepper(550, yPos, 10, element.position[1], -5000, 5000, 0);
			add(posYStepper);
			yPos += 30;
			
			// Scroll Factor
			add(new FlxText(220, yPos, 0, "Scroll Factor X:"));
			scrollXStepper = new FlxUINumericStepper(350, yPos, 0.1, element.scrollFactor[0], 0, 2, 1);
			add(scrollXStepper);
			
			add(new FlxText(520, yPos, 0, "Y:"));
			scrollYStepper = new FlxUINumericStepper(550, yPos, 0.1, element.scrollFactor[1], 0, 2, 1);
			add(scrollYStepper);
			yPos += 30;
			
			// Scale
			add(new FlxText(220, yPos, 0, "Scale X:"));
			scaleXStepper = new FlxUINumericStepper(350, yPos, 0.1, element.scale[0], 0.1, 10, 1);
			add(scaleXStepper);
			
			add(new FlxText(520, yPos, 0, "Y:"));
			scaleYStepper = new FlxUINumericStepper(550, yPos, 0.1, element.scale[1], 0.1, 10, 1);
			add(scaleYStepper);
			yPos += 30;
			
			// Alpha
			add(new FlxText(220, yPos, 0, "Alpha:"));
			alphaStepper = new FlxUINumericStepper(350, yPos, 0.1, element.alpha, 0, 1, 1);
			add(alphaStepper);
			yPos += 30;
			
			// Z Index
			add(new FlxText(220, yPos, 0, "Z Index:"));
			zIndexStepper = new FlxUINumericStepper(350, yPos, 1, element.zIndex != null ? element.zIndex : 0, -100, 100, 0);
			add(zIndexStepper);
			yPos += 30;
			
			// Color
			add(new FlxText(220, yPos, 0, "Color (hex):"));
			colorInput = new FlxUIInputText(350, yPos, 100, element.color);
			add(colorInput);
			yPos += 30;
			
			// Blend Mode
			add(new FlxText(220, yPos, 0, "Blend Mode:"));
			blendDropdown = new FlxUIDropDownMenu(350, yPos, 
				FlxUIDropDownMenu.makeStrIdLabelArray(["normal", "add", "multiply", "screen"]),
				function(blend:String) {
					// callback
				});
			blendDropdown.selectedLabel = element.blend;
			add(blendDropdown);
			yPos += 30;
			
			// Checkboxes
			antialiasingCheckbox = new FlxUICheckBox(220, yPos, null, null, "Antialiasing", 100);
			antialiasingCheckbox.checked = element.antialiasing;
			add(antialiasingCheckbox);
			
			activeCheckbox = new FlxUICheckBox(340, yPos, null, null, "Active", 100);
			activeCheckbox.checked = element.active;
			add(activeCheckbox);
			
			visibleCheckbox = new FlxUICheckBox(440, yPos, null, null, "Visible", 100);
			visibleCheckbox.checked = element.visible;
			add(visibleCheckbox);
			yPos += 30;
			
			flipXCheckbox = new FlxUICheckBox(220, yPos, null, null, "Flip X", 100);
			flipXCheckbox.checked = element.flipX;
			add(flipXCheckbox);
			
			flipYCheckbox = new FlxUICheckBox(340, yPos, null, null, "Flip Y", 100);
			flipYCheckbox.checked = element.flipY;
			add(flipYCheckbox);
			yPos += 30;
		}
		
		// Animated sprite specific
		if (isAnimated)
		{
			add(new FlxText(220, yPos, 0, "First Animation:"));
			firstAnimInput = new FlxUIInputText(350, yPos, 200, element.firstAnimation);
			add(firstAnimInput);
			yPos += 30;
			
			add(new FlxText(220, yPos, 0, "Animations (add via code for now)"));
			yPos += 20;
		}
		
		// Sound specific
		if (isSound)
		{
			add(new FlxText(220, yPos, 0, "Sound Asset:"));
			assetInput = new FlxUIInputText(350, yPos, 300, element.asset);
			add(assetInput);
			yPos += 30;
			
			add(new FlxText(220, yPos, 0, "Volume:"));
			volumeStepper = new FlxUINumericStepper(350, yPos, 0.1, element.volume != null ? element.volume : 1, 0, 1, 1);
			add(volumeStepper);
			yPos += 30;
			
			loopedCheckbox = new FlxUICheckBox(220, yPos, null, null, "Looped", 100);
			loopedCheckbox.checked = element.looped != null ? element.looped : false;
			add(loopedCheckbox);
			yPos += 30;
		}
		
		// Custom class specific
		if (isCustomClass)
		{
			add(new FlxText(220, yPos, 0, "Class Name:"));
			classNameInput = new FlxUIInputText(350, yPos, 200, element.className);
			add(classNameInput);
			yPos += 30;
			
			add(new FlxText(220, yPos, 0, "Examples: BackgroundGirls, BackgroundDancer"));
			yPos += 30;
		}
		
		// Buttons
		saveBtn = new FlxButton(FlxG.width - 450, FlxG.height - 100, "Save", save);
		cancelBtn = new FlxButton(FlxG.width - 350, FlxG.height - 100, "Cancel", cancel);
		
		add(saveBtn);
		add(cancelBtn);
	}
	
	function save():Void
	{
		// Update element with values
		element.name = nameInput.text;
		
		if (!isSound)
		{
			element.asset = assetInput.text;
			element.position = [posXStepper.value, posYStepper.value];
			element.scrollFactor = [scrollXStepper.value, scrollYStepper.value];
			element.scale = [scaleXStepper.value, scaleYStepper.value];
			element.alpha = alphaStepper.value;
			element.zIndex = Std.int(zIndexStepper.value);
			element.color = colorInput.text;
			element.blend = blendDropdown.selectedLabel;
			element.antialiasing = antialiasingCheckbox.checked;
			element.active = activeCheckbox.checked;
			element.visible = visibleCheckbox.checked;
			element.flipX = flipXCheckbox.checked;
			element.flipY = flipYCheckbox.checked;
		}
		
		if (isAnimated)
		{
			element.firstAnimation = firstAnimInput.text;
		}
		
		if (isSound)
		{
			element.asset = assetInput.text;
			element.volume = volumeStepper.value;
			element.looped = loopedCheckbox.checked;
		}
		
		if (isCustomClass)
		{
			element.className = classNameInput.text;
		}
		
		if (onSave != null)
			onSave(element);
	}
	
	function cancel():Void
	{
		if (onCancel != null)
			onCancel();
	}
}
