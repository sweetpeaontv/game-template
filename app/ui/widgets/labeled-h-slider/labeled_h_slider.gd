extends VBoxContainer

var label: Label
var slider: HSlider

func setup(display_name: String, node_name: String, min_value: float, max_value: float, step: float, value: float, value_changed_callback: Callable) -> void:
	_resolve_children()
	set_label_text(display_name)
	configure_slider(node_name, min_value, max_value, step, value, value_changed_callback)

func _resolve_children() -> void:
	if label == null:
		label = get_node(^"Label") as Label
	if slider == null:
		slider = get_node(^"HSlider") as HSlider

func set_label_text(text: String) -> void:
	label.text = text

func configure_slider(node_name: String, min_value: float, max_value: float, step: float, value: float, value_changed_callback: Callable) -> void:
	slider.name = node_name
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(value_changed_callback)
