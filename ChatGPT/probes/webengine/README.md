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
