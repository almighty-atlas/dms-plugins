import QtQuick
import QtQuick.Controls
Button {
    property string iconName: ""
    property color iconColor: "white"
    property int buttonSize: 28
    property string tooltipText: ""
    width: buttonSize
    height: buttonSize
    text: iconName
}
