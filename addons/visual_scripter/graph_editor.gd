@tool
## Bottom-panel GraphEdit workspace for the Visual Scripter addon.
##
## Responsibilities:
##   • Builds and owns the toolbar + GraphEdit widget tree.
##   • Creates GraphNode instances from node-type definitions.
##   • Serialises / deserialises the graph to/from a VisualScriptData resource.
##   • Delegates GDScript code generation to VSGraphCompiler.
class_name VSGraphEditor
extends VBoxContainer

const NodeDefs     := preload("res://addons/visual_scripter/node_definitions.gd")
const GraphCompiler := preload("res://addons/visual_scripter/graph_compiler.gd")

## Injected by plugin.gd so we can refresh the filesystem after compilation.
var editor_interface: EditorInterface = null

var _resource: VisualScriptData = null
var _graph_edit: GraphEdit       = null
var _status_label: Label         = null
var _extends_edit: LineEdit      = null
var _add_menu: PopupMenu         = null

## Maps each PopupMenu item-ID to its node-type string.
var _menu_type_map: Array[String] = []

## Graph-canvas position at which the next "Add Node" will be placed.
var _add_node_pos: Vector2 = Vector2(80.0, 80.0)

## True while load_resource() is running – prevents re-entrant saves.
var _loading: bool = false


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_build_ui()


# ── UI construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	size_flags_vertical   = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# ---- Toolbar ----------------------------------------------------------------
	var toolbar := HBoxContainer.new()
	add_child(toolbar)

	var add_btn := MenuButton.new()
	add_btn.text = "✚ Add Node"
	add_btn.flat = false
	toolbar.add_child(add_btn)
	_add_menu = add_btn.get_popup()
	_populate_add_menu()
	_add_menu.id_pressed.connect(_on_add_menu_item_pressed)

	toolbar.add_child(_make_sep())

	var compile_btn := Button.new()
	compile_btn.text        = "⚙ Compile"
	compile_btn.tooltip_text = "Generate a .gd file from the current graph"
	compile_btn.pressed.connect(_on_compile_pressed)
	toolbar.add_child(compile_btn)

	var save_btn := Button.new()
	save_btn.text    = "💾 Save Graph"
	save_btn.pressed.connect(_save_to_resource)
	toolbar.add_child(save_btn)

	toolbar.add_child(_make_sep())

	var extends_lbl := Label.new()
	extends_lbl.text = "  extends:"
	toolbar.add_child(extends_lbl)

	_extends_edit = LineEdit.new()
	_extends_edit.placeholder_text         = "Node"
	_extends_edit.custom_minimum_size.x    = 160
	_extends_edit.text_changed.connect(_on_extends_changed)
	toolbar.add_child(_extends_edit)

	# Spacer pushes status label to the right.
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(spacer)

	_status_label          = Label.new()
	_status_label.modulate = Color(0.6, 1.0, 0.6)
	toolbar.add_child(_status_label)

	# ---- GraphEdit --------------------------------------------------------------
	_graph_edit = GraphEdit.new()
	_graph_edit.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_graph_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_graph_edit.minimap_enabled       = true
	_graph_edit.show_zoom_label       = true
	add_child(_graph_edit)

	_graph_edit.connection_request.connect(_on_connection_request)
	_graph_edit.disconnection_request.connect(_on_disconnection_request)
	_graph_edit.delete_nodes_request.connect(_on_delete_nodes_request)
	_graph_edit.popup_request.connect(_on_graph_popup_request)


func _make_sep() -> VSeparator:
	return VSeparator.new()


# ── Add-node menu ─────────────────────────────────────────────────────────────

func _populate_add_menu() -> void:
	_menu_type_map.clear()
	_add_menu.clear()

	# Build category → type list, respecting preferred display order.
	var order: Array[String] = ["Events", "Input", "Actions", "Logic", "Math", "Variables"]
	var categories: Dictionary = {}
	for type_key: String in NodeDefs.DEFINITIONS:
		var cat: String = NodeDefs.DEFINITIONS[type_key].get("category", "Misc")
		if not categories.has(cat):
			categories[cat] = []
		(categories[cat] as Array).append(type_key)

	var item_id: int = 0
	for cat: String in order:
		if not categories.has(cat):
			continue
		_add_menu.add_separator(cat)
		for type_key: String in (categories[cat] as Array):
			var title: String = NodeDefs.DEFINITIONS[type_key]["title"]
			_add_menu.add_item(title, item_id)
			_menu_type_map.append(type_key)
			item_id += 1


func _on_add_menu_item_pressed(id: int) -> void:
	if id < 0 or id >= _menu_type_map.size():
		return
	_create_and_register_node(_menu_type_map[id], _add_node_pos)
	# Offset the next node slightly so they do not perfectly overlap.
	_add_node_pos += Vector2(20.0, 20.0)


func _on_graph_popup_request(_position: Vector2) -> void:
	# Convert the widget-local mouse position to graph-canvas coordinates,
	# accounting for the current scroll offset and zoom level.
	var local := _graph_edit.get_local_mouse_position()
	_add_node_pos = (local + _graph_edit.scroll_offset) / _graph_edit.zoom
	_add_menu.popup()


# ── Resource I/O ─────────────────────────────────────────────────────────────

## Called by plugin.gd when a VisualScriptData resource is selected.
func load_resource(res: VisualScriptData) -> void:
	_resource = res
	_loading  = true

	_extends_edit.text = res.extends_class

	# Wipe existing graph.
	_graph_edit.clear_connections()
	var to_remove: Array[Node] = []
	for child: Node in _graph_edit.get_children():
		if child is GraphNode:
			to_remove.append(child)
	for n: Node in to_remove:
		n.free()

	# Recreate nodes from serialised data.
	for node_data in res.nodes:
		_spawn_node(node_data as Dictionary)

	# Restore connections.
	for conn in res.connections:
		var cd := conn as Dictionary
		_graph_edit.connect_node(
				cd["from_node"], cd["from_port"],
				cd["to_node"],   cd["to_port"])

	_loading = false
	_set_status("Loaded: " + res.resource_path.get_file())


func _save_to_resource() -> void:
	if _resource == null or _loading:
		return

	var nodes_out: Array = []
	for child: Node in _graph_edit.get_children():
		if child is GraphNode:
			nodes_out.append(_serialise_node(child as GraphNode))

	var conns_out: Array = []
	for conn in _graph_edit.get_connection_list():
		var cd := conn as Dictionary
		conns_out.append({
			"from_node": cd["from_node"],
			"from_port": cd["from_port"],
			"to_node":   cd["to_node"],
			"to_port":   cd["to_port"],
		})

	_resource.nodes       = nodes_out
	_resource.connections = conns_out
	_resource.extends_class = _extends_edit.text

	var err: int = ResourceSaver.save(_resource)
	if err == OK:
		_set_status("Graph saved.")
	else:
		_set_status("Save error: " + str(err))


func _serialise_node(gnode: GraphNode) -> Dictionary:
	var type: String = gnode.get_meta("vs_type", "")
	var field_values: Dictionary = {}

	if NodeDefs.DEFINITIONS.has(type):
		for field: Dictionary in NodeDefs.DEFINITIONS[type].get("fields", []):
			var field_node: Node = gnode.find_child("field_" + field["name"], true, false)
			if field_node is LineEdit:
				field_values[field["name"]] = (field_node as LineEdit).text
			elif field_node is OptionButton:
				var opt := field_node as OptionButton
				field_values[field["name"]] = opt.get_item_text(opt.selected)

	return {
		"id":       gnode.name,
		"type":     type,
		"position": {"x": gnode.position_offset.x, "y": gnode.position_offset.y},
		"data":     field_values,
	}


# ── Node spawning ─────────────────────────────────────────────────────────────

## Creates a new node, assigns it a fresh ID, adds it to the graph, then saves.
func _create_and_register_node(type: String, position: Vector2) -> void:
	if _resource == null:
		_set_status("No resource loaded – open a VisualScriptData first.")
		return

	var id: String = str(_resource.next_node_id)
	_resource.next_node_id += 1

	_spawn_node({"id": id, "type": type, "position": {"x": position.x, "y": position.y}, "data": {}})
	_save_to_resource()


## Builds and adds a GraphNode from serialised node data.
func _spawn_node(node_data: Dictionary) -> GraphNode:
	var type: String = node_data.get("type", "")
	var id: String   = node_data.get("id",   "")
	var pos_raw      = node_data.get("position", {"x": 100.0, "y": 100.0})
	var pos := Vector2(float(pos_raw.get("x", 100.0)), float(pos_raw.get("y", 100.0)))
	var field_data: Dictionary = node_data.get("data", {})

	if not NodeDefs.DEFINITIONS.has(type):
		push_error("[VSGraphEditor] Unknown node type: " + type)
		return null

	var def: Dictionary   = NodeDefs.DEFINITIONS[type]
	var slots: Array      = def.get("slots",  [])
	var fields: Array     = def.get("fields", [])

	var gnode := GraphNode.new()
	gnode.name            = id
	gnode.title           = def["title"]
	gnode.position_offset = pos
	gnode.set_meta("vs_type", type)

	# ---- Slot rows (carry live ports) ----------------------------------------
	for i: int in range(slots.size()):
		var slot: Dictionary = slots[i]
		var left_type: int   = slot.get("left_type",   -1)
		var right_type: int  = slot.get("right_type",  -1)
		var left_lbl: String  = slot.get("left_label",  "")
		var right_lbl: String = slot.get("right_label", "")

		var row := HBoxContainer.new()

		if left_type != -1:
			var lbl := Label.new()
			lbl.text                    = left_lbl
			lbl.size_flags_horizontal   = Control.SIZE_EXPAND_FILL
			row.add_child(lbl)
		else:
			var sp := Control.new()
			sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(sp)

		if right_type != -1:
			var lbl := Label.new()
			lbl.text                  = right_lbl
			lbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_RIGHT
			row.add_child(lbl)

		gnode.add_child(row)

		# Configure the GraphEdit port for this slot.
		var left_en: bool   = left_type  != -1
		var right_en: bool  = right_type != -1
		var lc := NodeDefs.PORT_COLORS.get(left_type,  Color.WHITE) if left_en  else Color.WHITE
		var rc := NodeDefs.PORT_COLORS.get(right_type, Color.WHITE) if right_en else Color.WHITE
		gnode.set_slot(i,
				left_en,  left_type  if left_en  else 0, lc,
				right_en, right_type if right_en else 0, rc)

	# ---- Field rows (no live ports, carry editable widgets) ------------------
	for i: int in range(fields.size()):
		var field: Dictionary  = fields[i]
		var slot_idx: int      = slots.size() + i

		var row := HBoxContainer.new()

		var lbl := Label.new()
		lbl.text = field["name"].replace("_", " ").capitalize() + ":"
		row.add_child(lbl)

		match field["type"]:
			"text":
				var edit := LineEdit.new()
				edit.name                   = "field_" + field["name"]
				edit.text                   = str(field_data.get(field["name"],
				                                                  field.get("default", "")))
				edit.size_flags_horizontal  = Control.SIZE_EXPAND_FILL
				edit.text_changed.connect(func(_t: String) -> void: _auto_save())
				row.add_child(edit)

			"enum":
				var opt := OptionButton.new()
				opt.name                  = "field_" + field["name"]
				opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				var options: Array = field.get("options", [])
				for opt_str: String in options:
					opt.add_item(opt_str)
				var current: String = str(field_data.get(field["name"],
				                                          field.get("default", "")))
				var idx: int = options.find(current)
				if idx >= 0:
					opt.selected = idx
				opt.item_selected.connect(func(_idx: int) -> void: _auto_save())
				row.add_child(opt)

		gnode.add_child(row)
		# Field rows carry no ports.
		gnode.set_slot(slot_idx, false, 0, Color.WHITE, false, 0, Color.WHITE)

	_graph_edit.add_child(gnode)
	return gnode


# ── Graph-edit signal handlers ────────────────────────────────────────────────

func _on_connection_request(
		from_node: StringName, from_port: int,
		to_node: StringName,   to_port: int) -> void:

	var from_gnode: GraphNode = _graph_edit.get_node_or_null(NodePath(from_node))
	var to_gnode:   GraphNode = _graph_edit.get_node_or_null(NodePath(to_node))
	if from_gnode == null or to_gnode == null:
		return

	var out_type: int = _get_right_port_type(from_gnode, from_port)
	var in_type:  int = _get_left_port_type(to_gnode,   to_port)

	# Allow: same type, or either side is PORT_ANY (wildcard).
	var compatible: bool = (out_type == in_type
			or out_type == NodeDefs.PORT_ANY
			or in_type  == NodeDefs.PORT_ANY)
	if not compatible:
		return

	_graph_edit.connect_node(from_node, from_port, to_node, to_port)
	_auto_save()


func _on_disconnection_request(
		from_node: StringName, from_port: int,
		to_node: StringName,   to_port: int) -> void:
	_graph_edit.disconnect_node(from_node, from_port, to_node, to_port)
	_auto_save()


func _on_delete_nodes_request(nodes: Array) -> void:
	for node_name in nodes:
		var n: Node = _graph_edit.get_node_or_null(NodePath(str(node_name)))
		if n != null:
			# Remove all connections touching this node first.
			for conn in _graph_edit.get_connection_list():
				var cd := conn as Dictionary
				if str(cd["from_node"]) == str(node_name) \
						or str(cd["to_node"]) == str(node_name):
					_graph_edit.disconnect_node(
							cd["from_node"], cd["from_port"],
							cd["to_node"],   cd["to_port"])
			n.queue_free()
	_auto_save()


# ── Port-type helpers ─────────────────────────────────────────────────────────

func _get_right_port_type(gnode: GraphNode, port_idx: int) -> int:
	var type: String = gnode.get_meta("vs_type", "")
	if not NodeDefs.DEFINITIONS.has(type):
		return -1
	var slots: Array = NodeDefs.DEFINITIONS[type].get("slots", [])
	if port_idx >= slots.size():
		return -1
	return slots[port_idx].get("right_type", -1)


func _get_left_port_type(gnode: GraphNode, port_idx: int) -> int:
	var type: String = gnode.get_meta("vs_type", "")
	if not NodeDefs.DEFINITIONS.has(type):
		return -1
	var slots: Array = NodeDefs.DEFINITIONS[type].get("slots", [])
	if port_idx >= slots.size():
		return -1
	return slots[port_idx].get("left_type", -1)


# ── Compile ───────────────────────────────────────────────────────────────────

func _on_compile_pressed() -> void:
	if _resource == null:
		_set_status("No resource loaded.")
		return

	# Save current graph state first.
	_save_to_resource()

	var compiler := GraphCompiler.new()
	var result: Dictionary = compiler.compile(_resource)

	if not result["ok"]:
		_set_status("Compile error: " + result["error"])
		push_error("[VSGraphEditor] " + result["error"])
		return

	var code: String    = result["code"]
	var out_path: String = _resource.resource_path.get_basename() + "_generated.gd"

	var file := FileAccess.open(out_path, FileAccess.WRITE)
	if file == null:
		_set_status("Cannot write: " + out_path)
		return
	file.store_string(code)
	file.close()

	# Notify the editor filesystem so the new file appears immediately.
	if editor_interface != null:
		editor_interface.get_resource_filesystem().update_file(out_path)

	_set_status("Compiled → " + out_path.get_file())


# ── Toolbar signal handlers ───────────────────────────────────────────────────

func _on_extends_changed(_new_text: String) -> void:
	if _resource != null and not _loading:
		_resource.extends_class = _extends_edit.text


# ── Helpers ───────────────────────────────────────────────────────────────────

func _auto_save() -> void:
	if not _loading:
		_save_to_resource()


func _set_status(msg: String) -> void:
	if _status_label != null:
		_status_label.text = msg
