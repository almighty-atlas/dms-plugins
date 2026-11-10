# v0.2: native WebView research and implementation gate

**Not implemented or enabled in v0.1.** Keep the isolated/regular browser launcher
permanently available. Research date: 2026-11-10. The CachyOS desktop experiments
below confirm Qt WebEngine and patched Quickshell rendering; **authentication,
actual DMS popup integration and release safety remain unverified**. The early
tiny02 research did not perform a graphical test.

## What is actually possible

| Option | Evidence / assessment |
| --- | --- |
| Qt WebEngine | Chromium-based QML `import QtWebEngine`, `WebEngineView` plus an explicit persistent profile. Adds Qt WebEngine/QtWebEngineProcess and renderer/GPU processes; not a lightweight rectangle. |
| Quickshell host | QML can in principle load an installed Qt module, **but importability alone is not sufficient**. Upstream inspected at `9b0f339b19057f4731bf3b48293307d7ef241671` does not link/initialize WebEngine in its launch code. Qt documents `QtWebEngineQuick::initialize()` or `AA_ShareOpenGLContexts` **before QGuiApplication/window GL contexts**. A plugin loaded after shell startup cannot safely retroactively guarantee that. Probe host capabilities first; do not claim arbitrary Quickshell builds support it. |
| DMS `PluginComponent` / `PopoutComponent` | Provides native theme, bar anchoring and screen-aware popup geometry, **not a browser engine**. A lazy popout could host a WebEngine view only after the host-init gate is solved. Closing a popout must not silently erase the login/profile or interrupt an upload without warning. |
| Separate Qt Quick helper | A small correctly initialized WebEngine executable contains crashes outside the shell and preserves native Qt/Wayland behavior. It is a standalone floating window, not an in-shell popout. Prefer this over an unsafe in-process hack if upstream cannot support the host initialization contract. Browser v0.1 may still be simpler and more compatible. |
| Qt WebKit / remote browser tricks | Do not use obsolete WebKit for modern ChatGPT or remote debugging/cookie extraction to transfer Zen authentication. No unofficial auth/API proxy or user-agent/security bypass. |

The C++ library/module is named **WebEngineQuick**; the QML import remains
**QtWebEngine**. Do not confuse the two when checking installed modules.

## Authentication and persistent sessions

- Use official first-party login in a newly isolated **WebEngine-owned** profile;
  never import/export/read Zen cookies or ask the plugin for credentials.
- Qt's default profile is **off the record**. Create one named disk-backed
  profile (`storageName: dms-chatgpt-webview`, `offTheRecord: false`) and set
  private persistent-storage/cache locations **before constructing views**.
  Since Qt 6.9 the documentation recommends `WebEngineProfilePrototype` for
  creation; determine the target Qt version before choosing the precise API.
- Default to `AllowPersistentCookies`, respecting the service's own expiry.
  Do not force session cookies to become persistent merely to prolong auth.
  Cookie persistence is handled by the engine, never by plugin code.
- Test email/password, Google/Apple/Microsoft OAuth, passkeys, popup/new-window
  requests, redirects and return-to-chat. Embedded engines may be rejected by
  providers/anti-bot checks even when ordinary Zen succeeds. Fail visibly and
  offer **Open in Zen**, not a bypass. Browser fallback needs its own login.
- Persistence tests: clean close, popup close, shell restart, machine login,
  crash recovery, expiry/logout. A view's lifecycle and a profile's lifecycle
  are separate; one profile must outlive all its views.

## Security contract

1. Keep Chromium's sandbox on; never use `--no-sandbox`,
   `QTWEBENGINE_DISABLE_SANDBOX`, disabled web security, certificate bypass or
   request-header tricks. Check kernel namespaces/seccomp and Arch packaging.
2. No `WebChannel` exposing shell commands/files to web content. Treat every
   page and URL, including redirects and downloads, as untrusted input.
3. Browser auth origins must remain reachable for official flows. Ask before
   opening unrelated external links; reject `file:`, `javascript:` and arbitrary
   executable URLs. Do not impose a simplistic chatgpt-only redirect allowlist
   that breaks legitimate OAuth.
4. Handle permission requests in native UI with origin and purpose; default
   deny for microphone/camera/screen capture until explicitly accepted. Integrate
   Wayland/PipeWire portals rather than pretending they work automatically.
5. Downloads require explicit handling/acceptance and safe user-selected paths;
   attachments need a native file picker, drag/drop and progress/error handling.
   Never pre-grant filesystem access. Don't log local filenames/chat contents.
6. Keep Qt/Chromium packages updated. A security update path and privacy review
   are release prerequisites, not optional follow-up work. Push service stays off.
7. CSS applies to the intended HTTPS ChatGPT documents only. If style injection
   is necessary, use an isolated script world and CSS-only behavior, no auth
   DOM manipulation or credential interception.

## Memory, Wayland and functional completeness

No measurements have been taken. Expect multiple Chromium processes and a
nontrivial memory/GPU cost, **not necessarily less than one isolated Zen**.
Measure idle/loaded/conversing RSS/PSS and GPU resources on CachyOS, including
closing the popup, prolonged idle and reopening. Don't invent a memory saving.
Avoid destroy/recreate on every hover, unbounded duplicate views and invisible
ongoing audio/network work. Suspension/discard can disrupt streaming and uploads;
gate it on real activity and warn before termination.

Desktop matrix: Niri floating vs layer-shell popout focus, multi-monitor mixed
DPI, fractional scale, GPU/renderer crash, Wayland IME/compose keys, keyboard
navigation, selection/clipboard, drag/drop, screen-reader accessibility, file
uploads/downloads, model selector/history/settings, streaming, voice permissions,
PDF/images/canvas and external links. Qt support for advanced web APIs can lag
desktop browsers; test features, don't infer them from a module import.

## Concrete staged implementation plan

1. **Gate v0.1:** finish the desktop smoke/acceptance checklist in TESTING.md.
   Record actual DMS, Quickshell, Qt, Zen and Niri package versions.
2. **Separate opt-in probe, no production manifest changes:** verify QML module
   availability, sandbox, GL initialization and GPU compatibility in an isolated
   process. Never load a potentially crashing probe into the user's main shell.
3. **Host decision:** propose upstream Quickshell/DMS WebEngine initialization
   support if absent. Document the supported minimum build. If not available,
   evaluate a separate Qt helper; explicitly label it non-embedded, or stop here.
4. **Persistent engine profile:** private paths, single-instance ownership,
   normal first-party login and `newWindowRequested` handling. Test auth/session
   matrix before adding custom colors. No Zen state transfer.
5. **Native integration only with a verified host:** lazy `popoutContent`, native
   header/error/fallback actions and screen-clamped 760×860 layout. Keep a single
   persistent profile/controller outside transient content. Correct layer-shell
   keyboard focus and escape/close behavior must not steal typing or dismiss
   file dialogs. Offer a normal window if the popout cannot handle auth dialogs.
6. **Functional browser surface:** file dialogs/downloads, permissions, context
   menus, clipboard, navigation/recovery and origin/error display. Do not ship
   a bare WebEngineView that silently drops uploads/popups/permission requests.
7. **Theme:** use the existing validated DMS palette contract; optional,
   conservative stylesheet. Document differences from browser userContent.css.
8. **Tests:** mock profile/controller lifecycle plus real sandboxed Wayland tests
   for auth, attachments, stream completion, mixed DPI, reopen/restart and renderer
   failure. Compare memory/performance to v0.1 and record measurements.
9. **Release decision:** only enable opt-in WebView after login, send/receive,
   attachment, focus and persistence pass on the real target system. If a provider
   blocks embedding, remain browser-only; no security workaround. Keep browser
   fallback and export no cookies, ever.

## Official references and inspected sources

- [Dux plugin API](https://github.com/duxlabs-dev/dux-shell/blob/3548daab9a7595b6dff52a79eda4cccd3697fdd6/quickshell/PLUGINS/README.md),
  `PluginComponent.qml`, `PluginPopout.qml` in the same revision.
- [Quickshell launch source](https://github.com/quickshell-mirror/quickshell/blob/9b0f339b19057f4731bf3b48293307d7ef241671/src/launch/launch.cpp).
- [Qt 6.10 WebEngineQuick initialization](https://doc.qt.io/qt-6.10/qtwebenginequick.html).
- [Qt WebEngineProfile](https://doc.qt.io/qt-6.10/qml-qtwebengine-webengineprofile.html)
  (off-the-record defaults, storage, cookies and profile prototype recommendation).
- [Qt WebEngine platform / sandbox notes](https://doc.qt.io/qt-6/qtwebengine-platform-notes.html).
- [Qt WebEngine Qt6 changes](https://doc.qt.io/qt-6/qtwebengine-changes-qt6.html).

## First opt-in v0.2 feasibility probe

A deliberately separate, offline C++/QML renderer and read-only diagnostic are
now available in [probes/webengine](probes/webengine/README.md). They do not
change the v0.1 production plugin or registry manifest. A renderer success on
CachyOS proves only that an independently initialized Qt process works; the
host-initialization prerequisite for a true DMS popout remains unresolved.

## Host source gate, checked after standalone probe success

The user's CachyOS (Qt Base 6.12.0, Qt WebEngine 6.11.3, Quickshell
0.3.2) passed the six preflight unit tests and successfully displayed
the offline `Qt WebEngine is rendering` page, confirmed by screenshot.

The inspected upstream Quickshell launch source creates a `QApplication`
or `QGuiApplication` but does not explicitly call
`QtWebEngineQuick::initialize()` or
`QCoreApplication::setAttribute(Qt::AA_ShareOpenGLContexts)` first.
**This is a source-level observation, not proof of how every downstream
Quickshell build is configured.** Qt's WebEngineQuick API requires the
initialization/attribute before GUI application creation, so we must not
blindly load a WebEngineView into the live DMS shell.

An optional **online, no-login first-party landing-page check** has been
added as a separate QML file; instructions:
[`probes/webengine/README.md`](probes/webengine/README.md).
It is only a compatibility filter. Even a successful ChatGPT page load
does not clear the in-process host gate. A compatible upstream Quickshell
initialization route (or explicitly separate Qt helper) remains necessary
for further progress.

Official versioned API:
https://doc.qt.io/qt-6.11/qtwebenginequick.html

## Quickshell 0.3.2 additional blocker (verified upstream, 2026-11-10)

After the online no-login page-load probe correctly displayed the public
ChatGPT landing page (user screenshot), upstream Quickshell source and issue
reports revealed a more concrete integration blocker:

- Quickshell constructs `QApplication` / `QGuiApplication` with
  `auto qArgC = 0` in `src/launch/launch.cpp`.
- GitHub issues [#1393](https://github.com/quickshell-mirror/quickshell/issues/1393)
  and [#1412](https://github.com/quickshell-mirror/quickshell/issues/1412)
  reproduce **fatal Qt WebEngine/Chromium startup** in Quickshell 0.3.2
  because `QCoreApplication::arguments()` is empty.
- A proposed one-line upstream fix changes `qArgC` to 1; this is an
  external proposal, **not** an applied or verified fix for the user's
  installed DMS/Quickshell.
- The existing independent Qt executable passed because its
  `QGuiApplication app(argc, argv)` receives the real program name.
- A safe standalone `QuickshellArgsProbe.qml` now checks only the integer
  Qt argument count in a **separate Quickshell instance**. It does not
  import QtWebEngine, launch a browser or interact with DMS.

Keep the production v0.1 Zen launcher unchanged. Even if the argument
issue is resolved upstream, verify the Qt WebEngineQuick initialization,
popup focus, authentication, file uploads and persistent profile before
shipping embedded functionality.

## CachyOS Quickshell argv probe: confirmed blocker

On 2026-11-10 the user ran the separate `QuickshellArgsProbe.qml` on
Quickshell 0.3.2 (CachyOS). The eight Python tests passed and console showed:

```text
DMS_QS_ARGUMENT_COUNT=0
DMS_QS_ARGC_ZERO
```

This confirms the actual installed Quickshell has the argument-list behavior
reported upstream in issues #1393 and #1412. The observed
`QQmlEngine::quit() emitted, but no receivers connected` warning was caused
by the *diagnostic* configuration's attempt to call `Qt.quit()`, not a
WebEngine crash. The diagnostic no longer calls it; the process is bounded
by `timeout` instead.

**Decision:** do not instantiate `QtWebEngine` inside the production DMS
process. Pursue a reviewed upstream Quickshell fix that provides at least
`argv[0]` to Qt, then validate on a separate Quickshell instance before
ever testing the actual DMS config. Issue #1393 includes experimental
evidence that `argc=1` alone may be sufficient for its tested Qt build;
the earlier initialization concerns are version-dependent and must
be verified rather than assumed to require an additional patch.

## Isolated argc=1 experiment: tested on CachyOS (2026-11-10)

The missing `cli11` build package was installed on the target system.
The proof-of-concept scripts under `probes/webengine/` clone a pinned
Quickshell 0.3.2 source snapshot into `/tmp`, patch only the copied
`argc = 0` line to `1`, and configure a minimal test build.
No installed Quickshell/DMS files, plugin manifest, browser profile or
release v0.1.0 are changed. Desktop results: CMake configuration succeeded (warnings from deliberately
disabled modules were nonfatal); compilation completed at
`[276/276] Linking CXX executable src/quickshell`. The user's patched
binary returned `DMS_QS_ARGUMENT_COUNT=1` /
`DMS_QS_ARGC_NONZERO`; a screenshot from the separate patched Quickshell
process confirmed the offline HTML rendered with
`DMS_PATCHED_QS_WEBENGINE_LOADED`. This is conclusive proof of an
**in-Quickshell** WebEngineView renderer with the one-line fix for the
tested reduced build, not proof of production DMS compatibility.

Next opt-in gate: render the public ChatGPT landing page in the patched
Quickshell process with an ephemeral `WebEngineProfile`, without login.
See `QuickshellChatGPTPageProbe.qml` and the README. Do not treat the
standalone renderer PASS as final embedded-DMS certification.

## Patched Quickshell: online public page confirmed (2026-11-10)

The user provided a screenshot of the official unauthenticated ChatGPT
landing page rendered **inside** the separate, patched Quickshell 0.3.2
`FloatingWindow`. Navigation/sidebar, the chat composer and cookie prompt
were visible. This is **not** proof that login, chat responses or cookie
persistence work and **not** a production DMS popout. No login was
attempted, and the test retained an off-the-record browser profile.

The next experiment is a private Wayland-enabled Quickshell build with
an offline `PanelWindow` / Wlr layer-shell WebEngine renderer, to check
whether Niri displays such a window and permits typing into its content.
The actual DMS popout involves additional DPopout/PluginPopout lifecycle,
focus, and geometry behavior and remains unverified.

## DMS plugin host integration gate (source review 2026-11-10)

Following the successful Wayland Layer-Shell + WebEngine keyboard test, the
actual upstream DMS implementation was inspected:

- `PluginComponent.qml` exposes `popoutContent`, `popoutWidth`,
  `popoutHeight`, and `triggerPopout()`. Supplying a
  `pillClickAction` overrides the native popup behavior; a native
  experimental WebView widget must not keep the v0.1 Zen-launch click
  action in that mode. DMS also supports hover-triggered popouts.
- `PluginComponent` owns a `PluginPopout`, whose `pluginContent`
  is sourced from the widget's `popoutContent`; it anchors the popup
  through `PopoutManager`. Its own `Loader` is not a guarantee that
  heavyweight web content will remain mounted across popup close/reopen.
- `PluginPopout.qml` creates a focusable container and calls
  `forceActiveFocus()` on opening; the parent container handles Escape
  by closing the popup. An embedded `WebEngineView` must be tested
  for text input, IME, history, popup keyboard focus, and whether
  Escape is consumed unexpectedly.
- `DPopout.qml` chooses a screen-dependent popup backend and includes
  transient focus handling. Our `PanelWindow` test proves a standalone
  Wayland layer-shell surface works on Niri, **not** that both DMS
  backends, animations, focus, hover-dismiss and multi-monitor anchoring
  are compatible.
- The user confirmed the separate patched `build-layer` runtime
  shows the offline WebEngine renderer **and accepts text input** in
  the HTML field. This is not inferred from build success alone.

**Architecture recommendation:** Keep the v0.1 launch-only widget
as the production default and create a separate opt-in native-popout
candidate under experiments, not in the production manifest. Give the
WebEngine profile a stable owner outside the transient popup view,
and instantiate the view only when needed. Ensure keyboard/hover
dismissal cannot interrupt streaming or uploads without explicit
handling. Validate a clone of DMS under the **patched** Quickshell
binary with isolated config/state before testing the production shell.
The currently installed Quickshell still reports `argc=0`;
do not activate WebEngine in that process. A supported distribution
mechanism for the `argc=1` host fix is a prerequisite to enabling
native mode for users.

Reviewed upstream files:
https://github.com/duxlabs-dev/dux-shell/blob/master/quickshell/Modules/Plugins/PluginComponent.qml
https://github.com/duxlabs-dev/dux-shell/blob/master/quickshell/Modules/Plugins/PluginPopout.qml
https://github.com/duxlabs-dev/dux-shell/blob/master/quickshell/Widgets/DPopout.qml

## Experimental DMS-native popout candidate staged (2026-11-10)

Implemented an **offline-only**, manually invoked source candidate under
[`experiments/native-popout/`](experiments/native-popout/README.md):

- Real DMS `PluginComponent` / `PopoutComponent` and built-in
  `PluginPopout` on click, not a lookalike custom `PanelWindow`.
- Uses `WebEngineProfilePrototype` from Qt WebEngine >=6.9 to create a
  distinct disk-backed profile owned by the widget rather than the
  ephemeral popout content. Persistent cookies are limited to those
  marked persistent, and permission requests are rejected.
- Only a local HTML page with a keyboard test field. No ChatGPT network
  requests, account login, WebChannel, scripts, or data extraction.
- Intentionally **no experiment plugin.json** and **no references from
  the production Widget.qml / Settings.qml / plugin.json**. Neither
  stock Quickshell nor the currently installed DMS has been modified.
- A source-preparation script fetches DMS commit
  `e46ccbc1d58930d6a189cd1c90b276db2d64bf42` into a new private
  `/tmp` directory and copies the candidate there. It does not start
  DMS, connect to a daemon, install anything, or modify the user's config.
- Four structural tests passed in local development. **QML runtime
  loading, popup layout, keyboard focus, re-opening and profile behavior
  in actual DMS remain unverified.**

### Additional host compatibility gate

The DMS `shell.qml` source includes `//@ pragma RenderControl`, while
Qt 6.11's WebEngineView documentation cautions that rendering into a
`QQuickRenderControl` OpenGL surface can fail due to context sharing.
This is **not proof** that DMS's actual popout uses that rendering path:
the Quickshell 0.3.2 build has not yet been examined to determine whether
it recognizes or uses the pragma. Test the real DMS popup backend
rather than inferring compatibility from our successful standalone
layer-shell test. Do not patch private Qt graphics functions or
disable the WebEngine sandbox.

The existing reduced patched `build-layer` excludes some Quickshell
modules (e.g. `Quickshell.I3` and `Quickshell.Hyprland`) that DMS
imports. Therefore the candidate is **not yet safe to launch** using
that binary without a separate compatibility check/build. Do not run
the user's actual DMS against the experimental binary or launch a
second full DMS shell connected to the existing backend.

Qt references:
https://doc.qt.io/qt-6/qml-qtwebengine-webengineprofileprototype.html
https://doc.qt.io/qt-6.11/qml-qtwebengine-webengineview.html

## Source-wide DMS Quickshell module audit (prepared; runtime not started)

The user confirmed the private DMS 2.0 source checkout and experimental
native-popout QML were prepared without changing the active desktop.
An additional offline `check_host_imports.py` compares all QML
`import Quickshell.*` statements with the **isolated** patched
`build-layer/CMakeCache.txt`. The analysis is deliberately conservative:
optional/dormant DMS features are included, unrecognized QML modules are
reported as unknown and no actual runtime compatibility is assumed.
The audit must be executed on CachyOS before deciding which optional
Quickshell modules to rebuild. No test harness is being launched yet.

## Host-Module: DMS-Import-Audit ausgewertet (10.11.2026)

1033 DMS-QML-Dateien: zehn optionale Quickshell-Modulgruppen im reduzierten
`build-layer` deaktiviert (Bluetooth, Hyprland, I3, MPRIS, Notifications,
PAM, PipeWire, Polkit, SystemTray, UPower), **keine unbekannten Imports**.
Ein separater `build-dms`-Konfigurator aktiviert diese und relevante
Unterkomponenten. Er prüft die exakt einzeilige gepatchte Quickshell-Quelle
sowie Polkit/PipeWire-Entwicklungsabhängigkeiten, ohne zu installieren oder
Prozesse zu starten. Das ist nur ein Quell-/Build-Gate. Die QML-Laufzeit,
DMS-Singleton-Effekte, Desktop-Isolation und der echte Popout bleiben offen.

## Native offline DMS PluginPopout runner ready (2026-11-10)

User build result: `[1098/1098] Linking CXX executable src/quickshell`
for the patched host with DMS QML modules. DMS source review confirmed
that DMSService auto-connects using DMS_SOCKET if nonempty, and several
singletons use standard writable XDG locations and run helper processes.
The isolated runner therefore clears DMS_SOCKET and NIRI_SOCKET, uses
private HOME/all XDG directories, an independent session DBus and
in-memory GSettings, retaining only the Wayland display socket as an
intentional host connection. It does not start the full DMS shell or
touch the installed plugin. This reduces accidental backend interactions,
but is not a kernel-level sandbox. Actual native popout runtime is
still awaiting user verification.

## DCommon symlink/submodule prerequisite identified (2026-11-10)

The first bounded offline native DMS popup runtime **did not reach
the visual popup**. Quickshell failed to load `PluginComponent` because
`qs.DCommon.Widgets` was unavailable. The pinned upstream DMS checkout
has `quickshell/DCommon -> ../dux-qml-common/DCommon` and a
`dux-qml-common` gitlink pinned to
`0877466a25b8e191a865bf75d0e500de6351ae04`.
The source preparation cloned the superproject without initializing
its submodule; the missing QML imports are consistent with that.
Preparation now initializes/verifies the **private** submodule and
runtime preflights its presence. No production changes; retest pending.

## Offline WebEngine in real DMS PluginPopout CONFIRMED (2026-11-10)

User-provided screenshots and terminal log show 17/17 static tests,
successful source/DCommon QML startup, **real DMS PluginPopout**
rendering local HTML with `DMS_NATIVE_POPOUT_HTML_LOADED` and
successful entry of `asd` in the HTML input. This confirms native
DMS popup rendering **and text-input focus**, but not close/reopen
behavior or unsent-draft preservation.

The oversized separate test-pill `FloatingWindow` now gets explicit
420×95 size. Popup state and `WebEngineView` creation/destruction
markers were added for the next runtime test. Profile continuity
and DOM/page continuity must be measured separately. The experiment
remains offline and outside the live DMS installation.

## DMS popup lifecycle user test passed; public-page gate staged

On 2026-11-10 the user reported that the follow-up native DMS popup
test worked in full. This includes click-outside close, reopening,
retained test draft, Escape close and the updated compact test pill,
as requested in the preceding test instructions. The reply included
no fresh terminal lifecycle log, so exact WebEngineView creation and
destruction counts remain unknown. This is not evidence that real
ChatGPT streaming continues while hidden.

A new **explicit** `--public-chatgpt` mode has been staged for the
isolated native popup runner. The default remains offline; signed-out
online mode uses Qt 6.11 `WebEngineProfilePrototype` without a
`storageName` for an **off-the-record**, ephemeral profile; the only
direct navigation target is `https://chatgpt.com/`. No login, account
data, production DMS settings or installation are involved. Online
DMS popup runtime has **not** yet been performed. User must refrain
from signing in until cookie/session behavior is separately reviewed.

## Public-site native popout confirmed; persistent consent-only gate

The user's screenshot confirms responsive signed-out
`https://chatgpt.com/` within a genuine patched DMS PluginPopout,
including the cookie dialog. That is a rendering success, not an
authenticated session test.

Qt 6.11 documents that a named `WebEngineProfilePrototype` creates
separate disk-backed profile storage, and
`WebEngineProfile.AllowPersistentCookies` saves persistent cookies.
An opt-in `--persistent-chatgpt` runner mode now uses a **third** named
profile, `dms-chatgpt-consent-probe-v01`, underneath isolated `/tmp`
XDG paths. The test is intended only to check non-sensitive cookie
consent after a complete process restart; no login, profile import
from Zen, filesystem installation or production DMS activation.
Its runtime result is **pending**.
