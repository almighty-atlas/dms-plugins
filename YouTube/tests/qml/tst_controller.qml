import QtQuick
import QtTest
import qs.Common
import "../../components"

TestCase {
    id: tests
    name: "CompanionController"
    property var backend
    property var service
    property var first: ({
            id: "abcdefghijk",
            title: "Test",
            duration: 1
        })
    Component {
        id: fakeService
        QtObject {
            property var data: null
            property var settings: ({})
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
                return settings[key] === undefined ? fallback : settings[key];
            }
        }
    }
    Component {
        id: factory
        CompanionController {}
    }
    function init() {
        Proc.reset();
        service = createTemporaryObject(fakeService, tests);
        backend = createTemporaryObject(factory, tests, {
            service: service
        });
        compare(Proc.calls.length, 1); // mpv local probe
        Proc.reply(0, "mpv", 0);
        Proc.reset();
    }
    function test_search_lifecycle() {
        backend.search("", false);
        verify(backend.errorMessage.length > 0);
        compare(Proc.calls.length, 0);
        backend.search("x".repeat(201), false);
        compare(Proc.calls.length, 0);
        backend.search("linux", false);
        verify(backend.loading);
        compare(Proc.calls.length, 1);
        compare(Proc.calls[0].timeout, 25000);
        compare(Proc.calls[0].args[0], "/usr/bin/env");
        backend.search("linux", false);
        compare(Proc.calls.length, 1);
        Proc.reply(0, JSON.stringify({
            entries: [first, first]
        }), 0);
        verify(!backend.loading);
        compare(backend.results.length, 1);
        verify(backend.exhausted);
        backend.search("linux", false);
        Proc.reply(1, "broken", 0);
        verify(!backend.loading);
        verify(backend.errorMessage.indexOf("JSON") >= 0);
        backend.search("linux", false);
        Proc.reply(2, "", 127);
        verify(!backend.loading);
        verify(backend.errorMessage.indexOf("127") >= 0);
        backend.search("linux", false);
        Proc.reply(3, "", 124);
        verify(!backend.loading);
    }
    function test_coalesced_queries_and_stale() {
        backend.search("old", false);
        backend.search("second", false);
        backend.search("latest", false);
        compare(Proc.calls.length, 1);
        Proc.reply(0, JSON.stringify({
            entries: [first]
        }), 0);
        compare(backend.lastQuery, "latest");
        compare(backend.results.length, 0);
        verify(backend.loading);
        compare(Proc.calls.length, 2);
        Proc.reply(1, JSON.stringify({
            entries: []
        }), 0);
        verify(!backend.loading);
    }
    function test_timeout_and_late_reply() {
        backend.search("old", false);
        var timer = findChild(backend, "searchWatchdog");
        compare(timer.interval, 30000);
        timer.triggered();
        verify(!backend.loading);
        backend.search("new", false);
        Proc.reply(0, JSON.stringify({
            entries: [first]
        }), 0);
        verify(backend.loading);
        compare(backend.results.length, 0);
        Proc.reply(1, JSON.stringify({
            entries: [first]
        }), 0);
        verify(!backend.loading);
        compare(backend.results.length, 1);
    }
    function test_more_and_selection_window() {
        var entries = [];
        for (var i = 0; i < 10; ++i)
            entries.push({
                id: ("00000000000" + i).slice(-11)
            });
        backend.search("linux", false);
        Proc.reply(0, JSON.stringify({
            entries: entries
        }), 0);
        verify(!backend.exhausted);
        backend.search("linux", true);
        compare(Proc.calls[1].args.slice(-1)[0], "ytsearch20:linux");
        entries.push(first);
        Proc.reply(1, JSON.stringify({
            entries: entries
        }), 0);
        compare(backend.results.length, 11);
        verify(backend.exhausted);
    }
    function test_shared_state_and_privacy() {
        var other = createTemporaryObject(factory, tests, {
            service: service
        });
        verify(backend.mutate("save", first));
        compare(other.state.saved.length, 1);
        verify(other.mutate("queue", first));
        compare(backend.state.queue.length, 1);
        verify(other.mutate("save", first));
        compare(backend.state.saved.length, 0);
        service.settings = {
            searchHistory: false,
            openHistory: false
        };
        service.pluginDataChanged("youtubeSearch");
        backend.search("private", false);
        Proc.reply(1, JSON.stringify({
            entries: []
        }), 0);
        compare(backend.state.searches.length, 0);
        var reloaded = createTemporaryObject(factory, tests, {
            service: service
        });
        compare(reloaded.state.queue.length, 1);
    }
    function test_player_arguments_history_and_failure() {
        backend.play([first], "audio");
        wait(1);
        var process = findChild(backend, "playerProcess");
        verify(process !== null);
        compare(process.command[0], "/usr/bin/env");
        verify(process.command.indexOf("--no-video") > 0);
        compare(backend.state.opened.length, 1);
        process.exited(127);
        compare(backend.activePlayers, 0);
        verify(backend.errorMessage.indexOf("127") > 0);
        wait(1);
        backend.mpvAvailable = false;
        backend.play([first], "auto");
        wait(1);
        process = findChild(backend, "playerProcess");
        compare(process.command[1], "xdg-open");
        process.exited(0);
    }
    function test_destroyed_owner() {
        var temporary = factory.createObject(tests, {
            service: service
        });
        temporary.search("test", false);
        var index = Proc.calls.length - 1;
        temporary.destroy();
        wait(1);
        Proc.reply(index, JSON.stringify({
            entries: [first]
        }), 0);
        verify(!Qt.isQtObject(Proc.calls[index].owner));
    }
}
