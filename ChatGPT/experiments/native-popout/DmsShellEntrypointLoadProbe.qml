// Compile (do not instantiate) the pinned DMS shell.qml entrypoint.
// No second DMS shell, shell.ready IPC, bar or screen capture is started.
import QtQuick
import Quickshell

ShellRoot {
    Component.onCompleted: {
        const component = Qt.createComponent(
            Qt.resolvedUrl("shell.qml"), Component.PreferSynchronous)
        if (component.status === Component.Ready) {
            console.log("DMS_SHELL_ENTRY_QML_TYPE_TREE_READY")
        } else {
            console.error("DMS_SHELL_ENTRY_QML_TYPE_TREE_FAILED")
            console.error(component.errorString())
        }
        // Deliberately DO NOT call component.createObject().
    }
}
