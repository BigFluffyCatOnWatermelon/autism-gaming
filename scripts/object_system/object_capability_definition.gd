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

## Catalog classification is independent from the implementation and readiness.
@export_group("Catalog metadata")
@export var kind_id: String = ""
@export_enum("unclassified", "editor_only", "runtime", "hybrid", "data_only") var execution_scope: String = "unclassified"
@export var implementation_type: String = "unclassified"
@export var readiness_status: String = ""
@export var icon_resource_path: String = ""
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
