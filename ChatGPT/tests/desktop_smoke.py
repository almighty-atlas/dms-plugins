#!/usr/bin/env python3
"""Run on the real CachyOS desktop. No credentials, screenshots, page text or raw logs collected."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

PLUGIN = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PLUGIN / "scripts"))
import launcher
import manage
from runtime import Failure, atomic_write, private_dir
import theme_sync


class Smoke:
    def __init__(self, interactive=True):
        self.results = []
        self.interactive = interactive
        self.versions = {}

    def result(self, name, status):
        self.results.append({"test": name, "result": status})
        print(f"{status}: {name}", flush=True)

    def ask(self, name, instruction):
        if not self.interactive:
            self.result(name, "SKIP")
            return False
        print("\n" + instruction)
        answer = input("Ergebnis [j=PASS / n=FAIL / Enter=SKIP]: ").strip().lower()
        self.result(name, "PASS" if answer == "j" else "FAIL" if answer == "n" else "SKIP")
        return answer == "j"

    def run(self, argv, timeout=10):
        return subprocess.run(argv, stdin=subprocess.DEVNULL, capture_output=True,
                              text=True, timeout=timeout)

    def open(self, *extra):
        result = self.run([sys.executable, str(PLUGIN / "scripts/launcher.py"), *extra], 95)
        try:
            payload = json.loads(result.stdout)
        except ValueError:
            raise Failure("Ungültige Launcher-Antwort; Python/DMS-PATH prüfen.")
        if result.returncode or "error" in payload:
            # Plugin errors are fixed diagnostic strings, never browser output.
            raise Failure(payload.get("error", "Launcher fehlgeschlagen"))
        return payload

    def ipc(self, method, *args):
        # Dux master uses plugin-scan; older DMS builds used plugins.
        for target in ("plugin-scan", "plugins"):
            result = self.run(["dms", "ipc", "call", target, method, *args])
            if result.returncode == 0 and not result.stdout.strip().startswith("ERROR:"):
                return result.stdout.strip()
        return ""

    def desktop(self, install):
        tests = self.run([sys.executable, "-m", "unittest", "discover", "-s", str(PLUGIN / "tests"),
                          "-p", "test_*.py"], 90)
        self.result("Offline regression suite", "PASS" if tests.returncode == 0 else "FAIL")
        if tests.returncode:
            # Only local Python unittest diagnostics; no compositor, browser,
            # credential or window-title logs are collected here.
            details = (tests.stdout + "\n" + tests.stderr).strip()
            if details:
                print("Offline-Testfehler (unittest):\n" + details[-8000:], flush=True)
            return
        ready = bool(os.environ.get("WAYLAND_DISPLAY") and os.environ.get("NIRI_SOCKET"))
        self.result("Wayland + Niri session", "PASS" if ready else "FAIL")
        if not ready:
            print("In einem Terminal der laufenden CachyOS/Niri-Desktopsitzung ausführen.")
            return
        for name in ("niri", "dms"):
            if not shutil.which(name):
                self.result(name + " in PATH", "FAIL")
                return
            result = self.run([name, "--version"])
            self.versions[name] = re.findall(r'\b\d+\.\d+(?:\.\d+)?\b', result.stdout)[:2]
            self.result(name + " in PATH", "PASS")
        zen = launcher.find_zen()
        result = self.run([zen, "--version"])
        self.versions["zen"] = re.findall(r'\b\d+\.\d+(?:\.\d+)?\b', result.stdout)[:2]
        self.result("Zen executable", "PASS")
        outputs = {name: data for name, data in launcher.niri_query("outputs").items() if data.get("logical")}
        baseline = launcher.niri_query("windows")
        normal_ids = {w["id"] for w in baseline if w.get("app_id") != launcher.APP_ID}
        self.result("Niri JSON IPC", "PASS")
        self.result("Two connected outputs", "PASS" if len(outputs) >= 2 else "SKIP")

        if install:
            print(manage.manage("install"))
            self.result("Local feature-branch installation", "PASS")
        self.ipc("scan")
        time.sleep(1)
        if self.interactive:
            print("\nDMS → Einstellungen → Plugins: ChatGPT Web aktivieren, zur DankBar hinzufügen."
                  " Browsermodus: isoliert. Noch kein normales Browserfenster schließen.")
            input("Wenn bereit, Enter drücken … ")
        self.ipc("reload", "chatgptWeb")
        time.sleep(1)
        status = self.ipc("status", "chatgptWeb")
        self.result("Native DMS plugin loaded", "PASS" if status.startswith("loaded\t") else "FAIL")
        first = self.open()
        self.result("Dedicated window confirmed", "PASS" if first.get("window_id") is not None else "FAIL")
        second = self.open()
        self.result("Second launch focuses same window", "PASS" if second.get("status") == "focused" and
                    second.get("window_id") == first.get("window_id") else "FAIL")
        # Cross-process contention as produced by two bars on two monitors.
        commands = [subprocess.Popen([sys.executable, str(PLUGIN / "scripts/launcher.py")],
                    stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True) for _ in range(2)]
        replies = [p.communicate(timeout=95) for p in commands]
        same = all(p.returncode == 0 and json.loads(reply[0]).get("window_id") == first["window_id"]
                   for p, reply in zip(commands, replies))
        self.result("Concurrent launches stay single-window", "PASS" if same else "FAIL")
        windows = launcher.niri_query("windows")
        window = next((w for w in windows if w["id"] == first.get("window_id")), {})
        verified_pids = launcher.profile_processes(theme_sync.profile_path())
        verified_identity = (window.get("app_id") == launcher.APP_ID or
                             (window.get("pid") is not None and window.get("pid") in verified_pids))
        self.result("Isolated window identity (app-id or verified profile PID)",
                    "PASS" if verified_identity else "FAIL")
        if verified_identity and window.get("app_id") != launcher.APP_ID:
            print("INFO: Zen hat keine eigene app-id; die isolierte Profil-PID dient als Fensterkennung.")
        self.result("Floating window", "PASS" if window.get("is_floating") else "FAIL")
        self.result("Focused window", "PASS" if window.get("is_focused") else "FAIL")
        self.result("Normal windows remain open", "PASS" if normal_ids <= {w["id"] for w in windows} else "FAIL")
        size = window.get("layout", {}).get("window_size", [])
        self.result("Compact window size", "PASS" if len(size) == 2 and 300 <= size[0] <= 820 and
                    300 <= size[1] <= 920 else "FAIL")

        self.ask("DankBar horizontal + vertical and native settings",
                 "Widget in horizontaler und vertikaler Leiste testen, jeweils zweimal klicken."
                 " Einstellungen öffnen: Modus, Compact Mode, Theme, Monitoroption müssen bedienbar sein."
                 " Rechtsklick zeigt Hinweise, kein leerer Popout.")
        self.ask("Official login, composer, attachment, model menu and settings",
                 "Falls nötig Zen-Onboarding abschließen. Nur im Browser bei ChatGPT anmelden."
                 " Eine harmlose Nachricht senden, Antwort abwarten; kleine Testdatei anhängen,"
                 " Modellmenü, Verlauf und ChatGPT-Einstellungen bedienen. Keine Inhalte hier eingeben.")
        self.ask("Light/dark/custom palette, responsive 650–900px, reachable browser UI",
                 "DMS Light/Dark bzw. Custom Theme wechseln, Widget einmal klicken, NUR das isolierte Zen"
                 " vollständig beenden und über das Widget neu öffnen. Farben prüfen; Fenster schmal/breit"
                 " ziehen. Hover, Ctrl+L, Ctrl+Alt+S müssen Browser-Navigation sichtbar machen."
                 " Bei Darstellungsfehlern DMS-Farben deaktivieren und isoliertes Zen neu öffnen.")
        self.ask("Session persists after isolated close/reopen + DMS reload",
                 "Nur das isolierte Browserprofil vollständig beenden und über das Widget neu öffnen."
                 " Anmeldung/Verlauf müssen erhalten bleiben, normale Zen-Sitzung ebenfalls."
                 " Plugin in DMS neu laden; Klick muss wieder fokussieren, nicht duplizieren.")
        if len(outputs) >= 2:
            self.ask("Two monitor placement and follow-output option",
                     "Auf jedem Monitor über dessen DankBar öffnen/fokussieren. Standard: bestehendes Fenster"
                     " bleibt an seiner Position; mit Monitoroption wandert nur ChatGPT zum angeklickten Monitor."
                     " Floating-Fenster verschieben und skalieren. Optional Monitor trennen und erneut klicken.")
        else:
            self.result("Two monitor placement and follow-output option", "SKIP")
        self.ask("Existing Zen session fallback",
                 "Browsermodus Bestehende Sitzung wählen und öffnen. Normales Profil darf keine"
                 " Plugin-CSS/Compact-Einstellungen bekommen. Danach wieder auf isoliert wechseln."
                 " Im Fallback sind Fokus/Einzelfenster nur best effort, keine strikte Garantie.")
        self.ask("Relevant QML runtime warnings absent",
                 "DMS-eigene Diagnose/Logs lokal auf neue chatgptWeb-, QML- und Importfehler prüfen."
                 " Keine vollständigen Desktop-Logs hochladen. Dieser Test sammelt diese Logs nicht.")

    def finish(self):
        state = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "dms-chatgpt"
        private_dir(state)
        report = state / "desktop-smoke.json"
        atomic_write(report, json.dumps({"results": self.results, "versions": self.versions,
                                        "privacy": "No cookies, credentials, titles, page text, environment dumps or browser logs collected."}, indent=2))
        print("\nDiagnosebericht (nur Prüfergebnisse/Versionsnummern):", report)
        print("Eventuell geöffnete Browserfenster bleiben offen; kein Dienstneustart, keine Niri-Konfiguration verändert.")
        if any(r["result"] == "FAIL" for r in self.results):
            return 1
        return 2 if any(r["result"] == "SKIP" for r in self.results) else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--install", action="store_true", help="Link this checkout into the DMS 2.0 plugin directory")
    parser.add_argument("--non-interactive", action="store_true", help="Mark visual checks SKIP, never assume PASS")
    args = parser.parse_args()
    smoke = Smoke(not args.non_interactive and sys.stdin.isatty())
    try:
        smoke.desktop(args.install)
    except Failure as error:
        smoke.result("Desktop smoke operation", "FAIL")
        print(str(error))
    except (OSError, ValueError, subprocess.TimeoutExpired, EOFError, KeyboardInterrupt):
        smoke.result("Desktop smoke interrupted or dependency/IPC failure", "FAIL")
    return smoke.finish()


if __name__ == "__main__":
    raise SystemExit(main())
