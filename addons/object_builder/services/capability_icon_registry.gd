@tool
extends RefCounted
class_name CapabilityIconRegistry
## Resolves a capability's own icon resource or its permanent cell in the shared atlas.

const ICON_ATLAS_PATH := "res://addons/object_builder/assets/capabilities/capability_icon_atlas.svg"
const ICON_CELL_SIZE := 40
const ICON_COLUMNS := 10
const ICON_COUNT := 200

static var _atlas: Texture2D
static var _icon_cache: Dictionary = {}


static func get_icon(definition: ObjectCapabilityDefinition) -> Texture2D:
	if definition == null:
		return null
	var capability_id := definition.capability_id.strip_edges().to_lower()
	if _icon_cache.has(capability_id):
		return _icon_cache[capability_id] as Texture2D

	var custom_path := definition.icon_resource_path.strip_edges()
	if not custom_path.is_empty() and ResourceLoader.exists(custom_path):
		var custom_icon := load(custom_path) as Texture2D
		if custom_icon != null:
			_icon_cache[capability_id] = custom_icon
			return custom_icon

	var atlas_index := definition.icon_atlas_index
	if atlas_index < 0 or atlas_index >= ICON_COUNT:
		return null
	if _atlas == null:
		_atlas = load(ICON_ATLAS_PATH) as Texture2D
	if _atlas == null:
		push_warning("Object Builder: не удалось загрузить атлас значков возможностей: " + ICON_ATLAS_PATH)
		return null

	var atlas_texture := AtlasTexture.new()
	atlas_texture.atlas = _atlas
	var column := atlas_index % ICON_COLUMNS
	var row := int(floor(float(atlas_index) / float(ICON_COLUMNS)))
	atlas_texture.region = Rect2(
		column * ICON_CELL_SIZE,
		row * ICON_CELL_SIZE,
		ICON_CELL_SIZE,
		ICON_CELL_SIZE
	)
	_icon_cache[capability_id] = atlas_texture
	return atlas_texture


static func clear_cache() -> void:
	_icon_cache.clear()
	_atlas = null
