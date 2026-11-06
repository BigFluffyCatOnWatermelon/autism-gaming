@tool
extends RefCounted

const SCRIPT_CAN_INTERACT = preload("res://addons/object_builder/mechanics/interaction/components/can_interact.gd")
const SCRIPT_CAN_BE_PICKED_UP = preload("res://addons/object_builder/mechanics/interaction/components/can_be_picked_up.gd")
const SCRIPT_CAN_BE_ACTIVATED = preload("res://addons/object_builder/mechanics/interaction/components/can_be_activated.gd")
const SCRIPT_CAN_BE_OPENED = preload("res://addons/object_builder/mechanics/interaction/components/can_be_opened.gd")
const SCRIPT_CAN_BE_CLOSED = preload("res://addons/object_builder/mechanics/interaction/components/can_be_closed.gd")
const SCRIPT_CAN_BE_TOGGLED = preload("res://addons/object_builder/mechanics/interaction/components/can_be_toggled.gd")
const SCRIPT_CAN_BE_USED = preload("res://addons/object_builder/mechanics/interaction/components/can_be_used.gd")
const SCRIPT_HAS_INTERACTION_RANGE = preload("res://addons/object_builder/mechanics/interaction/components/has_interaction_range.gd")
const SCRIPT_SHOWS_INTERACTION_PROMPT = preload("res://addons/object_builder/mechanics/interaction/components/shows_interaction_prompt.gd")
const SCRIPT_SUPPORTS_HOLD_INTERACTION = preload("res://addons/object_builder/mechanics/interaction/components/supports_hold_interaction.gd")

const CATEGORY_ID := "interaction"
const CATEGORY_NAME := "Взаимодействие"
const STATE_NOTE := "Локальные состояния, проверки диапазона, счётчики и прогресс удержания реализованы. Запросы подбора/взаимодействия выдаются сигналами; ядро должно подключить получателей и интерфейс."

const DEFINITIONS := [
    {"id":"can_interact","name":"Можно взаимодействовать","description":"Принимает запрос от действующего Node и выдаёт сигнал interaction_requested.","script":SCRIPT_CAN_INTERACT,"defaults":{"enabled":true},"settings":[{"key":"enabled","display_name":"Взаимодействие включено","value_type":"Boolean","default_value":true,"group_name":"Взаимодействие"}],"keywords":["взаимодействие","interaction"]},
    {"id":"can_be_picked_up","name":"Можно подобрать","description":"Принимает однократный или повторный запрос подбора и выдаёт сигнал для передачи предмета системе инвентаря.","script":SCRIPT_CAN_BE_PICKED_UP,"defaults":{"enabled":true,"one_time_pickup":true},"settings":[{"key":"enabled","display_name":"Подбор включён","value_type":"Boolean","default_value":true,"group_name":"Подбор"},{"key":"one_time_pickup","display_name":"Только один раз","value_type":"Boolean","default_value":true,"group_name":"Подбор"}],"keywords":["подбор","pickup"]},
    {"id":"can_be_activated","name":"Можно активировать","description":"Хранит общее состояние активности на целевом узле и поддерживает активацию и деактивацию.","script":SCRIPT_CAN_BE_ACTIVATED,"defaults":{"enabled":true,"start_active":false},"settings":[{"key":"enabled","display_name":"Активация включена","value_type":"Boolean","default_value":true,"group_name":"Активация"},{"key":"start_active","display_name":"Активен при запуске","value_type":"Boolean","default_value":false,"group_name":"Активация"}],"keywords":["активация","active"]},
    {"id":"can_be_opened","name":"Можно открыть","description":"Открывает общий флаг состояния объекта и выдаёт событие opened.","script":SCRIPT_CAN_BE_OPENED,"defaults":{"enabled":true,"starts_open":false},"settings":[{"key":"enabled","display_name":"Открытие включено","value_type":"Boolean","default_value":true,"group_name":"Открытие"},{"key":"starts_open","display_name":"Открыт при запуске","value_type":"Boolean","default_value":false,"group_name":"Открытие"}],"keywords":["открыть","дверь","open"]},
    {"id":"can_be_closed","name":"Можно закрыть","description":"Закрывает тот же общий флаг состояния, который используется компонентом открытия.","script":SCRIPT_CAN_BE_CLOSED,"defaults":{"enabled":true,"starts_open":false},"settings":[{"key":"enabled","display_name":"Закрытие включено","value_type":"Boolean","default_value":true,"group_name":"Закрытие"},{"key":"starts_open","display_name":"Открыт при запуске","value_type":"Boolean","default_value":false,"group_name":"Закрытие"}],"keywords":["закрыть","дверь","close"]},
    {"id":"can_be_toggled","name":"Переключаемое состояние","description":"Переключает и хранит Boolean-состояние на целевом объекте, выдавая сигнал при изменении.","script":SCRIPT_CAN_BE_TOGGLED,"defaults":{"enabled":true,"initial_state":false},"settings":[{"key":"enabled","display_name":"Переключение включено","value_type":"Boolean","default_value":true,"group_name":"Переключение"},{"key":"initial_state","display_name":"Включено при запуске","value_type":"Boolean","default_value":false,"group_name":"Переключение"}],"keywords":["переключатель","toggle","состояние"]},
    {"id":"can_be_used","name":"Можно использовать","description":"Принимает использование, считает применения и блокирует запросы после достижения лимита.","script":SCRIPT_CAN_BE_USED,"defaults":{"enabled":true,"maximum_uses":0},"settings":[{"key":"enabled","display_name":"Использование включено","value_type":"Boolean","default_value":true,"group_name":"Использование"},{"key":"maximum_uses","display_name":"Максимум применений (0 — без лимита)","value_type":"Integer","default_value":0,"group_name":"Использование","has_range":true,"minimum":0,"maximum":1000000}],"keywords":["использовать","применение","use"]},
    {"id":"has_interaction_range","name":"Радиус взаимодействия","description":"Проверяет расстояние между целевым Node2D и инициатором взаимодействия.","script":SCRIPT_HAS_INTERACTION_RANGE,"defaults":{"interaction_range":96.0},"settings":[{"key":"interaction_range","display_name":"Радиус взаимодействия","value_type":"Float","default_value":96.0,"group_name":"Дальность","has_range":true,"minimum":0.0,"maximum":100000.0}],"keywords":["радиус","дальность","range"]},
    {"id":"shows_interaction_prompt","name":"Подсказка взаимодействия","description":"Возвращает текст подсказки, когда инициатор находится внутри заданного радиуса.","script":SCRIPT_SHOWS_INTERACTION_PROMPT,"defaults":{"prompt_text":"Взаимодействовать","prompt_range":96.0,"enabled":true},"settings":[{"key":"prompt_text","display_name":"Текст подсказки","value_type":"String","default_value":"Взаимодействовать","group_name":"Подсказка"},{"key":"prompt_range","display_name":"Радиус показа","value_type":"Float","default_value":96.0,"group_name":"Подсказка","has_range":true,"minimum":0.0,"maximum":100000.0},{"key":"enabled","display_name":"Показывать подсказку","value_type":"Boolean","default_value":true,"group_name":"Подсказка"}],"keywords":["подсказка","prompt"]},
    {"id":"supports_hold_interaction","name":"Удержание для взаимодействия","description":"Считает прогресс удержания по delta, отменяет его и завершает по достижении длительности.","script":SCRIPT_SUPPORTS_HOLD_INTERACTION,"defaults":{"hold_duration":1.0,"enabled":true},"settings":[{"key":"hold_duration","display_name":"Время удержания","value_type":"Float","default_value":1.0,"group_name":"Удержание","has_range":true,"minimum":0.05,"maximum":120.0},{"key":"enabled","display_name":"Удержание включено","value_type":"Boolean","default_value":true,"group_name":"Удержание"}],"keywords":["удержание","hold"]}
]

func build_component_definitions() -> Array:
    var result: Array = []
    for item in DEFINITIONS:
        var definition := ObjectComponentDefinition.new()
        definition.component_id = item["id"]
        definition.display_name = item["name"]
        definition.description = item["description"]
        definition.category = "Interaction"
        definition.category_id = CATEGORY_ID
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
        capability.category_id = CATEGORY_ID
        capability.category_name = CATEGORY_NAME
        capability.icon = "hand"
        capability.keywords = PackedStringArray(item["keywords"])
        capability.component_ids = PackedStringArray([item["id"]])
        capability.available_in_simple_mode = true
        capability.runtime_status = "Planned"
        capability.implementation_note = STATE_NOTE
        capability.version = 1
        result.append(capability)
    return result
