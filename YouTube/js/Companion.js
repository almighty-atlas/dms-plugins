.pragma library

var VERSION = 1
var limits = {saved: 200, queue: 50, searches: 25, opened: 100}
function validId(id) { return typeof id === "string" && /^[A-Za-z0-9_-]{11}$/.test(id) }
function url(id) { return validId(id) ? "https://www.youtube.com/watch?v=" + id : "" }
function text(value, fallback, limit) {
    return typeof value === "string" && value.trim() ? value.trim().slice(0, limit || 500) : fallback
}
function query(value) { return text(value, "", 201) }
function duration(value) {
    return typeof value === "number" && isFinite(value) && value >= 0 ? Math.floor(value) : null
}
function video(entry) {
    if (!entry || !validId(entry.id)) return null
    return {id: entry.id, title: text(entry.title, "Unbenanntes Video"),
        channel: text(entry.channel || entry.uploader, "Unbekannter Kanal"),
        durationSeconds: duration(entry.durationSeconds !== undefined ? entry.durationSeconds : entry.duration),
        live: entry.live === true || entry.live_status === "is_live" || entry.is_live === true,
        // Positive URL evidence only; a short duration does not establish Shorts membership.
        short: entry.short === true || /^https:\/\/(www\.)?youtube\.com\/shorts\/[A-Za-z0-9_-]{11}(?:[?/#]|$)/.test(entry.url || "")}
}
function videos(entries, limit) {
    var result = [], seen = {}
    if (!Array.isArray(entries)) return result
    for (var i = 0; i < entries.length && result.length < limit; ++i) {
        var item = video(entries[i])
        if (!item || seen[item.id]) continue
        seen[item.id] = true
        for (var k of ["savedAt", "openedAt"])
            if (typeof entries[i][k] === "string" && isFinite(Date.parse(entries[i][k])))
                item[k] = new Date(entries[i][k]).toISOString()
        result.push(item)
    }
    return result
}
function parse(output) {
    var payload = JSON.parse(output)
    if (!payload || !Array.isArray(payload.entries)) throw new Error("missing entries")
    return {items: videos(payload.entries, 50), count: payload.entries.length}
}
function matches(item, type, length) {
    if (type === "shorts" && !item.short) return false
    if (type === "live" && !item.live) return false
    // The extractor cannot prove that a regular watch URL is not also a Short.
    if (type === "videos") return false
    if (length === "all") return true
    var d = item.durationSeconds
    if (d === null || item.live) return false
    return length === "short" ? d < 240 : length === "medium" ? d >= 240 && d <= 1200 : d > 1200
}
function formatDuration(seconds) {
    if (seconds === null || seconds === undefined) return ""
    var d = duration(seconds)
    if (d === null) return ""
    var pad = function(n) { return n < 10 ? "0" + n : "" + n }
    return (d >= 3600 ? Math.floor(d / 3600) + ":" + pad(Math.floor(d % 3600 / 60)) : Math.floor(d / 60)) + ":" + pad(d % 60)
}
function searchArgs(term, count) {
    if (!query(term) || term.length > 200 || count < 10 || count > 50) throw new Error("invalid search")
    return ["/usr/bin/env", "yt-dlp", "--ignore-config", "--flat-playlist", "--dump-single-json",
        "--no-warnings", "--skip-download", "--socket-timeout", "10", "ytsearch" + count + ":" + term]
}
function playbackArgs(items, mode) {
    var urls = videos(items, 50).map(function(v) { return url(v.id) })
    if (!urls.length) throw new Error("Keine gültigen Videos.")
    if (mode === "browser") {
        if (urls.length !== 1) throw new Error("Warteschlangen benötigen mpv.")
        return ["/usr/bin/env", "xdg-open", urls[0]]
    }
    var args = ["/usr/bin/env", "mpv", "--no-config", "--no-terminal"]
    if (mode === "audio") args = args.concat(["--no-video", "--audio-display=no", "--force-window=no", "--ytdl-format=bestaudio/best"])
    return args.concat(["--"], urls)
}
function processError(program, code) {
    if (code === 127) return program + " wurde in der DMS-Umgebung nicht gefunden (127)."
    if (code === 126) return program + " kann nicht ausgeführt werden (126)."
    if (code === 124) return program + ": internes Zeitlimit von 25 Sekunden überschritten."
    return program + " fehlgeschlagen (Exit-Code " + code + "). Netzwerk, YouTube-Rate-Limit und DMS-Logs prüfen."
}
function empty() { return {version: VERSION, saved: [], queue: [], searches: [], opened: []} }
function normalize(raw) {
    var result = empty()
    if (!raw || typeof raw !== "object" || (raw.version !== undefined && raw.version !== VERSION && raw.version !== 0)) return result
    for (var key of ["saved", "queue", "opened"]) result[key] = videos(raw[key], limits[key])
    if (Array.isArray(raw.searches)) {
        for (var entry of raw.searches) {
            var term = query(typeof entry === "string" ? entry : entry && entry.query)
            if (!term || term.length > 200 || result.searches.indexOf(term) >= 0) continue
            result.searches.push(term)
            if (result.searches.length === limits.searches) break
        }
    }
    return result
}
function has(items, id) { return items.some(function(v) { return v.id === id }) }
// Always normalize a fresh service snapshot immediately before each synchronous mutation.
function change(raw, action, value, now) {
    if (raw && raw.version > VERSION) throw new Error("Neuere Datenversion: bitte Plugin aktualisieren.")
    var s = normalize(raw), item, index
    if (action === "search") {
        var term = query(value)
        if (term && term.length <= 200) s.searches = [term].concat(s.searches.filter(function(q) { return q !== term })).slice(0, 25)
    } else if (action === "removeSearch") s.searches = s.searches.filter(function(q) { return q !== value })
    else if (action === "clearSearches") s.searches = []
    else if (action === "clearOpened") s.opened = []
    else if (action === "clearQueue") s.queue = []
    else if (action === "move") {
        index = s.queue.findIndex(function(v) { return v.id === value.id })
        var target = index + value.offset
        if (index >= 0 && target >= 0 && target < s.queue.length) {
            item = s.queue.splice(index, 1)[0]; s.queue.splice(target, 0, item)
        }
    } else if (action === "removeQueue" || action === "removeOpened") {
        var field = action === "removeQueue" ? "queue" : "opened"
        s[field] = s[field].filter(function(v) { return v.id !== value })
    } else {
        item = video(value)
        if (!item) return s
        if (action === "save") {
            if (has(s.saved, item.id)) s.saved = s.saved.filter(function(v) { return v.id !== item.id })
            else {
                if (s.saved.length >= 200) throw new Error("Merkliste voll (200 Videos). Zuerst einen Eintrag entfernen.")
                item.savedAt = now; s.saved.unshift(item)
            }
        } else if (action === "queue" && !has(s.queue, item.id)) {
            if (s.queue.length >= 50) throw new Error("Warteschlange voll (50 Videos).")
            s.queue.push(item)
        } else if (action === "open") {
            item.openedAt = now
            s.opened = [item].concat(s.opened.filter(function(v) { return v.id !== item.id })).slice(0, 100)
        }
    }
    return s
}
