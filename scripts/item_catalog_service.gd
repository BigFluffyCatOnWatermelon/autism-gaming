extends RefCounted
class_name ItemCatalogService

const CATALOG_PATHS := {
	"tools": "res://data/items/tools.tres",
	"weapons": "res://data/items/weapons.tres",
	"food": "res://data/items/food.tres",
	"materials": "res://data/items/materials.tres",
	"ammunition": "res://data/items/ammunition.tres",
}


static func load_all() -> Dictionary:
	var catalogs: Dictionary = {}
	var definitions: Dictionary = {}
	var items: Dictionary = {}
	var weapons: Dictionary = {}
	var categories: Dictionary = {}
	var catalog_by_id: Dictionary = {}

	for category_value in CATALOG_PATHS:
		var category := str(category_value)
		var catalog_path := str(CATALOG_PATHS[category])
		var catalog := load(catalog_path) as ItemCatalog
		if catalog == null:
			push_error("Не удалось загрузить каталог предметов: " + catalog_path)
			continue
		catalogs[category] = catalog
		for definition in catalog.items:
			if definition == null or definition.item_id.is_empty():
				continue
			definition.category = category
			if category in ["tools", "weapons"]:
				definition.stack_limit = 1
			else:
				definition.stack_limit = maxi(1, definition.stack_limit)
			var item_id := definition.item_id
			definitions[item_id] = definition
			categories[item_id] = category
			catalog_by_id[item_id] = catalog

			var item_data: Dictionary = {
				"label": definition.display_name,
				"description": definition.description,
				"category": category,
				"max_stack": maxi(1, definition.stack_limit),
				"icon": definition.icon,
			}
			for property_key in definition.properties:
				item_data[property_key] = definition.properties[property_key]
			items[item_id] = item_data
			if not definition.combat_stats.is_empty():
				weapons[item_id] = definition.combat_stats.duplicate(true)

	return {
		"catalogs": catalogs,
		"definitions": definitions,
		"catalog_by_id": catalog_by_id,
		"items": items,
		"weapons": weapons,
		"categories": categories,
	}


static func rebuild_item_data(definition: ItemDefinition) -> Dictionary:
	var item_data: Dictionary = {
		"label": definition.display_name,
		"description": definition.description,
		"category": definition.category,
		"max_stack": maxi(1, definition.stack_limit),
		"icon": definition.icon,
	}
	for property_key in definition.properties:
		item_data[property_key] = definition.properties[property_key]
	return item_data
