@tool
extends "res://addons/object_builder/mechanics/animation/components/animation_action_component.gd"

signal variant_selected(base_animation: String, variant: String, resolved_animation: String)

var _variant_map: Dictionary = {}


func _on_configured() -> void:
    _load_options({"variant_map_json": "{}"})
    _parse_variant_map()


func configure_mechanic(values: Dictionary) -> bool:
    if values.has("variant_map_json") and not _is_valid_variant_map(str(values["variant_map_json"])):
        return _fail("Таблица вариантов имеет неверную структуру JSON.")
    if not super.configure_mechanic(values):
        return false
    return _parse_variant_map()


func _is_valid_variant_map(raw: String) -> bool:
    var parsed: Variant = JSON.parse_string(raw)
    if typeof(parsed) != TYPE_DICTIONARY:
        return false
    for base_name in parsed:
        if typeof(base_name) != TYPE_STRING or String(base_name).strip_edges().is_empty():
            return false
        if typeof(parsed[base_name]) != TYPE_DICTIONARY:
            return false
        for variant_name in parsed[base_name]:
            var resolved := str(parsed[base_name][variant_name]).strip_edges()
            if String(variant_name).strip_edges().is_empty() or resolved.is_empty():
                return false
    return true


func _parse_variant_map() -> bool:
    var parsed: Variant = JSON.parse_string(str(get_option("variant_map_json", "{}")))
    if not _is_valid_variant_map(str(get_option("variant_map_json", "{}"))):
        return _fail("Таблица вариантов должна быть корректным JSON-объектом.")
    var clean: Dictionary = {}
    for base_name in parsed:
        if typeof(base_name) != TYPE_STRING or String(base_name).strip_edges().is_empty():
            return _fail("Название базовой анимации некорректно.")
        if typeof(parsed[base_name]) != TYPE_DICTIONARY:
            return _fail("Варианты для %s должны быть JSON-объектом." % str(base_name))
        var variants: Dictionary = {}
        for variant_name in parsed[base_name]:
            var resolved := str(parsed[base_name][variant_name]).strip_edges()
            if String(variant_name).strip_edges().is_empty() or resolved.is_empty():
                return _fail("Названия вариантов и анимаций не могут быть пустыми.")
            variants[String(variant_name)] = resolved
        clean[String(base_name)] = variants
    _variant_map = clean
    return true


func play_variant(base_animation: String, variant: String) -> bool:
    var base := base_animation.strip_edges()
    var variant_key := variant.strip_edges()
    if not _variant_map.has(base) or not _variant_map[base].has(variant_key):
        return _fail("Вариант '%s' для анимации '%s' не настроен." % [variant_key, base])
    var resolved: String = _variant_map[base][variant_key]
    if not _play_animation(resolved):
        return false
    variant_selected.emit(base, variant_key, resolved)
    return true
