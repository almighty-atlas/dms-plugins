import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins
import Quickshell

PluginComponent {
    id: root
    
    // World boss schedule - times are in CET (local time, UTC+1)
    // Complete 24-hour schedule from official GW2 Wiki
    // Both normal and hardcore world bosses are included
    // Source: https://wiki.guildwars2.com/wiki/World_boss
    property var worldBosses: [
        { name: "Admiral Taidha Covington", time: "01:00", zone: "Bloodtide Coast", waypoint: "[&BKgBAAA=]" },
        { name: "Tequatl the Sunless", time: "01:00", zone: "Sparkfly Fen", waypoint: "[&BNABAAA=]" },
        { name: "Svanir Shaman Chief", time: "01:15", zone: "Wayfarer Foothills", waypoint: "[&BMIDAAA=]" },
        { name: "Megadestroyer", time: "01:30", zone: "Mount Maelstrom", waypoint: "[&BM0CAAA=]" },
        { name: "Fire Elemental", time: "01:45", zone: "Metrica Province", waypoint: "[&BEcAAAA=]" },
        { name: "The Shatterer", time: "02:00", zone: "Blazeridge Steppes", waypoint: "[&BE4DAAA=]" },
        { name: "Evolved Jungle Wurm", time: "02:00", zone: "Bloodtide Coast", waypoint: "[&BKoBAAA=]" },
        { name: "Great Jungle Wurm", time: "02:15", zone: "Caledon Forest", waypoint: "[&BEEFAAA=]" },
        { name: "Modniir Ulgoth", time: "02:30", zone: "Harathi Hinterlands", waypoint: "[&BLAAAAA=]" },
        { name: "Shadow Behemoth", time: "02:45", zone: "Queensdale", waypoint: "[&BPcAAAA=]" },
        { name: "Golem Mark II", time: "03:00", zone: "Mount Maelstrom", waypoint: "[&BM0CAAA=]" },
        { name: "Karka Queen", time: "03:00", zone: "Southsun Cove", waypoint: "[&BNUGAAA=]" },
        { name: "Svanir Shaman Chief", time: "03:15", zone: "Wayfarer Foothills", waypoint: "[&BMIDAAA=]" },
        { name: "Claw of Jormag", time: "03:30", zone: "Frostgorge Sound", waypoint: "[&BHoCAAA=]" },
        { name: "Fire Elemental", time: "03:45", zone: "Metrica Province", waypoint: "[&BEcAAAA=]" },
        { name: "Admiral Taidha Covington", time: "04:00", zone: "Bloodtide Coast", waypoint: "[&BKgBAAA=]" },
        { name: "Tequatl the Sunless", time: "04:00", zone: "Sparkfly Fen", waypoint: "[&BNABAAA=]" },
        { name: "Great Jungle Wurm", time: "04:15", zone: "Caledon Forest", waypoint: "[&BEEFAAA=]" },
        { name: "Megadestroyer", time: "04:30", zone: "Mount Maelstrom", waypoint: "[&BM0CAAA=]" },
        { name: "Shadow Behemoth", time: "04:45", zone: "Queensdale", waypoint: "[&BPcAAAA=]" },
        { name: "The Shatterer", time: "05:00", zone: "Blazeridge Steppes", waypoint: "[&BE4DAAA=]" },
        { name: "Evolved Jungle Wurm", time: "05:00", zone: "Bloodtide Coast", waypoint: "[&BKoBAAA=]" },
        { name: "Svanir Shaman Chief", time: "05:15", zone: "Wayfarer Foothills", waypoint: "[&BMIDAAA=]" },
        { name: "Modniir Ulgoth", time: "05:30", zone: "Harathi Hinterlands", waypoint: "[&BLAAAAA=]" },
        { name: "Fire Elemental", time: "05:45", zone: "Metrica Province", waypoint: "[&BEcAAAA=]" },
        { name: "Golem Mark II", time: "06:00", zone: "Mount Maelstrom", waypoint: "[&BM0CAAA=]" },
        { name: "Great Jungle Wurm", time: "06:15", zone: "Caledon Forest", waypoint: "[&BEEFAAA=]" },
        { name: "Claw of Jormag", time: "06:30", zone: "Frostgorge Sound", waypoint: "[&BHoCAAA=]" },
        { name: "Shadow Behemoth", time: "06:45", zone: "Queensdale", waypoint: "[&BPcAAAA=]" },
        { name: "Admiral Taidha Covington", time: "07:00", zone: "Bloodtide Coast", waypoint: "[&BKgBAAA=]" },
        { name: "Karka Queen", time: "07:00", zone: "Southsun Cove", waypoint: "[&BNUGAAA=]" },
        { name: "Svanir Shaman Chief", time: "07:15", zone: "Wayfarer Foothills", waypoint: "[&BMIDAAA=]" },
        { name: "Megadestroyer", time: "07:30", zone: "Mount Maelstrom", waypoint: "[&BM0CAAA=]" },
        { name: "Fire Elemental", time: "07:45", zone: "Metrica Province", waypoint: "[&BEcAAAA=]" },
        { name: "The Shatterer", time: "08:00", zone: "Blazeridge Steppes", waypoint: "[&BE4DAAA=]" },
        { name: "Tequatl the Sunless", time: "08:00", zone: "Sparkfly Fen", waypoint: "[&BNABAAA=]" },
        { name: "Great Jungle Wurm", time: "08:15", zone: "Caledon Forest", waypoint: "[&BEEFAAA=]" },
        { name: "Modniir Ulgoth", time: "08:30", zone: "Harathi Hinterlands", waypoint: "[&BLAAAAA=]" },
        { name: "Shadow Behemoth", time: "08:45", zone: "Queensdale", waypoint: "[&BPcAAAA=]" },
        { name: "Golem Mark II", time: "09:00", zone: "Mount Maelstrom", waypoint: "[&BM0CAAA=]" },
        { name: "Evolved Jungle Wurm", time: "09:00", zone: "Bloodtide Coast", waypoint: "[&BKoBAAA=]" },
        { name: "Svanir Shaman Chief", time: "09:15", zone: "Wayfarer Foothills", waypoint: "[&BMIDAAA=]" },
        { name: "Claw of Jormag", time: "09:30", zone: "Frostgorge Sound", waypoint: "[&BHoCAAA=]" },
        { name: "Fire Elemental", time: "09:45", zone: "Metrica Province", waypoint: "[&BEcAAAA=]" },
        { name: "Admiral Taidha Covington", time: "10:00", zone: "Bloodtide Coast", waypoint: "[&BKgBAAA=]" },
        { name: "Great Jungle Wurm", time: "10:15", zone: "Caledon Forest", waypoint: "[&BEEFAAA=]" },
        { name: "Megadestroyer", time: "10:30", zone: "Mount Maelstrom", waypoint: "[&BM0CAAA=]" },
        { name: "Shadow Behemoth", time: "10:45", zone: "Queensdale", waypoint: "[&BPcAAAA=]" },
        { name: "The Shatterer", time: "11:00", zone: "Blazeridge Steppes", waypoint: "[&BE4DAAA=]" },
        { name: "Svanir Shaman Chief", time: "11:15", zone: "Wayfarer Foothills", waypoint: "[&BMIDAAA=]" },
        { name: "Modniir Ulgoth", time: "11:30", zone: "Harathi Hinterlands", waypoint: "[&BLAAAAA=]" },
        { name: "Karka Queen", time: "11:30", zone: "Southsun Cove", waypoint: "[&BNUGAAA=]" },
        { name: "Fire Elemental", time: "11:45", zone: "Metrica Province", waypoint: "[&BEcAAAA=]" },
        { name: "Golem Mark II", time: "12:00", zone: "Mount Maelstrom", waypoint: "[&BM0CAAA=]" },
        { name: "Great Jungle Wurm", time: "12:15", zone: "Caledon Forest", waypoint: "[&BEEFAAA=]" },
        { name: "Claw of Jormag", time: "12:30", zone: "Frostgorge Sound", waypoint: "[&BHoCAAA=]" },
        { name: "Tequatl the Sunless", time: "12:30", zone: "Sparkfly Fen", waypoint: "[&BNABAAA=]" },
        { name: "Shadow Behemoth", time: "12:45", zone: "Queensdale", waypoint: "[&BPcAAAA=]" },
        { name: "Admiral Taidha Covington", time: "13:00", zone: "Bloodtide Coast", waypoint: "[&BKgBAAA=]" },
        { name: "Svanir Shaman Chief", time: "13:15", zone: "Wayfarer Foothills", waypoint: "[&BMIDAAA=]" },
        { name: "Megadestroyer", time: "13:30", zone: "Mount Maelstrom", waypoint: "[&BM0CAAA=]" },
        { name: "Evolved Jungle Wurm", time: "13:30", zone: "Bloodtide Coast", waypoint: "[&BKoBAAA=]" },
        { name: "Fire Elemental", time: "13:45", zone: "Metrica Province", waypoint: "[&BEcAAAA=]" },
        { name: "The Shatterer", time: "14:00", zone: "Blazeridge Steppes", waypoint: "[&BE4DAAA=]" },
        { name: "Great Jungle Wurm", time: "14:15", zone: "Caledon Forest", waypoint: "[&BEEFAAA=]" },
        { name: "Modniir Ulgoth", time: "14:30", zone: "Harathi Hinterlands", waypoint: "[&BLAAAAA=]" },
        { name: "Shadow Behemoth", time: "14:45", zone: "Queensdale", waypoint: "[&BPcAAAA=]" },
        { name: "Golem Mark II", time: "15:00", zone: "Mount Maelstrom", waypoint: "[&BM0CAAA=]" },
        { name: "Svanir Shaman Chief", time: "15:15", zone: "Wayfarer Foothills", waypoint: "[&BMIDAAA=]" },
        { name: "Claw of Jormag", time: "15:30", zone: "Frostgorge Sound", waypoint: "[&BHoCAAA=]" },
        { name: "Fire Elemental", time: "15:45", zone: "Metrica Province", waypoint: "[&BEcAAAA=]" },
        { name: "Admiral Taidha Covington", time: "16:00", zone: "Bloodtide Coast", waypoint: "[&BKgBAAA=]" },
        { name: "Karka Queen", time: "16:00", zone: "Southsun Cove", waypoint: "[&BNUGAAA=]" },
        { name: "Great Jungle Wurm", time: "16:15", zone: "Caledon Forest", waypoint: "[&BEEFAAA=]" },
        { name: "Megadestroyer", time: "16:30", zone: "Mount Maelstrom", waypoint: "[&BM0CAAA=]" },
        { name: "Shadow Behemoth", time: "16:45", zone: "Queensdale", waypoint: "[&BPcAAAA=]" },
        { name: "The Shatterer", time: "17:00", zone: "Blazeridge Steppes", waypoint: "[&BE4DAAA=]" },
        { name: "Tequatl the Sunless", time: "17:00", zone: "Sparkfly Fen", waypoint: "[&BNABAAA=]" },
        { name: "Svanir Shaman Chief", time: "17:15", zone: "Wayfarer Foothills", waypoint: "[&BMIDAAA=]" },
        { name: "Modniir Ulgoth", time: "17:30", zone: "Harathi Hinterlands", waypoint: "[&BLAAAAA=]" },
        { name: "Fire Elemental", time: "17:45", zone: "Metrica Province", waypoint: "[&BEcAAAA=]" },
        { name: "Golem Mark II", time: "18:00", zone: "Mount Maelstrom", waypoint: "[&BM0CAAA=]" },
        { name: "Evolved Jungle Wurm", time: "18:00", zone: "Bloodtide Coast", waypoint: "[&BKoBAAA=]" },
        { name: "Great Jungle Wurm", time: "18:15", zone: "Caledon Forest", waypoint: "[&BEEFAAA=]" },
        { name: "Claw of Jormag", time: "18:30", zone: "Frostgorge Sound", waypoint: "[&BHoCAAA=]" },
        { name: "Shadow Behemoth", time: "18:45", zone: "Queensdale", waypoint: "[&BPcAAAA=]" },
        { name: "Admiral Taidha Covington", time: "19:00", zone: "Bloodtide Coast", waypoint: "[&BKgBAAA=]" },
        { name: "Karka Queen", time: "19:00", zone: "Southsun Cove", waypoint: "[&BNUGAAA=]" },
        { name: "Svanir Shaman Chief", time: "19:15", zone: "Wayfarer Foothills", waypoint: "[&BMIDAAA=]" },
        { name: "Megadestroyer", time: "19:30", zone: "Mount Maelstrom", waypoint: "[&BM0CAAA=]" },
        { name: "Fire Elemental", time: "19:45", zone: "Metrica Province", waypoint: "[&BEcAAAA=]" },
        { name: "The Shatterer", time: "20:00", zone: "Blazeridge Steppes", waypoint: "[&BE4DAAA=]" },
        { name: "Tequatl the Sunless", time: "20:00", zone: "Sparkfly Fen", waypoint: "[&BNABAAA=]" },
        { name: "Great Jungle Wurm", time: "20:15", zone: "Caledon Forest", waypoint: "[&BEEFAAA=]" },
        { name: "Modniir Ulgoth", time: "20:30", zone: "Harathi Hinterlands", waypoint: "[&BLAAAAA=]" },
        { name: "Shadow Behemoth", time: "20:45", zone: "Queensdale", waypoint: "[&BPcAAAA=]" },
        { name: "Golem Mark II", time: "21:00", zone: "Mount Maelstrom", waypoint: "[&BM0CAAA=]" },
        { name: "Evolved Jungle Wurm", time: "21:00", zone: "Bloodtide Coast", waypoint: "[&BKoBAAA=]" },
        { name: "Svanir Shaman Chief", time: "21:15", zone: "Wayfarer Foothills", waypoint: "[&BMIDAAA=]" },
        { name: "Claw of Jormag", time: "21:30", zone: "Frostgorge Sound", waypoint: "[&BHoCAAA=]" },
        { name: "Fire Elemental", time: "21:45", zone: "Metrica Province", waypoint: "[&BEcAAAA=]" },
        { name: "Admiral Taidha Covington", time: "22:00", zone: "Bloodtide Coast", waypoint: "[&BKgBAAA=]" },
        { name: "Great Jungle Wurm", time: "22:15", zone: "Caledon Forest", waypoint: "[&BEEFAAA=]" },
        { name: "Megadestroyer", time: "22:30", zone: "Mount Maelstrom", waypoint: "[&BM0CAAA=]" },
        { name: "Shadow Behemoth", time: "22:45", zone: "Queensdale", waypoint: "[&BPcAAAA=]" },
        { name: "The Shatterer", time: "23:00", zone: "Blazeridge Steppes", waypoint: "[&BE4DAAA=]" },
        { name: "Svanir Shaman Chief", time: "23:15", zone: "Wayfarer Foothills", waypoint: "[&BMIDAAA=]" },
        { name: "Modniir Ulgoth", time: "23:30", zone: "Harathi Hinterlands", waypoint: "[&BLAAAAA=]" },
        { name: "Fire Elemental", time: "23:45", zone: "Metrica Province", waypoint: "[&BEcAAAA=]" },
        { name: "Golem Mark II", time: "00:00", zone: "Mount Maelstrom", waypoint: "[&BM0CAAA=]" },
        { name: "Karka Queen", time: "00:00", zone: "Southsun Cove", waypoint: "[&BNUGAAA=]" },
        { name: "Great Jungle Wurm", time: "00:15", zone: "Caledon Forest", waypoint: "[&BEEFAAA=]" },
        { name: "Claw of Jormag", time: "00:30", zone: "Frostgorge Sound", waypoint: "[&BHoCAAA=]" },
        { name: "Shadow Behemoth", time: "00:45", zone: "Queensdale", waypoint: "[&BPcAAAA=]" }
    ]
    
    // List of hardcore world bosses
    property var hardcoreBosses: ["Tequatl the Sunless", "Evolved Jungle Wurm", "Karka Queen"]
    
    // Test mode for double boss spawn - set to "00:00" to test, "" to disable
    property string testTime: ""
    
    // Track cycling through bosses on right-click
    property int copiedBossIndex: 0
    
    property var nextBoss: null
    property var nextBosses: []
    property var upcomingBossesForList: []
    property string displayText: "Loading..."
    property string timeLeft: ""
    property real button1Opacity: 0
    property real button2Opacity: 0
    
    Timer {
        id: updateTimer
        interval: 1000
        running: true
        repeat: true
        onTriggered: updateBossInfo()
    }
    
    function isHardcoreBoss(bossName) {
        return root.hardcoreBosses.indexOf(bossName) !== -1
    }
    
    function updateBossInfo() {
        var now = new Date()
        var currentHours = now.getHours()
        var currentMinutes = now.getMinutes()
        var currentSeconds = now.getSeconds()
        
        // Test mode override
        if (root.testTime !== "") {
            var testParts = root.testTime.split(':')
            currentHours = parseInt(testParts[0])
            currentMinutes = parseInt(testParts[1])
        }
        
        var currentTotalMinutes = currentHours * 60 + currentMinutes
        var currentTotalSeconds = (currentHours * 3600) + (currentMinutes * 60) + currentSeconds
        var upcoming = []
        
        for (var i = 0; i < worldBosses.length; i++) {
            var boss = worldBosses[i]
            var timeParts = boss.time.split(':')
            var hours = parseInt(timeParts[0])
            var minutes = parseInt(timeParts[1])
            var bossMinutes = hours * 60 + minutes
            var bossSeconds = (hours * 3600) + (minutes * 60)
            
            if (bossSeconds > currentTotalSeconds) {
                upcoming.push(boss)
            }
        }
        
        // Update the list for the popout
        root.upcomingBossesForList = upcoming
        
        if (upcoming.length === 0) {
            nextBoss = worldBosses[0]
            nextBosses = [worldBosses[0]]
            root.upcomingBossesForList = [worldBosses[0]]
            var tomorrow = new Date(now)
            tomorrow.setDate(tomorrow.getDate() + 1)
            var tomorrowHours = parseInt(worldBosses[0].time.split(':')[0])
            var tomorrowMinutes = parseInt(worldBosses[0].time.split(':')[1])
            tomorrow.setHours(tomorrowHours, tomorrowMinutes, 0, 0)
            timeLeft = formatTimeLeft(tomorrow)
            displayText = worldBosses[0].name
        } else {
            nextBoss = upcoming[0]
            
            // Find all bosses at same time
            var nextTime = nextBoss.time
            nextBosses = []
            for (var j = 0; j < upcoming.length; j++) {
                if (upcoming[j].time === nextTime) {
                    nextBosses.push(upcoming[j])
                } else {
                    break
                }
            }
            
            var bossHours = parseInt(nextBoss.time.split(':')[0])
            var bossMinutes = parseInt(nextBoss.time.split(':')[1])
            var bossDate = new Date(now)
            bossDate.setHours(bossHours, bossMinutes, 0, 0)
            
            if (bossMinutes + (bossHours * 60) < currentTotalMinutes) {
                bossDate.setDate(bossDate.getDate() + 1)
            }
            
            timeLeft = formatTimeLeft(bossDate)
            
            // Build display text
            var names = []
            for (var k = 0; k < nextBosses.length; k++) {
                names.push(nextBosses[k].name)
            }
            displayText = names.join(" / ")
        }
        
        // Update button opacities
        button1Opacity = (nextBosses.length > 0) ? 1 : 0
        button2Opacity = (nextBosses.length > 1) ? 1 : 0
    }
    
    function formatTimeLeft(targetTime) {
        var now = new Date()
        var diff = targetTime - now
        
        if (diff < 0) diff = 0
        
        var hours = Math.floor(diff / 3600000)
        var minutes = Math.floor((diff % 3600000) / 60000)
        var seconds = Math.floor((diff % 60000) / 1000)
        
        if (hours > 0) {
            return hours + "h " + minutes + "m"
        } else if (minutes > 0) {
            return minutes + "m " + seconds + "s"
        } else {
            return seconds + "s"
        }
    }
    
    function copyWaypoint(waypoint, name) {
        Quickshell.execDetached(["sh", "-c", "echo -n '" + waypoint + "' | wl-copy"])
        ToastService.showInfo("Waypoint for " + name + " has been copied!", "")
    }
    
    function handleWidgetRightClick() {
        if (root.nextBosses.length === 0) return
        
        if (root.nextBosses.length > 1) {
            root.copiedBossIndex = (root.copiedBossIndex + 1) % root.nextBosses.length
            var boss = root.nextBosses[root.copiedBossIndex]
            root.copyWaypoint(boss.waypoint, boss.name)
        } else {
            root.copyWaypoint(root.nextBosses[0].waypoint, root.nextBosses[0].name)
        }
    }
    
    Component.onCompleted: {
        updateBossInfo()
    }
    
    horizontalBarPill: Component {
        Rectangle {
            color: "transparent"
            implicitWidth: mainRow.implicitWidth + Theme.spacingM
            implicitHeight: mainRow.implicitHeight + Theme.spacingM
            
            Row {
                id: mainRow
                spacing: Theme.spacingXS
                anchors.centerIn: parent
                
                DankIcon {
                    name: "schedule"
                    size: root.iconSize
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }
                
                Column {
                    spacing: 0
                    anchors.verticalCenter: parent.verticalCenter
                    
                    StyledText {
                        text: root.displayText
                        font.pixelSize: Theme.fontSizeSmall
                        color: root.nextBosses.length > 0 && root.isHardcoreBoss(root.nextBosses[0].name) ? Theme.warning : Theme.surfaceText
                        maximumLineCount: 2
                    }
                    
                    StyledText {
                        text: root.timeLeft
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        font.weight: Font.Bold
                    }
                }
                
                Rectangle {
                    width: 20
                    height: 20
                    radius: 4
                    anchors.verticalCenter: parent.verticalCenter
                    color: mouseArea1.containsMouse ? Theme.withAlpha(Theme.primary, 0.2) : Theme.surfaceContainerHigh
                    border.color: Theme.primary
                    border.width: 1
                    opacity: root.button1Opacity
                    
                    DankIcon {
                        anchors.centerIn: parent
                        name: "content_copy"
                        size: 12
                        color: Theme.primary
                    }
                    
                    MouseArea {
                        id: mouseArea1
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: {
                            if (root.nextBosses.length > 0) {
                                root.copyWaypoint(root.nextBosses[0].waypoint, root.nextBosses[0].name)
                            }
                        }
                    }
                }
                
                Rectangle {
                    width: 20
                    height: 20
                    radius: 4
                    anchors.verticalCenter: parent.verticalCenter
                    color: mouseArea2.containsMouse ? Theme.withAlpha(Theme.warning, 0.2) : Theme.surfaceContainerHigh
                    border.color: Theme.warning
                    border.width: 1
                    opacity: root.button2Opacity
                    visible: root.button2Opacity > 0
                    
                    DankIcon {
                        anchors.centerIn: parent
                        name: "content_copy"
                        size: 12
                        color: Theme.warning
                    }
                    
                    MouseArea {
                        id: mouseArea2
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: {
                            if (root.nextBosses.length > 1) {
                                root.copyWaypoint(root.nextBosses[1].waypoint, root.nextBosses[1].name)
                            }
                        }
                    }
                }
            }
            
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                
                onClicked: {
                    root.handleWidgetRightClick()
                }
            }
        }
    }
    
    verticalBarPill: Component {
        Rectangle {
            color: "transparent"
            implicitWidth: contentColumn.implicitWidth + Theme.spacingM
            implicitHeight: contentColumn.implicitHeight + Theme.spacingM
            
            Column {
                id: contentColumn
                spacing: Theme.spacingXS
                anchors.centerIn: parent
                
                DankIcon {
                    name: "schedule"
                    size: root.iconSize
                    color: Theme.primary
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                
                Column {
                    spacing: 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    
                    StyledText {
                        text: root.displayText
                        font.pixelSize: Theme.fontSizeSmall
                        color: root.nextBosses.length > 0 && root.isHardcoreBoss(root.nextBosses[0].name) ? Theme.warning : Theme.surfaceText
                        anchors.horizontalCenter: parent.horizontalCenter
                        maximumLineCount: 2
                    }
                    
                    StyledText {
                        text: root.timeLeft
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        font.weight: Font.Bold
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
                
                Column {
                    spacing: Theme.spacingXS
                    anchors.horizontalCenter: parent.horizontalCenter
                    
                    Rectangle {
                        width: 20
                        height: 20
                        radius: 4
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: mouseArea3.containsMouse ? Theme.withAlpha(Theme.primary, 0.2) : Theme.surfaceContainerHigh
                        border.color: Theme.primary
                        border.width: 1
                        opacity: root.button1Opacity
                        
                        DankIcon {
                            anchors.centerIn: parent
                            name: "content_copy"
                            size: 12
                            color: Theme.primary
                        }
                        
                        MouseArea {
                            id: mouseArea3
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: {
                                if (root.nextBosses.length > 0) {
                                    root.copyWaypoint(root.nextBosses[0].waypoint, root.nextBosses[0].name)
                                }
                            }
                        }
                    }
                    
                    Rectangle {
                        width: 20
                        height: 20
                        radius: 4
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: mouseArea4.containsMouse ? Theme.withAlpha(Theme.warning, 0.2) : Theme.surfaceContainerHigh
                        border.color: Theme.warning
                        border.width: 1
                        opacity: root.button2Opacity
                        visible: root.button2Opacity > 0
                        
                        DankIcon {
                            anchors.centerIn: parent
                            name: "content_copy"
                            size: 12
                            color: Theme.warning
                        }
                        
                        MouseArea {
                            id: mouseArea4
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: {
                                if (root.nextBosses.length > 1) {
                                    root.copyWaypoint(root.nextBosses[1].waypoint, root.nextBosses[1].name)
                                }
                            }
                        }
                    }
                }
            }
            
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                
                onClicked: {
                    root.handleWidgetRightClick()
                }
            }
        }
    }
    
    popoutContent: Component {
        PopoutComponent {
            id: popoutColumn
            headerText: "GW2 World Boss Schedule"
            detailsText: "Upcoming spawns (CET)"
            showCloseButton: true
            
            Item {
                width: parent.width
                implicitHeight: root.popoutHeight - popoutColumn.headerHeight - popoutColumn.detailsHeight - Theme.spacingXL
                
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingM
                    color: Theme.surfaceContainer
                    radius: Theme.cornerRadius
                    
                    ListView {
                        id: bossList
                        anchors.fill: parent
                        anchors.margins: Theme.spacingS
                        spacing: Theme.spacingS
                        clip: true
                        
                        model: root.upcomingBossesForList
                        
                        delegate: Rectangle {
                            width: bossList.width
                            height: 60
                            radius: Theme.cornerRadius
                            color: modelData === root.nextBoss ? Theme.withAlpha(Theme.primary, 0.2) : Theme.surfaceContainerHigh
                            border.color: modelData === root.nextBoss ? Theme.primary : Theme.outlineVariant
                            border.width: 1
                            
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.RightButton
                                
                                onClicked: {
                                    if (mouse.button === Qt.RightButton) {
                                        root.copyWaypoint(modelData.waypoint, modelData.name)
                                    }
                                }
                            }
                            
                            Row {
                                anchors.fill: parent
                                anchors.margins: Theme.spacingS
                                spacing: Theme.spacingS
                                
                                Column {
                                    spacing: Theme.spacingXS
                                    width: parent.width - 30
                                    
                                    Row {
                                        spacing: Theme.spacingS
                                        width: parent.width
                                        
                                        StyledText {
                                            text: modelData.name
                                            font.pixelSize: Theme.fontSizeMedium
                                            font.weight: Font.Bold
                                            color: root.isHardcoreBoss(modelData.name) ? Theme.warning : Theme.surfaceText
                                            elide: Text.ElideRight
                                        }
                                        
                                        StyledText {
                                            text: modelData.time + " CET"
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: modelData === root.nextBoss ? Theme.primary : Theme.surfaceVariantText
                                            font.weight: Font.Bold
                                        }
                                    }
                                    
                                    StyledText {
                                        text: modelData.zone
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                    }
                                }
                                
                                Rectangle {
                                    width: 20
                                    height: 20
                                    radius: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: popoutBtn1.containsMouse ? Theme.withAlpha(Theme.primary, 0.2) : Theme.surfaceContainerHigh
                                    border.color: Theme.primary
                                    border.width: 1
                                    
                                    DankIcon {
                                        anchors.centerIn: parent
                                        name: "content_copy"
                                        size: 12
                                        color: Theme.primary
                                    }
                                    
                                    MouseArea {
                                        id: popoutBtn1
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onClicked: {
                                            root.copyWaypoint(modelData.waypoint, modelData.name)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    popoutWidth: 450
    popoutHeight: 600
}
