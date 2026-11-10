#!/usr/bin/env python3
"""Bounded launch/focus operation, not a resident service. Niri verifies isolated windows."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import time

from runtime import Failure, atomic_write, data_dir, locked, read_json
import theme_sync

APP_ID = "dms-chatgpt"
URL = "https://chatgpt.com/"
ZEN_NAMES = ("zen-browser", "zen", "zen-browser-bin", "zen-bin")


def find_zen():
    for name in ZEN_NAMES:
        if executable := shutil.which(name):
            return executable
    raise Failure("Zen Browser fehlt im DMS-PATH (zen-browser, zen, zen-browser-bin, zen-bin).")


def command(args, timeout=4):
    try:
        result = subprocess.run(args, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                                stderr=subprocess.DEVNULL, text=True, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired):
        raise Failure("Lokaler Befehl nicht verfügbar oder Zeitlimit erreicht.") from None
    if result.returncode:
        raise Failure("Lokaler Befehl fehlgeschlagen; Niri-/Zen-Version und laufende Sitzung prüfen.")
    return result.stdout


def niri_query(query):
    try:
        payload = json.loads(command(["niri", "msg", "-j", query]))
    except ValueError:
        raise Failure("Niri lieferte ungültiges JSON.") from None
    expected = dict if query == "outputs" else list
    if not isinstance(payload, expected):
        raise Failure("Niri-IPC-Schnittstelle unerwartet.")
    records = payload.values() if isinstance(payload, dict) else payload
    if any(not isinstance(record, dict) for record in records):
        raise Failure("Niri-IPC-Datensätze unerwartet.")
    if query == "outputs" and any(record.get("logical") is not None and
                                  not isinstance(record["logical"], dict) for record in payload.values()):
        raise Failure("Niri-Monitorgeometrie unerwartet.")
    return payload


def action(name, window_id, *args):
    if not isinstance(window_id, int) or isinstance(window_id, bool) or window_id < 0:
        raise Failure("Ungültige Niri-Fensterkennung.")
    command(["niri", "msg", "action", name, "--id", str(window_id), *map(str, args)])


def choose_window(windows, profile_pids=()):
    matches = [w for w in windows if isinstance(w, dict) and
               (w.get("app_id") == APP_ID or w.get("pid") in profile_pids)]
    # Prefer the main ChatGPT tab over an authentication popup; never use title alone as identity.
    return next((w for w in matches if "chatgpt" in str(w.get("title", "")).lower()),
                next((w for w in matches if w.get("is_focused")), matches[0] if matches else None))


def profile_processes(profile, proc_root=Path("/proc")):
    """Only inspect command-line arguments, never prefs, history, cookies or browser logs."""
    result = []
    for process in proc_root.glob("[0-9]*"):
        try:
            # Narrow before reading arguments: don't inspect unrelated services'
            # command lines, which could contain secrets passed by their owners.
            if process.stat().st_uid != os.getuid():
                continue
            name = (process / "comm").read_text().strip().lower()
            if name not in ZEN_NAMES:
                continue
            args = (process / "cmdline").read_bytes().split(b"\0")
            if os.fsencode(profile) in args and any(a in args for a in (b"--profile", b"-profile")):
                result.append(int(process.name))
        except (OSError, ValueError):
            pass
    return result


def focus(window, output="", move=False):
    if move and output:
        outputs = niri_query("outputs")
        if output not in outputs:
            raise Failure("DankBar-Monitor ist nicht mehr verfügbar; erneut klicken.")
        action("move-window-to-monitor", window["id"], "--", output)
    action("focus-window", window["id"])


def arrange(window, output, edge):
    outputs = niri_query("outputs")
    workspaces = niri_query("workspaces")
    current = next((w.get("output") for w in workspaces if w.get("id") == window.get("workspace_id")), None)
    target = output or current
    logical = outputs.get(target, {}).get("logical") or {}
    width = min(760, max(320, int(logical.get("width", 900)) - 48))
    height = min(860, max(320, int(logical.get("height", 1000)) - 96))
    action("move-window-to-floating", window["id"])
    if output:
        if output not in outputs:
            raise Failure("DankBar-Monitor wurde getrennt. Fenster bleibt auf aktuellem Monitor.")
        action("move-window-to-monitor", window["id"], "--", output)
    action("set-window-width", window["id"], width)
    action("set-window-height", window["id"], height)
    x = 24 if edge == "left" else max(24, int(logical.get("width", 900)) - width - 24)
    y = max(24, int(logical.get("height", 1000)) - height - 72) if edge == "bottom" else 72
    action("move-floating-window", window["id"], "--x", x, "--y", y)
    action("focus-window", window["id"])


def spawn(args):
    env = os.environ.copy()
    env["MOZ_ENABLE_WAYLAND"] = "1"
    # Inherited remote/profile overrides must not redirect a dedicated launch.
    for key in ("MOZ_NO_REMOTE", "MOZ_NEW_INSTANCE", "MOZ_PROFILE", "XRE_PROFILE_PATH",
                "XRE_PROFILE_LOCAL_PATH", "MOZ_HEADLESS"):
        env.pop(key, None)
    try:
        return subprocess.Popen(args, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                                stderr=subprocess.DEVNULL, start_new_session=True,
                                close_fds=True, env=env)
    except OSError:
        raise Failure("Browser gefunden, aber nicht ausführbar.") from None


def launch(args, timeout=20):
    with locked():
        if args.mode == "isolated":
            # Fail closed without working compositor IPC: never blindly start a second profile.
            windows = niri_query("windows")
            zen = find_zen()
            palette = json.loads(args.palette) if args.palette else None
            theme_sync.sync(palette, args.theme == "1", not args.full_chrome)
            profile = theme_sync.profile_path()
            pids = profile_processes(profile)
            if window := choose_window(windows, pids):
                focus(window, args.output, args.follow_output)
                return {"status": "focused", "window_id": window["id"]}
            if pids:
                raise Failure("Isoliertes Zen läuft ohne erkanntes Fenster. Browserstart abwarten oder dieses Profil regulär beenden; keine Profilsperren löschen.")
            help_text = command([zen, "--help"])
            if "--name" not in help_text and "-name" not in help_text:
                raise Failure("Zen unterstützt --name nicht. Bestehende Sitzung als Browsermodus wählen.")
            process = spawn([zen, "--no-remote", "--profile", str(profile), "--name", APP_ID,
                             "--new-window", URL])
            deadline = time.monotonic() + timeout
            while time.monotonic() < deadline:
                windows = niri_query("windows")
                if window := choose_window(windows, profile_processes(profile)):
                    warning = ("Zen ignoriert --name. Fenster sicher über die isolierte Profil-PID erkannt; die optionale app-id-Regel greift nicht."
                               if window.get("app_id") != APP_ID else "")
                    try:
                        arrange(window, args.output, args.edge)
                    except Failure:
                        return {"status": "opened", "window_id": window["id"],
                                "warning": warning + " Fenster erkannt, Positionierung fehlgeschlagen. Niri-Version/Monitor prüfen; Fenster manuell verschieben."}
                    result = {"status": "opened", "window_id": window["id"]}
                    if warning:
                        result["warning"] = warning
                    return result
                code = process.poll()
                if code is not None and code != 0:
                    raise Failure("Zen wurde beendet, ohne ein dediziertes Fenster bereitzustellen. Installation/Profil prüfen.")
                time.sleep(0.2)
            raise Failure("Nach 20 Sekunden kein Fenster mit app-id dms-chatgpt. Zen/Onboarding prüfen (niri msg pick-window). Kein weiterer Start bei laufendem Profil.")

        # Optional fallbacks: never modify or theme the normal browser profile.
        can_query = bool(shutil.which("niri") and os.environ.get("NIRI_SOCKET"))
        windows = niri_query("windows") if can_query else []
        state_path = data_dir() / (args.mode + "-window.json")
        saved = read_json(state_path)
        for window in windows:
            if (isinstance(saved, dict) and window.get("id") == saved.get("id") and
                    window.get("pid") == saved.get("pid") and window.get("pid") is not None and
                    window.get("app_id") == saved.get("app_id") and
                    "chatgpt" in str(window.get("title", "")).lower()):
                focus(window)
                return {"status": "focused", "window_id": window["id"]}
        argv = [find_zen(), "--new-window", URL] if args.mode == "existing" else ["xdg-open", URL]
        if not shutil.which(argv[0]):
            raise Failure("xdg-open ist nicht installiert.")
        process = spawn(argv)
        deadline = time.monotonic() + (timeout if can_query else 1)
        old_ids = {w.get("id") for w in windows}
        while time.monotonic() < deadline:
            if can_query:
                for window in niri_query("windows"):
                    if window.get("id") not in old_ids and "chatgpt" in str(window.get("title", "")).lower():
                        atomic_write(state_path, json.dumps({k: window.get(k) for k in ("id", "pid", "app_id")}))
                        return {"status": "opened", "window_id": window["id"]}
            code = process.poll()
            if code is not None and code != 0:
                raise Failure("Browser-Aufruf fehlgeschlagen; reguläre Sitzung/PATH prüfen.")
            if not can_query and code == 0:
                break
            time.sleep(0.2)
        return {"status": "requested", "warning": "An Browser übergeben; Fenster/Fokus nicht bestätigt. Strikte Einzelfenster-Garantie nur im isolierten Niri-Modus."}


def parser():
    result = argparse.ArgumentParser(description=__doc__)
    result.add_argument("mode", nargs="?", choices=("isolated", "existing", "system"), default="isolated")
    result.add_argument("theme", nargs="?", choices=("0", "1"), default="1")
    result.add_argument("--palette")
    result.add_argument("--output", default="")
    result.add_argument("--edge", choices=("top", "bottom", "left", "right"), default="top")
    result.add_argument("--follow-output", action="store_true")
    result.add_argument("--full-chrome", action="store_true")
    return result


def main():
    try:
        print(json.dumps(launch(parser().parse_args()), ensure_ascii=False))
        return 0
    except Failure as error:
        print(json.dumps({"error": str(error)}, ensure_ascii=False))
    except (OSError, ValueError, TypeError, KeyError):
        # Browser stderr, profile contents, window titles and arbitrary paths never reach DMS logs.
        print(json.dumps({"error": "ChatGPT-Start fehlgeschlagen. Datenpfad, Berechtigungen und Theme-Einstellungen prüfen."}))
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
