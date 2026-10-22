import QtQuick
import QtTest
import "../../js/Companion.js" as M

TestCase {
    name: "CompanionModel"
    property var first: ({
            id: "abcdefghijk",
            title: "Linux 日本語 <&>",
            channel: "Kanal",
            duration: 240
        })
    property var second: ({
            id: "123456789_-",
            title: "Second",
            duration: 1201
        })
    property string now: "2026-10-22T12:00:00.000Z"
    function test_video() {
        var v = M.video(first);
        compare(v.title, first.title);
        compare(v.durationSeconds, 240);
        compare(M.video({
            id: first.id
        }).channel, "Unbekannter Kanal");
        compare(M.video({
            id: first.id
        }).durationSeconds, null);
        compare(M.video({
            id: first.id,
            duration: "0"
        }).durationSeconds, null);
        compare(M.video({
            id: first.id,
            duration: -1
        }).durationSeconds, null);
        verify(M.video({
            id: first.id,
            live_status: "is_live"
        }).live);
        verify(!M.video({
            id: first.id,
            live_status: "was_live"
        }).live);
        verify(!M.video({
            id: first.id,
            duration: 30
        }).short);
        verify(M.video({
            id: first.id,
            url: "https://www.youtube.com/shorts/" + first.id
        }).short);
        compare(M.formatDuration(null), "");
        compare(M.formatDuration(0), "0:00");
        compare(M.formatDuration(3661), "1:01:01");
    }
    function test_parse() {
        var parsed = M.parse(JSON.stringify({
            entries: [first, first, null,
                {
                    id: "invalid"
                },
                second]
        }));
        compare(parsed.items.length, 2);
        compare(parsed.count, 5);
        for (var bad of ["", "{", "null", "{}", "[]", '{"entries":null}']) {
            var failed = false;
            try {
                M.parse(bad);
            } catch (e) {
                failed = true;
            }
            verify(failed);
        }
    }
    function test_urls_and_args() {
        for (var id of ["; rm -rf /", "abcdefghijk/", "https://evil", "", null, 42])
            compare(M.url(id), "");
        compare(M.url(first.id), "https://www.youtube.com/watch?v=" + first.id);
        var args = M.searchArgs('日本語 "$(touch /tmp/unsafe)"', 20);
        compare(args[0], "/usr/bin/env");
        compare(args[1], "yt-dlp");
        compare(args[args.length - 1], 'ytsearch20:日本語 "$(touch /tmp/unsafe)"');
        var audio = M.playbackArgs([first, second], "audio");
        compare(audio[0], "/usr/bin/env");
        verify(audio.indexOf("--no-video") > 0);
        compare(audio.slice(-3), ["--", M.url(first.id), M.url(second.id)]);
        verify(audio.indexOf("--ytdl-format=bestaudio/best") > 0);
    }
    function test_filters() {
        var v = M.video(first);
        verify(M.matches(v, "all", "medium"));
        verify(!M.matches(v, "all", "short"));
        verify(!M.matches(M.video({
            id: first.id
        }), "all", "short"));
        verify(!M.matches(v, "shorts", "all"));
        verify(!M.matches(v, "live", "all"));
        verify(M.matches(M.video({
            id: first.id,
            live_status: "is_live"
        }), "live", "all"));
        verify(M.matches(M.video(second), "all", "long"));
        verify(M.matches(M.video({
            id: first.id,
            duration: 1200
        }), "all", "medium"));
    }
    function test_saved_and_queue() {
        var s = M.change(null, "save", first, now);
        compare(s.saved.length, 1);
        compare(s.saved[0].savedAt, now);
        compare(M.change(s, "save", first, now).saved.length, 0);
        s = M.change(s, "queue", first, now);
        s = M.change(s, "queue", first, now);
        s = M.change(s, "queue", second, now);
        compare(s.queue.length, 2);
        s = M.change(s, "move", {
            id: second.id,
            offset: -1
        }, now);
        compare(s.queue[0].id, second.id);
        s = M.change(s, "removeQueue", first.id, now);
        compare(s.queue.length, 1);
        compare(M.change(s, "clearQueue", null, now).queue.length, 0);
    }
    function test_histories() {
        var s = null;
        for (var i = 0; i < 30; ++i)
            s = M.change(s, "search", "query " + i, now);
        compare(s.searches.length, 25);
        compare(s.searches[0], "query 29");
        s = M.change(s, "search", "query 10", now);
        compare(s.searches[0], "query 10");
        compare(s.searches.length, 25);
        s = M.change(s, "removeSearch", "query 10", now);
        compare(s.searches.length, 24);
        s = M.change(s, "open", first, now);
        s = M.change(s, "open", first, now);
        compare(s.opened.length, 1);
        compare(s.opened[0].openedAt, now);
        compare(M.change(s, "removeOpened", first.id, now).opened.length, 0);
        compare(M.change(s, "clearSearches", null, now).searches.length, 0);
        compare(M.change(s, "clearOpened", null, now).opened.length, 0);
    }
    function test_limits_and_migration() {
        var entries = [];
        for (var i = 0; i < 210; ++i)
            entries.push({
                id: ("00000000000" + i).slice(-11)
            });
        var s = M.normalize({
            version: 0,
            saved: entries,
            queue: entries,
            opened: entries,
            searches: ["a", "a",
                {
                    query: "b"
                },
                null]
        });
        compare(s.version, 1);
        compare(s.saved.length, 200);
        compare(s.queue.length, 50);
        compare(s.opened.length, 100);
        compare(s.searches, ["a", "b"]);
        var failed = false;
        try {
            M.change(s, "save", {
                id: "abcdefghijk"
            }, now);
        } catch (e) {
            failed = true;
        }
        verify(failed);
        failed = false;
        try {
            M.change(s, "queue", {
                id: "abcdefghijk"
            }, now);
        } catch (e) {
            failed = true;
        }
        verify(failed);
        compare(M.normalize(JSON.parse(JSON.stringify(s))), s);
        for (var bad of [null, 42, "bad", [],
            {
                version: 99
            },
            {
                saved: "oops",
                queue: [null]
            }
        ])
            compare(M.normalize(bad).saved.length, 0);
        failed = false;
        try {
            M.change({
                version: 99
            }, "search", "a", now);
        } catch (e) {
            failed = true;
        }
        verify(failed);
    }
    function test_errors() {
        for (var code of [124, 126, 127, 1])
            verify(M.processError("yt-dlp", code).length > 10);
        verify(M.processError("yt-dlp", 127).indexOf("gefunden") > 0);
    }
}
