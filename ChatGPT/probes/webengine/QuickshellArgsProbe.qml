// Separate Quickshell instance only. Does not instantiate Qt WebEngine.
// Prints an integer and a fixed status marker, never actual argv strings.
import QtQuick
import Quickshell

ShellRoot {
    Component.onCompleted: {
        const argc = Qt.application.arguments.length
        console.log("DMS_QS_ARGUMENT_COUNT=" + argc)
        console.log(argc === 0 ? "DMS_QS_ARGC_ZERO" : "DMS_QS_ARGC_NONZERO")
        // Do not call Qt.quit(): Quickshell does not connect this signal.
        // The invoking test command terminates this separate process by timeout.
    }
}
