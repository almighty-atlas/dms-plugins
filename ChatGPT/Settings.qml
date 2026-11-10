pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.DCommon.Widgets

PluginSettings {
    pluginId: "chatgptWeb"

    StyledText {
        width: parent.width
        text: "ChatGPT Web · ohne API-Schlüssel"
        color: Theme.surfaceText
        font.pixelSize: Theme.fontSizeLarge
    }

    SelectionSetting {
        settingKey: "browserMode"
        label: "Browsermodus"
        defaultValue: "isolated"
        description: "Isoliert: eigenes Zen-Profil mit CSS, einmalige Anmeldung nötig. Bestehend: normales Zen-Profil, keine automatische CSS-Injektion."
        options: [
            { "label": "Zen – eigenes Designprofil", "value": "isolated" },
            { "label": "Zen – bestehende Sitzung", "value": "existing" },
            { "label": "Systembrowser", "value": "system" }
        ]
    }

    ToggleSetting {
        settingKey: "materialTheme"
        label: "DMS-Farben übernehmen"
        defaultValue: true
        description: "Echte DMS-Farben inklusive Light/Dark und Custom Themes. CSS wird automatisch vorbereitet, aber erst nach vollständigem Beenden und erneutem Öffnen des isolierten Zen-Profils geladen."
    }

    ToggleSetting {
        settingKey: "compactMode"
        label: "Zen Compact Mode"
        defaultValue: true
        description: "Nur im isolierten Profil. Browserleisten bleiben per Hover und Ctrl+L erreichbar; Ctrl+Alt+S blendet die Seitenleiste ein. Änderungen benötigen einen vollständigen Browserneustart."
    }

    ToggleSetting {
        settingKey: "followOutput"
        label: "Fenster zum angeklickten Monitor holen"
        defaultValue: false
        description: "Beim ersten Öffnen auf dem DankBar-Monitor platzieren. Weitere Klicks fokussieren standardmäßig nur, ohne eigene Position/Größe zu verändern. Optional wird das bestehende isolierte Fenster zum angeklickten Monitor verschoben."
    }

    StyledText {
        width: parent.width
        text: "Klick auf die DankBar-Pill öffnet ChatGPT. Login und Unterhaltung laufen direkt über chatgpt.com. Kein API-Key, keine Weiterleitung an einen Drittanbieter. Die experimentelle WebView-Variante ist noch nicht enthalten."
        wrapMode: Text.WordWrap
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
    }
}
