@tool
extends "res://addons/web_object_builder/mechanics/object_identity/components/mechanic_component.gd"


func _on_configured() -> void:
    _load_options({"identity_id": ""})
    ensure_identity()


func ensure_identity() -> String:
    var identity := str(get_option("identity_id", "")).strip_edges()
    if identity.is_empty():
        identity = ResourceUID.id_to_text(ResourceUID.create_id())
        set_option("identity_id", identity)
    return identity


func set_identity(value: String) -> bool:
    var normalized := value.strip_edges()
    if normalized.is_empty():
        return fail("Идентификатор не может быть пустым.")
    return set_option("identity_id", normalized)
