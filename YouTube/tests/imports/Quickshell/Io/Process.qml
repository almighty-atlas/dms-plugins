import QtQuick
QtObject {
    property var command: []
    property bool running: false
    property QtObject stdout
    property QtObject stderr
    signal started
    signal exited(int code)
    onRunningChanged: if (running) Qt.callLater(started)
}
