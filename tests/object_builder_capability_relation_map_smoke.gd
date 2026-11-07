extends SceneTree

const MapViewScript = preload("res://addons/object_builder/ui/capability_relation_map_view.gd")
const DefinitionScript = preload("res://scripts/object_system/object_capability_definition.gd")

var failures := PackedStringArray()
var focused_id := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var owner := Control.new()
	root.add_child(owner)
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
	map.focus_requested.connect(_on_focus_requested)
	map.open(owner, focused, entries)
	_expect(map.get_node_count() >= 3, "relation map creates a focused node and related capability nodes")
	_expect(map.get_connection_count() == 2, "each related capability receives a visible graph connection")
	_expect(map.get_focus_button_count() == 2, "each related node has a navigation action")
	_expect(focused_id.is_empty(), "opening the map does not change the catalog focus")
	map._on_focus_pressed("can_move")
	_expect(focused_id == "can_move", "selecting a graph node requests navigation to its capability")
	owner.queue_free()

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
