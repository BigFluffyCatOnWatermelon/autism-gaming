@tool
extends ObjectComponent
class_name WorldGenerationMechanicComponent

signal growth_stage_changed(stage: int, ratio: float)
signal spread_completed(cells: Array[Vector2i])
signal action_failed(reason: String)


func _ready() -> void:
	if not Engine.is_editor_hint() and _has_mechanic("can_grow"):
		set_process(true)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not is_inside_tree() or not _has_mechanic("can_grow"):
		return
	if is_finite(delta) and delta > 0.0:
		advance_growth(delta)


func set_world_seed(seed_value: int) -> bool:
	if not _has_mechanic("supports_world_seed"):
		return _fail("Фиксированный seed мира не включён.")
	var state := _get_state()
	state["world_seed"] = seed_value
	_save_state(state)
	return true


func get_world_seed() -> int:
	return int(_get_state().get("world_seed", int(_option("supports_world_seed", "default_seed", 1))))


func can_spawn_in_biome(biome_id: String) -> bool:
	if not _has_mechanic("spawns_by_biome"):
		return true
	var allowed := _split_csv(str(_option("spawns_by_biome", "allowed_biomes_csv", "")))
	return allowed.is_empty() or allowed.has(biome_id.strip_edges().to_lower())


func can_spawn_in_region(region_id: String, current_count: int = 0) -> bool:
	if _has_mechanic("supports_region_rules"):
		var allowed := _split_csv(str(_option("supports_region_rules", "allowed_regions_csv", "")))
		var blocked := _split_csv(str(_option("supports_region_rules", "blocked_regions_csv", "")))
		var normalized := region_id.strip_edges().to_lower()
		if blocked.has(normalized) or (not allowed.is_empty() and not allowed.has(normalized)):
			return false
		var rules := _parse_json_dictionary(str(_option("supports_region_rules", "region_rules_json", "{}")))
		var region_rule: Variant = rules.get(normalized, {})
		if region_rule is Dictionary and not bool(region_rule.get("allowed", true)):
			return false
	if _has_mechanic("has_density_rules") and current_count >= get_spawn_limit(region_id):
		return false
	return true


func get_spawn_limit(region_id: String) -> int:
	if not _has_mechanic("has_density_rules"):
		return 2147483647
	var base_limit := maxi(0, int(_option("has_density_rules", "max_per_region", 20)))
	var overrides := _parse_json_dictionary(str(_option("has_density_rules", "density_by_region_json", "{}")))
	return maxi(0, int(overrides.get(region_id.strip_edges().to_lower(), base_limit)))


func can_spawn(context: Dictionary = {}) -> bool:
	if not can_spawn_in_biome(str(context.get("biome", ""))):
		return false
	if not can_spawn_in_region(str(context.get("region", "")), int(context.get("region_count", 0))):
		return false
	if not _has_mechanic("has_spawn_conditions"):
		return true
	var conditions := _parse_json_dictionary(str(_option("has_spawn_conditions", "conditions_json", "{}")))
	var temperature := float(context.get("temperature", 20.0))
	var elevation := float(context.get("elevation", 0.0))
	if temperature < float(conditions.get("min_temperature", -100.0)) or temperature > float(conditions.get("max_temperature", 100.0)):
		return false
	if elevation < float(conditions.get("min_elevation", -100000.0)) or elevation > float(conditions.get("max_elevation", 100000.0)):
		return false
	var allowed_seasons: Array = conditions.get("seasons", [])
	if not allowed_seasons.is_empty() and not allowed_seasons.has(str(context.get("season", "")).to_lower()):
		return false
	var required_tags: Array = conditions.get("required_tags", [])
	var context_tags: Array = context.get("tags", [])
	for tag in required_tags:
		if not context_tags.has(tag):
			return false
	return true


func choose_variant(seed_override: int = -1) -> Dictionary:
	if not _has_mechanic("has_random_variants"):
		return {}
	var variants := _parse_json_array(str(_option("has_random_variants", "variants_json", "[]")))
	var total_weight := 0.0
	for variant in variants:
		if variant is Dictionary:
			total_weight += maxf(0.0, float(variant.get("weight", 1.0)))
	if total_weight <= 0.0:
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_override if seed_override >= 0 else get_world_seed()
	var roll := rng.randf() * total_weight
	for variant in variants:
		if not variant is Dictionary:
			continue
		roll -= maxf(0.0, float(variant.get("weight", 1.0)))
		if roll <= 0.0:
			return variant.duplicate(true)
	return variants[-1].duplicate(true) if variants.size() > 0 and variants[-1] is Dictionary else {}


func generate_layout(bounds: Rect2, seed_override: int = -1) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if not _has_mechanic("has_procedural_layout") or bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return result
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_override if seed_override >= 0 else get_world_seed()
	var count := maxi(0, int(_option("has_procedural_layout", "object_count", 12)))
	var spacing := maxf(1.0, float(_option("has_procedural_layout", "spacing", 32.0)))
	var pattern := str(_option("has_procedural_layout", "pattern", "scatter")).to_lower()
	var center := bounds.position + bounds.size * 0.5
	for index in range(count):
		var position := center
		match pattern:
			"grid":
				var columns := maxi(1, int(floor(bounds.size.x / spacing)))
				var rows := maxi(1, int(floor(bounds.size.y / spacing)))
				var column := index % columns
				var row := int(floor(float(index) / float(columns)))
				if row >= rows:
					break
				position = bounds.position + Vector2((float(column) + 0.5) * spacing, (float(row) + 0.5) * spacing)
			"ring":
				var angle := TAU * float(index) / float(maxi(1, count))
				var radius := minf(bounds.size.x, bounds.size.y) * 0.35
				position = center + Vector2(cos(angle), sin(angle)) * radius
			"cluster":
				position = center + Vector2(rng.randf_range(-spacing, spacing), rng.randf_range(-spacing, spacing))
			_:
				position = Vector2(rng.randf_range(bounds.position.x, bounds.end.x), rng.randf_range(bounds.position.y, bounds.end.y))
		result.append(position)
	return result


func get_spread_cells(origin: Vector2i, occupied: Array = []) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not _has_mechanic("can_spread"):
		return result
	var radius := clampi(int(_option("can_spread", "spread_radius", 1)), 1, 32)
	var maximum := maxi(1, int(_option("can_spread", "max_spread_cells", 4)))
	var diagonal := bool(_option("can_spread", "allow_diagonal", false))
	var candidates: Array[Vector2i] = []
	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			if x == 0 and y == 0:
				continue
			if diagonal and maxi(absi(x), absi(y)) > radius:
				continue
			if not diagonal and absi(x) + absi(y) > radius:
				continue
			var cell := origin + Vector2i(x, y)
			if occupied.has(cell):
				continue
			candidates.append(cell)
	var rng := RandomNumberGenerator.new()
	rng.seed = get_world_seed() + origin.x * 92821 + origin.y * 68917
	for index in range(candidates.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var temporary := candidates[index]
		candidates[index] = candidates[swap_index]
		candidates[swap_index] = temporary
	for index in range(mini(maximum, candidates.size())):
		result.append(candidates[index])
	spread_completed.emit(result)
	return result


func advance_growth(delta: float) -> Dictionary:
	if not _has_mechanic("can_grow"):
		return _failed_result("Рост не включён.")
	if not is_finite(delta) or delta < 0.0:
		return _failed_result("Шаг роста должен быть неотрицательным.")
	var state := _get_state()
	var duration := maxf(0.001, float(_option("can_grow", "growth_duration", 60.0)))
	var elapsed := minf(duration, float(state.get("growth_elapsed", 0.0)) + delta)
	var ratio := elapsed / duration
	var thresholds := _parse_json_array(str(_option("can_grow", "growth_stages_json", "[0.25,0.5,0.75,1.0]")))
	var stage := 0
	for threshold in thresholds:
		if ratio >= float(threshold):
			stage += 1
	var changed := stage != int(state.get("growth_stage", 0))
	state["growth_elapsed"] = elapsed
	state["growth_stage"] = stage
	_save_state(state)
	if changed:
		growth_stage_changed.emit(stage, ratio)
	return {"ok": true, "stage": stage, "ratio": ratio, "completed": ratio >= 1.0}


func get_growth_stage() -> int:
	return maxi(0, int(_get_state().get("growth_stage", 0)))


func adapt_to_environment(context: Dictionary) -> Dictionary:
	if not _has_mechanic("adapts_to_environment"):
		return {}
	var rules := _parse_json_dictionary(str(_option("adapts_to_environment", "adaptation_rules_json", "{}")))
	var result: Dictionary = {}
	for context_key in context:
		if not rules.has(str(context_key)):
			continue
		var context_rules: Variant = rules[str(context_key)]
		if not context_rules is Dictionary:
			continue
		var modifier: Variant = context_rules.get(str(context[context_key]), {})
		if not modifier is Dictionary:
			continue
		for modifier_key in modifier:
			var value: Variant = modifier[modifier_key]
			if value is int or value is float:
				result[str(modifier_key)] = float(result.get(str(modifier_key), 1.0)) * float(value)
			else:
				result[str(modifier_key)] = value
	return result


func export_runtime_state() -> Dictionary:
	return _get_state().duplicate(true)


func import_runtime_state(state: Dictionary) -> bool:
	var elapsed := float(state.get("growth_elapsed", 0.0))
	if not is_finite(elapsed) or elapsed < 0.0:
		return _fail("Состояние генерации содержит некорректный прогресс.")
	_save_state({
		"world_seed": int(state.get("world_seed", int(_option("supports_world_seed", "default_seed", 1)))),
		"growth_elapsed": elapsed,
		"growth_stage": maxi(0, int(state.get("growth_stage", 0)))
	})
	return true


func _get_state() -> Dictionary:
	var root := get_object_root()
	if root == null:
		return {}
	if root.has_meta("object_builder_world_generation_state"):
		var stored: Variant = root.get_meta("object_builder_world_generation_state")
		if stored is Dictionary:
			return stored.duplicate(true)
	return {
		"world_seed": int(_option("supports_world_seed", "default_seed", 1)),
		"growth_elapsed": 0.0,
		"growth_stage": 0
	}


func _save_state(state: Dictionary) -> void:
	var root := get_object_root()
	if root != null:
		root.set_meta("object_builder_world_generation_state", state.duplicate(true))


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
