@tool
extends TabContainer
## Owns the four main constructor areas and their independent scroll containers.

var appearance_content: VBoxContainer
var capabilities_content: VBoxContainer
var settings_content: VBoxContainer
var advanced_content: VBoxContainer


func build() -> void:
	if appearance_content != null:
		return
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	appearance_content = _create_editor_page("Внешний вид", 8)
	capabilities_content = _create_editor_page("Возможности", 8)
	settings_content = _create_editor_page("Настройки", 10)
	advanced_content = _create_editor_page("Расширенный режим", 7)


func _create_editor_page(tab_title: String, separation: int) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = tab_title
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var content := VBoxContainer.new()
	content.name = tab_title.replace(" ", "") + "Content"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", separation)
	scroll.add_child(content)
	return content
