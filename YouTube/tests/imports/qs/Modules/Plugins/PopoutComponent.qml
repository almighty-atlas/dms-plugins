// Minimal test host for the documented DMS 1.6.3 popout interface.
import QtQuick
import qs.Widgets
Column {
    id: root
    property string headerText: ""
    property string detailsText: ""
    property bool showCloseButton: false
    property var closePopout: null
    property var parentPopout: null
    readonly property int headerHeight: header.visible ? 40 : 0
    readonly property int detailsHeight: details.visible ? details.implicitHeight : 0
    Item {
        id: header
        width: parent.width
        height: root.headerHeight
        visible: !!root.headerText
        Text { text: root.headerText; color: "white" }
        DankActionButton {
            anchors.right: parent.right
            visible: root.showCloseButton
            iconName: "close"
            onClicked: if (root.closePopout) root.closePopout()
        }
    }
    Text {
        id: details
        width: parent.width
        text: root.detailsText
        visible: !!text
    }
}
