# v0.2 isolated Qt WebEngine probe

**Opt-in research only.** This standalone binary does not use the running DMS
process, load a website, access existing profiles or support ChatGPT login.
No production QML, plugin manifest or v0.1 launcher changes.

## 1. Read-only preflight on CachyOS

```sh
python3 ChatGPT/probes/webengine/preflight.py
```

The JSON contains installed package versions and Boolean readiness indicators,
but no usernames, local environment values or browser data. Exit status:
0 = prerequisites available, 1 = dependencies missing, 2 = sandbox override.
This does **not** prove in-process embedding in Quickshell.

## 2. Optional standalone rendering test

Only after preflight reports `READY_TO_PROBE`. Do not change security flags:

```sh
cmake -S ChatGPT/probes/webengine -B /tmp/dms-chatgpt-webengine-probe
cmake --build /tmp/dms-chatgpt-webengine-probe -j2
/tmp/dms-chatgpt-webengine-probe/dms-chatgpt-webengine-probe \
  "$PWD/ChatGPT/probes/webengine/Probe.qml"
```

A separate window should show **Qt WebEngine is rendering**, and the console
should print `DMS_WEBENGINE_PROBE_LOADED`. Close the window normally.
There are no requests to ChatGPT, no persistent WebEngine profile, no cookie
transfer and no access to the normal Zen profile. Do not use `--no-sandbox`
or `QTWEBENGINE_DISABLE_SANDBOX` to hide runtime failures.

**Interpretation:** PASS means WebEngine renders after correct initialization
in a separate executable on this machine. It is **not** evidence that the
already-running DMS/Quickshell process meets the initialization requirement.
Without upstream/host support, a native embedded popout remains blocked.

## 3. Optional ChatGPT page-load check (online, **no login**)

After the offline Qt renderer works, you can use the **same standalone**
executable to test whether Qt WebEngine is able to display the official
ChatGPT landing page at all:

```sh
/tmp/dms-chatgpt-webengine-build/dms-chatgpt-webengine-probe \
  /tmp/dms-chatgpt-webview-probe/ChatGPT/probes/webengine/ChatGPTPageProbe.qml
```

**This step makes real network requests to chatgpt.com and its normal page
dependencies.** It starts only when explicitly invoked, never as part of the
preflight, existing offline test, or DMS. The temporary Qt profile has
`offTheRecord: true` and is not your Zen login.

For this first test **do not enter credentials or attempt a login**. Verify
only whether the ChatGPT landing page appears, or whether you see an error,
blank view, or unsupported-browser message. Fixed diagnostic markers are
`DMS_CHATGPT_PAGE_LOAD_SUCCEEDED` and `DMS_CHATGPT_PAGE_LOAD_FAILED`; the
load-succeeded marker alone does not prove full ChatGPT compatibility.
The page may load its own third-party resources. Close the window after
inspection.

Neither this nor the successful offline test proves that a WebEngineView
can be embedded inside the already-running Quickshell process.

## 4. Separate Quickshell argv preflight (safe, no WebEngine)

Quickshell upstream issues [#1393](https://github.com/quickshell-mirror/quickshell/issues/1393)
and [#1412](https://github.com/quickshell-mirror/quickshell/issues/1412)
report that **Quickshell 0.3.2** constructs `QGuiApplication` with
`argc = 0`. Qt WebEngine's Chromium implementation may then abort
on missing program name. The proposed upstream fix passes `argc = 1`
instead, without forwarding all Quickshell CLI options to Qt.

We can measure this **without creating any WebEngineView** or touching
the running DMS instance. This QML starts as an independent Quickshell
configuration/process:

```sh
timeout --signal=TERM 5s quickshell --path \
  /tmp/dms-chatgpt-webview-probe/ChatGPT/probes/webengine/QuickshellArgsProbe.qml
```

`timeout` ordinarily exits with status **124** here because the test config
has no window and deliberately stays running until the five-second timeout.
It stops only the separately launched probe process, not your existing DMS.
The two `DMS_QS_...` markers, not the timeout exit code, are the result.

If your binary is named `qs` instead, replace `quickshell` with `qs`.
The script emits only `DMS_QS_ARGUMENT_COUNT=<N>` and the fixed marker
`DMS_QS_ARGC_ZERO` or `DMS_QS_ARGC_NONZERO`, then remains idle until the wrapper timeout ends it. It **never prints arguments**, imports WebEngine, loads a website, or
changes a configuration. A zero count supports the upstream diagnosis.
A nonzero count means the specific binary differs from the reported
build; further investigation would be needed before attempting embedding.

Even with a nonzero count, early WebEngine/graphics initialization and
all login/profile/permission gates remain unverified. Do not load the
WebEngineView into the live DMS shell or modify installed Quickshell
without a separately reviewed, supported fix.

## 5. Separate pinned Quickshell `argc=1` experiment (opt-in)

**Do not replace the installed Quickshell or load WebEngine inside DMS.**
On the target CachyOS system, `cli11` is now installed and the stock
Quickshell 0.3.2 argv probe confirmed `DMS_QS_ARGC_ZERO`.

From the v0.2 feature-branch checkout, first check/build ONLY a separate
Quickshell source copy:

```sh
bash ChatGPT/probes/webengine/prepare_quickshell.sh
```

The helper clones the upstream source at pinned commit
`9b0f339b19057f4731bf3b48293307d7ef241671`,
refuses unexpected upstream changes, and modifies only
`src/launch/launch.cpp` in its `/tmp` copy. The one-line source change
sets `auto qArgC = 1;` instead of `0;`. It runs a reduced CMake configure,
with optional Quickshell Wayland/service modules disabled only for this
test; Qt Quick's own Wayland QPA plugin remains available.
This is a source experiment, **not** a compatible replacement DMS build.

If configure succeeds:

```sh
cmake --build /tmp/dms-chatgpt-qs-v02-argc1/build -j2
```

Then check the patched binary's argv without WebEngine, before trying
a renderer:

```sh
timeout --signal=TERM 5s \
  /tmp/dms-chatgpt-qs-v02-argc1/build/src/quickshell --path \
  /tmp/dms-chatgpt-webview-probe/ChatGPT/probes/webengine/QuickshellArgsProbe.qml
```

Expected: `DMS_QS_ARGC_NONZERO`. If it reports ZERO, stop. A `timeout`
exit status 124 is normal because the diagnostic stays idle until timeout.

Only if the argv probe reports NONZERO, use the **separate patched binary**:

```sh
timeout --signal=TERM 15s \
  /tmp/dms-chatgpt-qs-v02-argc1/build/src/quickshell --path \
  /tmp/dms-chatgpt-webview-probe/ChatGPT/probes/webengine/QuickshellWebEngineProbe.qml
```

Expected: an independent 640×420 window rendering local HTML, and
`DMS_PATCHED_QS_WEBENGINE_LOADED`. No ChatGPT network traffic, browser
credentials or persistent storage are involved. This step **passed on the user's desktop on 2026-11-10**: a screenshot\nconfirmed the rendered local HTML. It does not prove production DMS compatibility.

## 6. Patched Quickshell + ChatGPT page-load probe (online, no login)

**Preconditions verified on 2026-11-10:** the isolated Quickshell build
completed (`[276/276] Linking CXX executable src/quickshell`), its argv probe
reported `DMS_QS_ARGUMENT_COUNT=1`, and its **offline** WebEngineView
rendered local HTML (user screenshot).

To check the next gate, use **only the patched isolated executable** with
the separate online QML config. Do not execute it with stock `quickshell`
or inside the DMS session:

```sh
timeout --signal=TERM 25s \
  /tmp/dms-chatgpt-qs-v02-argc1/build/src/quickshell --path \
  /tmp/dms-chatgpt-webview-probe/ChatGPT/probes/webengine/QuickshellChatGPTPageProbe.qml
```

This explicitly requests the public `https://chatgpt.com/` landing page
and its ordinary dependencies. It uses a separate `WebEngineProfile`
with `offTheRecord: true`, does not read Zen cookies or DMS credentials,
and makes no changes to the production plugin. **Do not enter credentials,
send messages, or try to log in during this test.** Take a screenshot to
verify visible contents; `DMS_PATCHED_QS_CHATGPT_PAGE_LOAD_SUCCEEDED`
merely indicates a page navigation succeeded. A shell crash or blank
screen is a FAIL, not a cue to run it inside production DMS.

Even a successful result proves only public page rendering inside an
independent patched Quickshell process. DMS popout lifecycle, focus, browser
permissions, persistent account login, and an upstream-supported Quickshell
binary remain separate release gates.

## 7. Wayland layer-shell popout compatibility (offline, opt-in)

The preceding patched Quickshell **ChatGPT page-load test passed** on
2026-11-10: user screenshot showed the public ChatGPT landing page in a
separate `FloatingWindow`. This proves the web renderer, not the DMS
popout's Wayland layer surface.

DMS's native `DPopout` can use a layer-shell-based window; a working
`FloatingWindow` therefore does **not** yet prove focus or visibility in
a DMS popout. We next build the **same already-patched private Quickshell
source**, but with `WAYLAND=ON` and `WAYLAND_WLR_LAYERSHELL=ON`, in a
**separate** `/tmp/dms-chatgpt-qs-v02-argc1/build-layer` directory:

```sh
bash ChatGPT/probes/webengine/prepare_quickshell_layershell.sh
```

The script verifies the pinned upstream commit, the one-line `argc=1`
patch, and a clean source diff apart from that line. The CMake step does
not build, install or launch anything. If missing Wayland development
files cause failure, inspect the first `Could NOT find` or CMake error.
Do **not** disable a sandbox or modify the installed system Quickshell.

Once configured, build separately:

```sh
cmake --build /tmp/dms-chatgpt-qs-v02-argc1/build-layer -j2
```

Then test the Wayland layer-shell QML **only in the patched binary**:

```sh
timeout --signal=TERM 40s \
  /tmp/dms-chatgpt-qs-v02-argc1/build-layer/src/quickshell --path \
  /tmp/dms-chatgpt-webview-probe/ChatGPT/probes/webengine/QuickshellLayerShellProbe.qml
```

It opens an anchored overlay (not a real DMS popout), displays **offline**
HTML with marker `DMS_LAYERSHELL_WEBENGINE_LOADED`, and offers an ordinary
HTML text input. Click inside the input and type a harmless word like
`test` to check keyboard focus. **No accounts, login or network.** The
separate process is terminated by `timeout`; do not run the test with
the system-installed Quickshell binary, which is confirmed `argc=0`.
If the layer-shell surface doesn't render or cannot receive keyboard
input, stop and diagnose before attempting any native DMS integration.
Even success proves only an isolated panel-like layer surface, not the
actual DMS plugin's animation, popup-manager or lifecycle.
