@tool
## Serialisable data that backs a single visual script graph.
##
## Attach one of these to any Node property (or load it directly from the
## FileSystem) to open the Visual Scripter workspace.  When you press
## "Compile", a corresponding .gd file is generated next to this resource.
class_name VisualScriptData
extends Resource

## Serialised graph nodes.
## Each entry is a Dictionary:
##   { "id": String, "type": String,
##     "position": { "x": float, "y": float },
##     "data": { field_name: value, … } }
@export var nodes: Array = []

## Serialised GraphEdit connections.
## Each entry is a Dictionary:
##   { "from_node": String, "from_port": int,
##     "to_node":   String, "to_port":   int }
@export var connections: Array = []

## The class the generated script should extend (e.g. "CharacterBody2D").
@export var extends_class: String = "Node"

## Auto-incrementing counter used to assign unique node IDs.
@export var next_node_id: int = 1
