# Complete Multiplayer Setup Guide
## Following Your Game Flow Diagram

## 📋 Table of Contents
1. [Quick Setup (5 Steps)](#quick-setup)
2. [AutoLoad Setup](#autoload-setup)
3. [File Structure](#file-structure)
4. [Scene Setup](#scene-setup)
5. [Testing](#testing)
6. [Troubleshooting](#troubleshooting)

---

## 🚀 Quick Setup

### Step 1: Create Folder Structure
```
res://
├── autoload/
│   ├── NetworkManager.gd
│   └── GameState.gd
├── scenes/
│   ├── MainMenu.tscn
│   ├── GameplaySelect.tscn & .gd
│   ├── PVPLobby.tscn & .gd
│   ├── CharacterSelect.tscn & .gd
│   ├── LoadingScreen.tscn & .gd (you create)
│   └── FightArena.tscn & .gd (your Level1)
└── players/
    └── NetworkPlayer.tscn & .gd
```

### Step 2: Setup AutoLoad Singletons ⚠️ CRITICAL
1. **Open Project Settings:**
   - Menu: `Project > Project Settings`
   - Or press: `Alt + P` (Windows/Linux) or `Cmd + ,` (Mac)

2. **Add NetworkManager:**
   - Click on the **"Autoload"** tab (left sidebar)
   - Click the folder icon (📁) next to "Path:"
   - Navigate to `res://autoload/NetworkManager.gd`
   - In "Node Name" field, type: `NetworkManager`
   - Click **"Add"** button
   - ✅ You should see it in the list with a checkmark

3. **Add GameState:**
   - Click the folder icon (📁) again
   - Navigate to `res://autoload/GameState.gd`
   - In "Node Name" field, type: `GameState`
   - Click **"Add"** button
   - ✅ You should see it in the list with a checkmark

4. **Verify:**
   - You should now see both in the AutoLoad list:
     ```
     [✓] NetworkManager - res://autoload/NetworkManager.gd
     [✓] GameState - res://autoload/GameState.gd
     ```

### Step 3: Copy All Files
Copy all provided files to your project:
- `NetworkManager.gd` → `res://autoload/`
- `GameState.gd` → `res://autoload/`
- All scene files (.tscn) → `res://scenes/`
- All scripts (.gd) → `res://scenes/`
- `NetworkPlayer.tscn` and `.gd` → `res://players/`

### Step 4: Update MainMenu
Add this to your MainMenu script:
```gdscript
func _on_play_button_pressed():
    get_tree().change_scene_to_file("res://scenes/GameplaySelect.tscn")
```

### Step 5: Test!
- Press F5 to run
- Click through the menus
- Export and run two instances for multiplayer

---

## 🔧 AutoLoad Setup (Detailed)

### What is AutoLoad?
AutoLoad creates **singleton nodes** that:
- Load automatically when the game starts
- Persist across all scenes
- Can be accessed from anywhere using `/root/NodeName`

### How to Access AutoLoad in Scripts
```gdscript
# Method 1: Direct path
var network_manager = get_node("/root/NetworkManager")

# Method 2: Using $ shorthand
var game_state = $/root/GameState

# Method 3: In _ready() function
func _ready():
    network_manager = get_node("/root/NetworkManager")
```

### Troubleshooting AutoLoad
**"Can't find NetworkManager"**
1. Check Project Settings > Autoload tab
2. Verify the path is correct: `res://autoload/NetworkManager.gd`
3. Verify Node Name is exactly: `NetworkManager` (case-sensitive!)
4. Try restarting Godot editor

**"Invalid get index 'players' on base: 'Nil'"**
- This means AutoLoad wasn't set up correctly
- Follow Step 2 above carefully
- Make sure to click "Add" button, not just close the dialog

---

## 📁 File Structure

### autoload/ Folder
**NetworkManager.gd** - Core networking
- Handles host/join/disconnect
- Manages player connections
- Syncs data across network
- Configurable in Inspector (port, max players)

**GameState.gd** - Game state management  
- Tracks game mode (solo/pvp)
- Stores character selections
- Manages round wins (best of 3)
- Records match statistics

### scenes/ Folder
1. **MainMenu** - Entry point
2. **GameplaySelect** - Choose Solo vs AI or PVP
3. **PVPLobby** - Host/Join multiplayer games
4. **CharacterSelect** - Pick your fighter
5. **LoadingScreen** - Countdown before fight
6. **FightArena** - The actual battle

---

## 🎮 Game Flow (Following Your Diagram)

```
MAIN
 ├─→ GAMEPLAY SELECT
 │    ├─→ SOLO vs AI ──→ CHARACTER SELECT ──→ LOADING ──→ FIGHT
 │    └─→ PVP ──→ LOBBY ──→ CHARACTER SELECT ──→ LOADING ──→ FIGHT
 │
 └─→ FIGHT (Best of 3)
      ├─→ Round 1
      ├─→ Round 2  
      ├─→ Round 3 (if needed)
      └─→ END STATS ──→ BACK TO MAIN
```

### Scene Transitions
```gdscript
# In any script:
get_tree().change_scene_to_file("res://scenes/SceneName.tscn")

# For multiplayer (host triggers, clients follow):
@rpc("any_peer", "call_local", "reliable")
func _change_scene():
    get_tree().change_scene_to_file("res://scenes/SceneName.tscn")
```

---

## 🎯 Inspector Configuration

### NetworkManager (@export variables)
In the AutoLoad node (once added), you can configure:
```gdscript
@export var default_port: int = 7777  # Change in inspector
@export var max_players: int = 2      # Change in inspector
```

To change:
1. Select the NetworkManager autoload in the Scene tree
2. Look at Inspector panel (right side)
3. Modify values under "Script Variables"

### PVPLobby (@export variables)
```gdscript
@export var default_port: int = 7777
```

---

## 🧪 Testing

### Solo Testing (Quick)
1. Press F5
2. Click "GAMEPLAY SELECT"
3. Click "SOLO vs AI"
4. Select character
5. Fight AI

### Multiplayer Testing

#### Method 1: Editor + Export
1. Export your game: `Project > Export > Add... > Windows Desktop`
2. Click "Export Project" 
3. Run the exported .exe
4. In Godot Editor: Press F5
5. In one instance: Host game
6. In other: Join with `127.0.0.1`

#### Method 2: Two Exports
1. Export game twice to different folders
2. Run both
3. One hosts, other joins with `127.0.0.1`

#### Method 3: Same Network (LAN)
1. Find host IP: 
   - Windows: Open CMD, type `ipconfig`
   - Mac/Linux: Open Terminal, type `ifconfig`
   - Look for IPv4 Address (e.g., 192.168.1.100)
2. Host on one computer
3. Join from another using host's IP

---

## 🐛 Troubleshooting

### "Can't find AutoLoad"
```
ERROR: Can't find node: /root/NetworkManager
```
**Solution:**
1. Open `Project > Project Settings > Autoload`
2. Add `NetworkManager.gd` with Node Name: `NetworkManager`
3. Add `GameState.gd` with Node Name: `GameState`
4. Restart Godot

### "Connection Failed"
**Checklist:**
- [ ] Host clicked "HOST GAME" first?
- [ ] Correct IP address? (`127.0.0.1` for local testing)
- [ ] Port 7777 not blocked by firewall?
- [ ] Both on same network? (for LAN play)
- [ ] Host's game still running?

### "Players Can't See Each Other"
- Check AutoLoad is set up correctly
- Verify both players loaded the same scene
- Check console output for connection messages

### "Attacks Don't Work"
- Check collision layers in player scene:
  - Hitboxes: Layer 4, Mask 2
  - Hurtboxes: Layer 2, Mask 4
- Verify Area2D nodes are set up correctly

---

## 🎨 Customization

### Change Network Port
In `NetworkManager.gd`:
```gdscript
@export var default_port: int = 9999  # Your custom port
```

### Add More Characters
In `CharacterSelect.gd`:
```gdscript
var character_names = {
    "blue": "Blue Fighter",
    "red": "Red Fighter",  
    "green": "Green Fighter",
    "yellow": "Yellow Fighter",  # Add new
    "purple": "Purple Fighter"    # Add new
}
```

Then add buttons in CharacterSelect.tscn

### Change Rounds (Best of 5)
In `GameState.gd`:
```gdscript
var max_rounds: int = 5  # Change from 3 to 5
```

---

## 📝 Code Examples

### Accessing NetworkManager
```gdscript
extends Node

var network_manager

func _ready():
    network_manager = get_node("/root/NetworkManager")
    
    # Check if in multiplayer
    if network_manager.is_server():
        print("I'm the host!")
    
    # Get player data
    var my_id = network_manager.get_peer_id()
    var my_data = network_manager.get_player_data(my_id)
    print("My name: ", my_data.get("name", "Unknown"))
```

### Using RPC for Multiplayer
```gdscript
# Call function on all clients
func broadcast_message():
    _show_message.rpc("Hello everyone!")

@rpc("any_peer", "call_local", "reliable")
func _show_message(text: String):
    print(text)  # Shows on all clients

# Call function only on specific client
func send_to_client(peer_id: int):
    _private_message.rpc_id(peer_id, "Hello there!")

@rpc("any_peer", "reliable")  
func _private_message(text: String):
    print(text)
```

### Accessing GameState
```gdscript
extends Node

var game_state

func _ready():
    game_state = get_node("/root/GameState")
    
    # Check game mode
    if game_state.game_mode == "pvp":
        print("Multiplayer mode!")
    
    # Get character selections
    print("P1 Character: ", game_state.player1_character)
    print("P2 Character: ", game_state.player2_character)
    
    # Record round winner
    game_state.record_round_winner("player1")
    
    # Check if match is over
    if game_state.is_match_over():
        var winner = game_state.get_match_winner()
        print(winner, " won the match!")
```

---

## 🌐 Online Play (Internet)

### Port Forwarding (For hosting over internet)
1. Access your router settings (usually 192.168.1.1)
2. Find "Port Forwarding" section
3. Forward port **7777** (TCP & UDP) to your PC's local IP
4. Give your **public IP** to players (Google "what is my IP")
5. Players join using your public IP

### Alternative: Use VPN Services
Easier than port forwarding:
- **Hamachi** - Free, creates virtual LAN
- **ZeroTier** - Free, peer-to-peer
- **Radmin VPN** - Free, gaming focused

---

## ✅ Checklist Before Playing

- [ ] AutoLoad singletons added (NetworkManager + GameState)
- [ ] All files copied to correct folders
- [ ] MainMenu links to GameplaySelect
- [ ] Input Map configured (arrows, space, tab, enter)
- [ ] Game exported for testing
- [ ] Firewall allows port 7777
- [ ] Both players on same Godot version

---

## 📞 Support

### Debug Console Output
The system prints helpful messages:
```
[NetworkManager] Server created on port 7777
[NetworkManager] Player connected: 2
[NetworkManager] Game starting!
```

Check the Output panel (bottom of Godot) for these messages.

### Common Error Messages

**"Condition '!multiplayer' is true"**
- AutoLoad not set up correctly
- Restart Godot after adding AutoLoad

**"Invalid call. Nonexistent function 'rpc'"**
- Using RPC on wrong node type
- RPC only works on Node-derived classes

**"peer_connected signal not found"**
- Using old Godot syntax
- Make sure you're on Godot 4.x

---

## 🎓 Learning Resources

- Godot Docs: https://docs.godotengine.org/en/stable/tutorials/networking/
- High-level Multiplayer: https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html
- RPC Documentation: https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-method-rpc

---

## 📄 License
Free to use in your projects!

Good luck with your fighting game! 🥊
