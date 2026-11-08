@tool
extends ObjectComponent
class_name ContainerMechanicComponent

signal contents_changed(contents: Array[Dictionary])
signal lock_changed(locked: bool)
signal access_denied(actor_id: String, reason: String)
signal action_failed(reason: String)

static var _shared_storage_states: Dictionary = {}


func get_option(key: String, fallback: Variant = null) -> Variant:
	return get_setting(key, fallback)


func get_contents(actor_id: String = "", faction_id: String = "") -> Array[Dictionary]:
	if not can_access(actor_id, faction_id):
		access_denied.emit(actor_id, "Нет доступа к содержимому контейнера.")
		return []
	var result: Array[Dictionary] = []
	for item in _get_state().get("items", []):
		if item is Dictionary:
			result.append(item.duplicate(true))
	return result


func get_item_count(item_id: String) -> int:
	var total := 0
	for item in _get_state().get("items", []):
		if item is Dictionary and str(item.get("item_id", "")) == item_id:
			total += int(item.get("amount", 0))
	return total


func get_total_weight() -> float:
	var total := 0.0
	for item in _get_state().get("items", []):
		if item is Dictionary:
			total += float(item.get("weight", 0.0)) * float(item.get("amount", 0))
	return total


func can_access(actor_id: String = "", faction_id: String = "") -> bool:
	var state := _get_state()
	if bool(state.get("locked", false)):
		return false
	if not _has_mechanic("has_container_permissions"):
		return true
	if bool(_option("has_container_permissions", "public_access", true)):
		return true
	var owner_id := str(_option("has_container_permissions", "owner_id", "")).strip_edges()
	if not owner_id.is_empty() and actor_id == owner_id:
		return true
	return _split_csv(str(_option("has_container_permissions", "allowed_factions_csv", ""))).has(faction_id.strip_edges().to_lower())


func add_item(item_id: String, amount: int = 1, max_stack: int = 1, weight: float = 0.0, tags: Array = [], actor_id: String = "", faction_id: String = "") -> Dictionary:
	if not _has_mechanic("stores_items"):
		return _failed_result("Контейнер не поддерживает хранение предметов.")
	if not can_access(actor_id, faction_id):
		return _failed_result("Контейнер закрыт или недоступен.")
	if item_id.strip_edges().is_empty() or amount <= 0 or max_stack <= 0 or not is_finite(weight) or weight < 0.0:
		return _failed_result("Некорректные данные предмета.")
	var state := _get_state()
	var items: Array = state.get("items", [])
	var amount_allowed := amount
	var max_weight := float(_option("has_container_capacity", "max_weight", 0.0))
	if _has_mechanic("has_container_capacity") and max_weight > 0.0 and weight > 0.0:
		amount_allowed = mini(amount, int(floor(maxf(0.0, max_weight - get_total_weight()) / weight)))
	var capacity_remainder := amount - amount_allowed
	var remaining := amount_allowed
	if max_stack > 1:
		for index in range(items.size()):
			var current: Dictionary = items[index]
			if str(current.get("item_id", "")) != item_id or not is_equal_approx(float(current.get("weight", 0.0)), weight):
				continue
			var accepted := mini(remaining, maxi(0, int(current.get("max_stack", max_stack)) - int(current.get("amount", 0))))
			if accepted <= 0:
				continue
			current["amount"] = int(current.get("amount", 0)) + accepted
			items[index] = current
			remaining -= accepted
			if remaining <= 0:
				break
	var slot_capacity := maxi(1, int(_option("has_container_capacity", "max_slots", 24)))
	while remaining > 0 and items.size() < slot_capacity:
		var accepted_new := mini(remaining, max_stack)
		items.append({
			"item_id": item_id,
			"amount": accepted_new,
			"max_stack": max_stack,
			"weight": weight,
			"tags": tags.duplicate(true)
		})
		remaining -= accepted_new
	state["items"] = items
	_save_state(state)
	var accepted_total := amount_allowed - remaining
	var remainder := capacity_remainder + remaining
	return {"ok": remainder == 0, "accepted": accepted_total, "remainder": remainder}


func remove_item(item_id: String, amount: int = 1, actor_id: String = "", faction_id: String = "") -> bool:
	if not _has_mechanic("can_be_looted") or not bool(_option("can_be_looted", "loot_enabled", true)):
		return _fail("Содержимое контейнера нельзя обыскивать или изымать.")
	if not can_access(actor_id, faction_id):
		return _fail("Нет доступа к контейнеру.")
	if amount <= 0:
		return _fail("Количество для изъятия должно быть положительным.")
	var state := _get_state()
	var items: Array = state.get("items", [])
	var remaining := amount
	var index := 0
	while index < items.size() and remaining > 0:
		var item: Dictionary = items[index]
		if str(item.get("item_id", "")) != item_id:
			index += 1
			continue
		var removed := mini(remaining, int(item.get("amount", 0)))
		item["amount"] = int(item.get("amount", 0)) - removed
		remaining -= removed
		if int(item["amount"]) <= 0:
			items.remove_at(index)
		else:
			items[index] = item
			index += 1
	if remaining > 0:
		return _fail("В контейнере недостаточно предметов: " + item_id)
	state["items"] = items
	_save_state(state)
	return true


func loot(actor_id: String = "", faction_id: String = "") -> Array[Dictionary]:
	if not _has_mechanic("can_be_looted") or not bool(_option("can_be_looted", "loot_enabled", true)):
		_fail("Контейнер нельзя обыскать.")
		return []
	return get_contents(actor_id, faction_id)


func lock(key_id: String = "") -> bool:
	if not _has_mechanic("can_be_locked"):
		return _fail("Контейнер нельзя запереть.")
	var state := _get_state()
	if bool(state.get("locked", false)):
		return _fail("Контейнер уже заперт.")
	var required_key := str(_option("can_be_locked", "lock_key_id", "")).strip_edges()
	if not required_key.is_empty() and key_id != required_key:
		return _fail("Неверный ключ для запирания.")
	state["locked"] = true
	_save_state(state)
	lock_changed.emit(true)
	return true


func unlock(key_id: String = "") -> bool:
	if not _has_mechanic("can_be_unlocked"):
		return _fail("Контейнер нельзя отпереть.")
	var state := _get_state()
	if not bool(state.get("locked", false)):
		return _fail("Контейнер уже открыт.")
	var requires_key := bool(_option("can_be_unlocked", "requires_key", false))
	var required_key := str(_option("can_be_unlocked", "unlock_key_id", ""))
	if requires_key and (required_key.is_empty() or key_id != required_key):
		return _fail("Для отпирания нужен подходящий ключ.")
	state["locked"] = false
	_save_state(state)
	lock_changed.emit(false)
	return true


func is_locked() -> bool:
	return bool(_get_state().get("locked", false))


func sort_contents(mode: String = "") -> bool:
	if not _has_mechanic("supports_auto_sort"):
		return _fail("Автосортировка контейнера не включена.")
	var sort_mode := mode.strip_edges().to_lower()
	if sort_mode.is_empty():
		sort_mode = str(_option("supports_auto_sort", "default_sort", "name")).to_lower()
	if not ["name", "weight", "amount"].has(sort_mode):
		return _fail("Неизвестный режим сортировки: " + sort_mode)
	var state := _get_state()
	var items: Array = state.get("items", [])
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		match sort_mode:
			"weight":
				return float(a.get("weight", 0.0)) > float(b.get("weight", 0.0))
			"amount":
				return int(a.get("amount", 0)) > int(b.get("amount", 0))
			_:
				return str(a.get("item_id", "")).naturalnocasecmp_to(str(b.get("item_id", ""))) < 0
	)
	state["items"] = items
	_save_state(state)
	return true


func link_container(target: Object) -> bool:
	if not _has_mechanic("supports_container_links") or not bool(_option("supports_container_links", "allow_links", true)):
		return _fail("Связи между контейнерами отключены.")
	if target == null or not target.has_method("_has_mechanic") or not bool(target.call("_has_mechanic", "supports_container_links")):
		return _fail("Целевой объект не поддерживает связи контейнеров.")
	var target_root: Node = target.call("get_object_root")
	var own_root := get_object_root()
	if target_root == null or own_root == null or target_root == own_root:
		return _fail("Нельзя связать контейнер с самим собой.")
	var own_state := _get_state()
	var target_state: Dictionary = target.call("_get_state")
	var merged_items: Array = target_state.get("items", []).duplicate(true)
	for item in own_state.get("items", []):
		merged_items.append(item.duplicate(true))
	var own_capacity := maxi(1, int(_option("has_container_capacity", "max_slots", 24)))
	var target_capacity := maxi(1, int(target.call("_option", "has_container_capacity", "max_slots", 24)))
	if merged_items.size() > mini(own_capacity, target_capacity):
		return _fail("Содержимое не помещается в общую вместимость контейнеров.")
	var own_max_weight := float(_option("has_container_capacity", "max_weight", 0.0))
	var target_max_weight := float(target.call("_option", "has_container_capacity", "max_weight", 0.0))
	var merged_weight := 0.0
	for item in merged_items:
		merged_weight += float(item.get("weight", 0.0)) * float(item.get("amount", 0))
	if (own_max_weight > 0.0 and merged_weight > own_max_weight) or (target_max_weight > 0.0 and merged_weight > target_max_weight):
		return _fail("Содержимое превышает весовой лимит одного из контейнеров.")
	var group_id := str(target_root.get_meta("object_builder_container_shared_group", ""))
	if group_id.is_empty():
		group_id = "container_group_" + str(Time.get_ticks_usec()) + "_" + str(randi())
	var merged_state := {"items": merged_items, "locked": bool(own_state.get("locked", false)) or bool(target_state.get("locked", false))}
	_shared_storage_states[group_id] = merged_state.duplicate(true)
	target_root.remove_meta("object_builder_container_force_local")
	own_root.remove_meta("object_builder_container_force_local")
	target_root.set_meta("object_builder_container_shared_group", group_id)
	own_root.set_meta("object_builder_container_shared_group", group_id)
	return true

func unlink_container() -> bool:
	var root := get_object_root()
	if root == null:
		return false
	var group_id := str(root.get_meta("object_builder_container_shared_group", ""))
	if group_id.is_empty():
		return false
	var local_state := _get_state()
	root.remove_meta("object_builder_container_shared_group")
	root.set_meta("object_builder_container_force_local", true)
	root.set_meta("object_builder_container_state", local_state)
	return true

func can_persist() -> bool:
	return _has_mechanic("has_container_persistence") and bool(_option("has_container_persistence", "persistent", true))


func export_runtime_state() -> Dictionary:
	return _get_state().duplicate(true)


func import_runtime_state(state: Dictionary) -> bool:
	if not state.get("items", []) is Array or not state.get("locked", false) is bool:
		return _fail("Состояние контейнера имеет неверный формат.")
	var normalized := {"items": state.get("items", []).duplicate(true), "locked": bool(state.get("locked", false))}
	for item in normalized.items:
		if not item is Dictionary or str(item.get("item_id", "")).is_empty() or int(item.get("amount", 0)) <= 0:
			return _fail("Состояние контейнера содержит некорректный предмет.")
	_save_state(normalized)
	return true


func _get_state() -> Dictionary:
	var root := get_object_root()
	if root == null:
		return {"items": [], "locked": false}
	var group_id := str(root.get_meta("object_builder_container_shared_group", ""))
	if group_id.is_empty() and not bool(root.get_meta("object_builder_container_force_local", false)) and _has_mechanic("has_shared_storage"):
		group_id = str(_option("has_shared_storage", "shared_group_id", "")).strip_edges()
	if not group_id.is_empty():
		if not _shared_storage_states.has(group_id):
			_shared_storage_states[group_id] = _load_local_state(root)
		return (_shared_storage_states[group_id] as Dictionary).duplicate(true)
	if root.has_meta("object_builder_container_state"):
		var stored: Variant = root.get_meta("object_builder_container_state")
		if stored is Dictionary:
			return stored.duplicate(true)
	return _load_local_state(root)


func _load_local_state(root: Node) -> Dictionary:
	var items: Array = []
	var parsed: Variant = JSON.parse_string(str(_option("stores_items", "initial_contents_json", "[]")))
	if parsed is Array:
		for item in parsed:
			if item is Dictionary and not str(item.get("item_id", "")).is_empty() and int(item.get("amount", 0)) > 0:
				items.append(item.duplicate(true))
	return {"items": items, "locked": bool(_option("can_be_locked", "initially_locked", false))}


func _save_state(state: Dictionary) -> void:
	var root := get_object_root()
	if root == null:
		return
	var copied := state.duplicate(true)
	var group_id := str(root.get_meta("object_builder_container_shared_group", ""))
	if group_id.is_empty() and not bool(root.get_meta("object_builder_container_force_local", false)) and _has_mechanic("has_shared_storage"):
		group_id = str(_option("has_shared_storage", "shared_group_id", "")).strip_edges()
	if not group_id.is_empty():
		_shared_storage_states[group_id] = copied
	else:
		root.set_meta("object_builder_container_state", copied)
	contents_changed.emit(copied.get("items", []).duplicate(true))


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


func _failed_result(reason: String) -> Dictionary:
	_fail(reason)
	return {"ok": false, "error": reason}


func _fail(reason: String) -> bool:
	action_failed.emit(reason)
	return false
