@tool
extends "res://addons/object_builder/mechanics/object_identity/components/mechanic_component.gd"


func _on_configured() -> void:
    _load_options({"tags_csv": ""})


func get_tags() -> PackedStringArray:
    var result := PackedStringArray()
    for raw_tag in str(get_option("tags_csv", "")).split(","):
        var tag := raw_tag.strip_edges()
        if not tag.is_empty() and not result.has(tag):
            result.append(tag)
    return result


func add_tag(value: String) -> bool:
    var tag := value.strip_edges()
    if tag.is_empty() or tag.length() > 48:
        return fail("Метка должна содержать от 1 до 48 символов.")
    var tags := get_tags()
    if tags.has(tag):
        return true
    if tags.size() >= 64:
        return fail("Нельзя добавить больше 64 меток.")
    tags.append(tag)
    return set_option("tags_csv", ",".join(tags))


func remove_tag(value: String) -> bool:
    var tags := get_tags()
    var index := tags.find(value.strip_edges())
    if index < 0:
        return false
    tags.remove_at(index)
    return set_option("tags_csv", ",".join(tags))
