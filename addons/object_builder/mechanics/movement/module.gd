@tool
extends RefCounted

const SCRIPT_MOVE = preload("res://addons/object_builder/mechanics/movement/components/move.gd")
const SCRIPT_WALK = preload("res://addons/object_builder/mechanics/movement/components/walk.gd")
const SCRIPT_RUN = preload("res://addons/object_builder/mechanics/movement/components/run.gd")
const SCRIPT_JUMP = preload("res://addons/object_builder/mechanics/movement/components/jump.gd")
const SCRIPT_DASH = preload("res://addons/object_builder/mechanics/movement/components/dash.gd")
const SCRIPT_FLY = preload("res://addons/object_builder/mechanics/movement/components/fly.gd")
const SCRIPT_SWIM = preload("res://addons/object_builder/mechanics/movement/components/swim.gd")
const SCRIPT_CLIMB = preload("res://addons/object_builder/mechanics/movement/components/climb.gd")
const SCRIPT_TELEPORT = preload("res://addons/object_builder/mechanics/movement/components/teleport.gd")
const SCRIPT_PATROL = preload("res://addons/object_builder/mechanics/movement/components/patrol_route.gd")

const CATEGORY_ID := "movement"
const CATEGORY_NAME := "Движение"
const STATE_NOTE := "Локальные команды движения реализованы. Для работы Object Builder должен привязать Node2D, вызывать команды из игрового цикла и согласовывать конкурирующие источники движения."

const DEFINITIONS := [
    {"id":"can_move","name":"Может перемещаться","description":"Перемещает привязанный Node2D в заданном направлении; для CharacterBody2D использует move_and_slide().","script":SCRIPT_MOVE,"defaults":{"move_speed":120.0},"settings":[{"key":"move_speed","display_name":"Скорость движения","value_type":"Float","default_value":120.0,"group_name":"Движение","has_range":true,"minimum":0.0,"maximum":2000.0}],"keywords":["движение","перемещение","move"]},
    {"id":"can_walk","name":"Ходьба","description":"Выполняет шаг в указанном направлении со скоростью ходьбы.","script":SCRIPT_WALK,"defaults":{"walk_speed":80.0},"settings":[{"key":"walk_speed","display_name":"Скорость ходьбы","value_type":"Float","default_value":80.0,"group_name":"Движение","has_range":true,"minimum":0.0,"maximum":2000.0}],"keywords":["ходьба","walk"]},
    {"id":"can_run","name":"Бег","description":"Выполняет шаг в указанном направлении со скоростью бега.","script":SCRIPT_RUN,"defaults":{"run_speed":180.0},"settings":[{"key":"run_speed","display_name":"Скорость бега","value_type":"Float","default_value":180.0,"group_name":"Движение","has_range":true,"minimum":0.0,"maximum":2000.0}],"keywords":["бег","run"]},
    {"id":"can_jump","name":"Прыжок","description":"Создаёт Tween-прыжок с возвращением в исходную локальную высоту.","script":SCRIPT_JUMP,"defaults":{"jump_height":48.0,"jump_duration":0.45},"settings":[{"key":"jump_height","display_name":"Высота прыжка","value_type":"Float","default_value":48.0,"group_name":"Движение","has_range":true,"minimum":1.0,"maximum":1000.0},{"key":"jump_duration","display_name":"Длительность прыжка","value_type":"Float","default_value":0.45,"group_name":"Движение","has_range":true,"minimum":0.05,"maximum":5.0}],"keywords":["прыжок","jump"]},
    {"id":"can_dash","name":"Рывок","description":"Выполняет направленный Tween-рывок с длительностью и перезарядкой.","script":SCRIPT_DASH,"defaults":{"dash_distance":96.0,"dash_duration":0.18,"cooldown_seconds":0.6},"settings":[{"key":"dash_distance","display_name":"Дистанция рывка","value_type":"Float","default_value":96.0,"group_name":"Движение","has_range":true,"minimum":1.0,"maximum":2000.0},{"key":"dash_duration","display_name":"Длительность рывка","value_type":"Float","default_value":0.18,"group_name":"Движение","has_range":true,"minimum":0.03,"maximum":2.0},{"key":"cooldown_seconds","display_name":"Перезарядка","value_type":"Float","default_value":0.6,"group_name":"Движение","has_range":true,"minimum":0.0,"maximum":60.0}],"keywords":["рывок","dash"]},
    {"id":"can_fly","name":"Полёт","description":"Перемещает объект по двум осям со скоростью полёта.","script":SCRIPT_FLY,"defaults":{"flight_speed":160.0},"settings":[{"key":"flight_speed","display_name":"Скорость полёта","value_type":"Float","default_value":160.0,"group_name":"Движение","has_range":true,"minimum":0.0,"maximum":2000.0}],"keywords":["полёт","летать","fly"]},
    {"id":"can_swim","name":"Плавание","description":"Перемещает объект в состоянии плавания; состояние включается методом set_swimming().","script":SCRIPT_SWIM,"defaults":{"swim_speed":70.0,"requires_swimming_state":true},"settings":[{"key":"swim_speed","display_name":"Скорость плавания","value_type":"Float","default_value":70.0,"group_name":"Движение","has_range":true,"minimum":0.0,"maximum":2000.0},{"key":"requires_swimming_state","display_name":"Требовать состояние плавания","value_type":"Boolean","default_value":true,"group_name":"Движение"}],"keywords":["плавание","swim"]},
    {"id":"can_climb","name":"Лазание","description":"Перемещает объект по вертикали в соответствии с величиной ввода.","script":SCRIPT_CLIMB,"defaults":{"climb_speed":80.0},"settings":[{"key":"climb_speed","display_name":"Скорость лазания","value_type":"Float","default_value":80.0,"group_name":"Движение","has_range":true,"minimum":0.0,"maximum":2000.0}],"keywords":["лазание","climb"]},
    {"id":"can_teleport","name":"Телепортация","description":"Мгновенно перемещает объект в координаты с необязательным ограничением радиуса.","script":SCRIPT_TELEPORT,"defaults":{"max_range":0.0},"settings":[{"key":"max_range","display_name":"Максимальная дальность (0 — без ограничения)","value_type":"Float","default_value":0.0,"group_name":"Движение","has_range":true,"minimum":0.0,"maximum":100000.0}],"keywords":["телепорт","teleport"]},
    {"id":"has_patrol_route","name":"Маршрут движения","description":"Двигает объект по JSON-маршруту, поддерживает зацикливание и событие прибытия.","script":SCRIPT_PATROL,"defaults":{"route_json":"[[0,0],[128,0],[128,128]]","patrol_speed":60.0,"loop_route":true},"settings":[{"key":"route_json","display_name":"Маршрут JSON","value_type":"String","default_value":"[[0,0],[128,0],[128,128]]","group_name":"Движение"},{"key":"patrol_speed","display_name":"Скорость патруля","value_type":"Float","default_value":60.0,"group_name":"Движение","has_range":true,"minimum":0.0,"maximum":2000.0},{"key":"loop_route","display_name":"Зацикливать маршрут","value_type":"Boolean","default_value":true,"group_name":"Движение"}],"keywords":["маршрут","патруль","patrol"]}
]

func build_component_definitions() -> Array:
    var result: Array = []
    for item in DEFINITIONS:
        var definition := ObjectComponentDefinition.new()
        definition.component_id = item["id"]
        definition.display_name = item["name"]
        definition.description = item["description"]
        definition.category = "Movement"
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
        capability.icon = "move"
        capability.keywords = PackedStringArray(item["keywords"])
        capability.component_ids = PackedStringArray([item["id"]])
        capability.available_in_simple_mode = true
        capability.runtime_status = "Planned"
        capability.implementation_note = STATE_NOTE
        capability.version = 1
        result.append(capability)
    return result