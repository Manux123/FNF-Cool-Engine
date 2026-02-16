# JSON Character System

This system allows you to define characters using JSON files instead of hardcoded code, saving space and making it easier to create new characters.

## JSON Structure

```json
{
	"path": "folder/sprite",
	"isPlayer": false,
	"antialiasing": true,
	"scale": 1.0,
	"flipX": false,
	"pixelChar": false,
	"isTxt": false, // Optional, only Spirit Sprite for now
	"animations": [
		{
			"name": "idle",
			"prefix": "Idle Animation",
			"framerate": 24,
			"looped": false,
			"offsetX": 0,
			"offsetY": 0,
			"indices": [0, 1, 2, 3],  // Optional, only if you need specific indices
			"specialAnim": false // Optional, not necessary
		}
	]
}
```

## Main Fields

### CharacterData
- **path**: Path to the character's spritesheet (without extension)
- **isPlayer**: Whether the character is the player (true/false)
- **antialiasing**: Enable smoothing (true/false)
- **scale**: Character scale (1.0 = normal size)
- **specialAnim**: If it has special animations (true/false)
- **flipX**: Flip horizontally (optional)
- **pixelChar**: If it's a pixelated character (optional, activates pixel zoom)
- **animations**: Animation array

### AnimData
- **name**: Animation name (used in code)
- **prefix**: Animation prefix in the XML
- **framerate**: Animation speed
- **looped**: Whether the animation repeats
- **offsetX**: Horizontal offset
- **offsetY**: Vertical offset
- **indices**: Array of specific indices (optional, for using addByIndices)

## Converted Characters

All original characters have been converted to JSON:

### Boyfriend Variants
- `bf.json` - Normal Boyfriend
- `bf-christmas.json` - Christmas Boyfriend
- `bf-car.json` - Boyfriend in the car
- `bf-pixel.json` - Pixelated Boyfriend
- `bf-pixel-dead.json` - Dead pixelated Boyfriend
- `bf-pixel-enemy.json` - Enemy pixelated Boyfriend

### Girlfriend Variants
- `gf.json` - Normal Girlfriend
- `gf-christmas.json` - Christmas Girlfriend
- `gf-car.json` - Girlfriend in the car
- `gf-pixel.json` - Pixelated Girlfriend

### Other Characters
- `dad.json` - Daddy Dearest (uses text animation system)
- `mom.json` - Mommy Mearest
- `mom-car.json` - Mom in the car
- `spooky.json` - Spooky Kids
- `pico.json` - Pico
- `monster.json` - Monster/Lemon Demon
- `monster-christmas.json` - Christmas Monster
- `senpai.json` - Senpai
- `senpai-angry.json` - Angry Senpai
- `spirit.json` - Spirit
- `parents-christmas.json` - Parents Christmas

## Usage in Code

The new simplified Character.hx automatically loads the corresponding JSON:

```haxe
var character = new Character(100, 100, "bf", true);
```

This will search for the `bf.json` file in the characters folder.

## Advantages

1. **Less code**: Removed ~370 lines from the switch case
2. **More organized**: Each character has its own file
3. **Easy to modify**: Just edit the JSON to change animations or offsets
4. **Easy to add**: Create a new JSON and you're done

## Creating a New Character

1. Create a JSON file with the character's name
2. Fill in the data according to the structure
3. Place the file in the characters folder
4. Done! The game will load it automatically

## Important Notes

- Offsets can still be loaded from text files using `loadOffsetFile()`
- The "dad" character still uses the legacy text animation system
- Animations with `indices` use `addByIndices()` automatically
- Animations without `indices` use `addByPrefix()`

## Compatibility

This system is fully compatible with existing code. All characters work exactly the same as before, they're just now defined in JSON.