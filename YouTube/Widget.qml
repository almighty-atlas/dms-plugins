pragma ComponentBehavior: Bound

import QtQuick
import "components"
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginComponent {
    id: root

    layerNamespacePlugin: "youtube-search"
    popoutWidth: Math.min(540, root.parentScreen ? root.parentScreen.width - 32 : 540)
    popoutHeight: Math.min(660, root.parentScreen ? root.parentScreen.height - root.barThickness - 48 : 660)

    CompanionController {
        id: backend

        service: root.pluginService
        pluginId: root.pluginId
    }

    horizontalBarPill: Component {
        Item {
            implicitWidth: 108
            implicitHeight: root.widgetThickness

            Row {
                anchors.centerIn: parent
                spacing: 6

                DankIcon {
                    name: "smart_display"
                    size: 20
                    color: Theme.primary
                }

                Text {
                    text: "YouTube"
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeMedium
                }
            }
        }
    }

    verticalBarPill: Component {
        Item {
            implicitWidth: root.widgetThickness
            implicitHeight: 40

            DankIcon {
                anchors.centerIn: parent
                name: "smart_display"
                size: 22
                color: Theme.primary
            }
        }
    }

    popoutContent: Component {
        CompanionPanel {
            controller: backend
            availableHeight: root.popoutHeight
        }
    }
}
