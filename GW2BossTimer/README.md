# GW2 Boss Timer Plugin

> [!CAUTION]
> The code of this plugin is 99% written by AI!

A DankMaterialShell plugin that displays Guild Wars 2 world boss spawn timers in your shell bar.

## Features

- 📊 Shows next upcoming world boss spawn(s) in the bar
- ⏱️ Real-time countdown timer (HH:MM or MM:SS format)
- 🔄 Supports dual boss spawns - displays both names with slash separator
- 📋 Click to view complete world boss schedule popup
- 🔗 Right-click to copy waypoint link to clipboard
  - On widget: cycles through waypoints if multiple bosses spawn simultaneously
  - On popout entries: copies that specific boss's waypoint
- 🌍 All times displayed in CET (Central European Time, UTC+1)
- 🎨 Color differentiation - hardcore bosses shown in warning color (orange/yellow)
- 🔄 Automatic timer updates every second

## Installation

This plugin is part of the [almighty-atlas DMS plugins](../README.md) monorepo and is installed through its registry:

```bash
dms registry add atlas https://github.com/almighty-atlas/dms-plugins
dms plugins install gw2BossTimer
```

Then:

1. Open DankMaterialShell Settings → Plugins and toggle "GW2 Boss Timer" on
2. Add it to your DankBar widget list in the bar settings
3. Restart the shell with `dms restart` if the widget does not show up

See the [repository README](../README.md#installation) for manual installation.

## Usage

### Bar Widget
- **Left Click**: Opens the full world boss schedule popup
- **Right Click**: Copies the next boss's waypoint link to clipboard
  - If multiple bosses spawn at the same time, right-click cycles through them

### Widget Display
- Shows the schedule icon and next boss name(s)
- For dual spawns, displays: "Boss1 / Boss2"
- Hardcore bosses (Tequatl, Jungle Wurm, Karka Queen) are highlighted in orange

### Schedule Popup
- Lists all world bosses in today's spawn order (96 entries covering 24 hours)
- Shows spawn time in CET for each boss
- Next upcoming boss is highlighted with a blue border
- Boss names are color-coded (orange for hardcore, white for normal)
- **Right Click** on any boss entry: Copies that boss's waypoint link

### Waypoint Links
The plugin includes waypoint codes for each boss. When you copy a waypoint link, you can paste it in-game chat and click it to be transported to that location.

## Technical Details

### Schedule
The world bosses follow a complete 24-hour rotation with 96 total spawn entries. The schedule includes:
- All 11 standard world bosses
- 3 hardcore world bosses (Tequatl the Sunless, Evolved Jungle Wurm, Karka Queen)
- Complete timing for all 24 hours

### Hardcore Bosses
Displayed in orange/warning color:
- **Tequatl the Sunless** - Sparkfly Fen
- **Evolved Jungle Wurm** - Bloodtide Coast  
- **Karka Queen** - Southsun Cove

### Timezone
All times are in **CET (Central European Time, UTC+1)**. The plugin uses your system's local timezone, so if you're in a different timezone, adjust the times accordingly.

## Files

- `plugin.json` - Plugin metadata and configuration
- `Widget.qml` - Main widget component with bar display and popout
- `Settings.qml` - Settings/information panel
- `README.md` - This file

## Development

To test changes during development, use:

```bash
dms ipc call plugins reload gw2BossTimer
```

This hot-reloads the plugin without restarting the shell.

## Notes

- Times are in CET - adjust mentally for your timezone if different
- Each boss spawns for approximately 15 minutes
- The schedule is synchronized across all servers in Guild Wars 2
- For the official in-game timer, type `/wiki wb` in chat
- The plugin updates every second for accurate countdown display

## Source

World boss schedule data from: [GW2 Wiki - World Boss](https://wiki.guildwars2.com/wiki/World_boss)
