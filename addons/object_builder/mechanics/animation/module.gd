@tool
extends RefCounted

const SCRIPT_IDLE = preload("res://addons/object_builder/mechanics/animation/components/idle_animation.gd")
const SCRIPT_WALK = preload("res://addons/object_builder/mechanics/animation/components/walk_animation.gd")
const SCRIPT_RUN = preload("res://addons/object_builder/mechanics/animation/components/run_animation.gd")
const SCRIPT_ATTACK = preload("res://addons/object_builder/mechanics/animation/components/attack_animation.gd")
const SCRIPT_HIT = preload("res://addons/object_builder/mechanics/animation/components/hit_animation.gd")
const SCRIPT_DEATH = preload("res://addons/object_builder/mechanics/animation/components/death_animation.gd")
const SCRIPT_BLEND = preload("res://addons/object_builder/mechanics/animation/components/animation_blending.gd")
const SCRIPT_EVENTS = preload("res://addons/object_builder/mechanics/animation/components/animation_events.gd")
const SCRIPT_FRAME_EVENTS = preload("res://addons/object_builder/mechanics/animation/components/frame_events.gd")
const SCRIPT_VARIANTS = preload("res://addons/object_builder/mechanics/animation/components/animation_variants.gd")

const COMPONENT_CATEGORY_ID := "Appearance"
const CAPABILITY_CATEGORY_ID := "animation"
const CATEGORY_NAME := "Анимация"
const STATE_NOTE := "Локальная логика компонента реализована. Для активации в Object Builder требуется подтверждённая привязка AnimationPlayer/AnimatedSprite2D к экземпляру и проектные smoke-тесты."

const DEFINITIONS := [
    {"id":"plays_idle_animation","name":"Анимация ожидания","description":"Проигрывает указанную idle-анимацию через AnimationPlayer.","script":SCRIPT_IDLE,"defaults":{"animation_name":"idle"},"settings":[{"key":"animation_name","display_name":"Название анимации","value_type":"String","default_value":"idle","group_name":"Анимация"}],"keywords":["idle","ожидание","покой"]},
    {"id":"plays_walk_animation","name":"Анимация ходьбы","description":"Проигрывает указанную анимацию ходьбы.","script":SCRIPT_WALK,"defaults":{"animation_name":"walk"},"settings":[{"key":"animation_name","display_name":"Название анимации","value_type":"String","default_value":"walk","group_name":"Анимация"}],"keywords":["walk","ходьба"]},
    {"id":"plays_run_animation","name":"Анимация бега","description":"Проигрывает указанную анимацию бега.","script":SCRIPT_RUN,"defaults":{"animation_name":"run"},"settings":[{"key":"animation_name","display_name":"Название анимации","value_type":"String","default_value":"run","group_name":"Анимация"}],"keywords":["run","бег"]},
    {"id":"plays_attack_animation","name":"Анимация атаки","description":"Проигрывает анимацию атаки.","script":SCRIPT_ATTACK,"defaults":{"animation_name":"attack"},"settings":[{"key":"animation_name","display_name":"Название анимации","value_type":"String","default_value":"attack","group_name":"Анимация"}],"keywords":["attack","атака"]},
    {"id":"plays_hit_animation","name":"Анимация получения удара","description":"Проигрывает анимацию реакции на попадание.","script":SCRIPT_HIT,"defaults":{"animation_name":"hit"},"settings":[{"key":"animation_name","display_name":"Название анимации","value_type":"String","default_value":"hit","group_name":"Анимация"}],"keywords":["hit","получение урона"]},
    {"id":"plays_death_animation","name":"Анимация смерти","description":"Останавливает предыдущую анимацию и проигрывает анимацию смерти.","script":SCRIPT_DEATH,"defaults":{"animation_name":"death"},"settings":[{"key":"animation_name","display_name":"Название анимации","value_type":"String","default_value":"death","group_name":"Анимация"}],"keywords":["death","смерть"]},
    {"id":"supports_animation_blending","name":"Смешивание анимаций","description":"Запускает анимацию с настраиваемым временем плавного перехода.","script":SCRIPT_BLEND,"defaults":{"blend_seconds":0.15},"settings":[{"key":"blend_seconds","display_name":"Длительность перехода","value_type":"Float","default_value":0.15,"group_name":"Анимация","has_range":true,"minimum":0.0,"maximum":10.0}],"keywords":["blend","смешивание","переход"]},
    {"id":"supports_animation_events","name":"События анимации","description":"Отправляет события при начале и завершении AnimationPlayer-анимации.","script":SCRIPT_EVENTS,"defaults":{"emit_started":true,"emit_finished":true},"settings":[{"key":"emit_started","display_name":"Событие начала","value_type":"Boolean","default_value":true,"group_name":"Анимация"},{"key":"emit_finished","display_name":"Событие завершения","value_type":"Boolean","default_value":true,"group_name":"Анимация"}],"keywords":["events","события","сигналы"]},
    {"id":"supports_frame_events","name":"События кадров","description":"Отправляет событие при смене кадра AnimatedSprite2D; поддерживает фильтр индексов.","script":SCRIPT_FRAME_EVENTS,"defaults":{"frames_csv":""},"settings":[{"key":"frames_csv","display_name":"Кадры для событий (через запятую)","value_type":"String","default_value":"","group_name":"Анимация"}],"keywords":["frame","кадры","события кадров"]},
    {"id":"supports_animation_variants","name":"Варианты анимаций","description":"Выбирает вариант анимации из проверяемой JSON-таблицы.","script":SCRIPT_VARIANTS,"defaults":{"variant_map_json":"{}"},"settings":[{"key":"variant_map_json","display_name":"Таблица вариантов JSON","value_type":"String","default_value":"{}","group_name":"Анимация"}],"keywords":["variants","варианты","анимации"]}
]

func build_component_definitions() -> Array:
    var result: Array = []
    for item in DEFINITIONS:
        var definition := ObjectComponentDefinition.new()
        definition.component_id = item["id"]
        definition.display_name = item["name"]
        definition.description = item["description"]
        definition.category = "Appearance"
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
        capability.icon = "animation"
        capability.keywords = PackedStringArray(item["keywords"])
        capability.component_ids = PackedStringArray([item["id"]])
        capability.available_in_simple_mode = true
        capability.runtime_status = "Planned"
        capability.implementation_note = STATE_NOTE
        capability.version = 1
        result.append(capability)
    return result