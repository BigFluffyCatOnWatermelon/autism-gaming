@tool
extends ObjectComponent
class_name InteractableComponent

signal interacted(interactor: Node)
signal interaction_failed(interactor: Node, reason: String)

@export var can_be_interacted_with: bool = true
@export var prompt_text: String = "E — Взаимодействовать"
@export_range(1.0, 512.0, 1.0) var interaction_radius: float = 72.0
@export var interaction_method: String = ""
@export var interact_once: bool = false
@export_range(0.0, 60.0, 0.05) var cooldown_seconds: float = 0.25

var last_failure_reason: String = ""
var _next_interaction_time_msec: int = 0


func _on_configured() -> void:
	can_be_interacted_with = _read_bool("can_be_interacted_with", can_be_interacted_with)
	prompt_text = str(settings.get("prompt_text", prompt_text))
	interaction_radius = _read_float("interaction_radius", interaction_radius, 1.0)
	interaction_method = str(settings.get("interaction_method", interaction_method)).strip_edges()
	interact_once = _read_bool("interact_once", interact_once)
	cooldown_seconds = _read_float("cooldown_seconds", cooldown_seconds, 0.0)
	_next_interaction_time_msec = 0
	last_failure_reason = ""


func is_interaction_ready() -> bool:
	return can_be_interacted_with and Time.get_ticks_msec() >= _next_interaction_time_msec


## Optional target method contract: method_name(interactor: Node).
## The interacted signal is emitted after the method returns.
func try_interact(interactor: Node) -> bool:
	if interactor == null or not is_instance_valid(interactor):
		return _fail(interactor, "interactor_missing")
	if not can_be_interacted_with:
		return _fail(interactor, "interaction_disabled")
	if Time.get_ticks_msec() < _next_interaction_time_msec:
		return _fail(interactor, "cooldown")

	var target := get_object_root()
	if target == null or target == self or not is_instance_valid(target) or target.is_queued_for_deletion():
		return _fail(interactor, "target_missing")
	var target_position := _get_node_position(target)
	var interactor_position := _get_node_position(interactor)
	if target_position.distance_to(interactor_position) > interaction_radius:
		return _fail(interactor, "out_of_range")

	if not interaction_method.is_empty():
		if not target.has_method(interaction_method):
			return _fail(interactor, "interaction_method_missing")
		target.call(interaction_method, interactor)

	_next_interaction_time_msec = Time.get_ticks_msec() + roundi(cooldown_seconds * 1000.0)
	if interact_once:
		can_be_interacted_with = false
	interacted.emit(interactor)
	return true


func set_interaction_enabled(enabled: bool) -> void:
	can_be_interacted_with = enabled


func get_prompt_text() -> String:
	return prompt_text


func _get_node_position(node: Node) -> Vector2:
	if node != null and node.has_method("get_ground_position"):
		var value: Variant = node.call("get_ground_position")
		if typeof(value) == TYPE_VECTOR2:
			return value
	if node is Node2D:
		return (node as Node2D).global_position
	return Vector2.ZERO


func _fail(interactor: Node, reason: String) -> bool:
	last_failure_reason = reason
	interaction_failed.emit(interactor, reason)
	return false


func _read_bool(key: String, fallback: bool) -> bool:
	var value: Variant = settings.get(key, fallback)
	return bool(value) if typeof(value) == TYPE_BOOL else fallback


func _read_float(key: String, fallback: float, minimum: float) -> float:
	var value: Variant = settings.get(key, fallback)
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return maxf(minimum, float(value))
	return fallback
