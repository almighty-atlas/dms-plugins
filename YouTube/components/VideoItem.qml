pragma ComponentBehavior: Bound

import "../js/Companion.js" as Model
import QtQuick
import qs.Common
import qs.Widgets

FocusScope {
    id: root

    required property var video
    property bool thumbnailsEnabled: true
    property bool saved: false
    property bool selected: false
    property bool queueMode: false
    property bool historyMode: false
    property bool canMoveUp: false
    property bool canMoveDown: false

    signal play(string mode)
    signal toggleSaved
    signal enqueue
    signal remove
    signal move(int offset)
    signal navigate(int offset)
    signal selectedByUser
    signal focusSearchRequested

    activeFocusOnTab: true
    implicitHeight: 114
    onActiveFocusChanged: {
        if (activeFocus) {
            selectedByUser();
        }
    }
    Keys.onPressed: event => {
        // Child controls handle their own Enter/Space before bubbling here.
        if (event.key === Qt.Key_Down)
            root.navigate(1);
        else if (event.key === Qt.Key_Up)
            root.navigate(-1);
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
            root.play(event.modifiers & Qt.ControlModifier ? "audio" : "");
        else if (event.key === Qt.Key_M && event.modifiers === Qt.NoModifier)
            root.toggleSaved();
        else if (event.key === Qt.Key_Q && event.modifiers === Qt.NoModifier)
            root.enqueue();
        else if (event.key === Qt.Key_Escape)
            root.focusSearchRequested();
        else
            return;
        event.accepted = true;
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh
        border.width: root.activeFocus || root.selected ? 2 : 0
        border.color: Theme.primary
    }
    // The background click selects the row; actions have their own hit targets.

    MouseArea {
        anchors.fill: parent
        onClicked: {
            root.forceActiveFocus();
            root.selectedByUser();
        }
    }

    Row {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 10

        Rectangle {
            width: root.width < 420 ? 96 : 128
            height: width * 9 / 16
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.surfaceContainer

            DankIcon {
                anchors.centerIn: parent
                name: "smart_display"
                size: 24
                color: Theme.surfaceVariantText
            }

            Image {
                anchors.fill: parent
                source: root.thumbnailsEnabled && Model.validId(root.video.id) ? "https://i.ytimg.com/vi/" + root.video.id + "/mqdefault.jpg" : ""
                sourceSize.width: 256
                sourceSize.height: 144
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
            }
        }

        Column {
            width: parent.width - (root.width < 420 ? 96 : 128) - parent.spacing
            spacing: 2

            Text {
                width: parent.width
                height: 36
                text: root.video.title
                textFormat: Text.PlainText
                color: Theme.surfaceText
                font.pixelSize: 13
                font.weight: Font.DemiBold
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: root.video.channel + (root.video.live ? " · LIVE" : root.video.short ? " · Short" : "") + (Model.formatDuration(root.video.durationSeconds) ? " · " + Model.formatDuration(root.video.durationSeconds) : "")
                textFormat: Text.PlainText
                color: Theme.surfaceVariantText
                font.pixelSize: 11
                elide: Text.ElideRight
            }

            Text {
                visible: root.historyMode
                width: parent.width
                text: root.video.openedAt ? new Date(root.video.openedAt).toLocaleString(Qt.locale()) : "Zeitpunkt unbekannt"
                color: Theme.surfaceVariantText
                font.pixelSize: 10
                elide: Text.ElideRight
            }

            Row {
                spacing: 1

                DankActionButton {
                    iconName: "play_arrow"
                    iconColor: Theme.primary
                    buttonSize: 28
                    tooltipText: "Standardplayer (Enter)"
                    onClicked: root.play("")
                }

                DankActionButton {
                    iconName: "headphones"
                    buttonSize: 28
                    tooltipText: "Nur Audio (Ctrl+Enter)"
                    onClicked: root.play("audio")
                }

                DankActionButton {
                    iconName: root.saved ? "bookmark" : "bookmark_add"
                    iconColor: root.saved ? Theme.primary : Theme.surfaceText
                    buttonSize: 28
                    tooltipText: "Merken (M), maximal 200"
                    onClicked: root.toggleSaved()
                }

                DankActionButton {
                    visible: !root.queueMode
                    iconName: "playlist_add"
                    buttonSize: 28
                    tooltipText: "Zur Warteschlange (Q)"
                    onClicked: root.enqueue()
                }

                DankActionButton {
                    visible: root.queueMode
                    enabled: root.canMoveUp
                    iconName: "arrow_upward"
                    buttonSize: 28
                    tooltipText: "Nach oben"
                    onClicked: root.move(-1)
                }

                DankActionButton {
                    visible: root.queueMode
                    enabled: root.canMoveDown
                    iconName: "arrow_downward"
                    buttonSize: 28
                    tooltipText: "Nach unten"
                    onClicked: root.move(1)
                }

                DankActionButton {
                    visible: root.queueMode || root.historyMode
                    iconName: "delete"
                    buttonSize: 28
                    tooltipText: "Eintrag entfernen"
                    onClicked: root.remove()
                }
            }
        }
    }
}
