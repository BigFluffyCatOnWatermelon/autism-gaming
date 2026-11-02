extends Node2D
class_name ArrowProjectile

var embedded := false

func _ready() -> void:
	var arrow_sprite := Sprite2D.new()
	arrow_sprite.name = "ArrowSprite"
	arrow_sprite.texture = load("res://public/assets/projectiles/arrows/arrow.svg") as Texture2D
	arrow_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(arrow_sprite)

func embed() -> void:
	embedded = true
	scale = Vector2(0.9, 0.9)
	modulate = Color("#c6b995")
