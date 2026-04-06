extends Node

# NEEDS CLARIFICATION
# WHY NOT DEFINE RPCS HERE?

## Autoload singleton (see [code]project.godot[/code]; : helpers for running mutations **only on the server** (or offline), otherwise
## the caller issues an [@RPC] to the server peer.
##
## Does **not** define [@RPC] methods — those stay on the [Node] that owns state (stable path in the
## scene tree). Use [method run_mutation_on_authority] to branch; call your RPC when it returns false.


## Default peer id for the host in Godot's high-level multiplayer API (ENet, etc.).
const DEFAULT_SERVER_PEER_ID: int = 1


func _get_multiplayer() -> MultiplayerAPI:
	# Godot 4: [SceneTree] has no [code]multiplayer[/code] property; [MultiplayerAPI] comes from [Node.multiplayer].
	# This autoload is a [Node] under [code]/root[/code], so use the inherited property (same as [code]gnet.gd[/code]).
	return multiplayer


## No active multiplayer peer (single-player / main menu).
func is_offline() -> bool:
	var mp := _get_multiplayer()
	return mp == null or not mp.has_multiplayer_peer()


## Server process (host or dedicated); false for clients when online.
func is_server() -> bool:
	var mp := _get_multiplayer()
	if mp == null or not mp.has_multiplayer_peer():
		return true
	return mp.is_server()


## Peer id to use for [method MultiplayerAPI.rpc_id] when sending to the host.
func server_peer_id() -> int:
	return DEFAULT_SERVER_PEER_ID


## Runs [param mutator] immediately when offline or when this process is the server.
## Returns [code]true[/code] if the mutation ran locally (caller should **not** send an RPC).
## Returns [code]false[/code] when this is a client — caller should invoke the matching [@RPC] on the server.
func run_mutation_on_authority(mutator: Callable) -> bool:
	if is_offline():
		mutator.call()
		return true
	if is_server():
		mutator.call()
		return true
	return false
