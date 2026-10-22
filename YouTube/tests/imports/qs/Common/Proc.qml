pragma Singleton
import QtQuick
QtObject {
    property var calls: []
    function runCommand(id, args, callback, debounce, timeout, owner) {
        calls = calls.concat([{id:id, args:args, callback:callback, timeout:timeout, owner:owner}])
    }
    function reset() { calls = [] }
    function reply(index, output, code) {
        var call = calls[index]
        if (Qt.isQtObject(call.owner)) call.callback(output, code)
    }
}
