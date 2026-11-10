// Standalone OFFLINE renderer test; no account, cookies, or network.
import QtQuick
import QtQuick.Window
import QtWebEngine

Window {
    visible: true
    width: 640
    height: 440
    title: "DMS WebEngine probe (offline)"
    color: "#1e1e2e"

    WebEngineView {
        id: web
        anchors.fill: parent
        Component.onCompleted: web.loadHtml(
            "<!doctype html><html><head><meta charset='utf-8'>" +
            "<style>body{margin:0;background:#1e1e2e;color:#cdd6f4;" +
            "font:20px sans-serif;padding:45px}" +
            "code{color:#cba6f7}</style></head><body>" +
            "<h2>Qt WebEngine is rendering</h2>" +
            "<p>Offline probe: no login or network access.</p>" +
            "<p><code>DMS_WEBENGINE_PROBE_LOADED</code></p></body></html>"
        )
        onLoadingChanged: function(request) {
            if (request.status === WebEngineView.LoadSucceededStatus)
                console.log("DMS_WEBENGINE_PROBE_LOADED")
            else if (request.status === WebEngineView.LoadFailedStatus)
                console.error("DMS_WEBENGINE_PROBE_LOAD_FAILED")
        }
    }
}
