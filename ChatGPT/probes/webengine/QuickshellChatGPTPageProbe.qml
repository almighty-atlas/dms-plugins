// Deliberate ONLINE compatibility probe for a SEPARATE patched Quickshell
// process ONLY. Do not run with the installed Quickshell or in live DMS.
// Temporary off-the-record profile; do NOT sign in.
import QtQuick
import Quickshell
import QtWebEngine

ShellRoot {
    FloatingWindow {
        implicitWidth: 900
        implicitHeight: 740

        WebEngineProfile {
            id: temporaryProfile
            offTheRecord: true
        }

        Column {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                width: parent.width
                height: 48
                color: "#181825"

                Text {
                    anchors.centerIn: parent
                    text: "Patched Quickshell · ChatGPT page-load probe — do not sign in"
                    color: "#cdd6f4"
                    font.pixelSize: 15
                }
            }

            WebEngineView {
                id: chatgptSite
                width: parent.width
                height: parent.height - 48
                profile: temporaryProfile
                url: "https://chatgpt.com/"

                onLoadingChanged: function(request) {
                    if (request.status === WebEngineView.LoadSucceededStatus)
                        console.log("DMS_PATCHED_QS_CHATGPT_PAGE_LOAD_SUCCEEDED")
                    else if (request.status === WebEngineView.LoadFailedStatus)
                        console.log("DMS_PATCHED_QS_CHATGPT_PAGE_LOAD_FAILED")
                }
            }
        }
    }
}
