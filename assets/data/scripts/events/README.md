# Softcoded Chart Events — Guide for Modders

## What is this?

The chart editor event system is 100% softcoded. You can define new events without touching the engine source code. You only need:

1. A JSON file that defines how the event looks in the editor (name, color, fields).
2. An HScript (.hx) file that defines what the event does during gameplay.

---

## Folder Structure

mods/
└── yourMod/
    ├── data/
    │   └── events/
    │       ├── My Epic Event.json        ← Editor UI for this event
    │       ├── Another Event.json
    │       └── shared/                   ← Events available in ALL mods
    │           └── Shared Event.json
    └── scripts/
        └── events/
            └── My Epic Event.hx          ← Event gameplay logic

> data/events/ — events specific to your mod.  
> data/events/shared/ — events loaded in ALL mods (useful for libraries).

---

## JSON Format

```json
{
  "color": "#FF88CC",
  "params": [
    {
      "name": "Target",
      "type": "DropDown(bf,dad,gf)",
      "defaultValue": "bf"
    },
    {
      "name": "Duration",
      "type": "Float(0.0,10.0)",
      "defaultValue": "1.0"
    },
    {
      "name": "Loop",
      "type": "Bool",
      "defaultValue": "false"
    },
    {
      "name": "Custom Text",
      "type": "String",
      "defaultValue": "hello"
    },
    {
      "name": "Intensity",
      "type": "Int(1,100)",
      "defaultValue": "10"
    },
    {
      "name": "Color",
      "type": "Color",
      "defaultValue": "#FFFFFF"
    }
  ]
}
```

### Available Field Types

| JSON Type         | Description                   |
| ----------------- | ----------------------------- |
| "String"          | Free text field               |
| "Bool"            | true / false dropdown         |
| "Int"             | Integer without limits        |
| "Int(min,max)"    | Integer with range            |
| "Float"           | Decimal number without limits |
| "Float(min,max)"  | Decimal number with range     |
| "DropDown(a,b,c)" | Dropdown with fixed options   |
| "Color"           | Hex color field (#RRGGBB)     |

---

## HScript Format

Parameter values arrive in v1 and v2 separated by "|".

```hscript
// assets/scripts/events/My Epic Event.hx
// Or: mods/yourMod/scripts/events/My Epic Event.hx

function onEvent(name, v1, v2, time)
{
    if (name != 'My Epic Event') return null;

    // If the event has 3 params: target|duration|loop
    var parts  = v1.split('|');
    var target   = parts[0];          // "bf" / "dad" / "gf"
    var duration = Std.parseFloat(parts[1]);  // 1.0
    var loop     = parts[2] == 'true';        // false

    trace('My event: target=' + target + ' dur=' + duration);

    return true;   // true = cancels engine built-in handler
                   // null = lets the engine process it too
}
```

### Available HScript Callbacks

| Callback                        | When it is called                     |
| ------------------------------- | ------------------------------------- |
| onEvent(name,v1,v2,time)        | Every time an event triggers          |
| onAltAnim(target,value)         | When "Alt Anim" event happens         |
| onCharacterChange(slot,char)    | When "Change Character" event happens |
| onSingAnim(char,animName,force) | Before playing a singing animation    |
| onBeatHit(beat)                 | Every beat                            |
| onStepHit(step)                 | Every step                            |
| onCreate()                      | When the script loads                 |

---

## Multiple Parameter Serialization

When an event has more than 2 parameters, values are serialized inside v1 separated by "|":

```
event.value = "bf|1.5|true|#FF0000"
              ↓   ↓    ↓    ↓
              p1  p2   p3   p4
```

```hscript
var parts  = v1.split('|');
var param1 = parts[0];               // "bf"
var param2 = Std.parseFloat(parts[1]); // 1.5
var param3 = parts[2] == 'true';     // true
var param4 = parts[3];               // "#FF0000"
```

---

## Events Included in the Engine

These events already exist and you don’t need to create JSON files for them:

| Event            | Description                         |
| ---------------- | ----------------------------------- |
| Camera Follow    | Change camera target                |
| BPM Change       | Change BPM in real time             |
| Camera Zoom      | Camera zoom                         |
| Camera Shake     | Camera shake                        |
| Camera Flash     | Screen flash                        |
| Play Anim        | Play a character animation          |
| Alt Anim         | Enable/disable alt-idle mode        |
| Change Character | Change character model in real time |
| HUD Visible      | Show/hide HUD (with fade)           |
| Play Video       | Play video (mid-song or cutscene)   |
| Hey!             | BF “hey” animation / GF cheer       |
| Play Sound       | Play a sound                        |
| Add Health       | Modify player health                |
| Run Script       | Call an HScript function            |
| End Song         | Immediately end the song            |
