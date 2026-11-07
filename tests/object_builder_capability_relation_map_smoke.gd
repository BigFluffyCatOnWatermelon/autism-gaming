extends SceneTree

const MapViewScript = preload("res://addons/object_builder/ui/capability_relation_map_view.gd")
const DefinitionScript = preload("res://scripts/object_system/object_capability_definition.gd")
const MechanicModuleLoaderScript = preload("res://scripts/object_system/mechanic_module_loader.gd")

var failures := PackedStringArray()
var focused_id := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var host_control := Control.new()
	root.add_child(host_control)
	var focused = DefinitionScript.new()
	focused.capability_id = "can_attack"
	focused.display_name = "Атака"
	var movement = DefinitionScript.new()
	movement.capability_id = "can_move"
	movement.display_name = "Движение"
	var sound = DefinitionScript.new()
	sound.capability_id = "plays_attack_sound"
	sound.display_name = "Звук атаки"

	var entries: Array[Dictionary] = [
		{
			"definition": movement,
			"relation_type": "recommends",
			"explanation": "Атака может использовать направление движения.",
			"is_reverse": false
		},
		{
			"definition": sound,
			"relation_type": "related",
			"explanation": "Звуковое сопровождение атаки.",
			"is_reverse": true
		}
	]
	var map = MapViewScript.new()
	map.connect("focus_requested", Callable(self, "_on_focus_requested"))
	map.open(host_control, focused, entries)
	_expect(int(map.call("get_node_count")) >= 3, "relation map creates a focused node and related capability nodes")
	_expect(int(map.call("get_connection_count")) == 2, "each related capability receives a visible graph connection")
	_expect(bool(map.call("has_connection", "FocusedCapability", "Capability_0")), "outgoing relation is drawn from the focused node")
	_expect(bool(map.call("has_connection", "Capability_1", "FocusedCapability")), "incoming relation is drawn toward the focused node")
	_expect(int(map.call("get_focus_button_count")) == 2, "each related node has a navigation action")
	_expect(focused_id.is_empty(), "opening the map does not change the catalog focus")
	map.call("_on_focus_pressed", "can_move")
	_expect(focused_id == "can_move", "selecting a graph node requests navigation to its capability")
	var module_errors := MechanicModuleLoaderScript.register_modules_in_directory()
	for error_message in module_errors:
		failures.append("module registration: " + error_message)
	map.call("open_full", host_control, "can_attack")
	_expect(int(map.call("get_node_count")) >= 200, "full graph creates all 200 catalogue capability nodes")
	_expect(int(map.call("get_connection_count")) >= 60, "full graph renders the curated relationship network")
	_expect(int(map.call("get_relation_type_count")) == 6, "full graph exposes all six typed relationship kinds")
	_expect(int(map.call("get_focus_button_count")) == 200, "all catalogue nodes provide a navigation action")
	_expect(int(map.call("get_visible_node_count")) == 200, "full graph starts with every capability visible")
	map.call("filter_full_map", "атака")
	var filtered_count := int(map.call("get_visible_node_count"))
	_expect(filtered_count > 0 and filtered_count < 200, "full graph search filters nodes by localized capability metadata")
	map.call("filter_full_map", "")
	_expect(int(map.call("get_visible_node_count")) == 200, "clearing full graph search restores all nodes")
	host_control.queue_free()

	if failures.is_empty():
		print("Object Builder capability relation map tests passed.")
		quit(0)
		return
	for failure in failures:
		push_error("Object Builder capability relation map: " + failure)
	quit(1)


func _on_focus_requested(capability_id: String) -> void:
	focused_id = capability_id


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
