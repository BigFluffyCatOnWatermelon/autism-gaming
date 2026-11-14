@tool
extends ObjectComponent
class_name WorldTimeMechanicComponent

const GameplayTables = preload("res://scripts/object_system/object_gameplay_table_service.gd")

signal timer_activated
signal cooldown_ready
signal respawned
signal lifespan_expired
signal periodic_output(item_id: String, amount: int)
signal signal_triggered(signal_id: String, action: Dictionary)
signal action_failed(reason: String)
signal scheduled_event_dispatched(event: Dictionary)


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if component_id in ["has_timed_activation", "has_cooldown", "supports_timed_respawn", "has_lifespan", "has_periodic_output"]:
		set_process(true)
	_initialize_runtime_timers()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not is_inside_tree() or not is_finite(delta) or delta < 0.0:
		return
	match component_id:
		"has_timed_activation":
			advance_timed_activation(delta)
		"has_cooldown":
			if get_cooldown_remaining() > 0.0:
				advance_cooldown(delta)
		"supports_timed_respawn":
			if not bool(_get_state().get("alive", true)):
				advance_respawn(delta)
		"has_lifespan":
			if not bool(_get_state().get("expired", false)):
				advance_lifespan(delta)
		"has_periodic_output":
			advance_periodic_output(delta)


func _initialize_runtime_timers() -> void:
	var state := _get_state()
	if _has_mechanic("has_timed_activation") and not bool(state.get("activation_started", false)):
		state["activation_elapsed"] = 0.0
		state["activated"] = false
		state["activation_started"] = true
	if _has_mechanic("has_lifespan") and not bool(state.get("lifespan_started", false)):
		state["lifespan_remaining"] = maxf(0.0, float(_option("has_lifespan", "lifespan_seconds", 60.0)))
		state["expired"] = false
		state["lifespan_started"] = true
	_save_state(state)


func update_world_time(day: int, hour: float) -> Array[Dictionary]:
	var dispatched: Array[Dictionary] = []
	if not is_finite(hour):
		return dispatched
	var normalized_hour := fposmod(hour, 24.0)
	var state := _get_state()
	var fired: Dictionary = state.get("fired_schedule_events", {})
	if int(state.get("fired_schedule_day", day)) != day:
		fired.clear()
	for event in get_scheduled_events(day, normalized_hour):
		var event_id := str(event.get("event_id", ""))
		if event_id.is_empty():
			event_id = JSON.stringify(event)
		var event_key := event_id
		if fired.has(event_key):
			continue
		fired[event_key] = true
		dispatched.append(event.duplicate(true))
		scheduled_event_dispatched.emit(event.duplicate(true))
	state["fired_schedule_events"] = fired
	state["fired_schedule_day"] = day
	_save_state(state)
	return dispatched


func get_day_phase(hour: float) -> String:
	if not _has_mechanic("has_day_night_schedule"):
		return "day"
	var schedule := GameplayTables.normalize_schedule(_option("has_day_night_schedule", "schedule_json", "[]"))
	var normalized_hour := fposmod(hour, 24.0)
	for entry in schedule:
		if not entry is Dictionary:
			continue
		var start := float(entry.get("start", 0.0))
		var finish := float(entry.get("end", 24.0))
		var matches := normalized_hour >= start and normalized_hour < finish
		if start > finish:
			matches = normalized_hour >= start or normalized_hour < finish
		if matches:
			return str(entry.get("phase", "day"))
	return str(_option("has_day_night_schedule", "default_phase", "day"))


func get_season_data(season: String) -> Dictionary:
	if not _has_mechanic("changes_by_season"):
		return {}
	var values := _parse_json_dictionary(str(_option("changes_by_season", "seasonal_values_json", "{}")))
	var result: Variant = values.get(season.strip_edges().to_lower(), {})
	return result.duplicate(true) if result is Dictionary else {"value": result}


func start_timed_activation() -> bool:
	if not _has_mechanic("has_timed_activation"):
		return _fail("Активация по таймеру не включена.")
	var state := _get_state()
	state["activation_elapsed"] = 0.0
	state["activated"] = false
	state["activation_started"] = true
	_save_state(state)
	return true


func advance_timed_activation(delta: float) -> bool:
	if not _has_mechanic("has_timed_activation") or not _valid_delta(delta):
		return false
	var state := _get_state()
	if bool(state.get("activated", false)):
		return true
	var elapsed := float(state.get("activation_elapsed", 0.0)) + delta
	var delay := maxf(0.0, float(_option("has_timed_activation", "delay_seconds", 1.0)))
	state["activation_elapsed"] = elapsed
	var activated := elapsed >= delay
	state["activated"] = activated
	_save_state(state)
	if activated:
		var root := get_object_root()
		if root != null:
			root.set_meta("object_active", true)
		timer_activated.emit()
	return activated


func start_cooldown(duration: float = -1.0) -> bool:
	if not _has_mechanic("has_cooldown"):
		return _fail("Перезарядка не включена.")
	var resolved := duration if duration >= 0.0 else float(_option("has_cooldown", "cooldown_seconds", 1.0))
	if not is_finite(resolved) or resolved < 0.0:
		return _fail("Длительность перезарядки некорректна.")
	var state := _get_state()
	state["cooldown_remaining"] = resolved
	state["cooldown_ready"] = false
	_save_state(state)
	return true


func advance_cooldown(delta: float) -> bool:
	if not _has_mechanic("has_cooldown") or not _valid_delta(delta):
		return false
	var state := _get_state()
	var remaining := maxf(0.0, float(state.get("cooldown_remaining", 0.0)) - delta)
	state["cooldown_remaining"] = remaining
	var became_ready := remaining <= 0.0 and not bool(state.get("cooldown_ready", false))
	if remaining <= 0.0:
		state["cooldown_ready"] = true
	_save_state(state)
	if became_ready:
		cooldown_ready.emit()
	return remaining <= 0.0


func get_cooldown_remaining() -> float:
	return maxf(0.0, float(_get_state().get("cooldown_remaining", 0.0)))


func start_respawn() -> bool:
	if not _has_mechanic("supports_timed_respawn"):
		return _fail("Возрождение по таймеру не включено.")
	var state := _get_state()
	state["alive"] = false
	var root := get_object_root()
	if root != null:
		root.set_meta("object_alive", false)
	state["respawn_remaining"] = maxf(0.0, float(_option("supports_timed_respawn", "respawn_delay", 30.0)))
	_save_state(state)
	return true


func advance_respawn(delta: float) -> bool:
	if not _has_mechanic("supports_timed_respawn") or not _valid_delta(delta):
		return false
	var state := _get_state()
	if bool(state.get("alive", true)):
		return false
	var remaining := maxf(0.0, float(state.get("respawn_remaining", 0.0)) - delta)
	state["respawn_remaining"] = remaining
	if remaining <= 0.0:
		state["alive"] = true
		var root := get_object_root()
		if root != null:
			root.set_meta("object_alive", true)
		_save_state(state)
		respawned.emit()
		return true
	_save_state(state)
	return false


func start_lifespan() -> bool:
	if not _has_mechanic("has_lifespan"):
		return _fail("Время жизни не включено.")
	var state := _get_state()
	state["lifespan_remaining"] = maxf(0.0, float(_option("has_lifespan", "lifespan_seconds", 60.0)))
	state["expired"] = false
	state["lifespan_started"] = true
	_save_state(state)
	return true


func advance_lifespan(delta: float) -> bool:
	if not _has_mechanic("has_lifespan") or not _valid_delta(delta):
		return false
	var state := _get_state()
	if bool(state.get("expired", false)):
		return true
	var remaining := maxf(0.0, float(state.get("lifespan_remaining", _option("has_lifespan", "lifespan_seconds", 60.0))) - delta)
	state["lifespan_remaining"] = remaining
	var expired := remaining <= 0.0
	state["expired"] = expired
	_save_state(state)
	if expired:
		var root := get_object_root()
		if root != null:
			root.set_meta("object_active", false)
		lifespan_expired.emit()
	return expired


func get_weather_effect(weather_id: String) -> Dictionary:
	if not _has_mechanic("reacts_to_weather"):
		return {}
	var allowed := _split_csv(str(_option("reacts_to_weather", "allowed_weather_csv", "")))
	if not allowed.is_empty() and not allowed.has(weather_id.strip_edges().to_lower()):
		return {"allowed": false}
	var effects := _parse_json_dictionary(str(_option("reacts_to_weather", "weather_effects_json", "{}")))
	var value: Variant = effects.get(weather_id.strip_edges().to_lower(), {})
	return value.duplicate(true) if value is Dictionary else {"value": value}


func advance_periodic_output(delta: float) -> Dictionary:
	if not _has_mechanic("has_periodic_output") or not _valid_delta(delta):
		return _failed_result("Периодическое производство не включено или шаг времени некорректен.")
	var state := _get_state()
	var elapsed := float(state.get("output_elapsed", 0.0)) + delta
	var interval := maxf(0.001, float(_option("has_periodic_output", "output_interval", 60.0)))
	var cycles := int(floor(elapsed / interval))
	if cycles <= 0:
		state["output_elapsed"] = elapsed
		_save_state(state)
		return {"ok": true, "output": {}}
	var outputs := GameplayTables.load_production_table(
		str(_option("has_periodic_output", "production_table_path", "")),
		_option("has_periodic_output", "output_item_id", "resource"),
		maxi(1, int(_option("has_periodic_output", "amount_per_cycle", 1))),
		_option("has_periodic_output", "production_table_json", "[]")
	)
	if outputs.is_empty():
		return _failed_result("Для периодического производства не задан корректный item_id.")
	state["output_elapsed"] = fposmod(elapsed, interval)
	_save_state(state)
	var produced: Dictionary = {}
	for output in outputs:
		var item_id := str(output.get("item_id", ""))
		var amount := int(output.get("amount_per_cycle", 0)) * cycles
		if item_id.is_empty() or amount <= 0:
			continue
		produced[item_id] = int(produced.get(item_id, 0)) + amount
		periodic_output.emit(item_id, amount)
	return {"ok": true, "output": produced}


func receive_signal(signal_id: String, payload: Dictionary = {}) -> Dictionary:
	if not _has_mechanic("supports_signal_triggers"):
		return _failed_result("Триггеры сигналов не включены.")
	var rules := _parse_json_dictionary(str(_option("supports_signal_triggers", "event_rules_json", "{}")))
	if not rules.has(signal_id):
		return {"ok": false, "matched": false, "action": {}}
	var action: Variant = rules[signal_id]
	var result: Dictionary = action.duplicate(true) if action is Dictionary else {"action": str(action)}
	result["payload"] = payload.duplicate(true)
	signal_triggered.emit(signal_id, result)
	return {"ok": true, "matched": true, "action": result}


func get_scheduled_events(day: int, hour: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not _has_mechanic("supports_event_schedule"):
		return result
	var events := GameplayTables.normalize_schedule(_option("supports_event_schedule", "events_json", "[]"))
	var normalized_hour := fposmod(hour, 24.0)
	for event in events:
		if not event is Dictionary:
			continue
		var event_day := int(event.get("day", -1))
		if event_day >= 0 and event_day != day:
			continue
		var event_hour := fposmod(float(event.get("hour", 0.0)), 24.0)
		var hour_distance := minf(absf(event_hour - normalized_hour), 24.0 - absf(event_hour - normalized_hour))
		if hour_distance <= maxf(0.0, float(_option("supports_event_schedule", "hour_tolerance", 0.25))):
			result.append(event.duplicate(true))
	return result


func export_runtime_state() -> Dictionary:
	return _get_state().duplicate(true)


func import_runtime_state(state: Dictionary) -> bool:
	for key in ["activation_elapsed", "cooldown_remaining", "respawn_remaining", "lifespan_remaining", "output_elapsed"]:
		if state.has(key) and (not is_finite(float(state[key])) or float(state[key]) < 0.0):
			return _fail("Состояние таймеров содержит некорректное значение: " + key)
	_save_state(state.duplicate(true))
	return true


func _get_state() -> Dictionary:
	var root := get_object_root()
	if root == null:
		return {}
	if root.has_meta("object_builder_world_time_state"):
		var stored: Variant = root.get_meta("object_builder_world_time_state")
		if stored is Dictionary:
			return stored.duplicate(true)
	return {
		"activation_elapsed": 0.0,
		"activated": false,
		"activation_started": false,
		"cooldown_remaining": 0.0,
		"cooldown_ready": false,
		"alive": true,
		"respawn_remaining": 0.0,
		"lifespan_remaining": float(_option("has_lifespan", "lifespan_seconds", 60.0)),
		"expired": false,
		"lifespan_started": false,
		"fired_schedule_events": {},
		"output_elapsed": 0.0
	}


func _save_state(state: Dictionary) -> void:
	var root := get_object_root()
	if root != null:
		root.set_meta("object_builder_world_time_state", state.duplicate(true))


func _has_mechanic(mechanic_id: String) -> bool:
	var root := get_object_root()
	return root != null and ObjectFactory.get_component(root, mechanic_id) != null


func _option(mechanic_id: String, key: String, fallback: Variant = null) -> Variant:
	var root := get_object_root()
	if root == null:
		return fallback
	var component := ObjectFactory.get_component(root, mechanic_id)
	return component.get_setting(key, fallback) if component != null else fallback


func _valid_delta(delta: float) -> bool:
	return is_finite(delta) and delta >= 0.0


func _parse_json_dictionary(raw: String) -> Dictionary:
	return GameplayTables.parse_dictionary(raw)


func _parse_json_array(raw: String) -> Array:
	return GameplayTables.parse_array(raw)


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
