class_name InteractHandler
extends CommandHandler

const SCRIPT_NAME := "InteractHandler"

# VALIDATE
#===================================================================================#
func validate(message: Message) -> String:
	var payload: Payload.Interact = message.payload
	var interactable = RegistryLibrary.interactables.get_entry(payload.target_key)
	if interactable == null:
		return "interactable not found"
	if PlayerUtils.find_player(message.actor_peer_id) == null:
		return "actor not present"
	if interactable.get_interaction_type() != payload.interaction_type:
		return "interaction_type does not match interactable"
	if payload.interaction_type == InteractionTypes.InteractionType.OPERABLE:
		if not interactable is Operable:
			return "operable interact requires Operable"
	return "ok"
#===================================================================================#

# ACCEPT
#===================================================================================#
func accept_response(message: Message) -> Array[Delivery]:
	var deliveries: Array[Delivery] = [
		Delivery.new(
			Message.new(
				message.actor_peer_id,
				message.timestamp,
				Message.MessageType.CONFIRM,
				message.command,
				message.payload,
				message.request_id,
				1, # NEED TO SETUP RESPONSE ID STUFF
			),
			Delivery.Audience.ACTOR
		),
		Delivery.new(
			Message.new(
				message.actor_peer_id,
				message.timestamp,
				Message.MessageType.NOTIFY,
				message.command,
				message.payload,
				message.request_id,
				1, # NEED TO SETUP RESPONSE ID STUFF
			),
			Delivery.Audience.OTHERS,
		),
	]

	return deliveries
#===================================================================================#

# REJECT
#===================================================================================#
#func reject_response(message: Message) -> Array[Delivery]:
#	return [
#
#	]
#===================================================================================#

# APPLY
#===================================================================================#
func apply(message: Message) -> void:
	var payload: Payload.Interact = message.payload
	var interactable = RegistryLibrary.interactables.get_entry(payload.target_key)
	if interactable == null:
		SweetLogger.error("interactable not found: {0}", [payload.target_key], SCRIPT_NAME, "apply")
		return

	var interactor = PlayerUtils.find_player(message.actor_peer_id)
	if interactor == null:
		SweetLogger.error("interactor not found: {0}", [message.actor_peer_id], SCRIPT_NAME, "apply")
		return

	match payload.interaction_type:
		InteractionTypes.InteractionType.OPERABLE:
			_apply_operable(interactable, interactor, payload)
		InteractionTypes.InteractionType.EXAMINABLE:
			_apply_examinable(interactable, interactor, payload)
		_:
			SweetLogger.error("unsupported interaction type: {0}", [payload.interaction_type], SCRIPT_NAME, "apply")

func _apply_operable(interactable: Interactable, interactor: Node3D, payload: Payload.Interact) -> void:
	if not (interactable is Operable or interactable is OperableRollback):
		SweetLogger.error("expected Operable, got {0}", [interactable.get_class()], SCRIPT_NAME, "_apply_operable")
		return

	var operable_data := InteractionTypes.OperableData.new(
		payload.get_operable_action(),
		payload.get_target_state(),
	)
	
	(interactable as Operable).interact(interactor, operable_data)

func _apply_examinable(interactable: Interactable, interactor: Node3D, payload: Payload.Interact) -> void:
	if not (interactable is Examinable or interactable is ExaminableRollback):
		SweetLogger.error("expected Examinable", [], SCRIPT_NAME, "_apply_examinable")
		return

	var examinable_data: InteractionTypes.ExaminableData
	match payload.get_examinable_action():
		InteractionTypes.ExaminableData.Action.EXAMINE:
			examinable_data = InteractionTypes.ExaminableData.examine()
		InteractionTypes.ExaminableData.Action.DISENGAGE:
			examinable_data = InteractionTypes.ExaminableData.disengage()
		_:
			SweetLogger.error("invalid examinable action: {0}", [payload.action], SCRIPT_NAME, "_apply_examinable")
			return

	(interactable as Examinable).interact(interactor, examinable_data)
#===================================================================================#
