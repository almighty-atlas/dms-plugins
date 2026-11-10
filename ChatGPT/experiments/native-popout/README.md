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

## Real native rendering and text entry confirmed; lifecycle next

The user supplied **three screenshots** and a full runtime log on
2026-11-10: the isolated DMS source and DCommon submodule load;
the actual DMS `PluginPopout` renders offline WebEngine HTML with marker
`DMS_NATIVE_POPOUT_HTML_LOADED`; typing into the HTML input works.
All **17/17** local tests passed. No production shell was replaced.

The first screenshot shows an oversized external `FloatingWindow` test
pill container. The experimental harness now explicitly sets
`width: 420`, `height: 95` and widget 160×48; confirm the smaller
geometry on Niri.

New markers on the genuine DMS widget:
`DMS_NATIVE_POPOUT_STATE OPEN/CLOSED` (visibility) and
`DMS_NATIVE_WEBVIEW_CREATED/DESTROYED` (QML view lifetime).
The browser **profile** is outside the popup; that does NOT alone
preserve unsent text or running responses if the view is destroyed.

Next test: click pill, type `draft123`, click outside, reopen and
check draft preservation. Then test Escape. Compare markers to
determine whether close/reopen recreates `WebEngineView`.
No online navigation, account login or production plugin changes.

## Lifecycle passed; public ChatGPT page optional (2026-11-10)

After the 420×95 test-pill geometry and lifecycle tracing update, the
user reported **all tests work**: opening, typing, click-outside
dismissal, reopening, draft preservation and Escape. This is
user-reported; no second terminal lifecycle log was provided, so
we have **not** independently verified how many WebEngineView objects
survive or are recreated. Do not infer that a chat response can
continue while the popup is closed.

The next gate loads the **public, signed-out ChatGPT homepage** in the
**real** DMS `PluginPopout` with an explicit opt-in flag:

```sh
bash ChatGPT/experiments/native-popout/run_native_popout.sh --public-chatgpt
```

Default execution (without arguments) continues to load **only local
offline HTML**. The opt-in mode forwards an explicit flag through
the private `env -i` session; it uses a **separate off-the-record Qt
WebEngine profile** (no `storageName`, so cookies/cache are in memory)
and does not reuse the offline persistent test profile or Zen cookies.
Only `https://chatgpt.com/` is directly requested by the experiment
(the website itself can request associated resources and redirects).

**Do not sign in, send messages, upload files or grant permissions in
this test.** Page-load success does not guarantee usable website content;
inspect the screenshot for any Cloudflare challenges and visible rendering.
The runner remains bounded to 60 seconds and isolated from the live
DMS backend; it is not a kernel sandbox. The Qt WebEngine
Chromium sandbox remains enabled. Experimental production activation
is still blocked.

## Native public-site consent persistence gate (not yet tested)

A 2026-11-10 screenshot confirms the signed-out ChatGPT page renders
in the genuine DMS PluginPopout, including its cookie modal. Before
authentication, test whether a non-sensitive consent choice survives
a process restart with an **explicitly named, disk-backed profile**:

```sh
bash ChatGPT/experiments/native-popout/run_native_popout.sh --persistent-chatgpt
```

This new third profile, `dms-chatgpt-consent-probe-v01`, uses
`AllowPersistentCookies` and is separate from both the offline profile
and the public off-the-record `--public-chatgpt` profile. Qt's profile
data is written only beneath the isolated runner's private XDG data and
cache paths in `/tmp/dms-chatgpt-native-v02`. The files may remain on
the test machine after the process exits and are not automatically
deleted. The directory is **temporary**, not a production login path.

In this opt-in mode, select **Reject non-essential** on the public site,
let the test end, then launch **the same mode again** and check whether
the dialog remains dismissed. This is a consent persistence probe, not
proof of session authentication: some sites can store consent with
different mechanisms. **Do not sign in, send prompts, upload files or
grant permissions.** Run only one instance at a time.

## Consent persistence confirmed; separate opt-in authentication test (2026-11-10)

The user confirmed that the cookie dialog remained dismissed after the
second launch of `--persistent-chatgpt`. This shows that the tested
preference persisted across a **full Quickshell process restart**.
It does **not** demonstrate authenticated-session persistence.

A separate *fourth* named profile, `dms-chatgpt-auth-probe-v01`,
can now be selected by the **explicit** `--auth-chatgpt` argument.
It is distinct from all prior offline, anonymous public and cookie
consent profiles. To avoid losing login sessions after `/tmp`
cleanup, the runner stores this specific profile's private HOME/XDG
data in the user-owned, mode-0700 directory
`~/.local/share/dms-chatgpt-native-auth-probe/`. The runtime
session still uses the isolated socket path, private session D-Bus,
unset DMS/Niri backends and the reviewed patched Quickshell binary.

**Important:** This private directory can contain valid authentication
tokens, cookies and other sensitive account data. Do not upload or share
its contents, screenshots showing login details, OAuth callback URLs,
or unredacted authentication logs. The assistant never needs credentials.

Opt-in command, **only when you are ready to authenticate yourself**:

```sh
bash ChatGPT/experiments/native-popout/run_native_popout.sh --auth-chatgpt
```

The login mode lasts at most **300 seconds** per run, giving time for
interactive authentication. The login provider may reject Qt WebEngine,
open a new window that is not handled by this prototype or require a
passkey mechanism not available in the isolated D-Bus environment.
Do not weaken browser sandbox flags to work around such failures.

If sign-in works, close the run and launch the *same* opt-in mode
again. Verify whether the account remains signed in. This test is
limited to the local prototype; it is neither a release endorsement
nor evidence that an installed DMS plugin can run WebEngine using
the system's still-unpatched argc=0 Quickshell.

To end the experiment after testing, first close all test windows,
then remove the dedicated auth-test directory **only if you no longer
need its saved session**. Never delete the production DMS or Zen data
as part of this cleanup.

## Installed-host compatibility preflight (read-only by default)

After the user confirmed ChatGPT reply continuation across a hidden
**real DMS popup**, the remaining release blocker is the host:
the system-installed Quickshell was earlier verified as `argc=0`;
only the isolated, patched `build-dms` host was confirmed as
`argc=1`. Upstream tracking: quickshell
[#1393](https://github.com/quickshell-mirror/quickshell/issues/1393)
and [#1412](https://github.com/quickshell-mirror/quickshell/issues/1412).

The non-destructive host preflight compares package IDs and executable
hashes without starting a shell:

```sh
bash ChatGPT/experiments/native-popout/host_preflight.sh
```

To safely **re-test** the real argc behavior of each host, use the
explicit `--probe` argument. It launches the already-reviewed,
WebEngine-free `QuickshellArgsProbe.qml` under an independent
6-second timeout for each binary and prints **only** the marker
`ZERO_UNSAFE_FOR_WEBENGINE`, `NONZERO_WEBENGINE_PREREQUISITE_MET`
or `INCONCLUSIVE`:

```sh
bash ChatGPT/experiments/native-popout/host_preflight.sh --probe
```

Neither mode modifies DMS/Quickshell packages, installed plugins,
session profiles, the DMS daemon or the running desktop session.
The explicit probe briefly launches a separate Quickshell process,
never a WebEngineView. A nonzero argc is **necessary but insufficient**
for native embedding; QML modules and compatibility must also pass.
Do not enable a production native widget on an unpatched host.

## Built-frontend relocation gate, offline and without systemd changes

The user's live DMS diagnostics confirm:
- `/proc/1363/exe` resolves to stock `/usr/bin/quickshell`.
- The DMS backend's PATH begins with `/usr/local/sbin:/usr/local/bin:/usr/bin`.
- `ldd` on the patched `build-dms/src/quickshell` reports **no missing
  linked shared libraries**.
- ELF `RUNPATH` printed as `[::::::::::::::::::::::]`: effectively
  empty path elements, with no explicit `/tmp` build directory listed.
  This alone does **not** establish relocation of the Qt QML plugins.

The existing `run_native_popout.sh` now has an explicit
`--relocation-check` offline-only mode. It copies **only** the private
patched test executable to a **different private path** at
`/tmp/dms-chatgpt-native-v02/portable-host/quickshell`, verifies a
matching SHA256 hash, checks for missing linked libraries and then
executes the genuine DMS PluginPopout **with local HTML only** and the
same isolated HOME/XDG/D-Bus runtime.

```sh
bash ChatGPT/experiments/native-popout/run_native_popout.sh --relocation-check
```

Check that the DMS test pill appears, the popup opens and text is
accepted. A successful test proves basic runtime relocation to that
second path *in the current environment*, **not** that the binary
is safe to install system-wide or remains compatible after Qt/
Quickshell updates. On QML import errors, review the missing modules
before packaging: Quickshell's CMake output used
`QT_QML_OUTPUT_DIRECTORY` under the build tree, and the earlier
build issued a warning that `INSTALL_QMLDIR` and
`INSTALL_QML_PREFIX` were unset. No module relocation was assumed.

The test does not change `/usr/bin/qs`, `/usr/bin/quickshell`,
`dms.service`, PATH, Niri settings, package files or the production
ChatGPT plugin. The private authenticated profile is **not selected**
by this test, and no account data are copied. The test has not been
executed on the user's machine yet.

## Versioned private Quickshell staging, with RUNPATH sanitization

The user confirmed that the pinned patched host still opens the **real**
offline DMS PluginPopout after copying from its build directory to a
different path under `/tmp` (`--relocation-check`). This supports,
but does not by itself prove, user-directory installation portability.

New *explicit* staging script:

```sh
bash ChatGPT/experiments/native-popout/stage_private_host.sh --stage
```

It requires the tested build binary (exact SHA256
`63e258a5b089565b9a93feca02bce7d5dc6602e719d2c66997356643601290f4`)
and pinned source commit. It installs **only a copy** into the
user-owned version directory:

```text
~/.local/share/dms-chatgpt-native-host/9b0f339-argc1-v01/
├── host/quickshell
└── bin/qs
```

The source binary has a colon-only `RUNPATH`; the script demands
`patchelf`, removes the `RUNPATH` on the **new copy only**, confirms
no RPATH/RUNPATH dynamic entry remains using `readelf`, and checks
`ldd` for missing libraries. Directories are user-owned mode 0700;
the script refuses symlinked/unowned files or a divergent existing
same-version host. The shim delegates `qs` arguments via `exec` to
the adjacent private host. No general PATH, systemd, stock binary,
DMS config or plugin is changed.

**Next isolated offline runtime check, after staging:**

```sh
bash ChatGPT/experiments/native-popout/run_native_popout.sh --staged-host-check
```

This launches the real DMS Popup, **offline local HTML only**, through
the staged `bin/qs` shim under the previously isolated XDG/DBus
test instance. Check the pill, click open and type into the test
field. The persisted ChatGPT auth profile is not touched.

If `patchelf` is unavailable, staging stops with a clear
`DMS_PRIVATE_HOST_BLOCKED` message; it does not install packages.
This staged private copy is still a prototype, **not yet selected
by `dms.service`**. Full DMS plugin module compatibility and
Qt version maintenance need separate review. Rollback for this
staging-only step is simply not to enable the service override;
do not delete or edit any live DMS or Zen profile. Do not stage
a production override until explicit approval.

## Service-scoped private host override preview, intentionally read-only

On 2026-11-10 the user confirmed that the versioned, private
`stage_private_host.sh --stage` host also works through
`run_native_popout.sh --staged-host-check`: the true offline DMS
PluginPopout opens and the input is usable. This is a user-reported
runtime success, **not** a full production DMS host migration.

A strictly **read-only** systemd preview script is now available:

```sh
bash ChatGPT/experiments/native-popout/preview_dms_override.sh --preview
```

It verifies the private binary and exact launcher, confirms the
RPATH/RUNPATH was removed and linked libraries resolve, reads the
actual active `dms.service` MainPID and PATH from `/proc`, and
requires the previously observed system service path and *no*
existing overrides. It prints a proposed one-file drop-in:

```ini
# Proposed only, do NOT apply directly:
[Service]
Environment="PATH=<private bin/qs dir>:<existing DMS PATH>"
```

The concrete absolute paths come from the user's own runtime,
not an inferred systemd setting. `Environment=` does not expand
`$PATH`; systemd will use the full explicit string. See
systemd.exec(5) for the environment-setting semantics.

**The preview writes nothing and does not call systemctl reload,
restart, stop, kill, enable, or disable.** It also does not alter
the ChatGPT WebEngine auth profile, the installed plugin or the
stock Pacman files. The service-scoped PATH change, if separately
approved later, will affect DMS and its child processes, not
only Quickshell. A DMS restart can briefly interrupt the panel,
the Bitwarden helper and other child processes.

**Planned rollback (not executed or installed yet):** delete only
the exact managed `50-chatgpt-private-qs.conf` drop-in created
during the separately approved activation, run
`systemctl --user daemon-reload`, restart `dms.service`,
then verify `/proc/<new qs pid>/exe` resolves back to
`/usr/bin/quickshell`. This must be possible from a TTY even
if the graphical panel fails. Never delete third-party
overrides, the Pacman package, or the saved auth profile.
Before actual activation, explicit permission must be obtained.

Even after a service host switch, **native ChatGPT is not
automatically installed as a production plugin**: the released
`ChatGPT/Widget.qml` is still Zen-based. A separate, gated
native widget with safe Zen fallback will be needed.
