@tool
extends ObjectComponent
class_name AnimalMechanicComponent

signal animal_state_changed(state: Dictionary)
signal tamed(owner_id: String)
signal resource_produced(item_id: String, amount: int)
signal happiness_changed(value: float)
signal migrated(destination: String)
signal action_failed(reason: String)


func configure_mechanic(values: Dictionary) -> bool:
	for raw_key in values:
		var key := str(raw_key)
		if not settings.has(key) or typeof(values[raw_key]) != typeof(settings[key]):
			return _fail("Неизвестная настройка или неверный тип: " + key)
	for raw_key in values:
		settings[str(raw_key)] = values[raw_key]
	return true


func feed(food_id: String, nutrition: float = -1.0) -> bool:
	if not _has_mechanic("can_be_fed"):
		return _fail("Животное нельзя кормить.")
	if not _split_csv(str(_option("can_be_fed", "accepted_foods_csv", ""))).has(food_id.strip_edges().to_lower()):
		return _fail("Этот корм животному не подходит.")
	if nutrition < 0.0:
		nutrition = float(_option("can_be_fed", "nutrition_per_feed", 20.0))
	if not is_finite(nutrition) or nutrition <= 0.0:
		return _fail("Питательность корма должна быть положительной.")
	var state := _get_state()
	state["hunger"] = clampf(float(state.get("hunger", 0.0)) + nutrition, 0.0, 100.0)
	if _has_mechanic("has_happiness"):
		state["happiness"] = clampf(float(state.get("happiness", 50.0)) + float(_option("has_happiness", "feed_bonus", 5.0)), 0.0, 100.0)
	if _has_mechanic("can_be_tamed"):
		var taming_foods := _split_csv(str(_option("can_be_tamed", "taming_foods_csv", "")))
		if taming_foods.is_empty() or taming_foods.has(food_id.strip_edges().to_lower()):
			state["taming_progress"] = float(state.get("taming_progress", 0.0)) + maxf(0.0, float(_option("can_be_tamed", "taming_progress_per_feed", 1.0)))
			var required := maxf(0.1, float(_option("can_be_tamed", "taming_progress_required", 3.0)))
			if float(state["taming_progress"]) >= required and str(state.get("owner_id", "")).is_empty():
				state["owner_id"] = str(state.get("pending_owner_id", ""))
				tamed.emit(str(state["owner_id"]))
	_save_state(state)
	return true


func set_pending_owner(owner_id: String) -> void:
	var state := _get_state()
	state["pending_owner_id"] = owner_id
	_save_state(state)


func is_tamed() -> bool:
	return not str(_get_state().get("owner_id", "")).is_empty()


func get_owner_id() -> String:
	return str(_get_state().get("owner_id", ""))


func pet(actor_id: String = "") -> bool:
	if not _has_mechanic("can_be_petted"):
		return _fail("Животное не реагирует на поглаживание.")
	var state := _get_state()
	if float(state.get("pet_cooldown", 0.0)) > 0.0:
		return _fail("Животное пока не готово к повторному контакту.")
	var bonus := maxf(0.0, float(_option("can_be_petted", "affection_gain", 5.0)))
	state["affection"] = clampf(float(state.get("affection", 0.0)) + bonus, 0.0, 100.0)
	if _has_mechanic("has_happiness"):
		state["happiness"] = clampf(float(state.get("happiness", 50.0)) + float(_option("has_happiness", "pet_bonus", 10.0)), 0.0, 100.0)
	state["pet_cooldown"] = maxf(0.0, float(_option("can_be_petted", "pet_cooldown_seconds", 30.0)))
	state["last_petted_by"] = actor_id
	_save_state(state)
	if _has_mechanic("has_happiness"):
		happiness_changed.emit(float(state["happiness"]))
	return true


func advance_time(delta: float) -> void:
	if not is_finite(delta) or delta < 0.0:
		_fail("Шаг времени животного должен быть неотрицательным.")
		return
	var state := _get_state()
	state["pet_cooldown"] = maxf(0.0, float(state.get("pet_cooldown", 0.0)) - delta)
	state["breeding_cooldown"] = maxf(0.0, float(state.get("breeding_cooldown", 0.0)) - delta)
	_save_state(state)


func get_happiness() -> float:
	return clampf(float(_get_state().get("happiness", _option("has_happiness", "starting_happiness", 50.0))), 0.0, 100.0)


func change_happiness(amount: float) -> float:
	if not _has_mechanic("has_happiness") or not is_finite(amount):
		return get_happiness()
	var state := _get_state()
	state["happiness"] = clampf(float(state.get("happiness", _option("has_happiness", "starting_happiness", 50.0))) + amount, 0.0, 100.0)
	_save_state(state)
	happiness_changed.emit(float(state["happiness"]))
	return float(state["happiness"])


func can_live_in_habitat(biome_id: String, temperature: float = 20.0) -> bool:
	if not _has_mechanic("has_habitat"):
		return true
	var allowed := _split_csv(str(_option("has_habitat", "allowed_biomes_csv", "")))
	if not allowed.is_empty() and not allowed.has(biome_id.strip_edges().to_lower()):
		return false
	return temperature >= float(_option("has_habitat", "minimum_temperature", -100.0)) and temperature <= float(_option("has_habitat", "maximum_temperature", 100.0))


func get_routine_action(hour: float) -> String:
	if not _has_mechanic("has_daily_routine"):
		return "idle"
	var schedule := _parse_json_array(str(_option("has_daily_routine", "schedule_json", "[]")))
	for entry in schedule:
		if not entry is Dictionary:
			continue
		var start_hour := float(entry.get("start", 0.0))
		var end_hour := float(entry.get("end", 24.0))
		var normalized_hour := fposmod(hour, 24.0)
		var matches := normalized_hour >= start_hour and normalized_hour < end_hour
		if start_hour > end_hour:
			matches = normalized_hour >= start_hour or normalized_hour < end_hour
		if matches:
			return str(entry.get("action", "idle"))
	return str(_option("has_daily_routine", "default_action", "idle"))


func advance_resource_production(delta: float) -> Dictionary:
	if not _has_mechanic("can_produce_resources"):
		return _failed_result("Животное не производит ресурсы.")
	if not is_finite(delta) or delta < 0.0:
		return _failed_result("Шаг производства должен быть неотрицательным.")
	var state := _get_state()
	var elapsed := float(state.get("production_elapsed", 0.0)) + delta
	var interval := maxf(0.001, float(_option("can_produce_resources", "production_interval", 3600.0)))
	var cycles := int(floor(elapsed / interval))
	if cycles <= 0:
		state["production_elapsed"] = elapsed
		_save_state(state)
		return {"ok": true, "produced": {}}
	state["production_elapsed"] = fposmod(elapsed, interval)
	var item_id := str(_option("can_produce_resources", "resource_item_id", "milk"))
	var amount := maxi(1, int(_option("can_produce_resources", "amount_per_cycle", 1))) * cycles
	_save_state(state)
	var produced := {item_id: amount}
	resource_produced.emit(item_id, amount)
	return {"ok": true, "produced": produced}


func breed_with(other: Object) -> Dictionary:
	if not _has_mechanic("can_breed") or other == null or not other.has_method("_has_mechanic") or not bool(other.call("_has_mechanic", "can_breed")):
		return _failed_result("Для размножения нужны два совместимых животных.")
	var state := _get_state()
	var other_state: Dictionary = other.call("_get_state")
	if float(state.get("breeding_cooldown", 0.0)) > 0.0 or float(other_state.get("breeding_cooldown", 0.0)) > 0.0:
		return _failed_result("Одно из животных ещё не готово к размножению.")
	var offspring_id := str(_option("can_breed", "offspring_object_id", "animal_offspring"))
	var cooldown := maxf(0.0, float(_option("can_breed", "breeding_cooldown_seconds", 86400.0)))
	state["breeding_cooldown"] = cooldown
	other_state["breeding_cooldown"] = cooldown
	_save_state(state)
	other.call("_save_state", other_state)
	return {"ok": true, "offspring_object_id": offspring_id, "parent_ids": [str(get_object_root().get_meta("object_definition_id", "")), str(other.call("get_object_root").get_meta("object_definition_id", ""))]}


func mount(rider_id: String) -> Dictionary:
	if not _has_mechanic("can_be_mounted"):
		return _failed_result("Животное нельзя оседлать.")
	var state := _get_state()
	if not str(state.get("mounted_by", "")).is_empty():
		return _failed_result("Животное уже занято.")
	if _has_mechanic("can_be_tamed") and not is_tamed():
		return _failed_result("Сначала нужно приручить животное.")
	state["mounted_by"] = rider_id
	_save_state(state)
	return {"ok": true, "rider_id": rider_id, "speed": maxf(0.0, float(_option("can_be_mounted", "mount_speed", 120.0)))}


func dismount() -> bool:
	var state := _get_state()
	if str(state.get("mounted_by", "")).is_empty():
		return false
	state["mounted_by"] = ""
	_save_state(state)
	return true


func get_migration_destination(season: String) -> String:
	if not _has_mechanic("can_migrate"):
		return ""
	var routes := _parse_json_dictionary(str(_option("can_migrate", "migration_by_season_json", "{}")))
	return str(routes.get(season.strip_edges().to_lower(), ""))


func export_runtime_state() -> Dictionary:
	return _get_state().duplicate(true)


func import_runtime_state(state: Dictionary) -> bool:
	for key in ["hunger", "happiness", "affection", "taming_progress", "pet_cooldown", "breeding_cooldown", "production_elapsed"]:
		if state.has(key) and not is_finite(float(state[key])):
			return _fail("Состояние животного содержит некорректное число.")
	_save_state(state.duplicate(true))
	return true


func _get_state() -> Dictionary:
	var root := get_object_root()
	if root == null:
		return {}
	if root.has_meta("object_builder_animal_state"):
		var stored: Variant = root.get_meta("object_builder_animal_state")
		if stored is Dictionary:
			return stored.duplicate(true)
	return {
		"hunger": 0.0,
		"happiness": float(_option("has_happiness", "starting_happiness", 50.0)),
		"affection": 0.0,
		"taming_progress": 0.0,
		"owner_id": "",
		"pending_owner_id": "",
		"pet_cooldown": 0.0,
		"breeding_cooldown": 0.0,
		"production_elapsed": 0.0,
		"mounted_by": ""
	}


func _save_state(state: Dictionary) -> void:
	var root := get_object_root()
	if root != null:
		root.set_meta("object_builder_animal_state", state.duplicate(true))
		animal_state_changed.emit(state.duplicate(true))


func _has_mechanic(mechanic_id: String) -> bool:
	var root := get_object_root()
	return root != null and ObjectFactory.get_component(root, mechanic_id) != null


func _option(mechanic_id: String, key: String, fallback: Variant = null) -> Variant:
	var root := get_object_root()
	if root == null:
		return fallback
	var component := ObjectFactory.get_component(root, mechanic_id)
	return component.get_setting(key, fallback) if component != null else fallback


func _split_csv(value: String) -> PackedStringArray:
	var result := PackedStringArray()
	for raw in value.split(",", false):
		var item := raw.strip_edges().to_lower()
		if not item.is_empty() and not result.has(item):
			result.append(item)
	return result


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
