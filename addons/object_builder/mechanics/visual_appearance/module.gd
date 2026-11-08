@tool
extends RefCounted

const SCRIPT_SPRITE = preload("res://addons/object_builder/mechanics/visual_appearance/component.gd")
const SCRIPT_PARTS = preload("res://addons/object_builder/mechanics/visual_appearance/components/visual_parts.gd")
const SCRIPT_DIRECTIONAL = preload("res://addons/object_builder/mechanics/visual_appearance/components/directional_sprites.gd")
const SCRIPT_TINT = preload("res://addons/object_builder/mechanics/visual_appearance/components/tint.gd")
const SCRIPT_OPACITY = preload("res://addons/object_builder/mechanics/visual_appearance/components/opacity.gd")
const SCRIPT_SHADOW = preload("res://addons/object_builder/mechanics/visual_appearance/components/visual_shadow.gd")
const SCRIPT_OUTLINE = preload("res://addons/object_builder/mechanics/visual_appearance/components/outline.gd")
const SCRIPT_LAYER = preload("res://addons/object_builder/mechanics/visual_appearance/components/layer_order.gd")
const SCRIPT_FLIP = preload("res://addons/object_builder/mechanics/visual_appearance/components/flip.gd")
const SCRIPT_PALETTE = preload("res://addons/object_builder/mechanics/visual_appearance/components/palette_swap.gd")

const COMPONENT_CATEGORY_ID := "Appearance"
const CAPABILITY_CATEGORY_ID := "visual"
const CATEGORY_NAME := "Внешний вид"
const STATE_NOTE := "Компонент содержит рабочие операции применения внешнего вида. Для включения в Object Builder ядро должно передать целевой узел/привязку, вызывать публичный метод применения и сохранять runtime-состояние."

const DEFINITIONS := [
    {"id":"has_sprite", "name":"Изображение", "description":"Назначает Texture2D целевому Sprite2D по пути к ресурсу.", "script":SCRIPT_SPRITE, "defaults":{"texture_path":""}, "settings":[{"key":"texture_path", "display_name":"Путь к текстуре", "value_type":"String", "default_value":"", "editor_hint":"texture", "group_name":"Изображение"}], "keywords":["спрайт", "текстура", "sprite"]},
    {"id":"has_multiple_visual_parts", "name":"Несколько визуальных частей", "description":"Управляет видимостью и смещением перечисленных дочерних визуальных узлов.", "script":SCRIPT_PARTS, "defaults":{"part_paths":"", "parts_visible":true, "parts_offset":Vector2.ZERO}, "settings":[{"key":"part_paths", "display_name":"Пути частей через ;", "value_type":"String", "default_value":"", "group_name":"Части"}, {"key":"parts_visible", "display_name":"Показывать части", "value_type":"Boolean", "default_value":true, "group_name":"Части"}, {"key":"parts_offset", "display_name":"Смещение частей", "value_type":"Vector2", "default_value":Vector2.ZERO, "group_name":"Части"}], "keywords":["части", "слои", "составной объект"]},
    {"id":"supports_directional_sprites", "name":"Спрайты по направлениям", "description":"Выбирает текстуру по ключу направления из JSON-карты.", "script":SCRIPT_DIRECTIONAL, "defaults":{"directions_json":"{}", "initial_direction":"down"}, "settings":[{"key":"directions_json", "display_name":"Карта направлений JSON", "value_type":"String", "default_value":"{}", "editor_hint":"json", "group_name":"Направления"}, {"key":"initial_direction", "display_name":"Начальное направление", "value_type":"String", "default_value":"down", "group_name":"Направления"}], "keywords":["направление", "спрайт", "direction"]},
    {"id":"supports_tint", "name":"Цветовой оттенок", "description":"Меняет цвет CanvasItem, сохраняя текущую прозрачность.", "script":SCRIPT_TINT, "defaults":{"tint_color":"#ffffff"}, "settings":[{"key":"tint_color", "display_name":"Цвет оттенка", "value_type":"String", "default_value":"#ffffff", "editor_hint":"color", "group_name":"Цвет"}], "keywords":["цвет", "оттенок", "tint"]},
    {"id":"supports_opacity", "name":"Прозрачность", "description":"Устанавливает альфа-канал CanvasItem от 0 до 1.", "script":SCRIPT_OPACITY, "defaults":{"opacity":1.0}, "settings":[{"key":"opacity", "display_name":"Непрозрачность", "value_type":"Float", "default_value":1.0, "group_name":"Прозрачность", "has_range":true, "minimum":0.0, "maximum":1.0}], "keywords":["прозрачность", "альфа", "opacity"]},
    {"id":"casts_visual_shadow", "name":"Визуальная тень", "description":"Создаёт и обновляет отдельный Sprite2D с затемнённой текстурой источника.", "script":SCRIPT_SHADOW, "defaults":{"shadow_offset":Vector2(0,8), "shadow_opacity":0.35, "shadow_scale":Vector2(1,0.55)}, "settings":[{"key":"shadow_offset", "display_name":"Смещение тени", "value_type":"Vector2", "default_value":Vector2(0,8), "group_name":"Тень"}, {"key":"shadow_opacity", "display_name":"Прозрачность тени", "value_type":"Float", "default_value":0.35, "group_name":"Тень", "has_range":true, "minimum":0.0, "maximum":1.0}, {"key":"shadow_scale", "display_name":"Масштаб тени", "value_type":"Vector2", "default_value":Vector2(1,0.55), "group_name":"Тень"}], "keywords":["тень", "sprite", "shadow"]},
    {"id":"supports_outline", "name":"Обводка", "description":"Устанавливает ShaderMaterial, рисующий контур вокруг непрозрачных пикселей спрайта.", "script":SCRIPT_OUTLINE, "defaults":{"outline_color":"#ffffff", "outline_width":1.0}, "settings":[{"key":"outline_color", "display_name":"Цвет обводки", "value_type":"String", "default_value":"#ffffff", "editor_hint":"color", "group_name":"Обводка"}, {"key":"outline_width", "display_name":"Толщина обводки", "value_type":"Float", "default_value":1.0, "group_name":"Обводка", "has_range":true, "minimum":1.0, "maximum":4.0}], "keywords":["контур", "обводка", "outline"]},
    {"id":"supports_layer_order", "name":"Порядок отрисовки", "description":"Устанавливает z_index и режим относительного порядка CanvasItem.", "script":SCRIPT_LAYER, "defaults":{"z_index":0, "z_as_relative":true}, "settings":[{"key":"z_index", "display_name":"Порядок отрисовки", "value_type":"Integer", "default_value":0, "group_name":"Слои", "has_range":true, "minimum":-4096, "maximum":4096}, {"key":"z_as_relative", "display_name":"Относительный порядок", "value_type":"Boolean", "default_value":true, "group_name":"Слои"}], "keywords":["слой", "z-index", "отрисовка"]},
    {"id":"supports_flip", "name":"Отражение изображения", "description":"Отражает Sprite2D по горизонтали и/или вертикали.", "script":SCRIPT_FLIP, "defaults":{"flip_horizontal":false, "flip_vertical":false}, "settings":[{"key":"flip_horizontal", "display_name":"Отразить по горизонтали", "value_type":"Boolean", "default_value":false, "group_name":"Отражение"}, {"key":"flip_vertical", "display_name":"Отразить по вертикали", "value_type":"Boolean", "default_value":false, "group_name":"Отражение"}], "keywords":["отражение", "зеркало", "flip"]},
    {"id":"supports_palette_swap", "name":"Смена палитры", "description":"Создаёт runtime-копию текстуры с точечной заменой заданных RGBA-цветов.", "script":SCRIPT_PALETTE, "defaults":{"palette_json":"{}"}, "settings":[{"key":"palette_json", "display_name":"Замены цветов JSON", "value_type":"String", "default_value":"{}", "editor_hint":"json", "group_name":"Палитра"}], "keywords":["палитра", "цвета", "palette"]}
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
        capability.icon = "image"
        capability.keywords = PackedStringArray(item["keywords"])
        capability.component_ids = PackedStringArray([item["id"]])
        capability.available_in_simple_mode = true
        capability.runtime_status = "Planned"
        capability.implementation_note = STATE_NOTE
        capability.version = 1
        result.append(capability)
    return result
