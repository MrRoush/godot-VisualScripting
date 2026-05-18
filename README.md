# Godot Visual Scripting

A beginner-friendly Godot 4 editor plugin that lets you author game logic by connecting nodes on a canvas — no GDScript required up-front. When you are ready, a single click compiles your graph into a clean `.gd` file that you can read, extend, or hand off to a programmer.

---

## What this plugin does

| Feature | Detail |
|---|---|
| **Visual graph editor** | A `GraphEdit` workspace added to the Godot bottom panel. Drag, connect, and delete nodes with the mouse. |
| **Node library** | Pre-built nodes for Events, Input, Actions, Logic, Math, and Variables (see [Available nodes](#available-nodes)). |
| **One-click compile** | Generates a valid GDScript `.gd` file next to your `VisualScriptData` resource. |
| **Auto-save** | Every connection or field change is saved back to the resource automatically. |
| **Type-safe ports** | Ports are colour-coded by type; only compatible ports can be connected. |

---

## Installation

1. Copy the `addons/visual_scripter/` folder into your Godot 4 project.
2. Open **Project → Project Settings → Plugins** and enable **Visual Scripter**.
3. A **Visual Scripter** tab appears at the bottom of the editor.

---

## Quick start

1. In the FileSystem dock, right-click a folder and choose **New Resource**.
2. Select `VisualScriptData` and save it (e.g. `player.tres`).
3. Click the resource to open it in the Visual Scripter panel.
4. Use **✚ Add Node** (or right-click the canvas) to add nodes.
5. Set the **extends:** field in the toolbar to match your scene's root node type.
6. Click **⚙ Compile** — a `player_generated.gd` file is written next to `player.tres`.
7. Attach `player_generated.gd` to your scene's root node.

---

## Available nodes

### Port colour legend

| Colour | Type | Constant |
|---|---|---|
| ⬜ Light grey | Execution flow | `PORT_EXEC` |
| 🟦 Blue | Boolean | `PORT_BOOL` |
| 🟦 Cyan | Integer | `PORT_INT` |
| 🟧 Orange | Float | `PORT_FLOAT` |
| 🩷 Pink | String | `PORT_STRING` |
| 🟪 Purple | Any / Wildcard | `PORT_ANY` |

### Node categories

**Events** — entry points; every function starts here.

| Node | Generated code |
|---|---|
| `_physics_process(delta)` | `func _physics_process(delta: float) -> void:` |
| `Signal Receiver` | `func <name>(<param>: Node) -> void:` |

**Input** — read player input.

| Node | Generated code |
|---|---|
| `Input.get_axis` | `Input.get_axis("negative", "positive")` |
| `Input.is_action_just_pressed` | `Input.is_action_just_pressed("action")` |

**Actions** — do something in the scene.

| Node | Generated code |
|---|---|
| `move_and_slide()` | Assigns `velocity.x` / `velocity.y` then calls `move_and_slide()` |
| `AnimatedSprite2D.play` | `$NodePath.play("animation")` |
| `Set Property` | `property = value` or `$NodePath.property = value` |

**Logic**

| Node | Generated code |
|---|---|
| `Branch` | `if condition: … else: …` |

**Math**

| Node | Generated code |
|---|---|
| `Multiply (a × b)` | `(a * b)` |

**Variables**

| Node | Generated code |
|---|---|
| `Export Variable` | `@export var name: Type = default` |

---

## Tutorial: basic player scene with inputs

This walkthrough creates a simple `CharacterBody2D` player that moves left and right using keyboard input.

### 1. Set up the scene

1. Create a new scene with a **CharacterBody2D** root node.
2. Add a **CollisionShape2D** child (any shape) and a **Sprite2D** or **AnimatedSprite2D** child.
3. Save the scene (e.g. `player.tscn`).

### 2. Create the VisualScriptData resource

1. In the FileSystem dock, right-click the same folder and choose **New Resource → VisualScriptData**.
2. Save it as `player.tres`.
3. Click `player.tres` — the Visual Scripter panel opens.

### 3. Set the base class

In the toolbar, set **extends:** to `CharacterBody2D`.

### 4. Add an Export Variable for speed

1. Click **✚ Add Node → Variables → Export Variable**.
2. In the node's fields set:
   - **Var name:** `speed`
   - **Var type:** `float`
   - **Default value:** `300.0`

This produces `@export var speed: float = 300.0` at the top of the script.

### 5. Add the physics process event

Click **✚ Add Node → Events → _physics_process(delta)**.  
This is the entry point for the generated function:
- It has **no incoming exec port** (nothing connects *into* it).
- Start your chain by connecting its right-side white **exec** port to the first action node.
- The **delta** output is a float you can wire into math/action float inputs when needed.

### 6. Read horizontal input

Click **✚ Add Node → Input → Input.get_axis**.  
In its fields:
- **Negative action:** `ui_left`
- **Positive action:** `ui_right`

The orange **result** port outputs a float in the range `−1.0 … 1.0`.

### 7. Multiply input by speed

Click **✚ Add Node → Math → Multiply (a × b)**.

Connect:
- `Input.get_axis` **result** → `Multiply` **a**
- `Export Variable (speed)` **value** → `Multiply` **b**

*(Add the `Export Variable` node first if you haven't already.)*
The `Export Variable` **value** port is a purple wildcard, so it can connect to typed data ports (like `Multiply`'s orange float input).

### 8. Apply movement

Click **✚ Add Node → Actions → move_and_slide()**.

Connect:
- `_physics_process` **exec** → `move_and_slide` **exec** (white port)
- `Multiply` **result** → `move_and_slide` **velocity.x** (orange port)

For longer logic chains, continue from each action node's right-side **exec** output into the next node's left-side **exec** input.

### 9. Compile

Click **⚙ Compile** in the toolbar. A file `player_generated.gd` appears next to `player.tres`.

The generated script will look like:

```gdscript
# Generated by Visual Scripter – do not edit manually.
extends CharacterBody2D

@export var speed: float = 300.0

func _physics_process(delta: float) -> void:
    velocity.x = (Input.get_axis("ui_left", "ui_right") * speed)
    move_and_slide()
```

### 10. Attach the script

Select the `CharacterBody2D` root node in your scene, click the **Script** property, and choose `player_generated.gd`. Press **Play** — your player can now move left and right!

---

## Tips

- **Right-click** anywhere on the canvas to open the Add Node menu at that position.
- Re-compile after any change to regenerate the `.gd` file.
- The generated file is plain GDScript — feel free to extend it with hand-written code after compilation.
- Connect a **Branch** node after an input check to run different actions depending on a condition (e.g. playing different animations when moving vs. idle).
