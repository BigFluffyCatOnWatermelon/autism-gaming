@tool
extends ObjectComponent
class_name ConstructionMechanicComponent

signal placement_changed(position: Vector2, rotation_degrees: float)
signal build_progress_changed(progress: float, stage: int)
signal upgrade_completed(level: int)
signal dismantled(refund: Dictionary)
signal action_failed(reason: String)


func get_option(key: String, fallback: Variant = null) -> Variant:
	return get_setting(key, fallback)


func snap_position(position: Vector2) -> Vector2:
	if not _has_mechanic("snaps_to_grid"):
		return position
	var grid: Vector2 = _option("snaps_to_grid", "grid_size", Vector2.ONE)
	var origin: Vector2 = _option("snaps_to_grid", "grid_origin", Vector2.ZERO)
	grid.x = maxf(0.001, absf(grid.x))
	grid.y = maxf(0.001, absf(grid.y))
	return origin + Vector2(round((position.x - origin.x) / grid.x) * grid.x, round((position.y - origin.y) / grid.y) * grid.y)


func can_be_placed(position: Vector2, blockers: Array = [], terrain_id: String = "") -> bool:
	if not _has_mechanic("can_be_placed") or not bool(_option("can_be_placed", "placement_enabled", true)):
		return false
	if bool(_get_state().get("dismantled", false)):
		return false
	var candidate := snap_position(position)
	var bounds := _parse_json_dictionary(str(_option("can_be_placed", "world_bounds_json", "{}")))
	if bounds.has("min") and bounds.has("max"):
		var minimum: Array = bounds.min
		var maximum: Array = bounds.max
		if minimum.size() >= 2 and maximum.size() >= 2:
			if candidate.x < float(minimum[0]) or candidate.y < float(minimum[1]) or candidate.x > float(maximum[0]) or candidate.y > float(maximum[1]):
				return false
	var allowed_terrain := _split_csv(str(_option("can_be_placed", "allowed_terrain_csv", "")))
	if not allowed_terrain.is_empty() and not allowed_terrain.has(terrain_id.strip_edges().to_lower()):
		return false
	var clearance := maxf(0.0, float(_option("can_be_placed", "placement_clearance", 0.0)))
	for blocker in blockers:
		if blocker is Rect2:
			var blocker_rect: Rect2 = blocker
			if blocker_rect.has_point(candidate):
				return false
		if blocker is Node2D:
			var blocker_node: Node2D = blocker
			if blocker_node.global_position.distance_to(candidate) < clearance:
				return false
	return true


func get_placement_rotation() -> float:
	return float(_get_state().get("rotation_degrees", 0.0))


func rotate_placement(direction: int = 1) -> float:
	if not _has_mechanic("supports_rotation_placement"):
		_fail("Поворот при размещении не включён.")
		return get_placement_rotation()
	var step := maxf(1.0, float(_option("supports_rotation_placement", "rotation_step_degrees", 90.0)))
	var state := _get_state()
	state["rotation_degrees"] = fposmod(float(state.get("rotation_degrees", 0.0)) + step * float(sign(direction)), 360.0)
	_save_state(state)
	placement_changed.emit(Vector2.ZERO, float(state["rotation_degrees"]))
	return float(state["rotation_degrees"])


func get_build_cost() -> Dictionary:
	return _parse_json_dictionary(str(_option("has_build_cost", "build_cost_json", "{}")))


func can_afford(inventory: Object) -> bool:
	if inventory == null or not inventory.has_method("get_item_count"):
		return false
	var costs := _get_material_costs()
	for item_id in costs:
		if int(inventory.call("get_item_count", str(item_id))) < int(costs[item_id]):
			return false
	return true


func consume_build_materials(inventory: Object) -> bool:
	if not _has_mechanic("requires_build_materials"):
		return _fail("Проверка материалов для строительства не включена.")
	if inventory == null or not inventory.has_method("remove_item") or not inventory.has_method("get_item_count"):
		return _fail("Для строительства нужен доступный инвентарь.")
	if not can_afford(inventory):
		return _fail("Недостаточно материалов для строительства.")
	if not _consume_costs(inventory, _get_material_costs()):
		return _fail("Не удалось списать строительные материалы.")
	return true

func get_upgrade_level() -> int:
	return maxi(0, int(_get_state().get("upgrade_level", 0)))


func upgrade(inventory: Object = null) -> Dictionary:
	if not _has_mechanic("can_be_upgraded"):
		return _failed_result("Улучшения для объекта не включены.")
	var current_level := get_upgrade_level()
	var maximum := maxi(0, int(_option("can_be_upgraded", "max_upgrade_level", 3)))
	if current_level >= maximum:
		return _failed_result("Достигнут максимальный уровень улучшения.")
	var costs := _upgrade_cost(current_level + 1)
	if not costs.is_empty():
		if inventory == null or not inventory.has_method("get_item_count") or not inventory.has_method("remove_item"):
			return _failed_result("Для улучшения нужен доступный инвентарь.")
		if not can_afford(inventory):
			return _failed_result("Недостаточно материалов для улучшения.")
		if not _consume_costs(inventory, costs):
			return _failed_result("Не удалось списать материал улучшения.")
	var state := _get_state()
	state["upgrade_level"] = current_level + 1
	_save_state(state)
	upgrade_completed.emit(current_level + 1)
	return {"ok": true, "level": current_level + 1}

func dismantle() -> Dictionary:
	if not _has_mechanic("can_be_dismantled"):
		return _failed_result("Разбор конструкции не включён.")
	var state := _get_state()
	if bool(state.get("dismantled", false)):
		return _failed_result("Конструкция уже разобрана.")
	var ratio := clampf(float(_option("can_be_dismantled", "refund_ratio", 0.5)), 0.0, 1.0)
	var refund: Dictionary = {}
	for item_id in get_build_cost():
		var amount := int(floor(float(get_build_cost()[item_id]) * ratio))
		if amount > 0:
			refund[str(item_id)] = amount
	state["dismantled"] = true
	state["build_progress"] = 0.0
	_save_state(state)
	dismantled.emit(refund)
	return {"ok": true, "refund": refund}


func get_preview_state(position: Vector2, blockers: Array = [], terrain_id: String = "") -> Dictionary:
	if not _has_mechanic("supports_build_preview"):
		return {}
	var snapped := snap_position(position)
	var valid := can_be_placed(snapped, blockers, terrain_id)
	return {
		"position": snapped,
		"rotation_degrees": get_placement_rotation(),
		"valid": valid,
		"alpha": clampf(float(_option("supports_build_preview", "preview_alpha", 0.45)), 0.0, 1.0),
		"valid_color": str(_option("supports_build_preview", "valid_color", "#66dd88")),
		"invalid_color": str(_option("supports_build_preview", "invalid_color", "#ee6677"))
	}


func advance_build_progress(delta: float) -> Dictionary:
	if not _has_mechanic("has_build_stages"):
		return _failed_result("Этапы строительства не включены.")
	if not is_finite(delta) or delta <= 0.0:
		return _failed_result("Шаг строительства должен быть положительным.")
	var state := _get_state()
	var duration := maxf(0.001, float(_option("has_build_stages", "build_duration", 10.0)))
	state["build_progress"] = minf(duration, float(state.get("build_progress", 0.0)) + delta)
	var ratio := float(state["build_progress"]) / duration
	var thresholds := _parse_json_array(str(_option("has_build_stages", "stage_thresholds_json", "[0.25,0.5,0.75,1.0]")))
	var stage := 0
	for threshold in thresholds:
		if ratio >= float(threshold):
			stage += 1
	if stage != int(state.get("build_stage", 0)):
		state["build_stage"] = stage
	_save_state(state)
	build_progress_changed.emit(ratio, stage)
	return {"ok": true, "progress": ratio, "stage": stage, "completed": ratio >= 1.0}


func get_build_stage() -> int:
	return maxi(0, int(_get_state().get("build_stage", 0)))


func export_blueprint() -> Dictionary:
	if not _has_mechanic("supports_blueprint"):
		return {}
	var state := _get_state()
	return {
		"schema_version": 1,
		"source_object_id": str(get_object_root().get_meta("object_definition_id", "")),
		"placement_rotation": get_placement_rotation(),
		"upgrade_level": get_upgrade_level(),
		"build_stage": get_build_stage(),
		"build_progress": float(state.get("build_progress", 0.0)),
		"grid_size": _option("snaps_to_grid", "grid_size", Vector2.ZERO),
		"grid_origin": _option("snaps_to_grid", "grid_origin", Vector2.ZERO)
	}


func apply_blueprint(blueprint: Dictionary) -> bool:
	if not _has_mechanic("supports_blueprint"):
		return _fail("Чертежи для объекта не включены.")
	if int(blueprint.get("schema_version", 0)) != 1:
		return _fail("Версия чертежа не поддерживается.")
	var state := _get_state()
	state["rotation_degrees"] = fposmod(float(blueprint.get("placement_rotation", 0.0)), 360.0)
	state["upgrade_level"] = maxi(0, int(blueprint.get("upgrade_level", 0)))
	state["build_stage"] = maxi(0, int(blueprint.get("build_stage", 0)))
	state["build_progress"] = maxf(0.0, float(blueprint.get("build_progress", 0.0)))
	_save_state(state)
	return true


func export_runtime_state() -> Dictionary:
	return _get_state().duplicate(true)


func import_runtime_state(state: Dictionary) -> bool:
	for key in ["rotation_degrees", "upgrade_level", "build_stage", "build_progress"]:
		if state.has(key) and not is_finite(float(state[key])):
			return _fail("Состояние строительства содержит некорректное число.")
	var normalized := {
		"rotation_degrees": fposmod(float(state.get("rotation_degrees", 0.0)), 360.0),
		"upgrade_level": maxi(0, int(state.get("upgrade_level", 0))),
		"build_stage": maxi(0, int(state.get("build_stage", 0))),
		"build_progress": maxf(0.0, float(state.get("build_progress", 0.0))),
		"dismantled": bool(state.get("dismantled", false))
	}
	_save_state(normalized)
	return true


func _consume_costs(inventory: Object, costs: Dictionary) -> bool:
	var removed: Array[Dictionary] = []
	for item_id in costs:
		var amount := int(costs[item_id])
		var sample := _find_inventory_item(inventory, str(item_id))
		if not bool(inventory.call("remove_item", str(item_id), amount)):
			for item in removed:
				inventory.call(
					"add_item",
					str(item.get("item_id", "")),
					int(item.get("amount", 0)),
					int(item.get("max_stack", 1)),
					float(item.get("weight", 0.0)),
					item.get("tags", []),
					str(item.get("rarity", "common"))
				)
			return false
		sample["amount"] = amount
		removed.append(sample)
	return true


func _find_inventory_item(inventory: Object, item_id: String) -> Dictionary:
	if inventory != null and inventory.has_method("get_inventory"):
		for item in inventory.call("get_inventory"):
			if item is Dictionary and str(item.get("item_id", "")) == item_id:
				return item.duplicate(true)
	return {"item_id": item_id, "amount": 0, "max_stack": 1, "weight": 0.0, "tags": [], "rarity": "common"}


func _get_material_costs() -> Dictionary:
	var costs := get_build_cost()
	var material_costs := _parse_json_dictionary(str(_option("requires_build_materials", "material_costs_json", "{}")))
	return material_costs if not material_costs.is_empty() else costs


func _upgrade_cost(level: int) -> Dictionary:
	var costs := _parse_json_dictionary(str(_option("can_be_upgraded", "upgrade_costs_json", "{}")))
	var value: Variant = costs.get(str(level), {})
	return value if value is Dictionary else {}


func _get_state() -> Dictionary:
	var root := get_object_root()
	if root == null:
		return {}
	if root.has_meta("object_builder_construction_state"):
		var state: Variant = root.get_meta("object_builder_construction_state")
		if state is Dictionary:
			return state.duplicate(true)
	return {"rotation_degrees": 0.0, "upgrade_level": 0, "build_stage": 0, "build_progress": 0.0, "dismantled": false}


func _save_state(state: Dictionary) -> void:
	var root := get_object_root()
	if root != null:
		root.set_meta("object_builder_construction_state", state.duplicate(true))


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


func _split_csv(value: String) -> PackedStringArray:
	var result := PackedStringArray()
	for raw in value.split(",", false):
		var item := raw.strip_edges().to_lower()
		if not item.is_empty() and not result.has(item):
			result.append(item)
	return result


func _failed_result(reason: String) -> Dictionary:
	_fail(reason)
	return {"ok": false, "error": reason}


func _fail(reason: String) -> bool:
	action_failed.emit(reason)
	return false
