pragma ComponentBehavior: Bound

import QtQuick
import "js/Companion.js" as Model
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    id: root

    function erase(action) {
        var current = loadState("companion", null);
        saveState("companion", Model.change(current, action, null, new Date().toISOString()));
    }

    pluginId: "youtubeSearch"

    StyledText {
        text: "YouTube Companion · lokal und ohne Konto"
        color: Theme.surfaceText
        font.pixelSize: Theme.fontSizeLarge
    }

    SelectionSetting {
        settingKey: "player"
        label: "Standardplayer"
        defaultValue: "auto"
        description: "Automatisch: mpv Video, falls verfügbar; sonst Browser. Audio benötigt mpv."
        options: [
            {
                "label": "Automatisch",
                "value": "auto"
            },
            {
                "label": "Browser",
                "value": "browser"
            },
            {
                "label": "mpv Video",
                "value": "video"
            },
            {
                "label": "mpv Audio",
                "value": "audio"
            }
        ]
    }

    SelectionSetting {
        settingKey: "contentFilter"
        label: "Standard-Inhaltsfilter"
        defaultValue: "all"
        description: "Filter nur auf geladenen Treffern, mit positiven Shorts-/Live-Metadaten. Exklusiv normale Videos ist nicht zuverlässig bestimmbar."
        options: [
            {
                "label": "Alle unterstützten Inhalte",
                "value": "all"
            },
            {
                "label": "Shorts (belegt)",
                "value": "shorts"
            },
            {
                "label": "Livestreams (belegt)",
                "value": "live"
            }
        ]
    }

    SelectionSetting {
        settingKey: "lengthFilter"
        label: "Standard-Videolänge"
        defaultValue: "all"
        options: [
            {
                "label": "Alle",
                "value": "all"
            },
            {
                "label": "Unter 4 Minuten",
                "value": "short"
            },
            {
                "label": "4 bis 20 Minuten",
                "value": "medium"
            },
            {
                "label": "Über 20 Minuten",
                "value": "long"
            }
        ]
    }

    StyledText {
        width: parent.width
        wrapMode: Text.Wrap
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
        text: "Sortierung: Relevanz. Neueste zuerst ist nicht verfügbar. Je Suche werden maximal 50 Treffer angefragt. Einstellungen im Popout gelten für die aktuelle Sitzung."
    }

    ToggleSetting {
        settingKey: "searchHistory"
        label: "Suchverlauf lokal speichern"
        description: "Letzte 25 Suchanfragen. Deaktivieren löscht vorhandene Einträge nicht."
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "openHistory"
        label: "Öffnungsverlauf lokal speichern"
        description: "Letzte 100 an den Player übergebene Videos; keine Bestätigung der Wiedergabe."
        defaultValue: true
    }

    DankButton {
        text: "Suchverlauf löschen"
        onClicked: root.erase("clearSearches")
    }

    DankButton {
        text: "Öffnungsverlauf löschen"
        onClicked: root.erase("clearOpened")
    }

    DankButton {
        text: "Beide Verläufe löschen"
        onClicked: {
            root.erase("clearSearches");
            root.erase("clearOpened");
        }
    }
}
