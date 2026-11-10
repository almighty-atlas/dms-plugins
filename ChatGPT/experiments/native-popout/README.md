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

## DMS-QML-kompatiblen Quickshell-Testbuild vorbereiten

Der User-Audit (10.11.2026): vier Tests bestanden, **1.033 QML-Dateien**, zehn
Modulgruppen im vorherigen Testbuild deaktiviert und keine unbekannten.

```sh
bash ChatGPT/experiments/native-popout/prepare_quickshell_dms.sh
```

Der neue `build-dms` wird separat unter `/tmp` konfiguriert. Das Skript
verifiziert den gepinnten Upstream-Stand und exakt die eine `argc=1`-Änderung,
prüft Polkit/PipeWire-Entwicklungsbibliotheken und aktiviert die zehn fehlenden
QML-Modulgruppen. Fehlende Bibliotheken erscheinen als
`DMS_HOST_DEPENDENCY_MISSING`. **Keine Installation, kein DMS-Start.**

Wenn `DMS_HOST_CONFIGURED` erscheint, kann der neue Build anschließend
mit `cmake --build /tmp/dms-chatgpt-qs-v02-argc1/build-dms -j2` kompiliert
werden. Der native Popout-Harness darf bis zur Prüfung isolierter XDG-Pfade,
QML-Module und DMS-Singleton-Nebenwirkungen **nicht** gestartet werden.

## First real DMS PluginPopout runtime (offline, opt-in)

The user confirmed the DMS-capable patched Quickshell build finished at
`[1098/1098] Linking CXX executable src/quickshell`.

The source review found that DMSService can connect to the live backend
using `DMS_SOCKET`; SettingsData/Paths write under XDG paths; NiriService,
Theme and other singleton initializers can trigger helper activity.
`run_native_popout.sh` therefore launches a separate process with private
HOME, XDG_CONFIG_HOME, XDG_DATA_HOME, XDG_CACHE_HOME, XDG_STATE_HOME,
XDG_RUNTIME_DIR, private session DBus, in-memory GSettings, no
DMS_SOCKET and no NIRI_SOCKET. The only intended shared session endpoint
is the *absolute original Wayland compositor socket*, needed for
on-screen display. This is **process state/IPC isolation**, not a
kernel/filesystem sandbox.

From the updated feature-branch checkout:

```sh
python3 -m unittest discover -s ChatGPT/tests -p test_native_runtime_isolation.py -q
bash ChatGPT/experiments/native-popout/run_native_popout.sh
```

The test should show a small floating test pill. Click it to request
the **real DMS PluginPopout**; check offline marker
`DMS_NATIVE_POPOUT_HTML_LOADED` and the HTML input. Type `test`,
dismiss by clicking outside, reopen, and test Escape. The command
stops automatically after 60 seconds; a `timeout` exit status 124 is
expected for an otherwise successful run.

No website requests, ChatGPT login, credentials, production plugin edits
or full DMS daemon/session launch. The experiment is unverified until
the user's CachyOS runtime test.

## First runtime failure: missing DCommon submodule (verified 2026-11-10)

The first isolated Quickshell host launched and passed 4/4 static safety
tests, but **QML configuration load failed before the popout could open**:
`PluginComponent` -> `BasePill` -> `BarPill` ->
`module "qs.DCommon.Widgets" is not installed`.
Numerous Quickshell QML scanner warnings about missing `DCommon`
imports were associated with the same missing submodule. Portal/DBus
diagnostics are not the blocking error.

Upstream pinned DMS superproject commit
`e46ccbc1d58930d6a189cd1c90b276db2d64bf42`
stores `quickshell/DCommon` as the symlink
`../dux-qml-common/DCommon` and references `dux-qml-common`
as a git submodule at the **pinned gitlink commit**
`0877466a25b8e191a865bf75d0e500de6351ae04`.
Our original shallow superproject clone had omitted this submodule.

`prepare_sandbox.sh` now initializes that submodule **in the private
checkout only**, verifies the gitlink revision and symlink resolution,
and prints `DMS_COMMON_SHA`. The runtime runner fails immediately if
the required submodule is missing or at an unexpected revision.
No need to rebuild Quickshell: the failure is in copied QML content.
After running the updated tests and preparer, rerun the same
`run_native_popout.sh` trial. The result is not yet verified.
