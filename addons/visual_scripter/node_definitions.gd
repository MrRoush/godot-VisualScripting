@tool
## Centralised definitions for every Visual Scripter node type.
## Both the graph editor (UI) and the compiler (code generation) read from here
## so the two subsystems never go out of sync.
class_name VSNodeDefs


# ── Port-type constants ───────────────────────────────────────────────────────

## Execution / flow-control port (white).
const PORT_EXEC: int = 0
## Boolean data port (blue).
const PORT_BOOL: int = 1
## Integer data port (green).
const PORT_INT: int = 2
## Float data port (orange).
const PORT_FLOAT: int = 3
## String data port (red).
const PORT_STRING: int = 4
## Wildcard – connects to any type (purple).
const PORT_ANY: int = 5

## Display colour for each port type (keyed by the PORT_* constants above).
const PORT_COLORS: Dictionary = {
	0: Color(0.90, 0.90, 0.90, 1.0),  # EXEC   – light grey
	1: Color(0.40, 0.60, 1.00, 1.0),  # BOOL   – blue
	2: Color(0.25, 0.82, 0.88, 1.0),  # INT    – cyan
	3: Color(1.00, 0.70, 0.20, 1.0),  # FLOAT  – orange
	4: Color(0.95, 0.45, 0.78, 1.0),  # STRING – pink
	5: Color(0.90, 0.60, 0.90, 1.0),  # ANY    – purple
}


# ── Slot / field definition format ───────────────────────────────────────────
#
# "slots"  – Array of Dictionaries, one per visible row in the GraphNode.
#   left_type:   int    port type on the left  (-1 = no port)
#   left_label:  String label shown beside the left port
#   right_type:  int    port type on the right (-1 = no port)
#   right_label: String label shown beside the right port
#
# "fields" – Array of Dictionaries for inline-editable configuration widgets.
#   name:    String   key stored in node_data["data"]
#   type:    String   "text" | "enum"
#   default: String   initial value
#   options: Array    (enum only) list of choice strings
#
# NOTE: field rows are appended AFTER slot rows inside the GraphNode, so their
# slot indices begin at slots.size().  They never carry live ports.


## All supported node types, keyed by a stable snake_case identifier.
const DEFINITIONS: Dictionary = {

	# ── Events ───────────────────────────────────────────────────────────────

	"event_physics_process": {
		"title": "_physics_process(delta)",
		"category": "Events",
		"slots": [
			{"left_type": -1, "left_label": "",
			 "right_type": PORT_EXEC,  "right_label": "exec"},
			{"left_type": -1, "left_label": "",
			 "right_type": PORT_FLOAT, "right_label": "delta"},
		],
		"fields": [],
	},

	"event_signal_receiver": {
		"title": "Signal Receiver",
		"category": "Events",
		"slots": [
			{"left_type": -1, "left_label": "",
			 "right_type": PORT_EXEC, "right_label": "exec"},
			{"left_type": -1, "left_label": "",
			 "right_type": PORT_ANY,  "right_label": "body"},
		],
		"fields": [
			{"name": "signal_func", "type": "text", "default": "_on_body_entered"},
			{"name": "param_name",  "type": "text", "default": "body"},
		],
	},

	# ── Input ────────────────────────────────────────────────────────────────

	"input_get_axis": {
		"title": "Input.get_axis",
		"category": "Input",
		"slots": [
			{"left_type": -1, "left_label": "",
			 "right_type": PORT_FLOAT, "right_label": "result"},
		],
		"fields": [
			{"name": "negative_action", "type": "text", "default": "ui_left"},
			{"name": "positive_action", "type": "text", "default": "ui_right"},
		],
	},

	"input_is_action_just_pressed": {
		"title": "Input.is_action_just_pressed",
		"category": "Input",
		"slots": [
			{"left_type": -1, "left_label": "",
			 "right_type": PORT_BOOL, "right_label": "result"},
		],
		"fields": [
			{"name": "action", "type": "text", "default": "ui_accept"},
		],
	},

	# ── Actions ──────────────────────────────────────────────────────────────

	## move_and_slide() with optional velocity inputs for convenience.
	"action_move_and_slide": {
		"title": "move_and_slide()",
		"category": "Actions",
		"slots": [
			{"left_type": PORT_EXEC,  "left_label": "",
			 "right_type": PORT_EXEC, "right_label": ""},
			{"left_type": PORT_FLOAT, "left_label": "velocity.x",
			 "right_type": -1,        "right_label": ""},
			{"left_type": PORT_FLOAT, "left_label": "velocity.y",
			 "right_type": -1,        "right_label": ""},
		],
		"fields": [],
	},

	"action_animated_sprite_play": {
		"title": "AnimatedSprite2D.play",
		"category": "Actions",
		"slots": [
			{"left_type": PORT_EXEC,  "left_label": "",
			 "right_type": PORT_EXEC, "right_label": ""},
		],
		"fields": [
			{"name": "node_path",  "type": "text", "default": "AnimatedSprite2D"},
			{"name": "animation", "type": "text", "default": "idle"},
		],
	},

	## Generic property setter – covers the flip_h use-case and more (velocity.y…).
	"action_set_property": {
		"title": "Set Property",
		"category": "Actions",
		"slots": [
			{"left_type": PORT_EXEC, "left_label": "",
			 "right_type": PORT_EXEC, "right_label": ""},
			{"left_type": PORT_ANY,  "left_label": "value",
			 "right_type": -1,        "right_label": ""},
		],
		"fields": [
			{"name": "node_path", "type": "text", "default": ""},
			{"name": "property",  "type": "text", "default": "flip_h"},
		],
	},

	# ── Logic ────────────────────────────────────────────────────────────────

	"logic_branch": {
		"title": "Branch",
		"category": "Logic",
		"slots": [
			{"left_type": PORT_EXEC, "left_label": "",
			 "right_type": PORT_EXEC, "right_label": "true"},
			{"left_type": PORT_BOOL, "left_label": "condition",
			 "right_type": PORT_EXEC, "right_label": "false"},
		],
		"fields": [],
	},

	# ── Math ─────────────────────────────────────────────────────────────────

	"math_multiply": {
		"title": "Multiply  (a × b)",
		"category": "Math",
		"slots": [
			{"left_type": PORT_FLOAT, "left_label": "a",
			 "right_type": PORT_FLOAT, "right_label": "result"},
			{"left_type": PORT_FLOAT, "left_label": "b",
			 "right_type": -1,         "right_label": ""},
		],
		"fields": [],
	},

	# ── Variables ────────────────────────────────────────────────────────────

	"variable_export": {
		"title": "Export Variable",
		"category": "Variables",
		"slots": [
			{"left_type": -1, "left_label": "",
			 "right_type": PORT_ANY, "right_label": "value"},
		],
		"fields": [
			{"name": "var_name",       "type": "text",  "default": "speed"},
			{"name": "var_type",       "type": "enum",  "default": "float",
			 "options": ["float", "int", "bool", "String", "Vector2"]},
			{"name": "default_value",  "type": "text",  "default": "300.0"},
		],
	},
}
