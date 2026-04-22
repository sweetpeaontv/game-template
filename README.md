# game-template

A Godot 4 template for multiplayer 3D games. It wires up **[netfox](https://github.com/foxssake/netfox)** (rollback, network time, and related autoloads), expects a **custom Godot build** with **deterministic physics stepping** for sync, and is set up to use **GodotSteam** when you ship with Steam. Use it as a base for your next multiplayer game instead of starting from scratch.

## What's included

- **Editor addons**
	- **[Sweet Logger](addons/sweet_logger/)** — structured, colorized logs with peer and script context, handy when several debug windows share one editor console.
	- **[Interactable Collision Tool](addons/interactable_collision_tool)** — generate a **collision shape from a mesh** and assign it to a `CollisionShape3D` (speeds up blocking out interactable props).
- **Interactables & player actions** — focus-based interaction with **pickup**, **drop**, **charge-to-throw**, **examine**, and **operate** flows, built on shared `Interactable` types and registries (good reference for extending new interaction kinds).
- **netfox in practice** — example usage in the player and interactables (e.g. rollback ticks and `NetworkRollback.mutate` where state must stay simulation-safe), wired together with the netfox autoloads so you can trace a real pattern instead of only reading docs.
- **Networking shell** — **`GNet`** autoload for **ENet vs Steam** adapter switching, lobby-ish coordination, player metadata, and late-join spawning notes; combine with your own RPCs and netfox rollback for game traffic.
- **App scaffolding** — autoloads for **scene flow**, **UI**, **audio**, **settings**, **debug overlay**, and **server/client** helpers so new scenes plug into an existing structure.

## Running this project

You **cannot** open this repo in a stock Godot editor if you rely on Steam or the custom physics build. Use one of the following:

1. **Download a prebuilt editor** (and matching export templates) from **[sweetpeaontv/godork releases](https://github.com/sweetpeaontv/godork/releases)** — that engine matches what this template expects (physics stepping, GodotSteam, etc.).
2. **Build that engine yourself** from the same repository by following its README and build scripts.

If you build from source, you need Valve’s **Steamworks SDK**; it is **not** something this template or third-party repos can legally bundle or hand you. You obtain it through **Steamworks** / Valve’s developer agreements. Publishing on Steam also involves Valve’s **Steam Direct** per-product fee (**$100 USD**) and their partner terms—plan for that if you intend to release on Steam.

## Maintenance

I intend to keep incrementing on this template and bring it up to date with the latest Godot releases. Do not expect urgency or a fixed schedule for those updates.