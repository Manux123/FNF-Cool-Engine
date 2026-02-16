// =====================================================================
// DYNAMIC SCRIPT EXAMPLE: CustomOptionsExample.hx
// Location: assets/states/optionsmenustate/CustomOptionsExample.hx
// =====================================================================
// This script shows how to add custom categories and options
// to the options menu using the dynamic StateScriptHandler system
// =====================================================================

// ===== STATE SCRIPT CALLBACKS =====

function onCreate() {
    trace("CustomOptionsExample initialized!");
    // You can initialize variables here if needed
}

function onUpdate(elapsed) {
    // Runs every frame
    // Useful for updating values in real time
}

// ===== CUSTOM CATEGORY SYSTEM =====

/**
 * Returns an array with the names of the custom categories
 * that you want to add to the menu
 */
function getCustomCategories() {
    return ["Audio", "Advanced"];
}

/**
 * Returns the options for a specific custom category
 * @param categoryName The requested category name
 */
function getOptionsForCategory(categoryName) {
    if (categoryName == "Audio") {
        return getAudioOptions();
    }
    else if (categoryName == "Advanced") {
        return getAdvancedOptions();
    }
    
    return null;
}

/**
 * Returns additional options to add to existing categories
 * @param categoryName The name of the existing category
 */
function getAdditionalOptionsForCategory(categoryName) {
    // Example: Add options to "General"
    if (categoryName == "General") {
        return [
            {
                name: "Auto Save",
                get: function() {
                    if (save.autoSave == null) save.autoSave = true;
                    return save.autoSave ? "ON" : "OFF";
                },
                toggle: function() {
                    save.autoSave = !save.autoSave;
                    FlxG.save.flush();
                }
            }
        ];
    }
    
    // Example: Add options to "Graphics"
    if (categoryName == "Graphics") {
        return [
            {
                name: "Shader Quality",
                get: function() {
                    if (save.shaderQuality == null) save.shaderQuality = "HIGH";
                    return save.shaderQuality;
                },
                toggle: function() {
                    var qualities = ["LOW", "MEDIUM", "HIGH", "ULTRA"];
                    var currentIndex = qualities.indexOf(save.shaderQuality);
                    currentIndex = (currentIndex + 1) % qualities.length;
                    save.shaderQuality = qualities[currentIndex];
                    FlxG.save.flush();
                }
            }
        ];
    }
    
    return null;
}

// ===== OPTION DEFINITIONS =====

/**
 * Options for the "Audio" category
 */
function getAudioOptions() {
    return [
        {
            name: "Master Volume",
            get: function() {
                return Std.int(FlxG.sound.volume * 100) + "%";
            },
            toggle: function() {
                FlxG.sound.volume += 0.1;
                if (FlxG.sound.volume > 1.0) FlxG.sound.volume = 0.0;
                save.masterVolume = FlxG.sound.volume;
                FlxG.save.flush();
            }
        },
        {
            name: "Music Volume",
            get: function() {
                if (save.musicVolume == null) save.musicVolume = 0.7;
                return Std.int(save.musicVolume * 100) + "%";
            },
            toggle: function() {
                if (save.musicVolume == null) save.musicVolume = 0.7;
                save.musicVolume += 0.1;
                if (save.musicVolume > 1.0) save.musicVolume = 0.0;
                FlxG.save.flush();
            }
        },
        {
            name: "SFX Volume",
            get: function() {
                if (save.sfxVolume == null) save.sfxVolume = 1.0;
                return Std.int(save.sfxVolume * 100) + "%";
            },
            toggle: function() {
                if (save.sfxVolume == null) save.sfxVolume = 1.0;
                save.sfxVolume += 0.1;
                if (save.sfxVolume > 1.0) save.sfxVolume = 0.0;
                FlxG.save.flush();
            }
        }
    ];
}

/**
 * Options for the "Advanced" category
 */
function getAdvancedOptions() {
    return [
        {
            name: "Debug Mode",
            get: function() {
                if (save.debugMode == null) save.debugMode = false;
                return save.debugMode ? "ON" : "OFF";
            },
            toggle: function() {
                save.debugMode = !save.debugMode;
                FlxG.save.flush();
                trace("Debug Mode: " + (save.debugMode ? "ON" : "OFF"));
            }
        },
        {
            name: "Scroll Speed",
            get: function() {
                if (save.scrollSpeed == null) save.scrollSpeed = 1.0;
                return save.scrollSpeed + "x";
            },
            toggle: function() {
                if (save.scrollSpeed == null) save.scrollSpeed = 1.0;
                save.scrollSpeed += 0.1;
                if (save.scrollSpeed > 3.0) save.scrollSpeed = 0.5;
                // Round to 1 decimal
                save.scrollSpeed = Math.round(save.scrollSpeed * 10) / 10;
                FlxG.save.flush();
            }
        },
        {
            name: "Performance Mode",
            get: function() {
                if (save.performanceMode == null) save.performanceMode = false;
                return save.performanceMode ? "ON" : "OFF";
            },
            toggle: function() {
                save.performanceMode = !save.performanceMode;
                FlxG.save.flush();
            }
        },
        {
            name: "Show FPS Graph",
            get: function() {
                if (save.fpsGraph == null) save.fpsGraph = false;
                return save.fpsGraph ? "ON" : "OFF";
            },
            toggle: function() {
                save.fpsGraph = !save.fpsGraph;
                FlxG.save.flush();
            }
        }
    ];
}

// ===== ADDITIONAL EXAMPLES =====

/**
 * Example of an option with multiple values
 */
function getDifficultyOption() {
    return {
        name: "Difficulty",
        get: function() {
            var difficulties = ["Easy", "Normal", "Hard", "Expert"];
            var index = save.difficulty != null ? save.difficulty : 1;
            return difficulties[index];
        },
        toggle: function() {
            if (save.difficulty == null) save.difficulty = 1;
            save.difficulty = (save.difficulty + 1) % 4;
            FlxG.save.flush();
        }
    };
}

/**
 * Example of an option that opens a URL
 */
function getWikiOption() {
    return {
        name: "Open Wiki",
        get: function() {
            return "PRESS ENTER";
        },
        toggle: function() {
            FlxG.openURL("https://yourwiki.com");
        }
    };
}

/**
 * Example of an option with percentage
 */
function getOpacityOption() {
    return {
        name: "UI Opacity",
        get: function() {
            if (save.uiOpacity == null) save.uiOpacity = 100;
            return save.uiOpacity + "%";
        },
        toggle: function() {
            if (save.uiOpacity == null) save.uiOpacity = 100;
            save.uiOpacity += 10;
            if (save.uiOpacity > 100) save.uiOpacity = 0;
            FlxG.save.flush();
        }
    };
}

/**
 * Example of a numeric option with decimals
 */
function getZoomOption() {
    return {
        name: "Camera Zoom",
        get: function() {
            if (save.cameraZoom == null) save.cameraZoom = 1.0;
            return save.cameraZoom + "x";
        },
        toggle: function() {
            if (save.cameraZoom == null) save.cameraZoom = 1.0;
            save.cameraZoom += 0.05;
            if (save.cameraZoom > 1.5) save.cameraZoom = 0.5;
            save.cameraZoom = Math.round(save.cameraZoom * 100) / 100;
            FlxG.save.flush();
        }
    };
}

// ===== IMPORTANT NOTES =====
/*

OPTION STRUCTURE:
Each option must have:
- name: String - The name shown in the menu
- get: Function -> String - Returns the current value to display
- toggle: Function -> Void - Runs when ENTER is pressed

AVAILABLE VARIABLES:
- FlxG - Full access to FlxG
- save - Direct access to FlxG.save.data
- state - The current OptionsMenuState
- Math, Std, StringTools - Haxe utilities

STATESCRIPTHANDLER FUNCTIONS:
1. getCustomCategories() -> Array<String>
   - Returns names of new categories

2. getOptionsForCategory(categoryName) -> Array<Dynamic>
   - Returns options for custom categories

3. getAdditionalOptionsForCategory(categoryName) -> Array<Dynamic>
   - Returns options to add to existing categories

AVAILABLE CALLBACKS:
- onCreate() - When the menu is created
- onUpdate(elapsed) - Every frame
- onDestroy() - When the menu is destroyed

EXISTING CATEGORIES where you can add options:
- "General"
- "Graphics"
- "Gameplay"
- "Controls"
- "Note Skin"
- "Offset"

BEST PRACTICES:
1. Always initialize values with a null check:
   if (save.myValue == null) save.myValue = defaultValue;

2. Always save changes:
   FlxG.save.flush();

3. Use modulo to cycle values:
   currentIndex = (currentIndex + 1) % array.length;

4. Round decimals if necessary:
   value = Math.round(value * 10) / 10;

5. Always return String in get():
   return value.toString() or value + "unit";

USAGE EXAMPLES:

// Simple toggle
{
    name: "My Option",
    get: function() {
        if (save.myOption == null) save.myOption = false;
        return save.myOption ? "ON" : "OFF";
    },
    toggle: function() {
        save.myOption = !save.myOption;
        FlxG.save.flush();
    }
}

// Multiple values
{
    name: "Quality",
    get: function() {
        var values = ["Low", "Medium", "High"];
        var index = save.quality != null ? save.quality : 1;
        return values[index];
    },
    toggle: function() {
        if (save.quality == null) save.quality = 1;
        save.quality = (save.quality + 1) % 3;
        FlxG.save.flush();
    }
}

// Numeric value with increments
{
    name: "Speed",
    get: function() {
        if (save.speed == null) save.speed = 1.0;
        return save.speed + "x";
    },
    toggle: function() {
        save.speed += 0.1;
        if (save.speed > 2.0) save.speed = 0.5;
        save.speed = Math.round(save.speed * 10) / 10;
        FlxG.save.flush();
    }
}

*/

// ===== END OF EXAMPLE =====
