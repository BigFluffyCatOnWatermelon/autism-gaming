@tool
extends "res://addons/web_object_builder/mechanics/object_identity/components/mechanic_component.gd"


func _on_configured() -> void:
    _load_options({"faction_id": "neutral"})


func get_faction_id() -> String:
    return str(get_option("faction_id", "neutral"))


func set_faction_id(value: String) -> bool:
    var faction := value.strip_edges()
    if faction.is_empty() or faction.length() > 64:
        return fail("ID фракции должен содержать от 1 до 64 символов.")
    return set_option("faction_id", faction)
