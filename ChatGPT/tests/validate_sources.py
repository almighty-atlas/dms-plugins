#!/usr/bin/env python3
"""Developer-only syntax/schema/CSS validation against a real upstream Dux checkout.

Not a substitute for qmllint or a graphical DMS runtime test. Optional dependencies:
tree-sitter, tree-sitter-qmljs, jsonschema, tinycss2. A compiled grammar .so can be
passed instead of the Python qmljs package (useful without Python development headers).
"""
import argparse
import ctypes
import json
from pathlib import Path
import re
import sys

PLUGIN = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PLUGIN / "scripts"))
import theme_sync


def language(library):
    from tree_sitter import Language
    if library:
        lib = ctypes.CDLL(str(Path(library).resolve()))
        lib.tree_sitter_qmljs.restype = ctypes.c_void_p
        value = lib.tree_sitter_qmljs()
    else:
        import tree_sitter_qmljs
        value = tree_sitter_qmljs.language()
    # qmljs 0.3.1 exposes an integer pointer; modern bindings expose a capsule.
    if isinstance(value, int):
        new_capsule = ctypes.pythonapi.PyCapsule_New
        new_capsule.restype = ctypes.py_object
        new_capsule.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_void_p]
        value = new_capsule(value, b"tree_sitter.Language", None)
    return Language(value)


def validate(dms_source, grammar=None):
    import jsonschema
    from tree_sitter import Parser
    import tinycss2

    qml_parser = Parser(language(grammar))
    for path in PLUGIN.glob("*.qml"):
        tree = qml_parser.parse(path.read_bytes())
        if tree.root_node.has_error:
            raise ValueError(f"QML syntax error: {path.name}")
        print(f"PASS: QML syntax (tree-sitter): {path.name}")

    source = Path(dms_source) / "quickshell"
    schema = json.loads((source / "PLUGINS/plugin-schema.json").read_text())
    jsonschema.Draft7Validator(schema).validate(json.loads((PLUGIN / "plugin.json").read_text()))
    print("PASS: manifest against actual upstream Draft7 schema")

    widget = (PLUGIN / "Widget.qml").read_text()
    base = (source / "Modules/Plugins/PluginComponent.qml").read_text()
    for member in ("horizontalBarPill", "verticalBarPill", "pillClickAction", "pillRightClickAction",
                   "pluginData", "parentScreen", "barConfig", "iconSize", "textSize", "widgetThickness"):
        if not re.search(r'property\s+\w+\s+' + member + r'\s*:', base):
            raise ValueError(f"Missing DMS PluginComponent member: {member}")
    theme = (source / "Common/Theme.qml").read_text()
    for member in set(re.findall(r'Theme\.(\w+)', widget + (PLUGIN / "Settings.qml").read_text())):
        if not re.search(r'property\s+\w+\s+' + member + r'\s*:', theme):
            raise ValueError(f"Missing DMS Theme member: {member}")
    for name in ("PluginSettings", "SelectionSetting", "ToggleSetting"):
        if not (source / f"Modules/Plugins/{name}.qml").is_file():
            raise ValueError(f"Missing setting type: {name}")
    for name in ("DIcon", "StyledText"):
        if not (source / f"DCommon/Widgets/{name}.qml").is_file():
            raise ValueError(f"Missing DCommon type: {name}")
    if "function runCommand(id, command, callback, debounceMs, timeoutMs, owner)" not in (source / "Common/Proc.qml").read_text():
        raise ValueError("Unexpected Proc.runCommand interface")
    if "function showError(" not in (source / "Services/ToastService.qml").read_text():
        raise ValueError("Missing native error toast")
    print("PASS: production bindings against upstream DMS interfaces (source contract, not runtime)")

    for colors, mode in ((theme_sync.DEFAULTS, "dark"), (theme_sync.LIGHT, "light")):
        rules = tinycss2.parse_stylesheet(theme_sync.render_css(colors, mode), skip_whitespace=True, skip_comments=True)
        if len(rules) != 1 or rules[0].type != "at-rule" or rules[0].at_keyword != "-moz-document":
            raise ValueError("CSS escaped origin scope")

        def check_rules(items):
            for rule in items:
                if rule.type == "error":
                    raise ValueError("CSS syntax error")
                if rule.type == "at-rule":
                    check_rules(tinycss2.parse_rule_list(rule.content, skip_whitespace=True, skip_comments=True))
                elif rule.type == "qualified-rule":
                    declarations = tinycss2.parse_declaration_list(rule.content, skip_whitespace=True, skip_comments=True)
                    if any(d.type == "error" for d in declarations):
                        raise ValueError("CSS declaration error")
        check_rules(tinycss2.parse_rule_list(rules[0].content, skip_whitespace=True, skip_comments=True))
        print(f"PASS: CSS parser, nested rules and exact HTTPS origin scope ({mode})")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("dms_source")
    parser.add_argument("--qml-grammar")
    args = parser.parse_args()
    validate(args.dms_source, args.qml_grammar)
