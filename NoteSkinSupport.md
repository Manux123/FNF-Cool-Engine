# 🎨 Improved Note Skins and Splashes System

## 📋 Main Features

### ✨ What's New in the Improved System

1. **Configurable Animations**: Each skin can define its own animations
2. **Independent Splashes**: Splashes are completely separate from note skins
3. **Fallback System**: If an animation doesn't exist, it automatically uses the default one
4. **Multiple Variations**: Splashes can have multiple random animations
5. **Improved Auto-Detection**: Automatically detects skins and splashes without configuration

## 🗂️ Carpet Structure

```
assets/
├── skins/ ← NOTE SKINS
│ ├── Arrows/
│ │ ├── skin.json ← Configuration of the Skin
│ │ ├── notes.png ← Notes Texture
│ │ ├── notes.xml ← Sparrow Atlas
│ │ └── notes-pixel.png ← Pixel Version (Optional)
│ │
│ ├── Circles/
│ │ └── ...
│ │
│ └── YourCustomSkin/
│ └── ...
│
└── Splashes/ ← Splashes (Independent)
├── Default/
│ ├── splash.json ← Splash Settings
│ ├── splash.png ← Splash Texture
│ └── splash.xml ← Atlas Sparrow
│
├── Epic/
│ └── ...
│
└── YourCustomSplash/
└──...
```

## 🎮 Basic Usage

### Initialize the System

```axe
// In Main.hx or at the start of the game
NoteSkinSystem.init();
```

### Change Note Skin

```axe
NoteSkinSystem.setSkin("Arrows");

```

### Change splash (standalone)

```haxe
NoteSkinSystem.setSplash("Epic");
```

### Get available lists

```haxe
var skins:Array<String> = NoteSkinSystem.getSkinList();
var splashes:Array<String> = NoteSkinSystem.getSplashList();

trace("Available skins:");
for (skin in skins) trace(" - " + skin);

trace("Available splashes:");
for (splash in splashes) trace(" - " + splash);
```

## 📝 JSON Configuration - Notes Skins

### Complete skin.json Structure

```json
{
"name": "Custom Skin",
"author": "Your Name",
"description": "My awesome notes skin",

"normal": {
"path": "skins/custom/notes",
"type": "sparrow",
"scale": 0.7,
"antialiasing": true
},

"pixel": {
"path": "skins/custom/notes-pixel",
"type": "image",
"antialiasing": false
},

"animations": {
"left": "purple note",
"down": "blue note",
"up": "green note",
"right": "red note",

"leftHold": "press and hold purple",
"downHold": "press and hold blue",
"upHold": "press and hold green",
"rightHold": "hold red",

"leftHoldEnd": "purple tail",
"downHoldEnd": "blue tail",
"upHoldEnd": "green tail",
"rightHoldEnd": "red tail",

"strumLeft": "left arrow",
"strumDown": "down arrow",
"strumUp": "up arrow",
"strumRight": "right arrow",

"strumLeftPress": "left press",
"strumDownPress": "down press",
"strumUpPress": "up press",
"strumRightPress": "right press",

"strumLeftConfirm": "left confirm",
"strumDownConfirm": "down confirm",
"strumUpConfirm": "up confirm",
"strumRightConfirm": "right confirm"
}
}
```

### "normal" and "pixel" fields

- **path** (required): Path to the file without the .png extension
- **type** (optional): "sparrow", "packer", or "image" (default: "sparrow")
- **scale** (optional): Sprite scale (default: 0.7 for normal, 1.0 for pixel)
- **antialiasing** (optional): True/False (default: True for normal, False for pixel)

### "Animations" fields (all optional)

If you do not define an animation, the system uses the default FNF animation.

**Individual Notes:**
- Left, Down, Up, Right

**Sustain:**
- Left Hold, Down Hold, Up Hold, Right Hold

**End of Sustain:**
- Left Hold End, Down Hold End, Up Hold End, Right Hold End

**Static Strums:**
- Left Strum, Down Strum, Up Strum, Right Strum

**Pressed Strums:**
- Left Press Strum, Down Press Strum, Up Press Strum, Right Press Strum

**Confirmed Strums:**
- Left Confirm Strum, Down Confirm Strum, Up Confirm Strum, Right Confirm Strum

## 📝 Settings JSON - Splashes

### Full structure of splash.json

```json
{
"name": "Epic Splash",
"author": "Your name",
"description": "Amazing splash effects",

"assets": {
"path": "splashes/epic/splash",
"type": "sparrow",
"scale": 1.0,
"antialiasing": true,
"offset": [0, 0]
},

"animations": {
"left": [
"purple splash 1",
"purple splash 2",
"purple splash 3"
]
"down": [
"blue splash 1",
"blue splash 2"
]
"up": [
"green splash 1",
"green splash 2",
"green splash 3"
]
"right": [
"red splash" 1"
],
"framerate": 24,
"randomFramerateRange": 3
}
}
```

### Assets Fields

- **path** (required): Path to the file without the .png extension
- **type** (optional): "sparrow", "packer", or "image" (default: "sparrow")
- **scale** (optional): Sprite scale (default: 1.0)
- **antialiasing** (optional): true
/false (default: true)
- **offset** (optional): [x, y] offset for positioning (default: [0, 0])

### Animations Fields

- **left, down, up, right** (required): String arrays with animation names

- You can have multiple animations per direction

- One will be chosen randomly each time

- **framerate** (optional): Base framerate for animations (default: 24)

- **randomFramerateRange** (optional): Random range to vary the framerate (±N frames)

## 🎨 Configuration Examples

### Example 1: Minimalist Skin

```json
{
"name": "Simple Arrows",
"author": "Me",
"normal": {
"path": "skins/simple/notes",
"type": "sparrow"

}
}
```

The system will use default animations from FNF.

### Example 2: Skin with Custom Animations

```json
{ 
"name": "Custom Arrows", 
"author": "Me", 
"normal": { 
"path": "skins/custom/notes", 
"type": "sparrow" 
}, 
"animations": { 
"left": "my_purple_note", 
"down": "my_blue_note", 
"up": "my_green_note", 
"right": "my_red_note" 
}
}
```

You only define the animations you need to change.

### Example 3: Simple Splash

```json
{ 
"name": "Basic Splash", 
"author": "Me", 
"assets": { 
"path": "splashes/basic/splash", 
"type": "sparrow" 
}, 
"animations": { 
"left": ["splash purple"], 
"down": ["splash blue"], 
"up": ["splash green"], 
"right": ["splash red"] 
}
}
```

Only one animation per direction.

### Example 4: Splash with Variations

```json
{ 
"name": "Varied Splash", 
"author": "Me", 
"assets": { 
"path": "splashes/varied/splash", 
"type": "sparrow" 
}, 
"animations": { 
"left": ["purple1", "purple2", "purple3"], 
"down": ["blue1", "blue2"], 
"up": ["green1", "green2", "green3"], 
"right": ["red1", "red2", "red3"], 
"framerate": 30, 
"randomFramerateRange": 5 
}
}
```

Multiple random animations with variable framerate.

## 🔧 Integration in Your Code

### In PlayState.hx

**BEFORE:**
```haxe
var babyArrow:StrumNote = new StrumNote(0, strumLine.y);
```

**NOW:**
```haxe
var babyArrow:StrumNote = new StrumNote(0, strumLine.y, i);
```

### Create NoteSplash

```haxe
// Use the current system splash screen
var splash:NoteSplash = new NoteSplash(x, y, direction);

// Or use a specific splash screen
var epicSplash:NoteSplash = new NoteSplash(x, y, direction, "Epic");

```

## 🎛️ Options Menu

Implementation example:

```haxe
class NoteSkinOptions extends MusicBeatState
{ 
var skinIndex:Int = 0; 
var splashIndex:Int = 0; 

var skins:Array<String>; 
var splashes:Array<String>; 

var skinText:FlxText; 
var splashText:FlxText; 

override function create() 
{ 
NoteSkinSystem.init(); 

skins = NoteSkinSystem.getSkinList(); 
splashes = NoteSkinSystem.getSplashList(); 

skinIndex = skins.indexOf(NoteSkinSystem.currentSkin); 
splashIndex = splashes.indexOf(NoteSkinSystem.currentSplash); 

skinText = new FlxText(0, 100, 0, "Note Skin: " + skins[skinIndex]); 
splashText = new FlxText(0, 150, 0, "Splash: " + splashes[splashIndex]); 

add(skinText); 
add(splashText); 

super.create(); 
} 

override function update(elapsed:Float) 
{ 
// Change skin 
if (controls.LEFT_P) 
{ 
skinIndex--; 
if (skinIndex < 0) skinIndex = skins.length - 1; 
changeSkin(); 
} 
if (controls.RIGHT_P) 
{ 
skinIndex++; 
if (skinIndex >= skins.length) skinIndex = 0; 
changeSkin(); 
} 

// Change splash 
if (controls.UP_P) 
{ 
splashIndex--; 
if (splashIndex < 0) splashIndex = splashes.length - 1; 
changeSplash(); 
} 
if (controls.DOWN_P) 
{ 
splashIndex++; 
if (splashIndex >= splashes.length) splashIndex = 0; 
changeSplash(); 
} 

super.update(elapsed); 
} 

function changeSkin() 
{ 
NoteSkinSystem.setSkin(skins[skinIndex]); 
skinText.text = "Note Skin: " + skins[skinIndex]; 
} 

function changeSplash() 
{ 
NoteSkinSystem.setSplash(splashes[splashIndex]); 
splashText.text = "Splash: " + splashes[splashIndex]; 
}
}
```

## 🔍 Fallback System

The system has multiple levels of fallback to prevent errors:

1. **Animations not found** → Uses default FNF animations
2. **Skin not found** → Uses "Default" skin
3. **Splash not found** → Uses "Default" splash
4. **File does not exist** → Loads default assets
5. **Malformed JSON** → Ignores and continues with auto-detection

## 📊 Advantages of the New System

### Before (Old System)
❌ Splashes tied to the notes skin
❌ Hardcoded animations
❌ Required .txt files
❌ No fallback system
❌ Frequent errors if a file is missing

### Now (New System)