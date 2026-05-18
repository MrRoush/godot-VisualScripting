@tool
## Registers the Visual Scripter addon with the Godot editor.
## Adds a persistent bottom-panel tab containing the GraphEdit workspace.
## Intercepts VisualScriptData resource selection to load it into that panel.
extends EditorPlugin

var _panel: Control = null


func _enter_tree() -> void:
	_panel = preload("res://addons/visual_scripter/graph_editor.gd").new()
	_panel.editor_interface = get_editor_interface()
	add_control_to_bottom_panel(_panel, "Visual Scripter")


func _exit_tree() -> void:
	if is_instance_valid(_panel):
		remove_control_from_bottom_panel(_panel)
		_panel.queue_free()
	_panel = null


func _handles(object: Object) -> bool:
	return object is VisualScriptData


func _edit(object: Object) -> void:
	if object is VisualScriptData:
		_panel.load_resource(object as VisualScriptData)


func _make_visible(visible: bool) -> void:
	if visible and is_instance_valid(_panel):
		make_bottom_panel_item_visible(_panel)
