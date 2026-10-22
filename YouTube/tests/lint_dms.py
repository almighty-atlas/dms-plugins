"""Lint all production QML against a DMS checkout, without modifying that checkout.

Usage: python3 YouTube/tests/lint_dms.py /path/to/DankMaterialShell
Quickshell generates qs import metadata at runtime; qmllint needs temporary
qmldir files for those source-only modules. Copying also resolves the matching
DMS common submodule symlink. Requires Qt 6 qmllint.
"""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

plugin = Path(__file__).resolve().parents[1]
reference = Path(sys.argv[1]) / "quickshell"
with tempfile.TemporaryDirectory(prefix="youtube-dms-lint-") as directory:
    target = Path(directory) / "qs"
    shutil.copytree(reference, target, symlinks=False)
    for folder in [target, *(p for p in target.rglob("*") if p.is_dir())]:
        files = list(folder.glob("*.qml"))
        if not files or (folder / "qmldir").exists():
            continue
        suffix = ".".join(folder.relative_to(target).parts)
        lines = ["module qs" + ("." + suffix if suffix else "")]
        for file in files:
            if file.stem[0].isupper():
                singleton = "singleton " if "pragma Singleton" in file.read_text() else ""
                lines.append(f"{singleton}{file.stem} 1.0 {file.name}")
        (folder / "qmldir").write_text("\n".join(lines) + "\n")
    command = ["/usr/lib/qt6/bin/qmllint", "-I", directory, str(plugin / "Widget.qml"),
               str(plugin / "Settings.qml"), *map(str, sorted((plugin / "components").glob("*.qml")))]
    result = subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=60)
    print(result.stdout, end="")
    if result.returncode or "Warning:" in result.stdout or "Error:" in result.stdout:
        raise SystemExit(result.returncode or 1)
    print("PASS: production QML lint against DMS source interfaces")
