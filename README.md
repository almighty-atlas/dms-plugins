# DMS Plugins

> **In a nutshell**
> A small collection of plugins for [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) that you can install straight from the DMS settings. Add this repo as a registry once, then browse, install and update the plugins like any other. Currently ships a Guild Wars 2 world boss timer for the DankBar.

> [!NOTE]
> **About this code:** large parts of the plugins in this repository were written with AI assistance. As with any third-party code, feel free to have a look at it before you run it.

## Contents

- [Plugins](#plugins)
- [Installation](#installation)
- [Repository layout](#repository-layout)
- [Adding a new plugin](#adding-a-new-plugin)
- [Development](#development)

## Plugins

| Plugin | ID | Description |
|--------|----|-------------|
| [GW2 Boss Timer](./GW2BossTimer) | `gw2BossTimer` | Shows upcoming Guild Wars 2 world boss spawns with countdown timers in the DankBar |

## Installation

This repository is both a **plugin monorepo** (each plugin lives in its own directory) and a **DMS plugin registry** (the `plugins/` directory holds one registry entry per plugin). Adding it as a registry lets DMS browse, install and update the plugins directly.

### As a registry (recommended, DMS >= 1.6)

Add this repository as an additional registry once, then install plugins by ID:

```bash
dms registry add atlas https://github.com/almighty-atlas/dms-plugins
dms plugins install gw2BossTimer
```

Alternatively use **Settings → Plugins → Registries** in the DMS settings UI.

Updates are handled by `dms plugins update` like for any other registry plugin.

### Manually

Clone the repository and symlink (or copy) the plugin directory you want into your DMS plugins folder:

```bash
git clone https://github.com/almighty-atlas/dms-plugins ~/.config/DankMaterialShell/plugins/.repos/dms-plugins
ln -s ~/.config/DankMaterialShell/plugins/.repos/dms-plugins/GW2BossTimer ~/.config/DankMaterialShell/plugins/GW2BossTimer
dms restart
```

## Repository layout

```
.
├── plugins/                 # registry entries (one JSON file per plugin)
│   └── gw2-boss-timer.json
├── GW2BossTimer/            # plugin sources
│   ├── plugin.json
│   ├── Widget.qml
│   ├── Settings.qml
│   └── README.md
└── README.md
```

## Adding a new plugin

1. Create a new directory `<PluginName>/` with a `plugin.json` and the QML components.
2. Add a registry entry `plugins/<plugin-name>.json` that points to this repository with `"path": "<PluginName>"`. The `id` and `name` fields must match the plugin's `plugin.json`.
3. Add the plugin to the [table above](#plugins).

The registry entry format is documented in the [official registry's contribution guide](https://github.com/AvengeMedia/dms-plugin-registry/blob/master/CONTRIBUTING.md); the `plugin.json` format in the [DMS plugin development docs](https://danklinux.com/docs/dankmaterialshell/plugin-development).

## Development

Hot-reload a plugin without restarting the shell:

```bash
dms ipc call plugins reload <pluginId>
```
