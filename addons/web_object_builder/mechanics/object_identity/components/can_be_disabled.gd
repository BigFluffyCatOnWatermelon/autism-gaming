@tool
extends "res://addons/web_object_builder/mechanics/object_identity/components/mechanic_component.gd"


func _on_configured() -> void:
    _load_options({"initially_enabled": true, "allow_disable": true})


func is_enabled() -> bool:
    return get_shared_enabled_state(bool(get_option("initially_enabled", true)))


func disable() -> bool:
    if not bool(get_option("allow_disable", true)):
        return fail("Отключение этого объекта запрещено настройками.")
    set_shared_enabled_state(false)
    set_option("initially_enabled", false)
    action_completed.emit(false)
    return true
