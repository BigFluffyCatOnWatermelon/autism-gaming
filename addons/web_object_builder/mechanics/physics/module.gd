@tool
extends RefCounted

const SCRIPT_HAS_COLLISION = preload("res://addons/web_object_builder/mechanics/physics/components/has_collision.gd")
const SCRIPT_BLOCKS_MOVEMENT = preload("res://addons/web_object_builder/mechanics/physics/components/blocks_movement.gd")
const SCRIPT_CAN_BE_PUSHED = preload("res://addons/web_object_builder/mechanics/physics/components/can_be_pushed.gd")
const SCRIPT_CAN_BE_PULLED = preload("res://addons/web_object_builder/mechanics/physics/components/can_be_pulled.gd")
const SCRIPT_HAS_MASS = preload("res://addons/web_object_builder/mechanics/physics/components/has_mass.gd")
const SCRIPT_AFFECTED_BY_GRAVITY = preload("res://addons/web_object_builder/mechanics/physics/components/affected_by_gravity.gd")
const SCRIPT_CAN_BOUNCE = preload("res://addons/web_object_builder/mechanics/physics/components/can_bounce.gd")
const SCRIPT_CAN_ROLL = preload("res://addons/web_object_builder/mechanics/physics/components/can_roll.gd")
const SCRIPT_CAN_SLIDE = preload("res://addons/web_object_builder/mechanics/physics/components/can_slide.gd")
const SCRIPT_HAS_PHYSICS_MATERIAL = preload("res://addons/web_object_builder/mechanics/physics/components/has_physics_material.gd")

const COMPONENT_CATEGORY_ID := "Physics"
const CAPABILITY_CATEGORY_ID := "physics"
const CATEGORY_NAME := "Физика"
const STATE_NOTE := "Локальные физические настройки и команды реализованы. Для корректной симуляции требуются подходящие StaticBody2D / RigidBody2D и формы коллизии и физический цикл Godot; пакет не создаёт их автоматически."

const DEFINITIONS := [
    {"id":"has_collision","name":"Имеет коллизию","description":"Включает или отключает CollisionShape2D и CollisionPolygon2D во всём дереве объекта.","script":SCRIPT_HAS_COLLISION,"defaults":{"collision_enabled":true},"settings":[{"key":"collision_enabled","display_name":"Коллизия включена","value_type":"Boolean","default_value":true,"group_name":"Коллизия"}],"keywords":["коллизия","столкновение","collision"]},
    {"id":"blocks_movement","name":"Препятствует движению","description":"Включает или отключает выбранный бит collision_layer у CollisionObject2D.","script":SCRIPT_BLOCKS_MOVEMENT,"defaults":{"blocking_enabled":true,"collision_layer_bit":1},"settings":[{"key":"blocking_enabled","display_name":"Блокировать движение","value_type":"Boolean","default_value":true,"group_name":"Блокировка"},{"key":"collision_layer_bit","display_name":"Слой коллизии (1–32)","value_type":"Integer","default_value":1,"group_name":"Блокировка","has_range":true,"minimum":1,"maximum":32}],"keywords":["препятствие","блокировка","collision layer"]},
    {"id":"can_be_pushed","name":"Можно толкать","description":"Применяет физический импульс к RigidBody2D или добавляет импульс скорости CharacterBody2D.","script":SCRIPT_CAN_BE_PUSHED,"defaults":{"push_impulse":160.0,"mass_floor":0.1},"settings":[{"key":"push_impulse","display_name":"Сила толчка","value_type":"Float","default_value":160.0,"group_name":"Толчок","has_range":true,"minimum":0.0,"maximum":100000.0},{"key":"mass_floor","display_name":"Минимальная масса","value_type":"Float","default_value":0.1,"group_name":"Толчок","has_range":true,"minimum":0.01,"maximum":1000.0}],"keywords":["толкать","импульс","push"]},
    {"id":"can_be_pulled","name":"Можно тянуть","description":"Притягивает RigidBody2D или CharacterBody2D к другому Node2D с ограничением дальности.","script":SCRIPT_CAN_BE_PULLED,"defaults":{"pull_impulse":120.0,"maximum_distance":1200.0},"settings":[{"key":"pull_impulse","display_name":"Сила притяжения","value_type":"Float","default_value":120.0,"group_name":"Притяжение","has_range":true,"minimum":0.0,"maximum":100000.0},{"key":"maximum_distance","display_name":"Максимальная дальность (0 — без ограничения)","value_type":"Float","default_value":1200.0,"group_name":"Притяжение","has_range":true,"minimum":0.0,"maximum":100000.0}],"keywords":["тянуть","притяжение","pull"]},
    {"id":"has_mass","name":"Масса","description":"Устанавливает массу RigidBody2D и проверяет допустимый диапазон.","script":SCRIPT_HAS_MASS,"defaults":{"mass":1.0},"settings":[{"key":"mass","display_name":"Масса","value_type":"Float","default_value":1.0,"group_name":"Физика","has_range":true,"minimum":0.01,"maximum":1000000.0}],"keywords":["масса","вес физического тела","mass"]},
    {"id":"affected_by_gravity","name":"Гравитация","description":"Настраивает gravity_scale у RigidBody2D, включая отрицательную гравитацию.","script":SCRIPT_AFFECTED_BY_GRAVITY,"defaults":{"gravity_scale":1.0},"settings":[{"key":"gravity_scale","display_name":"Масштаб гравитации","value_type":"Float","default_value":1.0,"group_name":"Физика","has_range":true,"minimum":-100.0,"maximum":100.0}],"keywords":["гравитация","gravity"]},
    {"id":"can_bounce","name":"Отскакивает","description":"Назначает изолированную копию PhysicsMaterial с указанными отскоком и трением.","script":SCRIPT_CAN_BOUNCE,"defaults":{"bounce":0.65,"friction":0.2},"settings":[{"key":"bounce","display_name":"Сила отскока","value_type":"Float","default_value":0.65,"group_name":"Отскок","has_range":true,"minimum":0.0,"maximum":1.0},{"key":"friction","display_name":"Трение","value_type":"Float","default_value":0.2,"group_name":"Отскок","has_range":true,"minimum":0.0,"maximum":1.0}],"keywords":["отскок","прыжок","bounce"]},
    {"id":"can_roll","name":"Может катиться","description":"Задаёт угловую скорость RigidBody2D для вращения вокруг центра.","script":SCRIPT_CAN_ROLL,"defaults":{"angular_speed":5.0,"maximum_angular_speed":20.0},"settings":[{"key":"angular_speed","display_name":"Угловая скорость","value_type":"Float","default_value":5.0,"group_name":"Качение","has_range":true,"minimum":0.0,"maximum":100.0},{"key":"maximum_angular_speed","display_name":"Предел угловой скорости","value_type":"Float","default_value":20.0,"group_name":"Качение","has_range":true,"minimum":0.0,"maximum":200.0}],"keywords":["качение","вращение","roll"]},
    {"id":"can_slide","name":"Скольжение","description":"Переключает коэффициент трения PhysicsMaterial у StaticBody2D / RigidBody2D между обычным и скользким режимом.","script":SCRIPT_CAN_SLIDE,"defaults":{"sliding_friction":0.05,"normal_friction":1.0},"settings":[{"key":"sliding_friction","display_name":"Трение при скольжении","value_type":"Float","default_value":0.05,"group_name":"Скольжение","has_range":true,"minimum":0.0,"maximum":1.0},{"key":"normal_friction","display_name":"Обычное трение","value_type":"Float","default_value":1.0,"group_name":"Скольжение","has_range":true,"minimum":0.0,"maximum":1.0}],"keywords":["скольжение","трение","slide"]},
    {"id":"has_physics_material","name":"Материал физики","description":"Создаёт отдельный PhysicsMaterial и задаёт трение, отскок, rough и absorbent.","script":SCRIPT_HAS_PHYSICS_MATERIAL,"defaults":{"friction":0.6,"bounce":0.0,"rough":false,"absorbent":false},"settings":[{"key":"friction","display_name":"Трение","value_type":"Float","default_value":0.6,"group_name":"Материал","has_range":true,"minimum":0.0,"maximum":1.0},{"key":"bounce","display_name":"Отскок","value_type":"Float","default_value":0.0,"group_name":"Материал","has_range":true,"minimum":0.0,"maximum":1.0},{"key":"rough","display_name":"Шероховатый контакт","value_type":"Boolean","default_value":false,"group_name":"Материал"},{"key":"absorbent","display_name":"Поглощать отскок другой поверхности","value_type":"Boolean","default_value":false,"group_name":"Материал"}],"keywords":["физический материал","трение","physics material"]}
]

func build_component_definitions() -> Array:
    var result: Array = []
    for item in DEFINITIONS:
        var definition := ObjectComponentDefinition.new()
        definition.component_id = item["id"]
        definition.display_name = item["name"]
        definition.description = item["description"]
        definition.category = "Physics"
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
        capability.icon = "weight"
        capability.keywords = PackedStringArray(item["keywords"])
        capability.component_ids = PackedStringArray([item["id"]])
        capability.available_in_simple_mode = true
        capability.runtime_status = "Planned"
        capability.implementation_note = STATE_NOTE
        capability.version = 1
        result.append(capability)
    return result
