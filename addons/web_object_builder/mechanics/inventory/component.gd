@tool
extends ObjectComponent
class_name InventoryMechanicComponent

const GameplayTables = preload("res://scripts/object_system/object_gameplay_table_service.gd")
const ItemCatalog = preload("res://scripts/item_catalog_service.gd")

const ITEM_STACKS = preload("res://scripts/object_system/object_item_stack_service.gd")

signal inventory_changed(state: Dictionary)
signal item_added(item_id: String, amount: int)
signal item_removed(item_id: String, amount: int)
signal equipment_changed(slot_id: String, item: Dictionary)
signal hotbar_changed(slot_index: int, inventory_slot: int)
signal action_failed(reason: String)


func get_option(key: String, fallback: Variant = null) -> Variant:
	return get_setting(key, fallback)


func get_inventory() -> Array[Dictionary]:
	var state := _get_state()
	var result: Array[Dictionary] = []
	for item in state.get("slots", []):
		result.append(item.duplicate(true) if item is Dictionary else {})
	return result


## Common storage read API. Inventory slots retain their fixed empty entries.
func get_item_stacks(_options: Dictionary = {}) -> Array[Dictionary]:
	return get_inventory()


func get_equipment() -> Dictionary:
	return _get_state().get("equipment", {}).duplicate(true)


func get_hotbar() -> Dictionary:
	return _get_state().get("hotbar", {}).duplicate(true)


func get_item_count(item_id: String) -> int:
	return ITEM_STACKS.count_items(get_inventory(), item_id)


func get_inventory_weight() -> float:
	return ITEM_STACKS.total_weight(get_inventory()) + ITEM_STACKS.total_weight(get_equipment().values())


## Common storage read API. Includes equipped items in the carried-weight total.
func get_total_weight() -> float:
	return get_inventory_weight()


func can_add_item(item_id: String, amount: int, weight_per_unit: float = 0.0, tags: Array = []) -> bool:
	if not _has_mechanic("has_inventory") or item_id.strip_edges().is_empty() or amount <= 0:
		return false
	if not _passes_item_filter(item_id, tags):
		return false
	if _has_mechanic("has_weight_capacity"):
		var maximum := maxf(0.0, float(_option("has_weight_capacity", "max_weight", 100.0)))
		if maximum > 0.0 and get_inventory_weight() + float(amount) * maxf(0.0, weight_per_unit) > maximum + 0.0001:
			return false
	return _has_free_slot_or_stack(item_id)


func add_item(
	item_id: String,
	amount: int = 1,
	max_stack: int = 1,
	weight_per_unit: float = 0.0,
	tags: Array = [],
	rarity: String = "common"
) -> Dictionary:
	return add_item_data({
		"item_id": item_id,
		"amount": amount,
		"max_stack": max_stack,
		"weight": weight_per_unit,
		"tags": tags,
		"rarity": rarity,
		"bound": false
	})


## Shared storage contract used by inventory, containers and transfer adapters.
## Storage-specific rules (filters, carry weight and fixed slot count) stay here.
func add_item_data(item_data: Dictionary, amount_override: int = -1, _options: Dictionary = {}) -> Dictionary:
	if not _has_mechanic("has_inventory"):
		return _failed_result("У объекта не включён инвентарь.")
	var stack := ITEM_STACKS.normalize_item(item_data)
	if stack.is_empty():
		return _failed_result("Некорректная запись предмета.")
	if amount_override >= 0:
		stack["amount"] = amount_override
	var normalized_id := str(stack.get("item_id", "")).strip_edges()
	var amount := int(stack.get("amount", 0))
	var weight_per_unit := float(stack.get("weight", 0.0))
	var tags: Array = stack.get("tags", [])
	if normalized_id.is_empty() or amount <= 0:
		return _failed_result("Некорректный ID или количество предмета.")
	if not is_finite(weight_per_unit) or weight_per_unit < 0.0:
		return _failed_result("Вес предмета должен быть конечным и неотрицательным.")
	if not _passes_item_filter(normalized_id, tags):
		return _failed_result("Предмет отклонён фильтром инвентаря.")

	var amount_allowed := amount
	if _has_mechanic("has_weight_capacity") and weight_per_unit > 0.0:
		var maximum_weight := maxf(0.0, float(_option("has_weight_capacity", "max_weight", 100.0)))
		if maximum_weight > 0.0:
			var available_weight := maxf(0.0, maximum_weight - get_inventory_weight())
			amount_allowed = mini(amount, int(floor((available_weight + 0.0001) / weight_per_unit)))
	var capacity_remainder := amount - amount_allowed
	stack["amount"] = amount_allowed

	var state := _get_state()
	var slots: Array = state.get("slots", [])
	var add_result := ITEM_STACKS.add_stack(slots, stack, slots.size(), true)
	state["slots"] = add_result.get("items", slots)
	_save_state(state)
	var accepted_total := int(add_result.get("accepted", 0))
	var remainder := capacity_remainder + int(add_result.get("remainder", amount_allowed))
	if accepted_total > 0:
		item_added.emit(normalized_id, accepted_total)
	return {"ok": remainder == 0, "accepted": accepted_total, "remainder": remainder}


func remove_item(item_id: String, amount: int = 1, allow_bound: bool = false) -> bool:
	return bool(remove_item_data(item_id, amount, {"allow_bound": allow_bound}).get("ok", false))


## Returns the exact stack records removed, so rollback/transfer keeps all item metadata.
func remove_item_data(item_id: String, amount: int = 1, options: Dictionary = {}) -> Dictionary:
	if amount <= 0:
		return _failed_result("Количество для удаления должно быть положительным.")
	var state := _get_state()
	var slots: Array = state.get("slots", [])
	var allow_bound := bool(options.get("allow_bound", false))
	var skip_bound := not allow_bound and _has_mechanic("supports_item_binding")
	var remove_result := ITEM_STACKS.remove_stack(slots, item_id, amount, skip_bound, true)
	if not bool(remove_result.get("ok", false)):
		return _failed_result("В инвентаре недостаточно доступного количества: " + item_id)
	state["slots"] = remove_result.get("items", slots)
	_save_state(state)
	item_removed.emit(item_id, amount)
	return {
		"ok": true,
		"removed": int(remove_result.get("removed", amount)),
		"remainder": 0,
		"items": remove_result.get("removed_items", [])
	}


func split_stack(slot_index: int, amount: int) -> int:
	if not _has_mechanic("supports_stack_splitting") or not bool(_option("supports_stack_splitting", "allow_split", true)):
		_fail("Разделение стопок отключено.")
		return -1
	var state := _get_state()
	var slots: Array = state.get("slots", [])
	if slot_index < 0 or slot_index >= slots.size():
		_fail("Слот инвентаря не существует.")
		return -1
	var item: Dictionary = slots[slot_index]
	var current_amount := int(item.get("amount", 0))
	if item.is_empty() or amount <= 0 or amount >= current_amount or bool(item.get("bound", false)):
		_fail("Нельзя разделить выбранную стопку на указанное количество.")
		return -1
	var empty_index := _find_empty_slot(slots)
	if empty_index < 0:
		_fail("Нет свободного слота для новой стопки.")
		return -1
	item["amount"] = current_amount - amount
	slots[slot_index] = item
	var split_item := item.duplicate(true)
	split_item["amount"] = amount
	slots[empty_index] = split_item
	state["slots"] = slots
	_save_state(state)
	return empty_index


func equip_from_slot(slot_index: int, equipment_slot: String) -> bool:
	if not _has_mechanic("has_equipment_slots"):
		return _fail("Слоты экипировки не включены.")
	var slot_id := equipment_slot.strip_edges().to_lower()
	if not _split_csv(str(_option("has_equipment_slots", "equipment_slots_csv", "head,chest,legs,feet,hand"))).has(slot_id):
		return _fail("Неизвестный слот экипировки: " + slot_id)
	var state := _get_state()
	var slots: Array = state.get("slots", [])
	if slot_index < 0 or slot_index >= slots.size():
		return _fail("В выбранном слоте нет предмета.")
	var item: Dictionary = slots[slot_index]
	if item.is_empty():
		return _fail("В выбранном слоте нет предмета.")
	if bool(item.get("bound", false)) and _has_mechanic("supports_item_binding"):
		return _fail("Предмет закреплён и не может быть перемещён.")
	var equipment: Dictionary = state.get("equipment", {})
	if equipment.has(slot_id):
		return _fail("Слот экипировки уже занят.")
	equipment[slot_id] = item
	slots[slot_index] = {}
	state["slots"] = slots
	state["equipment"] = equipment
	_save_state(state)
	equipment_changed.emit(slot_id, item)
	return true


func unequip_to_inventory(equipment_slot: String) -> bool:
	var slot_id := equipment_slot.strip_edges().to_lower()
	var state := _get_state()
	var equipment: Dictionary = state.get("equipment", {})
	if not equipment.has(slot_id):
		return _fail("Слот экипировки пуст.")
	var item: Dictionary = equipment[slot_id]
	equipment.erase(slot_id)
	state["equipment"] = equipment
	_save_state(state)
	var add_result := add_item(
		str(item.get("item_id", "")),
		int(item.get("amount", 1)),
		int(item.get("max_stack", 1)),
		float(item.get("weight", 0.0)),
		item.get("tags", []),
		str(item.get("rarity", "common"))
	)
	if int(add_result.get("accepted", 0)) < int(item.get("amount", 1)):
		var accepted := int(add_result.get("accepted", 0))
		if accepted > 0:
			remove_item(str(item.get("item_id", "")), accepted, true)
		state = _get_state()
		equipment = state.get("equipment", {})
		equipment[slot_id] = item
		state["equipment"] = equipment
		_save_state(state)
		return _fail("В инвентаре недостаточно места для снятия экипировки.")
	equipment_changed.emit(slot_id, {})
	return true

func assign_hotbar(hotbar_slot: int, inventory_slot: int) -> bool:
	if not _has_mechanic("supports_hotbar"):
		return _fail("Панель быстрого доступа не включена.")
	var hotbar_count := maxi(1, int(_option("supports_hotbar", "hotbar_slots", 9)))
	var slots := get_inventory()
	if hotbar_slot < 0 or hotbar_slot >= hotbar_count or inventory_slot < 0 or inventory_slot >= slots.size() or slots[inventory_slot].is_empty():
		return _fail("Неверный слот панели быстрого доступа или инвентаря.")
	var state := _get_state()
	var hotbar: Dictionary = state.get("hotbar", {})
	hotbar[str(hotbar_slot)] = inventory_slot
	state["hotbar"] = hotbar
	_save_state(state)
	hotbar_changed.emit(hotbar_slot, inventory_slot)
	return true


func select_hotbar_slot(hotbar_slot: int) -> bool:
	if not _has_mechanic("supports_hotbar"):
		return _fail("Панель быстрого доступа не включена.")
	var hotbar := get_hotbar()
	if not hotbar.has(str(hotbar_slot)):
		return _fail("На выбранном слоте нет предмета.")
	var state := _get_state()
	state["selected_hotbar"] = hotbar_slot
	_save_state(state)
	return true


func get_selected_hotbar_item() -> Dictionary:
	var state := _get_state()
	var selected := int(state.get("selected_hotbar", -1))
	var hotbar := state.get("hotbar", {})
	if selected < 0 or not hotbar.has(str(selected)):
		return {}
	var inventory_slot := int(hotbar[str(selected)])
	var slots := get_inventory()
	return slots[inventory_slot].duplicate(true) if inventory_slot >= 0 and inventory_slot < slots.size() else {}


func filter_items(query: String = "", tag: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var normalized_query := query.strip_edges().to_lower()
	var normalized_tag := tag.strip_edges().to_lower()
	for item in get_inventory():
		if item.is_empty():
			continue
		var item_id := str(item.get("item_id", "")).to_lower()
		var tags: Array = item.get("tags", [])
		if not normalized_query.is_empty() and not item_id.contains(normalized_query):
			continue
		if not normalized_tag.is_empty() and not tags.has(normalized_tag):
			continue
		result.append(item)
	return result


func sort_inventory(mode: String = "") -> bool:
	if not _has_mechanic("supports_item_sorting"):
		return _fail("Сортировка инвентаря не включена.")
	var sort_mode := mode.strip_edges().to_lower()
	if sort_mode.is_empty():
		sort_mode = str(_option("supports_item_sorting", "default_sort", "name")).to_lower()
	if not ["name", "weight", "rarity", "type"].has(sort_mode):
		return _fail("Неизвестный режим сортировки: " + sort_mode)
	var state := _get_state()
	state["slots"] = ITEM_STACKS.sort_items(state.get("slots", []), sort_mode, true)
	_save_state(state)
	return true


func transfer_to(target: Object, item_id: String, amount: int) -> Dictionary:
	if not _has_mechanic("supports_quick_transfer") or target == null or not target.has_method("add_item_data"):
		return _failed_result("Быстрое перемещение недоступно.")
	if not target.has_method("_has_mechanic") or not bool(target.call("_has_mechanic", "supports_quick_transfer")):
		return _failed_result("У принимающего инвентаря не включено быстрое перемещение.")
	if amount <= 0:
		return _failed_result("Количество для перемещения должно быть положительным.")
	var quantity := mini(amount, get_item_count(item_id))
	if quantity <= 0:
		return _failed_result("Предмет не найден в исходном инвентаре.")
	var removed := remove_item_data(item_id, quantity)
	if not bool(removed.get("ok", false)):
		return _failed_result("Не удалось изъять предмет из исходного инвентаря.")

	# Transfer every extracted stack separately. Rarity, quality, tags and any
	# extension metadata must not be flattened to whichever stack was first.
	var transferred := 0
	for removed_stack in removed.get("items", []):
		if not removed_stack is Dictionary:
			continue
		var stack_data: Dictionary = removed_stack.duplicate(true)
		var stack_amount := int(stack_data.get("amount", 0))
		if stack_amount <= 0:
			continue
		var added_value: Variant = target.call("add_item_data", stack_data, stack_amount)
		var accepted := 0
		if added_value is Dictionary:
			accepted = clampi(int(added_value.get("accepted", 0)), 0, stack_amount)
		transferred += accepted
		var rejected := stack_amount - accepted
		if rejected > 0:
			var rollback := stack_data.duplicate(true)
			rollback["amount"] = rejected
			var rollback_result := add_item_data(rollback)
			if int(rollback_result.get("accepted", 0)) < rejected:
				push_error("InventoryMechanicComponent: не удалось вернуть непринятую стопку '%s'." % item_id)
	return {
		"ok": transferred == quantity,
		"transferred": transferred,
		"remainder": quantity - transferred
	}


func craft(recipe_id: String) -> Dictionary:
	if not _has_mechanic("supports_item_crafting"):
		return _failed_result("Создание предметов не включено.")
	var recipes := GameplayTables.load_recipe_table(str(_option("supports_item_crafting", "recipes_table_path", "")), _option("supports_item_crafting", "recipes_json", "{}"))
	if not recipes.has(recipe_id):
		return _failed_result("Рецепт не найден: " + recipe_id)
	var recipe: Dictionary = recipes[recipe_id]
	var ingredients: Dictionary = recipe.get("ingredients", {})
	var removed: Array[Dictionary] = []
	for ingredient_id in ingredients:
		var amount := int(ingredients[ingredient_id])
		if amount <= 0 or get_item_count(str(ingredient_id)) < amount:
			for rollback in removed:
				add_item_data(rollback)
			return _failed_result("Недостаточно ингредиентов для рецепта: " + str(ingredient_id))
		var remove_result := remove_item_data(str(ingredient_id), amount)
		if not bool(remove_result.get("ok", false)):
			for rollback in removed:
				add_item_data(rollback)
			return _failed_result("Не удалось списать ингредиент: " + str(ingredient_id))
		for removed_stack in remove_result.get("items", []):
			if removed_stack is Dictionary:
				removed.append(removed_stack)
	var output: Dictionary = recipe.get("output", {}).duplicate(true)
	var output_item_id := str(output.get("item_id", "")).strip_edges()
	var item_definition := ItemCatalog.get_definition(output_item_id)
	var catalog_output: Dictionary = ItemCatalog.rebuild_item_data(item_definition) if item_definition != null else {}
	catalog_output.merge(output, true)
	output = catalog_output
	output["item_id"] = output_item_id
	output["amount"] = maxi(1, int(output.get("amount", 1)))
	output["max_stack"] = maxi(1, int(output.get("max_stack", 1)))
	output["weight"] = maxf(0.0, float(output.get("weight", 0.0)))
	output["tags"] = output.get("tags", []) if output.get("tags", []) is Array else []
	output["rarity"] = str(output.get("rarity", "common"))
	var result := add_item_data(output)
	if int(result.get("accepted", 0)) < int(output.get("amount", 1)):
		var partial_output := int(result.get("accepted", 0))
		if partial_output > 0:
			remove_item(str(output.get("item_id", "")), partial_output, true)
		for rollback in removed:
			add_item_data(rollback)
		return _failed_result("Недостаточно места или веса для результата рецепта.")
	return {"ok": true, "recipe_id": recipe_id, "output": output.duplicate(true)}


func bind_item(slot_index: int, bound: bool = true) -> bool:
	if not _has_mechanic("supports_item_binding") or not bool(_option("supports_item_binding", "allow_binding", true)):
		return _fail("Закрепление предметов отключено.")
	var state := _get_state()
	var slots: Array = state.get("slots", [])
	if slot_index < 0 or slot_index >= slots.size():
		return _fail("Выбранный слот пуст.")
	var item: Dictionary = slots[slot_index]
	if item.is_empty():
		return _fail("Выбранный слот пуст.")
	item["bound"] = bound
	slots[slot_index] = item
	state["slots"] = slots
	_save_state(state)
	return true


func export_runtime_state() -> Dictionary:
	return _get_state().duplicate(true)


func import_runtime_state(state: Dictionary) -> bool:
	if not state.get("slots", []) is Array:
		return _fail("Состояние инвентаря не содержит массив слотов.")
	var capacity := maxi(1, int(_option("has_inventory", "slot_capacity", 24)))
	var slots: Array = state.get("slots", []).duplicate(true)
	if slots.size() > capacity:
		return _fail("Сохранённый инвентарь превышает вместимость.")
	while slots.size() < capacity:
		slots.append({})
	for item in slots:
		if not item is Dictionary:
			return _fail("Слот инвентаря содержит некорректные данные.")
	var normalized := {
		"slots": slots,
		"equipment": state.get("equipment", {}).duplicate(true),
		"hotbar": state.get("hotbar", {}).duplicate(true),
		"selected_hotbar": int(state.get("selected_hotbar", -1))
	}
	_save_state(normalized)
	return true


func _get_state() -> Dictionary:
	var root := get_object_root()
	if root == null:
		return {"slots": [], "equipment": {}, "hotbar": {}, "selected_hotbar": -1}
	if root.has_meta("object_builder_inventory_state"):
		var stored: Variant = root.get_meta("object_builder_inventory_state")
		if stored is Dictionary:
			var restored: Dictionary = stored.duplicate(true)
			restored["slots"] = ITEM_STACKS.normalize_items(stored.get("slots", []), true)
			return restored
	var capacity := maxi(1, int(_option("has_inventory", "slot_capacity", 24)))
	var slots: Array = []
	for _index in range(capacity):
		slots.append({})
	var initial: Variant = JSON.parse_string(str(_option("has_inventory", "initial_items_json", "[]")))
	for entry in ITEM_STACKS.normalize_items(initial):
		var slot := _find_empty_slot(slots)
		if slot >= 0:
			slots[slot] = entry
	var state := {"slots": slots, "equipment": {}, "hotbar": {}, "selected_hotbar": -1}
	root.set_meta("object_builder_inventory_state", state)
	return state.duplicate(true)


func _save_state(state: Dictionary) -> void:
	var root := get_object_root()
	if root == null:
		return
	var copied := state.duplicate(true)
	copied["slots"] = ITEM_STACKS.normalize_items(copied.get("slots", []), true)
	root.set_meta("object_builder_inventory_state", copied)
	inventory_changed.emit(copied.duplicate(true))


func _has_free_slot_or_stack(item_id: String) -> bool:
	return ITEM_STACKS.has_room_for_item(get_inventory(), item_id)


func _passes_item_filter(item_id: String, tags: Array) -> bool:
	if not _has_mechanic("supports_item_filters"):
		return true
	var rules := _parse_json_dictionary(str(_option("supports_item_filters", "filter_rules_json", "{}")))
	var allowed_ids: Array = rules.get("allowed_item_ids", [])
	var blocked_ids: Array = rules.get("blocked_item_ids", [])
	if not allowed_ids.is_empty() and not allowed_ids.has(item_id):
		return false
	if blocked_ids.has(item_id):
		return false
	var required_tags: Array = rules.get("required_tags", [])
	var blocked_tags: Array = rules.get("blocked_tags", [])
	for tag in required_tags:
		if not tags.has(tag):
			return false
	for tag in blocked_tags:
		if tags.has(tag):
			return false
	return true


func _find_empty_slot(slots: Array) -> int:
	for index in range(slots.size()):
		if slots[index] is Dictionary and (slots[index] as Dictionary).is_empty():
			return index
	return -1


func _find_last_matching_slot(slots: Array, item_id: String) -> int:
	for index in range(slots.size() - 1, -1, -1):
		if slots[index] is Dictionary and str(slots[index].get("item_id", "")) == item_id:
			return index
	return -1


func _find_item(item_id: String) -> Dictionary:
	for item in get_inventory():
		if str(item.get("item_id", "")) == item_id:
			return item
	return {"item_id": item_id, "amount": 0, "max_stack": 1, "weight": 0.0, "tags": [], "rarity": "common"}


func _weight_of_slots(slots: Array) -> float:
	return ITEM_STACKS.total_weight(slots)


func _equipment_weight(state: Dictionary) -> float:
	return ITEM_STACKS.total_weight(state.get("equipment", {}).values())


func _parse_json_dictionary(raw: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(raw)
	return parsed if parsed is Dictionary else {}


func _split_csv(value: String) -> PackedStringArray:
	var result := PackedStringArray()
	for raw in value.split(",", false):
		var item := raw.strip_edges().to_lower()
		if not item.is_empty() and not result.has(item):
			result.append(item)
	return result


func _has_mechanic(mechanic_id: String) -> bool:
	var root := get_object_root()
	if root == null:
		return false
	var component := ObjectFactory.get_component(root, mechanic_id)
	if component == null:
		return false
	var enabled_value: Variant = component.get_setting("enabled", null)
	return bool(enabled_value) if enabled_value != null else true


func _option(mechanic_id: String, key: String, fallback: Variant = null) -> Variant:
	var root := get_object_root()
	if root == null:
		return fallback
	var component := ObjectFactory.get_component(root, mechanic_id)
	return component.get_setting(key, fallback) if component != null else fallback


func _failed_result(reason: String) -> Dictionary:
	_fail(reason)
	return {"ok": false, "error": reason}


func _fail(reason: String) -> bool:
	action_failed.emit(reason)
	return false
