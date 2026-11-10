pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginComponent {
    id: root

    // Direct click launches the web app; no empty popup is shown.
    property string launchError: ""
    property string scriptPath: decodeURIComponent(
        Qt.resolvedUrl("./scripts/launch.sh").toString().replace(/^file:\/\//, ""))

    function openChat() {
        if (launchProcess.running)
            return;
        launchError = "";
        var mode = root.pluginService
            ? root.pluginService.loadPluginData(root.pluginId, "browserMode", "isolated")
            : "isolated";
        var theme = root.pluginService
            ? root.pluginService.loadPluginData(root.pluginId, "materialTheme", true)
            : true;
        launchProcess.command = ["/usr/bin/env", "bash", root.scriptPath,
                                 String(mode), theme ? "1" : "0"];
        launchProcess.running = true;
    }

    pillClickAction: () => root.openChat()

    horizontalBarPill: Component {
        Item {
            implicitWidth: 106
            implicitHeight: root.widgetThickness

            Row {
                anchors.centerIn: parent
                spacing: 6

                DankIcon {
                    name: root.launchError ? "error_outline" : "smart_toy"
                    size: 20
                    color: root.launchError ? Theme.error : Theme.primary
                }
                StyledText {
                    text: "ChatGPT"
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeMedium
                }
            }
        }
    }

    verticalBarPill: Component {
        Item {
            implicitWidth: root.widgetThickness
            implicitHeight: 44

            DankIcon {
                anchors.centerIn: parent
                name: root.launchError ? "error_outline" : "smart_toy"
                size: 22
                color: root.launchError ? Theme.error : Theme.primary
            }
        }
    }

    Process {
        id: launchProcess
        stdout: StdioCollector {}
        stderr: StdioCollector {
            onStreamFinished: {
                // Keep diagnostics in the DMS logs rather than storing commands or user data.
                if (this.text.trim().length)
                    console.warn("chatgptWeb:", this.text.trim());
            }
        }
        onExited: code => {
            if (code !== 0) {
                root.launchError = "Start fehlgeschlagen (Code " + code + "). DMS-Logs prüfen.";
                console.warn("chatgptWeb:", root.launchError);
            }
        }
    }
}
