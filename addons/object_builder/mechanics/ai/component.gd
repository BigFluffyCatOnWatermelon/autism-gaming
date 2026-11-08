@tool
extends ObjectComponent
class_name AIMechanicComponent

signal state_changed(state_id: String, intent: Dictionary)
signal help_requested(position: Vector2, radius: float)
signal dialogue_started(topic: String, lines: Array)
signal action_failed(reason: String)

var _actor: Node2D
var _target: Node2D
var _health_ratio := 1.0
var _patrol_index := 0
var _wander_target := Vector2.ZERO
var _wander_remaining := 0.0


func get_option(key: String, fallback: Variant = null) -> Variant:
	return get_setting(key, fallback)


func configure_mechanic(values: Dictionary) -> bool:
	for raw_key in values:
		var key := str(raw_key)
		if not settings.has(key) or typeof(values[raw_key]) != typeof(settings[key]):
			return _fail("Неизвестная настройка или неверный тип: " + key)
	for raw_key in values:
		settings[str(raw_key)] = values[raw_key]
	return true


func bind_target(target: Node2D) -> bool:
	if target == null or not is_instance_valid(target):
		return _fail("Для AI нужен действительный Node2D.")
	_actor = target
	return true


func set_target(target: Node2D) -> void:
	_target = target if is_instance_valid(target) else null


func set_health_ratio(value: float) -> bool:
	if not is_finite(value):
		return _fail("Доля здоровья должна быть конечным числом.")
	_health_ratio = clampf(value, 0.0, 1.0)
	return true


func get_ai_intent(delta: float, candidates: Array = [], allies: Array = []) -> Dictionary:
	if not _has_mechanic("has_ai") or not bool(_option("has_ai", "ai_enabled", true)):
		return _intent("disabled", Vector2.ZERO, null)
	if not is_finite(delta) or delta < 0.0:
		return _failed_result("Шаг AI должен быть неотрицательным.")
	if not is_instance_valid(_actor):
		return _failed_result("AI не привязан к управляющему Node2D.")

	if not is_instance_valid(_target):
		_target = _find_target(candidates)
	if is_instance_valid(_target):
		var distance := _actor.global_position.distance_to(_target.global_position)
		if _has_mechanic("can_flee") and _health_ratio <= float(_option("can_flee", "health_threshold", 0.25)):
			return _intent("flee", _actor.global_position + (_actor.global_position - _target.global_position).normalized() * float(_option("can_flee", "flee_distance", 128.0)), _target)
		if _has_mechanic("can_guard_area") and _is_inside_guard_area(_target.global_position):
			return _intent("guard", _actor.global_position, _target)
		if _has_mechanic("can_chase") and distance <= float(_option("can_chase", "detection_radius", 160.0)):
			return _intent("chase", _target.global_position, _target)
		if _has_mechanic("can_follow_target"):
			var follow_distance := maxf(0.0, float(_option("can_follow_target", "follow_distance", 48.0)))
			var follow_position := _actor.global_position if distance <= follow_distance else _target.global_position
			return _intent("follow", follow_position, _target)

	var ally := _find_ally_needing_help(allies)
	if ally != null and _has_mechanic("can_assist"):
		return _intent("assist", ally.global_position, ally)
	if _has_mechanic("can_patrol"):
		var patrol_target := _get_patrol_target()
		if patrol_target != null:
			return _intent("patrol", patrol_target, null)
	if _has_mechanic("can_wander"):
		return _intent("wander", _get_wander_target(delta), null)
	return _intent("idle", _actor.global_position, null)


func call_for_help() -> bool:
	if not _has_mechanic("can_call_for_help"):
		return _fail("Вызов помощи не включён.")
	if not is_instance_valid(_actor):
		return _fail("AI не привязан к объекту.")
	var radius := maxf(0.0, float(_option("can_call_for_help", "help_radius", 256.0)))
	help_requested.emit(_actor.global_position, radius)
	return true


func get_dialogue(topic: String = "greeting") -> Array:
	if not _has_mechanic("supports_dialogue"):
		return []
	var dialogue := _parse_json_dictionary(str(_option("supports_dialogue", "dialogue_json", "{}")))
	var lines: Variant = dialogue.get(topic, [])
	return lines.duplicate(true) if lines is Array else []


func start_dialogue(topic: String = "greeting") -> bool:
	var lines := get_dialogue(topic)
	if lines.is_empty():
		return _fail("Для темы диалога не заданы реплики: " + topic)
	dialogue_started.emit(topic, lines)
	return true


func get_patrol_index() -> int:
	return _patrol_index


func set_patrol_index(index: int) -> void:
	var points := _parse_json_array(str(_option("can_patrol", "patrol_points_json", "[]")))
	_patrol_index = clampi(index, 0, maxi(0, points.size() - 1))


func export_runtime_state() -> Dictionary:
	return {
		"health_ratio": _health_ratio,
		"patrol_index": _patrol_index,
		"wander_target": _wander_target,
		"wander_remaining": _wander_remaining,
		"target_path": str(_actor.get_path_to(_target)) if is_instance_valid(_actor) and is_instance_valid(_target) and _actor.is_ancestor_of(_target) else ""
	}


func import_runtime_state(state: Dictionary) -> bool:
	var health := float(state.get("health_ratio", 1.0))
	var remaining := float(state.get("wander_remaining", 0.0))
	if not is_finite(health) or not is_finite(remaining) or remaining < 0.0:
		return _fail("Состояние AI содержит некорректные значения.")
	_health_ratio = clampf(health, 0.0, 1.0)
	_patrol_index = maxi(0, int(state.get("patrol_index", 0)))
	_wander_target = state.get("wander_target", Vector2.ZERO)
	_wander_remaining = remaining
	if is_instance_valid(_actor):
		var path_text := str(state.get("target_path", ""))
		_target = _actor.get_node_or_null(NodePath(path_text)) as Node2D if not path_text.is_empty() else null
	return true


func _intent(state_id: String, target_position: Vector2, target_node: Node2D) -> Dictionary:
	var direction := Vector2.ZERO
	if is_instance_valid(_actor):
		direction = (target_position - _actor.global_position).normalized()
	var result := {
		"state": state_id,
		"target_position": target_position,
		"direction": direction,
		"target": target_node
	}
	state_changed.emit(state_id, result)
	return result


func _find_target(candidates: Array) -> Node2D:
	if not _has_mechanic("can_chase") and not _has_mechanic("can_follow_target") and not _has_mechanic("can_guard_area") and not _has_mechanic("can_flee"):
		return null
	if not is_instance_valid(_actor):
		return null
	var radius := maxf(0.0, float(_option("can_chase", "detection_radius", _option("can_guard_area", "guard_radius", 0.0))))
	var best: Node2D
	var best_distance := radius
	for candidate in candidates:
		if not candidate is Node2D or candidate == _actor:
			continue
		var node: Node2D = candidate
		var distance := _actor.global_position.distance_to(node.global_position)
		if distance <= best_distance:
			best = node
			best_distance = distance
	return best


func _is_inside_guard_area(position: Vector2) -> bool:
	if not is_instance_valid(_actor):
		return false
	var center: Vector2 = _option("can_guard_area", "guard_center", _actor.global_position)
	var radius := maxf(0.0, float(_option("can_guard_area", "guard_radius", 128.0)))
	return _actor.global_position.distance_to(center) <= radius and center.distance_to(position) <= radius


func _find_ally_needing_help(allies: Array) -> Node2D:
	if not is_instance_valid(_actor):
		return null
	var radius := maxf(0.0, float(_option("can_assist", "assist_radius", 128.0)))
	var best: Node2D
	var best_distance := radius
	for ally in allies:
		if not ally is Node2D or ally == _actor:
			continue
		var node: Node2D = ally
		var needs_help := bool(node.get_meta("needs_assistance", false))
		if node.has_method("get_health_ratio"):
			needs_help = needs_help or float(node.call("get_health_ratio")) <= float(_option("can_assist", "ally_health_threshold", 0.35))
		if not needs_help:
			continue
		var distance := _actor.global_position.distance_to(node.global_position)
		if distance <= best_distance:
			best = node
			best_distance = distance
	return best


func _get_patrol_target() -> Variant:
	var points := _parse_json_array(str(_option("can_patrol", "patrol_points_json", "[]")))
	if points.is_empty() or not is_instance_valid(_actor):
		return null
	_patrol_index = posmod(_patrol_index, points.size())
	var point: Variant = points[_patrol_index]
	if not point is Array or point.size() < 2:
		return null
	var target := Vector2(float(point[0]), float(point[1]))
	if _actor.global_position.distance_to(target) <= maxf(1.0, float(_option("can_patrol", "arrival_distance", 8.0))):
		_patrol_index = posmod(_patrol_index + 1, points.size())
		point = points[_patrol_index]
		if point is Array and point.size() >= 2:
			target = Vector2(float(point[0]), float(point[1]))
	return target


func _get_wander_target(delta: float) -> Vector2:
	if not is_instance_valid(_actor):
		return Vector2.ZERO
	_wander_remaining -= delta
	if _wander_remaining <= 0.0 or _wander_target == Vector2.ZERO:
		var radius := maxf(0.0, float(_option("can_wander", "wander_radius", 96.0)))
		var angle := randf() * TAU
		var distance := randf_range(radius * 0.25, radius)
		_wander_target = _actor.global_position + Vector2(cos(angle), sin(angle)) * distance
		_wander_remaining = maxf(0.1, float(_option("can_wander", "target_duration", 3.0)))
	return _wander_target


func _has_mechanic(mechanic_id: String) -> bool:
	var root := get_object_root()
	return root != null and ObjectFactory.get_component(root, mechanic_id) != null


func _option(mechanic_id: String, key: String, fallback: Variant = null) -> Variant:
	var root := get_object_root()
	if root == null:
		return fallback
	var component := ObjectFactory.get_component(root, mechanic_id)
	return component.get_setting(key, fallback) if component != null else fallback


func _parse_json_dictionary(raw: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(raw)
	return parsed if parsed is Dictionary else {}


func _parse_json_array(raw: String) -> Array:
	var parsed: Variant = JSON.parse_string(raw)
	return parsed if parsed is Array else []


func _failed_result(reason: String) -> Dictionary:
	_fail(reason)
	return {"ok": false, "error": reason}


func _fail(reason: String) -> bool:
	action_failed.emit(reason)
	return false
