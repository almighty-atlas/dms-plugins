# 0.2.0 verification record

## Executed in the development environment

Reference: DMS tag `v1.6.3`, commit
`4a87e8227daf0840b3376fd5e7f891f5900165a6`, matching dank-qml-common submodule
`1ae722232da7110d26cd2c355b6615e078e94197`.
Tools: Qt 6.12.0, yt-dlp 2026.10.21, mpv 0.41.0. No dependency installation.

| Check | Result |
| --- | --- |
| `python3 -m unittest discover -s YouTube/tests -v` | 7 passed; includes Qt suite, mock-host lint, manifest/registry and real CLI tests |
| `QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input YouTube/tests/qml -import YouTube/tests/imports` | 25 passed, zero failed/skipped; includes test initialization/cleanup |
| `python3 YouTube/tests/lint_dms.py /tmp/dms-youtube-reference` | All production QML, including Widget/Settings, clean against DMS 1.6.3 source interfaces |
| `python3 YouTube/tests/runtime_smoke.py /tmp/dms-youtube-reference` | Real Quickshell Process and matching DMS Proc: search fixture, JSON results, audio launch, 127 error; completion marker passed |
| Real `mpv` local WAV test (Python suite) | Audio options accepted; two input arguments played in order, exit 0, null audio/video outputs |
| `/usr/bin/env yt-dlp --ignore-config --version` | Exit 0 |
| `/usr/bin/env` missing-program fixture | Exit 127 |
| Actual `ytsearch10:linux` CLI request | Exit 1: DNS resolution of `www.youtube.com` failed; no live results verified |
| Qt 6 `qmlformat` on production QML and Qt test cases | Completed |
| `git diff --check` | Passed |

Qt tests execute the production JavaScript, controller and panel. They cover
normal/missing/duplicate/broken/Unicode metadata, null durations, positive
Shorts/live detection, safe IDs/argument arrays, state bounds and migration,
shared state synchronization, privacy switches, requests/coalescing/stale replies,
timeouts, retry, player defaults/errors, keyboard typing/navigation/bookmarks/
queue, reopen focus, empty views, small panel sizes, themes, scrolling and retained
selection. Expected `youtubeSearch:` warnings exercise errors deliberately.
They do not contact YouTube or load thumbnails.

The Qt test host mocks DMS service/widgets and Quickshell processes. Its minimal
PopoutComponent models the documented DMS 1.6.3 interface for layout testing. The separate
runtime smoke uses **real** Quickshell and DMS Proc with local yt-dlp/mpv executable
fixtures; it does not verify YouTube or real mpv streaming. Its offscreen window
and sandbox IPC warnings are environmental (window masks / local IPC socket),
not successful compositor integration. The lint helper builds temporary qmldir
metadata because Quickshell normally generates its own `qs` module namespace.

## Not verified here

- Installed DMS 1.6.3 startup and popout lifecycle on the user's Hyprland desktop.
- Live YouTube results, source metadata completeness, thumbnails, rate-limit
  responses and mpv YouTube video/audio streaming.
- Real browser opening and audio output, screen reader behavior and actual tab
  order of native DMS action buttons.
- Physical small/multiple monitors, vertical bars, light/dark native themes,
  opaque surrounding DMS popup decorations and compositor positioning.
- On-disk persistence across a real DMS restart/crash; mocked service round-trips
  and state reconstruction pass, while DMS owns the actual filesystem writer.
- DMS plugin update/reload and Dux Shell 2.0 runtime compatibility.

These are outstanding acceptance checks, not claims that 0.2.0 passed production
acceptance. Do not merge solely on the offline test results.

## Target-desktop acceptance procedure

1. Install the feature branch in a test plugin directory, enable `youtubeSearch`,
   and open Settings → Plugins → YouTube Search. Check all controls and choose
   automatic player selection. Preserve any existing plugin state before tests.
2. Open the popout from horizontal and vertical bars. Confirm the search field
   receives focus on first open and every reopen; type `mq linux` without invoking
   bookmark/queue actions. Enter starts one search; verify titles, channels,
   durations and failed-thumbnail fallbacks.
3. Use Down/Up, Enter, Ctrl+Enter, M, Q, Ctrl+K, Tab/Shift+Tab and Escape. Confirm
   visible focus, scrolling, default player, and audio without a video window.
4. Load more through 20/30/40/50 requested entries. Confirm distinct IDs, selection
   retention and the final limit indication. Test loaded-candidate length filters
   and positive Shorts/live filters; absent metadata must not be guessed.
5. Bookmark several videos, enqueue three, move the third up twice, and play the
   queue in video/audio modes. Confirm order and that playing retains the queue.
   Check browser as default too. Close players before testing the process limit.
6. Open both histories. Repeat/delete a query and relaunch/remove a video. Disable
   history recording and confirm new actions do not appear; old entries remain
   until explicitly cleared. Re-enable recording and test separate/all clear.
7. Use two widget instances/screens: add/remove saved videos and move/remove queue
   entries in each. Confirm immediate consistency. Wait at least two seconds for
   DMS's state writer, restart DMS manually and verify lists, order and settings.
8. Exercise empty/201-character queries, offline search, retries, rapid different
   queries, popout close/reopen during search and plugin reload during search.
   In an isolated test environment, remove mpv/yt-dlp from the shell PATH and
   confirm 127 errors and browser fallback. Do not rename system programs.
9. Test long titles/queries, a small usable screen, expanded filters, light/dark
   themes and unavailable thumbnails. Confirm internal scrolling and opaque
   surfaces without overflow. Inspect DMS logs for new QML warnings or callbacks
   touching destroyed components.
10. Update with `dms plugins update`, then
    `dms ipc call plugins reload youtubeSearch`. Confirm 0.2.0, Settings discovery
    and retained data. Record whether a full DMS restart is needed for newly added
    QML files. Repeat core checks on Dux 2.0 before claiming compatibility.
