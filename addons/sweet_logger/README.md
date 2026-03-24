# Sweet Logger

A small Godot 4 addon that provides a global **`SweetLogger`** autoload for readable, colorized console output. Log lines can include multiplayer peer context, log level styling, and optional script/function columns.

## Requirements

- Godot **4.x** (project uses 4.6 features; adjust if you target an older 4.x)

## Installation

1. Copy the `sweet_logger` folder into your project: `res://addons/sweet_logger/`.
2. Open **Project → Project Settings → Plugins**.
3. Enable **Sweet Logger**.

The plugin registers the `SweetLogger` autoload automatically. You do not need to add it manually under **Autoload** unless you prefer to manage it yourself (in that case, disable the plugin and add the singleton pointing at `res://addons/sweet_logger/SweetLogger.gd`).

## Usage

From any script:

```gdscript
SweetLogger.info("Player {0} joined", [peer_id], "MyScript.gd", "_ready")
SweetLogger.warning("Low health", [], "MyScript.gd", "take_damage")
SweetLogger.error("Invalid state", [], "MyScript.gd", "set_state")
```

See `SweetLogger.gd` for the full API (e.g. `log`, `debug`, format placeholders).

## Disabling the plugin

When the plugin is disabled, it removes the `SweetLogger` autoload entry from the project. Re-enable the plugin or add the autoload again if you still need the singleton.

## License

Released under the [MIT License](LICENSE). You may use, modify, and distribute this freely; keep the copyright and license notice in copies you distribute, as usual for MIT.
