pragma ComponentBehavior: Bound

import "../js/Companion.js" as Model
import QtQuick
import QtQuick.Window
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PopoutComponent {
    id: panel

    required property var controller
    property bool thumbnailsEnabled: true
    property real availableHeight: 660
    property bool syncingEntries: false
    property int view: 0
    property bool filtersVisible: false
    property string contentFilter: controller.setting("contentFilter", "all")
    property string lengthFilter: controller.setting("lengthFilter", "all")
    readonly property var entries: view === 0 ? controller.results.filter(function (v) {
        return Model.matches(v, contentFilter, lengthFilter);
    }) : view === 1 ? controller.state.saved : view === 2 ? controller.state.opened : controller.state.queue
    readonly property bool isOpen: parentPopout ? parentPopout.shouldBeVisible : visible

    function syncEntries() {
        if (!listStore || !list)
            return;
        var selectedId = list.currentIndex >= 0 && list.currentIndex < listStore.count ? listStore.get(list.currentIndex).item.id : "";
        var previousIndex = list.currentIndex;
        syncingEntries = true;
        for (var i = 0; i < entries.length; ++i) {
            if (i >= listStore.count)
                listStore.append({
                    item: entries[i]
                });
            else if (JSON.stringify(listStore.get(i).item) !== JSON.stringify(entries[i]))
                listStore.setProperty(i, "item", entries[i]);
        }
        if (listStore.count > entries.length)
            listStore.remove(entries.length, listStore.count - entries.length);
        var nextIndex = entries.findIndex(function (v) {
            return v.id === selectedId;
        });
        list.currentIndex = nextIndex >= 0 ? nextIndex : Math.min(previousIndex, entries.length - 1);
        syncingEntries = false;
    }
    onEntriesChanged: syncEntries()
    Component.onCompleted: syncEntries()
    ListModel {
        id: listStore
        dynamicRoles: true
    }

    function focusSearch() {
        if (isOpen)
            field.forceActiveFocus();
    }

    function focusRow(index) {
        if (!entries.length) {
            focusSearch();
            return;
        }
        list.currentIndex = Math.max(0, Math.min(entries.length - 1, index));
        list.positionViewAtIndex(list.currentIndex, ListView.Contain);
        if (list.currentItem)
            list.currentItem.forceActiveFocus();
    }

    headerText: "YouTube"
    showCloseButton: true
    onViewChanged: {
        list.currentIndex = -1;
        list.contentY = 0;
    }
    onParentPopoutChanged: Qt.callLater(focusSearch)
    Keys.onPressed: event => {
        if (event.key === Qt.Key_K && (event.modifiers & Qt.ControlModifier)) {
            panel.focusSearch();
            event.accepted = true;
        }
    }

    Connections {
        function onShouldBeVisibleChanged() {
            if (panel.isOpen)
                Qt.callLater(panel.focusSearch);
        }

        target: panel.parentPopout
    }

    Connections {
        function onActiveChanged() {
            if (panel.Window.window.active && panel.isOpen)
                Qt.callLater(panel.focusSearch);
        }

        target: panel.Window.window
    }

    Connections {
        function onSearchStarted(more) {
            if (!more) {
                panel.view = 0;
                list.currentIndex = -1;
                list.contentY = 0;
            }
        }

        target: panel.controller
    }

    // Opaque content including the header; DMS's surrounding shell supplies its own surface.
    Rectangle {
        parent: panel.parent
        z: -1
        anchors.fill: panel
        color: Theme.surfaceContainer
        radius: Theme.cornerRadius
    }

    Column {
        width: parent.width
        spacing: 6

        Row {
            width: parent.width
            spacing: 6

            Rectangle {
                width: parent.width - 78
                height: 40
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.width: field.activeFocus ? 2 : 0
                border.color: Theme.primary

                DankIcon {
                    x: 8
                    anchors.verticalCenter: parent.verticalCenter
                    name: "search"
                    size: 18
                    color: Theme.surfaceVariantText
                }

                TextInput {
                    id: field

                    objectName: "searchField"
                    anchors.fill: parent
                    anchors.leftMargin: 32
                    anchors.rightMargin: 8
                    verticalAlignment: TextInput.AlignVCenter
                    text: panel.controller.lastQuery
                    color: Theme.surfaceText
                    font.pixelSize: 14
                    selectByMouse: true
                    activeFocusOnTab: true
                    onAccepted: panel.controller.search(text, false)
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Down) {
                            panel.focusRow(0);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Escape && panel.filtersVisible) {
                            panel.filtersVisible = false;
                            event.accepted = true;
                        }
                    }

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        visible: !field.text
                        text: "YouTube durchsuchen …"
                        color: Theme.surfaceVariantText
                        font.pixelSize: 14
                    }
                }
            }

            DankActionButton {
                iconName: "search"
                tooltipText: "Suche starten"
                buttonSize: 34
                onClicked: panel.controller.search(field.text, false)
            }

            DankActionButton {
                iconName: "filter_list"
                tooltipText: "Filter"
                buttonSize: 32
                onClicked: panel.filtersVisible = !panel.filtersVisible
            }
        }

        Column {
            visible: panel.filtersVisible
            width: parent.width
            spacing: 4

            Row {
                spacing: 6

                DankButton {
                    text: ["Alle Inhalte", "Shorts (belegt)", "Live (belegt)"][["all", "shorts", "live"].indexOf(panel.contentFilter)] || "Alle Inhalte"
                    buttonHeight: 30
                    onClicked: {
                        var options = ["all", "shorts", "live"];
                        panel.contentFilter = options[(options.indexOf(panel.contentFilter) + 1) % options.length];
                    }
                }

                DankButton {
                    text: ["Alle Längen", "Unter 4 min", "4–20 min", "Über 20 min"][["all", "short", "medium", "long"].indexOf(panel.lengthFilter)] || "Alle Längen"
                    buttonHeight: 30
                    onClicked: {
                        var options = ["all", "short", "medium", "long"];
                        panel.lengthFilter = options[(options.indexOf(panel.lengthFilter) + 1) % options.length];
                    }
                }
            }

            Text {
                width: parent.width
                wrapMode: Text.Wrap
                font.pixelSize: 11
                color: Theme.surfaceVariantText
                text: "Filter gelten für geladene Treffer. Shorts/Live nur bei positiven Metadaten. Exklusiv Videos und Neueste zuerst sind nicht verfügbar. Sortierung: Relevanz."
            }
        }

        Row {
            width: parent.width

            Repeater {
                model: ["Suche", "Merkliste", "Verlauf", "Warteschlange"]

                DankButton {
                    required property string modelData
                    required property int index

                    width: parent.width / 4
                    horizontalPadding: 2
                    buttonHeight: 32
                    text: modelData
                    backgroundColor: panel.view === index ? Theme.primary : Theme.surfaceContainerHigh
                    textColor: panel.view === index ? Theme.onPrimary : Theme.surfaceText
                    onClicked: panel.view = index
                }
            }
        }

        Text {
            width: parent.width
            wrapMode: Text.Wrap
            font.pixelSize: 11
            color: Theme.surfaceVariantText
            text: panel.view === 0 ? (panel.controller.loading ? "Suche läuft …" : panel.entries.length + " Treffer · " + panel.controller.requestedCount + "/50 angefragt") : panel.view === 1 ? panel.entries.length + "/200 lokal gemerkt" : panel.view === 2 ? "Lokaler Öffnungsverlauf · keine Bestätigung angesehener Videos" : panel.entries.length + "/50 Videos · Reihenfolge bleibt gespeichert"
        }

        Row {
            visible: panel.view === 3
            spacing: 6

            DankButton {
                text: "Abspielen"
                buttonHeight: 30
                enabled: panel.entries.length > 0
                onClicked: panel.controller.play(panel.entries, "video")
            }

            DankButton {
                text: "Nur Audio"
                buttonHeight: 30
                enabled: panel.entries.length > 0
                onClicked: panel.controller.play(panel.entries, "audio")
            }

            DankActionButton {
                iconName: "delete_sweep"
                tooltipText: "Warteschlange leeren"
                onClicked: panel.controller.mutate("clearQueue")
            }
        }
        // Search history has its own bounded, scrollable viewport.

        Column {
            visible: panel.view === 2
            width: parent.width
            spacing: 2

            Row {
                spacing: 8

                Text {
                    text: "Letzte Suchanfragen (lokal)"
                    color: Theme.surfaceVariantText
                    font.pixelSize: 12
                }

                DankActionButton {
                    iconName: "delete_sweep"
                    buttonSize: 24
                    tooltipText: "Suchverlauf löschen"
                    onClicked: panel.controller.mutate("clearSearches")
                }

                DankActionButton {
                    iconName: "history_toggle_off"
                    buttonSize: 24
                    tooltipText: "Öffnungsverlauf löschen"
                    onClicked: panel.controller.mutate("clearOpened")
                }
            }

            ListView {
                width: parent.width
                height: Math.min(76, contentHeight)
                clip: true
                model: panel.controller.state.searches

                delegate: Row {
                    id: queryRow
                    required property string modelData

                    width: ListView.view.width

                    TextMetrics {
                        id: queryMetrics
                        text: queryRow.modelData
                        font.pixelSize: Theme.fontSizeMedium
                        elide: Qt.ElideRight
                        elideWidth: queryRow.width - 54
                    }
                    DankButton {
                        width: parent.width - 34
                        clip: true
                        text: queryMetrics.elidedText
                        horizontalPadding: 6
                        buttonHeight: 30
                        onClicked: {
                            field.text = parent.modelData;
                            panel.controller.search(parent.modelData, false);
                        }
                    }

                    DankActionButton {
                        iconName: "close"
                        tooltipText: "Suchanfrage entfernen"
                        buttonSize: 30
                        onClicked: panel.controller.mutate("removeSearch", parent.modelData)
                    }
                }
            }
        }

        Item {
            width: parent.width
            height: Math.max(48, panel.availableHeight - panel.headerHeight - parent.y - y - 88)

            ListView {
                id: list

                objectName: "videoList"
                anchors.fill: parent
                clip: true
                spacing: 6
                cacheBuffer: 0
                model: listStore
                currentIndex: -1
                keyNavigationEnabled: false
                onCountChanged: {
                    if (currentIndex >= count) {
                        currentIndex = count - 1;
                    }
                }

                delegate: VideoItem {
                    required property var item
                    required property int index

                    width: list.width
                    height: 114
                    video: item
                    thumbnailsEnabled: panel.thumbnailsEnabled
                    selected: list.currentIndex === index
                    saved: Model.has(panel.controller.state.saved, item.id)
                    queueMode: panel.view === 3
                    historyMode: panel.view === 2
                    canMoveUp: index > 0
                    canMoveDown: index < list.count - 1
                    onSelectedByUser: {
                        if (panel.syncingEntries)
                            return;
                        list.currentIndex = index;
                        list.positionViewAtIndex(index, ListView.Contain);
                    }
                    onNavigate: offset => {
                        if (index === 0 && offset < 0)
                            panel.focusSearch();
                        else
                            panel.focusRow(index + offset);
                    }
                    onFocusSearchRequested: panel.focusSearch()
                    onPlay: mode => {
                        return panel.controller.play([item], mode);
                    }
                    onToggleSaved: panel.controller.mutate("save", item)
                    onEnqueue: panel.controller.mutate("queue", item)
                    onRemove: panel.controller.mutate(panel.view === 3 ? "removeQueue" : "removeOpened", item.id)
                    onMove: offset => {
                        return panel.controller.mutate("move", {
                            "id": item.id,
                            "offset": offset
                        });
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                width: parent.width - 20
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
                color: Theme.surfaceVariantText
                font.pixelSize: 13
                visible: !panel.entries.length
                text: panel.controller.loading && panel.view === 0 ? "YouTube wird durchsucht …" : panel.view === 0 ? (panel.controller.lastQuery ? "Keine passenden Treffer. Filter ändern oder mehr laden." : "Suchbegriff eingeben und Enter drücken.") : panel.view === 1 ? "Noch nichts gemerkt. Mit M oder dem Lesezeichen Videos speichern." : panel.view === 2 ? "Noch keine Videos über dieses Plugin geöffnet." : "Warteschlange leer. Mit Q Videos hinzufügen."
            }
        }

        Row {
            visible: panel.view === 0
            spacing: 8

            DankButton {
                text: "Mehr laden"
                buttonHeight: 30
                enabled: !!panel.controller.lastQuery && !panel.controller.loading && !panel.controller.exhausted
                onClicked: panel.controller.search(panel.controller.lastQuery, true)
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: 11
                color: Theme.surfaceVariantText
                text: panel.controller.exhausted ? "Keine weiteren Treffer im Suchfenster (max. 50)." : "Je 10 weitere · erneute Suche"
            }
        }

        Row {
            width: parent.width
            spacing: 6

            Text {
                width: parent.width - (retry.visible ? 104 : 0)
                height: 34
                text: panel.controller.errorMessage || panel.controller.notice
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                maximumLineCount: 2
                color: panel.controller.errorMessage ? Theme.error : Theme.surfaceVariantText
                font.pixelSize: 11
            }

            DankButton {
                id: retry

                visible: !!panel.controller.errorMessage && panel.view === 0
                text: "Wiederholen"
                buttonHeight: 30
                horizontalPadding: 6
                enabled: !panel.controller.loading
                onClicked: panel.controller.search(field.text, false)
            }
        }
    }
}
