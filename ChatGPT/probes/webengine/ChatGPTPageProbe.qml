// Opt-in first-party page-load compatibility probe, NOT a login/browser replacement.
// Uses a distinct ephemeral Qt WebEngine profile; never reads Zen data.
// This file makes ordinary network requests to the ChatGPT site only when opened.
import QtQuick
import QtQuick.Window
import QtWebEngine

Window {
    visible: true
    width: 760
    height: 860
    title: "ChatGPT / Qt WebEngine page-load probe (no login)"
    color: "#1e1e2e"

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
                text: "Compatibility probe — do not sign in"
                color: "#cdd6f4"
                font.pixelSize: 16
            }
        }

        WebEngineView {
            id: site
            width: parent.width
            height: parent.height - 48
            profile: temporaryProfile
            url: "https://chatgpt.com/"

            onLoadingChanged: function(request) {
                if (request.status === WebEngineView.LoadSucceededStatus)
                    console.log("DMS_CHATGPT_PAGE_LOAD_SUCCEEDED")
                else if (request.status === WebEngineView.LoadFailedStatus)
                    console.log("DMS_CHATGPT_PAGE_LOAD_FAILED")
            }
        }
    }
}
