# Setting up VS Code to mod Cool Engine

The project includes full support for **VS Code** with autocomplete, hover documentation, and parameter help for the entire engine API.

---

## Installation (first time only)

### Windows
Double-click on **`setup.bat`**

### Linux / Mac
```bash
`chmod +x setup.sh
`/setup.sh`
```

This automatically installs the **Cool Engine HScript** extension and opens the project ready to use.

---

## What does the extension include?


- **Autocomplete** — suggestions for all engine functions and variables
- **Hover docs** — documentation when hovering over any function
- **Signature help** — displays parameters while typing a call
- **Syntax highlighting** — syntax highlighting for `.hscript` and `.hsc`

---

## If you already have VS Code open

If you opened the folder without running the setup, VS Code will display a notification
in the bottom right corner asking if you want to install the recommended extensions. Click on **"Install"**.

---

## Script Structure

| Folder | Script Type |

|--------|---------------|

`mods/scripts/` | PlayState Scripts |

`mods/stages/` | Stage Scripts |

`mods/states/` | State Scripts |