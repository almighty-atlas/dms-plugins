# Codex implementation handoff · ChatGPT DMS widget

## Agent selection

**Codex CLI · `gpt-6.1-sol` · reasoning `high`.** Use a stronger available model only if the client clearly supports it. Run inside a clean checkout of `almighty-atlas/dms-plugins`. This task is to make the v0.1 **browser plugin directly usable and verified**, not to build v0.2 prematurely.

## User environment & outcome

CachyOS Arch Linux, Wayland, Niri, Dux/DMS 2.0, Zen Browser. Existing DMS plugins in this monorepo. The user wants a native DankBar ChatGPT button opening an isolated, attractive, material-themed ChatGPT web-app-like floating window, with minimal browser UI, and a fallback that uses their existing Zen account.

The official `https://chatgpt.com/` must remain the actual service. The user uses their ChatGPT plan, NOT a separately billed API. Do not use undocumented auth tokens, alter request headers, bypass bot protection, or modify the user's normal browser profile without explicit consent.

## First read (required)

- `ChatGPT/README.md`, `ChatGPT/Widget.qml`, `ChatGPT/Settings.qml`, launch and theme scripts
- `ChatGPT/WEBVIEW.md`
- `YouTube/Widget.qml`, `YouTube/Settings.qml` for established repo patterns
- The **installed DMS 2.0** plugin interfaces; current upstream: https://github.com/duxlabs-dev/dux-shell/blob/master/quickshell/PLUGINS/README.md
- The installed Zen command-line behavior and Niri configuration; don't assume launch flags.

## Required work – complete all for v0.1

1. **Validate DMS plugin loading.** Check manifest against the installed version's schema; verify `PluginComponent`, direct `pillClickAction`, Quickshell.Io Process handling, styling tokens, plugin settings, horizontal and vertical pills. No runtime errors or QML warnings. Include an offscreen or real-shell smoke test if feasible.
2. **Make browser launching truly reliable.** Verify executable discovery (`zen`, `zen-browser`, etc.), `--profile`, `--no-remote` compatibility, create profile safely. Clicking twice must **focus the existing ChatGPT window rather than error or spawn unwanted duplicates**. Use Niri JSON IPC `niri msg -j windows` to identify/focus windows or a safer, tested method; avoid activating other Zen windows. Distinguish launch failure from successful spawn. Never infer success solely from backgrounding.
3. **Match DMS aesthetically.** Inspect real `~/.cache/dms/dms-colors.json` and change palette parser to match its actual schema, including light/dark preference. Keep site CSS scoped and minimal; test ChatGPT current DOM, responsiveness at ~650–900 px wide and login pages. Avoid selectors that hide controls needed for authentication. Prefer a real standalone Zen web-app mode if supported by the installed version; otherwise use a safe, reversible profile-specific userChrome.css. Do not touch existing Zen styling.
4. **Niri integration.** Find a stable window identifier for the dedicated profile and integrate an opt-in safe floating rule with ~760x860 initial size, positioned near top right. Confirm it doesn't also float normal Zen windows, and won't break multi-monitor behavior. Do not overwrite config.kdl. Include idempotent install steps and rollback.
5. **Lifecycle.** Close/relaunch, logout/login, theme update, two-click focus, missing binary, empty color cache, multiple monitors and DMS restart. Avoid idle pollers and orphaned processes. If live dynamic theme updates are feasible without a daemon, implement; otherwise document restart requirement clearly.
6. **Tests + docs + registry.** Add tests for launcher/focus logic using mocked commands, color JSON parsing and CSS stability, QML/static lint against installed DMS. Run tests and paste actual commands/results in your final report. Update `README.md` and `plugins/chatgpt-web.json` if needed. Ensure plugin can be installed using `dms plugins install chatgptWeb` after merge.

## Do not implement v0.2 in this task

Preserve `ChatGPT/WEBVIEW.md` as the scoped future plan. If you find a reliable QtWebEngine path, note it there; do not add an unverified login embedded browser.

## Definition of done

- `dms plugins install chatgptWeb` succeeds (or give precise fallback if the local registry command differs).
- DankBar shows an icon; click focuses/opens a single ChatGPT window, right account uses browser login.
- DMS color CSS visibly applies in the isolated profile and doesn't affect other sites or the main Zen profile.
- Can send and receive messages; history survives relaunch; Niri floating window is scoped correctly.
- Tests pass and no relevant runtime warnings. Document any environment limitation honestly.
- Commit the working changes to a feature branch/PR; never claim tests that were not run.

## Suggested CLI invocation

```sh
codex -m gpt-6.1-sol
```

Then choose **High** reasoning via `/model` and paste this prompt. Do not use an API key unless the user explicitly asks. No subagents are required for the scoped v0.1 task; use targeted validation and one coherent end-to-end implementation.
