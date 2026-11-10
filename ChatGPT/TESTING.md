# Verification record and desktop acceptance

Date: 2026-11-10. Host: tiny02/OpenCode, headless Linux, Python 3.14. No DMS,
Quickshell, Zen, Niri, Qt `qmllint` or `qmltestrunner` installed. **No desktop
components were installed to simulate graphical verification.** Developer-only
tree-sitter/jsonschema/tinycss2 were installed in an external Python venv.

## Executed on tiny02

```sh
python3 -m unittest discover -s ChatGPT/tests -p 'test_*.py' -v
bash -n ChatGPT/scripts/launch.sh
python3 -m compileall -q ChatGPT/scripts ChatGPT/tests
git diff --check
```

Result: **46 regression tests passed**, Bash syntax passed, Python compilation
passed, whitespace/diff check passed. Regression coverage:

- Manifest/registry ID, name, dependencies, relative files, permissions, version
  constraint, monorepo path and scoped Niri rule.
- Browser executable candidates/missing binary, safe array arguments, sanitized
  remote/profile environment, no shell interpolation.
- Real Python launcher subprocesses with **fake local executable Zen/Niri**:
  first start, second focus, parallel cross-process clicks, browser nonzero exit,
  failed focus, recovery/retry. No real browser or compositor used.
- Identity: exact app-ID and verified-profile PID fallback, never title alone;
  no second launch for an already-running profile with no window.
- Window readiness vs exit 0, startup deadline, multi-output sizing/clamping,
  explicit target ID, missing IPC and focus failure handling.
- True DMS `colors.dark/light` schema, active Theme snapshots, light defaults,
  legacy cache selection, malformed/empty input, CSS injection rejection, exact
  HTTPS scope, conservative selectors, theme disable/re-enable/idempotence,
  last-snapshot reuse, corrupt snapshot fallback.
- Private profile paths and permissions, known-scaffold migration, symlink
  refusal, preservation of unrelated preferences, no background profile creation.
- Local install/reinstall/update/uninstall with temporary directories,
  preservation of browser-data fixture, refusal to overwrite foreign installs or
  duplicate the same plugin ID under another directory name.
- Smoke-test report permissions/allowlisted fields, explicit headless failure,
  visual checks marked SKIP without an interactive tester.

The complete 46-test suite also passed **10 consecutive runs (460 test
executions)**. A race found in the fake compositor fixture (reading its temporary
window list during a non-atomic write) was fixed with atomic publication, matching
Niri's complete JSON replies; it was not hidden by weakening launcher validation.

The real `desktop_smoke.py --non-interactive` entry point was also invoked on
tiny02 with isolated temporary state: it passed the offline suite, correctly
reported the missing Wayland/Niri session as FAIL, exited 1, and wrote only the
sanitized diagnostic fields. This verifies the headless guard, **not** desktop
behavior.

Developer validation was also executed:

```sh
<dev-venv>/bin/python ChatGPT/tests/validate_sources.py <dux-shell-checkout> \
  --qml-grammar <compiled-tree-sitter-qmljs.so>
```

**All six reported checks passed**: both production QML files parsed without
syntax errors; manifest validated using the upstream **Draft7 JSON schema**;
referenced native `PluginComponent`/`Theme`/`Proc`/setting/icon/toast interfaces
were checked against actual upstream source; light and dark CSS were parsed
recursively using tinycss2, with every rule inside the exact origin scope.

This is **QML syntax and source-contract verification, not Qt type checking or
real-shell execution**. No `qmllint`/QML runtime pass is claimed. Initial attempts
to build the Python qmljs binding failed because the host lacks Python C headers;
the same grammar's parser/scanner were compiled as a local shared library and
loaded by tree-sitter instead. No plugin runtime dependency resulted.

Reproduction with normal development headers:

```sh
python3 -m venv .venv
.venv/bin/pip install -r ChatGPT/tests/requirements-dev.txt
git clone --recurse-submodules https://github.com/duxlabs-dev/dux-shell.git /path/to/dux-shell
.venv/bin/python ChatGPT/tests/validate_sources.py /path/to/dux-shell
```

The optional `tests/github-workflow.yml.example` pins the inspected Dux revision
and runs the same offline suite, parser/schema/contracts and CSS checks. It is
**not active**: the authorized GitHub token rejected adding `.github/workflows/`
without the separate `workflow` scope. No credentials/scopes were changed. A
maintainer can later copy the template to `.github/workflows/chatgpt.yml` using
workflow-authorized access. **No GitHub Actions run/pass is claimed.** Local
verification above was actually executed and does not depend on CI activation.

Unrelated-plugin regression command also executed:

```sh
python3 -m unittest discover -s YouTube/tests -p 'test_*.py' -v
```

Result: **3 passed, 4 skipped** (mpv, yt-dlp, Qt qmllint and Qt qmltestrunner
unavailable). No YouTube/GW2 production code was changed.

## Inspected official sources

- Dux Shell `3548daab9a7595b6dff52a79eda4cccd3697fdd6`, including full plugin
  development documentation, manifest schema, `PluginComponent`, setting types,
  `Proc`, `Theme`, `ToastService`, `PluginService` IPC and Go registry/monorepo
  installation implementation. Matching dux-qml-common submodule:
  `0877466a25b8e191a865bf75d0e500de6351ae04`.
- [Official plugin documentation](https://github.com/duxlabs-dev/dux-shell/blob/3548daab9a7595b6dff52a79eda4cccd3697fdd6/quickshell/PLUGINS/README.md)
  and [registry contribution format](https://github.com/duxlabs-dev/dux-plugin-registry/blob/master/CONTRIBUTING.md)
  (old AvengeMedia registry URL redirects upstream). A custom registry does not
  need a fabricated screenshot. No submission to the central registry was made.
- Zen source `142c13830dda7065f7fb0991eda1ec89650bf54b`, compact-mode preferences
  and implementation, plus [Compact Mode manual](https://docs.zen-browser.app/user-manual/compact-mode)
  and [reported --name caveat](https://github.com/zen-browser/desktop/issues/7576).
  Firefox GTK launch/window source reviewed to avoid assuming X11 `--class` and
  Wayland app-ID are interchangeable. Actual installed Zen flags still need the
  desktop probe; supporting `--name` in help is not proof it is honored.
- Niri source `5935130029941411d9c00784a974a77f244ea3b5`: window rules and
  `niri-ipc/src/lib.rs` action/query types. Explicit-ID floating, width/height,
  position and monitor actions, logical output geometry.
- Public `https://chatgpt.com/` HTML and its publicly referenced stylesheet:
  lightweight-web semantic composer/sidebar attributes observed; generated
  StyleX class/color hashes deliberately not used. This is **not** an
  authenticated session/visual test. No cookies/login data used or saved.
  Direct urllib stylesheet access returned 403; no bypass was attempted.
  The standard read-only web fetch could retrieve the public stylesheet.
- Quickshell/Qt WebEngine evidence and versions: [WEBVIEW.md](WEBVIEW.md).

## Run on CachyOS

From a feature-branch checkout:

```sh
python3 ChatGPT/tests/desktop_smoke.py --install
```

Or use the single clone-and-test command in README.md. The script installs only
a reversible symlink, runs offline tests, probes versions/session/IPC, attempts
native plugin scan/reload/status, starts/focuses ChatGPT, launches twice in
parallel and checks window identity, floating, focus, size and preservation of
normal windows. It then asks for **explicit human results** for visual/auth
checks. It does not manipulate ChatGPT DOM, type messages, read browser storage,
capture screenshots or dump compositor titles/logs. `--non-interactive` leaves
manual checks SKIP. Existing other installations are not overwritten.

Diagnostic JSON is 0600 under `${XDG_STATE_HOME:-~/.local/state}/dms-chatgpt/`.
It contains named PASS/FAIL/SKIP results and extracted numeric versions only.
Keep it locally or share it without adding private browser/shell logs.

### Required acceptance matrix (all still unverified here)

| Desktop check | Automated portion / remaining observation |
| --- | --- |
| DMS loading/settings | Scan/reload/status automated; inspect native widget + settings and relevant QML warnings |
| Horizontal/vertical bar | Click twice in both orientations; icon/text sizing and no empty popout |
| First launch | Confirm onboarding, app-ID/PID, floating and sensible size/position |
| Repeat/parallel launch | Same window ID/focus, no extra browser; script automates this |
| Close/relaunch | Quit only isolated profile normally, reopen, check login/history persistence |
| DMS reload | Reload plugin, click still focuses surviving browser; full shell logout/login remains a separate manual check |
| Login and core ChatGPT | Official login, send/receive, history, model menu, settings, test attachment |
| CSS safety | No missing controls on login/error/attachment/settings screens; theme off is reversible |
| Palette | DMS light/dark, stock/custom theme; click to prepare, isolated profile restart, compare visually |
| Narrow window | 650/760/900px: composer, navigation and dialogs usable; no clipping from plugin CSS |
| Browser chrome | Native compact mode, hover, Ctrl+L, sidebar/toolbar shortcuts, full-chrome recovery |
| Two monitors | First open on clicked output, repeat preserves position, optional follow-output moves only ChatGPT; hotplug |
| Existing profile | Normal Zen session stays intact; no plugin CSS/preferences in it; fallback behavior honestly best effort |
| Lifecycle failures | Close profile during launch, IPC outage, Zen upgrade/ignored app-ID: clear error/retry, no lock deletion |
| Registry lifecycle | **After merge** on a fresh DMS profile: registry add/install/update/uninstall, scan and enable |
| Local lifecycle | Installer tested with temp dirs; on desktop verify install/link, reload/update, disable/uninstall with profile retained |

No auto-close/kill, production-service restart, Niri edit, browser cookie access,
API usage, paid service or automatic PR merge is part of these tests.

## CachyOS desktop feedback – 2026-11-10 (manual, user-confirmed)

- DMS widget click opens and subsequently focuses the same ChatGPT window.
  Hover no longer triggers focus/launch oscillation.
- Isolated Zen login and previous ChatGPT conversations are available.
- Browser DevTools confirmed `--dms-background: #1e1e2e` is present, and
  the computed BODY background is `rgb(30, 30, 46)`.
- The actual authenticated page used `html.chatgpt-theme` with computed
  black background and a generated-ID MAIN with `rgb(0, 0, 0)`.
  No stable class was inferred from the generated class/ID.
- The new CSS override explicitly colors `html.chatgpt-theme` and its MAIN
  using the DMS background token, scoped to `https://chatgpt.com/`.
  **Visual correctness after profile restart is still unverified.**
