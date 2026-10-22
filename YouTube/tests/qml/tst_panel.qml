import QtQuick
import QtTest
import qs.Common
import "../../components"

Item {
    id: host
    width: 520
    height: 660
    Component {
        id: serviceFactory
        QtObject {
            property var data: null
            signal pluginStateChanged(string id)
            signal pluginDataChanged(string id)
            function loadPluginState(id, key, fallback) {
                return data || fallback;
            }
            function savePluginState(id, key, value) {
                data = value;
                pluginStateChanged(id);
            }
            function loadPluginData(id, key, fallback) {
                return fallback;
            }
        }
    }
    Component {
        id: controllerFactory
        CompanionController {}
    }
    Component {
        id: panelFactory
        CompanionPanel {
            width: 520
            thumbnailsEnabled: false
        }
    }
    Component {
        id: popoutFactory
        QtObject {
            property bool shouldBeVisible: false
        }
    }
    TestCase {
        id: tests
        name: "CompanionPanel"
        when: windowShown
        property var panel
        property var backend
        property var popout
        function init() {
            Proc.reset();
            var service = createTemporaryObject(serviceFactory, host);
            backend = createTemporaryObject(controllerFactory, host, {
                service: service
            });
            popout = createTemporaryObject(popoutFactory, host);
            panel = createTemporaryObject(panelFactory, host, {
                controller: backend,
                parentPopout: popout
            });
            verify(panel !== null);
            popout.shouldBeVisible = true;
            wait(10);
        }
        function test_keyboard_and_typing() {
            var field = findChild(panel, "searchField"), list = findChild(panel, "videoList");
            tryCompare(field, "activeFocus", true);
            keyClick(Qt.Key_M, Qt.ShiftModifier);
            keyClick(Qt.Key_Q, Qt.ShiftModifier);
            compare(field.text, "mq");
            compare(backend.state.queue.length, 0);
            keyClick(Qt.Key_Return);
            compare(Proc.calls.length, 2);
            Proc.reply(1, JSON.stringify({
                entries: [
                    {
                        id: "abcdefghijk",
                        title: "Very long title ".repeat(50)
                    },
                    {
                        id: "123456789_-"
                    }
                ]
            }), 0);
            keyClick(Qt.Key_Down);
            wait(10);
            compare(list.currentIndex, 0);
            keyClick(Qt.Key_Return, Qt.ControlModifier);
            wait(1);
            var player = findChild(backend, "playerProcess");
            verify(player.command.indexOf("--no-video") > 0);
            player.exited(0);
            keyClick(Qt.Key_M);
            compare(backend.state.saved.length, 1);
            keyClick(Qt.Key_Q);
            compare(backend.state.queue.length, 1);
            keyClick(Qt.Key_Down);
            compare(list.currentIndex, 1);
            keyClick(Qt.Key_Up);
            compare(list.currentIndex, 0);
            keyClick(Qt.Key_K, Qt.ControlModifier);
            tryCompare(field, "activeFocus", true);
            keyClick(Qt.Key_Down);
            keyClick(Qt.Key_Escape);
            tryCompare(field, "activeFocus", true);
        }
        function test_reopen_focus() {
            var field = findChild(panel, "searchField");
            field.focus = false;
            popout.shouldBeVisible = false;
            popout.shouldBeVisible = true;
            tryCompare(field, "activeFocus", true);
        }
        function test_small_height_empty_and_theme() {
            panel.availableHeight = 400;
            panel.width = 480;
            panel.filtersVisible = true;
            var list = findChild(panel, "videoList");
            for (var view = 0; view < 4; ++view) {
                panel.view = view;
                wait(1);
                compare(list.count, 0);
                verify(list.height >= 48);
                verify(panel.implicitHeight <= panel.availableHeight);
            }
            Theme.surfaceContainer = "white";
            Theme.surfaceText = "black";
            wait(1);
            Theme.surfaceContainer = "#222222";
            Theme.surfaceText = "white";
        }
        function test_scrolling_and_selection_after_more() {
            var entries = [];
            for (var i = 0; i < 20; ++i)
                entries.push({
                    id: ("00000000000" + i).slice(-11)
                });
            backend.results = entries.map(function (v) {
                return {
                    id: v.id,
                    title: "Video",
                    channel: "Kanal",
                    durationSeconds: null
                };
            });
            var list = findChild(panel, "videoList");
            wait(10);
            panel.focusRow(8);
            wait(10);
            compare(list.currentIndex, 8);
            verify(list.contentY > 0);
            backend.results = backend.results.concat([
                {
                    id: "abcdefghijk",
                    title: "More",
                    channel: "Test",
                    durationSeconds: 1
                }
            ]);
            compare(list.currentIndex, 8);
        }
    }
}
