extends HBoxContainer

const Types := preload("res://app/ui/components/wizard/types.gd")

@onready var prev_button: Button = $Prev
@onready var title_label: Label = $Title
@onready var next_button: Button = $Next

func apply_config(config: Types.HeaderConfig):
	set_text(Types.HeaderSlot.TITLE, config.title)
	apply_button_config(Types.HeaderSlot.PREV, config.prev)
	apply_button_config(Types.HeaderSlot.NEXT, config.next)

func apply_button_config(slot: Types.HeaderSlot,config: Types.HeaderButtonConfig):
	set_text(slot, config.text)
	set_disabled(slot, config.disabled)

func get_via_slot(slot):
	match slot:
		Types.HeaderSlot.PREV:
			return prev_button
		Types.HeaderSlot.TITLE:
			return title_label
		Types.HeaderSlot.NEXT:
			return next_button
		_:
			SweetLogger.error("WizardHeader.get_slot: slot is not valid", [slot], "WizardHeader.gd", "get_slot")
			return

func set_text(slot: Types.HeaderSlot, text: String):
	get_via_slot(slot).text = text

func set_disabled(slot: Types.HeaderSlot, disabled: bool):
	var node = get_via_slot(slot)
	if not node is Button:
		SweetLogger.error("WizardHeader.disable_slot: node is not a Button", [slot], "WizardHeader.gd", "disable_slot")
		return
	
	if node.disabled == disabled:
		return
	
	node.disabled = disabled
