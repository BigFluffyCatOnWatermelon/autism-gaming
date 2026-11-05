@tool
extends Resource
class_name ObjectCapabilitySelection

## User choice stored in an ObjectDefinition. Settings are keyed by component ID internally.

@export var capability_id: String = ""
@export var enabled: bool = true
@export var target_node_path: NodePath = NodePath(".")
@export_storage var settings_by_component: Dictionary = {}


func get_component_settings(component_id: String) -> Dictionary:
	var values: Variant = settings_by_component.get(component_id, {})
	if values is Dictionary:
		return values.duplicate(true)
	return {}


func set_component_setting(component_id: String, setting_key: String, value: Variant) -> void:
	var values := get_component_settings(component_id)
	values[setting_key] = value
	settings_by_component[component_id] = values
