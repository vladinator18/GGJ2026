# ⚠️ CRITICAL: AutoLoad Setup Instructions

## YOU MUST DO THIS FIRST OR NOTHING WILL WORK!

### What is AutoLoad?
AutoLoad creates singleton nodes that exist throughout your entire game. Think of them like "global managers" that are always available.

---

## Step-by-Step AutoLoad Setup

### 1. Open Project Settings
- Click **Project** in the top menu
- Click **Project Settings...**
- OR press `Alt+P` (Windows/Linux) or `Cmd+,` (Mac)

### 2. Navigate to AutoLoad Tab
- Look at the left sidebar in Project Settings
- Click on **"Autoload"** (near the bottom)
- You should see a panel that says "AutoLoad" at the top

### 3. Add NetworkManager
1. Click the **folder icon** (📁) next to "Path:"
2. Navigate to: `res://autoload/NetworkManager.gd`
3. Click the file to select it
4. Click "Open"
5. In the **"Node Name"** field, type exactly: `NetworkManager`
6. Click the **"Add"** button (important!)
7. ✅ You should now see it in the list below

### 4. Add GameState
1. Click the **folder icon** (📁) again
2. Navigate to: `res://autoload/GameState.gd`
3. Click the file to select it
4. Click "Open"
5. In the **"Node Name"** field, type exactly: `GameState`
6. Click the **"Add"** button
7. ✅ You should now see it in the list below

### 5. Verify Setup
You should now see both entries in the AutoLoad list:

```
[✓] NetworkManager    res://autoload/NetworkManager.gd
[✓] GameState        res://autoload/GameState.gd
```

### 6. Close Project Settings
Click the **"Close"** button at the bottom

---

## ✅ Testing if AutoLoad Works

Create a test script and add this:

```gdscript
extends Node

func _ready():
    var network_manager = get_node("/root/NetworkManager")
    var game_state = get_node("/root/GameState")
    
    if network_manager:
        print("✅ NetworkManager found!")
    else:
        print("❌ NetworkManager NOT found - AutoLoad not set up!")
    
    if game_state:
        print("✅ GameState found!")
    else:
        print("❌ GameState NOT found - AutoLoad not set up!")
```

Run the game (F5) and check the Output panel. You should see:
```
✅ NetworkManager found!
✅ GameState found!
```

---

## ❌ Common Mistakes

### Mistake 1: Wrong Path
❌ `res://NetworkManager.gd`
✅ `res://autoload/NetworkManager.gd`

Make sure files are in the `autoload/` folder!

### Mistake 2: Wrong Node Name
❌ `networkmanager` (lowercase)
❌ `Network Manager` (with space)
✅ `NetworkManager` (exact case!)

Node names are case-sensitive!

### Mistake 3: Didn't Click "Add"
You MUST click the "Add" button after entering the path and name. Just closing the dialog won't work!

### Mistake 4: Files Don't Exist
Make sure you copied:
- `NetworkManager.gd` to `res://autoload/`
- `GameState.gd` to `res://autoload/`

---

## 🆘 Troubleshooting

### "Can't find node: /root/NetworkManager"
**Solution:** AutoLoad not set up correctly
1. Go back to Project Settings > Autoload
2. Check if NetworkManager is in the list
3. If not, add it again following steps above
4. If yes, try restarting Godot

### "Script does not inherit from Node"
**Solution:** Wrong file selected
- Make sure you're selecting the `.gd` script file
- NOT the `.tscn` scene file

### "Invalid path"
**Solution:** Files not in correct location
- Check that `NetworkManager.gd` exists in `res://autoload/`
- Use the folder icon to browse, don't type the path manually

### Still Not Working?
1. Close Godot completely
2. Reopen your project
3. Check Project Settings > Autoload again
4. Try the test script above

---

## 📍 Visual Guide

```
Project Settings Window
┌─────────────────────────────────────┐
│ General                             │
│ Application                         │
│ Display                             │
│ Audio                               │
│ ...                                 │
│ ┌─────────────────────────────────┐ │
│ │ >>> Autoload <<<                │ │  ← Click here!
│ └─────────────────────────────────┘ │
│ Localization                        │
│ Rendering                           │
└─────────────────────────────────────┘

Autoload Panel
┌──────────────────────────────────────────┐
│ Path: [res://...      ] [📁] [🔍]       │  ← Click folder icon
│ Node Name: [NetworkManager          ]   │  ← Type exact name
│ [ ] Enable                              │
│ [      Add      ]  ← Click this!        │
├──────────────────────────────────────────┤
│ Name              Path                   │
│ [✓] NetworkManager  res://autoload/...  │
│ [✓] GameState      res://autoload/...   │
└──────────────────────────────────────────┘
```

---

## ✨ After Setup

Once AutoLoad is set up, you can access these managers from ANY script:

```gdscript
# In ANY script, in ANY scene:
var network_manager = get_node("/root/NetworkManager")
var game_state = get_node("/root/GameState")

# Or shorter:
var network_manager = $/root/NetworkManager
var game_state = $/root/GameState
```

---

## 🎯 Next Steps

After AutoLoad is set up:
1. ✅ Copy all other files to your project
2. ✅ Set up scenes and scripts
3. ✅ Test the game!

**Remember:** AutoLoad MUST be set up first or the entire multiplayer system won't work!
