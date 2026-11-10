# Experimental native DMS ChatGPT WebEngine popout — offline only

**Not a plugin release.** This directory intentionally has **no plugin.json**.
Do not symlink, install or register it in the running DMS/ChatGPT v0.1.0.
The stock installed Quickshell 0.3.2 has `argc=0`: creating a WebEngineView
inside that process may abort the **entire desktop shell** (upstream issues
[#1393](https://github.com/quickshell-mirror/quickshell/issues/1393) and
[#1412](https://github.com/quickshell-mirror/quickshell/issues/1412)).

## What is implemented

- Uses real DMS `PluginComponent`, `PopoutComponent`, and the existing
  `PluginPopout` and `PopoutManager` behind them; no independent surrogate
  `PanelWindow` pretending to be the DMS popup.
- Native pill opens a DMS popout on click. Hover cannot open/focus it.
- Displays **offline** HTML with a simple input field and a fixed success
  marker. No site requests, credentials, chat content, JS injection,
  WebChannel or automatic downloads.
- Creates a distinct disk-backed Qt WebEngine profile with the Qt 6.11
  `WebEngineProfilePrototype` API **on the widget owner**, not inside
  transient popout content. Only persistent cookies are stored; website
  permission requests are denied. This profile is **not Zen's**.
- The profile's default storage/cache paths resolve via Qt's
  QStandardPaths; the future test runner must set separate
  `XDG_DATA_HOME` and `XDG_CACHE_HOME`. **No login testing yet.**
- One experimental widget instance only. The profile factory returns null
  if the data directory is already used by another profile. A shared
  singleton profile owner and multi-monitor lifecycle design are required
  before production integration.

## Source-only preparation — no shell launch

Use the existing v0.2 feature branch:

```sh
python3 -m unittest discover -s ChatGPT/tests \
  -p test_native_popout.py -q
bash ChatGPT/experiments/native-popout/prepare_sandbox.sh
```

The script checks out a pinned DMS source revision
`e46ccbc1d58930d6a189cd1c90b276db2d64bf42` into
`/tmp/dms-chatgpt-native-v02/dux-shell`, then copies the candidate files
into **that private source tree only**:

- `quickshell/ChatGPTNativeProbe/Widget.qml`
- `quickshell/ChatGPTNativeHarness.qml`

This is necessary because the real DMS components resolve `qs.Common`,
`qs.Services` and `qs.Modules.Plugins` relative to the QML configuration
root. The harness uses a synthetic floating **test pill** but a **real**
DMS `PluginComponent`/`PluginPopout` for its popup.

The script does **not** launch Quickshell, DMS, or the browser. It does not
register a plugin, touch `~/.config/dms`, restart any process, or install
a package. Before running the harness, validate DMS's required Quickshell
QML modules against the **separately patched** host: our previous reduced
`build-layer` deliberately disabled I3, Hyprland, System Tray, etc., but
DMS imports some of those modules. A suitably isolated and compatible host
must be built first.

## Future runtime gate (not yet performed)

Run **only after** a distinct compatible patched host and isolated
`HOME`, `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_CACHE_HOME`,
`XDG_STATE_HOME` have been validated. Avoid starting an entire DMS
session connected to the existing daemon. Test actual click-open,
type `test`, Escape, click-outside dismissal, reopen, and whether the
WebEngineView is destroyed on hide. Native WebEngine in the real DMS
popout remains **unverified**.

Do not enable online navigation/login until the popout focus, profile
ownership, lifecycle and host compatibility gates pass.

## Prepared DMS vs patched Quickshell import audit

The private DMS source copy is now prepared on CachyOS
(`DMS_NATIVE_SANDBOX_PREPARED` and 4/4 static regression tests).
Before trying any QML runtime or changing build flags, run the purely
**read-only** module audit:

```sh
python3 ChatGPT/experiments/native-popout/check_host_imports.py
```

It reads only the fixed `/tmp/dms-chatgpt-native-v02/dux-shell/quickshell`
QML files and `/tmp/dms-chatgpt-qs-v02-argc1/build-layer/CMakeCache.txt`.
It scans all DMS QML files (including dormant features), reports which
`Quickshell.*` modules are disabled in the isolated build, and explicitly
labels unmapped modules as unknown. No shell, DMS daemon, browser, website,
or test popout is launched. A module-flag match **does not guarantee**
runtime compatibility; it is only the next prerequisite check.

Do not launch the experimental native harness until the missing modules,
isolated XDG variables and DMS service side effects have been reviewed.
