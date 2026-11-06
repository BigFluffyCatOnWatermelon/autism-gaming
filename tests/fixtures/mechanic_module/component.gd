@tool
extends ObjectComponent

var enabled: bool = false


func _on_configured() -> void:
	enabled = bool(settings.get("enabled", false))


func is_module_component_ready() -> bool:
	return enabled
