@tool
extends "res://addons/web_object_builder/mechanics/object_identity/components/mechanic_component.gd"


func _on_configured() -> void:
    _load_options({"metadata_json": "{}"})
    if not _metadata_is_valid(str(get_option("metadata_json", "{}"))):
        set_option("metadata_json", "{}")


func get_metadata() -> Dictionary:
    var parsed: Variant = JSON.parse_string(str(get_option("metadata_json", "{}")))
    if parsed is Dictionary:
        return parsed.duplicate(true)
    return {}


func set_metadata_value(key: String, value: Variant) -> bool:
    var normalized_key := key.strip_edges()
    if normalized_key.is_empty() or normalized_key.length() > 64:
        return fail("Ключ метаданных должен содержать от 1 до 64 символов.")
    var value_type := typeof(value)
    if value_type != TYPE_STRING and value_type != TYPE_INT and value_type != TYPE_FLOAT and value_type != TYPE_BOOL and value_type != TYPE_NIL:
        return fail("Метаданные поддерживают только String, Integer, Float, Boolean и null.")
    var metadata := get_metadata()
    metadata[normalized_key] = value
    var serialized := JSON.stringify(metadata)
    if serialized.length() > 16384:
        return fail("Размер метаданных не должен превышать 16 КБ.")
    return set_option("metadata_json", serialized)


func remove_metadata_value(key: String) -> bool:
    var metadata := get_metadata()
    if not metadata.has(key):
        return false
    metadata.erase(key)
    return set_option("metadata_json", JSON.stringify(metadata))


func _metadata_is_valid(source: String) -> bool:
    var parsed: Variant = JSON.parse_string(source)
    return parsed is Dictionary
