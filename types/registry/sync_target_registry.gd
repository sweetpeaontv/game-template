class_name SyncTargetRegistry
extends Registry

func collect_sync_target_snapshot() -> Array:
	var updates: Array = []
	for key in get_all_entries():
		var node := get_entry(key) as SyncStateNode
		if node == null:
			continue
		if not node.differs_from_initial():
			continue
		updates.append(Payload.SyncState.make_update(key, node.get_wire_state()))
	return updates

func collect_dirty_sync_targets() -> Array:
	var updates: Array = []
	for key in get_all_entries():
		var node := get_entry(key) as SyncStateNode
		if node == null:
			continue
		if not node.is_dirty:
			continue
		updates.append(Payload.SyncState.make_update(key, node.get_wire_state()))
	return updates
