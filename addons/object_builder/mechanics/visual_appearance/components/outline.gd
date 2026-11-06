@tool
extends "res://addons/object_builder/mechanics/visual_appearance/components/mechanic_component.gd"

var _previous_material: Material
var _outline_material: ShaderMaterial


func _on_configured() -> void:
    _load_options({"outline_color": "#ffffff", "outline_width": 1.0})
    set_option("outline_width", clampf(float(get_option("outline_width", 1.0)), 1.0, 4.0))


func apply_to(sprite: Sprite2D) -> bool:
    if not is_instance_valid(sprite) or sprite.texture == null:
        return fail("Для обводки нужен Sprite2D с текстурой.")
    var raw_color := str(get_option("outline_color", "#ffffff"))
    if not raw_color.is_valid_html_color():
        return fail("Неверный цвет обводки.")
    if _outline_material == null:
        var shader := Shader.new()
        shader.code = """
            shader_type canvas_item;
            uniform vec4 outline_color : source_color = vec4(1.0);
            uniform float outline_width = 1.0;
            void fragment() {
                vec4 base = texture(TEXTURE, UV);
                vec2 px = TEXTURE_PIXEL_SIZE * outline_width;
                float around = 0.0;
                around = max(around, texture(TEXTURE, UV + vec2(px.x, 0.0)).a);
                around = max(around, texture(TEXTURE, UV - vec2(px.x, 0.0)).a);
                around = max(around, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
                around = max(around, texture(TEXTURE, UV - vec2(0.0, px.y)).a);
                around = max(around, texture(TEXTURE, UV + px).a);
                around = max(around, texture(TEXTURE, UV - px).a);
                around = max(around, texture(TEXTURE, UV + vec2(px.x, -px.y)).a);
                around = max(around, texture(TEXTURE, UV + vec2(-px.x, px.y)).a);
                COLOR = base.a < 0.01 && around > 0.01 ? outline_color * COLOR : base * COLOR;
            }
        """
        _outline_material = ShaderMaterial.new()
        _outline_material.shader = shader
        _previous_material = sprite.material
    _outline_material.set_shader_parameter("outline_color", Color.from_string(raw_color, Color.WHITE))
    _outline_material.set_shader_parameter("outline_width", float(get_option("outline_width", 1.0)))
    sprite.material = _outline_material
    action_completed.emit(sprite)
    return true


func remove_from(sprite: Sprite2D) -> bool:
    if not is_instance_valid(sprite):
        return fail("Не передан действительный Sprite2D.")
    if sprite.material == _outline_material:
        sprite.material = _previous_material
    return true
