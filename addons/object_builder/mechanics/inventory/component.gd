@tool
extends ObjectComponent
class_name InventoryMechanicComponent

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


func get_equipment() -> Dictionary:
	return _get_state().get("equipment", {}).duplicate(true)


func get_hotbar() -> Dictionary:
	return _get_state().get("hotbar", {}).duplicate(true)


func get_item_count(item_id: String) -> int:
	var total := 0
	for item in get_inventory():
		if str(item.get("item_id", "")) == item_id:
			total += int(item.get("amount", 0))
	return total


func get_inventory_weight() -> float:
	var total := 0.0
	for item in get_inventory():
		total += float(item.get("weight", 0.0)) * float(item.get("amount", 0))
	for item in get_equipment().values():
		if item is Dictionary:
			total += float(item.get("weight", 0.0)) * float(item.get("amount", 1))
	return total


func can_add_item(item_id: String, amount: int, weight_per_unit: float = 0.0, tags: Array = []) -> bool:
	if not _has_mechanic("has_inventory") or item_id.strip_edges().is_empty() or amount <= 0:
		return false
	if not _passes_item_filter(item_id, tags):
		return false
	if _has_mechanic("has_weight_capacity"):
		var maximum := maxf(0.0, float(_option("has_weight_capacity", "max_weight", 100.0)))
		if get_inventory_weight() + float(amount) * maxf(0.0, weight_per_unit) > maximum + 0.0001:
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
	var normalized_id := item_id.strip_edges()
	if not _has_mechanic("has_inventory"):
		return _failed_result("У объекта не включён инвентарь.")
	if normalized_id.is_empty() or amount <= 0 or max_stack <= 0:
		return _failed_result("Некорректный ID или количество предмета.")
	if not is_finite(weight_per_unit) or weight_per_unit < 0.0:
		return _failed_result("Вес предмета должен быть конечным и неотрицательным.")
	if not _passes_item_filter(normalized_id, tags):
		return _failed_result("Предмет отклонён фильтром инвентаря.")
	var state := _get_state()
	var slots: Array = state.get("slots", [])
	var remaining := amount
	var can_stack := max_stack > 1
	for index in range(slots.size()):
		var current: Dictionary = slots[index]
		if current.is_empty() or str(current.get("item_id", "")) != normalized_id or not can_stack:
			continue
		var current_max := maxi(1, int(current.get("max_stack", max_stack)))
		var accepted := mini(remaining, maxi(0, current_max - int(current.get("amount", 0))))
		if accepted <= 0:
			continue
		current["amount"] = int(current.get("amount", 0)) + accepted
		slots[index] = current
		remaining -= accepted
		if remaining <= 0:
			break
	while remaining > 0:
		var empty_index := _find_empty_slot(slots)
		if empty_index < 0:
			break
		var accepted_new := mini(remaining, max_stack if can_stack else 1)
		slots[empty_index] = {
			"item_id": normalized_id,
			"amount": accepted_new,
			"max_stack": max_stack if can_stack else 1,
			"weight": weight_per_unit,
			"tags": tags.duplicate(true),
			"rarity": rarity,
			"bound": false
		}
		remaining -= accepted_new
	if _has_mechanic("has_weight_capacity"):
		var maximum_weight := maxf(0.0, float(_option("has_weight_capacity", "max_weight", 100.0)))
		while _weight_of_slots(slots) + _equipment_weight(state) > maximum_weight + 0.0001:
			var last_index := _find_last_matching_slot(slots, normalized_id)
			if last_index < 0:
				break
			var overflow: Dictionary = slots[last_index]
			var overflow_amount := int(overflow.get("amount", 0))
			remaining += overflow_amount
			slots[last_index] = {}
	state["slots"] = slots
	_save_state(state)
	var accepted_total := amount - remaining
	if accepted_total > 0:
		item_added.emit(normalized_id, accepted_total)
	return {"ok": remaining == 0, "accepted": accepted_total, "remainder": remaining}


func remove_item(item_id: String, amount: int = 1, allow_bound: bool = false) -> bool:
	if amount <= 0:
		return _fail("Количество для удаления должно быть положительным.")
	var state := _get_state()
	var slots: Array = state.get("slots", [])
	var remaining := amount
	for index in range(slots.size()):
		var item: Dictionary = slots[index]
		if item.is_empty() or str(item.get("item_id", "")) != item_id:
			continue
		if bool(item.get("bound", false)) and not allow_bound and _has_mechanic("supports_item_binding"):
			continue
		var removed := mini(remaining, int(item.get("amount", 0)))
		item["amount"] = int(item.get("amount", 0)) - removed
		remaining -= removed
		if int(item["amount"]) <= 0:
			slots[index] = {}
		else:
			slots[index] = item
		if remaining <= 0:
			break
	if remaining > 0:
		return _fail("В инвентаре недостаточно доступного количества: " + item_id)
	state["slots"] = slots
	_save_state(state)
	item_removed.emit(item_id, amount)
	return true


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
	if slot_index < 0 or slot_index >= slots.size() or (slots[slot_index] as Dictionary).is_empty():
		return _fail("В выбранном слоте нет предмета.")
	var item: Dictionary = slots[slot_index]
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
	var add_result := add_item(
		str(item.get("item_id", "")),
		int(item.get("amount", 1)),
		int(item.get("max_stack", 1)),
		float(item.get("weight", 0.0)),
		item.get("tags", []),
		str(item.get("rarity", "common"))
	)
	if int(add_result.get("accepted", 0)) < int(item.get("amount", 1)):
		return _fail("В инвентаре недостаточно места для снятия экипировки.")
	state = _get_state()
	equipment = state.get("equipment", {})
	equipment.erase(slot_id)
	state["equipment"] = equipment
	_save_state(state)
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
	var slots: Array = state.get("slots", [])
	var occupied: Array[Dictionary] = []
	for item in slots:
		if item is Dictionary and not item.is_empty():
			occupied.append(item)
	occupied.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		match sort_mode:
			"weight":
				return float(a.get("weight", 0.0)) > float(b.get("weight", 0.0))
			"rarity":
				return str(a.get("rarity", "")).naturalnocasecmp_to(str(b.get("rarity", ""))) < 0
			"type":
				return str(a.get("type", "")).naturalnocasecmp_to(str(b.get("type", ""))) < 0
			_:
				return str(a.get("item_id", "")).naturalnocasecmp_to(str(b.get("item_id", ""))) < 0
	)
	while occupied.size() < slots.size():
		occupied.append({})
	state["slots"] = occupied
	_save_state(state)
	return true


func transfer_to(target: Object, item_id: String, amount: int) -> Dictionary:
	if not _has_mechanic("supports_quick_transfer") or target == null or not target.has_method("add_item") or not target.has_method("remove_item"):
		return _failed_result("Быстрое перемещение недоступно.")
	if not target.has_method("_has_mechanic") or not bool(target.call("_has_mechanic", "supports_quick_transfer")):
		return _failed_result("У принимающего инвентаря не включено быстрое перемещение.")
	var source_items := filter_items(item_id)
	if source_items.is_empty():
		return _failed_result("Предмет не найден в исходном инвентаре.")
	var source_item: Dictionary = source_items[0]
	if bool(source_item.get("bound", false)) and _has_mechanic("supports_item_binding"):
		return _failed_result("Закреплённый предмет нельзя переместить.")
	var quantity := mini(amount, int(source_item.get("amount", 0)))
	if quantity <= 0 or not remove_item(item_id, quantity):
		return _failed_result("Не удалось изъять предмет из исходного инвентаря.")
	var added: Dictionary = target.call(
		"add_item",
		item_id,
		quantity,
		int(source_item.get("max_stack", 1)),
		float(source_item.get("weight", 0.0)),
		source_item.get("tags", []),
		str(source_item.get("rarity", "common"))
	)
	var accepted := int(added.get("accepted", 0))
	if accepted < quantity:
		add_item(
			item_id,
			quantity - accepted,
			int(source_item.get("max_stack", 1)),
			float(source_item.get("weight", 0.0)),
			source_item.get("tags", []),
			str(source_item.get("rarity", "common"))
		)
	return {"ok": accepted == quantity, "transferred": accepted, "remainder": quantity - accepted}


func craft(recipe_id: String) -> Dictionary:
	if not _has_mechanic("supports_item_crafting"):
		return _failed_result("Создание предметов не включено.")
	var recipes := _parse_json_dictionary(str(_option("supports_item_crafting", "recipes_json", "{}")))
	if not recipes.has(recipe_id):
		return _failed_result("Рецепт не найден: " + recipe_id)
	var recipe: Dictionary = recipes[recipe_id]
	var ingredients: Dictionary = recipe.get("ingredients", {})
	var removed: Array[Dictionary] = []
	for ingredient_id in ingredients:
		var amount := int(ingredients[ingredient_id])
		if amount <= 0 or get_item_count(str(ingredient_id)) < amount:
			for rollback in removed:
				add_item(str(rollback.item_id), int(rollback.amount), int(rollback.max_stack), float(rollback.weight), rollback.get("tags", []), str(rollback.get("rarity", "common")))
			return _failed_result("Недостаточно ингредиентов для рецепта: " + str(ingredient_id))
		var sample := _find_item(str(ingredient_id))
		if not remove_item(str(ingredient_id), amount):
			for rollback in removed:
				add_item(str(rollback.item_id), int(rollback.amount), int(rollback.max_stack), float(rollback.weight), rollback.get("tags", []), str(rollback.get("rarity", "common")))
			return _failed_result("Не удалось списать ингредиент: " + str(ingredient_id))
		sample["amount"] = amount
		removed.append(sample)
	var output: Dictionary = recipe.get("output", {})
	var result := add_item(
		str(output.get("item_id", "")),
		int(output.get("amount", 1)),
		int(output.get("max_stack", 1)),
		float(output.get("weight", 0.0)),
		output.get("tags", []),
		str(output.get("rarity", "common"))
	)
	if int(result.get("accepted", 0)) < int(output.get("amount", 1)):
		for rollback in removed:
			add_item(str(rollback.item_id), int(rollback.amount), int(rollback.max_stack), float(rollback.weight), rollback.get("tags", []), str(rollback.get("rarity", "common")))
		return _failed_result("Недостаточно места или веса для результата рецепта.")
	return {"ok": true, "recipe_id": recipe_id, "output": output.duplicate(true)}


func bind_item(slot_index: int, bound: bool = true) -> bool:
	if not _has_mechanic("supports_item_binding") or not bool(_option("supports_item_binding", "allow_binding", true)):
		return _fail("Закрепление предметов отключено.")
	var state := _get_state()
	var slots: Array = state.get("slots", [])
	if slot_index < 0 or slot_index >= slots.size() or (slots[slot_index] as Dictionary).is_empty():
		return _fail("Выбранный слот пуст.")
	var item: Dictionary = slots[slot_index]
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
			return stored.duplicate(true)
	var capacity := maxi(1, int(_option("has_inventory", "slot_capacity", 24)))
	var slots: Array = []
	for _index in range(capacity):
		slots.append({})
	var initial: Variant = JSON.parse_string(str(_option("has_inventory", "initial_items_json", "[]")))
	if initial is Array:
		for entry in initial:
			if entry is Dictionary and not str(entry.get("item_id", "")).is_empty():
				var slot := _find_empty_slot(slots)
				if slot >= 0:
					slots[slot] = entry.duplicate(true)
	var state := {"slots": slots, "equipment": {}, "hotbar": {}, "selected_hotbar": -1}
	root.set_meta("object_builder_inventory_state", state)
	return state.duplicate(true)


func _save_state(state: Dictionary) -> void:
	var root := get_object_root()
	if root == null:
		return
	root.set_meta("object_builder_inventory_state", state.duplicate(true))
	inventory_changed.emit(state.duplicate(true))


func _has_free_slot_or_stack(item_id: String) -> bool:
	for item in get_inventory():
		if item.is_empty():
			return true
		if str(item.get("item_id", "")) == item_id and int(item.get("amount", 0)) < int(item.get("max_stack", 1)):
			return true
	return false


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
	var total := 0.0
	for item in slots:
		if item is Dictionary:
			total += float(item.get("weight", 0.0)) * float(item.get("amount", 0))
	return total


func _equipment_weight(state: Dictionary) -> float:
	var total := 0.0
	for item in state.get("equipment", {}).values():
		if item is Dictionary:
			total += float(item.get("weight", 0.0)) * float(item.get("amount", 1))
	return total


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
	return root != null and ObjectFactory.get_component(root, mechanic_id) != null


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
