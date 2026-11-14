extends RefCounted
class_name ObjectGameplayTableService

const ItemCatalog = preload("res://scripts/item_catalog_service.gd")

## Shared compatibility layer for gameplay tables stored in legacy JSON settings.
## It normalizes records without changing their stable item IDs or runtime state keys.


static func parse_array(value: Variant) -> Array:
	if value is Array:
		return value.duplicate(true)
	if value is String:
		var parsed: Variant = JSON.parse_string(value)
		return parsed if parsed is Array else []
	return []


static func parse_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value.duplicate(true)
	if value is String:
		var parsed: Variant = JSON.parse_string(value)
		return parsed if parsed is Dictionary else {}
	return {}


static func normalize_item_id(value: Variant) -> String:
	return str(value).strip_edges()


static func normalize_item_output(item_id_value: Variant, amount_value: Variant, minimum_amount: int = 1) -> Dictionary:
	var item_id := normalize_item_id(item_id_value)
	var amount := int(amount_value)
	if item_id.is_empty() or amount <= 0:
		return {}
	amount = maxi(minimum_amount, amount)
	return {"item_id": item_id, "amount": amount}


static func normalize_yield_table(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw_entry in parse_array(value):
		if not raw_entry is Dictionary:
			continue
		var entry: Dictionary = raw_entry
		var item_id := normalize_item_id(entry.get("item_id", entry.get("id", "")))
		if item_id.is_empty():
			continue
		var minimum := maxi(0, int(entry.get("min", entry.get("minimum", entry.get("amount", 1)))))
		var maximum := maxi(minimum, int(entry.get("max", entry.get("maximum", entry.get("amount", minimum)))))
		result.append({
			"item_id": item_id,
			"chance": clampf(float(entry.get("chance", 1.0)), 0.0, 1.0),
			"min": minimum,
			"max": maximum
		})
	return result


static func normalize_recipe_table(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	var source := parse_dictionary(value)
	for raw_recipe_id in source:
		var recipe_id := str(raw_recipe_id).strip_edges()
		var raw_recipe: Variant = source.get(raw_recipe_id)
		if recipe_id.is_empty() or not raw_recipe is Dictionary:
			continue
		var recipe: Dictionary = raw_recipe
		var ingredients_value: Variant = recipe.get("ingredients", {})
		if not ingredients_value is Dictionary:
			continue
		var ingredients: Dictionary = {}
		var invalid_ingredients := false
		for raw_item_id in ingredients_value:
			var item_id := normalize_item_id(raw_item_id)
			var amount := int(ingredients_value[raw_item_id])
			if item_id.is_empty() or amount <= 0:
				invalid_ingredients = true
				break
			ingredients[item_id] = amount
		if invalid_ingredients:
			continue
		var output_value: Variant = recipe.get("output", {})
		if not output_value is Dictionary:
			continue
		var output: Dictionary = output_value.duplicate(true)
		var normalized_output := normalize_item_output(output.get("item_id", ""), output.get("amount", 1))
		if normalized_output.is_empty():
			continue
		output["item_id"] = normalized_output.item_id
		output["amount"] = normalized_output.amount
		if output.has("max_stack"):
			output["max_stack"] = maxi(1, int(output.get("max_stack", 1)))
		if output.has("weight"):
			output["weight"] = maxf(0.0, float(output.get("weight", 0.0)))
		if output.has("tags") and not output.get("tags") is Array:
			output["tags"] = []
		if output.has("rarity"):
			output["rarity"] = str(output.get("rarity", "common"))
		var normalized_recipe := recipe.duplicate(true)
		normalized_recipe["ingredients"] = ingredients
		normalized_recipe["output"] = output
		result[recipe_id] = normalized_recipe
	return result


static func normalize_schedule(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in parse_array(value):
		if entry is Dictionary:
			result.append(entry.duplicate(true))
	return result



static func load_yield_table(resource_path: String, legacy_value: Variant) -> Array[Dictionary]:
	var table := _load_table_resource(resource_path, "yield")
	if table != null:
		var normalized := normalize_yield_table(table.entries)
		_warn_unknown_item_ids(_collect_item_ids_from_entries(normalized), resource_path)
		return normalized
	return normalize_yield_table(legacy_value)


static func load_loot_table(resource_path: String, legacy_value: Variant) -> Array[Dictionary]:
	var table := _load_table_resource(resource_path, "loot")
	if table != null:
		var normalized := normalize_yield_table(table.entries)
		_warn_unknown_item_ids(_collect_item_ids_from_entries(normalized), resource_path)
		return normalized
	return normalize_yield_table(legacy_value)


static func load_recipe_table(resource_path: String, legacy_value: Variant) -> Dictionary:
	var table := _load_table_resource(resource_path, "recipe")
	if table != null:
		var recipes: Dictionary = {}
		for entry in table.entries:
			var recipe_id := str(entry.get("recipe_id", entry.get("id", ""))).strip_edges()
			if recipe_id.is_empty() or recipes.has(recipe_id):
				continue
			recipes[recipe_id] = entry
		var normalized := normalize_recipe_table(recipes)
		var referenced_ids: Array[String] = []
		for recipe_value in normalized.values():
			if not recipe_value is Dictionary:
				continue
			var recipe: Dictionary = recipe_value
			var ingredients: Dictionary = recipe.get("ingredients", {})
			for item_id in ingredients.keys():
				referenced_ids.append(str(item_id))
			var output: Dictionary = recipe.get("output", {})
			referenced_ids.append(str(output.get("item_id", "")))
		_warn_unknown_item_ids(referenced_ids, resource_path)
		return normalized
	return normalize_recipe_table(legacy_value)


static func load_production_table(
	resource_path: String,
	legacy_item_id: Variant,
	legacy_amount: Variant,
	legacy_table_value: Variant = null
) -> Array[Dictionary]:
	var table := _load_table_resource(resource_path, "production")
	if table != null:
		var normalized := normalize_production_table(table.entries)
		_warn_unknown_item_ids(_collect_item_ids_from_entries(normalized), resource_path)
		return normalized
	var legacy_entries := normalize_production_table(legacy_table_value)
	if not legacy_entries.is_empty():
		_warn_unknown_item_ids(_collect_item_ids_from_entries(legacy_entries), "legacy production settings")
		return legacy_entries
	var legacy_output := normalize_item_output(legacy_item_id, legacy_amount)
	if legacy_output.is_empty():
		return []
	return [{"item_id": legacy_output.item_id, "amount_per_cycle": legacy_output.amount}]


static func normalize_production_table(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw_entry in parse_array(value):
		if not raw_entry is Dictionary:
			continue
		var entry: Dictionary = raw_entry
		var item_id := normalize_item_id(entry.get("item_id", entry.get("id", "")))
		var amount := int(entry.get("amount_per_cycle", entry.get("amount", 1)))
		if item_id.is_empty() or amount <= 0:
			continue
		result.append({
			"item_id": item_id,
			"amount_per_cycle": amount
		})
	return result


static func _load_table_resource(resource_path: String, expected_type: String) -> GameplayTableDefinition:
	var normalized_path := resource_path.strip_edges()
	if normalized_path.is_empty():
		return null
	if not ResourceLoader.exists(normalized_path):
		push_warning("GameplayTableService: таблица не найдена: " + normalized_path)
		return null
	var table := ResourceLoader.load(normalized_path) as GameplayTableDefinition
	if table == null:
		push_warning("GameplayTableService: ресурс не является GameplayTableDefinition: " + normalized_path)
		return null
	if table.table_type != expected_type:
		push_warning("GameplayTableService: ожидалась таблица '%s', получена '%s': %s" % [expected_type, table.table_type, normalized_path])
		return null
	return table



static func _collect_item_ids_from_entries(entries: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for entry in entries:
		var item_id := normalize_item_id(entry.get("item_id", ""))
		if not item_id.is_empty() and item_id not in result:
			result.append(item_id)
	return result


static func _warn_unknown_item_ids(item_ids: Array[String], resource_path: String) -> void:
	var validation := ItemCatalog.validate_item_ids(item_ids)
	for missing_id in validation.get("missing", []):
		push_warning("GameplayTableService: item_id '%s' отсутствует в каталоге предметов (таблица %s)." % [str(missing_id), resource_path])
