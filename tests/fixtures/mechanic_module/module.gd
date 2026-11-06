extends RefCounted

const MODULE_COMPONENT_SCRIPT = preload("res://tests/fixtures/mechanic_module/component.gd")


func build_component_definitions() -> Array:
	var component := ObjectComponentDefinition.new()
	component.component_id = "module_smoke_component"
	component.display_name = "Module Smoke Component"
	component.description = "Проверочный компонент для теста модульной регистрации."
	component.category = "Interaction"
	component.category_id = "Interaction"
	component.category_display_name = "Взаимодействие"
	component.component_version = 1
	component.component_script = MODULE_COMPONENT_SCRIPT
	component.setting_definitions = [
		{
			"key": "enabled",
			"display_name": "Включён",
			"value_type": "Boolean",
			"default_value": true,
			"group_name": "Проверка"
		}
	]
	component.settings = {"enabled": true}
	return [component]


func build_capability_definitions() -> Array:
	var capability := ObjectCapabilityDefinition.new()
	capability.capability_id = "module_smoke_feature"
	capability.display_name = "Проверка модульной механики"
	capability.description = "Тестирует подключение автономного пакета через MechanicModuleLoader."
	capability.category_id = "interaction"
	capability.category_name = "Взаимодействие"
	capability.icon = "puzzle"
	capability.keywords = PackedStringArray(["module", "smoke", "модуль"])
	capability.component_ids = PackedStringArray(["module_smoke_component"])
	capability.available_in_simple_mode = true
	capability.runtime_status = "Implemented"
	capability.implementation_note = "Тестовая механика; не является игровой возможностью."
	capability.display_order = 9999
	capability.version = 1
	capability.definition_schema_version = 1
	return [capability]
