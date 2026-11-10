#!/usr/bin/env python3
"""Reversible local feature-branch installation; registry remains the release path."""
import argparse
import json
import os
from pathlib import Path

from runtime import Failure

SOURCE = Path(__file__).resolve().parents[1]


def plugin_dir():
    base = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    if not base.is_absolute():
        raise Failure("XDG_CONFIG_HOME muss absolut sein.")
    return base / "dms/plugins"


def manage(operation, directory=None):
    directory = directory or plugin_dir()
    target = directory / "chatgptWeb"
    if operation != "uninstall" and directory.exists():
        for entry in directory.iterdir():
            if entry == target or entry.name.startswith("."):
                continue
            manifest_path = entry / "plugin.json"
            try:
                metadata = json.loads(manifest_path.read_text(encoding="utf-8"))
            except (OSError, ValueError):
                continue
            if isinstance(metadata, dict) and metadata.get("id") == "chatgptWeb":
                raise Failure("ChatGPT ist bereits unter einem anderen Verzeichnisnamen installiert. Kein doppelter Plugin-Link angelegt; ursprünglichen Installationsweg verwenden.")
    if target.is_symlink():
        if target.resolve() != SOURCE:
            raise Failure("Andere Installation vorhanden; nicht überschrieben. Zuerst deren Installationsweg verwenden.")
    elif target.exists():
        raise Failure("Plugin-Verzeichnis existiert bereits; nicht überschrieben.")
    if operation == "uninstall":
        if target.is_symlink():
            target.unlink()
        return "Plugin-Link entfernt; Browserprofil und Anmeldung bleiben erhalten."
    manifest = json.loads((SOURCE / "plugin.json").read_text())
    if manifest.get("id") != "chatgptWeb" or not (SOURCE / "Widget.qml").is_file():
        raise Failure("Ungültiges Plugin-Quellverzeichnis.")
    directory.mkdir(parents=True, exist_ok=True)
    if not target.is_symlink():
        target.symlink_to(SOURCE, target_is_directory=True)
    return "Plugin verknüpft. In DMS Plugins scannen/aktivieren und ChatGPT zur DankBar hinzufügen."


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=("install", "update", "uninstall"))
    try:
        print(manage(parser.parse_args().operation))
    except (Failure, OSError, ValueError) as error:
        raise SystemExit(str(error))
