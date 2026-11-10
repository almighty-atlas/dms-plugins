// Strictly offline type-instantiation test for a full DMS Quickshell build.
// No bar, system services, capture source, WebEngine, or real DMS connection.
import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
    Component {
        id: sample
        Item {
            width: 1
            height: 1

            ScreencopyView {
                anchors.fill: parent
                captureSource: null
                live: false
            }
        }
    }

    Component.onCompleted: {
        const instance = sample.createObject(null)
        if (!instance) {
            console.error("DMS_SCREENCOPY_QML_INSTANTIATION_FAILED")
        } else {
            console.log("DMS_SCREENCOPY_QML_READY")
            instance.destroy()
        }
    }
}
