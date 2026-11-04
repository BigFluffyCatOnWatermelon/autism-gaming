extends Node
class_name HealthComponent

signal health_changed(current: float, maximum: float)
signal depleted

@export var maximum_health: float = 100.0
var current_health: float

func _ready() -> void:
	current_health = maximum_health
	health_changed.emit(current_health, maximum_health)

func apply_damage(amount: float) -> void:
	if current_health <= 0.0:
		return
	current_health = maxf(0.0, current_health - maxf(0.0, amount))
	health_changed.emit(current_health, maximum_health)
	if current_health <= 0.0:
		depleted.emit()

func restore(amount: float) -> void:
	current_health = minf(maximum_health, current_health + maxf(0.0, amount))
	health_changed.emit(current_health, maximum_health)
