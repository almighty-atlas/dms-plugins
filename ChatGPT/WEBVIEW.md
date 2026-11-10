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

## User confirmed persistent consent; isolated login mode staged

On 2026-11-10 the user reported the consent dialog **did not reappear**
after a complete Quickshell restart in `--persistent-chatgpt`.
This verifies persistence of that website preference only;
no authentication or message streaming has been tested.

A separately named WebEngine profile,
`dms-chatgpt-auth-probe-v01`, can now be selected with an explicit
`--auth-chatgpt` runner flag. Its local sensitive data are stored
in `~/.local/share/dms-chatgpt-native-auth-probe/`, with a
0700 directory mode, rather than in temporary `/tmp` storage.
That data may include active bearer cookies and tokens and must not
be published. A separate 300-second bounded runner preserves the
DMS_SOCKET/NIRI_SOCKET isolation and does not use Zen's user profile.
Authentication is solely a user-driven interaction in the browser.

**Not yet verified**: login UI flow, authentication callback handling,
2FA/passkeys/SSO, authenticated session persistence, browser-profile
migration, real ChatGPT message streaming, and production installation.
The upstream argc=1 host fix remains mandatory for native DMS mode;
the feature stays in draft.

## Interactive authentication in the genuine isolated DMS popout confirmed (2026-11-10)

The user supplied a screenshot after launching `--auth-chatgpt`:
the ChatGPT authenticated interface (Chat/Work selector, composer and
model selector, with no login button) is rendered in the **real**
DMS `PluginPopout`. The user explicitly reported that it worked.

This is user-confirmed successful interactive login in the **isolated**
patched Quickshell host. Authentication persistence across a **complete
process restart** is not yet established. The user was asked to restart
the *same* `--auth-chatgpt` mode and verify whether login survives
without repeating credentials or 2FA. The secret-bearing auth profile
remains outside the repo and must never be uploaded or logged.

The stock Quickshell argc=0 host and production DMS plugin remain
unchanged. The PR must remain draft until native integration and
a supported patched-host deployment path are tested.

## Authenticated ChatGPT session survives a full isolated Quickshell restart (2026-11-10)

The user restarted `run_native_popout.sh --auth-chatgpt` after signing in
during the first run, and explicitly confirmed that the same ChatGPT
account was **still logged in without reauthentication**. Together with
the user-provided screenshot of the signed-in UI, this verifies
authenticated session persistence for the separate named WebEngine
profile in the genuine DMS `PluginPopout` **under the patched, isolated
Quickshell build**.

This does not verify response streaming, conversation recovery after
popup closure, authenticated file uploads, OAuth/new-window handling
in other login flows, performance, DMS hot reload, multi-monitor
anchoring or production host compatibility. The profile can contain
live session tokens and must not be uploaded, printed or committed.
The system-installed Quickshell remains unpatched (`argc=0` as
previously tested), so a production DMS `WebEngineView` is **not
safe to activate** at this stage. Retain the released v0.1 Zen
fallback and keep this PR in Draft.

Next candidate should remain isolated from the v0.1 manifest until
an explicit preflight gate for the Quickshell host exists; native
login data should not be copied into or read from the Zen profile.


## Authenticated ChatGPT request/response in native DMS popout confirmed (2026-11-10)

User supplied a screenshot of the genuine isolated patched DMS
`PluginPopout`, containing the prompt `Antworte ausschließlich mit
TEST OK` and the expected assistant output `TEST OK`. This confirms
that the authenticated embedded webview can **send a message and
display an AI-generated reply**. The screenshot still includes the
purple Stop-generation control; it does **not** conclusively prove
that generation had ended at capture time, nor that background
generation continues while the DMS popup is hidden.

Next isolated runtime gate: while the model is producing a longer,
harmless answer, dismiss the DMS popup, reopen it shortly afterward,
and check whether the same conversation is still present and the
reply has continued or completed. Inspect existing
`DMS_NATIVE_POPOUT_STATE` and
`DMS_NATIVE_WEBVIEW_CREATED/DESTROYED` markers **locally**;
do not upload raw authentication logs or secret-bearing profiles.
No code release, production shell or persistent account storage
changes are required for this test.

This result does not remove the hard blocker: the installed stock
Quickshell host has `argc=0` while the isolated patched
host has `argc=1`; the v0.1 Zen launcher remains the safe
production fallback and this PR remains Draft.

## Streaming continues across hidden native DMS popup (user-confirmed, 2026-11-10)

The user ran the prescribed authenticated, harmless test: request a
50-sentence Linux response, close the real DMS `PluginPopout` while
generation was underway, then reopen it. They reported **"ja,
funktioniert"**, confirming the response continued/persisted across
popup hide/show in this particular patched, isolated DMS experiment.

This confirms a functioning popup hide/show interaction during active
ChatGPT message generation, **as observed by the user**. No new
lifecycle trace or Chromium network log was supplied; therefore do not
claim more specific facts about WebEngineView object lifetime,
WebSocket/SSE implementation, or recovery from terminating the
Quickshell process mid-stream. Do not rely on the result as a
guarantee for arbitrary browser tabs, pending uploads or long-running
generations.

The remaining release blocker is host compatibility: the installed
Quickshell was confirmed to provide `argc=0` and must not instantiate
a `WebEngineView` without a reviewed and reversible host fix.
The successful `argc=1` test binary is a private build under `/tmp`,
**not** the system-installed process. The production Zen-v0.1 widget
remains unchanged. Native plugin mode requires explicit feature
gating, safe fallback, verified QML-module compatibility, startup
and update integration, rollback, and user approval before any
system changes.

## Final host prerequisite: installed-versus-patched Quickshell preflight

An opt-in `host_preflight.sh` now compares the installed and isolated
patched Quickshell executables without replacing anything. By default,
it reports only package identities and binary digests. With
`--probe`, it executes **only** the previously-reviewed,
WebEngine-free `QuickshellArgsProbe.qml`, separately in each host
with a six-second timeout, and emits safe argc status markers.
The optional runtime probes do not touch ChatGPT authentication.

The user-confirmed popup tests do not establish compatibility of
the *installed* host; the previously observed `argc=0` was fatal
for WebEngine. There is no sanctioned automatic upgrade/patch
mechanism yet. A correct production path must be reversible, verify
the fully featured Qt/QML host and provide safe Zen fallback under
the installed stock binary. No changes to release v0.1.0 are made.


## Confirmed installed host incompatibility and reversible launch approach (2026-11-10)

The user ran the non-destructive `host_preflight.sh --probe` on CachyOS
and reported three passing static tests. Actual host results:

- Installed `/usr/bin/quickshell`, package `quickshell 0.3.2-1.1`,
  SHA256 `7796116aa1bf0139df37d023feba9e25ac02650eca678dc2bd4d23e1f09a045f`,
  returned `DMS_HOST_INSTALLED_ARGC: ZERO_UNSAFE_FOR_WEBENGINE`.
- Private patched host
  `/tmp/dms-chatgpt-qs-v02-argc1/build-dms/src/quickshell`,
  SHA256 `63e258a5b089565b9a93feca02bce7d5dc6602e719d2c66997356643601290f4`,
  returned `DMS_HOST_PATCHED_ARGC: NONZERO_WEBENGINE_PREREQUISITE_MET`.
- No WebEngine created by this preflight; no system changes.

**Upstream launch architecture was confirmed in the DMS pinned source**:
`core/go.mod` uses `github.com/duxlabs-dev/dux-go`
`v1.6.3-0.20261104145443-699311effba8`, whose
`shellapp/env.go` invokes
`exec.CommandContext(ctx, "qs", "-p", a.configPath)` for the frontend.
This is an executable resolved via the DMS backend's **PATH**, rather than
an explicit `/usr/bin/quickshell` path. DMS normally supervises that
frontend as a child process.

**Reversible design direction:** If the user's actual DMS startup uses
a systemd user service, a *service-scoped* PATH override could select a
private `qs` launcher instead of changing `/usr/bin/quickshell`.
If DMS is Niri-started, a Niri startup wrapper could provide the
equivalent process-scoped PATH. This is only an architecture finding,
**not an applied change**. The actual startup method, executable
`qs` resolution, private binary relocation/QML module availability,
full DMS startup/rollback and Qt version drift still need checking.
Do not put a replacement `qs` on the general interactive PATH or
replace the pacman-owned binary. No changes to the user's DMS process,
systemd units, Niri config, package database or production ChatGPT
v0.1 plugin have been made.


## Actual CachyOS DMS frontend startup method observed (2026-11-10)

The user provided read-only host diagnostics:

```text
command -v qs      -> /usr/bin/qs
readlink -f qs     -> /usr/bin/quickshell
systemd --user dms.service: ActiveState=active
FragmentPath=/usr/lib/systemd/user/dms.service
ps -C dms,quickshell -o pid,ppid,comm: only PID 1254, comm dms (PPID 1047)
```

This confirms the active DMS **systemd user service** and
`/usr/bin/qs` symlink to the stock `argc=0` host. It does **not**
confirm the child frontend's current PID or executable: `ps -C`
matches kernel comm names, which may not match `qs`, and the UI
could be absent/restarting. Do not infer the frontend state from
that narrow process list.

**Proposed reversible integration, not yet implemented:** a service-
scoped `PATH` prefix pointing to a dedicated `qs` wrapper that
execs a *permanently installed*, validated private Quickshell build.
This must be scoped exclusively to `dms.service` via an override
under the user's systemd config, leaving `/usr/bin/quickshell`
and the pacman-owned `/usr/bin/qs` untouched. The wrapper should
use a stable absolute binary path, and no auto-update should
silently replace it. Setting PATH for the DMS backend also affects
its subprocesses, so the prefix must be narrow and preserve the
existing PATH entries. Avoid copying only the compiled binary
without checking linked QML modules, library loading, relocation,
and installed Qt version compatibility.

**Before any service or plugin change**, inspect:
`systemctl --user show dms.service -p MainPID -p ExecStart
-p FragmentPath -p DropInPaths -p ControlGroup`
and `systemctl --user status dms.service --no-pager --lines=0`.
Then assess whether DMS currently has a supervised `qs` frontend,
whether a service override already exists, and a rollback that
removes only the newly created override followed by a controlled
restart. Changes require explicit user approval because restarting
DMS can briefly remove desktop panels, launchers and polkit prompts.
Keep the Zen v0.1 production widget until post-switch checks pass.


## Verified live DMS systemd cgroup before service-scoped qs override (2026-11-10)

Read-only user diagnostics confirm an active `dms.service`
(`/usr/lib/systemd/user/dms.service`, no drop-in overrides), main
DMS process PID 1254 (`/usr/bin/dms run --session`), and its
supervised frontend `qs -p /run/user/1000/dms-shell/9483c24f0a364ed0`
PID 1363 in the same service cgroup. Other child processes include
the user's Bitwarden-vault helper, systemd-inhibit, gdbus and cava;
a service restart may interrupt them.

This confirms the service-scoped PATH-selection strategy can target
the DMS frontend without altering the pacman-owned quickshell/qs
binaries. No override has been applied. Remaining checks: backend's
actual PATH, the isolated build's dynamic linkage / RPATH, QML
module relocation and startup behavior, and a prepared rollback.
A DMS restart is a significant external action and must be explicitly
approved after the candidate is installed and verified.

The already authenticated native experiment is **isolated**, not
enabled as a normal DMS plugin. Never feed the production host a
WebEngineView while stock quickshell still has argc=0.

## Relocation prerequisite before service-scoped private qs deployment

The user confirmed that live PID 1363 resolves to
`/usr/bin/quickshell`; the DMS backend's PATH includes
`/usr/local/sbin:/usr/local/bin:/usr/bin:...`. The patched
`build-dms/src/quickshell` had no missing libraries in `ldd`,
and ELF RUNPATH `[::::::::::::::::::::::]`, which has no explicit
absolute build-tree path. Neither fact alone proves Qt/QML module
relocatability or lasting stability.

A new explicit offline `--relocation-check` mode stages a verified
bit-for-bit copy of the patched private binary in
`/tmp/dms-chatgpt-native-v02/portable-host/quickshell`
and runs the **real copied DMS PluginPopout** in the previously
isolated environment. It does **not** use the authenticated test
profile, install an executable into general PATH, restart the
live DMS service or modify package-managed files.

The Quickshell build had `INSTALL_QMLDIR`/
`INSTALL_QML_PREFIX` unset and Qt QML output in the build tree.
A copied executable may still depend on missing QML module
artifacts. Only runtime validation can establish whether this
specific host can be relocated in its present environment.
A persistent, versioned private installation and user-systemd
drop-in plus rollback remain separate, later approval gates.

## Versioned user-owned QS host staged only after user confirmation

The user confirmed the complete relocated-copy offline DMS popup test
was successful. The feature branch now has
`stage_private_host.sh --stage`, which accepts **only** the exact
previously tested patched build SHA256 and pinned commit, requires
`patchelf`, creates a private versioned host under
`~/.local/share/dms-chatgpt-native-host/9b0f339-argc1-v01/`,
and **removes the unsafe empty-directory ELF RUNPATH from a copy**.
It checks linked-library resolution after patching and fails closed
on divergent existing versioned files. It never changes /usr/bin,
pacman, DMS systemd unit, Niri config, or the logged-in WebEngine
test profile.

The same isolated `run_native_popout.sh` supports the new exact
offline-only flag `--staged-host-check`, which invokes the staged
`bin/qs` shim, retains the old DMS harness and local HTML fixture,
and does **not** connect to the user's running DMS. Static source and
`bash -n` tests are in `test_native_stage_host.py`.
**Not yet runtime-tested** on the user's CachyOS host: successful
staging, the cleaned-RUNPATH binary boot, and the full DMS popup
through the versioned private shim.

A future **separate** approved change can add a DMS-service-specific
PATH drop-in and a full native/Zen-safe plugin mode once the staged
host is validated. Do not replace the Pacman-owned `qs` symlink or
`quickshell`, and preserve a rollback that requires no interactive
launcher/polkit UI.
