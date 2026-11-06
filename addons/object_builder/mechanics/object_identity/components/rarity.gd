@tool
extends "res://addons/object_builder/mechanics/object_identity/components/mechanic_component.gd"

const VALID_RARITIES := ["common", "uncommon", "rare", "epic", "legendary", "mythic", "custom"]


func _on_configured() -> void:
    _load_options({"rarity": "common"})


func get_rarity() -> String:
    return str(get_option("rarity", "common"))


func set_rarity(value: String) -> bool:
    var rarity := value.strip_edges().to_lower()
    if not VALID_RARITIES.has(rarity):
        return fail("Неизвестная редкость: %s" % rarity)
    return set_option("rarity", rarity)
