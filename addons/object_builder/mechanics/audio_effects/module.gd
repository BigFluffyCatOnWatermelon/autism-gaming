@tool
extends RefCounted

const SCRIPT = preload("res://addons/object_builder/mechanics/audio_effects/component.gd")
const CATEGORY_ID := "audio_effects"
const CATEGORY_NAME := "Звук и эффекты"
const STATE_NOTE := "Audio/VFX runtime API: одноразовые и фоновые звуки, поверхности шагов, частицы, Line2D trail, PointLight2D и запрос тряски камеры через сигнал."

const SOUND_SETTINGS := [
	{"key":"stream_path","display_name":"Путь к AudioStream","value_type":"String","default_value":"","group_name":"Звук"},
	{"key":"volume_db","display_name":"Громкость (dB)","value_type":"Float","default_value":0.0,"group_name":"Звук","has_range":true,"minimum":-80.0,"maximum":24.0},
	{"key":"pitch_scale","display_name":"Высота тона","value_type":"Float","default_value":1.0,"group_name":"Звук","has_range":true,"minimum":0.01,"maximum":4.0},
	{"key":"bus","display_name":"Аудиошина","value_type":"String","default_value":"Master","group_name":"Звук"},
	{"key":"max_distance","display_name":"Максимальная дистанция","value_type":"Float","default_value":1200.0,"group_name":"Звук","has_range":true,"minimum":1.0,"maximum":100000.0},
	{"key":"attenuation","display_name":"Затухание","value_type":"Float","default_value":1.0,"group_name":"Звук","has_range":true,"minimum":0.0,"maximum":10.0}
]

const DEFINITIONS := [
	{"id":"plays_ambient_sound","name":"Фоновый звук","description":"Проигрывает зацикленный аудиопоток окружения по запросу.","defaults":{"stream_path":"","volume_db":-12.0,"pitch_scale":1.0,"bus":"Master","max_distance":1200.0,"attenuation":1.0},"settings":SOUND_SETTINGS},
	{"id":"plays_interaction_sound","name":"Звук взаимодействия","description":"Проигрывает AudioStream при взаимодействии с объектом.","defaults":{"stream_path":"","volume_db":0.0,"pitch_scale":1.0,"bus":"Master","max_distance":1200.0,"attenuation":1.0},"settings":SOUND_SETTINGS},
	{"id":"plays_footsteps","name":"Звуки шагов","description":"Выбирает аудиопоток по ID поверхности.","defaults":{"surface_streams_json":"{}","volume_db":0.0,"pitch_scale":1.0,"bus":"Master","max_distance":1200.0,"attenuation":1.0},"settings":[{"key":"surface_streams_json","display_name":"Звуки поверхностей JSON","value_type":"String","default_value":"{}","group_name":"Шаги"},{"key":"volume_db","display_name":"Громкость (dB)","value_type":"Float","default_value":0.0,"group_name":"Звук","has_range":true,"minimum":-80.0,"maximum":24.0},{"key":"pitch_scale","display_name":"Высота тона","value_type":"Float","default_value":1.0,"group_name":"Звук","has_range":true,"minimum":0.01,"maximum":4.0},{"key":"bus","display_name":"Аудиошина","value_type":"String","default_value":"Master","group_name":"Звук"},{"key":"max_distance","display_name":"Максимальная дистанция","value_type":"Float","default_value":1200.0,"group_name":"Звук","has_range":true,"minimum":1.0,"maximum":100000.0},{"key":"attenuation","display_name":"Затухание","value_type":"Float","default_value":1.0,"group_name":"Звук","has_range":true,"minimum":0.0,"maximum":10.0}]},
	{"id":"plays_attack_sound","name":"Звук атаки","description":"Проигрывает аудиопоток атакующего действия.","defaults":{"stream_path":"","volume_db":0.0,"pitch_scale":1.0,"bus":"Master","max_distance":1200.0,"attenuation":1.0},"settings":SOUND_SETTINGS},
	{"id":"plays_damage_sound","name":"Звук получения урона","description":"Проигрывает звук при получении урона.","defaults":{"stream_path":"","volume_db":0.0,"pitch_scale":1.0,"bus":"Master","max_distance":1200.0,"attenuation":1.0},"settings":SOUND_SETTINGS},
	{"id":"plays_destroy_sound","name":"Звук разрушения","description":"Проигрывает звук при уничтожении объекта.","defaults":{"stream_path":"","volume_db":0.0,"pitch_scale":1.0,"bus":"Master","max_distance":1200.0,"attenuation":1.0},"settings":SOUND_SETTINGS},
	{"id":"emits_particles","name":"Частицы","description":"Создаёт CPU particles или инстанцирует настроенную сцену эффекта.","defaults":{"particle_scene_path":"","particle_amount":24,"particle_lifetime":0.8,"particle_one_shot":true,"particle_spread":45.0,"particle_velocity_min":20.0,"particle_velocity_max":80.0},"settings":[{"key":"particle_scene_path","display_name":"Сцена эффекта","value_type":"String","default_value":"","group_name":"Частицы"},{"key":"particle_amount","display_name":"Количество частиц","value_type":"Integer","default_value":24,"group_name":"Частицы","has_range":true,"minimum":1,"maximum":10000},{"key":"particle_lifetime","display_name":"Время жизни","value_type":"Float","default_value":0.8,"group_name":"Частицы","has_range":true,"minimum":0.05,"maximum":120.0},{"key":"particle_one_shot","display_name":"Однократный выброс","value_type":"Boolean","default_value":true,"group_name":"Частицы"},{"key":"particle_spread","display_name":"Разброс","value_type":"Float","default_value":45.0,"group_name":"Частицы","has_range":true,"minimum":0.0,"maximum":180.0},{"key":"particle_velocity_min","display_name":"Минимальная скорость","value_type":"Float","default_value":20.0,"group_name":"Частицы","has_range":true,"minimum":0.0,"maximum":10000.0},{"key":"particle_velocity_max","display_name":"Максимальная скорость","value_type":"Float","default_value":80.0,"group_name":"Частицы","has_range":true,"minimum":0.0,"maximum":10000.0}]},
	{"id":"has_trail_effect","name":"След","description":"Создаёт Line2D и обновляет точки по мировой траектории объекта.","defaults":{"trail_color":"#ffffff88","trail_width":4.0,"trail_length":16,"trail_z_index":-1},"settings":[{"key":"trail_color","display_name":"Цвет следа","value_type":"String","default_value":"#ffffff88","group_name":"След"},{"key":"trail_width","display_name":"Толщина следа","value_type":"Float","default_value":4.0,"group_name":"След","has_range":true,"minimum":0.1,"maximum":256.0},{"key":"trail_length","display_name":"Количество точек","value_type":"Integer","default_value":16,"group_name":"След","has_range":true,"minimum":2,"maximum":2048},{"key":"trail_z_index","display_name":"Z-индекс","value_type":"Integer","default_value":-1,"group_name":"След"}]},
	{"id":"has_light_effect","name":"Свечение","description":"Создаёт PointLight2D с текстурой или мягким градиентом по умолчанию.","defaults":{"light_color":"#fff2c4","light_energy":1.0,"light_texture_path":"","light_scale":1.0},"settings":[{"key":"light_color","display_name":"Цвет света","value_type":"String","default_value":"#fff2c4","group_name":"Свет"},{"key":"light_energy","display_name":"Энергия","value_type":"Float","default_value":1.0,"group_name":"Свет","has_range":true,"minimum":0.0,"maximum":16.0},{"key":"light_texture_path","display_name":"Текстура света","value_type":"String","default_value":"","group_name":"Свет"},{"key":"light_scale","display_name":"Масштаб света","value_type":"Float","default_value":1.0,"group_name":"Свет","has_range":true,"minimum":0.01,"maximum":100.0}]},
	{"id":"supports_screen_shake","name":"Тряска камеры","description":"Отправляет запрос интенсивности и длительности тряски внешнему контроллеру камеры.","defaults":{"shake_intensity":4.0,"shake_duration":0.15},"settings":[{"key":"shake_intensity","display_name":"Интенсивность","value_type":"Float","default_value":4.0,"group_name":"Камера","has_range":true,"minimum":0.0,"maximum":1000.0},{"key":"shake_duration","display_name":"Длительность","value_type":"Float","default_value":0.15,"group_name":"Камера","has_range":true,"minimum":0.0,"maximum":30.0}]}
]


func _settings_for(item: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for setting in item.settings:
		result.append(setting.duplicate(true))
	return result


func build_component_definitions() -> Array[ObjectComponentDefinition]:
	var result: Array[ObjectComponentDefinition] = []
	for item in DEFINITIONS:
		var definition := ObjectComponentDefinition.new()
		definition.component_id = str(item.id)
		definition.display_name = str(item.name)
		definition.description = str(item.description)
		definition.category = "AudioEffects"
		definition.category_id = "AudioEffects"
		definition.category_display_name = CATEGORY_NAME
		definition.component_version = 1
		definition.component_script = SCRIPT
		definition.setting_definitions = _settings_for(item)
		definition.settings = item.defaults.duplicate(true)
		result.append(definition)
	return result


func build_capability_definitions() -> Array[ObjectCapabilityDefinition]:
	var result: Array[ObjectCapabilityDefinition] = []
	for item in DEFINITIONS:
		var definition := ObjectCapabilityDefinition.new()
		definition.capability_id = str(item.id)
		definition.display_name = str(item.name)
		definition.description = str(item.description)
		definition.category_id = CATEGORY_ID
		definition.category_name = CATEGORY_NAME
		definition.icon = "volume-2"
		definition.keywords = PackedStringArray([str(item.id).replace("_", " "), str(item.name), CATEGORY_NAME, "звук", "эффект"])
		definition.component_ids = PackedStringArray([str(item.id)])
		definition.available_in_simple_mode = true
		definition.runtime_status = "Implemented"
		definition.implementation_note = STATE_NOTE
		definition.version = 1
		result.append(definition)
	return result
