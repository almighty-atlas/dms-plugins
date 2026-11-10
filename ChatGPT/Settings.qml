pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

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
        description: "Im isolierten Zen-Profil werden vor dem Start CSS-Farben aus ~/.cache/dms/dms-colors.json generiert. Änderungen werden beim nächsten vollständigen Browserstart sichtbar."
    }

    StyledText {
        width: parent.width
        text: "Klick auf die DankBar-Pill öffnet ChatGPT. Login und Unterhaltung laufen direkt über chatgpt.com. Kein API-Key, keine Weiterleitung an einen Drittanbieter. Die experimentelle WebView-Variante ist noch nicht enthalten."
        wrapMode: Text.WordWrap
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
    }
}
