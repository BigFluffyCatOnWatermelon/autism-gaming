@tool
extends Resource
class_name ObjectCapabilityDefinition

## User-facing capability card. Technical components remain an implementation detail.

@export var capability_id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var category_id: String = "general"
@export var category_name: String = "Основное"
@export var icon: String = "sparkles"
@export var keywords: PackedStringArray = PackedStringArray()
@export var required_capability_ids: PackedStringArray = PackedStringArray()
@export var incompatible_capability_ids: PackedStringArray = PackedStringArray()
@export var component_ids: PackedStringArray = PackedStringArray()
@export var available_in_simple_mode: bool = true
## Internal implementation helper. It is registered but not shown as a standalone mechanic.
@export var editor_hidden: bool = false
@export var hidden_component_ids: PackedStringArray = PackedStringArray()

## Deprecated standalone capability folded into a visible parent capability.
@export var merged_into_capability_id: String = ""
## Optional component ID inside the parent that receives this capability settings.
@export var merged_component_id: String = ""
## Optional source-setting key -> parent-setting key mapping used during migration.
@export_storage var merged_setting_key_map: Dictionary = {}
## Hide the merged component settings when they duplicate parent controls.
@export var hide_merged_settings: bool = false
## Force-enable one optional merged child feature when migrating an old selected card.
@export var merged_enable_setting_key: String = ""
## Force-enable multiple target settings when a legacy capability maps to one composite component.
@export var merged_enable_setting_keys: PackedStringArray = PackedStringArray()
## Defaults applied to the parent component only when this legacy child creates the parent selection.
@export_storage var merged_parent_default_settings: Dictionary = {}

## Catalog classification is independent from the implementation and readiness.
@export_group("Catalog metadata")
@export var kind_id: String = ""
@export_enum("unclassified", "editor_only", "runtime", "hybrid", "data_only") var execution_scope: String = "unclassified"
@export var implementation_type: String = "unclassified"
@export var readiness_status: String = ""
@export var icon_resource_path: String = ""
@export_range(-1, 9999, 1) var icon_atlas_index: int = -1
@export var illustration_resource_path: String = ""
@export var synonyms: PackedStringArray = PackedStringArray()
@export var example_queries: PackedStringArray = PackedStringArray()
@export_storage var relations: Array[Dictionary] = []
@export_storage var compatibility_rules: Array[Dictionary] = []

## Legacy runtime status is kept for old modules and saved resources.
@export_enum("Implemented", "Planned") var runtime_status: String = "Implemented"
@export_multiline var implementation_note: String = ""
@export_range(0, 100000, 1) var display_order: int = 100
## Version of the capability behaviour/contract. Increment when its meaning changes.
@export_range(1, 1000, 1) var version: int = 1
## Version of the serialized definition schema. Kept separate from the capability version.
@export_range(1, 1000, 1) var definition_schema_version: int = 1

## Typed, user-facing settings exposed by this capability. Empty schemas are generated
## from the settings of its registered runtime components.
@export_storage var settings_schema: Array[Dictionary] = []


func is_ready() -> bool:
	var normalized_status := readiness_status.strip_edges().to_lower()
	if normalized_status.is_empty():
		return runtime_status == "Implemented"
	return normalized_status == "ready"


func get_effective_readiness_status() -> String:
	var normalized_status := readiness_status.strip_edges().to_lower()
	if not normalized_status.is_empty():
		return normalized_status
	return "ready" if runtime_status == "Implemented" else "planned"
