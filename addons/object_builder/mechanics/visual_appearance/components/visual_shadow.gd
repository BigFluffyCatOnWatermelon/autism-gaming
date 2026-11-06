@tool
extends "res://addons/object_builder/mechanics/visual_appearance/components/mechanic_component.gd"


func _on_configured() -> void:
    _load_options({"shadow_offset": Vector2(0.0, 8.0), "shadow_opacity": 0.35, "shadow_scale": Vector2(1.0, 0.55)})
    set_option("shadow_opacity", clampf(float(get_option("shadow_opacity", 0.35)), 0.0, 1.0))


func create_shadow(source: Sprite2D) -> Sprite2D:
    if not is_instance_valid(source) or source.texture == null:
        fail("Для создания тени нужен Sprite2D с текстурой.")
        return null
    var parent := source.get_parent()
    if parent == null:
        fail("У исходного спрайта нет родительского узла.")
        return null
    var shadow := Sprite2D.new()
    shadow.name = "%s_Shadow" % source.name
    shadow.texture = source.texture
    shadow.region_enabled = source.region_enabled
    shadow.region_rect = source.region_rect
    shadow.hframes = source.hframes
    shadow.vframes = source.vframes
    shadow.frame = source.frame
    shadow.centered = source.centered
    shadow.offset = source.offset
    shadow.position = source.position + get_option("shadow_offset", Vector2(0.0, 8.0))
    shadow.scale = source.scale * get_option("shadow_scale", Vector2(1.0, 0.55))
    shadow.z_index = maxi(-4096, source.z_index - 1)
    shadow.modulate = Color(0.0, 0.0, 0.0, float(get_option("shadow_opacity", 0.35)))
    parent.add_child(shadow)
    action_completed.emit(shadow)
    return shadow


func update_shadow(source: Sprite2D, shadow: Sprite2D) -> bool:
    if not is_instance_valid(source) or not is_instance_valid(shadow):
        return fail("Исходный спрайт или тень больше не существуют.")
    shadow.texture = source.texture
    shadow.position = source.position + get_option("shadow_offset", Vector2(0.0, 8.0))
    shadow.scale = source.scale * get_option("shadow_scale", Vector2(1.0, 0.55))
    shadow.z_index = maxi(-4096, source.z_index - 1)
    return true
