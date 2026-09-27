# GW2 Boss Timer

> **In a nutshell**
> Never miss a Guild Wars 2 world boss again. This DankMaterialShell widget shows the next world boss and a live countdown right in your DankBar. Click it for the full daily schedule, right-click to copy the waypoint link and paste it into the in-game chat.

> [!NOTE]
> **About this code:** this plugin was written almost entirely with AI assistance. As with any third-party code, feel free to have a look at it before you run it.

## Contents

- [Features](#features)
- [Installation](#installation)
- [Usage](#usage)
- [Good to know](#good-to-know)
- [Development](#development)
- [Sources](#sources)

## Features

- 📊 Shows the next upcoming world boss spawn(s) in the bar
- ⏱️ Live countdown timer (HH:MM or MM:SS), updated every second
- 🔄 Dual spawns are displayed as `Boss1 / Boss2`
- 📋 Click to open the complete daily world boss schedule
- 🔗 Right-click to copy the waypoint link to the clipboard
- 🎨 Hardcore bosses are highlighted in the warning color (orange/yellow)
- 🌍 All times in CET (Central European Time, UTC+1)

## Installation

This plugin is part of the [almighty-atlas DMS plugins](../README.md) monorepo and is installed through its registry:

```bash
dms registry add atlas https://github.com/almighty-atlas/dms-plugins
dms plugins install gw2BossTimer
```

Then:

1. Open DankMaterialShell **Settings → Plugins** and toggle "GW2 Boss Timer" on
2. Add it to your DankBar widget list in the bar settings
3. Restart the shell with `dms restart` if the widget does not show up

See the [repository README](../README.md#installation) for manual installation.

## Usage

### Bar widget

| Action | Effect |
|--------|--------|
| **Left click** | Opens the full world boss schedule popup |
| **Right click** | Copies the next boss's waypoint link to the clipboard. If multiple bosses spawn at the same time, each right-click cycles to the next one |

The widget shows the schedule icon and the name(s) of the next boss. Hardcore bosses (Tequatl, Jungle Wurm, Karka Queen) are highlighted in orange.

### Schedule popup

- Lists all world bosses in today's spawn order (96 entries covering 24 hours)
- Shows the spawn time in CET for each boss
- The next upcoming boss is highlighted with a blue border
- Boss names are color-coded (orange for hardcore, white for normal)
- **Right click** on any entry copies that boss's waypoint link

### Waypoint links

Every boss comes with its waypoint code. Paste the copied link into the in-game chat and click it to travel straight to the spawn location.

## Good to know

- **Schedule:** the plugin covers the full 24-hour rotation with 96 spawn entries: all 11 standard world bosses plus the 3 hardcore bosses. The schedule is the same on all Guild Wars 2 servers, and each boss stays up for roughly 15 minutes.
- **Hardcore bosses** (shown in orange): Tequatl the Sunless (Sparkfly Fen), Evolved Jungle Wurm (Bloodtide Coast), Karka Queen (Southsun Cove).
- **Timezone:** all times are in CET (UTC+1). The plugin uses your system's local timezone, so adjust the times accordingly if you live elsewhere.
- **Official timer:** type `/wiki wb` in the in-game chat for the wiki's boss timer.

## Development

| File | Purpose |
|------|---------|
| `plugin.json` | Plugin metadata and configuration |
| `Widget.qml` | Main widget component with bar display and popout |
| `Settings.qml` | Settings/information panel |

Hot-reload the plugin without restarting the shell:

```bash
dms ipc call plugins reload gw2BossTimer
```

## Sources

World boss schedule data from the [GW2 Wiki – World boss](https://wiki.guildwars2.com/wiki/World_boss) page.
