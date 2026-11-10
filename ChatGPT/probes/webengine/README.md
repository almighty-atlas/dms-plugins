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
