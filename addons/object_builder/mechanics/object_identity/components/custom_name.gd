@tool
extends "res://addons/object_builder/mechanics/object_identity/components/mechanic_component.gd"


func _on_configured() -> void:
    _load_options({"custom_name": ""})


func get_custom_name() -> String:
    return str(get_option("custom_name", ""))


func set_custom_name(value: String) -> bool:
    var normalized := value.strip_edges()
    if normalized.length() > 128:
        return fail("Имя не должно превышать 128 символов.")
    return set_option("custom_name", normalized)
