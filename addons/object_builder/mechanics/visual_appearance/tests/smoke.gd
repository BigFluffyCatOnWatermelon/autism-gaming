extends SceneTree

const SPRITE = preload("res://addons/object_builder/mechanics/visual_appearance/component.gd")
const TINT = preload("res://addons/object_builder/mechanics/visual_appearance/components/tint.gd")
const OPACITY = preload("res://addons/object_builder/mechanics/visual_appearance/components/opacity.gd")
const FLIP = preload("res://addons/object_builder/mechanics/visual_appearance/components/flip.gd")
const LAYER = preload("res://addons/object_builder/mechanics/visual_appearance/components/layer_order.gd")
const SHADOW = preload("res://addons/object_builder/mechanics/visual_appearance/components/visual_shadow.gd")
const OUTLINE = preload("res://addons/object_builder/mechanics/visual_appearance/components/outline.gd")
const PALETTE = preload("res://addons/object_builder/mechanics/visual_appearance/components/palette_swap.gd")
const DIRECTIONAL = preload("res://addons/object_builder/mechanics/visual_appearance/components/directional_sprites.gd")
const PARTS = preload("res://addons/object_builder/mechanics/visual_appearance/components/visual_parts.gd")


func _initialize() -> void:
    var errors: Array[String] = []
    var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
    image.fill(Color.WHITE)
    var texture := ImageTexture.create_from_image(image)
    var root := Node2D.new()
    var sprite := Sprite2D.new()
    sprite.texture = texture
    root.add_child(sprite)

    var tint = TINT.new()
    tint._on_configured()
    if not tint.apply_to(sprite, "#ff0000") or sprite.modulate.r < 0.99 or sprite.modulate.g > 0.01:
        errors.append("Tint did not change the Sprite2D modulate color.")
    if tint.apply_to(sprite, "#not-a-color"):
        errors.append("Tint accepted an invalid color string.")

    var opacity = OPACITY.new()
    opacity._on_configured()
    if not opacity.apply_to(sprite, 0.4) or absf(sprite.modulate.a - 0.4) > 0.01:
        errors.append("Opacity did not update alpha.")
    if opacity.apply_to(sprite, 1.5):
        errors.append("Opacity accepted an out-of-range value.")

    var flip = FLIP.new()
    flip._on_configured()
    if not flip.apply_to(sprite, true, false) or not sprite.flip_h or sprite.flip_v:
        errors.append("Sprite flip was not applied.")

    var layer = LAYER.new()
    layer._on_configured()
    if not layer.apply_to(sprite, 12) or sprite.z_index != 12:
        errors.append("CanvasItem z-index was not applied.")

    var shadow_component = SHADOW.new()
    shadow_component._on_configured()
    var shadow: Sprite2D = shadow_component.create_shadow(sprite)
    if shadow == null or shadow.texture != sprite.texture or shadow.z_index >= sprite.z_index:
        errors.append("Shadow creation failed or produced the wrong draw order.")

    var outline = OUTLINE.new()
    outline._on_configured()
    if not outline.apply_to(sprite) or not (sprite.material is ShaderMaterial):
        errors.append("Outline ShaderMaterial was not installed.")
    outline.remove_from(sprite)

    var palette = PALETTE.new()
    palette._on_configured()
    palette.configure_mechanic({"palette_json": "{\"#ffffff\":\"#00ff00\"}"})
    if not palette.apply_to(sprite):
        errors.append("Palette replacement failed on a valid texture.")
    else:
        var changed_image := sprite.texture.get_image()
        if changed_image.get_pixel(0, 0).g < 0.99:
            errors.append("Palette replacement did not change pixel color.")

    var sprite_component = SPRITE.new()
    sprite_component._on_configured()
    if sprite_component.apply_to(sprite, "res://this/path/does/not/exist.png"):
        errors.append("Sprite loader accepted a missing texture path.")

    var parts = PARTS.new()
    parts._on_configured()
    parts.configure_mechanic({"part_paths": "ChildPart", "parts_visible": false})
    var child_part := Sprite2D.new()
    child_part.name = "ChildPart"
    root.add_child(child_part)
    if not parts.apply_to(root) or child_part.visible:
        errors.append("Visual parts visibility/NodePath handling failed.")

    var directional = DIRECTIONAL.new()
    directional._on_configured()
    if directional.set_direction(sprite, "unknown"):
        errors.append("Directional sprite accepted an undefined direction.")

    root.free()
    if errors.is_empty():
        print("MODULE_TESTS: PASS")
        quit(0)
    else:
        for error in errors:
            push_error(error)
        print("MODULE_TESTS: FAIL")
        quit(1)
