// Offline experiment only. Run with the separate argc=1 Quickshell
// binary built with WAYLAND_WLR_LAYERSHELL=ON. NEVER run inside live DMS.
import QtQuick
import Quickshell
import Quickshell.Wayland
import QtWebEngine

ShellRoot {
    PanelWindow {
        id: popup
        implicitWidth: 760
        implicitHeight: 760
        color: "transparent"
        exclusiveZone: 0

        anchors {
            top: true
            right: true
        }
        margins {
            top: 70
            right: 24
        }

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "dms-chatgpt-v02-layer-probe"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        Rectangle {
            anchors.fill: parent
            color: "#1e1e2e"
            radius: 12

            Text {
                id: heading
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.topMargin: 16
                text: "Quickshell Layer-Shell + WebEngine: keyboard focus test"
                color: "#cdd6f4"
                font.pixelSize: 17
            }

            WebEngineView {
                anchors {
                    left: parent.left
                    right: parent.right
                    top: heading.bottom
                    bottom: parent.bottom
                    margins: 20
                }

                Component.onCompleted: loadHtml(
                    "<!doctype html><html><meta charset='utf-8'>" +
                    "<body style='background:#1e1e2e;color:#cdd6f4;" +
                    "font:20px sans-serif;padding:20px'>" +
                    "<h2>Wayland Layer-Shell WebEngine</h2>" +
                    "<p>DMS_LAYERSHELL_WEBENGINE_LOADED</p>" +
                    "<p>Click and type a harmless word in the field below:</p>" +
                    "<input type='text' placeholder='Click here and type test' " +
                    "style='font:20px sans-serif;padding:12px;width:85%'></body></html>"
                )

                onLoadingChanged: function(request) {
                    if (request.status === WebEngineView.LoadSucceededStatus)
                        console.log("DMS_LAYERSHELL_WEBENGINE_LOADED")
                    else if (request.status === WebEngineView.LoadFailedStatus)
                        console.log("DMS_LAYERSHELL_WEBENGINE_FAILED")
                }
            }
        }
    }
}
