@tool
extends Node
class_name ObjectComponent

var settings: Dictionary = {}


func configure(values: Dictionary) -> void:
	settings = values.duplicate(true)
	_on_configured()


func get_setting(key: String, fallback: Variant = null) -> Variant:
	return settings.get(key, fallback)


func _on_configured() -> void:
	pass
