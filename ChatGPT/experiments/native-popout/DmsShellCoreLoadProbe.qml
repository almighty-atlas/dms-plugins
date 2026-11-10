// Full DMS ShellCore type-tree compilation ONLY; no shell object created.
// The shell's real QML services and widgets are resolved from a pinned,
// private DMS source copy, with isolated XDG/DBus and blank DMS/Niri IPC.
import QtQuick
import Quickshell

ShellRoot {
    Component.onCompleted: {
        const component = Qt.createComponent(
            Qt.resolvedUrl("ShellCore.qml"), Component.PreferSynchronous)
        if (component.status === Component.Ready) {
            console.log("DMS_SHELLCORE_QML_TYPE_TREE_READY")
        } else {
            console.error("DMS_SHELLCORE_QML_TYPE_TREE_FAILED")
            console.error(component.errorString())
        }
        // Deliberately DO NOT createObject(): this is an import/type load
        // check, not a live DMS daemon, panel or readiness test.
    }
}
