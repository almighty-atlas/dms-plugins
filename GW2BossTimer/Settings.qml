import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    id: root
    pluginId: "gw2BossTimer"
    
    StyledText {
        width: parent.width
        text: "GW2 World Boss Timer"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }
    
    StyledText {
        width: parent.width
        text: "Displays the next upcoming Guild Wars 2 world boss spawn with countdown timer."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }
    
    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outlineVariant
        anchors.topMargin: Theme.spacingM
        anchors.bottomMargin: Theme.spacingM
    }
    
    StyledText {
        width: parent.width
        text: "Features"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Bold
        color: Theme.surfaceText
    }
    
    StyledText {
        width: parent.width
        text: "• Shows next world boss spawn in the bar\n• Real-time countdown timer\n• Click to open full schedule popup\n• Right-click on widget or boss entry to copy waypoint link\n• All times displayed in UTC"
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
        lineHeight: 1.4
    }
    
    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outlineVariant
        anchors.topMargin: Theme.spacingM
        anchors.bottomMargin: Theme.spacingM
    }
    
    StyledText {
        width: parent.width
        text: "Schedule Information"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Bold
        color: Theme.surfaceText
    }
    
    StyledText {
        width: parent.width
        text: "Times shown are in UTC. When displayed in-game, they appear in your local timezone (CET/UTC+1 in winter, CEST/UTC+2 in summer for Germany).\n\nSchedule updates happen every 2 hours on a rotating basis. For the latest schedule or if times seem incorrect, check the official in-game timer with /wiki wb or visit the GW2 Wiki."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
        lineHeight: 1.4
    }
}
