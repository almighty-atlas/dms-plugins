pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Modules.Plugins
import qs.DCommon.Widgets

PluginComponent {
    id: root

    property bool busy: false
    property bool alive: true
    property int requestToken: 0
    property string launchError: ""
    readonly property string scripts: decodeURIComponent(Qt.resolvedUrl("./scripts/").toString().replace(/^file:\/\//, ""))
    // Snapshot the *rendered* theme, not just matugen's wallpaper palette. This also
    // handles stock/custom themes and DMS's current light/dark selection correctly.
    readonly property string palette: JSON.stringify({
        mode: Theme.isLightMode ? "light" : "dark",
        colors: {
            background: String(Theme.background), surface: String(Theme.surface),
            surfaceContainer: String(Theme.surfaceContainer), primary: String(Theme.primary),
            onPrimary: String(Theme.primaryText), surfaceText: String(Theme.surfaceText),
            surfaceVariantText: String(Theme.surfaceVariantText), outline: String(Theme.outline)
        }
    })

    function setting(key, fallback) {
        return root.pluginData[key] === undefined ? fallback : root.pluginData[key];
    }

    function reportError(message) {
        launchError = message;
        ToastService.showError("ChatGPT konnte nicht geöffnet werden", message);
        console.warn("chatgptWeb:", message);
    }

    function openChat(screen) {
        if (busy)
            return;
        busy = true;
        launchError = "";
        var token = ++requestToken;
        var edges = ["top", "bottom", "left", "right"];
        var edge = root.barConfig ? edges[root.barConfig.position % 4] || "top" : "top";
        var args = ["/usr/bin/env", "python3", scripts + "launcher.py",
                    String(setting("browserMode", "isolated")), setting("materialTheme", true) ? "1" : "0",
                    "--palette", palette, "--edge", edge];
        var target = screen || root.parentScreen;
        if (target && target.name)
            args.push("--output", target.name);
        if (setting("followOutput", false))
            args.push("--follow-output");
        if (!setting("compactMode", true))
            args.push("--full-chrome");
        watchdog.restart();
        Proc.runCommand(null, args, (output, code) => {
            if (!root.alive || token !== root.requestToken)
                return;
            watchdog.stop();
            root.busy = false;
            var result;
            try {
                result = JSON.parse(output);
            } catch (e) {
                root.reportError("Keine gültige Startantwort (Code " + code + "). Python 3 und DMS-PATH prüfen.");
                return;
            }
            if (!result || typeof result !== "object" || (!result.error && ["opened", "focused", "requested"].indexOf(result.status) < 0)) {
                root.reportError("Unerwartete Startantwort. Plugin-Dateien auf konsistenten Stand aktualisieren.");
                return;
            }
            if (code !== 0 || result.error)
                root.reportError(result.error || "Start fehlgeschlagen (Code " + code + ").");
            else if (result.warning)
                ToastService.showWarning("ChatGPT", result.warning);
        }, 0, 90000, root);
    }

    function prepareTheme() {
        if (setting("browserMode", "isolated") !== "isolated")
            return;
        var args = ["/usr/bin/env", "python3", scripts + "theme_sync.py", "--palette", palette];
        if (!setting("materialTheme", true))
            args.push("--disabled");
        if (!setting("compactMode", true))
            args.push("--full-chrome");
        // No profile is created by this operation. Browser stylesheets themselves
        // cannot be reliably hot-reloaded without an extension or privileged code.
        Proc.runCommand("chatgptWeb.theme", args, (output, code) => {
            if (root.alive && code !== 0)
                console.warn("chatgptWeb: Theme-Vorbereitung fehlgeschlagen; beim nächsten Klick erneut versucht.");
        }, 100, 40000, root);
    }

    pillClickAction: (x, y, width, section, screen) => root.openChat(screen)
    pillRightClickAction: () => ToastService.showInfo("ChatGPT Web", root.launchError || "Klicken öffnet/fokussiert ChatGPT. Neue DMS-Farben gelten nach vollständigem Beenden und erneutem Öffnen des isolierten Zen-Profils.")
    onPaletteChanged: themeDelay.restart()
    onPluginDataChanged: themeDelay.restart()
    Component.onCompleted: themeDelay.restart()
    Component.onDestruction: {
        alive = false;
        ++requestToken;
    }

    Timer {
        id: themeDelay
        interval: 800
        onTriggered: root.prepareTheme()
    }

    Timer {
        id: watchdog
        interval: 95000
        onTriggered: {
            ++root.requestToken;
            root.busy = false;
            root.reportError("Keine Prozessantwort nach 95 Sekunden. Niri/Python und DMS-Logs prüfen; danach erneut klicken.");
        }
    }

    horizontalBarPill: Component {
        Item {
            implicitWidth: content.implicitWidth
            implicitHeight: root.widgetThickness
            Row {
                id: content
                anchors.centerIn: parent
                spacing: Theme.spacingS
                DIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: root.launchError ? "error_outline" : root.busy ? "hourglass_top" : "smart_toy"
                    size: root.iconSize
                    color: root.launchError ? Theme.error : Theme.primary
                }
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "ChatGPT"
                    color: Theme.surfaceText
                    font.pixelSize: root.textSize
                }
            }
        }
    }

    verticalBarPill: Component {
        Item {
            implicitWidth: root.widgetThickness
            implicitHeight: root.iconSize + Theme.spacingS
            DIcon {
                anchors.centerIn: parent
                name: root.launchError ? "error_outline" : root.busy ? "hourglass_top" : "smart_toy"
                size: root.iconSize
                color: root.launchError ? Theme.error : Theme.primary
            }
        }
    }
}
