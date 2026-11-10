pragma ComponentBehavior: Bound

import QtQuick
import QtWebEngine
import qs.Modules.Plugins

// EXPERIMENT ONLY: requires the isolated argc=1 Quickshell host.
// Do not link this component into the installed DMS plugin.
PluginComponent {
    id: root

    // This profile belongs to the widget, not the transient popout content.
    // Qt stores its data under the isolated XDG paths of the test process.
    // Multiple instances must not use the same storageName simultaneously.
    WebEngineProfilePrototype {
        id: profileFactory
        storageName: "dms-chatgpt-native-probe-v02"
        persistentCookiesPolicy: WebEngineProfile.OnlyPersistentCookies
        persistentPermissionsPolicy: WebEngineProfile.AskEveryTime
    }

    property var webProfile: null
    Component.onCompleted: {
        webProfile = profileFactory.instance();
        if (!webProfile)
            console.warn("DMS_NATIVE_PROFILE_UNAVAILABLE");
    }

    // Mouse hover must not create a browser or steal keyboard focus.
    function triggerHoverPopout() {}

    popoutWidth: 620
    popoutHeight: 700

    horizontalBarPill: Component {
        Item {
            implicitWidth: 160
            implicitHeight: root.widgetThickness
            Rectangle {
                anchors.centerIn: parent
                width: 154
                height: Math.min(36, parent.height)
                radius: 12
                color: "#313244"
                Text {
                    anchors.centerIn: parent
                    text: "ChatGPT native (test)"
                    color: "#cdd6f4"
                    font.pixelSize: 13
                }
            }
        }
    }

    verticalBarPill: Component {
        Item {
            implicitWidth: root.widgetThickness
            implicitHeight: root.widgetThickness
            Text {
                anchors.centerIn: parent
                text: "GPT"
                color: "#cdd6f4"
                font.pixelSize: 13
            }
        }
    }

    // No pillClickAction: the native PluginComponent click handler opens
    // PluginPopout through DMS's PopoutManager.
    popoutContent: Component {
        PopoutComponent {
            headerText: "ChatGPT WebEngine · Offline-Test"
            detailsText: "Isolierte DMS-Testinstanz. Keine Website, keine Anmeldung."

            Rectangle {
                width: parent.width
                implicitHeight: 610
                color: "#1e1e2e"
                radius: 12

                Loader {
                    anchors.fill: parent
                    active: root.webProfile !== null
                    sourceComponent: Component {
                        WebEngineView {
                            profile: root.webProfile
                            Component.onCompleted: loadHtml(
                                "<!doctype html><html><meta charset='utf-8'>" +
                                "<body style='background:#1e1e2e;color:#cdd6f4;" +
                                "font:18px sans-serif;padding:24px'>" +
                                "<h2>DMS native PluginPopout + WebEngine</h2>" +
                                "<p>DMS_NATIVE_POPOUT_HTML_LOADED</p>" +
                                "<p>Click here, type <em>test</em>, then close and reopen the popup.</p>" +
                                "<input type='text' placeholder='Type test' " +
                                "style='font:18px sans-serif;padding:12px;width:85%'>" +
                                "</body></html>"
                            )
                            onLoadingChanged: function(info) {
                                if (info.status === WebEngineView.LoadSucceededStatus)
                                    console.log("DMS_NATIVE_POPOUT_HTML_LOADED")
                                else if (info.status === WebEngineView.LoadFailedStatus)
                                    console.warn("DMS_NATIVE_POPOUT_HTML_FAILED")
                            }
                            onPermissionRequested: function(permission) {
                                permission.deny();
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.webProfile === null
                    text: "Experimentelles WebEngine-Profil nicht verfügbar"
                    color: "#f38ba8"
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
