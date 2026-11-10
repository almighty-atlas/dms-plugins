# WebView phase (v0.2), gated experiment

The current version intentionally opens a **real browser**. A Qt WebEngine or WebKit view inside a native DMS/Quickshell popup is not equivalent to using ChatGPT in Zen.

Research/verify before implementing:
1. Whether the local DMS/Quickshell Qt build can load QtWebEngineQuick in a plugin without destabilizing the shell process.
2. Login flow: first-party ChatGPT login, OAuth and passkey flows, Cloudflare, cookies and refresh; never bypass security controls or scrape credentials.
3. Input: text editing, clipboard, drag/drop files, downloads, uploads, speech/microphone, context menus, keyboard shortcuts, accessibility, GPU scaling, Wayland IME.
4. Isolation: browser profile, persistence, required process sandboxing, memory usage, crash containment and security updates.
5. Lifecycle: popout closure, suspended/offscreen behavior, multiple DMS widget instances and restarts.
6. Graceful fallback: user can always switch to real Zen when WebView fails. Keep v0.1 experience intact.

Go/no-go: only offer WebView as default once login, send/receive, attachments, keyboard navigation and session persistence have been tested on the target CachyOS + Niri machine. Do not falsely claim it is already implemented.
