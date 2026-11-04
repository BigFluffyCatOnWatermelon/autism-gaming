extends Node3D
class_name Bonfire
@export var checkpoint_id := "ashen_outskirts_rest"
@export var checkpoint_title := "The Ashen Outskirts"
@export var spawn_offset := Vector3(1.8, 0.0, 0.0)
@onready var flame: MeshInstance3D = $Flame
@onready var fire_light: OmniLight3D = $FireLight
var elapsed := 0.0
var ember_timer := 0.0
var ember_rng := RandomNumberGenerator.new()
var ember_material: StandardMaterial3D

func _ready() -> void:
	add_to_group("interactables")
	ember_rng.randomize()
	ember_material = StandardMaterial3D.new()
	ember_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ember_material.albedo_color = Color(1.0, 0.31, 0.045)
	ember_material.emission_enabled = true
	ember_material.emission = Color(1.0, 0.12, 0.01)
	ember_material.emission_energy_multiplier = 3.0
	_update_visual_state()

func _process(delta: float) -> void:
	elapsed += delta
	ember_timer -= delta
	if ember_timer <= 0.0:
		_emit_ember()
		ember_timer = ember_rng.randf_range(0.07, 0.16)
	fire_light.light_energy = 2.1 + 0.22 * sin(elapsed * 9.0) + 0.1 * sin(elapsed * 17.0)
	flame.scale = Vector3(0.85, 1.0 + 0.12 * sin(elapsed * 11.0), 0.85)

func _emit_ember() -> void:
	var ember := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = ember_rng.randf_range(0.018, 0.04)
	mesh.height = mesh.radius * 2.0
	mesh.radial_segments = 6
	mesh.rings = 4
	ember.mesh = mesh
	ember.material_override = ember_material
	ember.position = Vector3(ember_rng.randf_range(-0.26, 0.26), ember_rng.randf_range(0.5, 0.9), ember_rng.randf_range(-0.18, 0.18))
	add_child(ember)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(ember, "position", ember.position + Vector3(ember_rng.randf_range(-0.5, 0.5), ember_rng.randf_range(0.8, 1.8), ember_rng.randf_range(-0.5, 0.5)), ember_rng.randf_range(0.65, 1.15)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ember, "scale", Vector3.ZERO, 0.9)
	tween.chain().tween_callback(ember.queue_free)

func get_interaction_text(_player: Node3D) -> String:
	return "[E]  REST AT THE BONFIRE"

func interact(player: PlayerController) -> void:
	RunState.activate_checkpoint(checkpoint_id, checkpoint_title, global_position + spawn_offset)
	player.rest_at_checkpoint()
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("show_level_up_menu"):
		hud.show_level_up_menu(player)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and enemy.has_method("reset_enemy"):
			enemy.reset_enemy()
	RunState.save_game()
	_update_visual_state()
	player.status_message.emit("CHECKPOINT KINDLED  •  WORLD RESTORED")

func _update_visual_state() -> void:
	if has_node("Ember"):
		(get_node("Ember") as MeshInstance3D).visible = RunState.checkpoint_id == checkpoint_id
