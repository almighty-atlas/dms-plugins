pragma ComponentBehavior: Bound

import "../js/Companion.js" as Model
import QtQuick
import Quickshell.Io
import qs.Common

Item {
    id: root

    property var service: null
    property string pluginId: "youtubeSearch"
    property var state: Model.empty()
    property var results: []
    property string lastQuery: ""
    property string errorMessage: ""
    property string notice: ""
    property bool loading: false
    property bool exhausted: false
    property int requestedCount: 0
    property int requestId: 0
    property int activeRequestId: -1
    property var pendingSearch: null
    property bool alive: true
    property bool mpvAvailable: false
    property int activePlayers: 0
    property int settingsRevision: 0

    signal searchStarted(bool more)

    function setting(key, fallback) {
        var revision = settingsRevision;
        return service ? service.loadPluginData(pluginId, key, fallback) : fallback;
    }

    function snapshot() {
        return service ? service.loadPluginState(pluginId, "companion", null) : null;
    }

    function reloadState() {
        state = Model.normalize(snapshot());
    }

    function mutate(action, value) {
        if (!service) {
            errorMessage = "Lokaler Speicher ist noch nicht verfügbar.";
            return false;
        }
        try {
            var before = snapshot();
            var next = Model.change(before, action, value, new Date().toISOString());
            if (JSON.stringify(before) !== JSON.stringify(next))
                service.savePluginState(pluginId, "companion", next);

            state = next;
            return true;
        } catch (e) {
            errorMessage = String(e.message || e);
            return false;
        }
    }

    function search(input, more) {
        var term = Model.query(input);
        if (!term || term.length > 200) {
            errorMessage = term ? "Suchbegriff zu lang (maximal 200 Zeichen)." : "Bitte einen Suchbegriff eingeben.";
            return;
        }
        if (loading) {
            if (more || term === lastQuery)
                return;
            // Coalesce rapid requests; only one yt-dlp process runs per widget.
            pendingSearch = term;
            ++requestId;
            return;
        }
        if (more && (term !== lastQuery || exhausted || requestedCount >= 50))
            return;

        lastQuery = term;
        requestedCount = more ? Math.min(50, requestedCount + 10) : 10;
        if (!more)
            results = [];

        exhausted = false;
        errorMessage = "";
        notice = "";
        loading = true;
        if (setting("searchHistory", true))
            mutate("search", term);

        searchStarted(!!more);
        var token = ++requestId;
        activeRequestId = token;
        var count = requestedCount;
        watchdog.restart();
        try {
            Proc.runCommand(null, Model.searchArgs(term, count), (output, code) => {
                if (!root.alive || root.activeRequestId !== token)
                    return;

                if (root.requestId !== token) {
                    if (root.pendingSearch !== null)
                        root.finishSearch();

                    return;
                }
                if (code !== 0) {
                    root.errorMessage = Model.processError("yt-dlp", code);
                    console.warn("youtubeSearch: yt-dlp exited with code", code);
                } else {
                    try {
                        var parsed = Model.parse(output);
                        // Preserve earlier results if YouTube reorders the growing search window.
                        root.results = Model.videos((more ? root.results : []).concat(parsed.items), 50);
                        root.exhausted = parsed.count < count || count >= 50 || root.results.length >= 50;
                    } catch (e) {
                        root.errorMessage = "Suchergebnisse konnten nicht gelesen werden (ungültiges JSON).";
                    }
                }
                root.finishSearch();
            }, 0, 25000, root);
        } catch (e) {
            errorMessage = "Suchprozess konnte nicht gestartet werden: " + e;
            finishSearch();
        }
    }

    function finishSearch() {
        watchdog.stop();
        loading = false;
        if (pendingSearch !== null) {
            var term = pendingSearch;
            pendingSearch = null;
            search(term, false);
        }
    }

    function play(items, mode) {
        if (!mode)
            mode = setting("player", "auto");

        if (mode === "auto")
            mode = mpvAvailable ? "video" : "browser";

        if (activePlayers >= 3) {
            errorMessage = "Bereits drei Player aktiv. Zuerst einen schließen.";
            return;
        }
        try {
            var args = Model.playbackArgs(items, mode);
            var child = playerComponent.createObject(root, {
                "command": args,
                "items": Model.videos(items, 50),
                "program": mode === "browser" ? "xdg-open" : "mpv"
            });
            if (!child)
                throw new Error("Player konnte nicht erzeugt werden.");

            ++activePlayers;
            errorMessage = "";
            notice = "Player wird gestartet …";
            child.running = true;
            child.startDeadline.start();
        } catch (e) {
            errorMessage = String(e.message || e);
        }
    }

    onServiceChanged: reloadState()
    onPluginIdChanged: reloadState()
    Component.onCompleted: {
        reloadState();
        // Local executable probe only: no network activity.
        Proc.runCommand(null, ["/usr/bin/env", "mpv", "--no-config", "--version"], (output, code) => {
            if (root.alive)
                root.mpvAvailable = code === 0;
        }, 0, 5000, root);
    }
    Component.onDestruction: {
        alive = false;
        ++requestId;
        pendingSearch = null;
    }

    Connections {
        function onPluginStateChanged(id) {
            if (id === root.pluginId)
                root.reloadState();
        }

        function onPluginDataChanged(id) {
            if (id === root.pluginId)
                ++root.settingsRevision;
        }

        target: root.service
    }

    Timer {
        id: watchdog
        objectName: "searchWatchdog"

        interval: 30000
        onTriggered: {
            ++root.requestId;
            root.activeRequestId = -1;
            root.pendingSearch = null;
            root.loading = false;
            root.errorMessage = "Keine Prozessantwort nach 30 Sekunden. Erneut versuchen; DMS-Logs prüfen.";
            console.warn("youtubeSearch: no callback from Proc.runCommand within 30 seconds");
        }
    }

    Component {
        id: playerComponent

        Process {
            id: player
            objectName: "playerProcess"
            property bool released: false

            property var items: []
            property string program: "mpv"

            onStarted: {
                deadline.stop();
                root.notice = "Player gestartet. Dies bestätigt keine erfolgreiche Wiedergabe.";
                // Record launches, never claim that queued entries have been watched.
                if (root.setting("openHistory", true))
                    for (var i = items.length - 1; i >= 0; --i)
                        root.mutate("open", items[i]);
            }
            onExited: code => {
                if (released)
                    return;
                released = true;
                deadline.stop();
                if (code !== 0) {
                    root.notice = "";
                    root.errorMessage = Model.processError(program, code);
                }
                --root.activePlayers;
                player.destroy();
            }

            property Timer startDeadline: Timer {
                id: deadline

                interval: 5000
                onTriggered: {
                    if (player.released)
                        return;
                    player.released = true;
                    root.errorMessage = "Player-Prozess konnte nicht gestartet werden. DMS-Logs prüfen.";
                    player.running = false;
                    --root.activePlayers;
                    player.destroy();
                }
            }

            stdout: StdioCollector {}

            stderr: StdioCollector {}
        }
    }
}
