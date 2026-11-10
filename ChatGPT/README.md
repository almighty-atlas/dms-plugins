# ChatGPT Web · DMS / Dux Shell 2.0 · v0.1.0

Native DankBar launcher for **https://chatgpt.com/** using your existing ChatGPT
subscription. No OpenAI API, API key or additional API charges. This is a real
browser window, **not an embedded WebView**.

**Verification status:** offline regression, syntax, upstream API-contract,
manifest-schema and CSS-parser checks passed on tiny02. No DMS/Zen/Niri graphical
session is available there. Login, visual appearance and desktop integration
are **not yet verified on CachyOS**. See [TESTING.md](TESTING.md).

## Features and architecture

- `Widget.qml`: horizontal/vertical `PluginComponent`, current `DIcon` and
  `StyledText` from `qs.DCommon.Widgets`, scale-aware sizes and native error
  toasts. Left click opens/focuses; right click explains the last error/theme
  lifecycle. A busy indicator and bounded process watchdog prevent dead UI.
- `Settings.qml`: native persisted browser mode, Material theme, Compact Mode,
  and optional follow-the-clicked-monitor settings.
- `scripts/launcher.py`: short-lived Python operation, argument arrays only,
  cross-process `flock`, executable discovery, bounded Niri IPC and confirmed
  window detection. `launch.sh` is a backwards-compatible wrapper.
- `scripts/theme_sync.py`: validated CSS, isolated profile initialization and
  event-driven theme preparation. `runtime.py` supplies private atomic state.
- `scripts/manage.py`: reversible **local checkout** install/update/uninstall.
  Release installation and updates use the existing registry.
- No daemon, idle browser poller, extension, remote backend or telemetry added.
  While starting, the launcher polls briefly for a real window, then exits.

### Requirements

For the default mode: **DMS/Dux 2.0+, Python 3 (3.10+), native Linux Zen, Niri
with JSON IPC and floating-window actions, Wayland**. No pip packages at runtime.
Discovery order: `zen-browser`, `zen`, `zen-browser-bin`, `zen-bin` in **DMS's PATH**.
Flatpak/Snap browser wrappers are not supported for isolated mode: sandboxed
profile paths and process IDs differ. Regular/system-browser mode is the fallback.
`xdg-open` is needed only for system-browser mode; Bash only for the legacy wrapper.

## Try PR #5 now: one desktop command

Run in a terminal **inside your CachyOS/Niri desktop session**. Requires Git and
Python 3. This deliberately checks out the feature branch; it does not deploy
anything on tiny02 or merge the PR.

```sh
git clone --single-branch --branch feat/chatgpt-dms-widget https://github.com/almighty-atlas/dms-plugins.git "$HOME/dms-plugins-chatgpt" && python3 "$HOME/dms-plugins-chatgpt/ChatGPT/tests/desktop_smoke.py" --install
```

Keep that checkout: the installer links it into
`${XDG_CONFIG_HOME:-~/.config}/dms/plugins/chatgptWeb`. It refuses to overwrite
another installation. If the checkout already exists, run its smoke script
directly after updating it on the feature branch.

The script runs automated checks, opens/focuses ChatGPT, and guides you through
the unavoidable visual/login checks. It asks you to enable the plugin and add
the widget in DMS. It never asks for passwords or chat content. Output is
`PASS` / `FAIL` / `SKIP`; exit codes are **0 all passed, 1 failure, 2 incomplete**.
Diagnostics: `${XDG_STATE_HOME:-~/.local/state}/dms-chatgpt/desktop-smoke.json`
(0600, results and version numbers only). Non-interactive mode marks manual
checks `SKIP`; it does **not** fake a graphical pass.

### Registry release installation (after merge, not yet tested end-to-end)

```sh
dms registry add atlas https://github.com/almighty-atlas/dms-plugins
dms plugins install chatgptWeb
```

Add the registry only once. In **Settings → Plugins**, enable **ChatGPT Web**;
add `chatgptWeb` to the desired horizontal or vertical DankBar on each screen.
The registry entry's `repo`, `path: ChatGPT`, ID, name and dependencies match
the manifest and upstream monorepo installer. DMS clones the repository's
**default branch**; it cannot publish this unmerged feature branch by ID.
No fabricated screenshot or unsupported registry branch property is supplied.

For current Dux upstream:

```sh
dms ipc call plugin-scan scan
dms ipc call plugin-scan reload chatgptWeb
dms ipc call plugin-scan status chatgptWeb
```

Some DMS builds use `plugins` instead of `plugin-scan`; the smoke script tries
both. Upstream prose still mentions the older target; the implementation was
checked against `Services/PluginService.qml`.

## Browser modes and window lifecycle

### Isolated Zen (default, recommended)

Profile: `${XDG_DATA_HOME:-~/.local/share}/dms-chatgpt/zen-profile` (0700).
Log in normally **once in this browser profile**, including OAuth/passkeys if
supported by Zen. Zen owns cookies, storage and session persistence. The plugin
never extracts, copies or interprets them. Your normal Zen profile is not opened
for writing by the plugin, registered as this profile or styled.

Launch arguments: `--no-remote --profile <fixed-plugin-profile> --name dms-chatgpt
--new-window https://chatgpt.com/`. No Chromium `--app`, kiosk or full-screen flag.
Zen's documented **Compact Mode** is the supported app-like alternative; no
reliable, documented standalone Zen app CLI was found in the inspected docs/source.
The profile has separate preferences, not a modified global `profiles.ini`.

Window identification uses exact `app_id == dms-chatgpt`. Some Zen versions
ignore `--name` ([upstream issue #7576](https://github.com/zen-browser/desktop/issues/7576)).
In that case the fallback is the Niri window PID **verified against the exact
dedicated `--profile` argument in `/proc/.../cmdline`**, not a broad Zen/title
match. Window title is only used to prefer the main ChatGPT window over an
OAuth popup among already identified dedicated windows. `--name` availability
is checked locally, and the actual window identity is checked after launch.

Repeated clicks, clicks from another bar, and DMS reloads find/focus the current
window without launching another browser. A per-plugin OS lock serializes
parallel launches and theme writes. If the browser is running without a detected
window, fail safely with a useful error: **do not delete profile locks or kill
normal Zen**. Wait for startup/shutdown or quit the isolated profile normally.
A stale lock file is harmless: the OS releases the advisory lock on process exit.

Closing the isolated browser leaves no plugin background worker. A later click
reopens the same persistent profile. Neither DMS restart nor plugin removal
terminates the independently launched browser. The launcher confirms **window
existence**, not successful login, network access or receipt of a ChatGPT reply.
First launch may need Zen onboarding. Normal window/tab management is still
possible; manually opened extra tabs/windows are not forcibly closed.

### Existing Zen / system browser

Existing Zen opens a regular `--new-window`; system browser uses `xdg-open`.
Neither mode creates/injects CSS into or modifies the normal profile. With Niri,
a newly observed ChatGPT window's ID, PID and app-ID can be remembered for
best-effort focus. Window title alone is never sufficient to focus an arbitrary
existing normal Zen window. Without identifiable new windows, browser startup
is reported as **requested**, not verified.

The strict single-window/positioning guarantee applies **only to isolated Zen
on Niri**. `xdg-open` may reuse a tab; normal-profile windows can change titles,
profiles or tabs. There is no privileged browser automation to resolve that.

## Material 3 theme

The widget reads the **active rendered `Theme` singleton**: background, surface,
surface container, primary/on-primary, surface text, variant text and outline,
plus `Theme.isLightMode`. Thus custom and stock themes work too; the wallpaper
cache alone is not necessarily the current shell palette.

On a palette/settings change, a debounced QML event prepares styles for an
already-created isolated profile. No polling service is needed. On every click,
the active snapshot is refreshed. Validated colors/mode are saved in plugin-owned
`theme.json` so terminal launches don't overwrite a custom theme with wallpaper
colors. Without a snapshot, the parser reads `~/.cache/dms/dms-colors.json` or the
legacy `DankMaterialShell` path: **`mode` + `colors.dark` / `colors.light`**, with
snake_case roles such as `surface_container` and `on_background`. Corrupt or empty
caches fall back to coherent light/dark defaults. Only opaque `#RRGGBB` literals
are accepted; executable CSS, short hex, URLs and ambiguous alpha values are rejected.

Generated `chrome/userContent.css` applies only to **`https://chatgpt.com/`**,
not authentication providers, other sites, subdomains or the normal profile.
It overrides semantic website surface/text/accent variables and a few stable
composer/sidebar attributes. Rounded composer/message containers are modest;
the website retains its own responsive layout, spacing and navigation.
The publicly accessible lightweight-web page and its semantic attributes were
inspected; authenticated desktop DOM and visual correctness remain unverified.
We intentionally do not depend on generated/hash-based CSS class names.

**Theme preparation is automatic; visible hot-reload is not.** Firefox/Zen
load userContent.css on profile startup. Fully quit **only isolated Zen**, then
click the widget again to apply colors/Compact Mode changes. Reloading the page
or focusing the existing window is insufficient. No unverified extension or
privileged browser injection is installed just to claim live synchronization.

Compact Mode is native Zen preferences; no CSS hides toolbars or authentication
controls. Hover at the edges, **Ctrl+L**, **Ctrl+Alt+S** (sidebar) and
**Ctrl+Alt+W** (toolbar in applicable Zen layouts) keep navigation reachable.
Turn Compact Mode off in plugin settings and restart the isolated browser for
full chrome. Turn **DMS-Farben übernehmen** off and restart to recover from a
ChatGPT DOM/style update; its stylesheet is replaced by a no-op, not left stale.
No CSS changes `display`, positioning, pointer events or generic form controls.
Login, file attachment, model/settings menus and input are never intentionally hidden.

## Niri: floating, positioning and two monitors

No Niri config is edited or reloaded automatically. After first detecting a new
dedicated window, explicit-ID Niri actions make it floating, size it to about
**760 × 860 logical pixels** (clamped for the output), and put it near the
clicked DankBar edge. The native screen name is passed by DMS, not inferred
from global monitor coordinates. Normal windows are never resized/moved.

Further clicks focus the same window, keeping your manually adjusted size and
position. Optional **Fenster zum angeklickten Monitor holen** moves that existing
window to the clicked bar's output. It is never fullscreen/pinned/always-on-top;
moving/resizing uses normal Niri controls. Placement uses a conservative 72px
edge offset, not a pixel-perfect anchored DMS popout. Unusual bars/struts may
need manual adjustment. IPC placement failures give a warning without destroying
the confirmed browser window.

For correct initial floating before the launcher observes the window, optionally
add the single block from [niri-window-rule.kdl.example](niri-window-rule.kdl.example)
**once**, or include a copied file from your own config. Validate with
`niri validate` before accepting it. It matches only `^dms-chatgpt$`, never all Zen
windows. If Zen ignores `--name`, this optional rule won't match, but the verified
PID-based runtime integration still works. Check locally using
`niri msg pick-window`; don't upload window listings with private titles.
Rollback: remove only the added block/include. Never replace `config.kdl`.

## Update, uninstall and recovery

Registry release: `dms plugins update chatgptWeb` / `dms plugins uninstall chatgptWeb`.
For a local feature-branch checkout, use `git pull --ff-only` on that branch and:

```sh
python3 ChatGPT/scripts/manage.py update
# Or remove only this checkout's symlink:
python3 ChatGPT/scripts/manage.py uninstall
```

Disable/remove the widget in DMS before uninstalling. Browser data and login are
**retained** outside the install directory; no data is deleted by either helper.
Updates need a plugin reload; new QML/JS siblings can require a DMS restart because
of Qt's component directory cache. This revision adds Python helpers, not new
production QML sibling files. Do not remove the checkout while its link is installed.

The earlier scaffold at the fixed profile path is adopted only if its CSS has
the known generator header; a marker identifies managed profiles thereafter.
Symlinked profile/chrome/managed files and unknown nonempty profiles are refused.
If an old **unthemed** scaffold profile has no marker/header, stop its browser
and back up/rename that exact profile directory manually before a fresh start.
It is intentionally not auto-adopted or deleted; keep the backup for its login.

Troubleshooting:

| Symptom | Action |
| --- | --- |
| Missing Zen/Python | Check executables in DMS's environment; don't install pip packages for the plugin |
| Niri/IPC error | Run inside the Wayland/Niri session; verify current Niri action support |
| Startup timeout, running profile | Finish onboarding or quit only isolated Zen normally, then retry |
| Theme not visible | Click widget, fully quit isolated Zen, reopen; authenticated site CSS may have changed |
| CSS harms readability | Disable theme, restart isolated profile; report the affected control, not chat/cookies |
| Wrong monitor / geometry warning | Check display connection; enable follow-output if desired; move manually |
| Native widget not loaded | DMS 2.0 required; check plugin scan/status and enable/add to DankBar |
| Local installer refuses replacement | Keep existing installation untouched; uninstall via its own original method first |

## Privacy and limitations

No cookie copying, token scraping, auth/header modification, CAPTCHA bypass,
certificate exceptions, DOM automation or API calls. The plugin launches only
the official ChatGPT URL. Login and normal website network traffic are handled
by Zen/ChatGPT; this is not a promise that the website or browser itself has no
telemetry. Dedicated-profile telemetry upload preferences are disabled, without
weakening browser security or update settings.

Diagnostics never collect raw browser output, private window titles, chat text,
cookies, passwords, screenshots, environment dumps or normal-profile contents.
Plugin settings use DMS persistence; the only extra state is private palette,
profile marker, advisory lock and best-effort fallback window identity. The
browser profile itself contains Zen-managed sensitive login data; protect your
local account and backups normally. No automatic profile deletion is offered.

Known limitations: desktop acceptance pending; theme reload requires profile
restart; upstream DOM/API changes; no verified Zen app mode; fallback focus is
best effort; Wayland app-ID can be ignored; Qt/qmllint runtime not available on
tiny02; registry release install requires merge by the user. No automatic merge.
WebView is a separate gated plan: [WEBVIEW.md](WEBVIEW.md), not production code.
