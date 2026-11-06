@tool
extends RefCounted

const SCRIPT_IDENTITY = preload("res://addons/object_builder/mechanics/object_identity/component.gd")
const SCRIPT_ENABLE = preload("res://addons/object_builder/mechanics/object_identity/components/can_be_enabled.gd")
const SCRIPT_DISABLE = preload("res://addons/object_builder/mechanics/object_identity/components/can_be_disabled.gd")
const SCRIPT_NAME = preload("res://addons/object_builder/mechanics/object_identity/components/custom_name.gd")
const SCRIPT_TAGS = preload("res://addons/object_builder/mechanics/object_identity/components/tags.gd")
const SCRIPT_FACTION = preload("res://addons/object_builder/mechanics/object_identity/components/faction.gd")
const SCRIPT_RARITY = preload("res://addons/object_builder/mechanics/object_identity/components/rarity.gd")
const SCRIPT_LEVEL = preload("res://addons/object_builder/mechanics/object_identity/components/level.gd")
const SCRIPT_EXPERIENCE = preload("res://addons/object_builder/mechanics/object_identity/components/experience.gd")
const SCRIPT_METADATA = preload("res://addons/object_builder/mechanics/object_identity/components/metadata.gd")

const COMPONENT_CATEGORY_ID := "Stats"
const CAPABILITY_CATEGORY_ID := "general"
const CATEGORY_NAME := "Основное"
const STATE_NOTE := "Компонент проверяет и изменяет собственное состояние. Для сохранения runtime-изменений ядро должно сохранять export_runtime_state() и вызывать import_runtime_state() при восстановлении."

const DEFINITIONS := [
    {"id":"has_unique_identity", "name":"Уникальный идентификатор", "description":"Создаёт и хранит постоянный UID объекта.", "script":SCRIPT_IDENTITY, "defaults":{"identity_id":""}, "settings":[{"key":"identity_id", "display_name":"ID объекта", "value_type":"String", "default_value":"", "group_name":"Идентификация"}], "keywords":["uid", "идентификатор", "identity"]},
    {"id":"can_be_enabled", "name":"Можно включать", "description":"Разрешает включать объект через enable() с проверкой разрешения.", "script":SCRIPT_ENABLE, "defaults":{"initially_enabled":false, "allow_enable":true}, "settings":[{"key":"initially_enabled", "display_name":"Включён изначально", "value_type":"Boolean", "default_value":false, "group_name":"Состояние"}, {"key":"allow_enable", "display_name":"Разрешить включение", "value_type":"Boolean", "default_value":true, "group_name":"Правила"}], "keywords":["включение", "активация", "enable"]},
    {"id":"can_be_disabled", "name":"Можно отключать", "description":"Разрешает отключать объект через disable() с проверкой разрешения.", "script":SCRIPT_DISABLE, "defaults":{"initially_enabled":true, "allow_disable":true}, "settings":[{"key":"initially_enabled", "display_name":"Включён изначально", "value_type":"Boolean", "default_value":true, "group_name":"Состояние"}, {"key":"allow_disable", "display_name":"Разрешить отключение", "value_type":"Boolean", "default_value":true, "group_name":"Правила"}], "keywords":["отключение", "деактивация", "disable"]},
    {"id":"has_custom_name", "name":"Собственное имя", "description":"Хранит имя объекта длиной до 128 символов.", "script":SCRIPT_NAME, "defaults":{"custom_name":""}, "settings":[{"key":"custom_name", "display_name":"Имя объекта", "value_type":"String", "default_value":"", "group_name":"Имя"}], "keywords":["имя", "название", "name"]},
    {"id":"supports_tags", "name":"Метки и теги", "description":"Хранит уникальный набор до 64 текстовых меток.", "script":SCRIPT_TAGS, "defaults":{"tags_csv":""}, "settings":[{"key":"tags_csv", "display_name":"Начальные метки", "value_type":"String", "default_value":"", "group_name":"Метки"}], "keywords":["теги", "метки", "фильтр"]},
    {"id":"supports_factions", "name":"Принадлежность к фракции", "description":"Хранит проверенный ID фракции объекта.", "script":SCRIPT_FACTION, "defaults":{"faction_id":"neutral"}, "settings":[{"key":"faction_id", "display_name":"ID фракции", "value_type":"String", "default_value":"neutral", "group_name":"Фракция"}], "keywords":["фракция", "команда", "faction"]},
    {"id":"supports_rarity", "name":"Редкость", "description":"Хранит один из поддерживаемых уровней редкости.", "script":SCRIPT_RARITY, "defaults":{"rarity":"common"}, "settings":[{"key":"rarity", "display_name":"Редкость", "value_type":"String", "default_value":"common", "group_name":"Редкость"}], "keywords":["редкость", "качество", "rarity"]},
    {"id":"supports_levels", "name":"Уровень", "description":"Хранит уровень объекта от 1 до 999.", "script":SCRIPT_LEVEL, "defaults":{"initial_level":1}, "settings":[{"key":"initial_level", "display_name":"Начальный уровень", "value_type":"Integer", "default_value":1, "group_name":"Прогресс", "has_range":true, "minimum":1, "maximum":999}], "keywords":["уровень", "прогресс", "level"]},
    {"id":"supports_experience_points", "name":"Опыт", "description":"Позволяет начислять и расходовать очки опыта с проверкой переполнения.", "script":SCRIPT_EXPERIENCE, "defaults":{"initial_experience":0}, "settings":[{"key":"initial_experience", "display_name":"Начальный опыт", "value_type":"Integer", "default_value":0, "group_name":"Прогресс", "has_range":true, "minimum":0, "maximum":2147483647}], "keywords":["опыт", "xp", "experience"]},
    {"id":"supports_metadata", "name":"Дополнительные данные", "description":"Хранит дополнительные примитивные значения в проверяемом JSON-словаре.", "script":SCRIPT_METADATA, "defaults":{"metadata_json":"{}"}, "settings":[{"key":"metadata_json", "display_name":"Начальные данные JSON", "value_type":"String", "default_value":"{}", "group_name":"Метаданные"}], "keywords":["метаданные", "данные", "json"]}
]


func build_component_definitions() -> Array:
    var result: Array = []
    for item in DEFINITIONS:
        var definition := ObjectComponentDefinition.new()
        definition.component_id = item["id"]
        definition.display_name = item["name"]
        definition.description = item["description"]
        definition.category = "Stats"
        definition.category_id = COMPONENT_CATEGORY_ID
        definition.category_display_name = CATEGORY_NAME
        definition.component_version = 1
        definition.component_script = item["script"]
        var typed_settings: Array[Dictionary] = []
        for setting_value in item["settings"]:
            if setting_value is Dictionary:
                typed_settings.append(setting_value.duplicate(true))
        definition.setting_definitions = typed_settings
        definition.settings = item["defaults"].duplicate(true)
        result.append(definition)
    return result


func build_capability_definitions() -> Array:
    var result: Array = []
    for item in DEFINITIONS:
        var capability := ObjectCapabilityDefinition.new()
        capability.capability_id = item["id"]
        capability.display_name = item["name"]
        capability.description = item["description"]
        capability.category_id = CAPABILITY_CATEGORY_ID
        capability.category_name = CATEGORY_NAME
        capability.icon = "dot"
        capability.keywords = PackedStringArray(item["keywords"])
        capability.component_ids = PackedStringArray([item["id"]])
        capability.available_in_simple_mode = true
        capability.runtime_status = "Planned"
        capability.implementation_note = STATE_NOTE
        capability.version = 1
        result.append(capability)
    return result
