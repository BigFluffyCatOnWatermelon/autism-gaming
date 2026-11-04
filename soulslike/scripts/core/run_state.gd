extends Node
signal souls_changed(total: int)
signal stain_changed(amount: int)
const SAVE_PATH := "user://ashen_oath_save.json"
const ATTRIBUTE_LABELS := {
	"vitality": "VITALITY",
	"attunement": "ATTUNEMENT",
	"endurance": "ENDURANCE",
	"strength": "STRENGTH",
	"dexterity": "DEXTERITY",
	"intelligence": "INTELLIGENCE",
	"faith": "FAITH",
	"luck": "LUCK"
}
var souls := 0
var level := 1
var attributes: Dictionary = {
	"vitality": 10, "attunement": 10, "endurance": 10, "strength": 10,
	"dexterity": 10, "intelligence": 10, "faith": 10, "luck": 10
}
var lost_souls := 0
var lost_position := Vector3.ZERO
var has_lost_souls := false
var has_checkpoint := false
var checkpoint_id := ""
var checkpoint_title := "The Ashen Road"
var checkpoint_position := Vector3(0.0, 0.0, 7.0)
var defeated_flags: Dictionary = {}

func _ready() -> void:
	load_game()

func next_level_cost() -> int:
	return 180 + level * level * 55

func level_up(attribute: String) -> bool:
	if not attributes.has(attribute) or souls < next_level_cost():
		return false
	souls -= next_level_cost()
	attributes[attribute] = int(attributes[attribute]) + 1
	level += 1
	souls_changed.emit(souls)
	save_game()
	return true

func add_souls(amount: int) -> void:
	souls = maxi(0, souls + amount)
	souls_changed.emit(souls)
	save_game()
	save_game()

func record_death(position: Vector3) -> void:
	lost_souls = souls
	has_lost_souls = lost_souls > 0
	lost_position = position
	souls = 0
	souls_changed.emit(souls)
	stain_changed.emit(lost_souls)
	save_game()

func reclaim_lost_souls() -> int:
	if not has_lost_souls:
		return 0
	var recovered := lost_souls
	lost_souls = 0
	has_lost_souls = false
	souls += recovered
	souls_changed.emit(souls)
	stain_changed.emit(0)
	save_game()
	return recovered

func activate_checkpoint(id: String, title: String, position: Vector3) -> void:
	checkpoint_id = id
	checkpoint_title = title
	checkpoint_position = position
	has_checkpoint = true
	save_game()

func set_defeated(flag: String) -> void:
	defeated_flags[flag] = true
	save_game()

func is_defeated(flag: String) -> bool:
	return bool(defeated_flags.get(flag, false))

func save_game() -> void:
	var data := {
		"version": 2, "souls": souls, "level": level, "attributes": attributes, "lost_souls": lost_souls,
		"has_lost_souls": has_lost_souls, "lost_position": _vector_to_array(lost_position),
		"has_checkpoint": has_checkpoint, "checkpoint_id": checkpoint_id,
		"checkpoint_title": checkpoint_title, "checkpoint_position": _vector_to_array(checkpoint_position),
		"defeated_flags": defeated_flags
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write save file: %s" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(data, "\t"))

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("Could not read save file: %s" % FileAccess.get_open_error())
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Save file is invalid; starting a new journey.")
		return
	var data: Dictionary = parsed
	souls = maxi(0, int(data.get("souls", 0)))
	level = maxi(1, int(data.get("level", 1)))
	var saved_attributes: Variant = data.get("attributes", {})
	if typeof(saved_attributes) == TYPE_DICTIONARY:
		for key in ATTRIBUTE_LABELS.keys():
			attributes[key] = maxi(1, int(saved_attributes.get(key, 10)))
	lost_souls = maxi(0, int(data.get("lost_souls", 0)))
	has_lost_souls = bool(data.get("has_lost_souls", false)) and lost_souls > 0
	lost_position = _array_to_vector(data.get("lost_position", [0.0, 0.0, 0.0]))
	has_checkpoint = bool(data.get("has_checkpoint", false))
	checkpoint_id = str(data.get("checkpoint_id", ""))
	checkpoint_title = str(data.get("checkpoint_title", "The Ashen Road"))
	checkpoint_position = _array_to_vector(data.get("checkpoint_position", [0.0, 0.0, 7.0]))
	var flags: Variant = data.get("defeated_flags", {})
	defeated_flags = flags if typeof(flags) == TYPE_DICTIONARY else {}

func _vector_to_array(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func _array_to_vector(value: Variant) -> Vector3:
	if typeof(value) == TYPE_ARRAY and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.ZERO
