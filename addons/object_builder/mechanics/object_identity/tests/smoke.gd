extends SceneTree

const IDENTITY = preload("res://addons/object_builder/mechanics/object_identity/component.gd")
const ENABLE = preload("res://addons/object_builder/mechanics/object_identity/components/can_be_enabled.gd")
const DISABLE = preload("res://addons/object_builder/mechanics/object_identity/components/can_be_disabled.gd")
const TAGS = preload("res://addons/object_builder/mechanics/object_identity/components/tags.gd")
const LEVEL = preload("res://addons/object_builder/mechanics/object_identity/components/level.gd")
const XP = preload("res://addons/object_builder/mechanics/object_identity/components/experience.gd")
const METADATA = preload("res://addons/object_builder/mechanics/object_identity/components/metadata.gd")
const NAME_COMPONENT = preload("res://addons/object_builder/mechanics/object_identity/components/custom_name.gd")
const RARITY = preload("res://addons/object_builder/mechanics/object_identity/components/rarity.gd")
const FACTION = preload("res://addons/object_builder/mechanics/object_identity/components/faction.gd")


func _initialize() -> void:
    var errors: Array[String] = []

    var identity = IDENTITY.new()
    identity._on_configured()
    var first_id: String = identity.ensure_identity()
    if first_id.is_empty() or identity.ensure_identity() != first_id:
        errors.append("UID must be created once and remain stable for this component instance.")
    if not identity.set_identity("test-object-01") or identity.ensure_identity() != "test-object-01":
        errors.append("Explicit identity assignment failed.")

    var enable = ENABLE.new()
    enable._on_configured()
    if not enable.enable() or not enable.is_enabled():
        errors.append("Allowed enable operation failed.")
    enable.configure_mechanic({"allow_enable": false})
    if enable.enable():
        errors.append("Enable operation ignored its restriction.")

    var disable = DISABLE.new()
    disable._on_configured()
    if not disable.disable() or disable.is_enabled():
        errors.append("Allowed disable operation failed.")
    disable.configure_mechanic({"allow_disable": false})
    if disable.disable():
        errors.append("Disable operation ignored its restriction.")

    var tags = TAGS.new()
    tags._on_configured()
    if not tags.add_tag("resource") or not tags.add_tag("wood") or tags.get_tags().size() != 2:
        errors.append("Tag insertion failed.")
    if not tags.add_tag("resource") or tags.get_tags().size() != 2:
        errors.append("Duplicate tags were not ignored.")
    if not tags.remove_tag("wood") or tags.get_tags().size() != 1:
        errors.append("Tag removal failed.")

    var level = LEVEL.new()
    level._on_configured()
    if not level.set_level(25) or level.get_level() != 25 or level.set_level(0):
        errors.append("Level range validation failed.")

    var xp = XP.new()
    xp._on_configured()
    if not xp.add_experience(20) or xp.get_experience() != 20 or xp.spend_experience(21):
        errors.append("Experience accounting or boundary validation failed.")

    var metadata = METADATA.new()
    metadata._on_configured()
    if not metadata.set_metadata_value("quality", 3) or metadata.get_metadata().get("quality") != 3:
        errors.append("Metadata write/read failed.")
    if metadata.set_metadata_value("unsupported", Vector2.ONE):
        errors.append("Metadata accepted a non-JSON value.")

    var custom_name = NAME_COMPONENT.new()
    custom_name._on_configured()
    if not custom_name.set_custom_name("Oak Tree") or custom_name.get_custom_name() != "Oak Tree":
        errors.append("Custom name update failed.")
    if custom_name.set_custom_name("x".repeat(129)):
        errors.append("Custom name length limit was ignored.")

    var faction = FACTION.new()
    faction._on_configured()
    if not faction.set_faction_id("forest_guardians") or faction.get_faction_id() != "forest_guardians":
        errors.append("Faction ID update failed.")
    if faction.set_faction_id(""):
        errors.append("Faction accepted an empty ID.")

    var rarity = RARITY.new()
    rarity._on_configured()
    if not rarity.set_rarity("epic") or rarity.set_rarity("ultra-unknown"):
        errors.append("Rarity validation failed.")

    if errors.is_empty():
        print("MODULE_TESTS: PASS")
        quit(0)
    else:
        for error in errors:
            push_error(error)
        print("MODULE_TESTS: FAIL")
        quit(1)
