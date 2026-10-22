"""Real Quickshell/Proc integration with local executable fixtures (no network).

Usage: python3 YouTube/tests/runtime_smoke.py /path/to/DankMaterialShell
The checkout must include the matching dank-qml-common submodule.
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

PLUGIN = Path(__file__).resolve().parents[1]
REFERENCE = Path(sys.argv[1]) / "dank-qml-common/DankCommon/Common"

SHELL = '''import QtQuick
import Quickshell
import Quickshell.Io
import "components"
ShellRoot {
    id: root
    property int stage: 0
    FileView { id: report; path: RESULT_PATH }
    FloatingWindow { visible: true; width: 32; height: 32 }
    CompanionController { id: backend }
    Timer {
        interval: 50; running: true; repeat: true
        onTriggered: {
            if (root.stage === 0) { backend.search("fixture",false); root.stage=1 }
            else if (root.stage === 1 && !backend.loading) {
                if (backend.results.length !== 1) { report.setText("FAIL search"); Qt.exit(1); return }
                backend.play(backend.results,"audio"); root.stage=2
            } else if (root.stage === 2 && backend.activePlayers === 0) {
                if (backend.errorMessage.indexOf("127") < 0) { report.setText("FAIL player"); Qt.exit(1); return }
                report.setText("PASS: real DMS Proc search and Quickshell player exit diagnostics")
                Qt.quit()
            }
        }
    }
    Timer { interval:8000; running:true; onTriggered: Qt.exit(1) }
}
'''

with tempfile.TemporaryDirectory(prefix="youtube-runtime-") as directory:
    target = Path(directory)
    for name in ("Common", "components", "js", "bin", "run"):
        (target / name).mkdir(mode=0o700)
    for name in ("Proc.qml", "Log.qml"):
        shutil.copyfile(REFERENCE / name, target / "Common" / name)
    shutil.copyfile(PLUGIN / "components/CompanionController.qml", target / "components/CompanionController.qml")
    shutil.copyfile(PLUGIN / "js/Companion.js", target / "js/Companion.js")
    for name, body in {
        "yt-dlp": 'import json\nprint(json.dumps({"entries":[{"id":"abcdefghijk","title":"Real Proc fixture"}]}))\n',
        "mpv": 'import sys\nif "--version" in sys.argv: print("mpv fixture"); sys.exit(0)\nassert "--no-video" in sys.argv\nassert "--" in sys.argv\nsys.exit(127)\n',
    }.items():
        executable = target / "bin" / name
        executable.write_text("#!/usr/bin/python3\n" + body)
        executable.chmod(0o700)
    result_path = target / "result.txt"
    (target / "shell.qml").write_text(SHELL.replace("RESULT_PATH", json.dumps(str(result_path))))
    result = subprocess.run([shutil.which("qs"), "-p", str(target / "shell.qml")],
                            env={**os.environ, "QT_QPA_PLATFORM": "offscreen", "XDG_RUNTIME_DIR": str(target / "run"),
                                 "PATH": str(target / "bin") + ":/usr/bin"},
                            text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=12)
    status = result_path.read_text() if result_path.exists() else "FAIL: no completion marker"
    if result.returncode or not status.startswith("PASS:"):
        print(result.stdout)
        raise SystemExit(status)
    print(status)
    warnings = [line for line in result.stdout.splitlines() if "WARN" in line or "ERROR" in line]
    if warnings:
        print("Host diagnostics (offscreen / restricted IPC):\n" + "\n".join(warnings))
