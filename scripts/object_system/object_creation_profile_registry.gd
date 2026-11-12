extends RefCounted
class_name ObjectCreationProfileRegistry

## Built-in and extension profiles share one registry API.
## Profiles are optional suggestions, never a whitelist of allowed object behavior.

const BUILTIN_PROFILE_DATA := {
	"npc": {
		"label": "Персонаж / NPC",
		"description": "Персонаж с запасом здоровья, скоростью передвижения, радиусом взаимодействия и фракцией.",
		"category": "Characters",
		"root_type": "CharacterBody2D",
		"suggested_capabilities": ["has_health", "can_receive_damage", "can_attack", "can_interact", "has_armor", "has_damage_resistance", "regenerates_health"],
		"properties": [
			{"id": "health", "name": "Здоровье", "type": "Integer", "default": 100, "group": "Характеристики", "min": 0, "max": 9999},
			{"id": "move_speed", "name": "Скорость передвижения", "type": "Float", "default": 80.0, "group": "Характеристики", "min": 0.0, "max": 1000.0},
			{"id": "interaction_radius", "name": "Радиус взаимодействия", "type": "Float", "default": 48.0, "group": "Взаимодействие", "min": 0.0, "max": 1024.0},
			{"id": "faction", "name": "Фракция", "type": "String", "default": "neutral", "group": "Поведение"}
		]
	},
	"resource": {
		"label": "Ресурс",
		"description": "Добываемый объект с прочностью, инструментом, добычей и эффектами. Все игровые параметры задаются через подключённые механики.",
		"category": "Nature",
		"root_type": "StaticBody2D",
		"suggested_capabilities": ["has_health", "can_receive_damage", "breaks_when_health_empty", "drops_loot_on_destroy", "can_regrow", "can_be_repaired", "spawns_debris", "emits_particles", "plays_damage_sound", "plays_destroy_sound"],
		"properties": []
	},
	"tree": {
		"label": "Дерево",
		"description": "Рубимое дерево с прочностью, материалом, требуемым инструментом, падением и добычей через механики.",
		"category": "Nature",
		"root_type": "StaticBody2D",
		"suggested_capabilities": ["has_health", "can_receive_damage", "breaks_when_health_empty", "falls_when_destroyed", "leaves_remains", "drops_loot_on_destroy", "spawns_debris", "emits_particles", "plays_damage_sound", "plays_destroy_sound"],
		"properties": []
	},
	"rock": {
		"label": "Камень / руда",
		"description": "Разрушаемый камень с прочностью, инструментом добычи, эффектами и таблицей добычи через механики.",
		"category": "Nature",
		"root_type": "StaticBody2D",
		"suggested_capabilities": ["has_health", "can_receive_damage", "breaks_when_health_empty", "leaves_remains", "drops_loot_on_destroy", "spawns_debris", "emits_particles", "plays_damage_sound", "plays_destroy_sound"],
		"properties": []
	},
	"construction": {
		"label": "Конструкция / постройка",
		"description": "Здание или размещаемая конструкция с прочностью, блокировкой движения и стоимостью строительства.",
		"category": "Buildings",
		"root_type": "StaticBody2D",
		"suggested_capabilities": ["has_health", "can_receive_damage", "breaks_when_health_empty", "has_armor", "has_damage_resistance", "can_be_repaired", "drops_loot_on_destroy", "can_interact"],
		"properties": [
			{"id": "health", "name": "Прочность", "type": "Integer", "default": 200, "group": "Параметры", "min": 0, "max": 99999},
			{"id": "blocks_movement", "name": "Блокирует движение", "type": "Boolean", "default": true, "group": "Коллизия"},
			{"id": "build_cost", "name": "Стоимость строительства", "type": "Integer", "default": 0, "group": "Экономика", "min": 0, "max": 999999}
		]
	},
	"item": {
		"label": "Предмет",
		"description": "Подбираемый предмет с размером стопки, весом и стоимостью.",
		"category": "Items",
		"root_type": "Area2D",
		"suggested_capabilities": ["is_pickup_item"],
		"properties": [
			{"id": "stack_size", "name": "Размер стопки", "type": "Integer", "default": 1, "group": "Инвентарь", "min": 1, "max": 999},
			{"id": "weight", "name": "Вес", "type": "Float", "default": 0.0, "group": "Инвентарь", "min": 0.0, "max": 9999.0},
			{"id": "sell_price", "name": "Цена продажи", "type": "Integer", "default": 0, "group": "Экономика", "min": 0, "max": 999999}
		]
	},
	"weapon": {
		"label": "Оружие",
		"description": "Боевой предмет с уроном, дистанцией атаки, перезарядкой и расходом выносливости.",
		"category": "Equipment",
		"root_type": "Area2D",
		"suggested_capabilities": ["can_attack"],
		"properties": [
			{"id": "damage", "name": "Урон", "type": "Integer", "default": 10, "group": "Бой", "min": 0, "max": 9999},
			{"id": "attack_range", "name": "Дистанция атаки", "type": "Float", "default": 48.0, "group": "Бой", "min": 0.0, "max": 1024.0},
			{"id": "attack_cooldown", "name": "Перезарядка атаки", "type": "Float", "default": 0.5, "group": "Бой", "min": 0.0, "max": 60.0},
			{"id": "stamina_cost", "name": "Расход выносливости", "type": "Float", "default": 0.0, "group": "Бой", "min": 0.0, "max": 1000.0}
		]
	},
	"tool": {
		"label": "Инструмент",
		"description": "Рабочий инструмент с силой воздействия, прочностью и интервалом использования.",
		"category": "Equipment",
		"root_type": "Area2D",
		"suggested_capabilities": ["can_interact", "can_attack", "can_receive_damage"],
		"properties": [
			{"id": "damage", "name": "Сила воздействия", "type": "Integer", "default": 5, "group": "Работа", "min": 0, "max": 9999},
			{"id": "durability", "name": "Прочность инструмента", "type": "Integer", "default": 100, "group": "Работа", "min": 0, "max": 99999},
			{"id": "attack_cooldown", "name": "Интервал использования", "type": "Float", "default": 0.5, "group": "Работа", "min": 0.0, "max": 60.0}
		]
	},
	"animal": {
		"label": "Животное",
		"description": "Живое существо с запасом здоровья, скоростью и параметрами приручения.",
		"category": "Animals",
		"root_type": "CharacterBody2D",
		"suggested_capabilities": ["has_health", "can_receive_damage", "can_attack", "can_interact", "can_regrow"],
		"properties": [
			{"id": "health", "name": "Здоровье", "type": "Integer", "default": 30, "group": "Характеристики", "min": 1, "max": 9999},
			{"id": "move_speed", "name": "Скорость передвижения", "type": "Float", "default": 60.0, "group": "Характеристики", "min": 0.0, "max": 1000.0},
			{"id": "tameable", "name": "Можно приручить", "type": "Boolean", "default": false, "group": "Поведение"}
		]
	},
	"interactive": {
		"label": "Интерактивный объект",
		"description": "Объект, с которым игрок взаимодействует в радиусе действия.",
		"category": "Interactive",
		"root_type": "Area2D",
		"suggested_capabilities": ["can_interact", "has_health", "can_receive_damage", "breaks_when_health_empty"],
		"properties": [
			{"id": "interaction_radius", "name": "Радиус взаимодействия", "type": "Float", "default": 48.0, "group": "Взаимодействие", "min": 0.0, "max": 1024.0},
			{"id": "one_shot", "name": "Одноразовое взаимодействие", "type": "Boolean", "default": false, "group": "Взаимодействие"}
		]
	},
	"decoration": {
		"label": "Декорация",
		"description": "Визуальный объект окружения с настройками сортировки и блокировки движения.",
		"category": "Decorations",
		"root_type": "Node2D",
		"properties": [
			{"id": "blocks_movement", "name": "Блокирует движение", "type": "Boolean", "default": false, "group": "Физика"},
			{"id": "sorting_offset", "name": "Смещение сортировки", "type": "Float", "default": 0.0, "group": "Визуал", "min": -4096.0, "max": 4096.0}
		]
	},
	"transport": {
		"label": "Транспорт",
		"description": "Транспортное средство с параметрами скорости и вместимости.",
		"category": "Transport",
		"root_type": "Node2D",
		"suggested_capabilities": ["can_interact", "has_health", "can_receive_damage", "can_be_repaired"],
		"properties": [
			{"id": "move_speed", "name": "Скорость", "type": "Float", "default": 100.0, "group": "Транспорт", "min": 0.0, "max": 2000.0},
			{"id": "capacity", "name": "Вместимость", "type": "Integer", "default": 1, "group": "Транспорт", "min": 1, "max": 999}
		]
	},
	"effect": {
		"label": "Эффект",
		"description": "Визуальный или звуковой эффект с длительностью и интенсивностью.",
		"category": "Effects",
		"root_type": "Node2D",
		"properties": [
			{"id": "duration", "name": "Длительность", "type": "Float", "default": 1.0, "group": "Эффект", "min": 0.0, "max": 3600.0},
			{"id": "intensity", "name": "Интенсивность", "type": "Float", "default": 1.0, "group": "Эффект", "min": 0.0, "max": 1000.0}
		]
	},
	"other": {
		"label": "Другой объект",
		"description": "Универсальная заготовка без специализированного набора параметров.",
		"category": "Other",
		"root_type": "Node2D",
		"properties": []
	}
}


static var _definitions: Dictionary = {}
static var _sources: Dictionary = {}
static var _initialized: bool = false


static func register_definition(
	definition: ObjectCreationProfileDefinition,
	source_id: String = "extension"
) -> bool:
	return register_definitions([definition], source_id).is_empty()


static func register_definitions(
	definitions: Array,
	source_id: String = "extension"
) -> PackedStringArray:
	_ensure_initialized()
	var errors := PackedStringArray()
	var normalized_source := source_id.strip_edges()
	if normalized_source.is_empty():
		errors.append("Для регистрации профилей нужен непустой source_id.")
		return errors

	var incoming: Dictionary = {}
	for value in definitions:
		if not value is ObjectCreationProfileDefinition:
			errors.append("Реестр профилей принимает только ObjectCreationProfileDefinition.")
			continue
		var definition := value as ObjectCreationProfileDefinition
		var profile_id := _normalize_id(definition.profile_id)
		if not _is_valid_id(profile_id):
			errors.append("Некорректный ID профиля: " + definition.profile_id)
			continue
		if BUILTIN_PROFILE_DATA.has(profile_id):
			errors.append("Нельзя переопределить встроенный профиль: " + profile_id)
			continue
		if incoming.has(profile_id):
			errors.append("В пакете повторяется ID профиля: " + profile_id)
			continue
		if _definitions.has(profile_id) and str(_sources.get(profile_id, "")) != normalized_source:
			errors.append("ID профиля уже зарегистрирован другим источником: " + profile_id)
			continue
		var existing := _definitions.get(profile_id) as ObjectCreationProfileDefinition
		if existing != null and existing.version > definition.version:
			errors.append("Нельзя понизить версию профиля '%s' с %d до %d." % [
				profile_id,
				existing.version,
				definition.version
			])
			continue
		var copy := definition.duplicate(true) as ObjectCreationProfileDefinition
		copy.profile_id = profile_id
		errors.append_array(_validate_definition(copy))
		incoming[profile_id] = copy

	if not errors.is_empty():
		return errors

	for profile_id in incoming:
		_definitions[profile_id] = incoming[profile_id]
		_sources[profile_id] = normalized_source
	return errors


static func unregister_source(source_id: String) -> PackedStringArray:
	_ensure_initialized()
	var normalized_source := source_id.strip_edges()
	var remove_ids := PackedStringArray()
	for profile_id in _sources:
		if str(_sources[profile_id]) == normalized_source:
			remove_ids.append(str(profile_id))
	for profile_id in remove_ids:
		_definitions.erase(profile_id)
		_sources.erase(profile_id)
	return PackedStringArray()


static func get_profile_ids() -> PackedStringArray:
	_ensure_initialized()
	var result := PackedStringArray()
	for profile_id in BUILTIN_PROFILE_DATA:
		result.append(str(profile_id))
	var extension_ids: Array[String] = []
	for profile_id in _definitions:
		if not BUILTIN_PROFILE_DATA.has(profile_id):
			extension_ids.append(str(profile_id))
	extension_ids.sort()
	for profile_id in extension_ids:
		result.append(profile_id)
	return result


static func get_definition(profile_id: String) -> ObjectCreationProfileDefinition:
	_ensure_initialized()
	var definition := _definitions.get(_normalize_id(profile_id)) as ObjectCreationProfileDefinition
	if definition == null:
		return null
	return definition.duplicate(true) as ObjectCreationProfileDefinition


static func get_display_name(profile_id: String) -> String:
	var definition := get_definition(profile_id)
	return definition.display_name if definition != null else ""


static func get_source_id(profile_id: String) -> String:
	_ensure_initialized()
	var normalized_id := _normalize_id(profile_id)
	if BUILTIN_PROFILE_DATA.has(normalized_id):
		return "builtin"
	return str(_sources.get(normalized_id, ""))


static func has_profile(profile_id: String) -> bool:
	_ensure_initialized()
	return _definitions.has(_normalize_id(profile_id))


static func validate_registry() -> PackedStringArray:
	_ensure_initialized()
	var errors := PackedStringArray()
	for profile_id in _definitions:
		errors.append_array(_validate_definition(_definitions[profile_id] as ObjectCreationProfileDefinition))
	return errors


static func _ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	for profile_id in BUILTIN_PROFILE_DATA:
		var definition := _make_builtin_definition(str(profile_id), BUILTIN_PROFILE_DATA[profile_id])
		_definitions[profile_id] = definition
		_sources[profile_id] = "builtin"


static func _make_builtin_definition(profile_id: String, data: Dictionary) -> ObjectCreationProfileDefinition:
	var definition := ObjectCreationProfileDefinition.new()
	definition.profile_id = profile_id
	definition.display_name = str(data.get("label", profile_id))
	definition.description = str(data.get("description", ""))
	definition.suggested_category = str(data.get("category", "Other"))
	definition.suggested_root_type = str(data.get("root_type", "Node2D"))
	definition.icon = _get_builtin_icon(profile_id)
	definition.suggested_capability_ids = PackedStringArray(data.get("suggested_capabilities", []))

	for property_data in data.get("properties", []):
		if not property_data is Dictionary:
			continue
		var property_definition := ObjectPropertyDefinition.new()
		property_definition.property_id = str(property_data.get("id", ""))
		property_definition.display_name = str(property_data.get("name", property_definition.property_id))
		property_definition.value_type = str(property_data.get("type", "String"))
		property_definition.default_value = property_data.get("default", "")
		property_definition.group_name = str(property_data.get("group", "Основное"))
		property_definition.description = str(property_data.get("description", ""))
		property_definition.advanced = bool(property_data.get("advanced", false))
		property_definition.has_range = property_data.has("min") and property_data.has("max")
		if property_definition.has_range:
			property_definition.minimum = float(property_data["min"])
			property_definition.maximum = float(property_data["max"])
		definition.suggested_properties.append(property_definition)
	return definition


static func _get_builtin_icon(profile_id: String) -> String:
	match profile_id:
		"npc", "animal":
			return "users"
		"resource":
			return "pickaxe"
		"construction":
			return "house"
		"item":
			return "package"
		"weapon":
			return "swords"
		"tool":
			return "hammer"
		"interactive":
			return "hand"
		"decoration":
			return "flower-2"
		"transport":
			return "truck"
		"effect":
			return "sparkles"
		_:
			return "shapes"


static func _validate_definition(definition: ObjectCreationProfileDefinition) -> PackedStringArray:
	var errors := PackedStringArray()
	if definition == null:
		errors.append("Профиль не создан.")
		return errors
	if not _is_valid_id(_normalize_id(definition.profile_id)):
		errors.append("У профиля должен быть корректный ID.")
	if definition.display_name.strip_edges().is_empty():
		errors.append("У профиля должно быть название.")
	if definition.suggested_category.strip_edges().is_empty():
		errors.append("У профиля должна быть стартовая категория.")
	if not ClassDB.class_exists(definition.suggested_root_type):
		errors.append("Неизвестный корневой класс профиля: " + definition.suggested_root_type)
	var used_capability_ids: Dictionary = {}
	for capability_id_value in definition.suggested_capability_ids:
		var capability_id := _normalize_id(str(capability_id_value))
		if not _is_valid_id(capability_id):
			errors.append("У профиля '%s' некорректный ID рекомендуемой возможности: %s." % [
				definition.profile_id,
				str(capability_id_value)
			])
		elif used_capability_ids.has(capability_id):
			errors.append("У профиля '%s' повторяется рекомендуемая возможность: %s." % [
				definition.profile_id,
				capability_id
			])
		else:
			used_capability_ids[capability_id] = true

	var used_property_ids: Dictionary = {}
	for property_definition in definition.suggested_properties:
		if property_definition == null:
			errors.append("У профиля есть пустое стартовое свойство.")
			continue
		var property_id := property_definition.property_id.strip_edges()
		if property_id.is_empty():
			errors.append("Стартовое свойство профиля должно иметь ID.")
		elif used_property_ids.has(property_id):
			errors.append("В профиле повторяется ID свойства: " + property_id)
		else:
			used_property_ids[property_id] = true
	return errors


static func _normalize_id(value: String) -> String:
	return value.strip_edges().to_lower()


static func _is_valid_id(value: String) -> bool:
	if value.is_empty():
		return false
	var expression := RegEx.new()
	if expression.compile("^[a-z][a-z0-9_]*$") != OK:
		return false
	return expression.search(value) != null
