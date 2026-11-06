@tool
extends ObjectComponent
class_name PickupComponent

signal pickup_received(receiver: Node, accepted_amount: int, remaining_amount: int)
signal pickup_failed(receiver: Node, reason: String)
signal depleted(receiver: Node)

@export var item_id: String = ""
@export_range(1, 99999, 1) var quantity: int = 1
@export var can_be_picked_up: bool = true
@export var remove_object_when_empty: bool = true


func _on_configured() -> void:
	item_id = str(settings.get("item_id", item_id)).strip_edges()
	quantity = maxi(1, _read_integer("quantity", quantity))
	can_be_picked_up = _read_bool("can_be_picked_up", can_be_picked_up)
	remove_object_when_empty = _read_bool("remove_object_when_empty", remove_object_when_empty)


## Receiver contract:
## receive_pickup(item_id: String, amount: int, source: Node) -> bool | int
## true accepts the whole stack; an integer accepts that many items.
## Returning false or 0 leaves the world object untouched.
func try_pickup(receiver: Node) -> int:
	if receiver == null or not is_instance_valid(receiver):
		return _fail(receiver, "receiver_missing")
	if not can_be_picked_up:
		return _fail(receiver, "pickup_disabled")
	if item_id.is_empty():
		return _fail(receiver, "item_id_missing")
	if quantity <= 0:
		return _fail(receiver, "empty_stack")
	if not receiver.has_method("receive_pickup"):
		return _fail(receiver, "receiver_contract_missing")

	var source := get_object_root()
	if source == null or source == self:
		return _fail(receiver, "source_missing")

	var result: Variant = receiver.call("receive_pickup", item_id, quantity, source)
	var accepted_amount := 0
	match typeof(result):
		TYPE_BOOL:
			accepted_amount = quantity if bool(result) else 0
		TYPE_INT:
			accepted_amount = clampi(int(result), 0, quantity)
		_:
			return _fail(receiver, "invalid_receiver_result")

	if accepted_amount <= 0:
		return _fail(receiver, "receiver_rejected")

	quantity -= accepted_amount
	pickup_received.emit(receiver, accepted_amount, quantity)
	if quantity == 0:
		can_be_picked_up = false
		depleted.emit(receiver)
		if remove_object_when_empty and is_instance_valid(source):
			source.queue_free()
	return accepted_amount


func set_pickup_enabled(enabled: bool) -> void:
	can_be_picked_up = enabled and quantity > 0 and not item_id.is_empty()


func get_remaining_quantity() -> int:
	return maxi(0, quantity)


func _fail(receiver: Node, reason: String) -> int:
	pickup_failed.emit(receiver, reason)
	return 0


func _read_integer(key: String, fallback: int) -> int:
	var value: Variant = settings.get(key, fallback)
	return int(value) if typeof(value) == TYPE_INT else fallback


func _read_bool(key: String, fallback: bool) -> bool:
	var value: Variant = settings.get(key, fallback)
	return bool(value) if typeof(value) == TYPE_BOOL else fallback
