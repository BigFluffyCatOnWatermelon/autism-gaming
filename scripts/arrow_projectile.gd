extends Node2D
class_name ArrowProjectile

const ARROW_SCALE := 0.6

var embedded := false

func _ready() -> void:
	scale = Vector2.ONE * ARROW_SCALE
	var arrow_sprite := Sprite2D.new()
	arrow_sprite.name = "ArrowSprite"
	arrow_sprite.texture = load("res://public/assets/projectiles/arrows/arrow.svg") as Texture2D
	arrow_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(arrow_sprite)

func embed() -> void:
	embedded = true
	modulate = Color("#c6b995")
