@tool
extends ObjectComponent
class_name HarvestingMechanicComponent

signal progress_changed(progress: float, duration: float, ratio: float)
signal stage_changed(stage: int)
signal harvest_completed(resources: Dictionary, quality: String)
signal regrown
signal action_failed(reason: String)

var _progress := 0.0
var _active := false
var _stage := 0
var _regrowth_elapsed := 0.0
var _regrowing := false


func _on_configured() -> void:
	_progress = 0.0
	_active = false
	_stage = 0
	_regrowth_elapsed = 0.0
	_regrowing = false


func get_option(key: String, fallback: Variant = null) -> Variant:
	return get_setting(key, fallback)


func configure_mechanic(values: Dictionary) -> bool:
	for raw_key in values:
		var key := str(raw_key)
		if not settings.has(key):
			return _fail("Неизвестная настройка: %s" % key)
		if typeof(values[raw_key]) != typeof(settings[key]):
			return _fail("Неверный тип настройки: %s" % key)
	for raw_key in values:
		settings[str(raw_key)] = values[raw_key]
	return true


func can_harvest(tool_id: String = "", season: String = "") -> bool:
	if _has_mechanic("can_be_harvested"):
		if not bool(_option("can_be_harvested", "enabled", true)):
			return false
	if _has_mechanic("requires_tool"):
		var required_tool := str(_option("requires_tool", "required_tool_id", "")).strip_edges().to_lower()
		if not required_tool.is_empty() and tool_id.strip_edges().to_lower() != required_tool:
			return false
		var minimum_level := int(_option("requires_tool", "minimum_tool_level", 0))
		if _tool_level(tool_id) < minimum_level:
			return false
	if _has_mechanic("can_be_mined"):
		var mining_tool := str(_option("can_be_mined", "required_tool_id", "pickaxe")).strip_edges().to_lower()
		if tool_id.strip_edges().to_lower() != mining_tool:
			return false
		var required_power := float(_option("can_be_mined", "minimum_mining_power", 1.0))
		if _tool_power(tool_id) < required_power:
			return false
	if _has_mechanic("has_seasonal_yield") and not season.strip_edges().is_empty():
		var seasons := _parse_json_dictionary("has_seasonal_yield", "seasonal_yields_json")
		if not seasons.is_empty() and not seasons.has(season.strip_edges().to_lower()):
			return false
	return true


func begin_harvest(tool_id: String = "", season: String = "") -> bool:
	if not can_harvest(tool_id, season):
		return _fail("Для добычи не выполнены условия инструмента, сезона или доступности.")
	_progress = 0.0
	_stage = 0
	_active = true
	_emit_progress()
	return true


func advance_harvest(delta: float, tool_id: String = "", season: String = "", external_efficiency: float = 1.0) -> Dictionary:
	if not is_finite(delta) or delta <= 0.0:
		return _failed_result("Шаг времени должен быть положительным конечным числом.")
	if not is_finite(external_efficiency) or external_efficiency <= 0.0:
		return _failed_result("Эффективность инструмента должна быть положительной.")
	if not _active and not begin_harvest(tool_id, season):
		return _failed_result("Не удалось начать добычу.")
	if not can_harvest(tool_id, season):
		_active = false
		return _failed_result("Условия добычи изменились во время работы.")
	var duration := _harvest_duration()
	var efficiency := external_efficiency * _configured_tool_efficiency(tool_id)
	_progress = minf(duration, _progress + delta * efficiency)
	_update_stage(duration)
	_emit_progress()
	var completed := _progress >= duration
	var result := {"ok": true, "completed": completed, "progress": _progress, "duration": duration, "ratio": clampf(_progress / duration, 0.0, 1.0)}
	if completed:
		_active = false
		var resources := roll_resource_yield(season)
		var quality := roll_quality()
		harvest_completed.emit(resources, quality)
		result["resources"] = resources
		result["quality"] = quality
	return result


func get_harvest_progress() -> Dictionary:
	var duration := _harvest_duration()
	return {"progress": _progress, "duration": duration, "ratio": clampf(_progress / duration, 0.0, 1.0), "stage": _stage, "active": _active}


func roll_resource_yield(season: String = "") -> Dictionary:
	var table := _parse_json_array("yields_resources", "resource_table_json")
	var result: Dictionary = {}
	var seasonal_multiplier := _seasonal_multiplier(season)
	for entry in table:
		if not entry is Dictionary:
			continue
		var item_id := str(entry.get("item_id", "")).strip_edges()
		if item_id.is_empty():
			continue
		var chance := clampf(float(entry.get("chance", 1.0)), 0.0, 1.0)
		if randf() > chance:
			continue
		var minimum := maxi(0, int(entry.get("min", 1)))
		var maximum := maxi(minimum, int(entry.get("max", minimum)))
		var amount := int(round(float(randi_range(minimum, maximum)) * seasonal_multiplier))
		if amount > 0:
			result[item_id] = int(result.get(item_id, 0)) + amount
	return result


func roll_quality() -> String:
	if not _has_mechanic("has_quality_variants"):
		return "normal"
	var chances := _parse_json_dictionary("has_quality_variants", "quality_chances_json")
	var total := 0.0
	for value in chances.values():
		total += maxf(0.0, float(value))
	if total <= 0.0:
		return "normal"
	var roll := randf() * total
	for quality in chances:
		roll -= maxf(0.0, float(chances[quality]))
		if roll <= 0.0:
			return str(quality)
	return str(chances.keys()[-1]) if not chances.is_empty() else "normal"


func start_regrowth() -> bool:
	if not _has_mechanic("has_regrowth"):
		return _fail("У объекта не включено повторное отрастание.")
	_regrowth_elapsed = 0.0
	_regrowing = true
	return true


func advance_regrowth(delta: float) -> bool:
	if not _regrowing:
		return false
	if not is_finite(delta) or delta < 0.0:
		return _fail("Шаг времени восстановления не может быть отрицательным.")
	_regrowth_elapsed += delta
	var duration := maxf(0.0, float(_option("has_regrowth", "regrowth_seconds", 30.0)))
	if _regrowth_elapsed < duration:
		return false
	_regrowing = false
	_regrowth_elapsed = duration
	regrown.emit()
	return true


func get_regrowth_progress() -> float:
	if not _regrowing:
		return 1.0 if _regrowth_elapsed >= _option("has_regrowth", "regrowth_seconds", 30.0) else 0.0
	var duration := maxf(0.001, float(_option("has_regrowth", "regrowth_seconds", 30.0)))
	return clampf(_regrowth_elapsed / duration, 0.0, 1.0)


func export_runtime_state() -> Dictionary:
	return {
		"progress": _progress,
		"active": _active,
		"stage": _stage,
		"regrowth_elapsed": _regrowth_elapsed,
		"regrowing": _regrowing
	}


func import_runtime_state(state: Dictionary) -> bool:
	var progress := float(state.get("progress", 0.0))
	var elapsed := float(state.get("regrowth_elapsed", 0.0))
	if not is_finite(progress) or progress < 0.0 or not is_finite(elapsed) or elapsed < 0.0:
		return _fail("Состояние добычи содержит некорректные значения.")
	_progress = minf(progress, _harvest_duration())
	_active = bool(state.get("active", false))
	_stage = maxi(0, int(state.get("stage", 0)))
	_regrowth_elapsed = elapsed
	_regrowing = bool(state.get("regrowing", false))
	_emit_progress()
	return true


func _harvest_duration() -> float:
	var value := float(_option("has_harvest_progress", "harvest_duration", _option("can_be_harvested", "harvest_time_seconds", 1.0)))
	return maxf(0.001, value)


func _update_stage(duration: float) -> void:
	if not _has_mechanic("has_multi_stage_harvest"):
		return
	var thresholds := _parse_json_array("has_multi_stage_harvest", "harvest_stages_json")
	var next_stage := 0
	var ratio := _progress / duration
	for threshold in thresholds:
		if ratio >= float(threshold):
			next_stage += 1
	if next_stage != _stage:
		_stage = next_stage
		stage_changed.emit(_stage)


func _seasonal_multiplier(season: String) -> float:
	if not _has_mechanic("has_seasonal_yield") or season.strip_edges().is_empty():
		return 1.0
	var seasons := _parse_json_dictionary("has_seasonal_yield", "seasonal_yields_json")
	var value: Variant = seasons.get(season.strip_edges().to_lower(), 1.0)
	if value is Dictionary:
		value = value.get("multiplier", 1.0)
	return maxf(0.0, float(value))


func _configured_tool_efficiency(tool_id: String) -> float:
	if not _has_mechanic("has_tool_efficiency"):
		return 1.0
	var efficiencies := _parse_json_dictionary("has_tool_efficiency", "tool_efficiency_json")
	return maxf(0.01, float(efficiencies.get(tool_id.strip_edges().to_lower(), 1.0)))


func _tool_level(tool_id: String) -> int:
	var tools := _parse_json_dictionary("requires_tool", "tool_requirements_json")
	var value: Variant = tools.get(tool_id.strip_edges().to_lower(), {})
	return int(value.get("level", 0)) if value is Dictionary else 0


func _tool_power(tool_id: String) -> float:
	var tools := _parse_json_dictionary("can_be_mined", "tool_power_json")
	var value: Variant = tools.get(tool_id.strip_edges().to_lower(), {})
	return float(value.get("power", 0.0)) if value is Dictionary else 0.0


func _parse_json_dictionary(mechanic_id: String, key: String) -> Dictionary:
	var raw := str(_option(mechanic_id, key, "{}"))
	var parsed: Variant = JSON.parse_string(raw)
	return parsed if parsed is Dictionary else {}


func _parse_json_array(mechanic_id: String, key: String) -> Array:
	var raw := str(_option(mechanic_id, key, "[]"))
	var parsed: Variant = JSON.parse_string(raw)
	return parsed if parsed is Array else []


func _has_mechanic(mechanic_id: String) -> bool:
	var object_root := get_object_root()
	return object_root != null and ObjectFactory.get_component(object_root, mechanic_id) != null


func _option(mechanic_id: String, key: String, fallback: Variant = null) -> Variant:
	var object_root := get_object_root()
	if object_root == null:
		return fallback
	var component := ObjectFactory.get_component(object_root, mechanic_id)
	return component.get_setting(key, fallback) if component != null else fallback


func _emit_progress() -> void:
	var duration := _harvest_duration()
	progress_changed.emit(_progress, duration, clampf(_progress / duration, 0.0, 1.0))


func _failed_result(reason: String) -> Dictionary:
	_fail(reason)
	return {"ok": false, "error": reason, "completed": false}


func _fail(reason: String) -> bool:
	action_failed.emit(reason)
	return false
