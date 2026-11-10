// Run ONLY in the isolated argc=1 Quickshell binary, never in live DMS.
import QtQuick
import Quickshell
import QtWebEngine

ShellRoot {
    FloatingWindow {
        implicitWidth: 640
        implicitHeight: 420

        WebEngineView {
            anchors.fill: parent
            Component.onCompleted: loadHtml(
                "<!doctype html><html><meta charset='utf-8'><body " +
                "style='background:#1e1e2e;color:#cdd6f4;font:20px sans-serif;padding:35px'>" +
                "<h2>Patched Quickshell + WebEngine</h2>" +
                "<p>Offline renderer; no login or network.</p>" +
                "<code>DMS_PATCHED_QS_WEBENGINE_LOADED</code></body></html>"
            )
            onLoadingChanged: function(request) {
                if (request.status === WebEngineView.LoadSucceededStatus)
                    console.log("DMS_PATCHED_QS_WEBENGINE_LOADED")
                else if (request.status === WebEngineView.LoadFailedStatus)
                    console.log("DMS_PATCHED_QS_WEBENGINE_FAILED")
            }
        }
    }
}
