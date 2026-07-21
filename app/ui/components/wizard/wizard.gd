extends Control

signal wizard_finished
signal wizard_cancelled
signal page_changed(page_index: int)

const Types := preload("res://app/ui/components/wizard/types.gd")

var pages: Array[Types.Page]
var index: int = 0
var _last_shown_page_index: int = -1

@onready var header: Control = $VBoxContainer/Header
@onready var margin_body: Control = $VBoxContainer/MarginBody
@onready var body: Control = $VBoxContainer/MarginBody/Body

# INIT
#===================================================================================#
func _ready() -> void:
	header.prev_button.pressed.connect(_on_prev_button_pressed)
	header.next_button.pressed.connect(_on_next_button_pressed)
#===================================================================================#

# API
#===================================================================================#
func configure_pages(new_pages: Array[Types.Page]) -> void:
	pages = new_pages

	for page in pages:
		page.body.visible = false
		body.add_child(page.body)

	_update_page()

func set_body_margin(margin: int) -> void:
	margin_body.add_theme_constant_override("margin_left", margin)
	margin_body.add_theme_constant_override("margin_right", margin)
	margin_body.add_theme_constant_override("margin_top", margin)
	margin_body.add_theme_constant_override("margin_bottom", margin)

func set_body_margin_x(padding: int) -> void:
	margin_body.add_theme_constant_override("margin_left", padding)
	margin_body.add_theme_constant_override("margin_right", padding)

func set_body_margin_y(padding: int) -> void:
	margin_body.add_theme_constant_override("margin_top", padding)
	margin_body.add_theme_constant_override("margin_bottom", padding)
#===================================================================================#

# SIGNAL HANDLERS
#===================================================================================#
func _on_prev_button_pressed() -> void:
	if index <= 0:
		wizard_cancelled.emit()
		return
	_last_shown_page_index = index
	index -= 1
	_update_page()

func _on_next_button_pressed() -> void:
	if index + 1 >= pages.size():
		wizard_finished.emit()
		return
	_last_shown_page_index = index
	index += 1
	_update_page()

func _hide_previous_page() -> void:
	if _last_shown_page_index >= 0 && _last_shown_page_index < pages.size():
		pages[_last_shown_page_index].body.visible = false

func _show_page(page_index: int) -> void:
	if page_index >= 0 && page_index < pages.size():
		pages[page_index].body.visible = true

func _update_page() -> void:
	header.apply_config(pages[index].header)
	_hide_previous_page()
	_show_page(index)
	page_changed.emit(index)
#===================================================================================#
