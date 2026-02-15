Here is the full translation into English:

---

# Enhanced Script System – Documentation

This system allows you to **cancel events** and **fully override functions** from scripts, giving you total control over the game's behavior.

---

## 📋 Table of Contents

1. [Event Cancellation](#event-cancellation)
2. [Function Overrides](#function-overrides)
3. [Priority System](#priority-system)
4. [Available Events](#available-events)
5. [Practical Examples](#practical-examples)
6. [Complete API](#complete-api)

---

## 🚫 Event Cancellation

### What is it?

It allows you to **stop the execution** of specific events by returning `true` from your script.

### How it works

```javascript
function onCameraZoom(amount, duration) {
    // Your custom code here
    trace('Camera zoom intercepted!');
    
    // Returning true cancels the original event
    return true; // EVENT CANCELED ❌
}
```

### Conditional cancellation

```javascript
function onHeyEvent(target) {
    if (target == 'bf') {
        // Cancel only for BF
        return true; // CANCELED
    }
    
    // Allow for others
    return false; // CONTINUE ✅
}
```

### Available helpers

```javascript
// Instead of return true/false, you can use:
return cancelEvent();   // Equivalent to return true
return continueEvent(); // Equivalent to return false
```

---

## 🔧 Function Overrides

### What is it?

It allows you to **completely replace** a game function with your own implementation.

### Basic syntax

```javascript
overrideFunction('functionName', function(arg1, arg2) {
    // Your completely custom implementation
    trace('Function overridden!');
    
    // Your code here...
});
```

### Real example

```javascript
// Override week change in StoryMenuState
overrideFunction('changeWeek', function(change) {
    trace('Custom week change');
    
    // Fully custom logic
    FlxG.camera.flash(FlxColor.WHITE, 0.5);
    FlxG.sound.play(Paths.sound('scrollMenu'));
    
    // Do whatever you want here
    state.curWeek += change * 2; // Change 2 at a time!
});
```

### Override control

```javascript
// Check if an override exists
if (hasOverride('changeWeek')) {
    trace('Override active!');
}

// Enable/disable temporarily
toggleOverride('changeWeek', false); // Disable
toggleOverride('changeWeek', true);  // Enable

// Remove completely
removeOverride('changeWeek');
```

---

## 🎯 Priority System

### Why priorities?

When you have **multiple scripts**, priorities determine the **execution order**.

### How it works

* **Higher priority = Executes first**
* If a high-priority script **cancels** an event, lower-priority scripts **won’t run**
* This improves **performance**

### Setting priority

```javascript
function onCreate() {
    setPriority(10); // This script has priority 10
}

// Recommended priorities:
// 1–10:   Light modifications
// 10–50:  Important changes  
// 50+:    Full system overrides
```

### Example with multiple scripts

```javascript
// Script A (priority 20)
setPriority(20);
function onCameraZoom(amount, duration) {
    trace('Script A runs first');
    return true; // CANCELED
}

// Script B (priority 10) 
setPriority(10);
function onCameraZoom(amount, duration) {
    trace('Script B never runs');
    // This function will NOT be called because A already canceled
}
```

---

## 📝 Available Events

### Camera events

```javascript
// Camera Zoom
function onCameraZoom(amount, duration) {
    return true; // Cancel
}

// Camera Flash
function onCameraFlash(duration, color) {
    return true; // Cancel
}

// Camera Fade
function onCameraFade(duration, color) {
    return true; // Cancel
}

// Screen Shake
function onScreenShake(intensity, duration) {
    return true; // Cancel
}
```

### Character events

```javascript
// Hey! Event
function onHeyEvent(target) {
    // target can be: 'bf', 'gf', etc
    return true; // Cancel
}

// Play Animation
function onPlayAnimation(target, animName) {
    // target: 'bf', 'dad', 'gf'
    // animName: animation name
    return true; // Cancel
}

// Change Character
function onChangeCharacter(target, newCharacter) {
    return true; // Cancel
}
```

### General event (all events)

```javascript
function onEvent(name, value1, value2, time) {
    trace('Event: ' + name);
    
    // Cancel all camera events
    if (name.contains('Camera')) {
        return true; // CANCELED
    }
    
    return false; // CONTINUE
}
```

---

## 💡 Practical Examples

### Example 1: Disable zoom during intro

```javascript
function onEvent(name, value1, value2, time) {
    // Disable zoom during the first 30 seconds
    if (time < 30000 && name == 'Camera Zoom') {
        trace('Zoom disabled during intro');
        return true; // CANCELED
    }
    return false;
}
```

### Example 2: Custom animations

```javascript
function onPlayAnimation(target, anim) {
    if (target == 'bf' && anim == 'hurt') {
        // Instead of damage animation, do something else
        trace('Custom damage animation');
        
        // Your custom code
        FlxG.camera.shake(0.01, 0.3);
        
        return true; // Cancel original animation
    }
    return false;
}
```

### Example 3: Custom selection system

```javascript
overrideFunction('selectWeek', function() {
    trace('Custom selection system');
    
    // Show custom dialog
    // Play different sound
    // Special animation
    
    FlxG.camera.flash(FlxColor.fromRGB(255, 100, 200), 1.0);
    FlxG.sound.play(Paths.sound('customConfirm'));
    
    // Your selection logic
    // ...
});
```

### Example 4: Modify difficulty change

```javascript
overrideFunction('changeDifficulty', function(change) {
    trace('Difficulty changed with effects');
    
    // Visual effects
    FlxG.camera.zoom = 1.05;
    
    // Your logic
    var newDiff = state.curDifficulty + change;
    
    // Custom validation
    if (newDiff < 0) newDiff = 5; // Allow 6 difficulties
    if (newDiff > 5) newDiff = 0;
    
    state.curDifficulty = newDiff;
    
    // Update custom UI
    // ...
});
```

### Example 5: Debug mode

```javascript
var debugMode = false;

function onCreate() {
    // Activate debug with D key
}

function onUpdate(elapsed) {
    if (FlxG.keys.justPressed.D) {
        debugMode = !debugMode;
        trace('Debug mode: ' + debugMode);
    }
}

// Cancel all events in debug mode
function onEvent(name, value1, value2, time) {
    if (debugMode) {
        trace('[DEBUG] Event canceled: ' + name);
        return true; // CANCELED
    }
    return false;
}
```

---

## 📚 Complete API

### Cancellation functions

```javascript
cancelEvent()      // Returns true (cancels event)
continueEvent()    // Returns false (continues event)
```

### Override functions

```javascript
overrideFunction(funcName, function)      // Register override
removeOverride(funcName)                  // Remove override
toggleOverride(funcName, enabled)         // Enable/disable
hasOverride(funcName)                     // Check if exists
```

### Priority functions

```javascript
setPriority(priority)    // Set script priority
```

### Available callbacks

```javascript
// Lifecycle
onCreate()
onUpdate(elapsed)
onDestroy()

// General events
onEvent(name, value1, value2, time)

// Specific events
onCameraZoom(amount, duration)
onCameraFlash(duration, color)
onCameraFade(duration, color)
onScreenShake(intensity, duration)
onHeyEvent(target)
onPlayAnimation(target, anim)
onChangeCharacter(target, newChar)
onSetGFSpeed(speed)

// Plus any custom registered event
```

---

## ⚡ Performance Tips

1. **Use high priorities** for scripts that frequently cancel
2. **Cancel early** – if you know you’ll cancel, do it fast
3. **Avoid heavy calculations** in functions called every frame
4. **Use overrides** instead of cancel + reimplementation

---

## 🐛 Debugging

```javascript
// View all events
function onEvent(name, value1, value2, time) {
    trace('[EVENT] ' + name + ' at ' + time + 'ms');
    return false; // Don’t cancel, just observe
}

// Check if your overrides are active
function onCreate() {
    trace('Change Week override: ' + hasOverride('changeWeek'));
    trace('Select Week override: ' + hasOverride('selectWeek'));
}

// Check script priority
function onCreate() {
    trace('Script priority: ' + this.priority); // Not directly available
    // Use setPriority() to set it
}
```

---

## ❓ FAQ

**Q: Can I cancel events and then run my code?**
A: Yes! Cancel with `return true`, but execute your code BEFORE the return.

**Q: What if two scripts have the same priority?**
A: They execute in the order they were loaded.

**Q: Can I override engine functions?**
A: Only functions exposed to the scripting system.

**Q: Do overrides affect other scripts?**
A: No, each script is independent. However, the override replaces the original function.

**Q: Can I temporarily undo an override?**
A: Yes, use `toggleOverride(funcName, false)` to disable without removing it.

---

## 🎓 Conclusion

This system gives you **total control** over the game’s behavior:

* ✅ **Cancel** unwanted events
* ✅ **Override** functions completely
* ✅ **Prioritize** important scripts
* ✅ **Create** fully custom behaviors

Now go build something awesome 🚀