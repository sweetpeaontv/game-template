# sweetpea's game-template

A Godot 4 template for multiplayer 3D games. 

The goal of this project is to make multiplayer games a bit more accessible — example code, a predefined structure, and two networking approaches you can learn from and extend, instead of starting from a blank project. I am using this template to build a game, and others have games in planning using the template as a basis.

The game is **server-authoritative**: the host (listen-server) owns simulation and discrete command validation; clients predict where needed and apply confirmed state. It runs with two networking layers in parallel:

1. **[netfox](https://github.com/foxssake/netfox)** — continuous simulation (rollback, network time, predicted input)
2. **Message / Command pipeline** — discrete authoritative events (spawn, scene change, sync patches, character cosmetics)

Transport is handled by `GNet` (ENet or Steam). The project expects a **custom Godot build** with deterministic physics stepping for rollback sync, and is set up for **GodotSteam** when shipping on Steam.

---

## Parallel networking

Both systems share the same peer connection from `GNet`. Use one or the other depending on how often state changes and whether clients need to predict.


| Need                                                                                    | Use                                          |
| --------------------------------------------------------------------------------------- | -------------------------------------------- |
| High-frequency predicted physics / input (move, hold, throw, mashy interactables)       | **netfox** rollback                          |
| Discrete authoritative facts (door open, keypad digits, cosmetics, spawn, scene change) | **Messages** + **SyncState**                 |
| Host / join / peer metadata                                                             | **GNet** + `ClientManager` / `ServerManager` |

### GNet (transport)

`app/autoload/gnet.gd` switches **ENet vs Steam** `MultiplayerPeer`, tracks connect/disconnect and player metadata, and exposes helpers like `is_authority()` and `execute_or_request()` (host runs locally; clients RPC to peer 1). The point of the adapter swap: develop and test multiplayer **locally with ENet** using the same networking code with no Steam servers or peer relay required; when you want to test with Steam, swap the adapter and that same code runs over Steam. GNet does not define game commands — after connect, game traffic is netfox and/or the message pipeline.

### netfox (continuous simulation)

Wired via the netfox autoloads (`NetworkTime`, `NetworkRollback`, etc.). In this project:

- `RollbackSynchronizer` + `TickInterpolator` on the player and rollback interactables
- `PlayerInput` (`BaseNetInput`) gathers input on network tick hooks
- `RewindableAction` drives interact / alt-interact across rollback
- `player._rollback_tick` runs movement, focus, and interactions inside the rollback loop
- `NetworkRollback.mutate(...)` marks nodes dirty when state changes mid-tick

Reference objects: pickup cube (production-style), plus deprecated `door-rollback` / `keypad-rollback` examples (see Interactables).

### Messages & SyncState (discrete events)

An EventBus-style command pipeline for authoritative, infrequent state. Flow:

```
ClientRelay.make_request(command, payload)
  → GNet.execute_or_request
  → ServerManager → ServerRelay → MessageRouter
  → CommandHandler.validate / accept
  → deliver (ACTOR / OTHERS / ALL / TARGETED)
  → ClientRelay → handler.apply
```

Message types (`types/messages/Message.gd`): **REQUEST**, **CONFIRM**, **REJECT**, **NOTIFY**.

Commands (`types/messages/command_registry.gd`): `CLIENT_READY`, `SESSION_END`, `SPAWN`, `DESPAWN`, `SYNC_STATE`, `SCENE_CHANGE`, `CHARACTER_CHANGE`, `INTERACT` (chat stubbed).

**SyncState** (`app/game/components/sync-state/`) patches registered nodes by path hash. Authority calls `update(patch)` → dirty → `MessageRouter` flushes `SYNC_STATE` notifies each server frame. Late join gets a full sync snapshot via `CLIENT_READY`. Used by non-rollback interactables (`door-sync-state`, `keypad-sync-state`, etc.).

> Discrete traffic lives in `types/messages/`, `app/messages/`, and `server/`.

---
## Repository layout


| Path      | Purpose                                                                                       |
| --------- | --------------------------------------------------------------------------------------------- |
| `app/`    | Client/game runtime: scenes, UI, gameplay, client message transport, autoloads                |
| `server/` | Host-side logic in the same process (listen-server): managers, relay, message router, spawner |
| `types/`  | Shared types: `Message`, `Payload`, command handlers, registries, session/game helpers        |
| `addons/` | Third-party + editor plugins (netfox, logger, collision tool, …)                              |
| `tools/`  | Editor/import helpers                                                                         |

### `app/`


| Path                   | Purpose                                                                          |
| ---------------------- | -------------------------------------------------------------------------------- |
| `app/main/`            | Entry scene — world container, players root, UI layers                           |
| `app/autoload/`        | Scene/UI/audio/settings, GNet, ClientManager, RegistryLibrary, PersistentData, … |
| `app/messages/`        | Client relay (requests out; confirm/reject/notify in)                            |
| `app/game/player/`     | Controllable avatar — netfox-heavy movement and interaction                      |
| `app/game/character/`  | Visual character (builder, armature, placeholder for template mode)              |
| `app/game/components/` | Reusable pieces: Interactable, focus sensor, SyncState, interaction variants     |
| `app/game/objects/`    | Concrete props; many have `-rollback` and `-sync-state` twins                    |
| `app/game/worlds/`     | Menu, game world, customizer                                                     |
| `app/data/registries/` | Content registries (meshes, palettes, colors)                                    |
| `app/ui/`              | Screens, overlays, HUD, widgets                                                  |

### `server/` & `types/`


| Path               | Purpose                                                     |
| ------------------ | ----------------------------------------------------------- |
| `server/network/`  | Server relay                                                |
| `server/messages/` | Message router (validate → deliver; flush dirty SyncStates) |
| `server/managers/` | ServerManager, player spawn orchestration                   |
| `types/messages/`  | Message, Payload, CommandRegistry, per-command handlers     |
| `types/registry/`  | Runtime registries (sync targets, etc.)                     |
| `types/entity/`    | Entity type handlers (e.g. player spawn)                    |


---
## Architecture

### Boot / scene flow

1. `Main` checks critical autoloads and registers UI containers
2. Loads **MenuWorld** + **MainMenu** via `SceneManager` / `UIManager`
3. Host: `ClientManager.start_game()` → `ServerManager.start_server()` → `GNet.host_game`
4. Server notifies `SCENE_CHANGE` → GameWorld
5. On scene ready, clients send `CLIENT_READY` (with character snapshot)
6. Server replies with existing players, SyncState snapshot, and `SPAWN` for the new peer

Worlds load into `Main/WorldContainer`; players live under `Main/Players`.

### Player & character

- **Player** (`CharacterBody3D`): simulation authority on the server; input/camera/actions on the owning peer
- **CharacterConfig** + registries drive mesh/color/size; changes go over `CHARACTER_CHANGE`
- **PersistentData** holds the local character snapshot used at join

The meshes shipped here are **placeholders**. A modular **character customizer** system is already in place (registries, builder, UI overlays). The models used in sweetpea’s own project are licensed but **not distributable** with this template. If there is enough interest, custom shareable models could be made for everyone to use. Until then, template mode (`IS_TEMPLATE`) runs on the placeholder character so the repo works without proprietary assets.

### Registries (`RegistryLibrary`)

Runtime lookup by deterministic int keys (usually `get_path().hash()` for scene-placed nodes; server IDs for spawned entities):

- Interaction: `interactables`, `operables`, `pickupables`, `examinables`
- Sync: `sync_targets`
- Content: character meshes, palettes, colors

### Interactables — dual implementations

Same gameplay ideas, two sync strategies:

```
app/game/components/interactable/
  interactions/            # SyncState / message-oriented (preferred for most props)
  interactions-rollback/   # netfox RollbackSynchronizer / RewindableStateMachine
```

`door-rollback` **and** `keypad-rollback` **are deprecated.** They remain only as examples of pushing netfox into more complex tasks. That approach is impractical for production and will not be used in shipped games — prefer the `door-sync-state` / `keypad-sync-state` (Message + SyncState) variants for real work.

Focus is handled by a focus sensor on the interactable physics layer, with shared flows for pickup, drop, charge-to-throw, examine, and operate.

### Extending

- **New discrete command** — add a `Command` + `Payload` + `CommandHandler`, register in `CommandRegistry`
- **New SyncState object** — add a `SyncStateNode`, register into `sync_targets`, call `update(patch)` on authority
- **New predicted input** — extend `PlayerInput` / rollback properties and handle them in `_rollback_tick`

---

## Running this project

You **cannot** open this repo in a stock Godot editor if you rely on Steam or the custom physics build. Use one of the following:

1. **Download a prebuilt editor** (and matching export templates) from **[sweetpeaontv/godork releases](https://github.com/sweetpeaontv/godork/releases)** — that engine matches what this template expects (physics stepping, GodotSteam, etc.).
2. **Build that engine yourself** from the same repository by following its README and build scripts.

If you build from source, you need Valve’s **Steamworks SDK**; it is **not** something this template or third-party repos can legally bundle. You obtain it through **Steamworks** / Valve’s developer agreements. Publishing on Steam also involves Valve’s **Steam Direct** per-product fee (**$100 USD**) and their partner terms.

---

## Editor addons

Secondary tooling included with the template:

- **[Sweet Logger](addons/sweet_logger/)** - custom structured, colorized logs with peer and script context
- **[Interactable Collision Tool](addons/interactable_collision_tool)** - generate a collision shape from a mesh onto a `CollisionShape3D`
- **netfox** (+ extras / internals) - rollback and network time (core to multiplayer sim)

---

## Maintenance

I intend to keep incrementing on this template and bring it up to date with the latest Godot releases. Do not expect urgency or a fixed schedule for those updates.