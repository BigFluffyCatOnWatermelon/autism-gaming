@tool
extends ObjectComponent
class_name ItemMechanicComponent

signal item_state_changed(state: Dictionary)
signal item_consumed(amount: int, remaining: int)
signal item_dropped(payload: Dictionary)
signal item_traded(quantity: int, total_value: float)
signal durability_changed(current: float, maximum: float)
signal uses_changed(remaining: int)
signal action_failed(reason: String)


func get_option(key: String, fallback: Variant = null) -> Variant:
	return get_setting(key, fallback)


func configure_mechanic(values: Dictionary) -> bool:
	for raw_key in values:
		var key := str(raw_key)
		if not settings.has(key):
			return _fail("Неизвестная настройка: %s" % key)
		if typeof(values[raw_key]) != typeof(settings[key]):
			return _fail("Неверный тип настройки: %s" % key)
		if values[raw_key] is int and int(values[raw_key]) < 0:
			return _fail("Числовая настройка не может быть отрицательной: %s" % key)
		if values[raw_key] is float and (not is_finite(float(values[raw_key])) or float(values[raw_key]) < 0.0):
			return _fail("Числовая настройка должна быть конечной и неотрицательной: %s" % key)
	for raw_key in values:
		settings[str(raw_key)] = values[raw_key]
	_emit_state()
	return true


func is_pickup_allowed() -> bool:
	return _has_mechanic("is_pickup_item") and bool(_option("is_pickup_item", "pickup_enabled", true)) and _get_count() > 0


func mark_picked_up() -> bool:
	if not is_pickup_allowed():
		return _fail("Предмет нельзя подобрать в текущем состоянии.")
	var root := get_object_root()
	if root == null:
		return _fail("Не найден корневой объект предмета.")
	root.set_meta("object_builder_item_picked_up", true)
	_emit_state()
	return true


func is_picked_up() -> bool:
	var root := get_object_root()
	return root != null and bool(root.get_meta("object_builder_item_picked_up", false))


func get_count() -> int:
	return _get_count()


func get_max_stack_size() -> int:
	if not _has_mechanic("is_stackable"):
		return 1
	return maxi(1, int(_option("is_stackable", "max_stack_size", 99)))


func can_stack_with(other_item_id: String) -> bool:
	if not _has_mechanic("is_stackable"):
		return false
	var own_id := str(get_object_root().get_meta("object_definition_id", "")) if get_object_root() != null else ""
	return not own_id.is_empty() and own_id == other_item_id and _get_count() < get_max_stack_size()


func add_to_stack(amount: int) -> int:
	if not _has_mechanic("is_stackable"):
		return 0
	if amount <= 0:
		return 0
	var accepted := mini(amount, maxi(0, get_max_stack_size() - _get_count()))
	_set_count(_get_count() + accepted)
	return accepted


func remove_from_stack(amount: int) -> int:
	if amount <= 0:
		return 0
	var removed := mini(amount, _get_count())
	_set_count(_get_count() - removed)
	return removed


func get_unit_weight() -> float:
	return maxf(0.0, float(_option("has_item_weight", "weight_per_unit", 0.0)))


func get_total_weight() -> float:
	return get_unit_weight() * float(_get_count())


func get_item_value() -> float:
	return maxf(0.0, float(_option("has_item_value", "base_value", 0.0)))


func consume(amount: int = 1) -> bool:
	if not _has_mechanic("is_consumable"):
		return _fail("Предмет не является расходуемым.")
	if amount <= 0 or amount > _get_count():
		return _fail("Недопустимое количество для использования.")
	var remaining := _set_count(_get_count() - amount)
	item_consumed.emit(amount, remaining)
	_emit_state()
	return true


func equip(slot_id: String = "") -> bool:
	if not _has_mechanic("can_be_equipped"):
		return _fail("Предмет нельзя экипировать.")
	var requested_slot := slot_id.strip_edges().to_lower()
	if requested_slot.is_empty():
		requested_slot = str(_option("can_be_equipped", "equipment_slot", "hand")).strip_edges().to_lower()
	var allowed := _split_csv(str(_option("can_be_equipped", "allowed_slots_csv", "hand")))
	if not allowed.has(requested_slot):
		return _fail("Слот экипировки не разрешён для этого предмета: " + requested_slot)
	var root := get_object_root()
	if root == null:
		return _fail("Не найден корневой объект предмета.")
	root.set_meta("object_builder_equipped_slot", requested_slot)
	_emit_state()
	return true


func unequip() -> bool:
	var root := get_object_root()
	if root == null:
		return false
	root.remove_meta("object_builder_equipped_slot")
	_emit_state()
	return true


func get_equipped_slot() -> String:
	var root := get_object_root()
	return str(root.get_meta("object_builder_equipped_slot", "")) if root != null else ""


func drop(amount: int = 1) -> Dictionary:
	if not _has_mechanic("can_be_dropped") or not bool(_option("can_be_dropped", "drop_enabled", true)):
		return _failed_result("Предмет нельзя выбросить.")
	if amount <= 0 or amount > _get_count():
		return _failed_result("Недопустимое количество для выбрасывания.")
	var remaining := _set_count(_get_count() - amount)
	var payload := {
		"object_id": str(get_object_root().get_meta("object_definition_id", "")) if get_object_root() != null else "",
		"amount": amount,
		"remaining": remaining,
		"unit_weight": get_unit_weight(),
		"value": get_item_value()
	}
	item_dropped.emit(payload)
	_emit_state()
	return {"ok": true, "payload": payload}


func can_trade() -> bool:
	return _has_mechanic("can_be_traded") and bool(_option("can_be_traded", "trade_enabled", true)) and _get_count() > 0


func trade(quantity: int = 1, price_modifier: float = 1.0) -> Dictionary:
	if not can_trade():
		return _failed_result("Предмет нельзя обменять.")
	if quantity <= 0 or quantity > _get_count() or not is_finite(price_modifier) or price_modifier < 0.0:
		return _failed_result("Недопустимое количество или множитель цены.")
	var total := get_item_value() * float(quantity) * price_modifier
	_set_count(_get_count() - quantity)
	item_traded.emit(quantity, total)
	_emit_state()
	return {"ok": true, "quantity": quantity, "total_value": total, "remaining": _get_count()}


func get_durability() -> Dictionary:
	var maximum := maxf(0.0, float(_option("has_item_durability", "maximum_durability", 100.0)))
	var current := _get_shared_float("object_builder_item_durability", float(_option("has_item_durability", "starting_durability", maximum)))
	return {"current": clampf(current, 0.0, maximum), "maximum": maximum, "ratio": clampf(current / maxf(0.001, maximum), 0.0, 1.0)}


func apply_durability_damage(amount: float) -> bool:
	if not _has_mechanic("has_item_durability"):
		return _fail("У предмета нет механики прочности.")
	if not is_finite(amount) or amount < 0.0:
		return _fail("Урон прочности должен быть конечным и неотрицательным.")
	var state := get_durability()
	var current := maxf(0.0, float(state.current) - amount)
	_set_shared("object_builder_item_durability", current)
	durability_changed.emit(current, float(state.maximum))
	_emit_state()
	return true


func has_durability() -> bool:
	return float(get_durability().current) > 0.0


func get_remaining_uses() -> int:
	return maxi(0, int(_get_shared("object_builder_item_uses", int(_option("has_item_uses", "starting_uses", _option("has_item_uses", "maximum_uses", 10))))))


func consume_uses(amount: int = 1) -> bool:
	if not _has_mechanic("has_item_uses"):
		return _fail("У предмета нет ограниченного числа применений.")
	if amount <= 0 or amount > get_remaining_uses():
		return _fail("Недостаточно оставшихся применений.")
	var remaining := get_remaining_uses() - amount
	_set_shared("object_builder_item_uses", remaining)
	uses_changed.emit(remaining)
	_emit_state()
	return true


func export_runtime_state() -> Dictionary:
	return {
		"count": _get_count(),
		"picked_up": is_picked_up(),
		"equipped_slot": get_equipped_slot(),
		"durability": get_durability().current,
		"uses": get_remaining_uses()
	}


func import_runtime_state(state: Dictionary) -> bool:
	var count := int(state.get("count", 1))
	var durability := float(state.get("durability", get_durability().current))
	var uses := int(state.get("uses", get_remaining_uses()))
	if count < 0 or uses < 0 or not is_finite(durability) or durability < 0.0:
		return _fail("Состояние предмета содержит некорректные значения.")
	_set_count(count)
	var root := get_object_root()
	if root != null:
		root.set_meta("object_builder_item_picked_up", bool(state.get("picked_up", false)))
		var slot := str(state.get("equipped_slot", ""))
		if slot.is_empty():
			root.remove_meta("object_builder_equipped_slot")
		else:
			root.set_meta("object_builder_equipped_slot", slot)
		root.set_meta("object_builder_item_durability", durability)
		root.set_meta("object_builder_item_uses", uses)
	_emit_state()
	return true


func _get_count() -> int:
	return maxi(0, int(_get_shared("object_builder_item_count", int(_option("is_stackable", "initial_count", 1)))))


func _set_count(value: int) -> int:
	var count := maxi(0, value)
	_set_shared("object_builder_item_count", count)
	_emit_state()
	return count


func _get_shared(key: StringName, fallback: Variant = null) -> Variant:
	var root := get_object_root()
	return root.get_meta(key, fallback) if root != null else fallback


func _get_shared_float(key: StringName, fallback: float) -> float:
	return float(_get_shared(key, fallback))


func _set_shared(key: StringName, value: Variant) -> void:
	var root := get_object_root()
	if root != null:
		root.set_meta(key, value)


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


func _emit_state() -> void:
	item_state_changed.emit(export_runtime_state())


func _failed_result(reason: String) -> Dictionary:
	_fail(reason)
	return {"ok": false, "error": reason}


func _fail(reason: String) -> bool:
	action_failed.emit(reason)
	return false
