# YouTube Search (DMS / Dux Shell)

A lightweight DankBar / dock widget for searching YouTube **without a Google
account or API key**. Results include thumbnails, titles, channels and durations.
Each result can be opened explicitly in the default browser or in mpv.

## Requirements

- DMS 1.6.x / Quickshell 0.3.x; designed to retain compatibility with Dux Shell 2.0
  via the existing plugin API and compatibility imports.
- `yt-dlp` (required for video search)
- `xdg-open` (browser action; normally provided by xdg-utils)
- `mpv` (optional, only for the mpv action)

On Arch / CachyOS:

```bash
sudo pacman -S --needed yt-dlp xdg-utils mpv
```

## Install through the registry

```bash
dms registry add atlas https://github.com/almighty-atlas/dms-plugins
dms plugins install youtubeSearch
```

Enable **YouTube Search** in *Settings → Plugins* and add it to the bar.
If the registry was already added for another plugin, skip the first command.

For local development, symlink this directory under
`~/.config/DankMaterialShell/plugins/YouTube` (DMS 1.6) or
`~/.config/dms/plugins/YouTube` (Dux 2.0), scan plugins, then run
`dms ipc call plugins reload youtubeSearch`.

## Usage

1. Click the YouTube icon in the bar.
2. Enter a search term; press Enter or click **Suchen**.
3. Choose **Im Browser öffnen** or **Mit mpv abspielen**.

Search runs through DMS's documented `Proc.runCommand` API and begins **only on explicit user action**. The plugin does not download
videos, automatically play anything, or log in to YouTube. URLs are constructed
only from validated 11-character YouTube video IDs. Child processes receive
arguments directly rather than through a shell. A 30-second UI deadline prevents
stuck searches; stale results are ignored after it expires. The Proc service
owns process cleanup (the deadline does not forcibly kill a subprocess).

## Known limits

- YouTube can change search behavior or rate-limit/block `yt-dlp`; update it
  when searches fail. Results may be incomplete or unavailable.
- No Google sign-in, subscriptions, watch history, recommendations, downloads,
  embedded video player, or playback-state control in this initial version.
- The mpv action needs a working mpv installation with yt-dlp support.
- Requires network access; thumbnails load directly from `i.ytimg.com`.
- Runtime verification on the target DMS 1.6.3 / Dux 2.0 system is required.

## Troubleshooting

Run the same search in a terminal:

```bash
time timeout 35s yt-dlp --ignore-config --flat-playlist \\
  --dump-single-json --no-warnings --skip-download --socket-timeout 10 \\
  'ytsearch10:linux' >/dev/null
echo "Exit-Code: $?"
```

If the command exits with 0 but the plugin fails, inspect DMS shell logs for
`youtubeSearch:` messages and report the error text from the popout. A failed
process now reports its exit code separately from a 30-second callback timeout.
