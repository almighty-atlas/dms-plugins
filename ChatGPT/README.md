# ChatGPT Web · DankBar plugin (v0.1.0)

A DMS 2.0 / Dux Shell widget to open the **official ChatGPT website**. It does **not** use the OpenAI API or bypass any ChatGPT subscription limits.

## What is implemented

- A horizontal/vertical native DankBar pill (click to launch, not a faux embedded chat).
- Settings: isolated Zen profile (default), existing Zen session, or system browser.
- Dedicated Zen profile under `~/.local/share/dms-chatgpt/zen-profile`. Login once in that profile.
- Optional safe userContent.css generation from `~/.cache/dms/dms-colors.json` (also supports legacy cache path).
- Optional Niri floating-window rule; manual integration required.
- Testable Python color parser and CSS generator. No network backend or API key.

## Install

Once this branch has been merged to the repository's default branch:

```sh
dms registry add atlas https://github.com/almighty-atlas/dms-plugins  # only once
dms plugins install chatgptWeb
dms ipc call plugins reload chatgptWeb
```

Alternatively, clone the repository and symlink `ChatGPT` to the plugin directory shown by DMS 2.0 (`~/.config/dms/plugins/` by default). Then enable the plugin and add it to DankBar via DMS settings.

### Browser / appearance

- **Isolated Zen (default):** Requires Zen and Python 3. Styling is generated into a dedicated Firefox-style profile. Authenticate at chatgpt.com once. Browser chrome remains visible initially.
- **Existing Zen:** Opens in your regular Zen profile and retains your existing login, but CSS is *not* automatically injected. Apply equivalent styling using a user stylesheet/extension if desired.
- **System browser:** Uses `xdg-open`; no built-in styling.

A Zen profile that is **already open** may reject a second `--no-remote --profile` launch. Reusing/focusing its window is part of the agent completion task; do not promise toggle behavior until tested. CSS changes may need a full browser restart.

For floating windows, review `niri-window-rule.kdl.example`, add a scoped rule to `~/.config/niri/config.kdl`, and validate actual app-id/title with `niri msg pick-window`. Never float all Zen windows inadvertently.

## Tests

```sh
python3 -m unittest discover -s ChatGPT/tests -p 'test_*.py' -v
bash -n ChatGPT/scripts/launch.sh
```

These test syntax and CSS generation, **not** login or a graphical integration.

## Agent handoff

See [AGENT_PROMPT.md](AGENT_PROMPT.md) for the remaining end-to-end tasks and their acceptance checks. Local Niri + DMS + Zen acceptance testing is still required. Do not call this version a verified, fully functional WebView.

## Security & scope

No network interception, credential extraction, cookie copying, ChatGPT DOM automation or proxying. The only external destination launched is `https://chatgpt.com/`. The generated CSS targets chatgpt.com and can break after a website update. Themes derive from local DMS cache with validation and fallback values.
