@tool
extends "res://addons/object_builder/mechanics/interaction/component.gd"

signal prompt_visibility_changed(visible: bool, text: String)


func _on_configured() -> void:
    _load_options({"prompt_text": "Взаимодействовать", "prompt_range": 96.0, "enabled": true})


func _validate_option(key: String, value: Variant) -> bool:
    if key == "prompt_range":
        return float(value) >= 0.0 and float(value) <= 100000.0
    return true


func get_prompt(interactor: Node2D) -> String:
    if not _is_enabled() or not _require_target():
        return ""
    if interactor == null or not is_instance_valid(interactor):
        return ""
    if _target.global_position.distance_to(interactor.global_position) > float(get_option("prompt_range", 96.0)):
        return ""
    return str(get_option("prompt_text", "Взаимодействовать"))


func update_prompt_visibility(interactor: Node2D) -> bool:
    var prompt := get_prompt(interactor)
    var is_visible := not prompt.is_empty()
    prompt_visibility_changed.emit(is_visible, prompt)
    action_completed.emit({"visible": is_visible, "text": prompt})
    return true
