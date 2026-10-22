# YouTube Companion 0.2.0

A local-first DMS bar widget: explicitly search YouTube, save videos, revisit local
search/launch history, and play video or audio queues through mpv. No Google
account, API key, background polling, automatic playback, or media downloads.
The plugin ID and registry name remain `youtubeSearch` / **YouTube Search**.

## Requirements and installation

Target: CachyOS/Arch, Hyprland, DMS 1.6.3 and Qt 6/Quickshell. Dux Shell 2.0
compatibility is intended through the existing plugin wrappers, but has not been
runtime-tested. Required: `yt-dlp`; optional: `mpv` and `xdg-open` (xdg-utils).
Install dependencies yourself if needed; the plugin never installs programs.

```bash
sudo pacman -S --needed yt-dlp xdg-utils mpv
dms registry add atlas https://github.com/almighty-atlas/dms-plugins
dms plugins install youtubeSearch
```

Enable **YouTube Search** in Settings → Plugins and add it to a bar. Both bar
orientations are supported. Update an existing registry installation with:

```bash
dms plugins update
dms ipc call plugins reload youtubeSearch
```

DMS 1.6.3 implements plugin unload/reload with cache-busted top-level component URLs. Reload is
the intended update path; actual desktop reload acceptance remains open. If old
QML types remain cached after adding files, restart DMS manually. Reloading the
plugin stops its managed mpv processes; it does not erase stored lists.

For development, symlink `YouTube/` into
`~/.config/DankMaterialShell/plugins/YouTube` (DMS 1.6), or the configured Dux
plugin directory (`~/.config/dms/plugins/YouTube` on a default Dux 2.0 setup).

## Use

The four tabs are **Suche**, **Merkliste**, **Verlauf**, **Warteschlange**.
Enter a query (maximum 200 characters), then press Enter or the search icon.
Nothing searches as you type. Videos have standard-player, audio, bookmark and
queue actions. Thumbnails have a fallback if loading fails. Filter changes apply
locally and do not trigger a new network search.

- **Merkliste:** toggle a bookmark, up to 200 distinct videos, newest saved first.
- **Verlauf:** the last 25 distinct queries and 100 distinct launched videos,
  newest first. Queries can be repeated or removed; both histories can be cleared.
  A launch is **not** confirmation that a video played successfully or was watched.
  Queue launches record all URLs handed to mpv, not track-by-track playback.
- **Warteschlange:** up to 50 distinct videos. Move entries up/down, remove or clear,
  and launch the entire ordered list as video or audio. Playing keeps the queue.
- **Settings → Plugins → YouTube Search:** choose the default player and filters,
  enable/disable histories, or clear histories separately/together. Disabling
  recording retains previous entries until explicitly deleted. Existing 0.1.2
  settings are not rewritten as a migration.

Automatic player selection uses a local `mpv --version` check: mpv Video when
available, otherwise Browser. Explicit mpv selections report missing-program
errors instead of silently changing the selection. Queue playback always uses
mpv. Audio uses `--no-video --audio-display=no --force-window=no` and requests
`bestaudio/best`; the fallback can receive a combined stream when an audio-only
format is unavailable, while video decoding stays disabled. mpv receives
`--no-config --no-terminal` so local user scripts/configuration cannot turn this
plugin's launch into disk downloads or unexpectedly open audio video windows.
At most three player processes per widget are allowed; close one before starting
another. Playback controls and status are handled by the player, not the plugin.

## Keyboard

Shortcuts stay inside the popout. Letters typed in the search field remain text.

| Key | Action |
| --- | --- |
| Ctrl+K | Focus search |
| Enter in search | Search once |
| Down in search | Focus first visible result |
| Up / Down on a result | Previous / next result; Up from first returns to search |
| Enter on a result | Open with default player |
| Ctrl+Enter on a result | Audio in mpv |
| M on a result | Toggle bookmark |
| Q on a result | Add to queue |
| Escape on a result | Return to search |
| Escape in search | Hide filters if open; otherwise DMS closes the popout |
| Tab / Shift+Tab | Navigate rows and action buttons |

The selected video scrolls into view. Loading more preserves its ID/selection.
Focus follows the actual `parentPopout.shouldBeVisible` and window activation
signals, with a deferred event-loop focus handoff after DMS's own focus handler.

## Search limits and filter accuracy

Search starts with `ytsearch10:`. **Mehr laden** repeats the same query with 20,
30, 40, then 50 requested entries and deduplicates validated video IDs. This is
**not server pagination**. YouTube can reorder the window; earlier results are
retained. Loading stops if fewer source entries arrive or the 50-entry request
limit is reached. There is no assumption that the entire YouTube result set is
exhausted. Rapid different searches coalesce to the latest pending query, avoiding
parallel yt-dlp searches within one widget. Separate widgets can each search.

Filters operate only on loaded search candidates and retain source relevance
order. Empty filtered results may require **Mehr laden** or a different filter.

| Filter | Behavior |
| --- | --- |
| All supported content | Valid video IDs returned by `ytsearch`; no channels/playlists |
| Shorts | Positive `youtube.com/shorts/ID` URL evidence, never duration alone |
| Live | `live_status=is_live` or explicit `is_live=true`; past/upcoming streams excluded |
| Length | Under 240 s, 240–1200 s inclusive, or over 1200 s; unknown duration and live items excluded |
| Exclusively regular videos | Unavailable: a watch URL does not prove absence of Shorts membership |
| Newest first | Unavailable: no verified server sort parameter or precise dates in flat results |

The inspected yt-dlp 2026.10.21 extractor supports search URLs with `sp` and
`ytsearch` video search, and exposes Shorts URLs/live badges in flat metadata.
No undocumented filter parameters or speculative date sorting are used here.
Positive-only Shorts/live filters can omit entries when YouTube/yt-dlp omits the
metadata. Remaining work: verify server filter encodings with live integration
fixtures before offering exclusive video filtering or newest-first sorting.

## Local storage and privacy

Settings use DMS `savePluginData/loadPluginData` in its shared
`plugin_settings.json`. Lists use `savePluginState/loadPluginState` under key
`companion`, schema version 1, normally at:
`~/.local/state/DankMaterialShell/plugins/youtubeSearch_state.json` on DMS 1.6.
Dux/XDG paths depend on shell configuration. No state-file permissions beyond
the normal DMS state API are requested. Settings need `settings_read` and
`settings_write`; search/playback need the existing network/process permissions.

Only bounded metadata is retained: ID, title, channel, optional duration,
positive live/Shorts flags and saved/opened timestamps. Thumbnail/watch URLs are
constructed from validated IDs, never stored executable paths or remote commands.
Unknown/corrupt records are ignored. Unversioned/version-0 `companion` objects
normalize to version 1 on the next explicit mutation; version 0.1.2 had no lists.
A newer unsupported schema is not overwritten. Loading alone does not rewrite
state. Every mutation re-reads the current synchronous service snapshot and
`pluginStateChanged` refreshes other widget instances. This protects widgets in
the same shell process; independent DMS processes sharing files are not supported.
DMS owns debounced disk writes, so an abrupt crash before its flush can lose the
most recent mutation. Lists are not encrypted; normal local account access applies.

The plugin probes only local mpv availability on startup. YouTube receives an
explicit search and player request; `i.ytimg.com` receives thumbnail requests
for instantiated rows, including saved/history rows when opened. Nothing syncs
with a Google account. Playing streams uses memory/buffers, not media files.

## Diagnostics

Search retains `/usr/bin/env yt-dlp` because directly launching the bare executable
failed in some Quickshell environments despite a correct PATH. mpv and xdg-open
also start through `/usr/bin/env`. All commands are argument arrays without a
shell. Search uses DMS Proc with a unique request token and a live owner, a 25 s
process timeout and a 30 s UI watchdog. Old replies cannot overwrite newer results.
Searches can be retried after failure. Player processes expose nonzero exits and
a start watchdog; startup confirmation is not proof of successful media playback.

- **127:** executable missing from the DMS environment PATH.
- **126:** executable found but cannot run.
- **124:** internal search timeout.
- **Other exits:** inspect network, YouTube rate limits and DMS/yt-dlp versions.
- **30 s without a callback:** inspect DMS logs for `youtubeSearch:`. The UI
  watchdog invalidates callbacks; DMS Proc owns subprocess timeout/cleanup.

Compare the same command in a terminal (no downloads):

```bash
timeout 35s /usr/bin/env yt-dlp --ignore-config --flat-playlist \
  --dump-single-json --no-warnings --skip-download --socket-timeout 10 \
  'ytsearch10:linux' >/dev/null
```

## Verification and desktop acceptance

See [TESTING.md](TESTING.md) for commands, recorded results, limitations and a
concrete target-desktop acceptance procedure. Passing offline tests is not
confirmation of live YouTube availability or DMS/Dux compositor behavior.

## Roadmap 0.3.x (not implemented)

1. **Local subscriptions:** persist stable `UC…` channel IDs; verify public
   `https://www.youtube.com/feeds/videos.xml?channel_id=…` RSS against live fixtures,
   cache/deduplicate bounded entries. Start with manual refresh; timed refresh and
   notifications require explicit opt-in. No permanent default background polling.
2. **mpv JSON IPC:** use an instance-specific socket in a private 0700 directory
   beneath validated user `XDG_RUNTIME_DIR`, bind ownership to the launched PID,
   enforce local permissions and cleanup on exit. Never discover/control arbitrary
   sockets. Add request IDs and property observation for pause, track navigation,
   volume, position, progress and speed. mpv's IPC is not an authentication boundary.
3. **SponsorBlock:** evaluate maintained mpv scripts, licensing, dependencies and
   category behavior. Explicit activation and category settings; no unreviewed
   automatic script installation.
4. **DMS launcher:** evaluate the composite widget/launcher surface and
   `LauncherPlugin`, prefix `yt`, bounded asynchronous results and shared actions.
   Confirm the lowest supported DMS/Dux version before changing manifest type.
5. **LaterSift:** agree on an explicit URL handoff contract with
   `almighty-atlas/latersift`; pass only a validated YouTube watch URL. Keep shared
   watch-later management in LaterSift; do not add OAuth or duplicate its backend.

## Interface references

- [DMS 1.6.3 PluginComponent](https://github.com/AvengeMedia/DankMaterialShell/blob/v1.6.3/quickshell/Modules/Plugins/PluginComponent.qml)
  and [PluginPopout](https://github.com/AvengeMedia/DankMaterialShell/blob/v1.6.3/quickshell/Modules/Plugins/PluginPopout.qml).
- [DMS 1.6.3 PluginService](https://github.com/AvengeMedia/DankMaterialShell/blob/v1.6.3/quickshell/Services/PluginService.qml),
  [Dux development interfaces](https://duxlabs.dev/docs/dms/plugin-development).
- [yt-dlp search extractor](https://github.com/yt-dlp/yt-dlp/blob/2026.10.21/yt_dlp/extractor/youtube/_search.py)
  and [flat metadata](https://github.com/yt-dlp/yt-dlp/blob/2026.10.21/yt_dlp/extractor/youtube/_tab.py).
- [mpv CLI / JSON IPC](https://mpv.io/manual/stable/),
  [Quickshell Process](https://quickshell.org/docs/v0.2.1/types/Quickshell.Io/Process/).
