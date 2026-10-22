pragma Singleton
import QtQuick
QtObject {
    property color surfaceContainer: "#222222"
    property color surfaceContainerHigh: "#333333"
    property color surfaceText: "white"
    property color surfaceVariantText: "#bbbbbb"
    property color primary: "#99ccff"
    readonly property color onPrimary: Qt.rgba(0, 0, 0, 1)
    property color error: "#ff7777"
    property int cornerRadius: 8
    property int fontSizeMedium: 14
    property int fontSizeSmall: 12
    property int fontSizeLarge: 18
    property int spacingS: 8
    property int spacingXS: 4
    property int iconSize: 24
    property color errorHover: "#442222"
    function withAlpha(c,a) {return Qt.rgba(c.r,c.g,c.b,a)}
}
