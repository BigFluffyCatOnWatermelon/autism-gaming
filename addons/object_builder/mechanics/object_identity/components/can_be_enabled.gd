@tool
extends "res://addons/object_builder/mechanics/object_identity/components/mechanic_component.gd"


func _on_configured() -> void:
    _load_options({"initially_enabled": false, "allow_enable": true})


func is_enabled() -> bool:
    return bool(get_option("initially_enabled", false))


func enable() -> bool:
    if not bool(get_option("allow_enable", true)):
        return fail("Включение этого объекта запрещено настройками.")
    set_option("initially_enabled", true)
    action_completed.emit(true)
    return true
