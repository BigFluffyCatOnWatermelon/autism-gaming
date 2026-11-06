@tool
extends TabContainer
## Owns editor tabs and scroll containers; the plugin fills the exposed content roots.

var simple_content: VBoxContainer
var advanced_content: VBoxContainer


func build() -> void:
	if simple_content != null and advanced_content != null:
		return
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_create_editor_page("Простой режим", 10, true)
	_create_editor_page("Расширенный режим", 7, false)


func _create_editor_page(tab_title: String, separation: int, is_simple: bool) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = tab_title
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", separation)
	scroll.add_child(content)
	if is_simple:
		simple_content = content
	else:
		advanced_content = content
