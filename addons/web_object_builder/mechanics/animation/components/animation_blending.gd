@tool
extends "res://addons/web_object_builder/mechanics/animation/components/animation_action_component.gd"


func _on_configured() -> void:
    _load_options({"blend_seconds": 0.15})


func _validate_option(key: String, value: Variant) -> bool:
    if key == "blend_seconds":
        return float(value) >= 0.0 and float(value) <= 10.0
    return true


func play_blended(animation_name: String) -> bool:
    return _play_animation(animation_name, float(get_option("blend_seconds", 0.15)))
