# 🎭 Stage System with JSON

## 📋 Description

A complete system for creating, editing, and managing stages using JSON files. Includes:
- ✅ `Stage.hx` class for loading stages from JSON
- ✅ `StageEditor.hx` visual editor
- ✅ 8 stages converted to JSON
- ✅ Extensible and easy-to-use system

## 🗂️ File Structure

```
assets/
└── data/
└── stages/
├── stage_week1.json
├── spooky.json
├── philly.json
├── limo.json
├── mall.json
├── mallEvil.json
├── school.json
└── schoolEvil.json
```

## 📄 JSON Format

### Basic Structure

```json
{
"name": "stage_week1",
"defaultZoom": 0.9,
"isPixelStage": false,
"gfVersion": "gf",
"boyfriendPosition": [770, 450],
"dadPosition": [100, 100],
"gfPosition": [400, 130],
"cameraBoyfriend": [0, 0],
"cameraDad": [0, 0],

"hideGirlfriend": false,

"elements": []
}
```

### Stage Properties

| Property | Type | Description |

|-----------|------|-------------|

`name` | String | Stage Name |

`defaultZoom` | Float | Default camera zoom |

`isPixelStage` | Bool | Whether it's a pixel art stage |

`gfVersion` | String | GF version to use (optional) |

`boyfriendPosition` | Array<Float> | Boyfriend's [x, y] position |

`dadPosition` | Array<Float> | Opponent's [x, y] position |

`gfPosition` | Array<Float> | Girlfriend's [x, y] position |

`cameraBoyfriend` | Array<Float> | Boyfriend camera offset [x, y] (optional) |

`cameraDad` | Array<Float> | Dad camera offset [x, y] (optional) |

`hideGirlfriend` | Bool | Hide GF (optional) |

`elements` | Array<StageElement> | List of stage elements |


## 🎨 Element Types

### 1. Static Sprite

```json
{ 
"type": "sprite", 
"name": "stageback", 
"asset": "stageback", 
"position": [-600, -200], 
"scrollFactor": [0.9, 0.9], 
"scale": [1.0, 1.0], 
"antialiasing": true, 
"active": false, 
"zIndex": 0
}
```

### 2. Animated Sprite

```json
{ 
"type": "animated", 
"name": "halloweenBG", 
"asset": "halloween_bg", 
"position": [-200, -100], 
"scrollFactor": [1, 1], 
"antialiasing": true, 
"zIndex": 0. 
"animations": [ 
{ 
"name": "idle", 
"prefix": "halloween bg0", 
"framerate": 24, 
"looped": true 
}, 
{ 
"name": "lightning", 
"prefix": "halloweem bg lightning strike", 
"framerate": 24, 
"looped": false 
} 
], 
"firstAnimation": "idle"
}
```

### 3. Sprite Group

```json
{ 
"type": "group", 
"name": "phillyCityLights", 
"zIndex": 2, 
"members": [ 
{ 
"asset": "win0", 
"position": [-10, 0], 
"scrollFactor": [0.3, 0.3], 
"scale": [0.85, 0.85] 
}, 
{ 
"asset": "win1", 
"position": [-10, 0],

"scrollFactor": [0.3, 0.3],

"scale": [0.85, 0.85]

}
]
}
```

### 4. Sound

```json
{
"type": "sound",

"name": "trainSound",

"asset": "train_passes",

"looped": false,

"volume": 1.0
}
```

## 🔧 Element Properties

### Common Properties

| Property | Type | Description |

|-----------|------|-------------|

`type` | String | "sprite", "animated", "group", "sound" |

`name` | String | Unique identifier of the element |

`asset` | String | Path to the asset (without extension) |

`position` | Array<Float> | Position [x, y] |
| `scrollFactor` | Array<Float> | Scroll factor [x, y] (optional) |

| `scale` | Array<Float> | Scale [x, y] (optional) |

| `antialiasing` | Bool | Antialiasing (optional) |

| `active` | Bool | Active on update (optional) |

| `alpha` | Float | Transparency 0-1 (optional) |

| `flipX` | Bool | Flip horizontally (optional) |

| `flipY` | Bool | Flip vertically (optional) |

| `color` | String | Color in hex "#RRGGBB" (optional) |

| `blend` | String | Blend mode (optional) |

| `visible` | Bool | Visibility (optional) |

| `zIndex` | Int | Render order (optional) |

### Animation Properties

```json
{
"name": "idle",
"prefix": "BG idle",
"framerate": 24,
"looped": true,
"indices": [0, 1, 2, 3]
}
```

## 💻 Using the Code

### Loading a Stage into PlayState

```haxe
// Replaces the setCurrentStage() function in PlayState
var currentStage:Stage;

function loadStage(stageName:String):Void
{
currentStage = new Stage(stageName);
add(currentStage);

// Apply properties
defaultCamZoom = currentStage.defaultCamZoom;

// Character positions
boyfriend.setPosition(currentStage.boyfriendPosition.x, currentStage.boyfriendPosition.y);

dad.setPosition(currentStage.dadPosition.x, currentStage.dadPosition.y); 
gf.setPosition(currentStage.gfPosition.x, currentStage.gfPosition.y); 

//GF Version 
if (currentStage.gfVersion != null) 
gfVersion = currentStage.gfVersion; 

if (currentStage.hideGirlfriend) 
gf.visible = false;
}
```

### Access Elements

```haxe
// Get a sprite by name
var halloweenBG = currentStage.getElement("halloweenBG");
if (halloweenBG != null) 
halloweenBG.animation.play("lightning");

// Get a group
var lights = currentStage.getGroup("phillyCityLights");
if (lightts != null)
{
lights.forEach(function(light:FlxSprite)

{
light.visible = false;

});

}

// Get a sound
var trainSound = currentStage.getSound("trainSound");

if (trainSound != null)
trainSound.play();

``

### Custom Callbacks

```haxe
// In create()
currentStage.onBeatHit = function()
{
// Code that runs on each beat

var santa = currentStage.getElement("santa");

if (santa != null)
santa.animation.play('idle', true);

};

currentStage.onUpdate = function(elapsed:Float)
{
// Code that runs every frame
};

// In beatHit()
if (currentStage != null) 
currentStage.beatHit(curBeat);
```

## 🎮 Using the Editor

### Editor Controls

- **I/K** - Move camera up/down
- **J/L** - Move camera left/right
- **Q/E** - Zoom in/out
- **G** - Show/hide grid
- **R** - Reset camera
- **ESC** - Exit

### Editor Tabs

#### 1. Stage
- Configure stage name
- Adjust default zoom
- Check if it's a pixel stage
- Configure GF version
- Hide GF if necessary

#### 2. Elements
- Add new elements
- Configure properties:

- Type (sprite, animated, group, sound)

- Unique name

- Asset path

- Position

- Scroll factor

- Scale

- Z-Index

- Antialiasing

#### 3. Positions
- Adjust character positions
- View Colored placeholders:

- **Cyan**: Boyfriend

- **Red**: Dad/Opponent

- **Magenta**: Girlfriend

- Apply changes in real time

#### 4. Export
- Export complete JSON
- Copy to clipboard
- Save file

## 📝 Stage Examples

### Simple Stage (Week 1)

```json
{
"name": "stage_week1",
"defaultZoom": 0.9,
"isPixelStage": false,
"elements": [

{
"type": "sprite",
"name": "stageback",
"asset": "stageback",
"position": [-600, -200],
"scrollFactor": [0.9, 0.9],
"antialiasing": true,
"zIndex": 0

},

{
"type": "sprite",
"name": "stagefront", 
"asset": "stagefront", 
"position": [-650, 600], 
"scale": [1.1, 1.1], 
"scrollFactor": [0.9, 0.9], 
"antialiasing": true, 
"zIndex": 1 
} 
]
}
```

### Stage with Animations (Spooky)

```json
{ 
"name": "spooky", 
"defaultZoom": 1.05, 
"isPixelStage": false, 
"elements": [ 
{ 
"type": "animated", 
"name": "halloweenBG", 
"asset": "halloween_bg", 
"position": [-200, -100], 
"animations": [ 
{ 
"name": "idle", 
"prefix": "halloween bg0", 
"framerate": 24, 
"looped": true 
}, 
{ 
"name": "lightning", 
"prefix": "halloweem bg lightning strike", 
"framerate": 24, 
"looped": false 
} 
], 
"firstAnimation": "idle" 
} 
]
}
```

### Stage with Groups (Philly)

```json
{ 
"name": "philly", 
"elements": [ 
{ 
"type": "group", 
"name": "phillyCityLights", 
"members": [ 
{ 
"asset": "win0", 
"position": [-10, 0], 
"scrollFactor": [0.3, 0.3] 
}, 
{ 
"asset": "win1", 
"position": [-10, 0], 
"scrollFactor": [0.3, 0.3] 
} 
] 
} 
]
}
```

## 🔄 Migration from PlayState

### Before (Hardcoded code)

```haxe
function setCurrentStage()
{ 
switch(curStage.toLowerCase()) 
{ 
case 'stage_week1': 
{ 
defaultCamZoom = 0.9; 
var bg:FlxSprite = new FlxSprite(-600, -200).loadGraphic(Paths.imageStage('stageback')); 
bg.antialiasing = true; 
bg.scrollFactor.set(0.9, 0.9); 
add(bg); 
// ... more code 
} 
}
}
```

### After (With JSON)

```haxe
function setCurrentStage()
{ 
currentStage = new Stage(curStage); 
add(currentStage); 
defaultCamZoom = currentStage.defaultCamZoom; 

// Apply positions 
boyfriend.setPosition(currentStage.boyfriendPosition.x, currentStage.boyfriendPosition.y); 
// ...
}
```

## 🎯 System Advantages

### ✅ Advantages
1. **Modularity**: Each stage in its own file
2. **Easy to Edit**: You don't need to program to create stages
3. **Visual Editor**: Create and modify stages visually
4. **Reusable**: Easily share stages
5. **Debugging**: Easier to find errors
6. **Versatile**: Supports sprites, animations, groups, and sounds
7. **Organized**: Clean and maintainable code

### 🎨 Use Cases

- Create custom stages without touching code
- Quickly test different configurations
- Share stages with the community
- Better organize the project
- Facilitate modding

## 🛠️ Advanced Features

### Stage Scripts (Future)

```json
{
"name": "my_stage",

"scripts": ["stages/my_stage_script.hx"],
"elements": []
}
```

### Custom Callbacks

```haxe
// Configure stage-specific logic
currentStage.onBeatHit = function()
{
if (currentBeat % 4 == 0)

{
var lights = currentStage.getGroup("lights");

// Change random light

}
};
```

## 📚 Included Stages

1. **stage_week1** - Default Stage (Week 1)
2. **spooky** - Halloween Stage (Week 2)
3. **philly** - City Stage with Train (Week 3)
4. **limo** - Limo Stage (Week 4)
5. **mall** - Christmas Shopping Mall (Week 5)
6. **mallEvil** - Corrupt Shopping Mall (Week 5)
7. **school** - Anime School (Week 6)
8. **schoolEvil** - Anime Evil School (Week 6)
