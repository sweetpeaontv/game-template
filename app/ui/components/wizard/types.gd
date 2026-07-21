enum HeaderSlot { PREV, TITLE, NEXT }

class HeaderButtonConfig:
	var text: String
	var disabled: bool

	func _init(new_text: String, new_disabled: bool):
		text = new_text
		disabled = new_disabled

class HeaderConfig:
	var title: String
	var prev: HeaderButtonConfig
	var next: HeaderButtonConfig

	func _init(new_title: String, new_prev: HeaderButtonConfig, new_next: HeaderButtonConfig):
		title = new_title
		prev = new_prev
		next = new_next

class Page:
	var header: HeaderConfig
	var body: Control

	func _init(new_header: HeaderConfig, new_body: Control):
		self.header = new_header
		self.body = new_body
