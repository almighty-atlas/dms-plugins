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
