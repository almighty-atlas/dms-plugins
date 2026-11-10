# v0.2: native WebView research and implementation gate

**Not implemented or enabled in v0.1.** Keep the isolated/regular browser launcher
permanently available. Research date: 2026-11-10. No login or graphical WebEngine
test was performed on tiny02; conclusions below distinguish source/API evidence
from desktop experiments still needed.

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
