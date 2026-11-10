//@ pragma UseQApplication
//@ pragma AppId dev.dms.chatgpt.native.probe

import QtQuick
import Quickshell
import "ChatGPTNativeProbe" as Native

// Independent Quickshell configuration located at the root of a DMS source
// checkout, to resolve qs.* imports while exercising *real* DMS PluginPopout.
ShellRoot {
    FloatingWindow {
        id: testBar
        visible: true
        implicitWidth: 420
        implicitHeight: 95
        width: 420
        height: 95
        title: "DMS native ChatGPT popout experiment (isolated)"
        color: "#181825"

        Native.Widget {
            width: 160
            height: 48
            anchors.centerIn: parent
            pluginId: "chatgptNativeProbe"
            parentScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
            section: "center"
            widgetThickness: 48
            barThickness: 48
            barSpacing: 4
            barConfig: ({ position: 0, spacing: 4, bottomGap: 0 })
        }
    }
}
