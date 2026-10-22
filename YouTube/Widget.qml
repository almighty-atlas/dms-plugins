import QtQuick
import Quickshell
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    // Compatible with the DMS 1.6 widget API and the Dux 2.0 compatibility wrappers.
    layerNamespacePlugin: "youtube-search"

    property var results: []
    property string lastQuery: ""
    property string errorMessage: ""
    property bool loading: false
    property bool timedOut: false
    property int searchRequestId: 0

    function formattedDuration(seconds) {
        if (typeof seconds !== "number" || !isFinite(seconds) || seconds < 0)
            return ""
        var total = Math.floor(seconds)
        var hours = Math.floor(total / 3600)
        var minutes = Math.floor((total % 3600) / 60)
        var secs = total % 60
        var pad = function(n) { return n < 10 ? "0" + n : "" + n }
        return hours ? hours + ":" + pad(minutes) + ":" + pad(secs) : minutes + ":" + pad(secs)
    }

    function validVideoId(id) {
        return typeof id === "string" && /^[A-Za-z0-9_-]{11}$/.test(id)
    }

    function startSearch(input) {
        var query = (input || "").trim()
        if (loading)
            return
        if (!query) {
            errorMessage = "Bitte einen Suchbegriff eingeben."
            return
        }
        if (query.length > 200) {
            errorMessage = "Der Suchbegriff ist zu lang (maximal 200 Zeichen)."
            return
        }

        lastQuery = query
        errorMessage = ""
        results = []
        timedOut = false
        loading = true
        searchTimeout.restart()

        // Arguments are passed without a shell, so search text is never evaluated as code.
        var requestId = ++root.searchRequestId
        try {
            // DMS's Qt/Quickshell process launcher could not start bare "yt-dlp"
            // even though its directory was present in the shell's PATH. Starting
            // the known system executable /usr/bin/env makes lookup happen in env,
            // which returns 126/127 instead of leaving a failed-start Process
            // without an exited signal or callback.
            // Arguments are passed directly (no shell, no command injection).
            Proc.runCommand(
                null,
                [
                    "/usr/bin/env", "yt-dlp", "--ignore-config", "--flat-playlist",
                    "--dump-single-json", "--no-warnings", "--skip-download",
                    "--socket-timeout", "10", "ytsearch10:" + query
                ],
                (output, exitCode) => {
                    // Discard stale responses, especially after a timeout/retry.
                    if (root.searchRequestId !== requestId || root.timedOut)
                        return
                    searchTimeout.stop()
                    root.loading = false
                    if (exitCode !== 0) {
                        if (exitCode === 127)
                            root.errorMessage = "yt-dlp wurde in der DMS-Umgebung nicht gefunden (Exit-Code 127)."
                        else if (exitCode === 126)
                            root.errorMessage = "yt-dlp wurde gefunden, konnte aber nicht gestartet werden (Exit-Code 126)."
                        else if (exitCode === 124)
                            root.errorMessage = "yt-dlp hat das interne Zeitlimit von 25 Sekunden überschritten."
                        else
                            root.errorMessage = "yt-dlp fehlgeschlagen (Exit-Code " + exitCode + ")."
                        console.warn("youtubeSearch: yt-dlp exited with code", exitCode)
                        return
                    }
                    root.consumeResults(output)
                },
                0,
                25000,
                root
            )
        } catch (err) {
            searchTimeout.stop()
            root.loading = false
            root.errorMessage = "Suchprozess konnte nicht gestartet werden: " + err
            console.error("youtubeSearch: Proc.runCommand failed:", err)
        }
    }

    function consumeResults(output) {
        if (timedOut || !output || !output.trim())
            return
        try {
            var payload = JSON.parse(output)
            if (!payload || !Array.isArray(payload.entries))
                throw new Error("missing entries")
            var videos = []
            for (var i = 0; i < payload.entries.length && videos.length < 10; i++) {
                var entry = payload.entries[i]
                if (!entry || !validVideoId(entry.id))
                    continue
                videos.push({
                    id: entry.id,
                    title: entry.title || "Unbenanntes Video",
                    channel: entry.channel || entry.uploader || "Unbekannter Kanal",
                    duration: formattedDuration(entry.duration)
                })
            }
            results = videos
            errorMessage = videos.length ? "" : "Keine Videos gefunden."
        } catch (err) {
            errorMessage = "Suchergebnisse konnten nicht gelesen werden."
        }
    }

    function openVideo(videoId, player) {
        if (!validVideoId(videoId))
            return
        var url = "https://www.youtube.com/watch?v=" + videoId
        if (player === "mpv")
            Quickshell.execDetached(["mpv", "--no-terminal", "--", url])
        else
            Quickshell.execDetached(["xdg-open", url])
    }

    Timer {
        id: searchTimeout
        interval: 30000
        repeat: false
        onTriggered: {
            if (!root.loading)
                return
            root.timedOut = true
            ++root.searchRequestId
            root.errorMessage = "DMS hat innerhalb von 30 Sekunden keine Antwort vom Suchprozess " +
                "erhalten. Bitte die DMS-Logs prüfen."
            console.warn("youtubeSearch: no callback from Proc.runCommand within 30 seconds")
            root.loading = false
        }
    }

    horizontalBarPill: Component {
        Item {
            implicitWidth: labelRow.implicitWidth + Theme.spacingM * 2
            implicitHeight: root.widgetThickness

            Row {
                id: labelRow
                anchors.centerIn: parent
                spacing: Theme.spacingS

                Text {
                    text: "▶"
                    color: Theme.primary
                    font.pixelSize: Theme.fontSizeLarge
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "YouTube"
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeMedium
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    verticalBarPill: Component {
        Item {
            implicitWidth: root.widgetThickness
            implicitHeight: 48

            Column {
                anchors.centerIn: parent
                spacing: 1
                Text {
                    text: "▶"
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: Theme.primary
                    font.pixelSize: Theme.fontSizeLarge
                }
                Text {
                    text: "YT"
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
        }
    }

    popoutContent: Component {
        PopoutComponent {
            id: panel
            headerText: "YouTube"
            detailsText: "Videos suchen und im Browser oder in mpv ansehen"
            showCloseButton: true

            Column {
                width: parent.width
                spacing: Theme.spacingM

                Row {
                    width: parent.width
                    spacing: Theme.spacingS

                    Rectangle {
                        width: parent.width - searchButton.width - parent.spacing
                        height: 42
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainerHigh
                        border.color: searchField.activeFocus ? Theme.primary : Theme.outlineVariant
                        border.width: 1

                        TextInput {
                            id: searchField
                            anchors.fill: parent
                            anchors.leftMargin: Theme.spacingM
                            anchors.rightMargin: Theme.spacingM
                            verticalAlignment: TextInput.AlignVCenter
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                            selectByMouse: true
                            activeFocusOnTab: true
                            text: root.lastQuery
                            onAccepted: root.startSearch(text)
                        }

                        Text {
                            anchors.fill: searchField
                            verticalAlignment: Text.AlignVCenter
                            text: "YouTube durchsuchen …"
                            color: Theme.surfaceVariantText
                            font.pixelSize: Theme.fontSizeMedium
                            visible: searchField.text.length === 0
                        }
                    }

                    Rectangle {
                        id: searchButton
                        width: 84
                        height: 42
                        radius: Theme.cornerRadius
                        color: root.loading ? Theme.surfaceContainerHigh : Theme.primary
                        opacity: root.loading ? 0.7 : 1

                        Text {
                            anchors.centerIn: parent
                            text: root.loading ? "Lädt …" : "Suchen"
                            font.pixelSize: Theme.fontSizeSmall
                            color: root.loading ? Theme.surfaceVariantText : Theme.onPrimary
                        }
                        MouseArea {
                            anchors.fill: parent
                            enabled: !root.loading
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.startSearch(searchField.text)
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: Math.max(250, root.popoutHeight -
                        panel.headerHeight - panel.detailsHeight - 42 - Theme.spacingXL * 3)

                    ListView {
                        id: videoList
                        anchors.fill: parent
                        spacing: Theme.spacingS
                        clip: true
                        model: root.results

                        delegate: Rectangle {
                            required property var modelData
                            width: videoList.width
                            height: 104
                            radius: Theme.cornerRadius
                            color: Theme.surfaceContainerHigh
                            border.color: Theme.outlineVariant
                            border.width: 1

                            Row {
                                anchors.fill: parent
                                anchors.margins: Theme.spacingS
                                spacing: Theme.spacingM

                                Image {
                                    width: 128
                                    height: 72
                                    anchors.verticalCenter: parent.verticalCenter
                                    fillMode: Image.PreserveAspectCrop
                                    source: "https://i.ytimg.com/vi/" + modelData.id + "/mqdefault.jpg"
                                    asynchronous: true
                                }

                                Column {
                                    width: parent.width - 128 - Theme.spacingM
                                    spacing: Theme.spacingXS

                                    Text {
                                        width: parent.width
                                        text: modelData.title
                                        color: Theme.surfaceText
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight: Font.DemiBold
                                        wrapMode: Text.Wrap
                                        maximumLineCount: 2
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        width: parent.width
                                        text: modelData.channel + (modelData.duration ? " · " + modelData.duration : "")
                                        color: Theme.surfaceVariantText
                                        font.pixelSize: Theme.fontSizeSmall
                                        elide: Text.ElideRight
                                    }
                                    Row {
                                        spacing: Theme.spacingM
                                        Text {
                                            text: "Im Browser öffnen"
                                            color: Theme.primary
                                            font.pixelSize: Theme.fontSizeSmall
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.openVideo(modelData.id, "browser")
                                            }
                                        }
                                        Text {
                                            text: "Mit mpv abspielen"
                                            color: Theme.primary
                                            font.pixelSize: Theme.fontSizeSmall
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.openVideo(modelData.id, "mpv")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        width: parent.width - Theme.spacingL * 2
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        color: Theme.surfaceVariantText
                        font.pixelSize: Theme.fontSizeMedium
                        visible: root.results.length === 0
                        text: root.loading ? "YouTube wird durchsucht …" :
                            root.errorMessage ? root.errorMessage :
                            "Suchbegriff eingeben und mit Enter bestätigen."
                    }
                }
            }
        }
    }

    popoutWidth: 540
    popoutHeight: 640
}
